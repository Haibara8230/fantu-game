# Art Brief M4: Duel Backgrounds, Duel Sprites and Event Illustrations

> 给人类读者：这份文档写给图像生成 AI，可以整份交给它，与 `docs/ART_BRIEF.md`（地图、横幅、立绘）和 `docs/PORTRAIT_POOL_BRIEF.md`（生成人物立绘图池）配套。
>
> **接入状态（交付前请看）：**
> - A、B 组已接入：图片放到指定路径后运行 `play.cmd` 或 `check.cmd`（会先导入资源）即可生效，不需要改代码；缺哪张就继续用 `bamboo_arena_v1.png` 或 `rival_atlas_v2.png`。
>   - 斗法背景按斗法地点选择；途中遭遇（妖狼、劫修拦路）用 `road.png`。路径规则见 `data/art.json` 的 `place_background`。
>   - 劫修图集见 `data/art.json` 中 `rogue`、`ruin_rogue` 的 `preferred`；生成修士按其门派与性别选 `cultivator_<门派>_<性别>.png`（`look`）。
> - C 组事件插图：对话与事件演出（M4）还未制作，图片先按本规格准备，版式确定后可能调整尺寸。接入工作记录在 `docs/BACKLOG.md`。

This brief is self-contained. Read it fully before generating anything.

---

## 1. What you are making

**The game.** 凡途 (Fantu), a single-player 2D Chinese cultivation (xianxia) RPG made in Godot. The player lives through centuries in one persistent world, travels a node map, meets people and fights **turn-based side-view duels**: the player stands on the left, the opponent on the right, both drawn as full-body sprites over a painted background. The style direction is the Chinese indie game **觅长生 (Mi Chang Sheng)**: illustrated 2D, hand-drawn, readable, not realistic.

**This batch: 29 images in three groups.**

| Group | Count | Purpose in the game |
|---|---|---|
| A. Duel backgrounds | 8 | Backdrop of the duel screen, one per place plus one for roadside fights |
| B. Duel sprite atlases | 14 | Six-pose full-body sprites for human opponents |
| C. Event illustrations | 7 | Key-moment pictures shown during story events |

**Priority:** B1 → A → B2 → C → B3. Deliver in that order if you cannot do everything at once.

---

## 2. Style guide (applies to every image)

**Match the existing art in the repository.** Look at these before starting:
- `assets/art/cultivator_atlas_v2.png`: the player's six-pose sprite atlas. Clear dark outlines, flat colors, simple two-tone shading.
- `assets/art/rival_atlas_v2.png`: a second character (female outer-sect disciple) in the same format and style.
- `assets/art/beasts_atlas_v1.png`: the mountain wolf and the crimson serpent.
- `assets/art/bamboo_arena_v1.png`: the current (only) duel background. **Group A must follow its composition.**
- `assets/art/portraits/*.png`: character portraits. Characters in groups B and C who already have a portrait must look like the same person.

**Do:**
- Unmistakably **two-dimensional, hand-drawn Chinese fantasy game art**.
- Clear ink outlines, flat color areas, restrained washes, one or two simple shadow tones.
- Palette: deep teal and ink green, slate blue, jade green, warm parchment and pale stone, small warm accents (lantern orange, sunset rose).
- All people are adults, modestly dressed.

**Do not:**
- No photorealism, 3D renders, cinematic lighting, glossy CGI, realistic textures, satin or brocade shine, heavy film grain.
- No chibi, no pixel art, no anime moe style.
- **No text, letters, calligraphy, labels, signatures, watermarks, frames, UI elements or logos anywhere.** Signs, banners and jade slips are blank or carry abstract patterns only.
- No modern objects.

---

## 3. Technical rules

- **Format:** PNG. Group A and C: RGB. Group B: **RGBA with real transparency** (not a painted checkerboard, not a dark backdrop).
- **Sizes:** exactly as listed. Group B must be **exactly 1536×1024**, because the game cuts it into a fixed grid.
- **File names and folders:** exactly as listed, lowercase, inside the repository.
- If you work inside the repository: only add image files. **Do not modify code or data files.** Then add a short record (file, size, prompt used) to `docs/ART_ASSETS.md`.

---

## 4. Group A: Duel backgrounds (8 images)

**Folder:** `assets/art/battle/`
**Size:** **1792×768** (7:3). The game stretches this image to fill the duel stage, so keep exactly this aspect ratio.

