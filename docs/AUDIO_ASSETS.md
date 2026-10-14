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
| 配乐 | OGG Vorbis，44.1 kHz，立体声 | 日常约 -18 LUFS；斗法 -17，结局 -20 | 当前 64–228 秒，循环接缝已处理 |
| 环境声 | OGG Vorbis，44.1 kHz，立体声 | 约 -24 LUFS | 30–90 秒，无缝循环，不要有明显旋律 |
| 音效 | OGG Vorbis（或 WAV），单声道即可 | 峰值不超过 -3 dBFS | 尽量短，起音干脆 |

来源需为原创，或可商用且允许再分发的授权（如 CC0）。使用第三方素材时，在本文末尾记录来源与许可。

## 配乐 `assets/audio/music/`

**已接入（2026-10-14）**：六首作品制成七个 OGG，覆盖七处地点、舆图、事件、斗法与结局共十一种情境。相近地点共用配乐；修改 `data/audio.json` 的 `music` 对应项即可单独换曲。配乐保持传统拨弦、笛音和克制的氛围方向，声音以实际下载作品为准。

| 文件 | 情境 | 作品与作者 | 时长 | 许可 |
|---|---|---|---|---|
| `lotus_pond.ogg` | 青云山、松风岭 | Lotus Pond · BiteMe Games | 64 秒 | CC0 1.0 |
| `asian_oriental_2.ogg` | 青石镇、云溪坊市 | Asianoriental2 · Tozan | 182 秒 | CC0 1.0 |
| `river_flute.ogg` | 白鹭渡 | River Flute · Kevin MacLeod | 180 秒 | CC BY 4.0 |
| `eastern_thought.ogg` | 落霞谷、古修洞府、抉择事件 | Eastern Thought · Kevin MacLeod | 228 秒 | CC BY 4.0 |
| `asian_oriental_1.ogg` | 舆图 | Asianoriental1 · Tozan | 94 秒 | CC0 1.0 |
| `dragon_dance.ogg` | 斗法 | Dragon Dance · BiteMe Games | 约 68.57 秒 | CC0 1.0 |
| `river_flute_ending.ogg` | 此生终结 | River Flute · Kevin MacLeod（另一节选） | 120 秒 | CC BY 4.0 |

BiteMe 使用作者提供的循环版本；Tozan 与 Kevin MacLeod 的作品作节选和首尾交叉衔接。全部重采样至 44.1 kHz、调整响度，并作 5 毫秒接缝微淡化；已解码检查响度、峰值、时长和边界跳变。实际音色及长期聆听感仍可随试玩反馈更换。

鸣谢保存在 `data/audio.json` 的 `music_credits`，游戏内可从「人物 · 系统 · 配乐鸣谢」查看作者、修改说明、作品来源与许可。资源目录另附 `CREDITS.txt`、完整许可文本和 `manifest.json`（来源、剪辑参数、文件校验和）。本轮仅补配乐，环境声仍按下列规格等待素材。

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

**现状（2026-10-13）**：音效已换成 CC0 素材（见下方第三方素材记录），按 `data/audio.json` 的 `sfx` 表挂接。每个挂点列出几个文件，播放时随机取一个（不连着重复同一个），音高在 0.92–1.08 之间随机（可按挂点另设 `pitch`、`volume`）。斗法的出招与命中按元素区分：`release_sword / fire / water / ice / wood / earth / beast`、`impact_` 同上，重击另叠 `impact_heavy`；剑类蓄势用 `prepare_sword`（拔剑声）。下表是原先的规格，作为将来换成定制音效时的方向，文件名不再使用。


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
| `battle_surge.ogg` | 天阶神通出招（叠在出招音下） | 低频轰鸣，渐强后骤然释放 |
| `battle_victory.ogg` | 斗法获胜 | 短乐句，上扬 |
| `battle_defeat.ogg` | 斗法落败 | 短乐句，下沉 |
| `realm_breakthrough.ogg` | 突破 | 渐强后释放 |
| `life_ends.ogg` | 此生终结 | 长钟声 |

## 第三方素材记录

下表音效与粒子素材为 CC0。配乐分别使用 CC0 1.0 或 CC BY 4.0，作品来源与署名另见下文及游戏内「配乐鸣谢」。

| 素材 | 作者与来源 | 位置 |
|---|---|---|
| Impact Sounds（选 45 个：金属、拳击、软物、玻璃、木、矿石、钢板、钟、草地脚步） | Kenney，https://kenney.nl/assets/impact-sounds | `assets/audio/sfx/kenney_impact/` |
| RPG Audio（选 13 个：拔刀、刀刃、衣袂、翻书、劈砍） | Kenney，https://kenney.nl/assets/rpg-audio | `assets/audio/sfx/kenney_rpg/` |
| Interface Sounds（选 14 个：点击、选择、打开、确认、钟声） | Kenney，https://kenney.nl/assets/interface-sounds | `assets/audio/sfx/kenney_ui/` |
| 80 CC0 RPG SFX（选 23 个：刀刃、法术、火系法术、石块、宝石、妖兽吼叫、木） | rubberduck，https://opengameart.org/content/80-cc0-rpg-sfx | `assets/audio/sfx/rubberduck/` |
| Particle Pack（选 37 张，缩到 256 px：火花、星光、剑痕、光迹、烟尘、碎土、法阵、火焰、光圈） | Kenney，https://kenney.nl/assets/particle-pack | `assets/art/vfx/` |

各 Kenney 素材包的许可文件随素材放在对应目录（`License.txt`）。

### 第三方配乐来源

| 作品 | 作者与官方下载页 | 许可 |
|---|---|---|
| Lotus Pond、Dragon Dance | [BiteMe Games](https://bitemegames.itch.io/chinese-game-music) | [CC0 1.0](https://creativecommons.org/publicdomain/zero/1.0/) |
| Asianoriental1 | [Tozan](https://opengameart.org/content/asianoriental1) | CC0 1.0 |
| Asianoriental2 | [Tozan](https://opengameart.org/content/asianoriental2) | CC0 1.0 |
| Eastern Thought | [Kevin MacLeod / incompetech](https://incompetech.com/music/royalty-free/index.html?isrc=USUAN1100682) | [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/) |
| River Flute | [Kevin MacLeod / incompetech](https://incompetech.com/music/royalty-free/index.html?isrc=USUAN1900005) | CC BY 4.0 |

“Eastern Thought” and “River Flute” by Kevin MacLeod (incompetech.com), licensed under Creative Commons Attribution 4.0 International: https://creativecommons.org/licenses/by/4.0/ . Game versions are edited excerpts, looped, resampled and loudness adjusted; see `assets/audio/music/manifest.json` for precise changes. These credits do not imply endorsement.
