extends RefCounted
## Restores a Session from save data: upgrades older versions first, then validates everything before
## changing the session, so a malformed save leaves the current journey untouched.
const Calendar = preload("res://scripts/core/calendar.gd")
const Chronicle = preload("res://scripts/core/chronicle.gd")
const SaveMigration = preload("res://scripts/core/save_migration.gd")
const Cultivation = preload("res://scripts/core/cultivation.gd")
const Talents = preload("res://scripts/core/talents.gd")
const Gear = preload("res://scripts/core/gear.gd")
const Layers = preload("res://scripts/core/layers.gd")
const Wuxiang = preload("res://scripts/core/wuxiang.gd")
const Forming = preload("res://scripts/core/forming.gd")
const Nascent = preload("res://scripts/core/nascent.gd")
# More 祭炼 steps than any piece could use; a save above it is malformed.
const MAX_REFINE := 20
const PLAYER_COUNTS := ["realm", "xp", "hp", "qi", "stones", "cultivation_carry", "fatigue", "fatigue_day", "insight"]
const FLOW_TURNS := ["dao_hit_turn", "array_driven", "dao_chain_metal", "dao_chain_wood", "dao_chain_water", "dao_chain_fire", "dao_chain_earth"]
const LIMIT := 1000000000.0

static func restore(s, data: Variant) -> bool:
	if not data is Dictionary:
		return false
	var saved: Dictionary = SaveMigration.migrate(data)
	if saved.is_empty() or int(saved.version) != SaveMigration.CURRENT_VERSION:
		return false
	var content = s.content
	var saved_world: Variant = saved.get("world")
	var saved_player: Variant = saved.get("player")
	var saved_battle: Variant = saved.get("battle")
	var saved_pending: Variant = saved.get("pending_event")
	var saved_ended: Variant = saved.get("ended")
	var saved_rng: Variant = saved.get("rng")
	# An auction under way (optional: saves before auctions have none).
	var saved_auction: Variant = saved.get("auction", {})
	for part: Variant in [saved_world, saved_player, saved_battle, saved_pending, saved_ended, saved_rng, saved_auction]:
		if not part is Dictionary:
			return false
	if not saved_auction.is_empty() and not _valid_auction(s, content, saved_auction):
		return false
	# 结丹 under way (optional: forming.gd); it holds the player apart from any duel, choice or attempt.
	var forming: Variant = Forming.valid_state(content, saved.get("forming", {}))
	if forming == null or (not forming.is_empty() and (not saved_battle.is_empty() or not saved_pending.is_empty() or saved_player.has("attempt") or int(saved_player.get("realm", -1)) != 1)):
		return false
	# 结婴 under way (optional: nascent.gd), likewise apart, and never beside a 结丹.
	var nascent: Variant = Nascent.valid_state(content, saved.get("nascent", {}))
	if nascent == null or (not nascent.is_empty() and (not forming.is_empty() or not saved_battle.is_empty() or not saved_pending.is_empty() or saved_player.has("attempt") or int(saved_player.get("realm", -1)) != 2)):
		return false
	# The kind of 金丹 formed (optional: forming.gd).
	if not Forming.valid_kind(content, saved_player.get("core_kind", {})):
		return false
	if not _whole_nonnegative(saved_world.get("day")) or not saved_world.get("flags") is Dictionary:
		return false
	if not saved_world.get("events") is Dictionary or not saved_world.get("people") is Dictionary:
		return false
	var day := int(saved_world.day)
	for flag: Variant in saved_world.flags:
		if not flag is String or not saved_world.flags[flag] is bool:
			return false
	var events: Variant = _valid_event_progress(saved_world.events)
	var people: Variant = _valid_people(content, saved_world.people, day)
	var caves: Variant = _valid_caves(content, saved_world.get("caves", {}))
	var supply: Variant = _valid_supply(content, saved_world.get("market_supply", {}), day)
	# Places' shortages filled lately (optional: inventory.gd demand), keyed "place:item".
	var demand: Variant = _valid_demand(content, saved_world.get("demand_supply", {}), day)
	if events == null or people == null or caves == null or supply == null or demand == null:
		return false
	# Who went into a cave along (optional: caves.gd).
	var party: Variant = saved_world.get("party", {})
	if not party is Dictionary or party.keys().any(func(cave_id: Variant) -> bool: return not content.cave_data.has(cave_id) or not party[cave_id] is String):
		return false
	var companion: Variant = saved_world.get("companion", "")
	var disciples: Variant = saved_world.get("disciples", [])
	var sworn: Variant = saved_world.get("sworn", [])
	if not companion is String or not disciples is Array or disciples.size() > 10 or disciples.any(func(person_id: Variant) -> bool: return not person_id is String):
		return false
	if not sworn is Array or sworn.size() > 10 or sworn.any(func(person_id: Variant) -> bool: return not person_id is String):
		return false
	if not saved_player.get("name") is String or not saved_player.get("location") is String or not content.locations.has(saved_player.location):
		return false
	var prepared_pill: Variant = saved_player.get("prepared_pill", "")
	if not s.Prebattle.valid_ids(content, saved_player.get("prepared_pills", [])) or not s.Prebattle.valid_ids(content, saved_battle.get("prepared_pills", [])):
		return false
	if not prepared_pill is String or (not prepared_pill.is_empty() and not content.item(prepared_pill).has("battle_preparation")):
		return false
	var pending_pills: Array = saved_player.get("prepared_pills", []).duplicate()
	if not prepared_pill.is_empty() and not prepared_pill in pending_pills:
		pending_pills.append(prepared_pill)
	if not s.Prebattle.valid_ids(content, pending_pills):
		return false
	var memory: Variant = saved_battle.get("payment_memory", {})
	if not memory is Dictionary or memory.size() > 256:
		return false
	for art_id: Variant in memory:
		if not art_id is String or content.technique(art_id).is_empty() or not memory[art_id] is Array or memory[art_id].size() > 64:
			return false
		if memory[art_id].any(func(e: Variant) -> bool: return not e is String or not content.technique_data.elements.has(e)):
			return false
	var battle_pill: Variant = saved_battle.get("prepared_pill", "")
	# Optional, battle-local build resources. Validate before assigning any live state.
	for key: String in ["resources", "foe_resources"]:
		var counters: Variant = saved_battle.get(key, {})
		if not counters is Dictionary or counters.keys().any(func(name: Variant) -> bool: return not name in ["dust", "sand"] or not _whole_nonnegative(counters[name]) or float(counters[name]) > s.Combat.DustFlow.CAP):
			return false
	for key: String in ["flow_used", "foe_flow_used"]:
		var used: Variant = saved_battle.get(key, {})
		if not used is Dictionary or used.size() > 256:
			return false
		for id: Variant in used:
			if not id is String or content.technique(id).is_empty() or not _whole_nonnegative(used[id]) or float(used[id]) < 1 or float(used[id]) > float(saved_battle.get("turn", 0)):
				return false
	if not battle_pill is String or (not battle_pill.is_empty() and not content.item(battle_pill).has("battle_preparation")):
		return false
	var active_pills: Array = saved_battle.get("prepared_pills", []).duplicate()
	if not battle_pill.is_empty() and not battle_pill in active_pills:
		active_pills.append(battle_pill)
	if not s.Prebattle.valid_ids(content, active_pills):
		return false
	for key: String in FLOW_TURNS:
		if saved_battle.has(key) and (not _whole_nonnegative(saved_battle[key]) or float(saved_battle[key]) > float(saved_battle.get("turn", 0))):
			return false
	if saved_battle.has("foe_next_draw") and (not _whole_nonnegative(saved_battle.foe_next_draw) or float(saved_battle.foe_next_draw) > 1000000):
		return false
	for key: String in PLAYER_COUNTS:
		if not _whole_nonnegative(saved_player.get(key)):
			return false
	if int(saved_player.cultivation_carry) >= Cultivation.CARRY_UNIT:
		return false
	if int(saved_player.fatigue_day) > day or int(saved_player.insight) > Cultivation.insight_needed(s):
		return false
	# The mind (心境): optional, since saves before it lack it.
	var mind: Variant = saved_player.get("mind", -1)
	if not _whole_signed(mind) or int(mind) < -1:
		return false
	var birth: Variant = saved_player.get("birth_day")
	if not _whole_signed(birth) or int(birth) > day:
		return false
	var warned: Variant = saved_player.get("warned_for")
	if not _whole_signed(warned) or int(warned) < -1:
		return false
	# Appointments chosen to leave a retreat for (optional: journeys before them chose none).
	var wake: Variant = _valid_wake(content, saved_player.get("wake", []))
	if wake == null:
		return false
	# A 天劫 under way: the grade the attempt earned waits on it (optional; only with its duel).
	var trial: Variant = saved_player.get("tribulation", {})
	# The 飞升天劫 (battle.ascension) is a 天劫 that waits on no breakthrough.
	var breakthrough_trial: bool = str(saved_battle.get("context", "")) == "tribulation" and str(saved_battle.get("ascension", "")).is_empty()
	if not trial is Dictionary or trial.is_empty() == breakthrough_trial or (not trial.is_empty() and (not _whole_nonnegative(trial.get("grade")) or not _whole_nonnegative(trial.get("days")) or not _whole_nonnegative(trial.get("xp")) or not trial.get("staked", "") is String)):
		return false
	# A series of fights under way and when each was last taken (optional).
	var underway: Variant = saved_player.get("series", {})
	if not underway is Dictionary or (not underway.is_empty() and (not content.series.has(underway.get("id", "")) or not _whole_nonnegative(underway.get("wave")) or int(underway.wave) >= content.series[underway.id].waves.size())):
		return false
	# What each sitting of a recurring trial came to (optional: trials.gd).
	var trials: Variant = saved_player.get("trials", {})
	if not trials is Dictionary or trials.keys().any(func(trial_id: Variant) -> bool: return not trial_id in s.Trials.TRIALS or not trials[trial_id] is Dictionary or trials[trial_id].keys().any(func(year: Variant) -> bool: return not year is String or not year.is_valid_int() or not _whole_nonnegative(trials[trial_id][year]))):
		return false
	# Standing as sects' 客卿 (optional: guest.gd); journeys from before there could be two kept one bond
	# as player.guest.
	var guests: Variant = _valid_guests(content, saved_player)
	if guests == null:
		return false
	# 天南散修盟 (optional: league.gd); its world flag stands exactly while a member.
	var league: Variant = _valid_league(content, saved_player, saved_world)
	if league == null:
		return false
	# 天骄榜 (optional: tianji.gd): the scrolls' orders and the player's notes and dates.
	var tianji: Variant = _valid_tianji(content, saved_player, saved_world)
	if tianji == null:
		return false
	var mijing: Variant = _valid_mijing(content, saved_world.get("mijing", {}))
	if mijing == null:
		return false
	var guishi: Variant = _valid_guishi(saved_world.get("guishi", {}))
	if guishi == null:
		return false
	var wuxiang: Variant = _valid_wuxiang(content, saved_world.get("wuxiang", {}))
	if wuxiang == null:
		return false
	var series_last: Variant = saved_player.get("series_last", {})
	if not series_last is Dictionary or series_last.keys().any(func(series_id: Variant) -> bool: return not content.series.has(series_id) or not _whole_nonnegative(series_last[series_id])):
		return false
	# A run at a 擂台 and the best streaks (optional).
	var run: Variant = saved_player.get("arena", {})
	if not run is Dictionary or (not run.is_empty() and (not content.locations.has(run.get("place", "")) or not _whole_nonnegative(run.get("streak")) or not run.get("fought") is Array or run.fought.any(func(person_id: Variant) -> bool: return not person_id is String))):
		return false
	var bests: Variant = saved_player.get("arena_best", {})
	if not bests is Dictionary or bests.keys().any(func(place: Variant) -> bool: return not content.locations.has(place) or not _whole_nonnegative(bests[place])):
		return false
	# Dwellings let for a term (optional: journeys before leases hold none).
	var leases: Variant = saved_player.get("leases", {})
	if not leases is Dictionary or leases.size() > 16 or leases.keys().any(func(flag: Variant) -> bool: return not flag in content.world_flags or not _whole_nonnegative(leases[flag])):
		return false
	var items: Variant = saved_player.get("items")
	if not items is Dictionary:
		return false
	var journey: Variant = saved_player.get("journey")
	if not journey is Dictionary or (not journey.is_empty() and (not journey.get("to") is String or not content.location_visible(journey.to, saved_world.flags))):
		return false
	if not journey.is_empty() and (not journey.get("mode", "fast") is String or not journey.get("mode", "fast") in ["fast", "cheap"]):
		return false
	var cooldowns: Variant = saved_player.get("cooldowns")
	if not cooldowns is Dictionary:
		return false
	for action_id: Variant in cooldowns:
		if not action_id is String or not _whole_nonnegative(cooldowns[action_id]):
			return false
	if not content.location_visible(saved_player.location, saved_world.flags):
		return false
	for item_id: Variant in items:
		if not item_id is String or Gear.is_instance(item_id) or not _whole_nonnegative(items[item_id]) or int(items[item_id]) < 1:
			return false
	if int(saved_player.realm) >= content.realms.size():
		return false
	# The sub-stage always follows from xp; stat caps follow from the stage.
	# Older saves follow from xp; since version 11 the stage is kept, because xp may wait at a bottleneck
	# (never above the next threshold).
	var saved_stage: int = content.stage_index(int(saved_player.realm), int(saved_player.xp))
	if saved_player.has("stage"):
		var stages: Array = content.realm(int(saved_player.realm)).stages
		if not _whole_nonnegative(saved_player.stage) or int(saved_player.stage) >= stages.size():
			return false
		saved_stage = int(saved_player.stage)
		if saved_stage + 1 < stages.size() and int(saved_player.xp) > int(stages[saved_stage + 1].xp):
			return false
	if not s.Dao.valid_state(content, saved_player, day):
		return false
	var loadout := _valid_loadout(content, saved_player)
	if loadout.is_empty():
		return false
	var quests: Variant = _valid_quests(content, saved_player.get("quests"))
	if quests == null:
		return false
	var rumors := {}
	for key: Variant in saved_world.get("rumors", {}):
		if not key is String or not _whole_nonnegative(saved_world.rumors[key]):
			return false
		rumors[key] = int(saved_world.rumors[key])
	var taken := {}
	for key: Variant in saved_world.get("quests_taken", {}):
		if not key is String:
			return false
		taken[key] = true
	var storylines: Variant = _valid_storylines(content, saved_world.get("storylines", {}), day)
	var letters: Variant = _valid_letters(content, saved_world.get("letters", []), day)
	var deeds: Variant = _valid_counts(saved_player.get("deeds", {}))
	var taught: Variant = saved_player.get("taught", [])
	# The sect one belongs to ("" for a wanderer); journeys from before it were all 青云 disciples.
	var affiliation: Variant = saved_player.get("affiliation", str(content.rules.lineage.home))
	if not affiliation is String or (not affiliation.is_empty() and not content.sect_data.sects.has(affiliation)):
		return false
	if storylines == null or letters == null or deeds == null or not taught is Array or taught.any(func(tip: Variant) -> bool: return not tip is String):
		return false
	# An attempt waits on 心魔 while its choice is pending or its duel is fought.
	var progress: Variant = _valid_breakthrough(content, saved_player, saved_pending if str(saved_battle.get("context", "")) != "demon" else {"id": "heart_demon"})
	var standing: Variant = _valid_standing(content, saved_player, day)
	var alchemy: Variant = _valid_alchemy(content, saved_player, day)
	if progress == null or standing == null or alchemy == null:
		return false
	# Talents: optional, since saves before them lack them; then they awaken from the world seed.
	var born: Variant = _valid_talents(content, saved_player)
	if born == null:
		return false
	var awakened: bool = born.is_empty()
	if awakened:
		var rng := RandomNumberGenerator.new()
		rng.seed = hash([int(saved_world.get("seed", 0)), "awaken"])
		born = Talents.roll(content, rng, str(content.talent_data.player.table), saved_player.get("roots", []) if saved_player.get("roots") is Array else [])
	# Health and qi within the caps the save was made with (before any talents awakened).
	var holder: Dictionary = loadout.duplicate()
	holder.merge({"realm": int(saved_player.realm), "stage": saved_stage, "talents": [] if awakened else born.talents, "flaws": [] if awakened else born.flaws, "foundation_grade": int(progress.foundation_grade), "core_grade": int(progress.core_grade)}, true)
	if progress.has("nascent_grade"):
		holder["nascent_grade"] = int(progress.nascent_grade)
	holder["dao"] = saved_player.get("dao", {})
	var saved_caps: Dictionary = s.stat_caps(holder)
	if int(saved_player.hp) <= 0 or int(saved_player.hp) > int(saved_caps.max_hp) or int(saved_player.qi) > int(saved_caps.max_qi):
		return false
	holder.merge({"talents": born.talents, "flaws": born.flaws}, true)
	var caps: Dictionary = s.stat_caps(holder)
	var roots: Variant = saved_player.get("roots")
	if not roots is Array or roots.is_empty() or roots.size() > content.rules.spirit_roots.elements.size():
		return false
	for element: Variant in roots:
		if not element in content.rules.spirit_roots.elements or roots.count(element) != 1:
			return false
	var saved_sect: Variant = saved_player.get("sect")
	if not saved_sect is String or not content.sects.has(saved_sect):
		return false
	if not saved_battle.is_empty():
		if not saved_battle.get("enemy_id") is String or not content.enemies.has(saved_battle.enemy_id):
			return false
		var foe: Variant = saved_battle.get("foe", {})
		if not foe is Dictionary or (not foe.is_empty() and (not _whole_nonnegative(foe.get("hp")) or not _whole_nonnegative(foe.get("damage_min")) or not _whole_nonnegative(foe.get("damage_max")) or not foe.get("name") is String)):
			return false
		# Saves before duel looks lack the foe's sect and gender; the stage then uses the shared sprite.
		if foe.has("sect") and (not foe.sect is String or not content.sects.has(foe.sect)):
			return false
		if foe.has("gender") and not foe.gender in ["male", "female"]:
			return false
		# Saves before duel backdrops lack the place; the stage then uses the shared background.
		var place: Variant = saved_battle.get("place", "road")
		if not place is String or (place != "road" and not content.locations.has(place)):
			return false
		var hp_cap: int = int(foe.hp) if not foe.is_empty() else int(content.enemies[saved_battle.enemy_id].hp)
		if not _whole_nonnegative(saved_battle.get("hp")) or int(saved_battle.hp) <= 0 or int(saved_battle.hp) > hp_cap:
			return false
		if not _whole_nonnegative(saved_battle.get("turn")) or int(saved_battle.turn) < 1 or not saved_battle.get("cooldowns") is Dictionary:
			return false
		for skill_id: Variant in saved_battle.cooldowns:
			if not skill_id is String or content.technique(skill_id).is_empty() or not _whole_nonnegative(saved_battle.cooldowns[skill_id]):
				return false
		if saved_battle.has("context") and not saved_battle.context in ["event", "spar", "tournament", "summit", "arena", "demon", "tribulation", "tianji", "mijing", "guishi"]:
			return false
		# The 金丹's opening qi held back while a quicker foe moved first (combat.gd open_hand).
		var held_back: Variant = saved_battle.get("core_orbs", [])
		if not held_back is Array or held_back.size() > 20 or held_back.any(func(element: Variant) -> bool: return not content.technique_data.elements.has(element)):
			return false
		# A duel with someone met in a 秘境 (mijing.gd), and robbers at its door.
		if saved_battle.get("context", "") == "mijing" and (not content.mijing_data.realms.has(str(saved_battle.get("mijing", ""))) or not saved_battle.get("foe") is Dictionary):
			return false
		if saved_battle.has("robbery") and not content.mijing_data.realms.has(str(saved_battle.robbery)):
			return false
		# A 鬼市 contract's duel (guishi.gd): whom, and what it pays.
		if saved_battle.get("context", "") == "guishi" and (not saved_battle.get("guishi") is Dictionary or not _whole_nonnegative(saved_battle.guishi.get("reward")) or not saved_battle.get("foe") is Dictionary):
			return false
		# A 天骄榜 duel (tianji.gd): the scroll, whom and what for.
		if saved_battle.get("context", "") == "tianji":
			var bout: Variant = saved_battle.get("tianji")
			if not bout is Dictionary or not content.tianji_data.scrolls.has(str(bout.get("scroll", ""))) or not bout.get("target") is String or not bout.get("kind") in ["challenge", "defend"]:
				return false
		# A contest's round (summit.gd): which contest (五宗论道 by default) and a round it has.
		if saved_battle.get("context", "") == "summit":
			var contest: Variant = content.summit_data.get(str(saved_battle.get("contest", "wuzong")))
			if not contest is Dictionary or not _whole_nonnegative(saved_battle.get("round")) or int(saved_battle.round) < 1 or int(saved_battle.round) > contest.champions.size():
				return false
		for status_key: String in ["status", "player_status"]:
			var status: Variant = saved_battle.get(status_key, {})
			if not status is Dictionary:
				return false
			for key: Variant in status:
				if not key in s.Combat.LINGERING or not status[key] is Array or status[key].size() != 2:
					return false
		# A handwritten opponent's move table (optional): a blow wound up, the phase entered, moves used.
		var enemy_def: Dictionary = content.enemies.get(saved_battle.get("enemy_id", ""), {})
		var move_ids: Array = []
		for phase: Dictionary in [{"moves": enemy_def.get("moves", [])}] + enemy_def.get("phases", []):
			for move: Dictionary in phase.get("moves", []):
				move_ids.append(move.id)
		if saved_battle.has("charged") and not saved_battle.charged in move_ids:
			return false
		if not _whole_nonnegative(saved_battle.get("phase", 0)) or int(saved_battle.get("phase", 0)) > enemy_def.get("phases", []).size():
			return false
		var used: Variant = saved_battle.get("used", [])
		if not used is Array or used.any(func(move_id: Variant) -> bool: return not move_id in move_ids):
			return false
		var traits_used: Variant = saved_battle.get("traits_used", [])
		if not traits_used is Array or traits_used.any(func(kind: Variant) -> bool: return not kind in ["heart_guard", "mirror"]):
			return false
		# 群敌 and 连战 (optional).
		var pack: Variant = saved_battle.get("pack", [])
		if not pack is Array or pack.size() > 4 or pack.any(func(member: Variant) -> bool: return not member is Dictionary or not content.enemies.has(member.get("enemy_id", "")) or not _whole_nonnegative(member.get("hp"))):
			return false
		if int(saved_battle.get("target", 0)) > pack.size():
			return false
		var felled: Variant = saved_battle.get("felled", [])
		if not felled is Array or felled.any(func(enemy_id: Variant) -> bool: return not content.enemies.has(enemy_id)):
			return false
		if saved_battle.has("series") and not content.series.has(saved_battle.series):
			return false
		if saved_battle.has("cave") and not content.cave_data.has(saved_battle.cave):
			return false
		var secrets: Variant = saved_battle.get("secrets", [])
		if not secrets is Array or secrets.any(func(art_id: Variant) -> bool: return not content.rules.get("duel", {}).get("secret_arts", {}).has(art_id)):
			return false
		for flag_key: String in ["array", "body_ready", "deadly", "old_wound"]:
			if saved_battle.has(flag_key) and not saved_battle[flag_key] is bool:
				return false
		for named: String in ["title", "grudge", "wanted"]:
			if saved_battle.has(named) and not saved_battle[named] is String:
				return false
		# Qi orbs (optional: duels saved before them draw a fresh hand when loaded).
		for orbs_key: String in ["orbs", "foe_orbs"]:
			var orbs: Variant = saved_battle.get(orbs_key, [])
			if not orbs is Array or orbs.size() > 4096 or orbs.any(func(orb: Variant) -> bool: return not content.technique_data.elements.has(orb)):
				return false
		# The element of the art cast last, for 连击 ("chain" in duels saved before it, read the same way).
		for last_key: String in ["last", "chain", "foe_last"]:
			var last: Variant = saved_battle.get(last_key, "")
			if not last is String or (not last.is_empty() and content.element_info(last).is_empty()):
				return false
		for count_key: String in ["shield", "foe_shield", "pills", "talismans", "released", "target", "sword_streak", "soul_turn", "dispel", "opening_percent", "guarded_turns", "next_draw"]:
			if not _whole_nonnegative(saved_battle.get(count_key, 0)):
				return false
		if int(saved_battle.get("opening_percent", 100)) > 100:
			return false
		var intent: Variant = saved_battle.get("intent", [])
		if not intent is Array or intent.any(func(entry: Variant) -> bool: return not entry is Dictionary or not entry.get("kind") is String or not entry.get("name") is String or (entry.has("art") and content.technique(str(entry.art)).is_empty()) or (entry.has("move") and not entry.move in move_ids) or (entry.has("landing") and not entry.landing is bool) or ["min", "max", "amount", "hits"].any(func(key: String) -> bool: return entry.has(key) and not _whole_nonnegative(entry[key]))):
			return false
		if foe.has("arts") and (not foe.arts is Array or foe.arts.any(func(art: Variant) -> bool: return not art is String or content.technique(art).is_empty()) or not (foe.get("power") is float or foe.get("power") is int) or not _whole_signed(foe.get("bonus")) or content.element_info(str(foe.get("element", ""))).is_empty()):
			return false
		if saved_battle.has("npc") and (not saved_battle.npc is String or not s.is_person(saved_battle.npc)):
			return false
		if foe.has("methods") and (not foe.methods is Array or foe.methods.any(func(id: Variant) -> bool: return not id is String or content.technique(id).get("slot", "") != "method")):
			return false
		var opponent: Variant = saved_battle.get("opponent_sect")
		if not opponent is String or not content.sects.has(opponent):
			return false
	if not saved_pending.is_empty():
		var pending_id: Variant = saved_pending.get("id")
		if not pending_id is String or not content.events.has(pending_id) or not content.events[pending_id].has("choices"):
			return false
		if not _whole_nonnegative(saved_pending.get("day")) or int(saved_pending.day) != day or not saved_battle.is_empty():
			return false
		var values: Variant = saved_pending.get("values", {})
		if not values is Dictionary or values.keys().any(func(key: Variant) -> bool: return not key is String or not values[key] is String):
			return false
	if not saved_ended.is_empty():
		if not saved_ended.get("kind") in ["lifespan", "ascension", "fallen", "story"] or not _whole_nonnegative(saved_ended.get("day")) or int(saved_ended.day) > day or not saved_ended.get("choice", false) is bool or not saved_ended.get("route", "") is String or not saved_ended.get("text", "") is String:
			return false
	for stream: String in ["combat", "world"]:
		if not saved_rng.get(stream) is String or not saved_rng[stream].is_valid_int():
			return false
	var saved_chronicle: Variant = Chronicle.parse(saved.get("chronicle"), day)
	if saved_chronicle == null:
		return false
	var sold := {}
	for key: Variant in saved_world.get("stock_sold", {}):
		if key is String:
			sold[key] = true
	var seed_value: Variant = saved_world.get("seed", 0)
	var shaped: Variant = saved_world.get("talent_lives", false)
	if not shaped is bool:
		return false
	var bonds: Variant = _valid_bonds(s, content, saved_world, day)
	if bonds == null:
		return false
	# 恩怨 (feuds.gd, optional).
	var grudges: Variant = saved_world.get("grudges", [])
	if not grudges is Array or grudges.any(func(grudge: Variant) -> bool: return not grudge is Dictionary or not grudge.get("id") is String or not grudge.get("name") is String or not content.enemies.has(grudge.get("enemy", "")) or not content.feuds.get("causes", {}).has(grudge.get("cause", "")) or not _whole_nonnegative(grudge.get("since")) or not content.regions.has(grudge.get("region", ""))):
		return false
	var stashes: Variant = saved_world.get("stashes", [])
	if not stashes is Array or stashes.any(func(stash: Variant) -> bool: return not stash is Dictionary or not content.locations.has(stash.get("place", "")) or not _whole_nonnegative(stash.get("stones"))):
		return false
	var grudge_seeds: Variant = saved_world.get("grudge_seeds", {})
	if not grudge_seeds is Dictionary or grudge_seeds.values().any(func(seen: Variant) -> bool: return not _whole_nonnegative(seen)) or not _whole_nonnegative(saved_world.get("grudge_serial", 0)):
		return false
	s.world = {"day": day, "flags": saved_world.flags.duplicate(), "events": events, "people": people, "seed": int(seed_value) if _whole_nonnegative(seed_value) else 0, "stock_sold": sold, "rumors": rumors, "quests_taken": taken, "storylines": storylines, "letters": letters, "talent_lives": shaped, "invites": bonds.invites, "loans": bonds.loans, "visit_period": bonds.visit_period, "caves": caves, "market_supply": supply, "demand_supply": demand, "companion": companion, "party": party.duplicate(), "disciples": disciples.duplicate(), "sworn": sworn.duplicate()}
	var kept_grudges: Array = []
	for grudge: Dictionary in grudges:
		kept_grudges.append({"id": str(grudge.id), "name": str(grudge.name), "enemy": str(grudge.enemy), "cause": str(grudge.cause), "since": int(grudge.since), "region": str(grudge.region)})
	s.world["grudges"] = kept_grudges
	var seen_seeds := {}
	for key: String in grudge_seeds:
		seen_seeds[key] = int(grudge_seeds[key])
	s.world["grudge_seeds"] = seen_seeds
	s.world["grudge_serial"] = int(saved_world.get("grudge_serial", 0))
	var kept_stashes: Array = []
	for stash: Dictionary in stashes:
		kept_stashes.append({"place": str(stash.place), "stones": int(stash.stones)})
	s.world["stashes"] = kept_stashes
	s.world["tianji"] = tianji.world
	s.world["mijing"] = mijing
	s.world["guishi"] = guishi
	s.world["wuxiang"] = wuxiang
	s.populate()
	var player: Dictionary = saved_player.duplicate(true)
	for key: String in PLAYER_COUNTS:
		player[key] = int(player[key])
	player.birth_day = int(birth)
	player.stage = saved_stage
	# Journeys from before the mind start with what their stage asks, so nothing they had slows down.
	player["mind"] = int(mind) if int(mind) >= 0 else int(content.stage(int(saved_player.realm), saved_stage).get("mind", 0))
	player.roots = roots.duplicate()
	for key: String in loadout:
		player[key] = loadout[key]
	player.quests = quests
	player["deeds"] = deeds
	player["taught"] = taught.duplicate()
	player["affiliation"] = affiliation
	player["talents"] = born.talents.duplicate()
	player["flaws"] = born.flaws.duplicate()
	for key: String in progress:
		player[key] = progress[key]
	for key: String in standing:
		player[key] = standing[key]
	for key: String in alchemy:
		player[key] = alchemy[key]
	if not progress.has("attempt"):
		player.erase("attempt")
	# Health and qi stay within the caps; talents that awaken may lower them.
	player.hp = mini(int(player.hp), int(caps.max_hp))
	player.qi = mini(int(player.qi), int(caps.max_qi))
	player.warned_for = int(warned)
	player["wake"] = wake
	if not trial.is_empty():
		player["tribulation"] = {"grade": int(trial.grade), "days": int(trial.days), "xp": int(trial.xp), "staked": str(trial.get("staked", ""))}
	if not underway.is_empty():
		player["series"] = {"id": str(underway.id), "wave": int(underway.wave)}
	var sittings := {}
	for trial_id: String in trials:
		sittings[trial_id] = {}
		for year: String in trials[trial_id]:
			sittings[trial_id][year] = int(trials[trial_id][year])
	player["trials"] = sittings
	player["guests"] = guests
	player["league"] = league
	player["tianji"] = tianji.player
	var last_taken := {}
	for series_id: String in series_last:
		last_taken[series_id] = int(series_last[series_id])
	player["series_last"] = last_taken
	if not run.is_empty():
		player["arena"] = {"place": str(run.place), "streak": int(run.streak), "fought": run.fought.duplicate()}
	var best_streaks := {}
	for place: String in bests:
		best_streaks[place] = int(bests[place])
	player["arena_best"] = best_streaks
	var terms := {}
	for flag: String in leases:
		terms[flag] = int(leases[flag])
	player["leases"] = terms
	# Items the content no longer knows (the pills retired from breakthroughs past 筑基) are dropped,
	# so retired content cannot lock a journey.
	var carried := {}
	for item_id: String in player.items:
		if not content.item(item_id).is_empty():
			carried[item_id] = int(player.items[item_id])
	player.items = carried
	player.journey = {} if journey.is_empty() else {"to": journey.to, "mode": journey.get("mode", "fast")}
	for action_id: String in player.cooldowns:
		player.cooldowns[action_id] = int(player.cooldowns[action_id])
	s.player = player
	s.refresh_realm_stats()
	# The fatigue limit depends on the realm, so it is applied once the player is in place.
	player.fatigue = mini(int(player.fatigue), Cultivation.fatigue_cap(s))
	var battle: Dictionary = saved_battle.duplicate(true)
	if player.has("dao"):
		for key: String in ["xp", "pending", "debates"]:
			for id: String in player.dao[key]:
				player.dao[key][id] = int(player.dao[key][id])
		player.dao.debate_xp = int(player.dao.debate_xp)
	var fresh_hand := false
	if not battle.is_empty():
		for key: String in FLOW_TURNS + ["foe_next_draw"]:
			if battle.has(key):
				battle[key] = int(battle[key])
		for key: String in ["resources", "foe_resources", "flow_used", "foe_flow_used"]:
			if battle.has(key):
				for entry: String in battle[key]:
					battle[key][entry] = int(battle[key][entry])
		if not battle.has("status"):
			battle.status = {}
		battle.hp = int(battle.hp)
		battle.turn = int(battle.turn)
		for skill_id: String in battle.cooldowns:
			battle.cooldowns[skill_id] = int(battle.cooldowns[skill_id])
		fresh_hand = not battle.has("orbs")
		for member: Dictionary in battle.get("pack", []):
			member.hp = int(member.hp)
		# 连击 reads the art cast last; a duel saved before kept it as "chain".
		if battle.has("chain"):
			battle.last = str(battle.get("last", battle.chain))
			battle.erase("chain")
		for count_key: String in ["shield", "foe_shield", "pills", "talismans", "released", "target", "sword_streak", "soul_turn", "dispel", "opening_percent", "guarded_turns", "next_draw"]:
			if battle.has(count_key):
				battle[count_key] = int(battle[count_key])
		# JSON brings every number back as a float; the whole ones are whole again.
		if battle.has("phase"):
			battle.phase = int(battle.phase)
		for entry: Dictionary in battle.get("intent", []):
			for key: String in ["min", "max", "amount", "hits"]:
				if entry.has(key):
					entry[key] = int(entry[key])
		for status_key: String in ["status", "player_status"]:
			var lingering: Dictionary = battle.get(status_key, {})
			for key: String in lingering:
				lingering[key] = s.Combat.lingering_value(key, lingering[key])
		# A 鬼市 contract's pay (guishi.gd).
		if battle.get("guishi") is Dictionary and battle.guishi.has("reward"):
			battle.guishi.reward = int(battle.guishi.reward)
		var foe_stats: Dictionary = battle.get("foe", {})
		for key: String in ["hp", "damage_min", "damage_max", "tier", "xp", "bonus", "realm"]:
			if foe_stats.has(key):
				foe_stats[key] = int(foe_stats[key])
	s.battle = battle
	s.auction = _normalized_auction(saved_auction)
	s.forming = forming
	s.nascent = nascent
	s.pending_event = {} if saved_pending.is_empty() else {"id": saved_pending.id, "day": int(saved_pending.day)}
	if not saved_pending.get("values", {}).is_empty():
		s.pending_event["values"] = saved_pending.values.duplicate()
	s.ended = {} if saved_ended.is_empty() else {"kind": saved_ended.kind, "day": int(saved_ended.day)}
	# The way an ascension went (ascension.gd).
	if not str(saved_ended.get("route", "")).is_empty():
		s.ended.route = str(saved_ended.route)
	if bool(saved_ended.get("choice", false)):
		s.ended["choice"] = true
	# The words of a life ended by a choice (events.gd end_life).
	if not str(saved_ended.get("text", "")).is_empty():
		s.ended["text"] = str(saved_ended.text)
	s.chronicle.entries = saved_chronicle
	s.combat_rng.state = int(saved_rng.combat)
	s.world_rng.state = int(saved_rng.world)
	# A duel saved before qi orbs carries on under them: a fresh hand and the opponent's intent.
	if fresh_hand:
		s.Combat.open_hand(s)
	s.combat_events.clear()
	if awakened:
		s.log_event("talents_awaken", {"talents": ",".join(born.talents + born.flaws)}, true)
	s.changed.emit()
	return true

