## Tracks where we are in the Strategy/Firefight phase loop, and owns
## the activation queue for the Firefight phase.
##
## IMPORTANT: the activation queue is NOT a simple alternating turn
## order. Rules like Death Korps Trooper's Group Activation and
## Confidant's Directive force a specific operative to activate next,
## out of the normal alternation. Model this as an explicit queue that
## defaults to "next ready operative, alternating players" but can be
## overridden by a rule effect pushing a forced-next-activation entry.
##
## PHASE: 3 (GameState and event system).
class_name TurnState
extends RefCounted

enum Phase { STRATEGY, FIREFIGHT }
enum StrategyStep { INITIATIVE, READY, GAMBIT }
enum FirefightStep { DETERMINE_ORDER, PERFORM_ACTIONS, EXPENDED }

var turning_point_number: int = 0
var phase: Phase = Phase.STRATEGY
var strategy_step: StrategyStep = StrategyStep.INITIATIVE
var firefight_step: FirefightStep = FirefightStep.DETERMINE_ORDER
var initiative_player: int = -1
## Tracks who did NOT have initiative last turning point -- the core
## rules' Initiative tie-break lets that player decide who gets it this
## time. -1 before turning point 2 (no prior turning point to reference).
var previous_non_initiative_player: int = -1
var command_points: Dictionary = {}          # player_id -> int
## Only holds FORCED next-activations (Group Activation, Directive, etc.).
## Normal alternation (whichever ready operative the active player selects)
## is NOT modeled as a queue -- see GameStateManager.next_activating_player().
var activation_queue: Array[String] = []     # operative_ids; front = next forced activation
var counteract_eligible_player: int = -1     # set once a side is fully expended while the other still has ready ops

func push_forced_activation(operative_id: String) -> void:
	activation_queue.push_front(operative_id)

func pop_next_forced_activation() -> String:
	if activation_queue.is_empty():
		return ""
	return activation_queue.pop_front()

func has_forced_activation() -> bool:
	return not activation_queue.is_empty()
