## Static gameplay properties of a terrain piece, independent of its
## visual model. Multiple visual assets can share one TerrainData.
##
## PHASE: 2 (Core data structures); populated Phase 6/10.
class_name TerrainData
extends Resource

enum TerrainTrait { LIGHT, HEAVY, TRAVERSABLE, INSIGNIFICANT, VANTAGE, ACCESSIBLE }

@export var terrain_id: String = ""
@export var display_name: String = ""
@export var height_inches: float = 2.0
@export var traits: Array[TerrainTrait] = []
@export var blocks_line_of_sight: bool = false
@export var climbable: bool = true
