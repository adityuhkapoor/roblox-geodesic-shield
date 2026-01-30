# Roblox Geodesic Shield System

A fully customizable geodesic dome shield system for Roblox with seamless looking triangles, animated spawn patterns, and an in-game playground UI. 
Not super optimal if your goal is a detailed looking shield however, as there's a pretty clear tradeoff between amount of detail and speed

![Shield Demo](assets/shield-demo.gif)


## Features

- **Seamless triangles** using UnionAsync
- **10 shape types**: dome, full sphere, front/back/left/right shields, and more
- **20 spawn patterns**: spiral, diagonal, rings, waves, random, etc.
- **Full customization**: colors, transparency, thickness, glow
- **Per-triangle HP system** with damage/repair mechanics
- **In-game playground** with live sliders and presets
- **Follows player** automatically



## Installation

### 1. Create RemoteEvent
In `ReplicatedStorage`, create a **RemoteEvent** named `ShieldRemote`

### 2. Add Server Script
Create a **Script** in `ServerScriptService` named `ShieldServer`
Copy contents from `src/ShieldServer.lua`

### 3. Add Client Script
Create a **LocalScript** in `StarterPlayerScripts` named `ShieldClient`
Copy contents from `src/ShieldClient.lua`

### Structure
```
game
├── ReplicatedStorage
│   └── ShieldRemote (RemoteEvent)
├── ServerScriptService
│   └── ShieldServer (Script)
└── StarterPlayer
    └── StarterPlayerScripts
        └── ShieldClient (LocalScript)
```

## Controls

| Key | Action |
|-----|--------|
| `INSERT` | Toggle playground panel |
| `Q` | Create shield |
| `C` | Destroy shield |
| `R` | Rebuild with current settings |
| `[` / `]` | Change shape type |
| `;` / `'` | Change spawn pattern |
| `T` | Damage hovered triangle |
| `Y` | Heal hovered triangle |

## Shape Types

| Shape | Description |
|-------|-------------|
| `dome_top` | Upper half dome |
| `dome_bottom` | Lower half dome |
| `full` | Complete sphere |
| `front` | Front-facing shield |
| `back` | Back-facing shield |
| `left` / `right` | Side shields |
| `quarter_front_top` | Front-top quarter |
| `band` | Horizontal ring |
| `cap` | Top cap only |

## Spawn Patterns

- **Directional:** `bottom_to_top`, `top_to_bottom`, `left_to_right`, `right_to_left`, `front_to_back`, `back_to_front`
- **Radial:** `center_out`, `outside_in`
- **Diagonal:** `diagonal_bl_tr`, `diagonal_tr_bl`, `diagonal_br_tl`, `diagonal_tl_br`
- **Spiral:** `spiral_cw`, `spiral_ccw`
- **Ring:** `ring_top_down`, `ring_bottom_up`
- **Special:** `wave_horizontal`, `checkerboard`, `random`

## Configuration Options

### Size & Shape
- `radius` (3-25): Shield size
- `subdivisionLevel` (0-3): Triangle density
- `cutoffY` (-1 to 1): Shape cutoff
- `offsetY`, `offsetZ`: Position offset

### Triangles
- `showTriangles`: Toggle visibility
- `triangleThickness`: Face thickness
- `triangleTransparency`: 0 (solid) to 0.95 (invisible)
- `triangleR/G/B`: Color (0-255)
- `glowMaterial`: Glass vs Neon

### Edges
- `showEdges`: Toggle visibility
- `edgeThickness`: Line thickness
- `edgeTransparency`: Edge visibility
- `edgeR/G/B`: Color (0-255)

### Vertices
- `showVertices`: Toggle corner nodes
- `vertexSize`: Node size

### Spawn Animation
- `spawnDelay` (0-0.2): Time between batches
- `spawnBatch` (1-20): Triangles per batch

## How It Works

### Geodesic Geometry
1. Start with an **icosahedron** (20 triangles)
2. **Subdivide** each triangle into 4 smaller triangles
3. **Project** all vertices onto a sphere
4. **Filter** triangles based on shape type
5. **Sort** triangles based on spawn pattern

### Seamless Triangles
Each triangle is created using two WedgeParts that are merged with `UnionAsync()` to create a single seamless part. This runs on the server because UnionAsync doesn't work in LocalScripts.

### Golden Ratio
The icosahedron vertices use the golden ratio (φ = 1.618...) for mathematically perfect proportions.

## License

MIT License - Feel free to use in your games!

## To-Do

Ideas for improvements:
- [ ] Sound effects
- [ ] Particle effects on damage
- [ ] Shield break animation
- [ ] More spawn patterns
- [ ] Multiplayer sync optimization

## Credits

- Triangle drawing method based on [EgoMoose's 3D Triangles](https://github.com/EgoMoose/Articles/blob/master/3d%20triangles/3D%20triangles.md)
- Geodesic math based on icosahedron subdivision
