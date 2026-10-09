# Art Brief: 凡途 · 修仙纪事 (Fantu), Region "Qingyun Mountains" (青云山周边)

> 给人类读者：这份文档是写给图像生成 AI 的完整说明，可以整份交给它。它说明了要画什么、画成什么样、文件放在哪里。所有图片放进指定路径后，游戏会自动替换占位图，不需要改代码。

This brief is self-contained. Read it fully before generating anything.

---

## 1. What you are making

**The game.** A single-player 2D Chinese cultivation (xianxia) RPG made in Godot. The player lives through centuries in one persistent world, travels a node map, visits places, meets people and fights turn-based duels. The style direction is the Chinese indie game **觅长生 (Mi Chang Sheng / "Seeking Immortality")**: illustrated 2D, hand-drawn, readable, not realistic.

**This batch.** Art for the first region, "Qingyun Mountains". **28 images in four groups:**

| Group | Count | Purpose in the game |
|---|---|---|
| A. Region map | 1 | Background of the travel map screen |
| B. Location banners | 7 | Wide banner at the top of each place's page |
| C. Scene banners | 13 | Wide banner for each sub-area inside a place |
| D. Character portraits | 7 | Picture on each NPC's profile card |

**Priority:** A → B → D → C. Deliver in that order if you cannot do everything at once.

---

## 2. Style guide (applies to every image)

**Match the existing art in the repository.** Look at these before starting:
- `assets/art/cultivator_atlas_v2.png`: player character sprites. Clear dark outlines, flat colors, simple two-tone shading.
- `assets/art/rival_atlas_v2.png`: a second character in the same style.
- `assets/art/bamboo_arena_v1.png`: a landscape background. Muted jade, warm stone and dusty blue, restrained ink lines, simplified painterly shapes.

**Do:**
- Unmistakably **two-dimensional, hand-drawn Chinese fantasy game art**.
- Clear ink outlines, flat color areas, restrained washes, one or two simple shadow tones.
- Calm, slightly mysterious spirit-world mood. Chinese architecture, mountains, mist, pines, rivers.
- Palette: deep teal and ink green, slate blue, jade green, warm parchment and pale stone, with small warm accents (lantern orange, sunset rose).

**Do not:**
- No photorealism, 3D renders, cinematic lighting, glossy CGI, realistic textures, or heavy film grain.
- No chibi, no pixel art, no anime moe style.
- **No text, letters, labels, signatures, watermarks, frames, UI elements or logos anywhere.** Shop signs and banners must be blank or carry abstract patterns only.
- No modern objects.

**How the game shows your art** (it affects composition):
- The game UI is dark teal (around `#11272d`) with gold (`#d5b777`) and pale ink-white (`#e3e8dc`) text. Art should sit comfortably next to it: not neon, not pure white, not pitch black.
- Banners (groups B and C) are scaled to fill a wide strip of about **900×190 pixels** and **cropped from the centre**. Keep the important content in the **central 70% of the width and the middle 80% of the height**.
- Portraits (group D) display at about **120×150 pixels**. The face and silhouette must read at that small size.

---

## 3. Technical rules

- **Format:** PNG. RGB is fine; RGBA only where noted.
- **Sizes:** exactly as listed for the map (it must be 2560×1600). Banners and portraits may be larger but must keep the listed aspect ratio.
- **File names and folders:** exactly as listed, lowercase, inside the repository. The game finds files by these names.
- **One image per file.** No sprite sheets in this batch.
- If you work inside the repository: only add image files. **Do not modify code or data files.** Then add a short record of what you made (file, size, prompt used) to `docs/ART_ASSETS.md`.

---

## 4. Group A: Region map (1 image)

**File:** `assets/art/map/region_qingyun.png`
**Size:** **2560×1600 exactly** (aspect 1.6). The game places markers by percentage of this size, so the size cannot change.

**What it is.** A painted map of one mountain region, seen from a high oblique bird's-eye angle, like a Chinese landscape map. It is the background of the travel screen. **The game draws location markers, names, roads, travel days and danger marks on top of it.** So the painting must contain **only terrain and buildings: no roads, no paths, no text, no compass, no legend, no frame**.

**Place these features at these positions** (x% from the left edge, y% from the top):

| Place | Position (x, y) | What to paint there |
|---|---|---|
| Qingyun Mountain 青云山 (sword sect) | 24%, 24% | Tall misty main peak with elegant sect halls and pavilions halfway up, clouds around the waist |
| Qingshi Town 青石镇 (mortal town) | 40%, 42% | Small town of grey-tiled roofs at the foot of the mountains, a little smoke |
| Bailu Ferry 白鹭渡 | 60%, 50% | River crossing: shallows, reeds, a small wooden pier, white egrets |
| Yunxi Market 云溪坊市 | 80%, 62% | Larger riverside market town, dense roofs, a few plain banners |
| Songfeng Ridge 松风岭 | 20%, 60% | Rolling ridge covered in old pines |
| Luoxia Valley 落霞谷 | 44%, 80% | Deep valley lit by rose-gold sunset light, faint glow of a spring at its floor |
| Ancient Cave 古修洞府 | 24%, 88% | A mossy stone door in a cliff, **subtle and easy to overlook** (it is a secret place the player discovers later) |

