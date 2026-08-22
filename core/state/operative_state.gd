## Mutable runtime state for a single operative on the battlefield.
##
## DO NOT confuse this with OperativeData (data/operatives/*) -- Data is
## the static datacard definition (APL/Move/Save/Wounds base stats,
## weapons, abilities); State is what changes during a battle (current
## wounds, position, order, ready/expended, active status effects,
## per-weapon use counters for Limited x, etc.)
##
## Scene nodes in presentation/ READ from this. They never own it.
##
## PHASE: 3 (GameState and event system).
class_name OperativeState
extends RefCounted

enum Order { CONCEAL, ENGAGE }

var operative_id: String = ""
var data: OperativeData = null
var owning_player: int = -1
var current_wounds: int = 0
var position: Vector2 = Vector2.ZERO
var order: Order = Order.CONCEAL
var is_ready: bool = true
var has_counteracted_this_turning_point: bool = false
var weapon_use_counts: Dictionary = {}    # weapon_id -> int, for Limited x
var active_status_effects: Array[TimedStatusEffect] = []
## Which named actions (Reposition, Dash, Charge, ...) this operative has
## already performed THIS activation -- movement actions in particular
## have explicit same-activation mutual-exclusivity rules that key off
## this (see movement_rules.gd). Reset at the start of each activation.
var actions_performed_this_activation: Array[String] = []
## "" = not carrying a marker. While set, this operative is the ONLY
## operative that contests/controls that marker (see objective_rules.gd).
var carrying_marker_id: String = ""

## Derived from active_status_effects -- see _recompute_status_modifiers().
## Not set directly; go through apply_status_effect()/expire_status_effects().
var _apl_modifier: int = 0
var _move_modifier_inches: float = 0.0

func init_from_data(operative_data: OperativeData) -> void:
	data = operative_data
	current_wounds = operative_data.wounds

func is_wounded() -> bool:
	return data != null and current_wounds < data.wounds

func is_injured() -> bool:
	# When true: Move -2" (folded into get_effective_move() below), weapon
	# Hit worsened by 1 (that half is combat_rules.gd's job, Phase 7 --
	# it reads is_injured() rather than this class knowing about weapons).
	return data != null and current_wounds < (data.wounds / 2.0)

func is_incapacitated() -> bool:
	return current_wounds <= 0

## Low-level state mutator only -- does NOT emit events or apply combat
## rules (blocking, cover, etc.). Combat resolution (Phase 7) calls this
## after it has already worked out how much damage gets through.
func apply_damage(amount: int) -> void:
	current_wounds = max(0, current_wounds - amount)

## Applies a TimedStatusEffect. If it belongs to an exclusivity group,
## any existing effect in that same group is replaced rather than
## stacked -- "only the most recent order benefits" (Guardsmen Orders),
## as opposed to Stun (empty exclusivity_group -- stacks freely, though
## in practice nothing currently stacks Stun on top of Stun).
func apply_status_effect(effect: TimedStatusEffect) -> void:
	if effect.exclusivity_group != "":
		active_status_effects = active_status_effects.filter(
			func(e): return e.exclusivity_group != effect.exclusivity_group
		)
	active_status_effects.append(effect)
	_recompute_status_modifiers()

func expire_status_effects(trigger: TimedStatusEffect.ExpiryTrigger) -> void:
	active_status_effects = active_status_effects.filter(func(e): return e.expiry != trigger)
	_recompute_status_modifiers()

func _recompute_status_modifiers() -> void:
	_apl_modifier = 0
	_move_modifier_inches = 0.0
	for e in active_status_effects:
		_apl_modifier += e.apl_delta
		_move_modifier_inches += e.move_delta_inches

## APL total change can never exceed +/-1 from base, regardless of how
## many stacked effects are modifying it -- a hard clamp, not a soft cap.
func get_effective_apl() -> int:
	return data.apl + clampi(_apl_modifier, -1, 1)

## Move can never drop below 4" regardless of stacked penalties. Injured
## folds in here directly (continuous, wound-state-driven) rather than
## as a TimedStatusEffect (which models bounded-duration effects).
func get_effective_move() -> float:
	var injured_penalty := -2.0 if is_injured() else 0.0
	return max(4.0, data.move_inches + _move_modifier_inches + injured_penalty)

## Normalizes the stored APL modifier into its hard clamp range. Called
## by EffectResolver.apply_stat_clamps() rather than reached into
## directly -- get_effective_apl() already clamps on read regardless,
## so this only matters for anything inspecting stored state directly
## (debug tooling, save data).
func clamp_stored_apl_modifier() -> void:
	_apl_modifier = clampi(_apl_modifier, -1, 1)

## Called by GameStateManager at the start of each turning point's Ready
## step. Clears turning-point-scoped status effects (e.g. Guardsmen
## Orders); END_OF_NEXT_ACTIVATION-scoped effects (e.g. Stun) clear
## separately when the operative finishes its next activation -- see
## GameStateManager.activate_operative().
func ready_for_new_turning_point() -> void:
	is_ready = true
	has_counteracted_this_turning_point = false
	expire_status_effects(TimedStatusEffect.ExpiryTrigger.END_OF_TURNING_POINT)

## Called by GameStateManager at the start of each activation (Determine
## Order step), before any actions are performed.
func reset_activation_actions() -> void:
	actions_performed_this_activation.clear()

func record_action_performed(action_name: String) -> void:
	if not actions_performed_this_activation.has(action_name):
		actions_performed_this_activation.append(action_name)

func has_performed_action(action_name: String) -> bool:
	return actions_performed_this_activation.has(action_name)
