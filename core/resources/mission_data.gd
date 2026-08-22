## Static mission definition: objectives, mission rules, Tac/Crit/Kill Op
## pools. Mission GENERATION (data/missions/) reproduces the tabletop
## mission-generation procedure using this as the pool to draw from --
## see the master spec's "Mission Generation" section.
##
## PHASE: 2 (Core data structures) for the shape; 13 (Mission generation)
## for the actual generation logic.
class_name MissionData
extends Resource

@export var mission_id: String = ""
@export var display_name: String = ""
@export var primary_objectives: Array[Resource] = []      # -> ObjectiveData, schema TODO Phase 8
@export var secondary_objective_pool: Array[Resource] = [] # -> ObjectiveData, schema TODO Phase 8
@export var mission_rules: Array[RuleEffect] = []

## Predicate flag consumed by mission scoring code -- operatives with
## an Expendable-style ability (e.g. Kommando Bomb Squig) are excluded
## from kill/elimination-op and escape/survive counting. See
## death-korps-kommandos-mapping.md section 2.
##
## Not Phase 8 (Objectives and mission system) -- marker contest/control
## is core-rules mechanics and is implemented (see core/rules/objective_rules.gd).
## VP *scoring* is mission-pack content with no mission data to score
## against yet (Phase 13).
func counts_operative_for_scoring(_operative: OperativeState) -> bool:
	push_warning("MissionData.counts_operative_for_scoring() not yet implemented (Phase 13)")
	return true
