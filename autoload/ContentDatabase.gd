## Autoload that loads and indexes all data/ Resources (factions,
## operatives, weapons, missions, maps, ...) at startup, so the rest of
## the game looks content up by id rather than loading .tres files ad hoc.
##
## PHASE: 2 (Core data structures) for the shape; populated as content
## lands per faction/mission in Phase 12/13.
extends Node

var _factions: Dictionary = {}
var _operatives: Dictionary = {}
var _weapons: Dictionary = {}

## Explicit paths rather than a directory scan for now -- swap for a
## recursive res://data/ scan once the full roster lands in Phase 12,
## at which point hardcoding a path per faction stops scaling.
const FACTION_PATHS := [
	"res://data/factions/death_korps/death_korps.tres",
	"res://data/factions/kommandos/kommandos.tres",
]

func _ready() -> void:
	_load_factions()

func _load_factions() -> void:
	for path in FACTION_PATHS:
		if not ResourceLoader.exists(path):
			push_warning("ContentDatabase: missing faction file %s" % path)
			continue
		var faction: FactionData = load(path)
		_factions[faction.faction_id] = faction
		for operative in faction.roster:
			_operatives[operative.operative_id] = operative
			for weapon in operative.weapons:
				_weapons[weapon.weapon_id] = weapon

func get_faction(faction_id: String) -> FactionData:
	return _factions.get(faction_id, null)

func get_operative(operative_id: String) -> OperativeData:
	return _operatives.get(operative_id, null)

func get_weapon(weapon_id: String) -> WeaponData:
	return _weapons.get(weapon_id, null)
