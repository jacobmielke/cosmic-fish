extends Node

## CastingManager
## Handles the full cast flow:
##   1. Player clicks a water tile  → ring starts expanding
##   2. Ring grows outward one step at a time
##   3. Player presses cast button  → locks in radius, resolves fish catch
##
## Signals:
##   cast_confirmed(center_cell, radius, water_cells)
##   cast_cancelled

signal cast_confirmed(center_cell, radius, water_cells)
signal cast_cancelled

# -- Config
@export var ring_interval:  float = 0.6   # seconds between ring expansions
@export var max_radius:     int   = 4     # how far the ring can grow
@export var ring_color:     Color = Color(0.3, 0.85, 1.0, 0.5)
@export var center_color:   Color = Color(1.0, 0.9, 0.2, 0.7)

# -- References
@onready var world: Node = $"../IsometricWorld"

# -- State
enum State { IDLE, CASTING }
var _state:        State    = State.IDLE
var _center_cell:  Vector2i = Vector2i.ZERO
var _current_radius: int    = 0
var _timer:        float    = 0.0
var _highlighted:  Array    = []   # currently highlighted cells


func _process(delta: float) -> void:
	if _state != State.CASTING:
		return

	_timer += delta
	if _timer >= ring_interval:
		_timer = 0.0
		_expand_ring()


# ---------------------------------------------------------------------------
# Called by IsometricWorld when a tile is clicked
# ---------------------------------------------------------------------------

func on_tile_clicked(tile: Node) -> void:
	if _state == State.CASTING:
		# Clicking again cancels
		_cancel()
		return

	if not world.is_water(tile.cell):
		return  # only start cast on water

	_begin_cast(tile.cell)


# ---------------------------------------------------------------------------
# Cast button — call this from your UI
# ---------------------------------------------------------------------------

func confirm_cast() -> void:
	if _state != State.CASTING:
		return

	var water_cells = _highlighted.filter(func(c): return world.is_water(c))
	emit_signal("cast_confirmed", _center_cell, _current_radius, water_cells)
	_end_cast()


# ---------------------------------------------------------------------------
# Internal
# ---------------------------------------------------------------------------

func _begin_cast(center: Vector2i) -> void:
	_state          = State.CASTING
	_center_cell    = center
	_current_radius = 0
	_timer          = 0.0
	_highlighted    = []

	world.clear_highlights()
	_highlight_ring(0)   # light up the center tile immediately


func _expand_ring() -> void:
	_current_radius += 1

	if _current_radius > max_radius:
		# Reached max — auto confirm or loop back, your choice
		confirm_cast()
		return

	_highlight_ring(_current_radius)


func _highlight_ring(radius: int) -> void:
	var new_cells = _get_ring_cells(_center_cell, radius)
	for c in new_cells:
		if world.get_tile(c) != null:
			_highlighted.append(c)

	# Centre tile gets a different colour
	var col = center_color if radius == 0 else ring_color
	world.highlight_cells(new_cells, col)


func _end_cast() -> void:
	_state = State.IDLE
	world.clear_highlights()
	_highlighted = []


func _cancel() -> void:
	emit_signal("cast_cancelled")
	_end_cast()


# ---------------------------------------------------------------------------
# Ring cell math (Chebyshev — gives diamond rings in iso space)
# ---------------------------------------------------------------------------

func _get_ring_cells(center: Vector2i, radius: int) -> Array:
	if radius == 0:
		return [center]

	var cells := []
	for x in range(-radius, radius + 1):
		for y in range(-radius, radius + 1):
			if maxi(absi(x), absi(y)) == radius:
				cells.append(center + Vector2i(x, y))
	return cells
