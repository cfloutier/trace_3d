import controlP5.*;

// Debug tab: display-only toggles for diagnosing the render pipeline. Doesn't affect
// what's computed (edges/patterns are still generated the same either way), only what
// LineBuilder.draw()/mergeIntoFinalGroup() actually draws. More toggles expected here
// over time as new diagnostics are added.
class DataDebug extends GenericData
{
  DataDebug()
  {
    super("Debug");
  }

  boolean show_edges = true;
  boolean show_patterns = true;
  // Off by default - opt-in diagnostic (see LineBuilder.debugFaceGroups/
  // appendDebugFaceDiagonal). No LoadJson()/SaveJson() override needed - GenericData's
  // inherited reflection-based versions already handle these plain boolean fields.
  boolean show_face_debug = false;
  // Final cleanup filter: any line (edge or pattern) shorter than this, measured in
  // screen pixels after projection, is dropped from finalGroup - see
  // LineBuilder.mergeIntoFinalGroup()/appendFilteredGroup(). 0 = no filtering.
  float min_line_length = 0;
}

class DebugGUI extends GUIPanel
{
  DataDebug debug;

  Toggle show_edges;
  Toggle show_patterns;
  Toggle show_face_debug;
  Slider min_line_length;

  DebugGUI(DataDebug debug)
  {
    super("Debug", debug);
    this.debug = debug;
  }

  void setupControls()
  {
    super.Init();

    show_edges = addToggle("show_edges", "Show Edges", debug);
    nextLine();
    show_patterns = addToggle("show_patterns", "Show Patterns", debug);
    nextLine();
    show_face_debug = addToggle("show_face_debug", "Show Face Debug Lines", debug);
    nextLine();
    min_line_length = addSlider("min_line_length", "Min Line Length (px)", debug, 0, 5);
    nextLine();
  }

  void setGUIValues()
  {
    show_edges.setValue(debug.show_edges);
    show_patterns.setValue(debug.show_patterns);
    show_face_debug.setValue(debug.show_face_debug);
    min_line_length.setValue(debug.min_line_length);
  }
}
