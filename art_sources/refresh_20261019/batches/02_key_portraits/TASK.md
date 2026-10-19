# 02_key_portraits · 关键 NPC 与同辈头像

现有资源：15 项。已归档本轮生成位图：6 张。

本文件是交接说明；当前对话已按用户要求停止生成，后续由用户在新对话授权执行。

## 先读

[通用规则](D:/fqh/flash/art_sources/refresh_20261019/COMMON_RULES.md)
[分类风格规范](D:/fqh/flash/art_sources/refresh_20261019/STYLE_GUIDE.md)
[新大纲](D:/fqh/flash/docs/WORLD_STORY_REWRITE_20261019.md)
[美术影响评审](D:/fqh/flash/docs/ART_IMPACT_WORLD_REWRITE_20261019.md)

## 本批画法

人物沿用 C 版。每人保留原身份、发型、衣色、年龄、道具和辨识轮廓；新增同辈使用现有候选作为暂定身份锚点。

## 制作范围与顺序

1. 先复核陆承舟、叶知微、闻人照、柳寒舟健康状态和拍卖老修士候选。
2. 阿芷已有重绘候选；沈墨有此前确认样张；其余关键人物逐一处理。
3. 柳寒舟受伤与健康是同一人，受伤图仍需保留；成长、衰老和结局状态按实际剧情分批做，不一律悲剧化。
4. 两张 assets/local/portraits 根目录定制头像归本批，不归普通头像池。

## 输入与输出

- `inputs.json` 是本批完整原图清单，含尺寸、哈希和角色帧定义；`inputs.csv` 便于浏览。
- `references.json` 指向本批已确定样张及对应真实参考。注意参考内容不一定与交付题材相同。
- `new_asset_briefs.json` 是新大纲所需图片的逐项说明，不代表已经生成或接入。P0开局／基础，P1首段修行，P2中期扩展，P3旧城与结局；后期布局未定时先留待办。
- `candidates/` 为已生成待验收图片，`prompts/` 为当时完整提示词；先复用或修订，不盲目从头生成。
- 新产物只写本目录 `output/`，交付 `delivery.json` 和逐张提示词；未生成项目保留待办，不冒称已完成。

## 已有位图候选

| 文件 | 内容 | 状态 |
|---|---|---|
| [lu_chengzhou.png](D:/fqh/flash/art_sources/refresh_20261019/batches/02_key_portraits/candidates/lu_chengzhou.png) | 陆承舟初期头像 | candidate |
| [ye_zhiwei.png](D:/fqh/flash/art_sources/refresh_20261019/batches/02_key_portraits/candidates/ye_zhiwei.png) | 叶知微初期头像 | candidate |
| [wenren_zhao.png](D:/fqh/flash/art_sources/refresh_20261019/batches/02_key_portraits/candidates/wenren_zhao.png) | 闻人照初期头像 | candidate |
| [liu_hanzhou_healthy.png](D:/fqh/flash/art_sources/refresh_20261019/batches/02_key_portraits/candidates/liu_hanzhou_healthy.png) | 柳寒舟健康状态 | candidate |
| [azhi.png](D:/fqh/flash/art_sources/refresh_20261019/batches/02_key_portraits/candidates/azhi.png) | 阿芷简化重绘 | candidate |
| [auction_elder.png](D:/fqh/flash/art_sources/refresh_20261019/batches/02_key_portraits/candidates/auction_elder.png) | 拍卖老修士暂拟形象 | candidate |
