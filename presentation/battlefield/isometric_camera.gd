## Isometric/top-down camera rig for the battlefield. Purely visual --
## never used as a source of truth for line-of-sight or visibility
## (see core/rules/line_of_sight_rules.gd, which is camera-independent).
##
## PHASE: 10 (Isometric battlefield).
class_name IsometricCamera
extends Node3D

# TODO (Phase 10): pan/zoom/rotate controls, angle matching the
# X-COM-style presentation described in the master spec.
