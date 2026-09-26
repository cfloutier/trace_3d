Polyline makeProjectedEdge(PVector a, PVector b, CameraProjector3D camera)
{
  Polyline edge = new Polyline();
  edge.addPoint(camera.projectPoint(a));
  edge.addPoint(camera.projectPoint(b));
  return edge;
}

// Row-major 3x3 rotation matrix of 'angle' radians (right-handed) around the unit
// vector 'axis' (Rodrigues' formula).
float[] axisAngleMatrix(PVector axis, float angle)
{
  float c = cos(angle);
  float s = sin(angle);
  float t = 1 - c;
  float x = axis.x, y = axis.y, z = axis.z;
  return new float[] {
    t * x * x + c,     t * x * y - s * z, t * x * z + s * y,
    t * x * y + s * z, t * y * y + c,     t * y * z - s * x,
    t * x * z - s * y, t * y * z + s * x, t * z * z + c
  };
}

class Box3D extends Mesh
{
  final int[][] EDGE_IDX = {
    { 0, 1 }, { 1, 2 }, { 2, 3 }, { 3, 0 },
    { 4, 5 }, { 5, 6 }, { 6, 7 }, { 7, 4 },
    { 0, 4 }, { 1, 5 }, { 2, 6 }, { 3, 7 }
  };

  // The 6 faces as planar quads (c0,c1,c2,c3 in order, with c1-c0 and c3-c0 forming a
  // perpendicular in-plane basis) - used by xlib3d_BoxIntersection to find seam edges
  // where two boxes' surfaces cross.
  final int[][] FACE_IDX = {
    { 0, 1, 2, 3 }, // Y = center_y (the box's base/ground face - screen-down; see getVertices())
    { 4, 5, 6, 7 }, // Y = center_y - size_y (the far/tall end - screen-up)
    { 0, 1, 5, 4 }, // -Z
    { 3, 2, 6, 7 }, // +Z
    { 0, 4, 7, 3 }, // -X
    { 1, 2, 6, 5 }  // +X
  };

  // Which 2 faces (FACE_IDX index) each edge (EDGE_IDX index) borders. Used to turn
  // "this edge had a visible segment" into "this face is (partly) visible" for the face
  // pattern feature.
  final int[][] EDGE_TO_FACES = {
    { 0, 2 }, { 0, 5 }, { 0, 3 }, { 0, 4 },
    { 1, 2 }, { 1, 5 }, { 1, 3 }, { 1, 4 },
    { 2, 4 }, { 2, 5 }, { 3, 5 }, { 3, 4 }
  };

  // Inverse of EDGE_TO_FACES: the 4 edges bordering each face.
  final int[][] FACE_TO_EDGES = {
    { 0, 1, 2, 3 },   // face 0 (top)
    { 4, 5, 6, 7 },   // face 1 (bottom)
    { 0, 4, 8, 9 },   // face 2 (-Z)
    { 2, 6, 10, 11 }, // face 3 (+Z)
    { 3, 7, 8, 11 },  // face 4 (-X)
    { 1, 5, 9, 10 }   // face 5 (+X)
  };

  // true = 'v' (FACE_IDX[f][3]-FACE_IDX[f][0]) is the face's local "vertical" (height)
  // axis; false = 'u' (FACE_IDX[f][1]-FACE_IDX[f][0]) is. Face 4 (-X) has the opposite
  // winding from the other 3 side faces. Faces 0/1 (top/bottom) have no true vertical
  // axis - 'u' is used there by convention (only relevant if those faces are enabled
  // for face-pattern lines).
  final boolean[] FACE_VERTICAL_IS_V = { false, false, true, true, false, true };

  float center_x;
  float center_y;
  float center_z;

  float size_x;
  float size_y;
  float size_z;

  // Euler angles as given to setRotation() (Rx applied first, then Ry, then Rz). Only
  // describes the orientation until applyWorldRotation() is called - 'orient' below is
  // what every transform actually uses.
  PVector rotation = new PVector(0, 0, 0);

  // Orientation as a row-major 3x3 rotation matrix (local -> world, around the base
  // pivot). Built from 'rotation' by setRotation(), then optionally left-multiplied by
  // applyWorldRotation() - e.g. Tube mode's bend, a rotation around an arbitrary
  // horizontal axis that doesn't fit a fixed Euler order without gimbal lock.
  float[] orient = { 1, 0, 0, 0, 1, 0, 0, 0, 1 };

