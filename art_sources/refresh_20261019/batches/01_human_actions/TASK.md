# 01_human_actions · 主角与人形战斗动作

现有资源：18 项。已归档本轮生成位图：2 张。

本文件是交接说明；当前对话已按用户要求停止生成，后续由用户在新对话授权执行。

## 先读

[通用规则](D:/fqh/flash/art_sources/refresh_20261019/COMMON_RULES.md)
[分类风格规范](D:/fqh/flash/art_sources/refresh_20261019/STYLE_GUIDE.md)
[新大纲](D:/fqh/flash/docs/WORLD_STORY_REWRITE_20261019.md)
[美术影响评审](D:/fqh/flash/docs/ART_IMPACT_WORLD_REWRITE_20261019.md)

## 本批画法

人物沿用已确认 C 版，保持身份、朝向与六姿态；图集按实际帧区域取样，不用六张相同站姿冒充动作。

## 制作范围与顺序

1. 先检查现有主角六姿态候选，逐格检查头发、剑尖、鞋底是否越界。
2. 重绘其余宗门男女修士、散修、对手和赤霄执法动作。
3. 同辈只有在确定会进入斗法时才新增全身动作，不擅自把所有剧情人物做成敌人。

## 输入与输出

- `inputs.json` 是本批完整原图清单，含尺寸、哈希和角色帧定义；`inputs.csv` 便于浏览。
- `references.json` 指向本批已确定样张及对应真实参考。注意参考内容不一定与交付题材相同。
- `new_asset_briefs.json` 是新大纲所需图片的逐项说明，不代表已经生成或接入。P0开局／基础，P1首段修行，P2中期扩展，P3旧城与结局；后期布局未定时先留待办。
- `candidates/` 为已生成待验收图片，`prompts/` 为当时完整提示词；先复用或修订，不盲目从头生成。
- 新产物只写本目录 `output/`，交付 `delivery.json` 和逐张提示词；未生成项目保留待办，不冒称已完成。

## 已有位图候选

| 文件 | 内容 | 状态 |
|---|---|---|
| [hero_atlas.png](D:/fqh/flash/art_sources/refresh_20261019/batches/01_human_actions/candidates/hero_atlas.png) | 主角六姿态初版 | superseded |
| [hero_atlas_alpha.png](D:/fqh/flash/art_sources/refresh_20261019/batches/01_human_actions/candidates/hero_atlas_alpha.png) | 主角六姿态修正版，优先检查此版 | candidate |
