@tool
extends Node2D
class_name Tile

## Individual isometric tile.
## Renders from a TerrainType resource if provided, otherwise colored polygons.

signal tile_clicked(tile)
signal tile_hovered(tile)

# -- Tile shape types
const TYPE_FULL  = 0
const TYPE_HALF  = 1
const TYPE_TOP   = 2
const TYPE_FLOOR = 3

# -- Layout (set by IsometricWorld from IsoMapData)
var tile_w: int = 64
var tile_h: int = 32
var height_step: int = 16

const WATER_BOB_AMOUNT = 3.0
const WATER_BOB_SPEED  = 2.0
const TAU_F := TAU

const HOLD_DURATION := 0.35    # seconds to hold a water tile before casting starts
const HOLD_RING_RADIUS := 18.0
const HOLD_RING_WIDTH := 3.0

# -- Exports
@export var cell: Vector2i = Vector2i.ZERO
@export var height: float = 0.0
@export var terrain_index: int = 0
@export var tile_type: int = TYPE_FULL

# -- Projection basis (set by IsometricWorld)
var iso_x := Vector2(32, 16)
var iso_y := Vector2(-32, 16)

# -- TerrainType resource (set by IsometricWorld)
var terrain_type: Resource

# -- Movement
const MOVE_SPEED = 10.0
var _target_pos := Vector2.ZERO

# -- Internal state
var is_highlighted  := false
var highlight_color := Color(1, 1, 0.3, 0.55)
var _bob_offset     := 0.0
var _bob_time       := 0.0
# _area removed — picking is now done via contains_point() in IsometricWorld
var _is_water := false
var is_surface := false

# -- Press-and-hold (water only)
var _holding := false
var _hold_time := 0.0
var _hold_fired := false
var _spinner: Node2D

# -- Detail Type (set by IsometricWorld)
var detail_type: Resource
var _detail_sprite: Sprite2D

# -- Water body (set by IsometricWorld for water tiles)
var water_body: Resource
var _water_phase: float = 0.0         # precomputed river phase along flow path
var _water_flow_strength: float = 0.0
var _water_noise_amount: float = 1.0
var _water_flow_speed: float = 1.0


func _ready() -> void:
	_is_water = terrain_type and terrain_type.is_water
	_build_detail_sprite()
	_cache_water_params()
	_target_pos = get_base_position()
	position = _target_pos
	set_process(true)


func _cache_water_params() -> void:
	if not _is_water or not water_body:
		return
	_water_noise_amount = water_body.noise_amount
	_water_flow_strength = water_body.flow_strength
	_water_flow_speed = water_body.flow_speed
	var wl: float = max(0.5, water_body.wavelength)
	_water_phase = water_body.get_phase_at(cell) / wl


func _build_detail_sprite() -> void:
	if not detail_type or not detail_type.sprite:
		return
	_detail_sprite = Sprite2D.new()
	_detail_sprite.texture = detail_type.sprite
	_detail_sprite.centered = false
	var size = Vector2(detail_type.sprite.get_size())
	_detail_sprite.position = Vector2(-size.x / 2.0, -size.y) + detail_type.offset
	add_child(_detail_sprite)


func _process(delta: float) -> void:
	if _is_water:
		_bob_time += delta * WATER_BOB_SPEED
		var chop = sin(_bob_time + cell.x * 0.7) * cos(_bob_time * 1.3 + cell.y * 0.5)
		var wave = sin(_bob_time * _water_flow_speed - _water_phase * TAU_F) * _water_flow_strength
		_bob_offset = (chop * _water_noise_amount + wave) * WATER_BOB_AMOUNT

	position = position.lerp(_target_pos + Vector2(0, _bob_offset), MOVE_SPEED * delta)

	if _holding and not _hold_fired:
		_hold_time += delta
		if _spinner:
			_spinner.global_position = global_position
			_spinner.queue_redraw()
		if _hold_time >= HOLD_DURATION:
			_hold_fired = true
			_hide_spinner()
			emit_signal("tile_clicked", self)


# ---------------------------------------------------------------------------
# Drawing
# ---------------------------------------------------------------------------

func _draw() -> void:
	var hw = tile_w / 2.0
	var hh = tile_h / 2.0

	if terrain_type and terrain_type.sprite:
		_draw_sprite(hw, hh)
	else:
		_draw_colored(hw, hh)

	if is_highlighted:
		var top = PackedVector2Array([
			Vector2(0, -hh), Vector2(hw, 0),
			Vector2(0, hh), Vector2(-hw, 0),
		])
		draw_colored_polygon(top, highlight_color)



func _draw_sprite(_hw: float, hh: float) -> void:
	var tex = terrain_type.sprite
	var region = terrain_type.sprite_region
	var use_region = region.size.x > 0 and region.size.y > 0

	var src_size = region.size if use_region else Vector2(tex.get_size())
	var dst = Rect2(
		Vector2(-src_size.x / 2.0, -src_size.y + hh),
		src_size,
	)
	if use_region:
		draw_texture_rect_region(tex, dst, region)
	else:
		draw_texture_rect(tex, dst, false)