  Box3D(float center_x, float center_y, float center_z, float size_x, float size_y, float size_z)
  {
    this.center_x = center_x;
    this.center_y = center_y;
    this.center_z = center_z;
    this.size_x = size_x;
    this.size_y = size_y;
    this.size_z = size_z;
  }

  Box3D(float center_x, float center_y, float center_z, float size_x, float size_y, float size_z, PVector rotation)
  {
    this(center_x, center_y, center_z, size_x, size_y, size_z);
    setRotation(rotation);
  }

  void setRotation(PVector rotation)
  {
    if (rotation == null)
      this.rotation = new PVector(0, 0, 0);
    else
      this.rotation = rotation.copy();

    // Columns = the local X/Y/Z axes run through the Euler helpers, so the matrix
    // reproduces rotateXPoint/rotateYPoint/rotateZPoint's exact convention.
    PVector[] cols = { new PVector(1, 0, 0), new PVector(0, 1, 0), new PVector(0, 0, 1) };
    for (int c = 0; c < 3; c++)
    {
      PVector v = cols[c];
      if (this.rotation.x != 0) v = rotateXPoint(v, this.rotation.x);
      if (this.rotation.y != 0) v = rotateYPoint(v, this.rotation.y);
      if (this.rotation.z != 0) v = rotateZPoint(v, this.rotation.z);
      orient[c] = v.x;
      orient[3 + c] = v.y;
      orient[6 + c] = v.z;
    }
  }

  // Rotates the box's orientation by 'angle' (radians, right-handed) around the unit
  // world-space 'axis', on top of its current orientation. Pivot stays the base center
  // (center_x/y/z) - callers position the box themselves.
  void applyWorldRotation(PVector axis, float angle)
  {
    float[] r = axisAngleMatrix(axis, angle);
    float[] m = new float[9];
    for (int i = 0; i < 3; i++)
      for (int j = 0; j < 3; j++)
        m[i * 3 + j] = r[i * 3] * orient[j] + r[i * 3 + 1] * orient[3 + j] + r[i * 3 + 2] * orient[6 + j];
    orient = m;
  }

  // Local-frame vector -> world-frame vector (no translation).
  PVector localToWorldDir(PVector v)
  {
    return new PVector(
      orient[0] * v.x + orient[1] * v.y + orient[2] * v.z,
      orient[3] * v.x + orient[4] * v.y + orient[5] * v.z,
      orient[6] * v.x + orient[7] * v.y + orient[8] * v.z);
  }

  // World-frame vector -> local-frame vector (transpose = inverse for a rotation).
  PVector worldToLocalDir(PVector v)
  {
    return new PVector(
      orient[0] * v.x + orient[3] * v.y + orient[6] * v.z,
      orient[1] * v.x + orient[4] * v.y + orient[7] * v.z,
      orient[2] * v.x + orient[5] * v.y + orient[8] * v.z);
  }

  PVector[] getVertices()
  {
    PVector[] vertices = new PVector[8];

    float min_x = center_x - size_x;
    float max_x = center_x + size_x;
    float min_z = center_z - size_z;
    float max_z = center_z + size_z;
    // World +Y renders toward the bottom of the screen in this project's projection (nothing
    // re-flips it to match Processing's screen-Y-down convention), so a box's "size_y" extent
    // has to grow toward -Y to read as growing upward on screen. center_y is the base of the
    // box (its screen-up face), not its true center - size_y extends from there down in Y.
    float far_y = center_y - size_y;

    vertices[0] = new PVector(min_x, center_y, min_z);
    vertices[1] = new PVector(max_x, center_y, min_z);
    vertices[2] = new PVector(max_x, center_y, max_z);
    vertices[3] = new PVector(min_x, center_y, max_z);

    vertices[4] = new PVector(min_x, far_y, min_z);
    vertices[5] = new PVector(max_x, far_y, min_z);
    vertices[6] = new PVector(max_x, far_y, max_z);
    vertices[7] = new PVector(min_x, far_y, max_z);

    for (int i = 0; i < vertices.length; i++)
      vertices[i] = rotateAroundBaseCenter(vertices[i]);

    return vertices;
  }

