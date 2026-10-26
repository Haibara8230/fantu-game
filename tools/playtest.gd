extends SceneTree
## A first journey played headless the way a new player would: the guided start, then the current goals
## (data/goals.json, goals.gd) and the storylines, commissions, gathering and selling for stones, duels,
## retreats, the 筑基丹 and the breakthrough, and some years after. Over a long life it ticks the 出关
## reminders a player would and keeps those appointments, explores the caves a storyline's finding lies
## in, takes up the once-only things people offer, and gathers what 照川城's 阵枢 asks. Everything the player would read is
## printed with the date, and each action is charged the seconds a player would spend on it, to judge
## pacing. Only rules are used; no window is opened.
## Usage: godot --headless --path . --script res://tools/playtest.gd [-- <seed> <years> [random|poor|ordinary|good] [cultivate|social|explore] [sect|wanderer]]
## The route: join 青云 after the opening (sect), or stay a 散修 who joins 天南散修盟, lives by 云溪's branch room
## and rents a lodge, and at 金丹 with standing retreats in 北岳's 灵窟 (wanderer).
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
var route := "sect"
var decisions := 0
var milestone_days := {}
var losses := 0
var breakthrough_failures := 0
# Everyday options of anyone (people.gd, bonds.gd): not what a storyline asks.
const EVERYDAY := ["talk", "gift", "help", "companion", "consult", "disciple", "instruct", "invite_help", "invite_spar", "sworn", "teach"]
var stuck := 0
var last_result := ""
# Appointments already kept ("event:day" of the window's opening).
var kept := {}
# Story steps found idle on arrival, not travelled for again until a day ("story:step" -> day).
var idle := {}
# Guardians faced again in a row, by cave.
var tries := {}
# Fights a choice has started ("event:choice" -> times): after a few, another way is taken if there is one.
var fights := {}
# Caves given up on until a day (cave id -> day), when a room barred the way.
var barred := {}
# Where each storyline finding lies: flag -> [cave, room] (a room's own finding or its guardian's flag).
var findings := {}
# The occasions a player plans a life around and ticks before a long retreat (the rest are left to chance).
const APPOINTMENTS := ["tiannan_contest_", "five_sects_entry", "jianya_open", "chenxia_gathering", "wenren_sail_day", "ye_deadline", "chixia_season", "wanjian_season"]
# The world flags worth reporting at the end of a long life (batches 4–6).
const REPORTED := ["guest_chixiao", "guest_changqing", "guest_canglan", "guest_xuanyue", "ye_cure", "ye_forbidden", "ye_letgo", "ye_late", "wenren_found_alive", "wenren_found_dead", "zhaochuan_seen", "guzhan_cleared", "pillar_cleared", "shouchuan_joined", "shouchuan_refused", "shouchuan_pact", "wen_testimony", "wen_diary", "zhaochuan_entered", "rift_seen", "truth_public", "truth_kept", "path_reopen", "path_replace", "path_self", "wuzong_champion", "tiannan_champion"]

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
	route = str(args[4]) if args.size() > 4 else "sect"
	if not route in ["sect", "wanderer"]:
		printerr("Route must be sect or wanderer")
		quit(1)
		return
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
	s.new_game("试玩", seed_value, roots, "rushi", born)
	for cave_id: String in s.content.cave_data:
		for room: Dictionary in s.content.cave_data[cave_id].rooms:
			if room.has("flag"):
				findings[str(room.flag)] = [cave_id, str(room.id)]
			if room.has("guardian"):
				var guarded: String = str(s.content.enemies[str(room.guardian)].get("world_flag", ""))
				if not guarded.is_empty():
					findings[guarded] = [cave_id, str(room.id)]
	_say("START", "灵根 %s（%s）· 天赋 %s · 缺陷 %s · 资质 %s" % [s.root_title(), ", ".join(roots), ", ".join(s.player.talents), ", ".join(s.player.flaws), str(s.aptitude().get("name", s.aptitude()))])
	_chronicle_since(0)
	var guard := 0
	while s.ended.is_empty() and int(s.world.day) < years * Calendar.DAYS_PER_YEAR and guard < 20000:
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
	print("PLAYTEST_RESULT ", JSON.stringify({"seed":seed_value,"opening":opening,"strategy":strategy,"route":route,"day":int(s.world.day),"realm":int(s.player.realm),"stones":int(s.player.stones),"estimated_minutes":float(seconds)/60.0,"clicks":clicks,"duels":duels,"steps":guard,"guard_exhausted":guard>=4000,"milestone_days":milestone_days,"losses":losses,"breakthrough_failures":breakthrough_failures,"early_serpent":s.Storylines.deed_count(s,"win:serpent")>0,"aftermath":s.story_state("valley_aftermath"),"recovery":s.story_state("valley_recovery"),"flags":REPORTED.filter(func(flag: String) -> bool: return s.has_flag(flag)),"mirror":str(s.Storylines.current_step(s, "mirror").get("id", s.story_state("mirror")))}))
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
	# 结丹 (forming.gd): one decision of the plain policy at a time, as a player clicks through it.
	if not s.forming.is_empty():
		if s.Forming.plain_step(s):
			_do("act", "FORMING", "")
		else:
			_do("act", "FORMING", s.forming_end_round(true))
		return
	if not s.player.journey.is_empty():
		_do("travel", "ONWARD", s.continue_journey())
		return
	if s.at_brink():
		_do("act", "BRINK", s.accept_end())
		return
	# Inside a 秘境 the days are counted: no resting at an inn there.
	if not s.Mijing.inside(s).is_empty() and _mijing():
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
	for realm: int in range(1, s.content.realms.size()):
		if int(s.player.realm) >= realm:
			_mark(str(s.content.realm(realm).name))
	if s.Storylines.deed_count(s, "win:serpent") > 0:
		_mark("除蟒")
	for bout: int in range(1, 4):
		if s.has_flag("xiao_bout%d" % bout):
			_mark("萧凌云第%d回：%s" % [bout, "胜" if s.has_flag("xiao_win%d" % bout) or (bout == 3 and s.has_flag("xiao_ambush")) else "负"])
	for ending: String in ["xiao_friend", "xiao_yield", "xiao_slain", "xiao_trampled"]:
		if s.has_flag(ending):
			_mark("萧家结局：" + ending)
	for scroll_id: String in s.Tianji.data(s).scrolls:
		if s.Tianji.best(s, scroll_id) > 0 and s.Tianji.best(s, scroll_id) <= 10:
			_mark("%s前十" % s.Tianji.scroll(s, scroll_id).name)
	for ending: String in ["chixia_exposed", "chixia_jiao_down", "chixia_jiao_beaten", "chixia_dan", "chixia_suheng", "chixia_done", "tianque_friend", "tianque_feud", "tianque_qingyun"]:
		if s.has_flag(ending):
			_mark("秘境结局：" + ending)
	for ending: String in ["canyu_free", "canyu_lie", "canyu_lu", "canyu_given", "lengxiang_solved", "lengxiang_plead", "lengxiang_exposed", "xishou_mediated", "xishou_sided", "feiyu_owes", "guishi_second", "guishi_gone"]:
		if s.has_flag(ending):
			_mark("第 6 步结局：" + ending)
	# 无相宝录 (wuxiang.gd): how each page was had, and how it ended.
	for n: int in range(1, s.Wuxiang.data(s).pages.size() + 1):
		if s.Wuxiang.held(s, n) or not s.Wuxiang.page_state(s, n).is_empty():
			_mark("无相宝录第 %d 处：%s" % [n, s.Wuxiang.page_state(s, n) if not s.Wuxiang.page_state(s, n).is_empty() else "self"])
	for ending: String in ["master", "shared", "sold"]:
		if s.Wuxiang.met(s, ending):
			_mark("无相宝录结局：" + ending)
	if _opening():
		return
	if _mijing():
		return
	if _ascend():
		return
	if _appointment():
		return
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
	if _settle():
		return
	if _earn():
		return
	if decisions % 7 == 0 and _preferred_outing():
		return
	# Cultivation first, as the game means it: out of the room (commissions, hunting, gathering) only
	# when the retreat has grown stale or the xp waits at the stage's cap.
	if s.retreat_efficiency() >= 70 and s.mind_percent() >= 60 and not s.at_xp_cap():
		_retreat()
		return
	if _tianji():
		return
	if _guishi():
		return
	if _commissions():
		return
	_outing()

