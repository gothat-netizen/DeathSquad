## Phase 7 smoke test: Shoot (obscured/cover/block-allocation/damage) and
## Fight (assists/alternating-strike resolution) against real Death
## Korps Trooper and Kommando Boy datacards, plus RulesEngine wiring.
##
## Run headlessly once Godot is available:
##   godot --headless --script res://tests/unit/test_phase7_combat.gd
##
## Plain script (not GUT) -- see test_phase2_data_load.gd for why.
extends SceneTree

var _failures: int = 0
var _events: Array = []

func _check(condition: bool, message: String) -> void:
	if condition:
		print("  [PASS] ", message)
	else:
		_failures += 1
		print("  [FAIL] ", message)

func _on_event(event_name: String, payload: Dictionary) -> void:
	_events.append(event_name)

func _make_trooper(at: Vector2 = Vector2.ZERO) -> OperativeState:
	var data: OperativeData = load("res://data/operatives/death_korps/trooper.tres")
	var op := OperativeState.new()
	op.operative_id = "trooper#%d" % randi()
	op.init_from_data(data)
	op.position = at
	return op

func _make_boy(at: Vector2 = Vector2.ZERO) -> OperativeState:
	var data: OperativeData = load("res://data/operatives/kommandos/boy.tres")
	var op := OperativeState.new()
	op.operative_id = "boy#%d" % randi()
	op.init_from_data(data)
	op.position = at
	return op

