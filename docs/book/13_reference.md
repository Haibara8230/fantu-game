# 附录二 数值速查

> 历史快照：本章保留 2026-10-14 版本的说明与数值，未逐项同步后续系统。旧价格、突破丹、宗门门槛、剧情及界面说明不能作为当前操作依据；现行入口见 [当前状态](../CURRENT_STATUS.md)、[游戏介绍](../GAME_INTRO.md) 和 [设计基线](../DESIGN_BASELINE.md)。本次仅整理状态，不把旧表宣称为重新验收的现行数值。

本附录把散落在各章的数值汇成表，全部由 `data/` 下的配置直接生成（2026-10-14）。配置改动后以配置为准。

## 一、境界与小阶段

| 境界 | 阶段 | 修为门槛 | 气血 | 灵力 | 攻击加成 | 神识 | 所需心境 | 单次闭关上限（日） |
|---|---|---|---|---|---|---|---|---|
| 炼气 | 初期 | 0 | 90 | 30 | 0 | 10 | 0 | 90 |
| 炼气 | 中期 | 500 | 100 | 34 | 2 | 12 | 6 | 120 |
| 炼气 | 后期 | 1000 | 110 | 38 | 4 | 14 | 14 | 150 |
| 炼气 | 圆满 | 1500 | 120 | 42 | 6 | 16 | 24 | 180 |
| 筑基 | 初期 | 0 | 140 | 50 | 8 | 30 | 36 | 360 |
| 筑基 | 中期 | 1500 | 155 | 55 | 10 | 33 | 50 | 540 |
| 筑基 | 后期 | 3000 | 170 | 60 | 12 | 36 | 66 | 720 |
| 筑基 | 圆满 | 4500 | 185 | 65 | 14 | 40 | 84 | 900 |
| 金丹 | 初期 | 0 | 230 | 80 | 18 | 60 | 110 | 1080 |
| 金丹 | 中期 | 4000 | 250 | 88 | 21 | 66 | 135 | 1440 |
| 金丹 | 后期 | 8000 | 270 | 96 | 24 | 72 | 160 | 1800 |
| 金丹 | 圆满 | 12000 | 290 | 104 | 27 | 80 | 190 | 2160 |
| 元婴 | 初期 | 0 | 360 | 130 | 32 | 120 | 230 | 2520 |
| 元婴 | 中期 | 10000 | 390 | 142 | 36 | 132 | 270 | 2880 |
| 元婴 | 后期 | 20000 | 420 | 154 | 40 | 144 | 310 | 3240 |
| 元婴 | 圆满 | 30000 | 450 | 166 | 44 | 160 | 360 | 3600 |
| 化神 | 初期 | 0 | 560 | 200 | 50 | 200 | 420 | 3960 |
| 化神 | 中期 | 25000 | 600 | 214 | 54 | 220 | 470 | 4320 |
| 化神 | 后期 | 50000 | 640 | 228 | 58 | 240 | 520 | 4680 |
| 化神 | 圆满 | 75000 | 680 | 242 | 62 | 260 | 580 | 5040 |

| 境界 | 寿元 | 闭关步长 | 连闭不倦 | 停留选项（日） | 修为封顶 | 突破所需修为 | 突破丹药 | 突破之难 |
|---|---|---|---|---|---|---|---|---|
| 炼气 | 120 | 10 | 180 | 1、10 | 2000 | 2000 | 筑基丹 | — |
| 筑基 | 220 | 30 | 540 | 1、10、30、90 | 6000 | 6000 | 凝元丹 | -15 |
| 金丹 | 400 | 30 | 720 | 1、10、30、90 | 16000 | 16000 | 化婴丹 | -25 |
| 元婴 | 700 | 90 | 1080 | 1、10、30、90、360 | 40000 | 40000 | 化神丹 | -35 |
| 化神 | 1200 | 90 | 1440 | 1、10、30、90、360 | 100000 | — | — | — |

## 二、对手

