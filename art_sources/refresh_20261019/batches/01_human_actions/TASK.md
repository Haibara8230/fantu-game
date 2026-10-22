# 01_human_actions · 主角与人形战斗动作

现有资源：18 项。已归档本轮生成位图：2 张。

本文件是分类交接说明；当前全量范围以 production_scope.json 与 ALL_ART_PROGRESS.json 为准，所有素材只交候选，不自动替换正式资源。

## 先读

[通用规则](../../COMMON_RULES.md)
[分类风格规范](../../STYLE_GUIDE.md)
[新大纲](../../../../docs/GAME_OUTLINE.md)
[美术影响评审](../../../../docs/ART_IMPACT_WORLD_REWRITE_20261019.md)
[新大纲制作范围](../../CONTENT_PLAN.md)

## 本批画法

人物沿用已确认 C 版，保持身份、朝向与六姿态；图集按实际帧区域取样，不用六张相同站姿冒充动作。

## 制作范围与顺序

1. 先检查主角六姿态候选；逐格验头发、剑尖、鞋底和帧区域，保持现有身份与布局。
2. 开局为16岁无名散修，服装／道具不提前宣告拜入青云；需要适配时说明内容差异，既有主角画法与身份参考不变。
3. 宗门男女修士、散修、对手和赤霄执法按实际消费者审查再处理；停用图集单列，不为覆盖清单重复重绘。
4. 同辈与晏无咎只有确定实际斗法用途后才新增全身动作，不自动把剧情人物做成敌人。

## 输入与输出

- `inputs.json` 是本批完整原图清单，含尺寸、哈希和角色帧定义；`inputs.csv` 便于浏览。
- `references.json` 指向本批已确定样张及对应真实参考。注意参考内容不一定与交付题材相同。
- `new_asset_briefs.json` 是新大纲所需图片的逐项说明，不代表已经生成或接入。P0开局／基础，P1炼气至筑基，P2金丹扩展，P3旧城与结局；后期布局未定时先留待办。
- `candidates/` 为已生成待验收图片，`prompts/` 为当时完整提示词；先复用或修订，不盲目从头生成。
- 新产物只写本目录 `output/`，交付 `delivery.json` 和逐张提示词；未生成项目保留待办，不冒称已完成。

## 已有位图候选

| 文件 | 内容 | 状态 |
|---|---|---|
| [hero_atlas.png](candidates/hero_atlas.png) | 主角六姿态初版 | superseded |
| [hero_atlas_alpha.png](candidates/hero_atlas_alpha.png) | 主角六姿态修正版，优先检查此版 | candidate |

## 新大纲同步

宗门男女动态图集的 `source_role: look` 来自 battle_stage.gd 的宗门／性别选图；保持3列2行、idle／prepare／attack／cast／hit／guard和朝右。晏无咎等剧情角色不自动新增敌人动作。
