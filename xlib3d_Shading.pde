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
// contrast is a gamma curve applied to the raw (unscaled, still in [0,1]) dot product
// FIRST - >1 pushes mid-tones down toward dark (accentuates shaded faces), <1 pushes
// them up toward light (accentuates lit faces), 1 = no change. power (the light's
// intensity) is applied AFTER, and the single clamp to [0,1] happens LAST. Order
// matters: clamping before contrast (as an earlier version of this did) let any face
// already pushed to exactly 1 by power get stuck there - pow(1, anything) is always 1
// - so contrast silently had no effect on saturated faces, and pushing power higher
// past the point most faces were already saturated had no visible effect either.
// Shaping (contrast) then exposure (power) then a single final clamp is the standard
// order for this reason (same as gamma correction before exposure in image pipelines).
float computeFaceBrightness(PVector faceNormal, PVector lightDir, float power, float contrast)
{
  float raw = max(0, faceNormal.dot(lightDir));
  float shaped = pow(raw, max(0.0001, contrast));
  return constrain(shaped * power, 0, 1);
}

// Density multiplier in [0,1] for a face's brightness: 1 = no shading effect (full
// base density), 0 = fully lit, no lines at all. Shared by every pattern type - each
// applies it to its own density parameter (line count, spacing, ...) itself, since
// that mapping is representation-specific.
float computeShadingDensityMultiplier(float brightness)
{
  return constrain(1.0 - brightness, 0, 1);
}
