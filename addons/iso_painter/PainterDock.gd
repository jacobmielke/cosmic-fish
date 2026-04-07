@tool
extends VBoxContainer

## PainterDock — 2D grid editor for isometric maps.
## Edits an IsoMapData resource. The iso scene view is just a runtime renderer.

const MapData = preload("res://addons/iso_painter/IsoMapData.gd")

signal map_changed()
signal save_requested()

enum BrushMode { TERRAIN, DETAIL }

var brush_mode        := BrushMode.TERRAIN
var current_height    := 0
var current_block     := 0
var current_tile_type := 0
var current_detail    := 0
var brush_size        := 1
var erasing           := false

var _map_data: Resource
var _grid_canvas: _GridCanvas
var _file_label: Label
var _terrain_options: VBoxContainer
var _detail_options: VBoxContainer
var _terrain_btn: OptionButton
var _detail_btn: OptionButton


func _init() -> void:
	name = "IsoPainter"
	size_flags_horizontal = Control.SIZE_EXPAND_FILL

	# -- Title
	var title = Label.new()
	title.text = "Iso Painter"
	title.add_theme_font_size_override("font_size", 14)
	add_child(title)

	# -- File info
	_file_label = Label.new()
	_file_label.text = "No map loaded"
	_file_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	add_child(_file_label)

	add_child(HSeparator.new())

	# -- Grid canvas
	_grid_canvas = _GridCanvas.new()
	_grid_canvas.custom_minimum_size = Vector2(0, 300)
	_grid_canvas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_grid_canvas.cell_painted.connect(_on_cell_painted)
	_grid_canvas.cell_erased.connect(_on_cell_erased)
	add_child(_grid_canvas)

	add_child(HSeparator.new())

	# -- Brush mode
	var mode_label = Label.new()
	mode_label.text = "Brush Mode"
	add_child(mode_label)

	var mode_btn = OptionButton.new()
	mode_btn.add_item("Terrain")
	mode_btn.add_item("Detail")
	mode_btn.item_selected.connect(func(idx):
		brush_mode = idx as BrushMode
		_terrain_options.visible = (brush_mode == BrushMode.TERRAIN)
		_detail_options.visible = (brush_mode == BrushMode.DETAIL)
	)
	add_child(mode_btn)

	# -- Erase toggle
	var erase_btn = CheckButton.new()
	erase_btn.text = "Erase"
	erase_btn.toggled.connect(func(on):
		erasing = on
		_grid_canvas.erasing = on
	)
	add_child(erase_btn)

	# -- Brush size
	var bs_label = Label.new()
	bs_label.text = "Brush Size"
	add_child(bs_label)

	var bs_spin = SpinBox.new()
	bs_spin.min_value = 1
	bs_spin.max_value = 8
	bs_spin.step      = 1
	bs_spin.value_changed.connect(func(v):
		brush_size = int(v)
		_grid_canvas.brush_size = brush_size
	)
	add_child(bs_spin)

	add_child(HSeparator.new())

	# -- Terrain options
	_terrain_options = VBoxContainer.new()
	add_child(_terrain_options)

	var h_label = Label.new()
	h_label.text = "Height (0-8)"
	_terrain_options.add_child(h_label)

	var h_spin = SpinBox.new()
	h_spin.min_value = 0
	h_spin.max_value = 8
	h_spin.step      = 1
	h_spin.value_changed.connect(func(v): current_height = int(v))
	_terrain_options.add_child(h_spin)

	_terrain_options.add_child(HSeparator.new())

	var tt_label = Label.new()
	tt_label.text = "Tile Type"
	_terrain_options.add_child(tt_label)

	var tt_btn = OptionButton.new()
	for n in MapData.TILE_TYPE_NAMES:
		tt_btn.add_item(n)
	tt_btn.item_selected.connect(func(idx): current_tile_type = idx)
	_terrain_options.add_child(tt_btn)

	_terrain_options.add_child(HSeparator.new())

	var b_label = Label.new()
	b_label.text = "Terrain"
	_terrain_options.add_child(b_label)

	_terrain_btn = OptionButton.new()
	_terrain_btn.item_selected.connect(func(idx): current_block = idx)
	_terrain_options.add_child(_terrain_btn)

	# -- Detail options (hidden by default)
	_detail_options = VBoxContainer.new()
	_detail_options.visible = false
	add_child(_detail_options)

	var d_label = Label.new()
	d_label.text = "Detail Type"
	_detail_options.add_child(d_label)

	_detail_btn = OptionButton.new()
	_detail_btn.item_selected.connect(func(idx): current_detail = idx)
	_detail_options.add_child(_detail_btn)

	add_child(HSeparator.new())

	# -- Save / Clear buttons
	var action_row = HBoxContainer.new()
	var save_btn = Button.new()
	save_btn.text = "Save"
	save_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	save_btn.pressed.connect(func(): save_requested.emit())
	action_row.add_child(save_btn)
	var clear_btn = Button.new()
	clear_btn.text = "Clear Map"
	clear_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	clear_btn.pressed.connect(_on_clear)
	action_row.add_child(clear_btn)
	add_child(action_row)


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

