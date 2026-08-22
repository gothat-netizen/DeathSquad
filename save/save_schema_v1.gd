## Save-file schema version 1. Save files must include rules_version,
## content_version, random_seed, mission, full game state, operative
## states, positions, objectives, scores. Never save references to
## temporary scene nodes -- only GameState/StateSnapshot data.
##
## PHASE: 14 (Save/load).
class_name SaveSchemaV1
extends RefCounted

const SCHEMA_VERSION := 1
