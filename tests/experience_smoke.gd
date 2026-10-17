extends SceneTree
const Session = preload("res://scripts/core/session.gd")
const Goals = preload("res://scripts/ui/goals.gd")
const Sources = preload("res://scripts/core/sources.gd")
var checks := 0
var failures := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: "+message)
func game() -> Session:
	var s := Session.new()
	s.new_game("行路",8421,["metal","wood","water"])
	s.encounters_enabled = false
	s.world.flags.tiannan_known = true
	s.player.realm = 1
	s.refresh_realm_stats()
	s.player.location = "nanming"
	return s
func _initialize() -> void:
	for stones: int in [0,22,40,100]:
		var s := game()
		s.player.stones = stones
		var preview: Dictionary = s.Journey.preview(s,"sect")
		check(preview.mode == ("cheap" if stones<40 else "fast"),"budget selects expected mode")
		var initial_day := int(s.world.day)
		var result := s.travel("sect")
		check(s.player.location=="sect" and s.player.journey.is_empty(),"affordable travel arrives: "+result)
		check(int(s.world.day)-initial_day==(26 if stones<40 else 8),"actual days match displayed road")
		check(int(s.player.stones)==stones-(0 if stones<40 else 40),"only actual gate fees paid")
	var cheap := game()
	cheap.player.stones = 100
	check(cheap.path_to("sect","cheap")==["nanming","chifeng","ferry","town","sect"],"cheap road stays on land")
	cheap.player.location = "chifeng"
	cheap.player.journey = {"to":"sect","mode":"cheap"}
	var saved: Dictionary = JSON.parse_string(JSON.stringify(cheap.snapshot()))
	var copy := Session.new()
	copy.encounters_enabled = false
	check(copy.restore(saved) and copy.player.journey.mode=="cheap","route mode restored")
	copy.continue_journey()
	check(copy.player.location=="sect" and int(copy.player.stones)==100,"resumed cheap journey never turns back to the gate")
	saved.player.journey.erase("mode")
	check(copy.restore(saved) and copy.player.journey.mode=="fast","old journey defaults to fast")
	var before := copy.snapshot()
	for bad: Variant in ["teleport",3,null]:
		saved.player.journey.mode = bad
		check(not copy.restore(saved) and copy.snapshot()==before,"malformed mode rejected atomically")
	var hints := game()
	hints.world.flags.found_ruin = true
	hints.world.flags.helped_wanderer = true
	hints.Storylines.update(hints)
	check(Goals.ruin_hint(hints).contains("劝他离开"),"known peaceful option appears")
	hints.world.flags.serpent_rampage = true
	check(hints.path_to("wild").is_empty(),"sealed destinations stay unreachable")
	check(Sources.line(hints,"dihuo_jing").contains("商铺") and not Sources.line(hints,"dihuo_jing").contains("丹铺"),"material shop is labelled accurately")
	for year: int in [10,150,151,210]:
		var entry := {"id":"story","day":(year-1)*360,"args":{"story":"true_disciple","step":"secret","part":"after"}}
		var words := hints.chronicle.format(entry,hints.content)
		check(not words.contains("{chenxia_date}") and words.contains("历元"),"cave date formatted from historical day")
	new_stories()
	feedback()
	print("EXPERIENCE: %d checks, %d failures" % [checks,failures])
	quit(0 if failures==0 else 1)

func fresh() -> Session:
	var s := game()
	s.player.location = "sect"
	s.player.stones = 500
	return s

