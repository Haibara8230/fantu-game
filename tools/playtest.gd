extends SceneTree
## A first journey played headless the way a new player would: the guided start, then the current goals
## (data/goals.json, goals.gd) and the storylines, commissions, gathering and selling for stones, duels,
## retreats, the 筑基丹 and the breakthrough, and some years after. Everything the player would read is
## printed with the date, and each action is charged the seconds a player would spend on it, to judge
## pacing. Only rules are used; no window is opened.
## Usage: godot --headless --path . --script res://tools/playtest.gd [-- <seed> <years> [random|poor|ordinary|good] [cultivate|social|explore]]
const Session = preload("res://scripts/core/session.gd")
const Goals = preload("res://scripts/ui/goals.gd")
const Calendar = preload("res://scripts/core/calendar.gd")

# Seconds a player spends: clicking and reading the outcome.
const COST := {"travel": 8, "act": 6, "retreat": 12, "talk": 8, "event": 20, "duel_turn": 7, "quick": 3, "menu": 4, "breakthrough": 25, "study": 6, "story": 12}

var s: Session
var seconds := 0
var clicks := 0
var duels := 0
var last_goals := ""
var marks := {}
var reported_year := -1
var log_lines := 0
var strategy := "cultivate"
var decisions := 0
var milestone_days := {}
var losses := 0
var breakthrough_failures := 0
# Everyday options of anyone (people.gd, bonds.gd): not what a storyline asks.
const EVERYDAY := ["talk", "gift", "help", "companion", "consult", "disciple", "instruct", "invite_help", "invite_spar", "sworn", "teach"]
var stuck := 0
var last_result := ""

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var seed_value := int(args[0]) if args.size() > 0 else 20261017
	var years := int(args[1]) if args.size() > 1 else 12
	s = Session.new()
	s.encounters_enabled = true
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var roots: Array = s.roll_roots(rng)
	var born: Dictionary = s.roll_talents(rng, roots)
	var opening := str(args[2]) if args.size() > 2 else "random"
	strategy = str(args[3]) if args.size() > 3 else "cultivate"
	if not strategy in ["cultivate", "social", "explore"]:
		printerr("Strategy must be cultivate, social or explore")
		quit(1)
		return
	if not opening in ["random", "poor", "ordinary", "good"]:
		printerr("Opening must be random, poor, ordinary or good")
		quit(1)
		return
	if opening != "random":
		roots = ["metal", "wood", "water", "fire", "earth"] if opening == "poor" else (["metal", "wood", "water"] if opening == "ordinary" else ["metal"])
		born = {"talents": [], "flaws": []}
	s.new_game("试玩", seed_value, roots, "guided", born)
	_say("START", "灵根 %s（%s）· 天赋 %s · 缺陷 %s · 资质 %s" % [s.root_title(), ", ".join(roots), ", ".join(s.player.talents), ", ".join(s.player.flaws), str(s.aptitude().get("name", s.aptitude()))])
	_chronicle_since(0)
	var guard := 0
	while s.ended.is_empty() and int(s.world.day) < years * Calendar.DAYS_PER_YEAR and guard < 4000:
		guard += 1
		decisions = guard
		_goals()
		_year_report()
		var mark: int = s.chronicle.added
		_step()
		_chronicle_since(mark)
	_say("END", "%s · %s · 灵石 %d · 现实约 %d 分钟、%d 次点击、%d 场斗法 · 结局 %s" % [s.time_name(), s.realm_name(), int(s.player.stones), seconds / 60, clicks, duels, str(s.ended.get("kind", "无"))])
	for key: String in marks:
		print("MARK %s: %s" % [key, marks[key]])
	print("PLAYTEST_RESULT ", JSON.stringify({"seed":seed_value,"opening":opening,"strategy":strategy,"day":int(s.world.day),"realm":int(s.player.realm),"stones":int(s.player.stones),"estimated_minutes":float(seconds)/60.0,"clicks":clicks,"duels":duels,"steps":guard,"guard_exhausted":guard>=4000,"milestone_days":milestone_days,"losses":losses,"breakthrough_failures":breakthrough_failures,"early_serpent":s.Storylines.deed_count(s,"win:serpent")>0,"aftermath":s.story_state("valley_aftermath"),"recovery":s.story_state("valley_recovery")}))
	quit(0)

