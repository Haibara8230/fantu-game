extends SceneTree
## Opening budgets, real tradeoffs, bounded high-end growth and legacy save compatibility.
const Session = preload("res://scripts/core/session.gd")
const Opening = preload("res://scripts/core/opening.gd")
const Talents = preload("res://scripts/core/talents.gd")
var checks := 0
var failures := 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: " + message)

func _initialize() -> void:
	create_timer(60.0).timeout.connect(func() -> void: printerr("OPENING test timed out"); quit(1))
	var game := Session.new()
	var content = game.content
	check(content.error_message.is_empty(), content.error_message)
	if not content.error_message.is_empty():
		quit(1)
		return
	var choice := Opening.fresh(content)
	Opening.set_root_count(content, choice, 5)
	for role: Dictionary in content.opening_data.difficulties:
		choice.difficulty = role.id
		check(Opening.points(content, choice) == int(role.points), "role budget " + str(role.id))
	choice.difficulty = "tianqian"
	check(not Opening.block(content, choice).is_empty(), "negative budget cannot start without a tradeoff")
	Opening.toggle(content, choice, "body", "mcs_frail")
	check(Opening.left(content, choice) == 0 and Opening.block(content, choice).is_empty(), "defect can repay negative budget")
	Opening.toggle(content, choice, "body", "mcs_frail")
	check(not Opening.block(content, choice).is_empty(), "removing a refund restores debt")
	choice.difficulty = "tianjiao"
	Opening.set_root_count(content, choice, 1)
	choice.roots = ["metal"]
	Opening.toggle(content, choice, "origin", "mcs_scholar")
	Opening.toggle(content, choice, "origin", "mcs_soul")
	check(Opening.selected(choice, "origin").size() == 2, "soul and a family coexist")
	check(not Opening.pick_block(content, choice, "origin", "mcs_merchant").is_empty(), "two families conflict")
	Opening.toggle(content, choice, "body", "mcs_reborn")
	Opening.toggle(content, choice, "body", "mcs_dao_body")
	Opening.toggle(content, choice, "child", "mcs_memory")
	check(Opening.left(content, choice) == 0 and Opening.block(content, choice).is_empty(), "forty-point high-comprehension build has a finite budget")
	check(not Opening.pick_block(content, choice, "body", "mcs_blocked_meridians").is_empty(), "cultivation conflict")
	check(not Opening.pick_block(content, choice, "child", "mcs_impaired").is_empty(), "memory conflict")
	check(not Opening.pick_block(content, choice, "body", "hundun").is_empty(), "legacy jackpot cannot be bought")
	var bad := choice.duplicate(true)
	bad.picks.body.append("mcs_reborn")
	check(not Opening.block(content, bad).is_empty(), "duplicate talent rejected at final validation")
	bad = choice.duplicate(true)
	bad.picks.body.append("mcs_blocked_meridians")
	check(not Opening.block(content, bad).is_empty(), "forged conflicting pick rejected")
	bad = choice.duplicate(true)
	bad.picks.child = ["hundun"]
	check(not Opening.block(content, bad).is_empty(), "forged legacy pick rejected")
	bad = choice.duplicate(true)
	bad.root_count = 2
	bad.roots = ["metal", "metal"]
	check(not Opening.block(content, bad).is_empty(), "duplicate roots rejected")
	bad = choice.duplicate(true)
	bad.picks.unknown = []
	check(not Opening.block(content, bad).is_empty(), "unknown page rejected")
	var base := Session.new()
	base.new_game("基准", 7, ["metal"], "free")
	game.new_game("高悟性", 7, ["metal"], "free", Opening.born(content, choice))
	check(game.comprehension() == 80, "20 base + 10 family + 20 memory + 30 reborn")
	check(game.study_days({"study_days": 100, "element": "none"}) == 25, "comprehension speeds learning without free instant skills")
	check(game.study_days({"study_days": 1, "element": "none"}) == 1, "learning always costs at least one day")
	check(is_equal_approx(game.cultivation_speed() / base.cultivation_speed(), 1.1), "best learning build only adds ten percent cultivation on the same roots")
	check(game.player.xp == 0 and game.player.realm == 0 and game.player.stage == 0, "gifted characters still begin at the first stage")
	check(game.player.max_hp == base.player.max_hp and game.bonuses().attack == base.bonuses().attack and game.bonuses().element_damage.is_empty(), "expensive talent does not gift health or damage")
	check(game.talent_modifier("breakthrough") == 0 and game.talent_modifier("grade") == 0, "no free breakthrough odds or quality")
	check(game.aptitude() == base.aptitude(), "cosmetic rarity no longer secretly raises aptitude")
	check(game.sense() == base.sense() + 3, "soul gives three fixed sense")
	for realm: int in range(5):
		base.player.realm = realm
		game.player.realm = realm
		check(game.Dao.earned(game) - base.Dao.earned(base) == realm, "reborn dao bonus requires major progression %d" % realm)
		check(game.sense() == base.sense() + 3, "flat sense does not explode with realm %d" % realm)
	check(game.Deifying.opening(game, 50, "metal", "", 0) - base.Deifying.opening(base, 50, "metal", "", 0) == 2, "reborn deity bonus is two points")
	# Save at a legal starting stage; derived values come from IDs, so no new save fields are required.
	game.player.realm = 0
	game.refresh_realm_stats()
	var copy := Session.new()
	check(copy.restore(JSON.parse_string(JSON.stringify(game.snapshot()))), "new build round trips")
	check(copy.comprehension() == 80 and copy.player.talents == game.player.talents, "new talents retain their effects after load")
	game.new_game("旧存档", 7, ["metal"], "free", {"talents": ["xianren_zhuanshi"], "flaws": []})
	check(copy.restore(JSON.parse_string(JSON.stringify(game.snapshot()))), "legacy jackpot save still loads")
	check(copy.talent_modifier("cultivation") == 400 and copy.comprehension() == 20, "legacy talent values unchanged, absent new modifiers default to zero")
	game.new_game("羸弱", 7, ["metal"], "free", {"talents": [], "flaws": ["mcs_frail", "mcs_impaired", "mcs_sick", "mcs_disabled"]})
	base.player.realm = 0
	base.refresh_realm_stats()
	check(game.player.max_hp == base.player.max_hp - 5, "frail loses five starting health")
	check(game.study_days({"study_days": 100, "element": "none"}) == 134, "impaired has a real learning cost")
	check(game.Combat.speed(game) == base.Combat.speed(base) - 3, "disability affects initiative and fleeing")
	check(game.lifespan() == base.lifespan() - 30, "sickness takes thirty years")
	game.player.realm = 1
	base.player.realm = 1
	game.refresh_realm_stats()
	base.refresh_realm_stats()
	check(base.player.max_hp - game.player.max_hp > 5, "frail continues to reduce health growth after breakthrough")
	for entry: Dictionary in content.opening_data.pages:
		for id: String in entry.talents + entry.flaws:
			game.new_game("逐项", 7, ["metal", "water", "wood"], "free", {"talents": [] if Talents.is_flaw(content, id) else [id], "flaws": [id] if Talents.is_flaw(content, id) else []})
			check(game.player.max_hp > 0 and game.comprehension() > 0, "valid live start " + id)
			check(not load("res://scripts/ui/talent_cards.gd").tooltip(content, id).is_empty(), "effect visible " + id)
	print("OPENING: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
