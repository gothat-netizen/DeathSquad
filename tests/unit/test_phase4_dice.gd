## Phase 4 smoke test: DiceRoller determinism, classification rules
## (unmodified 1 always fails, unmodified 6 always crits, threshold
## comparison otherwise), D3, and roll-off tie handling.
##
## Run headlessly once Godot is available:
##   godot --headless --script res://tests/unit/test_phase4_dice.gd
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

func _init() -> void:
	print("=== Phase 4 dice system smoke test ===")

	print("-- Determinism --")
	var roller_a := DiceRoller.new()
	roller_a.seed_with(999)
	var roll_a := roller_a.roll_attack_dice(10, 4, "determinism check A")

	var roller_b := DiceRoller.new()
	roller_b.seed_with(999)
	var roll_b := roller_b.roll_attack_dice(10, 4, "determinism check B")

	_check(roll_a.raw_values == roll_b.raw_values, "same seed produces identical raw values across independent DiceRoller instances")
	_check(roll_a.result_types == roll_b.result_types, "same seed produces identical classifications")

	var roller_c := DiceRoller.new()
	roller_c.seed_with(1000)
	var roll_c := roller_c.roll_attack_dice(10, 4, "different seed")
	_check(roll_a.raw_values != roll_c.raw_values, "a different seed produces different values (sanity check against a trivial always-equal bug)")

	print("-- Classification rules (large sample, threshold 4+) --")
	var roller_d := DiceRoller.new()
	roller_d.seed_with(42)
	var big_roll := roller_d.roll_attack_dice(500, 4, "classification sample")
	var rule_violation := false
	for i in range(big_roll.raw_values.size()):
		var raw: int = big_roll.raw_values[i]
		var t = big_roll.result_types[i]
		if raw == 1 and t != RollResult.ResultType.FAIL:
			rule_violation = true
		elif raw == 6 and t != RollResult.ResultType.CRITICAL_SUCCESS:
			rule_violation = true
		elif raw >= 4 and raw != 6 and t != RollResult.ResultType.NORMAL_SUCCESS:
			rule_violation = true
		elif raw < 4 and raw != 1 and t != RollResult.ResultType.FAIL:
			rule_violation = true
	_check(not rule_violation, "unmodified 1 always fails, unmodified 6 always crits, threshold applies otherwise (500-sample check)")
	_check(big_roll.total_success_count() == big_roll.normal_success_count() + big_roll.critical_success_count(), "total_success_count() == normal + critical")

	print("-- D3 --")
	var roller_e := DiceRoller.new()
	roller_e.seed_with(7)
	var d3_in_range := true
	for i in range(50):
		var v := roller_e.roll_d3("d3 range check")
		if v < 1 or v > 3:
			d3_in_range = false
	_check(d3_in_range, "roll_d3() always returns 1-3 across 50 samples")

	print("-- Roll-off --")
	var roller_f := DiceRoller.new()
	roller_f.seed_with(2024)
	var off_result := roller_f.roll_off(["alice", "bob"], "roll-off test")
	_check(off_result.has("winner") and (off_result["winner"] == "alice" or off_result["winner"] == "bob"), "roll_off() picks a winner from the contestant list")
	_check(off_result["rolls"].size() == 2, "roll_off() records a roll per contestant")

	print("-- DiceService autoload wiring --")
	DiceService.seed_with(555)
	var svc_roll := DiceService.roll_attack_dice(5, 3, "DiceService wiring check")
	_check(svc_roll.raw_values.size() == 5, "DiceService.roll_attack_dice() delegates correctly")
	_check(DiceService.get_roll_log().size() > 0, "rolls are logged for the combat log / replay")

	print("=== %s ===" % ("ALL PASS" if _failures == 0 else "%d FAILURE(S)" % _failures))
	quit(1 if _failures > 0 else 0)