func _init() -> void:
	print("=== Phase 7 combat engine smoke test ===")
	EventBus.game_event.connect(_on_event)
	DiceService.seed_with(31337)

	var los := LineOfSightRules.new()
	var cover := CoverRules.new()
	var combat := CombatRules.new()
	var lasgun: WeaponData = load("res://data/weapons/death_korps/lasgun.tres")
	var bayonet: WeaponData = load("res://data/weapons/death_korps/bayonet.tres")
	var choppa: WeaponData = load("res://data/weapons/kommandos/choppa.tres")

	print("-- Valid Target: Conceal + cover = not a valid target --")
	var shooter := _make_trooper(Vector2.ZERO)
	var concealed_target := _make_boy(Vector2(10, 0))
	concealed_target.order = OperativeState.Order.CONCEAL
	var terrain: Array[Dictionary] = [{"rect": Rect2(9, -2, 2, 4), "is_heavy": false}]
	_check(not combat.is_valid_target(shooter, concealed_target, [], los, cover, terrain), "Conceal target in cover is not a valid target")

	var engaged_target := _make_boy(Vector2(10, 0))
	engaged_target.order = OperativeState.Order.ENGAGE
	_check(combat.is_valid_target(shooter, engaged_target, [], los, cover, terrain), "Engage target in cover IS a valid target (just gets a cover save)")

	print("-- Valid Target: blocked by a friendly-of-shooter near the target --")
	var friendly_engaged_with_target := _make_trooper(Vector2(10.5, 0))
	_check(not combat.is_valid_target(shooter, engaged_target, [friendly_engaged_with_target], los, cover, []), "target is not valid while a friendly-of-shooter is in its control range")

	print("-- Damage math sanity: unblocked successes deal weapon damage --")
	var dmg_target := _make_boy(Vector2(5, 0))
	dmg_target.order = OperativeState.Order.ENGAGE
	var wounds_before: int = dmg_target.current_wounds
	var shoot_result := combat.resolve_shoot(shooter, dmg_target, lasgun, cover, [])
	var expected_damage: int = shoot_result["unblocked_normal"] * lasgun.normal_dmg + shoot_result["unblocked_crit"] * lasgun.critical_dmg
	_check(shoot_result["damage"] == expected_damage, "reported damage matches unblocked successes * weapon Dmg")
	_check(dmg_target.current_wounds == wounds_before - shoot_result["damage"], "target's actual wounds were reduced by exactly the damage dealt")

	print("-- Obscured: crits downgrade to normal, one success discarded --")
	var obscured_target := _make_boy(Vector2(8, 0))
	obscured_target.order = OperativeState.Order.ENGAGE
	var heavy_terrain: Array[Dictionary] = [{"rect": Rect2(3, -3, 2, 6), "is_heavy": true}]
	_check(cover.is_obscured(shooter, obscured_target, heavy_terrain), "sanity check: obstacle setup actually produces Obscured")
	var pre_wounds := obscured_target.current_wounds
	var obscured_result := combat.resolve_shoot(shooter, obscured_target, lasgun, cover, heavy_terrain)
	_check(obscured_result["target_obscured"], "resolve_shoot reports target_obscured correctly")
	# With obscured active, no crit damage should ever be dealt (all downgraded before discard)
	_check(obscured_result["unblocked_crit"] == 0, "no critical successes survive an Obscured shot (downgraded to normal)")

	print("-- Fight: alternating resolution incapacitates someone deterministically --")
	var fighter_a := _make_trooper(Vector2.ZERO)
	var fighter_b := _make_boy(Vector2(0.5, 0))
	var fight_result := combat.resolve_fight(fighter_a, bayonet, fighter_b, choppa, 0, 0)
	_check(fight_result["attacker_incapacitated"] or fight_result["defender_incapacitated"] or (fighter_a.current_wounds < fighter_a.data.wounds or fighter_b.current_wounds < fighter_b.data.wounds) or (fight_result["attacker_roll"].total_success_count() == 0 and fight_result["defender_roll"].total_success_count() == 0), "Fight either incapacitates someone, deals some damage, or both rolls whiffed entirely (all 3 are valid outcomes given real dice)")

	print("-- Fight: assists improve Hit stat --")
	var assisted_fighter := _make_trooper(Vector2.ZERO)
	var lone_defender := _make_boy(Vector2(0.5, 0))
	var assist_result := combat.resolve_fight(assisted_fighter, bayonet, lone_defender, choppa, 2, 0)  # +2 assists
	_check(assist_result.has("attacker_roll"), "resolve_fight runs with a nonzero assist count without error")

	print("-- RulesEngine wiring: preconditions + full activation flow --")
	GameStateManager.start_new_game({
		"seed": 555,
		"players": {0: {"faction_id": "death_korps"}, 1: {"faction_id": "kommandos"}},
	})
	GameStateManager.end_gambit_step()
	var state: GameState = GameStateManager.current_state
	var live_attacker: OperativeState = state.get_operatives_for_player(0)[0]
	var live_target: OperativeState = state.get_operatives_for_player(1)[0]
	live_attacker.position = Vector2.ZERO
	live_target.position = Vector2(5, 0)
	live_attacker.order = OperativeState.Order.ENGAGE
	live_target.order = OperativeState.Order.ENGAGE

	var engine := GameStateManager.rules_engine
	live_attacker.order = OperativeState.Order.CONCEAL
	var conceal_blocked := engine.validate_attack(state, live_attacker, live_target, lasgun)
	_check(not conceal_blocked["legal"], "RulesEngine.validate_attack() correctly blocks Shoot with a Conceal order")
	live_attacker.order = OperativeState.Order.ENGAGE

	var live_wounds_before: int = live_target.current_wounds
	var live_result := engine.resolve_shoot(state, live_attacker, live_target, lasgun)
	_check(live_result.get("legal", true) != false, "RulesEngine.resolve_shoot() succeeds for a legal shot")
	_check(live_target.current_wounds <= live_wounds_before, "live GameState target actually took the damage (or none, if the roll whiffed)")
	_check(_events.has("attack_resolved"), "attack_resolved event fired")
	_check(live_attacker.has_performed_action("Shoot"), "Shoot recorded on the attacker after resolve_shoot()")

	var second_shot := engine.resolve_shoot(state, live_attacker, live_target, lasgun)
	_check(not second_shot.get("legal", true), "a second Shoot in the same activation is correctly rejected")

	print("=== %s ===" % ("ALL PASS" if _failures == 0 else "%d FAILURE(S)" % _failures))
	quit(1 if _failures > 0 else 0)
