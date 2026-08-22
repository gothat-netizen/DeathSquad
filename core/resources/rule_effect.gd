## Base class for the reusable weapon/ability/ploy special-rule effect
## system (Blast, Torrent, Ceaseless, Accurate x, Severe, Punishing,
## Lethal x+, Devastating x, Piercing x, Heavy, Limited x, Silent, Seek,
## Stun, Brutal, Shock, Balanced, Saturate, Hot, and faction-specific
## effects like Guardsmen Orders). Subclassed per mechanic; NEVER
## replaced with faction-name branches inside combat_rules.gd.
##
## PHASE: 5 (Rules engine foundation) for the base shape; concrete
## subclasses land in Phase 12 alongside the content that needs them.
class_name RuleEffect
extends Resource

## When this effect applies relative to a dice roll -- see EffectResolver.EffectTiming.
@export var timing: int = 0

## --- Precedence metadata, consumed by core/rules/precedence_resolver.gd
## when two RuleEffects conflict. See the core rules' Precedence list:
## specific rule > designer's commentary > non-core-book rule > "cannot"
## > active player decides > initiative player decides. Defaults are
## all "generic" -- content that needs to win a specific conflict sets
## these explicitly rather than the engine guessing intent.
@export var specificity_level: int = 0       # higher = more specific / narrowly-scoped rule
@export var is_designer_commentary: bool = false
@export var is_non_core_book_rule: bool = false
@export var forbids_action: bool = false     # true = this is a "cannot", which beats a "can" at equal specificity
@export var source_description: String = ""  # for the combat/rules log, e.g. "Kill Team Designer's Commentary, March 2026"

func apply(context: Dictionary) -> Dictionary:
	push_warning("RuleEffect.apply() called on base class -- subclass must override (Phase 12)")
	return context
