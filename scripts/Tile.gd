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

# -- Exports
@export var cell: Vector2i = Vector2i.ZERO
@export var height: int = 0
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
var _area: Area2D
var _is_water := false


func _ready() -> void:
	_is_water = terrain_type and terrain_type.is_water
	_build_collision()
	_target_pos = get_base_position()
	position = _target_pos
	set_process(true)


func _process(delta: float) -> void:
	if _is_water:
		_bob_time += delta * WATER_BOB_SPEED
		_bob_offset = sin(_bob_time) * WATER_BOB_AMOUNT

	position = position.lerp(_target_pos + Vector2(0, _bob_offset), MOVE_SPEED * delta)


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

	draw_polyline(PackedVector2Array([
		Vector2(0, -hh), Vector2(hw, 0),
		Vector2(0, hh), Vector2(-hw, 0),
		Vector2(0, -hh),
	]), Color(0, 0, 0, 0.3), 1.0)


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
	var side_color = Color.GRAY
	if terrain_type:
		top_color = terrain_type.editor_color
		side_color = terrain_type.side_color

	var side_h = _get_side_height()
	if side_h > 0.0:
		draw_colored_polygon(PackedVector2Array([
			Vector2(hw, 0), Vector2(0, hh),
			Vector2(0, hh + side_h), Vector2(hw, side_h),
		]), side_color)
		draw_colored_polygon(PackedVector2Array([
			Vector2(-hw, 0), Vector2(0, hh),
			Vector2(0, hh + side_h), Vector2(-hw, side_h),
		]), side_color.darkened(0.2))

	draw_colored_polygon(PackedVector2Array([
		Vector2(0, -hh), Vector2(hw, 0),
		Vector2(0, hh), Vector2(-hw, 0),
	]), top_color)


func _get_side_height() -> float:
	match tile_type:
		TYPE_FULL:  return float(height_step)
		TYPE_HALF:  return float(height_step) / 2.0
		_:          return 0.0


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

func set_highlight(enabled: bool, color: Color = Color(1, 1, 0.3, 0.55)) -> void:
	is_highlighted = enabled
	highlight_color = color
	queue_redraw()


func set_block(id: int) -> void:
	terrain_index = id
	queue_redraw()


func set_height_value(h: int) -> void:
	height = h
	_update_position()
	queue_redraw()


# ---------------------------------------------------------------------------
# Collision (water tiles only at runtime)
# ---------------------------------------------------------------------------

func _build_collision() -> void:
	if Engine.is_editor_hint() or not _is_water:
		return
	_area = Area2D.new()
	var shape = CollisionPolygon2D.new()
	shape.polygon = PackedVector2Array([
		Vector2(0, -tile_h / 2.0),
		Vector2(tile_w / 2.0, 0),
		Vector2(0, tile_h / 2.0),
		Vector2(-tile_w / 2.0, 0),
	])
	_area.add_child(shape)
	_area.input_pickable = true
	_area.connect("input_event", _on_area_input)
	_area.connect("mouse_entered", _on_mouse_entered)
	add_child(_area)


func _update_position() -> void:
	_target_pos = get_base_position()


func get_base_position() -> Vector2:
	var base = iso_x * cell.x + iso_y * cell.y
	base.y -= height * height_step
	return base


func get_ground_depth() -> float:
	return (iso_x.y * cell.x + iso_y.y * cell.y)


# ---------------------------------------------------------------------------
# Input
# ---------------------------------------------------------------------------

func _on_area_input(_viewport, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		emit_signal("tile_clicked", self)


func _on_mouse_entered() -> void:
	emit_signal("tile_hovered", self)
