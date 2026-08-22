# trace_3d — Development

Implementation notes, architecture, and build procedure for `trace_3d`. For usage and parameters, see [README.md](README.md).

---

## Development Setup

Only needed to open/edit/run the sketch from source — not needed to just run a release build (see [README.md](README.md#getting-a-release)).

1. **Install Processing**: download from https://processing.org/download and install (Java Mode, the default one).
2. **Install ControlP5**: in the Processing IDE, go to `Sketch > Import Library... > Manage Libraries...`, search for **ControlP5**, and click Install. This puts it straight into your sketchbook's `libraries/` folder — no manual download/unzip needed. (Library home page, for reference: http://www.sojamo.de/libraries/controlP5)
3. Open `trace_3d.pde` in Processing and press Run.

---

## Architecture

Main files:
- trace_3d.pde: main loop, recompute/render orchestration.
- LineBuilder.pde: 2D line generation (normal + occlusion).
- mesh.pde: Meshes mode data+UI and Grid/Tube routing.
- mesh_grid.pde: Grid mode generation.
- mesh_tube.pde: random Tube mode generation.
- DataGlobal.pde: aggregates the data chapters.
- DataGUI.pde: tab GUI + mouse interactions.
- DataOcclusion.pde: HLR parameters + Occlusion UI.
- pattern.pde: `PatternTypeData` base, pattern-type routing data+UI (Pattern tab).
- pattern_random_lines.pde: data+UI for the Random Lines pattern type.
- pattern_hachures.pde: data+UI for the Hachures pattern type.
- pattern_shading.pde: data+UI for the optional pattern shading (light direction/power).
- xlib3d_Mesh.pde: Mesh abstraction + projected primitives (EdgeProjected, OccluderBox).
- xlib3d_Box3D.pde: box-to-edges/faces decomposition (EDGE_IDX, FACE_IDX,
  EDGE_TO_FACES/FACE_TO_EDGES), ray-box intersection (OBB, slab method), face normals.
- xlib3d_BVH3D.pde: generic BVH (spatial broad-phase) for "any-hit" ray queries and AABB overlap queries.
- xlib3d_BoxIntersection.pde: computes seam edges between overlapping boxes.
- xlib3d_FacePattern.pde: geometric generation for each pattern type (Random Lines, Hachures) on a box face.
- xlib3d_Shading.pde: pure math for light direction/brightness/density-multiplier.
- xlib3d_Camera3D.pde / xlib3d_CameraData.pde: camera projection + UI + screen->world deprojection.

Working objects:
- meshList: cache of Mesh instances.
- lineGroup: final displayed/exported 2D geometry (internal merge of edgeGroup and
  patternGroup in LineBuilder — see below).

Recompute rule:
- Meshes / Camera / Occlusion change: full rebuild (edges + seams + occlusion,
  then pattern if active).
- Pattern alone changes (Meshes/Camera/Occlusion unchanged): partial rebuild, only
  the pattern lines are regenerated (LineBuilder.requestPatternOnlyRebuild).

---

## Occlusion (HLR) — algorithm

When Occlusion.enabled is active, rendering goes through an analytical HLR pass (object-space ray-casting, not rasterization):
1. Collection: for each Box3D, an occluder (world bbox + center + diagonal) and its 12 projected edges (screen coordinates + world coordinates).
2. A BVH (xlib3d_BVH3D) is built over the occluders; it is only rebuilt when the box list changes (not on a simple camera drag).
3. Emission: each edge is sampled in screen space (same parametrization as before, correct in perspective via 1/z). At each sample, the point is deprojected to 3D and a ray is cast toward the camera against the BVH to test exact visibility (closed ray-box intersection, handles rotation). On a visibility change between two samples, a bisection refines the exact cutoff point (instead of snapping it to the sampling grid).
4. Self-occlusion: the ray origin is biased outward from the box that owns the edge, with an epsilon proportional to that box's diagonal; a specific threshold prevents a silhouette edge from mistakenly self-occluding, while still letting real self-occlusion (back face) work normally.

Notes:
- In perspective, edge depth is sampled with 1/z interpolation (more stable on long lines), then deprojected to 3D for ray-casting.
- With clipping active, samples outside the clip rectangle are treated as not visible.
- Occluders are Box3D instances (potentially rotated, OBB) — the ray-box test is exact (slab method in local space), not an approximation.

### Seam edges (box-box intersections)

When Occlusion.seam_edges_enabled is active, for each pair of overlapping boxes
(found via BVH3D.queryOverlaps, broad-phase AABB), xlib3d_BoxIntersection computes
the segments where a face of one crosses a face of the other (plane intersection +
double rectangular clipping) and adds them as extra edges. A seam edge visually
belongs to both boxes at once (EdgeProjected carries a second, optional owner
index), so both benefit from the tolerant self-occlusion threshold. The
computation is purely geometric (camera-independent) and is therefore only redone
when box geometry changes, never on a simple camera drag — but it can still be
costly on scenes with many overlaps, hence the option being off by default.

---

## Face Pattern — algorithm

Pattern tab (only useful when Occlusion.enabled): draws marks on the visible
faces of the Box3D meshes, reusing the HLR pipeline. Multiple pattern *types*
are supported (Random Lines, Hachures today), composed exactly the way
Grid/Tube are composed into `DataBoxes`/`BoxesGUI`
(`mesh.pde`/`mesh_grid.pde`/`mesh_tube.pde`):
`DataFacePattern` (`pattern.pde`) owns a `PatternTypeData` subchapter
per type (`RandomLinesData` in `pattern_random_lines.pde`, `HachuresData` in
`pattern_hachures.pde`) plus an `int pattern_type` selecting which one is active, and
dispatches to it via `DataFacePattern.generateWorldEdges()`. `FacePatternGUI`
mirrors this with a `pattern_type` radio and one `*GUI` per type, shown/hidden
by `updatePatternTypeVisibility()` (same idiom as
`BoxesGUI.updateDistributionVisibility()`).

Visibility pipeline (2nd pass, after normal occlusion), shared by every
pattern type:
1. During the 1st pass (box edges), any edge that produces at least one actually
   visible segment is recorded (edgeHasVisibleSegment).
2. At the end of that pass, a face is considered visible if at least 2 of its 4
   bordering edges were recorded this way (a single edge graze isn't enough).
3. For each visible face belonging to an active group (sides / top / bottom),
   `LineBuilder.appendFacePatternEdges()` computes the shading multiplier (see
   below) and calls `DataFacePattern.generateWorldEdges()`, which delegates to
   the active type's own generator in `xlib3d_FacePattern.pde`. The resulting
   segments go through the same visibility ray-casting as the normal edges.

Partial recompute: changing only a Pattern parameter does not re-run the
(expensive) edge/seam occlusion pass — only the pattern lines are regenerated, as
long as Meshes/Camera/Occlusion haven't changed in the meantime.

### Per-face local basis and rect clipping

Both generators work in a face's own local 2D basis: `acrossDir`/`acrossLen`
(the face's local "horizontal" axis) and `spanDir`/`spanLen` (its local
"vertical" axis, `FACE_VERTICAL_IS_V`, always bottom→top) — derived from the
face's own (already-rotated) edge vectors, same as before. A candidate segment
is built in this local (s,t) space and clipped to the face rectangle via the
**shared** `clipLineToCenteredRect()` (`xLib_ClippingUtils.pde`, already used
by spiral/image_processor/perlin_mountains for page clipping), called with
`centerX=acrossLen/2, centerY=spanLen/2, clipWidth=acrossLen, clipHeight=spanLen`
— then mapped back to world via `localToWorld(c0, acrossDir, spanDir, s, t)`.
Reusing this instead of a manual per-axis clamp is what makes an arbitrary
`orientation` tractable: the clip handles any angle correctly, and at
`orientation=0` it reduces to exactly the old 1D vertical-extent clamp.

### Random Lines (`pattern_random_lines.pde` + `generateRandomLinesWorldEdges()`)

For each of `lines_per_face` (scaled by the shading multiplier) lines: a
center point is drawn uniform across `acrossDir` and biased along `spanDir`
per `vertical_bias` (power-law skew on a uniform draw, always via an
exponent ≤ 1 so both bias directions concentrate equally strongly — mirrored
for negative bias rather than using an exponent > 1 directly, which left a
visibly loose "leftover" fraction of lines near the opposite end). A segment
of length `line_length_min + random(0, line_length_random)` is then grown from
that center along `orientation` degrees from `spanDir` (0 = vertical, 90 =
horizontal) and clipped to the face.

### Hachures (`pattern_hachures.pde` + `generateHachuresWorldEdges()`)

Fully deterministic, no per-line randomness. Projects the face rectangle's 4
corners onto the axis perpendicular to the line direction to find the offset
range needed to cover the whole face, then steps through that range by the
(shading-adjusted) spacing, each step producing an over-long segment through
the rectangle at that offset, clipped to the face by the same shared helper —
so exact coverage at any angle falls out of the clip, with no separate
per-angle geometry needed.

**Foreshortening compensation** (`foreshortening_compensation`, Hachures
only): a uniform world-space spacing doesn't stay uniform on screen — a face
seen at a steep/grazing angle compresses that spacing far more than a face
seen head-on, since the spacing is measured along the local perpendicular
axis, and that axis's world direction can point anywhere from fully lateral
(no compression) to nearly straight at/away from the camera (spacing
collapses toward zero apparent length). The correction:
```
perpWorld   = the perpendicular axis (depends on orientation), as a world vector
sightDir    = normalize(faceCenter - cameraPos)
alignment   = abs(dot(perpWorld, sightDir))       // 0 = lateral, 1 = aligned with sight line
foreshorten = sqrt(max(0, 1 - alignment^2))        // 1 = no compression, 0 = maximal
effective   = lerp(1, foreshorten, compensation)   // compensation in [0,1], 0 = off
spacing     = spacing / max(0.05, effective)       // widen spacing where compression is worst
```
Depends on `orientation` because that's what determines `perpWorld` - the
same face tilt can need very different compensation (or none) depending on
which way the hachures run across it.

### Shading

Optional, computed once in `LineBuilder.appendFacePatternEdges()` before
dispatching to the active pattern type — the *meaning* of the multiplier (1 =
full base density, 0 = none) is shared, but each type applies it to its own
density parameter itself (that mapping is that type's job, not shading's).
Implemented in `xlib3d_Shading.pde` (pure math) and `pattern_shading.pde`
(`ShadingData`/`ShadingGUI`, composed into `DataFacePattern`/`FacePatternGUI`
the same way the pattern-type subchapters are):

```
lightDir   = computeLightDirection(light_yaw, light_pitch)   // same yaw/pitch
                                                               // convention as
                                                               // CameraData
raw        = max(0, dot(faceNormal, lightDir))                // Lambertian, in [0,1]
shaped     = pow(raw, contrast)                               // gamma: >1 darkens/densifies
                                                               // mid-tones, <1 lightens/
                                                               // sparsens them, 1 = no change
brightness = clamp(shaped * power, 0, 1)                      // power = light intensity,
                                                               // applied AFTER contrast so
                                                               // it can't get stuck at a
                                                               // pre-clamped 1 (see
                                                               // computeFaceBrightness())
multiplier = computeShadingDensityMultiplier(brightness)     // = clamp(1 - brightness, 0, 1)
```
- Random Lines: `effectiveLinesPerFace = round(lines_per_face * multiplier)`.
- Hachures: `effectiveSpacing = line_spacing / multiplier` (spacing grows,
  i.e. sparser, as the multiplier shrinks), or no lines at all once the
  multiplier drops below a small floor (avoids spacing blowing up toward
  infinity).

No separate density-strength slider: `power` (how bright the light gets) and
each type's own density parameter already give enough control over how strong
the effect looks.

`faceNormal` comes from `Box3D.getFaceNormal(faceIndex)`, which cross-products
the face's own (already-rotated) edge vectors and flips the result if needed
so it points away from `getWorldGeometricCenter()` — necessary because
`FACE_IDX`'s vertex winding is not consistently outward across all 6 faces.

---

## Persisted Settings

Main file:
- Settings/default.json

Expected JSON chapters:
- Style
- Page
- Camera
- Boxes
- Occlusion
- FacePattern

If a field is missing, the code's default value is used.

---

## xLib Notes

The project embeds locally-copied xLib_*.pde files. Global xLib changes are managed through the processing_xlib repo's sync workflow.

---

## TODO

- Face pattern (Pattern tab): currently a single generation mode (vertical
  lines). A different texture is planned later specifically for the top/bottom
  faces (currently using the same mode as the sides).
- Known limitation: while the HLR computation is busy, the ControlP5 GUI can
  show visual artifacts (2D lines visible through it, text rendering sometimes
  corrupted) where it overlaps the 3D/2D content. Likely cause: GL state
  interaction between the native 3D rendering (Preview3D) and ControlP5's
  auto-draw, beyond a simple forgotten depth-test/depth-mask hint (already tried,
  insufficient). Once the computation finishes, rendering is correct.
  Deprioritized for now (see Preview3D.pde).

---

## Building a Release

`export_app.ps1` (project root) builds a standalone, installer-free application and packages it as a release zip.

```powershell
.\export_app.ps1
```

This will:
1. Export the sketch as a standalone application via `processing-java --export` (embeds a JRE and all libraries, including ControlP5 — end users install nothing).
2. Copy `Settings/` into the export (the Processing export step does **not** include it, and the sketch crashes on startup without a `Settings/default.json` to load).
3. Zip the result into `releases/trace_3d_<variant>_<date>.zip`, ready to hand out.

Useful options:
```powershell
.\export_app.ps1 -ProcessingPath "D:\tools\processing-4.3\processing-java.exe"  # different Processing install
.\export_app.ps1 -Zip $false                                                    # skip the release zip
```

**Note:** the build always targets the OS you run the script on — `-Variant` does not cross-compile for another platform (verified empirically: requesting `linux-amd64` from Windows still produced a Windows build). To produce a macOS or Linux build, run this script on a machine running that OS.
