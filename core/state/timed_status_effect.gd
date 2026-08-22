## A stat-modifying effect applied to an operative for a bounded duration.
## Generic infrastructure serving two confirmed needs:
## - Universal weapon keyword Stun ("target's APL -1 until end of its
##   next activation")
## - Death Korps' Guardsmen Orders (turning-point-scoped, mutually
##   exclusive within an `exclusivity_group` -- applying a new one in the
##   same group REPLACES the old one rather than stacking)
##
## Not itself a RuleEffect (RuleEffect subclasses like StatModifierEffect
## CREATE these when applied); this is the runtime record living on
## OperativeState.active_status_effects.
##
## PHASE: 5 (Rules engine foundation).
class_name TimedStatusEffect
extends RefCounted

enum ExpiryTrigger { END_OF_NEXT_ACTIVATION, END_OF_TURNING_POINT, END_OF_BATTLE }

var status_id: String = ""
## Effects sharing a non-empty exclusivity_group overwrite each other
## when applied (see OperativeState.apply_status_effect) rather than
## stacking -- "only the most recent order benefits" semantics.
var exclusivity_group: String = ""
var expiry: ExpiryTrigger = ExpiryTrigger.END_OF_TURNING_POINT
var apl_delta: int = 0
var move_delta_inches: float = 0.0
