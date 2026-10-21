extends SceneTree
## 新兵器枪、锤、鞭 (docs/SIDEQUESTS_DRAFT_20261020.md 2.5, step 5): three weapon bases found and forged like
## the others, each with its 祭出 and its own art while worn. 枪: always first, through the shield, 破甲.
## 锤: the shield broken first, the heaviest blow, 震慑 (one orb fewer next turn). 鞭: three lashes, 缠绕
## (fewer orbs, slower, harder to outpace). The art's layers grow with use and survive a save.
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
	# A script error aborts this function before quit(); the watchdog turns that hang into a failure.
	create_timer(120.0).timeout.connect(func() -> void: printerr("TIMEOUT: test did not finish (likely a script error)"); quit(1))
	_data()
	_spear()
	_hammer()
	_whip()
	_held()
	_effects()

## Each new stage effect drawn for a few frames, so a fault in its drawing shows as a script error.
func _effects() -> void:
	var Effect: GDScript = load("res://scripts/presentation/effect.gd")
	var stage := Node2D.new()
	root.add_child(stage)
	for kind: String in ["spear", "hammer", "whip", "pierce_hit", "quake_hit", "lash_hit"]:
		for direction: float in [1.0, -1.0]:
			var effect: Node2D = Effect.new()
			stage.add_child(effect)
			effect.setup(kind, Vector2(400, 300), Vector2(400 + 300 * direction, 300), 0.12, Color("#e8f0ff"))
	for frame: int in 20:
		await process_frame
	check(stage.get_child_count() == 0, "the six effects play out and clear away")
	print("WEAPONS: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

## A player of `realm` wearing a weapon of `base` at `tier`, in a duel with `enemy_id`.
func _armed(base: String, enemy_id: String, realm: int = 1, tier: int = 3) -> Session:
	var game := Session.new()
	game.encounters_enabled = false
	game.new_game("持兵", 53, ["metal", "earth", "wood"])
	game.player.realm = realm
	game.refresh_realm_stats()
	game.player.hp = game.player.max_hp
	if not base.is_empty():
		var piece: String = game.Arsenal.equipment_id(base, tier, "none", [], 0)
		game.add_item(piece, 1)
		game.equip_item(piece)
	if not enemy_id.is_empty():
		game.Combat.begin_battle(game, enemy_id, "event")
		game.battle.orbs = ["metal", "metal", "metal", "earth", "earth", "earth", "wood", "wood", "wood"]
	return game

func _data() -> void:
	var game := Session.new()
	check(game.content.error_message.is_empty(), "the new weapons pass the checks: " + game.content.error_message)
	var bases: Dictionary = game.content.equipment_data.bases
	for base: String in ["spear", "hammer", "whip"]:
		check(bases.has(base) and bases[base].slot == "weapon" and bases[base].has("release") and game.content.skills.has(str(bases[base].art)), "%s: a weapon with its 祭出 and its art" % base)
	var found := {}
	var rng := RandomNumberGenerator.new()
	for seed_value: int in 400:
		rng.seed = seed_value
		found[game.Arsenal.generate_equipment(game.content, rng, 3).get_slice(":", 1)] = true
	check(found.has("spear") and found.has("hammer") and found.has("whip"), "all three turn up among found treasures")
	check("whip" in game.Forge.bases_for(game, "silk_xuancan") and "spear" in game.Forge.bases_for(game, "ore_xuantie"), "a whip forged of silk, a spear or hammer of metal")
	var spear: Dictionary = game.content.equipment(game.Arsenal.equipment_id("spear", 3, "none", [], 0))
	check(spear.name.ends_with("枪") and spear.description.contains("破阵枪") and spear.description.contains("先出手"), "a 玄铁枪 tells its art and that it strikes first")

## 枪: first against a quicker foe; 破阵枪 and 穿云一枪 go through a shield.
func _spear() -> void:
	var bare := _armed("", "jianling_head", 0)
	check(bare.Combat.foe_leads(bare), "a 炼气 bare-handed is outpaced by a 筑基 sword spirit")
	var game := _armed("spear", "jianling_head", 0, 2)
	check(not game.Combat.foe_leads(game), "with a spear the player strikes first")
	check("spear_thrust" in game.active_skills() and game.player.layers.has("spear_thrust"), "破阵枪 is in hand, begun at its first layer")
	game.battle.foe_shield = 40
	var hp := int(game.battle.hp)
	game.use_skill("spear_thrust")
	check(int(game.battle.foe_shield) == 40 and int(game.battle.hp) < hp, "破阵枪 goes past the shield")
	check(int(game.player.layers.spear_thrust.practice) > 0, "and is practised by use")
	hp = int(game.battle.hp)
	game.Combat.release(game)
	check(int(game.battle.foe_shield) == 40 and int(game.battle.hp) < hp and game.battle.status.has("sunder"), "穿云一枪: through the shield, and 破甲")

## 锤: the shield broken first, the heaviest blow; the foe draws one orb fewer next turn.
func _hammer() -> void:
	var game := _armed("hammer", "jianling_head")
	game.battle.foe_shield = 30
	game.use_skill("hammer_smash")
	check(int(game.battle.foe_shield) == 0 and game.battle.status.has("slow"), "撼岳锤 breaks the shield and 震慑")
	var released := _armed("hammer", "jianling_head")
	released.battle.foe_shield = 25
	var hp := int(released.battle.hp)
	released.Combat.release(released)
	check(int(released.battle.foe_shield) == 0 and int(released.battle.hp) < hp and released.battle.status.has("slow"), "开山一锤 too")
	var sword := _armed("sword", "")
	var hammer := _armed("hammer", "")
	sword.Combat.begin_battle(sword, "jianling_head", "event")
	hammer.Combat.begin_battle(hammer, "jianling_head", "event")
	check(int(hammer.Combat.release_of(hammer).damage) > int(sword.Combat.release_of(sword).damage), "a hammer's release lands heavier than a sword's")

## 鞭: three lashes that bind; bound, the foe is slower.
func _whip() -> void:
	var game := _armed("whip", "jianling_head")
	var quick := game.Combat.foe_speed(game)
	game.use_skill("whip_lash")
	check(game.battle.status.has("entangle") and game.Combat.foe_speed(game) < quick, "缠龙鞭 binds the foe and slows it")
	var released := _armed("whip", "jianling_head")
	released.Combat.release(released)
	check(released.battle.status.has("entangle") and released.combat_events.any(func(event: Dictionary) -> bool: return int(event.get("hits", 0)) == 3), "缚灵鞭 lashes three times and binds")

## Only while worn; the art's layer survives a save and taking the weapon off.
func _held() -> void:
	var game := _armed("spear", "")
	game.player.layers.spear_thrust.practice = 7
	game.unequip_slot("weapon")
	check(not "spear_thrust" in game.active_skills(), "taken off, 破阵枪 is gone from hand")
	game.Combat.begin_battle(game, "wolf", "event")
	game.battle.orbs = ["metal", "metal"]
	check(game.use_skill("spear_thrust") == "此神通未在运转。", "and cannot be cast")
	game.battle.clear()
	var copy := Session.new()
	check(copy.restore(JSON.parse_string(JSON.stringify(game.snapshot()))) and int(copy.player.layers.spear_thrust.practice) == 7, "its practice survives a save")
	check(copy.snapshot() == game.snapshot(), "and the journey reads back the same")
