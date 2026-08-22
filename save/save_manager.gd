## Local-only save/load (per project decision -- no cloud sync).
## Serializes StateSnapshot to disk and back. Must never silently change
## the behavior of an existing save when a rules_version updates -- if
## rules_version in a save file doesn't match the current engine, flag
## it rather than reinterpreting the save under new rules.
##
## PHASE: 14 (Save/load).
class_name SaveManager
extends RefCounted

const SAVE_DIR := "user://saves/"

func save_game(_snapshot: StateSnapshot, _slot_name: String) -> bool:
	push_warning("SaveManager.save_game() not yet implemented (Phase 14)")
	return false

func load_game(_slot_name: String) -> StateSnapshot:
	push_warning("SaveManager.load_game() not yet implemented (Phase 14)")
	return null

func list_saves() -> Array[String]:
	push_warning("SaveManager.list_saves() not yet implemented (Phase 14)")
	return []
