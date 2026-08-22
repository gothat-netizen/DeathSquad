## Names/payload shapes for events emitted on EventBus. Kept as a plain
## data/constants file (not a Node) so both core/ and presentation/ can
## reference event names without depending on the autoload singleton.
##
## PHASE: 3 (GameState and event system).
class_name GameEvents
extends RefCounted

# Event name constants -- see master spec's Event System list.
const GAME_STARTED := "game_started"
const TURNING_POINT_STARTED := "turning_point_started"
const SCOUTING_STARTED := "scouting_started"
const ACTIVATION_STARTED := "activation_started"
const ACTIVATION_ENDED := "activation_ended"
const OPERATIVE_MOVED := "operative_moved"
const ACTION_DECLARED := "action_declared"
const ATTACK_DECLARED := "attack_declared"
const DICE_ROLLED := "dice_rolled"
const ATTACK_RESOLVED := "attack_resolved"
const DAMAGE_APPLIED := "damage_applied"
const OPERATIVE_INCAPACITATED := "operative_incapacitated"
const OBJECTIVE_CONTROLLED := "objective_controlled"
const OBJECTIVE_CHANGED := "objective_changed"
const TAC_OP_TRIGGERED := "tac_op_triggered"
const VICTORY_POINT_SCORED := "victory_point_scored"
const TURNING_POINT_ENDED := "turning_point_ended"
const GAME_ENDED := "game_ended"
