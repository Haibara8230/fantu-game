# 全量美术进度

用户已授权继续完成全部图。既有分类画风不变，全部候选保存在本包各批 `output/`。已有 288 项装入正式资源（`tools/art/integrate_refresh.py`，逐项见 [INTEGRATION.json](INTEGRATION.json)），其余仍为候选。

范围：645 项既有资源 + 98 项新增计划，共 743 项任务。计划与既有资源有独立交付记录，复用不计为新生成。

| 分类 | 新生成候选 | 复用 | SVG交付 | 待处理 | 明确排除 |
|---|---:|---:|---:|---:|---:|
| [01_human_actions](batches/01_human_actions/output/bulk_delivery.json) | 0 | 1 | 0 | 17 | 0 |
| [02_key_portraits](batches/02_key_portraits/output/bulk_delivery.json) | 18 | 7 | 0 | 0 | 0 |
| [03_portrait_pool](batches/03_portrait_pool/output/bulk_delivery.json) | 237 | 0 | 0 | 9 | 0 |
| [04_beast_actions](batches/04_beast_actions/output/bulk_delivery.json) | 0 | 0 | 0 | 9 | 1 |
| [05_locations](batches/05_locations/output/bulk_delivery.json) | 4 | 3 | 0 | 19 | 0 |
| [06_scenes](batches/06_scenes/output/bulk_delivery.json) | 27 | 3 | 0 | 36 | 0 |
| [07_battle_backgrounds](batches/07_battle_backgrounds/output/bulk_delivery.json) | 6 | 0 | 0 | 15 | 0 |
| [08_maps](batches/08_maps/output/bulk_delivery.json) | 5 | 1 | 0 | 0 | 0 |
| [09_events](batches/09_events/output/bulk_delivery.json) | 21 | 1 | 0 | 32 | 0 |
| [10_item_skill_icons](batches/10_item_skill_icons/output/bulk_delivery.json) | 0 | 184 | 1 | 0 | 0 |
| [11_ui_rites](batches/11_ui_rites/output/bulk_delivery.json) | 3 | 39 | 3 | 0 | 0 |
| [12_vfx](batches/12_vfx/output/bulk_delivery.json) | 4 | 37 | 0 | 0 | 0 |

总状态：`{"pending": 137, "delivered_reuse": 276, "delivered_generated": 325, "excluded_unconfirmed_enemy": 1, "delivered_vector": 4}`。

“新生成候选”仅统计经目视核对并已复制原始字节的本轮图片。“复用”包括此前候选、原生SVG和授权基础特效；不会冒称重绘。SVG交付含复用的空白出关纸签，具体见逐项记录。

目录联接与逐图实路径已核验在 D 盘。每张交付保留提示词、实际输入、哈希、目标/原生尺寸、alpha与退回原因。地图布局仍为规划候选；工具原生尺寸不一致的文件保留原图并注明待集成适配。

待处理项仍须继续，不代表全部完成。可选矿道傀儡没有确认的战斗消费者，明确排除，避免凭美术计划新增敌人。

机器可读进度：[ALL_ART_PROGRESS.json](ALL_ART_PROGRESS.json)。各批 `bulk_delivery.json` 为本轮全量清单，原有 `delivery.json` 保留历史首批记录。

文件核验：全部已交付文件通过哈希、解码/XML及要求的alpha检查。
