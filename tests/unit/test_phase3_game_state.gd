## Phase 3 smoke test: drives GameStateManager through game start, one
## full Strategy phase, into the Firefight phase, activates both
## operatives, and confirms the turning point ends -- while listening on
## EventBus to confirm the right events fire in the right order.
##
## Run headlessly once Godot is available:
##   godot --headless --script res://tests/unit/test_phase3_game_state.gd
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
	print("    (event) ", event_name, " ", payload)

func _init() -> void:
	print("=== Phase 3 GameState/event system smoke test ===")
	EventBus.game_event.connect(_on_event)

	print("-- start_new_game (Death Korps vs Kommandos) --")
	GameStateManager.start_new_game({
		"seed": 12345,
		"players": {0: {"faction_id": "death_korps"}, 1: {"faction_id": "kommandos"}},
	})
	var state: GameState = GameStateManager.current_state
	_check(state != null, "GameState created")
	_check(state.operatives.size() == 2, "both rosters spawned (1 Trooper + 1 Boy, given current Phase 2 content)")
	_check(_events.has("game_started") and _events.has("turning_point_started"), "game_started and turning_point_started fired")

	print("-- Strategy phase, turning point 1 --")
	var turn: TurnState = state.turn_state
	_check(turn.turning_point_number == 1, "turning_point_number == 1")
	_check(turn.phase == TurnState.Phase.STRATEGY, "phase == STRATEGY")
	_check(turn.strategy_step == TurnState.StrategyStep.GAMBIT, "auto-advanced through Ready into GAMBIT step")
	_check(turn.initiative_player == 0 or turn.initiative_player == 1, "initiative resolved to a valid player (dice-driven, seed-dependent)")
	_check(turn.command_points.get(0, 0) == 1 and turn.command_points.get(1, 0) == 1, "both players got +1 CP on turn 1 (no catch-up yet)")
	for op in state.operatives.values():
		_check(op.is_ready, "operative %s readied for the turning point" % op.operative_id)

	print("-- Firefight phase --")
	GameStateManager.end_gambit_step()
	_check(turn.phase == TurnState.Phase.FIREFIGHT, "phase == FIREFIGHT")

	var first_player := GameStateManager.next_activating_player()
	_check(first_player == turn.initiative_player, "initiative player activates first")
	var first_op: OperativeState = null
	for op in state.get_ready_operatives_for_player(first_player):
		first_op = op
		break
	_check(first_op != null, "found a ready operative for player %s" % first_player)
	GameStateManager.activate_operative(first_op.operative_id)
	_check(not first_op.is_ready, "operative expended after activation")
	_check(_events.has("activation_started") and _events.has("activation_ended"), "activation_started/activation_ended fired")

	var expected_second_player: int = -1
	for p in state.player_states.keys():
		if p != first_player:
			expected_second_player = p
	var second_player := GameStateManager.next_activating_player()
	_check(second_player == expected_second_player, "control passed to the other player")
	var second_op: OperativeState = null
	for op in state.get_ready_operatives_for_player(second_player):
		second_op = op
		break
	_check(second_op != null, "found a ready operative for player %s" % second_player)
	GameStateManager.activate_operative(second_op.operative_id)

	_check(_events.has("turning_point_ended"), "turning_point_ended fired once both sides are fully expended")
	_check(GameStateManager.next_activating_player() == -1, "no one left to activate")

	print("-- Turning point 2 (catch-up CP check) --")
	var cp_before_t2: Dictionary = turn.command_points.duplicate()
	GameStateManager.start_new_turning_point()
	_check(turn.turning_point_number == 2, "turning_point_number == 2")
	var t2_initiative: int = turn.initiative_player
	var t2_other: int = -1
	for p in state.player_states.keys():
		if p != t2_initiative:
			t2_other = p
	var initiative_gain: int = turn.command_points.get(t2_initiative, 0) - cp_before_t2.get(t2_initiative, 0)
	var other_gain: int = turn.command_points.get(t2_other, 0) - cp_before_t2.get(t2_other, 0)
	_check(initiative_gain == 1, "turn 2 initiative player (%s) gained exactly +1 CP" % t2_initiative)
	_check(other_gain == 2, "turn 2 non-initiative player (%s) got the +2 catch-up CP after turn 1" % t2_other)
	for op in state.operatives.values():
		_check(op.is_ready, "operative %s re-readied for turning point 2" % op.operative_id)

	print("=== %s ===" % ("ALL PASS" if _failures == 0 else "%d FAILURE(S)" % _failures))
	quit(1 if _failures > 0 else 0)
