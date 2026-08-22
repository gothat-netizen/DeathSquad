## Data object representing the outcome of a single dice roll request.
##
## Produced exclusively by DiceRoller. Never constructed by gameplay
## scripts directly -- if you need a die rolled, ask DiceService, not
## Godot's built-in RNG.
##
## PHASE: 4 (Dice/randomization system) implements the fields below.
class_name RollResult
extends RefCounted

enum ResultType { FAIL, NORMAL_SUCCESS, CRITICAL_SUCCESS }

var raw_values: Array[int] = []          # The untouched D6 results, in roll order
var result_types: Array[ResultType] = [] # Parallel array: classification of each raw value
var cause: String = ""                   # e.g. "Shoot: Death Korps Trooper lasgun attack dice"
var modifiers_applied: Array[String] = [] # Human-readable log of rerolls/Accurate/etc. for the combat log
var seed_state: int = 0                  # RNG state at time of roll, for replay/debugging

func count_of(result_type: ResultType) -> int:
	var count := 0
	for t in result_types:
		if t == result_type:
			count += 1
	return count

func normal_success_count() -> int:
	return count_of(ResultType.NORMAL_SUCCESS)

func critical_success_count() -> int:
	return count_of(ResultType.CRITICAL_SUCCESS)

## Normal successes AND crits combined -- what most weapon effects mean
## by "successes" unless they specifically say "crits".
func total_success_count() -> int:
	return normal_success_count() + critical_success_count()

func fail_count() -> int:
	return count_of(ResultType.FAIL)
