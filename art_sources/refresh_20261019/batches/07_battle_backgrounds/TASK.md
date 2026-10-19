# 07_battle_backgrounds · 斗法背景

现有资源：15 项。已归档本轮生成位图：0 张。

本文件是交接说明；当前对话已按用户要求停止生成，后续由用户在新对话授权执行。

## 先读

[通用规则](D:/fqh/flash/art_sources/refresh_20261019/COMMON_RULES.md)
[分类风格规范](D:/fqh/flash/art_sources/refresh_20261019/STYLE_GUIDE.md)
[新大纲](D:/fqh/flash/docs/WORLD_STORY_REWRITE_20261019.md)
[美术影响评审](D:/fqh/flash/docs/ART_IMPACT_WORLD_REWRITE_20261019.md)

## 本批画法

沿用 06_battle 与官方斗法截图：前中后景分层、植物群组、宽阔清楚地面；角色站位和动作不能被背景吞没。

## 制作范围与顺序

1. 竹林背景已有样张；其余地点背景按原场地身份重绘。
2. 双方约四分之一、四分之三横向位置留出人物和技能空间，不在背景烘焙角色、法术或地面投影。
3. 按实际清单保留不同比例；水下、矿洞、古境等新战斗场地随对应内容补齐。

## 输入与输出

- `inputs.json` 是本批完整原图清单，含尺寸、哈希和角色帧定义；`inputs.csv` 便于浏览。
- `references.json` 指向本批已确定样张及对应真实参考。注意参考内容不一定与交付题材相同。
- `new_asset_briefs.json` 是新大纲所需图片的逐项说明，不代表已经生成或接入。P0开局／基础，P1首段修行，P2中期扩展，P3旧城与结局；后期布局未定时先留待办。
- `candidates/` 为已生成待验收图片，`prompts/` 为当时完整提示词；先复用或修订，不盲目从头生成。
- 新产物只写本目录 `output/`，交付 `delivery.json` 和逐张提示词；未生成项目保留待办，不冒称已完成。
