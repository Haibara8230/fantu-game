extends RefCounted
## Read-only task instructions derived from the actual step, interaction and event rules.
## No quest progression or reward application belongs in this presentation helper.
const ConditionText = preload("res://scripts/ui/condition_text.gd")
const Calendar = preload("res://scripts/core/calendar.gd")
const Sources = preload("res://scripts/core/sources.gd")

static func describes(conditions: Array, key: String, value: Variant) -> bool:
	for condition: Dictionary in conditions:
		if condition.get(key) == value:
			return true
		for nested: String in ["all", "any"]:
			if condition.has(nested) and describes(condition[nested], key, value):
				return true
	return false

static func place_name(s, place: String, person_id: String = "") -> String:
	if not s.content.locations.has(place):
		return "暂无明确地点"
	var name := str(s.content.locations[place].name)
	var region: String = s.content.region_of(place)
	if s.content.regions.has(region):
		name = str(s.content.regions[region].name) + " · " + name
	if not person_id.is_empty():
		var person: Dictionary = s.person(person_id)
		for spot: Dictionary in s.content.locations[place].spots:
			if str(spot.id) == str(person.get("spot", "")):
				name += " → " + str(spot.name)
	return name

## Only reveal alternatives from the current branch. Material/stat shortages are displayed, not hidden.
static func _known_branch(s, conditions: Array) -> bool:
	for c: Dictionary in conditions:
		if c.has("all") and not _known_branch(s, c.all):
			return false
		if c.has("any") and not c.any.any(func(part: Dictionary) -> bool: return _known_branch(s, [part])):
			return false
		if c.has("flag") or c.has("story_state") or c.has("not"):
			if not s.Events.met(s, c):
				return false
	return true