## The breakthrough's saved progress, normalized: the foundation's grade (a middling one for journeys
## founded before grades), an injury, lessons, fortune met, and an attempt waiting on 心魔 (only while
## that choice is pending). Null when malformed.
static func _valid_breakthrough(content, saved_player: Dictionary, saved_pending: Dictionary) -> Variant:
	var rules: Dictionary = content.rules.breakthrough
	var result := {}
	var grade: Variant = saved_player.get("foundation_grade", 1)
	if not _whole_nonnegative(grade) or int(grade) >= rules.grades.size():
		return null
	result["foundation_grade"] = int(grade)
	var core: Variant = saved_player.get("core_grade", 0)
	if not _whole_nonnegative(core) or int(core) >= rules.core.grades.size():
		return null
	result["core_grade"] = int(core)
	# The 元婴's grade (optional: nascent.gd; a 元婴 formed before it counts as 成婴).
	if saved_player.has("nascent_grade"):
		if not Nascent.valid_grade(content, saved_player.nascent_grade):
			return null
		result["nascent_grade"] = int(saved_player.nascent_grade)
	var injury: Variant = saved_player.get("injury_until", 0)
	var lessons: Variant = saved_player.get("lessons", 0)
	if not _whole_nonnegative(injury) or not _whole_nonnegative(lessons) or int(lessons) > int(rules.lesson.most):
		return null
	result["injury_until"] = int(injury)
	result["lessons"] = int(lessons)
	# 外伤 from a fight (optional).
	var wound: Variant = saved_player.get("wound_until", 0)
	if not _whole_nonnegative(wound):
		return null
	result["wound_until"] = int(wound)
	var burned: Variant = saved_player.get("burned_years", 0)
	if not _whole_nonnegative(burned):
		return null
	result["burned_years"] = int(burned)
	var boons: Variant = saved_player.get("boons", {})
	if not boons is Dictionary:
		return null
	var kept := {}
	for id: Variant in boons:
		if not id is String or not id in content.boon_ids() or not boons[id] in ["ready", "spent"]:
			return null
		kept[id] = str(boons[id])
	result["boons"] = kept
	# Years gained by kind (延寿丹, 寿元果, defying fate); optional, since saves before them lack it.
	var longevity: Variant = saved_player.get("longevity", {})
	if not longevity is Dictionary:
		return null
	var gained := {}
	for kind: Variant in longevity:
		if not kind is String or not _whole_nonnegative(longevity[kind]) or int(longevity[kind]) > 1000:
			return null
		gained[kind] = int(longevity[kind])
	result["longevity"] = gained
	var forged: Variant = saved_player.get("forged", 0)
	if not _whole_nonnegative(forged):
		return null
	result["forged"] = int(forged)
	var waiting: bool = str(saved_pending.get("id", "")) == "heart_demon"
	var attempt: Variant = saved_player.get("attempt", null)
	if waiting != (attempt != null):
		return null
	if attempt != null:
		if not attempt is Dictionary or not _whole_nonnegative(attempt.get("odds")) or int(attempt.odds) > 100 or not attempt.get("certain") is bool or not _whole_nonnegative(attempt.get("steps")) or not _whole_nonnegative(attempt.get("xp")) or not attempt.get("guard") is String or not attempt.get("staked", "") is String:
			return null
		if not attempt.get("treasure", "") is String or (not str(attempt.get("treasure", "")).is_empty() and content.item(str(attempt.treasure)).is_empty()):
			return null
		result["attempt"] = {"odds": int(attempt.odds), "certain": attempt.certain, "steps": int(attempt.steps), "xp": int(attempt.xp), "guard": attempt.guard, "staked": str(attempt.get("staked", "")), "treasure": str(attempt.get("treasure", ""))}
	return result

