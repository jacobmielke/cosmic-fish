extends Node

## CastingManager
## Arcade-style casting minigame:
##   1. Player holds a water tile  → casting starts
##   2. An outlined ring of water tiles smoothly pulses large→small→large…
##   3. Player clicks again to lock in — smaller radius = better catch
##
## Signals:
##   cast_confirmed(center_cell, radius, water_cells)
##   cast_cancelled

signal cast_confirmed(center_cell, radius, water_cells)
signal cast_cancelled

# -- Config
@export var pulse_speed:    float = 3.0   # radius units per second
@export var max_radius:     int   = 4     # ring starts here
@export var outline_color:  Color = Color(1.0, 1.0, 1.0, 1.0)
@export var outline_width:  float = 8.0

# -- References
@onready var world: Node = $"../IsometricWorld"

# -- State
enum State { IDLE, CASTING }
var _state:          State    = State.IDLE
var _center_cell:    Vector2i = Vector2i.ZERO
var _radius_f:       float    = 0.0
var _shrinking:      bool     = true
var _prev_ring:      int      = -1

# -- Outline overlay (drawn on top of everything)
var _overlay: Node2D
var _border_edges: Array = [] # Array of [Vector2i cell, Vector2i outside_dir]


func _ready() -> void:
	_overlay = Node2D.new()
	_overlay.z_index = 4096
	_overlay.z_as_relative = false
	_overlay.draw.connect(_draw_overlay)
	_overlay.visible = false
	# Defer adding to world so @onready has resolved
	call_deferred("_add_overlay")


func _add_overlay() -> void:
	if world:
		world.add_child(_overlay)


func _process(delta: float) -> void:
	if _state != State.CASTING:
		return

	if _shrinking:
		_radius_f -= pulse_speed * delta
		if _radius_f <= 0.0:
			_radius_f = 0.0
			_shrinking = false
	else:
		_radius_f += pulse_speed * delta
		if _radius_f >= float(max_radius):
			_radius_f = float(max_radius)
			_shrinking = true

	var ring = int(round(_radius_f))
	if ring != _prev_ring:
		_prev_ring = ring
		_refresh_edge(ring)

	_overlay.queue_redraw()


# ---------------------------------------------------------------------------
# Called by IsometricWorld when a tile is clicked
# ---------------------------------------------------------------------------

func on_tile_clicked(tile: Node) -> void:
	if _state == State.CASTING:
		confirm_cast()
		return

	if not world.is_water(tile.cell):
		return

	_begin_cast(tile.cell)


# ---------------------------------------------------------------------------
# Cast button — locks in the current radius
# ---------------------------------------------------------------------------

func confirm_cast() -> void:
	if _state != State.CASTING:
		return

	var radius = int(round(_radius_f))
	var filled = _get_filled_cells(_center_cell, radius)
	var water_cells = filled.filter(func(c): return world.is_water(c))
	emit_signal("cast_confirmed", _center_cell, radius, water_cells)
	_end_cast()


# ---------------------------------------------------------------------------
# Internal
# ---------------------------------------------------------------------------

func _begin_cast(center: Vector2i) -> void:
	_state       = State.CASTING
	_center_cell = center
	_radius_f    = float(max_radius)
	_shrinking   = true
	_prev_ring   = -1
	_overlay.visible = true


func _refresh_edge(radius: int) -> void:
	var water_in_area: Dictionary = {}
	for c in _get_filled_cells(_center_cell, radius):
		if world.is_water(c) and world.get_tile(c) != null:
			water_in_area[c] = true

	# Store each individual border segment as [cell, outside_direction]
	_border_edges = []
	var dirs = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	for c in water_in_area:
		for d in dirs:
			if not water_in_area.has(c + d):
				_border_edges.append([c, d])


func _end_cast() -> void:
	_state = State.IDLE
	_prev_ring = -1
	_border_edges = []
	_overlay.visible = false


func _cancel() -> void:
	emit_signal("cast_cancelled")
	_end_cast()


# ---------------------------------------------------------------------------
# Overlay drawing — outlines rendered on top of all tiles
# ---------------------------------------------------------------------------

func _draw_overlay() -> void:
	if _state != State.CASTING or _border_edges.is_empty():
		return

	var frac = abs(_radius_f - round(_radius_f))
	var alpha = lerpf(outline_color.a, outline_color.a * 0.25, frac * 2.0)
	var col = Color(outline_color.r, outline_color.g, outline_color.b, alpha)

	# Diamond vertices (local to each tile)
	var hw = world.map_data.tile_width / 2.0
	var hh = world.map_data.tile_height / 2.0
	var verts = [
		Vector2(0, -hh),  # top
		Vector2(hw, 0),   # right
		Vector2(0, hh),   # bottom
		Vector2(-hw, 0),  # left
	]
	# Midpoint of each edge — used to match direction to edge
	var mids: Array[Vector2] = []
	for i in 4:
		mids.append((verts[i] + verts[(i + 1) % 4]) / 2.0)

	# Get current iso basis for direction→screen mapping
	var sample = world.get_tile(_center_cell)
	if not sample:
		return
	var iso_x = sample.iso_x
	var iso_y = sample.iso_y

	for entry in _border_edges:
		var c: Vector2i = entry[0]
		var d: Vector2i = entry[1]
		var t = world.get_tile(c)
		if not t:
			continue
		var pos = t.get_base_position()

		# Screen-space offset toward the outside neighbor
		var offset = float(d.x) * iso_x + float(d.y) * iso_y

		# Find which diamond edge faces that direction
		var best_i = 0
		var best_dot = -INF
		for i in 4:
			var dot = mids[i].dot(offset)
			if dot > best_dot:
				best_dot = dot
				best_i = i

		_overlay.draw_line(
			pos + verts[best_i],
			pos + verts[(best_i + 1) % 4],
			col, outline_width, true
		)


# ---------------------------------------------------------------------------
# Cell math (Chebyshev distance)
# ---------------------------------------------------------------------------

func _get_filled_cells(center: Vector2i, radius: int) -> Array:
	var cells := []
	for x in range(-radius, radius + 1):
		for y in range(-radius, radius + 1):
			if maxi(absi(x), absi(y)) <= radius:
				cells.append(center + Vector2i(x, y))
	return cells
