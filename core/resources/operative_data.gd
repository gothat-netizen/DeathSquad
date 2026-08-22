## Static datacard definition for an operative type (e.g. "Death Korps
## Trooper"). Independent from OperativeState (runtime, mutable) and
## from the operative's visual scene (presentation/operatives/).
##
## PHASE: 2 (Core data structures).
class_name OperativeData
extends Resource

@export var operative_id: String = ""
@export var display_name: String = ""
@export var faction_id: String = ""
@export var keywords: PackedStringArray = []  # e.g. ["DEATH KORPS", "IMPERIUM", "ASTRA MILITARUM", "TROOPER"]

@export var apl: int = 2
@export var move_inches: float = 6.0
@export var save_threshold: int = 5   # "5+" stored as 5
@export var wounds: int = 7
@export var base_size_mm: int = 25

@export var weapons: Array[WeaponData] = []
@export var abilities: Array[AbilityData] = []
@export var unique_actions: Array[UniqueActionData] = []

## Order restriction, e.g. Kommando Grot cannot Engage, Bomb Squig cannot
## Conceal. Empty array = no restriction (both orders allowed).
@export var forbidden_orders: PackedStringArray = []

func allows_order(order_name: String) -> bool:
	return not forbidden_orders.has(order_name)

func get_weapons_by_base_name(base_name: String) -> Array[WeaponData]:
	var matches: Array[WeaponData] = []
	for weapon in weapons:
		if weapon.base_name == base_name:
			matches.append(weapon)
	return matches

func has_keyword(keyword: String) -> bool:
	return keywords.has(keyword)
