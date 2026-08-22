## Autoload owning the single authoritative GameState for the current
## session. UI/presentation/AI read through this; only RulesEngine
## (via this manager) mutates it.
##
## Scope note: this phase wires up the STATE MACHINE and EVENT PLUMBING
## for the turn structure (Strategy phase Initiative/Ready/Gambit steps,
## Firefight phase activation bookkeeping). It deliberately does NOT
## implement Perform Actions (that needs movement_rules/combat_rules,
## Phase 6/7), real Initiative roll-offs (needs DiceService, Phase 4),
## or Gambit ploy effects (needs EffectResolver + faction content,
## Phase 5/12). Those seams are marked below.
##
## PHASE: 3 (GameState and event system).
extends Node

var current_state: GameState = null
var rules_engine: RulesEngine = null

var _last_activating_player: int = -1

func _ready() -> void:
	rules_engine = RulesEngine.new()

## config = {
##   "seed": int (optional, random if omitted),
##   "players": { player_id: int -> {"faction_id": String} }
## }
## Spawns every operative in each selected faction's current roster.
## Roster SELECTION (choosing which subset of a faction to field, under
## points/operative-count limits) is a Phase 11 (game setup UI) concern --
## this phase just proves a full faction roster can be spawned into a
## live GameState.
##
## KNOWN GAP: every operative spawns at Vector2.ZERO -- there's no
## deployment-zone system yet (MapData has the schema, but no map
## instance or deployment logic exists until Phase 10/13), so both
## rosters currently stack on top of each other at the origin. Harmless
## until something checks control range/distance at game start (Phase 6
## movement rules validation is a case that legitimately cares) -- code
## that needs realistic starting positions should reposition operatives
## manually until deployment lands.
func start_new_game(config: Dictionary) -> void:
	current_state = GameState.new()
	current_state.random_seed = config.get("seed", randi())
	DiceService.seed_with(current_state.random_seed)

	var players: Dictionary = config.get("players", {})
	for player_id in players.keys():
		var player_config: Dictionary = players[player_id]
		var faction: FactionData = ContentDatabase.get_faction(player_config.get("faction_id", ""))
		current_state.player_states[player_id] = {"faction_id": player_config.get("faction_id", "")}
		if faction == null:
			push_warning("GameStateManager.start_new_game: unknown faction '%s' for player %s" % [player_config.get("faction_id", ""), player_id])
			continue
		for operative_data in faction.roster:
			current_state.spawn_operative(operative_data, player_id)

	EventBus.emit_event(GameEvents.GAME_STARTED, {"seed": current_state.random_seed, "players": players.keys()})
	start_new_turning_point()

func start_new_turning_point() -> void:
	var turn := current_state.turn_state
	turn.turning_point_number += 1
	turn.phase = TurnState.Phase.STRATEGY
	turn.strategy_step = TurnState.StrategyStep.INITIATIVE
	_last_activating_player = -1

	EventBus.emit_event(GameEvents.TURNING_POINT_STARTED, {"turning_point": turn.turning_point_number})

	_resolve_initiative()
	_do_ready_step()
	# Gambit step is left open (turn.strategy_step == GAMBIT) for the
	# caller to drive via offer_gambit()/pass_gambit() below -- it
	# involves player/AI decisions this layer doesn't make.

func _resolve_initiative() -> void:
	var turn := current_state.turn_state
	var player_ids: Array = current_state.player_states.keys()
	if player_ids.size() < 2:
		turn.initiative_player = player_ids[0] if not player_ids.is_empty() else 0
		return

	var decider: int
	if turn.turning_point_number <= 1:
		# Real rule: turning point 1's initiative is set by the mission
		# pack's sequence -- no mission/mission-pack data exists yet
		# (Phase 13). Placeholder: player 0 decides.
		decider = player_ids[0]
		push_warning("GameStateManager._resolve_initiative: turning point 1 initiative uses a placeholder decider (player 0) -- the real rule depends on mission pack data not implemented yet (Phase 13)")
	else:
		var rolls: Dictionary = {}
		for pid in player_ids:
			rolls[pid] = DiceService.roll_single_d6("Initiative roll: player %s" % pid)
		var highest: int = -1
		for pid in rolls:
			highest = max(highest, rolls[pid])
		var top: Array = player_ids.filter(func(p): return rolls[p] == highest)

		if top.size() == 1:
			decider = top[0]  # roll-off winner decides who gets initiative
		else:
			# Real rule: on a tie, the player who did NOT have initiative
			# last turning point decides -- this OVERRIDES the generic
			# Roll-off's reroll-on-tie behavior (Initiative's own tie-break
			# is more specific, per the Precedence rules).
			decider = turn.previous_non_initiative_player if turn.previous_non_initiative_player != -1 else top[0]

	# The decider CHOOSES who gets initiative (self or opponent) -- that's
	# a real player/AI decision with no prompt system yet (Phase 9/11), so
	# as a placeholder policy the decider simply takes it for themselves.
	# This is the same seam as PrecedenceResolver's levels 5-6.
	turn.initiative_player = decider
	push_warning("GameStateManager._resolve_initiative: 'decider takes initiative themselves' is a placeholder policy standing in for a real decision prompt (Phase 9/11)")

	turn.previous_non_initiative_player = player_ids.filter(func(p): return p != turn.initiative_player)[0] if player_ids.size() == 2 else -1