# --- Reporting ------------------------------------------------------------------------------------

func _say(kind: String, text: String) -> void:
	log_lines += 1
	print("[%s | %s 修为%d 灵石%d 气血%d/%d | %d分] %s: %s" % [s.time_name() if s.player.size() > 0 else "", s.realm_name(), int(s.player.xp), int(s.player.stones), int(s.player.hp), int(s.player.max_hp), seconds / 60, kind, text.replace("\n", " / ")])

func _charge(kind: String, times: int = 1) -> void:
	seconds += int(COST[kind]) * times
	clicks += times

func _mark(key: String) -> void:
	if not marks.has(key):
		milestone_days[key] = int(s.world.day)
		marks[key] = "%s，%s，现实约 %d 分钟，%d 次点击" % [s.time_name(), s.realm_name(), seconds / 60, clicks]

func _goals() -> void:
	var lines: Array[String] = []
	for goal: Dictionary in Goals.current(s):
		lines.append("%s：%s" % [goal.title, goal.text])
	var text := " ‖ ".join(lines)
	if text != last_goals:
		last_goals = text
		_say("GOALS", text)

func _year_report() -> void:
	var year := int(s.world.day) / Calendar.DAYS_PER_YEAR
	if year != reported_year:
		reported_year = year
		_say("YEAR", "第 %d 年开始 · 心境 %d%% · 疲劳效率 %d%% · 瓶颈 %s · 委托 %d · 行囊 %s" % [year + 1, s.mind_percent(), s.retreat_efficiency(), str(s.at_bottleneck()), s.player.quests.size(), str(s.player.items)])

## What the chronicle told since `mark` that a player would see as story or letters.
func _chronicle_since(mark: int) -> void:
	var count := mini(int(s.chronicle.added) - mark, s.chronicle.entries.size())
	if count <= 0:
		return
	for entry: Dictionary in s.chronicle.entries.slice(-count):
		if entry.id in ["story", "letter", "event", "breakthrough", "stage_up", "layer_up", "heart_demon", "breakthrough_failed"]:
			_say("TOLD", s.chronicle.format(entry, s.content))

func _do(kind: String, label: String, result: String) -> String:
	_charge(kind)
	_say(label, result)
	stuck = stuck + 1 if result == last_result else 0
	last_result = result
	return result

# --- Playing --------------------------------------------------------------------------------------

func _step() -> void:
	if not s.pending_event.is_empty():
		_event()
		return
	if not s.battle.is_empty():
		_duel()
		return
	if not s.auction.is_empty():
		_do("act", "AUCTION", s.auction_leave())
		return
	if not s.player.journey.is_empty():
		_do("travel", "ONWARD", s.continue_journey())
		return
	if s.at_brink():
		_do("act", "BRINK", s.accept_end())
		return
	# A player rests before setting out hurt.
	if int(s.player.hp) * 5 < int(s.player.max_hp) * 3 and s.player.journey.is_empty():
		_rest()
		return
	if stuck >= 4:
		stuck = 0
		_say("STUCK", "同一结果重复，改去闭关或采集")
		if not _bottleneck():
			_outing()
		return
	if int(s.player.realm) >= 1:
		_mark("筑基")
	if s.Storylines.deed_count(s, "win:serpent") > 0:
		_mark("除蟒")
	if _story():
		return
	if _local_milestone():
		return
	if _deliver():
		return
	if _breakthrough():
		return
	if _bottleneck():
		return
	if _learn():
		return
	if decisions % 7 == 0 and _preferred_outing():
		return
	# Cultivation first, as the game means it: out of the room (commissions, hunting, gathering) only
	# when the retreat has grown stale or the xp waits at the stage's cap.
	if s.retreat_efficiency() >= 70 and s.mind_percent() >= 60 and not s.at_xp_cap():
		_retreat()
		return
	if _commissions():
		return
	_outing()

func _event() -> void:
	var definition: Dictionary = s.pending_definition()
	var choices: Array = definition.get("choices", [])
	var shown: Array[String] = []
	var pick := ""
	for choice: Dictionary in choices:
		var open := s.choice_available(choice)
		shown.append("%s%s" % [str(choice.get("text", choice.get("label", choice.id))), "" if open else "（不可选）"])
		if open and pick.is_empty():
			pick = str(choice.id)
	_say("EVENT", "%s：%s ｜ 选项：%s" % [str(definition.get("title", s.pending_event.id)), str(definition.get("text", "")), "、".join(shown)])
	_do("event", "CHOSE", s.choose_event(pick))
	if not s.pending_event.is_empty() and s.pending_event.get("id", "") == definition.get("id", "?"):
		s.pending_event = {}

