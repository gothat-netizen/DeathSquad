## Objective marker contest/control, and the Pick Up Marker / Place
## Marker universal actions. Confirmed against the core rules' "Markers"
## key principle and the Actions list.
##
## Control rule: operatives contest a marker within their control range
## (visible + within 1", same definition as operative-to-operative).
## Friendly operatives control a marker if their total APL contesting it
## exceeds the enemy total -- a tie means uncontrolled, not a coin flip.
## While a marker is carried, ONLY the carrier contests/controls it.
##
## KNOWN SIMPLIFICATION: the core rules state "control cannot change
## during an action" (i.e. it's a snapshot taken before the action, held
## until it completes). There's no action-sequencing orchestration layer
## yet that calls compute_control() at multiple points mid-action, so
## this always computes fresh from current positions -- correct for
## anything that calls it between actions, not yet enforced as a
## mid-action snapshot. Also NOT implemented: an incapacitated operative
## carrying a marker must Place Marker for 0AP before removal -- that
## needs combat_rules to know about mission_state, which doesn't happen
## yet (flagged rather than silently dropped).
##
## PHASE: 8 (Objectives and mission system).
class_name ObjectiveRules
extends RefCounted

func get_contesting_operatives(marker: MarkerState, all_operatives: Array[OperativeState], los: LineOfSightRules) -> Array[OperativeState]:
	if marker.carried_by_operative_id != "":
		for op in all_operatives:
			if op.operative_id == marker.carried_by_operative_id:
				return [op]
		return []

	var result: Array[OperativeState] = []
	for op in all_operatives:
		if op.is_incapacitated():
			continue
		if los.is_visible(op.position, marker.position) and op.position.distance_to(marker.position) <= 1.0:
			result.append(op)
	return result

## Returns the controlling player_id, or -1 if uncontrolled (no one
## contesting, or contesting APL tied between sides).
func compute_control(marker: MarkerState, all_operatives: Array[OperativeState], los: LineOfSightRules) -> int:
	var contesting := get_contesting_operatives(marker, all_operatives, los)
	if contesting.is_empty():
		return -1

	var apl_by_player: Dictionary = {}
	for op in contesting:
		apl_by_player[op.owning_player] = apl_by_player.get(op.owning_player, 0) + op.get_effective_apl()

	var players: Array = apl_by_player.keys()
	if players.size() == 1:
		return players[0]

	players.sort_custom(func(a, b): return apl_by_player[a] > apl_by_player[b])
	var top: int = players[0]
	var second: int = players[1]
	return top if apl_by_player[top] > apl_by_player[second] else -1

func validate_pick_up_marker(operative: OperativeState, marker: MarkerState, enemies: Array[OperativeState], all_operatives: Array[OperativeState], los: LineOfSightRules) -> Dictionary:
	if operative.has_performed_action("Pick Up Marker"):
		return {"legal": false, "reason": "Pick Up Marker already performed this activation"}
	if operative.carrying_marker_id != "":
		return {"legal": false, "reason": "operative is already carrying a marker"}
	for enemy in enemies:
		if los.is_within_control_range(operative, enemy):
			return {"legal": false, "reason": "Pick Up Marker cannot be performed while within control range of an enemy operative"}
	if operative.position.distance_to(marker.position) > 1.0 or not los.is_visible(operative.position, marker.position):
		return {"legal": false, "reason": "marker is not within the operative's control range"}
	if compute_control(marker, all_operatives, los) != operative.owning_player:
		return {"legal": false, "reason": "operative's side does not control this marker"}
	return {"legal": true, "reason": ""}

func execute_pick_up_marker(operative: OperativeState, marker: MarkerState, enemies: Array[OperativeState], all_operatives: Array[OperativeState], los: LineOfSightRules) -> Dictionary:
	var result := validate_pick_up_marker(operative, marker, enemies, all_operatives, los)
	if not result["legal"]:
		return result
	marker.carried_by_operative_id = operative.operative_id
	operative.carrying_marker_id = marker.marker_id
	operative.record_action_performed("Pick Up Marker")
	return result

## Placement position: this implementation places the marker at the
## operative's own position (always within its own control range, so
## always legal) rather than prompting for a specific point within
## control range -- exact placement is a real player decision with no
## prompt system yet (same seam category as Initiative/Precedence).
func validate_place_marker(operative: OperativeState, marker: MarkerState) -> Dictionary:
	if marker.carried_by_operative_id != operative.operative_id:
		return {"legal": false, "reason": "operative is not carrying this marker"}
	if operative.has_performed_action("Pick Up Marker") and not operative.is_incapacitated():
		return {"legal": false, "reason": "Place Marker cannot be performed in the same activation as Pick Up Marker (unless incapacitated)"}
	return {"legal": true, "reason": ""}

func execute_place_marker(operative: OperativeState, marker: MarkerState) -> Dictionary:
	var result := validate_place_marker(operative, marker)
	if not result["legal"]:
		return result
	marker.position = operative.position
	marker.carried_by_operative_id = ""
	operative.carrying_marker_id = ""
	if not operative.is_incapacitated():
		operative.record_action_performed("Place Marker")
	# Incapacitated-carrier Place Marker is 0AP and exempt from the
	# repeat-action restriction per the core rules -- not recorded as a
	# normal action use in that case.
	return result
