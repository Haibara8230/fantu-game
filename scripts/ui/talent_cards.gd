extends RefCounted
## How talents look: a tier-coloured chip per talent with its effects in the tooltip, and a row of them.
## The words for each modifier live here; the rules live in talents.gd.
const Talents = preload("res://scripts/core/talents.gd")

## Modifier names and how their numbers read: "%" percentages, "" plain numbers, "年" years, "点" points.
const WORDS := {
	"comprehension": ["悟性", "点"], "hp_flat": ["气血底子", ""], "hp_growth": ["境界气血增长", "%"],
	"sense_flat": ["神识底子", ""], "speed_flat": ["遁速", ""], "dao_realm": ["每大境界额外悟道", "点"], "immortal_start": ["化神起始仙性", "点"],
	"cultivation": ["修炼速度", "%"], "max_hp": ["气血上限", "%"], "max_qi": ["灵力上限", "%"], "attack": ["攻击", ""],
	"defense": ["减伤", "%"], "damage_metal": ["金系神通", "%"], "damage_wood": ["木系神通", "%"], "damage_water": ["水系神通", "%"],
	"damage_fire": ["火系神通", "%"], "damage_earth": ["土系神通", "%"], "damage_all": ["神通威力", "%"], "lifespan": ["寿元", "年"],
	"retreat_days": ["单次闭关上限", "%"], "fresh_days": ["闭关不倦", "%"], "insight": ["历练感悟", "%"], "mind_gain": ["心境增长", "%"],
	"mind_need": ["境界所需心境", "%"], "breakthrough": ["突破成功率", "点"], "pill": ["丹药药效", "%"], "pill_cooldown": ["丹毒积累", "%"], "alchemy": ["炼丹成功率", "%"],
	"grade": ["根基与金丹品质提升几率", "%"], "demon": ["抵御心魔", "%"], "boon": ["机缘几率", "%"], "study": ["参悟耗时", "%"],
	"gather": ["采集收获", "%"], "sell": ["卖价", "%"], "buy": ["买价", "%"], "favor": ["好感增长", "%"], "travel": ["行路耗时", "%"],
	"encounter": ["途中遇险", "%"], "rest": ["养伤耗时", "%"], "stones": ["初始灵石", ""],
	"orb_draw": ["斗法每回合多抽灵气", ""], "orb_cap": ["灵气上限", ""], "orb_first": ["斗法开局多抽灵气", ""],
	"orb_metal": ["金灵气更易抽到", ""], "orb_wood": ["木灵气更易抽到", ""], "orb_water": ["水灵气更易抽到", ""],
	"orb_fire": ["火灵气更易抽到", ""], "orb_earth": ["土灵气更易抽到", ""], "sense": ["神识", ""],
}

## "修炼速度 +10%、寿元 +3 年", in the order of Talents.MODIFIERS.
static func effects_text(mods: Dictionary) -> String:
	var parts: Array[String] = []
	for key: String in Talents.MODIFIERS:
		if not mods.has(key) or int(mods[key]) == 0:
			continue
		var word: Array = WORDS[key]
		var amount := int(mods[key])
		var unit: String = " 年" if word[1] == "年" else ("%" if word[1] == "%" else (" 点" if word[1] == "点" else ""))
		parts.append("%s %s%d%s" % [word[0], "+" if amount > 0 else "", amount, unit])
	return "、".join(parts) if not parts.is_empty() else "并无实效"

## The tooltip of a talent: its tier, its words and its effects, and what an 出身 brings from home.
static func tooltip(content, id: String) -> String:
	var talent: Dictionary = Talents.definition(content, id)
	var tier: Dictionary = Talents.tier_of(content, id)
	var text := "%s · %s\n%s\n%s" % [talent.get("name", id), tier.get("name", ""), talent.get("description", ""), effects_text(talent.get("mods", {}))]
	var brought := start_text(content, talent.get("start", []))
	return text + ("\n开局带：" + brought if not brought.is_empty() else "")

## What a talent's `start` hands the player at the beginning, in words: "回春草 ×4、黄阶玉简一枚（功法随机）".
static func start_text(content, effects: Array) -> String:
	var parts: Array[String] = []
	var tiers: Array = content.technique_data.tiers
	for effect: Dictionary in effects:
		var key: String = effect.keys()[0]
		var value: Variant = effect[key]
		match key:
			"item":
				parts.append("%s ×%d" % [content.item(str(value[0])).get("name", value[0]), int(value[1])])
			"gear":
				var piece: Dictionary = content.equipment(str(value))
				parts.append("%s（%s）" % [piece.get("name", value), piece.get("tier_name", "")])
			"manual":
				parts.append("%s玉简一枚（功法随机）" % tiers[int(value) - 1].name)
			"method":
				parts.append("%s心法玉简一枚（随第一行灵根）" % tiers[int(value) - 1].name)
			"slip":
				parts.append("《%s》玉简" % content.technique(str(value)).get("name", value))
			"stones":
				parts.append("灵石 %d" % int(value))
	return "、".join(parts)

## A talent as a small tag in its tier's colour.
static func chip(ui, content, id: String) -> PanelContainer:
	var tier: Dictionary = Talents.tier_of(content, id)
	var color := Color(str(tier.get("color", "#d6d0c2")))
	var tag := PanelContainer.new()
	tag.add_theme_stylebox_override("panel", ui.style(Color(color, 0.16), color, 6))
	tag.tooltip_text = tooltip(content, id)
	tag.mouse_filter = Control.MOUSE_FILTER_PASS
	var name: Label = ui.label(str(Talents.definition(content, id).get("name", id)), 15, color)
	name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tag.add_child(name)
	return tag

## A flowing row of chips, talents first and flaws after; a word when there are none.
static func row(ui, content, born: Dictionary) -> HFlowContainer:
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 8)
	flow.add_theme_constant_override("v_separation", 6)
	for id: Variant in born.get("talents", []) + born.get("flaws", []):
		flow.add_child(chip(ui, content, str(id)))
	if flow.get_child_count() == 0:
		flow.add_child(ui.label("生来平平，并无天赋", 15, ui.MUTED))
	return flow

## "资质 · 上等" in the grade's colour.
static func aptitude_label(ui, grade: Dictionary) -> Label:
	return ui.label("资质 · %s" % grade.name, 16, Color(str(grade.color)))