static func interactions(s, story_id: String, step: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for person_id: String in s.content.people:
		var person: Dictionary = s.person(person_id)
		if describes(step.get("done", []), "talked", person_id):
			result.append({"person": person_id, "label": "交谈", "conditions": []})
		for option: Dictionary in person.get("interactions", []):
			var conditions: Array = option.get("conditions", [])
			if describes(conditions, "story_at", [story_id, str(step.id)]):
				result.append({"person": person_id, "label": str(option.label), "conditions": conditions})
	return result

static func related_events(s, story_id: String, step: Dictionary) -> Array[String]:
	if step.has("choice_event"):
		return [str(step.choice_event)]
	var result: Array[String] = []
	for id: String in s.content.events:
		var event: Dictionary = s.content.events[id]
		if not str(event.trigger) in ["location", "date"]:
			continue
		var related := describes(event.get("conditions", []), "story_at", [story_id, str(step.id)]) or describes(step.get("done", []), "event_state", [id, "completed"]) or describes(step.get("done", []), "event_state", [id, "expired"])
		var effects: Array = event.get("effects", []).duplicate()
		for choice: Dictionary in event.get("choices", []):
			effects.append_array(choice.get("effects", []))
		for effect: Dictionary in effects:
			if effect.has("flag") and describes(step.get("done", []), "flag", effect.flag):
				related = true
		if related and (describes(event.get("conditions", []), "story_at", [story_id, str(step.id)]) or _known_branch(s, event.get("conditions", []))):
			result.append(id)
	return result

static func can_resume(s, story_id: String) -> bool:
	return s.Storylines.resume_block(s, story_id).is_empty()

static func describe(s, story_id: String, step: Dictionary) -> Dictionary:
	var progress: Dictionary = s.Storylines.progress(s, story_id)
	var lines: Array[String] = []
	var waiting := false
	var place := str(step.get("place", ""))
	var goal := str(step.get("goal", ""))
	if not goal.is_empty():
		lines.append(goal)
	if not place.is_empty():
		lines.append("任务地点 · %s%s" % [place_name(s, place), "（你已在此地）" if place == str(s.player.location) else "（从舆图前往）"])
	if not bool(progress.get("begun", false)):
		var missing := ConditionText.missing(s, step.get("requires", []))
		if not missing.is_empty():
			lines.append("开始条件 · " + missing)
			waiting = true
	elif step.has("wait_days"):
		var due := int(progress.since) + int(step.wait_days)
		lines.append("等待后续 · %s，尚需 %s；可在原地休息或闭关等候，无需离开再返回。" % [Calendar.short_text(due), Calendar.duration_text(maxi(0, due - int(s.world.day)))])
		waiting = true
	else:
		for target: Dictionary in interactions(s, story_id, step):
			var id := str(target.person)
			var where: String = s.npc_location(id)
			var name := str(s.person(id).name)
			if where.is_empty():
				lines.append("任务人物 · %s当前不在场，留意其传音或行踪。" % name)
			else:
				lines.append("操作 · %s → 左侧「此地人物」→ %s →「%s」" % [place_name(s, where, id), name, target.label])
			var missing := ConditionText.missing(s, target.conditions)
			if not missing.is_empty():
				lines.append("「%s」尚缺 · %s" % [target.label, missing])
		for event_id: String in related_events(s, story_id, step):
			var event: Dictionary = s.content.events[event_id]
			var window: Dictionary = s.Events.window_at(event, int(s.world.day))
			if window.is_empty():
				window = s.Events.next_window(event, int(s.world.day))
			var venue: String = s.Events.venue(event, window)
			if venue.is_empty():
				venue = place
			lines.append("触发 · %s%s" % [place_name(s, venue) + "：" if not venue.is_empty() else "", str(event.title)])
			if event.has("window") or event.has("periodic"):
				if window.is_empty():
					lines.append("时间 · 本次事件期限已过。")
					waiting = true
				else:
					lines.append("时间 · %s 至 %s%s" % [Calendar.short_text(int(window.from)), Calendar.short_text(int(window.to)), "（尚未开始）" if int(window.from) > int(s.world.day) else "（正在进行）"])
					if int(window.from) > int(s.world.day):
						waiting = true
			var missing := ConditionText.missing(s, event.get("conditions", []))
			if not missing.is_empty():
				lines.append("触发尚缺 · " + missing)
			for option: Dictionary in event.get("choices", []):
				if not _known_branch(s, option.get("conditions", [])):
					continue
				var shortage := ConditionText.missing(s, option.get("conditions", []))
				if not shortage.is_empty():
					lines.append("选项「%s」尚缺 · %s" % [option.label, shortage])
			if str(s.pending_event.get("id", "")) == event_id:
				lines.append("当前 · 事件已经出现，请先处理眼前的选项。")
			elif step.has("choice_event") and int(progress.get("asked", -1)) == int(s.world.day):
				lines.append("当前 · 已暂缓此事；在任务页点「继续此事」即可重开，无需换地图或等一天。")
			else:
				lines.append("方式 · 满足时间与条件后在此地自动触发；连续剧情不必离开再返回。")
		for deed: String in step.get("deeds", {}):
			var amount := maxi(0, s.deed_count(deed) - int(progress.get("base", {}).get(deed, 0)))
			var name: String = str(s.content.enemies.get(deed.trim_prefix("win:"), {}).get("name", "对手")) if deed.begins_with("win:") else str({"duel": "斗法", "gather": "采集"}.get(deed, "历练"))
			lines.append("进度 · %s %d / %d" % ["战胜" + name if deed.begins_with("win:") else name, amount, int(step.deeds[deed])])
		var needs: Dictionary = s.Storylines.required_items(s, story_id)
		for item_id: String in needs:
			var need := int(needs[item_id])
			lines.append("交付 · %s %d / %d%s" % [s.content.item(item_id).name, s.pill_count(item_id), need, "；" + Sources.line(s, item_id) if s.pill_count(item_id) < need else "（已备齐）"])
		var herbs: int = s.Storylines.required_herbs(s, story_id)
		if herbs > 0:
			lines.append("交付 · 任意灵草 %d / %d" % [s.herb_count(), herbs])
	if not place.is_empty() and s.content.location_sealed(place, s.world.flags):
		lines.append("当前 · 目的地暂时封锁，请先处理解封条件。")
		waiting = true
	return {"text": "\n".join(lines), "state": "waiting" if waiting else "ready", "place": place}
