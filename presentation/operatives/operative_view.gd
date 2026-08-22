## Visual representation of a single operative: mesh, animation, VFX,
## audio. Bound to an OperativeState id and re-reads that state via
## EventBus signals -- never mutates OperativeState directly, and never
## stores gameplay-authoritative position (OperativeState.position is
## authoritative; this just visually follows it).
##
## PHASE: 10/11 (Isometric battlefield / UI) for wiring; 16 for polish.
class_name OperativeView
extends Node3D

var operative_id: String = ""

func bind_to_operative(id: String) -> void:
	operative_id = id
	# TODO: subscribe to relevant EventBus events (OperativeMoved, DamageApplied, ...)