func _event() -> void:
	var definition: Dictionary = s.pending_definition()
	var choices: Array = definition.get("choices", [])
	var shown: Array[String] = []
	var pick := ""
	var fallback := ""
	for choice: Dictionary in choices:
		var open := s.choice_available(choice)
		shown.append("%s%s" % [str(choice.get("text", choice.get("label", choice.id))), "" if open else "（不可选）"])
		# A fight to the death only when nothing else is open (a player keeps their life).
		var deadly: bool = choice.get("effects", []).any(func(effect: Dictionary) -> bool: return effect.has("deadly"))
		# A fight lost again and again (萧家's house at 元婴): after five, the next way out instead.
		var worn: bool = choice.get("effects", []).any(func(effect: Dictionary) -> bool: return effect.has("battle")) and int(fights.get("%s:%s" % [s.pending_event.id, choice.id], 0)) >= 5
		if open and (deadly or worn) and fallback.is_empty():
			fallback = str(choice.id)
		elif open and pick.is_empty() and not worn:
			pick = str(choice.id)
	if pick.is_empty():
		pick = fallback
	_say("EVENT", "%s：%s ｜ 选项：%s" % [str(definition.get("title", s.pending_event.id)), str(definition.get("text", "")), "、".join(shown)])
	var key := "%s:%s" % [s.pending_event.id, pick]
	fights[key] = int(fights.get(key, 0)) + 1
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
	# An inn the purse cannot pay for: 调息 where one stands.
	var broke := not s.available_here("rest") and s.available_here("inn_rest") and int(s.player.stones) < int(s.content.rules.inn_price)
	if (s.available_here("rest") or s.available_here("inn_rest")) and not broke:
		_do("act", "REST", s.act("rest" if s.available_here("rest") else "inn_rest"))
	elif float(s.content.rules.get("field_rest", 0.0)) > 0.0:
		_do("act", "WAIT", s.wait(10))
	else:
		_go(_home())

