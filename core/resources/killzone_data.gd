## Killzone definition (terrain set + killzone-specific rules, e.g.
## Close Quarters). Referenced by MapData / mission generation.
##
## PHASE: 2 (Core data structures); populated Phase 13.
class_name KillzoneData
extends Resource

@export var killzone_id: String = ""
@export var display_name: String = ""
@export var special_rules: Array[RuleEffect] = []
