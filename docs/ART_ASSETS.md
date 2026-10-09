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

### 尚未规划
战斗背景目前所有地点共用 `bamboo_arena_v1.png`。按地区区分的战斗背景、劫修专属人物图集（目前沿用同门图集），放在 M3–M4 一并规划。


## 2026-10-09：青云山区域地图首张样图

- 文件：`assets/art/map/region_qingyun_preview_v1.png`
- 工具：内置 imagegen，未使用 CLI/API fallback。
- 实际尺寸：1586×992，PNG；未缩放、裁切或修改原始生成图。
- 用途：先供用户确认视觉效果，未接入正式地图路径。正式地图要求精确 2560×1600，本样图尚未满足该尺寸。
- 目视检查：二维手绘青黛山水、清晰墨线、局部暖色灵泉；未见文字、水印、UI 或连接道路。地标位置与标记留白仍需在正式版进一步校准，洞府表现也需更低调。
- 本次仅生成这一张样图；没有启动可见游戏或编辑器。

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