| id | 名称 | 属性 | 气血 | 伤害 | 境界要求 | 灵石 | 修为 | 回春草 | 掉落 | 贡献 | 人形 | 流派 |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| disciple | 外门同门 | 金 | 80 | 6–10 | — | 12 | 20 | 0 | — | — | 是 | — |
| wolf | 山谷妖狼 | 金 | 115 | 9–13 | — | 24 | 25 | 2 | — | — | 否 | — |
| serpent | 赤鳞妖蟒 | 火 | 250 | 16–23 | 筑基 | 100 | 200 | 5 | 100%，2–3 阶 | 100 | 否 | — |
| rogue | 拦路劫修 | 火 | 125 | 11–15 | — | 30 | 40 | 0 | 50%，1–2 阶 | — | 是 | 赤霄门 |
| cultivator | 修士 | 金 | 90 | 8–12 | — | 0 | 10 | 0 | — | — | 是 | — |
| ruin_rogue | 占据洞府的散修 | 土 | 175 | 13–18 | — | 60 | 80 | 2 | 100%，2–2 阶 | — | 是 | 玄岳宗 |
| mo_xiu | 魔修 | 水 | 420 | 28–38 | 金丹 | 120 | 300 | 0 | 50%，3–4 阶 | — | 是 | 沧澜阁 |
| mo_jiang | 魔潮魔将 | 火 | 650 | 36–46 | 金丹 | 1000 | 3000 | 0 | 100%，5–5 阶 | 500 | 是 | 赤霄门 |
| jiao | 千年蛟 | 水 | 800 | 44–56 | 元婴 | 400 | 1500 | 0 | 50%，4–5 阶 | — | 否 | — |
| jian_kui | 霞锈剑傀 | 金 | 480 | 30–40 | 金丹 | 0 | 400 | 0 | — | — | 是 | 青云剑宗 |
| can_nian | 古修残念 | 水 | 600 | 34–44 | 金丹 | 0 | 800 | 0 | — | — | 是 | 沧澜阁 |
| den_wolf | 石窟影狼 | 土 | 180 | 13–18 | — | 30 | 60 | 0 | — | — | 否 | — |

掉落的阶：1 凡品、2 黄阶、3 玄阶、4 地阶、5 天阶；一半是玉简，一半是法宝。

## 三、物品

| id | 名称 | 类别 | 基础价（收购价） | 稀有度 |
|---|---|---|---|---|
| huichun_grass | 回春草 | 灵草 | 4 | 0 |
| chiyan_flower | 赤炎花 | 灵草 | 9 | 1 |
| ninglu_grass | 凝露草 | 灵草 | 7 | 0 |
| lingzhi | 百年灵芝 | 灵草 | 60 | 3 |
| foundation_pill | 筑基丹 | 丹药 | 60 | 2 |
| huiqi_pill | 回气丹 | 丹药 | 7 | 0 |
| liaoshang_pill | 疗伤丹 | 丹药 | 10 | 0 |
| ningqi_pill | 凝气丹 | 丹药 | 30 | 1 |
| pozhang_pill | 破障丹 | 丹药 | 20 | 1 |
| liaoshang_pill_fine | 上品疗伤丹 | 丹药 | 20 | 1 |
| huiqi_pill_fine | 上品回气丹 | 丹药 | 14 | 1 |
| ningqi_pill_fine | 上品凝气丹 | 丹药 | 60 | 2 |
| pozhang_pill_fine | 上品破障丹 | 丹药 | 40 | 2 |
| foundation_pill_fine | 上品筑基丹 | 丹药 | 120 | 3 |
| auction_invitation | 云溪请柬 | 信物 | 0 | 2 |
| azhi_token | 刻字竹牌 | 信物 | 0 | 0 |
| polin_powder | 破鳞散 | 丹药 | 30 | 2 |
| peddler_pack | 货郎的货担 | 信物 | 0 | 0 |
| ore_qinggang | 青钢锭 | 材料 | 30 | 1 |
| ore_xuantie | 玄铁锭 | 材料 | 90 | 2 |
| ore_hantie | 寒铁精 | 材料 | 260 | 3 |
| silk_qing | 青丝 | 材料 | 30 | 1 |
| silk_xuancan | 玄蚕丝 | 材料 | 90 | 2 |
| silk_yunjin | 云锦 | 材料 | 260 | 3 |
| jade_qing | 青玉料 | 材料 | 30 | 1 |
| jade_mo | 墨玉料 | 材料 | 90 | 2 |
| jade_han | 寒玉髓 | 材料 | 260 | 3 |
| huashen_dan | 化神丹 | 丹药 | 12000 | 5 |
| huaying_dan | 化婴丹 | 丹药 | 3600 | 4 |
| ningyuan_dan | 凝元丹 | 丹药 | 900 | 3 |
| yanshou_dan | 延寿丹 | 丹药 | 150 | 2 |
| shouyuan_guo | 寿元果 | 天材地宝 | 400 | 3 |
| qiannian_shiru | 千年石乳 | 天材地宝 | 300 | 4 |
| jiuqu_lingshen | 九曲灵参 | 天材地宝 | 360 | 4 |
| recipe_liaoshang | 疗伤丹丹方 | 丹方 | 15 | 0 |
| recipe_huiqi | 回气丹丹方 | 丹方 | 15 | 0 |
| recipe_ningqi | 凝气丹丹方 | 丹方 | 40 | 1 |
| recipe_pozhang | 破障丹丹方 | 丹方 | 30 | 1 |
| recipe_foundation | 筑基丹丹方 | 丹方 | 100 | 3 |
| furnace_bronze | 青铜丹炉 | 器具 | 80 | 1 |
| furnace_purple | 紫铜丹炉 | 器具 | 150 | 2 |
| furnace_xuantie | 玄铁丹炉 | 器具 | 400 | 3 |
| kongho_fu | 控火符 | 器具 | 10 | 0 |

