extends Node
## Music, ambience and sound cues on separate buses with saved volumes. Any file listed in
## data/audio.json that is not in the project yet is replaced by a short synthesized placeholder
## (cues) or silence (music, ambience), so the system works before final audio arrives.
const SETTINGS_PATH := "user://settings.cfg"
const BUSES := ["Music", "SFX", "Ambience"]
const DEFAULT_VOLUMES := {"Master": 0.8, "Music": 0.7, "SFX": 0.8, "Ambience": 0.6}
const FADE_SECONDS := 1.2
const SFX_VOICES := 6
const MIX_RATE := 22050
var library: Dictionary = {}
var volumes: Dictionary = DEFAULT_VOLUMES.duplicate()
var settings_path := SETTINGS_PATH
var music_key := ""
var ambience_key := ""
var last_cue := ""
var _music: Array[AudioStreamPlayer] = []
var _active_music := 0
var _ambience: AudioStreamPlayer
var _voices: Array[AudioStreamPlayer] = []
var _placeholders: Dictionary = {}
# Headless runs (tests) track requests but start no playback: there is no one to hear it, and the
# dummy driver never releases stopped playbacks.
var silent := DisplayServer.get_name() == "headless"

func _ready() -> void:
	_ensure_buses()
	library = JSON.parse_string(FileAccess.get_file_as_string("res://data/audio.json"))
	for index: int in range(2):
		var player := AudioStreamPlayer.new()
		player.bus = "Music"
		player.volume_db = -80.0
		add_child(player)
		_music.append(player)
	_ambience = AudioStreamPlayer.new()
	_ambience.bus = "Ambience"
	add_child(_ambience)
	for index: int in range(SFX_VOICES):
		var voice := AudioStreamPlayer.new()
		voice.bus = "SFX"
		add_child(voice)
		_voices.append(voice)
	load_settings()

## Release playbacks so nothing is still mixing when the scene (or the game) goes away.
func _exit_tree() -> void:
	for player: AudioStreamPlayer in _voices + _music + [_ambience]:
		player.stop()
		player.stream = null

func _ensure_buses() -> void:
	for bus_name: String in BUSES:
		if AudioServer.get_bus_index(bus_name) == -1:
			AudioServer.add_bus()
			var index := AudioServer.bus_count - 1
			AudioServer.set_bus_name(index, bus_name)
			AudioServer.set_bus_send(index, "Master")

func set_volume(bus_name: String, linear: float) -> void:
	if not volumes.has(bus_name):
		return
	volumes[bus_name] = clampf(linear, 0.0, 1.0)
	_apply(bus_name)
	save_settings()

func _apply(bus_name: String) -> void:
	var index := AudioServer.get_bus_index(bus_name)
	if index == -1:
		return
	var linear: float = volumes[bus_name]
	AudioServer.set_bus_mute(index, linear <= 0.0)
	AudioServer.set_bus_volume_db(index, linear_to_db(maxf(linear, 0.0001)))

func load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(settings_path) == OK:
		for bus_name: String in DEFAULT_VOLUMES:
			var value: Variant = config.get_value("audio", bus_name, DEFAULT_VOLUMES[bus_name])
			volumes[bus_name] = clampf(float(value), 0.0, 1.0) if (value is float or value is int) else DEFAULT_VOLUMES[bus_name]
	for bus_name: String in volumes:
		_apply(bus_name)

func save_settings() -> void:
	var config := ConfigFile.new()
	for bus_name: String in volumes:
		config.set_value("audio", bus_name, volumes[bus_name])
	config.save(settings_path)

## Crossfades to the track for `key`; missing tracks fade to silence.
func play_music(key: String) -> void:
	if key == music_key:
		return
	music_key = key
	var stream := _looping(_file_stream(library.music.get(key, "")))
	var outgoing := _music[_active_music]
	_active_music = 1 - _active_music
	var incoming := _music[_active_music]
	var tween := create_tween().set_parallel(true)
	tween.tween_property(outgoing, "volume_db", -80.0, FADE_SECONDS)
	if stream != null:
		incoming.stream = stream
		incoming.volume_db = -80.0
		if not silent:
			incoming.play()
		tween.tween_property(incoming, "volume_db", 0.0, FADE_SECONDS)