func _duel() -> void:
	var foe: String = str(s.battle.get("foe", {}).get("name", s.content.enemies.get(str(s.battle.get("enemy_id", "")), {}).get("name", "?")))
	if int(s.battle.get("turn", 1)) <= 1 and not s.battle.has("_seen"):
		duels += 1
		s.battle["_seen"] = true
		_say("DUEL", "对上%s（%s）" % [foe, str(s.battle.get("context", ""))])
	# The first fights are fought by hand, later ones mostly with 速战.
	var before_turn := int(s.battle.get("turn", 0))
	var text: String = s.plain_turn()
	_charge("duel_turn" if duels <= 8 else "quick")
	if s.battle.is_empty():
		if text.contains("落败") or text.contains("败下"):
			losses += 1
		_say("DUEL_END", text)
	elif int(s.battle.get("turn", 0)) > 40 or before_turn == int(s.battle.get("turn", 0)) and text.is_empty():
		_do("act", "FLEE", s.flee())

## Hurt: a quiet room or an inn where there is one, else sitting still to 调息 where the player stands.
func _rest() -> void:
	if s.available_here("rest") or s.available_here("inn_rest"):
		_do("act", "REST", s.act("rest" if s.available_here("rest") else "inn_rest"))
	elif float(s.content.rules.get("field_rest", 0.0)) > 0.0:
		_do("act", "WAIT", s.wait(10))
	else:
		_go("sect")

func _go(place: String) -> bool:
	if str(s.player.location) == place:
		return false
	var path: Array = s.path_to(place)
	_do("travel", "TRAVEL", "→ %s：%s" % [s.content.locations[place].name, s.travel(place)])
	return true

## The guided start and the storylines: go where the step is, do what it asks.
func _story() -> bool:
	for goal: Dictionary in Goals.story_goals(s):
		var story_id := str(goal.id).trim_prefix("story:")
		var step: Dictionary = s.story_step(story_id)
		var place := str(step.get("place", s.player.location))
		var requires_person := false
		for person_id: String in s.content.people:
			for interaction: Dictionary in s.content.people[person_id].get("interactions", []):
				if interaction.get("conditions", []).any(func(c: Dictionary) -> bool: return c.has("story_at") and c.story_at == [story_id, str(step.id)]):
					requires_person = true
					var whereabouts: String = s.npc_location(person_id)
					if not whereabouts.is_empty():
						place = whereabouts
		for deed: String in step.get("deeds", {}):
			if deed.begins_with("win:"):
				var foe: Dictionary = s.content.enemies.get(deed.trim_prefix("win:"), {})
				var grounds: Array = foe.get("locations", [])
				if not grounds.is_empty() and not place in grounds:
					place = str(grounds[0])
		var needs: Dictionary = s.Storylines.required_items(s, story_id)
		for item_id: String in needs:
			if s.item_count(item_id) < int(needs[item_id]) and str(s.content.item(item_id).get("category", "")) == "herb":
				if _go("ridge" if item_id in ["huichun_grass", "ninglu_grass"] else "wild"):
					return true
				_gather()
				return true
		# Travel for a step only when it can be done on arrival (a talk, a deed); an errand that needs
		# things gathered first waits until they are carried.
		var doable: bool = requires_person or bool(goal.guide) or step.has("deeds") or step.has("retreat_days") or step.get("done", []).any(func(done: Dictionary) -> bool: return done.has("talked")) or _carrying_for(story_id, step)
		if not doable and place != str(s.player.location):
			continue
		if _go(place):
			return true
		# Something asked of a person here.
		for person_id: String in s.present_npcs():
			for option: Dictionary in s.npc_options(person_id):
				if option.get("reason", "").is_empty() and not str(option.id) in EVERYDAY and _story_option(option):
					_charge("talk")
					_say("ASK", "%s · %s → %s" % [s.person(person_id).name, option.label, s.interact(person_id, str(option.id))])
					return true
		var deeds: Dictionary = step.get("deeds", {})
		if deeds.has("retreat_days") or int(step.get("retreat_days", 0)) > 0:
			_retreat()
			return true
		if deeds.has("duel"):
			_do("act", "SPAR", s.start_battle("disciple"))
			return true
		if deeds.has("trade"):
			_sell_all()
			return true
		for deed: String in deeds:
			if deed.begins_with("win:"):
				var enemy_id := deed.trim_prefix("win:")
				if s.content.enemies.has(enemy_id) and int(s.player.realm) >= int(s.content.enemies[enemy_id].min_realm):
					if str(s.player.location) in s.content.enemies[enemy_id].get("locations", []):
						_do("act", "FIGHT", s.start_battle(enemy_id))
					elif s.available_here("hunt") and s.content.locations[s.player.location].get("hunt", {}).get("table", []).any(func(entry: Dictionary) -> bool: return str(entry.enemy) == enemy_id):
						_do("act", "HUNT", s.act("hunt"))
					else:
						continue
					return true
		for done: Dictionary in step.get("done", []):
			if done.has("herbs_at_least") and s.herb_count() < int(done.herbs_at_least):
				_gather()
				return true
			if done.has("talked"):
				var person_id := str(done.talked)
				if s.npc_location(person_id) == str(s.player.location):
					_charge("talk")
					_say("TALK", "%s → %s" % [s.person(person_id).name, s.interact(person_id, "talk")])
					return true
			if done.has("not") and str(story_id) == "lineage" and s.available_here("study"):
				_charge("study")
				_say("LINEAGE", s.choose_sect(s.Loadout.home_lineage(s)))
				return true
	return false

