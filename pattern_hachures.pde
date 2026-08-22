import controlP5.*;

// Regular, evenly-spaced full-face hachure lines - deterministic, no randomness. See
// xlib3d_FacePattern.pde's generateHachuresWorldEdges().
class HachuresData extends PatternTypeData
{
  HachuresData()
  {
    super("Hachures");
  }

  // World-space distance between successive lines, measured perpendicular to them.
  float line_spacing = 20;
  // Angle (degrees) of the lines within the face plane - same convention as
  // RandomLinesData.orientation: 0 = along the face's true vertical axis, 90 = along
  // its horizontal axis.
  float orientation = 0;
  // How much to counteract perspective foreshortening making steeply-angled faces
  // look denser (see generateHachuresWorldEdges()): 0 = off (today's behavior), 1 =
  // full geometric compensation. Off by default - opt-in per project convention.
  float foreshortening_compensation = 0;

  // Below this, shading would blow spacing up to (numerically) infinity - treated as
  // "no lines" instead.
  static final float MIN_SHADING_MULTIPLIER = 0.02;

  void generateWorldEdges(Box3D box, int boxIndex, int faceIndex, int patternSeed,
    float shadingMultiplier, PVector cameraPos, ArrayList<FacePatternWorldEdge> out)
  {
    if (shadingMultiplier < MIN_SHADING_MULTIPLIER)
      return;

    float effectiveSpacing = line_spacing / shadingMultiplier;
    generateHachuresWorldEdges(box, boxIndex, faceIndex, effectiveSpacing, orientation,
      foreshortening_compensation, cameraPos, out);
  }
}

class HachuresGUI
{
  HachuresData data;
  ControlsGroup controls;

  Slider line_spacing;
  Slider orientation;
  Slider foreshortening_compensation;

  HachuresGUI(HachuresData data)
  {
    this.data = data;
  }

  void setupControls(FacePatternGUI panel)
  {
    controls = new ControlsGroup(data);

    line_spacing = panel.addSlider("line_spacing", "Spacing", data, 2, 30);
    controls.add(line_spacing);
    orientation = panel.addSlider("orientation", "Orientation", data, 0, 180);
    controls.add(orientation);
    panel.nextLine();
    foreshortening_compensation = panel.addSlider("foreshortening_compensation", "Foreshortening Comp.", data, 0, 1);
    controls.add(foreshortening_compensation);
  }

  void setGUIValues()
  {
    controls.updateFromData();
  }

  void setVisible(boolean visible)
  {
    if (visible) controls.show();
    else controls.hide();
  }
}
