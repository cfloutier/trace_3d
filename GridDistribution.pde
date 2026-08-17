class GridDistributionData extends MeshDistributionData
{
  static final int HEIGHT_FIXED             = 0;
  static final int HEIGHT_WHITE_NOISE       = 1;
  static final int HEIGHT_PERLIN_NOISE      = 2;
  static final int HEIGHT_DISTANCE_WEIGHTED = 3;

  GridDistributionData()
  {
    super("Grid");
  }

  int   count_x     = 4;
  int   count_z     = 4;
  float spacing     = 90;
  float box_size    = 32;
  float random_size = 0;
  float box_height  = 120;
  int   height_mode = HEIGHT_FIXED;
  float random_h    = 0;
  float perlin_zoom = 0.15;
  // +1 = tall at the edges (original behavior), -1 = tall at the center, 0 = no distance
  // dependency (uniform weight, same as White Noise).
  float distance_bias = 1;

  PerlinNoise perlin = new PerlinNoise();

  @Override
    void createMeshes(ArrayList<Mesh> out_meshes, int random_seed)
  {
    out_meshes.clear();
    randomSeed(random_seed);
    perlin.noiseSeed(random_seed);

    int columns = max(1, count_x);
    int rows    = max(1, count_z);

    float half_width = (columns - 1) * spacing * 0.5;
    float half_depth = (rows - 1) * spacing * 0.5;
    float base_center_y = 0;

    // Normalizes distance-from-center weighting to [0,1] across the grid extent.
    float max_dist = sqrt(half_width * half_width + half_depth * half_depth);

    for (int row = 0; row < rows; row++)
    {
      for (int col = 0; col < columns; col++)
      {
        float center_x = col * spacing - half_width;
        float center_z = row * spacing - half_depth;
        float size_y = computeHeight(col, row, center_x, center_z, max_dist);
        float size_xz = box_size + random(0, random_size);

        out_meshes.add(new Box3D(center_x, base_center_y, center_z, size_xz, size_y, size_xz));
      }
    }
  }

  // random_h is always the extra height added on top of box_height, in [0, random_h] - never
  // shorter than box_height. Only its distribution across the grid changes per mode.
  float computeHeight(int col, int row, float center_x, float center_z, float max_dist)
  {
    switch (height_mode)
    {
    case HEIGHT_WHITE_NOISE:
      return box_height + random(0, random_h);

    case HEIGHT_PERLIN_NOISE:
      float n = perlin.noise(col * perlin_zoom, row * perlin_zoom);
      return box_height + n * random_h;

    case HEIGHT_DISTANCE_WEIGHTED:
      float dist = sqrt(center_x * center_x + center_z * center_z);
      float t = (max_dist > 0) ? (dist / max_dist) : 0;  // 0 at center, 1 at the edge
      float weight = 0.5 + distance_bias * (t - 0.5);
      return box_height + random(0, random_h) * weight;

    default: // HEIGHT_FIXED
      return box_height;
    }
  }
}

class GridDistributionGUI
{
  GridDistributionData data;
  ControlsGroup controls;

  Slider count_x;
  Slider count_z;
  Slider spacing;
  Slider box_size;
  Slider random_size;
  Slider box_height;
  myRadioButton height_mode;
  Slider random_h;
  Slider perlin_zoom;
  Slider distance_bias;

  GridDistributionGUI(GridDistributionData data)
  {
    this.data = data;
  }

  void setupControls(BoxesGUI panel)
  {
    controls = new ControlsGroup(data);

    count_x = panel.addIntSlider("count_x", "Count X", data, 1, 64);
    controls.add(count_x);
    count_z = panel.addIntSlider("count_z", "Count Z", data, 1, 64);
    controls.add(count_z);
    panel.nextLine();

    spacing = panel.addSlider("spacing", "Spacing", data, 10, 400);
    controls.add(spacing);
    box_size = panel.addSlider("box_size", "Box Size", data, 2, 200);
    controls.add(box_size);
    random_size = panel.addSlider("random_size", "Random Size", data, 0, 200);
    controls.add(random_size);
    panel.nextLine();

    box_height = panel.addSlider("box_height", "Height", data, 10, 1000);
    controls.add(box_height);
    panel.nextLine();

    ArrayList<String> height_modes = new ArrayList<String>();
    height_modes.add("Fixed");
    height_modes.add("White Noise");
    height_modes.add("Perlin Noise");
    height_modes.add("Distance");
    height_mode = panel.addRadio("height_mode", height_modes, data);

    random_h = panel.addSlider("random_h", "Random H", data, 0, 10000);
    controls.add(random_h);
    perlin_zoom = panel.addSlider("perlin_zoom", "Perlin Zoom", data, 0.01, 0.4);
    controls.add(perlin_zoom);
    distance_bias = panel.addSlider("distance_bias", "Distance Bias", data, -1, 1);
    controls.add(distance_bias);
  }

  void setGUIValues()
  {
    controls.updateFromData();

    if ((int)height_mode.getValue() != data.height_mode)
      height_mode.activate(data.height_mode);

    updateHeightModeVisibility();
  }

  void update_ui()
  {
    updateHeightModeVisibility();
  }

  void updateHeightModeVisibility()
  {
    boolean show_random_h     = data.height_mode != GridDistributionData.HEIGHT_FIXED;
    boolean show_perlin_zoom  = data.height_mode == GridDistributionData.HEIGHT_PERLIN_NOISE;
    boolean show_distance_bias = data.height_mode == GridDistributionData.HEIGHT_DISTANCE_WEIGHTED;

    if (show_random_h) random_h.show();
    else random_h.hide();
    if (show_perlin_zoom) perlin_zoom.show();
    else perlin_zoom.hide();
    if (show_distance_bias) distance_bias.show();
    else distance_bias.hide();
  }

  void setVisible(boolean visible)
  {
    if (visible)
    {
      controls.show();
      height_mode.show();
      updateHeightModeVisibility();
    } else
    {
      controls.hide();
      height_mode.hide();
      random_h.hide();
      perlin_zoom.hide();
      distance_bias.hide();
    }
  }
}
