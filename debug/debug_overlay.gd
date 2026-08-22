## Developer/debug overlay: grid, coordinates, movement ranges, LoS
## calculations, terrain collision, cover determination, objective
## control, current game state, random seed, event history. Must never
## alter normal gameplay unless explicitly enabled.
##
## PHASE: 1 (this stub, disabled by default); filled in progressively
## alongside the systems it visualizes.
class_name DebugOverlay
extends CanvasLayer

var enabled: bool = false
