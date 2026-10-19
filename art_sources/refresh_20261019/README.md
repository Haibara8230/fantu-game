# 美术分批交接总入口

**状态：按用户要求停止图片生成。用户将自行开启多个对话，分别执行下列批次。**

本包覆盖636项原有美术，加9个新大纲SVG，共645项正式目录资源。另归档本轮13张生成位图（12项独立资源，主角图集含初版及修正版），以及此前13类样张。

当前正式PNG替换数：0。已有195个正式SVG及两个原生生成器被修改，另有9个新增SVG；205个SVG已通过Godot无窗口渲染检查，整理阶段未进行游戏回归；后续提交前检查见本目录 VALIDATION.md。没有修改玩法数据、存档或运行脚本。

## 开新对话的用法

每批目录都有 `START_PROMPT.txt`，复制其内容到新对话即可。普通头像使用8个子批中的启动词，不把父目录与子批同时分给不同对话。

所有生成对话先交付本批 `output/`，正式替换最后统一集成。这样多对话不会同时改同一张正式资源或共享配置。

[通用规则](D:/fqh/flash/art_sources/refresh_20261019/COMMON_RULES.md) · [分类风格规范](D:/fqh/flash/art_sources/refresh_20261019/STYLE_GUIDE.md) · [本轮13张候选索引](D:/fqh/flash/art_sources/refresh_20261019/completed_candidates.json)

## 12类任务

| 批次 | 工作范围 | 原有／已新增目录资源 | 本轮位图候选 |
|---|---|---:|---:|
| [01_human_actions](D:/fqh/flash/art_sources/refresh_20261019/batches/01_human_actions/TASK.md) | 主角与人形战斗动作 | 18 | 2 |
| [02_key_portraits](D:/fqh/flash/art_sources/refresh_20261019/batches/02_key_portraits/TASK.md) | 关键 NPC 与同辈头像 | 15 | 6 |
| [03_portrait_pool](D:/fqh/flash/art_sources/refresh_20261019/batches/03_portrait_pool/TASK.md) | 普通修士头像池 | 246 | 0 |
| [04_beast_actions](D:/fqh/flash/art_sources/refresh_20261019/batches/04_beast_actions/TASK.md) | 妖兽战斗图集 | 9 | 0 |
| [05_locations](D:/fqh/flash/art_sources/refresh_20261019/batches/05_locations/TASK.md) | 城镇、宗门与地点全景 | 20 | 2 |
| [06_scenes](D:/fqh/flash/art_sources/refresh_20261019/batches/06_scenes/TASK.md) | 室内与二级探索场景 | 36 | 1 |
| [07_battle_backgrounds](D:/fqh/flash/art_sources/refresh_20261019/batches/07_battle_backgrounds/TASK.md) | 斗法背景 | 15 | 0 |
| [08_maps](D:/fqh/flash/art_sources/refresh_20261019/batches/08_maps/TASK.md) | 区域与探索舆图 | 2 | 0 |
| [09_events](D:/fqh/flash/art_sources/refresh_20261019/batches/09_events/TASK.md) | 剧情、天赋与结局插画 | 32 | 1 |
| [10_item_skill_icons](D:/fqh/flash/art_sources/refresh_20261019/batches/10_item_skill_icons/TASK.md) | 物品、功法、法宝与线索图标 | 175 | 0 |
| [11_ui_rites](D:/fqh/flash/art_sources/refresh_20261019/batches/11_ui_rites/TASK.md) | 界面、标记与修行生活插画 | 39 | 1 |
| [12_vfx](D:/fqh/flash/art_sources/refresh_20261019/batches/12_vfx/TASK.md) | 技能与劫雷特效 | 38 | 0 |

## 普通头像的8个子批

| 子批 | 张数 |
|---|---:|
| [female_middle](D:/fqh/flash/art_sources/refresh_20261019/batches/03_portrait_pool/female_middle/TASK.md) | 30 |
| [female_old](D:/fqh/flash/art_sources/refresh_20261019/batches/03_portrait_pool/female_old/TASK.md) | 30 |
| [female_young_01](D:/fqh/flash/art_sources/refresh_20261019/batches/03_portrait_pool/female_young_01/TASK.md) | 32 |
| [female_young_02](D:/fqh/flash/art_sources/refresh_20261019/batches/03_portrait_pool/female_young_02/TASK.md) | 31 |
| [male_middle](D:/fqh/flash/art_sources/refresh_20261019/batches/03_portrait_pool/male_middle/TASK.md) | 30 |
| [male_old](D:/fqh/flash/art_sources/refresh_20261019/batches/03_portrait_pool/male_old/TASK.md) | 30 |
| [male_young_01](D:/fqh/flash/art_sources/refresh_20261019/batches/03_portrait_pool/male_young_01/TASK.md) | 32 |
| [male_young_02](D:/fqh/flash/art_sources/refresh_20261019/batches/03_portrait_pool/male_young_02/TASK.md) | 31 |

## 已有图片与状态

- 本轮位图按批次归档在 `batches/*/candidates/`，完整提示词在相邻 `prompts/`。它们是已生成候选，不等于用户已批准新人物、城徽或构图。
- 主角图集 `hero_atlas.png` 为初版，`hero_atlas_alpha.png` 为修正版。两者均有真实alpha，透明检查应读取像素，不应只看预览底色。
- 前轮样张在 `approved_samples/`，包括2个SVG源文件。地点、地图、飞升样张只作为画法锚点，其旧构图不能覆盖新大纲要求。
- 真实《觅长生》截图仍在 D:/fqh/flash/.tmp/mcs_style_reference_20261019/，原始来源记录在本包 `reference_sources.json`，不复制到正式游戏资源。
- 原版资源备份位于 D:/fqh/flash/.tmp/art_refresh_20261019/baseline/。正式目录的SVG修改已保留，后续批次先审查现状，不盲目回滚或重复生成。

## 建议分工

可同时开展人物动作、关键头像、普通头像子批、环境、图标或界面。涉及同辈出场的剧情插画先使用第02批候选身份；地图和地点共享新大纲空间关系，但各自只交候选。特效先做审查，旧城与海域大场景在玩法和布局确定后再定稿。

生成批次不会自动替换PNG或创建其他对话；Git提交推送由用户另行授权。
