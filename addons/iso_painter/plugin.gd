@tool
extends EditorPlugin

## IsoPainter plugin
## Manages IsoMapData resources. The dock is the editor.
## No dependency on game scripts — just reads/writes .tres files.

const PainterDock = preload("res://addons/iso_painter/PainterDock.gd")
const MapData     = preload("res://addons/iso_painter/IsoMapData.gd")

var _dock: Control


func _enter_tree() -> void:
	_dock = PainterDock.new()
	add_control_to_dock(DOCK_SLOT_RIGHT_UL, _dock)
	_dock.save_requested.connect(_on_save)


func _exit_tree() -> void:
	remove_control_from_docks(_dock)
	_dock.free()


# ---------------------------------------------------------------------------
# Editor integration — handle IsoMapData resources
# ---------------------------------------------------------------------------

func _handles(object: Object) -> bool:
	return object is Resource and object.get_script() == MapData


func _edit(object: Object) -> void:
	if object is Resource and object.get_script() == MapData:
		_dock.load_map(object)


# ---------------------------------------------------------------------------
# Save
# ---------------------------------------------------------------------------

func _on_save() -> void:
	var map = _dock.get_map_data()
	if not map:
		return
	if map.resource_path.is_empty():
		# New resource — prompt for save location
		var dialog = FileDialog.new()
		dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
		dialog.filters = ["*.tres ; Iso Map Data"]
		dialog.access = FileDialog.ACCESS_RESOURCES
		dialog.file_selected.connect(func(path):
			map.resource_path = path
			ResourceSaver.save(map, path)
			dialog.queue_free()
		)
		dialog.canceled.connect(func(): dialog.queue_free())
		get_editor_interface().get_base_control().add_child(dialog)
		dialog.popup_centered(Vector2i(600, 400))
	else:
		ResourceSaver.save(map, map.resource_path)
