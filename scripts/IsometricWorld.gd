extends Node2D
class_name IsometricWorld

## IsometricWorld — runtime isometric renderer.
## Reads an IsoMapData resource and spawns Tile nodes.

const TileScene = preload("res://scenes/world/Tile.tscn")

@export var map_data: Resource   # IsoMapData

var casting_manager: Node
var rotation_step: int = 0
var _iso_bases: Array = []
var _tiles: Dictionary = {}


func _ready() -> void:
	casting_manager = get_node_or_null("../CastingManager")
	if map_data:
		_build_bases()
		spawn_tiles()


func _build_bases() -> void:
	var hw = map_data.tile_width / 2.0
	var hh = map_data.tile_height / 2.0
	_iso_bases = [
		[Vector2(hw, hh),  Vector2(-hw, hh)],    # 0°
		[Vector2(hw, -hh), Vector2(hw, hh)],      # 90° CW
		[Vector2(-hw, -hh), Vector2(hw, -hh)],    # 180°
		[Vector2(-hw, hh), Vector2(-hw, -hh)],    # 270°
	]


# ---------------------------------------------------------------------------
# Tile spawning
# ---------------------------------------------------------------------------

func spawn_tiles() -> void:
	for t in get_children():
		if t.has_method("set_block"):
			t.queue_free()
	_tiles.clear()

	if not map_data:
		return

	var cells = map_data.cells
	for cell in cells:
		var data  = cells[cell]
		var h: int      = data.get("height", 0)
		var terrain: int = data.get("terrain", 0)
		var ttype: int  = data.get("tile_type", 0)

		for fh in range(h):
			_spawn_tile(cell, fh, terrain, 0)

		var tile = _spawn_tile(cell, h, terrain, ttype)
		tile.connect("tile_clicked", _on_tile_clicked)
		tile.connect("tile_hovered", _on_tile_hovered)
		_tiles[cell] = tile

	_sort_tiles()


func _spawn_tile(cell: Vector2i, h: int, terrain_idx: int, ttype: int, drop: bool = true) -> Node:
	var tile = TileScene.instantiate()
	tile.cell          = cell
	tile.height        = h
	tile.terrain_index = terrain_idx
	tile.tile_type     = ttype
	tile.tile_w        = map_data.tile_width
	tile.tile_h        = map_data.tile_height
	tile.height_step   = map_data.height_step
	tile.iso_x         = _iso_bases[rotation_step][0]
	tile.iso_y         = _iso_bases[rotation_step][1]
	# Pass terrain type resource if available
	if terrain_idx >= 0 and terrain_idx < map_data.terrain_types.size():
		tile.terrain_type = map_data.terrain_types[terrain_idx]
	add_child(tile)
	if drop:
		var target = tile.get_base_position()
		var depth = cell.x + cell.y
		tile.position = target + Vector2(0, -300 - depth * 15)
	return tile


# ---------------------------------------------------------------------------
# Rotation
# ---------------------------------------------------------------------------

func rotate_world(direction: int = 1) -> void:
	rotation_step = (rotation_step + direction) % 4
	if rotation_step < 0:
		rotation_step += 4

	var basis = _iso_bases[rotation_step]
	var all_tiles = get_children().filter(func(n): return n.has_method("set_block"))
	for t in all_tiles:
		t.iso_x = basis[0]
		t.iso_y = basis[1]
		t._update_position()
	_sort_tiles()


# ---------------------------------------------------------------------------
# Public helpers
# ---------------------------------------------------------------------------

func get_tile(cell: Vector2i) -> Node:
	return _tiles.get(cell, null)

func get_all_cells() -> Array:
	return _tiles.keys()

func highlight_cells(cells: Array, color: Color) -> void:
	for c in cells:
		var t = get_tile(c)
		if t:
			t.set_highlight(true, color)

func clear_highlights() -> void:
	for t in _tiles.values():
		t.set_highlight(false)

func is_water(cell: Vector2i) -> bool:
	if map_data:
		return map_data.is_water(cell)
	return false


# ---------------------------------------------------------------------------
# Input routing
# ---------------------------------------------------------------------------

func _on_tile_clicked(tile: Node) -> void:
	if casting_manager:
		casting_manager.on_tile_clicked(tile)

func _on_tile_hovered(tile: Node) -> void:
	pass


# ---------------------------------------------------------------------------
# Draw order
# ---------------------------------------------------------------------------

func _sort_tiles() -> void:
	var tiles = get_children().filter(func(n): return n.has_method("set_block"))
	tiles.sort_custom(func(a, b):
		var da = a.get_ground_depth()
		var db = b.get_ground_depth()
		if da != db:
			return da < db
		return a.height < b.height
	)
	for i in tiles.size():
		move_child(tiles[i], i)
