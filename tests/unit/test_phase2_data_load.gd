## Phase 2 smoke test: loads the Death Korps / Kommandos proof-of-concept
## content directly from res://data/ (bypassing the ContentDatabase
## autoload, so this also works run standalone) and asserts the schema
## round-trips correctly -- weapons resolve, keywords are set, order
## restrictions default correctly, faction roster lookup works.
##
## Run headlessly once Godot is available:
##   godot --headless --script res://tests/unit/test_phase2_data_load.gd
##
## This is a plain script, not a GUT test case -- GUT (or an equivalent
## headless runner) is planned for Phase 15. Nothing stops individual
## checks like this existing earlier, per the master spec's "whenever a
## new rule is implemented, create a test for it."
extends SceneTree

var _failures: int = 0

func _check(condition: bool, message: String) -> void:
	if condition:
		print("  [PASS] ", message)
	else:
		_failures += 1
		print("  [FAIL] ", message)

func _init() -> void:
	print("=== Phase 2 data-structure smoke test ===")

	print("-- Death Korps Trooper --")
	var trooper: OperativeData = load("res://data/operatives/death_korps/trooper.tres")
	_check(trooper != null, "trooper.tres loads")
	if trooper:
		_check(trooper.operative_id == "death_korps_trooper", "operative_id correct")
		_check(trooper.apl == 2 and trooper.move_inches == 6.0 and trooper.save_threshold == 5 and trooper.wounds == 7, "base stats correct (APL2/Move6/Save5+/Wounds7)")
		_check(trooper.has_keyword("TROOPER") and trooper.has_keyword("DEATH KORPS"), "keywords include TROOPER and DEATH KORPS")
		_check(trooper.weapons.size() == 2, "has 2 weapons (lasgun, bayonet)")
		_check(trooper.get_weapons_by_base_name("lasgun").size() == 1, "lasgun lookup by base_name works")
		_check(trooper.allows_order("Engage") and trooper.allows_order("Conceal"), "no order restrictions (unlike Grot/Bomb Squig)")
		_check(trooper.abilities.size() == 1 and trooper.abilities[0].ability_id == "death_korps_trooper_group_activation", "Group Activation ability attached")

	print("-- Kommando Boy --")
	var boy: OperativeData = load("res://data/operatives/kommandos/boy.tres")
	_check(boy != null, "boy.tres loads")
	if boy:
		_check(boy.wounds == 10 and boy.save_threshold == 5, "base stats correct (Wounds10/Save5+)")
		var choppa_matches = boy.get_weapons_by_base_name("choppa")
		_check(choppa_matches.size() == 1 and choppa_matches[0].hit_threshold == 3, "choppa resolves with Hit 3+")

	print("-- Faction roster lookup --")
	var death_korps: FactionData = load("res://data/factions/death_korps/death_korps.tres")
	_check(death_korps != null and death_korps.get_operative_by_id("death_korps_trooper") != null, "Death Korps faction roster resolves Trooper by id")
	var kommandos: FactionData = load("res://data/factions/kommandos/kommandos.tres")
	_check(kommandos != null and kommandos.get_operative_by_id("kommando_boy") != null, "Kommandos faction roster resolves Boy by id")

	print("=== %s ===" % ("ALL PASS" if _failures == 0 else "%d FAILURE(S)" % _failures))
	quit(1 if _failures > 0 else 0)
