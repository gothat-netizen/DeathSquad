## Main menu controller. Pure navigation -- Start Game / Load Game /
## Options / Rules Reference / Exit Game. No gameplay logic here.
##
## PHASE: 1 (this stub + scene) so the project has a runnable entry
## point from day one; button wiring fleshed out in Phase 11.
class_name MainMenu
extends Control

func _on_start_game_pressed() -> void:
	push_warning("MainMenu: Start Game not yet wired (Phase 11)")

func _on_load_game_pressed() -> void:
	push_warning("MainMenu: Load Game not yet wired (Phase 11/14)")

func _on_options_pressed() -> void:
	push_warning("MainMenu: Options not yet wired (Phase 11)")

func _on_rules_reference_pressed() -> void:
	push_warning("MainMenu: Rules Reference not yet wired (Phase 11)")

func _on_exit_game_pressed() -> void:
	get_tree().quit()
