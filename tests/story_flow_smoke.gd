extends SceneTree
const Session = preload("res://scripts/core/session.gd")
const Goals = preload("res://scripts/ui/goals.gd")
const Hints = preload("res://scripts/ui/story_hints.gd")
var checks := 0
var failures := 0

func check(ok: bool, text: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: " + text)

func game() -> Session:
	var s := Session.new()
	s.encounters_enabled = false
	s.new_game("续接", 7, ["metal", "wood", "fire"], "free")
	return s

func isolated() -> Session:
	var s := game()
	s.content.storylines = {}
	s.content.events = {}
	s.content._by_location.clear()
	s.content._by_priority_source = -1
	s.world.storylines = {}
	s.world.events = {}
	s.pending_event = {}
	return s

func choice_event(flag: String, reward: int = 0) -> Dictionary:
	return {"title": "原地续谈", "trigger": "manual", "text": "继续谈。", "choices": [
		{"id": "go", "label": "继续", "effects": [{"flag": flag}, {"stones": reward}], "chronicle": "谈完这一段。"},
		{"id": "later", "label": "稍后再谈", "effects": [], "chronicle": "稍后再谈。"}]}

func _initialize() -> void:
	create_timer(90.0).timeout.connect(func() -> void: printerr("STORY FLOW timed out"); quit(1))
	_real_opening()
	_same_day_choices()
	_location_chain()
	_hints()
	_hint_coverage()
	print("STORY FLOW: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

func _real_opening() -> void:
	var s := Session.new()
	s.encounters_enabled = false
	s.new_game("入世", 7, ["metal", "wood", "fire"], "rushi")
	s.choose_event("watch")
	s.player.location = "market"
	s.world.day = 8
	s.conclude("")
	check(s.pending_event.get("id", "") == "rushi_gate", "arrival starts the real gate event")
	var day := int(s.world.day)
	s.choose_event("pass")
	check(s.pending_event.get("id", "") == "rushi_fair", "gate immediately continues to fair in the same city")
	s.choose_event("ask")
	check(s.pending_event.get("id", "") == "rushi_auction", "fair immediately continues to the available auction")
	check(int(s.world.day) == day and s.player.location == "market", "no travel or extra day required")
	var copy := Session.new()
	check(copy.restore(JSON.parse_string(JSON.stringify(s.snapshot()))) and copy.pending_event == s.pending_event, "pending continuation survives save/load")
	s.choose_event("watch")
	check(s.story_step("rushi").id == "qianlong" and s.pending_event.is_empty(), "future tournament waits for its date")
	var detail: Dictionary = Hints.describe(s, "rushi", s.story_step("rushi"))
	check(str(detail.text).contains("云溪坊市") and str(detail.text).contains("潜龙会") and str(detail.text).contains("尚未开始"), "goal identifies event, city and future window")
	s.wait(s.Calendar.to_day(1, 3, 1) - int(s.world.day))
	check(s.pending_event.get("id", "") == "qianlong_entry", "waiting in the same city triggers the tournament")

func _same_day_choices() -> void:
	var s := isolated()
	s.content.events = {"test_first": choice_event("test_first_done"), "test_second": choice_event("test_second_done", 7)}
	s.content.storylines.test_chain = {"title": "连谈", "giver": "xu_qinghe", "steps": [
		{"id": "first", "place": "town", "goal": "第一段", "choice_event": "test_first", "done": [{"flag": "test_first_done"}]},
		{"id": "second", "place": "town", "goal": "第二段", "choice_event": "test_second", "done": [{"flag": "test_second_done"}]}]}
	s.start_story("test_chain")
	check(s.pending_event.get("id", "") == "test_first", "first manual question opens")
	s.choose_event("go")
	check(s.pending_event.get("id", "") == "test_second" and int(s.world.day) == 0, "asked timestamp is scoped to the step, not the entire day")
	s.choose_event("later")
	check(s.pending_event.is_empty(), "explicit deferral does not immediately reopen")
	s.conclude("")
	check(s.pending_event.is_empty(), "ordinary same-day action respects deferral")
	check(str(Hints.describe(s, "test_chain", s.story_step("test_chain")).text).contains("继续此事"), "deferred task explains how to resume")
	s.player.location = "market"
	check(not s.Storylines.resume_block(s, "test_chain").is_empty(), "resume requires the task location")
	s.player.location = "town"
	var stones := int(s.player.stones)
	s.Storylines.resume_choice(s, "test_chain")
	check(s.pending_event.get("id", "") == "test_second" and int(s.player.stones) == stones and int(s.world.day) == 0, "explicit resume costs no day and gives no reward")
	s.choose_event("go")
	check(s.story_state("test_chain") == "done" and int(s.player.stones) == stones + 7, "completion reward once")
	s.conclude("")
	s.Storylines.resume_choice(s, "test_chain")
	check(s.pending_event.is_empty() and int(s.player.stones) == stones + 7, "completed task cannot reopen or duplicate rewards")
	# Save between a step's completion and beginning the next: stale asked must not survive.
	check(not s.world.storylines.test_chain.has("asked"), "completed step clears its asked marker")
	for lock: String in ["auction", "battle", "founding", "forming", "nascent", "deifying"]:
		s.world.storylines.test_chain = {"state": "active", "step": 0, "since": 0, "begun": true, "base": {}}
		s.world.flags.erase("test_first_done")
		s.world.flags.erase("test_second_done")
		s.set(lock, {"locked": true})
		s.settle_story_events()
		check(s.pending_event.is_empty(), "question cannot interrupt " + lock)
		s.set(lock, {})
	s.pending_event = {"id": "test_second", "day": 0}
	s.settle_story_events()
	check(s.pending_event.id == "test_second", "an existing choice is never overwritten")

func _location_chain() -> void:
	var s := isolated()
	s.content.events = {
		"test_a": {"title": "后续", "trigger": "location", "location": "town", "priority": 10, "conditions": [{"flag": "test_unlock"}], "effects": [{"stones": 3}], "chronicle": "领取一次。"},
		"test_z": {"title": "解锁", "trigger": "location", "location": "town", "effects": [{"flag": "test_unlock"}], "chronicle": "解锁后续。"}}
	var stones := int(s.player.stones)
	s.conclude("")
	check(int(s.player.stones) == stones + 3 and int(s.world.events.test_a.count) == 1, "reverse-priority local chain settles in one action")
	s.conclude("")
	check(int(s.player.stones) == stones + 3, "completed local events are not replayed")

func _hints() -> void:
	var s := game()
	s.player.location = "ridge"
	s.world.storylines.errands = {"state": "active", "step": 1, "since": 0, "begun": true, "base": {}}
	var text := str(Hints.describe(s, "errands", s.story_step("errands")).text)
	check(text.contains("青云山") and text.contains("执事堂") and text.contains("许清和") and text.contains("此地人物"), "delivery shows actual city, building and person")
	check(text.contains("凝露草") and text.contains("持有 0") and text.contains("交付"), "delivery shows shortages and sources")
	s.world.storylines.errands.step = 0
	s.world.storylines.errands.since = 10
	s.world.day = 20
	text = str(Hints.describe(s, "errands", s.story_step("errands")).text)
	check(text.contains(s.Calendar.short_text(100)) and text.contains(s.Calendar.duration_text(80)), "waiting gives due date and exact remaining span")
	s.world.storylines.lineage = {"state": "active", "step": 2, "since": 0, "begun": false, "base": {}}
	text = str(Hints.describe(s, "lineage", s.story_step("lineage")).text)
	check(text.contains("开始条件") and text.contains("炼气圆满"), "unbegun known step shows its actual realm requirement")
	var goals := Goals.current(s)
	check(goals.any(func(g: Dictionary) -> bool: return g.id == "story:lineage" and g.state == "waiting"), "blocked known quests remain in current goals")
	var before := JSON.stringify(s.snapshot())
	for id: String in s.world.storylines:
		var step: Dictionary = s.story_step(id)
		if not step.is_empty():
			Hints.describe(s, id, step)
	check(JSON.stringify(s.snapshot()) == before, "reading hints never advances stories, changes time or gives rewards")

func _hint_coverage() -> void:
	var s := game()
	var count := 0
	for story_id: String in s.content.storylines:
		var definition: Dictionary = s.content.storylines[story_id]
		for index: int in definition.steps.size():
			var step: Dictionary = definition.steps[index]
			if not step.has("goal") and not step.has("wait_days"):
				continue
			s.world.storylines[story_id] = {"state": "active", "step": index, "since": 0, "begun": true, "base": {}}
			var hint := Hints.describe(s, story_id, Goals.described_step(s, step))
			check(not str(hint.text).is_empty(), "shipped task instructions render: %s/%s" % [story_id, step.id])
			count += 1
	print("STORY HINT COVERAGE: %d shipped steps" % count)
