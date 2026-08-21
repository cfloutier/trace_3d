// Generates world-space lines on a single box face, for the face-pattern feature in
// LineBuilder. Pure geometry (no BVH/stage/camera-frame coupling), same spirit as
// xlib3d_BoxIntersection.pde. Two pattern types today (Random Lines, Hachures), both
// working in the face's own local 2D basis and reusing the shared
// clipLineToCenteredRect() (xLib_ClippingUtils.pde) to clip a candidate segment to the
// face rectangle - so any pattern type can add an orientation without reinventing
// rectangle-clip geometry per angle.

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
// visibility, not their position, should change while orbiting). Used only by
// generateRandomLinesWorldEdges() - Hachures is fully deterministic from geometry
// alone, no seed needed.
int hashFaceSeed(int patternSeed, int boxIndex, int faceIndex)
{
  int h = patternSeed;
  h = h * 92821 + boxIndex;
  h = h * 92821 + faceIndex;
  return h;
}

// Maps a point in a face's local (s,t) basis - s along acrossDir, t along spanDir -
// back to world space.
PVector localToWorld(PVector c0, PVector acrossDir, PVector spanDir, float s, float t)
{
  PVector p = PVector.add(c0, PVector.mult(acrossDir, s));
  p.add(PVector.mult(spanDir, t));
  return p;
}

// Appends `linesPerFace` hachure lines for one face of `box` into `out`. Each line is
// centered on a random point on the face (uniform across the face's local "horizontal"
// axis, biased along its "vertical" axis - FACE_VERTICAL_IS_V, which always points from
// the face's bottom edge to its top edge - per verticalBias) and grows outward from
// that point in both directions by lengthMin + random(0, lengthRandom), along a
// direction `orientationDeg` degrees from the true vertical (0 = vertical, 90 =
// horizontal) - clipped to the face's own rectangle for any angle.
// verticalBias skews where the center point lands along the true vertical axis
// (independent of orientationDeg): negative pushes it toward the bottom, 0 is uniform,
// positive pushes it toward the top.
void generateRandomLinesWorldEdges(Box3D box, int boxIndex, int faceIndex, int patternSeed,
  int linesPerFace, float lengthMin, float lengthRandom, float verticalBias, float orientationDeg,
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

  float acrossLen = acrossAxis.mag();
  float spanLen = spanAxis.mag();
  if (acrossLen < 1e-6 || spanLen < 1e-6)
    return;

  PVector acrossDir = PVector.div(acrossAxis, acrossLen);
  PVector spanDir = PVector.div(spanAxis, spanLen);

  // Line direction in the face's local (s,t) basis: 0 deg = along spanDir (today's
  // only behavior), 90 deg = along acrossDir.
  float orientRad = radians(orientationDeg);
  float dirAcross = sin(orientRad);
  float dirSpan = cos(orientRad);

  // Power-law skew on a uniform [0,1] draw. Always uses an exponent <= 1 (which
  // concentrates draws toward 1 almost completely as |verticalBias| grows - the
  // region that stays away from 1 shrinks double-exponentially with 1/exponent),
  // then mirrors the result for negative bias - rather than using pow(3,-bias)
  // directly as the exponent (exponent 1 = uniform, >1 for negative bias, <1 for
  // positive bias), which looked symmetric but wasn't: an exponent > 1 only pushes
  // MOST mass toward 0, leaving a boundary layer of width ~1/exponent (e.g. ~11%
  // of lines at bias=-2) still spread over the middle/top - visibly looser than
  // the same |bias| pushing toward the top, which had no such leftover.
  float concentrationExponent = pow(3.0, -abs(verticalBias));

  float centerS = acrossLen * 0.5;
  float centerT = spanLen * 0.5;
  float[] clipped = new float[4];

  for (int i = 0; i < linesPerFace; i++)
  {
    float sCenter = random(0, acrossLen);

    float concentrated = pow(random(0, 1), concentrationExponent);
    float posFraction = (verticalBias >= 0) ? concentrated : (1 - concentrated);
    float tCenter = posFraction * spanLen;

    // Draw a point anywhere on the face (biased along true vertical), then grow the
    // line outward from it in both directions along the chosen orientation - not just
    // one way - so lines can land anywhere, including flush against an edge. The
    // shared rect-clip (not a manual clamp) truncates whichever end(s) actually leave
    // the face, correctly for any angle - at orientationDeg=0 this reduces to exactly
    // the old 1D clamp on the vertical extent (the across-axis bound never binds when
    // both endpoints share the same s).
    float lineLength = max(0, lengthMin) + random(0, max(0, lengthRandom));
    float half = lineLength * 0.5;

    float s0 = sCenter - half * dirAcross;
    float t0 = tCenter - half * dirSpan;
    float s1 = sCenter + half * dirAcross;
    float t1 = tCenter + half * dirSpan;

    if (!clipLineToCenteredRect(s0, t0, s1, t1, centerS, centerT, acrossLen, spanLen, clipped))
      continue;

    PVector p0 = localToWorld(c0, acrossDir, spanDir, clipped[0], clipped[1]);
    PVector p1 = localToWorld(c0, acrossDir, spanDir, clipped[2], clipped[3]);
    out.add(new FacePatternWorldEdge(p0, p1));
  }
}