func _draw_colored(hw: float, hh: float) -> void:
	var top_color = Color.WHITE
	if terrain_type:
		top_color = terrain_type.editor_color

	_draw_sides(hw, hh)

	draw_colored_polygon(PackedVector2Array([
		Vector2(0, -hh), Vector2(hw, 0),
		Vector2(0, hh), Vector2(-hw, 0),
	]), top_color)


func _draw_sides(hw: float, hh: float) -> void:
	var side_h = _get_side_height()
	if side_h <= 0.0:
		return

	var base = Color.GRAY
	if terrain_type:
		base = terrain_type.editor_color

	draw_colored_polygon(PackedVector2Array([
		Vector2(-hw, 0), Vector2(0, hh),
		Vector2(0, hh + side_h), Vector2(-hw, side_h),
	]), base.darkened(0.2))


func _get_side_height() -> float:
	match tile_type:
		TYPE_FULL:
			# For fractional-height surface tiles, only draw the sub-step side portion.
			# A tile at height 1.3 sits 0.3 steps above the integer level, so its
			# visible side is 0.3 * height_step tall. Integer tiles (frac == 0) draw
			# a full step (handles filler blocks and height == 0.0 cases).
			var frac := fmod(height, 1.0)
			return float(height_step) * (frac if frac > 0.0001 else 1.0)
		TYPE_HALF:  return float(height_step) / 2.0
		_:          return 0.0


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

func set_light_level(v: float) -> void:
	var c = clamp(v, 0.0, 1.0)
	self_modulate = Color(c, c, c, 1.0)


func set_highlight(enabled: bool, color: Color = Color(1, 1, 0.3, 0.55)) -> void:
	is_highlighted = enabled
	highlight_color = color
	queue_redraw()



func set_block(id: int) -> void:
	terrain_index = id
	queue_redraw()


func set_height_value(h: float) -> void:
	height = h
	_update_position()
	queue_redraw()


# ---------------------------------------------------------------------------
# Hit-testing (replaces Area2D collision pick)
# ---------------------------------------------------------------------------

## Returns true when screen-space point `p` lands inside this tile's top-face
## diamond, accounting for the tile's current world position (including bob).
func contains_point(p: Vector2) -> bool:
	if not _is_water or not is_surface:
		return false
	# Local point relative to tile's current world position
	var lp = p - global_position
	var hw = tile_w / 2.0
	var hh = tile_h / 2.0
	# Diamond |lp.x/hw| + |lp.y/hh| <= 1
	return (abs(lp.x) / hw + abs(lp.y) / hh) <= 1.0


func _update_position() -> void:
	_target_pos = get_base_position()


func get_base_position() -> Vector2:
	var base = iso_x * cell.x + iso_y * cell.y
	base.y -= height * float(height_step)
	return base


func get_ground_depth() -> float:
	return (iso_x.y * cell.x + iso_y.y * cell.y)


# ---------------------------------------------------------------------------
# Input
# ---------------------------------------------------------------------------

## Called by IsometricWorld when a press is routed to this tile.
func on_press() -> void:
	_start_hold()


## Called by IsometricWorld when the press is released.
func on_release() -> void:
	_cancel_hold()


## Called by IsometricWorld when the mouse moves over this tile.
func on_hover() -> void:
	emit_signal("tile_hovered", self)


func _start_hold() -> void:
	_holding = true
	_hold_time = 0.0
	_hold_fired = false
	_show_spinner()


func _cancel_hold() -> void:
	if not _holding:
		return
	_holding = false
	_hold_time = 0.0
	_hold_fired = false
	_hide_spinner()


func cancel_interaction() -> void:
	_cancel_hold()


func _show_spinner() -> void:
	if not _spinner:
		_spinner = Node2D.new()
		_spinner.top_level = true
		_spinner.z_index = 4096
		_spinner.z_as_relative = false
		_spinner.draw.connect(_draw_spinner)
		add_child(_spinner)
	_spinner.global_position = global_position
	_spinner.visible = true
	_spinner.queue_redraw()


func _hide_spinner() -> void:
	if _spinner:
		_spinner.visible = false


func _draw_spinner() -> void:
	if not _spinner:
		return
	var progress = clamp(_hold_time / HOLD_DURATION, 0.0, 1.0)
	_spinner.draw_arc(Vector2.ZERO, HOLD_RING_RADIUS, 0.0, TAU_F, 32, Color(0, 0, 0, 0.35), HOLD_RING_WIDTH + 1.0, true)
	var start = -PI / 2.0
	var end = start + TAU_F * progress
	_spinner.draw_arc(Vector2.ZERO, HOLD_RING_RADIUS, start, end, 32, Color(1, 1, 1, 0.9), HOLD_RING_WIDTH, true)
