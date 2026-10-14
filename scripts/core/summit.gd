extends RefCounted
## 五宗论道: every sixty years from 历元 60 the five sects send their best to 青云山 (events.json
## five_sects_entry). Operates on a Session. A cultivator of foundation or above may stand for 青云:
## four rounds against the senior disciples of the other sects (data/summit.json), each casting their
## own lineage's three arts at their own fixed cultivation (`levels`: 筑基后期 to 金丹中期).
## Between rounds some health and qi come back. Each round won brings stones, contribution and xp; the
## champion takes a 地阶 slip and a large reward. A loss ends the run without any penalty.
## The duel: battle.context "summit", battle.round, and battle.foe built here (no person behind it).

static func data(s) -> Dictionary:
	return s.content.summit_data

## Starts round `round` (from 1) against that round's champion.
static func begin(s, round: int) -> void:
	var champion: Dictionary = data(s).champions[round - 1]
	var level: Array = data(s).levels[round - 1]
	var realm := clampi(int(level[0]), 0, s.content.realms.size() - 1)
	var stage := clampi(int(level[1]), 0, s.content.realm(realm).stages.size() - 1)
	var caps: Dictionary = s.content.stage(realm, stage)
	var power := float(data(s).power[round - 1])
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
		"art": str(best.id), "art_name": str(best.name), "vfx": str(best.vfx), "tier": int(best.tier), "xp": int(data(s).round.xp),
		"sect": str(champion.sect), "gender": str(champion.gender), "arts": arts, "power": snappedf(power, 0.01), "bonus": bonus,
		"element": str(best.element), "realm": realm,
	}
	s.battle = {"enemy_id": "cultivator", "hp": int(foe.hp), "turn": 1, "cooldowns": {}, "opponent_sect": str(champion.sect), "status": {}, "context": "summit", "round": round, "foe": foe, "place": s.Combat._battle_place(s)}
	s.combat_events.clear()
	s.Combat.open_hand(s)
	s.log_event("summit_start", {"round": round, "foe": "%s%s" % [champion.title, champion.name]})

## A round ends: a win leads on (or crowns the player), a loss ends the run.
static func over(s, won: bool) -> String:
	var round := int(s.battle.get("round", 1))
	var champion: Dictionary = data(s).champions[round - 1]
	var foe_name := "%s%s" % [champion.title, champion.name]
	s.battle.clear()
	s.record_deed("duel")
	if not won:
		s.player.hp = maxi(int(s.player.hp), 1)
		var out: String = s.log_event("summit_out", {"round": round, "foe": foe_name})
		return s.conclude(_join(out, s.gain_insight("spar")), s.advance_days(s.content.action_days("road_recovery")))
	var reward: Dictionary = data(s).round
	s.player.stones = int(s.player.stones) + int(reward.stones)
	var message: String = _join(s.log_event("summit_round", {"round": round, "foe": foe_name, "stones": int(reward.stones)}, round == data(s).champions.size()), s.gain_insight("spar"))
	message += " " + s.Sect.gain(s, int(reward.contribution), "五宗论道胜了一轮")
	message = _join(message, s.gain_xp(int(reward.xp)))
	if round < data(s).champions.size():
		var share := float(data(s).recover_percent) / 100.0
		s.player.hp = mini(int(s.player.max_hp), int(s.player.hp) + int(float(s.player.max_hp) * share))
		s.player.qi = mini(int(s.player.max_qi), int(s.player.qi) + int(float(s.player.max_qi) * share))
		begin(s, round + 1)
		s.changed.emit()
		return message + " 下一轮开始。"
	var prize: Dictionary = data(s).champion
	var slip: String = "j:" + s.Arsenal.generate_technique(s.content, s.world_rng, int(prize.manual), {"slot": "art"})
	s.add_item(slip, 1)
	s.player.stones = int(s.player.stones) + int(prize.stones)
	message += " " + s.log_event("summit_champion", {"stones": int(prize.stones), "item": slip}, true)
	s.record_deed("summit_champion")
	message += " " + s.Sect.gain(s, int(prize.contribution), "五宗论道夺魁")
	message = _join(message, s.gain_xp(int(prize.xp)))
	message = _join(message, s.congratulate("summit"))
	return s.conclude(message, s.advance_days(s.content.action_days("road_recovery")))

static func _join(message: String, more: Array[String]) -> String:
	return message if more.is_empty() else message + " " + " ".join(more)
