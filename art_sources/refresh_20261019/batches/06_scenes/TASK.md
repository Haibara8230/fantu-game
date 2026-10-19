# 06_scenes · 室内与二级探索场景

现有资源：36 项。已归档本轮生成位图：1 张。

本文件是交接说明；当前对话已按用户要求停止生成，后续由用户在新对话授权执行。

## 先读

[通用规则](D:/fqh/flash/art_sources/refresh_20261019/COMMON_RULES.md)
[分类风格规范](D:/fqh/flash/art_sources/refresh_20261019/STYLE_GUIDE.md)
[新大纲](D:/fqh/flash/docs/WORLD_STORY_REWRITE_20261019.md)
[美术影响评审](D:/fqh/flash/docs/ART_IMPACT_WORLD_REWRITE_20261019.md)

## 本批画法

室内沿用 07_interior：木构家具用暖色大块、清楚轮廓、有序陈设、少木纹；室外支路沿用地点环境画法。

## 制作范围与顺序

1. 青石客栈已有确认样张，后续需适配开局和同辈日常。
2. 正常青云山门已有候选；正式 sect_gate.png 当前用于魔潮状态，不能用日常图直接覆盖。
3. 补云溪城门、陆府室内／庭院、其他城市代表内景；按章节再做古境房间、矿道分岔、船上、岛屿与水下遗迹。
4. 野外发现用少量具体线索和状态变化，不为每个隐藏标志单独画一整幅全景。

## 输入与输出

- `inputs.json` 是本批完整原图清单，含尺寸、哈希和角色帧定义；`inputs.csv` 便于浏览。
- `references.json` 指向本批已确定样张及对应真实参考。注意参考内容不一定与交付题材相同。
- `new_asset_briefs.json` 是新大纲所需图片的逐项说明，不代表已经生成或接入。P0开局／基础，P1首段修行，P2中期扩展，P3旧城与结局；后期布局未定时先留待办。
- `candidates/` 为已生成待验收图片，`prompts/` 为当时完整提示词；先复用或修订，不盲目从头生成。
- 新产物只写本目录 `output/`，交付 `delivery.json` 和逐张提示词；未生成项目保留待办，不冒称已完成。

## 已有位图候选

| 文件 | 内容 | 状态 |
|---|---|---|
| [sect_gate_normal.png](D:/fqh/flash/art_sources/refresh_20261019/batches/06_scenes/candidates/sect_gate_normal.png) | 日常山门，不能直接覆盖魔潮状态 | candidate |
