## Draws the movement path preview using the SAME validator
## (core/rules/movement_rules.gd) that executes the actual move. The
## player must never be shown a legal-looking path that the rules
## engine later rejects.
##
## PHASE: 11 (User interface).
class_name MovementPreview
extends Node3D

func preview_path(_operative: OperativeState, _target_position: Vector2) -> void:
	push_warning("MovementPreview.preview_path() not yet implemented (Phase 11)")
