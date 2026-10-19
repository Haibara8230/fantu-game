# 05_locations · 城镇、宗门与地点全景

现有资源：20 项。已归档本轮生成位图：2 张。

本文件是交接说明；当前对话已按用户要求停止生成，后续由用户在新对话授权执行。

## 先读

[通用规则](D:/fqh/flash/art_sources/refresh_20261019/COMMON_RULES.md)
[分类风格规范](D:/fqh/flash/art_sources/refresh_20261019/STYLE_GUIDE.md)
[新大纲](D:/fqh/flash/docs/WORLD_STORY_REWRITE_20261019.md)
[美术影响评审](D:/fqh/flash/docs/ART_IMPACT_WORLD_REWRITE_20261019.md)

## 本批画法

按官方宗门／城镇参考与地点样张画法：屋顶、墙面、群树和远山归并色块，建筑按功能组织；不套人物 C 版提示词。

## 制作范围与顺序

1. 青云小宗全景已有候选，仍需检查规模与可点击建筑分布。
2. 云溪城已有新增城市候选；旧云溪坊市不能未经内容迁移就直接视为全城。
3. 南明扩城，并新增沧澜医药城、北岳古物阵法城、望海海贸城。沧澜阁不等于沧澜城，玄岳宗不等于北岳城。
4. 现有两种地点横图有不同尺寸和用途，按清单逐个处理，不能强行全部改成16:9。

## 输入与输出

- `inputs.json` 是本批完整原图清单，含尺寸、哈希和角色帧定义；`inputs.csv` 便于浏览。
- `references.json` 指向本批已确定样张及对应真实参考。注意参考内容不一定与交付题材相同。
- `new_asset_briefs.json` 是新大纲所需图片的逐项说明，不代表已经生成或接入。P0开局／基础，P1首段修行，P2中期扩展，P3旧城与结局；后期布局未定时先留待办。
- `candidates/` 为已生成待验收图片，`prompts/` 为当时完整提示词；先复用或修订，不盲目从头生成。
- 新产物只写本目录 `output/`，交付 `delivery.json` 和逐张提示词；未生成项目保留待办，不冒称已完成。

## 已有位图候选

| 文件 | 内容 | 状态 |
|---|---|---|
| [sect_small.png](D:/fqh/flash/art_sources/refresh_20261019/batches/05_locations/candidates/sect_small.png) | 青云小宗全景 | candidate |
| [yunxi_city.png](D:/fqh/flash/art_sources/refresh_20261019/batches/05_locations/candidates/yunxi_city.png) | 云溪城市全景规划 | candidate |