## Friends' open appointments and requests, silver lent, and the last period letters were written in
## (optional: saves before them have none, and letters start from the period of loading). Invites
## from people no longer known are dropped; anything malformed is null.
static func _valid_bonds(s, content, saved_world: Dictionary, day: int) -> Variant:
	var kinds: Dictionary = content.bonds_data.visits.kinds
	var invites: Array = []
	var saved_invites: Variant = saved_world.get("invites", [])
	if not saved_invites is Array:
		return null
	for invite: Variant in saved_invites:
		if not invite is Dictionary or not invite.get("id") is String or not invite.get("npc") is String or not kinds.has(invite.get("kind", "")) or not _whole_nonnegative(invite.get("made")) or int(invite.made) > day:
			return null
		if invite.has("deadline") and not _whole_nonnegative(invite.deadline):
			return null
		if invite.has("item") and content.item(str(invite.item)).is_empty():
			return null
		if invite.has("place") and not content.locations.has(str(invite.place)):
			return null
		for key: String in ["count", "amount"]:
			if invite.has(key) and not _whole_nonnegative(invite[key]):
				return null
		if not s.is_person(invite.npc):
			continue
		var kept: Dictionary = invite.duplicate()
		for key: String in ["made", "deadline", "count", "amount"]:
			if kept.has(key):
				kept[key] = int(kept[key])
		invites.append(kept)
	var loans: Array = []
	var saved_loans: Variant = saved_world.get("loans", [])
	if not saved_loans is Array:
		return null
	for loan: Variant in saved_loans:
		if not loan is Dictionary or not loan.get("npc") is String or not _whole_nonnegative(loan.get("amount")) or not _whole_nonnegative(loan.get("repay")) or not _whole_nonnegative(loan.get("due")):
			return null
		if s.is_person(loan.npc):
			loans.append({"npc": loan.npc, "amount": int(loan.amount), "repay": int(loan.repay), "due": int(loan.due)})
	var period: Variant = saved_world.get("visit_period", day / int(content.bonds_data.visits.period_days))
	if not _whole_nonnegative(period):
		return null
	return {"invites": invites, "loans": loans, "visit_period": int(period)}