## Where one retreats and breaks through: the sect's chamber, or for a 散修 云溪's branch room, inn and
## lodge — until a 灵地 of 天南散修盟 takes them (金丹 and standing).
func _home() -> String:
	if s.Sect.member(s):
		return "sect"
	if s.League.member(s):
		for place: String in ["beiyue", "wanghai"]:
			if not s.location_visible(place):
				continue
			for spot: Dictionary in s.content.locations[place].spots:
				if spot.get("lodging", {}).has("realm") and s.League.room_open(s, spot.lodging) and int(s.player.stones) >= int(spot.lodging.rent) * 2:
					return place
	return "market"

func _sealed(place: String) -> bool:
	return s.content.location_sealed(place, s.world.flags)

func _go(place: String) -> bool:
	if str(s.player.location) == place:
		return false
	var path: Array = s.path_to(place)
	# No road the realm can take there yet (the sea to 外海雾岛 before 金丹): not a journey.
	if path.is_empty():
		return false
	_do("travel", "TRAVEL", "→ %s：%s" % [s.content.locations[place].name, s.travel(place)])
	return true

## The guided start and the storylines: go where the step is, do what it asks.
## The 入世 opening: go where its step is and let the days bring its occasions; afterwards join 青云,
## whose life the strategies below play.
func _opening() -> bool:
	var step: Dictionary = s.story_step(str(s.content.rules.opening.story))
	if not step.is_empty():
		if _go(str(step.get("place", s.player.location))):
			return true
		_do("act", "OPENING", s.wait(1))
		return true
	if route == "sect" and s.affiliation().is_empty() and s.has_flag("rushi_done"):
		if _go("sect"):
			return true
		_do("act", "JOIN", s.join_sect())
		return true
	return false