## Whether the things a step's hand-in asks are carried (the 凝露草 for 许清和).
func _carrying_for(story_id: String, step: Dictionary) -> bool:
	var needs: Dictionary = s.Storylines.required_items(s, story_id)
	if not needs.is_empty():
		for item_id: String in needs:
			if s.item_count(item_id) < int(needs[item_id]):
				return false
		return true
	return step.get("done", []).any(func(c: Dictionary) -> bool: return c.has("at_location"))

## An interaction a storyline step offers (not a duel picked for its own sake).
func _story_option(option: Dictionary) -> bool:
	var label := str(option.get("label", ""))
	return not (label.begins_with("约斗") or label.begins_with("切磋"))

func _gather() -> void:
	if not s.available_here("gather"):
		_go("ridge" if str(s.player.location) != "wild" else "wild")
		return
	_do("act", "GATHER", s.act("gather"))

## 全部卖出 keeps what commissions and errands ask for (inventory.gd reserved).
func _sell_all() -> void:
	if not s.available_here("sell"):
		_go("market")
		return
	_do("act", "SELL", s.act("sell"))

func _deliver() -> bool:
	for quest: Dictionary in s.player.quests.duplicate():
		var reason: String = s.delivery_block(quest)
		if reason.is_empty():
			_do("act", "DELIVER", s.deliver_commission(str(quest.key)))
			return true
	return false

## Takes commissions a new disciple can do now and then works on one.
func _commissions() -> bool:
	if s.player.quests.is_empty() and int(s.world.day) > 60:
		var board: String = s.board_here()
		if board.is_empty():
			return false
		for offer: Dictionary in s.commission_offers(board):
			if offer.kind in ["gather", "hunt", "patrol", "beast_parts"] and not s.world.quests_taken.has(offer.key):
				_charge("menu")
				_say("ACCEPT", "%s：%s" % [s.commission_text(offer).title, s.accept_commission(str(offer.key))])
				return true
		return false
	for quest: Dictionary in s.player.quests:
		match str(quest.kind):
			"gather", "beast_parts":
				if str(quest.kind) == "beast_parts":
					if _go("wild"):
						return true
					_do("act", "HUNT", s.act("hunt"))
					return true
				_gather()
				return true
			"hunt":
				if _go("wild"):
					return true
				_do("act", "HUNT", s.act("hunt"))
				return true
			"patrol":
				return _go(str(quest.get("place", "town")))
	return false