## An auction under way: a known auction, lots of known items, a lot in range, a whole price, a leader
## who is the player, nobody or a bidder, and bidders who are people.
static func _valid_auction(s, content, saved: Dictionary) -> bool:
	if not content.auction_data.auctions.has(saved.get("id", "")) or not saved.get("lots") is Array or saved.lots.is_empty() or not saved.get("bidders") is Array:
		return false
	for lot: Variant in saved.lots:
		if not lot is Dictionary or content.item(str(lot.get("item", ""))).is_empty():
			return false
		for key: String in ["count", "start", "step", "value"]:
			if not _whole_nonnegative(lot.get(key)):
				return false
	if not _whole_nonnegative(saved.get("index")) or int(saved.index) >= saved.lots.size() or not _whole_nonnegative(saved.get("price")):
		return false
	if saved.bidders.any(func(person_id: Variant) -> bool: return not person_id is String or not s.is_person(person_id)):
		return false
	var leader: Variant = saved.get("leader")
	return leader is String and (leader in ["", "player"] or leader in saved.bidders)

static func _normalized_auction(saved: Dictionary) -> Dictionary:
	if saved.is_empty():
		return {}
	var result := saved.duplicate(true)
	result.index = int(result.index)
	result.price = int(result.price)
	for lot: Dictionary in result.lots:
		for key: String in ["count", "start", "step", "value"]:
			lot[key] = int(lot[key])
	return result