func new_stories() -> void:
	for choice: String in ["company", "recipe"]:
		var s := fresh()
		s.player.location = "ridge"
		s.interact("azhi", "offer_route")
		s.set_item_count("huichun_grass", 2)
		s.set_item_count("ninglu_grass", 2)
		s.interact("azhi", "route_herbs")
		check(s.herb_count()==0 and s.story_at("azhi_route","consult"),"route herbs consumed once")
		s.player.location = "market"
		s.interact("shen_mo", "route_consult")
		s.player.location = "ridge"
		s.interact("azhi", "route_"+choice)
		var before := s.herb_count()
		s.act("gather")
		check(s.story_state("azhi_route")=="done", "both herb route choices finish")
		if choice=="company":
			check(s.herb_count()-before>=3 and not s.has_flag("azhi_route_ready"),"one-use company help applied")
			before=s.herb_count()
			s.act("gather")
			check(s.herb_count()-before<=2,"company help cannot repeat")
		else:
			check(s.Alchemy.knows(s,"liaoshang"),"recipe alternative teaches existing recipe")
	for choice: String in ["relief", "order"]:
		var s := fresh()
		s.player.location = "market"
		s.interact("shen_mo","offer_order")
		s.set_item_count("liaoshang_fine",0)
		var fine: String = s.content.fine_pill("liaoshang_pill")
		s.set_item_count(fine,2)
		s.Storylines.update(s)
		check(s.story_at("shen_order","decide"),"fine pills fulfill preparation")
		s.act("sell")
		check(s.item_count(fine)==2,"fine delivery pills survive bulk sale")
		s.interact("shen_mo","order_"+choice)
		check(s.item_count(fine)==0 and s.has_flag("medicine_"+choice),"choice consumes fine family and records outcome")
		s.player.location="ridge"
		s.interact("azhi","order_visit")
		s.player.location="market"
		var money:=int(s.player.stones)
		s.interact("shen_mo","order_settle")
		check(s.story_state("shen_order")=="done" and int(s.player.stones)==money+30 and s.Alchemy.knows(s,"huiqi"),"order rewards and recipe once")
		s.interact("shen_mo","order_settle")
		check(int(s.player.stones)==money+30,"repeated settle cannot pay again")
	for path: String in ["patrol","alchemy","mediation"]:
		var s:=fresh()
		s.player.rank=1
		s.player.merit=240
		s.interact("gu_changgeng","offer_exam")
		s.interact("gu_changgeng","exam_"+path)
		check(s.Storylines.required_items(s,"inner_exam").has("huiqi_pill")== (path=="alchemy"),"only selected exam branch reserves pills")
		match path:
			"patrol":
				s.record_deed("win:wolf_pack",2)
				s.interact("gu_changgeng","exam_patrol_report")
			"alchemy":
				s.set_item_count(s.content.fine_pill("liaoshang_pill"),2)
				s.set_item_count(s.content.fine_pill("huiqi_pill"),2)
				s.interact("xu_qinghe","exam_pills")
				check(s.pill_count("liaoshang_pill")==0 and s.pill_count("huiqi_pill")==0,"exam consumes both fine pill families")
			"mediation":
				s.player.location="ridge"
				s.interact("azhi","exam_hear_azhi")
				s.player.location="market"
				s.interact("shen_mo","exam_hear_shen")
				s.player.location="sect"
				s.interact("gu_changgeng","exam_mediate")
		check(s.story_at("inner_exam","witness"),"each exam path reaches independent witness")
		s.player.location="ridge"
		s.interact("azhi","exam_witness_"+path)
		s.player.location="sect"
		s.interact("gu_changgeng","exam_finish")
		check(s.story_state("inner_exam")=="done" and int(s.player.merit)==400 and int(s.player.rank)==1 and s.promotion_block().is_empty(),"exam adds 160 without automatic rank or lower threshold")
		s.interact("gu_changgeng","exam_finish")
		check(int(s.player.merit)==400,"exam contribution cannot repeat")
	var switching:=fresh()
	switching.interact("gu_changgeng","offer_exam")
	switching.interact("gu_changgeng","exam_alchemy")
	check(switching.Storylines.required_items(switching,"inner_exam").has("huiqi_pill"),"chosen production exam reserves medicine")
	switching.interact("gu_changgeng","exam_switch_mediation")
	check(switching.has_flag("exam_mediation") and not switching.has_flag("exam_alchemy") and switching.Storylines.required_items(switching,"inner_exam").is_empty(),"changing exam clears old costs without advancing or rewarding")
	check(Goals.described_step(switching,switching.story_step("inner_exam")).goal.contains("赊账"),"selected branch gets its own actionable wording")
	for choice: String in ["gate","road"]:
		var s:=fresh()
		s.Storylines.mark_done(s,"south_journey")
		s.player.location="nanming"
		s.Storylines.update(s)
		s.set_item_count("huichun_grass",2)
		s.set_item_count("ninglu_grass",2)
		var money:=int(s.player.stones)
		s.conclude("")
		check(s.pending_event.get("id","")=="south_return_routes" and int(s.player.stones)==money+60 and s.herb_count()==0,"southern supplies pay once and introduce route choice")
		s.choose_event(choice)
		s.player.location="chixiao_gate"
		s.interact("yuan_chifeng","talk")
		check(s.story_state("south_settlement")=="done" and s.has_flag("south_"+("gate" if choice=="gate" else "road")+"_known"),"both return plans lead to southern introduction")
	for evidence: String in ["forge","caravan"]:
		for ending: String in ["turn_in","expose","let_go"]:
			var s:=fresh()
			s.world.flags.dihuo_lizard_down=true
			s.world.storylines.furnace_bounty={"state":"active","step":2,"begun":true,"since":0,"base":{}}
			s.player.location="chifeng"
			s.interact("han_jin","hear_out")
			var expose: Array = s.npc_options("han_jin").filter(func(o: Dictionary) -> bool: return o.id=="expose")
			check(not expose[0].available and s.story_at("furnace_inquiry","verify"),"new inquiry needs corroboration before exposure")
			if evidence=="forge":
				s.player.location="chixiao_gate"
				s.interact("yuan_chifeng","verify_forge")
			else:
				s.player.location=s.npc_location("peddler")
				s.interact("peddler","verify_caravan")
			check(s.story_state("furnace_inquiry")=="done" and s.has_flag("furnace_evidence"),"both evidence routes validate ledger")
			var copy:=Session.new()
			check(copy.restore(JSON.parse_string(JSON.stringify(s.snapshot()))) and copy.has_flag("furnace_evidence"),"investigation survives save restore")
			s.player.location="chifeng"
			var money:=int(s.player.stones)
			s.interact("han_jin",ending)
			check(s.story_state("furnace_bounty")=="done" and int(s.player.stones)==money+({"turn_in":300,"expose":150,"let_go":0}[ending]),"all three original rewards retained")
			check(s.npc_location("yuan_chifeng").is_empty()==(ending=="expose"),"exposure removes the dismissed official only")
			s.player.location="market"
			s.interact("shen_mo","bounty_echo_"+{"turn_in":"turned_in","expose":"exposed","let_go":"let_go"}[ending])
			check(s.story_state("furnace_aftermath")=="done", "each ending has its own return response")
	var legacy:=fresh()
	legacy.world.storylines.furnace_bounty={"state":"active","step":2,"begun":true,"since":0,"base":{}}
	legacy.world.flags.hanjin_heard=true
	legacy.player.location="chifeng"
	legacy.interact("han_jin","expose")
	check(legacy.has_flag("bounty_exposed"),"old already-heard case is not newly blocked")