**Composition (same for all eight, copy `bamboo_arena_v1.png`):**
- Side view, camera slightly above the ground, no extreme perspective.
- **Ground line at about 80% of the height.** The lower part is a broad, flat, unobstructed walkable surface across the full width.
- Two full-body characters will stand at about **28% and 74% of the width**, each about 85% of the image height tall. Keep those two zones and the space between them **calm and uncluttered**: no tall objects, no bright spots behind the characters.
- Frame only the far left and right edges with scenery (trees, rocks, buildings).
- Spell effects (sword light, fire, water, leaves, stone) will be drawn on top, so avoid strong glows or saturated colours in the middle band.
- No characters, animals, weapons or magic effects in the picture.

| File | Where the fight happens | Content |
|---|---|---|
| `sect.png` | Qingyun Mountain: training plaza (sparring, outer-sect tournament) | Wide pale stone plaza on a mountain, low stone railings, weapon racks at the far edges, sect halls and a sea of clouds behind, distant main peak |
| `town.png` | Qingshi Town | Packed-earth lane at the edge of a small mortal town, grey-tiled walls and a willow at the edges, low hills behind |
| `ferry.png` | Bailu Ferry | Flat sandy riverbank and shallows, reeds at the edges, a small wooden pier at the far right, wide calm river and far mountains behind |
| `market.png` | Yunxi Market | Open stone-paved square just outside the market at dusk, closed stalls and hanging lanterns at the edges, river roofs behind |
| `ridge.png` | Songfeng Ridge | Needle-covered forest clearing on a ridge, ancient pines framing both edges, layered ridge lines behind |
| `wild.png` | Luoxia Valley: every fight in the valley (wolves at its mouth, the serpent at its spring) | Rocky valley floor with mist, a faint glowing spring far in the background (not behind the characters), a few large red scales on the rocks, rose-gold sunset light high on the cliffs; uneasy mood |
| `ruin.png` | Ancient Cave: in front of the stone door | Narrow ledge at the foot of a vine-covered cliff, the old stone door half visible at the far right edge, quiet and slightly dim |
| `road.png` | Roadside ambushes while travelling (wolves, the masked rogue) | Winding mountain road at a bend, scattered rocks and shrubs at the edges, hills and distant pines behind; neutral daylight so it suits any route |

**Prompt template** (replace `<SUBJECT>` with the Content column):
```text
Wide side-view DUEL BACKGROUND for a 2D Chinese cultivation turn-based RPG, in the illustrated visual family of the game 觅长生. Exactly 1792x768 (7:3).
Subject: <SUBJECT>.
Composition: side view with the camera slightly above the ground, no extreme perspective. Ground line at about 80% of the height; the lower area is a broad flat unobstructed walkable surface across the whole width. Two full-body characters will stand at about 28% and 74% of the width; keep those zones and the space between them calm, low-contrast and uncluttered. Frame only the far outer edges with scenery. No strong glow or saturated colour in the middle band, because spell effects will be drawn on top.
Style: unmistakably two-dimensional hand-painted Chinese game background, restrained ink outlines, flat colour areas, simplified painterly shapes, muted jade, warm pale stone, dusty blue mountains, parchment highlights; calm spirit-world atmosphere. Not a photo, not 3D, no cinematic lighting.
NO characters, animals, monsters, weapons, magic effects, text, labels, UI, frame or watermark.
```

---

## 5. Group B: Duel sprite atlases (14 images)

**Folder:** `assets/art/actors/`
**Format (identical for all 14, copy `cultivator_atlas_v2.png` exactly):**
- **1536×1024 RGBA**, real transparent background.
- **Strict 3 columns × 2 rows** of equal 512×512 cells. No gridlines, labels, floor, shadows, effects or background.
- **One figure per cell**, the whole body and weapon inside the cell with safe margins. Same character size in every cell, **feet on a baseline at about 92% of the cell height**, figure about 6.5 heads tall.
- **Every pose faces RIGHT.** The game mirrors the sprite when the character stands on the right side.
- Same identity, face and costume in all six cells. Silhouette must read clearly at about 220 pixels tall.

**Pose order** (left to right, top row then bottom row):

| Cell | Pose | Description |
|---|---|---|
| 1 | idle | Relaxed ready stance, weapon lowered or hands at rest |
| 2 | prepare | Gathering power: weight back, weapon drawn back or hands pulling energy in |
| 3 | attack | Forward strike to the RIGHT: weapon thrust or palm strike, body leaning in |
| 4 | cast | Spell gesture: two fingers raised or hand-seal held in front |
| 5 | hit | Recoiling backward (to the LEFT) from a blow, off balance |
| 6 | guard | Defensive stance, weapon or forearm raised across the body |

