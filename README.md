# trace_3d

Processing sketch that generates a field of Box3D meshes projected to 2D (wireframe), with an orbital camera, Ortho/Perspective projection, analytical HLR (ray-casting + BVH), and direct SVG export.

## Getting a Release

No Processing, Java, or ControlP5 installation is required to run a release build — everything needed is bundled in the zip.

1. Download the release zip (see `releases/` or wherever it was shared with you).
2. Unzip it anywhere.
3. Run the `.exe` inside — that's it.

## Purpose

- Produce clean 2D traces from a simple 3D scene.
- Keep interaction smooth with a large number of meshes.
- Provide reliable vector export (display and export stay consistent).

## Quick Start

1. Open trace_3d.pde in Processing.
2. Run the sketch.
3. Adjust parameters via the tabs:
- Meshes
- Camera
- Occlusion
- Pattern
- Style
- Files

On startup, values are loaded from Settings/default.json.

## User Interaction

- Left-click drag: moves the target on the horizontal plane (Y unchanged), in the
  camera's current view direction flattened onto that plane (mouse Y axis inverted:
  you move "forward" when dragging the mouse down). Independent of pitch, so it
  still works in a steep top-down view.
- Shift + left-click drag: classic pan in the camera's screen plane (moves the
  target along the camera's right/up axes).
- Right-click drag: orbits the camera around the target (yaw, pitch).
- Shift + right-click drag: reorients the camera's look direction (yaw, pitch)
  while keeping its world position fixed; the target is recomputed to follow
  (free-look).
- Mouse wheel over the canvas:
- Perspective: affects target_distance.
- Ortho: affects ortho_zoom.
- Camera buttons: Front, Back, Left, Right, Iso, Top, Center (re-centers the target
  on the world origin).

Important: camera interactions are disabled while the mouse is over the GUI.

## Meshes Parameters

The Meshes tab drives the Box3D distribution through an active mode:
- distribution_mode: Grid or Tube.
- random_seed: global seed shared by all distributions (the "Seed" button draws a new random one).

### Grid Mode

| Parameter | Role |
|-----------|------|
| `count_x` / `count_z` | Number of boxes along each grid axis |
| `spacing` | Distance between adjacent boxes |
| `box_size` | Base size (X/Z) of each box |
| `random_size` | Additional random variation on `box_size` (0 to this value) |
| `box_height` | Base height of the boxes |
| `height_mode` | Height variation mode: Fixed / White Noise / Perlin Noise / Distance |
| `random_h` | Additional random height (0 to this value), applied according to `height_mode` |
| `perlin_zoom` | Perlin noise scale (Perlin Noise mode only) |
| `distance_bias` | Weight for Distance mode: positive = taller boxes at the center, negative = taller at the edges, 0 = uniform |
| `rotation_y` | Base rotation of the boxes around the Y axis (degrees) |
| `random_rotation_y` | Additional random rotation (+/- this value) |

### Tube Mode (random)

| Parameter | Role |
|-----------|------|
| `box_count` | Base number of boxes |
| `box_multiplier` | Multiplier applied to `box_count` (total count = box_count x box_multiplier) |
| `radius_min` / `radius_max` | Range of box distance from the central axis |
| `base_y_min` / `base_y_max` | Range of box base height |
| `box_size` | X/Z cross-section of the boxes |
| `box_length_min` / `box_length_max` | Range of box length (Y height) |

3D geometry is cached in meshList and only rebuilt when Meshes changes.

## Camera

The Camera tab drives projection and viewpoint.

| Parameter | Role |
|-----------|------|
| `projection_mode` | Ortho or Perspective |
| `fov` | Field of view in Perspective mode |
| `target_distance` | Camera-target distance (orbit radius), also controlled via the mouse wheel in Perspective |
| `ortho_zoom` | Zoom in Ortho mode, also controlled via the mouse wheel |
| `yaw` / `pitch` | Camera orientation around the target |
| `target_x` / `target_y` / `target_z` | Target position in world space |

