## Generic interpreter for weapon/ability/ploy special rules (RuleEffect
## and subclasses). Combat/movement code calls into this rather than
## branching on faction, operative, or weapon name.
##
## Confirmed timing hooks (see death-korps-kommandos-mapping.md section 1):
##   PRE_ROLL       - e.g. Accurate x, Range x
##   POST_ROLL      - e.g. Severe, Punishing, Lethal x+, Obscured discard
##   POST_ACTION    - e.g. Hot, Devastating x's immediate damage
##
## Also owns the final STAT CLAMP pass (APL total change never > +/-1
## from base, Move never < 4", AP per action never < 0) -- applied AFTER
## all additive/multiplicative effects, taking precedence over them.
##
## PHASE: 5 (Rules engine foundation) stands up the enum/dispatch;
## individual RuleEffect subclasses are added alongside the content
## that needs them (Phase 12 onward).
class_name EffectResolver
extends RefCounted

enum EffectTiming { PRE_ROLL, POST_ROLL, POST_ACTION }

## Runs every effect in `effects` whose `timing` matches, in array order,
## threading `context` through each. Order-sensitivity between two
## effects at the SAME timing that genuinely conflict is what
## PrecedenceResolver is for -- this function does not itself resolve
## conflicts, only sequences same-timing effects as given.
func apply_effects(timing: EffectTiming, context: Dictionary, effects: Array[RuleEffect]) -> Dictionary:
	for effect in effects:
		if effect.timing == timing:
			context = effect.apply(context)
	return context

## Explicit final clamp pass: APL total change never exceeds +/-1 from
## base, Move never drops below 4". Both are ALSO enforced live by
## OperativeState.get_effective_apl()/get_effective_move() (the actual
## source of truth read by movement/combat code) -- this pass exists to
## normalize stored state for anything that inspects _apl_modifier
## directly (debug tooling, save data) rather than going through those
## getters, and as the documented, explicit "clamp step" the master
## spec calls for. AP-per-action >=0 isn't an OperativeState field (it's
## a per-action cost calculation) -- see clamp_ap_cost() below, called
## by movement_rules/combat_rules wherever an action's AP cost is
## computed (Phase 6/7).
func apply_stat_clamps(operative: OperativeState) -> void:
	operative.clamp_stored_apl_modifier()
	# Move's floor is on the EFFECTIVE value, not the modifier itself --
	# a very negative move_modifier is left as-is in storage (it may
	# reflect several real stacked penalties) and only floored on read.
	# Nothing to normalize here without discarding that information.

func clamp_ap_cost(cost: int) -> int:
	return max(0, cost)