**Sect costume colours** (used by B2 and B3; keep them muted, these are the accent colours of each sect):

| Sect | Accent | Costume direction | Typical weapon / gesture |
|---|---|---|---|
| Wanderer 散修 (no sect) | grey-green `#b6d8c9` | Plain travelling robe, patched, straw-coloured sash, small cloth bundle | Plain sword or bare hands |
| Qingyun Sword Sect 青云剑宗 | pale jade `#c2f3e9` | Ivory outer robe, pale jade trim, neat topknot | Straight jian sword |
| Chixiao Sect 赤霄门 (fire) | ember orange `#ffb579` | Dark crimson robe with ember-orange trim, wide sleeves | Fire hand-seals, palm strikes |
| Changqing Valley 长青谷 (wood) | leaf green `#a4e9a6` | Moss-green layered robe, leaf-shaped hem, vine cord belt | Finger-seals, a short wooden staff |
| Canglan Pavilion 沧澜阁 (water, ice) | water blue `#9ddcf4` | Slate-blue and white robe with wave-pattern hem | Pushing palms, a slender ice-blue sword |
| Xuanyue Sect 玄岳宗 (earth) | ochre `#e1bf81` | Heavy earth-brown robe, ochre trim, broad shoulders, grounded stance | Heavy palm, stamping stance |

### B1. Named opponents (2 atlases, highest priority)

| File | Character | Description |
|---|---|---|
| `rogue.png` | Masked rogue cultivator 拦路劫修 (Chixiao outcast), 35, male | Must match `assets/art/portraits/rogue.png`: cloth mask over the lower face, dark robe with red trim, cold eyes. Carries a plain sword ("blocks the road with a drawn sword") and summons a small flame in one palm for the cast pose |
| `ruin_rogue.png` | Shi Han 石寒, cave squatter (Xuanyue outcast), 49, male | Must match `assets/art/portraits/squatter.png`: rough brown Taoist robe, stony suspicious face, earth-toned. Bare-handed, heavy stamping stances, stone-palm strikes |

### B2. Generated cultivators of this region (6 atlases)

These are the generated people of the Qingyun region (outer disciples, wanderers, market cultivators, herb gatherers, travelling Chixiao cultivators). Each atlas is a **generic, ordinary-looking** member of that group, not a hero: simpler clothes and plainer faces than the player sprite.

| File | Group | Gender |
|---|---|---|
| `cultivator_qingyun_male.png` | Qingyun outer disciple | male |
| `cultivator_qingyun_female.png` | Qingyun outer disciple | female |
| `cultivator_wanderer_male.png` | Wanderer (also used for market cultivators and herb gatherers) | male |
| `cultivator_wanderer_female.png` | Wanderer | female |
| `cultivator_chixiao_male.png` | Travelling Chixiao cultivator | male |
| `cultivator_chixiao_female.png` | Travelling Chixiao cultivator | female |

The Qingyun pair must look clearly different from the player (`cultivator_atlas_v2.png`) and the named female disciple (`rival_atlas_v2.png`): plainer outer-disciple uniform, different hairstyles.

### B3. Other sects (6 atlases, lowest priority)

For sparring opponents of the remaining sects: `cultivator_changqing_male.png`, `cultivator_changqing_female.png`, `cultivator_canglan_male.png`, `cultivator_canglan_female.png`, `cultivator_xuanyue_male.png`, `cultivator_xuanyue_female.png`. Use the sect costume table above.

**Prompt template** (replace `<CHARACTER>`):
```text
Transparent sprite animation atlas for a 2D Chinese cultivation RPG, in the visual family of 觅长生's illustrated in-game characters, matching the attached reference atlas exactly in format and style.
Character: <CHARACTER>. Adult, modest practical clothing.
STRICT 3x2 grid on a 1536x1024 transparent canvas, six equal 512x512 cells, one figure per cell, no gridlines or labels. Entire body and weapon inside each cell with safe margins; same size in every cell; feet on a baseline at 92% of the cell height; about 6.5 heads tall. FACING RIGHT in every pose.
Top row: idle ready stance / gathering power, weight back / forward strike to the right.
Bottom row: spell hand-seal with two fingers raised / recoiling backward to the left from a hit / defensive guard.
Same identity, face and costume in all six poses; crisp simple silhouettes readable at 220px tall.
Style: NON-REALISTIC hand-drawn 2D game sprite, clear thin dark outlines, flat opaque colour areas, one or two simple cel-shaded shadow tones, simplified clothing folds, slightly stylized face, graphic grouped hair locks. Not photorealistic, not 3D, not semi-realistic, no satin or brocade, not chibi.
No scene, floor, shadows, particles, effects or background. Real transparent alpha.
```

