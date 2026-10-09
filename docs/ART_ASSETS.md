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
| 云溪坊市 | 80%, 62% | 河畔较大的集镇，屋舍密集，有几面幡旗 |
| 松风岭 | 20%, 60% | 松林覆盖的山岭 |
| 落霞谷 | 44%, 80% | 晚霞映照的山谷，谷底一点泉光 |
| 古修洞府 | 24%, 88% | 落霞谷西南的崖壁石门，要**低调**：开局时它不显示在地图上，被发现后才出现标记 |

云溪从北面流下，经过白鹭渡与云溪坊市之间，向东南流出。

```text
Use case: stylized-concept
Asset type: top-down oblique REGIONAL MAP background for a 2D Chinese cultivation RPG, original, in the illustrated visual family of 觅长生. 2560x1600 exact.
Content: a painted landscape map of one mountain region seen from a high oblique angle. Place terrain features at these positions (percent of width, height): misty main peak with sect pavilions halfway up at (24,24); small mortal town of grey-tiled roofs at the foot of the mountains (40,42); river ferry crossing with shallows, reeds and a tiny pier (60,50); larger riverside market town with dense roofs and a few banners (80,62); pine-covered ridge (20,60); valley glowing with sunset light and a faint spring at its floor (44,80); a subtle mossy stone cave door in a cliff (24,88), understated. A river enters from the north edge, passes between (60,50) and (80,62) and leaves to the south-east.
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
