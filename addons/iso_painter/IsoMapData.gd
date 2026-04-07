@tool
extends Resource
class_name IsoMapData

## Isometric map data resource.
## Stores terrain/detail type palettes and cell placement data.

const _TerrainType = preload("res://addons/iso_painter/TerrainType.gd")
const _DetailType  = preload("res://addons/iso_painter/DetailType.gd")

## Type palettes — define these in the inspector
@export var terrain_types: Array[Resource] = []
@export var detail_types: Array[Resource] = []

## Tile dimensions
@export var tile_width: int = 64
@export var tile_height: int = 32
@export var height_step: int = 16

## Cell data — indices into the palettes above
@export var cells: Dictionary = {}    # Vector2i -> { "height": int, "terrain": int, "tile_type": int }
@export var details: Dictionary = {}  # Vector2i -> { "type": int, "variant": int }

# Tile shape types (how the block is shaped, not what it looks like)
const TYPE_FULL  = 0
const TYPE_HALF  = 1
const TYPE_TOP   = 2
const TYPE_FLOOR = 3
const TILE_TYPE_NAMES = ["Full Block", "Half Block", "Top Only", "Floor"]


func set_cell(cell: Vector2i, height: int, terrain: int, tile_type: int) -> void:
	cells[cell] = {
		"height": height,
		"terrain": terrain,
		"tile_type": tile_type,
	}


func erase_cell(cell: Vector2i) -> void:
	cells.erase(cell)


func clear() -> void:
	cells.clear()
	details.clear()


func get_cell(cell: Vector2i) -> Dictionary:
	return cells.get(cell, {})


func get_terrain_type(cell: Vector2i) -> Resource:
	var idx = get_cell(cell).get("terrain", -1)
	if idx >= 0 and idx < terrain_types.size():
		return terrain_types[idx]
	return null


func is_water(cell: Vector2i) -> bool:
	var tt = get_terrain_type(cell)
	return tt != null and tt.is_water


func set_detail(cell: Vector2i, type: int, variant: int = 0) -> void:
	details[cell] = { "type": type, "variant": variant }


func erase_detail(cell: Vector2i) -> void:
	details.erase(cell)


func get_detail(cell: Vector2i) -> Dictionary:
	return details.get(cell, {})


func get_detail_type(cell: Vector2i) -> Resource:
	var idx = get_detail(cell).get("type", -1)
	if idx >= 0 and idx < detail_types.size():
		return detail_types[idx]
	return null


func get_height_at(cell: Vector2i) -> int:
	return get_cell(cell).get("height", 0)


func get_all_cells() -> Array:
	return cells.keys()


static func rotate_cell(c: Vector2i, steps: int) -> Vector2i:
	var r = c
	for i in (steps % 4):
		r = Vector2i(r.y, -r.x)
	return r
