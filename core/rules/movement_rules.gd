## Movement legality and execution: Reposition, Dash, Fall Back, Charge.
##
## All four are, per the core rules text, explicitly defined as
## variations on Reposition ("the same as the Reposition action,
## except...") -- implemented here as one parameterized function keyed
## by MoveType rather than four near-duplicate functions, with each
## action's specific overrides applied explicitly rather than inferred.
##
## Distance measurement: one or more straight-line increments, each
## ROUNDED UP INDIVIDUALLY to the nearest inch, then summed (confirmed
## by the core rules' own worked example: 0.5" + 2.75" increments ->
## 1" + 3" = 4" total, not ceil(3.25) = 4 by coincidence -- the
## per-increment rounding is the actual rule, not an approximation).
##
## KNOWN GAP: "cannot climb during Dash" isn't enforced -- there's no
## terrain/elevation data yet (Phase 10/13) for a move to climb
## anything. Flagged rather than silently ignored.
##
## PHASE: 6 (Movement and spatial rules).
class_name MovementRules
extends RefCounted

enum MoveType { REPOSITION, DASH, FALL_BACK, CHARGE }

const AP_COST := {
	MoveType.REPOSITION: 1,
	MoveType.DASH: 1,
	MoveType.FALL_BACK: 2,
	MoveType.CHARGE: 1,
}

const ACTION_NAMES := {
	MoveType.REPOSITION: "Reposition",
	MoveType.DASH: "Dash",
	MoveType.FALL_BACK: "Fall Back",
	MoveType.CHARGE: "Charge",
}

func get_ap_cost(move_type: MoveType) -> int:
	return AP_COST[move_type]

func get_action_name(move_type: MoveType) -> String:
	return ACTION_NAMES[move_type]

## Sums each straight-line increment's length, rounded up individually
## BEFORE summing -- see class doc for why this isn't the same as
## rounding the total once.
func compute_increment_distance(path: PackedVector2Array) -> float:
	if path.size() < 2:
		return 0.0
	var total := 0.0
	for i in range(path.size() - 1):
		var segment_length: float = path[i].distance_to(path[i + 1])
		total += ceil(segment_length - 0.0001)  # epsilon guards exact-integer segments from float error rounding up spuriously
	return total

