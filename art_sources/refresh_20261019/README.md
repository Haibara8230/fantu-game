# 美术分批交接总入口

**状态：用户已授权继续做完全部图，按既定分类画风生产候选；实时完成数见 [全量进度](PROGRESS.md)。**

本包覆盖636项原有美术，加9个新大纲SVG，共645项正式目录资源。另归档本轮13张生成位图（12项独立资源，主角图集含初版及修正版），以及此前13类样张。

2026-10-22 起已集成：`python -B tools/art/integrate_refresh.py` 把已交付、经目视核对的位图装入正式资源——既有资源原地替换（大于原尺寸的缩到原尺寸，原样式与透明度不变），新增计划图装入 `assets/art/` 并在 `data/art.json` 接到有消费者的场所、城市、事件与斗法场；逐项路径、尺寸与哈希见 [INTEGRATION.json](INTEGRATION.json)，旧图备份在项目 `.tmp/art_integration/backup/`。可重复运行，后续交付的图再跑一次即装入。各批 `output/` 下的原尺寸 PNG 只留在本机 D 盘，不进 Git。已有195个正式SVG及两个原生生成器被修改，另有9个新增SVG；205个SVG已通过Godot无窗口渲染检查；提交前检查见本目录 VALIDATION.md。

## 开新对话的用法

每批目录都有 `START_PROMPT.txt`，复制其内容到新对话即可。普通头像使用8个子批中的启动词，不把父目录与子批同时分给不同对话。

所有生成对话先交付本批 `output/`，正式替换最后统一集成。这样多对话不会同时改同一张正式资源或共享配置。

## 新大纲内容与风格

内容与制作顺序见 [新大纲生图制作说明](CONTENT_PLAN.md)，以 [游戏大纲](../../docs/GAME_OUTLINE.md) 为依据，按开局、炼气、筑基、五城成形、金丹大经历、元婴与飞升六个可玩阶段交付。01—12仍是美术分类批次，P0—P3是内容优先级，不表示一次生成全部后期资源。

各类图的风格、参考样张、既定画法、尺寸、透明度、帧定义和验收要求保持不变；人物继续沿用C版，其余类别各自沿用原文档和参考。本轮只更新人物经历、地点用途、剧情题材、优先级与新提示词的内容边界，历史提示词与确认样张保留。所有批次启动词已同步此约束。

重点包括白鹭渡内天河渡口的月圆城影、静房与散修开局、筑基北岳与天南大比、金丹五宗论道、同辈中期经历、温照衡两种线索接续及三条飞升通路。新增需求不计入645项已有资源覆盖数；未定的古境房间、城市邻接与结局空间先交候选或保留待办。

仅同步内容时运行 `python -B tools/art/repair_handoffs.py --content-only`；该模式不重写原图清单、风格参考或历史提示词，也不调用生图工具。

## 当前生图执行状态

用户已授权将生图目录联接至D盘并使用内置工具；目录写入探针与实际生成文件均已验证真实存储位于项目 `.tmp/imagegen_storage/generated_images/`。规格继承、逐项引用哈希、依赖与全量执行规则见 [执行规则](PRODUCTION_RULES.md) 和 `PRODUCTION_MANIFEST.json`。

用户最新要求为继续做完全部图。已完成的开局静房、渡口与月圆城影保留，继续制作全部分类与P0—P3候选。逐图交付和待办见 [全量进度](PROGRESS.md) 与 `ALL_ART_PROGRESS.json`；复用与新生成分开统计。原有各类画法和确认样张不变；已交付的图按上文集成，其余仍为候选。

[通用规则](COMMON_RULES.md) · [分类风格规范](STYLE_GUIDE.md) · [本轮13张候选索引](completed_candidates.json)

## 12类任务

