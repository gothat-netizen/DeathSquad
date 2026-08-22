## Runtime mission/objective state: markers, VP, Tac/Crit/Kill Op
## progress, mission-specific rule flags.
##
## VP SCORING SCOPE NOTE: the core rules define HOW markers are
## contested/controlled (that's ObjectiveRules, Phase 8) but not WHEN
## VP get scored for controlling one -- that's mission-pack content
## (Phase 13, no mission data exists yet). victory_points here is a
## plain accumulator with no automatic scoring wired to it yet.
##
## PHASE: 3 (GameState and event system) for the shell; 8 (Objectives
## and mission system) fills in marker contest/control.
class_name MissionState
extends RefCounted

var mission_data: MissionData = null
var victory_points: Dictionary = {}   # player_id -> int
var markers: Dictionary = {}          # marker_id -> MarkerState
var tac_ops_progress: Dictionary = {}

func add_marker(marker: MarkerState) -> void:
	markers[marker.marker_id] = marker

func add_victory_points(player_id: int, amount: int) -> void:
	victory_points[player_id] = victory_points.get(player_id, 0) + amount

# TODO (Phase 13): counts_for_scoring(operative) predicate hook and real
# mission-pack-driven VP scoring, once mission data exists. See
# MissionData.counts_operative_for_scoring() -- same gap, different file.
