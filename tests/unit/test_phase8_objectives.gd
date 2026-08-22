## Phase 8 smoke test: marker contest/control (including the carrying-
## only-contests rule and APL-tie-means-uncontrolled case), Pick Up
## Marker / Place Marker legality, and the GameStateManager control-
## change event hook.
##
## Run headlessly once Godot is available:
##   godot --headless --script res://tests/unit/test_phase8_objectives.gd
##
## Plain script (not GUT) -- see test_phase2_data_load.gd for why.
extends SceneTree

var _failures: int = 0
var _events: Array = []

func _check(condition: bool, message: String) -> void:
	if condition:
		print("  [PASS] ", message)
	else:
		_failures += 1
		print("  [FAIL] ", message)

func _on_event(event_name: String, payload: Dictionary) -> void:
	_events.append({"name": event_name, "payload": payload})

func _make_trooper(at: Vector2, player: int) -> OperativeState:
	var data: OperativeData = load("res://data/operatives/death_korps/trooper.tres")
	var op := OperativeState.new()
	op.operative_id = "trooper#%d" % randi()
	op.init_from_data(data)
	op.position = at
	op.owning_player = player
	return op

func _make_boy(at: Vector2, player: int) -> OperativeState:
	var data: OperativeData = load("res://data/operatives/kommandos/boy.tres")
	var op := OperativeState.new()
	op.operative_id = "boy#%d" % randi()
	op.init_from_data(data)
	op.position = at
	op.owning_player = player
	return op

