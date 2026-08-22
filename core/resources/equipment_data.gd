## Universal or faction equipment selected before the battle. Each
## player can select each equipment option at most once per game
## (enforced by game-setup/roster validation, not here).
##
## PHASE: 2 (Core data structures); populated Phase 12+.
class_name EquipmentData
extends Resource

@export var equipment_id: String = ""
@export var display_name: String = ""
@export var is_universal: bool = false
@export var faction_id: String = ""       # empty if universal
@export var description: String = ""
@export var effects: Array[RuleEffect] = []
@export var grants_weapons: Array[WeaponData] = []
