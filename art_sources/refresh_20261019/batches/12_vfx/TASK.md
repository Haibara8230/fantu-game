# 12_vfx · 技能与劫雷特效

现有资源：38 项。已归档本轮生成位图：0 张。

本文件是交接说明；当前对话已按用户要求停止生成，后续由用户在新对话授权执行。

## 先读

[通用规则](D:/fqh/flash/art_sources/refresh_20261019/COMMON_RULES.md)
[分类风格规范](D:/fqh/flash/art_sources/refresh_20261019/STYLE_GUIDE.md)
[新大纲](D:/fqh/flash/docs/WORLD_STORY_REWRITE_20261019.md)
[美术影响评审](D:/fqh/flash/docs/ART_IMPACT_WORLD_REWRITE_20261019.md)

## 本批画法

使用清楚大形和克制光效，服务技能辨识与场地阅读；不把静态背景画法强加给瞬时特效。

## 制作范围与顺序

1. 37张现有特效来自CC0素材，先审查用途和配色，保留许可证；能沿用的基础形状不必强制重画。
2. tribulation.png 为多帧劫雷特效图集，保留其帧结构与透明度。
3. 新增代表功法特效需和第10批图标及实际机制一致，不能仅因名字自行添加新战斗规则。

## 输入与输出

- `inputs.json` 是本批完整原图清单，含尺寸、哈希和角色帧定义；`inputs.csv` 便于浏览。
- `references.json` 指向本批已确定样张及对应真实参考。注意参考内容不一定与交付题材相同。
- `new_asset_briefs.json` 是新大纲所需图片的逐项说明，不代表已经生成或接入。P0开局／基础，P1首段修行，P2中期扩展，P3旧城与结局；后期布局未定时先留待办。
- `candidates/` 为已生成待验收图片，`prompts/` 为当时完整提示词；先复用或修订，不盲目从头生成。
- 新产物只写本目录 `output/`，交付 `delivery.json` 和逐张提示词；未生成项目保留待办，不冒称已完成。