  PVector rotateAroundBaseCenter(PVector point)
  {
    PVector rotated = localToWorldDir(new PVector(point.x - center_x, point.y - center_y, point.z - center_z));
    rotated.add(center_x, center_y, center_z);
    return rotated;
  }

  PVector rotateXPoint(PVector point, float angle)
  {
    float c = cos(angle);
    float s = sin(angle);
    return new PVector(point.x, point.y * c - point.z * s, point.y * s + point.z * c);
  }

  PVector rotateYPoint(PVector point, float angle)
  {
    float c = cos(angle);
    float s = sin(angle);
    return new PVector(point.x * c + point.z * s, point.y, -point.x * s + point.z * c);
  }

  PVector rotateZPoint(PVector point, float angle)
  {
    float c = cos(angle);
    float s = sin(angle);
    return new PVector(point.x * c - point.y * s, point.x * s + point.y * c, point.z);
  }

  @Override
  void addWireframe(PolylineGroup group, CameraProjector3D camera)
  {
    PVector[] vertices = getVertices();

    for (int i = 0; i < EDGE_IDX.length; i++)
    {
      group.add(makeProjectedEdge(vertices[EDGE_IDX[i][0]], vertices[EDGE_IDX[i][1]], camera));
    }
  }

  @Override
  OccluderBox buildOccluder()
  {
    return new OccluderBox(this);
  }

  @Override
  void appendProjectedEdges(
    ArrayList<EdgeProjected> edges,
    CameraProjector3D camera,
    CameraFrame frame,
    int ownerOccluderIndex)
  {
    PVector[] worldVertices = getVertices();
    ProjectedPoint[] p = new ProjectedPoint[worldVertices.length];
    for (int i = 0; i < worldVertices.length; i++)
      p[i] = camera.projectPointWithDepth(worldVertices[i], frame);

    PVector[] outWorld = new PVector[2];
    ProjectedPoint[] outProjected = new ProjectedPoint[2];

    for (int i = 0; i < EDGE_IDX.length; i++)
    {
      int ia = EDGE_IDX[i][0];
      int ib = EDGE_IDX[i][1];

      if (!clipSegmentToNearPlane(worldVertices[ia], p[ia], worldVertices[ib], p[ib], camera, frame, outWorld, outProjected))
        continue;

      edges.add(new EdgeProjected(
        outProjected[0], outProjected[1],
        outWorld[0], outWorld[1],
        ownerOccluderIndex, -1, i));
    }
  }

  // World-space geometric center of the box volume (base pivot - half-height on Y, rotated).
  // Note: center_x/y/z is a BASE pivot (Y in [-size_y, 0] relative to it, see getVertices()),
  // not the volume's geometric center.
  PVector getWorldGeometricCenter()
  {
    PVector offset = localToWorldDir(new PVector(0, -size_y * 0.5, 0));
    return new PVector(center_x + offset.x, center_y + offset.y, center_z + offset.z);
  }

  // Axis-aligned world-space bounding box of the (possibly rotated) box, from its 8 vertices.
  void computeWorldAABB(float[] outMin, float[] outMax)
  {
    PVector[] vertices = getVertices();

    float minX = Float.MAX_VALUE, minY = Float.MAX_VALUE, minZ = Float.MAX_VALUE;
    float maxX = -Float.MAX_VALUE, maxY = -Float.MAX_VALUE, maxZ = -Float.MAX_VALUE;

    for (int i = 0; i < vertices.length; i++)
    {
      PVector v = vertices[i];
      if (v.x < minX) minX = v.x;
      if (v.x > maxX) maxX = v.x;
      if (v.y < minY) minY = v.y;
      if (v.y > maxY) maxY = v.y;
      if (v.z < minZ) minZ = v.z;
      if (v.z > maxZ) maxZ = v.z;
    }

    outMin[0] = minX; outMin[1] = minY; outMin[2] = minZ;
    outMax[0] = maxX; outMax[1] = maxY; outMax[2] = maxZ;
  }

