@tool
extends Resource
class_name DetailType

## Defines a single detail type (tree, rock, bush, etc.)
## Anchored to one cell, sprite can overflow upward.

@export var name: String = "Detail"
@export var editor_color: Color = Color.WHITE        # color shown in 2D grid painter
@export var editor_label: String = "?"               # single char shown on grid

## Rendering — use ONE of these approaches:
## 1. Single sprite
@export var sprite: Texture2D
## 2. Region in a shared spritesheet
@export var sprite_region: Rect2 = Rect2()

## Offset from cell base. Useful for anchoring.
@export var offset: Vector2 = Vector2.ZERO

## How tall this detail is, in height_step units.
## Used to decide which nearby cells it can shade (won't shade cells above its top).
@export var height: int = 0

## Shade footprint — this detail darkens its own cell and nearby cells.
## -1 = no shade at all
##  0 = only the cell under the detail
##  1 = 3x3 area around the detail, 2 = 5x5, etc.
@export var shade_radius: int = -1
## 0.0 = no darkening, 1.0 = full black at center.
@export var shade_strength: float = 0.0
