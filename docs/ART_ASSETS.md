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
