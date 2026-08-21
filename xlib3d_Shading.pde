// Generic per-face shading utilities for the face-pattern feature(s) in LineBuilder -
// deliberately independent of any specific pattern's line-generation logic (hachures
// today, more patterns planned later), so any of them can reuse the same brightness/
// density mapping without knowing shading exists.

// Direction the light comes FROM, as a unit vector, from two Euler angles (degrees) -
// same yaw/pitch-to-direction convention as CameraData.getCameraPosition().
PVector computeLightDirection(float yawDeg, float pitchDeg)
{
  float yaw = radians(yawDeg);
  float pitch = radians(pitchDeg);
  float cosPitch = cos(pitch);
  return new PVector(cosPitch * sin(yaw), sin(pitch), cosPitch * cos(yaw));
}

// Lambertian-style brightness in [0,1]: how directly faceNormal faces the light.
// power is the light's own intensity, scaling the raw dot product before clamping -
// a weak light (power < 1) keeps every face dimmer, a strong light (power > 1) pushes
// more faces toward fully lit faster.
float computeFaceBrightness(PVector faceNormal, PVector lightDir, float power)
{
  float raw = max(0, faceNormal.dot(lightDir));
  return constrain(raw * power, 0, 1);
}

// Density multiplier in [0,1] for a face's brightness: 1 = no shading effect (full
// base density), 0 = fully lit, no lines at all. Shared by every pattern type - each
// applies it to its own density parameter (line count, spacing, ...) itself, since
// that mapping is representation-specific.
float computeShadingDensityMultiplier(float brightness)
{
  return constrain(1.0 - brightness, 0, 1);
}
