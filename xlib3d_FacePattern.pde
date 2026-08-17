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
// line is placed at a random position on the face (both along the face's local
// "vertical" axis - FACE_VERTICAL_IS_V - and across it) and its length is
// lengthMin + random(0, lengthRandom), clamped to the face's vertical extent so it
// never overshoots past the face's own edge.
void generateFacePatternWorldEdges(Box3D box, int boxIndex, int faceIndex, int patternSeed,
  int linesPerFace, float lengthMin, float lengthRandom, ArrayList<FacePatternWorldEdge> out)
{
  PVector[] verts = box.getVertices();
  PVector c0 = verts[box.FACE_IDX[faceIndex][0]];
  PVector u  = PVector.sub(verts[box.FACE_IDX[faceIndex][1]], c0);
  PVector v  = PVector.sub(verts[box.FACE_IDX[faceIndex][3]], c0);

  randomSeed(hashFaceSeed(patternSeed, boxIndex, faceIndex));

  boolean verticalIsV = box.FACE_VERTICAL_IS_V[faceIndex];
  PVector acrossAxis = verticalIsV ? u : v;
  PVector spanAxis    = verticalIsV ? v : u;

  float spanLen = spanAxis.mag();
  PVector spanDir = (spanLen > 1e-6) ? PVector.div(spanAxis, spanLen) : new PVector(0, 0, 0);

  for (int i = 0; i < linesPerFace; i++)
  {
    float posAcross = random(0, 1);
    PVector base = PVector.add(c0, PVector.mult(acrossAxis, posAcross));

    float lineLength = min(max(0, lengthMin) + random(0, max(0, lengthRandom)), spanLen);
    float posStart = random(0, max(0, spanLen - lineLength));

    PVector p0 = PVector.add(base, PVector.mult(spanDir, posStart));
    PVector p1 = PVector.add(p0, PVector.mult(spanDir, lineLength));
    out.add(new FacePatternWorldEdge(p0, p1));
  }
}
