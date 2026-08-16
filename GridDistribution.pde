class GridDistributionData extends MeshDistributionData
{
  GridDistributionData()
  {
    super("Grid");
  }

  int   count_x     = 4;
  int   count_z     = 4;
  float spacing     = 90;
  float box_size    = 32;
  float box_height  = 120;
  float random_h    = 0;

  @Override
    void createMeshes(ArrayList<Mesh> out_meshes, int random_seed)
  {
    out_meshes.clear();
    randomSeed(random_seed);

    int columns = max(1, count_x);
    int rows    = max(1, count_z);

    float size_x = box_size;
    float size_z = box_size;

    float half_width = (columns - 1) * spacing * 0.5;
    float half_depth = (rows - 1) * spacing * 0.5;
    float base_center_y = 0;

    for (int row = 0; row < rows; row++)
    {
      for (int col = 0; col < columns; col++)
      {
        float center_x = col * spacing - half_width;
        float center_z = row * spacing - half_depth;
        float size_y = box_height + random(0, random_h);

        out_meshes.add(new Box3D(center_x, base_center_y, center_z, size_x, size_y, size_z));
      }
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
  Slider box_height;
  Slider random_h;

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
    panel.nextLine();

    box_height = panel.addSlider("box_height", "Height", data, 10, 1000);
    controls.add(box_height);
    random_h = panel.addSlider("random_h", "Random H", data, 0, 1000);
    controls.add(random_h);
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