func _init() -> void:
	print("=== Phase 8 objectives/markers smoke test ===")
	EventBus.game_event.connect(_on_event)

	var los := LineOfSightRules.new()
	var objectives := ObjectiveRules.new()

	print("-- Uncontested marker: single side controls --")
	var marker := MarkerState.new()
	marker.marker_id = "obj_1"
	marker.position = Vector2(10, 10)
	var lone_defender := _make_trooper(Vector2(10.5, 10), 0)
	_check(objectives.compute_control(marker, [lone_defender], los) == 0, "sole contesting operative's player controls the marker")

	print("-- Contested marker: higher total APL controls --")
	var p0_a := _make_trooper(Vector2(10.5, 10), 0)   # APL 2
	var p0_b := _make_trooper(Vector2(9.5, 10), 0)     # APL 2 -- total 4 for player 0
	var p1_a := _make_boy(Vector2(10, 10.9), 1)        # APL 2 -- total 2 for player 1
	_check(objectives.compute_control(marker, [p0_a, p0_b, p1_a], los) == 0, "player with higher total contesting APL controls (4 vs 2)")

	print("-- Tied APL: uncontrolled --")
	var tie_a := _make_trooper(Vector2(10.5, 10), 0)   # APL 2
	var tie_b := _make_boy(Vector2(9.5, 10), 1)        # APL 2
	_check(objectives.compute_control(marker, [tie_a, tie_b], los) == -1, "tied contesting APL means uncontrolled, not a coin flip")

	print("-- No one contesting: uncontrolled --")
	var far_away := _make_trooper(Vector2(100, 100), 0)
	_check(objectives.compute_control(marker, [far_away], los) == -1, "no one within control range means uncontrolled")

	print("-- Carried marker: only the carrier contests, regardless of others nearby --")
	var carrier := _make_boy(Vector2(10, 10), 1)
	marker.carried_by_operative_id = carrier.operative_id
	var bystander_with_more_apl := _make_trooper(Vector2(10.2, 10), 0)
	_check(objectives.compute_control(marker, [carrier, bystander_with_more_apl], los) == 1, "carrying operative's player controls it even if an enemy with more APL is also in range")
	marker.carried_by_operative_id = ""  # reset for later checks

	print("-- Pick Up Marker: requires control --")
	var uncontrolled_marker := MarkerState.new()
	uncontrolled_marker.marker_id = "obj_2"
	uncontrolled_marker.position = Vector2(20, 20)
	var outnumbered_boy := _make_boy(Vector2(20.5, 20), 1)          # APL 2
	var opposing_a := _make_trooper(Vector2(19.5, 20), 0)            # APL 2
	var opposing_b := _make_trooper(Vector2(20, 20.9), 0)            # APL 2 -- player 0 has 4 total, outnumbers player 1's 2
	var pickup_blocked := objectives.validate_pick_up_marker(outnumbered_boy, uncontrolled_marker, [], [outnumbered_boy, opposing_a, opposing_b], los)
	_check(not pickup_blocked["legal"], "cannot Pick Up Marker when outnumbered on contesting APL (doesn't control it)")

	var controller := _make_trooper(Vector2(20.5, 20), 0)
	var pickup_ok := objectives.validate_pick_up_marker(controller, uncontrolled_marker, [], [controller], los)
	_check(pickup_ok["legal"], "controlling operative CAN Pick Up Marker (got: %s)" % pickup_ok.get("reason", ""))
	var pickup_result := objectives.execute_pick_up_marker(controller, uncontrolled_marker, [], [controller], los)
	_check(pickup_result["legal"] and uncontrolled_marker.carried_by_operative_id == controller.operative_id, "Pick Up Marker actually assigns the carrier")
	_check(controller.carrying_marker_id == "obj_2", "operative's carrying_marker_id is set")

	print("-- Pick Up Marker: blocked while already carrying --")
	var already_carrying_check := objectives.validate_pick_up_marker(controller, uncontrolled_marker, [], [controller], los)
	_check(not already_carrying_check["legal"], "cannot Pick Up Marker while already carrying one")

	print("-- Place Marker: blocked in the same activation as Pick Up Marker --")
	var place_blocked := objectives.validate_place_marker(controller, uncontrolled_marker)
	_check(not place_blocked["legal"], "Place Marker is illegal in the same activation as Pick Up Marker (unless incapacitated)")

	controller.reset_activation_actions()  # simulate a new activation
	var place_ok := objectives.validate_place_marker(controller, uncontrolled_marker)
	_check(place_ok["legal"], "Place Marker is legal in a later activation (got: %s)" % place_ok.get("reason", ""))
	var place_result := objectives.execute_place_marker(controller, uncontrolled_marker)
	_check(place_result["legal"] and uncontrolled_marker.carried_by_operative_id == "", "Place Marker drops the marker")
	_check(controller.carrying_marker_id == "", "operative's carrying_marker_id is cleared")
	_check(uncontrolled_marker.position == controller.position, "marker placed at the operative's position (placeholder placement policy)")

	print("-- Incapacitated-carrier Place Marker is free and exempt from the repeat-action rule --")
	var carrier2 := _make_trooper(Vector2(30, 30), 0)
	var marker3 := MarkerState.new()
	marker3.marker_id = "obj_3"
	marker3.carried_by_operative_id = carrier2.operative_id
	carrier2.carrying_marker_id = "obj_3"
	carrier2.record_action_performed("Pick Up Marker")  # already used this activation
	carrier2.current_wounds = 0  # incapacitated
	var incap_place := objectives.validate_place_marker(carrier2, marker3)
	_check(incap_place["legal"], "incapacitated carrier CAN Place Marker even in the same activation as Pick Up Marker")

	print("-- RulesEngine wiring + GameStateManager control-change event --")
	GameStateManager.start_new_game({
		"seed": 909,
		"players": {0: {"faction_id": "death_korps"}, 1: {"faction_id": "kommandos"}},
	})
	GameStateManager.end_gambit_step()
	var state: GameState = GameStateManager.current_state
	var live_op: OperativeState = state.get_operatives_for_player(0)[0]
	var enemy_op: OperativeState = state.get_operatives_for_player(1)[0]
	enemy_op.position = Vector2(200, 200)  # keep it out of the way (both spawn at origin -- Phase 6's known gap)

	var live_marker := MarkerState.new()
	live_marker.marker_id = "live_obj"
	live_marker.position = Vector2(0, 0)
	state.mission_state.add_marker(live_marker)
	live_op.position = Vector2(0.5, 0)

	var engine := GameStateManager.rules_engine
	_check(engine.get_marker_controller(state, "live_obj") == 0, "get_marker_controller() is a live query -- returns the correct answer immediately, independent of the cached refresh")
	_check(live_marker.controlling_player == -1, "the marker's CACHED controlling_player field hasn't been refreshed yet, though (still at its initial value)")

	GameStateManager.activate_operative(live_op.operative_id)
	_check(live_marker.controlling_player == 0, "cached control refreshed automatically at end of activation -- player 0 now controls it")
	var control_events := _events.filter(func(e): return e["name"] == "objective_controlled")
	_check(not control_events.is_empty(), "objective_controlled event fired on the control change")

	print("=== %s ===" % ("ALL PASS" if _failures == 0 else "%d FAILURE(S)" % _failures))
	quit(1 if _failures > 0 else 0)
