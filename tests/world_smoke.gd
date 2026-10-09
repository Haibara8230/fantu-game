extends SceneTree
## Calendar, unified time, save migration, random streams and chronicle checks.
const Session = preload("res://scripts/core/session.gd")
const SaveStore = preload("res://scripts/core/save_store.gd")
const Calendar = preload("res://scripts/core/calendar.gd")
const Chronicle = preload("res://scripts/core/chronicle.gd")
const FIXTURES := "res://tests/fixtures/"
var checks := 0
var failures := 0

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: " + message)

func _fixture(name: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(FIXTURES + name))
	return parsed if parsed is Dictionary else {}

func _initialize() -> void:
	_calendar()
	_unified_time()
	_migration()
	_store_migration()
	_validation_from_config()
	_random_streams()
	_chronicle()
	_time_writes_are_centralized()
	print("WORLD: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

func _calendar() -> void:
	check(Calendar.date_text(0) == "历元 1 年 1 月初一", "day 0 is the first day of the era")
	check(Calendar.date_text(359) == "历元 1 年 12 月三十", "last day of year one")
	check(Calendar.date_text(360) == "历元 2 年 1 月初一", "year rolls over")
	check(Calendar.day_name(10) == "初十" and Calendar.day_name(15) == "十五" and Calendar.day_name(20) == "二十" and Calendar.day_name(21) == "廿一", "day names")
	check(Calendar.duration_text(5) == "5 日" and Calendar.duration_text(90) == "3 个月" and Calendar.duration_text(720) == "2 年", "durations")
	check(Calendar.age_years(-16 * 360, 359) == 16 and Calendar.age_years(-16 * 360, 360) == 17, "age advances by full years")

func _unified_time() -> void:
	var game = Session.new()
	game.new_game("行路", 11)
	check(game.age() == 16 and game.lifespan() == 120, "starting age and realm lifespan")
	var before: Dictionary = game.snapshot()
	game.travel("sect")
	game.journal_lines()
	game.realm_name()
	check(game.snapshot() == before, "viewing and invalid travel do not move time")
	game.travel("wild")
	check(game.world.day == game.content.route_days("sect", "wild"), "travel uses route length")
	var entry: Dictionary = game.chronicle.entries.back()
	check(entry.id == "travel" and entry.args.days == 30 and entry.args.location == "wild", "travel recorded with structured arguments")
	check(game.journal_lines().back().begins_with("【1年2月初一】跋涉 1 个月，抵达落霞谷"), "chronicle renders from template and date")
	game.travel("market")
	var day: int = game.world.day
	game.act("sell")
	check(game.world.day == day, "trading takes no time")

func _migration() -> void:
	var fresh = Session.new()
	check(fresh.restore(_fixture("v1_fresh.json")), "v1 fresh save migrates")
	check(fresh.snapshot().version == Session.SAVE_VERSION and fresh.world.day == 0 and fresh.age() == 16, "migrated time and age")
	check(fresh.chronicle.entries.size() == 1 and fresh.chronicle.entries[0].major, "v1 journal becomes chronicle with major marker")
	var copy = Session.new()
	check(copy.restore(JSON.parse_string(JSON.stringify(fresh.snapshot()))) and copy.snapshot() == fresh.snapshot(), "migrated save round-trips as the current version")

	var done = Session.new()
	var completed: Dictionary = _fixture("v1_completed.json")
	check(done.restore(completed), "v1 save after the serpent migrates")
	check(done.has_flag("serpent_slain") and done.player.realm == 1 and done.player.max_hp == 140, "completion becomes a world flag; stats derive from realm")
	check(done.world.day == int(completed.player.month) * 30, "months convert to days")
	var dated := false
	var majors := 0
	for item: Dictionary in done.chronicle.entries:
		if item.args.get("text", "").contains("丹田化海"):
			dated = item.day == 390
		if item.major:
			majors += 1
	check(dated, "legacy entry keeps its recorded month")
	check(majors >= 4, "legacy milestones kept as major entries")
	var settled: Dictionary = done.snapshot()
	done.start_battle("serpent")
	check(done.snapshot() == settled, "migrated world keeps the serpent slain")
	done.travel("sect")
	done.act("cultivate")
	check(done.world.day == int(settled.world.day) + 60, "migrated journey keeps going")

	var future: Dictionary = fresh.snapshot()
	future.version = Session.SAVE_VERSION + 1
	check(not copy.restore(future), "future version rejected")
	var ancient: Dictionary = _fixture("v1_fresh.json")
	ancient.version = 0
	check(not copy.restore(ancient), "unknown old version rejected")
	var broken: Dictionary = _fixture("v1_fresh.json")
	broken.player.erase("month")
	check(not copy.restore(broken), "malformed v1 rejected")

func _store_migration() -> void:
	var path := "res://.godot/migration_store_%d" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path))
	DirAccess.copy_absolute(ProjectSettings.globalize_path(FIXTURES + "v1_store/journey_1.json"), ProjectSettings.globalize_path(path + "/journey_1.json"))
	var store = SaveStore.new(path)
	var game = Session.new()
	check(store.load_game(game) and game.player.name == "青禾", "save store reads a v1 file")
	game.act("cultivate")
	check(store.save_game(game), "migrated journey saves")
	var newest: Variant = JSON.parse_string(FileAccess.get_file_as_string(path + "/journey_0.json"))
	check(newest is Dictionary and int(newest.session.version) == Session.SAVE_VERSION, "new generation written in the current version")
	check(FileAccess.file_exists(path + "/journey_1.json") and int(JSON.parse_string(FileAccess.get_file_as_string(path + "/journey_1.json")).session.version) == 1, "previous v1 generation kept as backup")

