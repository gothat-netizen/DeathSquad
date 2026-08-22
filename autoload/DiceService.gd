## Autoload wrapper around core/dice/dice_roller.gd. The ONLY sanctioned
## source of randomness in the project -- see master spec's "Dice System".
extends Node

var _roller: DiceRoller = DiceRoller.new()

func seed_with(seed_value: int) -> void:
	_roller.seed_with(seed_value)

func roll_attack_dice(count: int, hit_threshold: int, cause: String) -> RollResult:
	return _roller.roll_attack_dice(count, hit_threshold, cause)

func roll_defence_dice(count: int, save_threshold: int, cause: String) -> RollResult:
	return _roller.roll_defence_dice(count, save_threshold, cause)

func roll_single_d6(cause: String) -> int:
	return _roller.roll_single_d6(cause)

func roll_d3(cause: String) -> int:
	return _roller.roll_d3(cause)

func reroll_die(cause: String) -> int:
	return _roller.reroll_die(cause)

func roll_off(contestant_ids: Array, cause: String) -> Dictionary:
	return _roller.roll_off(contestant_ids, cause)

func get_roll_log() -> Array[RollResult]:
	return _roller.roll_log
