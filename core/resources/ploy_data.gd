## Strategy ploy (STRATEGIC GAMBIT, used in the Gambit step) or Firefight
## ploy (used during the Firefight phase). Cost defaults to 1CP per core
## rules unless overridden.
##
## PHASE: 2 (Core data structures); populated Phase 12+.
class_name PloyData
extends Resource

enum PloyType { STRATEGY, FIREFIGHT }

@export var ploy_id: String = ""
@export var display_name: String = ""
@export var ploy_type: PloyType = PloyType.STRATEGY
@export var cp_cost: int = 1
@export var description: String = ""
@export var effects: Array[RuleEffect] = []
@export var once_per_battle: bool = false
@export var once_per_turning_point: bool = true
