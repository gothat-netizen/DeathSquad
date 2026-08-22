## Phase 5 smoke test: TimedStatusEffect application via StatModifierEffect
## and EffectResolver.apply_effects(), the APL +/-1 / Move >=4" hard
## clamps, exclusivity-group overwrite semantics (Guardsmen-Orders-style),
## END_OF_NEXT_ACTIVATION expiry via the real GameStateManager activation
## flow, and PrecedenceResolver's 6-level resolution.
##
## Run headlessly once Godot is available:
##   godot --headless --script res://tests/unit/test_phase5_effects.gd
##
## Plain script (not GUT) -- see test_phase2_data_load.gd for why.
extends SceneTree

var _failures: int = 0

func _check(condition: bool, message: String) -> void:
	if condition:
		print("  [PASS] ", message)
	else:
		_failures += 1
		print("  [FAIL] ", message)

func _make_operative() -> OperativeState:
	var trooper_data: OperativeData = load("res://data/operatives/death_korps/trooper.tres")
	var op := OperativeState.new()
	op.operative_id = "test_trooper#0"
	op.init_from_data(trooper_data)
	return op

func _init() -> void:
	print("=== Phase 5 effect/precedence/clamp smoke test ===")

	print("-- StatModifierEffect + EffectResolver.apply_effects() (Stun-style) --")
	var resolver := EffectResolver.new()
	var op := _make_operative()
	_check(op.get_effective_apl() == 2 and op.get_effective_move() == 6.0, "baseline effective stats match datacard (APL2/Move6)")

	var stun := StatModifierEffect.new()
	stun.status_id = "stunned"
	stun.expiry = TimedStatusEffect.ExpiryTrigger.END_OF_NEXT_ACTIVATION
	stun.apl_delta = -1
	stun.timing = EffectResolver.EffectTiming.POST_ACTION

	resolver.apply_effects(EffectResolver.EffectTiming.POST_ACTION, {"operative": op}, [stun])
	_check(op.get_effective_apl() == 1, "Stun reduces effective APL by 1 (2 -> 1)")

	print("-- APL hard clamp (never more than +/-1 from base) --")
	var stun_again := StatModifierEffect.new()
	stun_again.apl_delta = -1
	stun_again.timing = EffectResolver.EffectTiming.POST_ACTION
	resolver.apply_effects(EffectResolver.EffectTiming.POST_ACTION, {"operative": op}, [stun_again])
	_check(op.get_effective_apl() == 1, "a second stacked -1 does NOT push APL below base-1 (clamp holds, still APL 1 not 0)")
	resolver.apply_stat_clamps(op)
	_check(op.get_effective_apl() == 1, "apply_stat_clamps() normalizes stored modifier without changing the already-clamped effective value")

	print("-- Move hard clamp (never below 4\") --")
	var op2 := _make_operative()
	var move_penalty := StatModifierEffect.new()
	move_penalty.move_delta_inches = -10.0   # deliberately absurd to prove the floor
	move_penalty.timing = EffectResolver.EffectTiming.POST_ACTION
	resolver.apply_effects(EffectResolver.EffectTiming.POST_ACTION, {"operative": op2}, [move_penalty])
	_check(op2.get_effective_move() == 4.0, "Move never drops below 4\" even with a -10\" stacked penalty")

	print("-- Exclusivity group overwrite (Guardsmen-Orders-style) --")
	var op3 := _make_operative()
	var order_a := TimedStatusEffect.new()
	order_a.status_id = "order_advance"
	order_a.exclusivity_group = "death_korps_guardsmen_order"
	order_a.move_delta_inches = 2.0
	order_a.expiry = TimedStatusEffect.ExpiryTrigger.END_OF_TURNING_POINT
	op3.apply_status_effect(order_a)
	_check(op3.get_effective_move() == 8.0, "first order applies (+2\" move)")

	var order_b := TimedStatusEffect.new()
	order_b.status_id = "order_hold"
	order_b.exclusivity_group = "death_korps_guardsmen_order"
	order_b.move_delta_inches = -1.0
	order_b.expiry = TimedStatusEffect.ExpiryTrigger.END_OF_TURNING_POINT
	op3.apply_status_effect(order_b)
	_check(op3.active_status_effects.size() == 1, "applying a second order in the same exclusivity group REPLACES the first, not stacks (only 1 active effect)")
	_check(op3.get_effective_move() == 5.0, "only the most recent order's modifier applies (+2 gone, -1 in effect: 6 - 1 = 5)")

	print("-- Turning-point-scoped expiry via ready_for_new_turning_point() --")
	op3.ready_for_new_turning_point()
	_check(op3.active_status_effects.is_empty(), "END_OF_TURNING_POINT effects clear when the turning point resets")
	_check(op3.get_effective_move() == 6.0, "move back to baseline after the order expires")

	print("-- END_OF_NEXT_ACTIVATION expiry via the real activation flow --")
	GameStateManager.start_new_game({
		"seed": 777,
		"players": {0: {"faction_id": "death_korps"}, 1: {"faction_id": "kommandos"}},
	})
	GameStateManager.end_gambit_step()
	var live_state: GameState = GameStateManager.current_state
	var live_op: OperativeState = live_state.get_operatives_for_player(0)[0]
	var stun_live := StatModifierEffect.new()
	stun_live.apl_delta = -1
	stun_live.expiry = TimedStatusEffect.ExpiryTrigger.END_OF_NEXT_ACTIVATION
	resolver.apply_effects(EffectResolver.EffectTiming.POST_ACTION, {"operative": live_op}, [stun_live])
	_check(live_op.get_effective_apl() == 1, "operative is Stunned before activating (APL 2 -> 1)")
	GameStateManager.activate_operative(live_op.operative_id)
	_check(live_op.get_effective_apl() == 2, "Stun clears once the operative's activation completes (APL back to 2)")

	print("-- PrecedenceResolver --")
	var precedence := PrecedenceResolver.new()

	var single := precedence.resolve([stun])
	_check(single["effect"] == stun and single["requires_decision_by"] == PrecedenceResolver.DecisionOwner.NONE, "a single candidate resolves trivially")

	var generic_a := RuleEffect.new()
	var specific_b := RuleEffect.new()
	specific_b.specificity_level = 5
	var specific_result := precedence.resolve([generic_a, specific_b])
	_check(specific_result["effect"] == specific_b, "the more specific rule wins outright")

	var cannot_effect := RuleEffect.new()
	cannot_effect.forbids_action = true
	var can_effect := RuleEffect.new()
	var cannot_result := precedence.resolve([can_effect, cannot_effect])
	_check(cannot_result["effect"] == cannot_effect, "'cannot' beats 'can' at equal specificity")

	var tied_a := RuleEffect.new()
	var tied_b := RuleEffect.new()
	var tied_result := precedence.resolve([tied_a, tied_b])
	_check(tied_result["effect"] == null and tied_result["requires_decision_by"] == PrecedenceResolver.DecisionOwner.ACTIVE_PLAYER, "a genuine tie honestly reports that it needs a player decision, rather than guessing")

	print("=== %s ===" % ("ALL PASS" if _failures == 0 else "%d FAILURE(S)" % _failures))
	quit(1 if _failures > 0 else 0)
