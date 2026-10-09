# 音频资源规格

音频系统已经接好：`scripts/presentation/audio_director.gd` 按 `data/audio.json` 的路径播放配乐、环境声和音效。文件不存在时，音效用程序合成的短音占位，配乐和环境声保持安静。把文件放到下列路径，运行 `play.cmd` 或 `check.cmd`（会先导入资源）即可生效，不需要改代码。

## 系统行为
- 四个音量分组：总音量、配乐、音效、环境声。音量在游戏内「设置」里调整，保存在 `user://settings.cfg`，与存档分开。
- 配乐随情境切换并交叉淡入淡出（约 1.2 秒）：所在地点 → 舆图 → 抉择事件 → 斗法 → 此生终结。
- 环境声跟随所在地点。配乐和环境声由代码强制循环，导入设置里不勾循环也没关系。
- 音效挂点：按钮点击、切换场景、启程、抵达、事件出现、作出抉择、斗法各阶段（蓄势、出招、命中、治疗、守御）、胜负、突破、此生终结。

## 技术规格

| 类型 | 格式 | 响度 | 其他 |
|---|---|---|---|
| 配乐 | OGG Vorbis，44.1 kHz，立体声 | 约 -16 LUFS | 1.5–3 分钟，首尾可无缝循环 |
| 环境声 | OGG Vorbis，44.1 kHz，立体声 | 约 -24 LUFS | 30–90 秒，无缝循环，不要有明显旋律 |
| 音效 | OGG Vorbis（或 WAV），单声道即可 | 峰值不超过 -3 dBFS | 尽量短，起音干脆 |

来源需为原创，或可商用且允许再分发的授权（如 CC0）。使用第三方素材时，在本文末尾记录来源与许可。

## 配乐 `assets/audio/music/`
风格建议：传统民乐为主（古琴、箫、笛、古筝、琵琶、编钟），节奏舒缓，避免过满的管弦铺底。

| 文件 | 情境 | 方向 |
|---|---|---|
| `qingyun_mountain.ogg` | 青云山 | 古琴与箫，清远、山门气象 |
| `qingshi_town.ogg` | 青石镇 | 笛与小打击，凡俗烟火、轻快 |
| `bailu_ferry.ogg` | 白鹭渡 | 古筝流水音型，开阔平和 |
| `yunxi_market.ogg` | 云溪坊市 | 琵琶与笛，热闹但不吵 |
| `songfeng_ridge.ogg` | 松风岭 | 箫与低音古琴，幽静 |
| `luoxia_valley.ogg` | 落霞谷 | 低沉弦乐垫与编钟，神秘、带危险感 |
| `ancient_cave.ogg` | 古修洞府 | 稀疏的钟磬与回声，古老 |
| `journey.ogg` | 舆图 | 行路感，中速 |
| `encounter.ogg` | 抉择事件 | 短小悬念，可循环 |
| `duel.ogg` | 斗法 | 鼓与琵琶轮指，紧张 |
| `life_ends.ogg` | 此生终结 | 缓慢、释然 |

## 环境声 `assets/audio/ambience/`

| 文件 | 地点 | 内容 |
|---|---|---|
| `mountain_wind_bells.ogg` | 青云山 | 山风、远处檐铃 |
| `town_street.ogg` | 青石镇 | 远处人声、犬吠、炊事 |
| `river_egrets.ogg` | 白鹭渡 | 流水、偶尔的鸟鸣 |
| `market_crowd.ogg` | 云溪坊市 | 人群嘈杂、吆喝（不要可辨识的台词） |
| `pine_wind.ogg` | 松风岭 | 松涛 |
| `valley_insects.ogg` | 落霞谷 | 虫鸣、远处兽吼 |
| `cave_drips.ogg` | 古修洞府 | 滴水、空洞回声 |

## 音效 `assets/audio/sfx/`

| 文件 | 挂点 | 方向 |
|---|---|---|
| `ui_click.ogg` | 按钮点击 | 轻木质点击 |
| `ui_page.ogg` | 切换场景、点选舆图 | 翻纸 |
| `travel_depart.ogg` | 启程 | 衣袂与脚步 |
| `travel_arrive.ogg` | 抵达 | 轻柔钟声 |
| `event_open.ogg` | 事件出现 | 一声磬 |
| `event_choice.ogg` | 作出抉择 | 短促木鱼 |
| `reminder_bell.ogg` | 约定提醒（预留） | 两声钟 |
| `battle_prepare.ogg` | 蓄势 | 气流聚集 |
| `battle_release.ogg` | 出招 | 破空 |
| `battle_impact.ogg` | 命中 | 沉闷撞击 |
| `battle_heal.ogg` | 治疗 | 上行的清亮音 |
| `battle_guard.ogg` | 守御 | 低沉护罩 |
| `battle_victory.ogg` | 斗法获胜 | 短乐句，上扬 |
| `battle_defeat.ogg` | 斗法落败 | 短乐句，下沉 |
| `realm_breakthrough.ogg` | 突破 | 渐强后释放 |
| `life_ends.ogg` | 此生终结 | 长钟声 |

## 第三方素材记录
（暂无）