## Herbs sold lately that weigh on the market's prices (optional: saves before it have none), or null
## when malformed. Items no longer known are dropped.
static func _valid_supply(content, saved: Variant, day: int) -> Variant:
	if not saved is Dictionary:
		return null
	var result := {}
	for item_id: Variant in saved:
		var sold: Variant = saved[item_id]
		if not item_id is String or not sold is Dictionary or not (sold.get("count") is float or sold.get("count") is int) or float(sold.count) < 0.0 or float(sold.count) > LIMIT or not _whole_nonnegative(sold.get("day")) or int(sold.day) > day:
			return null
		if not content.item(item_id).is_empty():
			result[item_id] = {"count": snappedf(float(sold.count), 0.01), "day": int(sold.day)}
	return result

## Shortages filled at places (`place:item` → {"count", "day"}), or null when malformed. Entries the
## content no longer names are dropped.
static func _valid_demand(content, saved: Variant, day: int) -> Variant:
	if not saved is Dictionary:
		return null
	var result := {}
	for key: Variant in saved:
		var sold: Variant = saved[key]
		if not key is String or key.count(":") != 1 or not sold is Dictionary or not (sold.get("count") is float or sold.get("count") is int) or float(sold.count) < 0.0 or float(sold.count) > LIMIT or not _whole_nonnegative(sold.get("day")) or int(sold.day) > day:
			return null
		var place: String = key.get_slice(":", 0)
		var item_id: String = key.get_slice(":", 1)
		if content.locations.has(place) and content.locations[place].get("demand", []).any(func(entry: Dictionary) -> bool: return str(entry.item) == item_id):
			result[key] = {"count": snappedf(float(sold.count), 0.01), "day": int(sold.day)}
	return result

## The old cave's rooms (optional: saves before it have none), or null when malformed. Caves and rooms
## no longer in the content are dropped.
static func _valid_caves(content, saved: Variant) -> Variant:
	if not saved is Dictionary:
		return null
	var result := {}
	for cave_id: Variant in saved:
		var cave: Variant = saved[cave_id]
		if not cave is Dictionary or not cave.get("explored") is Array or not cave.get("taken") is Array or not cave.get("fortune") is Dictionary:
			return null
		if not content.cave_data.has(cave_id):
			continue
		var rooms: Array = content.cave_data[cave_id].rooms.map(func(room: Dictionary) -> String: return str(room.id))
		var explored: Array = []
		for room_id: Variant in cave.explored:
			if not room_id is String:
				return null
			if room_id in rooms and not room_id in explored:
				explored.append(room_id)
		var taken: Array = []
		for key: Variant in cave.taken:
			if not key is String:
				return null
			if str(key).trim_suffix(":hidden") in rooms and not key in taken:
				taken.append(key)
		var fortune := {}
		for id: Variant in cave.fortune:
			if not id in ["shiru", "remnant"] or not cave.fortune[id] is bool:
				return null
			fortune[id] = cave.fortune[id]
		result[cave_id] = {"explored": explored, "taken": taken, "fortune": fortune}
	return result

