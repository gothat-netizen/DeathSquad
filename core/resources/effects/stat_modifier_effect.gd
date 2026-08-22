## Generic RuleEffect that applies a TimedStatusEffect (APL/Move delta,
## with a duration and optional exclusivity group) to the operative in
## `context["operative"]`. This is genuinely universal infrastructure,
## not faction-specific content -- it's what implements the core rules'
## universal Stun weapon keyword ("target's APL -1 until end of its
## next activation") and is exactly the shape Death Korps' Guardsmen
## Orders need too. Concrete instances (the actual Stun weapon rule,
## the four Guardsmen Orders) are Phase 12 content; this is the
## reusable mechanism.
##
## PHASE: 5 (Rules engine foundation).
class_name StatModifierEffect
extends RuleEffect

@export var status_id: String = ""
@export var exclusivity_group: String = ""
@export var expiry: TimedStatusEffect.ExpiryTrigger = TimedStatusEffect.ExpiryTrigger.END_OF_TURNING_POINT
@export var apl_delta: int = 0
@export var move_delta_inches: float = 0.0

func apply(context: Dictionary) -> Dictionary:
	var operative: OperativeState = context.get("operative")
	if operative == null:
		push_warning("StatModifierEffect.apply(): context missing 'operative' key")
		return context

	var status := TimedStatusEffect.new()
	status.status_id = status_id
	status.exclusivity_group = exclusivity_group
	status.expiry = expiry
	status.apl_delta = apl_delta
	status.move_delta_inches = move_delta_inches
	operative.apply_status_effect(status)

	return context