func load_map(map_data: Resource) -> void:
	_map_data = map_data
	if _map_data:
		_file_label.text = _map_data.resource_path.get_file() if _map_data.resource_path else "Unsaved map"
		_grid_canvas.cell_data = _map_data.cells
		_grid_canvas.detail_data = _map_data.details
		_grid_canvas.terrain_types = _map_data.terrain_types
		_grid_canvas.detail_types = _map_data.detail_types
		_populate_type_buttons()
	else:
		_file_label.text = "No map loaded"
		_grid_canvas.cell_data = {}
		_grid_canvas.detail_data = {}
		_grid_canvas.terrain_types = []
		_grid_canvas.detail_types = []
	_grid_canvas.queue_redraw()


func _populate_type_buttons() -> void:
	_terrain_btn.clear()
	for tt in _map_data.terrain_types:
		_terrain_btn.add_item(tt.name if tt else "???")

	_detail_btn.clear()
	for dt in _map_data.detail_types:
		_detail_btn.add_item(dt.name if dt else "???")


func get_map_data() -> Resource:
	return _map_data


# ---------------------------------------------------------------------------
# Grid paint callbacks
# ---------------------------------------------------------------------------

func _get_brush_cells(center: Vector2i) -> Array:
	var cells = []
	for dx in range(brush_size):
		for dy in range(brush_size):
			cells.append(center + Vector2i(dx, dy))
	return cells


func _on_cell_painted(cell: Vector2i) -> void:
	if not _map_data:
		return
	for c in _get_brush_cells(cell):
		if brush_mode == BrushMode.TERRAIN:
			_map_data.set_cell(c, current_height, current_block, current_tile_type)
		else:
			_map_data.set_detail(c, current_detail)
	_grid_canvas.queue_redraw()
	map_changed.emit()


func _on_cell_erased(cell: Vector2i) -> void:
	if not _map_data:
		return
	for c in _get_brush_cells(cell):
		if brush_mode == BrushMode.TERRAIN:
			_map_data.erase_cell(c)
		else:
			_map_data.erase_detail(c)
	_grid_canvas.queue_redraw()
	map_changed.emit()


func _on_clear() -> void:
	if not _map_data:
		return
	_map_data.clear()
	_grid_canvas.queue_redraw()
	map_changed.emit()


# ===========================================================================
# Inner class: the actual drawable grid
# ===========================================================================

