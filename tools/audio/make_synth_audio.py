"""Synthesizes the ambience loops and the bell-type cues that need no recording (docs/AUDIO_ASSETS.md):
pine wind, mountain wind with eaves bells, river, valley insects, cave drips; a temple bell, a small
bell, a stone chime (磬), a wooden fish (木鱼) and the breakthrough swell.

Every ambience is built periodic — noise shaped in the frequency domain over exactly one loop, slow
envelopes from the same kind of noise, events wrapped around the end, reverb as circular convolution —
so the loop has no seam. Ambience is normalized to about -24 LUFS (BS.1770 gating), cues to a -3 dBFS
peak. Fixed seeds: the same files every run.

Needs numpy, scipy and soundfile (libsndfile with Vorbis). Install them outside the system drive, e.g.
  python -m pip install --target .tmp/pylib numpy scipy soundfile
  PYTHONPATH=.tmp/pylib python tools/audio/make_synth_audio.py <project root>"""
import os, sys, json, hashlib
import numpy as np
import soundfile as sf
from scipy import signal

ROOT = sys.argv[1]
SR = 44100
AMBIENCE = os.path.join(ROOT, 'assets', 'audio', 'ambience')
CUES = os.path.join(ROOT, 'assets', 'audio', 'sfx', 'synth')

# --- Building blocks -------------------------------------------------------------------------------
def band_noise(rng, n, lo, hi, order=2, tilt=0.0):
    """Noise of period n samples between lo and hi Hz (Butterworth-like skirts); tilt -0.5 is pink."""
    f = np.fft.rfftfreq(n, 1.0 / SR)
    f[0] = 1e-3
    shape = np.ones_like(f)
    if lo > 0:
        shape /= np.sqrt(1 + (lo / f) ** (2 * order))
    if hi > 0:
        shape /= np.sqrt(1 + (f / hi) ** (2 * order))
    shape *= (f / 1000.0) ** tilt
    spectrum = (rng.standard_normal(f.size) + 1j * rng.standard_normal(f.size)) * shape
    spectrum[0] = 0
    x = np.fft.irfft(spectrum, n)
    return x / (np.sqrt(np.mean(x ** 2)) + 1e-12)

def envelope(rng, n, cutoff, lo, hi, sharpness=1.2):
    """A slow random level between lo and hi, periodic over n samples, changing at about `cutoff` Hz."""
    e = band_noise(rng, n, 0, cutoff, order=3)
    return lo + (hi - lo) * (0.5 + 0.5 * np.tanh(e * sharpness))

def stereo(left, right):
    return np.stack([left, right], axis=1)

def wide(rng, n, lo, hi, correlation=0.5, **kw):
    common = band_noise(rng, n, lo, hi, **kw)
    a, b = np.sqrt(correlation), np.sqrt(1 - correlation)
    return stereo(a * common + b * band_noise(rng, n, lo, hi, **kw), a * common + b * band_noise(rng, n, lo, hi, **kw))

def pan_gains(pan):
    angle = (pan + 1) * np.pi / 4
    return np.cos(angle), np.sin(angle)

def place(buf, start, sound, pan=0.0, gain=1.0):
    """Adds a mono sound at `start`, wrapping past the end of the loop."""
    n = buf.shape[0]
    left, right = pan_gains(pan)
    index = (start + np.arange(sound.size)) % n
    np.add.at(buf[:, 0], index, sound * gain * left)
    np.add.at(buf[:, 1], index, sound * gain * right)

def room(rng, seconds, decay, lowpass=6000, predelay=0.01):
    """A stereo impulse response: decorrelated noise under an exponential tail."""
    n = int(seconds * SR)
    t = np.arange(n) / SR
    tail = np.exp(-t * 6.9 / decay)
    ir = []
    for _ in range(2):
        x = band_noise(rng, n, 80, lowpass) * tail
        x[: int(predelay * SR)] = 0
        ir.append(x / np.sqrt(np.sum(x ** 2)))
    return ir