## Returns {"legal": bool, "reason": String, "distance": float,
## "destination": Vector2}. Does not mutate anything -- see execute_move().
func validate_move(
	operative: OperativeState,
	path: PackedVector2Array,
	move_type: MoveType,
	enemies: Array[OperativeState],
	friendlies: Array[OperativeState],
	los_rules: LineOfSightRules,
	blocking_obstacles: Array[Rect2] = []
) -> Dictionary:
	var action_name := get_action_name(move_type)

	if operative.has_performed_action(action_name):
		return {"legal": false, "reason": "%s already performed this activation" % action_name}

	# Same-activation mutual exclusivity -- asymmetric on purpose, matching
	# the core rules text exactly rather than assuming symmetry between actions.
	match move_type:
		MoveType.REPOSITION:
			if operative.has_performed_action("Fall Back") or operative.has_performed_action("Charge"):
				return {"legal": false, "reason": "Reposition cannot be performed in the same activation as Fall Back or Charge"}
		MoveType.DASH:
			if operative.has_performed_action("Charge"):
				return {"legal": false, "reason": "Dash cannot be performed in the same activation as Charge"}
		MoveType.FALL_BACK:
			if operative.has_performed_action("Reposition") or operative.has_performed_action("Charge"):
				return {"legal": false, "reason": "Fall Back cannot be performed in the same activation as Reposition or Charge"}
		MoveType.CHARGE:
			if operative.has_performed_action("Reposition") or operative.has_performed_action("Dash") or operative.has_performed_action("Fall Back"):
				return {"legal": false, "reason": "Charge cannot be performed in the same activation as Reposition, Dash, or Fall Back"}

	var currently_in_enemy_control_range := false
	for enemy in enemies:
		if los_rules.is_within_control_range(operative, enemy, blocking_obstacles):
			currently_in_enemy_control_range = true
			break

	match move_type:
		MoveType.REPOSITION, MoveType.DASH:
			if currently_in_enemy_control_range:
				return {"legal": false, "reason": "%s cannot be performed while within control range of an enemy operative" % action_name}
		MoveType.FALL_BACK:
			if not currently_in_enemy_control_range:
				return {"legal": false, "reason": "Fall Back requires an enemy operative already within control range"}
		MoveType.CHARGE:
			if operative.order == OperativeState.Order.CONCEAL:
				return {"legal": false, "reason": "Charge cannot be performed with a Conceal order"}
			if currently_in_enemy_control_range:
				return {"legal": false, "reason": "Charge cannot be performed while already within control range of an enemy operative"}

	var distance := compute_increment_distance(path)
	var max_distance: float
	match move_type:
		MoveType.REPOSITION, MoveType.FALL_BACK:
			max_distance = operative.get_effective_move()
		MoveType.DASH:
			max_distance = 3.0  # fixed -- Dash explicitly ignores the Move stat entirely
		MoveType.CHARGE:
			max_distance = operative.get_effective_move() + 2.0

	if distance > max_distance:
		return {"legal": false, "reason": "path requires %.1f\" but max for %s is %.1f\"" % [distance, action_name, max_distance]}

	var destination: Vector2 = path[path.size() - 1] if path.size() > 0 else operative.position

	# Reposition/Dash: cannot pass through OR finish within an unassisted
	# enemy's control range at any point along the path -- checked against
	# every segment, not just the endpoint, using distance-to-segment
	# (visibility-along-the-path is a follow-up once real terrain exists).
	if move_type == MoveType.REPOSITION or move_type == MoveType.DASH:
		for enemy in enemies:
			var assisted := false
			for friendly in friendlies:
				if friendly != operative and los_rules.is_within_control_range(friendly, enemy, blocking_obstacles):
					assisted = true
					break
			if assisted:
				continue  # may pass through (but still may not FINISH there -- checked below regardless)
			for i in range(path.size() - 1):
				if los_rules.distance_point_to_segment(enemy.position, path[i], path[i + 1]) <= 1.0:
					return {"legal": false, "reason": "%s cannot move through an unassisted enemy operative's control range" % action_name}

	if move_type == MoveType.REPOSITION or move_type == MoveType.DASH or move_type == MoveType.FALL_BACK:
		for enemy in enemies:
			if destination.distance_to(enemy.position) <= 1.0:
				return {"legal": false, "reason": "%s cannot finish within an enemy operative's control range" % action_name}

	if move_type == MoveType.CHARGE:
		var ends_in_range := false
		for enemy in enemies:
			if destination.distance_to(enemy.position) <= 1.0:
				ends_in_range = true
				break
		if not ends_in_range:
			return {"legal": false, "reason": "Charge must finish within control range of an enemy operative"}
		# "if it moves within control range of an enemy that no other friendly
		# is within control range of, it cannot leave that operative's control
		# range" -- a Phase 7 concern (it constrains FUTURE actions this
		# activation, not this move itself), flagged rather than silently dropped.

	return {"legal": true, "reason": "", "distance": distance, "destination": destination}

## Validates, then (only if legal) mutates operative.position and records
## the action as performed. Per the core rules: "if an action is declared
## or begun but not possible to complete, revert" -- validating fully
## before any mutation is how that's honored, rather than partially
## applying a move and rolling it back.
func execute_move(
	operative: OperativeState,
	path: PackedVector2Array,
	move_type: MoveType,
	enemies: Array[OperativeState],
	friendlies: Array[OperativeState],
	los_rules: LineOfSightRules,
	blocking_obstacles: Array[Rect2] = []
) -> Dictionary:
	var result := validate_move(operative, path, move_type, enemies, friendlies, los_rules, blocking_obstacles)
	if not result["legal"]:
		return result
	operative.position = result["destination"]
	operative.record_action_performed(get_action_name(move_type))
	return result
