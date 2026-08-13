import controlP5.*;

class DataOcclusion extends GenericData
{
  DataOcclusion()
  {
    super("Occlusion");
  }

  boolean enabled = false;

  float sample_step_px = 2.0;
  float min_visible_segment_px = 1.5;
  int bisection_iterations = 10;
  float self_occlusion_eps_scale = 0.0001;

  void LoadJson(JSONObject src)
  {
    if (src == null) return;
    enabled = src.getBoolean("enabled", enabled);
    sample_step_px = src.getFloat("sample_step_px", sample_step_px);
    min_visible_segment_px = src.getFloat("min_visible_segment_px", min_visible_segment_px);
    bisection_iterations = src.getInt("bisection_iterations", bisection_iterations);
    self_occlusion_eps_scale = src.getFloat("self_occlusion_eps_scale", self_occlusion_eps_scale);
  }

  JSONObject SaveJson()
  {
    JSONObject dest = new JSONObject();
    dest.setBoolean("enabled", enabled);
    dest.setFloat("sample_step_px", sample_step_px);
    dest.setFloat("min_visible_segment_px", min_visible_segment_px);
    dest.setInt("bisection_iterations", bisection_iterations);
    dest.setFloat("self_occlusion_eps_scale", self_occlusion_eps_scale);
    return dest;
  }
}


class OcclusionGUI extends GUIPanel
{
  DataOcclusion occlusion;

  Toggle enabled;
  Slider sample_step_px;
  Slider min_visible_segment_px;
  Slider bisection_iterations;
  Slider self_occlusion_eps_scale;

  OcclusionGUI(DataOcclusion occlusion)
  {
    super("Occlusion", occlusion);
    this.occlusion = occlusion;
  }

  void setupControls()
  {
    super.Init();

    enabled = addToggle("enabled", "Enable HLR", occlusion);
    nextLine();

    sample_step_px = addSlider("sample_step_px", "Sample Step px", 0.5, 8.0);
    min_visible_segment_px = addSlider("min_visible_segment_px", "Min Segment px", 0.0, 20.0);
    nextLine();
    bisection_iterations = addIntSlider("bisection_iterations", "Bisection Iters", 4, 16);
    self_occlusion_eps_scale = addSlider("self_occlusion_eps_scale", "Self-Occl Eps Scale", 0.00001, 0.01);
  }

  void setGUIValues()
  {
    enabled.setValue(occlusion.enabled);
    sample_step_px.setValue(occlusion.sample_step_px);
    min_visible_segment_px.setValue(occlusion.min_visible_segment_px);
    bisection_iterations.setValue(occlusion.bisection_iterations);
    self_occlusion_eps_scale.setValue(occlusion.self_occlusion_eps_scale);
  }

  void update_ui()
  {
    sample_step_px.setValue(occlusion.sample_step_px);
    min_visible_segment_px.setValue(occlusion.min_visible_segment_px);
    bisection_iterations.setValue(occlusion.bisection_iterations);
    self_occlusion_eps_scale.setValue(occlusion.self_occlusion_eps_scale);
  }
}