func feedback() -> void:
	var s:=fresh()
	s.world.flags.serpent_rampage=true
	s.world.flags.found_ruin=true
	var goals:=Goals.current(s)
	var waiting: Array=goals.filter(func(g: Dictionary)->bool: return g.get("state","")=="waiting")
	check(not waiting.is_empty() and waiting[0].text.contains("暂时封锁"),"blocked known goal explains alternatives")
	s.player.location="wild"
	s.world.flags.erase("serpent_rampage")
	s.player.hp=20
	s.start_battle("serpent")
	var battle_save: Dictionary = JSON.parse_string(JSON.stringify(s.snapshot()))
	var loaded := Session.new()
	check(loaded.restore(battle_save) and int(loaded.battle.opening_percent)<70,"new battle facts survive real JSON restore")
	var unchanged := loaded.snapshot()
	battle_save.battle.opening_percent = 101
	check(not loaded.restore(battle_save) and loaded.snapshot()==unchanged,"invalid battle facts reject atomically")
	for field: String in ["opening_percent","guarded_turns","old_wound"]:
		battle_save.battle.erase(field)
	check(loaded.restore(battle_save),"old battles without feedback facts remain loadable")
	s.Combat._lose(s)
	var reviews: Array=s.chronicle.entries.filter(func(e: Dictionary)->bool: return e.id=="battle_review")
	check(reviews.size()==1 and int(reviews[0].args.opening_percent)<70,"defeat records actual opening health")
	check(preload("res://scripts/ui/experience_text.gd").defeat_advice(s,reviews[0]).contains("气血不足"),"advice follows the recorded fight")
	var before:=s.chronicle.to_save()
	preload("res://scripts/ui/experience_text.gd").messages(s,s.chronicle.entries)
	check(before==s.chronicle.to_save(),"message grouping leaves history untouched")
