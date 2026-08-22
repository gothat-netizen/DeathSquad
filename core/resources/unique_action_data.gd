## Named unique action available only to specified operatives (e.g.
## MEDIKIT, SPOT, SIGNAL, GET IT DUN!, DAKKA DASH, GRAPPLING HOOK).
##
## Distinct from AbilityData: an AbilityData is a passive/triggered
## rule modifier; a UniqueActionData is a full Action an operative
## spends AP to perform during "Perform Actions", competing with the
## universal actions (Shoot, Fight, Dash, etc.) for that operative's
## APL. Some are flagged is_support = true (the SUPPORT keyword --
## can't be performed by an operative that already performed a
## non-SUPPORT action this activation, or vice versa, per core rules).
##
## PHASE: 2 (Core data structures) for the shape; populated Phase 12+.
class_name UniqueActionData
extends Resource

@export var action_id: String = ""
@export var display_name: String = ""
@export var ap_cost: int = 1
@export var description: String = ""
@export var is_support: bool = false
@export var requires_order: int = -1   # -1 = no restriction; OperativeState.Order otherwise
@export var effects: Array[RuleEffect] = []
@export var unique_procedural: bool = false