// Appends evenly-spaced, full-face hachure lines for one face of `box` into `out`, at
// `spacing` world units apart (measured perpendicular to the lines) and `orientationDeg`
// degrees from the true vertical (same convention as generateRandomLinesWorldEdges).
// Fully deterministic - no randomness, no seed - so the pattern reads as uniform.
void generateHachuresWorldEdges(Box3D box, int boxIndex, int faceIndex,
  float spacing, float orientationDeg, ArrayList<FacePatternWorldEdge> out)
{
  if (spacing < 1e-6)
    return;

  PVector[] verts = box.getVertices();
  PVector c0 = verts[box.FACE_IDX[faceIndex][0]];
  PVector u  = PVector.sub(verts[box.FACE_IDX[faceIndex][1]], c0);
  PVector v  = PVector.sub(verts[box.FACE_IDX[faceIndex][3]], c0);

  boolean verticalIsV = box.FACE_VERTICAL_IS_V[faceIndex];
  PVector acrossAxis = verticalIsV ? u : v;
  PVector spanAxis    = verticalIsV ? v : u;

  float acrossLen = acrossAxis.mag();
  float spanLen = spanAxis.mag();
  if (acrossLen < 1e-6 || spanLen < 1e-6)
    return;

  PVector acrossDir = PVector.div(acrossAxis, acrossLen);
  PVector spanDir = PVector.div(spanAxis, spanLen);

  float orientRad = radians(orientationDeg);
  float dirAcross = sin(orientRad);
  float dirSpan = cos(orientRad);
  // Perpendicular to the line direction (in the local (s,t) basis) - the axis we step
  // along by `spacing` to place successive parallel lines.
  float perpAcross = dirSpan;
  float perpSpan = -dirAcross;

  float centerS = acrossLen * 0.5;
  float centerT = spanLen * 0.5;

  // Generous over-length for each raw line before clipping - more than the rectangle's
  // diagonal, so every line fully crosses it regardless of angle; the clip trims it
  // down to the actual visible segment.
  float overLength = acrossLen + spanLen;

  // Perpendicular-offset range needed to sweep lines across the whole rectangle:
  // project all 4 corners onto the perpendicular axis, relative to the rect center.
  float[] cornerS = { 0, acrossLen, acrossLen, 0 };
  float[] cornerT = { 0, 0, spanLen, spanLen };
  float maxAbsOffset = 0;
  for (int i = 0; i < 4; i++)
  {
    float offset = (cornerS[i] - centerS) * perpAcross + (cornerT[i] - centerT) * perpSpan;
    maxAbsOffset = max(maxAbsOffset, abs(offset));
  }

  float[] clipped = new float[4];

  // Offsets near +-maxAbsOffset only graze a corner of the rectangle, so the clipped
  // segment shrinks toward zero length right at the sweep's extremes - without a
  // floor, that produces a swarm of near-invisible slivers hugging the face's edges.
  // Scaled to the face itself so it adapts to box size instead of being a fixed
  // world-unit constant.
  float minSegmentLen = 0.01 * sqrt(acrossLen * acrossLen + spanLen * spanLen);

  for (float offset = -maxAbsOffset; offset <= maxAbsOffset + 1e-4; offset += spacing)
  {
    float baseS = centerS + offset * perpAcross;
    float baseT = centerT + offset * perpSpan;

    float s0 = baseS - overLength * dirAcross;
    float t0 = baseT - overLength * dirSpan;
    float s1 = baseS + overLength * dirAcross;
    float t1 = baseT + overLength * dirSpan;

    if (!clipLineToCenteredRect(s0, t0, s1, t1, centerS, centerT, acrossLen, spanLen, clipped))
      continue;

    if (dist(clipped[0], clipped[1], clipped[2], clipped[3]) < minSegmentLen)
      continue;

    PVector p0 = localToWorld(c0, acrossDir, spanDir, clipped[0], clipped[1]);
    PVector p1 = localToWorld(c0, acrossDir, spanDir, clipped[2], clipped[3]);
    out.add(new FacePatternWorldEdge(p0, p1));
  }
}
