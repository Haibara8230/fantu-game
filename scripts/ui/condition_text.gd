extends RefCounted
## Human-readable requirements belong to presentation; Events remains the rule authority.
const Events = preload("res://scripts/core/events.gd")

static func missing(s, conditions: Array) -> String:
	var lines: Array[String] = []
	for condition: Dictionary in conditions:
		if not Events.met(s, condition):
			lines.append(describe(s, condition))
	return "；".join(lines)

## A future story branch stays undiscovered until its structural prerequisites hold.
static func future(s, conditions: Array) -> bool:
	for condition: Dictionary in conditions:
		if Events.met(s, condition):
			continue
		var key: String = condition.keys()[0]
		if key == "all" and future(s, condition[key]):
			return true
		if key == "any":
			if (condition[key] as Array).all(func(part: Dictionary) -> bool: return future(s, [part])):
				return true
		elif key == "not" and future(s, [condition[key]]):
			return true
		elif key in ["story_at", "story_state", "event_state", "event_applied", "flag", "realm_at_least", "stage_at_least", "rank_at_least"]:
			return true
	return false

static func describe(s, condition: Dictionary) -> String:
	var key: String = condition.keys()[0]
	var value: Variant = condition[key]
	match key:
		"all":
			return missing(s, value)
		"any":
			var alternatives: Array[String] = []
			for part: Dictionary in value:
				alternatives.append(describe(s, part))
			return "满足其一：" + "或".join(alternatives)
		"not":
			return "须尚未满足：" + describe(s, value)
		"realm_at_least":
			return "需%s（当前%s）" % [s.content.realm(int(value)).name, s.realm_name()]
		"stage_at_least":
			return "需%s（当前%s）" % [s.content.realm_title(int(value[0]), int(value[1])), s.realm_name()]
		"item_at_least":
			return "需%s %d（持有 %d）" % [s.content.item(str(value[0])).name, int(value[1]), s.pill_count(str(value[0]))]
		"stones_at_least":
			return "需灵石 %d（持有 %d）" % [int(value), int(s.player.stones)]
		"herbs_at_least":
			return "需灵草 %d（持有 %d）" % [int(value), s.herb_count()]
		"mind_at_least":
			return "需心境 %d（当前 %d）" % [int(value), int(s.player.mind)]
		"sense_at_least":
			return "需神识 %d（当前 %d）" % [int(value), s.sense()]
		"met", "talked":
			return "需%s%s" % ["结识" if key == "met" else "交谈过", s.person(str(value)).name]
		"relation_at_least":
			return "需与%s交情 %d（当前 %d）" % [s.person(str(value[0])).name, int(value[1]), s.favor(str(value[0]))]
		"at_location":
			return "需到%s" % s.content.locations[str(value)].name
		"story_at":
			var story: Dictionary = s.content.storylines[str(value[0])]
			for step: Dictionary in story.steps:
				if str(step.id) == str(value[1]):
					return "需推进「%s」：%s" % [story.title, step.get("goal", "等待人物后续传音")]
		"story_state":
			return "需「%s」%s" % [s.content.storylines[str(value[0])].title, {"none":"尚未开始", "active":"进行中", "done":"已完成", "closed":"已作罢"}.get(str(value[1]), "推进后续")]
		"event_state":
			return "需「%s」%s" % [s.content.events[str(value[0])].title, "已完成" if str(value[1]) == "completed" else "已过期"]
		"flag":
			for enemy: Dictionary in s.content.enemies.values():
				if enemy.get("world_flag", "") == str(value):
					return "需击败%s" % enemy.name
			for event: Dictionary in s.content.events.values():
				for effect: Dictionary in event.get("effects", []):
					if effect.get("flag", "") == str(value):
						return "需经历「%s」" % event.title
			return {"rushi_done":"需走完入世经历", "found_ruin":"需打听到古修洞府", "azhi_promised":"需答应阿芷的托付", "tiannan_known":"需听顾长庚说起天南", "spirit_eye_found":"需发现谷中灵眼", "hanjin_heard":"需听完韩烬的陈述"}.get(str(value), "需先推进相关剧情，见任务·剧情")
		"talent":
			return "需天赋「%s」" % s.Talents.definition(s.content, str(value)).name
		"rank_at_least":
			for rank: Dictionary in s.content.sect_data.ranks:
				if rank.id == value:
					return "需宗门身份「%s」" % rank.name
		"sect":
			return "需修习%s传承" % s.content.sects[str(value)].name
		"recipe":
			return "需掌握%s丹方" % s.content.alchemy_data.recipes[str(value)].name
		"grudge_pay":
			return "需灵石 %d（持有 %d）" % [s.Feuds.pay(s), int(s.player.stones)]
		"grudge":
			return "需尚有未了恩怨" if bool(value) else "需了结现有恩怨"
		"deed_at_least":
			var deed := str(value[0])
			var name: String = "击败%s" % s.content.enemies[deed.trim_prefix("win:")].name if deed.begins_with("win:") else {"duel":"斗法", "gather":"采集", "retreat_days":"闭关日数", "trade":"交易", "commission":"交付委托"}.get(deed, "历练")
			return "需%s %d 次（已达 %d）" % [name, int(value[1]), s.deed_count(deed)]
	return "需先推进相关剧情，见任务·剧情"
