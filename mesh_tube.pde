class TubeDistributionData extends MeshDistributionData
{
  TubeDistributionData()
  {
    super("Tube");
  }

  int   box_count = 24;
  int   box_multiplier = 1;
  float radius_min = 300;
  float radius_max = 600;
  // Tube's central line: starts at (0, start_y, 0) going up on screen (world -Y, the
  // direction boxes grow in - see Box3D.getVertices()), tube_length long measured along
  // the line itself (so a bent tube keeps its length). Box mid-heights are spread
  // uniformly along it.
  float tube_length = 600;
  float start_y = 300;
  float tube_box_size = 90;
  float box_length_min = 80;
  float box_length_max = 180;

  // Orientation around Y (the up/down axis - same axis GridDistributionData.grid_rotation_y
  // uses). In degrees (converted to radians in createMeshes(), like Grid's fields);
  // tube_random_rotation_y is a +/- range added on top per box, same convention as Grid.
  float tube_rotation_y        = 0;
  float tube_random_rotation_y = 0;
  // When true, tube_rotation_y is measured from a per-box radial base angle instead of 0 -
  // each box's default (tube_rotation_y=0) side then faces directly away from the tube's
  // central axis, following the box's own position angle around it, rather than
  // every box sharing one fixed world-space orientation.
  boolean radial_orientation = false;

  // Bend of the tube's central line. bend_angle (degrees) is the total turn of the line
  // over tube_length - 0 = straight, 180 = a U-turn, 360 = a full ring - so the shape
  // stays the same when the length changes. The line becomes a circular arc, vertical at
  // the start point and curving progressively toward bend_direction (degrees, horizontal
  // angle measured like a box's own position angle around the axis: 0 = +X, 90 = +Z).
  float bend_angle     = 0;
  float bend_direction = 0;

  // Tilt of each box relative to the tube's axis (degrees): 0 = along the axis,
  // 90 = perpendicular to it. tilt_direction (degrees) picks which way it leans, measured
  // around the axis from the box's own radial direction: 0 = outward (at 90 tilt, spokes
  // radiating from the axis), 90 = along the circumference (rings; in between, a helical
  // twist). The box pivots around its own mid point, so it stays where it was placed.
  float box_tilt       = 0;
  float tilt_direction = 0;

  @Override
    void createMeshes(ArrayList<Mesh> out_meshes, int random_seed)
  {
    out_meshes.clear();
    randomSeed(random_seed);

    int total_boxes = box_count * box_multiplier;

    float rMin = min(radius_min, radius_max);
    float rMax = max(radius_min, radius_max);

    float len = max(0, tube_length);

    float lenMin = max(1, min(box_length_min, box_length_max));
    float lenMax = max(1, max(box_length_min, box_length_max));

    float size_x = tube_box_size;
    float size_z = tube_box_size;

    // Bend setup (see bend_angle). Each box is laid out as on a straight vertical tube,
    // then moved rigidly onto the arc: s = distance of its mid-height from the start
    // point along the line, theta = k*s the line's turn there. The arc's "up" tangent is
    // up(s) = sin(theta)*bendDir - cos(theta)*Y, and rotating by -theta around bendAxis
    // (= Y x bendDir, Rodrigues) maps -Y (a straight box's up) onto it.
    float k = (len > 0) ? radians(bend_angle) / len : 0;
    boolean bent = abs(k) > 1e-9;
    float dirA = radians(bend_direction);
    PVector bendDir = new PVector(cos(dirA), 0, sin(dirA));
    PVector bendAxis = new PVector(bendDir.z, 0, -bendDir.x);

    float tilt = radians(box_tilt);
    boolean tilted = abs(tilt) > 1e-9;

    for (int i = 0; i < total_boxes; i++)
    {
      float a = random(TWO_PI);
      float radius = random(rMin, rMax);
      // Mirrored draw (len - random) keeps the exact box layout the settings had back
      // when they drew random(base_y_min, base_y_max) (converted to tube_length/start_y).
      float s = len - random(0, len);
      float size_y = random(lenMin, lenMax);

      float ox = cos(a) * radius;
      float oz = sin(a) * radius;

      // Rotating local +Z (the unrotated box's world-+Z-facing side) by (HALF_PI - a)
      // around Y lands it on (cos(a), 0, sin(a)) - exactly the radial direction at this
      // box's own position (Box3D.rotateYPoint's convention: x'=x*cos+z*sin, z'=-x*sin+
      // z*cos, so (0,0,1) -> (sin(HALF_PI-a), 0, cos(HALF_PI-a)) = (cos(a), 0, sin(a))).
      float radialBase = radial_orientation ? (HALF_PI - a) : 0;
      float box_rotation_y = radialBase + radians(tube_rotation_y) + radians(random(-tube_random_rotation_y, tube_random_rotation_y));

      // Orientation, innermost first: tube_rotation_y spins the box around its own length,
      // then the tilt leans it away from the tube's axis, then the bend carries it onto
      // the arc. Box3D's pivot (base center) is set last, from the box's mid point.
      Box3D box = new Box3D(0, 0, 0, size_x, size_y, size_z, new PVector(0, box_rotation_y, 0));

      if (tilted)
      {
        // Lean direction: tilt_direction degrees around the axis from this box's radial
        // direction (cos(a), 0, sin(a)). Same Rodrigues setup as the bend: rotating by
        // -tilt around Y x leanDir maps -Y (the box's up) to cos*(-Y) + sin*leanDir.
        float leanA = a + radians(tilt_direction);
        PVector leanAxis = new PVector(sin(leanA), 0, -cos(leanA));
        box.applyWorldRotation(leanAxis, -tilt);
      }

      // Box mid point: on a straight tube, (ox, start_y - s, oz).
      PVector mid = new PVector(ox, start_y - s, oz);

      if (bent)
      {
        float theta = k * s;
        float[] r = axisAngleMatrix(bendAxis, -theta);

        // Line point on the arc at s (radius 1/k).
        float lateral = (1 - cos(theta)) / k;
        PVector linePt = new PVector(bendDir.x * lateral, start_y - sin(theta) / k, bendDir.z * lateral);

        // Horizontal offset from the straight line, carried into the arc's cross-section.
        mid.set(
          linePt.x + r[0] * ox + r[2] * oz,
          linePt.y + r[3] * ox + r[5] * oz,
          linePt.z + r[6] * ox + r[8] * oz);

        box.applyWorldRotation(bendAxis, -theta);
      }

      // Box3D pivots on its base center, half a length "below" the mid point (+local Y).
      PVector toBase = box.localToWorldDir(new PVector(0, size_y * 0.5, 0));
      box.center_x = mid.x + toBase.x;
      box.center_y = mid.y + toBase.y;
      box.center_z = mid.z + toBase.z;

      out_meshes.add(box);
    }
  }
}

