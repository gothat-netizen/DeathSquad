## Centralized dice/RNG service. ALL random rolls in the game must go
## through this class -- never call randi()/randf() from gameplay code.
##
## Responsibilities (see master spec, "Dice System"):
## - Deterministic given a seed
## - Supports xD6/xD3, D6+x/D3+x, success thresholds, crits, rerolls,
##   automatic successes/failures, roll manipulation
## - Every roll is logged (RollResult.cause) for the combat/game log
##
## Classification rule (shared by attack AND defence dice -- Save works
## the same way Hit does): unmodified 1 always fails, unmodified 6 is
## always a critical success, everything else compares to the threshold.
## "Automatic successes/failures" (e.g. Accurate x retaining successes
## without rolling) are an EffectResolver concern (Phase 5) layered on
## top of these primitives, not something DiceRoller does itself.
##
## PHASE: 4 (Dice/randomization system).
class_name DiceRoller
extends RefCounted

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var roll_log: Array[RollResult] = []

func seed_with(seed_value: int) -> void:
	_rng.seed = seed_value

## Rolls one D6 and classifies it against `threshold`. Shared by
## roll_attack_dice/roll_defence_dice below and available directly for
## single-die rolls (e.g. Initiative, roll-offs) that need the raw value.
func _roll_and_classify_die(threshold: int) -> Dictionary:
	var value: int = _rng.randi_range(1, 6)
	var result_type: RollResult.ResultType
	if value == 1:
		result_type = RollResult.ResultType.FAIL
	elif value == 6:
		result_type = RollResult.ResultType.CRITICAL_SUCCESS
	elif value >= threshold:
		result_type = RollResult.ResultType.NORMAL_SUCCESS
	else:
		result_type = RollResult.ResultType.FAIL
	return {"value": value, "type": result_type}

func _roll_dice_set(count: int, threshold: int, cause: String) -> RollResult:
	var result := RollResult.new()
	result.cause = cause
	for i in range(count):
		var rolled := _roll_and_classify_die(threshold)
		result.raw_values.append(rolled["value"])
		result.result_types.append(rolled["type"])
	result.seed_state = _rng.state
	roll_log.append(result)
	return result

func roll_attack_dice(count: int, hit_threshold: int, cause: String) -> RollResult:
	return _roll_dice_set(count, hit_threshold, cause)

func roll_defence_dice(count: int, save_threshold: int, cause: String) -> RollResult:
	return _roll_dice_set(count, save_threshold, cause)

## Single unclassified D6, for contexts with no success threshold
## (Initiative rolls, roll-offs, damage-table style lookups).
func roll_single_d6(cause: String) -> int:
	var value: int = _rng.randi_range(1, 6)
	var result := RollResult.new()
	result.cause = cause
	result.raw_values.append(value)
	result.seed_state = _rng.state
	roll_log.append(result)
	return value

func roll_d3(cause: String) -> int:
	var value := roll_single_d6(cause + " (D3)")
	return (value + 1) / 2   # 1-2->1, 3-4->2, 5-6->3

## Re-rolls a single die and logs it distinctly from the original roll,
## so the combat log shows both the original and rerolled values (e.g.
## for Balanced/Ceaseless/Command Re-roll). Callers apply the new
## classification themselves via the same threshold as the original roll.
func reroll_die(cause: String) -> int:
	return roll_single_d6(cause + " (reroll)")

## Generic Roll-off: each contestant rolls 1D6, highest wins; ties are
## resolved by re-rolling only the tied contestants. NOTE: this is the
## generic core-rules Roll-off definition -- the Strategy phase
## Initiative step has its OWN tie-break (previous turning point's
## non-initiative player decides), which does not reroll and is
## implemented in GameStateManager, not here.
func roll_off(contestant_ids: Array, cause: String) -> Dictionary:
	var rolls: Dictionary = {}
	for id in contestant_ids:
		rolls[id] = roll_single_d6("%s (roll-off)" % cause)

	var highest: int = -1
	for id in rolls:
		highest = max(highest, rolls[id])
	var winners: Array = contestant_ids.filter(func(id): return rolls[id] == highest)

	if winners.size() == 1:
		return {"winner": winners[0], "rolls": rolls}

	var tiebreak := roll_off(winners, cause)
	return {"winner": tiebreak["winner"], "rolls": rolls, "tiebreak": tiebreak}