  // Transforms a world-space point (isDirection=false) or vector (isDirection=true, no translation)
  // into the box's unrotated local frame, where the box occupies x in [-size_x,size_x],
  // y in [-size_y,0], z in [-size_z,size_z]. This is the exact inverse of rotateAroundBaseCenter
  // (transposed orientation matrix).
  PVector worldToLocal(PVector world, boolean isDirection)
  {
    PVector p = world.copy();
    if (!isDirection)
      p.sub(center_x, center_y, center_z);

    return worldToLocalDir(p);
  }

  // Closed-form ray/box (OBB) intersection via the slab method, done in the box's local frame
  // so rotation is handled exactly. origin/dir are world-space; dir need not be normalized, but
  // outT is then expressed in units of |dir| (pass a normalized dir to get true distances).
  // Returns true and fills outT = {tEntry, tExit} (clamped to [tMin,tMax]) on intersection.
  boolean intersectRaySlab(PVector origin, PVector dir, float tMin, float tMax, float[] outT)
  {
    PVector lo = worldToLocal(origin, false);
    PVector ld = worldToLocal(dir, true);

    float t0 = tMin;
    float t1 = tMax;

    float[] o = { lo.x, lo.y, lo.z };
    float[] d = { ld.x, ld.y, ld.z };
    float[] mn = { -size_x, -size_y, -size_z };
    float[] mx = { size_x, 0, size_z };

    for (int axis = 0; axis < 3; axis++)
    {
      if (Math.abs(d[axis]) < 1e-12f)
      {
        if (o[axis] < mn[axis] || o[axis] > mx[axis])
          return false;
        continue;
      }

      float invD = 1.0f / d[axis];
      float tNear = (mn[axis] - o[axis]) * invD;
      float tFar = (mx[axis] - o[axis]) * invD;
      if (tNear > tFar)
      {
        float tmp = tNear;
        tNear = tFar;
        tFar = tmp;
      }

      t0 = Math.max(t0, tNear);
      t1 = Math.min(t1, tFar);

      if (t0 > t1)
        return false;
    }

    outT[0] = t0;
    outT[1] = t1;
    return true;
  }

  // Diagonal length of the box volume, used to scale a per-box self-occlusion epsilon.
  float getDiagonal()
  {
    return sqrt(sq(2 * size_x) + sq(size_y) + sq(2 * size_z));
  }

  // Outward-facing unit normal of one face (FACE_IDX index), in world space (accounts
  // for the box's rotation, same as getVertices()). Built from a cross product of the
  // face's own edges, then flipped if needed against the face-center-to-box-center
  // direction, rather than trusting FACE_IDX's winding directly - that winding is NOT
  // consistently outward across all 6 faces (see FACE_VERTICAL_IS_V, which already
  // differs per face for the same reason), so a fixed cross-product order would
  // silently invert some faces.
  PVector getFaceNormal(int faceIndex)
  {
    PVector[] verts = getVertices();
    int[] idx = FACE_IDX[faceIndex];
    PVector c0 = verts[idx[0]];
    PVector u = PVector.sub(verts[idx[1]], c0);
    PVector v = PVector.sub(verts[idx[3]], c0);

    PVector normal = u.cross(v);
    normal.normalize();

    PVector faceCenter = new PVector(0, 0, 0);
    for (int i = 0; i < 4; i++)
      faceCenter.add(verts[idx[i]]);
    faceCenter.div(4);

    PVector outward = PVector.sub(faceCenter, getWorldGeometricCenter());
    if (normal.dot(outward) < 0)
      normal.mult(-1);

    return normal;
  }

  // World-space center of one face (FACE_IDX index) - average of its 4 (already
  // rotated) vertices. Paired with getFaceNormal() for back-face tests.
  PVector getFaceCenter(int faceIndex)
  {
    PVector[] verts = getVertices();
    int[] idx = FACE_IDX[faceIndex];

    PVector center = new PVector(0, 0, 0);
    for (int i = 0; i < 4; i++)
      center.add(verts[idx[i]]);
    center.div(4);

    return center;
  }
}


void addBoxWireframe(PolylineGroup group, CameraProjector3D camera, float center_x, float center_y, float center_z, float size_x, float size_y, float size_z)
{
  Box3D box = new Box3D(center_x, center_y, center_z, size_x, size_y, size_z);
  box.addWireframe(group, camera);
}
