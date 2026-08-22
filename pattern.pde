import controlP5.*;

abstract class PatternTypeData extends GenericData
{
  PatternTypeData(String chapter_name)
  {
    super(chapter_name);
  }

  abstract void generateWorldEdges(Box3D box, int boxIndex, int faceIndex, int patternSeed,
    float shadingMultiplier, PVector cameraPos, ArrayList<FacePatternWorldEdge> out);
}

class DataFacePattern extends GenericData
{
  static final int TYPE_RANDOM_LINES = 0;
  static final int TYPE_HACHURES = 1;

  DataFacePattern()
  {
    super("FacePattern");
    addChapter(random_lines);
    addChapter(hachures);
    addChapter(shading);
  }

  boolean enabled = false;
  int pattern_type = TYPE_RANDOM_LINES;
  boolean apply_sides = true;
  boolean apply_top = false;
  boolean apply_bottom = false;
  int seed = 1;

  RandomLinesData random_lines = new RandomLinesData();
  HachuresData hachures = new HachuresData();
  ShadingData shading = new ShadingData();

  void generateWorldEdges(Box3D box, int boxIndex, int faceIndex, float shadingMultiplier,
    PVector cameraPos, ArrayList<FacePatternWorldEdge> out)
  {
    if (pattern_type == TYPE_HACHURES)
      hachures.generateWorldEdges(box, boxIndex, faceIndex, seed, shadingMultiplier, cameraPos, out);
    else
      random_lines.generateWorldEdges(box, boxIndex, faceIndex, seed, shadingMultiplier, cameraPos, out);
  }

  void LoadJson(JSONObject src)
  {
    if (src == null) return;
    enabled = src.getBoolean("enabled", enabled);
    pattern_type = src.getInt("pattern_type", pattern_type);
    apply_sides = src.getBoolean("apply_sides", apply_sides);
    apply_top = src.getBoolean("apply_top", apply_top);
    apply_bottom = src.getBoolean("apply_bottom", apply_bottom);
    seed = src.getInt("seed", seed);

    // Pre-multi-pattern settings files saved lines_per_face/line_length_min/
    // line_length_random/vertical_bias flat, at this same level, instead of nested
    // under a "RandomLines" chapter - fall back to the outer object itself so those
    // still load instead of silently resetting to defaults. Safe: RandomLinesData's
    // reflection-based LoadJson only reads the field names it declares, ignoring
    // unrelated keys (seed, apply_sides, Shading, ...) present in the outer object.
    JSONObject randomLinesJson = src.getJSONObject(random_lines.chapter_name);
    if (randomLinesJson == null)
      randomLinesJson = src;
    random_lines.LoadJson(randomLinesJson);

    hachures.LoadJson(src.getJSONObject(hachures.chapter_name));
    shading.LoadJson(src.getJSONObject(shading.chapter_name));

    changed = true;
  }

  JSONObject SaveJson()
  {
    JSONObject dest = new JSONObject();
    dest.setBoolean("enabled", enabled);
    dest.setInt("pattern_type", pattern_type);
    dest.setBoolean("apply_sides", apply_sides);
    dest.setBoolean("apply_top", apply_top);
    dest.setBoolean("apply_bottom", apply_bottom);
    dest.setInt("seed", seed);
    dest.setJSONObject(random_lines.chapter_name, random_lines.SaveJson());
    dest.setJSONObject(hachures.chapter_name, hachures.SaveJson());
    dest.setJSONObject(shading.chapter_name, shading.SaveJson());
    return dest;
  }
}


class FacePatternGUI extends GUIPanel
{
  DataFacePattern facepattern;
  ShadingGUI shading_ui;
  RandomLinesGUI random_lines_ui;
  HachuresGUI hachures_ui;

  Toggle enabled;
  myRadioButton pattern_type;
  Toggle apply_sides;
  Toggle apply_top;
  Toggle apply_bottom;

  FacePatternGUI(DataFacePattern facepattern)
  {
    super("Pattern", facepattern);
    this.facepattern = facepattern;
    this.shading_ui = new ShadingGUI(facepattern.shading);
    this.random_lines_ui = new RandomLinesGUI(facepattern.random_lines);
    this.hachures_ui = new HachuresGUI(facepattern.hachures);
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

    shading_ui.setupControls(this);

    ArrayList<String> pattern_types = new ArrayList<String>();
    pattern_types.add("Random Lines");
    pattern_types.add("Hachures");
    pattern_type = addRadio("pattern_type", pattern_types);
    nextLine();

    float start_y_pos = yPos;
    random_lines_ui.setupControls(this);
    nextLine();
    // reset y pos for each pattern type, same as BoxesGUI does for grid/tube
    yPos = start_y_pos;
    hachures_ui.setupControls(this);
    nextLine();

    apply_sides = addToggle("apply_sides", "Sides", facepattern);
    apply_top = addToggle("apply_top", "Top", facepattern);
    apply_bottom = addToggle("apply_bottom", "Bottom", facepattern);
    nextLine();

    addButton("Seed").plugTo(this, "setSeed");
  }

  void updatePatternTypeVisibility()
  {
    boolean is_random_lines = facepattern.pattern_type == DataFacePattern.TYPE_RANDOM_LINES;
    random_lines_ui.setVisible(is_random_lines);
    hachures_ui.setVisible(!is_random_lines);
  }

  void setGUIValues()
  {
    enabled.setValue(facepattern.enabled);
    if ((int)pattern_type.getValue() != facepattern.pattern_type)
      pattern_type.activate(facepattern.pattern_type);
    random_lines_ui.setGUIValues();
    hachures_ui.setGUIValues();
    apply_sides.setValue(facepattern.apply_sides);
    apply_top.setValue(facepattern.apply_top);
    apply_bottom.setValue(facepattern.apply_bottom);
    shading_ui.setGUIValues();
    updatePatternTypeVisibility();
  }

  void update_ui()
  {
    if ((int)pattern_type.getValue() != facepattern.pattern_type)
      pattern_type.activate(facepattern.pattern_type);
    updatePatternTypeVisibility();
    shading_ui.update_ui();
  }
}
