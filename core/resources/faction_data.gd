## Faction-wide rules container: identity, faction rules (e.g. Death
## Korps' Guardsmen Orders, Kommandos' Throat Slittas), strategy/firefight
## ploys, faction equipment, and the operative roster list with any
## selection restrictions (e.g. "only TROOPER may repeat").
##
## PHASE: 2 (Core data structures); populated Phase 12 for Death Korps
## and Kommandos specifically.
class_name FactionData
extends Resource

@export var faction_id: String = ""
@export var display_name: String = ""
@export var faction_keyword: String = ""   # e.g. "DEATH KORPS", "KOMMANDO"

@export var faction_rules: Array[RuleEffect] = []
@export var strategy_ploys: Array[PloyData] = []
@export var firefight_ploys: Array[PloyData] = []
@export var faction_equipment: Array[EquipmentData] = []
@export var roster: Array[OperativeData] = []

func get_operative_by_id(operative_id: String) -> OperativeData:
	for op in roster:
		if op.operative_id == operative_id:
			return op
	return null