---

## 6. Group C: Event illustrations (7 images)

**Folder:** `assets/art/events/`
**Size:** **1600×900** (16:9). Keep the important content in the **central 80% of the width**; the game may show text over the **bottom quarter**, so keep that area quieter.

These are the key moments of the story events. Unlike the banners, they **do** show characters. Characters who have a portrait must match it (look at `assets/art/portraits/`). The serpent must match `assets/art/beasts_atlas_v1.png` (crimson scales, short horns, amber eyes, pale belly, dark red crest; not a western dragon).

| File | Event | Scene |
|---|---|---|
| `yunxi_auction.png` | 云溪特殊拍卖 Special auction at Yunxi | Inside a red-lacquered small hall lit by many lamps; guests in veiled wide-brim hats seated in rows; on a stand at the centre, a hundred-year lingzhi mushroom on a tray beside a few pills in an open box |
| `yunxi_night_market.png` | 云溪夜市 Yunxi night market (every three years) | Long market street at night hung with rows of lanterns; wanderer cultivators displaying pills and herbs on cloths; busy but calm, small figures, no readable signs |
| `teahouse_story.png` | 茶馆说书 Storytelling at the teahouse | The storyteller He Sangeng (see `storyteller.png`) on a small stage, folding fan raised, wooden gavel on the table, pausing with a sly smile; tea drinkers leaning forward; rain outside the window |
| `wounded_in_pines.png` | 林间伤者 The wounded cultivator | Liu Hanzhou (see `wounded.png`) sitting against an old pine beside a forest path, blood on his collar, plain sword across his knees, dappled light |
| `rogue_ambush.png` | 劫修拦路 Ambush on the road | The masked rogue (see `rogue.png`) standing in the middle of a mountain road with a drawn sword, viewed from the traveller's position, a small flame in his other palm |
| `serpent_rampage.png` | 妖蟒之乱 The serpent rampage | The crimson serpent coiled across the mouth of Luoxia Valley among broken rocks, head raised, mist and sunset light behind; tiny fleeing figures for scale; the valley clearly blocked |
| `outer_tournament.png` | 外门小比 Outer-sect tournament (every ten years) | The Qingyun training plaza with plain sect banners (no writing) around the edge, rows of outer disciples watching, two disciples facing each other in the centre, elders seated on a raised platform |

**Prompt template** (replace `<SCENE>`):
```text
Story event illustration for a 2D Chinese cultivation RPG, in the illustrated visual family of the game 觅长生. Exactly 1600x900 (16:9).
Scene: <SCENE>.
Composition: clear focal point in the central 80% of the width; the bottom quarter stays quieter because text may be shown there. Characters are adults in modest clothing, consistent with the referenced portraits.
Style: unmistakably two-dimensional hand-drawn Chinese game illustration, clear ink outlines, flat colour areas, restrained washes, one or two simple shadow tones; muted jade, slate blue, warm stone and parchment palette with small warm accents. Not photorealistic, not 3D, no cinematic lighting, not chibi, not anime moe.
NO text, letters, calligraphy, labels, UI, frame, signature or watermark; all signs and banners blank.
```

---

## 7. Final checklist

- [ ] File name and folder exactly as listed (lowercase)
- [ ] Group A: exactly 1792×768; ground line at about 80%; the 28% and 74% character zones calm; no characters or effects
- [ ] Group B: exactly 1536×1024, real transparent alpha; strict 3×2 grid; pose order correct; every pose faces right; feet at 92% of each cell; same size in all cells
- [ ] Group B1: rogue and Shi Han match their portraits
- [ ] Group C: exactly 1600×900; portrait characters and the serpent match their references; bottom quarter quieter
- [ ] No text, letters, labels, signatures or watermarks anywhere
- [ ] Style consistent with `cultivator_atlas_v2.png` and `bamboo_arena_v1.png`: 2D, outlined, flat colours, not realistic
- [ ] (Working in the repository) only image files added, plus a record in `docs/ART_ASSETS.md`

**Testing (in the repository):** run `check.cmd`. It imports new images and runs the automated tests in the background.
