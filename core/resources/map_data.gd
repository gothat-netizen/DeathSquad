## Static map/board definition: dimensions, deployment zones, objective
## positions, terrain placement list. The visual battlefield is
## generated FROM this, not the other way around.
##
## PHASE: 2 (Core data structures); populated Phase 10/13.
class_name MapData
extends Resource

@export var map_id: String = ""
@export var display_name: String = ""
@export var board_size: Vector2 = Vector2(30, 22)   # inches
@export var deployment_zones: Array[Dictionary] = []
@export var terrain_placements: Array[Dictionary] = []
@export var objective_positions: Array[Vector2] = []
