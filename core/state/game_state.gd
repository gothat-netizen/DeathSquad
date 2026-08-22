## The single authoritative representation of an in-progress game.
## Everything needed to save, restore, replay, or headlessly test a game
## lives here. Scene nodes are a VIEW of this, never the source of truth.
##
## PHASE: 3 (GameState and event system).
class_name GameState
extends RefCounted

var rules_version: String = "KT-2026-08"
var content_version: String = "CONTENT-001"
var random_seed: int = 0

var mission_state: MissionState
var turn_state: TurnState
var operatives: Dictionary = {}   # operative_id (instance id) -> OperativeState
var player_states: Dictionary = {} # player_id -> Dictionary (roster, equipment selections, etc.)

var _next_instance_suffix: Dictionary = {}   # operative_data_id -> int, so repeated operatives get unique instance ids

func _init() -> void:
	mission_state = MissionState.new()
	turn_state = TurnState.new()

## Creates a runtime OperativeState from a static OperativeData for the
## given player, registers it in `operatives`, and returns it. Instance
## ids are unique even when a kill team fields multiple copies of the
## same OperativeData (e.g. two Death Korps Troopers).
func spawn_operative(operative_data: OperativeData, owning_player: int, spawn_position: Vector2 = Vector2.ZERO) -> OperativeState:
	var suffix: int = _next_instance_suffix.get(operative_data.operative_id, 0)
	_next_instance_suffix[operative_data.operative_id] = suffix + 1
	var instance_id := "%s#%d" % [operative_data.operative_id, suffix]

	var op_state := OperativeState.new()
	op_state.operative_id = instance_id
	op_state.init_from_data(operative_data)
	op_state.owning_player = owning_player
	op_state.position = spawn_position

	operatives[instance_id] = op_state
	return op_state

func get_operatives_for_player(player_id: int) -> Array[OperativeState]:
	var result: Array[OperativeState] = []
	for op in operatives.values():
		if op.owning_player == player_id:
			result.append(op)
	return result

func get_ready_operatives_for_player(player_id: int) -> Array[OperativeState]:
	var result: Array[OperativeState] = []
	for op in get_operatives_for_player(player_id):
		if op.is_ready and not op.is_incapacitated():
			result.append(op)
	return result

# TODO (Phase 3): to_snapshot() / from_snapshot() for save/replay (see save/).