func _story() -> bool:
	if _ask_here():
		return true
	for goal: Dictionary in Goals.story_goals(s):
		var story_id := str(goal.id).trim_prefix("story:")
		var step: Dictionary = s.story_step(story_id)
		# 温照衡's note: be at the ferry on a full moon (the 15th) and wait for the night.
		if story_id == "mirror" and str(step.get("id", "")) == "tianhe" and Calendar.day_of_month(int(s.world.day)) >= 10:
			if _go("ferry"):
				return true
			_do("act", "WAIT", s.wait(1))
			return true
		var place := str(step.get("place", s.player.location))
		var idle_key := "%s:%s" % [story_id, str(step.get("id", ""))]
		var requires_person := false
		for person_id: String in s.content.people:
			for interaction: Dictionary in s.content.people[person_id].get("interactions", []):
				# Only someone whose part can be played now: what they ask is carried, not done before.
				if interaction.get("conditions", []).any(func(c: Dictionary) -> bool: return c.has("story_at") and c.story_at == [story_id, str(step.id)]) and interaction.get("conditions", []).all(func(c: Dictionary) -> bool: return s.Events.met(s, c)):
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
		# A sealed place (落霞谷 while the serpent is loose) waits for its reopening.
		if _sealed(place):
			continue
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
		# A finding inside a cave: explore toward it.
		if _explore_for(step):
			return true
		# Stones a step's offer asks (a reckoning paid for, a ship stocked): out to earn them.
		if _short_for(story_id, step):
			return true
		if story_id == "mirror" and str(step.id) == "choice" and _gather_for_choice():
			return true
		# A choice asked at the place, an occasion that happens there, or someone there with something
		# to offer only once: worth the journey.
		doable = doable or step.has("choice_event") or _happens_at(story_id, step, place) or _once_at(place)
		if not doable and place != str(s.player.location):
			continue
		if place != str(s.player.location) and (int(idle.get(idle_key, -1)) > int(s.world.day) or s.path_to(place).is_empty()):
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
		if deeds.has("gather") and s.available_here("gather"):
			_do("act", "GATHER", s.act("gather"))
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
		# Here for the step and nothing came of it: not worth the journey again for a month.
		if place == str(s.player.location):
			idle[idle_key] = int(s.world.day) + Calendar.DAYS_PER_MONTH
	return false

## Something a storyline asks of a person present, or something they offer only once: asked at once.
func _ask_here() -> bool:
	for person_id: String in s.present_npcs():
		for option: Dictionary in s.npc_options(person_id):
			if option.get("reason", "").is_empty() and not str(option.id) in EVERYDAY and _story_option(option) and (_advances_story(person_id, str(option.id)) or _once(person_id, str(option.id))):
				_charge("talk")
				_say("ASK", "%s · %s → %s" % [s.person(person_id).name, option.label, s.interact(person_id, str(option.id))])
				return true
	return false

## Whether an interaction is a storyline's step (its conditions name an active step).
func _advances_story(person_id: String, option_id: String) -> bool:
	for interaction: Dictionary in s.content.people[person_id].get("interactions", []):
		if str(interaction.id) == option_id:
			return interaction.get("conditions", []).any(func(c: Dictionary) -> bool: return c.has("story_at") and s.story_at(str(c.story_at[0]), str(c.story_at[1])))
	return false

## Whether the things a step's hand-in asks are carried (the 凝露草 for 许清和).
func _carrying_for(story_id: String, step: Dictionary) -> bool:
	var needs: Dictionary = s.Storylines.required_items(s, story_id)
	if not needs.is_empty():
		for item_id: String in needs:
			if s.item_count(item_id) < int(needs[item_id]):
				return false
		return true
	var done: Array = step.get("done", [])
	return done.any(func(c: Dictionary) -> bool: return c.has("at_location")) and done.all(func(c: Dictionary) -> bool: return not c.has("item_at_least") or s.item_count(str(c.item_at_least[0])) >= int(c.item_at_least[1]))

