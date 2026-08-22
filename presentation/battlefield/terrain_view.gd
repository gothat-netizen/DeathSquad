## Instances visual terrain models from a MapData's terrain_placements,
## using whatever visual asset is mapped to each TerrainData id. The
## gameplay properties always come from TerrainData, never inferred from
## the visual mesh.
##
## PHASE: 10 (Isometric battlefield).
class_name TerrainView
extends Node3D

func build_from_map(_map_data: Resource) -> void:
	push_warning("TerrainView.build_from_map() not yet implemented (Phase 10)")
