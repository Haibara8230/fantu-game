extends SceneTree
## Talents: six tiers and flaws drawn at birth, the modifiers they bring to the rules, 资质, the generated
## population's talents and what they shape, who can see them, and how they survive a save (older
## journeys awaken theirs from the seed). And the breakthrough they bear on: its odds part by part,
## failure, the foundation's grade, 心魔, guards and treasures.
const Session = preload("res://scripts/core/session.gd")
const Talents = preload("res://scripts/core/talents.gd")
const Calendar = preload("res://scripts/core/calendar.gd")
var checks := 0
var failures := 0

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: " + message)

func _initialize() -> void:
	# A script error aborts this function before quit(); the watchdog turns that hang into a failure.
	create_timer(240.0).timeout.connect(func() -> void: printerr("TIMEOUT: test did not finish (likely a script error)"); quit(1))
	_content()
	_rolls()
	_modifiers()
	_aptitude()
	_people()
	_saves()
	_breakthrough()
	_grades_and_demons()
	_breakthrough_saves()
	print("TALENTS: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

func _game(born: Dictionary = {}, roots: Array = ["metal", "wood", "fire"], seed_value: int = 31) -> Session:
	var game := Session.new()
	game.encounters_enabled = false
	game.new_game("天赋", seed_value, roots, "plain", born)
	return game

func _born(ids: Array) -> Dictionary:
	var content = Session.new().content
	return {"talents": ids.filter(func(id: String) -> bool: return not Talents.is_flaw(content, id)), "flaws": ids.filter(func(id: String) -> bool: return Talents.is_flaw(content, id))}

func _content() -> void:
	var content = Session.new().content
	check(content.error_message.is_empty(), "the talents load and pass their checks: " + content.error_message)
	var counts := {}
	for id: String in content.talent_data.talents:
		var talent: Dictionary = content.talent_data.talents[id]
		if not talent.get("gained", false):
			counts[talent.tier] = int(counts.get(talent.tier, 0)) + 1
	check(counts == {"white": 90, "green": 75, "blue": 60, "purple": 40, "orange": 20, "red": 10}, "talents in six tiers, white to red: %s" % counts)
	var flaws: Array = content.talent_data.flaws.keys().filter(func(id: String) -> bool: return not content.talent_data.flaws[id].get("gained", false))
	check(flaws.size() == 40, "forty flaws to be born with")
	var tiers: Array = content.talent_data.tiers.map(func(tier: Dictionary) -> String: return tier.name)
	check(tiers == ["寻常", "不凡", "出众", "稀世", "绝世", "天命"], "the tiers are named")
	var gained: Array = content.talent_data.talents.keys().filter(func(id: String) -> bool: return content.talent_data.talents[id].get("gained", false))
	check(gained.has("qianbei_yize") and content.talent_data.flaws.canhun_raoshen.gained, "fortune has talents (and a flaw) of its own to bestow")

## Tallies `draws` births from a table: {"people", "tiers" {tier: people whose best talent it is},
## "none", "flawed", "clashes"}.
func _tally(content, table: String, draws: int, seed_value: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var order: Array = content.talent_data.tiers.map(func(tier: Dictionary) -> String: return tier.id)
	var result := {"tiers": {}, "none": 0, "flawed": 0, "clashes": 0, "most": 0}
	for i: int in draws:
		var born := Talents.roll(content, rng, table)
		var groups := {}
		var best := -1
		for id: String in born.talents + born.flaws:
			var group := str(Talents.definition(content, id).get("group", "#" + id))
			result.clashes += 1 if groups.has(group) or Talents.definition(content, id).get("gained", false) else 0
			groups[group] = true
		for id: String in born.talents:
			best = maxi(best, order.find(str(Talents.tier_of(content, id).id)))
		if best < 0:
			result.none += 1
		else:
			result.tiers[order[best]] = int(result.tiers.get(order[best], 0)) + 1
		result.flawed += born.flaws.size()
		result.most = maxi(result.most, born.talents.size())
		result.clashes += 100 if born.flaws.size() > 1 else 0
	return result

func _rolls() -> void:
	var content = Session.new().content
	var local := _tally(content, "qingyun", 20000, 7)
	var tiers: Dictionary = local.tiers
	check(local.clashes == 0 and local.most <= 3, "never two of a kind, never fortune's own, at most one flaw: %d clashes, %d most" % [local.clashes, local.most])
	check(local.none > 9000 and int(tiers.get("white", 0)) > 7000, "around 青云山 most people have no talent or a white one: %s, none %d" % [tiers, local.none])
	check(int(tiers.get("green", 0)) > 600 and int(tiers.get("green", 0)) < 1600, "a green talent makes a small prodigy, one in twenty or so")
	check(int(tiers.get("blue", 0)) > 20 and int(tiers.get("blue", 0)) < 160, "a blue one is the region's finest, a few in a thousand")
	check(not tiers.has("purple") and not tiers.has("orange") and not tiers.has("red"), "nobody there is born with purple or above")
	check(local.flawed > 3400 and local.flawed < 4600, "about one in five is born with a flaw")
	var hero := _tally(content, "player", 20000, 11)
	var high := int(hero.tiers.get("purple", 0)) + int(hero.tiers.get("orange", 0)) + int(hero.tiers.get("red", 0))
	check(high > 20 and high < 300 and int(hero.tiers.get("red", 0)) < 15, "the protagonist alone may be born with more, very rarely: %s" % hero.tiers)
	var abroad := _tally(content, "default", 20000, 13)
	check(not abroad.tiers.has("red") and int(abroad.tiers.get("orange", 0)) < 20, "elsewhere an orange talent is all but unheard of, and nobody but the protagonist is born red")
	var data: Dictionary = content.talent_data.talents
	check(int(data.qinmian.mods.cultivation) == 5 and int(data.zhuanzhu.mods.cultivation) == 15 and int(data.qicai.mods.cultivation) == 84 and int(data.xianren_zhuanshi.mods.cultivation) == 400, "the gap between tiers is glaring")
	check(hero.none > 4500 and hero.none < 7500, "and is often born with nothing at all")
	var session := Session.new()
	var a := RandomNumberGenerator.new()
	a.seed = 99
	var b := RandomNumberGenerator.new()
	b.seed = 99
	check(session.roll_talents(a) == session.roll_talents(b), "the same draw gives the same talents")
	# The generated people of the region follow the local table.
	var game := _game()
	var best := 0
	var order: Array = content.talent_data.tiers.map(func(tier: Dictionary) -> String: return tier.id)
	for seat: int in game._local_seats:
		for life: Dictionary in game.seat_lives(seat, Calendar.to_day(200, 1, 1)):
			for id: String in life.talents:
				best = maxi(best, order.find(str(Talents.tier_of(content, id).id)))
	check(best <= order.find("blue"), "two centuries of the region's people, and none above blue")

func _modifiers() -> void:
	var plain := _game()
	check(plain.player.talents.is_empty() and plain.player.flaws.is_empty() and plain.cultivation_rate() == 60, "a character made without talents follows the plain rules")
	var keen := _game(_born(["zhuanzhu"]))
	check(keen.cultivation_rate() == 69, "专注 cultivates faster")
	var long_lived := _game(_born(["changshou", "tiruo"]))
	check(long_lived.lifespan() == 132 and long_lived.player.max_hp == 76 and long_lived.player.hp == 76, "长寿相 adds years; 体弱多病 takes health")
	var rich := _game(_born(["fujia"]))
	check(int(rich.player.stones) == 270, "富家子弟 sets out with more silver")
	var pills := _game(_born(["danti"]))
	pills.set_item_count("ningqi_pill", 1)
	pills.use_item("ningqi_pill")
	check(int(pills.player.xp) == 250, "丹体 draws far more from a pill")
	var friendly := _game(_born(["qinhe"]))
	Session.Events.apply(friendly, [{"relation": ["boatman", 10]}, {"relation": ["peddler", -10]}])
	check(friendly.favor("boatman") == 13 and friendly.favor("peddler") == -10, "亲和 gains more favor and loses no less")
	var calm := _game(_born(["jingxin"]))
	calm.gain_mind(4)
	check(int(calm.player.mind) == 6, "静心 turns more experience into mind")
	var reader := _game(_born(["bowen"]))
	check(reader.study_days({"study_days": 10}) == 7, "博闻强记 studies faster")
	var walker := _game(_born(["shenxing"]))
	check(walker.route_days({"days": 4}) == 3 and walker.path_days(walker.path_to("ridge")) == 3, "神行 shortens the road")
	walker.travel("ridge")
	check(int(walker.world.day) == 3, "and the journey takes those days")
	var trader := _game(_born(["shangdao"]))
	trader.player.location = "market"
	var price := 0
	for good: Dictionary in trader.shop_goods():
		if good.item == "foundation_pill":
			price = int(good.price)
	check(price == 91 and trader.sell_price("huichun_grass") == 5, "商道天成 buys cheaper and sells dearer")
	var sturdy := _game(_born(["kunyuan"]))
	check(sturdy.player.max_hp == 117 and is_equal_approx(sturdy.defense(), 0.3) and is_equal_approx(sturdy.element_multiplier({"element": "earth"}), 1.75), "坤元土体 hardens the body and the earth arts")
	var hermit := _game(_born(["kuzuo"]))
	check(hermit.retreat_cap() == 153 and hermit.mind_needed() == 0, "枯坐如石 can stay in retreat longer")
	var settled := _game(_born(["chengming"]))
	settled.player.stage = 1
	check(settled.mind_needed() == 5, "道心澄明 lowers the mind a stage asks")
	var seeker := _game(_born(["congming"]))
	seeker.gain_insight("spar")
	check(int(seeker.player.insight) == 13, "聪慧 draws more insight from a spar")
	var gifted := _game()
	var text := gifted.gain_talent("qianbei_yize")
	check(gifted.has_talent("qianbei_yize") and text.contains("前辈遗泽") and gifted.cultivation_rate() == 74, "fortune can bestow a talent later")
	check(gifted.gain_talent("qianbei_yize").is_empty(), "the same talent is not given twice")
	var frail := _game(_born(["tijian"]))
	check(frail.gain_talent("tiruo").is_empty() and not frail.has_talent("tiruo"), "nor one that clashes with what one has")
	Session.Events.apply(gifted, [{"talent": "canhun_raoshen"}])
	check(gifted.has_talent("canhun_raoshen") and "canhun_raoshen" in gifted.player.flaws, "an effect can leave a flaw too")
	check(Session.Events.met(gifted, {"talent": "qianbei_yize"}) and not Session.Events.met(gifted, {"talent": "zhuanzhu"}), "conditions can ask for a talent")

func _aptitude() -> void:
	var content = Session.new().content
	check(_game().aptitude().name == "中等", "three roots and no talents: 中等")
	check(_game({}, ["metal", "wood", "water", "fire", "earth"]).aptitude().name == "下等", "a five-element root: 下等")
	check(_game({}, ["fire"]).aptitude().name == "绝佳", "a heavenly root alone: 绝佳")
	check(_game(_born(["lingqiao"])).aptitude().name == "上等", "three roots and a blue talent: 上等")
	check(_game(_born(["lansan"])).aptitude().name == "下等", "a flaw lowers the aptitude")
	check(_game(_born(["xianren_zhuanshi"]), ["fire"]).aptitude().name == "天纵", "a heavenly root and a red talent: 天纵")
	check(Talents.aptitude(content, 100).name == "天纵" and Talents.aptitude(content, -10).name == "下等", "the grades hold at the ends")

func _people() -> void:
	var game := _game()
	var someone := ""
	var gifted := 0
	for person_id: String in game.living_people():
		if game.is_generated(person_id) and not game.talents_of(person_id).talents.is_empty():
			gifted += 1
			someone = person_id
	var born: Dictionary = game.talents_of(someone)
	check(gifted > 5 and born.talents.size() <= 3 and born.talents.all(func(id: String) -> bool: return game.content.is_talent(id)), "some generated people are born with talents")
	var again := _game()
	check(again.talents_of(someone) == born, "and the same world gives them the same ones")
	var parts := someone.split(":")
	var shaped := Session.Population.next_life(game.content, int(game.world.seed), int(parts[1]), {}, true)
	var kept := Session.Population.next_life(game.content, int(game.world.seed), int(parts[1]), {}, false)
	check(shaped.name == kept.name and shaped.kind == kept.kind and shaped.talents == kept.talents, "talents are drawn apart from the rest of a life")
	var changed := 0
	for seat: int in game._local_seats.slice(0, 60):
		var a := Session.Population.next_life(game.content, int(game.world.seed), seat, {}, true)
		var b := Session.Population.next_life(game.content, int(game.world.seed), seat, {}, false)
		changed += 1 if a.speed != b.speed or a.death != b.death or a.foundation_age != b.foundation_age else 0
	check(changed > 10, "in a world begun with talents they shape people's lives")
	check(bool(game.world.talent_lives), "a new world is shaped by talents")
	var foe_plain := Session.Population.foe(game.content, "x", {"name": "甲", "realm": 0, "stage": 1, "loadout": game.person(someone).loadout, "sect": "qingyun", "gender": "male"})
	var foe_strong := Session.Population.foe(game.content, "x", {"name": "甲", "realm": 0, "stage": 1, "loadout": game.person(someone).loadout, "sect": "qingyun", "gender": "male", "talents": ["jingang", "shafa"]})
	check(int(foe_strong.hp) > int(foe_plain.hp) and int(foe_strong.damage_max) > int(foe_plain.damage_max), "talents make a sparring partner tougher")
	# Seeing through people.
	var higher := ""
	for person_id: String in game.living_people():
		if game.is_generated(person_id) and int(game.person(person_id).realm) * 10 + int(game.person(person_id).stage) > 0:
			higher = person_id
			break
	check(not higher.is_empty() and not game.talents_visible(higher), "a stranger above you keeps their talents hidden")
	Session.Events.apply(game, [{"relation": [higher, 40]}])
	check(game.talents_visible(higher), "an acquaintance's talents show")
	check(not game.talents_visible("shen_mo"), "a key person shows theirs only to those they know")
	var shen: Dictionary = game.talents_of("shen_mo")
	check(shen.talents == ["danshi", "wenxiang", "jinshen"] and shen.flaws == ["duoyi"], "a key person's talents are written, flaws apart")
	check(game.person_aptitude(higher).has("name") and game.person_aptitude("gu_changgeng").has("name"), "anyone's aptitude can be judged")

func _saves() -> void:
	var game := _game(_born(["zhuanzhu", "changshou", "tiruo"]))
	var copy := Session.new()
	check(copy.restore(JSON.parse_string(JSON.stringify(game.snapshot()))) and copy.player.talents == ["zhuanzhu", "changshou"] and copy.player.flaws == ["tiruo"] and copy.player.max_hp == 76, "talents survive a save")
	check(bool(copy.world.talent_lives), "and so does a world shaped by them")
	for broken: Array in [["talents", ["no_such_talent"]], ["talents", ["tiruo"]], ["flaws", ["zhuanzhu"]], ["talents", ["zhuanzhu", "zhuanzhu"]], ["talents", "zhuanzhu"]]:
		var data: Dictionary = game.snapshot()
		data.player[broken[0]] = broken[1]
		check(not copy.restore(data), "malformed %s rejected: %s" % broken)
	var data: Dictionary = game.snapshot()
	data.world.talent_lives = "yes"
	check(not copy.restore(data), "a malformed world flag for talents rejected")
	var v12 := Session.new()
	check(v12.restore(JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/v12_sect_ridge.json"))) and v12.snapshot().version == 13 and v12.player.has("talents") and not bool(v12.world.talent_lives), "a version 12 save migrates and awakens its talents")
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/v11_after_retreats.json"))
	var old := Session.new()
	check(old.restore(fixture.duplicate(true)) and old.snapshot().version == 13, "an older journey migrates to version 13")
	check(old.player.has("talents") and not bool(old.world.talent_lives), "its talents awaken; its people keep the lives they had")
	check(old.journal_lines().back().contains("生来便有"), "and the awakening is written down")
	var twice := Session.new()
	twice.restore(fixture.duplicate(true))
	check(twice.player.talents == old.player.talents and twice.player.flaws == old.player.flaws, "the same journey awakens the same talents")
	var round_trip := Session.new()
	check(round_trip.restore(JSON.parse_string(JSON.stringify(old.snapshot()))) and round_trip.player.talents == old.player.talents and round_trip.chronicle.entries.size() == old.chronicle.entries.size(), "they awaken once, not on every load")

## A character at 炼气圆满 with 2000 xp and the mind the stage asks, ready to break through.
func _ripe(born: Dictionary = {}, pills: int = 1) -> Session:
	var game := _game(born)
	game.player.stage = 3
	game.player.xp = 2000
	game.player.mind = 24
	game.set_item_count("foundation_pill", pills)
	game.refresh_realm_stats()
	return game

func _odds(game: Session, plan: Dictionary = {}) -> int:
	return int(game.breakthrough_odds(plan if not plan.is_empty() else game.breakthrough_plan()).total)

func _part(game: Session, plan: Dictionary, label: String) -> int:
	for part: Array in game.breakthrough_odds(plan).parts:
		if str(part[0]).begins_with(label):
			return int(part[1])
	return 0

func _breakthrough() -> void:
	var game := _ripe({}, 4)
	check(_odds(game) == 60 and _part(game, game.breakthrough_plan(), "资质 · 中等") == 35, "an ordinary aptitude and one pill: 60 in a hundred")
	check(_odds(game, {"pills": 2, "treasure": "", "guard": ""}) == 75 and _odds(game, {"pills": 3, "treasure": "", "guard": ""}) == 85, "each further pill helps less")
	check(not game.breakthrough_block({"pills": 4, "treasure": "", "guard": ""}).is_empty(), "no more than three pills at once")
	check(not game.breakthrough_block({"pills": 0, "treasure": "", "guard": ""}).is_empty(), "nor none, without a treasure")
	game.player.mind = 34
	check(_part(game, game.breakthrough_plan(), "心境盈余") == 5, "a mind beyond the stage's need helps")
	var boned := _ripe(_born(["gengu"]))
	check(_odds(boned) == 62, "a talent for breaking through adds its points")
	var potent := _ripe(_born(["danti"]))
	check(_part(potent, potent.breakthrough_plan(), "筑基丹") == 63, "a talent for pills makes the pill count for more")
	var gifted := _ripe(_born(["xianren_zhuanshi"]), 1)
	check(_odds(gifted) == 95, "the odds never pass 95")
	var heavenly := _game({}, ["fire"])
	check(heavenly.aptitude().name == "绝佳" and int(heavenly.content.rules.breakthrough.base[3]) == 55, "a better aptitude starts from more")
	# A 心法 suited to the roots.
	var suited := _ripe()
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var method := ""
	while method.is_empty():
		var candidate: String = Session.Arsenal.generate_technique(suited.content, rng, 2, {"slot": "method"})
		if suited.content.technique(candidate).element in suited.player.roots:
			method = candidate
	suited.player.learned.append(method)
	suited.player.methods = [method]
	check(_part(suited, suited.breakthrough_plan(), "心法") == 8, "a yellow-tier 心法 suited to the roots adds 5 and 3")
	# A treasure in place of the pills.
	var lucky := _ripe({}, 0)
	lucky.set_item_count("qiannian_shiru", 1)
	var plan := lucky.breakthrough_plan()
	check(plan.treasure == "qiannian_shiru" and lucky.breakthrough_block(plan).is_empty() and _odds(lucky, plan) == 70, "a treasure stands in for the pills")
	check(lucky.breakthrough_odds(plan).steps == ["千年石乳"], "and promises a better foundation")
	# Guards.
	var guarded := _ripe()
	check(guarded.breakthrough_guards().is_empty(), "nobody to stand guard at first")
	guarded.world.storylines["lineage"] = {"state": "done", "step": 4, "since": 0, "begun": false, "base": {}}
	Session.Events.apply(guarded, [{"relation": ["boatman", 140]}])
	check(guarded.breakthrough_guards() == ["gu_changgeng", "boatman"], "the mentor once his teaching is done, and anyone trusted")
	check(_part(guarded, {"pills": 1, "treasure": "", "guard": "gu_changgeng"}, "护法") == 10 and _part(guarded, {"pills": 1, "treasure": "", "guard": "boatman"}, "护法") == 5, "the mentor guards better than a friend")
	check(not guarded.breakthrough_odds({"pills": 1, "treasure": "", "guard": "boatman"}).demon, "a guard keeps 心魔 away")
	guarded.player.mind = 36
	check(not guarded.breakthrough_odds({"pills": 1, "treasure": "", "guard": ""}).demon, "and a mind ready for foundation needs none")
	guarded.player.mind = 10
	check(guarded.breakthrough_odds({"pills": 1, "treasure": "", "guard": ""}).demon, "a short mind unguarded invites it")
	check(not guarded.breakthrough_block({"pills": 1, "treasure": "", "guard": "peddler"}).is_empty(), "a stranger cannot stand guard")
	# Failure.
	var failing := _ripe({}, 2)
	failing.fortune = {"demon": 0.99, "breakthrough": 0.99}
	var day := int(failing.world.day)
	var text := failing.act("breakthrough")
	check(failing.player.realm == 0 and int(failing.player.xp) == 1700 and failing.item_count("foundation_pill") == 1 and text.contains("冲关失败"), "a failure spends the pill and sets xp back")
	check(int(failing.world.day) == day + 90 and failing.injured() and int(failing.player.lessons) == 1 and int(failing.player.mind) == 28 and int(failing.player.hp) > 0, "and costs months of injury, never the life, and teaches")
	var hurt := failing.retreat_preview(30)
	var healed_at := int(failing.player.injury_until)
	failing.player.injury_until = 0
	check(int(hurt.xp) * 2 == int(failing.retreat_preview(30).xp), "an injury halves what a retreat brings")
	failing.player.injury_until = healed_at
	failing.player.xp = 2000
	check(_part(failing, failing.breakthrough_plan(), "前车之鉴") == 5, "the next attempt is a little surer")
	failing.fortune = {"demon": 0.99, "breakthrough": 0.0}
	failing.act("breakthrough")
	check(failing.player.realm == 1 and int(failing.player.lessons) == 0 and not failing.injured(), "success clears the lessons and the injury")

func _grades_and_demons() -> void:
	# The margin under the odds decides the grade.
	for case: Array in [[0.55, "下品", 133], [0.45, "中品", 140], [0.2, "上品", 154]]:
		var game := _ripe()
		game.fortune = {"demon": 0.99, "breakthrough": case[0]}
		game.act("breakthrough")
		check(game.foundation_grade().get("name", "") == case[1] and int(game.player.max_hp) == int(case[2]), "a roll %.2f under 60: %s, health %d" % [case[0], case[1], game.player.max_hp])
	var fine := _ripe()
	fine.fortune = {"demon": 0.99, "breakthrough": 0.2}
	fine.act("breakthrough")
	var plain := _ripe()
	plain.fortune = {"demon": 0.99, "breakthrough": 0.45}
	plain.act("breakthrough")
	check(fine.cultivation_rate() == 66 and plain.cultivation_rate() == 60, "a better foundation cultivates faster")
	var treasured := _ripe({}, 0)
	treasured.set_item_count("jiuqu_lingshen", 1)
	treasured.fortune = {"demon": 0.99, "breakthrough": 0.2}
	treasured.act("breakthrough")
	check(treasured.foundation_grade().get("name", "") == "无瑕" and treasured.item_count("jiuqu_lingshen") == 0, "a treasure lifts a 上品 foundation to 无瑕")
	check(treasured.journal_lines().any(func(line: String) -> bool: return line.contains("根基品质：无瑕")), "the chronicle tells the grade")
	# 心魔.
	var haunted := _ripe()
	haunted.player.mind = 18
	haunted.fortune = {"demon": 0.0, "breakthrough": 0.0}
	var day := int(haunted.world.day)
	haunted.act("breakthrough")
	check(haunted.pending_event.get("id", "") == "heart_demon" and haunted.player.has("attempt") and int(haunted.world.day) == day and haunted.item_count("foundation_pill") == 0, "a mind short of foundation's need meets 心魔 first")
	var copy := Session.new()
	check(copy.restore(JSON.parse_string(JSON.stringify(haunted.snapshot()))) and copy.pending_event.id == "heart_demon" and int(copy.player.attempt.odds) == int(haunted.player.attempt.odds), "an attempt waiting on 心魔 survives a save")
	haunted.choose_event("evade")
	check(haunted.player.realm == 1 and not haunted.player.has("attempt") and int(haunted.world.day) == day + 90, "evading it, the attempt goes on")
	var bold := _ripe()
	bold.player.mind = 18
	bold.fortune = {"demon": 0.0, "breakthrough": 0.45, "slay": 0.0}
	bold.act("breakthrough")
	bold.choose_event("slay")
	check(bold.player.realm == 1 and bold.foundation_grade().get("name", "") == "上品" and int(bold.player.mind) == 26, "slaying it lifts the grade and the mind (6, and 2 for living through it)")
	var shaken := _ripe()
	shaken.player.mind = 18
	shaken.fortune = {"demon": 0.0, "breakthrough": 0.5, "slay": 0.99}
	shaken.act("breakthrough")
	check(int(shaken.player.attempt.odds) == 60, "before the choice the odds stand")
	shaken.choose_event("slay")
	check(shaken.player.realm == 0 and shaken.journal_lines().any(func(line: String) -> bool: return line.contains("未能斩尽")), "failing to slay it costs the attempt dearly")
	var steady := _ripe(_born(["jianding"]))
	steady.player.mind = 10
	steady.fortune = {"demon": 0.0, "breakthrough": 0.0}
	steady.act("breakthrough")
	check(steady.pending_event.is_empty() and steady.player.realm == 1, "a firm 道心 keeps 心魔 away")
	# 残魂灌顶 makes it certain, without pills, at a middling grade.
	var blessed := _ripe({}, 0)
	blessed.player.boons = {"remnant": "ready"}
	blessed.player.mind = 10
	blessed.fortune = {"demon": 0.0, "breakthrough": 0.99}
	check(blessed.breakthrough_block(blessed.breakthrough_plan()).is_empty() and blessed.breakthrough_odds(blessed.breakthrough_plan()).certain, "a remnant's blessing needs no pill")
	blessed.act("breakthrough")
	check(blessed.player.realm == 1 and blessed.foundation_grade().get("name", "") == "中品" and blessed.player.boons.remnant == "spent", "and cannot fail")

func _breakthrough_saves() -> void:
	var old := Session.new()
	check(old.restore(JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/v5_foundation_ridge.json"))) and old.foundation_grade().get("name", "") == "中品", "a foundation from before grades counts as 中品")
	var game := _ripe()
	game.fortune = {"demon": 0.99, "breakthrough": 0.99}
	game.act("breakthrough")
	var copy := Session.new()
	check(copy.restore(JSON.parse_string(JSON.stringify(game.snapshot()))) and copy.injured() and int(copy.player.lessons) == 1, "an injury and a lesson survive a save")
	for broken: Array in [["foundation_grade", 9], ["lessons", 7], ["injury_until", -1], ["boons", {"nonsense": "ready"}], ["boons", {"epiphany": "maybe"}], ["attempt", {"odds": 50, "certain": false, "steps": 0, "xp": 2000, "guard": ""}]]:
		var data: Dictionary = game.snapshot()
		data.player[broken[0]] = broken[1]
		check(not copy.restore(data), "malformed %s rejected" % broken[0])
