import controlP5.*;
import processing.pdf.*;
import processing.dxf.*;
import processing.svg.*;

BoxGridData data;
DataGUI dataGui;

PGraphics current_graphics;
ControlP5 cp5;

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
}

void setupControls()
{
  cp5 = new ControlP5(this);
  cp5.getTab("default").setLabel("Hide GUI");
  dataGui.Init();
}

void draw()
{
  start_draw();

  boolean boxes_changed = data.boxes.changed;
  boolean camera_changed = data.camera.changed;
  boolean occlusion_changed = data.occlusion.changed;
  boolean page_changed   = data.page.changed;

  // if (occlusion_changed)
  // {
  //   println("[Occlusion] enabled=" + data.occlusion.enabled +
  //     " sample_step_px=" + nf(data.occlusion.sample_step_px, 1, 2) +
  //     " bisection_iterations=" + data.occlusion.bisection_iterations +
  //     " self_occlusion_eps_scale=" + nf(data.occlusion.self_occlusion_eps_scale, 1, 6) +
  //     " min_visible_segment_px=" + nf(data.occlusion.min_visible_segment_px, 1, 2));
  // }

  if (boxes_changed)
    buildBoxes();

  if (boxes_changed || camera_changed || occlusion_changed)
  {
    lineBuilder.requestBuild(meshList, lineGroup);
    if (!lineBuilder.isBusy())
      hud_last_lines_gen_ms = lineBuilder.getElapsedMs();
  }

  if (lineBuilder.update(0.2f))
    hud_last_lines_gen_ms = lineBuilder.getElapsedMs();

  if (boxes_changed || camera_changed || occlusion_changed || page_changed)
    file_ui.updateExportScale(lineBuilder.getDisplayBoundingBox(data.page.clipping, data.page.clip_width, data.page.clip_height));

  dataGui.update_ui();
  data.reset_all_changes();

  // Debug: draw clipping rect border
  //if (data.page.clipping) {
  //  current_graphics.noFill();
  //  current_graphics.stroke(data.style.lineColor.col);
  //  current_graphics.rect(-data.page.clip_width / 2, -data.page.clip_height / 2,
  //                         data.page.clip_width, data.page.clip_height);
  //}

  long render_start_ns = System.nanoTime();
  lineBuilder.draw(data.page.clipping, data.page.clip_width, data.page.clip_height);

  end_draw();
  hud_last_render_ms = (System.nanoTime() - render_start_ns) / 1000000.0;

  dataGui.draw();
  drawHud();
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

void buildBoxes()
{
  data.boxes.createMeshes(meshList);
  meshListVersion++;
}