**River:** the Yunxi river enters from the **north edge**, flows **between the ferry (60%, 50%) and the market (80%, 62%)**, and leaves toward the **south-east corner**.

**Leave space for markers:** around each position above, keep a calm, low-contrast area about **80 pixels in radius**. A marker and a name label will be drawn there.

**Overall tone:** slightly dark and muted, so gold markers drawn on top stand out.

**Prompt:**
```text
Painted regional map background for a 2D Chinese cultivation RPG, in the illustrated visual family of the game 觅长生. Exactly 2560x1600. High oblique bird's-eye view of one mountain region, like a hand-painted Chinese landscape map.
Place terrain at these positions (percent of width, percent of height): misty main peak with sword-sect halls and pavilions halfway up, clouds around its waist (24,24); small mortal town of grey-tiled roofs at the foot of the mountains (40,42); river ferry crossing with shallows, reeds, a small wooden pier and white egrets (60,50); larger riverside market town with dense roofs and a few plain banners (80,62); rolling ridge covered in old pine forest (20,60); deep valley lit by rose-gold sunset light with a faint glowing spring at its floor (44,80); a subtle, easily overlooked mossy stone cave door in a cliff (24,88).
A river enters from the north edge, flows between (60,50) and (80,62), and leaves toward the south-east corner.
Keep a calm low-contrast area about 80px in radius around each listed position for game markers.
NO roads, NO paths, NO text, NO labels, NO compass, NO legend, NO frame, NO characters.
Style: unmistakably two-dimensional hand-painted Chinese game art, clear ink outlines, flat color areas with restrained washes; muted deep teal, slate blue, jade green, warm parchment highlights; overall slightly dark so gold UI markers stand out. Not a photo, not 3D, not satellite imagery.
```

---

## 5. Group B: Location banners (7 images)

**Folder:** `assets/art/locations/`
**Size:** **2400×600** (4:1). Horizontal panorama, main subject in the central third, quieter edges, no dominant characters (tiny distant figures are fine).

| File | Place | Content |
|---|---|---|
| `sect.png` | Qingyun Mountain (sword sect, outer court) | Sword-sect halls on a mountain above a sea of clouds, long stone stairs, the main peak in the distance |
| `town.png` | Qingshi Town (mortal town) | Small-town street at the mountain foot: inn with a blank signboard, a teahouse, cooking smoke, willow trees |
| `ferry.png` | Bailu Ferry | Wide calm river, a bamboo-pole ferry boat, egrets on the shallows, far mountains across the water |
| `market.png` | Yunxi Market | Lantern-lit market street at dusk, a herb shop, small stalls, blurred passers-by |
| `ridge.png` | Songfeng Ridge | Rolling ridge lines, ancient pine forest, wind through the pines, a narrow mountain path |
| `wild.png` | Luoxia Valley (dangerous) | Deep valley under sunset sky, slopes of glowing spirit herbs, mist at the bottom, a hint of danger |
| `ruin.png` | Ancient Cave | Cliff face covered in vines around an old stone door, faint light leaking from the gap |

**Prompt template** (replace `<SUBJECT>` with the Content column):
```text
Wide 4:1 location banner for a 2D Chinese cultivation RPG, in the illustrated visual family of the game 觅长生. 2400x600.
Subject: <SUBJECT>.
Composition: horizontal panorama, main subject in the central third, quieter edges so the image can be cropped; no dominant characters, only tiny distant figures allowed.
Style: unmistakably two-dimensional hand-painted Chinese game background, restrained ink outlines, flat color areas, simple washes; muted jade, slate blue, warm stone and parchment tones; calm spirit-world atmosphere. Not photorealistic, not 3D, no cinematic lighting. No text, letters, labels, UI, frame or watermark; signboards blank.
```

---

## 6. Group C: Scene banners (13 images)

**Folder:** `assets/art/scenes/`
**Size:** **2400×600** (4:1). Use the same prompt template as Group B. These are closer views of a sub-area inside a place. If one is missing, the game temporarily shows that place's location banner.

