## Explainable log of AI decisions -- what it considered, what it chose,
## and why. Consumed by debug/ tooling. Kept separate from AIController
## so decision logging works the same regardless of which evaluator ran.
##
## PHASE: 9 (Basic AI).
class_name AIDecisionLog
extends RefCounted

var entries: Array[Dictionary] = []

func log_decision(operative_id: String, action: String, reasoning: String, score: float = 0.0) -> void:
	entries.append({
		"operative_id": operative_id,
		"action": action,
		"reasoning": reasoning,
		"score": score,
	})
