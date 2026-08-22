## Combat resolution: Shoot and Fight.
##
## Confirmed against the actual core rules text -- two genuinely
## distinct pipelines, kept as separate functions rather than one
## generic "resolve_attack":
##
## Shoot: attacker rolls, defender collects 3 defence dice (1 free
## retained if in cover) and rolls the rest, defender allocates blocks,
## THEN unblocked successes deal damage. Obscured downgrades all crits
## to normal AND makes the attacker discard one success of their choice.
##
## Fight: both sides roll simultaneously (Hit improved by 1 per
## assisting friendly), then ALTERNATE resolving one success at a time
## (attacker first), each one either a strike (damage now) or a block
## (cancel one of the opponent's unresolved successes) -- no separate
## defence roll at all.
##
## PLACEHOLDER POLICIES (documented, not real tactical AI -- same
## category of gap as Initiative/Precedence, Phase 9/11 territory):
## - Shoot's Obscured "discard one success of your choice": discards a
##   normal success if one exists (keeps crits when possible).
## - Shoot's defence-dice block allocation: greedy (crits block crits
##   first, then normals block normals, then leftover pairs of normal
##   successes block crits).
## - Fight's strike-or-block choice: ALWAYS STRIKE, never block.
##
## PHASE: 7 (Combat engine).
class_name CombatRules
extends RefCounted

func is_valid_target(
	shooter: OperativeState,
	target: OperativeState,
	shooter_friendlies: Array[OperativeState],
	los: LineOfSightRules,
	cover: CoverRules,
	terrain_obstacles: Array[Dictionary] = [],
	vis_obstacles: Array[Rect2] = []
) -> bool:
	if not los.is_operative_visible(shooter, target, vis_obstacles):
		return false
	if target.order == OperativeState.Order.CONCEAL and cover.is_in_cover(shooter, target, terrain_obstacles):
		return false  # Conceal + cover = not a valid target at all
	# "...and has no friendly operatives within its control range" --
	# "friendly" here means friendly to the SHOOTER (can't shoot into a
	# target your own operative is engaged with).
	for friendly in shooter_friendlies:
		if friendly != shooter and los.is_within_control_range(friendly, target, vis_obstacles):
			return false
	return true

func get_valid_targets(
	shooter: OperativeState,
	enemies: Array[OperativeState],
	shooter_friendlies: Array[OperativeState],
	los: LineOfSightRules,
	cover: CoverRules,
	terrain_obstacles: Array[Dictionary] = [],
	vis_obstacles: Array[Rect2] = []
) -> Array[OperativeState]:
	var valid: Array[OperativeState] = []
	for enemy in enemies:
		if is_valid_target(shooter, enemy, shooter_friendlies, los, cover, terrain_obstacles, vis_obstacles):
			valid.append(enemy)
	return valid