## An interaction a storyline step offers (not a duel picked for its own sake, nor a 筑基丹 bought past
## foundation).
func _story_option(option: Dictionary) -> bool:
	var label := str(option.get("label", ""))
	if label.contains("筑基丹") and int(s.player.realm) >= 1:
		return false
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
			if offer.kind in ["gather", "hunt", "patrol", "beast_parts", "league_fetch", "league_wolves"] and not s.world.quests_taken.has(offer.key):
				_charge("menu")
				_say("ACCEPT", "%s：%s" % [s.commission_text(offer).title, s.accept_commission(str(offer.key))])
				return true
		return false
	for quest: Dictionary in s.player.quests:
		match str(quest.kind):
			"gather", "beast_parts":
				if str(quest.kind) == "beast_parts":
					if _go("ridge" if _sealed("wild") else "wild"):
						return true
					_do("act", "HUNT", s.act("hunt"))
					return true
				_gather()
				return true
			"hunt", "league_wolves":
				if _go("ridge" if _sealed("wild") else "wild"):
					return true
				_do("act", "HUNT", s.act("hunt"))
				return true
			"patrol", "league_fetch":
				return _go(str(quest.get("place", "town")))
	return false

func _learn() -> bool:
	# A 心法 from the hall once settled in; and 参悟 of the arts in use when a few days suffice.
	if s.player.methods.is_empty() and s.Sect.member(s) and int(s.world.day) > 100:
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

## A 散修 whose purse would not pay two months of the inn goes out to earn: a commission from the
## board, else herbs gathered and sold.
func _earn() -> bool:
	if s.Sect.member(s) or not s.has_flag("rushi_done") or s.has_flag("yunxi_abode"):
		return false
	var inn: Dictionary = {}
	for spot: Dictionary in s.content.locations[_home()].spots:
		if spot.has("lodging"):
			inn = spot.lodging
	if inn.is_empty() or int(s.player.stones) >= int(inn.rent) * 2:
		return false
	if _commissions():
		return true
	_outing()
	return true

## A 散修 joins 天南散修盟 at 云溪's lamp once out in the world; with stones to spare they lease 云溪's
## 溪畔竹舍: no rent by the month, a whole retreat's yield.
func _settle() -> bool:
	if s.Sect.member(s) or not s.has_flag("rushi_done"):
		return false
	if not s.League.member(s) and not s.League.banned(s):
		if str(s.player.location) != "market" and _go("market"):
			return true
		if str(s.player.location) == "market" and s.League.block(s).is_empty():
			_do("act", "LEAGUE", s.league_join())
			return true
	var lease: Dictionary = s.content.locations.market.get("lease", {})
	if lease.is_empty() or s.has_flag(str(lease.flag)) or int(s.player.stones) < int(lease.price) + 60:
		return false
	if _go("market"):
		return true
	_do("act", "LEASE", s.take_lease())
	return true

## Out of the room, at a city's 榜亭 and whole: a 战帖 up the 天骄榜 (tianji.gd) — as far up as the
## seat's strength allows the player's stage, else the next seat up.
## 鬼市 (guishi.gd): on the fifteenth at 云溪, a look round, and a lot the 神识 believes is good bought
## when the purse is deep enough.
func _guishi() -> bool:
	if not s.available_here("guishi") or not s.Guishi.block(s).is_empty():
		return false
	s.Guishi.visit(s)
	_mark("鬼市")
	var lots: Array = s.Guishi.lots(s)
	for index: int in lots.size():
		if int(lots[index].hint) >= 2 and int(s.player.stones) >= int(lots[index].price) * 3 and s.Guishi.gamble_block(s, index).is_empty():
			_do("act", "GUISHI", s.guishi_gamble(index))
			return true
	return false

