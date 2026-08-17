import controlP5.*;

class DataFacePattern extends GenericData
{
  DataFacePattern()
  {
    super("FacePattern");
  }

  boolean enabled = false;
  int lines_per_face = 20;
  boolean apply_sides = true;
  boolean apply_top = false;
  boolean apply_bottom = false;
  int seed = 1;

  void LoadJson(JSONObject src)
  {
    if (src == null) return;
    enabled = src.getBoolean("enabled", enabled);
    lines_per_face = src.getInt("lines_per_face", lines_per_face);
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
    apply_sides.setValue(facepattern.apply_sides);
    apply_top.setValue(facepattern.apply_top);
    apply_bottom.setValue(facepattern.apply_bottom);
  }

  void update_ui()
  {
  }
}
