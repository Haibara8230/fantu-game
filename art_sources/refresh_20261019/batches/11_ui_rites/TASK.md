# 11_ui_rites · 界面、标记与修行生活插画

现有资源：39 项。已归档本轮生成位图：1 张。

本文件是交接说明；当前对话已按用户要求停止生成，后续由用户在新对话授权执行。

## 先读

[通用规则](D:/fqh/flash/art_sources/refresh_20261019/COMMON_RULES.md)
[分类风格规范](D:/fqh/flash/art_sources/refresh_20261019/STYLE_GUIDE.md)
[新大纲](D:/fqh/flash/docs/WORLD_STORY_REWRITE_20261019.md)
[美术影响评审](D:/fqh/flash/docs/ART_IMPACT_WORLD_REWRITE_20261019.md)

## 本批画法

沿用各自系统参考：卷轴青绿卷边和纸色阅读区，丹炉简洁器型、灵田植物成簇；UI装饰不是人物 C 版。

## 制作范围与顺序

1. 浅纸色卷轴已有样张；深色兼容版也已生成。现有文字为浅色，不能未经主题适配就套浅纸底。
2. 33个正式UI矢量已修改，先审查现状；丹炉、灵田沿用各自样张，保留真实透明通道。
3. 补主角打坐与突破筹划需要的空白部件，文字、材料槽和风险结果由程序绘制。
4. 应用图标 assets/icon.svg 归本批；仅本批负责 tools/art/make_ui_art.py 的后续修改。

## 输入与输出

- `inputs.json` 是本批完整原图清单，含尺寸、哈希和角色帧定义；`inputs.csv` 便于浏览。
- `references.json` 指向本批已确定样张及对应真实参考。注意参考内容不一定与交付题材相同。
- `new_asset_briefs.json` 是新大纲所需图片的逐项说明，不代表已经生成或接入。P0开局／基础，P1首段修行，P2中期扩展，P3旧城与结局；后期布局未定时先留待办。
- `candidates/` 为已生成待验收图片，`prompts/` 为当时完整提示词；先复用或修订，不盲目从头生成。
- 新产物只写本目录 `output/`，交付 `delivery.json` 和逐张提示词；未生成项目保留待办，不冒称已完成。

## 已有位图候选

| 文件 | 内容 | 状态 |
|---|---|---|
| [scroll_panel_dark.png](D:/fqh/flash/art_sources/refresh_20261019/batches/11_ui_rites/candidates/scroll_panel_dark.png) | 与浅色文字兼容的深色卷轴 | candidate |