## 秘境 (mijing.gd): inside, the next room open to the player, a guardian faced again once, things a
## fallen guardian kept, a hidden place the 神识 sees; out by the door when nothing is left or the days
## run short. Outside, while one opens that the player may enter, go where it calls from.
func _mijing() -> bool:
	var realm_id: String = s.Mijing.inside(s)
	if realm_id.is_empty():
		for candidate: String in s.content.mijing_data.realms:
			var info: Dictionary = s.content.mijing_data.realms[candidate]
			var held: Dictionary = s.Mijing.state(s)
			if not s.Mijing.is_open(s, candidate) or not s.Mijing.fits(s, candidate) or int(held.offered.get(candidate, -1)) == int(held.opened.get(candidate, -2)):
				continue
			for place: String in [_home()] + Array(info.call_at):
				if place in info.call_at and s.location_visible(place) and (str(s.player.location) == place or not s.path_to(place).is_empty()):
					_mark("秘境：" + str(info.name))
					if _go(place):
						return true
					_do("act", "MIJING", s.wait(1))
					return true
		return false
	var cave_id := str(s.Mijing.realm(s, realm_id).cave)
	if s.Mijing.days_left(s, realm_id) <= 3 or int(s.player.hp) * 4 < int(s.player.max_hp):
		_do("act", "MIJING", s.mijing_exit())
		return true
	for room: Dictionary in s.content.cave_data[cave_id].rooms:
		var room_id := str(room.id)
		if s.Caves.explored(s, cave_id, room_id):
			if s.Caves.loot_waits(s, cave_id, room_id):
				_do("act", "MIJING", s.collect_room(cave_id, room_id))
				return true
			if s.Caves.hidden_seen(s, cave_id, room_id) and s.Caves.hidden_block(s, cave_id, room_id).is_empty():
				_do("act", "MIJING", s.open_hidden(cave_id, room_id))
				return true
			if s.Caves.guarded(s, cave_id, room_id) and int(tries.get(cave_id, 0)) < 1 and int(s.player.hp) == int(s.player.max_hp):
				tries[cave_id] = int(tries.get(cave_id, 0)) + 1
				_do("act", "MIJING", s.challenge_guardian(cave_id, room_id))
				return true
		elif s.Caves.enter_block(s, cave_id, room_id).is_empty():
			_do("act", "MIJING", s.enter_room(cave_id, room_id))
			return true
	_do("act", "MIJING", s.mijing_exit())
	tries.erase(cave_id)
	return true

func _tianji() -> bool:
	if not s.available_here("tianji") or not s.Tianji.block(s).is_empty() or int(s.player.hp) < int(s.player.max_hp) or int(s.player.qi) < int(s.player.max_qi):
		return false
	var scroll_id: String = s.Tianji.own_scroll(s)
	var span: Array = s.Tianji.reach(s, scroll_id)
	if span.is_empty():
		return false
	var target: int = int(span[0]) if int(s.Tianji.tier(s, int(span[0]))[0]) <= int(s.player.stage) else int(span[1])
	_mark("天骄榜")
	_do("act", "TIANJI", s.tianji_challenge(target))
	return true

## Out of the room for a while: gather and sell, spar, take a commission — the mind and fatigue recover.
func _outing() -> void:
	if s.herb_count() >= 8:
		_sell_all()
		return
	_gather()

func _retreat() -> void:
	if not s.available_here("cultivate"):
		_go(_home())
		return
	# A room the purse cannot pay for: home to the sect's chamber, or out to earn.
	if not s.Cultivation.rent_block(s, 30).is_empty():
		if s.Sect.member(s) and _go("sect"):
			return
		if not _commissions():
			_outing()
		return
	if s.at_xp_cap():
		_outing()
		return
	# A player ticks the appointments ahead before shutting the door (出关提醒).
	for entry: Dictionary in s.Events.upcoming(s):
		if _planned(str(entry.event)) and not s.wakes_for(str(entry.event)) and int(entry.from) > int(s.world.day):
			s.set_wake(str(entry.event), true)
	# A room paid by the month: out to earn when the purse covers less than a month.
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
		if _go(_home()):
			return true
		# The room for the days of the attempt is paid first: out to earn when the purse falls short.
		var blocked: String = s.breakthrough_block(plan)
		if not blocked.is_empty():
			_say("SHORT", blocked)
			if not _commissions():
				_outing()
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

## Whether a handwritten person's interaction is a once-only offer that costs no stones and starts no
## fight (told what was found, taught a secret).
func _once(person_id: String, option_id: String) -> bool:
	if not s.content.people.has(person_id):
		return false
	for interaction: Dictionary in s.content.people[person_id].get("interactions", []):
		if str(interaction.id) == option_id:
			var effects: Array = interaction.get("effects", [])
			return bool(interaction.get("once", false)) and not effects.any(func(effect: Dictionary) -> bool: return effect.has("battle") or (effect.has("stones") and int(effect.stones) < 0))
	return false

