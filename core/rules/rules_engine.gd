## Facade over the specialized rules modules (movement, combat, LoS,
## cover, effects). This is the ONLY entry point gameplay-adjacent code
## (AI, UI, presentation) should call to validate or execute a rule.
##
## No consumer of this class should ever re-derive rules logic locally --
## if the UI needs to know if a move is legal, it calls validate_move()
## here, the same function move execution uses.
##
## PHASE: 5 (Rules engine foundation) stands this up; 6/7/8 fill in
## movement, combat, and mission-rule bodies respectively.
class_name RulesEngine
extends RefCounted

var movement_rules: MovementRules
var combat_rules: CombatRules
var line_of_sight_rules: LineOfSightRules
var cover_rules: CoverRules
var objective_rules: ObjectiveRules
var effect_resolver: EffectResolver
var precedence_resolver: PrecedenceResolver

func _init() -> void:
	movement_rules = MovementRules.new()
	combat_rules = CombatRules.new()
	line_of_sight_rules = LineOfSightRules.new()
	cover_rules = CoverRules.new()
	objective_rules = ObjectiveRules.new()
	effect_resolver = EffectResolver.new()
	precedence_resolver = PrecedenceResolver.new()

# ---- Movement ----
## `state` is needed to gather enemies/friendlies for control-range
## checks -- this wasn't in the Phase 1 stub signature, added here since
## movement rules genuinely can't be validated against just the mover.
func validate_move(state: GameState, operative: OperativeState, path: PackedVector2Array, move_type: MovementRules.MoveType, blocking_obstacles: Array[Rect2] = []) -> Dictionary:
	var enemies := _enemies_of(state, operative)
	var friendlies := _friendlies_of(state, operative)
	return movement_rules.validate_move(operative, path, move_type, enemies, friendlies, line_of_sight_rules, blocking_obstacles)

func execute_move(state: GameState, operative: OperativeState, path: PackedVector2Array, move_type: MovementRules.MoveType, blocking_obstacles: Array[Rect2] = []) -> Dictionary:
	var enemies := _enemies_of(state, operative)
	var friendlies := _friendlies_of(state, operative)
	var result := movement_rules.execute_move(operative, path, move_type, enemies, friendlies, line_of_sight_rules, blocking_obstacles)
	if result["legal"]:
		EventBus.emit_event(GameEvents.OPERATIVE_MOVED, {
			"operative_id": operative.operative_id,
			"move_type": movement_rules.get_action_name(move_type),
			"distance": result["distance"],
			"destination": result["destination"],
		})
	return result

func _enemies_of(state: GameState, operative: OperativeState) -> Array[OperativeState]:
	var result: Array[OperativeState] = []
	for op in state.operatives.values():
		if op.owning_player != operative.owning_player and not op.is_incapacitated():
			result.append(op)
	return result

func _friendlies_of(state: GameState, operative: OperativeState) -> Array[OperativeState]:
	var result: Array[OperativeState] = []
	for op in state.operatives.values():
		if op.owning_player == operative.owning_player and op != operative and not op.is_incapacitated():
			result.append(op)
	return result

# ---- Combat ----
## Weapon param is accepted for API symmetry with callers that naturally
## think "valid targets for this weapon" -- not yet used internally,
## since base Valid Target doesn't depend on weapon stats (Range x
## would, but that's a RuleEffect, Phase 12 content).
func get_valid_targets(state: GameState, operative: OperativeState, _weapon: WeaponData) -> Array[OperativeState]:
	var enemies := _enemies_of(state, operative)
	var friendlies := _friendlies_of(state, operative)
	return combat_rules.get_valid_targets(operative, enemies, friendlies, line_of_sight_rules, cover_rules)

func validate_attack(state: GameState, attacker: OperativeState, target: OperativeState, weapon: WeaponData) -> Dictionary:
	if attacker.order == OperativeState.Order.CONCEAL:
		return {"legal": false, "reason": "Shoot cannot be performed with a Conceal order"}
	for enemy in _enemies_of(state, attacker):
		if line_of_sight_rules.is_within_control_range(attacker, enemy):
			return {"legal": false, "reason": "Shoot cannot be performed while within control range of an enemy operative"}
	if attacker.has_performed_action("Shoot"):
		return {"legal": false, "reason": "Shoot already performed this activation"}
	var valid_targets := get_valid_targets(state, attacker, weapon)
	if not valid_targets.has(target):
		return {"legal": false, "reason": "not a valid target"}
	return {"legal": true, "reason": ""}

func resolve_shoot(state: GameState, attacker: OperativeState, target: OperativeState, weapon: WeaponData) -> Dictionary:
	var validation := validate_attack(state, attacker, target, weapon)
	if not validation["legal"]:
		return validation
	var result := combat_rules.resolve_shoot(attacker, target, weapon, cover_rules)
	attacker.record_action_performed("Shoot")
	EventBus.emit_event(GameEvents.ATTACK_RESOLVED, {
		"attacker_id": attacker.operative_id, "target_id": target.operative_id,
		"weapon": weapon.display_name, "damage": result["damage"],
	})
	if result["damage"] > 0:
		EventBus.emit_event(GameEvents.DAMAGE_APPLIED, {"operative_id": target.operative_id, "damage": result["damage"]})
	if result["target_incapacitated"]:
		EventBus.emit_event(GameEvents.OPERATIVE_INCAPACITATED, {"operative_id": target.operative_id})
	return result