| 批次 | 工作范围 | 原有／已新增目录资源 | 本轮位图候选 |
|---|---|---:|---:|
| [01_human_actions](batches/01_human_actions/TASK.md) | 主角与人形战斗动作 | 18 | 2 |
| [02_key_portraits](batches/02_key_portraits/TASK.md) | 关键 NPC 与同辈头像 | 15 | 6 |
| [03_portrait_pool](batches/03_portrait_pool/TASK.md) | 普通修士头像池 | 246 | 0 |
| [04_beast_actions](batches/04_beast_actions/TASK.md) | 妖兽战斗图集 | 9 | 0 |
| [05_locations](batches/05_locations/TASK.md) | 城镇、宗门与地点全景 | 20 | 2 |
| [06_scenes](batches/06_scenes/TASK.md) | 室内与二级探索场景 | 36 | 1 |
| [07_battle_backgrounds](batches/07_battle_backgrounds/TASK.md) | 斗法背景 | 15 | 0 |
| [08_maps](batches/08_maps/TASK.md) | 区域与探索舆图 | 2 | 0 |
| [09_events](batches/09_events/TASK.md) | 剧情、天赋与结局插画 | 32 | 1 |
| [10_item_skill_icons](batches/10_item_skill_icons/TASK.md) | 物品、功法、法宝与线索图标 | 175 | 0 |
| [11_ui_rites](batches/11_ui_rites/TASK.md) | 界面、标记与修行生活插画 | 39 | 1 |
| [12_vfx](batches/12_vfx/TASK.md) | 技能与劫雷特效 | 38 | 0 |

## 普通头像的8个子批

| 子批 | 张数 |
|---|---:|
| [female_middle](batches/03_portrait_pool/female_middle/TASK.md) | 30 |
| [female_old](batches/03_portrait_pool/female_old/TASK.md) | 30 |
| [female_young_01](batches/03_portrait_pool/female_young_01/TASK.md) | 32 |
| [female_young_02](batches/03_portrait_pool/female_young_02/TASK.md) | 31 |
| [male_middle](batches/03_portrait_pool/male_middle/TASK.md) | 30 |
| [male_old](batches/03_portrait_pool/male_old/TASK.md) | 30 |
| [male_young_01](batches/03_portrait_pool/male_young_01/TASK.md) | 32 |
| [male_young_02](batches/03_portrait_pool/male_young_02/TASK.md) | 31 |

## 已有图片与状态

- 本轮位图按批次归档在 `batches/*/candidates/`，完整提示词在相邻 `prompts/`。它们是已生成候选，不等于用户已批准新人物、城徽或构图。
- 主角图集 `hero_atlas.png` 为初版，`hero_atlas_alpha.png` 为修正版。两者均有真实alpha，透明检查应读取像素，不应只看预览底色。
- 前轮样张在 `approved_samples/`，包括2个SVG源文件。地点、地图、飞升样张只作为画法锚点，其旧构图不能覆盖新大纲要求。
- 原作参考存入项目忽略目录 `PNG/mcs_style_reference_20261019/originals/`；来源与SHA-256见 `reference_sources.json`，恢复和验证见 [参考恢复说明](REFERENCE_SETUP.md)。
- 历史原版备份路径为 `.tmp/art_refresh_20261019/baseline/`，不随Git携带，也不假定当前机器已有。正式SVG修改已保留，集成前另在项目 `.tmp/` 做当前快照，不盲目回滚。

## 建议分工

可同时开展人物动作、关键头像、普通头像子批、环境、图标或界面。涉及同辈出场的剧情插画先使用第02批候选身份；地图和地点共享新大纲空间关系，但各自只交候选。特效先做审查，旧城与海域大场景在玩法和布局确定后再定稿。

生成批次不会自动替换PNG或创建其他对话；Git提交推送由用户另行授权。

## 本次交接修正

内容以 `docs/GAME_OUTLINE.md` 为准；新增需求见各批说明和 `new_asset_briefs.json`，不计入645项现有资源。清单路径相对于项目根目录，链接相对于文档。使用 `python -B tools/art/repair_handoffs.py` 更新现有包，不依赖旧机器的生成缓存。目录核验和全量生图交付的当前状态见上方“当前生图执行状态”；历史归档与本轮output分别记录。