| File | Place: scene | Content |
|---|---|---|
| `sect_chamber.png` | Qingyun Mountain: meditation chamber | Quiet chamber with a meditation cushion, incense burner, open window onto a sea of clouds |
| `sect_arena.png` | Qingyun Mountain: training plaza | Open stone plaza for sparring, weapon racks, sect halls behind |
| `sect_hall.png` | Qingyun Mountain: technique hall | Hall of shelves holding jade slips, a long table, hanging silk curtains |
| `town_inn.png` | Qingshi Town: inn | Wooden inn hall, staircase, steam rising from medicinal dishes |
| `town_teahouse.png` | Qingshi Town: teahouse | Storyteller's small stage, tea tables, a rain curtain outside the window |
| `ferry_dock.png` | Bailu Ferry: dock | Wooden pier posts, the ferry boat moored, an old boatman seen from behind in a straw hat |
| `market_street.png` | Yunxi Market: main street | Pill shop, artifact shop, street stalls, hanging lanterns |
| `market_pharmacy.png` | Yunxi Market: herb shop | Wall of small medicine drawers, a counter, bundles of dried spirit herbs |
| `ridge_pines.png` | Songfeng Ridge: pine forest | Ancient pines, dappled light, a few spirit herbs on the forest floor |
| `wild_entrance.png` | Luoxia Valley: valley mouth | Jagged rocks, claw marks, an uneasy narrow entrance |
| `wild_slope.png` | Luoxia Valley: herb slope | Sunny slope covered in faintly glowing spirit herbs |
| `wild_spring.png` | Luoxia Valley: deep spring | Glowing spring at the valley floor, mist, a few large red scales on the rocks (a serpent's lair) |
| `ruin_stone_room.png` | Ancient Cave: stone room | Stone bed, worn cushion, scattered jade slips and clay jars, dust in a beam of light |

---

## 7. Group D: Character portraits (7 images)

**Folder:** `assets/art/portraits/`
**Size:** **512×640** (4:5). Half-body bust, three-quarter view **facing right**, plain muted background or transparent (RGBA). Displayed small (about 120×150), so keep a clear silhouette and a readable face in the upper third. All characters are adults, modestly dressed, in the same style as `assets/art/cultivator_atlas_v2.png`.

| File | Character | Description |
|---|---|---|
| `shen_mo.png` | Shen Mo 沈墨, herb-shop owner, 54 | Shrewd but kindly, neat grey-blue scholar's robe, holding an abacus, small goatee |
| `boatman.png` | Old ferryman 老艄公, 67 | Talkative mortal, conical straw hat, straw rain cape, weathered tanned face, warm smile |
| `storyteller.png` | He Sangeng 何三更, storyteller, 61 | Theatrical, long plain robe, holding a folding fan and a small wooden gavel, raised eyebrow |
| `peddler.png` | Qian the peddler 钱货郎, 38 | Smooth-talking travelling herb seller, simple traveller's clothes, carrying-pole baskets with herbs |
| `wounded.png` | Liu Hanzhou 柳寒舟, wandering cultivator, 27 | Quiet young swordsman, pale, blood on his robe collar, holding a plain sword, tired but proud |
| `rogue.png` | Masked rogue cultivator 蒙面修士, 35 | Hostile, cloth mask over the lower face, dark robe with red trim, small flame in one palm, cold eyes |
| `squatter.png` | Shi Han 石寒, cave squatter, 49 | Suspicious, rough brown Taoist robe, sitting cross-legged, stony expression, earth-toned |

**Prompt template:**
```text
Character bust portrait for a 2D Chinese cultivation RPG, in the illustrated visual family of the game 觅长生 and matching hand-drawn cel-shaded character sprites. 512x640.
Subject: <DESCRIPTION>. Adult, modest clothing. Half-body, three-quarter view facing right, expression matching the personality, clear silhouette readable at small size.
Style: NON-REALISTIC hand-drawn 2D game portrait, clear dark ink outlines, flat color areas, restrained two-tone cel shading, simplified clothing folds, slightly stylized face. Not photorealistic, not 3D, not chibi, not anime moe. Plain muted background or transparent. No text, frame or watermark.
```

---

## 8. Final checklist

Before delivering, check every image:

- [ ] File name and folder exactly as listed (lowercase)
- [ ] Map is exactly 2560×1600; banners are 4:1; portraits are 4:5
- [ ] No text, letters, labels, signatures or watermarks anywhere
- [ ] Map: no roads or paths; features sit at the listed positions; quiet area around each one; cave door subtle
- [ ] Banners: key content inside the central 70% of the width
- [ ] Portraits: face readable when shrunk to 120×150
- [ ] Style consistent with `assets/art/cultivator_atlas_v2.png` and `assets/art/bamboo_arena_v1.png`: 2D, outlined, flat colors, not realistic
- [ ] (Working in the repository) only image files added, plus a record in `docs/ART_ASSETS.md`

**Testing (in the repository):** run `check.cmd`. It imports new images and runs the automated tests. To see the art in the game, run `play.cmd`.
