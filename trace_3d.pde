import controlP5.*;
import processing.pdf.*;
import processing.dxf.*;
import processing.svg.*;

BoxGridData data;
DataGUI dataGui;

PGraphics current_graphics;
ControlP5 cp5;
ColorChooserPopup colorPopup;

ArrayList<Mesh> meshList = new ArrayList<Mesh>();
int meshListVersion = 0;
PolylineGroup lineGroup = new PolylineGroup();
LineBuilder lineBuilder;
NativePreview3D preview3D = new NativePreview3D();

float hud_last_lines_gen_ms = 0;
float hud_last_render_ms = 0;

void setup()
{
  size(1200, 800, P3D);
  pixelDensity(1);
  surface.setResizable(true);

  data = new BoxGridData();
  dataGui = new DataGUI(data);

  setupControls();

  data.LoadSettings("./Settings/default.json");
  dataGui.setGUIValues();
  lineBuilder = new LineBuilder(data);
  buildBoxes();
  lineBuilder.requestBuild(meshList, lineGroup);
  if (!lineBuilder.isBusy())
    hud_last_lines_gen_ms = lineBuilder.getElapsedMs();

  file_ui.export_group = lineGroup;  // enable direct SVG export
  file_ui.export_busy_guard = new ExportBusyGuard() {
    boolean isBusy() { return lineBuilder.isOcclusionBuilding(); }
  };
}

void setupControls()
{
  // Drawn manually at the end of draw() instead (see drawControlP5()): auto-draw fires via
  // a registerMethod("draw", ...) callback whose exact GL state at invocation we don't
  // fully control, which is why hint(DISABLE_DEPTH_TEST) set earlier in our own draw()
  // wasn't reliably still in effect by the time it actually rendered. Same reasoning for
  // the color-chooser popup's own gradient rendering - init_xlib(false) skips its
  // registerMethod("draw", colorPopup) too, drawn manually in drawControlP5() instead.
  init_xlib(false);
  cp5.setAutoDraw(false);
  dataGui.Init();
}

void draw()
{
  start_draw();

  boolean boxes_changed = data.boxes.changed;
  boolean camera_changed = data.camera.changed;
  boolean occlusion_changed = data.occlusion.changed;
  boolean facepattern_changed = data.facepattern.changed;
  boolean page_changed   = data.page.changed;
  boolean debug_changed  = data.debug.changed;

  // if (occlusion_changed)
  // {
  //   println("[Occlusion] enabled=" + data.occlusion.enabled +
  //     " sample_step_px=" + nf(data.occlusion.sample_step_px, 1, 2) +
  //     " bisection_iterations=" + data.occlusion.bisection_iterations +
  //     " self_occlusion_eps_scale=" + nf(data.occlusion.self_occlusion_eps_scale, 1, 6));
  // }

  if (boxes_changed)
    buildBoxes();

  // stop_compute is set around Save/Save As/Load (see xLib_FileUI.pde) precisely to keep
  // a save/load cycle from kicking off an unwanted rebuild (previously declared but never
  // actually read anywhere).
  if (!stop_compute)
  {
    if (boxes_changed || camera_changed || occlusion_changed)
      lineBuilder.requestBuild(meshList, lineGroup);
    else if (facepattern_changed)
      lineBuilder.requestPatternOnlyRebuild();
    // show_edges/show_patterns only decide what mergeIntoFinalGroup() includes from
    // the already-computed edgeGroup/patternGroup - no geometry/occlusion recompute
    // needed, just re-merge so the toggle takes effect this frame instead of waiting
    // for the next unrelated rebuild (e.g. moving the camera). show_face_debug isn't
    // part of this - draw() reads it directly every frame, already instant.
    else if (debug_changed && !lineBuilder.isBusy())
      lineBuilder.mergeIntoFinalGroup();

    if (!lineBuilder.isBusy())
      hud_last_lines_gen_ms = lineBuilder.getElapsedMs();
  }

  if (lineBuilder.update(0.2f))
    hud_last_lines_gen_ms = lineBuilder.getElapsedMs();

  if (boxes_changed || camera_changed || occlusion_changed || facepattern_changed || page_changed)
    file_ui.updateExportScale(lineBuilder.getDisplayBoundingBox(data.page.clipping, data.page.clip_width, data.page.clip_height));

  dataGui.update_ui();
  data.reset_all_changes();

  // Debug: draw clipping rect border
  //if (data.page.clipping) {
  //  current_graphics.noFill();
  //  current_graphics.stroke(data.style.lineColor);
  //  current_graphics.rect(-data.page.clip_width / 2, -data.page.clip_height / 2,
  //                         data.page.clip_width, data.page.clip_height);
  //}

  long render_start_ns = System.nanoTime();
  lineBuilder.draw(data.page.clipping, data.page.clip_width, data.page.clip_height);

  end_draw();
  hud_last_render_ms = (System.nanoTime() - render_start_ns) / 1000000.0;

  dataGui.draw();
  drawHud();
  drawClippingWarning();
  drawControlP5();
}

// Drawn manually (autoDraw disabled in setupControls()) with the depth test forced off
// immediately beforehand, nothing else running in between: Processing resets P3D's depth
// test to enabled at the start of every frame, and the 2D line content + GUI are both
// effectively at z=0, so without this the GUI (drawn last) loses the depth test wherever
// a line was already drawn there, which reads as the GUI "showing through" the lines.
void drawControlP5()
{
  hint(DISABLE_DEPTH_TEST);
  hint(DISABLE_DEPTH_MASK);
  cp5.draw();
  colorPopup.draw();
  hint(ENABLE_DEPTH_TEST);
  hint(ENABLE_DEPTH_MASK);
}

void drawHud()
{
  if (_record)
    return;

  String hud_text = "Lines: " + lineBuilder.getDisplayLineCount()
    + (lineBuilder.isOcclusionBuilding() ? " | Occlusion: " + lineBuilder.getStatusText() : "")
    + " | Lines gen: " + nf(hud_last_lines_gen_ms, 1, 2) + " ms";

  hud_text += " | Render: " + nf(hud_last_render_ms, 1, 2) + " ms";

  if (lineBuilder.isOcclusionBuilding())
    hud_text += " | preview";

  pushStyle();
  textAlign(LEFT, BOTTOM);
  textSize(13);

  float padding = 10;
  float tw = textWidth(hud_text);
  float th = textAscent() + textDescent();
  float x = padding;
  float y = height - padding;

  noStroke();
  fill(0, 150);
  rect(x - 6, y - th - 6, tw + 12, th + 10, 4);

  fill(255);
  text(hud_text, x, y);
  popStyle();
}

// Clipping (Page tab) isn't just a display crop here - the export-scale auto-fit
// (updateExportScale, via getDisplayBoundingBox) relies on it to keep the bounding box
// sane. Without it, a handful of numerically-unstable near-camera points can still blow
// up the fit and leave nothing visible, and there's no defined page aspect ratio for the
// camera to target. Not worth chasing further (clip_width/clip_height/clipping are shared
// DataPage fields used by several other, mostly 2D, projects - not something to rework
// here) - just make the unsupported state obvious instead.
void drawClippingWarning()
{
  if (_record)
    return;

  if (data.page.clipping)
    return;

  pushStyle();
  textAlign(CENTER, CENTER);
  textSize(28);
  fill(255, 40, 40);
  text("CLIPPING DESACTIVE - resultat non garanti", width / 2, height / 2);
  popStyle();
}

void buildBoxes()
{
  data.boxes.createMeshes(meshList);
  meshListVersion++;
}
