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
// line is centered on a random point on the face (both along the face's local
// "vertical" axis - FACE_VERTICAL_IS_V, which always points from the face's bottom
// edge to its top edge - and across it) and grows outward from that point in both
// directions by lengthMin + random(0, lengthRandom), truncated at the face's own
// edge if it would otherwise overshoot (so the actual length can end up shorter
// than requested for lines centered near an edge).
// verticalBias skews where along that vertical axis the center point lands: negative
// pushes it toward the bottom, 0 is uniform, positive pushes it toward the top.
void generateFacePatternWorldEdges(Box3D box, int boxIndex, int faceIndex, int patternSeed,
  int linesPerFace, float lengthMin, float lengthRandom, float verticalBias,
  ArrayList<FacePatternWorldEdge> out)
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

  // Power-law skew on a uniform [0,1] draw: exponent 1 = uniform (bias 0); >1 pulls
  // samples down toward 0 (bottom); <1 pushes them up toward 1 (top). base 3 gives a
  // clearly visible effect across the full [-1,1] range without being all-or-nothing
  // at the extremes.
  float biasExponent = pow(3.0, -verticalBias);

  for (int i = 0; i < linesPerFace; i++)
  {
    float posAcross = random(0, 1);
    PVector base = PVector.add(c0, PVector.mult(acrossAxis, posAcross));

    float lineLength = min(max(0, lengthMin) + random(0, max(0, lengthRandom)), spanLen);

    // Draw a point anywhere on the face's vertical extent (biased), then grow the
    // line outward from it in both directions (half up, half down) - not just
    // upward from it - so lines can land anywhere, including flush against the
    // top or bottom edge, instead of always starting at the drawn point. Each end
    // is truncated independently at the face's own edge rather than shifting the
    // whole line, so a point drawn near an edge yields a shorter line there.
    float posPoint = pow(random(0, 1), biasExponent) * spanLen;
    float half = lineLength * 0.5;
    float posStart = max(0, posPoint - half);
    float posEnd = min(spanLen, posPoint + half);

    PVector p0 = PVector.add(base, PVector.mult(spanDir, posStart));
    PVector p1 = PVector.add(base, PVector.mult(spanDir, posEnd));
    out.add(new FacePatternWorldEdge(p0, p1));
  }
}