## Whether the bot plans around an occasion (APPOINTMENTS).
func _planned(event_id: String) -> bool:
	return APPOINTMENTS.any(func(prefix: String) -> bool: return event_id.begins_with(prefix))

## Whether someone found at `place` has a once-only offer open now.
func _once_at(place: String) -> bool:
	for person_id: String in s.content.people:
		if s.npc_location(person_id) != place:
			continue
		for interaction: Dictionary in s.content.people[person_id].get("interactions", []):
			if _once(person_id, str(interaction.id)) and _option_open(person_id, str(interaction.id)):
				return true
	return false

func _option_open(person_id: String, option_id: String) -> bool:
	for option: Dictionary in s.npc_options(person_id):
		if str(option.id) == option_id:
			return str(option.get("reason", "")).is_empty()
	return false

## Whether a choice asked by a step has something other than putting it off.
func _choice_open(event_id: String) -> bool:
	for choice: Dictionary in s.content.events.get(event_id, {}).get("choices", []):
		if str(choice.id) != "later" and s.choice_available(choice):
			return true
	return false

## Whether something happens at `place` for this step (a location event that names it).
func _happens_at(story_id: String, step: Dictionary, place: String) -> bool:
	var named := JSON.stringify({"story_at": [story_id, str(step.id)]})
	for event_id: String in s.content.location_events(place):
		var definition: Dictionary = s.content.events[event_id]
		var window: Dictionary = s.Events.window_at(definition, int(s.world.day))
		if window.is_empty() or s.Events.venue(definition, window) != place or not s.Events.open_for(s, event_id, window, int(s.world.day)):
			continue
		if JSON.stringify(definition.get("conditions", [])).contains(named.trim_prefix("{").trim_suffix("}")) and s.Events.all_met(s, definition.get("conditions", [])):
			return true
	return false

## The flags a step waits for (its `done`, through any/all).
func _wanted_flags(conditions: Array, into: Array) -> void:
	for condition: Dictionary in conditions:
		if condition.has("flag"):
			into.append(str(condition.flag))
		for key: String in ["any", "all"]:
			if condition.has(key):
				_wanted_flags(condition[key], into)

## Explores toward a finding the step waits for, in a cave that can be entered now. True when it acted.
func _explore_for(step: Dictionary) -> bool:
	var wanted: Array = []
	_wanted_flags(step.get("done", []), wanted)
	for flag: String in wanted:
		if s.has_flag(flag) or not findings.has(flag):
			continue
		var cave_id: String = findings[flag][0]
		var target: String = findings[flag][1]
		var cave: Dictionary = s.content.cave_data[cave_id]
		if int(barred.get(cave_id, -1)) > int(s.world.day) or not s.has_flag(str(cave.requires_flag)) or int(s.player.realm) < int(cave.get("requires_realm", 0)) or not s.location_visible(str(cave.location)):
			continue
		if _go(str(cave.location)):
			return true
		if not s.Caves.open_here(s, cave_id):
			continue
		if _explore_toward(cave_id, target):
			return true
	return false

## One step through a cave toward `target`: the next room on the way, a guardian faced again, things
## left behind taken. A room that bars the way sets the cave aside for a year.
func _explore_toward(cave_id: String, target: String) -> bool:
	for room_id: String in _cave_route(cave_id, target):
		if not s.Caves.explored(s, cave_id, room_id):
			var reason: String = s.Caves.enter_block(s, cave_id, room_id)
			if not reason.is_empty():
				_say("CAVE", "%s：%s" % [s.content.cave_data[cave_id].name, reason])
				barred[cave_id] = int(s.world.day) + Calendar.DAYS_PER_YEAR
				return false
			_do("act", "CAVE", s.enter_room(cave_id, room_id))
			return true
		if s.Caves.guarded(s, cave_id, room_id):
			# Beaten three times running: set the cave aside for a few years and grow stronger first.
			tries[cave_id] = int(tries.get(cave_id, 0)) + 1
			if int(tries[cave_id]) > 3:
				tries[cave_id] = 0
				barred[cave_id] = int(s.world.day) + 5 * Calendar.DAYS_PER_YEAR
				return false
			_do("act", "CAVE", s.Caves.challenge(s, cave_id, room_id))
			return true
		if s.Caves.loot_waits(s, cave_id, room_id):
			_do("act", "CAVE", s.collect_room(cave_id, room_id))
			return true
	return false