### 长街丹铺

| 货品 | 售价 |
|---|---|
| 筑基丹 | 120 |
| 凝元丹 | 900 |
| 化婴丹 | 3600 |
| 化神丹 | 12000 |
| 回气丹 | 15 |
| 疗伤丹 | 20 |
| 凝气丹 | 60 |
| 破障丹 | 40 |
| 疗伤丹丹方 | 30 |
| 回气丹丹方 | 30 |
| 青铜丹炉 | 160 |
| 控火符 | 20 |
| 青钢锭 | 30 |
| 青丝 | 30 |
| 青玉料 | 30 |

## 四、宗门兑换

| 兑换 | 贡献 | 限量 | 周期（日） | 身份 |
|---|---|---|---|---|
| 回气丹 | 8 | 3 | 30 | — |
| 疗伤丹 | 10 | 3 | 30 | — |
| 破障丹 | 30 | 2 | 360 | — |
| 凝气丹 | 35 | 2 | 360 | — |
| 筑基丹 | 150 | 1 | 720 | 外门精英 |
| 凝气丹丹方 | 40 | 1 | 360 | — |
| 破障丹丹方 | 40 | 1 | 360 | — |
| 筑基丹丹方 | 120 | 1 | 360 | 外门精英 |
| 紫铜丹炉 | 150 | 1 | 360 | 外门精英 |
| 玄铁丹炉 | 400 | 1 | 720 | 内门弟子 |
| 玄铁锭 | 50 | 3 | 180 | 内门弟子 |
| 玄蚕丝 | 50 | 3 | 180 | 内门弟子 |
| 墨玉料 | 50 | 3 | 180 | 内门弟子 |
| 凝元丹 | 600 | 1 | 1440 | 内门弟子 |
| 黄阶玉简（2 种轮换） | 50 | 1 | 90 | — |
| 玄阶玉简（1 种轮换） | 180 | 1 | 180 | 内门弟子 |
| 化婴丹 | 2000 | 1 | 2880 | 真传弟子 |
| 化神丹 | 6000 | 1 | 7200 | 真传弟子 |
| 地阶玉简（1 种轮换） | 450 | 1 | 360 | 真传弟子 |

## 五、路线与行为耗时

| 路线 | 天数 | 危险度 |
|---|---|---|
| 青云山 — 青石镇 | 2 | 0 |
| 青石镇 — 白鹭渡 | 3 | 1 |
| 白鹭渡 — 云溪坊市 | 2 | 0 |
| 青云山 — 松风岭 | 4 | 1 |
| 青石镇 — 松风岭 | 3 | 1 |
| 松风岭 — 落霞谷 | 3 | 2 |
| 云溪坊市 — 落霞谷 | 6 | 2 |
| 落霞谷 — 古修洞府 | 2 | 3 |

| 行为 | 日数 |
|---|---|
| 闭关（默认一档） | 30 |
| 静养（上限） | 30 |
| 采集 | 5 |
| 出售 | 0 |
| 购买 | 0 |
| 突破 | 90 |
| 斗法获胜整顿 | 3 |
| 斗法落败 | 15 |
| 撤离 | 2 |
| 客栈歇息 | 1 |
| 翻找洞府石室 | 5 |
| 事件斗法后整顿 | 1 |

## 六、规则常数（`rules`）

下表逐项列出 `world.json` 的 `rules`，各项的含义见正文相应的章节（闭关与心境见第三章，斗法见第四章，行情见第六章……）。

