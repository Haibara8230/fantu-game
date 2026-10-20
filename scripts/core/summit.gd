extends RefCounted
## 擂台大会: a run of rounds against other sects' disciples (data/summit.json, one entry per contest).
## 五宗论道 (`wuzong`): every sixty years from 历元 120 the five sects send their best to 青云山
## (events.json five_sects_entry); a cultivator of 金丹 or above may stand for 青云. 天南大比 (`tiannan`):
## every twenty years from 历元 20, hosted by the five cities in turn, for 筑基 cultivators of any
## standing who qualify (events.json tiannan_contest_*). Operates on a Session.
## Each round is fought against one sect's disciple casting their own lineage's arts at their own fixed
## cultivation (`levels`). Between rounds some health and qi come back. Each round won brings stones,
## contribution (for a sect's disciple) and xp; the champion takes a slip and a large reward. A loss
## ends the run without any penalty.
## The duel: battle.context "summit", battle.contest, battle.round, and battle.foe built here (no person
## behind it).

static func data(s, contest: String = "") -> Dictionary:
	if contest.is_empty():
		contest = str(s.battle.get("contest", "wuzong"))
	return s.content.summit_data.get(contest, {})

## The cultivation each round's champion fights at: the contest's own, or its group for the player's
## realm (`groups`: 五宗论道's 元婴组 for a 元婴 or above).
static func levels(s, rules: Dictionary) -> Array:
	var group: Dictionary = {}
	for realm_key: String in rules.get("groups", {}):
		if int(s.player.realm) >= int(realm_key) and (group.is_empty() or int(realm_key) > int(group.realm)):
			group = rules.groups[realm_key].merged({"realm": realm_key})
	return group.get("levels", rules.levels)

## Starts round `round` (from 1) of `contest` against that round's champion.
static func begin(s, round: int, contest: String = "wuzong") -> void:
	var rules := data(s, contest)
	var champion: Dictionary = rules.champions[round - 1]
	var level: Array = levels(s, rules)[round - 1]
	var realm := clampi(int(level[0]), 0, s.content.realms.size() - 1)
	var stage := clampi(int(level[1]), 0, s.content.realm(realm).stages.size() - 1)
	var caps: Dictionary = s.content.stage(realm, stage)
	var power := float(rules.power[round - 1])
	var arts: Array = s.content.sects[str(champion.sect)].skills.duplicate()
	var best: Dictionary = {}
	for art_id: Variant in arts:
		var art: Dictionary = s.content.technique(str(art_id))
		if art.get("kind", "") == "attack" and (best.is_empty() or int(art.damage_max) > int(best.damage_max)):
			best = art
	var bonus := int(caps.attack_bonus)
	var foe := {
		"name": "%s · %s" % [champion.title, champion.name], "hp": int(round(float(caps.max_hp) * power)),
		"damage_min": maxi(1, int(round(float(best.damage_min) * power)) + bonus), "damage_max": maxi(1, int(round(float(best.damage_max) * power)) + bonus),
		"art": str(best.id), "art_name": str(best.name), "vfx": str(best.vfx), "tier": int(best.tier), "xp": int(rules.round.xp),
		"sect": str(champion.sect), "gender": str(champion.gender), "arts": arts, "power": snappedf(power, 0.01), "bonus": bonus,
		"element": str(best.element), "realm": realm,
	}
	s.battle = {"enemy_id": "cultivator", "hp": int(foe.hp), "turn": 1, "cooldowns": {}, "opponent_sect": str(champion.sect), "status": {}, "context": "summit", "contest": contest, "round": round, "foe": foe, "place": s.Combat._battle_place(s)}
	s.combat_events.clear()
	s.Combat.open_hand(s)
	s.log_event("summit_start", {"round": round, "foe": "%s%s" % [champion.title, champion.name], "contest": str(rules.name), "stage": str(champion.get("stage", ""))})

## A round ends: a win leads on (or crowns the player), a loss ends the run.
static func over(s, won: bool) -> String:
	var round := int(s.battle.get("round", 1))
	var contest := str(s.battle.get("contest", "wuzong"))
	var rules := data(s, contest)
	var champion: Dictionary = rules.champions[round - 1]
	var foe_name := "%s%s" % [champion.title, champion.name]
	var args := {"round": round, "foe": foe_name, "contest": str(rules.name)}
	s.battle.clear()
	s.record_deed("duel")
	# The rounds won are the sitting's score (trials.gd).
	s.Trials.record(s, contest, round if won else round - 1)
	if not won:
		s.player.hp = maxi(int(s.player.hp), 1)
		var out: String = s.log_event("summit_out", args)
		return s.conclude(_join(out, s.gain_insight("spar")), s.advance_days(s.content.action_days("road_recovery")))
	var reward: Dictionary = rules.round
	s.player.stones = int(s.player.stones) + int(reward.stones)
	var message: String = _join(s.log_event("summit_round", args.merged({"stones": int(reward.stones)}), round == rules.champions.size()), s.gain_insight("spar"))
	message += " " + s.Sect.gain(s, int(reward.contribution), "%s胜了一轮" % rules.name)
	message = _join(message, s.gain_xp(int(reward.xp)))
	if round < rules.champions.size():
		var share := float(rules.recover_percent) / 100.0
		s.player.hp = mini(int(s.player.max_hp), int(s.player.hp) + int(float(s.player.max_hp) * share))
		s.player.qi = mini(int(s.player.max_qi), int(s.player.qi) + int(float(s.player.max_qi) * share))
		begin(s, round + 1, contest)
		s.changed.emit()
		return message + " 下一轮开始。"
	var prize: Dictionary = rules.champion
	var slip: String = "j:" + s.Arsenal.generate_technique(s.content, s.world_rng, int(prize.manual), {"slot": "art"})
	s.add_item(slip, 1)
	s.player.stones = int(s.player.stones) + int(prize.stones)
	message += " " + s.log_event("summit_champion" if contest == "wuzong" else "contest_champion", {"stones": int(prize.stones), "item": slip, "contest": str(rules.name)}, true)
	if contest == "wuzong":
		s.record_deed("summit_champion")
	# The crown is remembered in the world (`world_flag`: 天南大比's opens the four sects' doors, guest.gd).
	if rules.has("world_flag"):
		s.world.flags[str(rules.world_flag)] = true
	message += " " + s.Sect.gain(s, int(prize.contribution), "%s夺魁" % rules.name)
	message = _join(message, s.gain_xp(int(prize.xp)))
	if contest == "wuzong":
		message = _join(message, s.congratulate("summit"))
	return s.conclude(message, s.advance_days(s.content.action_days("road_recovery")))

static func _join(message: String, more: Array[String]) -> String:
	return message if more.is_empty() else message + " " + " ".join(more)
