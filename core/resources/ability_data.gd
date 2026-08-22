## Static definition of an operative ability (e.g. Bruiser's damage
## mitigation, Medic's "Medic!" rule). Effects expressed via RuleEffect
## where possible; abilities with unique procedural logic that doesn't
## fit the generic effect model are flagged unique_procedural = true and
## get an explicit handler registered in effect_resolver.gd.
##
## PHASE: 2 (Core data structures); populated Phase 12+.
class_name AbilityData
extends Resource

@export var ability_id: String = ""
@export var display_name: String = ""
@export var description: String = ""
@export var effects: Array[RuleEffect] = []
@export var unique_procedural: bool = false