| 键 | 值 |
|---|---|
| `rules.starting_age` | 16 |
| `rules.starting_stones` | 30 |
| `rules.cultivate_xp` | 60 |
| `rules.retreat.fresh_days` | 180 |
| `rules.retreat.decline_days` | 720 |
| `rules.retreat.floor_percent` | 50 |
| `rules.retreat.recovery_per_day` | 2 |
| `rules.bottleneck.insight_needed` | 100 |
| `rules.bottleneck.insight.battle_win` | 20 |
| `rules.bottleneck.insight.spar` | 10 |
| `rules.bottleneck.insight.commission` | 25 |
| `rules.bottleneck.insight.event` | 15 |
| `rules.bottleneck.insight.consult` | 15 |
| `rules.fortune.epiphany.chance` | 0.02 |
| `rules.fortune.epiphany.per_days` | 10 |
| `rules.fortune.epiphany.days` | 10 |
| `rules.fortune.epiphany.places` | ["ferry", "ridge", "sect"] |
| `rules.fortune.epiphany.event` | "epiphany" |
| `rules.fortune.epiphany.talent` | "dunwu_yuyun" |
| `rules.fortune.epiphany.talent_chance` | 0.1 |
| `rules.fortune.brink.chance` | 0.05 |
| `rules.fortune.brink.hp_percent` | 15 |
| `rules.fortune.brink.talent` | "shengsi_lilian" |
| `rules.fortune.brink.talent_chance` | 0.1 |
| `rules.fortune.shiru.chance` | 0.3 |
| `rules.fortune.shiru.item` | "qiannian_shiru" |
| `rules.fortune.lingshen.chance` | 0.005 |
| `rules.fortune.lingshen.item` | "jiuqu_lingshen" |
| `rules.fortune.lingshen.location` | "wild" |
| `rules.fortune.spirit_eye.chance` | 0.02 |
| `rules.fortune.spirit_eye.location` | "wild" |
| `rules.fortune.spirit_eye.flag` | "spirit_eye_found" |
| `rules.fortune.spirit_eye.event` | "spirit_eye" |
| `rules.fortune.spirit_eye.sense_reference` | 10 |
| `rules.fortune.remnant.chance` | 0.3 |
| `rules.fortune.remnant.before_realm` | 1 |
| `rules.fortune.remnant.event` | "remnant_soul" |
| `rules.fortune.remnant.mind` | 30 |
| `rules.fortune.remnant.talent` | "qianbei_yize" |
| `rules.fortune.remnant.flaw` | "canhun_raoshen" |
| `rules.fortune.remnant.injury_days` | 360 |
| `rules.breakthrough.base` | [25, 35, 45, 55, 65] |
| `rules.breakthrough.pill_bonus` | [25, 15, 10] |
| `rules.breakthrough.mind_step` | 2 |
| `rules.breakthrough.mind_most` | 10 |
| `rules.breakthrough.method_root` | 5 |
| `rules.breakthrough.method_tier.2` | 3 |
| `rules.breakthrough.method_tier.3` | 6 |
| `rules.breakthrough.method_tier.4` | 9 |
| `rules.breakthrough.guard.favor` | 140 |
| `rules.breakthrough.guard.bonus` | 5 |
| `rules.breakthrough.guard.mentor` | "gu_changgeng" |
| `rules.breakthrough.guard.mentor_bonus` | 10 |
| `rules.breakthrough.guard.mentor_story` | "lineage" |
| `rules.breakthrough.guard.mentor_step` | "foundation" |
| `rules.breakthrough.eye.location` | "wild" |
| `rules.breakthrough.eye.flag` | "spirit_eye_found" |
| `rules.breakthrough.eye.bonus` | 10 |
| `rules.breakthrough.boons` | [{"id": "epiphany", "name": "顿悟", "bonus": 15, "grade": 1}, {"id": "brink", "name": "生死之间", "bonus": 10}] |
| `rules.breakthrough.lesson.bonus` | 5 |
| `rules.breakthrough.lesson.most` | 3 |
| `rules.breakthrough.least` | 5 |
| `rules.breakthrough.most` | 95 |
| `rules.breakthrough.failure.xp_percent` | 85 |
| `rules.breakthrough.failure.injury_days` | 90 |
| `rules.breakthrough.failure.injury_percent` | 50 |
| `rules.breakthrough.failure.mind` | 4 |
| `rules.breakthrough.demon.chance` | 0.6 |
| `rules.breakthrough.demon.slay_mind` | 6 |
| `rules.breakthrough.demon.slay_penalty` | 15 |
| `rules.breakthrough.demon.evade_penalty` | 10 |
| `rules.breakthrough.grades` | [{"id": "low", "name": "下品", "margin": 0, "stats": -5, "speed": -10}, {"id": "mid", "name": "中品", "margin": 10, "stats": 0, "speed": 0}, {"id": "high", "name… |
| `rules.breakthrough.core.foundation` | 2 |
| `rules.breakthrough.core.margins` | [0, 10, 30] |
| `rules.breakthrough.core.grades` | [{"id": "ninth", "name": "九品金丹", "stats": -5, "speed": -10}, {"id": "eighth", "name": "八品金丹", "stats": 0, "speed": -5}, {"id": "seventh", "name": "七品金丹", "st… |
| `rules.mind.gain.battle_win` | 2 |
| `rules.mind.gain.spar` | 1 |
| `rules.mind.gain.commission` | 4 |
| `rules.mind.gain.event` | 2 |
| `rules.mind.gain.consult` | 3 |
| `rules.mind.short_percent` | 50 |
| `rules.mind.ample_margin` | 10 |
| `rules.mind.ample_percent` | 120 |
| `rules.rest_full_days` | 12 |
| `rules.spirit_roots.elements` | ["metal", "wood", "water", "fire", "earth"] |
| `rules.spirit_roots.names` | {"metal": "金", "wood": "木", "water": "水", "fire": "火", "earth": "土"} |
| `rules.spirit_roots.grades` | [{"count": 1, "name": "天灵根", "weight": 5, "speed": 1.8}, {"count": 2, "name": "双灵根", "weight": 20, "speed": 1.4}, {"count": 3, "name": "三灵根", "weight": 35, "… |
| `rules.lifespan_warning_years` | 5 |
| `rules.root_study` | 20 |
| `rules.market.categories` | ["herb"] |
| `rules.market.spread` | 0.15 |
| `rules.market.drop` | 0.02 |
| `rules.market.floor` | 0.7 |
| `rules.market.recover_per_day` | 0.2 |
| `rules.flight.realm` | 2 |
| `rules.flight.days_percent` | 50 |
| `rules.longevity.defy_chance` | 0.35 |
| `rules.longevity.defy_mind_step` | 0.01 |
| `rules.longevity.defy_least` | 0.1 |
| `rules.longevity.defy_most` | 0.6 |
| `rules.longevity.defy_years` | 10 |
| `rules.longevity.defy_injury_days` | 360 |
| `rules.art_slots` | 4 |
| `rules.method_slots` | 2 |
| `rules.cultivate_options` | [30, 90, 360] |
| `rules.wait_options` | [1, 10] |
| `rules.inn_price` | 5 |
| `rules.duel.draw` | [3, 4, 5, 6, 7] |
| `rules.duel.first_extra` | 1 |
| `rules.duel.root_weight` | 3 |
| `rules.duel.other_weight` | 1 |
| `rules.duel.qi_per_orb` | 5 |
| `rules.duel.hand_least` | 5 |
| `rules.duel.convert` | 2 |
| `rules.duel.counter` | 1.3 |
| `rules.duel.countered` | 0.75 |
| `rules.duel.pills` | 3 |
| `rules.duel.guard_orbs` | 1 |
| `rules.duel.foe_draw` | [3, 4, 5, 6, 7] |
| `rules.duel.generates` | {"metal": "water", "water": "wood", "wood": "fire", "fire": "earth", "earth": "metal"} |
| `rules.duel.overcomes` | {"metal": "wood", "wood": "earth", "earth": "water", "water": "fire", "fire": "metal"} |
| `rules.lineage.home` | "qingyun" |
| `rules.lineage.study_days` | 30 |
| `rules.letters.kept` | 60 |
| `rules.requests.period_days` | 180 |
| `rules.requests.chance` | 0.25 |
| `rules.requests.items` | ["huichun_grass", "ninglu_grass", "chiyan_flower", "huiqi_pill", "liaoshang_pill"] |
| `rules.requests.count` | [1, 3] |
| `rules.requests.favor` | 12 |
| `rules.requests.mind` | 2 |
| `rules.requests.reward_scale` | 1.5 |
| `rules.inquire.days` | 1 |
| `rules.inquire.price` | 2 |
| `rules.inquire.repeat_after_days` | 90 |
| `rules.encounter_chance` | [0.08, 0.18, 0.3, 0.42] |
| `rules.ruin_search.stones` | [10, 30] |
| `rules.ruin_search.herbs` | [1, 3] |
| `rules.ruin_search.pill_chance` | 0.1 |
| `rules.ruin_search.manual_chance` | 0.15 |
| `rules.ruin_search.manual_tiers` | [2, 2] |
| `rules.action_cooldowns.search_ruin` | 90 |

## 七、编年史的记载

编年史以结构化方式记录每件事（类别 id、参数、日期），显示时套用 `data/chronicle.json` 的文字模板。下表列出全部模板，花括号里是参数。

| 类别 | 筛选分组 | 文字 |
|---|---|---|
| legacy | 修炼 | {text} |
| start | 修炼 | 你拜入青云山。先修炼功法、积攒灵石，再寻筑基之机。 |
| cultivate | 修炼 | 闭关 {duration}，修为增加 {xp}，灵力恢复。 |
| rest | 修炼 | 静养 {duration}，气血与灵力尽复。 |
| gather | 行旅 | 在山谷采得 {amount} 株灵草。 |
| sell | 交易与委托 | 售出全部灵草，获得 {revenue} 灵石。 |
| buy_pill | 交易与委托 | 花费 {price} 灵石，购入一枚筑基丹。 |
| breakthrough | 修炼 | 闭关 {duration}，丹田化海，你已踏入{realm_name}。 |
| travel | 行旅 | 跋涉 {duration}，抵达{location_name}。 |
| fly | 行旅 | 御剑而行 {duration}，落在{location_name}。 |
| choose_sect | 修炼 | 开始研习{sect_name}传承，神通已更换。 |
| skill_shield | 斗法 | 施展{skill_name}，结成 {amount} 点护盾。 |
| guard_turn | 斗法 | 凝神守御，结束这一回合：对手的出手减半，下回合多抽 {amount} 颗灵气。 |
| duel_pill | 斗法 | 斗法间隙服下{item_name}。 |
| tournament_enter | 斗法 | 你在演武坪报名参加了外门小比。 |
| study_lineage | 修炼 | 在传功堂研习{sect_name}传承 {duration}，神通已更换。 |
| battle_start | 斗法 | 与{enemy_name}展开斗法。 |
| skill_attack | 斗法 | 施展{skill_name}，造成 {amount} 点伤害。 |
| skill_heal | 斗法 | 施展{skill_name}，恢复 {amount} 气血。 |
| skill_guard | 斗法 | 施展{skill_name}，恢复 {amount} 气血，本回合伤害减半。 |
| defend | 斗法 | 凝神守御，恢复 {amount} 灵力，本回合受到的伤害减半。 |
| enemy_attack | 斗法 | {enemy_name}反击，造成 {amount} 点伤害。 |
| battle_victory | 斗法 | 斗法获胜，获得 {stones} 灵石、{xp} 修为、{herbs} 灵草。 |
| battle_defeat | 斗法 | 斗法落败，被救回青云山。损失 {lost} 灵石，静养后可再出发。 |
| flee | 斗法 | 收起神通，撤出斗法。修为与物品保留，耗时 {duration}。 |
| serpent_slain | 斗法 | 赤鳞妖蟒伏诛，落霞谷灵泉重现。山中消息渐渐传开，世事仍在流转。 |
| wait | 修炼 | 在{location_name}停留 {duration}。 |
| lifespan_warning | 修炼 | 寿元将尽：你只余 {years} 年光阴。 |
| lifespan_end | 修炼 | 寿元耗尽，你坐化于{location_name}，享年 {age} 岁。 |
| ascended | 修炼 | 你踏上天河渡桥，回望人间一眼，便再没有回头。享年 {age} 岁，白日飞升。 |
| lifespan_brink | 修炼 | 大限已至。气机一点点散去，是就此坐化，还是逆天一搏？ |
| longevity_gained | 修炼 | 服下{item_name}，寿元多了 {years} 年。 |
| defy_success | 修炼 | 你强提最后一口真元，逆冲死关——竟硬生生续上了 {years} 年寿元，只是经脉受创，须将养许久。 |
| defy_failed | 修炼 | 逆天续命不成，最后一口真元散尽。 |
| gather_at | 行旅 | 在{location_name}采得 {amount} 株灵草。 |
| inn_rest | 修炼 | 在青石客栈歇息 {duration}，花去 {price} 灵石，气血与灵力尽复。 |
| summit_start | 斗法 | 五宗论道第 {round} 轮，对手是{foe}。 |
| summit_round | 斗法 | 五宗论道第 {round} 轮，你胜了{foe}，得灵石 {stones}。 |
| summit_out | 斗法 | 五宗论道第 {round} 轮，你败给了{foe}，就此下台。 |
| summit_champion | 斗法 | 五宗论道，你四战四胜，替青云夺得魁首！得灵石 {stones} 与{item_name}。 |
| forged | 炼丹与灵田 | 在器铺炼器 {duration}，打出{item_name}。 |
| companion_bound | 人物 | 你与{npc_name}结为道侣，往后修行路上，有人同行。 |
| companion_gone | 人物 | 道侣{npc_name}先你一步而去。你在静室里坐了很久。 |
| sworn_bound | 人物 | 你与{npc_name}焚香结拜，从此以兄弟姊妹相称。 |
| disciple_taken | 人物 | 你收{npc_name}为徒，传下本门心法。 |
| disciple_taught | 人物 | 你为弟子{npc_name}讲道 {duration}，教学相长，自己也有所得。 |
| duty_taken | 交易与委托 | 你在执事堂领了{duty}的差事。 |
| auction_open | 交易与委托 | {auction_name}开场，今日拍品 {amount} 件。 |
| auction_won | 交易与委托 | 在{auction_name}以 {stones} 灵石拍得{loot_text}。 |
| auction_lost | 交易与委托 | {auction_name}上，{loot_text}被{npc_name}以 {stones} 灵石拍走。 |
| auction_unsold | 交易与委托 | {auction_name}上，{loot_text}无人出价，流拍。 |
| auction_close | 交易与委托 | {auction_name}落幕。 |
| cave_enter | 行旅 | 在{cave_name}探入{room_name}，费时 {duration}。 |
| cave_trap_seen | 行旅 | 神识扫过，识破了{room_name}里的{trap}，从旁绕了过去。 |
| cave_trap_grazed | 行旅 | {room_name}里的{trap}骤然发动，你拼着最后一口气躲了过去。 |
| cave_trap_sprung | 行旅 | {room_name}里的{trap}骤然发动，你受伤 {amount} 点气血。 |
| cave_loot | 行旅 | 在{room_name}找到{loot_text}。 |
| cave_stones | 行旅 | 在{room_name}拾得灵石 {stones}。 |
| cave_hidden | 行旅 | 以神识看破{hidden}，耗 {qi} 灵力破开禁制。 |
| calamity_turned | 行旅 | 魔潮魔将伏诛于山门之前，魔潮群龙无首，攻势一下子散了。 |
| chenxia_puppet_down | 行旅 | 剑冢里的霞锈剑傀散成了一地锈铁，通往藏经石阁的路开了。 |
| chenxia_remnant_down | 行旅 | 古修的残念对你一揖，散进了灯影里。 |
| den_cleared | 行旅 | 兵器室里的石窟影狼伏诛，再往里去的路通了。 |
| search_ruin | 行旅 | 在洞府石室翻找 {duration}，得灵石 {stones}、灵草 {herbs}、筑基丹 {pills}。 |
| ruin_cleared | 斗法 | 占据古修洞府的散修败走，石室从此归于寂静。 |
| gift | 人物 | 你赠给{npc_name}一株灵草，好感 +{favor}。 |
| stage_up | 修炼 | 修为精进，你已至{realm_name}。 |
| xp_held | 修炼 | 修为卡在瓶颈，其中 {xp} 点未能化入。 |
| gather_items | 行旅 | 在{location_name}采得{loot_text}。 |
| sell_all | 交易与委托 | 售出{loot_text}，得灵石 {revenue}。 |
| sell_item | 交易与委托 | 售出{item_name}×{count}，得灵石 {revenue}。 |
| buy_item | 交易与委托 | 花费 {price} 灵石，购得{item_name}。 |
| use_item | 修炼 | 服下{item_name}。 |
| loot | 行旅 | 缴获{loot_text}。 |
| learn | 修炼 | 参悟 {duration}，习得{technique_name}。 |
| spar_win | 斗法、人物 | 你在切磋中胜过{npc_name}，修为 +{xp}，彼此更添几分敬意。 |
| spar_lose | 斗法、人物 | {npc_name}点到为止，你输了这一场切磋，却也有所领悟。 |
| spar_start | 斗法、人物 | 你与{npc_name}切磋。 |
| rumor_auction | 奇遇与传闻 | 坊间传言：明年三四月间，云溪坊市将有一场不对外的拍卖，须持请柬，或经熟人引荐方可入场。 |
| rumor_person | 人物、奇遇与传闻 | 听说{npc_name}（{title}）近来常在{location_name}一带。 |
| rumor_ruin | 奇遇与传闻 | 茶客说落霞谷深处有座古修洞府，听雨茶馆的说书先生最清楚它的来历。 |
| rumor_serpent | 奇遇与传闻 | 落霞谷的赤鳞妖蟒越来越躁动，有人说它迟早要冲出灵泉。 |
| rumor_sealed | 奇遇与传闻 | 落霞谷还封着，听说宗门长老要过几年才会出手。 |
| rumor_stock | 奇遇与传闻 | 云溪坊市本月新到了{item_name}。 |
| rumor_tournament | 奇遇与传闻 | 青云剑宗的外门小比快到了，听说头名能得一卷好功法。 |
| rumor_commission | 奇遇与传闻 | {board_name}新贴了几张委托，报酬还算丰厚。 |
| rumor_none | 奇遇与传闻 | 众人聊的都是些家长里短，没什么要紧的消息。 |
| quest_accept | 交易与委托 | 接下委托：{quest_title}。 |
| quest_done | 交易与委托 | 完成委托「{quest_title}」，得灵石 {stones}、修为 {xp}。 |
| quest_expired | 交易与委托 | 委托「{quest_title}」已过期限，只得作罢。 |
| tournament_round | 斗法、人物 | 小比第 {round} 轮，你胜过了{npc_name}。 |
| tournament_champion | 斗法 | 你在外门小比中连胜三轮，夺得头名，得灵石 {stones}、修为 {xp}与宗门赏赐的{item_name}。 |
| tournament_out | 斗法、人物 | 小比第 {round} 轮，你败给了{npc_name}，止步于此。 |
| obituary | 人物 | 传来消息：{npc_name}已经故去，享年 {age} 岁。 |
| sound | 人物、剧情与传音 | 你与{npc_name}互留了传音符，往后可以传音往来。 |
| help | 人物 | 你送给{npc_name}{loot_text}，解了对方的燃眉之急。好感 +{favor}，得灵石 {stones}。 |
| talent_gained | 修炼 | 你身上多了一样天赋：「{talent_name}」。 |
| talents_awaken | 修炼 | 你体内似有什么苏醒了。静坐内视，才知自己生来便有：{talents_text}。 |
| contribution | 奇遇与传闻 | {reason}，记宗门贡献 {amount}。 |
| rank_up | 奇遇与传闻 | 你晋升为青云剑宗{rank_name}。{rank_words} |
| stipend | 奇遇与传闻 | 你在执事堂领了 {months} 个月的月俸，共 {stones} 灵石。 |
| exchange | 奇遇与传闻 | 你用 {price} 点宗门贡献换得{item_name}。 |
| donate | 奇遇与传闻 | 你向宗门捐献{loot_text}，记贡献 {amount}。 |
| consult | 人物 | 你向{npc_name}请教了 {duration}，颇有所得。 |
| taught_by | 人物 | {npc_name}把自己的{technique_name}传给了你，写成一枚玉简。 |
| invite_kept | 人物 | 你如约去找{npc_name}切磋。 |
| invite_spar_done | 人物 | 这场约好的切磋，让你与{npc_name}更亲近了些（好感 +{favor}）。 |
| invite_missed | 人物 | 你没有赴{npc_name}的约，对方有些不快。 |
| outing | 人物 | 你与{npc_name}同在{location_name}采药，收获翻倍。 |
| loan_made | 人物 | 你借给{npc_name} {amount} 灵石。 |
| loan_refused | 人物 | 你婉拒了{npc_name}借钱的请求。 |
| loan_lost | 人物 | {npc_name}已经故去，借出的 {amount} 灵石再也收不回来了。 |
| aid | 人物 | 你以传音符求援，{npc_name}应声而至，一击打出 {amount} 点伤害。 |
| breakthrough_grade | 修炼 | 根基品质：{grade_name}。 |
| breakthrough_core_grade | 修炼 | 金丹品级：{grade_name}。 |
| breakthrough_failed | 修炼 | 闭关 {duration}，冲关失败：药力散尽，修为跌回 {xp}，经脉受创，需将养 {injury} 日。所幸性命无碍，有了这番前车之鉴，下次把握更大。 |
| heart_demon | 修炼 | 突破关头，心魔丛生。 |
| demon_slain | 修炼 | 你斩尽心魔，道心更坚，心境 +{mind}。 |
| demon_lingers | 修炼 | 心魔未能斩尽，萦绕不去，此番突破的把握少了 {points} 分。 |
| demon_evaded | 修炼 | 你避开心魔，守住了灵台，此番突破的把握少了 {points} 分。 |
| boon_brink | 奇遇与传闻 | 生死一线之间，你忽有所悟。 |
| boon_breach | 奇遇与传闻 | 灵光一现，困你许久的瓶颈应声而破。 |
| boon_ready | 奇遇与传闻 | 这番{boon_name}的感悟留在心头，下次突破把握更大，根基也会更稳。 |
| boon_treasure | 奇遇与传闻 | 你在{location_name}意外得了一样天材地宝：{item_name}！ |
| remnant_blessed | 奇遇与传闻 | 残魂化作清光没入你的眉心，前辈的感悟在经脉中缓缓流转。下一次突破，必成无疑。 |
| remnant_seized | 奇遇与传闻 | 灌顶刚开始，残魂便露出狰狞面目——它要夺舍！你拼死守住识海，将它磨灭，自己也重伤难起，需将养 {days} 日，识海里留下了暗伤。 |
| read_recipe | 炼丹与灵田 | 研读{item_name}，把主药、药引与火候一一记下。 |
| alchemy_done | 炼丹与灵田 | 开炉 {duration}，炼成{loot_text}。 |
| alchemy_fine | 炼丹与灵田 | 开炉 {duration}，启炉时异香满室，炼成{loot_text}！ |
| alchemy_fail | 炼丹与灵田 | 开炉 {duration}，火候失当，一炉{item_name}化作了药渣。 |
| alchemy_burst | 炼丹与灵田 | 开炉 {duration}，武火过猛，丹炉轰然炸开，一炉{item_name}尽毁，你被炉火灼伤，气血 -{amount}。 |
| field_plant | 炼丹与灵田 | 在洞府灵田种下一株{item_name}，约 {duration} 后可收。 |
| field_harvest | 炼丹与灵田 | 灵田收获{loot_text}。 |
| field_upgrade | 炼丹与灵田 | 灵田重新翻整、引来灵泉，如今已是{field}。 |
