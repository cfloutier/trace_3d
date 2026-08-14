class LineBuilder implements BVH3DRayTest
{
  static final int STAGE_IDLE = 0;
  static final int STAGE_COLLECT = 1;
  static final int STAGE_EMIT = 2;

  // Numeric floor for BVH ray queries: avoids picking up a hit at literally t=0
  // (the biased sample origin itself) regardless of which box owns/doesn't own the edge.
  static final float QUERY_T_MIN = 0.0001;

  BoxGridData data;

  ArrayList<Mesh> sourceMeshes = null;
  PolylineGroup finalGroup = null;
  ArrayList<EdgeProjected> edges = new ArrayList<EdgeProjected>();
  ArrayList<OccluderBox> occluders = new ArrayList<OccluderBox>();
  BVH3D bvh = new BVH3D();
  float orthoRayTMax = 1000;

  // World-space seam edges between overlapping boxes (see xLib_BoxIntersection) - purely
  // geometric, so cached and only recomputed alongside occluders (indexedMeshListVersion),
  // then reprojected into `edges` every rebuild like any other edge.
  ArrayList<SeamWorldEdge> seamEdges = new ArrayList<SeamWorldEdge>();
  ArrayList<Integer> overlapScratch = new ArrayList<Integer>();
  boolean seamEdgesBuiltForCurrentOccluders = false;

  // Scratch state for the current testObject() call, set just before each bvh.anyHit()
  // so the ray-test callback can tell "the edge's own box (or boxes, for a seam edge)"
  // from "any other occluder" without allocating a closure per sample
  // (see isSampleVisible/testObject). currentOwnerIndexB is -1 for normal box edges.
  int currentOwnerIndexA = -1;
  int currentOwnerIndexB = -1;
  float currentOwnerEps = 0.001;
  float[] scratchT = new float[2];

  CameraFrame frame = null;

  int stage = STAGE_IDLE;
  int meshIndex = 0;
  int edgeIndex = 0;
  boolean busy = false;
  boolean occlusionMode = false;
  long startNs = 0;
  int last_occlusion_debug_ms = -100000;

  // meshListVersion (declared in trace_3d.pde, bumped once in buildBoxes()) lets us skip
  // rebuilding occluders/BVH on camera-only or occlusion-param-only rebuilds - by far the
  // most frequent interaction (orbiting the camera never touches box geometry).
  int indexedMeshListVersion = -1;
  boolean rebuildingOccluders = true;

  LineBuilder(BoxGridData data)
  {
    this.data = data;
  }

  void requestBuild(ArrayList<Mesh> meshList, PolylineGroup outGroup)
  {
    sourceMeshes = meshList;
    finalGroup = outGroup;
    startNs = System.nanoTime();

    if (data.occlusion.enabled)
    {
      beginOcclusionBuild();
      return;
    }

    stopBuild();
    finalGroup.clear();
    for (int i = 0; i < sourceMeshes.size(); i++)
      sourceMeshes.get(i).addWireframe(finalGroup, data.camera);
  }

  void beginOcclusionBuild()
  {
    busy = true;
    occlusionMode = true;
    stage = STAGE_COLLECT;
    meshIndex = 0;
    edgeIndex = 0;
    edges.clear();
    frame = data.camera.buildFrame();

    int currentMeshCount = (sourceMeshes == null) ? 0 : sourceMeshes.size();
    rebuildingOccluders = (indexedMeshListVersion != meshListVersion) || (occluders.size() != currentMeshCount);

    if (rebuildingOccluders)
      occluders.clear();
  }

  void stopBuild()
  {
    busy = false;
    occlusionMode = false;
    stage = STAGE_IDLE;
  }

  boolean update(float timeBudgetSeconds)
  {
    if (!busy || !occlusionMode || sourceMeshes == null)
      return false;

    long deadlineNs = System.nanoTime() + (long)(max(0.01, timeBudgetSeconds) * 1000000000.0);

    while (busy && System.nanoTime() < deadlineNs)
    {
      if (stage == STAGE_COLLECT)
      {
        if (meshIndex >= sourceMeshes.size())
        {
          if (rebuildingOccluders)
            indexedMeshListVersion = meshListVersion;

          prepareEmit(rebuildingOccluders);
          projectSeamEdges();
          stage = STAGE_EMIT;
          finalGroup.clear();
          edgeIndex = 0;
          continue;
        }

        Mesh mesh = sourceMeshes.get(meshIndex);
        if (rebuildingOccluders)
          occluders.add(mesh.buildOccluder());
        mesh.appendProjectedEdges(edges, data.camera, frame, meshIndex);
        meshIndex++;
      }
      else if (stage == STAGE_EMIT)
      {
        if (edgeIndex >= edges.size())
        {
          stopBuild();
          if (millis() - last_occlusion_debug_ms > 250)
            last_occlusion_debug_ms = millis();
          return true;
        }

        edgeIndex = emitVisibleEdgeSegmentsRange(edgeIndex, deadlineNs, finalGroup);
      }
      else
      {
        break;
      }
    }

    return !busy;
  }

  // Refreshes the user-tunable self-occlusion epsilon on every occluder (cheap, must
  // happen even when reusing occluders, since the eps scale slider can change without a
  // mesh rebuild). When rebuildBVH is true, also rebuilds the BVH broad-phase and (for
  // ortho mode) the scene-scale ray length - both purely geometric, so safe to skip
  // whenever the box list itself hasn't changed (see indexedMeshListVersion).
  void prepareEmit(boolean rebuildBVH)
  {
    int n = occluders.size();

    for (int i = 0; i < n; i++)
    {
      OccluderBox occ = occluders.get(i);
      occ.epsilon = max(0.001, data.occlusion.self_occlusion_eps_scale * occ.diagonal);
    }

    if (!rebuildBVH)
    {
      // Occluders (and the BVH built from them) are unchanged - still valid to query,
      // so a plain enable-toggle can still (re)build seam edges without a full rebuild.
      updateSeamEdgesIfNeeded();
      return;
    }

    float[] minXs = new float[n];
    float[] minYs = new float[n];
    float[] minZs = new float[n];
    float[] maxXs = new float[n];
    float[] maxYs = new float[n];
    float[] maxZs = new float[n];

    float sceneMinX = Float.MAX_VALUE, sceneMinY = Float.MAX_VALUE, sceneMinZ = Float.MAX_VALUE;
    float sceneMaxX = -Float.MAX_VALUE, sceneMaxY = -Float.MAX_VALUE, sceneMaxZ = -Float.MAX_VALUE;

    for (int i = 0; i < n; i++)
    {
      OccluderBox occ = occluders.get(i);

      minXs[i] = occ.minX; minYs[i] = occ.minY; minZs[i] = occ.minZ;
      maxXs[i] = occ.maxX; maxYs[i] = occ.maxY; maxZs[i] = occ.maxZ;

      if (occ.minX < sceneMinX) sceneMinX = occ.minX;
      if (occ.minY < sceneMinY) sceneMinY = occ.minY;
      if (occ.minZ < sceneMinZ) sceneMinZ = occ.minZ;
      if (occ.maxX > sceneMaxX) sceneMaxX = occ.maxX;
      if (occ.maxY > sceneMaxY) sceneMaxY = occ.maxY;
      if (occ.maxZ > sceneMaxZ) sceneMaxZ = occ.maxZ;
    }

    bvh.build(minXs, minYs, minZs, maxXs, maxYs, maxZs);

    if (n > 0)
    {
      float dx = sceneMaxX - sceneMinX;
      float dy = sceneMaxY - sceneMinY;
      float dz = sceneMaxZ - sceneMinZ;
      orthoRayTMax = 2.0 * sqrt(dx * dx + dy * dy + dz * dz) + 1.0;
    }
    else
    {
      orthoRayTMax = 1000;
    }

    // Occluders just changed - any previously cached seam edges are stale.
    seamEdgesBuiltForCurrentOccluders = false;
    updateSeamEdgesIfNeeded();
  }

  // (Re)builds seamEdges only when actually needed: skipped entirely while disabled,
  // and only recomputed once per occluder set (tracked by seamEdgesBuiltForCurrentOccluders)
  // even if called again on a camera-only rebuild or a repeated enable toggle.
  void updateSeamEdgesIfNeeded()
  {
    if (!data.occlusion.seam_edges_enabled)
    {
      seamEdges.clear();
      seamEdgesBuiltForCurrentOccluders = false;
      return;
    }

    if (seamEdgesBuiltForCurrentOccluders)
      return;

    seamEdges.clear();
    buildSeamEdges();
    seamEdgesBuiltForCurrentOccluders = true;
  }

  // Finds overlapping box pairs via the BVH broad-phase (each pair visited once, j > i)
  // and computes their surface-seam segments. World-space and camera-independent, so
  // only needs to run when occluders themselves are rebuilt.
  void buildSeamEdges()
  {
    int n = occluders.size();

    for (int i = 0; i < n; i++)
    {
      OccluderBox occI = occluders.get(i);
      overlapScratch.clear();
      bvh.queryOverlaps(occI.minX, occI.minY, occI.minZ, occI.maxX, occI.maxY, occI.maxZ, overlapScratch);

      for (int k = 0; k < overlapScratch.size(); k++)
      {
        int j = overlapScratch.get(k);
        if (j <= i)
          continue;

        appendBoxSeamEdges(occI.box, i, occluders.get(j).box, j, seamEdges);
      }
    }
  }

  // Projects the cached world-space seam edges for the current camera frame - cheap,
  // so (unlike buildSeamEdges) this runs on every rebuild, same as regular mesh edges.
  void projectSeamEdges()
  {
    PVector[] outWorld = new PVector[2];
    ProjectedPoint[] outProjected = new ProjectedPoint[2];

    for (int i = 0; i < seamEdges.size(); i++)
    {
      SeamWorldEdge s = seamEdges.get(i);
      ProjectedPoint pa = data.camera.projectPointWithDepth(s.worldA, frame);
      ProjectedPoint pb = data.camera.projectPointWithDepth(s.worldB, frame);

      if (!clipSegmentToNearPlane(s.worldA, pa, s.worldB, pb, data.camera, frame, outWorld, outProjected))
        continue;

      edges.add(new EdgeProjected(outProjected[0], outProjected[1], outWorld[0], outWorld[1], s.ownerA, s.ownerB));
    }
  }

  int emitVisibleEdgeSegmentsRange(int startIndex, long deadlineNs, PolylineGroup outGroup)
  {
    float stepPx = max(0.25, data.occlusion.sample_step_px);
    int bisectIters = (int)constrain(data.occlusion.bisection_iterations, 1, 32);

    for (int i = startIndex; i < edges.size(); i++)
    {
      if (System.nanoTime() >= deadlineNs)
        return i;

      EdgeProjected e = edges.get(i);
      if (e.a.z <= 0 || e.b.z <= 0)
        continue;

      float segLenPx = dist(e.a.x, e.a.y, e.b.x, e.b.y);
      int steps = max(1, (int)ceil(segLenPx / stepPx));

      boolean runOpen = false;
      float runStartT = 0;

      boolean prevVisible = false;
      float prevT = 0;

      for (int s = 0; s <= steps; s++)
      {
        if (System.nanoTime() >= deadlineNs)
          return i;

        float t = s / (float)steps;
        boolean visible = isSampleVisibleAtT(e, t);

        if (s == 0)
        {
          prevVisible = visible;
          prevT = t;
          if (visible)
          {
            runOpen = true;
            runStartT = t;
          }
          continue;
        }

        if (visible != prevVisible)
        {
          float transitionT = bisectTransition(e, prevT, t, prevVisible, bisectIters);

          if (visible)
          {
            runOpen = true;
            runStartT = transitionT;
          }
          else if (runOpen)
          {
            emitRunIfLongEnough(e, runStartT, transitionT, outGroup);
            runOpen = false;
          }
        }

        prevVisible = visible;
        prevT = t;
      }

      if (runOpen)
        emitRunIfLongEnough(e, runStartT, 1.0, outGroup);
    }

    return edges.size();
  }

  boolean isSampleVisibleAtT(EdgeProjected e, float t)
  {
    float sx = lerp(e.a.x, e.b.x, t);
    float sy = lerp(e.a.y, e.b.y, t);
    float z;

    if (data.camera.projection_mode == CameraData.PROJECTION_PERSPECTIVE)
    {
      float invz = lerp(e.a.invz, e.b.invz, t);
      if (invz <= 1e-9)
        return false;
      z = 1.0 / invz;
    }
    else
    {
      z = lerp(e.a.z, e.b.z, t);
    }

    if (data.page.clipping && isOutsideClipDomain(sx, sy))
      return false;

    PVector worldPoint = data.camera.unprojectPoint(sx, sy, z, frame);
    return isSampleVisible(worldPoint, e.ownerOccluderIndex, e.ownerOccluderIndexB);
  }

  boolean isOutsideClipDomain(float sx, float sy)
  {
    float halfW = data.page.clip_width * 0.5;
    float halfH = data.page.clip_height * 0.5;
    return (sx < -halfW || sx > halfW || sy < -halfH || sy > halfH);
  }

  // Binary search on screen-space t between two samples of known (and differing) visibility,
  // converging to the exact transition point instead of snapping to the sampling grid.
  float bisectTransition(EdgeProjected e, float tKnown, float tOther, boolean knownVisible, int iterations)
  {
    float tLo = tKnown;
    float tHi = tOther;

    for (int k = 0; k < iterations; k++)
    {
      float mid = (tLo + tHi) * 0.5;
      boolean midVisible = isSampleVisibleAtT(e, mid);
      if (midVisible == knownVisible)
        tLo = mid;
      else
        tHi = mid;
    }

    return (tLo + tHi) * 0.5;
  }

  void emitRunIfLongEnough(EdgeProjected e, float t0, float t1, PolylineGroup outGroup)
  {
    float x0 = lerp(e.a.x, e.b.x, t0);
    float y0 = lerp(e.a.y, e.b.y, t0);
    float x1 = lerp(e.a.x, e.b.x, t1);
    float y1 = lerp(e.a.y, e.b.y, t1);

    if (dist(x0, y0, x1, y1) < data.occlusion.min_visible_segment_px)
      return;

    Polyline line = new Polyline();
    line.addPoint(new PVector(x0, y0));
    line.addPoint(new PVector(x1, y1));
    outGroup.add(line);
  }

  // Casts a line-of-sight ray from worldPoint toward the camera and tests it against the
  // BVH of occluder boxes. The ray origin is biased outward by an owner-relative epsilon
  // to damp exact-surface numerical noise; testObject() then applies a lenient
  // chord-length threshold specifically when the candidate is an owning box (self-
  // occlusion), and treats any other box's hit as unconditional occlusion. A seam edge
  // (ownerIndexB >= 0) sits on both owners' surfaces at once, so both get the lenient
  // treatment and the bias direction is the combined "away from both centers" direction.
  boolean isSampleVisible(PVector worldPoint, int ownerIndexA, int ownerIndexB)
  {
    OccluderBox ownerOccA = occluders.get(ownerIndexA);

    PVector outwardDir = PVector.sub(worldPoint, ownerOccA.worldCenter);
    float eps = ownerOccA.epsilon;

    if (ownerIndexB >= 0)
    {
      OccluderBox ownerOccB = occluders.get(ownerIndexB);
      outwardDir.add(PVector.sub(worldPoint, ownerOccB.worldCenter));
      eps = max(eps, ownerOccB.epsilon);
    }

    if (outwardDir.magSq() < 1e-12)
      outwardDir.set(0, 1, 0);
    else
      outwardDir.normalize();

    PVector biasedOrigin = PVector.add(worldPoint, PVector.mult(outwardDir, eps));

    PVector dir;
    float tMax;

    if (data.camera.projection_mode == CameraData.PROJECTION_PERSPECTIVE)
    {
      dir = PVector.sub(frame.camera_pos, biasedOrigin);
      tMax = dir.mag();
      if (tMax < 1e-6)
        return true;
      dir.normalize();
    }
    else
    {
      dir = PVector.mult(frame.forward, -1);
      tMax = orthoRayTMax;
    }

    currentOwnerIndexA = ownerIndexA;
    currentOwnerIndexB = ownerIndexB;
    currentOwnerEps = eps;

    boolean occluded = bvh.anyHit(biasedOrigin, dir, QUERY_T_MIN, tMax, this);
    return !occluded;
  }

  // BVH3DRayTest callback: exact ray-OBB test per candidate, with the self/other
  // epsilon split described on isSampleVisible().
  boolean testObject(int objectIndex, PVector origin, PVector dir, float tMin, float tMax)
  {
    OccluderBox occ = occluders.get(objectIndex);

    if (!occ.box.intersectRaySlab(origin, dir, tMin, tMax, scratchT))
      return false;

    if (objectIndex == currentOwnerIndexA || objectIndex == currentOwnerIndexB)
    {
      // The ray always starts essentially ON an owning box's own surface, so tEntry is
      // near-zero whether this is a genuine self-occlusion (ray travels deep through the
      // box before exiting) or just a grazing touch at a silhouette edge (near-zero chord).
      // The chord length (tExit - tEntry) is what actually distinguishes the two cases.
      float chordLength = scratchT[1] - scratchT[0];
      return chordLength > currentOwnerEps * 4;
    }

    return true;
  }

  // While an occlusion build is running: draw a real 3D backdrop (solid boxes, native
  // Processing camera) instead of the old flat 2D wireframe preview, then overlay the
  // 2D lines already resolved so far - but only once STAGE_EMIT has started, since
  // finalGroup still holds the PREVIOUS build's (different camera angle) lines during
  // STAGE_COLLECT and would show mismatched ghost lines if drawn then.
  void draw(boolean clipping, float clipWidth, float clipHeight)
  {
    pushStyle();

    if (busy && occlusionMode && !_record)
      preview3D.renderAndComposite(current_graphics, data.camera, sourceMeshes);

    int c = data.style.lineColor.col;
    current_graphics.stroke(red(c), green(c), blue(c), 255);

    boolean showFinalLines = !busy || !occlusionMode || stage == STAGE_EMIT;
    if (showFinalLines && finalGroup != null)
      finalGroup.draw(clipping, clipWidth, clipHeight);

    popStyle();
  }

  int getDisplayLineCount()
  {
    return (finalGroup != null) ? finalGroup.size() : 0;
  }

  BoundingBox getDisplayBoundingBox(boolean clipping, float clipWidth, float clipHeight)
  {
    return (finalGroup != null) ? finalGroup.getBoundingBox(clipping, clipWidth, clipHeight) : new BoundingBox();
  }

  boolean isBusy()
  {
    return busy;
  }

  boolean isOcclusionBuilding()
  {
    return busy && occlusionMode;
  }

  int getPhaseIndex()
  {
    if (stage == STAGE_COLLECT)
      return 1;
    if (stage == STAGE_EMIT)
      return 2;
    return 0;
  }

  String getPhaseName()
  {
    if (stage == STAGE_COLLECT)
      return "collecting";
    if (stage == STAGE_EMIT)
      return "emitting";
    return "idle";
  }

  float getPhaseProgress01()
  {
    if (!busy || sourceMeshes == null || sourceMeshes.size() == 0)
      return 1.0;

    float meshCount = max(1, sourceMeshes.size());
    if (stage == STAGE_COLLECT)
      return meshIndex / meshCount;
    if (stage == STAGE_EMIT)
      return (edges.size() <= 0) ? 0 : edgeIndex / (float)max(1, edges.size());

    return 0.0;
  }

  float getProgress01()
  {
    if (!busy || sourceMeshes == null || sourceMeshes.size() == 0)
      return 1.0;

    float meshCount = max(1, sourceMeshes.size());
    if (stage == STAGE_COLLECT)
      return 0.5 * (meshIndex / meshCount);
    if (stage == STAGE_EMIT)
      return 0.5 + 0.5 * (edges.size() <= 0 ? 0 : edgeIndex / (float)max(1, edges.size()));

    return 0.0;
  }

  String getStatusText()
  {
    if (!busy)
      return "idle";

    return getPhaseIndex() + "/2 " + getPhaseName() + " " + int(getPhaseProgress01() * 100) + "%";
  }

  float getElapsedMs()
  {
    return (System.nanoTime() - startNs) / 1000000.0;
  }
}