def circular_reverb(dry, ir, wet):
    n = dry.shape[0]
    out = dry.copy() * (1 - wet)
    for ch in range(2):
        out[:, ch] += wet * np.fft.irfft(np.fft.rfft(dry[:, ch], n) * np.fft.rfft(ir[ch], n), n)
    return out

def modal(partials, seconds, f0, rng=None, beat=0.0):
    """Sum of decaying sines: partials are (ratio, amplitude, decay seconds). `beat` Hz splits each in two."""
    t = np.arange(int(seconds * SR)) / SR
    out = np.zeros_like(t)
    for ratio, amp, tau in partials:
        f = f0 * ratio
        if f >= SR / 2.2:
            continue
        phase = rng.uniform(0, 2 * np.pi) if rng is not None else 0.0
        tone = np.sin(2 * np.pi * f * t + phase)
        if beat > 0:
            tone = 0.5 * (tone + np.sin(2 * np.pi * (f + beat * ratio ** 0.5) * t + phase * 1.7))
        out += amp * tone * np.exp(-t / tau)
    attack = np.minimum(1.0, t / 0.002)
    return out * attack

def strike(rng, seconds, lo, hi, tau):
    t = np.arange(int(seconds * SR)) / SR
    return band_noise(rng, t.size, lo, hi) * np.exp(-t / tau) * np.minimum(1, t / 0.0005)

def lowpass(x, hz, order=2):
    """Lowpass applied over the loop as a circle, so the filter adds no seam."""
    f = np.fft.rfftfreq(x.shape[0], 1.0 / SR)
    gain = 1 / np.sqrt(1 + (f / hz) ** (2 * order))
    return np.fft.irfft(np.fft.rfft(x, axis=0) * gain[:, None], x.shape[0], axis=0)

# --- Loudness (ITU-R BS.1770: K-weighting, 400 ms blocks, absolute and relative gates) --------------
def k_weight(x):
    a_db, q, fc = 4.0, 1 / np.sqrt(2), 1681.97
    A = 10 ** (a_db / 40)
    w0 = 2 * np.pi * fc / SR
    alpha = np.sin(w0) / (2 * q)
    c = np.cos(w0)
    b = [A * ((A + 1) + (A - 1) * c + 2 * np.sqrt(A) * alpha), -2 * A * ((A - 1) + (A + 1) * c), A * ((A + 1) + (A - 1) * c - 2 * np.sqrt(A) * alpha)]
    a = [(A + 1) - (A - 1) * c + 2 * np.sqrt(A) * alpha, 2 * ((A - 1) - (A + 1) * c), (A + 1) - (A - 1) * c - 2 * np.sqrt(A) * alpha]
    y = signal.lfilter(b, a, x, axis=0)
    w0 = 2 * np.pi * 38.13 / SR
    alpha = np.sin(w0) / (2 * 0.5003)
    c = np.cos(w0)
    return signal.lfilter([(1 + c) / 2, -(1 + c), (1 + c) / 2], [1 + alpha, -2 * c, 1 - alpha], y, axis=0)

def lufs(x):
    y = k_weight(x if x.ndim == 2 else x[:, None])
    block, step = int(0.4 * SR), int(0.1 * SR)
    if y.shape[0] <= block:   # shorter than one block: ungated
        return -0.691 + 10 * np.log10(np.sum(np.mean(y ** 2, axis=0)) + 1e-20)
    powers = np.array([np.sum(np.mean(y[i:i + block] ** 2, axis=0)) for i in range(0, y.shape[0] - block, step)])
    loud = -0.691 + 10 * np.log10(powers + 1e-20)
    kept = powers[loud > -70]
    relative = -0.691 + 10 * np.log10(np.mean(kept)) - 10
    kept = powers[(loud > -70) & (loud > relative)]
    return -0.691 + 10 * np.log10(np.mean(kept))

MANIFEST = {}

