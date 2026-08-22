## Scores how threatening an enemy operative is, for target-selection
## and movement-planning decisions.
##
## PHASE: 9 (Basic AI baseline gets a trivial version); refined later.
class_name ThreatEvaluator
extends RefCounted

func score_threat(_operative: OperativeState) -> float:
	push_warning("ThreatEvaluator.score_threat() not yet implemented (Phase 9)")
	return 0.0
