## Scores objective-related priorities (control markers, VP opportunities)
## for AI decision-making.
##
## PHASE: 9 (Basic AI baseline gets a trivial version); refined later.
class_name ObjectiveEvaluator
extends RefCounted

func score_objective_value(_marker_id: String, _operative: OperativeState) -> float:
	push_warning("ObjectiveEvaluator.score_objective_value() not yet implemented (Phase 9)")
	return 0.0