func _do_ready_step() -> void:
	var turn := current_state.turn_state
	turn.strategy_step = TurnState.StrategyStep.READY

	for player_id in current_state.player_states.keys():
		var gain: int = 1
		if player_id != turn.initiative_player and turn.turning_point_number > 1:
			gain = 2  # non-initiative player's catch-up CP after turn 1
		turn.command_points[player_id] = turn.command_points.get(player_id, 0) + gain

	for op in current_state.operatives.values():
		op.ready_for_new_turning_point()

	turn.strategy_step = TurnState.StrategyStep.GAMBIT

## Call once both players have passed on Strategic Gambits (ploy
## resolution itself is Phase 12 content) to move into the Firefight phase.
func end_gambit_step() -> void:
	var turn := current_state.turn_state
	turn.phase = TurnState.Phase.FIREFIGHT
	turn.firefight_step = TurnState.FirefightStep.DETERMINE_ORDER
	turn.counteract_eligible_player = -1

# ---- Firefight phase / activation bookkeeping ----

func has_ready_operatives(player_id: int) -> bool:
	return not current_state.get_ready_operatives_for_player(player_id).is_empty()

## Whose turn it is to choose an operative to activate. Honors forced
## activations (Group Activation, Directive) ahead of normal alternation.
## Returns -1 if neither player has a ready operative (turning point over).
func next_activating_player() -> int:
	var turn := current_state.turn_state
	if turn.has_forced_activation():
		var forced_op: OperativeState = current_state.operatives.get(turn.activation_queue[0])
		if forced_op != null and forced_op.is_ready:
			return forced_op.owning_player
		turn.pop_next_forced_activation()  # stale entry (already expended/removed) -- drop and re-evaluate

	if _last_activating_player == -1:
		return turn.initiative_player if has_ready_operatives(turn.initiative_player) else _other_ready_player(turn.initiative_player)

	var other := _other_player(_last_activating_player)
	if has_ready_operatives(other):
		return other
	if has_ready_operatives(_last_activating_player):
		return _last_activating_player
	return -1

func _other_player(player_id: int) -> int:
	for p in current_state.player_states.keys():
		if p != player_id:
			return p
	return player_id

func _other_ready_player(player_id: int) -> int:
	var other := _other_player(player_id)
	return other if has_ready_operatives(other) else player_id

## Activates a specific ready operative. Perform Actions (the operative
## actually doing anything) is Phase 6/7 -- this only handles the
## Determine Order / Expended bookkeeping and event emission.
func activate_operative(operative_id: String) -> void:
	var op: OperativeState = current_state.operatives.get(operative_id)
	if op == null or not op.is_ready:
		push_warning("GameStateManager.activate_operative: '%s' is not a ready operative" % operative_id)
		return

	if current_state.turn_state.has_forced_activation() and current_state.turn_state.activation_queue[0] == operative_id:
		current_state.turn_state.pop_next_forced_activation()

	EventBus.emit_event(GameEvents.ACTIVATION_STARTED, {"operative_id": operative_id, "player": op.owning_player})
	current_state.turn_state.firefight_step = TurnState.FirefightStep.PERFORM_ACTIONS
	op.reset_activation_actions()
	# Movement (Phase 6) and Shoot/Fight combat (Phase 7) are all available
	# now via rules_engine. Nothing here yet decides WHICH actions a ready
	# operative performs -- that's a UI/AI decision source (Phase 9/11),
	# same category of gap as the Initiative and precedence decision prompts.

	op.is_ready = false
	_last_activating_player = op.owning_player
	# Stun-style effects ("until end of its next activation") clear here --
	# they were live for this whole activation, then go away.
	op.expire_status_effects(TimedStatusEffect.ExpiryTrigger.END_OF_NEXT_ACTIVATION)
	current_state.turn_state.firefight_step = TurnState.FirefightStep.EXPENDED
	EventBus.emit_event(GameEvents.ACTIVATION_ENDED, {"operative_id": operative_id, "player": op.owning_player})

	_update_counteract_eligibility()
	_check_firefight_phase_end()
	rules_engine.refresh_all_marker_control(current_state)

func _update_counteract_eligibility() -> void:
	var turn := current_state.turn_state
	for player_id in current_state.player_states.keys():
		if not has_ready_operatives(player_id) and has_ready_operatives(_other_player(player_id)):
			turn.counteract_eligible_player = player_id
			return
	turn.counteract_eligible_player = -1

func _check_firefight_phase_end() -> void:
	var turn := current_state.turn_state
	var any_ready := false
	for player_id in current_state.player_states.keys():
		if has_ready_operatives(player_id):
			any_ready = true
			break
	if not any_ready:
		EventBus.emit_event(GameEvents.TURNING_POINT_ENDED, {"turning_point": turn.turning_point_number})
		# Caller (game setup/mission loop, Phase 8+) decides whether to
		# call start_new_turning_point() again or end the game.
