# 美术资源与生成记录

使用内置 imagegen 工具制作原创资源，未使用 CLI/API fallback。视觉参考是《觅长生》的二维手绘方向；实际采用清楚线稿、平涂与有限阴影，而非写实人物。官方参考：[Steam 页面](https://store.steampowered.com/app/1189490/)。

所有正在使用的图像已复制到项目。原始生成文件保留在 Codex generated_images；引擎只引用以下本地文件。角色、场景并未使用原游戏素材。

## cultivator_atlas_v2.png

保存路径：D:/fqh/flash/assets/art/cultivator_atlas_v2.png

```text
Use case: style-transfer
Edit target: the attached male cultivator six-pose atlas. Keep the 3-column 2-row grid, pose order, full-body framing, costume identity and RIGHT-facing direction, and genuine transparent background.
REDRAW all six figures in a visibly NON-REALISTIC simple hand-drawn Chinese 2D cultivation RPG illustration style, in the visual family of Mi Chang Sheng / 觅长生's in-game sprites.
Very clear thin dark outlines, flat opaque ivory and teal color areas, one or two simple cel-shaded shadows per area, lightly stylized expressive face, slightly larger head (about 6.5 heads tall), simple economical folds. Clean readable 2D game sprite at 220 pixels tall. Moderately stylized illustrated anatomy. Clothing is simple pale ivory outer robe, muted teal under-robe, jade belt, gold small trim. Remove intricate embroidery, brocade, textile weave, glossy satin, realistic skin and soft volumetric gradients. Hair should be graphic grouped locks, not many realistic strands.
This is not a high-end realistic concept painting, not a 3D render, not cinematic, not photorealistic, not semi-realistic, not chibi. It should visibly look like a drawn Chinese fantasy game character.
Six poses: idle / anticipation / sword thrust / spell gesture / recoil / guard. Same character size in all cells, keep each sprite entirely inside its cell with transparent spacing. Grid is 3x2 on a 1536x1024 canvas. No gridlines, labels, effects, floor, background or shadows. Preserve actual transparent alpha.
```

## rival_atlas_v2.png

保存路径：D:/fqh/flash/assets/art/rival_atlas_v2.png

```text
Use case: stylized-concept
Reference image role: style reference only, the male cultivator atlas. Match its clearly drawn linework and flat ivory/jade shading; create a DISTINCT ORIGINAL female rival.
Asset: transparent sprite animation atlas for a Chinese cultivation 2D RPG in the visual family of 觅长生's illustrated in-game characters. NON-REALISTIC hand-drawn sprite, clear ink outlines, flat color blocks, restrained two-tone cel shading, simplified robe folds, expressive stylized face, 6.5-head proportions. No photorealism, realistic textures, brocade, satin, cinematic lighting, or 3D.
Female adult cultivator in modest long layered indigo and dusty lavender robe, purple sash, small silver hairpin, long dark hair tied back, simple straight jian sword. Graceful but practical clothing, no bare thighs or cleavage. Excellent cohesive character design.
STRICT 3x2 grid on 1536x1024 transparent canvas. SIX equal 512x512 cells; no labels or gridlines. Entire body and sword inside each cell with safe margins; same height and baseline feet at 92%; facing LEFT in every pose. One figure per cell.
Top: idle sword lowered / anticipation drawing sword back / thrust sword LEFT.
Bottom: spellcasting fingers / recoiling RIGHT from a hit / defensive guard.
Keep same identity, face and costume in all poses, simple crisp silhouettes that work at 220px tall. No scene, floor, shadows, particles or background; actual transparent alpha.
```

## bamboo_arena_v1.png

保存路径：D:/fqh/flash/assets/art/bamboo_arena_v1.png

```text
Use case: stylized-concept
Asset type: wide landscape BACKGROUND for a 2D Chinese cultivation turn-based game, original environment in the illustrated visual family of 觅长生.
Composition: 1792x768 wide panorama, side-view duel arena. Lower half is a broad worn pale stone terrace and mossy packed earth, clear unobstructed ground across the whole width, appropriate for two full-body drawn characters standing at 28% and 74% horizontal positions. Camera level slightly above terrace floor, no extreme perspective. Backdrop is a lush Chinese bamboo valley, misty layered jade mountains, an elegant small distant mountain pavilion at upper center-left, a waterfall at far right. Keep the middle spacious and quiet, frame only far outer edges with bamboo trunks and leaves. The ground line should be at 80% height, so tall characters fit against scenery.
Style: unmistakable TWO-DIMENSIONAL hand-painted Chinese game background, muted jade, warm pale stone, dusty blue mountains, restrained ink outlines, simplified painterly shapes. Attractive composed illustration rather than a photo or realistic 3D environment. Soft bright daylight, calm spirit-world atmosphere, no dark gloomy teal filter, no cinematic realism. No characters, monsters, weapons, magic effects, text, UI, labels, frames or watermark. Suitable to layer transparent cel-shaded character sprites and particle effects on top.
```

## beasts_atlas_v1.png

保存路径：D:/fqh/flash/assets/art/beasts_atlas_v1.png

```text
Use case: stylized-concept
Asset type: ORIGINAL transparent 2D monster sprite atlas for a Chinese cultivation RPG, matching simple drawn 觅长生-style fantasy game characters.
Canvas 1536x1024, STRICT two columns and two rows, four equal 768x512 cells. Each cell contains ONE complete creature, facing LEFT, entirely inside its own cell with at least 35px margins; no labels or lines. Feet or coil base at 92% of cell height.
Top-left: grey blue mountain spirit WOLF idle, alert stance, four paws grounded, thick grouped fur, small jade glowing eyes, subtle cyan mane accents. Top-right: THE SAME WOLF lunging LEFT and baring fangs, all paws and tail inside cell.
Bottom-left: large crimson scaled horned SERPENT in upright coiled idle stance, one complete clearly connected body, amber eyes, pale belly scales, simple dark red crest, not a western dragon. Bottom-right: SAME SERPENT leaning its head and neck forward LEFT to strike, coils still visible, all anatomy inside the cell.
Art is unmistakably 2D DRAWN: crisp dark contours, flat color areas, simple cel shading, expressive coherent monster silhouettes; slight ink wash touches. Sophisticated game art, not cute chibi, not pixel art, no photographic detail, no realistic fur strands, no glossy CGI, no background, no floor, no shadow, no effects, text, frames or checkerboard. True transparent alpha.
```

## 当前资源清单

- cultivator_atlas_v2.png：1536×1024，RGBA；3×2 人物六姿态图集，待机、蓄势、御剑、施法、受击、守御。
- rival_atlas_v2.png：1536×1024，RGBA；同门人物六姿态。原图向右，战斗中按配置翻转朝向。
- beasts_atlas_v1.png：1536×1024，RGBA；2×2 图集，妖狼与妖蟒各有待机、攻击姿态。
- bamboo_arena_v1.png：1916×821，RGB；竹林、山谷、远山与石坪战斗背景。
- cultivator_atlas_v1.png：早期拟真探索版，保留用于回溯，游戏不引用。

人物图集通过 Sprite2D 的 hframes/vframes 读取；妖兽通过配置中的精确区域取帧，排除相邻行的图像，并校准定位。没有用 Python 抠图或编辑角色。透明通道已检查。
`data/art.json` 定义图集、姿态帧、朝向与相对高度；替换角色不应修改战斗规则。

## 动画与反馈

- 人物：六张关键姿态，加蓄势、前冲、后仰、回位与轻微呼吸补间。
- 妖兽：两张姿态，加扑击、回位和受击补间。
- 技能：剑气、火弹、治疗叶片与守御屏障使用 Godot 绘制，方便调节颜色和时长。
- 命中：约 65ms 的演出停顿、闪白、位移、跳字、短促震动；不改变全局时间流速。
- 角色血条在各次命中时变化。规则先完成一整个有效回合并自动保存，随后播放事件。
- 演出期间锁定技能、旅行、存读档与重开操作，防止重复输入和对象销毁。
- 截图来自真实 Godot 图形渲染器，输出到 builds/previews。

当前是美术与演出的首轮实现。它是姿态图集与补间动画，尚不是逐帧连续作画或骨骼绑定；后续可以保持事件接口，替换成更完整的骨骼/逐帧角色。音效和三个地点各自的正式美术仍待制作。

## M4 待制作：斗法背景、斗法人物图集与事件插图

规格与提示词见 `docs/ART_BRIEF_M4.md`（可整份交给图像生成 AI）：按地点的斗法背景 8 张、劫修与生成修士的六姿态图集 14 张、事件关键插图 7 张。斗法背景与人物图集已接入，放到指定路径即生效，缺图时回退到 `bamboo_arena_v1.png` 与 `rival_atlas_v2.png`；事件插图要等演出接入，见 `docs/BACKLOG.md`。

## M2 待制作：区域地图、地点与场景（规格）

> 交给图像生成 AI 时，直接使用 `docs/ART_BRIEF.md`：那是一份自成一体的完整说明（含人物立绘）。本节保留同样的规格，供开发参考。

M2 已把地图、地点横幅和二级场景接好。下列图片放到指定路径后，运行 `play.cmd` 或 `check.cmd`（都会先导入资源）就会直接替换代码绘制的占位图，不需要改代码。缺哪张就继续用占位图。

**通用要求**
- 风格与现有人物、竹林背景一致：《觅长生》方向的二维手绘中国修仙游戏美术，清晰墨线、平涂色块、克制的两层阴影、简化的笔触；不要写实照片、3D 渲染、电影光效。
- 色调偏沉稳的青黛、石青、暖米色。界面底色是深青（#11272d 一带），金色标记要能看清。
- 画面里不要文字、标签、边框、水印和 UI；地点横幅与场景图不要以人物为主体（可有远处很小的人影）。
- PNG，RGB 即可；地图需要精确尺寸，横幅可以更大但比例须为 4:1（界面按“铺满并居中裁切”显示）。

**优先顺序**：先出地图与 7 张地点横幅，再出 15 张场景图。

### 1. 区域地图 `assets/art/map/region_qingyun.png`

2560×1600（比例 1.6，必须一致，节点坐标按此比例换算）。节点、路线、地名和天数由代码叠加绘制，所以图上**不要画道路和地名**，只画地形。每个节点中心周围约 80 像素半径内保持画面平静（不要放高对比细节），名字会写在节点下方。

| 地点 | 位置（横, 纵） | 画面 |
|---|---|---|
| 青云山 | 24%, 24% | 云雾环绕的主峰，半山腰有剑宗楼阁 |
| 青石镇 | 40%, 42% | 山脚下的小镇，青瓦屋顶聚在一起 |
| 白鹭渡 | 60%, 50% | 河边渡口，浅滩、芦苇与小码头 |
| 云溪坊市 | 86%, 62% | 河畔较大的集镇，屋舍密集，有几面幡旗 |
| 松风岭 | 20%, 60% | 松林覆盖的山岭 |
| 落霞谷 | 44%, 80% | 晚霞映照的山谷，谷底一点泉光 |
| 古修洞府 | 24%, 88% | 落霞谷西南的崖壁石门，要**低调**：开局时它不显示在地图上，被发现后才出现标记 |

云溪从北面流下，经过白鹭渡与云溪坊市之间，向东南流出。

```text
Use case: stylized-concept
Asset type: top-down oblique REGIONAL MAP background for a 2D Chinese cultivation RPG, original, in the illustrated visual family of 觅长生. 2560x1600 exact.
Content: a painted landscape map of one mountain region seen from a high oblique angle. Place terrain features at these positions (percent of width, height): misty main peak with sect pavilions halfway up at (24,24); small mortal town of grey-tiled roofs at the foot of the mountains (40,42); river ferry crossing with shallows, reeds and a tiny pier (60,50); larger riverside market town with dense roofs and a few banners (86,62); pine-covered ridge (20,60); valley glowing with sunset light and a faint spring at its floor (44,80); a subtle mossy stone cave door in a cliff (24,88), understated. A river enters from the north edge, passes between (60,50) and (86,62) and leaves to the south-east.
Keep a calm low-contrast area of about 80px radius around each listed position for game markers. NO roads, NO paths, NO text, NO labels, NO compass, NO frame, NO legend, NO characters.
Style: unmistakably TWO-DIMENSIONAL hand-painted Chinese game art, ink outlines, flat color areas with restrained washes, muted deep teal, slate blue, jade green, warm parchment highlights; overall slightly dark so gold UI markers stand out. Not a photo, not 3D, not satellite imagery.
```

### 2. 地点横幅 `assets/art/locations/<地点ID>.png`

建议 2400×600（4:1），水平全景，主体在中部，左右可以渐隐。

| 文件 | 画面 |
|---|---|
| `sect.png` | 青云山外门：云海中的剑宗殿阁、石阶、远处主峰 |
| `town.png` | 青石镇：凡人小镇街景，客栈招牌（无字）、茶馆、炊烟 |
| `ferry.png` | 白鹭渡：宽阔河面、竹篙渡船、浅滩白鹭、对岸远山 |
| `market.png` | 云溪坊市：灯笼长街、药铺与地摊、往来的模糊人影 |
| `ridge.png` | 松风岭：起伏山岭、古松林、松涛与山径 |
| `wild.png` | 落霞谷：晚霞下的幽深山谷、灵草坡、谷底雾气 |
| `ruin.png` | 古修洞府：藤蔓覆盖的崖壁石门，门缝透出微光 |

```text
Use case: stylized-concept
Asset type: wide 4:1 LOCATION BANNER for a 2D Chinese cultivation RPG, original, 2400x600, illustrated visual family of 觅长生.
Subject: <填入上表对应画面，英文描述>.
Composition: horizontal panorama, main subject in the central third, edges quieter so the banner can be cropped; no dominant characters (only tiny distant figures allowed).
Style: unmistakably TWO-DIMENSIONAL hand-painted Chinese game background, restrained ink outlines, flat color areas, simple washes, muted jade, slate, warm stone and parchment tones; calm spirit-world atmosphere. Not photorealistic, not 3D, no cinematic lighting. No text, labels, UI, frame or watermark.
```

### 3. 二级场景 `assets/art/scenes/<地点ID>_<场景ID>.png`

同样 2400×600（4:1），用上面的横幅提示词，把 Subject 换成下表内容。场景图缺失时会先用所在地点的横幅。

| 文件 | 画面 |
|---|---|
| `sect_chamber.png` | 静室：蒲团、香炉、窗外云海 |
| `sect_arena.png` | 演武坪：青石平台、兵器架、远处殿阁 |
| `sect_hall.png` | 传功堂：书架上排列的玉简、长案、垂幔 |
| `town_inn.png` | 青石客栈：木质大堂、楼梯、药膳热气 |
| `town_teahouse.png` | 听雨茶馆：说书台、茶桌、雨帘窗 |
| `ferry_dock.png` | 渡口：码头木桩、渡船、艄公的斗笠（背影） |
| `market_street.png` | 长街：丹铺、器铺、地摊与灯笼 |
| `market_pharmacy.png` | 云溪药铺：药柜抽屉墙、柜台、晒干的灵草 |
| `ridge_pines.png` | 松林：古松、林下灵草、斑驳光影 |
| `wild_entrance.png` | 谷口：乱石嶙峋、狼爪痕迹 |
| `wild_slope.png` | 灵草坡：向阳缓坡、成片发光的灵草 |
| `wild_spring.png` | 深谷灵泉：泉眼、红色鳞片痕迹、水汽 |
| `ruin_stone_room.png` | 洞府石室：石床、残破蒲团、散落的玉简与陶罐 |

### 4. 人物立绘 `assets/art/portraits/<人物ID>.png`

人物资料卡左侧的立绘。缺失时显示金色描边的首字印章占位。建议 512×640（4:5），半身像，透明或素色背景，人物面向画面右侧。

| 文件 | 人物 |
|---|---|
| `shen_mo.png` | 沈墨，54 岁药铺掌柜，精明和气，青灰长衫，手持算盘 |
| `boatman.png` | 老艄公，67 岁，斗笠蓑衣，黝黑健谈 |
| `storyteller.png` | 何三更，61 岁说书人，长衫，手持醒木与折扇 |
| `peddler.png` | 钱货郎，38 岁行脚药贩，圆滑，背着药担 |
| `wounded.png` | 柳寒舟，27 岁散修，沉默，衣襟染血，佩剑 |
| `rogue.png` | 蒙面修士，35 岁赤霄门弃徒，蒙面，掌心火光，敌意 |
| `squatter.png` | 石寒，49 岁玄岳宗弃徒，多疑，粗布道袍，盘坐 |

```text
Use case: stylized-concept
Asset type: character BUST PORTRAIT for a 2D Chinese cultivation RPG, original, 512x640, in the illustrated visual family of 觅长生 and matching the existing cultivator sprites.
Subject: <填入上表对应人物，英文描述>. Half-body, three-quarter view facing right, readable expression that matches the personality.
Style: NON-REALISTIC hand-drawn 2D game portrait, clear dark ink outlines, flat color areas, restrained two-tone cel shading, simplified clothing folds, slightly stylized face. Not photorealistic, not 3D, not chibi. Plain muted background or transparent alpha. No text, frame or watermark.
```

### 斗法背景与人物图集
按地点区分的斗法背景、劫修与生成修士的斗法人物图集，规格见 `docs/ART_BRIEF_M4.md`，已接入代码；图片到位前沿用 `bamboo_arena_v1.png` 与同门图集。


## 2026-10-09：青云山区域地图首张样图

- 文件：`assets/art/map/region_qingyun_preview_v1.png`
- 工具：内置 imagegen，未使用 CLI/API fallback。
- 实际尺寸：1586×992，PNG；未缩放、裁切或修改原始生成图。
- 用途：先供用户确认视觉效果，未接入正式地图路径。正式地图要求精确 2560×1600，本样图尚未满足该尺寸。
- 目视检查：二维手绘青黛山水、清晰墨线、局部暖色灵泉；未见文字、水印、UI 或连接道路。地标位置与标记留白仍需在正式版进一步校准，洞府表现也需更低调。
- 本次仅生成这一张样图；没有启动可见游戏或编辑器。
- 正式地图完成后，样图已从仓库删除（可在提交历史中找回）。

提示词：

```text
Use case: stylized-concept.
Create ONE original production art asset: the Qingyun Mountains regional map background for 凡途, a 2D Chinese cultivation RPG. PNG landscape image, EXACTLY 2560x1600 pixels (8:5 aspect ratio).
Style: unmistakably TWO-DIMENSIONAL hand-drawn Chinese fantasy game art, in the illustrated visual family of 觅长生. Match the project art direction: clear dark ink outlines, flat muted jade and slate-blue color areas, economical simplified painterly shapes, restrained washes and one or two shadow tones, warm pale stone highlights. Calm slightly mysterious atmosphere. Overall muted and moderately dark for gold UI markers, but readable terrain. No photographic textures, no realistic rendering, no 3D, no CGI, no cinematic lighting, no glossy detail, no heavy film grain, no chibi or pixel art.
Composition: a coherent painted landscape MAP of a mountain region, high oblique bird''s-eye view, looking down across the whole terrain rather than a horizon landscape. Terrain fills the entire rectangular image edge to edge. No large sky area.
Place seven features carefully at these normalized coordinates (x from left, y from top):
1. (24%,24%): tall misty mountain main peak, elegant Chinese sword-sect halls and pavilions halfway up, clouds encircling the mountain waist.
2. (40%,42%): small mortal town at the mountain foot, clustered grey-tiled roofs, a little cooking smoke.
3. (60%,50%): river ferry crossing with shallows, reeds, small wooden pier, tiny white egrets.
4. (80%,62%): larger riverside market town with dense roofs and a few completely plain blank banners.
5. (20%,60%): rolling ridge covered with old pine forest.
6. (44%,80%): deep valley with localized subtle rose-gold sunset illumination, faint glowing spring on valley floor.
7. (24%,88%): subtle mossy stone door in a cliff, small and easy to overlook, a secret cave, NOT a dominant landmark.
A single coherent winding Yunxi river enters from the north edge, passes between the ferry at (60%,50%) and the market at (80%,62%), and flows out towards the southeast corner.
Around each specified coordinate keep approximately 80-pixel-radius calm low-contrast terrain where the game will overlay a marker. Integrate landmark structures just adjacent to those calm centres, avoid high-contrast clutter around marker positions. Do not draw any marker placeholders.
STRICT NEGATIVES: NO roads, NO paths, NO streets visible as connecting routes, NO route lines, NO labels, NO text or letters, NO signs with writing, NO compass, NO legend, NO borders, NO frame, NO UI elements, NO map markers, NO characters, NO signature, NO watermark. Terrain and buildings only. One complete image, not a collage or sheet.
```



## 2026-10-09：青云山区域完整美术批次

已完成 `docs/ART_BRIEF.md` 的 28 个正式文件：1 张地图、7 张地点横幅、7 张 NPC 立绘和 13 张二级场景。首张地图样图保留，正式地图通过 imagegen 修正洞府表现与标记附近留白后另存。

所有绘画由内置 imagegen 生成或编辑，未使用 CLI/API fallback。用户明确授权常规图像工具仅做裁切和尺寸调整，因此使用 Pillow 的 ImageOps.fit 与 Lanczos 重采样统一尺寸，没有用它重绘画面或改变配色。生成工具原图仍保留在 Codex generated_images；正式游戏资源均在仓库内。

横幅采用居中裁切；静室使用 `(0.5, 0.72)` 的裁切中心，以保留蒲团和香炉。地图仅作极小比例校正与尺寸调整。按游戏显示比例检查地点/场景横幅（900×190）与立绘（120×150），未见文字、水印或主体严重裁断。地图地标是图像模型近似排布，未作像素级地形坐标测量。

### 正式文件与最终尺寸

| 文件 | 尺寸 | 内容 |
|---|---|---|
| `assets/art/locations/sect.png` | 2400×600 | 青云山 |
| `assets/art/locations/town.png` | 2400×600 | 青石镇 |
| `assets/art/locations/ferry.png` | 2400×600 | 白鹭渡 |
| `assets/art/locations/market.png` | 2400×600 | 云溪坊市 |
| `assets/art/locations/ridge.png` | 2400×600 | 松风岭 |
| `assets/art/locations/wild.png` | 2400×600 | 落霞谷 |
| `assets/art/locations/ruin.png` | 2400×600 | 古修洞府 |
| `assets/art/portraits/shen_mo.png` | 512×640 | 沈墨 |
| `assets/art/portraits/boatman.png` | 512×640 | 老艄公 |
| `assets/art/portraits/storyteller.png` | 512×640 | 何三更 |
| `assets/art/portraits/peddler.png` | 512×640 | 钱货郎 |
| `assets/art/portraits/wounded.png` | 512×640 | 柳寒舟 |
| `assets/art/portraits/rogue.png` | 512×640 | 蒙面修士 |
| `assets/art/portraits/squatter.png` | 512×640 | 石寒 |
| `assets/art/portraits/azhi.png` | 512×640 | 阿芷（2026-10-12 起暂用图池 `gatherer_female_young_02.png` 的副本，待绘专属立绘） |
| `assets/art/scenes/sect_chamber.png` | 2400×600 | 静室 |
| `assets/art/scenes/sect_arena.png` | 2400×600 | 演武坪 |
| `assets/art/scenes/sect_hall.png` | 2400×600 | 传功堂 |
| `assets/art/scenes/town_inn.png` | 2400×600 | 青石客栈 |
| `assets/art/scenes/town_teahouse.png` | 2400×600 | 听雨茶馆 |
| `assets/art/scenes/ferry_dock.png` | 2400×600 | 渡口 |
| `assets/art/scenes/market_street.png` | 2400×600 | 坊市长街 |
| `assets/art/scenes/market_pharmacy.png` | 2400×600 | 云溪药铺 |
| `assets/art/scenes/ridge_pines.png` | 2400×600 | 松林 |
| `assets/art/scenes/wild_entrance.png` | 2400×600 | 落霞谷口 |
| `assets/art/scenes/wild_slope.png` | 2400×600 | 灵草坡 |
| `assets/art/scenes/wild_spring.png` | 2400×600 | 深谷灵泉 |
| `assets/art/scenes/ruin_stone_room.png` | 2400×600 | 洞府石室 |
| `assets/art/map/region_qingyun.png` | 2560×1600 | 青云山周边区域地图（洞府与留白修正版） |

### 批次提示词：横幅公共模板

除 `locations/sect.png` 外的横幅均使用以下模板。`{KIND}` 为地点图的 `location` 或场景图的 `sub-area scene`；`{SUBJECT}` 与追加要求逐项列于后文。

```text
Use case: stylized-concept.
Asset: ONE original {KIND} banner for 凡途, a 2D Chinese cultivation RPG in the illustrated visual family of 觅长生.
Output: 2400x600 PNG, 4:1 extra-wide panoramic composition, painting fills the whole canvas. One image, no collage.
Subject: {SUBJECT}
Composition: MAIN SUBJECT IN CENTRAL THIRD, ALL KEY CONTENT INSIDE CENTRAL 70% WIDTH AND CENTRAL 45% HEIGHT of the entire canvas so a very shallow centre crop keeps the subject. Keep upper and lower edges as quiet expendable scenery. Camera pulled back enough that complete main architecture fits inside the middle horizontal band. Designed for a 900x190 UI strip. No dominant people, only tiny distant adults if specified.
Style: unmistakably TWO-DIMENSIONAL HAND-DRAWN Chinese game background, clear economical dark ink outlines, FLAT color blocks, simple restrained washes, one or two simple shadow tones, simplified painterly shapes matching cel-shaded character sprites. Muted jade, deep teal, ink green, slate blue, warm pale stone and parchment, small warm accents, calm slightly mysterious spirit-world mood. Readable without extreme darkness. NO photorealism, 3D, CGI, realistic textures, glossy detail, cinematic lighting, heavy grain, chibi, pixel art.
NO text, lettering, calligraphy, labels, logo, watermark, signature, UI, frame or border. Every signboard, banner, book, slip and jar entirely blank or abstract pattern only.
```

### 批次提示词：立绘公共模板

```text
Use case: stylized-concept.
Asset: ONE original NPC bust portrait for 凡途, a 2D Chinese cultivation RPG in the illustrated visual family of 觅长生, matching clear ink outlined flat-color cel-shaded characters.
Output: 512x640 PNG portrait, EXACT 4:5 aspect ratio.
Subject: {SUBJECT}
Composition: ONE ADULT Chinese man, modest traditional clothing, half-body bust, THREE-QUARTER VIEW FACING TO THE RIGHT OF THE IMAGE, head and eyes directed toward image right. Clear readable silhouette and expressive simplified face in upper third, head fully inside frame with margin, hands and held object readable. Face readable displayed at 120x150. Plain muted slate-teal background with no scenery, no floor and no decorative halo.
Style: NON-REALISTIC HAND-DRAWN 2D GAME PORTRAIT, very clear dark ink contours, flat opaque color blocks, restrained two-tone cel shading, simple economical clothing folds and grouped hair shapes, slightly stylized face, adult proportions. Muted jade, slate, warm parchment and earth tones. Do not render a realistic person.
NO photorealism, semi-realistic concept painting, 3D, glossy CGI, cinematic lighting, realistic skin detail, intricate embroidery, brocade, realistic fabric weave, heavy grain, chibi, anime moe or pixel art.
NO text, letters, calligraphy, labels, watermark, signature, frame, border, logos, UI or decorative background. One complete portrait, not sheet or collage.
```

### 各图 Subject 与追加要求

- `assets/art/locations/town.png`
  - Subject: Qingshi Town, a small mortal town street at a mountain foot: wooden inn with completely blank signboard, teahouse, cooking smoke, willow trees, grey tiled roofs.
- `assets/art/locations/ferry.png`
  - Subject: Bailu Ferry: wide calm jade river, a wooden bamboo-pole ferry boat at a small pier, white egrets on reed-fringed shallows, muted distant mountains across the water.
- `assets/art/locations/market.png`
  - Subject: Yunxi Market: Chinese cultivation-town market street at dusk, warm lanterns, a herb shop, small stalls with herbs and pottery, a few tiny distant blurred adult passers-by, every signboard and hanging banner entirely blank.
- `assets/art/locations/ridge.png`
  - Subject: Songfeng Ridge: rolling jade mountain ridges covered in ancient Chinese pines, wind in layered pine branches, one narrow mountain walking path, mist between distant ridges.
  - 追加要求: Critical subject constraint: Only forest and natural ridges with ONE narrow dirt walking trail. ABSOLUTELY NO buildings, no temples, no sect halls, no pavilions, no stairs, no stone bridges, no lanterns, no people. Pine-covered rolling ridges are the hero subject.
- `assets/art/locations/wild.png`
  - Subject: Luoxia Valley, dangerous wilderness: a deep Chinese mountain valley beneath muted rose-gold sunset sky, slopes of faintly glowing spirit herbs, mist at its floor, restrained atmosphere of concealed danger.
  - 追加要求: Critical subject constraint: Untamed dangerous wilderness only. ABSOLUTELY NO buildings, temples, sect halls, pavilions, bridges, stone stairs, roads, gateways or people. Deep valley, rocky herb-covered slopes, faint glowing spirit herbs and bottom mist are the hero subject.
- `assets/art/locations/ruin.png`
  - Subject: Ancient cultivator cave: mossy stone cliff covered in hanging vines surrounding an old modest stone door, faint jade light leaking from the narrow door gap, quiet mysterious secluded atmosphere.
- `assets/art/portraits/shen_mo.png`
  - Subject: Shen Mo, male herb-shop owner aged 54, shrewd but kindly, neat grey-blue scholar's robe, small goatee, holding a simple wooden abacus with correctly arranged beads, friendly knowing expression.
- `assets/art/portraits/boatman.png`
  - Subject: An old male mortal ferryman aged 67, talkative, conical woven straw hat and simple straw rain cape, weathered tanned face, warm smile. Simplified graphic woven shapes, not realistic texture.
- `assets/art/portraits/storyteller.png`
  - Subject: He Sangeng, male storyteller aged 61, theatrical expression with one raised eyebrow, long plain muted blue-grey Chinese robe, holding a folding fan and a small plain wooden storyteller's gavel.
- `assets/art/portraits/peddler.png`
  - Subject: Qian the peddler, male travelling herb seller aged 38, smooth-talking confident smile, simple modest traveller's clothes, wooden carrying pole resting across one shoulder with herb baskets partly visible at the lower edges.
- `assets/art/portraits/wounded.png`
  - Subject: Liu Hanzhou, male wandering cultivator aged 27, quiet young swordsman, pale face, small restrained blood stain on his modest robe collar, holding a plain straight Chinese jian sword, tired but proud expression. No gore.
- `assets/art/portraits/rogue.png`
  - Subject: Hostile male rogue cultivator aged 35, cloth mask covering only the lower face, modest dark Chinese robe with restrained red trim, small controlled orange flame in one palm, cold threatening eyes.
- `assets/art/portraits/squatter.png`
  - Subject: Shi Han, male cultivator aged 49, suspicious, rough plain brown Taoist robe, stony guarded expression, earth-toned clothing, seated cross-legged, upper-body bust framing with only a hint of folded knees at bottom.
- `assets/art/scenes/sect_chamber.png`
  - Subject: Qingyun sword sect meditation chamber: quiet modest wooden room, one meditation cushion, bronze incense burner with a thin wisp of smoke, open window looking onto a jade mountain sea of clouds.
  - 追加要求: No people in this scene. Depict the specified environment only. All jade slips and weapons undecorated, without writing.
- `assets/art/scenes/sect_arena.png`
  - Subject: Qingyun sword sect training plaza: open worn pale stone platform for sparring, simple wooden weapon racks containing plain Chinese swords and staffs near sides, elegant Chinese sect halls behind, mountain mist.
  - 追加要求: No people in this scene. Depict the specified environment only. All jade slips and weapons undecorated, without writing.
- `assets/art/scenes/sect_hall.png`
  - Subject: Qingyun sword sect technique hall: wooden shelves holding orderly smooth jade slips without inscriptions, a long wooden reading table, hanging silk curtains, calm scholarly cultivation interior.
  - 追加要求: Depict the specified room as an environment without people. No writing on any scroll, book, sign, container or jade slip. Keep key table/cushion/dishes and window/stage inside the central horizontal band.
- `assets/art/scenes/town_inn.png`
  - Subject: Qingshi Town wooden inn hall: wooden tables and benches, a visible staircase, soft steam rising from simple bowls of medicinal dishes, warm restrained interior light, no people in foreground.
  - 追加要求: Depict the specified room as an environment without people. No writing on any scroll, book, sign, container or jade slip. Keep key table/cushion/dishes and window/stage inside the central horizontal band.
- `assets/art/scenes/town_teahouse.png`
  - Subject: Qingshi Town listening-to-rain teahouse: a small empty storyteller's stage with plain wooden table, tea tables and cups, fine rain curtain outside open windows, calm intimate Chinese wooden interior.
  - 追加要求: Depict the specified room as an environment without people. No writing on any scroll, book, sign, container or jade slip. Keep key table/cushion/dishes and window/stage inside the central horizontal band.
- `assets/art/scenes/ferry_dock.png`
  - Subject: Bailu Ferry dock close view: aged wooden pier posts, a wooden ferry boat moored beside the pier, one small old boatman viewed from behind in conical straw hat, calm jade river with reeds and distant mountains. Boatman is a small environmental figure, not dominant.
  - 追加要求: Only ONE small old boatman from behind, wearing straw hat and cape. No other people, no character portrait framing. Ferry boat and wooden pier are main subjects.
- `assets/art/scenes/market_street.png`
  - Subject: Yunxi cultivation market main street: pill shop, artifact shop, small street stalls, hanging warm lanterns, grey tiled Chinese buildings, all signboards completely blank and without writing; tiny distant passers-by only.
  - 追加要求: No foreground people. All signboards, drawers and jars must be COMPLETELY BLANK with no letters or symbols.
- `assets/art/scenes/market_pharmacy.png`
  - Subject: Yunxi herb shop interior: orderly wall of small plain wooden medicine drawers with simple ring handles, wooden counter, hanging bundles of dried spirit herbs, a few ceramic jars, every drawer and jar completely unlabelled.
  - 追加要求: No foreground people. All signboards, drawers and jars must be COMPLETELY BLANK with no letters or symbols.
- `assets/art/scenes/ridge_pines.png`
  - Subject: Songfeng Ridge pine forest close view: ancient twisted Chinese pines, restrained dappled light through flat foliage, mossy rocks, a few faintly glowing spirit herbs on the forest floor, peaceful mountain mist.
  - 追加要求: STRICT SUBJECT CONSTRAINT: wild natural environment ONLY. NO buildings, temples, pavilions, stairs, gates, bridges, lanterns, furniture or people. No visible monsters. Keep the distinctive forest-floor herbs / rock claw scratches / glowing herb patches clearly visible inside the middle horizontal band. Use simple flat outlined vegetation, not photographic forest texture.
- `assets/art/scenes/wild_entrance.png`
  - Subject: Luoxia Valley mouth: jagged rocks forming an uneasy narrow valley entrance, distinct claw scratches on a foreground rock, low mist, sparse pines and muted sunset light, dangerous atmosphere without visible monsters.
  - 追加要求: STRICT SUBJECT CONSTRAINT: wild natural environment ONLY. NO buildings, temples, pavilions, stairs, gates, bridges, lanterns, furniture or people. No visible monsters. Keep the distinctive forest-floor herbs / rock claw scratches / glowing herb patches clearly visible inside the middle horizontal band. Use simple flat outlined vegetation, not photographic forest texture.
- `assets/art/scenes/wild_slope.png`
  - Subject: Luoxia Valley spirit-herb slope: sunny gentle hillside with patches of faintly jade-glowing spirit herbs, rocks and small grasses, surrounding Chinese mountain valley, restrained warm daylight and clear flat leaf silhouettes.
  - 追加要求: STRICT SUBJECT CONSTRAINT: wild natural environment ONLY. NO buildings, temples, pavilions, stairs, gates, bridges, lanterns, furniture or people. No visible monsters. Keep the distinctive forest-floor herbs / rock claw scratches / glowing herb patches clearly visible inside the middle horizontal band. Use simple flat outlined vegetation, not photographic forest texture.
- `assets/art/scenes/wild_spring.png`
  - Subject: Luoxia Valley deep spring, a serpent's lair: small softly jade-glowing spring at the rocky valley floor, delicate mist, a few large crimson red shed serpent scales lying on rocks, dark jade vegetation, no visible serpent.
  - 追加要求: Wild natural serpent lair ONLY: NO buildings, temples, pavilions, bridges, stairs, statues, people or visible serpent. Show a few distinctly red fallen serpent scales ON rocks near the glowing spring, within the central band; keep spring glow restrained.
- `assets/art/scenes/ruin_stone_room.png`
  - Subject: Ancient cultivator cave stone room: stone bed, worn meditation cushion, scattered plain jade slips without inscriptions and clay jars, dust in a restrained shaft of daylight, old quiet Chinese cultivation retreat.
  - 追加要求: Old abandoned modest stone cell carved inside a mountain, NOT a palace, NOT a modern room. Stone bed, visibly worn cushion, scattered jade slips and jars near center; slips entirely blank. No people, no inscriptions, no readable marks. Restrained dusty daylight, not theatrical cinematic light.

### 青云山地点图首张提示词

```text
Use case: stylized-concept.
Asset: ONE original location banner for 凡途, a 2D Chinese cultivation RPG in the illustrated visual family of 觅长生.
OUTPUT SIZE: 2400x600 PNG, EXACTLY FOUR TIMES AS WIDE AS TALL (4:1). Extremely wide horizontal panorama, edge-to-edge painting, no letterboxing.
Subject: Qingyun Mountain sword sect outer court: elegant Chinese sect halls and pavilions halfway up a mountain above a sea of clouds, long worn pale stone stairs, the tall main peak in the distance.
Composition: main subject in central third; all important content inside central 70% width and middle 80% height; quieter edges, designed for centre cropping into a 900x190 UI strip. No dominant people; only tiny distant adult figures when specified.
Style: unmistakably two-dimensional hand-painted Chinese fantasy game background, clear restrained dark ink outlines, flat color areas, simplified economical painterly shapes, one or two simple shadow tones and limited washes. Cohesive muted jade, ink green, slate blue, warm stone and parchment palette, small warm accents. Calm slightly mysterious spirit-world mood; comfortably readable beside dark teal UI. Match a hand-drawn cel-shaded game, not a realistic concept painting.
No photorealism, 3D, CGI, cinematic lighting, glossy surfaces, photographic textures, heavy film grain, chibi or pixel art. NO text, lettering, labels, calligraphy, logos, watermark, signature, UI, frame, borders. All signs blank. One complete image only, not collage or sprite sheet.
```

### 正式地图修正提示词

输入目标：`assets/art/map/region_qingyun_preview_v1.png`。

```text
Use case: precise-object-edit.
Edit target: the attached Qingyun regional map. Preserve its original 2D hand-drawn Chinese game style, clear dark ink contours, flat muted jade/slate/teal palette, warm local spring glow, high oblique bird's-eye view, complete coherent river, overall atmosphere and rectangular 8:5 composition. Output 2560x1600 PNG; terrain fills entire canvas.
Make a focused production-map correction:
- The secret cave stone door is currently far too prominent in the lower-left. Remove the ornamental temple-like entrance and replace with a TINY weathered plain stone door almost concealed by moss and vines, located at x24%, y88%. It should be easy to overlook, no glow or pavilion or lamps.
- Align landmark areas to the following normalized coordinates measured from top-left: mountain sword-sect halls at (24%,24%); small grey-roof mortal town at (40%,42%); reed shallows and wooden ferry pier at (60%,50%); larger riverside market town at (80%,62%); ancient pine-covered ridge at (20%,60%); deep rose-gold sunset valley and faint glowing spring at (44%,80%); tiny secret cave stone door at (24%,88%).
- Integrate a calm low-contrast terrain patch of approximately 80px radius at each of these marker coordinates, with architecture and busy vegetation nearby rather than occupying the exact centre. These calm areas must look natural, not circles or holes; the game will place a marker and label there.
Keep one Yunxi river entering from the north, passing between ferry and market, exiting southeast. No new extra settlements or sect buildings elsewhere.
Absolute negatives: NO roads, paths, streets or route lines; NO text, letters, calligraphy, labels, marker icons, circles, dots, compass, legend, frame, border, UI, watermark or signature; NO characters. No realistic textures, 3D or cinematic lighting. One complete original painted regional map.
```

### 验证记录

- 28 张正式 PNG 均存在、可解码，且尺寸严格符合最终规格。
- Godot `--headless --path . --import` 成功，无脚本或导入错误。
- 视觉检查图保存在忽略目录 `builds/previews/art_batch/`；未打开可见游戏或编辑器窗口。

- check.cmd passed: CORE 25 / WORLD 42 / EVENTS 66 / REGION 126 / UI 26 / PRESENTATION 17 / SECTS 237; 539 checks, 0 failures. All launches used --headless, with no visible windows and no script/resource errors in output.
- After syncing origin/main at c1c7979, check.cmd passed again: CORE 28 / WORLD 42 / EVENTS 66 / REGION 126 / GROWTH 54 / ARSENAL 77 / UI 30 / PRESENTATION 17 / SECTS 237; 677 checks, 0 failures. All launches used --headless; no script/resource errors in output.

## 2026-10-09 M4 与路人头像池生成记录

需求：`docs/ART_BRIEF_M4.md` 的 29 张，以及用户选择的 180 张头像（六组各 30 张）。

生成方式：Codex 原生 imagegen，逐张生成。以觅长生官方游戏截图中的人物线稿、平涂、简洁阴影作为画风参考，人物为本项目原创普通修士。没有复制具体游戏角色。

参考页：[觅长生官方 Steam 页面](https://store.steampowered.com/app/1189490/)。斗法场地同时参考本仓库 `bamboo_arena_v1.png` 的构图；命名角色参考对应现有立绘以保持身份。

尺寸处理：使用用户已授权的裁切、缩放；六姿势图集裁切每个完整动作、等比缩放后放入 512x512 单格，脚底统一约 y=471，保留生成图片原有 alpha。未以脚本重绘人物或去背。

当前记录：209 张；分组计数：female_middle=30, female_old=30, female_young=30, m4=29, male_middle=30, male_old=30, male_young=30。

接入说明：头像池由现有 `ArtLibrary.pool_index()` 从磁盘自动读取；性别、年龄段和身份优先匹配。现有分配使用确定性哈希，不保证不同路人绝不重复，头像池变动或人物进入新的年龄段时也可能改变结果。本批不修改分配代码或存档。

已同步远程提交 84e9a53：现有斗法界面会按地点选择本批背景，并按门派和性别选择修士图集；命名劫修图集路径也已接入。事件插图界面仍在 BACKLOG 中。本次增加图片、导入配置和资源登记，并更新展示测试以覆盖新资源；未修改游戏代码或数据。

### 2026-10-12 最终验证

- 209 张 PNG 均可解码，尺寸、色彩模式及分组数量符合要求；14 张人物图集保留透明通道，六个动作格均非空，无跨格内容。
- 同步远程 main（4b0fdeb）后，Godot 后台导入成功；资源运行检查 250 项、0 失败。
- 后台游戏测试共 762 项，1 失败：EVENTS 的 500 年模拟合计 4123 ms，超过 4000 ms 预算。新增图片前同项也超限，保留原预算并如实记录；其余测试均通过。
- 展示测试已改为验证新背景、门派/性别图集及命名劫修图集，同时保留缺图回退覆盖；25 项、0 失败。
- 所有自动启动均使用 --headless；输出无脚本或资源错误，未打开可见游戏或编辑器窗口。视觉检查和运行日志保存在忽略目录 builds/previews/m4_art_batch/。

### 文件、尺寸与生成提示词

每张图实际使用的提示词由下表的 P 编号按顺序以一个换行连接组成。重复风格段落只登记一次，主体描述、道具覆盖和布局修正均保留。空段落也按编号保留。

| 文件 | 尺寸 | 色彩模式 | 提示词段落顺序 |
|---|---|---|---|
| `assets/art/actors/cultivator_canglan_female.png` | 1536x1024 | RGBA | P001, P002, P003, P004, P005, P006 |
| `assets/art/actors/cultivator_canglan_male.png` | 1536x1024 | RGBA | P001, P002, P007, P004, P005, P006 |
| `assets/art/actors/cultivator_changqing_female.png` | 1536x1024 | RGBA | P001, P002, P008, P004, P005, P006 |
| `assets/art/actors/cultivator_changqing_male.png` | 1536x1024 | RGBA | P001, P002, P009, P004, P005, P006 |
| `assets/art/actors/cultivator_chixiao_female.png` | 1536x1024 | RGBA | P001, P002, P010, P004, P005, P006 |
| `assets/art/actors/cultivator_chixiao_male.png` | 1536x1024 | RGBA | P001, P002, P011, P004, P005, P006 |
| `assets/art/actors/cultivator_qingyun_female.png` | 1536x1024 | RGBA | P001, P002, P012, P004, P005, P006 |
| `assets/art/actors/cultivator_qingyun_male.png` | 1536x1024 | RGBA | P001, P002, P013, P004, P005, P006 |
| `assets/art/actors/cultivator_wanderer_female.png` | 1536x1024 | RGBA | P001, P002, P014, P004, P005, P006 |
| `assets/art/actors/cultivator_wanderer_male.png` | 1536x1024 | RGBA | P001, P002, P015, P004, P005, P006 |
| `assets/art/actors/cultivator_xuanyue_female.png` | 1536x1024 | RGBA | P001, P002, P016, P004, P005, P006 |
| `assets/art/actors/cultivator_xuanyue_male.png` | 1536x1024 | RGBA | P001, P002, P017, P004, P005, P006 |
| `assets/art/actors/rogue.png` | 1536x1024 | RGBA | P001, P018, P019, P004, P005, P020, P021, P022, P023, P024 |
| `assets/art/actors/ruin_rogue.png` | 1536x1024 | RGBA | P001, P018, P025, P004, P005, P020, P021, P022, P023, P024 |
| `assets/art/battle/ferry.png` | 1792x768 | RGB | P026, P027, P028, P029, P005, P030 |
| `assets/art/battle/market.png` | 1792x768 | RGB | P026, P027, P031, P029, P005, P030 |
| `assets/art/battle/ridge.png` | 1792x768 | RGB | P026, P027, P032, P029, P005, P030 |
| `assets/art/battle/road.png` | 1792x768 | RGB | P026, P027, P033, P029, P005, P030 |
| `assets/art/battle/ruin.png` | 1792x768 | RGB | P026, P027, P034, P029, P005, P030 |
| `assets/art/battle/sect.png` | 1792x768 | RGB | P026, P027, P035, P029, P005, P030 |
| `assets/art/battle/town.png` | 1792x768 | RGB | P026, P027, P036, P029, P005, P030 |
| `assets/art/battle/wild.png` | 1792x768 | RGB | P026, P027, P037, P029, P005, P030 |
| `assets/art/events/outer_tournament.png` | 1600x900 | RGB | P038, P039, P040, P041, P005, P042 |
| `assets/art/events/rogue_ambush.png` | 1600x900 | RGB | P038, P043, P044, P041, P005, P042 |
| `assets/art/events/serpent_rampage.png` | 1600x900 | RGB | P038, P043, P045, P041, P005, P042 |
| `assets/art/events/teahouse_story.png` | 1600x900 | RGB | P038, P043, P046, P041, P005, P042 |
| `assets/art/events/wounded_in_pines.png` | 1600x900 | RGB | P038, P043, P047, P041, P005, P042 |
| `assets/art/events/yunxi_auction.png` | 1600x900 | RGB | P038, P039, P048, P041, P005, P042 |
| `assets/art/events/yunxi_night_market.png` | 1600x900 | RGB | P038, P039, P049, P041, P005, P042 |
| `assets/local/portraits/pool/female_middle/disciple_female_middle_01.png` | 512x640 | RGB | P050, P051, P052, P005, P053, P054, P055 |
| `assets/local/portraits/pool/female_middle/disciple_female_middle_02.png` | 512x640 | RGB | P050, P051, P056, P005, P053, P057, P055 |
| `assets/local/portraits/pool/female_middle/disciple_female_middle_03.png` | 512x640 | RGB | P050, P051, P058, P005, P053, P059, P055 |
| `assets/local/portraits/pool/female_middle/disciple_female_middle_04.png` | 512x640 | RGB | P050, P051, P060, P005, P053, P061, P055 |
| `assets/local/portraits/pool/female_middle/disciple_female_middle_05.png` | 512x640 | RGB | P050, P051, P062, P005, P053, P063, P055 |
| `assets/local/portraits/pool/female_middle/disciple_female_middle_06.png` | 512x640 | RGB | P050, P051, P064, P005, P053, P065, P055 |
| `assets/local/portraits/pool/female_middle/disciple_female_middle_07.png` | 512x640 | RGB | P050, P051, P066, P005, P053, P067, P055 |
| `assets/local/portraits/pool/female_middle/disciple_female_middle_08.png` | 512x640 | RGB | P050, P051, P068, P005, P053, P069, P055 |
| `assets/local/portraits/pool/female_middle/disciple_female_middle_09.png` | 512x640 | RGB | P050, P051, P070, P005, P053, P071, P055 |
| `assets/local/portraits/pool/female_middle/gatherer_female_middle_01.png` | 512x640 | RGB | P050, P051, P072, P005, P053, P063, P073, P055 |
| `assets/local/portraits/pool/female_middle/gatherer_female_middle_02.png` | 512x640 | RGB | P050, P051, P074, P005, P053, P065, P075, P055 |
| `assets/local/portraits/pool/female_middle/gatherer_female_middle_03.png` | 512x640 | RGB | P050, P051, P076, P005, P053, P067, P077, P055 |
| `assets/local/portraits/pool/female_middle/gatherer_female_middle_04.png` | 512x640 | RGB | P050, P051, P078, P005, P053, P069, P079, P055 |
| `assets/local/portraits/pool/female_middle/trader_female_middle_01.png` | 512x640 | RGB | P050, P051, P080, P005, P053, P071, P081, P055 |
| `assets/local/portraits/pool/female_middle/trader_female_middle_02.png` | 512x640 | RGB | P050, P051, P082, P005, P053, P083, P084, P055 |
| `assets/local/portraits/pool/female_middle/trader_female_middle_03.png` | 512x640 | RGB | P050, P051, P085, P005, P053, P054, P086, P055 |
| `assets/local/portraits/pool/female_middle/trader_female_middle_04.png` | 512x640 | RGB | P050, P051, P087, P005, P053, P057, P088, P055 |
| `assets/local/portraits/pool/female_middle/trader_female_middle_05.png` | 512x640 | RGB | P050, P051, P089, P005, P053, P059, P081, P055 |
| `assets/local/portraits/pool/female_middle/trader_female_middle_06.png` | 512x640 | RGB | P050, P051, P090, P005, P053, P061, P084, P055 |
| `assets/local/portraits/pool/female_middle/visitor_female_middle_01.png` | 512x640 | RGB | P050, P051, P091, P005, P053, P071, P055 |
| `assets/local/portraits/pool/female_middle/visitor_female_middle_02.png` | 512x640 | RGB | P050, P051, P092, P005, P053, P083, P055 |
| `assets/local/portraits/pool/female_middle/wanderer_female_middle_01.png` | 512x640 | RGB | P050, P051, P093, P005, P053, P083, P094, P055 |
| `assets/local/portraits/pool/female_middle/wanderer_female_middle_02.png` | 512x640 | RGB | P050, P051, P095, P005, P053, P054, P096, P055 |
| `assets/local/portraits/pool/female_middle/wanderer_female_middle_03.png` | 512x640 | RGB | P050, P051, P097, P005, P053, P057, P098, P055 |
| `assets/local/portraits/pool/female_middle/wanderer_female_middle_04.png` | 512x640 | RGB | P050, P051, P099, P005, P053, P059, P100, P055 |
| `assets/local/portraits/pool/female_middle/wanderer_female_middle_05.png` | 512x640 | RGB | P050, P051, P101, P005, P053, P061, P094, P055 |
| `assets/local/portraits/pool/female_middle/wanderer_female_middle_06.png` | 512x640 | RGB | P050, P051, P102, P005, P053, P063, P096, P055 |
| `assets/local/portraits/pool/female_middle/wanderer_female_middle_07.png` | 512x640 | RGB | P050, P051, P103, P005, P053, P065, P098, P055 |
| `assets/local/portraits/pool/female_middle/wanderer_female_middle_08.png` | 512x640 | RGB | P050, P051, P104, P005, P053, P067, P100, P055 |
| `assets/local/portraits/pool/female_middle/wanderer_female_middle_09.png` | 512x640 | RGB | P050, P051, P105, P005, P053, P069, P094, P055 |
| `assets/local/portraits/pool/female_old/disciple_female_old_01.png` | 512x640 | RGB | P050, P051, P106, P005, P053, P059, P055 |
| `assets/local/portraits/pool/female_old/disciple_female_old_02.png` | 512x640 | RGB | P050, P051, P107, P005, P053, P061, P055 |
| `assets/local/portraits/pool/female_old/disciple_female_old_03.png` | 512x640 | RGB | P050, P051, P108, P005, P053, P063 |
| `assets/local/portraits/pool/female_old/disciple_female_old_04.png` | 512x640 | RGB | P050, P051, P109, P005, P053, P065, P055 |
| `assets/local/portraits/pool/female_old/disciple_female_old_05.png` | 512x640 | RGB | P050, P051, P110, P005, P053, P067, P055 |
| `assets/local/portraits/pool/female_old/disciple_female_old_06.png` | 512x640 | RGB | P050, P051, P111, P005, P053, P069, P055 |
| `assets/local/portraits/pool/female_old/disciple_female_old_07.png` | 512x640 | RGB | P050, P051, P112, P005, P053, P071, P055 |
| `assets/local/portraits/pool/female_old/gatherer_female_old_01.png` | 512x640 | RGB | P050, P051, P113, P005, P053, P065, P073, P055 |
| `assets/local/portraits/pool/female_old/gatherer_female_old_02.png` | 512x640 | RGB | P050, P051, P114, P005, P053, P067, P075, P055 |
| `assets/local/portraits/pool/female_old/gatherer_female_old_03.png` | 512x640 | RGB | P050, P051, P115, P005, P053, P069, P077, P055 |
| `assets/local/portraits/pool/female_old/gatherer_female_old_04.png` | 512x640 | RGB | P050, P051, P116, P005, P053, P071, P079, P055 |
| `assets/local/portraits/pool/female_old/gatherer_female_old_05.png` | 512x640 | RGB | P050, P051, P117, P005, P053, P083, P073, P055 |
| `assets/local/portraits/pool/female_old/trader_female_old_01.png` | 512x640 | RGB | P050, P051, P118, P005, P053, P083, P081, P055 |
| `assets/local/portraits/pool/female_old/trader_female_old_02.png` | 512x640 | RGB | P050, P051, P119, P005, P053, P054, P084, P055 |
| `assets/local/portraits/pool/female_old/trader_female_old_03.png` | 512x640 | RGB | P050, P051, P120, P005, P053, P057, P086, P055 |
| `assets/local/portraits/pool/female_old/trader_female_old_04.png` | 512x640 | RGB | P050, P051, P121, P005, P053, P059, P088, P055 |
| `assets/local/portraits/pool/female_old/trader_female_old_05.png` | 512x640 | RGB | P050, P051, P122, P005, P053, P061, P081, P055 |
| `assets/local/portraits/pool/female_old/trader_female_old_06.png` | 512x640 | RGB | P050, P051, P123, P005, P053, P063, P084, P055 |
| `assets/local/portraits/pool/female_old/visitor_female_old_01.png` | 512x640 | RGB | P050, P051, P124, P005, P053, P054, P055 |
| `assets/local/portraits/pool/female_old/visitor_female_old_02.png` | 512x640 | RGB | P050, P051, P125, P005, P053, P057, P055 |
| `assets/local/portraits/pool/female_old/wanderer_female_old_01.png` | 512x640 | RGB | P050, P051, P126, P005, P053, P083, P094, P055 |
| `assets/local/portraits/pool/female_old/wanderer_female_old_02.png` | 512x640 | RGB | P050, P051, P127, P005, P053, P054, P096, P055 |
| `assets/local/portraits/pool/female_old/wanderer_female_old_03.png` | 512x640 | RGB | P050, P051, P128, P005, P053, P057, P098, P055 |
| `assets/local/portraits/pool/female_old/wanderer_female_old_04.png` | 512x640 | RGB | P050, P051, P129, P005, P053, P059, P100, P055 |
| `assets/local/portraits/pool/female_old/wanderer_female_old_05.png` | 512x640 | RGB | P050, P051, P130, P005, P053, P061, P094, P055 |
| `assets/local/portraits/pool/female_old/wanderer_female_old_06.png` | 512x640 | RGB | P050, P051, P131, P005, P053, P063, P096, P055 |
| `assets/local/portraits/pool/female_old/wanderer_female_old_07.png` | 512x640 | RGB | P050, P051, P132, P005, P053, P065, P098, P055 |
| `assets/local/portraits/pool/female_old/wanderer_female_old_08.png` | 512x640 | RGB | P050, P051, P133, P005, P053, P067, P100, P055 |
| `assets/local/portraits/pool/female_old/wanderer_female_old_09.png` | 512x640 | RGB | P050, P051, P134, P005, P053, P069, P094, P055 |
| `assets/local/portraits/pool/female_old/wanderer_female_old_10.png` | 512x640 | RGB | P050, P051, P135, P005, P053, P071, P096, P055 |
| `assets/local/portraits/pool/female_young/disciple_female_young_01.png` | 512x640 | RGB | P050, P051, P136, P005, P053, P054, P055 |
| `assets/local/portraits/pool/female_young/disciple_female_young_02.png` | 512x640 | RGB | P050, P051, P137, P005, P053, P057, P055 |
| `assets/local/portraits/pool/female_young/disciple_female_young_03.png` | 512x640 | RGB | P050, P051, P138, P005, P053, P059, P055 |
| `assets/local/portraits/pool/female_young/disciple_female_young_04.png` | 512x640 | RGB | P050, P051, P139, P005, P053, P061, P055 |
| `assets/local/portraits/pool/female_young/disciple_female_young_05.png` | 512x640 | RGB | P050, P051, P140, P005, P053, P063, P055 |
| `assets/local/portraits/pool/female_young/disciple_female_young_06.png` | 512x640 | RGB | P050, P051, P141, P005, P053, P065, P055 |
| `assets/local/portraits/pool/female_young/disciple_female_young_07.png` | 512x640 | RGB | P050, P051, P142, P005, P053, P067, P055 |
| `assets/local/portraits/pool/female_young/disciple_female_young_08.png` | 512x640 | RGB | P050, P051, P143, P005, P053, P069, P055 |
| `assets/local/portraits/pool/female_young/disciple_female_young_09.png` | 512x640 | RGB | P050, P051, P144, P005, P053, P071, P055 |
| `assets/local/portraits/pool/female_young/disciple_female_young_10.png` | 512x640 | RGB | P050, P051, P145, P005, P053, P083, P055 |
| `assets/local/portraits/pool/female_young/disciple_female_young_11.png` | 512x640 | RGB | P050, P051, P146, P005, P053, P054, P055 |
| `assets/local/portraits/pool/female_young/disciple_female_young_12.png` | 512x640 | RGB | P050, P051, P147, P005, P053, P057, P055 |
| `assets/local/portraits/pool/female_young/disciple_female_young_13.png` | 512x640 | RGB | P050, P051, P148, P005, P053, P059, P055 |
| `assets/local/portraits/pool/female_young/disciple_female_young_14.png` | 512x640 | RGB | P050, P051, P149, P005, P053, P061, P055 |
| `assets/local/portraits/pool/female_young/gatherer_female_young_01.png` | 512x640 | RGB | P050, P051, P150, P005, P053, P063, P073, P055 |
| `assets/local/portraits/pool/female_young/gatherer_female_young_02.png` | 512x640 | RGB | P050, P051, P151, P005, P053, P065, P075, P055 |
| `assets/local/portraits/pool/female_young/gatherer_female_young_03.png` | 512x640 | RGB | P050, P051, P152, P005, P053, P067, P077, P055 |
| `assets/local/portraits/pool/female_young/gatherer_female_young_04.png` | 512x640 | RGB | P050, P051, P153, P005, P053, P069, P079, P055 |
| `assets/local/portraits/pool/female_young/trader_female_young_01.png` | 512x640 | RGB | P050, P051, P154, P005, P053, P057, P081, P055 |
| `assets/local/portraits/pool/female_young/trader_female_young_02.png` | 512x640 | RGB | P050, P051, P155, P005, P053, P059, P084, P055 |
| `assets/local/portraits/pool/female_young/trader_female_young_03.png` | 512x640 | RGB | P050, P051, P156, P005, P053, P061, P086, P055 |
| `assets/local/portraits/pool/female_young/visitor_female_young_01.png` | 512x640 | RGB | P050, P051, P157, P005, P053, P071, P055 |
| `assets/local/portraits/pool/female_young/visitor_female_young_02.png` | 512x640 | RGB | P050, P051, P158, P005, P053, P083, P055 |
| `assets/local/portraits/pool/female_young/wanderer_female_young_01.png` | 512x640 | RGB | P050, P051, P159, P005, P053, P063, P094, P055 |
| `assets/local/portraits/pool/female_young/wanderer_female_young_02.png` | 512x640 | RGB | P050, P051, P160, P005, P053, P065, P096, P055 |
| `assets/local/portraits/pool/female_young/wanderer_female_young_03.png` | 512x640 | RGB | P050, P051, P161, P005, P053, P067, P098, P055 |
| `assets/local/portraits/pool/female_young/wanderer_female_young_04.png` | 512x640 | RGB | P050, P051, P162, P005, P053, P069, P100, P055 |
| `assets/local/portraits/pool/female_young/wanderer_female_young_05.png` | 512x640 | RGB | P050, P051, P163, P005, P053, P071, P094, P055 |
| `assets/local/portraits/pool/female_young/wanderer_female_young_06.png` | 512x640 | RGB | P050, P051, P164, P005, P053, P083, P096, P055 |
| `assets/local/portraits/pool/female_young/wanderer_female_young_07.png` | 512x640 | RGB | P050, P051, P165, P005, P053, P054, P098, P055 |
| `assets/local/portraits/pool/male_middle/disciple_male_middle_01.png` | 512x640 | RGB | P050, P051, P166, P005, P053, P069 |
| `assets/local/portraits/pool/male_middle/disciple_male_middle_02.png` | 512x640 | RGB | P050, P051, P167, P005, P053, P071 |
| `assets/local/portraits/pool/male_middle/disciple_male_middle_03.png` | 512x640 | RGB | P050, P051, P168, P005, P053, P083 |
| `assets/local/portraits/pool/male_middle/disciple_male_middle_04.png` | 512x640 | RGB | P050, P051, P169, P005, P053, P054 |
| `assets/local/portraits/pool/male_middle/disciple_male_middle_05.png` | 512x640 | RGB | P050, P051, P170, P005, P053, P057 |
| `assets/local/portraits/pool/male_middle/disciple_male_middle_06.png` | 512x640 | RGB | P050, P051, P171, P005, P053, P059 |
| `assets/local/portraits/pool/male_middle/disciple_male_middle_07.png` | 512x640 | RGB | P050, P051, P172, P005, P053, P061 |
| `assets/local/portraits/pool/male_middle/disciple_male_middle_08.png` | 512x640 | RGB | P050, P051, P173, P005, P053, P063 |
| `assets/local/portraits/pool/male_middle/disciple_male_middle_09.png` | 512x640 | RGB | P050, P051, P174, P005, P053, P065 |
| `assets/local/portraits/pool/male_middle/gatherer_male_middle_01.png` | 512x640 | RGB | P050, P051, P175, P005, P053, P057, P073, P055 |
| `assets/local/portraits/pool/male_middle/gatherer_male_middle_02.png` | 512x640 | RGB | P050, P051, P176, P005, P053, P059, P075, P055 |
| `assets/local/portraits/pool/male_middle/gatherer_male_middle_03.png` | 512x640 | RGB | P050, P051, P177, P005, P053, P061, P077, P055 |
| `assets/local/portraits/pool/male_middle/gatherer_male_middle_04.png` | 512x640 | RGB | P050, P051, P178, P005, P053, P063, P079, P055 |
| `assets/local/portraits/pool/male_middle/trader_male_middle_01.png` | 512x640 | RGB | P050, P051, P179, P005, P053, P065, P081 |
| `assets/local/portraits/pool/male_middle/trader_male_middle_02.png` | 512x640 | RGB | P050, P051, P180, P005, P053, P067, P084, P055 |
| `assets/local/portraits/pool/male_middle/trader_male_middle_03.png` | 512x640 | RGB | P050, P051, P181, P005, P053, P069, P086, P055 |
| `assets/local/portraits/pool/male_middle/trader_male_middle_04.png` | 512x640 | RGB | P050, P051, P182, P005, P053, P071, P088, P055 |
| `assets/local/portraits/pool/male_middle/trader_male_middle_05.png` | 512x640 | RGB | P050, P051, P183, P005, P053, P083, P081, P055 |
| `assets/local/portraits/pool/male_middle/trader_male_middle_06.png` | 512x640 | RGB | P050, P051, P184, P005, P053, P054, P084, P055 |
| `assets/local/portraits/pool/male_middle/visitor_male_middle_01.png` | 512x640 | RGB | P050, P051, P185, P005, P053, P065, P055 |
| `assets/local/portraits/pool/male_middle/visitor_male_middle_02.png` | 512x640 | RGB | P050, P051, P186, P005, P053, P067, P055 |
| `assets/local/portraits/pool/male_middle/wanderer_male_middle_01.png` | 512x640 | RGB | P050, P051, P187, P005, P053, P067, P094 |
| `assets/local/portraits/pool/male_middle/wanderer_male_middle_02.png` | 512x640 | RGB | P050, P051, P188, P005, P053, P069, P096 |
| `assets/local/portraits/pool/male_middle/wanderer_male_middle_03.png` | 512x640 | RGB | P050, P051, P189, P005, P053, P071, P098 |
| `assets/local/portraits/pool/male_middle/wanderer_male_middle_04.png` | 512x640 | RGB | P050, P051, P190, P005, P053, P083, P100 |
| `assets/local/portraits/pool/male_middle/wanderer_male_middle_05.png` | 512x640 | RGB | P050, P051, P191, P005, P053, P054, P094 |
| `assets/local/portraits/pool/male_middle/wanderer_male_middle_06.png` | 512x640 | RGB | P050, P051, P192, P005, P053, P057, P096 |
| `assets/local/portraits/pool/male_middle/wanderer_male_middle_07.png` | 512x640 | RGB | P050, P051, P193, P005, P053, P059, P098 |
| `assets/local/portraits/pool/male_middle/wanderer_male_middle_08.png` | 512x640 | RGB | P050, P051, P194, P005, P053, P061, P100 |
| `assets/local/portraits/pool/male_middle/wanderer_male_middle_09.png` | 512x640 | RGB | P050, P051, P195, P005, P053, P063, P094 |
| `assets/local/portraits/pool/male_old/disciple_male_old_01.png` | 512x640 | RGB | P050, P051, P196, P005, P053, P083, P055 |
| `assets/local/portraits/pool/male_old/disciple_male_old_02.png` | 512x640 | RGB | P050, P051, P197, P005, P053, P054, P055 |
| `assets/local/portraits/pool/male_old/disciple_male_old_03.png` | 512x640 | RGB | P050, P051, P198, P005, P053, P057, P055 |
| `assets/local/portraits/pool/male_old/disciple_male_old_04.png` | 512x640 | RGB | P050, P051, P199, P005, P053, P059, P055 |
| `assets/local/portraits/pool/male_old/disciple_male_old_05.png` | 512x640 | RGB | P050, P051, P200, P005, P053, P061, P055 |
| `assets/local/portraits/pool/male_old/disciple_male_old_06.png` | 512x640 | RGB | P050, P051, P201, P005, P053, P063, P055 |
| `assets/local/portraits/pool/male_old/disciple_male_old_07.png` | 512x640 | RGB | P050, P051, P202, P005, P053, P065, P055 |
| `assets/local/portraits/pool/male_old/gatherer_male_old_01.png` | 512x640 | RGB | P050, P051, P203, P005, P053, P059, P073, P055 |
| `assets/local/portraits/pool/male_old/gatherer_male_old_02.png` | 512x640 | RGB | P050, P051, P204, P005, P053, P061, P075, P055 |
| `assets/local/portraits/pool/male_old/gatherer_male_old_03.png` | 512x640 | RGB | P050, P051, P205, P005, P053, P063, P077, P055 |
| `assets/local/portraits/pool/male_old/gatherer_male_old_04.png` | 512x640 | RGB | P050, P051, P206, P005, P053, P065, P079, P055 |
| `assets/local/portraits/pool/male_old/gatherer_male_old_05.png` | 512x640 | RGB | P050, P051, P207, P005, P053, P067, P073, P055 |
| `assets/local/portraits/pool/male_old/trader_male_old_01.png` | 512x640 | RGB | P050, P051, P208, P005, P053, P067, P081, P055 |
| `assets/local/portraits/pool/male_old/trader_male_old_02.png` | 512x640 | RGB | P050, P051, P209, P005, P053, P069, P084, P055 |
| `assets/local/portraits/pool/male_old/trader_male_old_03.png` | 512x640 | RGB | P050, P051, P210, P005, P053, P071, P086, P055 |
| `assets/local/portraits/pool/male_old/trader_male_old_04.png` | 512x640 | RGB | P050, P051, P211, P005, P053, P083, P088, P055 |
| `assets/local/portraits/pool/male_old/trader_male_old_05.png` | 512x640 | RGB | P050, P051, P212, P005, P053, P054, P081, P055 |
| `assets/local/portraits/pool/male_old/trader_male_old_06.png` | 512x640 | RGB | P050, P051, P213, P005, P053, P057, P084, P055 |
| `assets/local/portraits/pool/male_old/visitor_male_old_01.png` | 512x640 | RGB | P050, P051, P214, P005, P053, P069, P055 |
| `assets/local/portraits/pool/male_old/visitor_male_old_02.png` | 512x640 | RGB | P050, P051, P215, P005, P053, P071, P055 |
| `assets/local/portraits/pool/male_old/wanderer_male_old_01.png` | 512x640 | RGB | P050, P051, P216, P005, P053, P067, P094, P055 |
| `assets/local/portraits/pool/male_old/wanderer_male_old_02.png` | 512x640 | RGB | P050, P051, P217, P005, P053, P069, P096, P055 |
| `assets/local/portraits/pool/male_old/wanderer_male_old_03.png` | 512x640 | RGB | P050, P051, P218, P005, P053, P071, P098, P055 |
| `assets/local/portraits/pool/male_old/wanderer_male_old_04.png` | 512x640 | RGB | P050, P051, P219, P005, P053, P083, P100, P055 |
| `assets/local/portraits/pool/male_old/wanderer_male_old_05.png` | 512x640 | RGB | P050, P051, P220, P005, P053, P054, P094, P055 |
| `assets/local/portraits/pool/male_old/wanderer_male_old_06.png` | 512x640 | RGB | P050, P051, P221, P005, P053, P057, P096, P055 |
| `assets/local/portraits/pool/male_old/wanderer_male_old_07.png` | 512x640 | RGB | P050, P051, P222, P005, P053, P059, P098, P055 |
| `assets/local/portraits/pool/male_old/wanderer_male_old_08.png` | 512x640 | RGB | P050, P051, P223, P005, P053, P061, P100, P055 |
| `assets/local/portraits/pool/male_old/wanderer_male_old_09.png` | 512x640 | RGB | P050, P051, P224, P005, P053, P063, P094, P055 |
| `assets/local/portraits/pool/male_old/wanderer_male_old_10.png` | 512x640 | RGB | P050, P051, P225, P005, P053, P065, P096, P055 |
| `assets/local/portraits/pool/male_young/disciple_male_young_01.png` | 512x640 | RGB | P050, P226, P227, P005, P053, P228 |
| `assets/local/portraits/pool/male_young/disciple_male_young_02.png` | 512x640 | RGB | P050, P229, P230, P005, P053 |
| `assets/local/portraits/pool/male_young/disciple_male_young_03.png` | 512x640 | RGB | P050, P229, P231, P005, P053 |
| `assets/local/portraits/pool/male_young/disciple_male_young_04.png` | 512x640 | RGB | P050, P051, P232, P005, P053, P054 |
| `assets/local/portraits/pool/male_young/disciple_male_young_05.png` | 512x640 | RGB | P050, P051, P233, P005, P053, P057 |
| `assets/local/portraits/pool/male_young/disciple_male_young_06.png` | 512x640 | RGB | P050, P051, P234, P005, P053, P059 |
| `assets/local/portraits/pool/male_young/disciple_male_young_07.png` | 512x640 | RGB | P050, P051, P235, P005, P053, P061 |
| `assets/local/portraits/pool/male_young/disciple_male_young_08.png` | 512x640 | RGB | P050, P051, P236, P005, P053, P063 |
| `assets/local/portraits/pool/male_young/disciple_male_young_09.png` | 512x640 | RGB | P050, P051, P237, P005, P053, P065 |
| `assets/local/portraits/pool/male_young/disciple_male_young_10.png` | 512x640 | RGB | P050, P051, P238, P005, P053, P067 |
| `assets/local/portraits/pool/male_young/disciple_male_young_11.png` | 512x640 | RGB | P050, P051, P239, P005, P053, P069 |
| `assets/local/portraits/pool/male_young/disciple_male_young_12.png` | 512x640 | RGB | P050, P051, P240, P005, P053, P071 |
| `assets/local/portraits/pool/male_young/disciple_male_young_13.png` | 512x640 | RGB | P050, P051, P241, P005, P053, P083 |
| `assets/local/portraits/pool/male_young/disciple_male_young_14.png` | 512x640 | RGB | P050, P051, P242, P005, P053, P054 |
| `assets/local/portraits/pool/male_young/gatherer_male_young_01.png` | 512x640 | RGB | P050, P051, P243, P005, P053, P057, P073 |
| `assets/local/portraits/pool/male_young/gatherer_male_young_02.png` | 512x640 | RGB | P050, P051, P244, P005, P053, P059, P075 |
| `assets/local/portraits/pool/male_young/gatherer_male_young_03.png` | 512x640 | RGB | P050, P051, P245, P005, P053, P061, P077 |
| `assets/local/portraits/pool/male_young/gatherer_male_young_04.png` | 512x640 | RGB | P050, P051, P246, P005, P053, P063, P079 |
| `assets/local/portraits/pool/male_young/trader_male_young_01.png` | 512x640 | RGB | P050, P051, P247, P005, P053, P071 |
| `assets/local/portraits/pool/male_young/trader_male_young_02.png` | 512x640 | RGB | P050, P051, P248, P005, P053, P083, P084 |
| `assets/local/portraits/pool/male_young/trader_male_young_03.png` | 512x640 | RGB | P050, P051, P249, P005, P053, P054, P086 |
| `assets/local/portraits/pool/male_young/visitor_male_young_01.png` | 512x640 | RGB | P050, P051, P250, P005, P053, P065 |
| `assets/local/portraits/pool/male_young/visitor_male_young_02.png` | 512x640 | RGB | P050, P051, P251, P005, P053, P067 |
| `assets/local/portraits/pool/male_young/wanderer_male_young_01.png` | 512x640 | RGB | P050, P051, P252, P005, P053, P057 |
| `assets/local/portraits/pool/male_young/wanderer_male_young_02.png` | 512x640 | RGB | P050, P051, P253, P005, P053, P059 |
| `assets/local/portraits/pool/male_young/wanderer_male_young_03.png` | 512x640 | RGB | P050, P051, P254, P005, P053, P061 |
| `assets/local/portraits/pool/male_young/wanderer_male_young_04.png` | 512x640 | RGB | P050, P051, P255, P005, P053, P063 |
| `assets/local/portraits/pool/male_young/wanderer_male_young_05.png` | 512x640 | RGB | P050, P051, P256, P005, P053, P065 |
| `assets/local/portraits/pool/male_young/wanderer_male_young_06.png` | 512x640 | RGB | P050, P051, P257, P005, P053, P067 |
| `assets/local/portraits/pool/male_young/wanderer_male_young_07.png` | 512x640 | RGB | P050, P051, P258, P005, P053, P069 |

### 提示词原文段落

<details>
<summary>P001</summary>

```text
Use case: stylized-concept. ONE six-pose sprite atlas for 凡途, a Chinese cultivation game.
```

</details>

<details>
<summary>P002</summary>

```text
References: image 1 is official ART STYLE only (auction-list NPC portraits, ignore UI); image 2 is simplified LINEWORK/SHADING only, never copy its character; invent a distinct ordinary original person.
```

</details>

<details>
<summary>P003</summary>

```text
Character: calm adult woman aged 35, soft rectangular face, dark hair neatly rolled with plain silver-grey pin. Canglan water cultivator, matte slate-blue and ivory robe, subtle abstract wave hem, plain slender muted ice-blue jian sword, pushing-palm gestures. Ordinary practical modest adult, distinct face and hairstyle from all named characters; same identity in all cells.
```

</details>

<details>
<summary>P004</summary>

```text
STRICT 3 columns x 2 rows, SIX EQUAL 512x512 cells on EXACT 1536x1024 RGBA canvas. All six complete figures FACE TO IMAGE RIGHT (nose and torso pointing right), one per cell. Keep the full hair, body, all hands and weapon entirely inside the cell with at least 35px transparent margins. Same 6.5-head proportions and figure scale in every cell, feet approximately at 92% cell height. Cell centres x=256,768,1280; top feet y=471 and bottom feet y=983. Pose order TOP LEFT idle relaxed ready stance; TOP MIDDLE prepare gathering power with weight back; TOP RIGHT attack striking forwards to the RIGHT. BOTTOM LEFT cast with hand seal/two fingers; BOTTOM MIDDLE hit recoiling backwards toward LEFT while still facing RIGHT; BOTTOM RIGHT guard defensive stance. Same face, hairstyle and costume in all six poses. True TRANSPARENT background, no backdrop, no checkerboard painting, no floor, no shadow, no particles or light effects, no gridlines and no labels. Crisp silhouettes readable at 220px.
```

</details>

<details>
<summary>P005</summary>

```text
Target the ACTUAL 2D NPC art of Mi Chang Sheng / 觅长生 shown in the official gameplay screenshot, especially the auction portraits, and the newer simplified portrait candidate: fine restrained brown-grey contours, broad opaque flat colors, small calm stylized adult eyes, simple face marks, grouped matte hair shapes, VERY FEW economical robe folds, one subdued shadow tone. Modest ordinary game NPC illustration, not polished modern concept art. Muted jade, slate blue, ivory, grey, brown, restrained warm accents. Keep faces and anatomy natural, not idealized idol clones. No photorealism, semi-realistic rendering, 3D, glossy CGI, cinematic lighting, brocade shine, heavy grain, Western comic-book anatomy, anime moe, chibi or pixel art. No text, lettering, calligraphy, signatures, watermark, labels, UI, frames or logos. Everyone is an adult and modestly dressed.
```

</details>

<details>
<summary>P006</summary>

```text
EXTRA IMPORTANT LAYOUT: draw EACH figure MUCH SMALLER than a full cell, within a 390x390 pixel envelope. Leave at least 50px clear transparent margin on every side, including swords, staff and all flying robe edges. Distinct wide transparent gaps separate ALL six sprites, no overlaps.
```

</details>

<details>
<summary>P007</summary>

```text
Character: calm slender adult man aged 38, straight shoulder-length half-up hair. Canglan water cultivator, matte slate-blue and ivory robe, subtle abstract wave hem, plain slender muted ice-blue jian sword, pushing-palm gestures. Ordinary practical modest adult, distinct face and hairstyle from all named characters; same identity in all cells.
```

</details>

<details>
<summary>P008</summary>

```text
Character: gentle adult woman aged 43, round cheeks, long hair in low bun with wooden pin. Changqing wood cultivator, moss-green layered robe, subtly leaf-shaped hem, vine cord belt, short plain wooden staff and finger seals. Ordinary practical modest adult, distinct face and hairstyle from all named characters; same identity in all cells.
```

</details>

<details>
<summary>P009</summary>

```text
Character: gentle narrow-faced adult man aged 45, simple long braid and plain cloth band. Changqing wood cultivator, moss-green layered robe, subtly leaf-shaped hem, vine cord belt, short plain wooden staff and finger seals. Ordinary practical modest adult, distinct face and hairstyle from all named characters; same identity in all cells.
```

</details>

<details>
<summary>P010</summary>

```text
Character: ordinary adult woman aged 31, half-up hair with simple red cord, rounded face. Chixiao cultivator, matte dark crimson modest robe with muted ember-orange trim and wide sleeves, hand seals and palm strikes, NO weapons or flames/effects. Ordinary practical modest adult, distinct face and hairstyle from all named characters; same identity in all cells.
```

</details>

<details>
<summary>P011</summary>

```text
Character: ordinary adult man aged 33, short tied hair with red cord, straight brows. Chixiao cultivator, matte dark crimson modest robe with muted ember-orange trim and wide sleeves, hand seals and palm strikes, NO weapons or flames/effects. Ordinary practical modest adult, distinct face and hairstyle from all named characters; same identity in all cells.
```

</details>

<details>
<summary>P012</summary>

```text
Character: ordinary adult woman aged 29 with a single high braid loop and small wooden hairpin, blue-grey sash. Qingyun outer disciple, plainer than the player or named female rival, plain ivory outer robe, pale jade trim, simple neat cloth topknot, straight jian sword. Ordinary practical modest adult, distinct face and hairstyle from all named characters; same identity in all cells.
```

</details>

<details>
<summary>P013</summary>

```text
Character: ordinary square-faced adult man aged 26 with cropped side hair and a small topknot, plain blue-grey sash. Qingyun outer disciple, plainer than the player or named female rival, plain ivory outer robe, pale jade trim, simple neat cloth topknot, straight jian sword. Ordinary practical modest adult, distinct face and hairstyle from all named characters; same identity in all cells.
```

</details>

<details>
<summary>P014</summary>

```text
Character: weathered slim adult woman aged 37, tied low braid under a plain cloth head wrap. Unaligned wanderer, worn patched grey-green travelling robe, straw-coloured sash, small cloth bundle tied on back, plain sword. Ordinary practical modest adult, distinct face and hairstyle from all named characters; same identity in all cells.
```

</details>

<details>
<summary>P015</summary>

```text
Character: weathered broad-nosed adult man aged 42, wrapped short hair, sparse moustache. Unaligned wanderer, worn patched grey-green travelling robe, straw-coloured sash, small cloth bundle tied on back, plain sword. Ordinary practical modest adult, distinct face and hairstyle from all named characters; same identity in all cells.
```

</details>

<details>
<summary>P016</summary>

```text
Character: sturdy ordinary adult woman aged 46, broad face and thick eyebrows, compact low bun. Xuanyue earth cultivator, heavy earth-brown robe with subdued ochre trim, broad modest clothing, grounded stance, NO WEAPON, heavy palm strike and stamping prepare. Ordinary practical modest adult, distinct face and hairstyle from all named characters; same identity in all cells.
```

</details>

<details>
<summary>P017</summary>

```text
Character: stocky ordinary adult man aged 48, broad round jaw, short hair with cloth cap, sparse beard. Xuanyue earth cultivator, heavy earth-brown robe with subdued ochre trim, broad modest clothing, grounded stance, NO WEAPON, heavy palm strike and stamping prepare. Ordinary practical modest adult, distinct face and hairstyle from all named characters; same identity in all cells.
```

</details>

<details>
<summary>P018</summary>

```text
References: image 1 is official ART STYLE only (auction-list NPC portraits, ignore UI); image 2 is simplified LINEWORK/SHADING only, never copy its character; image 3 is this named CHARACTER IDENTITY/COSTUME, simplify shading to match style.
```

</details>

<details>
<summary>P019</summary>

```text
Character: Male masked road rogue aged 35, Chixiao outcast. Match the named portrait: narrow cold eyes, black tied-back hair with red cord, cloth mask covering lower face, charcoal robe with muted red trim. Carry a plain straight jian sword; sword lowered idle, drawn back prepare, thrust right attack, left hand makes a spell seal in cast (only a very small flame in that palm is allowed), sword-bearing arm recoils left hit, defensive sword raised guard.
```

</details>

<details>
<summary>P020</summary>

```text

```

</details>

<details>
<summary>P021</summary>

```text
LAYOUT REPAIR PROMPT:
```

</details>

<details>
<summary>P022</summary>

```text
Use case: precise-object-edit. Repair only the SPRITE SHEET LAYOUT of the attached six-pose transparent atlas. Preserve this character's identity, costume, pose meanings, right-facing orientation, hand-drawn flat-color rendering and true alpha.
```

</details>

<details>
<summary>P023</summary>

```text
OUTPUT EXACTLY 1536x1024 RGBA, strict 3 columns x 2 rows of 512x512 cells. SIX separate complete figures.
```

</details>

<details>
<summary>P024</summary>

```text
CRITICAL: SHRINK EVERY WHOLE FIGURE INCLUDING WEAPON BY ABOUT 22 PERCENT compared with the current sheet and reposition it WITHIN ITS OWN CELL. Maximum complete figure-and-weapon bounding box roughly 400px wide and 400px tall. Leave WIDE CLEAR TRANSPARENT SPACE between every neighbouring figure; nothing crosses x512, x1024 or y512. No figure touches any outside border. Top figures feet y471; bottom figures feet y983. Entire hair and sword must be well inside the cell with at least 40px clear margins. Top three centres x256,768,1280; bottom same. The current sword/cloak edges cross grid boundaries: correct that by making the sprites smaller, not by clipping any body or sword. Keep ALL six poses and the full anatomy. Do NOT draw gridlines or backgrounds. No text or effects. Maintain true transparent alpha.
```

</details>

<details>
<summary>P025</summary>

```text
Character: Shi Han, male cave squatter aged 49, Xuanyue outcast. Match the named portrait: rough brown Taoist robe, tied brown-black hair with plain straw cord, small dark moustache/goatee, stony suspicious eyes, broad grounded body. NO WEAPON; bare-hand palm attack to right, heavy stable stamping prepare, hand-seal cast without added stones or effects, recoil left hit, forearm guard.
```

</details>

<details>
<summary>P026</summary>

```text
Use case: stylized-concept. ONE 2D Chinese cultivation side-view duel background, 1792x768 PNG (7:3).
```

</details>

<details>
<summary>P027</summary>

```text
Reference 1 COMPOSITION ONLY: bamboo duel ground; reference 2 OFFICIAL simplified BACKGROUND STYLE only, ignore characters and UI.
```

</details>

<details>
<summary>P028</summary>

```text
Subject: Broad flat sandy riverbank and reed-fringed shallows; reeds ONLY at extreme edges; small wooden pier far right; wide calm river and slate-blue distant mountains behind.
```

</details>

<details>
<summary>P029</summary>

```text
Camera slightly above ground, no extreme perspective. Broad FLAT UNOBSTRUCTED walkable ground across the entire lower part, floor line near 80% image height. Character overlays will stand at x28% and x74%, reaching high into the picture; keep the WHOLE two character zones and centre calm, low contrast, spacious and empty. Scenery only on extreme edges or small/distant background. No bright glow behind the fighters. No text or signs. NO characters, people, animals, monsters, weapons, magic effects, particles, silhouettes or UI.
```

</details>

<details>
<summary>P030</summary>

```text
Environment should use broad simplified painted shapes and restrained washes, not dense realistic foliage textures.
```

</details>

<details>
<summary>P031</summary>

```text
Subject: An open unobstructed stone-paved square outside a market at dusk; closed small Chinese stalls and hanging plain lanterns ONLY at extreme edges; low riverside roofs behind.
```

</details>

<details>
<summary>P032</summary>

```text
Subject: A broad needle-covered forest clearing on a ridge; ancient Chinese pines ONLY framing both outer edges; softly layered ridge lines behind. No buildings.
```

</details>

<details>
<summary>P033</summary>

```text
Subject: A broad flat mountain roadside clearing at a gentle bend; scattered rocks and shrubs only at outer edges; low hills and distant pines behind; neutral daylight, no buildings.
```

</details>

<details>
<summary>P034</summary>

```text
Subject: A broad walkable low stone ledge at the foot of a vine-covered cliff; an old simple stone door only HALF visible at the FAR RIGHT edge; subdued slightly dim stone-green light, calm empty middle.
```

</details>

<details>
<summary>P035</summary>

```text
Subject: A broad pale stone mountain training plaza; LOW railings; sect halls and sea of clouds in the distance, far main peak. Any empty training racks only at extreme outer edges; no weapons in racks.
```

</details>

<details>
<summary>P036</summary>

```text
Subject: Broad packed-earth lane at the edge of a small mortal Chinese town; grey-tiled walls and a willow ONLY at extreme edges; low hills and a few distant roofs behind.
```

</details>

<details>
<summary>P037</summary>

```text
Subject: A broad flat rocky deep valley floor with low mist; a faint jade spring FAR in the background and OFF the two character zones; a few shed crimson serpent scales near edge rocks; subdued rose-gold sunset light HIGH on distant cliffs; uneasy wilderness, no buildings.
```

</details>

<details>
<summary>P038</summary>

```text
Use case: illustration-story. ONE original story event illustration for 凡途, 1600x900 PNG (16:9).
```

</details>

<details>
<summary>P039</summary>

```text
First two reference images are STRICT 2D CHARACTER DRAWING STYLE only, ignore UI and the candidate's identity.
```

</details>

<details>
<summary>P040</summary>

```text
Scene: Qingyun mountain training plaza with plain BLANK sect banners at edges; rows of modest adult outer disciples in plain ivory/slate uniforms watching; two ordinary adult disciples face each other in the centre in sparring stance with simple straight swords; elders seated on a raised distant platform.
```

</details>

<details>
<summary>P041</summary>

```text
Composition: focal action in central 80% width and upper three quarters; bottom QUARTER is quieter low-detail scenery for future text overlay, no text painted. Adults modestly dressed. Keep faces and simple silhouettes clearly readable.
```

</details>

<details>
<summary>P042</summary>

```text
Landscape and rooms use simplified flat shapes and restrained washes. No cinematic spectacle or realistic skin. No readable signs, banners, jade slips or labels.
```

</details>

<details>
<summary>P043</summary>

```text
First two reference images are STRICT 2D CHARACTER DRAWING STYLE only, ignore UI and the candidate's identity. Additional reference is named character/creature IDENTITY only; keep that face, hair, costume and defining traits while simplifying rendering.
```

</details>

<details>
<summary>P044</summary>

```text
Scene: The masked adult male road rogue matching the identity portrait: black tied hair with red cord, lower-face cloth mask, cold eyes, charcoal robe with muted red trim. Standing in the middle of a mountain road, drawn plain straight jian sword, a small orange flame in other palm; viewed from the traveller position.
```

</details>

<details>
<summary>P045</summary>

```text
Scene: A crimson Chinese horned serpent matching the creature reference: red scales, short horns, amber eyes, pale belly, dark red crest, ONE continuous connected coiled body. Coiled across the mouth of Luoxia Valley blocking the passage among broken rocks; head raised, mist and sunset behind; tiny fleeing adult figures for scale. Not a Western dragon.
```

</details>

<details>
<summary>P046</summary>

```text
Scene: He Sangeng, the aged male storyteller matching the identity portrait: tied greying hair, small moustache and goatee, grey-blue plain robe, raised eyebrow and sly smile. He pauses on a small wooden stage raising a folding fan; plain wooden gavel on the table; adult tea drinkers lean forward; rain beyond the window.
```

</details>

<details>
<summary>P047</summary>

```text
Scene: Liu Hanzhou, the pale young adult male swordsman matching the identity portrait: long tied black hair with pale cloth cord, plain slate/ivory robe, restrained blood stain on collar, tired proud expression. Sitting against an old pine beside a forest path, plain sword across his knees, simple dappled light; no gore.
```

</details>

<details>
<summary>P048</summary>

```text
Scene: A small red-lacquered Chinese hall lit by many modest lamps; adult guests in veiled wide-brim bamboo hats seated in rows; a central stand displays a hundred-year lingzhi mushroom on a tray beside a few pills in an open box. Anonymous modest guests, no text.
```

</details>

<details>
<summary>P049</summary>

```text
Scene: Long Chinese market street at night with rows of warm plain lanterns; ordinary wandering adult cultivators display pills and herbs on cloths, small adult figures; busy but calm; signboards entirely blank.
```

</details>

<details>
<summary>P050</summary>

```text
Use case: stylized-concept. ONE original half-body NPC portrait for a 2D Chinese cultivation game, PNG 512x640 (4:5). One person, not a sheet or collage.
```

</details>

<details>
<summary>P051</summary>

```text
References: official screenshot NPC portraits are the ONLY ART STYLE reference. Do NOT copy any particular reference character. Create the distinct person described here.
```

</details>

<details>
<summary>P052</summary>

```text
Subject: An ordinary original Chinese woman, about 35 years old. oval face with high forehead, slightly drooping eyelids, arched brows; single thick braid over one shoulder; quietly curious; average build. Clearly mature ADULT, a few modest age lines and some grey at temples; composed lived-in face. No facial hair. A small subtle facial beauty mark. Qingyun outer disciple: simple matching pale-ivory sect uniform, slate-blue collar and cuffs, blue sash, very faint abstract cloud hem, plain hair cord or wooden pin, simple straight sword hilt partly visible at the hip/back. No fancy embroidery.
```

</details>

<details>
<summary>P053</summary>

```text
Half-body bust, THREE-QUARTER VIEW FACING IMAGE RIGHT, both shoulders and complete head/hair inside with safe margin; face in upper third. Understated original face readable at 120x150. VERY SIMPLE FLAT SKIN, fine contours, at most one light shadow, sparse grouped matte hair strokes, a few broad robe color areas and VERY FEW fold lines. Less detailed than hero concept art. Keep this person's face shape, age, hair and expression distinct from previously made NPCs. Prop small and held low, never hides face. Plain uniform softly muted grey-jade background, no scenery or halo. No dramatic shadow, no text or markings on props, no frame.
```

</details>

<details>
<summary>P054</summary>

```text
PRIORITY UNIQUE IDENTITY: A SOFT OVAL FACE with unusually high forehead, drooping narrow eyelids and fine curved brows; very understated smile lines. Render these distinguishing face proportions visibly, even if plain or unattractive. Do not default to the same handsome narrow-nosed topknot face. Follow the specified hairstyle precisely; do not add a high bun when a crop, cap, wrap, loose hair or low braid is specified. Skin is pale/muted earthy with subtle differences, no glossy facial modelling. This is a new individual, not an edit of any previous portrait.
```

</details>

<details>
<summary>P055</summary>

```text
FINAL IDENTITY CHECK: This is a common villager/cultivator, not a universally attractive hero. The exact face width, jaw outline, nose width and hairstyle specified above MUST determine the drawing. Round or stocky faces must really have noticeably plump cheeks/short wide noses; square faces must have a broad jaw. Avoid giving every person the same long slender face or identical thin goatee. Keep the entire head and BOTH SHOULDERS safely framed. Pure flat soft grey-jade background, no texture speckle.
```

</details>

<details>
<summary>P056</summary>

```text
Subject: An ordinary original Chinese woman, about 42 years old. short sturdy face, low brows, small hooded eyes, broad mouth; two modest braids tied behind; thoughtful and solemn; average build. Clearly mature ADULT, a few modest age lines and some grey at temples; composed lived-in face. No facial hair. No distinctive scars, eyepatch or decorative jewellery. Qingyun outer disciple: simple matching pale-ivory sect uniform, slate-blue collar and cuffs, blue sash, very faint abstract cloud hem, plain hair cord or wooden pin, simple straight sword hilt partly visible at the hip/back. No fancy embroidery.
```

</details>

<details>
<summary>P057</summary>

```text
PRIORITY UNIQUE IDENTITY: A short STOCKY FACE with broad chin, sturdy neck, thick uneven low brows, hooded small eyes and round broad nose. Render these distinguishing face proportions visibly, even if plain or unattractive. Do not default to the same handsome narrow-nosed topknot face. Follow the specified hairstyle precisely; do not add a high bun when a crop, cap, wrap, loose hair or low braid is specified. Skin is pale/muted earthy with subtle differences, no glossy facial modelling. This is a new individual, not an edit of any previous portrait.
```

</details>

<details>
<summary>P058</summary>

```text
Subject: An ordinary original Chinese woman, about 49 years old. narrow triangular adult face, upturned eye corners, fine brows, thin lips; side-part hair in a low knot; quietly curious; average build. Clearly mature ADULT, a few modest age lines and some grey at temples; composed lived-in face. No facial hair. No distinctive scars, eyepatch or decorative jewellery. Qingyun outer disciple: simple matching pale-ivory sect uniform, slate-blue collar and cuffs, blue sash, very faint abstract cloud hem, plain hair cord or wooden pin, simple straight sword hilt partly visible at the hip/back. No fancy embroidery.
```

</details>

<details>
<summary>P059</summary>

```text
PRIORITY UNIQUE IDENTITY: A distinctly NARROW TRIANGULAR ADULT FACE, pointed chin, fine upward brows, small thin lips, long angular ear shapes. Render these distinguishing face proportions visibly, even if plain or unattractive. Do not default to the same handsome narrow-nosed topknot face. Follow the specified hairstyle precisely; do not add a high bun when a crop, cap, wrap, loose hair or low braid is specified. Skin is pale/muted earthy with subtle differences, no glossy facial modelling. This is a new individual, not an edit of any previous portrait.
```

</details>

<details>
<summary>P060</summary>

```text
Subject: An ordinary original Chinese woman, about 36 years old. soft rectangular face, long eyebrows, narrow nose, full lips; low compact bun; thoughtful and solemn; average build. Clearly mature ADULT, a few modest age lines and some grey at temples; composed lived-in face. No facial hair. No distinctive scars, eyepatch or decorative jewellery. Qingyun outer disciple: simple matching pale-ivory sect uniform, slate-blue collar and cuffs, blue sash, very faint abstract cloud hem, plain hair cord or wooden pin, simple straight sword hilt partly visible at the hip/back. No fancy embroidery.
```

</details>

<details>
<summary>P061</summary>

```text
PRIORITY UNIQUE IDENTITY: A RECTANGULAR FACE with BROAD FLAT NOSE, close-set calm eyes, visibly larger ears and full lips; ordinary unglamorous face. Render these distinguishing face proportions visibly, even if plain or unattractive. Do not default to the same handsome narrow-nosed topknot face. Follow the specified hairstyle precisely; do not add a high bun when a crop, cap, wrap, loose hair or low braid is specified. Skin is pale/muted earthy with subtle differences, no glossy facial modelling. This is a new individual, not an edit of any previous portrait.
```

</details>

<details>
<summary>P062</summary>

```text
Subject: An ordinary original Chinese woman, about 43 years old. round full cheeks, relaxed narrow eyes, short uneven brows, small dimple; neatly rolled hair with a wooden pin; quietly curious; average build. Clearly mature ADULT, a few modest age lines and some grey at temples; composed lived-in face. No facial hair. No distinctive scars, eyepatch or decorative jewellery. Qingyun outer disciple: simple matching pale-ivory sect uniform, slate-blue collar and cuffs, blue sash, very faint abstract cloud hem, plain hair cord or wooden pin, simple straight sword hilt partly visible at the hip/back. No fancy embroidery.
```

</details>

<details>
<summary>P063</summary>

```text
PRIORITY UNIQUE IDENTITY: A FULL ROUNDED FACE with plump cheeks, small upturned nose, short uneven brows, modest cheek dimple, tiny relaxed eyes. Render these distinguishing face proportions visibly, even if plain or unattractive. Do not default to the same handsome narrow-nosed topknot face. Follow the specified hairstyle precisely; do not add a high bun when a crop, cap, wrap, loose hair or low braid is specified. Skin is pale/muted earthy with subtle differences, no glossy facial modelling. This is a new individual, not an edit of any previous portrait.
```

</details>

<details>
<summary>P064</summary>

```text
Subject: An ordinary original Chinese woman, about 50 years old. long face with a firm chin, lowered eye corners, broad soft nose; short jaw-length hair tucked behind ears; thoughtful and solemn; average build. Clearly mature ADULT, a few modest age lines and some grey at temples; composed lived-in face. No facial hair. No distinctive scars, eyepatch or decorative jewellery. Qingyun outer disciple: simple matching pale-ivory sect uniform, slate-blue collar and cuffs, blue sash, very faint abstract cloud hem, plain hair cord or wooden pin, simple straight sword hilt partly visible at the hip/back. No fancy embroidery.
```

</details>

<details>
<summary>P065</summary>

```text
PRIORITY UNIQUE IDENTITY: A distinctly LONG FACE with firm cleft chin, drooping eye corners, long low brows and broad soft nose. Render these distinguishing face proportions visibly, even if plain or unattractive. Do not default to the same handsome narrow-nosed topknot face. Follow the specified hairstyle precisely; do not add a high bun when a crop, cap, wrap, loose hair or low braid is specified. Skin is pale/muted earthy with subtle differences, no glossy facial modelling. This is a new individual, not an edit of any previous portrait.
```

</details>

<details>
<summary>P066</summary>

```text
Subject: An ordinary original Chinese woman, about 37 years old. diamond face with softly defined cheekbones, shallow eyelids, thin mouth; long hair in a simple ponytail; quietly curious; average build. Clearly mature ADULT, a few modest age lines and some grey at temples; composed lived-in face. No facial hair. No distinctive scars, eyepatch or decorative jewellery. Qingyun outer disciple: simple matching pale-ivory sect uniform, slate-blue collar and cuffs, blue sash, very faint abstract cloud hem, plain hair cord or wooden pin, simple straight sword hilt partly visible at the hip/back. No fancy embroidery.
```

</details>

<details>
<summary>P067</summary>

```text
PRIORITY UNIQUE IDENTITY: A DIAMOND FACE with high softly drawn cheekbones, small protruding ears, shallow narrow eyelids and a thin straight mouth. Render these distinguishing face proportions visibly, even if plain or unattractive. Do not default to the same handsome narrow-nosed topknot face. Follow the specified hairstyle precisely; do not add a high bun when a crop, cap, wrap, loose hair or low braid is specified. Skin is pale/muted earthy with subtle differences, no glossy facial modelling. This is a new individual, not an edit of any previous portrait.
```

</details>

<details>
<summary>P068</summary>

```text
Subject: An ordinary original Chinese woman, about 44 years old. broad rounded face, small narrow eyes, gently curved brows, short broad nose; half-up shoulder-length hair; thoughtful and solemn; average build. Clearly mature ADULT, a few modest age lines and some grey at temples; composed lived-in face. No facial hair. No distinctive scars, eyepatch or decorative jewellery. Qingyun outer disciple: simple matching pale-ivory sect uniform, slate-blue collar and cuffs, blue sash, very faint abstract cloud hem, plain hair cord or wooden pin, simple straight sword hilt partly visible at the hip/back. No fancy embroidery.
```

</details>

<details>
<summary>P069</summary>

```text
PRIORITY UNIQUE IDENTITY: A distinctly BROAD ROUND FACE with full cheeks, nearly circular jaw, short wide nose, broad neck and small wide-set eyes; do not narrow the jaw. Render these distinguishing face proportions visibly, even if plain or unattractive. Do not default to the same handsome narrow-nosed topknot face. Follow the specified hairstyle precisely; do not add a high bun when a crop, cap, wrap, loose hair or low braid is specified. Skin is pale/muted earthy with subtle differences, no glossy facial modelling. This is a new individual, not an edit of any previous portrait.
```

</details>

<details>
<summary>P070</summary>

```text
Subject: An ordinary original Chinese woman, about 51 years old. long slender face, close-set almond eyes, straight fine brows, small straight nose; small high bun with a simple cloth cord; quietly curious; average build. Clearly mature ADULT, a few modest age lines and some grey at temples; composed lived-in face. No facial hair. No distinctive scars, eyepatch or decorative jewellery. Qingyun outer disciple: simple matching pale-ivory sect uniform, slate-blue collar and cuffs, blue sash, very faint abstract cloud hem, plain hair cord or wooden pin, simple straight sword hilt partly visible at the hip/back. No fancy embroidery.
```

</details>

<details>
<summary>P071</summary>

```text
PRIORITY UNIQUE IDENTITY: A distinctly LONG THIN FACE, high narrow forehead, long simple straight nose, thin mouth, slim neck and close-set tired eyes. Render these distinguishing face proportions visibly, even if plain or unattractive. Do not default to the same handsome narrow-nosed topknot face. Follow the specified hairstyle precisely; do not add a high bun when a crop, cap, wrap, loose hair or low braid is specified. Skin is pale/muted earthy with subtle differences, no glossy facial modelling. This is a new individual, not an edit of any previous portrait.
```

</details>

<details>
<summary>P072</summary>

```text
Subject: An ordinary original Chinese woman, about 43 years old. round full cheeks, relaxed narrow eyes, short uneven brows, small dimple; neatly rolled hair with a wooden pin; quietly curious; average build. Clearly mature ADULT, a few modest age lines and some grey at temples; composed lived-in face. No facial hair. No distinctive scars, eyepatch or decorative jewellery. ordinary herb gatherer: practical modest short robe over trousers, sleeves tied back, rope belt, weathered sun-touched skin. one small plain herb hoe held low.
```

</details>

<details>
<summary>P073</summary>

```text
Specific prop for this individual: a modest herb basket with simple leaves. Follow this prop choice if the earlier role description mentions another. Keep it secondary to the face.
```

</details>

<details>
<summary>P074</summary>

```text
Subject: An ordinary original Chinese woman, about 50 years old. long face with a firm chin, lowered eye corners, broad soft nose; short jaw-length hair tucked behind ears; thoughtful and solemn; average build. Clearly mature ADULT, a few modest age lines and some grey at temples; composed lived-in face. No facial hair. No distinctive scars, eyepatch or decorative jewellery. ordinary herb gatherer: practical modest short robe over trousers, sleeves tied back, rope belt, weathered sun-touched skin. a rope-tied herb basket partly visible.
```

</details>

<details>
<summary>P075</summary>

```text
Specific prop for this individual: one small practical herb hoe held low. Follow this prop choice if the earlier role description mentions another. Keep it secondary to the face.
```

</details>

<details>
<summary>P076</summary>

```text
Subject: An ordinary original Chinese woman, about 37 years old. diamond face with softly defined cheekbones, shallow eyelids, thin mouth; long hair in a simple ponytail; quietly curious; average build. Clearly mature ADULT, a few modest age lines and some grey at temples; composed lived-in face. No facial hair. A small subtle facial beauty mark. ordinary herb gatherer: practical modest short robe over trousers, sleeves tied back, rope belt, weathered sun-touched skin. one small plain herb hoe held low.
```

</details>

<details>
<summary>P077</summary>

```text
Specific prop for this individual: a small rope-tied bundle of herbs. Follow this prop choice if the earlier role description mentions another. Keep it secondary to the face.
```

</details>

<details>
<summary>P078</summary>

```text
Subject: An ordinary original Chinese woman, about 44 years old. broad rounded face, small narrow eyes, gently curved brows, short broad nose; half-up shoulder-length hair; thoughtful and solemn; average build. Clearly mature ADULT, a few modest age lines and some grey at temples; composed lived-in face. No facial hair. No distinctive scars, eyepatch or decorative jewellery. ordinary herb gatherer: practical modest short robe over trousers, sleeves tied back, rope belt, weathered sun-touched skin. a rope-tied herb basket partly visible.
```

</details>

<details>
<summary>P079</summary>

```text
Specific prop for this individual: a partly visible basket with dried roots. Follow this prop choice if the earlier role description mentions another. Keep it secondary to the face.
```

</details>

<details>
<summary>P080</summary>

```text
Subject: An ordinary original Chinese woman, about 41 years old. long slender face, close-set almond eyes, straight fine brows, small straight nose; small high bun with a simple cloth cord; thoughtful and solemn; average build. Clearly mature ADULT, a few modest age lines and some grey at temples; composed lived-in face. No facial hair. No distinctive scars, eyepatch or decorative jewellery. ordinary market cultivator: tidy modest robe in deep green, muted plum or brown, slightly nicer simple trim. modest waist pouches and a plain jade token.
```

</details>

<details>
<summary>P081</summary>

```text
Specific prop for this individual: one small unlabelled ledger held low. Follow this prop choice if the earlier role description mentions another. Keep it secondary to the face.
```

</details>

<details>
<summary>P082</summary>

```text
Subject: An ordinary original Chinese woman, about 48 years old. soft square face, wide-set calm eyes, thick flat brows, small round nose; wrapped hair under a plain travel cloth; quietly curious; average build. Clearly mature ADULT, a few modest age lines and some grey at temples; composed lived-in face. No facial hair. No distinctive scars, eyepatch or decorative jewellery. ordinary market cultivator: tidy modest robe in deep green, muted plum or brown, slightly nicer simple trim. a simple wooden abacus held low.
```

</details>

<details>
<summary>P083</summary>

```text
PRIORITY UNIQUE IDENTITY: A distinctly SQUAT SQUARE FACE with a wide jaw, broad mouth, short forehead, thick straight eyebrows and a blunt small nose. Render these distinguishing face proportions visibly, even if plain or unattractive. Do not default to the same handsome narrow-nosed topknot face. Follow the specified hairstyle precisely; do not add a high bun when a crop, cap, wrap, loose hair or low braid is specified. Skin is pale/muted earthy with subtle differences, no glossy facial modelling. This is a new individual, not an edit of any previous portrait.
```

</details>

<details>
<summary>P084</summary>

```text
Specific prop for this individual: one simple wooden abacus held low. Follow this prop choice if the earlier role description mentions another. Keep it secondary to the face.
```

</details>

<details>
<summary>P085</summary>

```text
Subject: An ordinary original Chinese woman, about 35 years old. oval face with high forehead, slightly drooping eyelids, arched brows; single thick braid over one shoulder; thoughtful and solemn; average build. Clearly mature ADULT, a few modest age lines and some grey at temples; composed lived-in face. No facial hair. No distinctive scars, eyepatch or decorative jewellery. ordinary market cultivator: tidy modest robe in deep green, muted plum or brown, slightly nicer simple trim. modest waist pouches and a plain jade token.
```

</details>

<details>
<summary>P086</summary>

```text
Specific prop for this individual: one plain folded fan. Follow this prop choice if the earlier role description mentions another. Keep it secondary to the face.
```

</details>

<details>
<summary>P087</summary>

```text
Subject: An ordinary original Chinese woman, about 42 years old. short sturdy face, low brows, small hooded eyes, broad mouth; two modest braids tied behind; quietly curious; average build. Clearly mature ADULT, a few modest age lines and some grey at temples; composed lived-in face. No facial hair. No distinctive scars, eyepatch or decorative jewellery. ordinary market cultivator: tidy modest robe in deep green, muted plum or brown, slightly nicer simple trim. a simple wooden abacus held low.
```

</details>

<details>
<summary>P088</summary>

```text
Specific prop for this individual: simple waist pouches with a small jade token. Follow this prop choice if the earlier role description mentions another. Keep it secondary to the face.
```

</details>

<details>
<summary>P089</summary>

```text
Subject: An ordinary original Chinese woman, about 49 years old. narrow triangular adult face, upturned eye corners, fine brows, thin lips; side-part hair in a low knot; thoughtful and solemn; average build. Clearly mature ADULT, a few modest age lines and some grey at temples; composed lived-in face. No facial hair. No distinctive scars, eyepatch or decorative jewellery. ordinary market cultivator: tidy modest robe in deep green, muted plum or brown, slightly nicer simple trim. modest waist pouches and a plain jade token.
```

</details>

<details>
<summary>P090</summary>

```text
Subject: An ordinary original Chinese woman, about 36 years old. soft rectangular face, long eyebrows, narrow nose, full lips; low compact bun; quietly curious; average build. Clearly mature ADULT, a few modest age lines and some grey at temples; composed lived-in face. No facial hair. No distinctive scars, eyepatch or decorative jewellery. ordinary market cultivator: tidy modest robe in deep green, muted plum or brown, slightly nicer simple trim. a simple wooden abacus held low.
```

</details>

<details>
<summary>P091</summary>

```text
Subject: An ordinary original Chinese woman, about 51 years old. long slender face, close-set almond eyes, straight fine brows, small straight nose; small high bun with a simple cloth cord; shy and cautious; average build. Clearly mature ADULT, a few modest age lines and some grey at temples; composed lived-in face. No facial hair. No distinctive scars, eyepatch or decorative jewellery. ordinary Chixiao travelling cultivator: matte muted crimson and charcoal robe, tiny abstract flame-shaped trim, plain red hair cord, confident practical bearing, no magic effects.
```

</details>

<details>
<summary>P092</summary>

```text
Subject: An ordinary original Chinese woman, about 38 years old. soft square face, wide-set calm eyes, thick flat brows, small round nose; wrapped hair under a plain travel cloth; stern but approachable; average build. Clearly mature ADULT, a few modest age lines and some grey at temples; composed lived-in face. No facial hair. No distinctive scars, eyepatch or decorative jewellery. ordinary Chixiao travelling cultivator: matte muted crimson and charcoal robe, tiny abstract flame-shaped trim, plain red hair cord, confident practical bearing, no magic effects.
```

</details>

<details>
<summary>P093</summary>

```text
Subject: An ordinary original Chinese woman, about 38 years old. soft square face, wide-set calm eyes, thick flat brows, small round nose; wrapped hair under a plain travel cloth; proud but ordinary; average build. Clearly mature ADULT, a few modest age lines and some grey at temples; composed lived-in face. No facial hair. No distinctive scars, eyepatch or decorative jewellery. ordinary unaligned wandering cultivator: worn patched travelling robe in grey, brown or ink green, straw-coloured sash. a small wrapped travel bundle.
```

</details>

<details>
<summary>P094</summary>

```text
Specific prop for this individual: one small plain gourd tied at waist. Follow this prop choice if the earlier role description mentions another. Keep it secondary to the face.
```

</details>

<details>
<summary>P095</summary>

```text
Subject: An ordinary original Chinese woman, about 45 years old. oval face with high forehead, slightly drooping eyelids, arched brows; single thick braid over one shoulder; tired and watchful; average build. Clearly mature ADULT, a few modest age lines and some grey at temples; composed lived-in face. No facial hair. No distinctive scars, eyepatch or decorative jewellery. ordinary unaligned wandering cultivator: worn patched travelling robe in grey, brown or ink green, straw-coloured sash. small plain gourd at the waist.
```

</details>

<details>
<summary>P096</summary>

```text
Specific prop for this individual: a plain wooden walking staff held low. Follow this prop choice if the earlier role description mentions another. Keep it secondary to the face.
```

</details>

<details>
<summary>P097</summary>

```text
Subject: An ordinary original Chinese woman, about 52 years old. short sturdy face, low brows, small hooded eyes, broad mouth; two modest braids tied behind; proud but ordinary; average build. Clearly mature ADULT, a few modest age lines and some grey at temples; composed lived-in face. No facial hair. No distinctive scars, eyepatch or decorative jewellery. ordinary unaligned wandering cultivator: worn patched travelling robe in grey, brown or ink green, straw-coloured sash. a small wrapped travel bundle.
```

</details>

<details>
<summary>P098</summary>

```text
Specific prop for this individual: one simple rope-tied travel bundle over shoulder. Follow this prop choice if the earlier role description mentions another. Keep it secondary to the face.
```

</details>

<details>
<summary>P099</summary>

```text
Subject: An ordinary original Chinese woman, about 39 years old. narrow triangular adult face, upturned eye corners, fine brows, thin lips; side-part hair in a low knot; tired and watchful; average build. Clearly mature ADULT, a few modest age lines and some grey at temples; composed lived-in face. No facial hair. No distinctive scars, eyepatch or decorative jewellery. ordinary unaligned wandering cultivator: worn patched travelling robe in grey, brown or ink green, straw-coloured sash. small plain gourd at the waist.
```

</details>

<details>
<summary>P100</summary>

```text
Specific prop for this individual: a plain sheathed sword at hip. Follow this prop choice if the earlier role description mentions another. Keep it secondary to the face.
```

</details>

<details>
<summary>P101</summary>

```text
Subject: An ordinary original Chinese woman, about 46 years old. soft rectangular face, long eyebrows, narrow nose, full lips; low compact bun; proud but ordinary; average build. Clearly mature ADULT, a few modest age lines and some grey at temples; composed lived-in face. No facial hair. A small subtle facial beauty mark. ordinary unaligned wandering cultivator: worn patched travelling robe in grey, brown or ink green, straw-coloured sash. a small wrapped travel bundle.
```

</details>

<details>
<summary>P102</summary>

```text
Subject: An ordinary original Chinese woman, about 53 years old. round full cheeks, relaxed narrow eyes, short uneven brows, small dimple; neatly rolled hair with a wooden pin; tired and watchful; average build. Clearly mature ADULT, a few modest age lines and some grey at temples; composed lived-in face. No facial hair. No distinctive scars, eyepatch or decorative jewellery. ordinary unaligned wandering cultivator: worn patched travelling robe in grey, brown or ink green, straw-coloured sash. small plain gourd at the waist.
```

</details>

<details>
<summary>P103</summary>

```text
Subject: An ordinary original Chinese woman, about 40 years old. long face with a firm chin, lowered eye corners, broad soft nose; short jaw-length hair tucked behind ears; proud but ordinary; average build. Clearly mature ADULT, a few modest age lines and some grey at temples; composed lived-in face. No facial hair. No distinctive scars, eyepatch or decorative jewellery. ordinary unaligned wandering cultivator: worn patched travelling robe in grey, brown or ink green, straw-coloured sash. a small wrapped travel bundle.
```

</details>

<details>
<summary>P104</summary>

```text
Subject: An ordinary original Chinese woman, about 47 years old. diamond face with softly defined cheekbones, shallow eyelids, thin mouth; long hair in a simple ponytail; tired and watchful; average build. Clearly mature ADULT, a few modest age lines and some grey at temples; composed lived-in face. No facial hair. No distinctive scars, eyepatch or decorative jewellery. ordinary unaligned wandering cultivator: worn patched travelling robe in grey, brown or ink green, straw-coloured sash. small plain gourd at the waist.
```

</details>

<details>
<summary>P105</summary>

```text
Subject: An ordinary original Chinese woman, about 54 years old. broad rounded face, small narrow eyes, gently curved brows, short broad nose; half-up shoulder-length hair; proud but ordinary; average build. Clearly mature ADULT, a few modest age lines and some grey at temples; composed lived-in face. No facial hair. A small healed eyebrow scar. ordinary unaligned wandering cultivator: worn patched travelling robe in grey, brown or ink green, straw-coloured sash. a small wrapped travel bundle.
```

</details>

<details>
<summary>P106</summary>

```text
Subject: An ordinary original Chinese woman, about 55 years old. narrow triangular adult face, upturned eye corners, fine brows, thin lips; neatly rolled hair with a wooden pin; quietly curious; average build. Clearly ELDERLY adult, grey or white matte hair, visibly aged brows and understated wrinkles at eyes and mouth; do NOT make this person look young. Avoid realistic skin texture. No facial hair. A small subtle facial beauty mark. Qingyun outer disciple: simple matching pale-ivory sect uniform, slate-blue collar and cuffs, blue sash, very faint abstract cloud hem, plain hair cord or wooden pin, simple straight sword hilt partly visible at the hip/back. No fancy embroidery.
```

</details>

<details>
<summary>P107</summary>

```text
Subject: An ordinary original Chinese woman, about 64 years old. soft rectangular face, long eyebrows, narrow nose, full lips; short jaw-length hair tucked behind ears; thoughtful and solemn; sturdy build. Clearly ELDERLY adult, grey or white matte hair, visibly aged brows and understated wrinkles at eyes and mouth; do NOT make this person look young. Avoid realistic skin texture. No facial hair. No distinctive scars, eyepatch or decorative jewellery. Qingyun outer disciple: simple matching pale-ivory sect uniform, slate-blue collar and cuffs, blue sash, very faint abstract cloud hem, plain hair cord or wooden pin, simple straight sword hilt partly visible at the hip/back. No fancy embroidery.
```

</details>

<details>
<summary>P108</summary>

```text
Subject: An ordinary original Chinese woman, about 73 years old. round full cheeks, relaxed narrow eyes, short uneven brows, small dimple; long hair in a simple ponytail; quietly curious; average build. Clearly ELDERLY adult, grey or white matte hair, visibly aged brows and understated wrinkles at eyes and mouth; do NOT make this person look young. Avoid realistic skin texture. No facial hair. No distinctive scars, eyepatch or decorative jewellery. Qingyun outer disciple: simple matching pale-ivory sect uniform, slate-blue collar and cuffs, blue sash, very faint abstract cloud hem, plain hair cord or wooden pin, simple straight sword hilt partly visible at the hip/back. No fancy embroidery.
```

</details>

<details>
<summary>P109</summary>

```text
Subject: An ordinary original Chinese woman, about 82 years old. long face with a firm chin, lowered eye corners, broad soft nose; half-up shoulder-length hair; thoughtful and solemn; sturdy build. Clearly ELDERLY adult, grey or white matte hair, visibly aged brows and understated wrinkles at eyes and mouth; do NOT make this person look young. Avoid realistic skin texture. No facial hair. No distinctive scars, eyepatch or decorative jewellery. Qingyun outer disciple: simple matching pale-ivory sect uniform, slate-blue collar and cuffs, blue sash, very faint abstract cloud hem, plain hair cord or wooden pin, simple straight sword hilt partly visible at the hip/back. No fancy embroidery.
```

</details>

<details>
<summary>P110</summary>

```text
Subject: An ordinary original Chinese woman, about 55 years old. diamond face with softly defined cheekbones, shallow eyelids, thin mouth; small high bun with a simple cloth cord; quietly curious; average build. Clearly ELDERLY adult, grey or white matte hair, visibly aged brows and understated wrinkles at eyes and mouth; do NOT make this person look young. Avoid realistic skin texture. No facial hair. No distinctive scars, eyepatch or decorative jewellery. Qingyun outer disciple: simple matching pale-ivory sect uniform, slate-blue collar and cuffs, blue sash, very faint abstract cloud hem, plain hair cord or wooden pin, simple straight sword hilt partly visible at the hip/back. No fancy embroidery.
```

</details>

<details>
<summary>P111</summary>

```text
Subject: An ordinary original Chinese woman, about 64 years old. broad rounded face, small narrow eyes, gently curved brows, short broad nose; wrapped hair under a plain travel cloth; thoughtful and solemn; sturdy build. Clearly ELDERLY adult, grey or white matte hair, visibly aged brows and understated wrinkles at eyes and mouth; do NOT make this person look young. Avoid realistic skin texture. No facial hair. No distinctive scars, eyepatch or decorative jewellery. Qingyun outer disciple: simple matching pale-ivory sect uniform, slate-blue collar and cuffs, blue sash, very faint abstract cloud hem, plain hair cord or wooden pin, simple straight sword hilt partly visible at the hip/back. No fancy embroidery.
```

</details>

<details>
<summary>P112</summary>

```text
Subject: An ordinary original Chinese woman, about 73 years old. long slender face, close-set almond eyes, straight fine brows, small straight nose; single thick braid over one shoulder; quietly curious; average build. Clearly ELDERLY adult, grey or white matte hair, visibly aged brows and understated wrinkles at eyes and mouth; do NOT make this person look young. Avoid realistic skin texture. No facial hair. No distinctive scars, eyepatch or decorative jewellery. Qingyun outer disciple: simple matching pale-ivory sect uniform, slate-blue collar and cuffs, blue sash, very faint abstract cloud hem, plain hair cord or wooden pin, simple straight sword hilt partly visible at the hip/back. No fancy embroidery.
```

</details>

<details>
<summary>P113</summary>

```text
Subject: An ordinary original Chinese woman, about 82 years old. long face with a firm chin, lowered eye corners, broad soft nose; half-up shoulder-length hair; friendly half-smile; sturdy build. Clearly ELDERLY adult, grey or white matte hair, visibly aged brows and understated wrinkles at eyes and mouth; do NOT make this person look young. Avoid realistic skin texture. No facial hair. No distinctive scars, eyepatch or decorative jewellery. ordinary herb gatherer: practical modest short robe over trousers, sleeves tied back, rope belt, weathered sun-touched skin. a modest herb basket with simple leaves.
```

</details>

<details>
<summary>P114</summary>

```text
Subject: An ordinary original Chinese woman, about 55 years old. diamond face with softly defined cheekbones, shallow eyelids, thin mouth; small high bun with a simple cloth cord; reserved faint smile; average build. Clearly ELDERLY adult, grey or white matte hair, visibly aged brows and understated wrinkles at eyes and mouth; do NOT make this person look young. Avoid realistic skin texture. No facial hair. No distinctive scars, eyepatch or decorative jewellery. ordinary herb gatherer: practical modest short robe over trousers, sleeves tied back, rope belt, weathered sun-touched skin. a small bundle of dried herbs.
```

</details>

<details>
<summary>P115</summary>

```text
Subject: An ordinary original Chinese woman, about 64 years old. broad rounded face, small narrow eyes, gently curved brows, short broad nose; wrapped hair under a plain travel cloth; friendly half-smile; sturdy build. Clearly ELDERLY adult, grey or white matte hair, visibly aged brows and understated wrinkles at eyes and mouth; do NOT make this person look young. Avoid realistic skin texture. No facial hair. No distinctive scars, eyepatch or decorative jewellery. ordinary herb gatherer: practical modest short robe over trousers, sleeves tied back, rope belt, weathered sun-touched skin. a modest herb basket with simple leaves.
```

</details>

<details>
<summary>P116</summary>

```text
Subject: An ordinary original Chinese woman, about 73 years old. long slender face, close-set almond eyes, straight fine brows, small straight nose; single thick braid over one shoulder; reserved faint smile; average build. Clearly ELDERLY adult, grey or white matte hair, visibly aged brows and understated wrinkles at eyes and mouth; do NOT make this person look young. Avoid realistic skin texture. No facial hair. A small subtle facial beauty mark. ordinary herb gatherer: practical modest short robe over trousers, sleeves tied back, rope belt, weathered sun-touched skin. a small bundle of dried herbs.
```

</details>

<details>
<summary>P117</summary>

```text
Subject: An ordinary original Chinese woman, about 82 years old. soft square face, wide-set calm eyes, thick flat brows, small round nose; two modest braids tied behind; friendly half-smile; sturdy build. Clearly ELDERLY adult, grey or white matte hair, visibly aged brows and understated wrinkles at eyes and mouth; do NOT make this person look young. Avoid realistic skin texture. No facial hair. No distinctive scars, eyepatch or decorative jewellery. ordinary herb gatherer: practical modest short robe over trousers, sleeves tied back, rope belt, weathered sun-touched skin. a modest herb basket with simple leaves.
```

</details>

<details>
<summary>P118</summary>

```text
Subject: An ordinary original Chinese woman, about 64 years old. soft square face, wide-set calm eyes, thick flat brows, small round nose; two modest braids tied behind; reserved faint smile; sturdy build. Clearly ELDERLY adult, grey or white matte hair, visibly aged brows and understated wrinkles at eyes and mouth; do NOT make this person look young. Avoid realistic skin texture. No facial hair. A small healed eyebrow scar. ordinary market cultivator: tidy modest robe in deep green, muted plum or brown, slightly nicer simple trim. a plain folded fan.
```

</details>

<details>
<summary>P119</summary>

```text
Subject: An ordinary original Chinese woman, about 73 years old. oval face with high forehead, slightly drooping eyelids, arched brows; side-part hair in a low knot; friendly half-smile; average build. Clearly ELDERLY adult, grey or white matte hair, visibly aged brows and understated wrinkles at eyes and mouth; do NOT make this person look young. Avoid realistic skin texture. No facial hair. No distinctive scars, eyepatch or decorative jewellery. ordinary market cultivator: tidy modest robe in deep green, muted plum or brown, slightly nicer simple trim. one small unlabelled ledger held low.
```

</details>

<details>
<summary>P120</summary>

```text
Subject: An ordinary original Chinese woman, about 82 years old. short sturdy face, low brows, small hooded eyes, broad mouth; low compact bun; reserved faint smile; sturdy build. Clearly ELDERLY adult, grey or white matte hair, visibly aged brows and understated wrinkles at eyes and mouth; do NOT make this person look young. Avoid realistic skin texture. No facial hair. No distinctive scars, eyepatch or decorative jewellery. ordinary market cultivator: tidy modest robe in deep green, muted plum or brown, slightly nicer simple trim. a plain folded fan.
```

</details>

<details>
<summary>P121</summary>

```text
Subject: An ordinary original Chinese woman, about 55 years old. narrow triangular adult face, upturned eye corners, fine brows, thin lips; neatly rolled hair with a wooden pin; friendly half-smile; average build. Clearly ELDERLY adult, grey or white matte hair, visibly aged brows and understated wrinkles at eyes and mouth; do NOT make this person look young. Avoid realistic skin texture. No facial hair. No distinctive scars, eyepatch or decorative jewellery. ordinary market cultivator: tidy modest robe in deep green, muted plum or brown, slightly nicer simple trim. one small unlabelled ledger held low.
```

</details>

<details>
<summary>P122</summary>

```text
Subject: An ordinary original Chinese woman, about 64 years old. soft rectangular face, long eyebrows, narrow nose, full lips; short jaw-length hair tucked behind ears; reserved faint smile; sturdy build. Clearly ELDERLY adult, grey or white matte hair, visibly aged brows and understated wrinkles at eyes and mouth; do NOT make this person look young. Avoid realistic skin texture. No facial hair. No distinctive scars, eyepatch or decorative jewellery. ordinary market cultivator: tidy modest robe in deep green, muted plum or brown, slightly nicer simple trim. a plain folded fan.
```

</details>

<details>
<summary>P123</summary>

```text
Subject: An ordinary original Chinese woman, about 73 years old. round full cheeks, relaxed narrow eyes, short uneven brows, small dimple; long hair in a simple ponytail; friendly half-smile; average build. Clearly ELDERLY adult, grey or white matte hair, visibly aged brows and understated wrinkles at eyes and mouth; do NOT make this person look young. Avoid realistic skin texture. No facial hair. No distinctive scars, eyepatch or decorative jewellery. ordinary market cultivator: tidy modest robe in deep green, muted plum or brown, slightly nicer simple trim. one small unlabelled ledger held low.
```

</details>

<details>
<summary>P124</summary>

```text
Subject: An ordinary original Chinese woman, about 55 years old. oval face with high forehead, slightly drooping eyelids, arched brows; side-part hair in a low knot; shy and cautious; average build. Clearly ELDERLY adult, grey or white matte hair, visibly aged brows and understated wrinkles at eyes and mouth; do NOT make this person look young. Avoid realistic skin texture. No facial hair. No distinctive scars, eyepatch or decorative jewellery. ordinary Chixiao travelling cultivator: matte muted crimson and charcoal robe, tiny abstract flame-shaped trim, plain red hair cord, confident practical bearing, no magic effects.
```

</details>

<details>
<summary>P125</summary>

```text
Subject: An ordinary original Chinese woman, about 64 years old. short sturdy face, low brows, small hooded eyes, broad mouth; low compact bun; stern but approachable; sturdy build. Clearly ELDERLY adult, grey or white matte hair, visibly aged brows and understated wrinkles at eyes and mouth; do NOT make this person look young. Avoid realistic skin texture. No facial hair. No distinctive scars, eyepatch or decorative jewellery. ordinary Chixiao travelling cultivator: matte muted crimson and charcoal robe, tiny abstract flame-shaped trim, plain red hair cord, confident practical bearing, no magic effects.
```

</details>

<details>
<summary>P126</summary>

```text
Subject: An ordinary original Chinese woman, about 82 years old. soft square face, wide-set calm eyes, thick flat brows, small round nose; two modest braids tied behind; earnest and attentive; sturdy build. Clearly ELDERLY adult, grey or white matte hair, visibly aged brows and understated wrinkles at eyes and mouth; do NOT make this person look young. Avoid realistic skin texture. No facial hair. No distinctive scars, eyepatch or decorative jewellery. ordinary unaligned wandering cultivator: worn patched travelling robe in grey, brown or ink green, straw-coloured sash. small plain gourd at the waist.
```

</details>

<details>
<summary>P127</summary>

```text
Subject: An ordinary original Chinese woman, about 55 years old. oval face with high forehead, slightly drooping eyelids, arched brows; side-part hair in a low knot; mildly suspicious; average build. Clearly ELDERLY adult, grey or white matte hair, visibly aged brows and understated wrinkles at eyes and mouth; do NOT make this person look young. Avoid realistic skin texture. No facial hair. No distinctive scars, eyepatch or decorative jewellery. ordinary unaligned wandering cultivator: worn patched travelling robe in grey, brown or ink green, straw-coloured sash. a small wrapped travel bundle.
```

</details>

<details>
<summary>P128</summary>

```text
Subject: An ordinary original Chinese woman, about 64 years old. short sturdy face, low brows, small hooded eyes, broad mouth; low compact bun; earnest and attentive; sturdy build. Clearly ELDERLY adult, grey or white matte hair, visibly aged brows and understated wrinkles at eyes and mouth; do NOT make this person look young. Avoid realistic skin texture. No facial hair. No distinctive scars, eyepatch or decorative jewellery. ordinary unaligned wandering cultivator: worn patched travelling robe in grey, brown or ink green, straw-coloured sash. small plain gourd at the waist.
```

</details>

<details>
<summary>P129</summary>

```text
Subject: An ordinary original Chinese woman, about 73 years old. narrow triangular adult face, upturned eye corners, fine brows, thin lips; neatly rolled hair with a wooden pin; mildly suspicious; average build. Clearly ELDERLY adult, grey or white matte hair, visibly aged brows and understated wrinkles at eyes and mouth; do NOT make this person look young. Avoid realistic skin texture. No facial hair. No distinctive scars, eyepatch or decorative jewellery. ordinary unaligned wandering cultivator: worn patched travelling robe in grey, brown or ink green, straw-coloured sash. a small wrapped travel bundle.
```

</details>

<details>
<summary>P130</summary>

```text
Subject: An ordinary original Chinese woman, about 82 years old. soft rectangular face, long eyebrows, narrow nose, full lips; short jaw-length hair tucked behind ears; earnest and attentive; sturdy build. Clearly ELDERLY adult, grey or white matte hair, visibly aged brows and understated wrinkles at eyes and mouth; do NOT make this person look young. Avoid realistic skin texture. No facial hair. No distinctive scars, eyepatch or decorative jewellery. ordinary unaligned wandering cultivator: worn patched travelling robe in grey, brown or ink green, straw-coloured sash. small plain gourd at the waist.
```

</details>

<details>
<summary>P131</summary>

```text
Subject: An ordinary original Chinese woman, about 55 years old. round full cheeks, relaxed narrow eyes, short uneven brows, small dimple; long hair in a simple ponytail; mildly suspicious; average build. Clearly ELDERLY adult, grey or white matte hair, visibly aged brows and understated wrinkles at eyes and mouth; do NOT make this person look young. Avoid realistic skin texture. No facial hair. No distinctive scars, eyepatch or decorative jewellery. ordinary unaligned wandering cultivator: worn patched travelling robe in grey, brown or ink green, straw-coloured sash. a small wrapped travel bundle.
```

</details>

<details>
<summary>P132</summary>

```text
Subject: An ordinary original Chinese woman, about 64 years old. long face with a firm chin, lowered eye corners, broad soft nose; half-up shoulder-length hair; earnest and attentive; sturdy build. Clearly ELDERLY adult, grey or white matte hair, visibly aged brows and understated wrinkles at eyes and mouth; do NOT make this person look young. Avoid realistic skin texture. No facial hair. A small subtle facial beauty mark. ordinary unaligned wandering cultivator: worn patched travelling robe in grey, brown or ink green, straw-coloured sash. small plain gourd at the waist.
```

</details>

<details>
<summary>P133</summary>

```text
Subject: An ordinary original Chinese woman, about 73 years old. diamond face with softly defined cheekbones, shallow eyelids, thin mouth; small high bun with a simple cloth cord; mildly suspicious; average build. Clearly ELDERLY adult, grey or white matte hair, visibly aged brows and understated wrinkles at eyes and mouth; do NOT make this person look young. Avoid realistic skin texture. No facial hair. No distinctive scars, eyepatch or decorative jewellery. ordinary unaligned wandering cultivator: worn patched travelling robe in grey, brown or ink green, straw-coloured sash. a small wrapped travel bundle.
```

</details>

<details>
<summary>P134</summary>

```text
Subject: An ordinary original Chinese woman, about 82 years old. broad rounded face, small narrow eyes, gently curved brows, short broad nose; wrapped hair under a plain travel cloth; earnest and attentive; sturdy build. Clearly ELDERLY adult, grey or white matte hair, visibly aged brows and understated wrinkles at eyes and mouth; do NOT make this person look young. Avoid realistic skin texture. No facial hair. No distinctive scars, eyepatch or decorative jewellery. ordinary unaligned wandering cultivator: worn patched travelling robe in grey, brown or ink green, straw-coloured sash. small plain gourd at the waist.
```

</details>

<details>
<summary>P135</summary>

```text
Subject: An ordinary original Chinese woman, about 55 years old. long slender face, close-set almond eyes, straight fine brows, small straight nose; single thick braid over one shoulder; mildly suspicious; average build. Clearly ELDERLY adult, grey or white matte hair, visibly aged brows and understated wrinkles at eyes and mouth; do NOT make this person look young. Avoid realistic skin texture. No facial hair. No distinctive scars, eyepatch or decorative jewellery. ordinary unaligned wandering cultivator: worn patched travelling robe in grey, brown or ink green, straw-coloured sash. a small wrapped travel bundle.
```

</details>

<details>
<summary>P136</summary>

```text
Subject: An ordinary original Chinese woman, about 18 years old. oval face with high forehead, slightly drooping eyelids, arched brows; low compact bun; quietly curious; modestly heavy build. Clearly young ADULT, smooth face, dark matte hair; not childlike or glamorous. No facial hair. A small subtle facial beauty mark. Qingyun outer disciple: simple matching pale-ivory sect uniform, slate-blue collar and cuffs, blue sash, very faint abstract cloud hem, plain hair cord or wooden pin, simple straight sword hilt partly visible at the hip/back. No fancy embroidery.
```

</details>

<details>
<summary>P137</summary>

```text
Subject: An ordinary original Chinese woman, about 23 years old. short sturdy face, low brows, small hooded eyes, broad mouth; neatly rolled hair with a wooden pin; thoughtful and solemn; slim build. Clearly young ADULT, smooth face, dark matte hair; not childlike or glamorous. No facial hair. No distinctive scars, eyepatch or decorative jewellery. Qingyun outer disciple: simple matching pale-ivory sect uniform, slate-blue collar and cuffs, blue sash, very faint abstract cloud hem, plain hair cord or wooden pin, simple straight sword hilt partly visible at the hip/back. No fancy embroidery.
```

</details>

<details>
<summary>P138</summary>

```text
Subject: An ordinary original Chinese woman, about 28 years old. narrow triangular adult face, upturned eye corners, fine brows, thin lips; short jaw-length hair tucked behind ears; quietly curious; modestly heavy build. Clearly young ADULT, smooth face, dark matte hair; not childlike or glamorous. No facial hair. No distinctive scars, eyepatch or decorative jewellery. Qingyun outer disciple: simple matching pale-ivory sect uniform, slate-blue collar and cuffs, blue sash, very faint abstract cloud hem, plain hair cord or wooden pin, simple straight sword hilt partly visible at the hip/back. No fancy embroidery.
```

</details>

<details>
<summary>P139</summary>

```text
Subject: An ordinary original Chinese woman, about 33 years old. soft rectangular face, long eyebrows, narrow nose, full lips; long hair in a simple ponytail; thoughtful and solemn; slim build. Clearly young ADULT, smooth face, dark matte hair; not childlike or glamorous. No facial hair. No distinctive scars, eyepatch or decorative jewellery. Qingyun outer disciple: simple matching pale-ivory sect uniform, slate-blue collar and cuffs, blue sash, very faint abstract cloud hem, plain hair cord or wooden pin, simple straight sword hilt partly visible at the hip/back. No fancy embroidery.
```

</details>

<details>
<summary>P140</summary>

```text
Subject: An ordinary original Chinese woman, about 21 years old. round full cheeks, relaxed narrow eyes, short uneven brows, small dimple; half-up shoulder-length hair; quietly curious; sturdy build. Clearly young ADULT, smooth face, dark matte hair; not childlike or glamorous. No facial hair. No distinctive scars, eyepatch or decorative jewellery. Qingyun outer disciple: simple matching pale-ivory sect uniform, slate-blue collar and cuffs, blue sash, very faint abstract cloud hem, plain hair cord or wooden pin, simple straight sword hilt partly visible at the hip/back. No fancy embroidery.
```

</details>

<details>
<summary>P141</summary>

```text
Subject: An ordinary original Chinese woman, about 26 years old. long face with a firm chin, lowered eye corners, broad soft nose; small high bun with a simple cloth cord; thoughtful and solemn; average build. Clearly young ADULT, smooth face, dark matte hair; not childlike or glamorous. No facial hair. No distinctive scars, eyepatch or decorative jewellery. Qingyun outer disciple: simple matching pale-ivory sect uniform, slate-blue collar and cuffs, blue sash, very faint abstract cloud hem, plain hair cord or wooden pin, simple straight sword hilt partly visible at the hip/back. No fancy embroidery.
```

</details>

<details>
<summary>P142</summary>

```text
Subject: An ordinary original Chinese woman, about 31 years old. diamond face with softly defined cheekbones, shallow eyelids, thin mouth; wrapped hair under a plain travel cloth; quietly curious; sturdy build. Clearly young ADULT, smooth face, dark matte hair; not childlike or glamorous. No facial hair. No distinctive scars, eyepatch or decorative jewellery. Qingyun outer disciple: simple matching pale-ivory sect uniform, slate-blue collar and cuffs, blue sash, very faint abstract cloud hem, plain hair cord or wooden pin, simple straight sword hilt partly visible at the hip/back. No fancy embroidery.
```

</details>

<details>
<summary>P143</summary>

```text
Subject: An ordinary original Chinese woman, about 19 years old. broad rounded face, small narrow eyes, gently curved brows, short broad nose; single thick braid over one shoulder; thoughtful and solemn; modestly heavy build. Clearly young ADULT, smooth face, dark matte hair; not childlike or glamorous. No facial hair. No distinctive scars, eyepatch or decorative jewellery. Qingyun outer disciple: simple matching pale-ivory sect uniform, slate-blue collar and cuffs, blue sash, very faint abstract cloud hem, plain hair cord or wooden pin, simple straight sword hilt partly visible at the hip/back. No fancy embroidery.
```

</details>

<details>
<summary>P144</summary>

```text
Subject: An ordinary original Chinese woman, about 24 years old. long slender face, close-set almond eyes, straight fine brows, small straight nose; two modest braids tied behind; quietly curious; slim build. Clearly young ADULT, smooth face, dark matte hair; not childlike or glamorous. No facial hair. No distinctive scars, eyepatch or decorative jewellery. Qingyun outer disciple: simple matching pale-ivory sect uniform, slate-blue collar and cuffs, blue sash, very faint abstract cloud hem, plain hair cord or wooden pin, simple straight sword hilt partly visible at the hip/back. No fancy embroidery.
```

</details>

<details>
<summary>P145</summary>

```text
Subject: An ordinary original Chinese woman, about 29 years old. soft square face, wide-set calm eyes, thick flat brows, small round nose; side-part hair in a low knot; thoughtful and solemn; modestly heavy build. Clearly young ADULT, smooth face, dark matte hair; not childlike or glamorous. No facial hair. No distinctive scars, eyepatch or decorative jewellery. Qingyun outer disciple: simple matching pale-ivory sect uniform, slate-blue collar and cuffs, blue sash, very faint abstract cloud hem, plain hair cord or wooden pin, simple straight sword hilt partly visible at the hip/back. No fancy embroidery.
```

</details>

<details>
<summary>P146</summary>

```text
Subject: An ordinary original Chinese woman, about 34 years old. oval face with high forehead, slightly drooping eyelids, arched brows; low compact bun; quietly curious; slim build. Clearly young ADULT, smooth face, dark matte hair; not childlike or glamorous. No facial hair. No distinctive scars, eyepatch or decorative jewellery. Qingyun outer disciple: simple matching pale-ivory sect uniform, slate-blue collar and cuffs, blue sash, very faint abstract cloud hem, plain hair cord or wooden pin, simple straight sword hilt partly visible at the hip/back. No fancy embroidery.
```

</details>

<details>
<summary>P147</summary>

```text
Subject: An ordinary original Chinese woman, about 22 years old. short sturdy face, low brows, small hooded eyes, broad mouth; neatly rolled hair with a wooden pin; thoughtful and solemn; sturdy build. Clearly young ADULT, smooth face, dark matte hair; not childlike or glamorous. No facial hair. No distinctive scars, eyepatch or decorative jewellery. Qingyun outer disciple: simple matching pale-ivory sect uniform, slate-blue collar and cuffs, blue sash, very faint abstract cloud hem, plain hair cord or wooden pin, simple straight sword hilt partly visible at the hip/back. No fancy embroidery.
```

</details>

<details>
<summary>P148</summary>

```text
Subject: An ordinary original Chinese woman, about 27 years old. narrow triangular adult face, upturned eye corners, fine brows, thin lips; short jaw-length hair tucked behind ears; quietly curious; average build. Clearly young ADULT, smooth face, dark matte hair; not childlike or glamorous. No facial hair. No distinctive scars, eyepatch or decorative jewellery. Qingyun outer disciple: simple matching pale-ivory sect uniform, slate-blue collar and cuffs, blue sash, very faint abstract cloud hem, plain hair cord or wooden pin, simple straight sword hilt partly visible at the hip/back. No fancy embroidery.
```

</details>

<details>
<summary>P149</summary>

```text
Subject: An ordinary original Chinese woman, about 32 years old. soft rectangular face, long eyebrows, narrow nose, full lips; long hair in a simple ponytail; thoughtful and solemn; sturdy build. Clearly young ADULT, smooth face, dark matte hair; not childlike or glamorous. No facial hair. A small subtle facial beauty mark. Qingyun outer disciple: simple matching pale-ivory sect uniform, slate-blue collar and cuffs, blue sash, very faint abstract cloud hem, plain hair cord or wooden pin, simple straight sword hilt partly visible at the hip/back. No fancy embroidery.
```

</details>

<details>
<summary>P150</summary>

```text
Subject: An ordinary original Chinese woman, about 19 years old. round full cheeks, relaxed narrow eyes, short uneven brows, small dimple; half-up shoulder-length hair; quietly curious; average build. Clearly young ADULT, smooth face, dark matte hair; not childlike or glamorous. No facial hair. No distinctive scars, eyepatch or decorative jewellery. ordinary herb gatherer: practical modest short robe over trousers, sleeves tied back, rope belt, weathered sun-touched skin. one small plain herb hoe held low.
```

</details>

<details>
<summary>P151</summary>

```text
Subject: An ordinary original Chinese woman, about 24 years old. long face with a firm chin, lowered eye corners, broad soft nose; small high bun with a simple cloth cord; thoughtful and solemn; sturdy build. Clearly young ADULT, smooth face, dark matte hair; not childlike or glamorous. No facial hair. No distinctive scars, eyepatch or decorative jewellery. ordinary herb gatherer: practical modest short robe over trousers, sleeves tied back, rope belt, weathered sun-touched skin. a rope-tied herb basket partly visible.
```

</details>

<details>
<summary>P152</summary>

```text
Subject: An ordinary original Chinese woman, about 29 years old. diamond face with softly defined cheekbones, shallow eyelids, thin mouth; wrapped hair under a plain travel cloth; quietly curious; average build. Clearly young ADULT, smooth face, dark matte hair; not childlike or glamorous. No facial hair. A small subtle facial beauty mark. ordinary herb gatherer: practical modest short robe over trousers, sleeves tied back, rope belt, weathered sun-touched skin. one small plain herb hoe held low.
```

</details>

<details>
<summary>P153</summary>

```text
Subject: An ordinary original Chinese woman, about 34 years old. broad rounded face, small narrow eyes, gently curved brows, short broad nose; single thick braid over one shoulder; thoughtful and solemn; sturdy build. Clearly young ADULT, smooth face, dark matte hair; not childlike or glamorous. No facial hair. No distinctive scars, eyepatch or decorative jewellery. ordinary herb gatherer: practical modest short robe over trousers, sleeves tied back, rope belt, weathered sun-touched skin. a rope-tied herb basket partly visible.
```

</details>

<details>
<summary>P154</summary>

```text
Subject: An ordinary original Chinese woman, about 21 years old. short sturdy face, low brows, small hooded eyes, broad mouth; neatly rolled hair with a wooden pin; proud but ordinary; modestly heavy build. Clearly young ADULT, smooth face, dark matte hair; not childlike or glamorous. No facial hair. No distinctive scars, eyepatch or decorative jewellery. ordinary market cultivator: tidy modest robe in deep green, muted plum or brown, slightly nicer simple trim. a plain folded fan.
```

</details>

<details>
<summary>P155</summary>

```text
Subject: An ordinary original Chinese woman, about 26 years old. narrow triangular adult face, upturned eye corners, fine brows, thin lips; short jaw-length hair tucked behind ears; tired and watchful; slim build. Clearly young ADULT, smooth face, dark matte hair; not childlike or glamorous. No facial hair. No distinctive scars, eyepatch or decorative jewellery. ordinary market cultivator: tidy modest robe in deep green, muted plum or brown, slightly nicer simple trim. one small unlabelled ledger held low.
```

</details>

<details>
<summary>P156</summary>

```text
Subject: An ordinary original Chinese woman, about 31 years old. soft rectangular face, long eyebrows, narrow nose, full lips; long hair in a simple ponytail; proud but ordinary; modestly heavy build. Clearly young ADULT, smooth face, dark matte hair; not childlike or glamorous. No facial hair. No distinctive scars, eyepatch or decorative jewellery. ordinary market cultivator: tidy modest robe in deep green, muted plum or brown, slightly nicer simple trim. a plain folded fan.
```

</details>

<details>
<summary>P157</summary>

```text
Subject: An ordinary original Chinese woman, about 22 years old. long slender face, close-set almond eyes, straight fine brows, small straight nose; two modest braids tied behind; shy and cautious; modestly heavy build. Clearly young ADULT, smooth face, dark matte hair; not childlike or glamorous. No facial hair. No distinctive scars, eyepatch or decorative jewellery. ordinary Chixiao travelling cultivator: matte muted crimson and charcoal robe, tiny abstract flame-shaped trim, plain red hair cord, confident practical bearing, no magic effects.
```

</details>

<details>
<summary>P158</summary>

```text
Subject: An ordinary original Chinese woman, about 27 years old. soft square face, wide-set calm eyes, thick flat brows, small round nose; side-part hair in a low knot; stern but approachable; slim build. Clearly young ADULT, smooth face, dark matte hair; not childlike or glamorous. No facial hair. No distinctive scars, eyepatch or decorative jewellery. ordinary Chixiao travelling cultivator: matte muted crimson and charcoal robe, tiny abstract flame-shaped trim, plain red hair cord, confident practical bearing, no magic effects.
```

</details>

<details>
<summary>P159</summary>

```text
Subject: An ordinary original Chinese woman, about 20 years old. round full cheeks, relaxed narrow eyes, short uneven brows, small dimple; half-up shoulder-length hair; amused knowing expression; modestly heavy build. Clearly young ADULT, smooth face, dark matte hair; not childlike or glamorous. No facial hair. No distinctive scars, eyepatch or decorative jewellery. ordinary unaligned wandering cultivator: worn patched travelling robe in grey, brown or ink green, straw-coloured sash. plain sheathed sword.
```

</details>

<details>
<summary>P160</summary>

```text
Subject: An ordinary original Chinese woman, about 25 years old. long face with a firm chin, lowered eye corners, broad soft nose; small high bun with a simple cloth cord; calm and composed; slim build. Clearly young ADULT, smooth face, dark matte hair; not childlike or glamorous. No facial hair. No distinctive scars, eyepatch or decorative jewellery. ordinary unaligned wandering cultivator: worn patched travelling robe in grey, brown or ink green, straw-coloured sash. plain walking staff held low.
```

</details>

<details>
<summary>P161</summary>

```text
Subject: An ordinary original Chinese woman, about 30 years old. diamond face with softly defined cheekbones, shallow eyelids, thin mouth; wrapped hair under a plain travel cloth; amused knowing expression; modestly heavy build. Clearly young ADULT, smooth face, dark matte hair; not childlike or glamorous. No facial hair. No distinctive scars, eyepatch or decorative jewellery. ordinary unaligned wandering cultivator: worn patched travelling robe in grey, brown or ink green, straw-coloured sash. plain sheathed sword.
```

</details>

<details>
<summary>P162</summary>

```text
Subject: An ordinary original Chinese woman, about 18 years old. broad rounded face, small narrow eyes, gently curved brows, short broad nose; single thick braid over one shoulder; calm and composed; average build. Clearly young ADULT, smooth face, dark matte hair; not childlike or glamorous. No facial hair. A small healed eyebrow scar. ordinary unaligned wandering cultivator: worn patched travelling robe in grey, brown or ink green, straw-coloured sash. plain walking staff held low.
```

</details>

<details>
<summary>P163</summary>

```text
Subject: An ordinary original Chinese woman, about 23 years old. long slender face, close-set almond eyes, straight fine brows, small straight nose; two modest braids tied behind; amused knowing expression; sturdy build. Clearly young ADULT, smooth face, dark matte hair; not childlike or glamorous. No facial hair. No distinctive scars, eyepatch or decorative jewellery. ordinary unaligned wandering cultivator: worn patched travelling robe in grey, brown or ink green, straw-coloured sash. plain sheathed sword.
```

</details>

<details>
<summary>P164</summary>

```text
Subject: An ordinary original Chinese woman, about 28 years old. soft square face, wide-set calm eyes, thick flat brows, small round nose; side-part hair in a low knot; calm and composed; average build. Clearly young ADULT, smooth face, dark matte hair; not childlike or glamorous. No facial hair. No distinctive scars, eyepatch or decorative jewellery. ordinary unaligned wandering cultivator: worn patched travelling robe in grey, brown or ink green, straw-coloured sash. plain walking staff held low.
```

</details>

<details>
<summary>P165</summary>

```text
Subject: An ordinary original Chinese woman, about 33 years old. oval face with high forehead, slightly drooping eyelids, arched brows; low compact bun; amused knowing expression; sturdy build. Clearly young ADULT, smooth face, dark matte hair; not childlike or glamorous. No facial hair. No distinctive scars, eyepatch or decorative jewellery. ordinary unaligned wandering cultivator: worn patched travelling robe in grey, brown or ink green, straw-coloured sash. plain sheathed sword.
```

</details>

<details>
<summary>P166</summary>

```text
Subject: An ordinary original Chinese man, about 35 years old. broad rounded face, small narrow eyes, gently curved brows, short broad nose; low tied bun with side part; quietly curious; average build. Clearly mature ADULT, a few modest age lines and some grey at temples; composed lived-in face. small neat moustache A small subtle facial beauty mark. Qingyun outer disciple: simple matching pale-ivory sect uniform, slate-blue collar and cuffs, blue sash, very faint abstract cloud hem, plain hair cord or wooden pin, simple straight sword hilt partly visible at the hip/back. No fancy embroidery.
```

</details>

<details>
<summary>P167</summary>

```text
Subject: An ordinary original Chinese man, about 42 years old. long slender face, close-set almond eyes, straight fine brows, small straight nose; simple single braid; thoughtful and solemn; average build. Clearly mature ADULT, a few modest age lines and some grey at temples; composed lived-in face. short squared beard No distinctive scars, eyepatch or decorative jewellery. Qingyun outer disciple: simple matching pale-ivory sect uniform, slate-blue collar and cuffs, blue sash, very faint abstract cloud hem, plain hair cord or wooden pin, simple straight sword hilt partly visible at the hip/back. No fancy embroidery.
```

</details>

<details>
<summary>P168</summary>

```text
Subject: An ordinary original Chinese man, about 49 years old. soft square face, wide-set calm eyes, thick flat brows, small round nose; pulled-back hair with high forehead; quietly curious; average build. Clearly mature ADULT, a few modest age lines and some grey at temples; composed lived-in face. clean shaven No distinctive scars, eyepatch or decorative jewellery. Qingyun outer disciple: simple matching pale-ivory sect uniform, slate-blue collar and cuffs, blue sash, very faint abstract cloud hem, plain hair cord or wooden pin, simple straight sword hilt partly visible at the hip/back. No fancy embroidery.
```

</details>

<details>
<summary>P169</summary>

```text
Subject: An ordinary original Chinese man, about 36 years old. oval face with high forehead, slightly drooping eyelids, arched brows; compact high topknot; thoughtful and solemn; average build. Clearly mature ADULT, a few modest age lines and some grey at temples; composed lived-in face. short sparse goatee No distinctive scars, eyepatch or decorative jewellery. Qingyun outer disciple: simple matching pale-ivory sect uniform, slate-blue collar and cuffs, blue sash, very faint abstract cloud hem, plain hair cord or wooden pin, simple straight sword hilt partly visible at the hip/back. No fancy embroidery.
```

</details>

<details>
<summary>P170</summary>

```text
Subject: An ordinary original Chinese man, about 43 years old. short sturdy face, low brows, small hooded eyes, broad mouth; shoulder-length half-up hair; quietly curious; average build. Clearly mature ADULT, a few modest age lines and some grey at temples; composed lived-in face. wispy moustache and thin goatee No distinctive scars, eyepatch or decorative jewellery. Qingyun outer disciple: simple matching pale-ivory sect uniform, slate-blue collar and cuffs, blue sash, very faint abstract cloud hem, plain hair cord or wooden pin, simple straight sword hilt partly visible at the hip/back. No fancy embroidery.
```

</details>

<details>
<summary>P171</summary>

```text
Subject: An ordinary original Chinese man, about 50 years old. narrow triangular adult face, upturned eye corners, fine brows, thin lips; small bun and clean side locks; thoughtful and solemn; average build. Clearly mature ADULT, a few modest age lines and some grey at temples; composed lived-in face. small neat moustache No distinctive scars, eyepatch or decorative jewellery. Qingyun outer disciple: simple matching pale-ivory sect uniform, slate-blue collar and cuffs, blue sash, very faint abstract cloud hem, plain hair cord or wooden pin, simple straight sword hilt partly visible at the hip/back. No fancy embroidery.
```

</details>

<details>
<summary>P172</summary>

```text
Subject: An ordinary original Chinese man, about 37 years old. soft rectangular face, long eyebrows, narrow nose, full lips; loose neck-length hair tied with a cord; quietly curious; average build. Clearly mature ADULT, a few modest age lines and some grey at temples; composed lived-in face. short squared beard No distinctive scars, eyepatch or decorative jewellery. Qingyun outer disciple: simple matching pale-ivory sect uniform, slate-blue collar and cuffs, blue sash, very faint abstract cloud hem, plain hair cord or wooden pin, simple straight sword hilt partly visible at the hip/back. No fancy embroidery.
```

</details>

<details>
<summary>P173</summary>

```text
Subject: An ordinary original Chinese man, about 44 years old. round full cheeks, relaxed narrow eyes, short uneven brows, small dimple; short cropped hair under a plain cloth band; thoughtful and solemn; average build. Clearly mature ADULT, a few modest age lines and some grey at temples; composed lived-in face. clean shaven No distinctive scars, eyepatch or decorative jewellery. Qingyun outer disciple: simple matching pale-ivory sect uniform, slate-blue collar and cuffs, blue sash, very faint abstract cloud hem, plain hair cord or wooden pin, simple straight sword hilt partly visible at the hip/back. No fancy embroidery.
```

</details>

<details>
<summary>P174</summary>

```text
Subject: An ordinary original Chinese man, about 51 years old. long face with a firm chin, lowered eye corners, broad soft nose; wrapped hair under a plain travel cloth; quietly curious; average build. Clearly mature ADULT, a few modest age lines and some grey at temples; composed lived-in face. short sparse goatee No distinctive scars, eyepatch or decorative jewellery. Qingyun outer disciple: simple matching pale-ivory sect uniform, slate-blue collar and cuffs, blue sash, very faint abstract cloud hem, plain hair cord or wooden pin, simple straight sword hilt partly visible at the hip/back. No fancy embroidery.
```

</details>

<details>
<summary>P175</summary>

```text
Subject: An ordinary original Chinese man, about 43 years old. short sturdy face, low brows, small hooded eyes, broad mouth; shoulder-length half-up hair; quietly curious; average build. Clearly mature ADULT, a few modest age lines and some grey at temples; composed lived-in face. clean shaven No distinctive scars, eyepatch or decorative jewellery. ordinary herb gatherer: practical modest short robe over trousers, sleeves tied back, rope belt, weathered sun-touched skin. one small plain herb hoe held low.
```

</details>

<details>
<summary>P176</summary>

```text
Subject: An ordinary original Chinese man, about 50 years old. narrow triangular adult face, upturned eye corners, fine brows, thin lips; small bun and clean side locks; thoughtful and solemn; average build. Clearly mature ADULT, a few modest age lines and some grey at temples; composed lived-in face. short sparse goatee No distinctive scars, eyepatch or decorative jewellery. ordinary herb gatherer: practical modest short robe over trousers, sleeves tied back, rope belt, weathered sun-touched skin. a rope-tied herb basket partly visible.
```

</details>

<details>
<summary>P177</summary>

```text
Subject: An ordinary original Chinese man, about 37 years old. soft rectangular face, long eyebrows, narrow nose, full lips; loose neck-length hair tied with a cord; quietly curious; average build. Clearly mature ADULT, a few modest age lines and some grey at temples; composed lived-in face. wispy moustache and thin goatee A small subtle facial beauty mark. ordinary herb gatherer: practical modest short robe over trousers, sleeves tied back, rope belt, weathered sun-touched skin. one small plain herb hoe held low.
```

</details>

<details>
<summary>P178</summary>

```text
Subject: An ordinary original Chinese man, about 44 years old. round full cheeks, relaxed narrow eyes, short uneven brows, small dimple; short cropped hair under a plain cloth band; thoughtful and solemn; average build. Clearly mature ADULT, a few modest age lines and some grey at temples; composed lived-in face. small neat moustache No distinctive scars, eyepatch or decorative jewellery. ordinary herb gatherer: practical modest short robe over trousers, sleeves tied back, rope belt, weathered sun-touched skin. a rope-tied herb basket partly visible.
```

</details>

<details>
<summary>P179</summary>

```text
Subject: An ordinary original Chinese man, about 41 years old. long face with a firm chin, lowered eye corners, broad soft nose; wrapped hair under a plain travel cloth; thoughtful and solemn; average build. Clearly mature ADULT, a few modest age lines and some grey at temples; composed lived-in face. wispy moustache and thin goatee No distinctive scars, eyepatch or decorative jewellery. ordinary market cultivator: tidy modest robe in deep green, muted plum or brown, slightly nicer simple trim. modest waist pouches and a plain jade token.
```

</details>

<details>
<summary>P180</summary>

```text
Subject: An ordinary original Chinese man, about 48 years old. diamond face with softly defined cheekbones, shallow eyelids, thin mouth; short hair under a soft cloth cap; quietly curious; average build. Clearly mature ADULT, a few modest age lines and some grey at temples; composed lived-in face. small neat moustache No distinctive scars, eyepatch or decorative jewellery. ordinary market cultivator: tidy modest robe in deep green, muted plum or brown, slightly nicer simple trim. a simple wooden abacus held low.
```

</details>

<details>
<summary>P181</summary>

```text
Subject: An ordinary original Chinese man, about 35 years old. broad rounded face, small narrow eyes, gently curved brows, short broad nose; low tied bun with side part; thoughtful and solemn; average build. Clearly mature ADULT, a few modest age lines and some grey at temples; composed lived-in face. short squared beard No distinctive scars, eyepatch or decorative jewellery. ordinary market cultivator: tidy modest robe in deep green, muted plum or brown, slightly nicer simple trim. modest waist pouches and a plain jade token.
```

</details>

<details>
<summary>P182</summary>

```text
Subject: An ordinary original Chinese man, about 42 years old. long slender face, close-set almond eyes, straight fine brows, small straight nose; simple single braid; quietly curious; average build. Clearly mature ADULT, a few modest age lines and some grey at temples; composed lived-in face. clean shaven No distinctive scars, eyepatch or decorative jewellery. ordinary market cultivator: tidy modest robe in deep green, muted plum or brown, slightly nicer simple trim. a simple wooden abacus held low.
```

</details>

<details>
<summary>P183</summary>

```text
Subject: An ordinary original Chinese man, about 49 years old. soft square face, wide-set calm eyes, thick flat brows, small round nose; pulled-back hair with high forehead; thoughtful and solemn; average build. Clearly mature ADULT, a few modest age lines and some grey at temples; composed lived-in face. short sparse goatee No distinctive scars, eyepatch or decorative jewellery. ordinary market cultivator: tidy modest robe in deep green, muted plum or brown, slightly nicer simple trim. modest waist pouches and a plain jade token.
```

</details>

<details>
<summary>P184</summary>

```text
Subject: An ordinary original Chinese man, about 36 years old. oval face with high forehead, slightly drooping eyelids, arched brows; compact high topknot; quietly curious; average build. Clearly mature ADULT, a few modest age lines and some grey at temples; composed lived-in face. wispy moustache and thin goatee No distinctive scars, eyepatch or decorative jewellery. ordinary market cultivator: tidy modest robe in deep green, muted plum or brown, slightly nicer simple trim. a simple wooden abacus held low.
```

</details>

<details>
<summary>P185</summary>

```text
Subject: An ordinary original Chinese man, about 51 years old. long face with a firm chin, lowered eye corners, broad soft nose; wrapped hair under a plain travel cloth; shy and cautious; average build. Clearly mature ADULT, a few modest age lines and some grey at temples; composed lived-in face. wispy moustache and thin goatee No distinctive scars, eyepatch or decorative jewellery. ordinary Chixiao travelling cultivator: matte muted crimson and charcoal robe, tiny abstract flame-shaped trim, plain red hair cord, confident practical bearing, no magic effects.
```

</details>

<details>
<summary>P186</summary>

```text
Subject: An ordinary original Chinese man, about 38 years old. diamond face with softly defined cheekbones, shallow eyelids, thin mouth; short hair under a soft cloth cap; stern but approachable; average build. Clearly mature ADULT, a few modest age lines and some grey at temples; composed lived-in face. small neat moustache No distinctive scars, eyepatch or decorative jewellery. ordinary Chixiao travelling cultivator: matte muted crimson and charcoal robe, tiny abstract flame-shaped trim, plain red hair cord, confident practical bearing, no magic effects.
```

</details>

<details>
<summary>P187</summary>

```text
Subject: An ordinary original Chinese man, about 38 years old. diamond face with softly defined cheekbones, shallow eyelids, thin mouth; short hair under a soft cloth cap; proud but ordinary; average build. Clearly mature ADULT, a few modest age lines and some grey at temples; composed lived-in face. clean shaven No distinctive scars, eyepatch or decorative jewellery. ordinary unaligned wandering cultivator: worn patched travelling robe in grey, brown or ink green, straw-coloured sash. a small wrapped travel bundle.
```

</details>

<details>
<summary>P188</summary>

```text
Subject: An ordinary original Chinese man, about 45 years old. broad rounded face, small narrow eyes, gently curved brows, short broad nose; low tied bun with side part; tired and watchful; average build. Clearly mature ADULT, a few modest age lines and some grey at temples; composed lived-in face. short sparse goatee No distinctive scars, eyepatch or decorative jewellery. ordinary unaligned wandering cultivator: worn patched travelling robe in grey, brown or ink green, straw-coloured sash. small plain gourd at the waist.
```

</details>

<details>
<summary>P189</summary>

```text
Subject: An ordinary original Chinese man, about 52 years old. long slender face, close-set almond eyes, straight fine brows, small straight nose; simple single braid; proud but ordinary; average build. Clearly mature ADULT, a few modest age lines and some grey at temples; composed lived-in face. wispy moustache and thin goatee No distinctive scars, eyepatch or decorative jewellery. ordinary unaligned wandering cultivator: worn patched travelling robe in grey, brown or ink green, straw-coloured sash. a small wrapped travel bundle.
```

</details>

<details>
<summary>P190</summary>

```text
Subject: An ordinary original Chinese man, about 39 years old. soft square face, wide-set calm eyes, thick flat brows, small round nose; pulled-back hair with high forehead; tired and watchful; average build. Clearly mature ADULT, a few modest age lines and some grey at temples; composed lived-in face. small neat moustache No distinctive scars, eyepatch or decorative jewellery. ordinary unaligned wandering cultivator: worn patched travelling robe in grey, brown or ink green, straw-coloured sash. small plain gourd at the waist.
```

</details>

<details>
<summary>P191</summary>

```text
Subject: An ordinary original Chinese man, about 46 years old. oval face with high forehead, slightly drooping eyelids, arched brows; compact high topknot; proud but ordinary; average build. Clearly mature ADULT, a few modest age lines and some grey at temples; composed lived-in face. short squared beard A small subtle facial beauty mark. ordinary unaligned wandering cultivator: worn patched travelling robe in grey, brown or ink green, straw-coloured sash. a small wrapped travel bundle.
```

</details>

<details>
<summary>P192</summary>

```text
Subject: An ordinary original Chinese man, about 53 years old. short sturdy face, low brows, small hooded eyes, broad mouth; shoulder-length half-up hair; tired and watchful; average build. Clearly mature ADULT, a few modest age lines and some grey at temples; composed lived-in face. clean shaven No distinctive scars, eyepatch or decorative jewellery. ordinary unaligned wandering cultivator: worn patched travelling robe in grey, brown or ink green, straw-coloured sash. small plain gourd at the waist.
```

</details>

<details>
<summary>P193</summary>

```text
Subject: An ordinary original Chinese man, about 40 years old. narrow triangular adult face, upturned eye corners, fine brows, thin lips; small bun and clean side locks; proud but ordinary; average build. Clearly mature ADULT, a few modest age lines and some grey at temples; composed lived-in face. short sparse goatee No distinctive scars, eyepatch or decorative jewellery. ordinary unaligned wandering cultivator: worn patched travelling robe in grey, brown or ink green, straw-coloured sash. a small wrapped travel bundle.
```

</details>

<details>
<summary>P194</summary>

```text
Subject: An ordinary original Chinese man, about 47 years old. soft rectangular face, long eyebrows, narrow nose, full lips; loose neck-length hair tied with a cord; tired and watchful; average build. Clearly mature ADULT, a few modest age lines and some grey at temples; composed lived-in face. wispy moustache and thin goatee No distinctive scars, eyepatch or decorative jewellery. ordinary unaligned wandering cultivator: worn patched travelling robe in grey, brown or ink green, straw-coloured sash. small plain gourd at the waist.
```

</details>

<details>
<summary>P195</summary>

```text
Subject: An ordinary original Chinese man, about 54 years old. round full cheeks, relaxed narrow eyes, short uneven brows, small dimple; short cropped hair under a plain cloth band; proud but ordinary; average build. Clearly mature ADULT, a few modest age lines and some grey at temples; composed lived-in face. small neat moustache A small healed eyebrow scar. ordinary unaligned wandering cultivator: worn patched travelling robe in grey, brown or ink green, straw-coloured sash. a small wrapped travel bundle.
```

</details>

<details>
<summary>P196</summary>

```text
Subject: An ordinary original Chinese man, about 55 years old. soft square face, wide-set calm eyes, thick flat brows, small round nose; shoulder-length half-up hair; quietly curious; average build. Clearly ELDERLY adult, grey or white matte hair, visibly aged brows and understated wrinkles at eyes and mouth; do NOT make this person look young. Avoid realistic skin texture. small neat moustache A small subtle facial beauty mark. Qingyun outer disciple: simple matching pale-ivory sect uniform, slate-blue collar and cuffs, blue sash, very faint abstract cloud hem, plain hair cord or wooden pin, simple straight sword hilt partly visible at the hip/back. No fancy embroidery.
```

</details>

<details>
<summary>P197</summary>

```text
Subject: An ordinary original Chinese man, about 64 years old. oval face with high forehead, slightly drooping eyelids, arched brows; small bun and clean side locks; thoughtful and solemn; sturdy build. Clearly ELDERLY adult, grey or white matte hair, visibly aged brows and understated wrinkles at eyes and mouth; do NOT make this person look young. Avoid realistic skin texture. short squared beard No distinctive scars, eyepatch or decorative jewellery. Qingyun outer disciple: simple matching pale-ivory sect uniform, slate-blue collar and cuffs, blue sash, very faint abstract cloud hem, plain hair cord or wooden pin, simple straight sword hilt partly visible at the hip/back. No fancy embroidery.
```

</details>

<details>
<summary>P198</summary>

```text
Subject: An ordinary original Chinese man, about 73 years old. short sturdy face, low brows, small hooded eyes, broad mouth; loose neck-length hair tied with a cord; quietly curious; average build. Clearly ELDERLY adult, grey or white matte hair, visibly aged brows and understated wrinkles at eyes and mouth; do NOT make this person look young. Avoid realistic skin texture. clean shaven No distinctive scars, eyepatch or decorative jewellery. Qingyun outer disciple: simple matching pale-ivory sect uniform, slate-blue collar and cuffs, blue sash, very faint abstract cloud hem, plain hair cord or wooden pin, simple straight sword hilt partly visible at the hip/back. No fancy embroidery.
```

</details>

<details>
<summary>P199</summary>

```text
Subject: An ordinary original Chinese man, about 82 years old. narrow triangular adult face, upturned eye corners, fine brows, thin lips; short cropped hair under a plain cloth band; thoughtful and solemn; sturdy build. Clearly ELDERLY adult, grey or white matte hair, visibly aged brows and understated wrinkles at eyes and mouth; do NOT make this person look young. Avoid realistic skin texture. short sparse goatee No distinctive scars, eyepatch or decorative jewellery. Qingyun outer disciple: simple matching pale-ivory sect uniform, slate-blue collar and cuffs, blue sash, very faint abstract cloud hem, plain hair cord or wooden pin, simple straight sword hilt partly visible at the hip/back. No fancy embroidery.
```

</details>

<details>
<summary>P200</summary>

```text
Subject: An ordinary original Chinese man, about 55 years old. soft rectangular face, long eyebrows, narrow nose, full lips; wrapped hair under a plain travel cloth; quietly curious; average build. Clearly ELDERLY adult, grey or white matte hair, visibly aged brows and understated wrinkles at eyes and mouth; do NOT make this person look young. Avoid realistic skin texture. wispy moustache and thin goatee No distinctive scars, eyepatch or decorative jewellery. Qingyun outer disciple: simple matching pale-ivory sect uniform, slate-blue collar and cuffs, blue sash, very faint abstract cloud hem, plain hair cord or wooden pin, simple straight sword hilt partly visible at the hip/back. No fancy embroidery.
```

</details>

<details>
<summary>P201</summary>

```text
Subject: An ordinary original Chinese man, about 64 years old. round full cheeks, relaxed narrow eyes, short uneven brows, small dimple; short hair under a soft cloth cap; thoughtful and solemn; sturdy build. Clearly ELDERLY adult, grey or white matte hair, visibly aged brows and understated wrinkles at eyes and mouth; do NOT make this person look young. Avoid realistic skin texture. small neat moustache No distinctive scars, eyepatch or decorative jewellery. Qingyun outer disciple: simple matching pale-ivory sect uniform, slate-blue collar and cuffs, blue sash, very faint abstract cloud hem, plain hair cord or wooden pin, simple straight sword hilt partly visible at the hip/back. No fancy embroidery.
```

</details>

<details>
<summary>P202</summary>

```text
Subject: An ordinary original Chinese man, about 73 years old. long face with a firm chin, lowered eye corners, broad soft nose; low tied bun with side part; quietly curious; average build. Clearly ELDERLY adult, grey or white matte hair, visibly aged brows and understated wrinkles at eyes and mouth; do NOT make this person look young. Avoid realistic skin texture. short squared beard No distinctive scars, eyepatch or decorative jewellery. Qingyun outer disciple: simple matching pale-ivory sect uniform, slate-blue collar and cuffs, blue sash, very faint abstract cloud hem, plain hair cord or wooden pin, simple straight sword hilt partly visible at the hip/back. No fancy embroidery.
```

</details>

<details>
<summary>P203</summary>

```text
Subject: An ordinary original Chinese man, about 82 years old. narrow triangular adult face, upturned eye corners, fine brows, thin lips; short cropped hair under a plain cloth band; friendly half-smile; sturdy build. Clearly ELDERLY adult, grey or white matte hair, visibly aged brows and understated wrinkles at eyes and mouth; do NOT make this person look young. Avoid realistic skin texture. wispy moustache and thin goatee No distinctive scars, eyepatch or decorative jewellery. ordinary herb gatherer: practical modest short robe over trousers, sleeves tied back, rope belt, weathered sun-touched skin. a modest herb basket with simple leaves.
```

</details>

<details>
<summary>P204</summary>

```text
Subject: An ordinary original Chinese man, about 55 years old. soft rectangular face, long eyebrows, narrow nose, full lips; wrapped hair under a plain travel cloth; reserved faint smile; average build. Clearly ELDERLY adult, grey or white matte hair, visibly aged brows and understated wrinkles at eyes and mouth; do NOT make this person look young. Avoid realistic skin texture. small neat moustache No distinctive scars, eyepatch or decorative jewellery. ordinary herb gatherer: practical modest short robe over trousers, sleeves tied back, rope belt, weathered sun-touched skin. a small bundle of dried herbs.
```

</details>

<details>
<summary>P205</summary>

```text
Subject: An ordinary original Chinese man, about 64 years old. round full cheeks, relaxed narrow eyes, short uneven brows, small dimple; short hair under a soft cloth cap; friendly half-smile; sturdy build. Clearly ELDERLY adult, grey or white matte hair, visibly aged brows and understated wrinkles at eyes and mouth; do NOT make this person look young. Avoid realistic skin texture. short squared beard No distinctive scars, eyepatch or decorative jewellery. ordinary herb gatherer: practical modest short robe over trousers, sleeves tied back, rope belt, weathered sun-touched skin. a modest herb basket with simple leaves.
```

</details>

<details>
<summary>P206</summary>

```text
Subject: An ordinary original Chinese man, about 73 years old. long face with a firm chin, lowered eye corners, broad soft nose; low tied bun with side part; reserved faint smile; average build. Clearly ELDERLY adult, grey or white matte hair, visibly aged brows and understated wrinkles at eyes and mouth; do NOT make this person look young. Avoid realistic skin texture. clean shaven A small subtle facial beauty mark. ordinary herb gatherer: practical modest short robe over trousers, sleeves tied back, rope belt, weathered sun-touched skin. a small bundle of dried herbs.
```

</details>

<details>
<summary>P207</summary>

```text
Subject: An ordinary original Chinese man, about 82 years old. diamond face with softly defined cheekbones, shallow eyelids, thin mouth; simple single braid; friendly half-smile; sturdy build. Clearly ELDERLY adult, grey or white matte hair, visibly aged brows and understated wrinkles at eyes and mouth; do NOT make this person look young. Avoid realistic skin texture. short sparse goatee No distinctive scars, eyepatch or decorative jewellery. ordinary herb gatherer: practical modest short robe over trousers, sleeves tied back, rope belt, weathered sun-touched skin. a modest herb basket with simple leaves.
```

</details>

<details>
<summary>P208</summary>

```text
Subject: An ordinary original Chinese man, about 64 years old. diamond face with softly defined cheekbones, shallow eyelids, thin mouth; simple single braid; reserved faint smile; sturdy build. Clearly ELDERLY adult, grey or white matte hair, visibly aged brows and understated wrinkles at eyes and mouth; do NOT make this person look young. Avoid realistic skin texture. short squared beard A small healed eyebrow scar. ordinary market cultivator: tidy modest robe in deep green, muted plum or brown, slightly nicer simple trim. a plain folded fan.
```

</details>

<details>
<summary>P209</summary>

```text
Subject: An ordinary original Chinese man, about 73 years old. broad rounded face, small narrow eyes, gently curved brows, short broad nose; pulled-back hair with high forehead; friendly half-smile; average build. Clearly ELDERLY adult, grey or white matte hair, visibly aged brows and understated wrinkles at eyes and mouth; do NOT make this person look young. Avoid realistic skin texture. clean shaven No distinctive scars, eyepatch or decorative jewellery. ordinary market cultivator: tidy modest robe in deep green, muted plum or brown, slightly nicer simple trim. one small unlabelled ledger held low.
```

</details>

<details>
<summary>P210</summary>

```text
Subject: An ordinary original Chinese man, about 82 years old. long slender face, close-set almond eyes, straight fine brows, small straight nose; compact high topknot; reserved faint smile; sturdy build. Clearly ELDERLY adult, grey or white matte hair, visibly aged brows and understated wrinkles at eyes and mouth; do NOT make this person look young. Avoid realistic skin texture. short sparse goatee No distinctive scars, eyepatch or decorative jewellery. ordinary market cultivator: tidy modest robe in deep green, muted plum or brown, slightly nicer simple trim. a plain folded fan.
```

</details>

<details>
<summary>P211</summary>

```text
Subject: An ordinary original Chinese man, about 55 years old. soft square face, wide-set calm eyes, thick flat brows, small round nose; shoulder-length half-up hair; friendly half-smile; average build. Clearly ELDERLY adult, grey or white matte hair, visibly aged brows and understated wrinkles at eyes and mouth; do NOT make this person look young. Avoid realistic skin texture. wispy moustache and thin goatee No distinctive scars, eyepatch or decorative jewellery. ordinary market cultivator: tidy modest robe in deep green, muted plum or brown, slightly nicer simple trim. one small unlabelled ledger held low.
```

</details>

<details>
<summary>P212</summary>

```text
Subject: An ordinary original Chinese man, about 64 years old. oval face with high forehead, slightly drooping eyelids, arched brows; small bun and clean side locks; reserved faint smile; sturdy build. Clearly ELDERLY adult, grey or white matte hair, visibly aged brows and understated wrinkles at eyes and mouth; do NOT make this person look young. Avoid realistic skin texture. small neat moustache No distinctive scars, eyepatch or decorative jewellery. ordinary market cultivator: tidy modest robe in deep green, muted plum or brown, slightly nicer simple trim. a plain folded fan.
```

</details>

<details>
<summary>P213</summary>

```text
Subject: An ordinary original Chinese man, about 73 years old. short sturdy face, low brows, small hooded eyes, broad mouth; loose neck-length hair tied with a cord; friendly half-smile; average build. Clearly ELDERLY adult, grey or white matte hair, visibly aged brows and understated wrinkles at eyes and mouth; do NOT make this person look young. Avoid realistic skin texture. short squared beard No distinctive scars, eyepatch or decorative jewellery. ordinary market cultivator: tidy modest robe in deep green, muted plum or brown, slightly nicer simple trim. one small unlabelled ledger held low.
```

</details>

<details>
<summary>P214</summary>

```text
Subject: An ordinary original Chinese man, about 55 years old. broad rounded face, small narrow eyes, gently curved brows, short broad nose; pulled-back hair with high forehead; shy and cautious; average build. Clearly ELDERLY adult, grey or white matte hair, visibly aged brows and understated wrinkles at eyes and mouth; do NOT make this person look young. Avoid realistic skin texture. wispy moustache and thin goatee No distinctive scars, eyepatch or decorative jewellery. ordinary Chixiao travelling cultivator: matte muted crimson and charcoal robe, tiny abstract flame-shaped trim, plain red hair cord, confident practical bearing, no magic effects.
```

</details>

<details>
<summary>P215</summary>

```text
Subject: An ordinary original Chinese man, about 64 years old. long slender face, close-set almond eyes, straight fine brows, small straight nose; compact high topknot; stern but approachable; sturdy build. Clearly ELDERLY adult, grey or white matte hair, visibly aged brows and understated wrinkles at eyes and mouth; do NOT make this person look young. Avoid realistic skin texture. small neat moustache No distinctive scars, eyepatch or decorative jewellery. ordinary Chixiao travelling cultivator: matte muted crimson and charcoal robe, tiny abstract flame-shaped trim, plain red hair cord, confident practical bearing, no magic effects.
```

</details>

<details>
<summary>P216</summary>

```text
Subject: An ordinary original Chinese man, about 82 years old. diamond face with softly defined cheekbones, shallow eyelids, thin mouth; simple single braid; earnest and attentive; sturdy build. Clearly ELDERLY adult, grey or white matte hair, visibly aged brows and understated wrinkles at eyes and mouth; do NOT make this person look young. Avoid realistic skin texture. short squared beard No distinctive scars, eyepatch or decorative jewellery. ordinary unaligned wandering cultivator: worn patched travelling robe in grey, brown or ink green, straw-coloured sash. small plain gourd at the waist.
```

</details>

<details>
<summary>P217</summary>

```text
Subject: An ordinary original Chinese man, about 55 years old. broad rounded face, small narrow eyes, gently curved brows, short broad nose; pulled-back hair with high forehead; mildly suspicious; average build. Clearly ELDERLY adult, grey or white matte hair, visibly aged brows and understated wrinkles at eyes and mouth; do NOT make this person look young. Avoid realistic skin texture. clean shaven No distinctive scars, eyepatch or decorative jewellery. ordinary unaligned wandering cultivator: worn patched travelling robe in grey, brown or ink green, straw-coloured sash. a small wrapped travel bundle.
```

</details>

<details>
<summary>P218</summary>

```text
Subject: An ordinary original Chinese man, about 64 years old. long slender face, close-set almond eyes, straight fine brows, small straight nose; compact high topknot; earnest and attentive; sturdy build. Clearly ELDERLY adult, grey or white matte hair, visibly aged brows and understated wrinkles at eyes and mouth; do NOT make this person look young. Avoid realistic skin texture. short sparse goatee No distinctive scars, eyepatch or decorative jewellery. ordinary unaligned wandering cultivator: worn patched travelling robe in grey, brown or ink green, straw-coloured sash. small plain gourd at the waist.
```

</details>

<details>
<summary>P219</summary>

```text
Subject: An ordinary original Chinese man, about 73 years old. soft square face, wide-set calm eyes, thick flat brows, small round nose; shoulder-length half-up hair; mildly suspicious; average build. Clearly ELDERLY adult, grey or white matte hair, visibly aged brows and understated wrinkles at eyes and mouth; do NOT make this person look young. Avoid realistic skin texture. wispy moustache and thin goatee No distinctive scars, eyepatch or decorative jewellery. ordinary unaligned wandering cultivator: worn patched travelling robe in grey, brown or ink green, straw-coloured sash. a small wrapped travel bundle.
```

</details>

<details>
<summary>P220</summary>

```text
Subject: An ordinary original Chinese man, about 82 years old. oval face with high forehead, slightly drooping eyelids, arched brows; small bun and clean side locks; earnest and attentive; sturdy build. Clearly ELDERLY adult, grey or white matte hair, visibly aged brows and understated wrinkles at eyes and mouth; do NOT make this person look young. Avoid realistic skin texture. small neat moustache No distinctive scars, eyepatch or decorative jewellery. ordinary unaligned wandering cultivator: worn patched travelling robe in grey, brown or ink green, straw-coloured sash. small plain gourd at the waist.
```

</details>

<details>
<summary>P221</summary>

```text
Subject: An ordinary original Chinese man, about 55 years old. short sturdy face, low brows, small hooded eyes, broad mouth; loose neck-length hair tied with a cord; mildly suspicious; average build. Clearly ELDERLY adult, grey or white matte hair, visibly aged brows and understated wrinkles at eyes and mouth; do NOT make this person look young. Avoid realistic skin texture. short squared beard No distinctive scars, eyepatch or decorative jewellery. ordinary unaligned wandering cultivator: worn patched travelling robe in grey, brown or ink green, straw-coloured sash. a small wrapped travel bundle.
```

</details>

<details>
<summary>P222</summary>

```text
Subject: An ordinary original Chinese man, about 64 years old. narrow triangular adult face, upturned eye corners, fine brows, thin lips; short cropped hair under a plain cloth band; earnest and attentive; sturdy build. Clearly ELDERLY adult, grey or white matte hair, visibly aged brows and understated wrinkles at eyes and mouth; do NOT make this person look young. Avoid realistic skin texture. clean shaven A small subtle facial beauty mark. ordinary unaligned wandering cultivator: worn patched travelling robe in grey, brown or ink green, straw-coloured sash. small plain gourd at the waist.
```

</details>

<details>
<summary>P223</summary>

```text
Subject: An ordinary original Chinese man, about 73 years old. soft rectangular face, long eyebrows, narrow nose, full lips; wrapped hair under a plain travel cloth; mildly suspicious; average build. Clearly ELDERLY adult, grey or white matte hair, visibly aged brows and understated wrinkles at eyes and mouth; do NOT make this person look young. Avoid realistic skin texture. short sparse goatee No distinctive scars, eyepatch or decorative jewellery. ordinary unaligned wandering cultivator: worn patched travelling robe in grey, brown or ink green, straw-coloured sash. a small wrapped travel bundle.
```

</details>

<details>
<summary>P224</summary>

```text
Subject: An ordinary original Chinese man, about 82 years old. round full cheeks, relaxed narrow eyes, short uneven brows, small dimple; short hair under a soft cloth cap; earnest and attentive; sturdy build. Clearly ELDERLY adult, grey or white matte hair, visibly aged brows and understated wrinkles at eyes and mouth; do NOT make this person look young. Avoid realistic skin texture. wispy moustache and thin goatee No distinctive scars, eyepatch or decorative jewellery. ordinary unaligned wandering cultivator: worn patched travelling robe in grey, brown or ink green, straw-coloured sash. small plain gourd at the waist.
```

</details>

<details>
<summary>P225</summary>

```text
Subject: An ordinary original Chinese man, about 55 years old. long face with a firm chin, lowered eye corners, broad soft nose; low tied bun with side part; mildly suspicious; average build. Clearly ELDERLY adult, grey or white matte hair, visibly aged brows and understated wrinkles at eyes and mouth; do NOT make this person look young. Avoid realistic skin texture. small neat moustache No distinctive scars, eyepatch or decorative jewellery. ordinary unaligned wandering cultivator: worn patched travelling robe in grey, brown or ink green, straw-coloured sash. a small wrapped travel bundle.
```

</details>

<details>
<summary>P226</summary>

```text
References: official screenshot NPC portraits are the ONLY STYLE REFERENCE, never copy a particular character. Create the distinct person described here.
```

</details>

<details>
<summary>P227</summary>

```text
Subject: An ordinary original Chinese man, about 18 years old. broad rounded face, small narrow eyes, gently curved brows, short broad nose; compact high topknot; quietly curious; modestly heavy build. Clearly young ADULT, smooth face, dark matte hair; not childlike or glamorous. clean shaven A small subtle facial beauty mark. Qingyun outer disciple: simple matching pale-ivory sect uniform, slate-blue collar and cuffs, blue sash, very faint abstract cloud hem, plain hair cord or wooden pin, simple straight sword hilt partly visible at the hip/back. No fancy embroidery.
```

</details>

<details>
<summary>P228</summary>

```text
CRITICAL DISTINCT IDENTITY OVERRIDE: a visibly HEAVY/PLUMP ordinary adult male novice aged 24, thick neck, very full rounded cheeks, broad almost circular jaw with a slight double chin, small narrow widely spaced eyes, blunt BROAD FLAT nose, short broad mouth, clean shaven, two faint freckles. Small LOW compact hair knot with closely cropped sides, plain wooden pin, NOT a tall high bun. Grown adult anatomy, no chibi or childish eyes. Keep the pale ivory/slate-blue Qingyun outer-disciple uniform and a plain sword hilt. This must be visibly a different person from narrow-faced handsome cultivator portraits.
```

</details>

<details>
<summary>P229</summary>

```text
References: official screenshot NPC portraits are the PRIMARY STYLE REFERENCE; newer plain portrait is LINEWORK/SHADING reference only. DO NOT COPY its face, hair, age, costume or abacus. Create the distinct person described here.
```

</details>

<details>
<summary>P230</summary>

```text
Subject: An ordinary original Chinese man, about 23 years old. long slender face, close-set almond eyes, straight fine brows, small straight nose; shoulder-length half-up hair; thoughtful and solemn; slim build. Clearly young ADULT, smooth face, dark matte hair; not childlike or glamorous. clean shaven No distinctive scars, eyepatch or decorative jewellery. Qingyun outer disciple: simple matching pale-ivory sect uniform, slate-blue collar and cuffs, blue sash, very faint abstract cloud hem, plain hair cord or wooden pin, simple straight sword hilt partly visible at the hip/back. No fancy embroidery.
```

</details>

<details>
<summary>P231</summary>

```text
Subject: An ordinary original Chinese man, about 28 years old. soft square face, wide-set calm eyes, thick flat brows, small round nose; small bun and clean side locks; quietly curious; modestly heavy build. Clearly young ADULT, smooth face, dark matte hair; not childlike or glamorous. clean shaven No distinctive scars, eyepatch or decorative jewellery. Qingyun outer disciple: simple matching pale-ivory sect uniform, slate-blue collar and cuffs, blue sash, very faint abstract cloud hem, plain hair cord or wooden pin, simple straight sword hilt partly visible at the hip/back. No fancy embroidery.
```

</details>

<details>
<summary>P232</summary>

```text
Subject: An ordinary original Chinese man, about 33 years old. oval face with high forehead, slightly drooping eyelids, arched brows; loose neck-length hair tied with a cord; thoughtful and solemn; slim build. Clearly young ADULT, smooth face, dark matte hair; not childlike or glamorous. clean shaven No distinctive scars, eyepatch or decorative jewellery. Qingyun outer disciple: simple matching pale-ivory sect uniform, slate-blue collar and cuffs, blue sash, very faint abstract cloud hem, plain hair cord or wooden pin, simple straight sword hilt partly visible at the hip/back. No fancy embroidery.
```

</details>

<details>
<summary>P233</summary>

```text
Subject: An ordinary original Chinese man, about 21 years old. short sturdy face, low brows, small hooded eyes, broad mouth; short cropped hair under a plain cloth band; quietly curious; sturdy build. Clearly young ADULT, smooth face, dark matte hair; not childlike or glamorous. a sparse short moustache No distinctive scars, eyepatch or decorative jewellery. Qingyun outer disciple: simple matching pale-ivory sect uniform, slate-blue collar and cuffs, blue sash, very faint abstract cloud hem, plain hair cord or wooden pin, simple straight sword hilt partly visible at the hip/back. No fancy embroidery.
```

</details>

<details>
<summary>P234</summary>

```text
Subject: An ordinary original Chinese man, about 26 years old. narrow triangular adult face, upturned eye corners, fine brows, thin lips; wrapped hair under a plain travel cloth; thoughtful and solemn; average build. Clearly young ADULT, smooth face, dark matte hair; not childlike or glamorous. clean shaven No distinctive scars, eyepatch or decorative jewellery. Qingyun outer disciple: simple matching pale-ivory sect uniform, slate-blue collar and cuffs, blue sash, very faint abstract cloud hem, plain hair cord or wooden pin, simple straight sword hilt partly visible at the hip/back. No fancy embroidery.
```

</details>

<details>
<summary>P235</summary>

```text
Subject: An ordinary original Chinese man, about 31 years old. soft rectangular face, long eyebrows, narrow nose, full lips; short hair under a soft cloth cap; quietly curious; sturdy build. Clearly young ADULT, smooth face, dark matte hair; not childlike or glamorous. clean shaven No distinctive scars, eyepatch or decorative jewellery. Qingyun outer disciple: simple matching pale-ivory sect uniform, slate-blue collar and cuffs, blue sash, very faint abstract cloud hem, plain hair cord or wooden pin, simple straight sword hilt partly visible at the hip/back. No fancy embroidery.
```

</details>

<details>
<summary>P236</summary>

```text
Subject: An ordinary original Chinese man, about 19 years old. round full cheeks, relaxed narrow eyes, short uneven brows, small dimple; low tied bun with side part; thoughtful and solemn; modestly heavy build. Clearly young ADULT, smooth face, dark matte hair; not childlike or glamorous. clean shaven No distinctive scars, eyepatch or decorative jewellery. Qingyun outer disciple: simple matching pale-ivory sect uniform, slate-blue collar and cuffs, blue sash, very faint abstract cloud hem, plain hair cord or wooden pin, simple straight sword hilt partly visible at the hip/back. No fancy embroidery.
```

</details>

<details>
<summary>P237</summary>

```text
Subject: An ordinary original Chinese man, about 24 years old. long face with a firm chin, lowered eye corners, broad soft nose; simple single braid; quietly curious; slim build. Clearly young ADULT, smooth face, dark matte hair; not childlike or glamorous. clean shaven No distinctive scars, eyepatch or decorative jewellery. Qingyun outer disciple: simple matching pale-ivory sect uniform, slate-blue collar and cuffs, blue sash, very faint abstract cloud hem, plain hair cord or wooden pin, simple straight sword hilt partly visible at the hip/back. No fancy embroidery.
```

</details>

<details>
<summary>P238</summary>

```text
Subject: An ordinary original Chinese man, about 29 years old. diamond face with softly defined cheekbones, shallow eyelids, thin mouth; pulled-back hair with high forehead; thoughtful and solemn; modestly heavy build. Clearly young ADULT, smooth face, dark matte hair; not childlike or glamorous. clean shaven No distinctive scars, eyepatch or decorative jewellery. Qingyun outer disciple: simple matching pale-ivory sect uniform, slate-blue collar and cuffs, blue sash, very faint abstract cloud hem, plain hair cord or wooden pin, simple straight sword hilt partly visible at the hip/back. No fancy embroidery.
```

</details>

<details>
<summary>P239</summary>

```text
Subject: An ordinary original Chinese man, about 34 years old. broad rounded face, small narrow eyes, gently curved brows, short broad nose; compact high topknot; quietly curious; slim build. Clearly young ADULT, smooth face, dark matte hair; not childlike or glamorous. a sparse short moustache No distinctive scars, eyepatch or decorative jewellery. Qingyun outer disciple: simple matching pale-ivory sect uniform, slate-blue collar and cuffs, blue sash, very faint abstract cloud hem, plain hair cord or wooden pin, simple straight sword hilt partly visible at the hip/back. No fancy embroidery.
```

</details>

<details>
<summary>P240</summary>

```text
Subject: An ordinary original Chinese man, about 22 years old. long slender face, close-set almond eyes, straight fine brows, small straight nose; shoulder-length half-up hair; thoughtful and solemn; sturdy build. Clearly young ADULT, smooth face, dark matte hair; not childlike or glamorous. clean shaven No distinctive scars, eyepatch or decorative jewellery. Qingyun outer disciple: simple matching pale-ivory sect uniform, slate-blue collar and cuffs, blue sash, very faint abstract cloud hem, plain hair cord or wooden pin, simple straight sword hilt partly visible at the hip/back. No fancy embroidery.
```

</details>

<details>
<summary>P241</summary>

```text
Subject: An ordinary original Chinese man, about 27 years old. soft square face, wide-set calm eyes, thick flat brows, small round nose; small bun and clean side locks; quietly curious; average build. Clearly young ADULT, smooth face, dark matte hair; not childlike or glamorous. clean shaven No distinctive scars, eyepatch or decorative jewellery. Qingyun outer disciple: simple matching pale-ivory sect uniform, slate-blue collar and cuffs, blue sash, very faint abstract cloud hem, plain hair cord or wooden pin, simple straight sword hilt partly visible at the hip/back. No fancy embroidery.
```

</details>

<details>
<summary>P242</summary>

```text
Subject: An ordinary original Chinese man, about 32 years old. oval face with high forehead, slightly drooping eyelids, arched brows; loose neck-length hair tied with a cord; thoughtful and solemn; sturdy build. Clearly young ADULT, smooth face, dark matte hair; not childlike or glamorous. clean shaven A small subtle facial beauty mark. Qingyun outer disciple: simple matching pale-ivory sect uniform, slate-blue collar and cuffs, blue sash, very faint abstract cloud hem, plain hair cord or wooden pin, simple straight sword hilt partly visible at the hip/back. No fancy embroidery.
```

</details>

<details>
<summary>P243</summary>

```text
Subject: An ordinary original Chinese man, about 19 years old. short sturdy face, low brows, small hooded eyes, broad mouth; short cropped hair under a plain cloth band; quietly curious; average build. Clearly young ADULT, smooth face, dark matte hair; not childlike or glamorous. clean shaven No distinctive scars, eyepatch or decorative jewellery. ordinary herb gatherer: practical modest short robe over trousers, sleeves tied back, rope belt, weathered sun-touched skin. one small plain herb hoe held low.
```

</details>

<details>
<summary>P244</summary>

```text
Subject: An ordinary original Chinese man, about 24 years old. narrow triangular adult face, upturned eye corners, fine brows, thin lips; wrapped hair under a plain travel cloth; thoughtful and solemn; sturdy build. Clearly young ADULT, smooth face, dark matte hair; not childlike or glamorous. clean shaven No distinctive scars, eyepatch or decorative jewellery. ordinary herb gatherer: practical modest short robe over trousers, sleeves tied back, rope belt, weathered sun-touched skin. a rope-tied herb basket partly visible.
```

</details>

<details>
<summary>P245</summary>

```text
Subject: An ordinary original Chinese man, about 29 years old. soft rectangular face, long eyebrows, narrow nose, full lips; short hair under a soft cloth cap; quietly curious; average build. Clearly young ADULT, smooth face, dark matte hair; not childlike or glamorous. clean shaven A small subtle facial beauty mark. ordinary herb gatherer: practical modest short robe over trousers, sleeves tied back, rope belt, weathered sun-touched skin. one small plain herb hoe held low.
```

</details>

<details>
<summary>P246</summary>

```text
Subject: An ordinary original Chinese man, about 34 years old. round full cheeks, relaxed narrow eyes, short uneven brows, small dimple; low tied bun with side part; thoughtful and solemn; sturdy build. Clearly young ADULT, smooth face, dark matte hair; not childlike or glamorous. clean shaven No distinctive scars, eyepatch or decorative jewellery. ordinary herb gatherer: practical modest short robe over trousers, sleeves tied back, rope belt, weathered sun-touched skin. a rope-tied herb basket partly visible.
```

</details>

<details>
<summary>P247</summary>

```text
Subject: An ordinary original Chinese man, about 21 years old. long slender face, close-set almond eyes, straight fine brows, small straight nose; shoulder-length half-up hair; proud but ordinary; modestly heavy build. Clearly young ADULT, smooth face, dark matte hair; not childlike or glamorous. clean shaven No distinctive scars, eyepatch or decorative jewellery. ordinary market cultivator: tidy modest robe in deep green, muted plum or brown, slightly nicer simple trim. a plain folded fan.
```

</details>

<details>
<summary>P248</summary>

```text
Subject: An ordinary original Chinese man, about 26 years old. soft square face, wide-set calm eyes, thick flat brows, small round nose; small bun and clean side locks; tired and watchful; slim build. Clearly young ADULT, smooth face, dark matte hair; not childlike or glamorous. a sparse short moustache No distinctive scars, eyepatch or decorative jewellery. ordinary market cultivator: tidy modest robe in deep green, muted plum or brown, slightly nicer simple trim. one small unlabelled ledger held low.
```

</details>

<details>
<summary>P249</summary>

```text
Subject: An ordinary original Chinese man, about 31 years old. oval face with high forehead, slightly drooping eyelids, arched brows; loose neck-length hair tied with a cord; proud but ordinary; modestly heavy build. Clearly young ADULT, smooth face, dark matte hair; not childlike or glamorous. clean shaven No distinctive scars, eyepatch or decorative jewellery. ordinary market cultivator: tidy modest robe in deep green, muted plum or brown, slightly nicer simple trim. a plain folded fan.
```

</details>

<details>
<summary>P250</summary>

```text
Subject: An ordinary original Chinese man, about 22 years old. long face with a firm chin, lowered eye corners, broad soft nose; simple single braid; shy and cautious; modestly heavy build. Clearly young ADULT, smooth face, dark matte hair; not childlike or glamorous. a sparse short moustache No distinctive scars, eyepatch or decorative jewellery. ordinary Chixiao travelling cultivator: matte muted crimson and charcoal robe, tiny abstract flame-shaped trim, plain red hair cord, confident practical bearing, no magic effects.
```

</details>

<details>
<summary>P251</summary>

```text
Subject: An ordinary original Chinese man, about 27 years old. diamond face with softly defined cheekbones, shallow eyelids, thin mouth; pulled-back hair with high forehead; stern but approachable; slim build. Clearly young ADULT, smooth face, dark matte hair; not childlike or glamorous. clean shaven No distinctive scars, eyepatch or decorative jewellery. ordinary Chixiao travelling cultivator: matte muted crimson and charcoal robe, tiny abstract flame-shaped trim, plain red hair cord, confident practical bearing, no magic effects.
```

</details>

<details>
<summary>P252</summary>

```text
Subject: An ordinary original Chinese man, about 20 years old. short sturdy face, low brows, small hooded eyes, broad mouth; short cropped hair under a plain cloth band; amused knowing expression; modestly heavy build. Clearly young ADULT, smooth face, dark matte hair; not childlike or glamorous. clean shaven No distinctive scars, eyepatch or decorative jewellery. ordinary unaligned wandering cultivator: worn patched travelling robe in grey, brown or ink green, straw-coloured sash. plain sheathed sword.
```

</details>

<details>
<summary>P253</summary>

```text
Subject: An ordinary original Chinese man, about 25 years old. narrow triangular adult face, upturned eye corners, fine brows, thin lips; wrapped hair under a plain travel cloth; calm and composed; slim build. Clearly young ADULT, smooth face, dark matte hair; not childlike or glamorous. clean shaven No distinctive scars, eyepatch or decorative jewellery. ordinary unaligned wandering cultivator: worn patched travelling robe in grey, brown or ink green, straw-coloured sash. plain walking staff held low.
```

</details>

<details>
<summary>P254</summary>

```text
Subject: An ordinary original Chinese man, about 30 years old. soft rectangular face, long eyebrows, narrow nose, full lips; short hair under a soft cloth cap; amused knowing expression; modestly heavy build. Clearly young ADULT, smooth face, dark matte hair; not childlike or glamorous. a sparse short moustache No distinctive scars, eyepatch or decorative jewellery. ordinary unaligned wandering cultivator: worn patched travelling robe in grey, brown or ink green, straw-coloured sash. plain sheathed sword.
```

</details>

<details>
<summary>P255</summary>

```text
Subject: An ordinary original Chinese man, about 18 years old. round full cheeks, relaxed narrow eyes, short uneven brows, small dimple; low tied bun with side part; calm and composed; average build. Clearly young ADULT, smooth face, dark matte hair; not childlike or glamorous. clean shaven A small healed eyebrow scar. ordinary unaligned wandering cultivator: worn patched travelling robe in grey, brown or ink green, straw-coloured sash. plain walking staff held low.
```

</details>

<details>
<summary>P256</summary>

```text
Subject: An ordinary original Chinese man, about 23 years old. long face with a firm chin, lowered eye corners, broad soft nose; simple single braid; amused knowing expression; sturdy build. Clearly young ADULT, smooth face, dark matte hair; not childlike or glamorous. clean shaven No distinctive scars, eyepatch or decorative jewellery. ordinary unaligned wandering cultivator: worn patched travelling robe in grey, brown or ink green, straw-coloured sash. plain sheathed sword.
```

</details>

<details>
<summary>P257</summary>

```text
Subject: An ordinary original Chinese man, about 28 years old. diamond face with softly defined cheekbones, shallow eyelids, thin mouth; pulled-back hair with high forehead; calm and composed; average build. Clearly young ADULT, smooth face, dark matte hair; not childlike or glamorous. clean shaven No distinctive scars, eyepatch or decorative jewellery. ordinary unaligned wandering cultivator: worn patched travelling robe in grey, brown or ink green, straw-coloured sash. plain walking staff held low.
```

</details>

<details>
<summary>P258</summary>

```text
Subject: An ordinary original Chinese man, about 33 years old. broad rounded face, small narrow eyes, gently curved brows, short broad nose; compact high topknot; amused knowing expression; sturdy build. Clearly young ADULT, smooth face, dark matte hair; not childlike or glamorous. clean shaven No distinctive scars, eyepatch or decorative jewellery. ordinary unaligned wandering cultivator: worn patched travelling robe in grey, brown or ink green, straw-coloured sash. plain sheathed sword.
```

</details>


## 2026-10-13：补齐当前内容与整屏美术

使用内置 image_gen 制作 37 张独立原创素材；未使用 CLI/API fallback，也没有用其他工具裁切、改色或重绘。各图完整提示词、原始文件、实际尺寸与 SHA-256 记录在 `ART_BATCH_20261013.json`。图像保留原始输出尺寸，横图约为 16:9，立绘为 4:5；不把原始输出标为 2560×1440。

24 个新增事件在 `data/art.json/event_art` 登记；无选择的大事同样经 `_stage_story` 显示。七张 `_fullscreen.png` 由整屏地点界面选用，原横幅仍用于场景小窗口。执事堂与灵眼按场景路径接入。三位核心人物的 `_unique.png` 由 `portrait_art` 选用；仅识别并跳过已知旧图池副本（SHA-256 在 `portrait_placeholders`），用户自定义立绘仍优先，旧副本保留作缺图回退。云竹面板由 `ui_skin.gd` 用于主窗口和资料/对话面板，按钮与场景纸条继续使用现有主题。没有更改玩法、存档字段或保存位置。

所有生成结果逐张检查了题材、手绘线稿、构图与无界面/水印；后台检查只使用 --headless，未开启可见游戏或编辑器。界面实机视觉验收仍须用户运行预览。

| 文件 | 实际尺寸 | 用途 |
|---|---|---|
| `assets/art/scenes/wild_eye.png` | 1672×941 | scene |
| `assets/art/events/heart_demon.png` | 1672×941 | event |
| `assets/art/events/epiphany.png` | 1672×941 | event |
| `assets/art/events/spirit_eye.png` | 1672×941 | event |
| `assets/art/events/talent_hunyuan.png` | 1672×941 | event |
| `assets/art/events/remnant_soul.png` | 1672×941 | event |
| `assets/art/events/talent_xiantian_daoti.png` | 1672×941 | event |
| `assets/art/events/talent_linglong.png` | 1672×941 | event |
| `assets/art/events/talent_wanfa.png` | 1672×941 | event |
| `assets/art/events/talent_qiyun_zhizi.png` | 1672×941 | event |
| `assets/art/events/talent_bumie.png` | 1672×941 | event |
| `assets/art/events/talent_danqi.png` | 1672×941 | event |
| `assets/art/events/talent_jiangu.png` | 1672×941 | event |
| `assets/art/events/talent_shouyou.png` | 1672×941 | event |
| `assets/art/events/talent_lingqiao_tian.png` | 1672×941 | event |
| `assets/art/events/talent_daqiyun.png` | 1672×941 | event |
| `assets/art/events/talent_tianyan.png` | 1672×941 | event |
| `assets/art/events/talent_shouxing.png` | 1672×941 | event |
| `assets/art/events/talent_yinyang.png` | 1672×941 | event |
| `assets/art/events/talent_huigen.png` | 1672×941 | event |
| `assets/art/locations/sect_fullscreen.png` | 1672×941 | location |
| `assets/art/events/talent_zhanti.png` | 1672×941 | event |
| `assets/art/locations/town_fullscreen.png` | 1672×941 | location |
| `assets/art/events/talent_bulao.png` | 1672×941 | event |
| `assets/art/locations/ferry_fullscreen.png` | 1672×941 | location |
| `assets/art/events/talent_tongming.png` | 1672×941 | event |
| `assets/art/locations/wild_fullscreen.png` | 1672×941 | location |
| `assets/art/events/talent_jiandan.png` | 1672×941 | event |
| `assets/art/locations/market_fullscreen.png` | 1672×941 | location |
| `assets/art/locations/ruin_fullscreen.png` | 1672×941 | location |
| `assets/art/locations/ridge_fullscreen.png` | 1672×941 | location |
| `assets/art/portraits/gu_changgeng_unique.png` | 1122×1402 | portrait |
| `assets/art/events/talent_fuze.png` | 1672×941 | event |
| `assets/art/ui/scroll_panel.png` | 1672×941 | ui |
| `assets/art/portraits/azhi_unique.png` | 1122×1402 | portrait |
| `assets/art/scenes/sect_office.png` | 1672×941 | scene |
| `assets/art/portraits/xu_qinghe_unique.png` | 1122×1402 | portrait |

### 本批后台验证

- 37 张新增图片完整解码且 SHA-256 各不相同；所有图片共 283 张，场景路径无缺失。
- `art_smoke` 157 项、`ui_smoke` 150 项、`presentation_smoke` 31 项全部通过；核心、世界、区域、成长、法宝、社会、故事、天赋与门派检查亦通过。全部使用 --headless，0 图形截图；日志在 `builds/previews/art_audit_20261013/`。
- 完整检查 13 项中 12 项通过；`events_smoke` 的 69 项里，68 项行为检查通过，500 年模拟的性能检查未通过。首次 193+5356 ms，复测 186+5202 ms，超过 5000 ms 阈值。该测试只加载未修改的规则层，不加载美术；未降低时限或改动玩法来掩盖失败。