func play_ambience(key: String) -> void:
	if key == ambience_key:
		return
	ambience_key = key
	var stream := _looping(_file_stream(library.ambience.get(key, "")))
	_ambience.stop()
	if stream != null:
		_ambience.stream = stream
		if not silent:
			_ambience.play()

## Plays a one-shot cue on a free voice (or the oldest one).
func cue(name: String) -> void:
	if not library.sfx.has(name):
		return
	last_cue = name
	var stream := _file_stream(library.sfx[name])
	if stream == null:
		stream = placeholder(name)
	var voice := _voices[0]
	for candidate: AudioStreamPlayer in _voices:
		if not candidate.playing:
			voice = candidate
			break
	voice.stream = stream
	if not silent:
		voice.play()

func _file_stream(path: String) -> AudioStream:
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	return load(path) as AudioStream

## Music and ambience always loop, whatever the import settings say.
func _looping(stream: AudioStream) -> AudioStream:
	if stream is AudioStreamOggVorbis or stream is AudioStreamMP3:
		stream.set("loop", true)
	elif stream is AudioStreamWAV and (stream as AudioStreamWAV).format == AudioStreamWAV.FORMAT_16_BITS:
		var wav := stream as AudioStreamWAV
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_end = wav.data.size() / (4 if wav.stereo else 2)
	return stream

func has_file(kind: String, key: String) -> bool:
	return _file_stream(library.get(kind, {}).get(key, "")) != null

# --- Placeholder synthesis ---------------------------------------------------------

## A short synthesized sound per cue. Deterministic, cached, and clearly temporary.
func placeholder(name: String) -> AudioStreamWAV:
	if _placeholders.has(name):
		return _placeholders[name]
	var shapes := {
		"click": [[1400.0, 0.03, 0.0]],
		"page": [[520.0, 0.08, 0.5]],
		"depart": [[0.0, 0.25, 1.0]],
		"arrive": [[660.0, 0.12, 0.0], [880.0, 0.18, 0.0]],
		"event": [[523.0, 0.5, 0.0]],
		"choice": [[784.0, 0.1, 0.0]],
		"reminder": [[988.0, 0.25, 0.0], [740.0, 0.35, 0.0]],
		"prepare": [[220.0, 0.12, 0.3]],
		"release": [[0.0, 0.18, 1.0]],
		"impact": [[90.0, 0.14, 0.6]],
		"heal": [[523.0, 0.1, 0.0], [659.0, 0.1, 0.0], [784.0, 0.16, 0.0]],
		"guard": [[150.0, 0.25, 0.1]],
		"victory": [[523.0, 0.12, 0.0], [659.0, 0.12, 0.0], [1046.0, 0.3, 0.0]],
		"defeat": [[330.0, 0.2, 0.0], [247.0, 0.35, 0.0]],
		"breakthrough": [[392.0, 0.15, 0.0], [523.0, 0.15, 0.0], [784.0, 0.5, 0.0]],
		"ending": [[294.0, 0.6, 0.0], [220.0, 0.9, 0.0]],
	}
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(name)
	var data := PackedByteArray()
	for note: Array in shapes.get(name, [[440.0, 0.1, 0.0]]):
		var frequency: float = note[0]
		var seconds: float = note[1]
		var noise: float = note[2]
		var frames := int(seconds * MIX_RATE)
		for frame: int in range(frames):
			var t := float(frame) / MIX_RATE
			var envelope := minf(1.0, t * 200.0) * pow(1.0 - float(frame) / frames, 2.0)
			var tone := sin(TAU * frequency * t) if frequency > 0.0 else 0.0
			var sample := (tone * (1.0 - noise) + rng.randf_range(-1.0, 1.0) * noise) * envelope * 0.35
			var value := int(clampf(sample, -1.0, 1.0) * 32767.0)
			data.append(value & 0xff)
			data.append((value >> 8) & 0xff)
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = MIX_RATE
	stream.stereo = false
	stream.data = data
	_placeholders[name] = stream
	return stream
