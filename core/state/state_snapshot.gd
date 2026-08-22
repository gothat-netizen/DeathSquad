## Serializable snapshot of a GameState, used by save/save_manager.gd and
## by the replay/debug systems. Kept separate from GameState itself so
## that GameState can hold richer runtime references (e.g. Resource
## pointers) while the snapshot stays flat and JSON/text-serializable.
##
## PHASE: 14 (Save/load), stubbed now so the shape exists early.
class_name StateSnapshot
extends RefCounted

var data: Dictionary = {}

func from_game_state(state: GameState) -> void:
	push_warning("StateSnapshot.from_game_state() not yet implemented (Phase 14)")

func to_game_state() -> GameState:
	push_warning("StateSnapshot.to_game_state() not yet implemented (Phase 14)")
	return GameState.new()