## Appointments to leave a retreat for, normalized, or null when malformed: each a known event and a day.
static func _valid_wake(content, saved: Variant) -> Variant:
	if not saved is Array or saved.size() > 32:
		return null
	var result: Array = []
	for wake: Variant in saved:
		if not wake is Dictionary or not wake.get("event") is String or not content.events.has(wake.event) or not _whole_nonnegative(wake.get("day")):
			return null
		result.append({"event": wake.event, "day": int(wake.day)})
	return result

## The player's standing in the sect, normalized (optional fields default to an outer disciple with
## nothing yet), or null when malformed.
static func _valid_standing(content, saved_player: Dictionary, day: int) -> Variant:
	var result := {}
	# Each sect has its own ranks and duties; a wanderer's standing is read against the home sect's.
	var sects: Dictionary = content.sect_data.sects
	var own: Dictionary = sects.get(str(saved_player.get("affiliation", "")), sects[str(content.rules.lineage.home)])
	var rank: Variant = saved_player.get("rank", 0)
	if not _whole_nonnegative(rank) or int(rank) >= own.ranks.size():
		return null
	result["rank"] = int(rank)
	# The day the sect was joined (optional: older journeys count as long served) and the sects
	# betrayed (optional: none).
	var sect_day: Variant = saved_player.get("sect_day", 0)
	if not _whole_signed(sect_day) or int(sect_day) > day:
		return null
	result["sect_day"] = int(sect_day)
	var betrayed: Variant = saved_player.get("betrayed", [])
	if not betrayed is Array or betrayed.any(func(sect: Variant) -> bool: return not sect is String or not sects.has(sect)):
		return null
	result["betrayed"] = betrayed.duplicate()
	for key: String in ["contribution", "merit"]:
		var value: Variant = saved_player.get(key, 0)
		if not _whole_nonnegative(value):
			return null
		result[key] = int(value)
	var stipend_day: Variant = saved_player.get("stipend_day", day)
	if not _whole_signed(stipend_day) or int(stipend_day) > day:
		return null
	result["stipend_day"] = int(stipend_day)
	var exchanged: Variant = _valid_counts(saved_player.get("exchanged", {}))
	if exchanged == null:
		return null
	result["exchanged"] = exchanged
	var donated: Variant = saved_player.get("donated", {})
	if not donated is Dictionary or (not donated.is_empty() and (not _whole_nonnegative(donated.get("period")) or not _whole_nonnegative(donated.get("amount")))):
		return null
	result["donated"] = {} if donated.is_empty() else {"period": int(donated.period), "amount": int(donated.amount)}
	# A duty (optional: journeys before duties hold none); one no longer known is dropped.
	var held: Variant = saved_player.get("duty", "")
	var held_day: Variant = saved_player.get("duty_day", -1)
	if not held is String or not _whole_signed(held_day) or int(held_day) > day:
		return null
	result["duty"] = held if own.duties.list.has(held) else ""
	result["duty_day"] = int(held_day)
	return result

## The 客卿 bonds, normalized: player.guests, or the single player.guest of older journeys; null when
## malformed (an unknown sect, a sect twice, a bad day or count).
static func _valid_guests(content, saved_player: Dictionary) -> Variant:
	var saved: Variant = saved_player.get("guests", null)
	if saved == null:
		var old: Variant = saved_player.get("guest", {})
		if not old is Dictionary:
			return null
		saved = [] if old.is_empty() else [old]
	if not saved is Array:
		return null
	var result: Array = []
	var seen := {}
	for held: Variant in saved:
		if not held is Dictionary or not content.guest_data.get("sects", {}).has(held.get("sect", "")) or seen.has(held.sect) or ["since", "pay_day", "next_call", "missed"].any(func(key: String) -> bool: return not _whole_nonnegative(held.get(key))):
			return null
		seen[held.sect] = true
		result.append({"sect": str(held.sect), "since": int(held.since), "pay_day": int(held.pay_day), "next_call": int(held.next_call), "missed": int(held.missed)})
	return result if result.size() <= int(content.guest_data.most) else null

## The standing with 天南散修盟, normalized ({} for none), or null when malformed.
static func _valid_league(content, saved_player: Dictionary, saved_world: Dictionary) -> Variant:
	var saved: Variant = saved_player.get("league", {})
	if not saved is Dictionary:
		return null
	var member := bool(saved.get("member", false))
	if member != bool(saved_world.get("flags", {}).get("league_member", false)):
		return null
	if saved.is_empty():
		return {}
	if ["member", "deputy", "banned"].any(func(key: String) -> bool: return not saved.get(key, false) is bool) or not _whole_nonnegative(saved.get("standing", 0)) or not _whole_nonnegative(saved.get("since", 0)):
		return null
	var branch := str(saved.get("branch", ""))
	if (member or not branch.is_empty()) and not content.league_data.get("branches", {}).has(branch):
		return null
	if member and bool(saved.get("banned", false)):
		return null
	return {"member": member, "branch": branch, "since": int(saved.get("since", 0)), "standing": int(saved.get("standing", 0)), "deputy": bool(saved.get("deputy", false)), "banned": bool(saved.get("banned", false))}

## The 天骄榜 (tianji.gd), normalized: {"world": scrolls' orders, "player": notes and dates}, or null when
## malformed. A scroll no longer in the content is dropped; its order is revised again when next read.
static func _valid_tianji(content, saved_player: Dictionary, saved_world: Dictionary) -> Variant:
	var boards: Variant = saved_world.get("tianji", {})
	var saved: Variant = saved_player.get("tianji", {})
	if not boards is Dictionary or not saved is Dictionary:
		return null
	var kept_boards := {}
	for scroll_id: Variant in boards:
		var board: Variant = boards[scroll_id]
		if not scroll_id is String or not board is Dictionary or not _whole_nonnegative(board.get("period")) or not board.get("order") is Array:
			return null
		if board.order.any(func(id: Variant) -> bool: return not id is String) or board.order.count("player") > 1:
			return null
		if content.tianji_data.scrolls.has(scroll_id):
			kept_boards[scroll_id] = {"period": int(board.period), "order": board.order.duplicate()}
	var held := {}
	var best: Variant = saved.get("best", {})
	if not best is Dictionary or best.keys().any(func(scroll_id: Variant) -> bool: return not scroll_id is String or not _whole_nonnegative(best[scroll_id])):
		return null
	held["best"] = {}
	for scroll_id: String in best:
		if content.tianji_data.scrolls.has(scroll_id):
			held.best[scroll_id] = int(best[scroll_id])
	var notes: Variant = saved.get("notes", [])
	if not notes is Array or notes.any(func(entry: Variant) -> bool: return not entry is Dictionary or not _whole_nonnegative(entry.get("day")) or not entry.get("text") is String):
		return null
	held["notes"] = []
	for entry: Dictionary in notes:
		held.notes.append({"day": int(entry.day), "text": str(entry.text)})
	for key: String in ["next_challenge", "defend_day", "gift_year"]:
		if saved.has(key):
			if not _whole_nonnegative(saved[key]):
				return null
			held[key] = int(saved[key])
	return {"world": kept_boards, "player": held if not saved.is_empty() else {}}

## A 秘境's state (mijing.gd), normalized (optional: journeys before them have none), or null when
## malformed. One inside a realm no longer in the content cannot be restored.
static func _valid_mijing(content, saved: Variant) -> Variant:
	if not saved is Dictionary:
		return null
	var realms: Dictionary = content.mijing_data.realms
	var inside: Variant = saved.get("inside", "")
	if not inside is String or (not inside.is_empty() and not realms.has(inside)):
		return null
	var held := {}
	for key: String in ["inside", "from", "way", "room"]:
		if not saved.get(key, "") is String:
			return null
		if saved.has(key):
			held[key] = str(saved[key])
	if not inside.is_empty() and not content.locations.has(str(saved.get("from", ""))):
		return null
	for key: String in ["day", "wins"]:
		if not _whole_nonnegative(saved.get(key, 0)):
			return null
		if saved.has(key):
			held[key] = int(saved[key])
	if not saved.get("ally", false) is bool:
		return null
	if saved.has("ally"):
		held["ally"] = bool(saved.ally)
	var beats: Variant = saved.get("beats", [])
	if not beats is Array or beats.any(func(event_id: Variant) -> bool: return not event_id is String):
		return null
	if saved.has("beats"):
		held["beats"] = beats.duplicate()
	var haul: Variant = _valid_haul(content, saved.get("haul", {}))
	if haul == null:
		return null
	if saved.has("haul"):
		held["haul"] = haul
	for key: String in ["opened", "offered"]:
		var days: Variant = saved.get(key, {})
		if not days is Dictionary or days.keys().any(func(realm_id: Variant) -> bool: return not realm_id is String or not _whole_nonnegative(days[realm_id])):
			return null
		if saved.has(key):
			held[key] = {}
			for realm_id: String in days:
				if realms.has(realm_id):
					held[key][realm_id] = int(days[realm_id])
	var meet: Variant = saved.get("meet", {})
	if not meet is Dictionary or (not meet.is_empty() and (not meet.get("name") is String or not meet.get("title") is String or not content.sects.has(str(meet.get("sect", ""))) or not _whole_nonnegative(meet.get("stage")) or int(meet.stage) > 3 or not (meet.get("power") is float or meet.get("power") is int))):
		return null
	if saved.has("meet"):
		held["meet"] = meet.duplicate()
		if not meet.is_empty():
			held.meet.stage = int(meet.stage)
			held.meet.power = float(meet.power)
	var out: Variant = saved.get("out", {})
	if not out is Dictionary or (not out.is_empty() and not realms.has(str(out.get("realm", "")))):
		return null
	var out_haul: Variant = _valid_haul(content, out.get("haul", {}))
	if out_haul == null:
		return null
	if saved.has("out"):
		held["out"] = {} if out.is_empty() else {"realm": str(out.realm), "haul": out_haul}
	return held

