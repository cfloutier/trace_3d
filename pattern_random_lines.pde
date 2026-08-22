import controlP5.*;

// Today's original face-pattern style: variable-length lines at random positions,
// biased vertically. See xlib3d_FacePattern.pde's generateRandomLinesWorldEdges().
class RandomLinesData extends PatternTypeData
{
  RandomLinesData()
  {
    super("RandomLines");
  }

  int lines_per_face = 20;
  // Actual line length = line_length_min + random(0, line_length_random), clipped to
  // the face (see generateRandomLinesWorldEdges).
  float line_length_min = 30;
  float line_length_random = 60;
  // -1 = lines pushed toward the bottom of the face, 0 = evenly distributed,
  // 1 = pushed toward the top - relative to the face's true vertical axis, regardless
  // of orientation (see generateRandomLinesWorldEdges).
  float vertical_bias = 0;
  // Angle (degrees) of the lines within the face plane: 0 = along the face's true
  // vertical axis (this pattern's only behavior before orientation was added),
  // 90 = along its horizontal axis.
  float orientation = 0;

  // cameraPos is unused here (only Hachures' foreshortening compensation needs it) -
  // part of the shared PatternTypeData contract, same as patternSeed being unused by
  // Hachures.
  void generateWorldEdges(Box3D box, int boxIndex, int faceIndex, int patternSeed,
    float shadingMultiplier, PVector cameraPos, ArrayList<FacePatternWorldEdge> out)
  {
    int effectiveLinesPerFace = round(lines_per_face * shadingMultiplier);
    generateRandomLinesWorldEdges(box, boxIndex, faceIndex, patternSeed,
      effectiveLinesPerFace, line_length_min, line_length_random, vertical_bias, orientation, out);
  }
}

class RandomLinesGUI
{
  RandomLinesData data;
  ControlsGroup controls;

  Slider lines_per_face;
  Slider line_length_min;
  Slider line_length_random;
  Slider vertical_bias;
  Slider orientation;

  RandomLinesGUI(RandomLinesData data)
  {
    this.data = data;
  }

  void setupControls(FacePatternGUI panel)
  {
    controls = new ControlsGroup(data);

    lines_per_face = panel.addIntSlider("lines_per_face", "Lines / Face", data, 1, 300);
    controls.add(lines_per_face);
    panel.nextLine();

    line_length_min = panel.addSlider("line_length_min", "Length Min", data, 0, 1000);
    controls.add(line_length_min);
    line_length_random = panel.addSlider("line_length_random", "Length Random", data, 0, 1000);
    controls.add(line_length_random);
    panel.nextLine();

    vertical_bias = panel.addSlider("vertical_bias", "Vertical Bias", data, -5, 5);
    controls.add(vertical_bias);
    orientation = panel.addSlider("orientation", "Orientation", data, 0, 180);
    controls.add(orientation);
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
