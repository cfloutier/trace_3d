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
- MeshDistribution.pde: Meshes mode data+UI and Grid/Tube routing.
- GridDistribution.pde: Grid mode generation.
- TubeDistribution.pde: random Tube mode generation.
- DataGlobal.pde: aggregates the data chapters.
- DataGUI.pde: tab GUI + mouse interactions.
- DataOcclusion.pde: HLR parameters + Occlusion UI.
- DataFacePattern.pde: parameters + UI for the face hatching pattern (Pattern tab).
- xlib3d_Mesh.pde: Mesh abstraction + projected primitives (EdgeProjected, OccluderBox).
- xlib3d_Box3D.pde: box-to-edges/faces decomposition (EDGE_IDX, FACE_IDX,
  EDGE_TO_FACES/FACE_TO_EDGES), ray-box intersection (OBB, slab method).
- xlib3d_BVH3D.pde: generic BVH (spatial broad-phase) for "any-hit" ray queries and AABB overlap queries.
- xlib3d_BoxIntersection.pde: computes seam edges between overlapping boxes.
- xlib3d_FacePattern.pde: geometric generation of hatching lines on a box face.
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

Pattern tab (only useful when Occlusion.enabled): adds vertical hatching lines on
the visible faces of the Box3D meshes, reusing the HLR pipeline.

How it works (2nd pass, after normal occlusion):
1. During the 1st pass (box edges), any edge that produces at least one actually
   visible segment is recorded (edgeHasVisibleSegment).
2. At the end of that pass, a face is considered visible if at least 2 of its 4
   bordering edges were recorded this way (a single edge graze isn't enough).
3. For each visible face belonging to an active group (sides / top / bottom),
   vertical lines are centered on a random point on the face's surface (random
   along the face's horizontal axis AND its own vertical axis — not the screen
   vertical) and extend from that point both up and down, by a random length
   (line_length_min + a random value in [0, line_length_random]); if a line would
   overflow the top or bottom of the face, it is clipped to the face's boundary
   (so it ends up shorter than intended for a point drawn near an edge). Everything
   then goes through the same visibility ray-casting as the normal edges.

Partial recompute: changing only a Pattern parameter does not re-run the
(expensive) edge/seam occlusion pass — only the pattern lines are regenerated, as
long as Meshes/Camera/Occlusion haven't changed in the meantime.

### Shading

Optional, computed in `LineBuilder.appendFacePatternEdges()` before calling
`generateFacePatternWorldEdges()` — the generator itself stays unaware shading
exists, so any future pattern type can reuse the same step. Implemented in
`xlib3d_Shading.pde` (pure math) and `Shading.pde` (`ShadingData`/`ShadingGUI`,
composed into `DataFacePattern`/`FacePatternGUI` the same way Grid/Tube are
composed into `DataBoxes`/`BoxesGUI`):

```
lightDir   = computeLightDirection(light_yaw, light_pitch)   // same yaw/pitch
                                                               // convention as
                                                               // CameraData
brightness = clamp(dot(faceNormal, lightDir) * power, 0, 1)  // Lambertian, power = light intensity
multiplier = clamp(1 - brightness, 0, 1)
effectiveLinesPerFace = round(lines_per_face * multiplier)
```

No separate density-strength slider: `power` (how bright the light gets) and
`lines_per_face` (the base count it scales down from) already give enough
control over how strong the effect looks.

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
