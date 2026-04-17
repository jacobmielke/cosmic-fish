extends Node2D
class_name IsometricWorld

## IsometricWorld — runtime isometric renderer.
## Reads an IsoMapData resource and spawns Tile nodes.

const TileScene = preload("res://scenes/world/Tile.tscn")

@export var map_data: Resource # IsoMapData
@export_range(0.0, 1.0) var ambient: float = 1.0 # 1.0 day, ~0.3 night

@onready var casting_manager: Node = $"../CastingManager"
var rotation_step: int = 0
var _iso_bases: Array = []
var _tiles: Dictionary = {}
var _light_grid: Dictionary = {} # Vector2i -> float (0..1)

# -- Input state
var _pressed_tile: Node = null   # tile currently held
var _hovered_tile: Node = null   # tile under cursor


func _ready() -> void:
	if map_data:
		_build_bases()
		spawn_tiles()


func _build_bases() -> void:
	var hw = map_data.tile_width / 2.0
	var hh = map_data.tile_height / 2.0
	_iso_bases = [
		[Vector2(hw, hh), Vector2(-hw, hh)], # 0°
		[Vector2(hw, -hh), Vector2(hw, hh)], # 90° CW
		[Vector2(-hw, -hh), Vector2(hw, -hh)], # 180°
		[Vector2(-hw, hh), Vector2(-hw, -hh)], # 270°
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
		var data = cells[cell]
		var h: float = data.get("height", 0.0)
		var terrain: int = data.get("terrain", 0)
		var ttype: int = data.get("tile_type", 0)

		# Spawn full filler blocks for every whole step below the surface
		for fh in range(int(floor(h))):
			_spawn_tile(cell, float(fh), terrain, 0)

		var detail_res: Resource = null
		var ddata = map_data.details.get(cell)
		if ddata:
			var dtype = ddata.get("type", -1)
			if dtype >= 0 and dtype < map_data.detail_types.size():
				detail_res = map_data.detail_types[dtype]

		var tile = _spawn_tile(cell, h, terrain, ttype, true, detail_res, true)

		tile.connect("tile_clicked", _on_tile_clicked)
		tile.connect("tile_hovered", _on_tile_hovered)
		_tiles[cell] = tile

	_bake_light_grid()
	_apply_lighting()
	_sort_tiles()


# ---------------------------------------------------------------------------
# Lighting
# ---------------------------------------------------------------------------

func _bake_light_grid() -> void:
	_light_grid.clear()
	for cell in map_data.cells:
		_light_grid[cell] = 1.0

	for cell in map_data.details:
		var ddata = map_data.details[cell]
		var dtype_idx = ddata.get("type", -1)
		if dtype_idx < 0 or dtype_idx >= map_data.detail_types.size():
			continue
		var dtype = map_data.detail_types[dtype_idx]
		if not dtype or dtype.shade_strength <= 0.0:
			continue
		var r = dtype.shade_radius
		if r < 0:
			continue
		var detail_top = map_data.get_height_at(cell) + dtype.height
		for dx in range(-r, r + 1):
			for dy in range(-r, r + 1):
				var c = cell + Vector2i(dx, dy)
				if not _light_grid.has(c):
					continue
				# Skip cells whose surface is at or above the detail's top.
				# (A height-0 detail therefore shades nothing.)
				if map_data.get_height_at(c) >= detail_top:
					continue
				var dist = max(abs(dx), abs(dy))
				var falloff = 1.0 - (float(dist) / float(r + 1))
				var darken = dtype.shade_strength * falloff
				_light_grid[c] = min(_light_grid[c], 1.0 - darken)


func _apply_lighting() -> void:
	for t in get_children():
		if not t.has_method("set_light_level"):
			continue
		var v = ambient * _light_grid.get(t.cell, 1.0)
		t.set_light_level(v)


func set_ambient(a: float) -> void:
	ambient = clamp(a, 0.0, 1.0)
	_apply_lighting()


func _spawn_tile(cell: Vector2i, h: float, terrain_idx: int, ttype: int, drop: bool = true, detail_res: Resource = null, surface: bool = false) -> Node:
	var tile = TileScene.instantiate()
	tile.cell = cell
	tile.height = h
	tile.terrain_index = terrain_idx
	tile.tile_type = ttype
	tile.tile_w = map_data.tile_width
	tile.tile_h = map_data.tile_height
	tile.height_step = map_data.height_step
	tile.iso_x = _iso_bases[rotation_step][0]
	tile.iso_y = _iso_bases[rotation_step][1]
	if terrain_idx >= 0 and terrain_idx < map_data.terrain_types.size():
		tile.terrain_type = map_data.terrain_types[terrain_idx]
	tile.detail_type = detail_res
	if map_data.has_method("get_water_body"):
		tile.water_body = map_data.get_water_body(cell)
	tile.is_surface = surface
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
	# Cancel any in-progress hold before moving tiles
	if _pressed_tile:
		_pressed_tile.on_release()
		_pressed_tile = null
	_hovered_tile = null
	for t in _tiles.values():
		if t.has_method("cancel_interaction"):
			t.cancel_interaction()

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

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			var t = _pick_water_tile(event.position)
			if t:
				_pressed_tile = t
				t.on_press()
		else:
			if _pressed_tile:
				_pressed_tile.on_release()
				_pressed_tile = null

	elif event is InputEventMouseMotion:
		var t = _pick_water_tile(event.position)
		if t != _hovered_tile:
			_hovered_tile = t
			if t:
				t.on_hover()


## Returns the frontmost water tile whose top-face diamond contains viewport point `p`,
## or null if none. "Frontmost" = highest ground_depth + highest height.
func _pick_water_tile(viewport_pos: Vector2) -> Node:
	# Convert viewport (screen) coords → world space so we can compare with
	# tile.global_position, which lives in the 2D world coordinate space.
	var world_pos: Vector2 = get_viewport().get_canvas_transform().affine_inverse() * viewport_pos
	var best: Node = null
	var best_depth: float = -INF
	var best_h: int = -INF
	for t in _tiles.values():
		if not t.has_method("contains_point"):
			continue
		if not t.contains_point(world_pos):
			continue
		var d: float = t.get_ground_depth()
		if d > best_depth or (d == best_depth and t.height > best_h):
			best_depth = d
			best_h = t.height
			best = t
	return best


func _on_tile_clicked(tile: Node) -> void:
	if casting_manager:
		casting_manager.on_tile_clicked(tile)

func _on_tile_hovered(_tile: Node) -> void:
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
		if a.height != b.height:
			return a.height < b.height
		return a.cell.x < b.cell.x
	)
	for i in tiles.size():
		move_child(tiles[i], i)
