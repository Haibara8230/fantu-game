# 09_events · 剧情、天赋与结局插画

现有资源：32 项。已归档本轮生成位图：1 张。

本文件是交接说明；当前对话已按用户要求停止生成，后续由用户在新对话授权执行。

## 先读

[通用规则](D:/fqh/flash/art_sources/refresh_20261019/COMMON_RULES.md)
[分类风格规范](D:/fqh/flash/art_sources/refresh_20261019/STYLE_GUIDE.md)
[新大纲](D:/fqh/flash/docs/WORLD_STORY_REWRITE_20261019.md)
[美术影响评审](D:/fqh/flash/docs/ART_IMPACT_WORLD_REWRITE_20261019.md)

## 本批画法

沿用官方演出参考及 13_event 的图形化语言：云形与山形分层、象征性焦点、大色块和留白；旧飞升题材本身不能照搬。

## 制作范围与顺序

1. 现有32幅事件包括天赋图，按清单保留事件身份，不统一画成同一张仙山。
2. 补集会、拍卖残镜异象、潜龙会、陆府夜宴；潜龙会公共赛场已有背景候选。
3. 镜中旧城需与第10批候选城徽一致；城徽目前是暂拟设计，不能宣称已最终批准。
4. 飞升需要不同通路与结局状态；先共享基础构图再制作变化，不再用一张金色云桥宫阙代表全部结局。
5. 剧情人物出场时先读取第02批身份图，不为同一人重画一张无关的脸。

## 输入与输出

- `inputs.json` 是本批完整原图清单，含尺寸、哈希和角色帧定义；`inputs.csv` 便于浏览。
- `references.json` 指向本批已确定样张及对应真实参考。注意参考内容不一定与交付题材相同。
- `new_asset_briefs.json` 是新大纲所需图片的逐项说明，不代表已经生成或接入。P0开局／基础，P1首段修行，P2中期扩展，P3旧城与结局；后期布局未定时先留待办。
- `candidates/` 为已生成待验收图片，`prompts/` 为当时完整提示词；先复用或修订，不盲目从头生成。
- 新产物只写本目录 `output/`，交付 `delivery.json` 和逐张提示词；未生成项目保留待办，不冒称已完成。

## 已有位图候选

| 文件 | 内容 | 状态 |
|---|---|---|
| [qianlong_arena.png](D:/fqh/flash/art_sources/refresh_20261019/batches/09_events/candidates/qianlong_arena.png) | 公共潜龙会背景 | candidate |
