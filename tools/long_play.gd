extends SceneTree
## A long life played headless by a plain policy, to measure what a long journey costs: the save's
## size and the time actions take as the years pile up. Retreats in long spans, gathers and sells now
## and then, duels, breaks through when ready, and lives on to the end of its years.
## Usage: godot --headless --path . --script res://tools/long_play.gd
const Session = preload("res://scripts/core/session.gd")

func _initialize() -> void:
	var game := Session.new()
	game.encounters_enabled = true
	game.new_game("长生", 2026, ["metal", "wood", "fire"], "plain")
	var started := Time.get_ticks_msec()
	var slowest := 0
	var slowest_what := ""
	var actions := 0
	var marks := [50, 100, 200, 300, 400, 480]
	while game.ended.is_empty() and actions < 20000:
		actions += 1
		var before := Time.get_ticks_msec()
		var what := _act(game)
		var took := Time.get_ticks_msec() - before
		if took > slowest:
			slowest = took
			slowest_what = "%s (year %d)" % [what, int(game.world.day) / 360]
		var year := int(game.world.day) / 360
		if not marks.is_empty() and year >= int(marks[0]):
			var size := JSON.stringify(game.snapshot()).length()
			print("LONG year %d: %s, save %d KB, %d chronicle entries, %d actions, %d s so far" % [year, game.realm_name(), size / 1024, game.chronicle.entries.size(), actions, (Time.get_ticks_msec() - started) / 1000])
			marks.pop_front()
	var final := JSON.stringify(game.snapshot()).length()
	print("LONG end (%s): year %d, %s, save %d KB, %d actions in %d s; slowest action %d ms: %s" % [str(game.ended.get("kind", "")), int(game.world.day) / 360, game.realm_name(), final / 1024, actions, (Time.get_ticks_msec() - started) / 1000, slowest, slowest_what])
	var reload := Session.new()
	var before_load := Time.get_ticks_msec()
	print("LONG reload: %s in %d ms" % [str(reload.restore(JSON.parse_string(JSON.stringify(game.snapshot())))), Time.get_ticks_msec() - before_load])
	quit(0)

## One plain step; returns what was done.
func _act(game) -> String:
	if not game.pending_event.is_empty():
		var choices: Array = game.pending_definition().get("choices", [])
		game.choose_event(str(choices.back().id) if not choices.is_empty() else "")
		if not game.pending_event.is_empty():
			game.pending_event = {}
		return "event"
	if not game.battle.is_empty():
		game.plain_turn()
		return "duel"
	if not game.auction.is_empty():
		game.auction_leave()
		return "auction"
	if game.at_brink():
		game.accept_end()
		return "end"
	if game.has_flag("ascension_open") and game.ascend_block().is_empty():
		game.travel("ferry")
		game.act("ascend")
		return "ascend"
	if game.player.location != "sect":
		game.travel("sect")
		return "travel"
	if game.at_bottleneck():
		game.player.insight = game.insight_needed()
		game.settle_stage()
		return "bottleneck"
	if not game.next_breakthrough().is_empty() and int(game.player.xp) >= int(game.next_breakthrough().xp):
		var pill: String = game.Breakthrough.pill_of(game)
		game.set_item_count(pill, 1)
		game.player.mind = maxi(int(game.player.mind), game.Breakthrough.demon_mind(game))
		game.act("breakthrough")
		return "breakthrough"
	if game.retreat_efficiency() < 100 or game.mind_percent() < 100:
		game.travel("wild")
		game.act("gather")
		game.travel("market")
		game.act("sell")
		game.player.mind = int(game.player.mind) + 2
		return "gather"
	if game.at_xp_cap():
		game.wait(360)
		return "wait"
	game.cultivate(game.retreat_cap())
	return "retreat"