## The rooms from an opening room to `target` (breadth first over the links).
func _cave_route(cave_id: String, target: String) -> Array[String]:
	var rooms := {}
	var queue: Array = []
	var came := {}
	for room: Dictionary in s.content.cave_data[cave_id].rooms:
		rooms[str(room.id)] = room
		if bool(room.get("start", false)):
			queue.append(str(room.id))
			came[str(room.id)] = ""
	while not queue.is_empty():
		var at: String = queue.pop_front()
		if at == target:
			break
		for link: Variant in rooms[at].get("links", []):
			if not came.has(str(link)):
				came[str(link)] = at
				queue.append(str(link))
	var path: Array[String] = []
	var walk := target
	while came.has(walk) and not walk.is_empty():
		path.push_front(walk)
		walk = str(came[walk])
	return path

## The things 照川城's 阵枢 asks for a way over the river: 潮心石 and 寒铁 gathered where they lie.
func _gather_for_choice() -> bool:
	if _choice_open("zhenshu_choice"):
		return false
	for need: Array in [["chaoxin_shi", 3, "waihai"], ["ore_hantie", 5, "guzhanchang"]]:
		if s.item_count(str(need[0])) < int(need[1]):
			if _go(str(need[2])):
				return true
			_do("act", "GATHER", s.act("gather"))
			return true
	return false

## An appointment open now (a listed occasion that applies, or one ticked): go there for it once.
func _appointment() -> bool:
	for entry: Dictionary in s.Events.upcoming(s):
		var key := "%s:%d" % [str(entry.event), int(entry.from)]
		if not _planned(str(entry.event)) or kept.has(key) or int(entry.from) > int(s.world.day) or int(entry.to) < int(s.world.day):
			continue
		var place := str(entry.location)
		if place.is_empty() or not s.location_visible(place) or _sealed(place):
			kept[key] = true
			continue
		if _go(place):
			return true
		kept[key] = true
		_do("act", "WAIT", s.wait(1))
		return true
	return false

## Whether someone's offer for this step waits only on stones: if so, earns toward it and is true.
func _short_for(story_id: String, step: Dictionary) -> bool:
	var needed := 0
	for person_id: String in s.content.people:
		for interaction: Dictionary in s.content.people[person_id].get("interactions", []):
			var conditions: Array = interaction.get("conditions", [])
			if not conditions.any(func(c: Dictionary) -> bool: return c.has("story_at") and c.story_at == [story_id, str(step.id)]):
				continue
			var rest: Array = conditions.filter(func(c: Dictionary) -> bool: return not c.has("stones_at_least"))
			for condition: Dictionary in conditions:
				if condition.has("stones_at_least") and s.Events.all_met(s, rest):
					needed = maxi(needed, int(condition.stones_at_least))
	if needed <= int(s.player.stones):
		return false
	# Beast cores sell well in 南明: hunt where the realm allows, sell when the pack fills.
	if s.item_count("yaodan") + s.item_count("yaodan_small") >= 6:
		if _go("nanming"):
			return true
		for core: String in ["yaodan", "yaodan_small"]:
			if s.item_count(core) > 0:
				_do("act", "SELL", s.sell(core, s.item_count(core)))
				return true
		return true
	var ground := "waihai" if int(s.player.realm) >= 2 and s.location_visible("waihai") else "chifeng"
	if _go(ground):
		return true
	_do("act", "HUNT", s.act("hunt"))
	return true

## A way over the river settled (ascension.gd): to the crossing, and onto the bridge.
func _ascend() -> bool:
	if s.Ascension.route(s).is_empty() or int(s.player.realm) < s.content.realms.size() - 1 or s.Breakthrough.injured(s):
		return false
	if _go("ferry"):
		return true
	var reason: String = s.ascend_block()
	if not reason.is_empty():
		return false
	_mark("飞升天劫")
	_do("act", "ASCEND", s.act("ascend"))
	return true

