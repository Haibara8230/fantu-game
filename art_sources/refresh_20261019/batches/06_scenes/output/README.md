# 开局首批场景候选

本轮使用内置imagegen，生成目录已通过NTFS联接实际存储在D盘。这里只交候选，未替换正式游戏资源。

| 文件 | 内容 | 旧图目标规格 | 原生输出 |
|---|---|---|---|
| [qingshi_inn_quiet_room.png](qingshi_inn_quiet_room.png) | 青石客栈静房，首次闭关／领悟／突破 | `sect_chamber.png`，2400×600，RGB | 2172×724，RGB；中央4:1适配待正式集成确认 |
| [tianhe_ferry_day.png](tianhe_ferry_day.png) | 白鹭渡天河渡口日常基础 | `ferry_crossing.png`，2172×724，RGB；布局参考 `ferry_dock.png` | 2172×724，RGB |
| [tianhe_ferry_reflection.png](tianhe_ferry_reflection.png) | 同一渡口的月圆城影修正版 | 同上，沿用日常版摄像机和主要场景布局 | 2172×724，RGB |

静房延用07室内画法，渡口按原场景规范延用04地点画法。月夜城影已定向修正为倒置水中城影；初版保留在 `originals/`，不作为交付选用。城影仅是早期候选视觉，不代表后期整座照川城已定稿。

完整初始与修正提示词在 `prompts/`；真实输入路径／哈希、工具输出的逻辑与真实路径、目标及实测规格、透明度、修正关系与集成备注见 [delivery.json](delivery.json)。所有PNG保留原生生成字节，未用像素滤镜或批量风格处理。

后期项目暂缓；其余批次只读引用本次明确选用的候选，不修改本目录文件。接入前继续按真实消费者验证裁切与状态切换，不宣称已完成游戏回归。
