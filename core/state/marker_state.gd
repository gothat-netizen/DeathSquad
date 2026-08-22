## Runtime state for a single marker (objective marker or other mission
## marker) on the battlefield. What a marker DOES when controlled/carried
## (victory points, mission effects) is mission-pack content (Phase 13);
## this is just the marker's own position/carry/control state.
##
## PHASE: 8 (Objectives and mission system).
class_name MarkerState
extends RefCounted

var marker_id: String = ""
## Free-form tag ("objective", or a mission-specific marker type).
## Objective markers are 40mm diameter, all others 20mm -- purely a
## presentation/rules-text detail, not modeled as a numeric radius here.
var marker_type: String = "objective"
var position: Vector2 = Vector2.ZERO
## "" = not being carried. While carried, the carrying operative is the
## ONLY operative that contests or controls this marker (core rules).
var carried_by_operative_id: String = ""
## Cached from the last control computation -- -1 = uncontrolled/contested.
## Not authoritative on its own; ObjectiveRules.compute_control()
## recomputes it fresh each time. Cached here so GameStateManager can
## detect a CHANGE and emit OBJECTIVE_CONTROLLED only when it actually flips.
var controlling_player: int = -1
