extends SceneTree
## Opponents' move tables and phases, and the four new lingering effects (docs/COMBAT_PLAN.md, part
## one, stage one): a blow wound up one turn lands the next and a guard halves it; 流血 piles up;
## 缠绕 draws fewer and forbids fleeing; 禁疗 cuts healing; 蓄势 makes the next blow harder once;
## helpers strike each turn; a move that comes round every few turns does; a heal waits until hurt;
## phases are entered for good below their share; and a duel mid-move survives a save.
const Session = preload("res://scripts/core/session.gd")
const Combat = preload("res://scripts/core/combat.gd")
var checks := 0
var failures := 0

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: " + message)

func _initialize() -> void:
	create_timer(120.0).timeout.connect(func() -> void: printerr("TIMEOUT: test did not finish (likely a script error)"); quit(1))
	_content()
	_charge()
	_bleed_and_wound()
	_entangle()
	_focus_and_summon()
	_rhythm()
	_phases()
	_saves()
	_hunts()
	_roads()
	_arenas()
	_gear_and_talismans()
	_packs_and_series()
	_feuds()
	_ground_scout_wounds()
	_terms_and_schools()
	_demon_and_tribulation()
	_deadly_and_secrets()
	print("DUEL MOVES: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

## A duel against `enemy_id` with plenty of health, the opponent's next move set to `move_id`.
func _duel(enemy_id: String, move_id: String = "", realm: int = 2) -> Session:
	var game := Session.new()
	game.encounters_enabled = false
	game.new_game("试招", 51, ["metal", "wood", "fire"])
	game.player.realm = realm
	game.refresh_realm_stats()
	game.player.hp = game.player.max_hp
	game.Combat.begin_battle(game, enemy_id, "event")
	if not move_id.is_empty():
		_set_move(game, move_id)
	return game

func _set_move(game: Session, move_id: String) -> void:
	var enemy: Dictionary = game.content.enemies[game.battle.enemy_id]
	game.battle.intent = [Combat._intent(game, enemy, Combat._move(enemy, move_id), false)]

func _content() -> void:
	var game := Session.new()
	check(game.content.error_message.is_empty(), "every move table passes its checks: " + game.content.error_message)
	# Generated people fight by their loadout, 心魔 by the player's own arts, 天劫 by counted bolts.
	var handwritten: Array = game.content.enemies.keys().filter(func(id: String) -> bool: return id != "cultivator" and id != "xin_mo" and not bool(game.content.enemies[id].get("tribulation", false)))
	check(handwritten.all(func(id: String) -> bool: return game.content.enemies[id].has("moves") and game.content.enemies[id].moves.size() >= 2), "every handwritten opponent has two moves or more")
	var broken := Session.new()
	broken.content.enemies.wolf.moves[1].inflict = {"poison": [2, 2]}
	check(broken.content._validate().contains("未知状态"), "an unknown lingering effect is reported")
	broken = Session.new()
	broken.content.enemies.serpent.phases[0].below = 1.5
	check(broken.content._validate().contains("阶段"), "phases out of order are reported")
	var plain := _duel("wolf", "", 0)
	check(plain.battle.intent.size() == 1 and plain.battle.intent[0].has("move"), "a handwritten opponent plans from its table")

func _charge() -> void:
	var game := _duel("wolf", "pounce")
	check(game.battle.intent[0].kind == "charge" and int(game.battle.intent[0].min) == int(round(9 * 1.6)), "the intent shows the blow being wound up and how hard it will land")
	var hp := int(game.player.hp)
	game.end_turn()
	check(int(game.player.hp) == hp, "winding up does no harm this turn (%d → %d)" % [hp, int(game.player.hp)])
	check(game.battle.intent[0].kind == "attack" and game.battle.intent[0].move == "pounce", "and the blow is announced for the next")
	var guarded := _duel("wolf", "pounce")
	guarded.end_turn()
	var plain := _duel("wolf", "pounce")
	plain.end_turn()
	var guard_hp := int(guarded.player.hp)
	var plain_hp := int(plain.player.hp)
	guarded.defend()
	plain.end_turn()
	check(guard_hp - int(guarded.player.hp) < plain_hp - int(plain.player.hp), "守御 against the wound-up blow takes far less of it")

func _bleed_and_wound() -> void:
	var game := _duel("wolf", "rend")
	game.end_turn()
	check(game.battle.player_status.has("bleed") and game.battle.player_status.bleed == [2, 2], "撕咬 leaves 流血, already biting once (%s)" % [game.battle.player_status.get("bleed")])
	_set_move(game, "rend")
	game.end_turn()
	check(int(game.battle.player_status.bleed[0]) == 4, "流血 piles up (%s)" % [game.battle.player_status.bleed])
	var cursed := _duel("mo_xiu", "curse")
	cursed.end_turn()
	check(cursed.battle.player_status.has("wound"), "蚀骨咒 leaves 禁疗")
	check(Combat._healed(cursed.battle.player_status, 40) == 20, "禁疗 halves healing")

func _entangle() -> void:
	var game := _duel("serpent", "coil", 1)
	game.end_turn()
	check(game.battle.player_status.has("entangle"), "缠身 coils the player")
	var held := int(game.battle.orbs.size())
	check(game.flee().contains("脱身不得") and not game.battle.is_empty(), "coiled, the player cannot flee")

func _focus_and_summon() -> void:
	var game := _duel("den_wolf", "shadow", 0)
	game.end_turn()
	check(game.battle.status.has("focus"), "隐入暗处 gathers 蓄势")
	_set_move(game, "bite")
	game.end_turn()
	check(not game.battle.status.has("focus"), "and the next blow spends it")
	var general := _duel("mo_jiang", "horde")
	general.end_turn()
	check(general.battle.status.has("minions") and int(general.battle.status.minions[0]) == 20, "召魔卒 brings helpers")
	_set_move(general, "blade")
	var hp := int(general.player.hp)
	general.end_turn()
	check(general.combat_events.any(func(event: Dictionary) -> bool: return str(event.get("name", "")).contains("帮手")), "the helpers strike in the next turn")
	check(not Combat._move_open(general, general.content.enemies.mo_jiang, Combat._move(general.content.enemies.mo_jiang, "horde")), "no new helpers while the last still fight")

func _rhythm() -> void:
	var game := _duel("jian_kui", "rust")
	game.battle.turn = 2
	game.end_turn()
	check(int(game.battle.turn) == 3 and game.battle.intent[0].move == "array" and int(game.battle.intent[0].hits) == 3, "剑阵连斩 comes round on the third turn")
	var remnant := _duel("can_nian")
	var revive: Dictionary = Combat._move(remnant.content.enemies.can_nian, "revive")
	check(not Combat._move_open(remnant, remnant.content.enemies.can_nian, revive), "残念回生 waits while the remnant is whole")
	remnant.battle.hp = 200
	check(Combat._move_open(remnant, remnant.content.enemies.can_nian, revive), "and is open once it is hurt")

func _phases() -> void:
	var game := _duel("serpent", "tail", 1)
	var calm: int = int(game.battle.intent[0].max)
	game.battle.hp = 60
	Combat._plan_move(game)
	check(int(game.battle.get("phase", 0)) == 1 and game.journal_lines().back().contains("毒雾"), "below three tenths the serpent rages, and it is told")
	_set_move(game, "tail")
	check(int(game.battle.intent[0].max) > calm, "raging, its blows land harder")
	var moves: Array = Combat._moves(game, game.content.enemies.serpent).map(func(move: Dictionary) -> String: return str(move.id))
	check("miasma" in moves, "and 毒雾 joins its moves")
	game.battle.hp = 200
	Combat._plan_move(game)
	check(int(game.battle.phase) == 1, "a phase once entered stays")

## 历练 (part two, B1): days in the wilds, then a beast the realm can face; beasts leave parts that
## have uses: 蛇胆 a cold 药引, 妖丹 修为 at the price of 丹毒.
func _hunts() -> void:
	var game := Session.new()
	game.encounters_enabled = false
	game.new_game("历练", 52, ["metal", "wood", "fire"])
	game.player.location = "wild"
	check(game.available_here("hunt"), "the valley's mouth can be hunted")
	var met := {}
	for trip: int in 12:
		var day := int(game.world.day)
		game.act("hunt")
		if game.battle.is_empty():
			continue
		check(int(game.world.day) == day + 2, "a hunt takes two days before the beast is met")
		met[str(game.battle.enemy_id)] = true
		game.battle.hp = 1
		game.Combat._win(game)
		game.player.hp = game.player.max_hp
	check(not met.has("chilian_snake") and met.size() >= 2, "a 炼气 disciple meets the valley's lesser beasts, never the 赤练妖蛇 (%s)" % [met.keys()])
	var strong := Session.new()
	strong.encounters_enabled = false
	strong.new_game("历练", 53, ["metal", "wood", "fire"])
	strong.player.realm = 1
	strong.refresh_realm_stats()
	strong.player.location = "wild"
	for beast: Dictionary in strong.content.enemies.values():
		for part: Dictionary in beast.get("parts", []):
			part.chance = 1.0
	strong.Combat.begin_battle(strong, "chilian_snake", "event")
	strong.battle.hp = 1
	strong.Combat._win(strong)
	check(strong.item_count("snake_gall") >= 1 and strong.item_count("yaodan") == 1 and strong.journal_lines().any(func(line: String) -> bool: return line.contains("蛇胆")), "a fallen 赤练妖蛇 leaves its gall and its 妖丹")
	check(strong.content.item("snake_gall").category == "herb" and strong.Alchemy.nature(strong, "snake_gall") == "cold", "蛇胆 serves the furnace as a cold 药引")
	var xp := int(strong.player.xp)
	var toxin: int = strong.Alchemy.toxin(strong)
	strong.use_item("yaodan")
	check(int(strong.player.xp) == xp + 500 and strong.Alchemy.toxin(strong) > toxin, "refining a 妖丹 brings 修为 and 丹毒")
	check(not strong.commission_offers("sect").is_empty(), "the boards still post")

## Road encounters (part two, B2): 水匪 on the river, a traveller pursued, 魔修探子 and 血煞教徒; each
## can be fought, paid or slipped at a cost, and the 传送阵 is never waylaid.
func _roads() -> void:
	var game := Session.new()
	game.encounters_enabled = false
	game.new_game("行路", 54, ["metal", "wood", "fire"])
	game.player.realm = 1
	game.refresh_realm_stats()
	game.player.hp = game.player.max_hp
	game.player.stones = 100
	for event_id: String in ["river_pirates", "pursued_traveller", "demon_scout", "blood_cult"]:
		check(game.content.events.has(event_id) and game.content.events[event_id].trigger == "route", event_id + " waylays travellers")
	game.Events.start(game, "river_pirates")
	game.choose_event("pay")
	check(int(game.player.stones) == 80 and game.battle.is_empty(), "paying the 水匪 costs twenty stones and no fight")
	game.Events.start(game, "river_pirates")
	var hp := int(game.player.hp)
	game.choose_event("wade")
	check(int(game.player.hp) == hp - 15 and game.battle.is_empty(), "wading round them costs health")
	game.Events.start(game, "river_pirates")
	game.choose_event("fight")
	check(game.battle.get("enemy_id", "") == "shui_fei", "or they are fought")
	game.battle.clear()
	var mind := int(game.player.mind)
	game.Events.start(game, "pursued_traveller")
	game.choose_event("save")
	check(game.battle.get("enemy_id", "") == "zhui_bing" and int(game.player.mind) >= mind + 4, "standing up for the pursued brings their pursuer, and tempers the mind (%s, %d → %d)" % [game.battle.get("enemy_id", ""), mind, int(game.player.mind)])
	game.battle.clear()
	var gate := Session.new()
	gate.encounters_enabled = true
	gate.new_game("传送", 55, ["metal", "wood", "fire"])
	gate.player.realm = 1
	gate.refresh_realm_stats()
	gate.player.stones = 200
	gate.world.flags["tiannan_known"] = true
	gate.player.location = "market"
	gate.content.rules.encounter_chance = [1.0, 1.0, 1.0, 1.0]
	gate.travel("nanming")
	check(gate.player.location == "nanming" and gate.pending_event.is_empty() and gate.battle.is_empty(), "nothing waylays the 传送阵")

## 擂台 (part two, B3): 演武坪's 连胜榜 and 赤枫岭's 斗法台; challengers are local people, each no weaker
## than the last and never the same twice; the purse grows with the streak, some streaks bring a prize;
## a loss, fleeing or stepping down ends the run without penalty, and the best streak is kept.
func _arenas() -> void:
	var game := Session.new()
	game.encounters_enabled = false
	game.new_game("打擂", 56, ["metal", "wood", "fire"])
	game.player.location = "sect"
	check(game.available_here("arena") and game.Arena.block(game).is_empty(), "the 演武坪 keeps a 连胜榜")
	var stones := int(game.player.stones)
	var strengths: Array[int] = []
	for bout: int in 3:
		game.arena_fight()
		check(game.battle.get("context", "") == "arena" and str(game.life_by_id(str(game.battle.npc)).kind) == "disciple", "a fellow outer disciple comes up (bout %d)" % (bout + 1))
		strengths.append(int(game.person(str(game.battle.npc)).realm) * 10 + int(game.person(str(game.battle.npc)).stage))
		game.battle.hp = 1
		game.Combat._win(game)
	check(int(game.Arena.run(game).streak) == 3 and game.Arena.run(game).fought.size() == 3 and strengths[1] >= strengths[0] and strengths[2] >= strengths[1], "three in a row, none met twice, each no weaker (%s)" % [strengths])
	check(int(game.player.stones) == stones + 6 + 12 + 18 + 40, "the purse grows with the streak, and the third win brings its prize")
	game.arena_fight()
	game.flee()
	check(game.Arena.run(game).is_empty() and game.battle.is_empty() and game.Arena.best(game) == 3, "stepping off mid-bout concedes it; the best streak is kept")
	game.arena_fight()
	game.battle.hp = 1
	game.Combat._win(game)
	var kept := Session.new()
	check(kept.restore(JSON.parse_string(JSON.stringify(game.snapshot()))) and int(kept.Arena.run(kept).streak) == 1 and kept.Arena.best(kept) == 3, "a run and the best streak survive a save")
	game.arena_leave()
	check(game.Arena.run(game).is_empty() and game.journal_lines().back().contains("下了擂台"), "stepping down keeps what was won")
	var south := Session.new()
	south.encounters_enabled = false
	south.new_game("打擂", 57, ["metal", "wood", "fire"])
	south.player.realm = 1
	south.refresh_realm_stats()
	south.player.stones = 100
	south.world.flags["tiannan_known"] = true
	south.player.location = "chifeng"
	south.arena_fight()
	var kinds: Array = south.content.locations.chifeng.arena.kinds
	check(int(south.player.stones) == 80 and str(south.life_by_id(str(south.battle.npc)).kind) in kinds, "赤枫岭's 斗法台 takes twenty stones and sends up 天南's own")
	south.battle.hp = 0
	south.Combat._lose(south)
	check(south.Arena.run(south).is_empty() and int(south.player.hp) >= 1, "a loss ends the run, nothing more")

## Part one, stage two: 祭出 the worn 兵刃 (once, twice from 法宝; not two realms short), 符箓 counted apart
## from pills, and fleeing by the odds (a 遁地符 always gets away, even coiled).
func _gear_and_talismans() -> void:
	var game := _duel("wolf", "bite", 0)
	check(game.Combat.release_of(game).is_empty(), "no 兵刃, nothing to release")
	var sword := game.Arsenal.equipment_id("sword", 2, "fire", [], 0)
	game.battle.clear()
	game.add_item(sword, 1)
	game.equip_item(sword)
	game.Combat.begin_battle(game, "wolf", "event")
	var release: Dictionary = game.Combat.release_of(game)
	check(int(release.left) == 1 and int(release.damage) > 20, "a 法器 sword can be released once (%d)" % int(release.damage))
	var hp := int(game.battle.hp)
	game.Combat.release(game)
	check(int(game.battle.hp) < hp and int(game.Combat.release_of(game).left) == 0 and not game.Combat.release_block(game).is_empty(), "it strikes without taking the turn, and only once")
	var saber_game := _duel("wolf", "bite", 3)
	var treasure := saber_game.Arsenal.equipment_id("saber", 4, "none", [], 0)
	saber_game.battle.clear()
	saber_game.add_item(treasure, 1)
	saber_game.equip_item(treasure)
	saber_game.Combat.begin_battle(saber_game, "wolf", "event")
	check(int(saber_game.Combat.release_of(saber_game).left) == 2, "a 法宝 can be released twice")
	saber_game.Combat.release(saber_game)
	check(saber_game.battle.is_empty() or saber_game.battle.status.has("sunder"), "刀芒 leaves 破甲")
	var low := _duel("wolf", "bite", 0)
	var far := low.Arsenal.equipment_id("sword", 4, "none", [], 0)
	low.player.equipment.weapon = far
	check(not bool(low.Combat.release_of(low).usable), "a 法宝 two realms above cannot be released")
	# 符箓
	var charm := _duel("wolf", "bite", 0)
	for talisman: String in ["lei_fu", "jinguang_fu", "dingshen_fu", "dundi_fu"]:
		check(charm.content.item(talisman).category == "talisman", talisman + " is a 符箓")
		charm.set_item_count(talisman, 2)
	charm.battle.hp = 200
	charm.take_duel_pill("lei_fu")
	check(int(charm.battle.hp) == 160 and int(charm.battle.get("pills", 0)) == 0 and int(charm.battle.talismans) == 1, "a 雷符 strikes forty, counted apart from pills")
	charm.take_duel_pill("jinguang_fu")
	check(int(charm.battle.shield) >= 35, "a 金光符 shields")
	charm.take_duel_pill("dingshen_fu")
	check(charm.battle.status.has("entangle"), "a 定身符 binds the foe")
	check(not charm.duel_pill_block("lei_fu").is_empty(), "three 符箓 a duel at most")
	var coiled := _duel("serpent", "coil", 1)
	coiled.end_turn()
	coiled.set_item_count("dundi_fu", 1)
	check(coiled.flee().contains("脱身不得") and not coiled.battle.is_empty(), "coiled, no fleeing on foot")
	coiled.take_duel_pill("dundi_fu")
	check(coiled.battle.is_empty(), "but a 遁地符 always gets away")
	# 遁逃 by the odds.
	var strong := _duel("wolf", "bite", 1)
	check(is_equal_approx(strong.Combat.flee_chance(strong), 1.0), "from a lesser foe one always gets away")
	var weak := _duel("mo_jiang", "blade", 1)
	check(weak.Combat.flee_chance(weak) < 0.6, "from a foe a realm above, the odds fall (%.2f)" % weak.Combat.flee_chance(weak))
	var tries := 0
	while not weak.battle.is_empty() and tries < 10:
		tries += 1
		weak.player.hp = weak.player.max_hp
		weak.flee()
	check(tries > 1 or weak.battle.is_empty(), "fleeing may fail, and then the foe takes its turn")
	var hurt := _duel("wolf", "bite", 0)
	var fresh: float = hurt.Combat.flee_chance(hurt)
	hurt.player.hp = 1
	check(hurt.Combat.flee_chance(hurt) < fresh, "badly hurt, getting away is harder")
	# Gear of its own (part one, stage two): 护心甲 halves one heavy blow, 照影镜 turns half an art back,
	# a bell's 铃音 breaks a wound-up blow; the pieces say so.
	var guarded := _duel("wolf", "bite", 1)
	var vest := guarded.Arsenal.equipment_id("vest", 1, "none", [], 0)
	var mirror := guarded.Arsenal.equipment_id("mirror", 1, "water", [], 0)
	check(guarded.content.equipment(vest).description.contains("护心") and guarded.content.equipment(mirror).description.contains("反照") and guarded.content.equipment(guarded.Arsenal.equipment_id("bell", 1, "none", [], 0)).description.contains("祭出"), "a piece's description names what it does in a duel")
	guarded.player.equipment.robe = vest
	guarded.player.equipment.accessory = mirror
	guarded.player.hp = guarded.player.max_hp
	var heavy := int(guarded.player.max_hp) / 2
	var before := int(guarded.player.hp)
	Combat._hurt_player(guarded, heavy, 1.0, false, {"style": "enemy"})
	check(before - int(guarded.player.hp) == heavy - int(round(heavy * 0.5)), "护心 halves the first heavy blow (%d of %d)" % [before - int(guarded.player.hp), heavy])
	before = int(guarded.player.hp)
	Combat._hurt_player(guarded, 20, 1.0, false, {"style": "enemy"})
	check(before - int(guarded.player.hp) == 20, "only once a duel")
	var foe_before := int(guarded.battle.hp)
	before = int(guarded.player.hp)
	Combat._hurt_player(guarded, 20, 1.0, false, {"style": "enemy", "wound_up": true})
	check(before - int(guarded.player.hp) == 10 and foe_before - int(guarded.battle.hp) == 10, "反照 turns half a wound-up blow back")
	before = int(guarded.player.hp)
	Combat._hurt_player(guarded, 20, 1.0, false, {"style": "fire_burst", "spent": []})
	check(before - int(guarded.player.hp) == 20, "and only once")
	var rung := _duel("wolf", "", 1)
	var bell := rung.Arsenal.equipment_id("bell", 1, "none", [], 0)
	rung.player.equipment.weapon = bell
	var wolf: Dictionary = rung.content.enemies.wolf
	rung.battle.intent = [Combat._intent(rung, wolf, Combat._move(wolf, "pounce"), true)]
	check(bool(rung.battle.intent[0].landing), "a wound-up blow is marked as landing")
	rung.battle.hp = 500
	rung.Combat.release(rung)
	check(str(rung.battle.intent[0].kind) == "stunned", "the bell's 铃音 breaks it")
	before = int(rung.player.hp)
	rung.end_turn()
	check(int(rung.player.hp) == before or rung.battle.is_empty(), "and it lands as nothing")
	var kept := Session.new()
	guarded.battle.intent[0]["landing"] = true
	check(kept.restore(JSON.parse_string(JSON.stringify(guarded.snapshot()))) and kept.battle.traits_used.size() == 2, "spent gear effects survive a save")

## 群敌 (part one, stage five) and 成串的战斗 (part two, B4): a pack strikes beside its lead, the player
## picks a target, 连击 sweeps the rest, the next steps up when the lead falls and the spoils of all are
## paid at the end; 兽潮守镇 comes in its window, three waves to 铁背熊王; 护送 ends at its destination.
func _packs_and_series() -> void:
	var game := _duel("wolf", "bite", 1)
	game.Combat.add_pack(game, ["wolf", "wolf"])
	var joined := int(round(float(game.content.enemies.wolf.hp) * Combat.PACK_HP))
	check(game.battle.pack.size() == 2 and int(game.battle.target) == 0 and int(game.battle.pack[0].hp) == joined, "two more wolves join the fight, lighter than the lead")
	var before := int(game.player.hp)
	game.battle.intent = [{"kind": "guard", "move": "bite", "name": "伏低", "amount": 0}]
	game.end_turn()
	check(int(game.player.hp) < before, "the pack strikes even when the lead holds back")
	game.set_target(2)
	var lead_hp := int(game.battle.hp)
	game.Combat._strike_foe(game, 5)
	check(int(game.battle.hp) == lead_hp and int(game.battle.pack[1].hp) == joined - 5, "the chosen target takes the blow")
	game.Combat._strike_foe(game, 999)
	check(game.battle.pack.size() == 1 and game.battle.felled == ["wolf"] and int(game.battle.target) == 0, "a fallen pack wolf leaves the fight; the aim returns to the lead")
	game.Combat._sweep(game, 7)
	check(int(game.battle.pack[0].hp) == joined - 7, "a 连击 catches the others")
	var kept := Session.new()
	check(kept.restore(JSON.parse_string(JSON.stringify(game.snapshot()))) and kept.battle.pack.size() == 1 and kept.battle.pack[0].hp is int, "a pack survives a save")
	game.battle.hp = 0
	var text: String = game.Combat._win(game)
	check(not game.battle.is_empty() and game.battle.pack.is_empty() and int(game.battle.hp) == joined - 7 and text.contains("顶了上来"), "the lead falls; the last wolf steps up")
	var stones := int(game.player.stones)
	game.battle.hp = 0
	game.Combat._win(game)
	check(game.battle.is_empty() and int(game.player.stones) >= stones + 3 * int(game.content.enemies.wolf.reward_stones), "the spoils of all three are paid (%d)" % (int(game.player.stones) - stones))
	# A lead felled by bleeding at the turn's start hands over without acting.
	var bled := _duel("wolf", "bite", 1)
	bled.Combat.add_pack(bled, ["wolf"])
	bled.battle.hp = 1
	bled.battle.status.bleed = [5, 2]
	bled.end_turn()
	check(not bled.battle.is_empty() and bled.battle.pack.is_empty() and int(bled.battle.turn) == 2, "bled out, the lead gives way and the turn goes on")
	# 兽潮守镇.
	var town := Session.new()
	town.encounters_enabled = false
	town.new_game("守镇", 58, ["metal", "wood", "fire"])
	town.player.realm = 1
	town.refresh_realm_stats()
	town.player.location = "town"
	var tide_window: Dictionary = town.Events.next_window(town.content.events.beast_tide, 0)
	town.world.day = int(tide_window.from)
	check(town.Series.block(town, "beast_tide").contains("需达到"), "筑基初期 is not yet up to the tide")
	town.player.stage = 1
	town.refresh_realm_stats()
	town.world.day = 0
	check(not town.Series.block(town, "beast_tide").is_empty(), "no beast tide out of season")
	var tide: Dictionary = town.content.events.beast_tide
	town.world.day = int(town.Events.next_window(tide, 0).from)
	check(town.Series.block(town, "beast_tide").is_empty(), "in its window the town asks for help")
	town.take_series("beast_tide")
	check(str(town.battle.enemy_id) == "wolf_pack" and town.battle.pack.size() == 1 and str(town.battle.series) == "beast_tide", "the first wave: the wolves")
	var day := int(town.world.day)
	var waves: Array[String] = []
	for wave: int in 3:
		waves.append(str(town.battle.enemy_id))
		while not town.battle.is_empty() and str(town.battle.get("series", "")) == "beast_tide" and town.player.has("series") and int(town.player.series.wave) == wave:
			town.battle.hp = 0
			town.Combat._win(town)
	check(waves == ["wolf_pack", "qinglin_snake", "bear_king"], "three waves to 铁背熊王 (%s)" % [waves])
	check(not town.player.has("series") and town.battle.is_empty() and town.item_count("xiong_dan") >= 1 and town.journal_lines().any(func(line: String) -> bool: return line.contains("兽潮退回")), "the tide is turned and paid for; 熊王 leaves its 熊胆")
	check(not town.Series.block(town, "beast_tide").is_empty(), "once a window")
	# The town's plea on arrival: only one up to it may stay.
	var plea := Session.new()
	plea.encounters_enabled = false
	plea.new_game("守镇", 61, ["metal", "wood", "fire"])
	plea.player.realm = 1
	plea.refresh_realm_stats()
	plea.world.day = int(plea.Events.next_window(plea.content.events.beast_tide, 0).from)
	plea.player.location = "ridge"
	plea.travel("town")
	var offered: Array = plea.pending_definition().get("choices", []).filter(func(choice: Dictionary) -> bool: return plea.Events.all_met(plea, choice.get("conditions", []))).map(func(choice: Dictionary) -> String: return str(choice.id))
	check(plea.pending_event.get("id", "") == "beast_tide" and not "defend" in offered and "unready" in offered, "筑基初期 hears the plea but cannot stay to defend (%s)" % [offered])
	# 护送: two ambushes, then the road's days and the far end.
	var escort := Session.new()
	escort.encounters_enabled = false
	escort.new_game("护送", 59, ["metal", "wood", "fire"])
	escort.player.location = "town"
	check(escort.Series.block(escort, "escort_qingshi").contains("需达到"), "炼气初期 is not trusted with a caravan")
	escort.player.stage = 2
	escort.refresh_realm_stats()
	escort.take_series("escort_qingshi")
	check(escort.battle.get("pack", []).is_empty() and str(escort.battle.enemy_id) == "rogue", "the first ambush: a lone 劫修")
	var start := int(escort.world.day)
	escort.player.hp = 1
	escort.battle.hp = 0
	escort.Combat._win(escort)
	check(escort.player.has("series") and int(escort.player.hp) > 1 and int(escort.world.day) == start and escort.battle.pack.size() == 1, "a breath, and the second ambush, two of them, at once")
	var mid := Session.new()
	check(mid.restore(JSON.parse_string(JSON.stringify(escort.snapshot()))) and int(mid.player.series.wave) == 1, "a series under way survives a save")
	escort.battle.pack.clear()
	escort.battle.hp = 0
	escort.Combat._win(escort)
	check(str(escort.player.location) == "market" and int(escort.world.day) >= start + 5 and not escort.player.has("series"), "the caravan reaches 云溪坊市 after the road's days")
	escort.player.location = "town"
	check(not escort.Series.block(escort, "escort_qingshi").is_empty(), "no new caravan until the cooldown is over")
	var lost := Session.new()
	lost.encounters_enabled = false
	lost.new_game("护送", 60, ["metal", "wood", "fire"])
	lost.player.location = "town"
	lost.player.stage = 2
	lost.take_series("escort_qingshi")
	lost.player.hp = 0
	lost.Combat._lose(lost)
	check(not lost.player.has("series") and lost.journal_lines().any(func(line: String) -> bool: return line.contains("没能撑到最后")), "a lost ambush ends the escort")

## 恩怨找上门 (B5) and 悬赏猎杀 (B6), feuds.gd: a beaten road foe's comrade remembers, the teahouse
## whispers, and once ripe they waylay the player on a road of their region (fight, pay or slip away);
## exposing 袁赤锋 sets 赤霄门 on the player once they can face it. Outlaws are posted by name, found
## where they hide (some framed), and paid for at the board.
func _feuds() -> void:
	var game := _duel("rogue", "", 1)
	game.content.feuds.grudge_chance = 1.0
	game.player.location = "town"
	game.battle.hp = 0
	game.Combat._win(game)
	check(str(game.pending_event.get("id", "")) == "victory_terms", "a beaten road outlaw awaits the player's verdict")
	game.choose_event("search")
	check(game.world.grudges.size() == 1 and str(game.world.grudges[0].enemy) == "rogue" and str(game.world.grudges[0].region) == "qingyun", "a beaten 劫修's comrade remembers")
	var foe: String = str(game.world.grudges[0].name)
	check(foe.begins_with("「") and game.journal_lines().any(func(line: String) -> bool: return line.contains(foe + "记下了")), "by name (%s)" % foe)
	check(game.Events.met(game, {"grudge": true}), "the teahouse may whisper of it")
	var road: Dictionary = game.content.route_between("sect", "town")
	game.content.feuds.ambush_chance = 1.0
	check(not game.Feuds.ambush(game, road), "not before it ripens")
	game.world.day = int(game.world.day) + 21
	check(not game.Feuds.ambush(game, game.content.route_between("nanming", "chifeng")), "not on a road of another region")
	check(game.Feuds.ambush(game, road) and str(game.pending_event.id) == "grudge_ambush" and str(game.pending_event.values.foe) == foe, "once ripe, on a road of its region, they waylay the player")
	var kept := Session.new()
	check(kept.restore(JSON.parse_string(JSON.stringify(game.snapshot()))) and kept.world.grudges.size() == 1 and str(kept.pending_event.values.foe) == foe, "the grudge and the ambush survive a save")
	var stones := int(game.player.stones)
	game.player.stones = stones + 100
	game.choose_event("pay")
	check(game.world.grudges.is_empty() and int(game.player.stones) == stones + 100 - game.Feuds.pay(game) and game.journal_lines().slice(-3).any(func(line: String) -> bool: return line.contains(foe) and line.contains("交出 %d 灵石" % game.Feuds.pay(game))), "paying it off settles it, in the avenger's name")
	# Slipping away, then fighting it out.
	game.Feuds._add(game, {"name": "「独眼」韩青", "enemy": "zhui_bing", "cause": "comrade", "region": "qingyun"})
	game.world.day = int(game.world.day) + 21
	game.Feuds.ambush(game, road)
	game.choose_event("slip")
	check(game.world.grudges.size() == 1 and int(game.world.grudges[0].since) == int(game.world.day), "slipping away only puts it off")
	game.world.day = int(game.world.day) + 21
	game.Feuds.ambush(game, road)
	game.choose_event("fight")
	check(str(game.battle.get("title", "")) == "「独眼」韩青" and str(game.battle.enemy_id) == "zhui_bing", "the avenger fights under their own name")
	game.battle.hp = 0
	game.Combat._win(game)
	check(game.world.grudges.is_empty() and game.journal_lines().any(func(line: String) -> bool: return line.contains("了结")), "beaten, the account is closed")
	# 袁赤锋 exposed: 赤霄门 sends its enforcer once the player can face a 金丹.
	game.world.flags["bounty_exposed"] = true
	game.Feuds.update(game)
	game.Feuds.update(game)
	check(game.world.grudges.size() == 1 and str(game.world.grudges[0].enemy) == "chixiao_zhifa", "exposing 袁赤锋 sets 赤霄门 against the player, once")
	game.world.day = int(game.world.day) + 21
	check(not game.Feuds.ambush(game, game.content.route_between("nanming", "chifeng")), "not while the player is short of 金丹")
	game.player.realm = 2
	check(game.Feuds.ambush(game, game.content.route_between("nanming", "chifeng")), "then on 天南's roads")
	game.pending_event = {}
	# 悬赏.
	var hunter := Session.new()
	hunter.encounters_enabled = false
	hunter.new_game("悬赏", 62, ["metal", "wood", "fire"])
	hunter.player.location = "market"
	var posted: Dictionary = {}
	for period: int in 60:
		hunter.world.day = period * int(hunter.content.commission_data.period_days)
		for offer: Dictionary in hunter.Commissions.offers(hunter, "market"):
			if offer.has("wanted"):
				posted = offer
				break
		if not posted.is_empty():
			break
	check(not posted.is_empty() and hunter.content.region_of(str(posted.wanted.place)) == "qingyun" and int(hunter.content.enemies[str(posted.wanted.enemy)].min_realm) == 0, "the market posts an outlaw of its region a 炼气 can take")
	check(hunter.Commissions.text(hunter, posted).title.contains(str(posted.wanted.name)), "by name")
	hunter.accept_commission(str(posted.key))
	var quest: Dictionary = hunter.player.quests.back()
	quest.wanted.twist = false
	check(not hunter.delivery_block(quest).is_empty(), "nothing to claim before they are taken")
	hunter.player.location = str(quest.wanted.place)
	hunter.Events.check_location(hunter)
	check(str(hunter.pending_event.get("id", "")) == "bounty_found" and str(hunter.pending_event.values.foe) == str(quest.wanted.name), "stopping where they hide finds them")
	hunter.choose_event("wait")
	hunter.Events.check_location(hunter)
	check(hunter.pending_event.is_empty(), "held back, they are left alone a while")
	hunter.world.day = int(quest.wanted.wait_until)
	hunter.Events.check_location(hunter)
	hunter.choose_event("fight")
	check(str(hunter.battle.get("wanted", "")) == str(quest.key) and str(hunter.battle.title) == str(quest.wanted.name), "taking them on")
	hunter.battle.hp = 0
	hunter.Combat._win(hunter)
	check(int(quest.progress) == 1 and hunter.journal_lines().any(func(line: String) -> bool: return line.contains("拿下了通缉犯")), "taken, the bounty waits at the board")
	hunter.player.location = "market"
	var purse := int(hunter.player.stones)
	hunter.deliver_commission(str(quest.key))
	check(int(hunter.player.stones) == purse + int(quest.reward.stones) and hunter.player.quests.is_empty(), "and is paid there")
	var framed := Session.new()
	framed.encounters_enabled = false
	framed.new_game("悬赏", 62, ["metal", "wood", "fire"])
	framed.player.location = "market"
	framed.world.day = int(posted.key.get_slice(":", 1)) * int(framed.content.commission_data.period_days)
	framed.accept_commission(str(posted.key))
	var lie: Dictionary = framed.player.quests.back()
	lie.wanted.twist = true
	framed.player.location = str(lie.wanted.place)
	var mind := int(framed.player.mind)
	framed.Events.check_location(framed)
	check(str(framed.pending_event.get("id", "")) == "bounty_twist", "sometimes the poster lied")
	framed.choose_event("spare")
	check(framed.player.quests.is_empty() and int(framed.player.mind) >= mind, "letting the framed one go drops the bounty")

## Part one, stage three: the ground favours some elements (and a sect's people on its own ground),
## 神识 above the foe's sees its make-up, and fights leave 外伤 (and a defeat 内伤) to be treated.
func _ground_scout_wounds() -> void:
	var game := _duel("wolf", "bite", 1)
	game.battle.place = "ferry"
	check(is_equal_approx(Combat.ground(game, "water", false), 1.15) and is_equal_approx(Combat.ground(game, "fire", true), 0.9) and Combat.ground_text(game).contains("临水"), "by the river water arts gain and fire arts lose, both sides alike")
	game.battle.cave = "dihuo"
	check(is_equal_approx(Combat.ground(game, "fire", false), 1.2) and Combat.ground_text(game).contains("地火"), "in the 熔窟 the 地火 rules")
	game.battle.erase("cave")
	game.battle.place = "sect"
	game.Loadout.take_lineage(game, "qingyun")
	check(is_equal_approx(Combat.ground(game, "metal", false), 1.1) and Combat.ground_text(game).contains("本门地界"), "on one's own sect's ground one strikes harder")
	var guest := _duel("yue_disciple", "", 1)
	guest.battle.place = "xuanyue_gate"
	check(is_equal_approx(Combat.ground(guest, "earth", true), 1.25) and Combat.ground_text(guest).contains("玄岳宗地界"), "and a sect's people on theirs (the mountain's earth too)")
	var wolf_here := _duel("wolf", "bite", 1)
	wolf_here.battle.place = "sect"
	check(is_equal_approx(Combat.ground(wolf_here, "metal", true), 1.0), "a beast has no sect ground")
	# The ground's favour lands in the blow: a fire sword released in 赤枫岭 against at home.
	var dealt: Array[int] = []
	for place: String in ["town", "chifeng"]:
		var thrower := _duel("wolf", "bite", 1)
		var sword := thrower.Arsenal.equipment_id("sword", 2, "fire", [], 0)
		thrower.player.equipment.weapon = sword
		thrower.battle.place = place
		thrower.battle.hp = 500
		thrower.Combat.release(thrower)
		dealt.append(500 - int(thrower.battle.hp))
	check(dealt[1] > dealt[0], "the fire blade bites deeper among the red maples (%s)" % [dealt])
	# 神识探查.
	var keen := _duel("wolf_pack", "", 1)
	var look: Dictionary = keen.Combat.scout(keen)
	check(bool(look.seen) and "
".join(look.lines).contains("招式") and "
".join(look.lines).contains("群扑") and "
".join(look.lines).contains("妖狼牙"), "神识 above a wolf pack's sees its moves and what it carries")
	var dull := _duel("mo_jiang", "", 1)
	var veiled: Dictionary = dull.Combat.scout(dull)
	check(not bool(veiled.seen) and veiled.lines.size() == 1 and str(veiled.lines[0]).contains("神识不及"), "below a 魔将's, only its rough cultivation")
	# 伤势.
	var beaten := _duel("wolf", "bite", 1)
	var day := int(beaten.world.day)
	beaten.player.hp = 0
	beaten.Combat._lose(beaten)
	check(beaten.Combat.wounded(beaten) and beaten.injured(), "a defeat leaves 外伤 and 内伤")
	beaten.player.hp = beaten.player.max_hp
	beaten.Combat.begin_battle(beaten, "wolf", "event")
	check(int(beaten.player.hp) <= int(round(float(beaten.player.max_hp) * 0.75)), "wounded, one starts a fight short of health")
	var kept := Session.new()
	check(kept.restore(JSON.parse_string(JSON.stringify(beaten.snapshot()))) and kept.Combat.wounded(kept), "a wound survives a save")
	beaten.battle.clear()
	beaten.set_item_count("liaoshang_pill", 1)
	beaten.use_item("liaoshang_pill")
	check(not beaten.Combat.wounded(beaten) and beaten.injured(), "a 疗伤丹 treats the 外伤; the 内伤 only time heals")
	var narrow := _duel("wolf", "bite", 1)
	narrow.player.hp = 1
	narrow.battle.hp = 0
	narrow.Combat._win(narrow)
	check(narrow.Combat.wounded(narrow) and not narrow.injured(), "a narrow win leaves 外伤 only")
	narrow.player.location = "town"
	narrow.player.stones = 100
	narrow.act("inn_rest")
	check(not narrow.Combat.wounded(narrow), "a night at the inn treats it")

## 收尾抉择 (part one, stage three) and 流派 (stage four, schools.gd).
func _terms_and_schools() -> void:
	# Let go: no grudge, the mind eased.
	var mercy := _duel("zhui_bing", "", 1)
	mercy.content.feuds.grudge_chance = 1.0
	var mind := int(mercy.player.mind)
	mercy.battle.hp = 0
	mercy.Combat._win(mercy)
	mercy.choose_event("release")
	check(mercy.world.grudges.is_empty() and int(mercy.player.mind) >= mind and mercy.journal_lines().any(func(line: String) -> bool: return line.contains("改邪归正")), "letting the outlaw go leaves no grudge")
	# Searched: half their purse again.
	var frisk := _duel("rogue", "", 1)
	frisk.content.feuds.grudge_chance = 0.0
	frisk.battle.hp = 0
	frisk.Combat._win(frisk)
	var stones := int(frisk.player.stones)
	frisk.choose_event("search")
	check(int(frisk.player.stones) == stones + int(frisk.content.enemies.rogue.reward_stones) / 2 and frisk.journal_lines().any(func(line: String) -> bool: return line.contains("身上搜出")), "searching them finds half their purse again")
	# Pressed: a hoard waits at a place of the region.
	var squeeze := _duel("rogue", "", 1)
	squeeze.content.feuds.grudge_chance = 0.0
	squeeze.player.location = "town"
	squeeze.battle.hp = 0
	squeeze.Combat._win(squeeze)
	squeeze.choose_event("press")
	check(squeeze.world.stashes.size() == 1 and squeeze.content.region_of(str(squeeze.world.stashes[0].place)) == "qingyun", "pressing them gives up their gang's hoard")
	var kept := Session.new()
	check(kept.restore(JSON.parse_string(JSON.stringify(squeeze.snapshot()))) and kept.world.stashes.size() == 1, "a confessed hoard survives a save")
	var hoard: Dictionary = squeeze.world.stashes[0]
	stones = int(squeeze.player.stones)
	squeeze.player.location = str(hoard.place)
	squeeze.Events.check_location(squeeze)
	check(squeeze.world.stashes.is_empty() and int(squeeze.player.stones) == stones + int(hoard.stones), "and stopping there takes it")
	var named := _duel("rogue", "", 1)
	named.battle.npc = "rogue"
	named.battle.hp = 0
	named.Combat._win(named)
	check(str(named.pending_event.get("id", "")) != "victory_terms", "a named person's fate is their story's")
	var beast := _duel("wolf", "bite", 1)
	beast.battle.hp = 0
	beast.Combat._win(beast)
	check(beast.pending_event.is_empty(), "a beast is simply beaten")
	# 流派.
	var sword := _duel("wolf", "", 1)
	var affinity := sword.Arsenal.technique_id("affinity", "metal", 2, [], 0)
	sword.player.methods = [affinity]
	check(sword.Schools.player(sword) == "sword" and sword.content.technique(affinity).description.contains("剑意"), "a metal 元气 心法 of 黄阶 makes a 剑修, and says so")
	var low := sword.Arsenal.technique_id("affinity", "metal", 1, [], 0)
	sword.player.methods = [low]
	check(sword.Schools.player(sword).is_empty(), "not from a 凡阶 one")
	sword.player.methods = [affinity]
	var first := Combat._school_force(sword, "metal")
	var second := Combat._school_force(sword, "metal")
	var third := Combat._school_force(sword, "metal")
	check(is_equal_approx(first, 1.0) and is_equal_approx(second, 1.15) and is_equal_approx(third, 1.3), "剑意 grows with each metal art of the turn (%.2f %.2f %.2f)" % [first, second, third])
	sword.end_turn()
	check(sword.battle.is_empty() or not sword.battle.has("sword_streak"), "and fades with the turn")
	var body := _duel("wolf", "bite", 1)
	body.player.methods = [body.Arsenal.technique_id("body", "earth", 2, [], 0)]
	check(body.Schools.player(body) == "body", "a 炼体 心法 makes a 体修")
	Combat._hurt_player(body, int(body.player.max_hp) / 5, 1.0, false, {"style": "enemy"})
	check(bool(body.battle.get("body_ready", false)) and is_equal_approx(Combat._school_force(body, "fire"), 1.25) and not body.battle.has("body_ready"), "a heavy blow taken readies 反震, once")
	body.battle.enemy_id = "wolf"
	var overcome := ""
	for element: String in body.content.technique_data.elements:
		if str(body.Combat.rules(body).overcomes.get("metal", "")) == element:
			overcome = element
	check(is_equal_approx(Combat.counter_multiplier(body, overcome), 0.9), "being overcome costs a 体修 less")
	var soul := _duel("wolf", "bite", 1)
	soul.player.methods = [soul.Arsenal.technique_id("focus", "water", 2, [], 0)]
	soul.battle.orbs = ["metal", "metal", "wood", "wood", "fire", "fire", "water", "earth"]
	var art: String = soul.active_skills()[0]
	soul.use_skill(art)
	check(soul.battle.is_empty() or soul.battle.status.has("weaken"), "魂修 shakes a beast's next blow")
	var array := _duel("wolf", "bite", 1)
	array.player.methods = [array.Arsenal.technique_id("breath", "earth", 2, [], 0)]
	check(array.Schools.player(array) == "array" and array.Combat.array_block(array).is_empty(), "an earth 吐纳 心法 makes a 阵修")
	array.player.hp = array.player.max_hp
	array.Combat.lay_array(array)
	check(array.battle.is_empty() or (bool(array.battle.array) and int(array.battle.shield) >= 8 and not array.Combat.array_block(array).is_empty()), "布阵 takes a turn, then shields every turn")
	var foe_school := _duel("wolf", "bite", 1)
	var people: Array = foe_school.living_people().filter(func(id: String) -> bool: return foe_school.is_generated(id))
	var schooled := 0
	for person_id: String in people:
		if not str(foe_school.Population.foe(foe_school.content, person_id, foe_school.person(person_id)).get("school", "")).is_empty():
			schooled += 1
	check(schooled > 0, "some of the world's people fight by a school too (%d of %d)" % [schooled, people.size()])

## B7: 心魔 as a duel against the player's own arts, and 天劫 as rounds of lightning before the 金丹.
func _ready_to_found(seed_value: int, mind: int) -> Session:
	var game := Session.new()
	game.encounters_enabled = false
	game.new_game("渡劫", seed_value, ["metal", "wood", "fire"])
	game.player.stage = 3
	game.player.xp = 2000
	game.player.mind = mind
	game.refresh_realm_stats()
	game.set_item_count("foundation_pill", 1)
	game.player.hp = game.player.max_hp
	return game

func _demon_and_tribulation() -> void:
	var game := _ready_to_found(63, 0)
	game.fortune = {"demon": 0.0, "breakthrough": 0.0}
	game.act("breakthrough")
	check(str(game.pending_event.get("id", "")) == "heart_demon" and game.pending_definition().choices.any(func(choice: Dictionary) -> bool: return choice.id == "duel"), "心魔 may be met in a duel")
	game.choose_event("duel")
	check(str(game.battle.get("context", "")) == "demon" and str(game.battle.foe.name) == "心魔" and game.battle.foe.arts == game.active_skills() and int(game.battle.hp) == int(round(float(game.player.max_hp) * float(game.content.rules.breakthrough.demon.hp_share))) and game.player.has("attempt"), "it takes the player's own arts, with more health than they have")
	var kept := Session.new()
	check(kept.restore(JSON.parse_string(JSON.stringify(game.snapshot()))) and str(kept.battle.context) == "demon" and kept.player.has("attempt"), "a 心魔 duel survives a save")
	game.battle.hp = 0
	game.Combat._win(game)
	check(game.battle.is_empty() and int(game.player.realm) == 1 and game.journal_lines().any(func(line: String) -> bool: return line.contains("心魔")), "slain, the breakthrough goes on (筑基 has no 天劫)")
	var lost := _ready_to_found(64, 0)
	lost.fortune = {"demon": 0.0, "breakthrough": 0.0}
	lost.act("breakthrough")
	var odds := int(lost.player.attempt.odds)
	lost.choose_event("duel")
	lost.player.hp = 0
	lost.Combat._lose(lost)
	check(lost.battle.is_empty() and not lost.player.has("attempt") and int(lost.player.hp) >= 1, "lost to 心魔, the attempt still goes on, weaker (from %d)" % odds)
	var fled := _ready_to_found(65, 0)
	fled.fortune = {"demon": 0.0, "breakthrough": 0.0}
	fled.act("breakthrough")
	fled.choose_event("duel")
	fled.flee()
	check(fled.battle.is_empty() and fled.journal_lines().any(func(line: String) -> bool: return line.contains("避开心魔")), "turning from it is evading it")
	# 天劫 before the 金丹.
	var core := Session.new()
	core.encounters_enabled = false
	core.new_game("渡劫", 66, ["metal", "wood", "fire"])
	core.player.realm = 1
	core.player.stage = 3
	core.player.xp = 6000
	core.player.mind = 200
	core.refresh_realm_stats()
	core.player.hp = core.player.max_hp
	core.fortune = {"demon": 0.99, "breakthrough": 0.0, "grade": 0.5}
	core.act("breakthrough")
	check(str(core.battle.get("context", "")) == "tribulation" and str(core.battle.enemy_id) == "tribulation_core" and int(core.battle.hp) == 3 and int(core.player.realm) == 1 and core.player.has("tribulation"), "the 金丹 waits on 三九雷劫: three bolts")
	check(core.flee().contains("无处可逃") and not core.battle.is_empty(), "there is no fleeing it")
	check(str(core.battle.intent[0].name) == "第 1 道天雷", "the bolts are counted")
	core.battle.orbs = ["metal", "metal", "metal", "wood", "wood", "fire", "fire", "fire"]
	var hp := int(core.battle.hp)
	for art_id: String in core.active_skills():
		if str(core.content.technique(art_id).kind) == "attack":
			core.use_skill(art_id)
			break
	check(int(core.battle.hp) == hp and int(core.battle.get("dispel", 0)) > 0, "an attack art disperses the coming bolt instead")
	var saved := Session.new()
	check(saved.restore(JSON.parse_string(JSON.stringify(core.snapshot()))) and str(saved.battle.context) == "tribulation" and saved.player.has("tribulation"), "a 天劫 under way survives a save")
	var bolts := 0
	while not core.battle.is_empty() and bolts < 6:
		bolts += 1
		core.player.hp = core.player.max_hp
		core.defend()
	check(bolts == 3 and int(core.player.realm) == 2 and int(core.player.core_grade) >= 0 and core.journal_lines().any(func(line: String) -> bool: return line.contains("渡过了天劫")), "three bolts weathered, the core is formed (%d)" % bolts)
	var struck := Session.new()
	struck.encounters_enabled = false
	struck.new_game("渡劫", 67, ["metal", "wood", "fire"])
	struck.player.realm = 1
	struck.player.stage = 3
	struck.player.xp = 6000
	struck.player.mind = 200
	struck.refresh_realm_stats()
	struck.fortune = {"demon": 0.99, "breakthrough": 0.0}
	struck.act("breakthrough")
	struck.player.hp = 1
	struck.defend()
	check(struck.battle.is_empty() and int(struck.player.realm) == 1 and int(struck.player.injury_until) - int(struck.world.day) == 2 * int(struck.content.rules.breakthrough.failure.injury_days), "struck down, the attempt fails with twice the injury")

## Part one, stage five: 禁忌秘术 (a burst for lifespan, an injury or a 妖丹, costs kept for good) and
## 死斗 (marked before it begins; lost, the life ends).
func _deadly_and_secrets() -> void:
	var low := _duel("wolf", "bite", 0)
	check(low.Combat.secret_block(low, "burn_blood").contains("筑基"), "秘术 wait for 筑基")
	var game := _duel("wolf", "bite", 1)
	var years := game.lifespan()
	game.Combat.use_secret(game, "burn_blood")
	check(game.lifespan() == years - 3 and game.battle.player_status.has("fervor") and not game.Combat.secret_block(game, "burn_blood").is_empty(), "燃血 burns three years for a burst, once a duel")
	var kept := Session.new()
	check(kept.restore(JSON.parse_string(JSON.stringify(game.snapshot()))) and kept.lifespan() == years - 3 and "burn_blood" in kept.battle.secrets, "the years stay burned through a save")
	game.end_turn()
	check(game.battle.is_empty() or int(game.battle.player_status.get("fervor", [0, 0])[1]) == 2, "the burst wanes turn by turn")
	var torn := _duel("wolf", "bite", 1)
	var orbs := int(torn.battle.orbs.size())
	torn.Combat.use_secret(torn, "shatter")
	check(torn.battle.orbs.size() >= orbs + 1 and torn.injured() and torn.Combat.wounded(torn), "解体 tears the body for qi at once")
	var offered := _duel("wolf", "bite", 1)
	check(not offered.Combat.secret_block(offered, "offer_core").is_empty(), "祭丹 needs a 妖丹")
	offered.set_item_count("yaodan_small", 1)
	offered.player.hp = 10
	offered.Combat.use_secret(offered, "offer_core")
	check(offered.item_count("yaodan_small") == 0 and int(offered.player.hp) > 10 and int(offered.battle.shield) >= 30, "and gives it up for health and a shield")
	var bout := _duel("wolf", "bite", 1)
	bout.battle.context = "spar"
	check(not bout.Combat.secret_block(bout, "burn_blood").is_empty(), "no 秘术 in a bout among fellows")
	# 死斗.
	var doomed := _duel("xuesha_tu", "", 1)
	doomed.battle.deadly = true
	doomed.player.hp = 0
	doomed.Combat._lose(doomed)
	check(str(doomed.ended.get("kind", "")) == "fallen" and doomed.journal_lines().back().contains("陨落"), "a 死斗 lost ends the life")
	var after := Session.new()
	check(after.restore(JSON.parse_string(JSON.stringify(doomed.snapshot()))) and str(after.ended.kind) == "fallen", "and the fall is kept in a save")
	var rescued := _duel("xuesha_tu", "", 1)
	rescued.player.hp = 0
	rescued.Combat._lose(rescued)
	check(rescued.ended.is_empty(), "an unmarked defeat is still survived")
	var road := _duel("wolf", "bite", 1)
	road.battle.clear()
	Session.Events.apply(road, [{"battle": "xuesha_tu"}, {"deadly": true}])
	check(bool(road.battle.get("deadly", false)), "the 血煞截杀 fight is marked a 死斗")
	var avenged := _duel("wolf", "bite", 1)
	avenged.battle.clear()
	avenged.Feuds._add(avenged, {"name": "「黑风」林照", "enemy": "rogue", "cause": "comrade", "region": "qingyun"})
	avenged.pending_event = {"id": "grudge_ambush", "day": int(avenged.world.day), "values": {"grudge": str(avenged.world.grudges[0].id), "foe": "「黑风」林照"}}
	avenged.Feuds.fight(avenged)
	check(bool(avenged.battle.get("deadly", false)) and avenged.content.events.grudge_ambush.choices[0].label.contains("死斗"), "仇杀 is a 死斗, and its choice says so")

func _saves() -> void:
	var game := _duel("wolf", "pounce")
	game.end_turn()
	var kept := Session.new()
	check(kept.restore(JSON.parse_string(JSON.stringify(game.snapshot()))) and kept.battle.intent[0].move == "pounce" and kept.battle.intent[0].kind == "attack", "a duel with a blow announced survives a save")
	var broken: Dictionary = game.snapshot()
	broken.battle.charged = "dragon_breath"
	check(not Session.new().restore(JSON.parse_string(JSON.stringify(broken))), "a wound-up move the opponent does not know is refused")