def save(path, x, note, target_lufs=None, peak_db=-3.0):
    if target_lufs is not None:
        x = x * 10 ** ((target_lufs - lufs(x)) / 20)
        peak = np.max(np.abs(x))
        if peak > 10 ** (-1 / 20):   # keep ambience under -1 dBFS
            x *= 10 ** (-1 / 20) / peak
    else:
        x = x * 10 ** (peak_db / 20) / np.max(np.abs(x))
    os.makedirs(os.path.dirname(path), exist_ok=True)
    # In small blocks: one large write overflows libsndfile's stack in its Vorbis encoder on Windows.
    with sf.SoundFile(path, 'w', SR, 1 if x.ndim == 1 else x.shape[1], format='OGG', subtype='VORBIS') as out:
        for i in range(0, x.shape[0], 8192):
            out.write(x[i:i + 8192].astype(np.float32))
    data = open(path, 'rb').read()
    rel = os.path.relpath(path, ROOT).replace('\\', '/')
    MANIFEST[rel] = {'note': note, 'seconds': round(x.shape[0] / SR, 2), 'channels': 1 if x.ndim == 1 else x.shape[1],
                     'lufs': round(lufs(x), 1), 'peak_dbfs': round(20 * np.log10(np.max(np.abs(x))), 1),
                     'sha256': hashlib.sha256(data).hexdigest()}
    print('%-52s %5.1f s  %6.1f LUFS  peak %5.1f dBFS  %4d KB' % (rel, x.shape[0] / SR, MANIFEST[rel]['lufs'], MANIFEST[rel]['peak_dbfs'], len(data) // 1024))

# --- Ambience --------------------------------------------------------------------------------------
def wind_bed(rng, n, lo, hi, gust_rate, gust_lo, brightness):
    gust = envelope(rng, n, gust_rate, gust_lo, 1.0)
    flutter = envelope(rng, n, 0.7, 0.85, 1.0)
    low = wide(rng, n, lo, (lo + hi) / 2, 0.6, tilt=-0.4)
    high = wide(rng, n, (lo + hi) / 2, hi, 0.4, tilt=-0.4)
    level = (gust * flutter)[:, None]
    # Stronger gusts sound brighter.
    bed = low * level + high * level ** 1.6 * brightness
    return bed, gust

def pine_wind(seconds=48):
    rng = np.random.default_rng(101)
    n = seconds * SR
    bed, gust = wind_bed(rng, n, 160, 1400, 0.09, 0.22, 0.8)
    needles = wide(rng, n, 2200, 7500, 0.2, tilt=-0.3) * (gust ** 2.2)[:, None] * 0.35
    rumble = wide(rng, n, 35, 140, 0.8) * gust[:, None] * 0.5
    return bed + needles + rumble

def eaves_bell(rng, f0):
    partials = [(1.0, 1.0, 1.9), (1.51, 0.45, 1.1), (2.74, 0.35, 0.6), (4.17, 0.18, 0.3), (5.6, 0.08, 0.18)]
    tone = modal(partials, 3.0, f0, rng, beat=0.6)
    return tone + 0.25 * strike(rng, 3.0, 2500, 9000, 0.004)

def mountain_wind_bells(seconds=60):
    rng = np.random.default_rng(202)
    n = seconds * SR
    bed, gust = wind_bed(rng, n, 110, 900, 0.07, 0.25, 0.5)
    bells = np.zeros((n, 2))
    pitches = [1245.0, 1397.0, 1661.0]   # three bells under the eaves, a little out of tune with each other
    t = 0.6
    while t < seconds - 0.2:
        level = gust[int(t * SR)]
        if rng.random() < 0.15 + 0.85 * level ** 2:
            bell = int(rng.integers(len(pitches)))
            f0 = pitches[bell] * rng.uniform(0.997, 1.003)
            gain = rng.uniform(0.3, 1.0) * (0.5 + 0.5 * level)
            pan = (-0.5, 0.15, 0.55)[bell] + rng.uniform(-0.08, 0.08)
            place(bells, int(t * SR), eaves_bell(rng, f0), pan, gain)
            if rng.random() < 0.45:   # the clapper falls back
                place(bells, int((t + rng.uniform(0.12, 0.22)) * SR), eaves_bell(rng, f0), pan, gain * 0.4)
        t += rng.exponential(2.6)
    bells = lowpass(bells, 6000)
    bells = circular_reverb(bells, room(rng, 2.2, 2.0, 5000, 0.03), 0.45)
    return bed + bells * 1.2

def bubble(rng, f0, tau):
    t = np.arange(int(tau * 6 * SR)) / SR
    freq = f0 * (1 + 0.6 * t / tau)
    return np.sin(2 * np.pi * np.cumsum(freq) / SR) * np.exp(-t / tau) * np.minimum(1, t / 0.0005)

def bird_call(rng):
    out = []
    base = rng.uniform(2600, 3300)
    for i in range(int(rng.integers(3, 6))):
        d = rng.uniform(0.06, 0.11)
        t = np.arange(int(d * SR)) / SR
        sweep = base * (1 + rng.uniform(0.2, 0.45) * np.sin(np.pi * t / d)) * (1 + 0.03 * np.sin(2 * np.pi * 38 * t))
        phase = 2 * np.pi * np.cumsum(sweep) / SR
        tone = (np.sin(phase) + 0.25 * np.sin(2 * phase)) * np.sin(np.pi * t / d) ** 2
        out += [tone, np.zeros(int(rng.uniform(0.04, 0.09) * SR))]
        base *= rng.uniform(0.94, 1.08)
    return np.concatenate(out)

def river_egrets(seconds=50):
    rng = np.random.default_rng(303)
    n = seconds * SR
    swell = envelope(rng, n, 0.12, 0.7, 1.0)[:, None]
    flow = wide(rng, n, 180, 3200, 0.3, tilt=-0.5) * swell
    lap = wide(rng, n, 70, 320, 0.6) * envelope(rng, n, 1.8, 0.2, 1.0, 2.0)[:, None] * 0.6
    burble = np.zeros((n, 2))
    t = 0.0
    while t < seconds:
        f0 = rng.uniform(350, 1600)
        place(burble, int(t * SR), bubble(rng, f0, rng.uniform(0.004, 0.012)), rng.uniform(-0.8, 0.8), rng.uniform(0.05, 0.3))
        t += rng.exponential(1 / 45.0)
    birds = np.zeros((n, 2))
    for start in (7.5, 29.0, 41.5):
        place(birds, int(start * SR), bird_call(rng), rng.uniform(-0.7, 0.7), 1.5)
    birds = circular_reverb(lowpass(birds, 7000), room(rng, 1.6, 1.4, 6000, 0.04), 0.5)
    return flow * 0.45 + lap + burble * 6.0 + birds

def cricket(rng):
    """One cricket's song: chirps of a few pulses, repeated with a little drift, fading in and out."""
    f = rng.uniform(3900, 5200)
    pulses = int(rng.integers(3, 6))
    pulse = int(rng.uniform(0.012, 0.018) * SR)
    gap = int(rng.uniform(0.008, 0.014) * SR)
    t = np.arange(pulse) / SR
    one = (np.sin(2 * np.pi * f * t) + 0.15 * np.sin(4 * np.pi * f * t)) * np.sin(np.pi * np.arange(pulse) / pulse) ** 2
    chirp = np.concatenate([np.concatenate([one, np.zeros(gap)]) for _ in range(pulses)])
    period = rng.uniform(0.45, 1.1)
    return chirp, period

def valley_insects(seconds=45):
    rng = np.random.default_rng(404)
    n = seconds * SR
    air = wide(rng, n, 90, 1800, 0.5, tilt=-0.6) * 0.25
    song = np.zeros((n, 2))
    for i in range(6):
        chirp, period = cricket(rng)
        pan = rng.uniform(-0.8, 0.8)
        presence = envelope(rng, n, 0.05, 0.0, 1.0, 1.8)
        gain = rng.uniform(0.35, 1.0)
        t = rng.uniform(0, period)
        while t < seconds:
            place(song, int(t * SR), chirp, pan, gain * presence[int(t * SR)])
            t += period * rng.uniform(0.96, 1.04)
    t = np.arange(n) / SR
    trill_rate = 32.0 * round(seconds * 32.0) / (seconds * 32.0)
    trill = np.sin(2 * np.pi * 6400 * t) * (0.5 + 0.5 * np.sign(np.sin(2 * np.pi * trill_rate * t))) * envelope(rng, n, 0.04, 0.0, 1.0, 1.5)
    song[:, 0] += 0.12 * trill
    song[:, 1] += 0.08 * trill
    song = circular_reverb(song, room(rng, 1.2, 0.9, 9000, 0.02), 0.35)
    return air + song * 0.5

def drip(rng, f0):
    tau = rng.uniform(0.012, 0.03)
    t = np.arange(int(tau * 7 * SR)) / SR
    freq = f0 * (1 + 1.4 * (1 - np.exp(-t / (tau * 0.8))))
    tone = np.sin(2 * np.pi * np.cumsum(freq) / SR) * np.exp(-t / tau) * np.minimum(1, t / 0.0004)
    click = band_noise(rng, t.size, 2000, 8000) * np.exp(-t / 0.0015) * 0.15
    return tone + click

def cave_drips(seconds=45):
    rng = np.random.default_rng(505)
    n = seconds * SR
    tone = wide(rng, n, 30, 260, 0.7, tilt=-0.6) * envelope(rng, n, 0.05, 0.7, 1.0)[:, None] * 0.35
    drops = np.zeros((n, 2))
    for source in range(5):   # a few places in the cave that keep dripping, each with its own pitch and pace
        f0 = rng.uniform(700, 2300)
        pan = rng.uniform(-0.8, 0.8)
        period = rng.uniform(1.6, 4.5)
        gain = rng.uniform(0.35, 1.0)
        t = rng.uniform(0, period)
        while t < seconds:
            place(drops, int(t * SR), drip(rng, f0 * rng.uniform(0.98, 1.02)), pan, gain * rng.uniform(0.8, 1.0))
            t += period * rng.uniform(0.85, 1.15)
    drops = circular_reverb(drops, room(rng, 3.5, 3.2, 4500, 0.035), 0.65)
    return tone + drops * 0.6

# --- Cues ------------------------------------------------------------------------------------------
TEMPLE = [(0.5, 0.55, 5.0), (1.0, 1.0, 4.0), (1.19, 0.55, 3.2), (1.5, 0.45, 2.6), (2.0, 0.7, 2.0), (2.5, 0.28, 1.5),
          (2.97, 0.32, 1.1), (4.0, 0.18, 0.75), (5.2, 0.1, 0.45), (6.4, 0.06, 0.3)]

def temple_bell(seconds=7.0, f0=196.0, seed=601):
    rng = np.random.default_rng(seed)
    tone = modal(TEMPLE, seconds, f0, rng, beat=0.45)
    thump = modal([(1.0, 1.0, 0.12)], seconds, f0 * 0.5, rng) * 0.4
    hit = strike(rng, seconds, 150, 2500, 0.012) * 0.5
    x = tone + thump + hit
    x[-int(0.3 * SR):] *= np.linspace(1, 0, int(0.3 * SR))
    return x

def small_bell(seconds=2.4, f0=988.0, seed=602):
    rng = np.random.default_rng(seed)
    x = modal([(1.0, 1.0, 1.1), (2.0, 0.35, 0.6), (2.76, 0.25, 0.4), (5.4, 0.08, 0.15)], seconds, f0, rng, beat=0.8)
    x += 0.15 * strike(rng, seconds, 3000, 9000, 0.003)
    x[-int(0.2 * SR):] *= np.linspace(1, 0, int(0.2 * SR))
    return x

def two_bells():
    first = small_bell(seed=603)
    second = small_bell(f0=880.0, seed=604)
    gap = int(0.42 * SR)
    out = np.zeros(gap + second.size)
    out[:first.size] += first
    out[gap:] += second * 0.85
    return out

def stone_chime(f0=523.0, seed=605):
    rng = np.random.default_rng(seed)
    x = modal([(1.0, 1.0, 1.4), (2.76, 0.45, 0.55), (5.40, 0.22, 0.25), (8.93, 0.1, 0.12)], 2.6, f0, rng, beat=0.3)
    x += 0.3 * strike(rng, 2.6, 800, 6000, 0.004)
    x[-int(0.2 * SR):] *= np.linspace(1, 0, int(0.2 * SR))
    return x

def wooden_fish(f0, seed):
    rng = np.random.default_rng(seed)
    x = modal([(1.0, 1.0, 0.045), (1.87, 0.35, 0.025), (3.1, 0.12, 0.012)], 0.32, f0, rng)
    x += 0.35 * strike(rng, 0.32, 1500, 6000, 0.0025)
    return x

def breakthrough(seed=606):
    rng = np.random.default_rng(seed)
    rise, total = 1.3, 4.5
    n = int(total * SR)
    t = np.arange(n) / SR
    out = np.zeros(n)
    # Qi gathering: noise bands coming in from low to high, and a rising hum.
    for i, (lo, hi) in enumerate([(200, 600), (500, 1400), (1200, 3200), (2800, 7000)]):
        band = band_noise(rng, n, lo, hi)
        start = rise * i / 5
        env = np.clip((t - start) / (rise - start), 0, 1) ** 2 * (t < rise)
        out += band * env * 0.18
    glide = 110 * 2 ** (2.0 * np.clip(t / rise, 0, 1))
    hum = np.sin(2 * np.pi * np.cumsum(glide) / SR)
    hum = (hum + 0.4 * np.sin(2 * 2 * np.pi * np.cumsum(glide) / SR)) * np.clip(t / rise, 0, 1) ** 1.5 * (t < rise)
    out += hum * 0.25
    # The release: a bell, a deep boom and a shower of sparkles.
    at = int(rise * SR)
    bell = modal(TEMPLE[1:], total - rise, 330.0, rng, beat=0.5)
    boom = modal([(1.0, 1.0, 0.5)], total - rise, 55.0, rng)
    sparkle = np.zeros(n - at)
    for _ in range(26):
        f = rng.uniform(2500, 6500)
        d = int(rng.uniform(0.05, 1.2) * SR)
        s = modal([(1.0, 1.0, rng.uniform(0.08, 0.3))], 0.9, f, rng)
        end = min(sparkle.size, d + s.size)
        sparkle[d:end] += s[:end - d] * rng.uniform(0.1, 0.3)
    out[at:] += bell * 0.8 + boom * 0.7 + sparkle * 0.5
    out[-int(0.3 * SR):] *= np.linspace(1, 0, int(0.3 * SR))
    return out

# --- Write -----------------------------------------------------------------------------------------
AMBIENT = {
    'pine_wind.ogg': (pine_wind, '松涛：分层风声，阵风越强越亮，松针高频沙沙'),
    'mountain_wind_bells.ogg': (mountain_wind_bells, '山风与远处三只檐铃，阵风时铃声多，带回响'),
    'river_egrets.ogg': (river_egrets, '流水、细碎水泡与拍岸，三次远处鸟鸣'),
    'valley_insects.ogg': (valley_insects, '六只蟋蟀各自的鸣唱与一层远处虫声，夜气'),
    'cave_drips.ogg': (cave_drips, '洞中五处滴水各有音高与节奏，长混响，低沉的空洞底噪'),
}
for name, (make, note) in AMBIENT.items():
    save(os.path.join(AMBIENCE, name), make(), note, target_lufs=-24.0)

SOUNDS = {
    'temple_bell.ogg': (temple_bell(), '寺钟：长鸣，钟声拍频'),
    'small_bell.ogg': (small_bell(), '小铃一声'),
    'two_bells.ogg': (two_bells(), '小铃两声'),
    'stone_chime.ogg': (stone_chime(), '磬一声'),
    'wooden_fish_1.ogg': (wooden_fish(760.0, 607), '木鱼'),
    'wooden_fish_2.ogg': (wooden_fish(690.0, 608), '木鱼（低）'),
    'breakthrough.ogg': (breakthrough(), '突破：灵气聚拢渐强，钟声、低鸣与星屑释放'),
}
for name, (x, note) in SOUNDS.items():
    save(os.path.join(CUES, name), x, note)

json.dump({'generator': 'tools/audio/make_synth_audio.py', 'sample_rate': SR, 'files': MANIFEST},
          open(os.path.join(ROOT, 'assets', 'audio', 'synth_manifest.json'), 'w', encoding='utf-8', newline='\n'), ensure_ascii=False, indent=1)
