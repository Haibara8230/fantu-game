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
	var handwritten: Array = game.content.enemies.keys().filter(func(id: String) -> bool: return id != "cultivator")
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

func _saves() -> void:
	var game := _duel("wolf", "pounce")
	game.end_turn()
	var kept := Session.new()
	check(kept.restore(JSON.parse_string(JSON.stringify(game.snapshot()))) and kept.battle.intent[0].move == "pounce" and kept.battle.intent[0].kind == "attack", "a duel with a blow announced survives a save")
	var broken: Dictionary = game.snapshot()
	broken.battle.charged = "dragon_breath"
	check(not Session.new().restore(JSON.parse_string(JSON.stringify(broken))), "a wound-up move the opponent does not know is refused")