func resolve_fight(state: GameState, attacker: OperativeState, defender: OperativeState, attacker_weapon: WeaponData, defender_weapon: WeaponData) -> Dictionary:
	if not line_of_sight_rules.is_within_control_range(attacker, defender):
		return {"legal": false, "reason": "Fight requires an enemy operative within control range"}
	if attacker.has_performed_action("Fight"):
		return {"legal": false, "reason": "Fight already performed this activation"}

	var attacker_assists := _count_assists(state, attacker, defender)
	var defender_assists := _count_assists(state, defender, attacker)
	var result := combat_rules.resolve_fight(attacker, attacker_weapon, defender, defender_weapon, attacker_assists, defender_assists)
	attacker.record_action_performed("Fight")

	EventBus.emit_event(GameEvents.ATTACK_RESOLVED, {
		"attacker_id": attacker.operative_id, "target_id": defender.operative_id, "weapon": attacker_weapon.display_name,
	})
	if result["defender_incapacitated"]:
		EventBus.emit_event(GameEvents.OPERATIVE_INCAPACITATED, {"operative_id": defender.operative_id})
	if result["attacker_incapacitated"]:
		EventBus.emit_event(GameEvents.OPERATIVE_INCAPACITATED, {"operative_id": attacker.operative_id})
	result["legal"] = true
	return result

## A friendly assists `defender_of` in a fight against `fighting`'s side
## if it's within control range of `fighting` and NOT within control
## range of any other enemy.
func _count_assists(state: GameState, side_being_assisted: OperativeState, opponent: OperativeState) -> int:
	var count := 0
	for friendly in _friendlies_of(state, side_being_assisted):
		if friendly == side_being_assisted:
			continue
		if not line_of_sight_rules.is_within_control_range(friendly, opponent):
			continue
		var engaged_elsewhere := false
		for other_enemy in _enemies_of(state, friendly):
			if other_enemy != opponent and line_of_sight_rules.is_within_control_range(friendly, other_enemy):
				engaged_elsewhere = true
				break
		if not engaged_elsewhere:
			count += 1
	return count

# ---- Objectives / markers ----
func _all_operatives(state: GameState) -> Array[OperativeState]:
	var result: Array[OperativeState] = []
	for op in state.operatives.values():
		result.append(op)
	return result

func get_marker_controller(state: GameState, marker_id: String) -> int:
	var marker: MarkerState = state.mission_state.markers.get(marker_id)
	if marker == null:
		return -1
	return objective_rules.compute_control(marker, _all_operatives(state), line_of_sight_rules)

func validate_pick_up_marker(state: GameState, operative: OperativeState, marker_id: String) -> Dictionary:
	var marker: MarkerState = state.mission_state.markers.get(marker_id)
	if marker == null:
		return {"legal": false, "reason": "no such marker"}
	return objective_rules.validate_pick_up_marker(operative, marker, _enemies_of(state, operative), _all_operatives(state), line_of_sight_rules)

func execute_pick_up_marker(state: GameState, operative: OperativeState, marker_id: String) -> Dictionary:
	var marker: MarkerState = state.mission_state.markers.get(marker_id)
	if marker == null:
		return {"legal": false, "reason": "no such marker"}
	var result := objective_rules.execute_pick_up_marker(operative, marker, _enemies_of(state, operative), _all_operatives(state), line_of_sight_rules)
	if result["legal"]:
		_refresh_marker_control(state, marker)
	return result

func execute_place_marker(state: GameState, operative: OperativeState, marker_id: String) -> Dictionary:
	var marker: MarkerState = state.mission_state.markers.get(marker_id)
	if marker == null:
		return {"legal": false, "reason": "no such marker"}
	var result := objective_rules.execute_place_marker(operative, marker)
	if result["legal"]:
		_refresh_marker_control(state, marker)
	return result

## Recomputes one marker's control and emits OBJECTIVE_CONTROLLED only on
## an actual change. Called after marker-affecting actions; also called
## by GameStateManager at the end of every activation (positions/wounds
## can change control even without a marker action).
func refresh_all_marker_control(state: GameState) -> void:
	for marker in state.mission_state.markers.values():
		_refresh_marker_control(state, marker)

func _refresh_marker_control(state: GameState, marker: MarkerState) -> void:
	var new_controller := objective_rules.compute_control(marker, _all_operatives(state), line_of_sight_rules)
	if new_controller != marker.controlling_player:
		marker.controlling_player = new_controller
		EventBus.emit_event(GameEvents.OBJECTIVE_CONTROLLED, {"marker_id": marker.marker_id, "controlling_player": new_controller})
