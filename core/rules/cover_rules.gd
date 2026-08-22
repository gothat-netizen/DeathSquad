## Cover and Obscured determination, confirmed against the actual core
## rules text (Cover, Obscured sections).
##
## Cover: intervening terrain within the TARGET's control range (i.e.
## within 1" of the target), but the target can never be in cover while
## within 2" of the ATTACKER, regardless of terrain.
##
## Obscured: intervening HEAVY terrain specifically, ignoring any part
## of that terrain within 1" of EITHER operative.
##
## KNOWN SIMPLIFICATION: "ignoring any part within 1"" is a per-point
## rule (only the nearby part of a large terrain piece stops obscuring,
## not the whole piece) -- this implementation checks the closest point
## of the whole obstacle rect to each operative, which is a reasonable
## approximation without a real per-point terrain mesh (Phase 10/13).
## Also NOT implemented: "cannot be in cover from and obscured by the
## same terrain feature -- defender chooses" -- a genuine defender
## decision with no prompt system yet (same seam as Initiative/
## Precedence/action-selection). Both are flagged rather than silently
## approximated away.
##
## PHASE: 7 (Combat engine).
class_name CoverRules
extends RefCounted

## Each obstacle: {"rect": Rect2, "is_heavy": bool}.
func is_in_cover(attacker: OperativeState, target: OperativeState, obstacles: Array[Dictionary] = []) -> bool:
	if attacker.position.distance_to(target.position) <= 2.0:
		return false
	for obstacle in obstacles:
		var rect: Rect2 = obstacle.get("rect")
		if _intervenes(attacker.position, target.position, rect) and _closest_distance(rect, target.position) <= 1.0:
			return true
	return false

func is_obscured(attacker: OperativeState, target: OperativeState, obstacles: Array[Dictionary] = []) -> bool:
	for obstacle in obstacles:
		if not obstacle.get("is_heavy", false):
			continue
		var rect: Rect2 = obstacle.get("rect")
		if not _intervenes(attacker.position, target.position, rect):
			continue
		if _closest_distance(rect, attacker.position) > 1.0 and _closest_distance(rect, target.position) > 1.0:
			return true
	return false

func _closest_distance(rect: Rect2, point: Vector2) -> float:
	var clamped := Vector2(
		clampf(point.x, rect.position.x, rect.position.x + rect.size.x),
		clampf(point.y, rect.position.y, rect.position.y + rect.size.y)
	)
	return point.distance_to(clamped)

func _intervenes(from_pos: Vector2, to_pos: Vector2, rect: Rect2) -> bool:
	if rect.has_point(from_pos) or rect.has_point(to_pos):
		return true
	var corners := [
		rect.position,
		rect.position + Vector2(rect.size.x, 0),
		rect.position + rect.size,
		rect.position + Vector2(0, rect.size.y),
	]
	for i in range(4):
		if Geometry2D.segment_intersects_segment(from_pos, to_pos, corners[i], corners[(i + 1) % 4]):
			return true
	return false