class TubeDistributionGUI
{
  TubeDistributionData data;
  ControlsGroup controls;

  Slider box_count;
  Slider box_multiplier;

  Slider radius_min;
  Slider radius_max;
  Slider tube_length;
  Slider start_y;
  Slider tube_box_size;
  Slider box_length_min;
  Slider box_length_max;
  Slider tube_rotation_y;
  Slider tube_random_rotation_y;
  Toggle radial_orientation;
  Slider bend_angle;
  Slider bend_direction;
  Slider box_tilt;
  Slider tilt_direction;

  TubeDistributionGUI(TubeDistributionData data)
  {
    this.data = data;
  }

  void setupControls(BoxesGUI panel)
  {
    controls = new ControlsGroup(data);

    box_count = panel.addIntSlider("box_count", "Count", data, 1, 1000);
    box_multiplier = panel.addIntSlider("box_multiplier", "multiplier", data, 1, 100);

    controls.add(box_count);
    controls.add(box_multiplier);

    panel.nextLine();

    radius_min = panel.addSlider("radius_min", "Radius Min", data, 10, 2500);
    controls.add(radius_min);
    radius_max = panel.addSlider("radius_max", "Radius Max", data, 10, 2500);
    controls.add(radius_max);
    panel.nextLine();

    tube_length = panel.addSlider("tube_length", "Tube Length", data, 0, 40000);
    controls.add(tube_length);
    start_y = panel.addSlider("start_y", "Start Y", data, -20000, 20000);
    controls.add(start_y);
    panel.nextLine();

    tube_box_size = panel.addSlider("tube_box_size", "Box Size", data, 10, 400);
    controls.add(tube_box_size);
    box_length_min = panel.addSlider("box_length_min", "Length Min", data, 2, 2000);
    controls.add(box_length_min);
    box_length_max = panel.addSlider("box_length_max", "Length Max", data, 2, 2000);
    controls.add(box_length_max);
    panel.nextLine();

    tube_rotation_y = panel.addSlider("tube_rotation_y", "Rotation Y", data, -180, 180);
    controls.add(tube_rotation_y);
    tube_random_rotation_y = panel.addSlider("tube_random_rotation_y", "Random Rotation", data, 0, 180);
    controls.add(tube_random_rotation_y);
    radial_orientation = panel.addToggle("radial_orientation", "Radial", data);
    controls.add(radial_orientation);
    panel.nextLine();

    bend_angle = panel.addSlider("bend_angle", "Bend", data, 0, 360);
    controls.add(bend_angle);
    bend_direction = panel.addSlider("bend_direction", "Bend Direction", data, -180, 180);
    controls.add(bend_direction);
    panel.nextLine();

    box_tilt = panel.addSlider("box_tilt", "Box Tilt", data, 0, 90);
    controls.add(box_tilt);
    tilt_direction = panel.addSlider("tilt_direction", "Tilt Direction", data, -180, 180);
    controls.add(tilt_direction);
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