func _learn() -> bool:
	# A 心法 from the hall once settled in; and 参悟 of the arts in use when a few days suffice.
	if s.player.methods.is_empty() and s.has_flag("intro_done") and int(s.world.day) > 100:
		if _go("sect"):
			return true
		for technique_id: String in s.teachings():
			var t: Dictionary = s.content.technique(technique_id)
			if t.slot == "method" and s.learn_block(technique_id).is_empty():
				_charge("study")
				_mark("first 心法")
				# The hall hands out the slip; it is studied in the chamber next door.
				_say("SLIP", s.take_slip(technique_id))
				_say("LEARN", s.study_manual("j:" + technique_id))
				return true
	for art_id: String in s.active_skills():
		if s.comprehend_block(art_id).is_empty() and int(s.Layers.comprehend_cost(s, art_id).days) <= 12 and int(s.Layers.comprehend_cost(s, art_id).stones) == 0:
			_charge("study")
			_say("COMPREHEND", s.comprehend(art_id))
			return true
	return false

## Out of the room for a while: gather and sell, spar, take a commission — the mind and fatigue recover.
func _outing() -> void:
	if s.herb_count() >= 8:
		_sell_all()
		return
	_gather()

func _retreat() -> void:
	if not s.available_here("cultivate"):
		_go("sect")
		return
	if s.at_xp_cap():
		_outing()
		return
	_charge("retreat")
	_say("RETREAT", s.cultivate(s.retreat_most()))

func _bottleneck() -> bool:
	if not s.at_bottleneck():
		return false
	_mark("first bottleneck")
	if s.item_count("pozhang_pill") > 0:
		_do("act", "PILL", s.use_item("pozhang_pill"))
		return true
	# 历练: duels and outings break it — 松风岭's woods when 落霞谷 is sealed.
	var ground := "ridge" if s.has_flag("serpent_rampage") else "wild"
	if str(s.player.location) == ground or not _go(ground):
		_do("act", "FIGHT", s.act("hunt"))
	return true

## At the threshold of 筑基: earn the pill, buy it, break through.
func _breakthrough() -> bool:
	var next: Dictionary = s.next_breakthrough()
	if next.is_empty() or int(s.player.xp) < int(next.xp):
		return false
	_mark("ready to break through (%s)" % s.content.realm(int(s.player.realm) + 1).name)
	var plan: Dictionary = s.breakthrough_plan()
	var pill: String = s.Breakthrough.pill_of(s)
	var has_pill: bool = pill.is_empty() or s.pill_count(pill) >= int(next.get("pills", 1)) or not s.breakthrough_treasures().is_empty()
	if has_pill:
		if _go("sect"):
			return true
		_charge("breakthrough")
		var odds: Dictionary = s.breakthrough_odds(plan)
		var realm_before := int(s.player.realm)
		_say("BREAKTHROUGH", "成功率 %s → %s" % [str(odds.get("total", "?")), s.breakthrough(plan)])
		if int(s.player.realm) == realm_before and s.battle.is_empty() and s.pending_event.is_empty():
			breakthrough_failures += 1
		if int(s.player.realm) >= 1:
			_mark("筑基")
		return true
	if int(s.player.stones) >= Goals._price(s, pill) and pill == "foundation_pill":
		if _go("market"):
			return true
		_do("act", "BUY", s.buy(pill))
		return true
	_say("SHORT", "缺%s：%s（灵石 %d）" % [s.content.item(pill).name, s.breakthrough_block(plan), int(s.player.stones)])
	_outing()
	return true

## Follow the same public challenge offered to a player, with the ordinary health check above.
func _local_milestone() -> bool:
	if int(s.player.realm) >= 1 and not s.has_flag("serpent_slain") and not s.has_flag("serpent_rampage"):
		if _go("wild"):
			return true
		if s.item_count("polin_powder") > 0 and s.use_block("polin_powder").is_empty():
			_do("act", "PREPARE", s.use_item("polin_powder"))
			return true
		_do("act", "SERPENT", s.start_battle("serpent"))
		return true
	return false

func _preferred_outing() -> bool:
	if not s.Storylines.guide_step(s).is_empty():
		return false
	if strategy == "social":
		for person_id: String in s.present_npcs():
			if s.is_generated(person_id):
				continue
			for option: Dictionary in s.npc_options(person_id):
				if option.id == "talk" and option.available:
					_do("talk", "SOCIAL", s.interact(person_id, "talk"))
					return true
	elif strategy == "explore":
		var ground := "ridge" if s.has_flag("serpent_rampage") else "wild"
		if _go(ground):
			return true
		if s.available_here("hunt"):
			_do("act", "EXPLORE", s.act("hunt"))
			return true
	return false
