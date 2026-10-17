extends SceneTree
## Regression checks for the 2026-10-17 playtest decisions; always launched headless.
const Session = preload("res://scripts/core/session.gd")
const Calendar = preload("res://scripts/core/calendar.gd")
const Goals = preload("res://scripts/ui/goals.gd")
const Conditions = preload("res://scripts/ui/condition_text.gd")
var checks := 0
var failures := 0

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: " + message)

func game(low: bool = true) -> Session:
	var s := Session.new()
	s.new_game("回归", 721, ["metal", "wood", "water", "fire", "earth"] if low else ["metal"])
	s.encounters_enabled = false
	s.player.mind = 12
	return s

func _initialize() -> void:
	create_timer(120).timeout.connect(func() -> void: printerr("POLISH timed out"); quit(1))
	call_deferred("run")

func run() -> void:
	fortunes()
	payments()
	recovery()
	release_terms()
	requirements()
	economy_and_deliveries()
	story_save_identity()
	clue_continuation()
	aftermath()
	gifts_and_independent_deadlines()
	history_and_comparisons()
	await layouts()
	print("POLISH: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

func fortunes() -> void:
	for id: String in ["humble_spring", "humble_echo", "humble_temper"]:
		var s := game()
		s.player.location = "ridge"
		s.fortune[id] = 0.0
		s.Fortune._humble(s, id)
		check(str(s.pending_event.get("id", "")) == id, id + " can occur for a poor start")
		var before := s.cultivation_speed()
		s.choose_event("accept")
		check(s.has_talent(str(s.content.rules.fortune[id].talent)), id + " grants its advertised gained-only talent")
		check(s.cultivation_speed() > before if id != "humble_temper" else s.attack_bonus() >= 4, id + " has a real gameplay effect")
		var copy := Session.new()
		check(copy.restore(JSON.parse_string(JSON.stringify(s.snapshot()))), id + " survives saving")
		check(copy.has_talent(str(s.content.rules.fortune[id].talent)) and copy.player.boons[id] == "spent", id + " reward and one-time marker persist")
		s.Fortune._humble(s, id)
		check(s.pending_event.is_empty(), id + " cannot repeat")
		var failed := game()
		failed.player.location = "ridge"
		failed.fortune[id] = 1.0
		failed.Fortune._humble(failed, id)
		failed.fortune[id] = 0.0
		failed.Fortune._humble(failed, id)
		check(failed.pending_event.is_empty() and failed.player.boons[id] == "spent", id + " failure cannot be farmed")
		var strong := game(false)
		strong.fortune[id] = 0.0
		strong.Fortune._humble(strong, id)
		check(strong.pending_event.get("id", "") != id and not strong.player.boons.has(id), id + " targets low aptitude")
	var s := game()
	var copy := Session.new()
	var old: Dictionary = s.snapshot()
	old.player.erase("boons")
	check(copy.restore(old) and copy.player.boons.is_empty(), "older saves default missing opportunity state")
	var malformed: Dictionary = s.snapshot()
	malformed.player.boons = {"humble_spring": "guaranteed"}
	check(not copy.restore(malformed), "malformed opportunity states are rejected")
	# Count real seed-fixed rolls: ordinary low aptitude remains overwhelmingly unassisted.
	var hits := 0
	for seed_value: int in 10000:
		var rng := RandomNumberGenerator.new()
		rng.seed = hash([seed_value, "humble_opportunity", "humble_spring"])
		if rng.randf() < float(s.content.rules.fortune.humble_spring.chance):
			hits += 1
	check(hits >= 50 and hits <= 160, "1%% spring opportunity stays rare across 10000 worlds (%d)" % hits)
	# Existing pending events, wrong places, insufficient mind and higher realms are untouched.
	s.pending_event = {"id": "epiphany", "day": 0}
	s.fortune.humble_echo = 0.0
	s.Fortune.after_wait(s, 10)
	check(s.pending_event.id == "epiphany" and not s.player.boons.has("humble_echo"), "an opportunity never overwrites a pending choice")
	s.pending_event = {}
	s.player.location = "town"
	s.Fortune.after_wait(s, 10)
	check(s.pending_event.is_empty(), "the old breathing echo only occurs at appropriate places")

func payments() -> void:
	var s := game()
	var initial := int(s.player.stones)
	s.advance_days(365)
	check(int(s.player.stones) == initial + 36 and int(s.player.stipend_day) == 360, "a year of outer stipend is modest and automatic")
	var copy := Session.new()
	check(copy.restore(JSON.parse_string(JSON.stringify(s.snapshot()))), "payment date survives saving")
	copy.advance_days(25)
	check(int(copy.player.stones) == initial + 39 and int(copy.player.stipend_day) == 390, "partial months survive reload without double pay")
	var split := game()
	for i: int in 365:
		split.advance_days(1)
	check(int(split.player.stones) == int(s.player.stones), "splitting time does not change stipend")
	var legacy := game()
	legacy.world.day = 720
	legacy.player.stipend_day = 0
	legacy.advance_days(60)
	check(int(legacy.player.stones) == initial + 42, "old capped arrears and all new months are paid once")
	var wanderer := game()
	wanderer.player.sect = "wanderer"
	wanderer.advance_days(360)
	check(int(wanderer.player.stones) == initial + 36, "a disciple without the sect lineage still receives their rank stipend")

func recovery() -> void:
	var s := game()
	s.advance_days(Calendar.to_day(9, 3, 1))
	s.Storylines.update(s)
	check(s.has_flag("serpent_slain") and not s.has_flag("serpent_rampage"), "the original fixed-date world events remain intact")
	check(s.story_state("valley_recovery") == "active" and s.story_at("valley_recovery", "medicine"), "a player who missed the serpent can help after reopening, even in qi cultivation")
	s.player.location = "market"
	s.set_item_count("huichun_grass", 3)
	s.set_item_count("ninglu_grass", 3)
	s.Storylines.update(s)
	check(s.story_at("valley_recovery", "road") and s.item_count("ninglu_grass") == 0, "the recovery medicines are actually consumed")
	var copy := Session.new()
	check(copy.restore(JSON.parse_string(JSON.stringify(s.snapshot()))) and copy.story_at("valley_recovery", "road"), "the new storyline resumes from a saved step")
	s.player.location = "wild"
	s.record_deed("win:wolf_pack")
	s.record_deed("win:wolf_pack")
	s.Storylines.update(s)
	check(s.story_at("valley_recovery", "report"), "new wolf victories advance the recovery")
	s.player.location = "sect"
	var stones := int(s.player.stones)
	s.Storylines.update(s)
	check(s.story_state("valley_recovery") == "done" and int(s.player.stones) == stones + 100, "recovery ends with its distinct reward")
	s.Storylines.update(s)
	check(int(s.player.stones) == stones + 100, "recovery rewards cannot be claimed twice")
	var hero := game()
	hero.record_deed("win:serpent")
	hero.world.flags.serpent_slain = true
	hero.advance_days(Calendar.to_day(9, 3, 1))
	hero.Storylines.update(hero)
	check(hero.story_state("valley_recovery").is_empty(), "an early serpent slayer does not receive the missed-event route")

func release_terms() -> void:
	var s := game()
	s.auto_release = true
	var mind := int(s.player.mind)
	s.Feuds.offer_terms(s, "rogue")
	check(s.pending_event.is_empty() and int(s.player.mind) == mind + 4, "opt-in release applies release and encounter rewards exactly once")
	s.auto_release = false
	s.Feuds.offer_terms(s, "rogue")
	check(s.pending_event.get("id", "") == "victory_terms", "disabling the preference restores the verdict")
	s.pending_event = {"id": "grudge_ambush", "day": 0}
	s.auto_release = true
	s.Feuds.offer_terms(s, "rogue")
	check(s.pending_event.id == "grudge_ambush", "the preference cannot consume a different important choice")

func requirements() -> void:
	var s := game()
	var text := Conditions.missing(s, [{"realm_at_least": 1}, {"item_at_least": ["ninglu_grass", 3]}, {"relation_at_least": ["xu_qinghe", 40]}])
	check(text.contains("筑基") and text.contains("凝露草") and text.contains("许清和") and not text.contains("条件不足"), "current event conditions name the actual realm, item and relationship")
	check(Conditions.future(s, [{"story_at": ["errands", "herbs"]}]), "undiscovered future steps are hidden")

func layouts() -> void:
	var main = load("res://scenes/main.tscn").instantiate()
	var store_path := "res://.godot/polish_test_%d" % Time.get_ticks_usec()
	main.settings_path = store_path + "/settings.cfg"
	main.guide_path = store_path + "/guide.cfg"
	main.manual_store = main.SaveStore.new(store_path + "/manual")
	main.auto_store = main.SaveStore.new(store_path + "/auto")
	root.add_child(main)
	main.close_welcome()
	main.started = true
	main.guide_enabled = false
	main.session.new_game("布局", 721, ["metal", "wood", "fire"])
	# Explicitly active promises must all be available, including the fourth and beyond.
	main.session.world.flags.azhi_promised = true
	main.session.world.flags.found_ruin = true
	main.session.set_item_count("auction_invitation", 1)
	main.view = "place"
	main.render()
	check(Goals.current(main.session).size() >= 4 and main.goal_label.text.split("\n").size() == Goals.current(main.session).size(), "the HUD retains every current goal")
	for dimensions: Vector2i in [Vector2i(1920, 1080), Vector2i(2560, 1440)]:
		root.size = dimensions
		main.set_view("map")
		await process_frame
		await process_frame
		check(not main.window.get_global_rect().intersects(main.hud_right.get_global_rect()), "route information stays below the expanded goal list at %s" % dimensions)
		main.story = {"title":"简短剧情", "text":"许清和递来一枚玉简。", "event":"", "speaker":"xu_qinghe", "mark":0}
		main.render()
		await process_frame
		check(main.window.size.y < main.size.y * 0.7 and main.get_global_rect().encloses(main.window.get_global_rect()), "short dialogue has a compact visible scroll at %s" % dimensions)
		check(main.EventView.speaker(main) == "xu_qinghe", "the story retains the actual speaker")
		main.story = {}
	main.people_filter = "story"
	main.session.world.storylines["errands"] = {"state":"active", "step":1, "begun":true, "since":int(main.session.world.day), "base":{}}
	var people: Array[String] = ["xu_qinghe", "gu_changgeng"]
	check(main.PeopleView.filtered_here(main, people).has("xu_qinghe"), "a missing delivery item does not hide its person from the story filter")
	main.people_filter = "familiar"
	check(not main.PeopleView.filtered_here(main, people).has("xu_qinghe"), "familiar filter requires an actual established relationship")
	main.tracked_goal = "serpent"
	var displayed := Goals.displayed(main)
	check(displayed[0].id == "serpent" and displayed.size() == Goals.current(main.session).size(), "tracking promotes one goal without removing the others")
	main.session.world.storylines["intro"] = {"state":"active", "step":0, "begun":true, "since":int(main.session.world.day), "base":{}}
	check(bool(Goals.displayed(main)[0].get("guide", false)), "manual tracking cannot override active introduction guidance")
	main.queue_free()
	await process_frame

func economy_and_deliveries() -> void:
	var s := game()
	for day: int in 60:
		if s.npc_location("peddler", day) == "market":
			s.advance_days(day)
			break
	s.player.location = "market"
	s.player.stones = 1000
	var count := s.item_count("foundation_pill")
	s.interact("peddler", "buy_pill")
	check(s.item_count("foundation_pill") == count + 1, "ordinary merchant stock can be bought")
	s.interact("peddler", "buy_pill")
	check(s.item_count("foundation_pill") == count + 1, "merchant cannot sell two ordinary pills in one month")
	s.world.flags["peddler_friend"] = true
	s.interact("peddler", "buy_pill_friend")
	check(s.item_count("foundation_pill") == count + 1, "becoming a friend does not reset shared stock")
	var copy := Session.new()
	check(copy.restore(JSON.parse_string(JSON.stringify(s.snapshot()))), "merchant purchase date restores")
	copy.interact("peddler", "buy_pill_friend")
	check(copy.item_count("foundation_pill") == count + 1, "reload does not replenish monthly stock")
	var funds := int(s.player.stones)
	s.sell("foundation_pill", 1)
	check(int(s.player.stones) == funds + 40, "ordinary foundation pill resale base is forty")
	s.advance_days(30)
	s.player.location = s.npc_location("peddler")
	count = s.item_count("foundation_pill")
	s.interact("peddler", "buy_pill_friend")
	check(s.item_count("foundation_pill") == count + 1, "shared stock restocks in a new calendar month")
	var q := game()
	q.advance_days(Calendar.to_day(9, 3, 1))
	q.Storylines.update(q)
	q.player.location = "sect"
	q.set_item_count("huichun_grass", 5)
	q.set_item_count("ninglu_grass", 6)
	check(int(q.Inventory.reserved(q).get("ninglu_grass", 0)) == 3, "active recovery medicines are reserved before arrival")
	q.world.storylines["errands"] = {"state":"active", "step":1, "begun":true, "since":int(q.world.day), "base":{}}
	check(int(q.Inventory.reserved(q).get("ninglu_grass", 0)) == 6, "two different deliveries add their material costs")
	q.world.storylines.erase("errands")
	q.player.location = "market"
	q.act("sell")
	check(q.item_count("huichun_grass") == 0 and q.item_count("ninglu_grass") == 0 and q.story_at("valley_recovery", "road"), "bulk selling leaves medicines for immediate arrival hand-in")
	check(not q.Inventory.reserved(q).has("ninglu_grass"), "delivered medicines stop being reserved")

func story_save_identity() -> void:
	var s := game()
	s.world.storylines["errands"] = {"state":"active", "step":1, "begun":true, "since":0, "base":{}}
	var snapshot: Dictionary = s.snapshot()
	check(snapshot.world.storylines.errands.step_id == "dew", "new saves write stable step IDs")
	for legacy: bool in [false, true]:
		var saved: Dictionary = snapshot.duplicate(true)
		if legacy:
			saved.world.storylines.errands.erase("step_id")
		var target := Session.new()
		target.content.storylines.errands.steps.insert(1, {"id":"inserted", "auto":true})
		check(target.restore(saved) and target.story_at("errands", "dew"), "old and new saves locate the original step after insertion (%s)" % legacy)
		check(target.snapshot().world.storylines.errands.step_id == "dew", "resaving keeps the semantic step (%s)" % legacy)
	var broken: Dictionary = snapshot.duplicate(true)
	broken.world.storylines.errands.step_id = 7
	check(not Session.new().restore(broken), "non-string step identity is rejected")
	broken = snapshot.duplicate(true)
	broken.world.storylines.errands.step_id = "missing"
	check(not Session.new().restore(broken), "unmapped step identity cannot silently fall back to another step")
	var old_last := game()
	old_last.world.storylines["errands"] = {"state":"active", "step":6, "begun":true, "since":0, "base":{}}
	var compacted := Session.new()
	compacted.content.storylines.errands.steps.remove_at(0)
	check(compacted.restore(old_last.snapshot()) and compacted.story_at("errands", "advice"), "removing an earlier step keeps a later saved step reachable")
	var done: Dictionary = snapshot.duplicate(true)
	done.world.storylines.errands.state = "done"
	done.world.storylines.errands.step_id = ""
	var completed := Session.new()
	check(completed.restore(done) and completed.story_state("errands") == "done", "completed stories remain completed without repeated rewards")

func clue_continuation() -> void:
	var s := game()
	s.player.location = "ridge"
	s.fortune["humble_spring"] = 0.0
	s.Fortune._humble(s, "humble_spring")
	var insight := int(s.player.insight)
	s.choose_event("later")
	check(s.player.boons.humble_spring == "ready" and not s.has_talent("xisui_yulu"), "postponing leaves a real discovered clue")
	check(int(s.player.insight) == insight, "postponing cannot farm event insight")
	check(Goals.current(s).any(func(g: Dictionary) -> bool: return str(g.id) == "fortune:humble_spring"), "a postponed clue stays visible in current goals")
	var target := Session.new()
	check(target.restore(JSON.parse_string(JSON.stringify(s.snapshot()))), "a postponed clue survives saving")
	target.player.location = "market"
	target.Fortune.pursue(target, "humble_spring")
	check(target.pending_event.is_empty(), "a saved clue states its destination instead of resolving anywhere")
	target.player.location = "ridge"
	target.Fortune.pursue(target, "humble_spring")
	check(target.pending_event.get("id", "") == "humble_spring", "returning follows the existing clue without another roll")
	var day := int(target.world.day)
	target.choose_event("accept")
	check(target.has_talent("xisui_yulu") and int(target.world.day) == day + 10 and target.player.boons.humble_spring == "spent", "following a clue spends ten days and grants its reward once")
	var speed := target.cultivation_speed()
	target.Fortune.pursue(target, "humble_spring")
	check(target.pending_event.is_empty() and is_equal_approx(speed, target.cultivation_speed()), "spent clues cannot be claimed twice")

func aftermath() -> void:
	for donate: bool in [false, true]:
		var s := game()
		s.record_deed("win:serpent")
		s.world.flags.serpent_slain = true
		s.Storylines.update(s)
		check(s.story_at("valley_aftermath", "thanks"), "an early serpent victory opens its own aftermath")
		s.player.location = "market"
		var stones := int(s.player.stones)
		var mind := int(s.player.mind)
		var merit := int(s.player.merit)
		var contribution := int(s.player.contribution)
		var favor := s.favor("shen_mo")
		s.interact("shen_mo", "valley_donate" if donate else "valley_reward")
		check(s.story_at("valley_aftermath", "azhi") and int(s.player.stones) == stones + (0 if donate else 60), "aftermath choice has the stated economic result (%s)" % donate)
		check(int(s.player.mind)==mind+(4 if donate else 2) and s.favor("shen_mo")==favor+(10 if donate else 0), "audited shared and branch rewards have their intended total")
		check(int(s.player.merit)==merit+20 and int(s.player.contribution)==contribution+20, "shared merit and contribution pay exactly once")
		s.interact("shen_mo", "valley_reward")
		check(int(s.player.mind)==mind+(4 if donate else 2) and int(s.player.merit)==merit+20 and int(s.player.contribution)==contribution+20, "rejected repeat cannot pay shared or branch rewards again")
		check(int(s.player.stones) == stones + (0 if donate else 60), "mutually exclusive rewards cannot be collected again")
		s.player.location = "ridge"
		s.interact("azhi", "valley_future")
		check(s.has_flag("azhi_livelihood"), "the early victory changes Azhi's livelihood")
		var line := s.interact("azhi", "talk")
		check(line.contains("险路") or line.contains("养活"), "repeat dialogue acknowledges the new livelihood")
		var copy := Session.new()
		check(copy.restore(JSON.parse_string(JSON.stringify(s.snapshot()))) and copy.journal_lines().back() == s.journal_lines().back(), "situational dialogue remains what was actually said after reload")
		s.player.location = "sect"
		s.interact("gu_changgeng", "valley_report")
		check(s.story_state("valley_aftermath") == "done" and s.has_flag("valley_remembered"), "the aftermath ends in a distinct remembered result")

func gifts_and_independent_deadlines() -> void:
	var s := game()
	s.world.storylines["errands"] = {"state":"active", "step":1, "begun":true, "since":0, "base":{}}
	s.set_item_count("ninglu_grass", 3)
	var favor := s.favor("xu_qinghe")
	s.interact("xu_qinghe", "gift")
	check(s.item_count("ninglu_grass") == 3 and s.favor("xu_qinghe") == favor, "ordinary gifting protects all reserved herbs")
	s.set_item_count("huichun_grass", 1)
	s.interact("xu_qinghe", "gift")
	check(s.item_count("huichun_grass") == 0 and s.item_count("ninglu_grass") == 3, "a gift takes the named surplus herb")
	var intro := game()
	intro.world.storylines["intro"] = {"state":"active", "step":3, "begun":true, "since":0, "base":{}}
	intro.set_item_count("huichun_grass", 4)
	check(int(intro.Inventory.reserved(intro).get("huichun_grass", 0)) == 3, "generic three-herb tutorial delivery is protected")
	var timed := game()
	timed.world.people.clear()
	timed.People.obituaries_changed(timed)
	timed.world.storylines["errands"] = {"state":"active", "step":0, "begun":true, "since":0, "base":{}}
	check(timed.next_obituary(0).is_empty(), "deadline regression has no known mortal acquaintance")
	timed.advance_days(100)
	check(timed.story_at("errands", "dew"), "a ninety-day letter arrives even without an obituary")
	var letters: Array = timed.world.letters.filter(func(letter: Dictionary) -> bool: return letter.get("story", "") == "errands")
	check(not letters.is_empty() and int(letters[0].day) == 90, "the independent letter keeps its exact day")

func history_and_comparisons() -> void:
	var old_hero := game()
	old_hero.world.flags.serpent_slain = true
	old_hero.advance_days(Calendar.to_day(9, 3, 1))
	old_hero.Storylines.update(old_hero)
	check(not old_hero.Events.applied(old_hero, "serpent_rampage_ends") and old_hero.story_state("valley_recovery").is_empty(), "a skipped dated event does not misclassify an older hero with no deed counters")
	var old := game()
	old.advance_days(Calendar.to_day(9, 3, 1))
	var saved: Dictionary = old.snapshot()
	saved.world.events.serpent_rampage_ends.erase("applied")
	saved.world.storylines.erase("valley_recovery")
	var restored := Session.new()
	check(restored.restore(saved) and restored.Events.applied(restored, "serpent_rampage_ends"), "a legacy major world record recovers actual history")
	restored.Storylines.update(restored)
	check(restored.story_state("valley_recovery") == "active", "legacy players who actually experienced reopening retain the recovery route")
	saved.world.events.serpent_rampage_ends.applied = "yes"
	check(not Session.new().restore(saved), "invalid optional event outcomes are rejected")
	var wearer := game()
	var code: String = wearer.Arsenal.generate_equipment(wearer.content, wearer.world_rng, 1, "weapon")
	wearer.add_item(code, 1)
	var state: Dictionary = wearer.snapshot()
	var delta: Dictionary = wearer.Loadout.equipment_comparison(wearer, code)
	check(wearer.snapshot() == state, "previewing equipment never changes player or RNG state")
	var before: Dictionary = wearer.bonuses()
	wearer.equip_item(code)
	var after: Dictionary = wearer.bonuses()
	check(is_equal_approx(float(delta.get("attack",0)), float(after.attack)-float(before.attack)), "equipment preview matches the actual equip result")
	var sources = load("res://scripts/core/sources.gd")
	var herbal := game()
	check(sources.of(herbal,"ninglu_grass").any(func(source: Dictionary) -> bool: return source.kind=="gather" and str(source.text).contains("松风岭")), "delivery materials show their known gathering destination")
	check(not sources.of(herbal,"foundation_pill").any(func(source: Dictionary) -> bool: return source.kind=="person" and str(source.text).contains("钱货郎")), "unknown merchant discounts are not spoiled")
	herbal.mark_met("peddler")
	herbal.player.stones = 0
	check(sources.of(herbal,"foundation_pill").any(func(source: Dictionary) -> bool: return source.kind=="person" and str(source.text).contains("70") and not bool(source.ready)), "known unaffordable offers still explain where to buy")
	var robe_wearer := game()
	robe_wearer.gain_talent("fanqu_bailian")
	var robe: String = robe_wearer.Arsenal.generate_equipment(robe_wearer.content, robe_wearer.world_rng, 1, "robe")
	robe_wearer.add_item(robe,1)
	var hp_before := int(robe_wearer.player.max_hp)
	var preview: Dictionary = robe_wearer.Loadout.equipment_comparison(robe_wearer,robe)
	robe_wearer.equip_item(robe)
	check(int(preview.get("max_hp",0)) == int(robe_wearer.player.max_hp)-hp_before, "equipment comparison includes talent and foundation health multipliers")
