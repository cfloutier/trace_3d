// Live 3D preview shown while an occlusion (HLR) build is running, instead of the old
// flat low-alpha 2D wireframe: real solid boxes rendered via Processing's native 3D API,
// directly onto the main canvas (size(...,P3D) in setup()).
//
// An offscreen P3D PGraphics + image() composite was tried first specifically to avoid
// touching the main renderer (ControlP5 auto-draws on it via registerMethod("draw", this),
// with no depth-test/camera handling of its own). That approach is actually IMPOSSIBLE,
// not just risky: Processing refuses to create an OpenGL-backed offscreen PGraphics
// unless the main renderer is itself P2D/P3D ("createGraphics() with P3D or OPENGL
// requires size() to use P2D or P3D"). So the main renderer has to be P3D for this
// feature to exist at all - which means properly resetting camera/projection/depth-test
// after the 3D box drawing (see renderAndComposite()) so the 2D line content and the
// ControlP5 GUI that auto-draws after our own draw() still render correctly afterward.
class NativePreview3D
{
  void renderAndComposite(PGraphics target, CameraData camera, ArrayList<Mesh> meshes)
  {
    target.hint(ENABLE_DEPTH_TEST);
    target.pushMatrix();
    applyCamera(target, camera);

    target.ambientLight(80, 80, 80);
    // Fixed directional light, arbitrary azimuth, ~45deg down toward the ground (world Y
    // is up here) - independent of camera/orbit angle, so faces stay lit consistently.
    target.directionalLight(255, 255, 255, 0.5, -1, 0.3);

    target.pushStyle();
    target.strokeWeight(1);
    // Edges: 1/3 line color, 2/3 background. Fill: 1/6 line color, 5/6 background - both
    // sit closer to the background than before, so the 3D backdrop reads as a dim,
    // clearly secondary layer under the final line color (drawn at full brightness on
    // top of it once STAGE_EMIT starts).
    int bg = data.style.backgroundColor.col;
    int line = data.style.lineColor.col;
    target.stroke(lerpColor(bg, line, 1.0 / 3.0));
    target.fill(lerpColor(bg, line, 1.0 / 6.0));

    if (meshes != null)
    {
      for (int i = 0; i < meshes.size(); i++)
      {
        Mesh m = meshes.get(i);
        if (m instanceof Box3D)
          drawBox((Box3D) m, target);
      }
    }

    target.popStyle();
    // popMatrix() alone already fully restores whatever modelview (start_draw()'s
    // translate(width/2,height/2)/scale(global_scale)) was active before pushMatrix() -
    // do NOT also call camera() here: camera(), even with no arguments, doesn't compose
    // with the current matrix, it REPLACES it outright, which would silently wipe out
    // that just-restored 2D transform and misalign everything drawn after this.
    target.popMatrix();

    // perspective() is a separate, persistent global (not saved/restored by push/popMatrix
    // at all), so our custom fov-based projection from applyCamera() would otherwise keep
    // applying to the 2D content drawn after this - reset it back to Processing's default.
    target.perspective();

    // Lights are also persistent global state in P3D, applied to ALL geometry drawn after
    // they're set - including ControlP5's flat 2D-style rects, which is why they looked
    // washed out/semi-transparent (being lit) instead of drawing as flat opaque color.
    target.noLights();

    // DISABLE_DEPTH_TEST alone stops fragments being rejected against the depth buffer,
    // but Processing tracks depth writes as a separate hint - without also disabling the
    // mask, the box pass's real (non-zero) depth values stay written, and whatever draws
    // next while depth test flips back on (e.g. next frame's default state) tests against
    // them instead of getting a clean slate.
    target.hint(DISABLE_DEPTH_TEST);
    target.hint(DISABLE_DEPTH_MASK);
  }

  // Mirrors CameraData.buildFrame()'s look-at basis via Processing's native camera(), and
  // fov/ortho_zoom via perspective()/ortho() using the same fov-to-focal relationship
  // CameraData itself now uses (focal_distance was removed for exactly this reason).
  //
  // Also folds in data.page.global_scale: the 2D line content is drawn inside
  // start_draw()'s scale(global_scale) (an auto-computed "fit to view" zoom), while this
  // native camera draws at native 1:1 scale with no equivalent - without compensating for
  // it here, the two layers render at different apparent sizes and visibly drift apart
  // relative to each other as global_scale changes.
  void applyCamera(PGraphics pg, CameraData camera)
  {
    PVector eye = camera.getCameraPosition();
    PVector target = camera.getTarget();
    pg.camera(eye.x, eye.y, eye.z, target.x, target.y, target.z, 0, 1, 0);

    float aspect = (float) pg.width / pg.height;
    float near = max(1, camera.target_distance * 0.01);
    float far = camera.target_distance * 4 + 20000;
    float globalScale = max(1e-6, data.page.global_scale);

    if (camera.projection_mode == CameraData.PROJECTION_PERSPECTIVE)
    {
      // Screen-space scale by globalScale (as the 2D projection applies it, post-focal)
      // is equivalent to an effective focal of focal*globalScale, i.e. tan(fovUsed/2) =
      // tan(fov/2) / globalScale.
      float halfFov = radians(camera.fov) * 0.5;
      float fovUsed = 2.0 * atan(tan(halfFov) / globalScale);
      pg.perspective(fovUsed, aspect, near, far);
    }
    else
    {
      float halfW = (pg.width * 0.5) / max(1e-6, camera.ortho_zoom * globalScale);
      float halfH = (pg.height * 0.5) / max(1e-6, camera.ortho_zoom * globalScale);
      pg.ortho(-halfW, halfW, -halfH, halfH, near, far);
    }
  }

  // Rotation order matches Box3D.rotateAroundBaseCenter() (Rx applied first, innermost):
  // Processing's rotateX/Y/Z calls compose in the OPPOSITE order (last call acts on the
  // vertex first), so they must be issued Z, then Y, then X to produce the same Rz.Ry.Rx
  // composition Box3D uses.
  void drawBox(Box3D box, PGraphics pg)
  {
    PVector c = box.getWorldGeometricCenter();

    pg.pushMatrix();
    pg.translate(c.x, c.y, c.z);
    pg.rotateZ(box.rotation.z);
    pg.rotateY(box.rotation.y);
    pg.rotateX(box.rotation.x);
    pg.box(box.size_x * 2, box.size_y, box.size_z * 2);
    pg.popMatrix();
  }
}
