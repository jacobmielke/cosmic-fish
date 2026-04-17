@tool
extends Resource
class_name IsoMapData

## Isometric map data resource.
## Stores terrain/detail type palettes and cell placement data.

const _TerrainType = preload("res://addons/iso_painter/TerrainType.gd")
const _DetailType  = preload("res://addons/iso_painter/DetailType.gd")
const _WaterBody   = preload("res://addons/iso_painter/WaterBody.gd")

## Type palettes — define these in the inspector
@export var terrain_types: Array[Resource] = []
@export var detail_types: Array[Resource] = []

## Tile dimensions
@export var tile_width: int = 64
@export var tile_height: int = 32
@export var height_step: int = 16

## Cell data — indices into the palettes above
@export var cells: Dictionary = {}    # Vector2i -> { "height": float, "terrain": int, "tile_type": int }
@export var details: Dictionary = {}  # Vector2i -> { "type": int, "variant": int }

## Water bodies — rebuilt from connected water cells via rebuild_water_bodies().
@export var water_bodies: Array[Resource] = []
var _cell_to_body: Dictionary = {}  # Vector2i -> WaterBody (rebuilt lazily)

# Tile shape types (how the block is shaped, not what it looks like)
const TYPE_FULL  = 0
const TYPE_HALF  = 1
const TYPE_TOP   = 2
const TYPE_FLOOR = 3
const TILE_TYPE_NAMES = ["Full Block", "Half Block", "Top Only", "Floor"]


func set_cell(cell: Vector2i, height: float, terrain: int, tile_type: int) -> void:
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


func get_height_at(cell: Vector2i) -> float:
	return get_cell(cell).get("height", 0.0)


func get_all_cells() -> Array:
	return cells.keys()


func get_water_body(cell: Vector2i) -> Resource:
	if water_bodies == null or water_bodies.is_empty():
		return null
	if _cell_to_body.is_empty():
		_rebuild_lookup()
	return _cell_to_body.get(cell, null)


func _rebuild_lookup() -> void:
	_cell_to_body.clear()
	if water_bodies == null:
		return
	for body in water_bodies:
		if not body:
			continue
		for c in body.cells:
			_cell_to_body[c] = body


## Flood-fills connected water cells into WaterBody resources.
## Preserves params from old bodies that overlap new ones (match by any shared cell).
func rebuild_water_bodies() -> void:
	if water_bodies == null:
		water_bodies = []
	var old_by_cell := {}
	for body in water_bodies:
		if not body:
			continue
		for c in body.cells:
			old_by_cell[c] = body

	var visited := {}
	var new_bodies: Array[Resource] = []
	for cell in cells:
		if visited.has(cell) or not is_water(cell):
			continue
		# BFS over 4-connected water neighbors
		var component: Array[Vector2i] = []
		var queue: Array = [cell]
		visited[cell] = true
		while not queue.is_empty():
			var c: Vector2i = queue.pop_back()
			component.append(c)
			for n in [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]:
				var nc: Vector2i = c + n
				if visited.has(nc) or not is_water(nc):
					continue
				visited[nc] = true
				queue.append(nc)

		# Reuse old body if any cell overlaps; else make fresh
		var reused: Resource = null
		for c in component:
			if old_by_cell.has(c):
				reused = old_by_cell[c]
				break
		var body: Resource = reused if reused else _WaterBody.new()
		body.cells = component
		new_bodies.append(body)

	water_bodies = new_bodies
	_rebuild_lookup()


static func rotate_cell(c: Vector2i, steps: int) -> Vector2i:
	var r = c
	for i in (steps % 4):
		r = Vector2i(r.y, -r.x)
	return r
