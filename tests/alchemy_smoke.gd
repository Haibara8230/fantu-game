extends SceneTree
## 炼丹, 丹毒 and the 灵田: recipes, the 药引's balance, furnaces and talismans, the fire, fine pills where
## pills are asked for, toxin, the field and its grades, saves and their migration, and static checks.
const Session = preload("res://scripts/core/session.gd")
const Content = preload("res://scripts/core/content.gd")
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
	_recipes()
	_brewing()
	_furnaces()
	_market()
	_determinism()
	_toxin()
	_fine_pills()
	_field()
	_forging()
	_saves()
	_static_checks()
	print("ALCHEMY: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

func _game() -> Session:
	var game := Session.new()
	game.encounters_enabled = false
	game.new_game("丹师", 11, ["metal", "wood", "fire"])
	return game

## 炼器: three of one material at the market's 器铺 make a piece at its tier, of the chosen base and
## element; its affixes follow the world and the count; a wrong material or too few are refused.
func _forging() -> void:
	var game := _game()
	game.travel("market")
	check(game.available_here("forge"), "the market's street has a forge")
	game.set_item_count("ore_qinggang", 3)
	game.set_item_count("silk_qing", 3)
	game.player.stones = 100
	var plan := {"material": "ore_qinggang", "base": "sword", "element": "fire"}
	check(game.Forge.block(game, {"material": "silk_qing", "base": "sword", "element": "none"}).contains("打不出"), "silk makes no sword")
	var twin := _game()
	twin.travel("market")
	twin.set_item_count("ore_qinggang", 3)
	twin.player.stones = 100
	var day := int(game.world.day)
	game.forge_item(plan)
	twin.forge_item(plan)
	var made: Array = game.player.items.keys().filter(func(item_id: String) -> bool: return item_id.begins_with("e:sword:2:fire:"))
	check(made.size() == 1 and game.item_count("ore_qinggang") == 0 and int(game.player.stones) == 80 and int(game.world.day) == day + 10, "three 青钢锭 make a 黄阶 fire sword for 20 stones and ten days")
	check(twin.player.items.has(made[0]), "the same world forges the same piece")
	check(game.Forge.block(game, plan).contains("不足"), "without materials nothing is forged")
	check(int(game.player.forged) == 1, "the count of pieces forged is kept")
	var copy := Session.new()
	check(copy.restore(JSON.parse_string(JSON.stringify(game.snapshot()))) and int(copy.player.forged) == 1, "and survives a save")
	game.travel("sect")
	game.set_item_count("ore_qinggang", 3)
	check(game.Forge.block(game, plan).contains("器铺"), "and only at a forge")

func _recipes() -> void:
	var game := _game()
	check(game.content.error_message.is_empty(), "the content with alchemy loads: " + game.content.error_message)
	check(game.known_recipes().is_empty() and game.alchemy_block({"recipe": "liaoshang", "guide": "", "fire": "gentle", "aid": ""}).contains("不会"), "a new journey knows no recipe")
	game.set_item_count("recipe_liaoshang", 1)
	game.use_item("recipe_liaoshang")
	check(game.known_recipes() == ["liaoshang"] and game.item_count("recipe_liaoshang") == 0, "reading a 丹方 teaches its recipe")
	check(game.journal_lines()[-1].contains("研读疗伤丹丹方"), "reading is recorded as reading, not swallowing")
	game.set_item_count("recipe_liaoshang", 1)
	check(game.use_block("recipe_liaoshang").contains("已通晓"), "a known recipe is not read twice")
	game.player.location = "market"
	check(game.buy("recipe_liaoshang").contains("已通晓"), "nor bought again")
	game.player.location = "sect"
	Session.Events.apply(game, [{"recipe": "ningqi"}])
	check(game.known_recipes() == ["liaoshang", "ningqi"] and Session.Events.met(game, {"recipe": "ningqi"}), "an effect can teach a recipe and a condition can ask for one")
	check(game.Alchemy.lean(game, "liaoshang") == "neutral" and game.Alchemy.lean(game, "ningqi") == "hot" and game.Alchemy.guide_nature(game, "ningqi") == "cold" and game.Alchemy.guide_nature(game, "huiqi") == "hot", "main herbs lean, and the 药引 answers the other way")

func _brewing() -> void:
	var game := _game()
	Session.Events.apply(game, [{"recipe": "liaoshang"}, {"recipe": "huiqi"}])
	game.set_item_count("huichun_grass", 4)
	var plan: Dictionary = game.alchemy_plan("liaoshang")
	check(plan.guide == "huichun_grass" and plan.fire == "gentle", "the plan picks a fitting 药引 that is carried")
	var odds: Dictionary = game.alchemy_odds(plan)
	check(int(odds.success) == 70 and int(odds.fine) == 10 and odds.yield == [2, 3] and bool(odds.balanced) and int(odds.days) == 3, "a first brew at the sect's furnace has the recipe's odds")
	game.fortune = {"alchemy": 0.0, "alchemy_fine": 0.99}
	var day := int(game.world.day)
	game.brew(plan)
	var made: int = game.item_count("liaoshang_pill")
	check(made >= 2 and made <= 3 and game.item_count("huichun_grass") == 0 and int(game.world.day) == day + 3, "a brew takes the herbs and the days and gives pills")
	check(int(game.player.practice.liaoshang) == 1 and int(game.alchemy_odds(game.alchemy_plan("liaoshang")).success) == 73, "practice raises the odds a little")
	game.set_item_count("huichun_grass", 4)
	game.fortune = {"alchemy": 0.0, "alchemy_fine": 0.0}
	game.brew(game.alchemy_plan("liaoshang"))
	check(game.item_count("liaoshang_pill_fine") >= 2, "a fine roll makes the whole furnace fine")
	game.set_item_count("ninglu_grass", 2)
	game.set_item_count("huichun_grass", 1)
	var plain: Dictionary = game.alchemy_plan("huiqi")
	var unbalanced: Dictionary = game.alchemy_odds(plain)
	check(plain.guide == "" and not bool(unbalanced.balanced) and unbalanced.yield == [1, 2] and int(unbalanced.fine) == 0, "without a hot 药引 the cold herbs yield one fewer and never fine")
	game.set_item_count("chiyan_flower", 1)
	check(game.alchemy_plan("huiqi").guide == "chiyan_flower" and bool(game.alchemy_odds(game.alchemy_plan("huiqi")).balanced), "a hot herb balances them")
	game.fortune = {"alchemy": 0.99, "alchemy_fine": 0.0}
	var hp := int(game.player.hp)
	var before: int = game.item_count("huiqi_pill")
	game.brew(game.alchemy_plan("huiqi"))
	check(game.item_count("huiqi_pill") == before and game.item_count("chiyan_flower") == 0 and game.item_count("ninglu_grass") == 0 and int(game.player.hp) == hp, "a failed brew under a gentle fire only loses the herbs")
	game.set_item_count("huichun_grass", 4)
	var fierce: Dictionary = game.alchemy_plan("liaoshang")
	fierce.fire = "fierce"
	var risky: Dictionary = game.alchemy_odds(fierce)
	check(int(risky.success) == int(game.alchemy_odds(game.alchemy_plan("liaoshang")).success) - 10 and int(risky.fine) == int(game.alchemy_odds(game.alchemy_plan("liaoshang")).fine) + 15 and bool(risky.burst), "武火 trades odds for fine pills and risks the furnace")
	game.brew(fierce)
	check(int(game.player.hp) == hp - int(game.player.max_hp) * 15 / 100 and game.journal_lines()[-1].contains("炸开"), "a failed 武火 brew bursts the furnace and burns")
	game.set_item_count("huichun_grass", 4)
	game.set_item_count("kongho_fu", 1)
	var bare := int(game.alchemy_odds(fierce).success)
	fierce.aid = "kongho_fu"
	var held: Dictionary = game.alchemy_odds(fierce)
	check(int(held.success) == bare + 15 and not bool(held.burst), "a 控火符 steadies the fire and the odds")
	hp = int(game.player.hp)
	game.brew(fierce)
	check(int(game.player.hp) == hp and game.item_count("kongho_fu") == 0, "and is used up, keeping the furnace whole")
	game.set_item_count("huichun_grass", 2)
	check(game.alchemy_block(game.alchemy_plan("liaoshang")).contains("药材不足"), "a brew needs every herb")
	game.player.location = "town"
	check(game.alchemy_block(game.alchemy_plan("liaoshang")).contains("无处开炉"), "and a furnace")

func _furnaces() -> void:
	var game := _game()
	Session.Events.apply(game, [{"recipe": "liaoshang"}])
	game.set_item_count("huichun_grass", 4)
	var base: Dictionary = game.alchemy_odds(game.alchemy_plan("liaoshang"))
	game.set_item_count("furnace_bronze", 1)
	var bronze: Dictionary = game.alchemy_odds(game.alchemy_plan("liaoshang"))
	check(bronze.furnace.item == "furnace_bronze" and int(bronze.success) == int(base.success) + 8 and int(bronze.fine) == int(base.fine) + 5, "a bronze furnace carried raises the odds")
	game.set_item_count("furnace_purple", 1)
	var purple: Dictionary = game.alchemy_odds(game.alchemy_plan("liaoshang"))
	check(purple.furnace.item == "furnace_purple" and purple.yield == [3, 4], "the best furnace carried is used, and a better one yields more")
	game.player.talents = ["danqi"]
	check(int(game.alchemy_odds(game.alchemy_plan("liaoshang")).success) == 95 and int(game.alchemy_odds(game.alchemy_plan("liaoshang")).fine) == int(purple.fine) + 15, "丹道奇才 brews far surer, up to the most a furnace allows")

func _market() -> void:
	var game := _game()
	Session.Events.apply(game, [{"recipe": "liaoshang"}])
	game.set_item_count("huichun_grass", 4)
	game.player.location = "market"
	check(game.alchemy_block(game.alchemy_plan("liaoshang")).contains("沈墨"), "沈墨's furnace is lent only to someone he knows")
	Session.Events.apply(game, [{"meet": "shen_mo"}])
	var odds: Dictionary = game.alchemy_odds(game.alchemy_plan("liaoshang"))
	check(int(odds.success) == 80 and int(odds.fee) == 10, "at his shop the brew costs a fee and goes surer")
	var stones := int(game.player.stones)
	game.fortune = {"alchemy": 0.0, "alchemy_fine": 0.99}
	game.brew(game.alchemy_plan("liaoshang"))
	check(int(game.player.stones) == stones - 10 and game.item_count("liaoshang_pill") >= 2, "the fee is paid")
	check(game.Sect.goods(game).any(func(good: Dictionary) -> bool: return good.item == "recipe_foundation" and str(good.block).contains("精英")), "the sect gives the 筑基丹 recipe only to its elite")
	Session.Events.apply(game, [{"recipe": "ningqi"}])
	check(game.Sect.goods(game).any(func(good: Dictionary) -> bool: return good.item == "recipe_ningqi" and str(good.block).contains("已通晓")), "nor a recipe already known")

func _determinism() -> void:
	var game := _game()
	Session.Events.apply(game, [{"recipe": "ningqi"}])
	game.set_item_count("huichun_grass", 20)
	game.set_item_count("chiyan_flower", 5)
	game.set_item_count("ninglu_grass", 5)
	var saved: Dictionary = game.snapshot()
	var outcomes: Array = []
	for attempt: int in 2:
		var copy := Session.new()
		copy.encounters_enabled = false
		check(copy.restore(JSON.parse_string(JSON.stringify(saved))), "the journey loads")
		for brew: int in 4:
			copy.brew(copy.alchemy_plan("ningqi"))
		outcomes.append([copy.item_count("ningqi_pill"), copy.item_count("ningqi_pill_fine"), copy.item_count("huichun_grass")])
	check(outcomes[0] == outcomes[1], "loading a save does not change what the furnace gives")

func _toxin() -> void:
	var game := _game()
	game.set_item_count("ningqi_pill", 3)
	game.use_item("ningqi_pill")
	check(game.toxin() == 60 and game.use_block("ningqi_pill").contains("丹毒未消"), "a 凝气丹 leaves 丹毒 that refuses the next")
	check(game.breakthrough_odds(game.breakthrough_plan()).parts.any(func(part: Array) -> bool: return part[0] == "丹毒未清" and int(part[1]) == -6), "丹毒 costs a breakthrough a little")
	game.advance_days(10)
	check(game.toxin() == 40 and game.use_block("ningqi_pill").is_empty(), "it fades by the day")
	game.use_item("ningqi_pill")
	check(game.toxin() == 100, "and adds up to the limit")
	game.set_item_count("ningqi_pill_fine", 1)
	game.advance_days(28)
	check(game.use_block("ningqi_pill").contains("丹毒未消") and game.use_block("ningqi_pill_fine").is_empty(), "a fine pill leaves less of it")
	var hardy := _game()
	hardy.player.talents = ["naiyao"]
	hardy.set_item_count("ningqi_pill", 1)
	hardy.use_item("ningqi_pill")
	check(hardy.toxin() == 42, "耐药 takes in less of it")

func _fine_pills() -> void:
	var game := _game()
	game.set_item_count("foundation_pill", 1)
	game.set_item_count("foundation_pill_fine", 1)
	check(game.pill_count("foundation_pill") == 2 and Session.Events.met(game, {"item_at_least": ["foundation_pill", 2]}), "a fine pill counts as its pill")
	var parts: Array = game.breakthrough_odds({"pills": 2, "treasure": "", "guard": ""}).parts
	check(parts.any(func(part: Array) -> bool: return str(part[0]).contains("上品 1") and int(part[1]) == 25 + 15 + 8), "上品筑基丹 go in first and add more")
	check(game.breakthrough_block({"pills": 2, "treasure": "", "guard": ""}).contains("突破需修至"), "both count toward the pills a breakthrough asks")
	game.Inventory.remove_family(game, "foundation_pill", 1, true)
	check(game.item_count("foundation_pill_fine") == 0 and game.item_count("foundation_pill") == 1, "a breakthrough spends the fine ones first")
	game.set_item_count("liaoshang_pill_fine", 2)
	game.Inventory.remove_family(game, "liaoshang_pill", 1)
	check(game.item_count("liaoshang_pill_fine") == 1, "a delivery takes fine pills when no plain ones are left")
	game.player.hp = 10
	game.use_item("liaoshang_pill_fine")
	check(int(game.player.hp) == 80, "a fine healing pill heals more")

func _field() -> void:
	var game := _game()
	check(not game.available_here("field") and not game.Alchemy.field_open(game), "an outer disciple has no field")
	game.player.rank = game.Sect.rank_index(game, "inner")
	check(game.available_here("field") and game.field_plots().size() == 2, "an inner disciple's 洞府 has the plainest field")
	check(game.plant(0, "huichun_grass").contains("没有"), "planting takes a herb")
	game.set_item_count("huichun_grass", 1)
	game.plant(0, "huichun_grass")
	check(game.field_plots()[0].herb == "huichun_grass" and game.item_count("huichun_grass") == 0, "a herb is planted")
	check(game.plant(0, "huichun_grass").contains("种着"), "one herb to a plot")
	game.set_item_count("lingzhi", 1)
	check(game.plant(1, "lingzhi").contains("种不活"), "a 百年灵芝 cannot be grown")
	game.advance_days(29)
	check(game.harvest(0).contains("尚未长成"), "nothing comes before it ripens")
	game.advance_days(1)
	game.harvest(0)
	check(game.item_count("huichun_grass") == 3 and game.field_plots()[0].is_empty(), "a ripe plot gives its herbs")
	check(game.Alchemy.upgrade_block(game).contains("须修至"), "a better field asks a higher stage")
	game.player.realm = 1
	game.player.stage = 1
	game.player.stones = 300
	game.player.contribution = 100
	game.upgrade_field()
	check(game.field_plots().size() == 3 and int(game.player.stones) == 0 and int(game.player.contribution) == 0, "the field is improved for stones and contribution")
	game.set_item_count("chiyan_flower", 1)
	game.plant(2, "chiyan_flower")
	check(game.Alchemy.ripe_day(game, game.field_plots()[2]) == int(game.world.day) + 48 and game.Alchemy.harvest_count(game, game.field_plots()[2]) == 4, "a better field grows faster and yields more")
	game.player.location = "town"
	check(game.harvest(2).contains("洞府"), "the field is tended at the 洞府")

func _saves() -> void:
	var game := _game()
	Session.Events.apply(game, [{"recipe": "liaoshang"}])
	game.player.rank = game.Sect.rank_index(game, "inner")
	game.set_item_count("huichun_grass", 2)
	game.plant(1, "huichun_grass")
	game.set_item_count("ningqi_pill", 1)
	game.use_item("ningqi_pill")
	var copy := Session.new()
	check(copy.restore(JSON.parse_string(JSON.stringify(game.snapshot()))) and copy.snapshot() == game.snapshot(), "recipes, practice, 丹毒 and the field save and load")
	var old: Dictionary = JSON.parse_string(JSON.stringify(game.snapshot()))
	old.version = 14
	for key: String in ["recipes", "practice", "toxin", "toxin_day", "field"]:
		old.player.erase(key)
	old.player.cooldowns["use:ningqi_pill"] = int(old.world.day) + 10
	var migrated := Session.new()
	check(migrated.restore(old) and migrated.toxin() == 60 and not migrated.player.cooldowns.has("use:ningqi_pill"), "a pill's waiting days become as much 丹毒")
	check(migrated.known_recipes().is_empty() and migrated.player.field.plots.is_empty() and migrated.use_block("ningqi_pill").contains("行囊里没有"), "older journeys know no recipe and have an empty field")
	# Genuine version 14 save made by the code before alchemy: a 凝气丹 taken on day 9, the next due on day 39.
	var v14 := Session.new()
	v14.encounters_enabled = false
	check(v14.restore(JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/v14_pill_cooldown.json"))) and v14.snapshot().version == Session.SAVE_VERSION, "a version 14 save migrates")
	check(v14.toxin() == 100 and v14.use_block("ningqi_pill").contains("丹毒未消") and v14.player.cooldowns.is_empty(), "its pill's thirty days become a full 丹毒")
	v14.advance_days(29)
	check(not v14.use_block("ningqi_pill").is_empty(), "the next pill still waits until the day it was due")
	v14.advance_days(1)
	check(v14.use_block("ningqi_pill").is_empty(), "and is taken on that day")
	var bad: Dictionary = JSON.parse_string(JSON.stringify(game.snapshot()))
	bad.player.field.plots = [{}, {}, {}]
	check(not Session.new().restore(bad), "more plots than the field has are rejected")
	bad = JSON.parse_string(JSON.stringify(game.snapshot()))
	bad.player.toxin = 500
	check(not Session.new().restore(bad), "toxin beyond the limit is rejected")
	bad = JSON.parse_string(JSON.stringify(game.snapshot()))
	bad.player.recipes.append("phoenix")
	var dropped := Session.new()
	check(dropped.restore(bad) and dropped.known_recipes() == ["liaoshang"], "recipes no longer in the content are dropped")

func _broken(change: Callable) -> String:
	var content := Content.new()
	content.load_data()
	change.call(content)
	return content._validate()

func _static_checks() -> void:
	var cards = load("res://scripts/ui/talent_cards.gd")
	check(Session.Talents.MODIFIERS.all(func(key: String) -> bool: return cards.WORDS.has(key)) and cards.effects_text({"alchemy": 30}) == "炼丹成功率 +30%", "every talent modifier has words on the talent cards")
	check(_broken(func(c) -> void: c.alchemy_data.recipes.liaoshang.main = {"moonstone": 2}).contains("主药"), "unknown main herbs reported")
	check(_broken(func(c) -> void: c.items.huichun_grass.erase("nature")).contains("药性"), "every herb has a nature")
	check(_broken(func(c) -> void: c.alchemy_data.recipes.huiqi.fine = "liaoshang_pill_fine").contains("丹药"), "a recipe's fine pill belongs to its pill")
	check(_broken(func(c) -> void: c.locations.sect.spots[2].requires_rank = "patriarch").contains("宗门身份"), "a spot kept for an unknown rank reported")
	check(_broken(func(c) -> void: c.alchemy_data.places.erase("market")).contains("丹炉"), "a place with a furnace needs its numbers")
	check(_broken(func(c) -> void: c.items.huiqi_pill.use = [{"recipe": "phoenix"}]).contains("效果无效"), "unknown recipes in effects reported")
	check(_broken(func(c) -> void: c.alchemy_data.field.grades[1].erase("cost")).contains("灵田"), "a better field says what it costs")
