# Objectives
## Isometric Renderer
- An Isometric renderer that uses a 2d grid as its reference.
- Each grid space contains metadata that will be useful down the road. Examples: sprite index, height, type (ground/water), selected, highlight, ...
- The world will be sorted based on this map
- The world can be rotated by 90 degrees
- Water tiles will need to raise and lower

## Isometric editor
- Provide a tool that can switch between two views: 2d grid painter and an isometric preview
- The grid will grow and expand as you paint withs numbers
- Various tools will let you set height, increase brush size, and flatten height (maybe)
- The paint brushes will come in two types: height and 'color'. Color is simply the index from a sprite sheet


## API
- Expose metadata to be used to place foliage at a later time
- Expose metadata to support a fishing game