## Visibility and Control Range.
##
## Rules text confirmed directly from the core rules (Visible, Control
## Range): Visible requires an unobstructed 1mm-wide line from the active
## operative's head to any part of the target's miniature (ignoring
## bases), drawn in 3D when there's a height difference. Control Range
## is mutual: within 1" AND visible.
##
## SCOPE NOTE: no terrain/elevation data exists yet (maps and terrain
## placements land in Phase 10/13), so this phase implements the real
## geometry contract -- 2D line-vs-obstacle intersection, given an
## explicit list of blocking shapes -- rather than pretending to query a
## battlefield that doesn't exist. With no obstacles supplied, everything
## is visible (open ground). The 3D/height-aware version (needed once
## Vantage terrain exists) is a follow-up once real terrain data exists.
##
## Independent from the camera -- never rely on Godot's rendering
## visibility to answer these queries, even once presentation/ exists.
##
## PHASE: 6 (Movement and spatial rules).
class_name LineOfSightRules
extends RefCounted

## Each blocking obstacle is a Rect2 in battlefield inches (2D
## footprint). This is a deliberately simple placeholder shape --
## real terrain will need richer footprints (Phase 10/13).
func is_visible(from_position: Vector2, to_position: Vector2, blocking_obstacles: Array[Rect2] = []) -> bool:
	for obstacle in blocking_obstacles:
		if _segment_intersects_rect(from_position, to_position, obstacle):
			return false
	return true

func is_operative_visible(from_op: OperativeState, to_op: OperativeState, blocking_obstacles: Array[Rect2] = []) -> bool:
	if from_op == to_op:
		return true  # "An operative is always visible to itself."
	return is_visible(from_op.position, to_op.position, blocking_obstacles)

func is_within_control_range(a: OperativeState, b: OperativeState, blocking_obstacles: Array[Rect2] = []) -> bool:
	if a == b:
		return true
	return a.position.distance_to(b.position) <= 1.0 and is_operative_visible(a, b, blocking_obstacles)

## Shortest distance from `point` to the segment a-b -- used by
## movement_rules.gd to check whether a MOVE PATH (not just its
## endpoint) passes within control range of an enemy.
func distance_point_to_segment(point: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var len_sq := ab.length_squared()
	if len_sq == 0.0:
		return point.distance_to(a)
	var t: float = clampf((point - a).dot(ab) / len_sq, 0.0, 1.0)
	var closest: Vector2 = a + ab * t
	return point.distance_to(closest)

func _segment_intersects_rect(p1: Vector2, p2: Vector2, rect: Rect2) -> bool:
	if rect.has_point(p1) or rect.has_point(p2):
		return true
	var corners := [
		rect.position,
		rect.position + Vector2(rect.size.x, 0),
		rect.position + rect.size,
		rect.position + Vector2(0, rect.size.y),
	]
	for i in range(4):
		if Geometry2D.segment_intersects_segment(p1, p2, corners[i], corners[(i + 1) % 4]):
			return true
	return false
