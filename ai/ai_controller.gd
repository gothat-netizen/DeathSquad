## Drives AI-controlled players. Calls RulesEngine exactly the same way
## a human player's UI input would -- the AI must never have a shortcut
## path that skips validation "for performance" or receives hidden
## information not defined by the difficulty level.
##
## PHASE: 9 (Basic AI) for a simple rules-compliant AI; evaluators/ fills
## in objective prioritization, threat assessment, etc. afterward.
class_name AIController
extends RefCounted

var rules_engine: RulesEngine
var decision_log: AIDecisionLog

func _init(engine: RulesEngine) -> void:
	rules_engine = engine
	decision_log = AIDecisionLog.new()

func choose_action(operative: OperativeState) -> Dictionary:
	push_warning("AIController.choose_action() not yet implemented (Phase 9)")
	return {}
