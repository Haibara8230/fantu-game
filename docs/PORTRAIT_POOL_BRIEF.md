# Portrait Pool Brief: generated NPCs (local, personal use)

> 给人类读者：这份文档交给图像生成 AI，用来批量生成「生成人物」的立绘图池。每个世界会随机生成 20 多名修士，游戏按性别、年龄段和身份从图池里给每人分配一张，同一世界内不重复、同一个人每次看都是同一张。
> 这批图放在 `assets/local/portraits/pool/`，会随仓库一起提交。注意仓库是公开的。
> 想更像《觅长生》，可以同时把几张觅长生的人物截图交给图像 AI 作为**画风参考**。

This brief is self-contained. Read it fully before generating anything.

---

## 1. What you are making

A pool of **half-body portraits for ordinary cultivators** in a 2D Chinese cultivation (xianxia) RPG. The world holds about 1200 generated people over its centuries, around 180 of them in the current region at any time (outer disciples, wandering cultivators, market cultivators, herb gatherers, travelling cultivators) and deals each one a portrait from this pool. A person always keeps the same face; with more people than images, faces repeat across people. The bigger and more varied the pool, the less often faces repeat between playthroughs.

**Minimum: 72 images** (12 in each of the 6 gender/age groups). **Better: 180 or more** (30 per group): with about 180 people in the region, faces will repeat less. Outer disciples are the largest group (dozens at the sect), so give `disciple_` images the biggest share. You can deliver in batches; every new file is picked up automatically.

---

## 2. Style (applies to every image)

**Target look: the character portraits of the game 觅长生 (Mi Chang Sheng).** If you were given 觅长生 screenshots, use them as style reference for linework, colouring, proportions and mood. Do not copy any specific character; every portrait is a new, ordinary person of this world.

Also match the portraits already in this repository, especially `assets/art/portraits/shen_mo.png`:
- Two-dimensional illustrated Chinese fantasy game portrait.
- Clean dark ink outlines, flat colour areas, one or two soft shadow tones, restrained highlights.
- Realistic adult proportions; slightly stylized, expressive faces; natural, believable people, not idols.
- Muted, earthy palette: slate blue, ink green, ivory, grey, brown, with small accents (jade, red cord, gold trim).
- Plain muted background, a single flat or very softly graded colour, so the figure reads clearly.

**Avoid:** photorealism, 3D render, glossy anime/moe style, chibi, heavy glow or particle effects, fantasy armour, modern objects, text, signatures, watermarks, frames.

---

## 3. Technical rules

- **Size:** 512×640 (4:5), PNG.
- **Framing:** half body, head in the upper third, three-quarter view **facing right**, both shoulders inside the frame. The game shows it at about 120×150, so the face and silhouette must read at that size.
- **One person per image.** All adults (18 or older), modestly dressed.

---

## 4. Groups, folders and file names

Put each image in the folder for its **gender and age band**:

| Folder | Gender | Age band |
|---|---|---|
| `pool/male_young/` | male | 18–34 |
| `pool/male_middle/` | male | 35–54 |
| `pool/male_old/` | male | 55 and older |
| `pool/female_young/` | female | 18–34 |
| `pool/female_middle/` | female | 35–54 |
| `pool/female_old/` | female | 55 and older |

All folders are under `assets/local/portraits/`.

**File name:** `<role>_<gender>_<age>_<number>.png`, for example `disciple_female_young_03.png`. **The name must start with the role**, which tells the game who should wear it. Roles are listed in section 5.

**Suggested mix per group of 12** (adjust freely):

| Group | disciple | wanderer | trader | gatherer | visitor |
|---|---|---|---|---|---|
| young (male / female) | 5 | 3 | 1 | 2 | 1 |
| middle (male / female) | 2 | 4 | 3 | 2 | 1 |
| old (male / female) | 1 | 4 | 3 | 3 | 1 |

---

## 5. Roles and costumes

