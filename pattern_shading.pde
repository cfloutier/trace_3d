import controlP5.*;

class ShadingData extends GenericData
{
  ShadingData()
  {
    super("Shading");
  }

  boolean enabled = false;
  // Direction the light comes FROM, as two Euler angles (degrees) - same convention
  // as CameraData's orbit direction (see computeLightDirection(), xlib3d_Shading.pde).
  float light_yaw = 45;
  float light_pitch = -45;
  // Light intensity: scales the raw brightness dot product before it's clamped to
  // [0,1] - see computeFaceBrightness(). Together with lines_per_face (Pattern tab)
  // this is enough control over the effect's strength - no separate density slider.
  float power = 1;

  // No LoadJson()/SaveJson() override needed here - GenericData's inherited
  // reflection-based versions already handle these plain boolean/float fields
  // correctly (same approach DataPage uses in xLib_FileUI.pde).
}

class ShadingGUI
{
  ShadingData shading;

  Toggle enabled;
  Slider light_yaw;
  Slider light_pitch;
  Slider power;

  ShadingGUI(ShadingData shading)
  {
    this.shading = shading;
  }

  void setupControls(FacePatternGUI panel)
  {
    panel.addLabel("Shading :");
    enabled = panel.addToggle("enabled", "Enable Shading", shading);
    panel.nextLine();

    light_yaw = panel.addSlider("light_yaw", "Light Yaw", shading, -180, 180);
    light_pitch = panel.addSlider("light_pitch", "Light Pitch", shading, -90, 90);
    power = panel.addSlider("power", "Power", shading, 0, 5);
    panel.nextLine();
  }

  void setGUIValues()
  {
    enabled.setValue(shading.enabled);
    light_yaw.setValue(shading.light_yaw);
    light_pitch.setValue(shading.light_pitch);
    power.setValue(shading.power);
    updateVisibility();
  }

  void update_ui()
  {
    updateVisibility();
  }

  void updateVisibility()
  {
    if (shading.enabled)
    {
      light_yaw.show();
      light_pitch.show();
      power.show();
    } else
    {
      light_yaw.hide();
      light_pitch.hide();
      power.hide();
    }
  }
}
