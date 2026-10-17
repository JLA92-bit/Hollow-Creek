class_name Ground
extends RefCounted
## Ground types for the logical grid (docs/BUILDING.md) and their rules.

enum Type { GRASS, DIRT, GRAVEL, MUD, WATER, ROAD_SEALED, FOOTPATH, FLOOR }

const NAMES: Array[String] = ["grass", "dirt", "gravel", "mud", "water", "sealed_road", "footpath", "floor"]

## Path cost for residents (docs/SIMULATION.md). Water is impassable.
const PATH_COST: Array[float] = [1.5, 1.0, 1.0, 2.0, INF, 1.0, 1.0, 1.0]


static func from_name(n: String) -> Type:
	var i := NAMES.find(n)
	assert(i >= 0, "Unknown ground type: %s" % n)
	return i as Type


## How readable a bootprint is on this ground: 0 none, 0.5 faint (50% of steps), 1 clear.
static func print_clarity(t: Type, wet: bool) -> float:
	match t:
		Type.GRASS:
			return 0.5 if wet else 0.0
		Type.DIRT:
			return 1.0 if wet else 0.5
		Type.MUD:
			return 1.0
		_:
			return 0.0


## Splat weights for the terrain shader: (dirt, gravel, mud). Grass is whatever is left.
static func splat(t: Type) -> Color:
	match t:
		Type.DIRT, Type.FOOTPATH, Type.FLOOR:
			return Color(1, 0, 0)
		Type.GRAVEL, Type.ROAD_SEALED:
			return Color(0, 1, 0)
		Type.MUD, Type.WATER:
			return Color(0, 0, 1)
		_:
			return Color(0, 0, 0)
