extends RefCounted
## 天南散修盟 (docs/SIDEQUESTS_DRAFT_20261020.md 2.2 散修联盟): a loose alliance of wanderers, not a
## sect. A 散修 joins or leaves at any branch (分舵: a city spot with the `league` action) at will, and
## joining a sect leaves it. A member reads the branch's 青灯簿 besides the city's board (commissions
## that pay 声望, standing), rests free in the branch's 静室 and rents it by the month (a `lodging` with
## `league`, cultivation.gd); members of the realm and standing a 灵地 asks (lodging `realm`, `standing`)
## rent that too. One beaten far from any inn is carried to the branch they joined at, and nothing is
## taken from the purse. A 副盟主 (story effect league: deputy) pays no rent at the branches; one the
## alliance casts out (league: ban) may not join again. Operates on a Session; the terms live in
## data/league.json.
## player.league: {"member", "branch", "since", "standing", "deputy", "banned"}; the world flag
## league_member stands while a member, so the branches' rooms open by it.

const FLAG := "league_member"

static func data(s) -> Dictionary:
	return s.content.league_data

static func state(s) -> Dictionary:
	return s.player.get("league", {})

static func member(s) -> bool:
	return bool(state(s).get("member", false))

static func standing(s) -> int:
	return int(state(s).get("standing", 0))

## A 副盟主 while still in the alliance.
static func deputy(s) -> bool:
	return member(s) and bool(state(s).get("deputy", false))

static func banned(s) -> bool:
	return bool(state(s).get("banned", false))

## The branch's name at `location_id`, or "" where the alliance has none.
static func branch_name(s, location_id: String) -> String:
	return str(data(s).get("branches", {}).get(location_id, ""))

## The location of the branch here, or "".
static func branch_here(s) -> String:
	var here := str(s.player.location)
	return here if not branch_name(s, here).is_empty() and s.available_here("league") else ""

## Where a member beaten far from any inn is carried: the branch they joined at.
static func home(s) -> String:
	return str(state(s).get("branch", ""))

## Whether a room the alliance lets (a 灵地) takes the player: its realm and standing.
static func room_open(s, let: Dictionary) -> bool:
	return int(s.player.realm) >= int(let.get("realm", 0)) and standing(s) >= int(let.get("standing", 0))

## Why the player cannot join here and now, or "".
static func block(s) -> String:
	var reason: String = s.blocked()
	if not reason.is_empty():
		return reason
	if branch_here(s).is_empty():
		return "此地没有%s的分舵。" % data(s).name
	if member(s):
		return "你已是%s中人。" % data(s).name
	if banned(s):
		return "%s已不认你。" % data(s).name
	if not s.affiliation().is_empty():
		return "已拜入宗门的人不能入盟。"
	return ""

static func join(s) -> String:
	var reason := block(s)
	if not reason.is_empty():
		return reason
	var held := state(s).duplicate()
	held.member = true
	held.branch = branch_here(s)
	held.since = int(s.world.day)
	s.player["league"] = held
	s.world.flags[FLAG] = true
	return s.finish(s.log_event("league_join", {"branch": branch_name(s, str(held.branch))}, true))

## Leaves the alliance; its commissions go with it. `quiet` returns the chronicle text without ending
## the action (a sect joined leaves it).
static func leave(s, quiet: bool = false) -> String:
	if not member(s):
		return "你不是%s中人。" % data(s).name
	_drop(s)
	var text: String = s.log_event("league_sect" if quiet else "league_leave", {}, true)
	return text if quiet else s.finish(text)

static func _drop(s) -> void:
	s.player.league.member = false
	s.world.flags.erase(FLAG)
	for quest: Dictionary in s.player.get("quests", []).duplicate():
		if bool(s.content.commission_data.boards.get(str(quest.board), {}).get("league", false)):
			s.player.quests.erase(quest)

## Adds standing; returns its chronicle text ("" for none or a non-member).
static func gain(s, amount: int) -> String:
	if amount <= 0 or not member(s):
		return ""
	s.player.league.standing = standing(s) + amount
	return s.log_event("league_standing", {"amount": amount, "standing": standing(s)})

## A story's word on the alliance (events.gd effect `league`): "deputy" makes the player 副盟主,
## "ban" casts them out for good.
static func apply(s, what: String) -> String:
	match what:
		"deputy":
			if member(s):
				s.player.league.deputy = true
				return s.log_event("league_deputy", {}, true)
		"ban":
			if member(s):
				_drop(s)
			var held := state(s).duplicate()
			held.banned = true
			held.deputy = false
			s.player["league"] = held
			return s.log_event("league_banned", {}, true)
	return ""
