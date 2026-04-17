@tool
extends Resource
class_name WaterBody

## A connected region of water tiles with shared animation parameters.
## Rebuilt by IsoMapData.rebuild_water_bodies(). Params are preserved across
## rebuilds when the new body overlaps the old one.

@export var cells: Array[Vector2i] = []

## Vertical chop amount (organic, non-directional). 0 = glassy, 1 = choppy.
@export_range(0.0, 2.0) var noise_amount: float = 1.0

## Wave amplitude along flow_path. 0 = still (lake), >0 = river.
@export_range(0.0, 2.0) var flow_strength: float = 0.0

## Speed of the travelling wave (radians/sec multiplier).
@export_range(0.0, 4.0) var flow_speed: float = 1.0

## Wavelength in cells.
@export_range(0.5, 16.0) var wavelength: float = 3.0

## River spine in cell-space. Empty = still water (lake/pond).
## Per-tile flow direction is the tangent of the nearest segment.
@export var flow_path: PackedVector2Array = PackedVector2Array()


func get_flow_dir_at(cell: Vector2i) -> Vector2:
	if flow_path.size() < 2:
		return Vector2.ZERO
	var p = Vector2(cell)
	var best_dir = Vector2.ZERO
	var best_d2 = INF
	for i in flow_path.size() - 1:
		var a = flow_path[i]
		var b = flow_path[i + 1]
		var ab = b - a
		var len2 = ab.length_squared()
		if len2 <= 0.0001:
			continue
		var t = clamp((p - a).dot(ab) / len2, 0.0, 1.0)
		var proj = a + ab * t
		var d2 = p.distance_squared_to(proj)
		if d2 < best_d2:
			best_d2 = d2
			best_dir = ab.normalized()
	return best_dir


func get_phase_at(cell: Vector2i) -> float:
	# Distance along the path (in cells) from the start to the projection of `cell`.
	if flow_path.size() < 2:
		return 0.0
	var p = Vector2(cell)
	var best_d2 = INF
	var best_along = 0.0
	var accum = 0.0
	for i in flow_path.size() - 1:
		var a = flow_path[i]
		var b = flow_path[i + 1]
		var ab = b - a
		var seg_len = ab.length()
		if seg_len <= 0.0001:
			continue
		var t = clamp((p - a).dot(ab) / (seg_len * seg_len), 0.0, 1.0)
		var proj = a + ab * t
		var d2 = p.distance_squared_to(proj)
		if d2 < best_d2:
			best_d2 = d2
			best_along = accum + seg_len * t
		accum += seg_len
	return best_along
