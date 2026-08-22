## Formal implementation of the core rules' Precedence system -- used
## whenever two RuleEffects (or a RuleEffect and a base rule) conflict.
##
## Priority order (core rules, "Precedence"):
##   1. The specific rule says so
##   2. Designer's commentary says so
##   3. Not found in the core book (non-core-book rules win)
##   4. The rule says "cannot"
##   5. Active operative's controlling player decides
##   6. Player with initiative decides
##
## Levels 1-4 are automatic (decided by RuleEffect metadata). Levels 5-6
## need an actual decision from a player or AI -- that prompt doesn't
## exist yet (same seam as the Initiative tie-break in GameStateManager,
## deferred to Phase 9/11). resolve() surfaces that honestly: it returns
## requires_decision_by instead of guessing, rather than silently
## picking one side.
##
## PHASE: 5 (Rules engine foundation).
class_name PrecedenceResolver
extends RefCounted

enum DecisionOwner { NONE, ACTIVE_PLAYER, INITIATIVE_PLAYER }

## Returns {"effect": RuleEffect or null, "requires_decision_by":
## DecisionOwner, "reason": String}. `effect` is null exactly when
## requires_decision_by != NONE -- the caller must obtain a real
## decision (Phase 9/11) before proceeding; this layer will not guess.
func resolve(conflicting_effects: Array[RuleEffect]) -> Dictionary:
	if conflicting_effects.is_empty():
		return {"effect": null, "requires_decision_by": DecisionOwner.NONE, "reason": "no conflicting effects given"}
	if conflicting_effects.size() == 1:
		return {"effect": conflicting_effects[0], "requires_decision_by": DecisionOwner.NONE, "reason": "only one candidate -- nothing to resolve"}

	# 1. Specific rule: highest specificity_level wins if it's unique.
	var max_specificity: int = -1
	for e in conflicting_effects:
		max_specificity = max(max_specificity, e.specificity_level)
	var candidates: Array[RuleEffect] = conflicting_effects.filter(
		func(e): return e.specificity_level == max_specificity
	)
	if candidates.size() == 1:
		return {"effect": candidates[0], "requires_decision_by": DecisionOwner.NONE, "reason": "the more specific rule takes precedence"}

	# 2. Designer's commentary.
	var commentary: Array[RuleEffect] = candidates.filter(func(e): return e.is_designer_commentary)
	if commentary.size() == 1:
		return {"effect": commentary[0], "requires_decision_by": DecisionOwner.NONE, "reason": "designer's commentary takes precedence"}
	elif commentary.size() > 1:
		candidates = commentary

	# 3. Non-core-book rule.
	var non_core: Array[RuleEffect] = candidates.filter(func(e): return e.is_non_core_book_rule)
	if non_core.size() == 1:
		return {"effect": non_core[0], "requires_decision_by": DecisionOwner.NONE, "reason": "non-core-book rule takes precedence"}
	elif non_core.size() > 1:
		candidates = non_core

	# 4. "Cannot" beats "can".
	var forbidding: Array[RuleEffect] = candidates.filter(func(e): return e.forbids_action)
	if not forbidding.is_empty():
		return {"effect": forbidding[0], "requires_decision_by": DecisionOwner.NONE, "reason": "'cannot' takes precedence over 'can'"}

	# 5/6. Still genuinely tied -- this requires a real decision from the
	# active operative's controlling player (falling back to the
	# initiative player where that's inapplicable). No automatic answer.
	return {
		"effect": null,
		"requires_decision_by": DecisionOwner.ACTIVE_PLAYER,
		"reason": "tied after all automatic precedence levels -- needs a player decision (Phase 9/11)",
	}