## The 鬼市's nights (guishi.gd), normalized with only the keys saved, or null when malformed.
static func _valid_guishi(saved: Variant) -> Variant:
	if not saved is Dictionary:
		return null
	var held := {}
	for key: String in ["night", "spent", "contract", "black", "visited"]:
		if saved.has(key):
			if not _whole_nonnegative(saved[key]):
				return null
			held[key] = int(saved[key])
	if saved.has("tail"):
		if not saved.tail is bool:
			return null
		held["tail"] = saved.tail
	if saved.has("bought"):
		if not saved.bought is Array or saved.bought.any(func(index: Variant) -> bool: return not _whole_nonnegative(index)):
			return null
		var bought: Array = []
		for index: Variant in saved.bought:
			bought.append(int(index))
		held["bought"] = bought
	return held

## 无相宝录 (wuxiang.gd), normalized with only the keys saved, or null when malformed. Journeys from before
## it hold none.
static func _valid_wuxiang(content, saved: Variant) -> Variant:
	if not saved is Dictionary:
		return null
	var held := {}
	var pages := int(content.wuxiang_data.get("pages", []).size())
	if saved.has("pages"):
		if not saved.pages is Dictionary or saved.pages.keys().any(func(n: Variant) -> bool: return not str(n).is_valid_int() or int(str(n)) < 1 or int(str(n)) > pages or not saved.pages[n] in Wuxiang.STATES):
			return null
		var kept := {}
		for n: Variant in saved.pages:
			kept[str(int(str(n)))] = str(saved.pages[n])
		held["pages"] = kept
	if saved.has("rewarded"):
		if not saved.rewarded is Array or saved.rewarded.any(func(n: Variant) -> bool: return not _whole_nonnegative(n) or int(n) < 1 or int(n) > pages):
			return null
		var given: Array = []
		for n: Variant in saved.rewarded:
			if not int(n) in given:
				given.append(int(n))
		held["rewarded"] = given
	for key: String in ["stash", "blade", "gambled"]:
		if saved.has(key):
			if not _whole_nonnegative(saved[key]):
				return null
			held[key] = int(saved[key])
	if held.get("blade", 0) > content.wuxiang_data.get("blades", []).size():
		return null
	for key: String in ["met", "ally", "sold"]:
		if saved.has(key):
			if not saved[key] is bool:
				return null
			held[key] = saved[key]
	if saved.has("favor"):
		if not content.sect_data.get("sects", {}).has(saved.favor):
			return null
		held["favor"] = str(saved.favor)
	if saved.has("ending"):
		if not saved.ending in Wuxiang.ENDINGS:
			return null
		held["ending"] = str(saved.ending)
	return held

## Things gathered in a 秘境: {item: count}, unknown items dropped; null when malformed.
static func _valid_haul(content, haul: Variant) -> Variant:
	if not haul is Dictionary or haul.keys().any(func(item_id: Variant) -> bool: return not item_id is String or not _whole_nonnegative(haul[item_id])):
		return null
	var kept := {}
	for item_id: String in haul:
		if not content.item(item_id).is_empty() and int(haul[item_id]) > 0:
			kept[item_id] = int(haul[item_id])
	return kept

## Recipes known, brews made, 丹毒 and the 灵田, normalized (optional: journeys before them know no
## recipe and have no field yet), or null when malformed. Recipes no longer in the content are dropped;
## a plot whose herb no longer grows is cleared.
static func _valid_alchemy(content, saved_player: Dictionary, day: int) -> Variant:
	var result := {}
	var recipes: Variant = saved_player.get("recipes", [])
	if not recipes is Array:
		return null
	var known: Array = []
	for recipe_id: Variant in recipes:
		if not recipe_id is String:
			return null
		if content.alchemy_data.recipes.has(recipe_id) and not recipe_id in known:
			known.append(recipe_id)
	result["recipes"] = known
	var practice: Variant = _valid_counts(saved_player.get("practice", {}))
	if practice == null:
		return null
	result["practice"] = practice
	var toxin: Variant = saved_player.get("toxin", 0)
	var toxin_day: Variant = saved_player.get("toxin_day", day)
	if not _whole_nonnegative(toxin) or int(toxin) > int(content.alchemy_data.toxin.limit) or not _whole_nonnegative(toxin_day) or int(toxin_day) > day:
		return null
	result["toxin"] = int(toxin)
	result["toxin_day"] = int(toxin_day)
	var field: Variant = saved_player.get("field", {"grade": 0, "plots": []})
	if not field is Dictionary or not _whole_nonnegative(field.get("grade")) or int(field.grade) >= content.alchemy_data.field.grades.size() or not field.get("plots") is Array:
		return null
	if field.plots.size() > int(content.alchemy_data.field.grades[int(field.grade)].plots):
		return null
	var plots: Array = []
	for plot: Variant in field.plots:
		if not plot is Dictionary:
			return null
		if plot.is_empty():
			plots.append({})
			continue
		if not plot.get("herb") is String or not _whole_nonnegative(plot.get("day")) or int(plot.day) > day:
			return null
		plots.append({"herb": plot.herb, "day": int(plot.day)} if content.item(plot.herb).has("grow") else {})
	result["field"] = {"grade": int(field.grade), "plots": plots}
	return result

## The saved talents and flaws ({"talents", "flaws"}), {} when the save has none yet, or null when they
## are malformed: unknown ids, a flaw among the talents or the other way round, or the same one twice.
static func _valid_talents(content, saved_player: Dictionary) -> Variant:
	if not saved_player.has("talents"):
		return {}
	var result := {}
	for key: String in ["talents", "flaws"]:
		var list: Variant = saved_player.get(key, [])
		if not list is Array:
			return null
		var kept: Array = []
		for id: Variant in list:
			if not content.is_talent(id) or Talents.is_flaw(content, id) != (key == "flaws") or id in kept:
				return null
			kept.append(id)
		result[key] = kept
	return result

## Normalized copy of saved event progress, or null. Progress for events no longer in content is kept.
static func _valid_event_progress(data: Dictionary) -> Variant:
	var result := {}
	for event_id: Variant in data:
		var progress: Variant = data[event_id]
		if not event_id is String or not progress is Dictionary or not str(progress.get("state", "")) in ["", "completed", "expired"]:
			return null
		var normalized := {"state": str(progress.get("state", ""))}
		for key: String in ["count", "last_day", "last_occurrence", "reminded"]:
			if not _whole_signed(progress.get(key)) or int(progress[key]) < -1:
				return null
			normalized[key] = int(progress[key])
		if progress.has("applied"):
			if not progress.applied is bool:
				return null
			normalized["applied"] = progress.applied
		result[event_id] = normalized
	return result

static func _valid_people(content, data: Dictionary, day: int) -> Variant:
	var result := {}
	for person_id: Variant in data:
		var person: Variant = data[person_id]
		if not person_id is String or not person is Dictionary or not person.get("met") is bool or not _whole_signed(person.get("relation")):
			return null
		if absi(int(person.relation)) > content.FAVOR_MAX or not person.get("last") is Dictionary:
			return null
		if not _whole_signed(person.get("absent_until")) or int(person.absent_until) < -1 or not _whole_nonnegative(person.get("talks")):
			return null
		var last := {}
		for option_id: Variant in person.last:
			if not option_id is String or not _whole_nonnegative(person.last[option_id]):
				return null
			last[option_id] = int(person.last[option_id])
		# When and where they were met: optional (saves before 2026-10-12 lack it), -1 and "" when unknown.
		var met_day: Variant = person.get("met_day", -1)
		var met_place: Variant = person.get("met_place", "")
		if not _whole_signed(met_day) or int(met_day) < -1 or int(met_day) > day or not met_place is String or not (met_place.is_empty() or content.locations.has(met_place)):
			return null
		result[person_id] = {"met": person.met, "relation": int(person.relation), "last": last, "absent_until": int(person.absent_until), "talks": int(person.talks), "met_day": int(met_day), "met_place": met_place}
		var mourned: Variant = person.get("mourned", false)
		if mourned is bool and mourned:
			result[person_id].mourned = true
		# Whether 传音符 were exchanged: optional, saves before version 12 lack it.
		var sound: Variant = person.get("sound", false)
		if not sound is bool:
			return null
		if sound:
			result[person_id]["sound"] = true
	return result