class _GridCanvas extends Control:
	signal cell_painted(cell: Vector2i)
	signal cell_erased(cell: Vector2i)

	const CELL_SIZE = 24.0

	var cell_data: Dictionary = {}
	var detail_data: Dictionary = {}
	var terrain_types: Array = []
	var detail_types: Array = []
	var erasing := false
	var brush_size := 1
	var _painting := false
	var _last_painted_cell := Vector2i(-9999, -9999)
	var _hover_cell := Vector2i(-9999, -9999)
	var _pan_offset := Vector2.ZERO
	var _panning := false

	func _ready() -> void:
		clip_contents = true
		mouse_filter = Control.MOUSE_FILTER_STOP
		focus_mode = Control.FOCUS_ALL

	func _is_visible(pos: Vector2) -> bool:
		var margin = CELL_SIZE * 2.0
		return pos.x > -margin and pos.x < size.x + margin \
			and pos.y > -margin and pos.y < size.y + margin

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.12, 0.12, 0.14), true)

		var center = size / 2.0 + _pan_offset
		var hw = CELL_SIZE
		var hh = CELL_SIZE / 2.0

		# Draw terrain cells (culled)
		for cell in cell_data:
			var pos = _cell_to_local(cell, center)
			if not _is_visible(pos):
				continue
			var data = cell_data[cell]
			var tidx = data.get("terrain", 0)
			var h = data.get("height", 0)

			var col = Color.WHITE
			if tidx >= 0 and tidx < terrain_types.size() and terrain_types[tidx]:
				col = terrain_types[tidx].editor_color
			if h > 0:
				col = col.lightened(h * 0.06)

			draw_colored_polygon(_diamond_pts(pos, hw, hh), col)
			_draw_diamond_outline(pos, hw, hh, Color(0, 0, 0, 0.3), 1.0)

			if h > 0:
				draw_string(get_theme_default_font(), pos + Vector2(-4, 4), str(h),
					HORIZONTAL_ALIGNMENT_CENTER, -1, 10, Color(1, 1, 1, 0.7))

		# Draw detail markers (culled)
		for cell in detail_data:
			var pos = _cell_to_local(cell, center)
			if not _is_visible(pos):
				continue
			var data = detail_data[cell]
			var dtype = data.get("type", 0)

			var dcol = Color.WHITE
			var label = "?"
			if dtype >= 0 and dtype < detail_types.size() and detail_types[dtype]:
				dcol = detail_types[dtype].editor_color
				label = detail_types[dtype].editor_label

			draw_circle(pos, 6.0, dcol)
			draw_string(get_theme_default_font(), pos + Vector2(-4, 4), label,
				HORIZONTAL_ALIGNMENT_CENTER, -1, 9, Color(1, 1, 1, 0.9))

		# Hover cursor
		if _hover_cell != Vector2i(-9999, -9999):
			for dx in range(brush_size):
				for dy in range(brush_size):
					var bc = _hover_cell + Vector2i(dx, dy)
					var pos = _cell_to_local(bc, center)
					draw_colored_polygon(_diamond_pts(pos, hw, hh), Color(1, 1, 0.3, 0.2))
					_draw_diamond_outline(pos, hw, hh, Color(1, 1, 0.3, 0.8), 2.0)

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton:
			if event.button_index == MOUSE_BUTTON_LEFT:
				if event.pressed:
					_painting = true
					_last_painted_cell = Vector2i(-9999, -9999)
					_paint_at(event.position)
				else:
					_painting = false
				accept_event()
			elif event.button_index == MOUSE_BUTTON_MIDDLE:
				if event.pressed:
					_panning = true
				else:
					_panning = false
				accept_event()

		elif event is InputEventMouseMotion:
			if _panning:
				_pan_offset += event.relative
				queue_redraw()
				accept_event()
			else:
				var new_cell = _local_to_cell(event.position)
				if new_cell != _hover_cell:
					_hover_cell = new_cell
					queue_redraw()
				if _painting:
					_paint_at(event.position)
					accept_event()

	func _paint_at(pos: Vector2) -> void:
		var cell = _local_to_cell(pos)
		if cell == _last_painted_cell:
			return
		_last_painted_cell = cell
		if erasing:
			cell_erased.emit(cell)
		else:
			cell_painted.emit(cell)

	func _cell_to_local(cell: Vector2i, center: Vector2) -> Vector2:
		return center + Vector2(
			(cell.x - cell.y) * CELL_SIZE,
			(cell.x + cell.y) * (CELL_SIZE / 2.0),
		)

	func _local_to_cell(pos: Vector2) -> Vector2i:
		var center = size / 2.0 + _pan_offset
		var rel = pos - center
		var fx = rel.x / CELL_SIZE
		var fy = rel.y / (CELL_SIZE / 2.0)
		return Vector2i(
			int(round((fx + fy) / 2.0)),
			int(round((fy - fx) / 2.0)),
		)

	func _diamond_pts(center: Vector2, hw: float, hh: float) -> PackedVector2Array:
		return PackedVector2Array([
			center + Vector2(0, -hh),
			center + Vector2(hw, 0),
			center + Vector2(0, hh),
			center + Vector2(-hw, 0),
		])

	func _draw_diamond_outline(center: Vector2, hw: float, hh: float, color: Color, width: float) -> void:
		draw_polyline(PackedVector2Array([
			center + Vector2(0, -hh), center + Vector2(hw, 0),
			center + Vector2(0, hh), center + Vector2(-hw, 0),
			center + Vector2(0, -hh),
		]), color, width)
