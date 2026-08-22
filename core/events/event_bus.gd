## Global pub/sub hub. RulesEngine and GameStateManager emit here;
## presentation/, ui/, ai/, and save/ subscribe. No consumer of an event
## can affect a resolution that has already happened -- results are
## final by the time they're emitted.
##
## This script is attached as the EventBus autoload (see autoload/EventBus.gd,
## which is a thin wrapper -- kept separate so core/ doesn't hard-depend on
## Godot's autoload/singleton mechanism for its own internal tests).
##
## PHASE: 3 (GameState and event system).
class_name EventBusImpl
extends Node

signal game_event(event_name: String, payload: Dictionary)

func emit_event(event_name: String, payload: Dictionary = {}) -> void:
	game_event.emit(event_name, payload)