## Normalized storyline progress, or null when malformed. Progress of storylines no longer in the
## content is dropped.
static func _valid_storylines(content, data: Variant, day: int) -> Variant:
	if not data is Dictionary:
		return null
	var result := {}
	for story_id: Variant in data:
		var saved: Variant = data[story_id]
		if not story_id is String or not saved is Dictionary or not str(saved.get("state", "")) in ["active", "done", "closed"]:
			return null
		if not _whole_nonnegative(saved.get("step")) or not _whole_nonnegative(saved.get("since")) or int(saved.since) > day or not saved.get("begun") is bool:
			return null
		var base: Variant = _valid_counts(saved.get("base", {}))
		if base == null:
			return null
		if not content.storylines.has(story_id):
			continue
		var steps := int(content.storylines[story_id].steps.size())
		var known_steps := maxi(steps, SaveMigration.LEGACY_STORY_STEPS.get(story_id, []).size())
		if int(saved.step) > known_steps or (saved.state == "active" and int(saved.step) >= known_steps):
			return null
		var index := int(saved.step)
		var step_id: Variant = saved.get("step_id", null)
		if step_id != null and not step_id is String:
			return null
		if step_id == null:
			var legacy: Array = SaveMigration.LEGACY_STORY_STEPS.get(story_id, [])
			if index < legacy.size():
				step_id = str(legacy[index])
		if saved.state == "done":
			index = steps
		elif step_id != null and not str(step_id).is_empty():
			index = -1
			for i: int in steps:
				if str(content.storylines[story_id].steps[i].id) == str(step_id):
					index = i
					break
			if index < 0:
				return null
		elif saved.state == "active" and step_id != null:
			return null
		result[story_id] = {"state": saved.state, "step": index, "since": int(saved.since), "begun": saved.begun, "base": base}
	return result

## Normalized 传音, or null when malformed. Letters about storylines no longer in the content are dropped.
static func _valid_letters(content, data: Variant, day: int) -> Variant:
	if not data is Array:
		return null
	var result: Array = []
	for letter: Variant in data:
		if not letter is Dictionary or not letter.get("npc") is String or not _whole_nonnegative(letter.get("day")) or int(letter.day) > day or not letter.get("read") is bool:
			return null
		if not content.people.has(letter.npc):
			continue
		if letter.has("story"):
			if not letter.story is String or not letter.get("step") is String:
				return null
			if not content.storylines.has(letter.story):
				continue
			result.append({"npc": letter.npc, "day": int(letter.day), "read": letter.read, "story": letter.story, "step": letter.step})
		elif letter.get("kind") is String:
			result.append({"npc": letter.npc, "day": int(letter.day), "read": letter.read, "kind": letter.kind})
		else:
			return null
	return result

## A dictionary of names to whole non-negative counts (deeds), normalized, or null.
static func _valid_counts(data: Variant) -> Variant:
	if not data is Dictionary:
		return null
	var result := {}
	for key: Variant in data:
		if not key is String or not _whole_nonnegative(data[key]):
			return null
		result[key] = int(data[key])
	return result

static func _whole_nonnegative(value: Variant) -> bool:
	return _whole_signed(value) and float(value) >= 0.0

static func _whole_signed(value: Variant) -> bool:
	if not (value is int or value is float):
		return false
	return is_finite(float(value)) and float(value) == floor(float(value)) and absf(float(value)) <= LIMIT

## The saved techniques and equipment, keeping only what the content still knows. {} when malformed.
## Unknown ids are dropped instead of rejecting the save, so retired content cannot lock a journey.
static func _valid_loadout(content, saved_player: Dictionary) -> Dictionary:
	for key: String in ["learned", "arts", "methods"]:
		if not saved_player.get(key) is Array:
			return {}
	if not saved_player.get("equipment") is Dictionary:
		return {}
	var learned: Array = []
	for technique_id: Variant in saved_player.learned:
		if technique_id is String and not content.technique(technique_id).is_empty() and not technique_id in learned:
			learned.append(technique_id)
	var arts: Array = []
	var methods: Array = []
	for pair: Array in [["arts", arts, "art", int(content.rules.art_slots)], ["methods", methods, "method", int(content.rules.method_slots)]]:
		for technique_id: Variant in saved_player[pair[0]]:
			if technique_id in learned and content.technique(technique_id).slot == pair[2] and not technique_id in pair[1] and pair[1].size() < pair[3]:
				pair[1].append(technique_id)
	if arts.is_empty():
		# Older journeys knew exactly their lineage's three arts.
		var lineage: String = saved_player.get("sect", "wanderer") if content.sects.has(saved_player.get("sect", "")) else "wanderer"
		for skill_id: String in content.sects[lineage].skills:
			if not skill_id in learned:
				learned.append(skill_id)
			arts.append(skill_id)
	# Journeys from before the 气 arts know them too: they cast from any element's qi, so a hand drawn
	# from one spirit root alone is never left without an art. They take free slots.
	for skill_id: String in content.sects.wanderer.skills:
		if not skill_id in learned:
			learned.append(skill_id)
			if arts.size() < int(content.rules.art_slots):
				arts.append(skill_id)
	# 宝物 instances (optional: journeys before 祭炼 hold none). Retired types are dropped.
	var saved_gear: Variant = saved_player.get("gear", {})
	var serial: Variant = saved_player.get("gear_serial", 0)
	if not saved_gear is Dictionary or not _whole_nonnegative(serial):
		return {}
	var gear := {}
	for item_id: Variant in saved_gear:
		var held: Variant = saved_gear[item_id]
		if not item_id is String or not Gear.is_instance(item_id) or not item_id.trim_prefix(Gear.PREFIX).is_valid_int() or int(item_id.trim_prefix(Gear.PREFIX)) > int(serial):
			return {}
		if not held is Dictionary or not held.get("type") is String or not _whole_nonnegative(held.get("refine")) or int(held.refine) > MAX_REFINE:
			return {}
		if held.has("sigil") and (not held.sigil is String or not content.formulation_data.sigils.has(held.sigil)):
			return {}
		if not content.equipment(held.type).is_empty():
			if held.has("sigil") and content.equipment(held.type).slot != "weapon":
				return {}
			gear[item_id] = {"type": held.type, "refine": int(held.refine)}
			if held.has("sigil"):
				gear[item_id].sigil = str(held.sigil)
	var equipment := {}
	for slot: String in content.equipment_data.slots:
		var worn: Variant = saved_player.equipment.get(slot, "")
		var piece: Dictionary = Gear.item_in(content, gear, str(worn)) if worn is String else {}
		equipment[slot] = worn if not piece.is_empty() and piece.slot == slot and not worn in equipment.values() else ""
	# 功法层数 (layers.gd), optional: a technique without a record (journeys before layers were kept) is
	# held as it always was, at the realm's cap. Records of techniques no longer known are dropped.
	var layers := {}
	var saved_layers: Variant = saved_player.get("layers", {})
	if not saved_layers is Dictionary:
		return {}
	for technique_id: Variant in saved_layers:
		var entry: Variant = saved_layers[technique_id]
		if not technique_id is String or not entry is Dictionary or not _whole_nonnegative(entry.get("layer")) or int(entry.layer) < 1 or not _whole_nonnegative(entry.get("practice")):
			return {}
		# A weapon's own art is kept by its record alone, never learned (loadout.gd).
		if technique_id in learned or not str(content.skills.get(technique_id, {}).get("weapon", "")).is_empty():
			# Content may have changed the layers since: clamp rather than lock the journey.
			layers[technique_id] = {"layer": mini(int(entry.layer), int(content.technique(technique_id).layers)), "practice": int(entry.practice)}
	return {"learned": learned, "arts": arts, "methods": methods, "equipment": equipment, "gear": gear, "gear_serial": int(serial), "layers": layers}

## Normalized accepted commissions, or null when malformed. Quests of retired kinds are dropped.
static func _valid_quests(content, data: Variant) -> Variant:
	if not data is Array:
		return null
	var result: Array = []
	for quest: Variant in data:
		if not quest is Dictionary or not quest.get("key") is String or not quest.get("reward") is Dictionary:
			return null
		for key: String in ["count", "days", "deadline", "progress"]:
			if not _whole_nonnegative(quest.get(key)):
				return null
		if not content.commission_data.templates.has(quest.get("kind", "")) or not content.commission_data.boards.has(quest.get("board", "")):
			continue
		if quest.has("item") and content.item(str(quest.item)).is_empty():
			continue
		if quest.has("enemy") and not content.enemies.has(quest.enemy):
			continue
		if quest.has("place") and not content.locations.has(quest.place):
			continue
		var wanted: Variant = quest.get("wanted", {})
		if not wanted is Dictionary or (quest.has("wanted") and (not wanted.get("name") is String or not content.enemies.has(wanted.get("enemy", "")) or not content.locations.has(wanted.get("place", "")) or not wanted.get("twist") is bool or not _whole_nonnegative(wanted.get("wait_until", 0)))):
			continue
		# A 历练帖 keeps the season it counts toward (optional).
		if quest.has("season") and not _whole_nonnegative(quest.season):
			continue
		# A 客卿's 差遣 names its sect (optional).
		if quest.has("guest") and not content.guest_data.get("sects", {}).has(quest.guest):
			continue
		var normalized: Dictionary = quest.duplicate(true)
		for key: String in ["count", "days", "deadline", "progress"]:
			normalized[key] = int(normalized[key])
		if normalized.has("season"):
			normalized.season = int(normalized.season)
		if normalized.has("wanted") and normalized.wanted.has("wait_until"):
			normalized.wanted.wait_until = int(normalized.wanted.wait_until)
		# Commissions from before contribution pay none.
		normalized.reward = {"stones": int(quest.reward.get("stones", 0)), "xp": int(quest.reward.get("xp", 0)), "contribution": int(quest.reward.get("contribution", 0))}
		result.append(normalized)
	return result
