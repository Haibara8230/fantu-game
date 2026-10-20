extends RefCounted
## 飞升 (docs/GAME_OUTLINE.md 8.3, 22): at 化神 the player settles what becomes of 照川城's 阵枢 — one of
## three ways (`routes`: 修复重开, 替换旧阵, 自寻通路, each a world flag) — and the crossing at 白鹭渡
## opens to them (ascension_open). There, at any stage of 化神, they weather the 飞升天劫; struck down,
## they heal for a while (player.injury_until) and may try again. Weathered, the life ends in ascension
## (ended.route names the way). Whether the truth was made known is told with it (rules `truth`).
## Operates on a Session; the terms live in data/world.json rules.ascension.

static func rules(s) -> Dictionary:
	return s.content.rules.ascension

## The way the player settled on, or "" before the choice.
static func route(s) -> String:
	for route_id: String in rules(s).routes:
		if s.has_flag(str(rules(s).routes[route_id].flag)):
			return route_id
	return ""

## Why the player cannot ascend at the crossing now, or "".
static func block(s) -> String:
	var top: int = s.content.realms.size() - 1
	if int(s.player.realm) < top:
		return "唯有%s方能踏上天河渡桥。" % s.content.realm(top).name
	if route(s).is_empty():
		return "照川城的阵枢还没有定下怎么处理，天河没有为你打开的路。"
	if s.Breakthrough.injured(s):
		return "上回渡劫的伤还没有好。"
	return ""

## Steps onto the crossing: the 飞升天劫 comes down.
static func attempt(s) -> String:
	var reason := block(s)
	if not reason.is_empty():
		return reason
	var text: String = s.log_event("ascension_trial", {"route": route(s)}, true)
	s.Combat.begin_tribulation(s, str(rules(s).tribulation))
	s.battle.ascension = route(s)
	s.changed.emit()
	return text

## The 飞升天劫 is over (combat.gd): weathered, the life ends in ascension; struck down, a year to heal.
static func over(s, route_id: String, won: bool) -> String:
	if won:
		s.ended = {"kind": "ascension", "day": int(s.world.day), "route": route_id}
		var text: String = s.log_event("ascended", {"age": s.age(), "route": route_id}, true)
		s.changed.emit()
		return text
	s.player["injury_until"] = int(s.world.day) + int(rules(s).injury_days)
	return s.finish(s.log_event("ascension_failed", {"days": int(rules(s).injury_days)}, true))

## The closing words of an ascension: the way taken, and whether the truth was told.
static func ending_text(s) -> String:
	var route_id := str(s.ended.get("route", ""))
	var words: Array[String] = []
	if rules(s).routes.has(route_id):
		words.append(str(rules(s).routes[route_id].ending))
	for flag: String in rules(s).truth:
		if s.has_flag(flag):
			words.append(str(rules(s).truth[flag]))
	return "".join(words)
