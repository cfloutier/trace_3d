// Generates world-space "hachure" lines on a single box face, for the face-pattern
// feature in LineBuilder. Pure geometry (no BVH/stage/camera-frame coupling), same
// spirit as xlib3d_BoxIntersection.pde.

class FacePatternWorldEdge
{
  PVector worldA;
  PVector worldB;

  FacePatternWorldEdge(PVector worldA, PVector worldB)
  {
    this.worldA = worldA;
    this.worldB = worldB;
  }
}

// Combines a global pattern seed with the box/face indices into a deterministic
// per-face seed, so pattern lines stay stable across camera-only rebuilds (only their
// visibility, not their position, should change while orbiting).
int hashFaceSeed(int patternSeed, int boxIndex, int faceIndex)
{
  int h = patternSeed;
  h = h * 92821 + boxIndex;
  h = h * 92821 + faceIndex;
  return h;
}

// Appends `linesPerFace` vertical hachure lines for one face of `box` into `out`. Each
// line runs the full extent of the face's local "vertical" axis (FACE_VERTICAL_IS_V) at
// a random position along the other axis.
void generateFacePatternWorldEdges(Box3D box, int boxIndex, int faceIndex, int patternSeed,
  int linesPerFace, ArrayList<FacePatternWorldEdge> out)
{
  PVector[] verts = box.getVertices();
  PVector c0 = verts[box.FACE_IDX[faceIndex][0]];
  PVector u  = PVector.sub(verts[box.FACE_IDX[faceIndex][1]], c0);
  PVector v  = PVector.sub(verts[box.FACE_IDX[faceIndex][3]], c0);

  randomSeed(hashFaceSeed(patternSeed, boxIndex, faceIndex));

  boolean verticalIsV = box.FACE_VERTICAL_IS_V[faceIndex];
  PVector acrossAxis = verticalIsV ? u : v;
  PVector spanAxis    = verticalIsV ? v : u;

  for (int i = 0; i < linesPerFace; i++)
  {
    float pos = random(0, 1);
    PVector base = PVector.add(c0, PVector.mult(acrossAxis, pos));
    PVector p0 = base;
    PVector p1 = PVector.add(base, spanAxis);
    out.add(new FacePatternWorldEdge(p0, p1));
  }
}
