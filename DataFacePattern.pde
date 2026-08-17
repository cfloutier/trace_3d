import controlP5.*;

class DataFacePattern extends GenericData
{
  DataFacePattern()
  {
    super("FacePattern");
  }

  boolean enabled = false;
  int lines_per_face = 20;
  // Actual line length = line_length_min + random(0, line_length_random), clamped to
  // the face's own vertical extent (see generateFacePatternWorldEdges).
  float line_length_min = 30;
  float line_length_random = 60;
  // -1 = lines pushed toward the bottom of the face, 0 = evenly distributed,
  // 1 = pushed toward the top (see generateFacePatternWorldEdges).
  float vertical_bias = 0;
  boolean apply_sides = true;
  boolean apply_top = false;
  boolean apply_bottom = false;
  int seed = 1;

  void LoadJson(JSONObject src)
  {
    if (src == null) return;
    enabled = src.getBoolean("enabled", enabled);
    lines_per_face = src.getInt("lines_per_face", lines_per_face);
    line_length_min = src.getFloat("line_length_min", line_length_min);
    line_length_random = src.getFloat("line_length_random", line_length_random);
    vertical_bias = src.getFloat("vertical_bias", vertical_bias);
    apply_sides = src.getBoolean("apply_sides", apply_sides);
    apply_top = src.getBoolean("apply_top", apply_top);
    apply_bottom = src.getBoolean("apply_bottom", apply_bottom);
    seed = src.getInt("seed", seed);
  }

  JSONObject SaveJson()
  {
    JSONObject dest = new JSONObject();
    dest.setBoolean("enabled", enabled);
    dest.setInt("lines_per_face", lines_per_face);
    dest.setFloat("line_length_min", line_length_min);
    dest.setFloat("line_length_random", line_length_random);
    dest.setFloat("vertical_bias", vertical_bias);
    dest.setBoolean("apply_sides", apply_sides);
    dest.setBoolean("apply_top", apply_top);
    dest.setBoolean("apply_bottom", apply_bottom);
    dest.setInt("seed", seed);
    return dest;
  }
}


class FacePatternGUI extends GUIPanel
{
  DataFacePattern facepattern;

  Toggle enabled;
  Slider lines_per_face;
  Slider line_length_min;
  Slider line_length_random;
  Slider vertical_bias;
  Toggle apply_sides;
  Toggle apply_top;
  Toggle apply_bottom;

  FacePatternGUI(DataFacePattern facepattern)
  {
    super("Pattern", facepattern);
    this.facepattern = facepattern;
  }

  void setSeed()
  {
    Random rand = new Random(System.currentTimeMillis());
    this.facepattern.seed = rand.nextInt();
    this.facepattern.changed = true;
  }

  void setupControls()
  {
    super.Init();

    enabled = addToggle("enabled", "Enable Pattern", facepattern);
    nextLine();

    lines_per_face = addIntSlider("lines_per_face", "Lines / Face", facepattern, 1, 300);
    nextLine();

    line_length_min = addSlider("line_length_min", "Length Min", facepattern, 0, 1000);
    line_length_random = addSlider("line_length_random", "Length Random", facepattern, 0, 1000);
    nextLine();

    vertical_bias = addSlider("vertical_bias", "Vertical Bias", facepattern, -5, 5);
    nextLine();

    apply_sides = addToggle("apply_sides", "Sides", facepattern);
    apply_top = addToggle("apply_top", "Top", facepattern);
    apply_bottom = addToggle("apply_bottom", "Bottom", facepattern);
    nextLine();

    addButton("Seed").plugTo(this, "setSeed");
  }

  void setGUIValues()
  {
    enabled.setValue(facepattern.enabled);
    lines_per_face.setValue(facepattern.lines_per_face);
    line_length_min.setValue(facepattern.line_length_min);
    line_length_random.setValue(facepattern.line_length_random);
    vertical_bias.setValue(facepattern.vertical_bias);
    apply_sides.setValue(facepattern.apply_sides);
    apply_top.setValue(facepattern.apply_top);
    apply_bottom.setValue(facepattern.apply_bottom);
  }

  void update_ui()
  {
  }
}
