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

## Vertical offset from cell base (negative = up). Useful for anchoring.
@export var y_offset: float = 0.0