| Role (file prefix) | Who they are | Costume and props |
|---|---|---|
| `disciple` | Outer disciple of the Qingyun Sword Sect (青云剑宗外门弟子) | Matching sect uniform: pale ivory robe with slate-blue collar and cuffs, faint cloud pattern on the hem, blue sash, hair tied up neatly with a plain cord or wooden pin, a simple straight sword on the back or at the hip |
| `wanderer` | Wandering cultivator (散修) | Varied, worn travelling robes in grey, brown or ink green; cloak, bamboo hat or wrapped hair; a gourd, a staff or a plain sword; a little weathered |
| `trader` | Market cultivator (坊市修士) | Neater, slightly richer robes (deep green, plum, brown with modest trim); pouches, jade token, small ledger, abacus or a fan |
| `gatherer` | Herb gatherer (采药人) | Practical short robe and trousers, sleeves tied back, rope belt; herb basket, small hoe or bundles of herbs; outdoorsy, sunburnt |
| `visitor` | Travelling cultivator from the Chixiao sect (赤霄门) | Robe in muted crimson and charcoal with small flame-shaped embroidery, red hair cord; a confident bearing; optionally a faint ember in one palm |

---

## 6. Age bands

- **young (18–34):** smooth faces, dark hair, energetic or earnest expressions.
- **middle (35–54):** a few lines, more composed; some grey at the temples; beards possible for men.
- **old (55+):** grey or white hair, wrinkles, thinner or heavier builds, calm, shrewd or kindly expressions.

---

## 7. Variety (important)

Within each group, no two images should look like the same person. Vary:
- face shape, eyes, brows, nose and mouth; build (slim, sturdy, heavy);
- hairstyles (topknot, half-up, braids, short cropped, hair under a hat or cloth), hair ornaments;
- expression (smiling, stern, shy, proud, tired, curious, suspicious);
- palette within the role's range, and props;
- accessories (scar, eyepatch, beads, earrings, freckles, beauty mark, bandage) used sparingly.

Keep **the same art style** across all images, so the pool looks like one game.

---

## 8. Prompt template

Fill the angle brackets for each image:
```text
Half-body portrait of an ordinary cultivator for a 2D Chinese xianxia RPG, in the illustrated character style of the game 觅长生 (Mi Chang Sheng). 512x640.
Subject: a <gender>, about <age> years old, <role description from section 5>, <distinctive face and hair details>, <expression>.
Three-quarter view facing right, head in the upper third, readable at small size. Adult, modestly dressed.
Style: hand-drawn 2D game portrait, clean dark ink outlines, flat colours, one or two soft shadow tones, restrained highlights, muted earthy palette; plain muted single-colour background.
Not photorealistic, not 3D, not glossy anime, not chibi. No text, frame, signature or watermark.
```

---

## 9. Optional: replacing a specific person

To give a particular character your own image, put it directly in `assets/local/portraits/` named after their id, for example `shen_mo.png` (沈墨), `boatman.png`, `storyteller.png`, `peddler.png`, `wounded.png`, `rogue.png`, `squatter.png`. A local image always wins over the one in the repository.

---

## 10. Checklist

- [ ] 512×640 PNG, half body, facing right, plain background
- [ ] In the right `pool/<gender>_<age>/` folder, file name starting with the role
- [ ] At least 12 per group (72 in total), 20 per group if possible
- [ ] Clearly different people within each group; one consistent art style overall
- [ ] No text, watermark or frame

To see them in the game, run `play.cmd`, stop somewhere with people around, and open a profile.


## 11. 高颜值与气质补充（2026-10-13）

图池保留普通外貌，也应包含容貌出众与神仙气质的年轻修士。可使用英气俊朗、温润秀雅、清冷出尘等不同面孔与神态，避免只靠衣服配色区分人物。继续沿用二维手绘、清晰轮廓与克制阴影，保持成人比例，避免拟真人像。

首批新增男女各 3 张（年轻组各 33 张），清单与完整提示词见 `PORTRAIT_SUPPLEMENT_20261013.json`。文件名仍以身份开头，在序号前加入 `handsome` / `beautiful` / `ethereal` 便于检索。清单的 `appearance` 和 `bearing` 是未来颜值分配的素材标签，当前图池选择逻辑尚未使用这些字段。


第二批继续补充男女各 5 张，五种身份各一对，年轻组各 38 张，总图池 196 张。通过脸型、肤色、发髻、束发、辫发与身份衣着区分高颜值角色。完整提示词与分类清单见 `PORTRAIT_SUPPLEMENT_20261013_02.json`。


第三批新增 50 张（男女各 25 张，五种身份每种各男女 5 张），年轻组各 63 张，总图池 246 张。清单 `PORTRAIT_SUPPLEMENT_20261013_03.json` 包含完整提示词、脸型、发型、建议外观年龄、气质和高颜值标签；这些字段仍是美术元数据，后续颜值属性需显式接入分配。文件名采用 `<role>_<gender>_young_high_b03_<number>.png`，继续兼容现有身份前缀与图池目录。