See also [User Interaction](#user-interaction) for mouse controls and the quick-view buttons (Front/Back/Left/Right/Iso/Top/Center).

## Occlusion (HLR)

When Occlusion.enabled is active, rendering goes through an analytical HLR (Hidden
Line Removal) pass: each box edge is ray-cast against the other boxes in the scene
to determine exactly which portions are visible, rather than a simple approximate
depth test.

| Parameter | Role |
|-----------|------|
| `enabled` | Enables/disables the HLR computation |
| `sample_step_px` | Edge sampling step in screen space |
| `bisection_iterations` | Number of bisection iterations used to refine a visibility cutoff point |
| `self_occlusion_eps_scale` | Factor (x box diagonal) for the anti self-occlusion epsilon |
| `seam_edges_enabled` | Adds "seam" edges at intersection areas between boxes (off by default, can be costly on very dense scenes) |

For the algorithm details (ray-casting, BVH, bisection, seam edges), see [DEVELOPMENT.md](DEVELOPMENT.md).

## Face Pattern

Pattern tab (only useful when Occlusion.enabled): adds vertical hatching lines on
the visible faces of the Box3D meshes.

| Parameter | Role |
|-----------|------|
| `enabled` | Enables/disables the pattern |
| `lines_per_face` | Number of lines generated per visible face (can go high, e.g. 200-300, depending on desired density) |
| `line_length_min` | Minimum line length |
| `line_length_random` | Additional random length (0 to this value), added to `line_length_min` |
| `vertical_bias` | Biases the vertical position of the lines' center point on the face (negative = toward the bottom, 0 = even distribution, positive = toward the top) |
| `apply_sides` / `apply_top` / `apply_bottom` | Which face groups are affected (sides on by default; top/bottom off by default) |
| `seed` | Dedicated seed for the pattern, independent of `random_seed` (Meshes) — lets you reroll the lines without changing the box layout (the "Seed" button draws a new one) |

For the algorithm details (2nd ray-casting pass), see [DEVELOPMENT.md](DEVELOPMENT.md).

## Style

The Style tab controls the rendering appearance.

| Parameter | Role |
|-----------|------|
| `lineWidth` | Width of the drawn lines |
| `lineColor` | Line color |
| `backgroundColor` | Background color |

## Files & Export

The Files tab groups settings load/save, clipping, and export.

### Load / Save

Load and "Save as..." open a built-in file browser (no system window) that
navigates the project's `Settings/` folder, including its sub-folders: clicking a
file loads it (Load) or offers to overwrite it after confirmation (Save as...),
clicking a folder navigates into it, ".." goes up one level. In Save as..., a new
name can also be typed into a text field to create a file in the currently
displayed folder. A Cancel button lets you back out without doing anything at any
point.

The "Save" button (next to "Save as...") directly overwrites the currently loaded
file, without going through this browser.

### Clipping

- `Clip`: enables/disables the clipping rectangle.
- `Clip width` / `Clip height`: dimensions of the rectangle.
- `Clip Ratio`: locks the rectangle to a fixed proportion — None (free), A4, 16:9,
  4:3, Raisin, or 1:1 (square). Moving either slider then recomputes the other
  automatically.
- `Landscape`: flips the orientation of the chosen ratio (long side horizontal or
  vertical).

### Export

- `Export Page size`: page format for export (None, A4, A3, A2, Raisin).
- `Margins`: margin around the exported drawing (0, 1, 2, or 3 cm).
- `Export SVG`: vector export via a custom writer (recommended, more reliable for
  the plotter) that applies clipping in drawing space then centers and sizes the
  export consistently with the display.

For architecture details, persisted settings, and the build procedure, see [DEVELOPMENT.md](DEVELOPMENT.md).

---

## Changelog

### 2026-08-19 — xLib 3.13.4
- **File picker**: Load/Save as... now use a built-in file browser (folders + files under `Settings/`) instead of the system dialog, which could open behind the main window on this sketch (P3D/JOGL renderer).
- **Clip Ratio**: the clipping rectangle can be locked to a fixed proportion (None, A4, 16:9, 4:3, Raisin, 1:1), with a Landscape button to flip orientation.
- **Build**: added `export_app.ps1` to produce a standalone application requiring no install for end users.
- **Docs**: split into `README.md` (usage) and `DEVELOPMENT.md` (algorithms, architecture, build); Meshes (Grid/Tube), Camera, Style, and Files/Export parameters now documented in full (previously missing or incomplete).