## Returns a detailed result dict: attack_roll, target_obscured,
## target_in_cover, unblocked_normal, unblocked_crit, damage,
## target_incapacitated. Mutates `target`'s wounds directly.
func resolve_shoot(
	attacker: OperativeState,
	target: OperativeState,
	weapon: WeaponData,
	cover: CoverRules,
	terrain_obstacles: Array[Dictionary] = []
) -> Dictionary:
	var hit_threshold := weapon.hit_threshold
	if attacker.is_injured():
		hit_threshold += 1  # worsen by 1

	# Step 3: Roll Attack Dice
	var attack_roll := DiceService.roll_attack_dice(
		weapon.atk, hit_threshold, "Shoot: %s fires %s at %s" % [attacker.operative_id, weapon.display_name, target.operative_id]
	)
	var normal_successes := attack_roll.normal_success_count()
	var crit_successes := attack_roll.critical_success_count()

	var target_obscured := cover.is_obscured(attacker, target, terrain_obstacles)
	var target_in_cover := cover.is_in_cover(attacker, target, terrain_obstacles)

	if target_obscured:
		normal_successes += crit_successes  # all crits retained as normal, precedence-locked
		crit_successes = 0
		if normal_successes > 0:
			normal_successes -= 1  # attacker discards one success of their choice (placeholder: a normal)
		elif crit_successes > 0:
			crit_successes -= 1

	# Step 4: Roll Defence Dice -- always 3 total; 1 free retained (not
	# rolled) if in cover.
	var defence_normal := 0
	var defence_crit := 0
	var dice_to_roll := 3
	if target_in_cover:
		defence_normal += 1
		dice_to_roll = 2
	if dice_to_roll > 0 and target.data != null:
		var defence_roll := DiceService.roll_defence_dice(
			dice_to_roll, target.data.save_threshold, "Shoot: %s defends against %s" % [target.operative_id, attacker.operative_id]
		)
		defence_normal += defence_roll.normal_success_count()
		defence_crit += defence_roll.critical_success_count()

	# Step 5: Resolve Defence Dice -- greedy block allocation.
	var unblocked_crit := crit_successes
	var crit_vs_crit := min(defence_crit, unblocked_crit)
	unblocked_crit -= crit_vs_crit
	defence_crit -= crit_vs_crit

	var unblocked_normal := normal_successes
	var crit_vs_normal := min(defence_crit, unblocked_normal)
	unblocked_normal -= crit_vs_normal

	var normal_vs_normal := min(defence_normal, unblocked_normal)
	unblocked_normal -= normal_vs_normal
	defence_normal -= normal_vs_normal

	var pairs_vs_crit := int(defence_normal / 2)
	var applied_pairs := min(pairs_vs_crit, unblocked_crit)
	unblocked_crit -= applied_pairs

	# Step 6: Resolve Attack Dice -- apply damage.
	var damage := unblocked_normal * weapon.normal_dmg + unblocked_crit * weapon.critical_dmg
	target.apply_damage(damage)

	return {
		"attack_roll": attack_roll,
		"target_obscured": target_obscured,
		"target_in_cover": target_in_cover,
		"unblocked_normal": unblocked_normal,
		"unblocked_crit": unblocked_crit,
		"damage": damage,
		"target_incapacitated": target.is_incapacitated(),
	}

func _successes_queue(roll: RollResult) -> Array:
	var queue := []
	for t in roll.result_types:
		if t == RollResult.ResultType.CRITICAL_SUCCESS:
			queue.append("crit")
		elif t == RollResult.ResultType.NORMAL_SUCCESS:
			queue.append("normal")
	return queue

## Returns {attacker_roll, defender_roll, attacker_incapacitated,
## defender_incapacitated}. Mutates both operatives' wounds directly.
## Assist counts are computed by the caller (RulesEngine), which knows
## the full friendly/enemy layout.
func resolve_fight(
	attacker: OperativeState,
	attacker_weapon: WeaponData,
	defender: OperativeState,
	defender_weapon: WeaponData,
	attacker_assists: int = 0,
	defender_assists: int = 0
) -> Dictionary:
	var attacker_hit: int = max(2, attacker_weapon.hit_threshold - attacker_assists)
	if attacker.is_injured():
		attacker_hit += 1
	var defender_hit: int = max(2, defender_weapon.hit_threshold - defender_assists)
	if defender.is_injured():
		defender_hit += 1

	var attacker_roll := DiceService.roll_attack_dice(attacker_weapon.atk, attacker_hit, "Fight: %s attacks %s" % [attacker.operative_id, defender.operative_id])
	var defender_roll := DiceService.roll_attack_dice(defender_weapon.atk, defender_hit, "Fight: %s retaliates against %s" % [defender.operative_id, attacker.operative_id])

	var attacker_queue := _successes_queue(attacker_roll)
	var defender_queue := _successes_queue(defender_roll)

	var attacker_turn := true
	while not attacker_queue.is_empty() or not defender_queue.is_empty():
		if attacker_turn:
			if not attacker_queue.is_empty():
				var s: String = attacker_queue.pop_front()
				defender.apply_damage(attacker_weapon.critical_dmg if s == "crit" else attacker_weapon.normal_dmg)
				if defender.is_incapacitated():
					break
		else:
			if not defender_queue.is_empty():
				var s: String = defender_queue.pop_front()
				attacker.apply_damage(defender_weapon.critical_dmg if s == "crit" else defender_weapon.normal_dmg)
				if attacker.is_incapacitated():
					break
		attacker_turn = not attacker_turn

	return {
		"attacker_roll": attacker_roll,
		"defender_roll": defender_roll,
		"attacker_incapacitated": attacker.is_incapacitated(),
		"defender_incapacitated": defender.is_incapacitated(),
	}