func _validation_from_config() -> void:
	var game = Session.new()
	game.new_game("校验", 1)
	var data: Dictionary = game.snapshot()
	data.player.realm = 1
	data.player.hp = 140
	check(game.restore(data.duplicate(true)), "realm limits come from configuration")
	data.player.hp = 141
	check(not game.restore(data.duplicate(true)), "hp above realm limit rejected")
	data.player.hp = 100
	data.player.realm = game.content.realms.size()
	check(not game.restore(data.duplicate(true)), "unopened realm rejected")
	data = game.snapshot()
	data.chronicle[0].day = data.world.day + 1
	check(not game.restore(data), "chronicle entries from the future rejected")
	data = game.snapshot()
	data.rng.erase("world")
	check(not game.restore(data), "missing random stream rejected")

func _random_streams() -> void:
	var gatherer = Session.new()
	var fighter = Session.new()
	gatherer.new_game("采药", 5)
	fighter.new_game("斗法", 5)
	gatherer.travel("wild")
	fighter.travel("wild")
	for i: int in range(3):
		gatherer.act("gather")
	gatherer.start_battle("wolf")
	fighter.start_battle("wolf")
	var a: Array = []
	var b: Array = []
	for i: int in range(3):
		gatherer.use_skill("sword")
		fighter.use_skill("sword")
		a.append(gatherer.combat_events.map(func(event: Dictionary) -> int: return int(event.get("amount", 0))))
		b.append(fighter.combat_events.map(func(event: Dictionary) -> int: return int(event.get("amount", 0))))
	check(a == b, "world-side draws do not change duel results")

func _chronicle() -> void:
	var game = Session.new()
	game.new_game("记事", 2)
	var record = Chronicle.new()
	record.add(0, "start", {}, true)
	for i: int in range(150):
		record.add(i, "gather", {"amount": i})
	record.add(150, "breakthrough", {"days": 90, "realm": 1}, true)
	var minors: Array = record.entries.filter(func(item: Dictionary) -> bool: return not item.major)
	check(minors.size() == Chronicle.RECENT_LIMIT and record.entries.size() == Chronicle.RECENT_LIMIT + 2, "everyday entries trimmed, milestones kept")
	check(record.entries[0].id == "start" and minors[0].args.amount == 50, "trim keeps order and the most recent entries")
	check(record.format(record.entries.back(), game.content) == "闭关 3 个月，丹田化海，你已踏入筑基初期。", "names resolved when displayed")
	game.content.locations.wild.name = "落霞旧谷"
	check(record.format({"day": 0, "id": "travel", "args": {"days": 30, "location": "wild"}, "major": false}, game.content).contains("落霞旧谷"), "renamed content updates old records")
	check(record.format({"day": 0, "id": "removed_event", "args": {}, "major": false}, game.content) == "（失传的记载）", "removed templates degrade gracefully")

func _time_writes_are_centralized() -> void:
	# World time may only be assigned inside Session.advance_days (new_game and restore rebuild the whole world).
	var pattern := RegEx.create_from_string("world\\.day\\s*[-+]?=[^=]|world\\[\"day\"\\]\\s*[-+]?=[^=]")
	var offenders: Array[String] = []
	for folder: String in ["res://scripts/core", "res://scripts/ui", "res://scripts/presentation"]:
		for file_name: String in DirAccess.get_files_at(folder):
			if not file_name.ends_with(".gd"):
				continue
			var text := FileAccess.get_file_as_string(folder.path_join(file_name))
			if pattern.search(text) and file_name != "session.gd":
				offenders.append(file_name)
	var session_text := FileAccess.get_file_as_string("res://scripts/core/session.gd")
	var start := session_text.find("func advance_days")
	var body := session_text.substr(start, session_text.find("\nfunc ", start + 1) - start)
	var inside := pattern.search_all(body).size()
	check(offenders.is_empty() and inside > 0 and pattern.search_all(session_text).size() == inside, "world time changes only through advance_days: %s" % ", ".join(offenders))
