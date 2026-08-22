## Static weapon profile. Ranged or Melee. Supports the multi-profile
## pattern (e.g. "plasma gun (standard)" / "plasma gun (supercharge)",
## "burna (standard)" / "burna (deluge)") via base_name -- a rule
## referencing the bare name should match every profile sharing it.
##
## PHASE: 2 (Core data structures).
class_name WeaponData
extends Resource

enum WeaponType { RANGED, MELEE }

@export var weapon_id: String = ""
@export var base_name: String = ""      # e.g. "plasma gun" -- shared across profiles
@export var display_name: String = ""   # e.g. "Plasma gun (supercharge)"
@export var weapon_type: WeaponType = WeaponType.RANGED

@export var atk: int = 4
@export var hit_threshold: int = 4      # "4+" stored as 4
@export var normal_dmg: int = 3
@export var critical_dmg: int = 4

## Weapon rules as data-driven effects rather than hardcoded branches --
## see core/resources/rule_effect.gd and death-korps-kommandos-mapping.md
## section 1 for the confirmed keyword list.
@export var weapon_rules: Array[RuleEffect] = []

func has_rule(rule_class: String) -> bool:
	for rule in weapon_rules:
		if rule.get_class() == rule_class or (rule.get_script() and rule.get_script().get_global_name() == rule_class):
			return true
	return false
