@tool
extends Resource
class_name TerrainType

## Defines a single terrain type (grass, water, sand, etc.)
## Can render as a single sprite or a region in a spritesheet.

@export var name: String = "Terrain"
@export var editor_color: Color = Color.WHITE        # color shown in 2D grid painter
@export var side_color: Color = Color.GRAY           # fallback side wall color
@export var is_water: bool = false                    # enables bobbing, click detection

## Rendering — use ONE of these approaches:
## 1. Single sprite per tile type
@export var sprite: Texture2D
## 2. Region in a shared spritesheet (set sprite to the sheet, region to the frame rect)
@export var sprite_region: Rect2 = Rect2()           # (0,0,0,0) means use full sprite
