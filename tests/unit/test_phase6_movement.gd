## Phase 6 smoke test: increment-rounding distance measurement, all four
## movement actions' legality rules (including control-range interaction
## and same-activation mutual exclusivity), and RulesEngine wiring
## (event emission + real GameState mutation).
##
## Run headlessly once Godot is available:
##   godot --headless --script res://tests/unit/test_phase6_movement.gd
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
	_events.append(event_name)

func _make_operative(at: Vector2 = Vector2.ZERO) -> OperativeState:
	var trooper_data: OperativeData = load("res://data/operatives/death_korps/trooper.tres")
	var op := OperativeState.new()
	op.operative_id = "test#%d" % randi()
	op.init_from_data(trooper_data)
	op.position = at
	return op

func _init() -> void:
	print("=== Phase 6 movement/spatial rules smoke test ===")
	EventBus.game_event.connect(_on_event)

	var movement := MovementRules.new()
	var los := LineOfSightRules.new()

	print("-- Increment rounding (0.5\" + 2.75\" -> 1\" + 3\" = 4\", not ceil(3.25)) --")
	var path := PackedVector2Array([Vector2(0, 0), Vector2(0.5, 0), Vector2(0.5, 2.75)])
	_check(movement.compute_increment_distance(path) == 4.0, "per-increment rounding gives 4\", matching the core rules' own worked example")

	print("-- Reposition: within Move, no enemies --")
	var mover := _make_operative(Vector2.ZERO)
	var straight_path := PackedVector2Array([Vector2.ZERO, Vector2(6, 0)])  # exactly 6" = Trooper's Move
	var result := movement.validate_move(mover, straight_path, MovementRules.MoveType.REPOSITION, [], [], los)
	_check(result["legal"], "6\" straight Reposition is legal for a Move-6 operative (got: %s)" % result.get("reason", ""))

	var too_far_path := PackedVector2Array([Vector2.ZERO, Vector2(7, 0)])
	var too_far_result := movement.validate_move(mover, too_far_path, MovementRules.MoveType.REPOSITION, [], [], los)
	_check(not too_far_result["legal"], "7\" Reposition is illegal for a Move-6 operative")

	print("-- Reposition: cannot start within an enemy's control range --")
	var enemy_adjacent := _make_operative(Vector2(0.5, 0))
	var blocked_start := movement.validate_move(mover, straight_path, MovementRules.MoveType.REPOSITION, [enemy_adjacent], [], los)
	_check(not blocked_start["legal"], "Reposition is illegal while already within an enemy's control range")

	print("-- Reposition: cannot finish within an enemy's control range --")
	var far_enemy := _make_operative(Vector2(6.5, 0))
	var blocked_end := movement.validate_move(mover, straight_path, MovementRules.MoveType.REPOSITION, [far_enemy], [], los)
	_check(not blocked_end["legal"], "Reposition ending within 1\" of an enemy (6\" dest vs enemy at 6.5\") is illegal")

	print("-- Reposition: cannot pass through an unassisted enemy's control range --")
	var midpoint_enemy := _make_operative(Vector2(3, 0))
	var pass_through_path := PackedVector2Array([Vector2.ZERO, Vector2(0, 5)])  # goes around, shouldn't trigger
	var straight_through := PackedVector2Array([Vector2.ZERO, Vector2(6, 0)])   # passes right by (3,0)
	var blocked_pass := movement.validate_move(mover, straight_through, MovementRules.MoveType.REPOSITION, [midpoint_enemy], [], los)
	_check(not blocked_pass["legal"], "Reposition path passing within 1\" of an unassisted enemy at the midpoint is illegal")

	print("-- Reposition: CAN pass through when a friendly already assists that enemy --")
	var assisting_friendly := _make_operative(Vector2(3, 0.5))  # within 1" of midpoint_enemy
	var assisted_pass := movement.validate_move(mover, straight_through, MovementRules.MoveType.REPOSITION, [midpoint_enemy], [assisting_friendly], los)
	_check(assisted_pass["legal"], "Reposition may pass through when a friendly already occupies that enemy's control range (got: %s)" % assisted_pass.get("reason", ""))

	print("-- Dash: fixed 3\", ignores Move stat --")
	var dash_ok := movement.validate_move(mover, PackedVector2Array([Vector2.ZERO, Vector2(3, 0)]), MovementRules.MoveType.DASH, [], [], los)
	_check(dash_ok["legal"], "3\" Dash is legal")
	var dash_too_far := movement.validate_move(mover, PackedVector2Array([Vector2.ZERO, Vector2(4, 0)]), MovementRules.MoveType.DASH, [], [], los)
	_check(not dash_too_far["legal"], "4\" Dash is illegal even though it's within the operative's 6\" Move stat")

	print("-- Fall Back: requires already being in an enemy's control range --")
	var free_mover := _make_operative(Vector2.ZERO)
	var fall_back_no_enemy := movement.validate_move(free_mover, straight_path, MovementRules.MoveType.FALL_BACK, [], [], los)
	_check(not fall_back_no_enemy["legal"], "Fall Back is illegal when not already within an enemy's control range")

	var engaged_mover := _make_operative(Vector2.ZERO)
	var adjacent_enemy := _make_operative(Vector2(0.5, 0))
	var fall_back_ok := movement.validate_move(engaged_mover, PackedVector2Array([Vector2.ZERO, Vector2(-6, 0)]), MovementRules.MoveType.FALL_BACK, [adjacent_enemy], [], los)
	_check(fall_back_ok["legal"], "Fall Back away from an adjacent enemy is legal (got: %s)" % fall_back_ok.get("reason", ""))

	print("-- Charge: must finish within an enemy's control range --")
	var charger := _make_operative(Vector2.ZERO)
	charger.order = OperativeState.Order.ENGAGE
	var charge_target := _make_operative(Vector2(7.5, 0))  # within Move(6)+2=8" charge range, 1" control range at 6.5-8.5
	var charge_ok := movement.validate_move(charger, PackedVector2Array([Vector2.ZERO, Vector2(6.5, 0)]), MovementRules.MoveType.CHARGE, [charge_target], [], los)
	_check(charge_ok["legal"], "8\"-range Charge ending within 1\" of the target is legal (got: %s)" % charge_ok.get("reason", ""))
	var charge_short := movement.validate_move(charger, PackedVector2Array([Vector2.ZERO, Vector2(5, 0)]), MovementRules.MoveType.CHARGE, [charge_target], [], los)
	_check(not charge_short["legal"], "a Charge that doesn't end within control range of any enemy is illegal")

	print("-- Charge: illegal with Conceal order --")
	var concealed_charger := _make_operative(Vector2.ZERO)
	concealed_charger.order = OperativeState.Order.CONCEAL
	var conceal_charge := movement.validate_move(concealed_charger, PackedVector2Array([Vector2.ZERO, Vector2(6.5, 0)]), MovementRules.MoveType.CHARGE, [charge_target], [], los)
	_check(not conceal_charge["legal"], "Charge is illegal while the operative has a Conceal order")

	print("-- Same-activation mutual exclusivity --")
	var multi_mover := _make_operative(Vector2.ZERO)
	multi_mover.record_action_performed("Reposition")
	var charge_after_reposition := movement.validate_move(multi_mover, PackedVector2Array([Vector2.ZERO, Vector2(6.5, 0)]), MovementRules.MoveType.CHARGE, [charge_target], [], los)
	_check(not charge_after_reposition["legal"], "Charge is illegal in the same activation as a prior Reposition")
	var dash_after_reposition := movement.validate_move(multi_mover, PackedVector2Array([Vector2.ZERO, Vector2(3, 0)]), MovementRules.MoveType.DASH, [], [], los)
	_check(dash_after_reposition["legal"], "Dash is explicitly still legal after Reposition (only Charge is excluded for Dash)")

	print("-- RulesEngine wiring: real GameState mutation + event emission --")
	GameStateManager.start_new_game({
		"seed": 4242,
		"players": {0: {"faction_id": "death_korps"}, 1: {"faction_id": "kommandos"}},
	})
	GameStateManager.end_gambit_step()
	var state: GameState = GameStateManager.current_state
	var live_op: OperativeState = state.get_operatives_for_player(0)[0]
	live_op.position = Vector2.ZERO
	for enemy_op in state.get_operatives_for_player(1):
		enemy_op.position = Vector2(100, 100)  # both rosters default-spawn at (0,0) -- separate them so control range doesn't interfere with this check
	var engine := GameStateManager.rules_engine
	var move_result := engine.execute_move(state, live_op, PackedVector2Array([Vector2.ZERO, Vector2(4, 0)]), MovementRules.MoveType.REPOSITION)
	_check(move_result["legal"], "RulesEngine.execute_move() succeeds for a legal move")
	_check(live_op.position == Vector2(4, 0), "operative's actual GameState position was mutated")
	_check(_events.has("operative_moved"), "operative_moved event fired")
	_check(live_op.has_performed_action("Reposition"), "action recorded on the operative after execute_move()")

	print("=== %s ===" % ("ALL PASS" if _failures == 0 else "%d FAILURE(S)" % _failures))
	quit(1 if _failures > 0 else 0)
