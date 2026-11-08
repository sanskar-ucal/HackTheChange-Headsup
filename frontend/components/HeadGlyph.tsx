/**
 * A simple round head wearing two white AirPods, drawn around (0, 0) with radius 16.
 * yaw / pitch are in [-1, 1] (right / down positive); roll is in degrees (right shoulder positive).
 * Pure SVG <g> so it can be placed inside any SVG.
 */
export function HeadGlyph({
  yaw = 0,
  pitch = 0,
  roll = 0,
  x = 0,
  y = 0,
  scale = 1,
  withShoulders = true,
}: {
  yaw?: number;
  pitch?: number;
  roll?: number;
  x?: number;
  y?: number;
  scale?: number;
  withShoulders?: boolean;
}) {
  const R = 16;
  const yawA = yaw * 0.6; // radians, max ~35°
  const pitchA = pitch * 0.5;
  const faceX = R * Math.sin(yawA);
  const faceY = R * Math.sin(pitchA) * 0.85;
  const eyeSpread = 5.2 * Math.cos(yawA);

  // Ears sit at ±90° on the sphere; turning brings one forward and hides the other.
  const ears = [-1, 1].map((side) => {
    const angle = side * (Math.PI / 2) + yawA;
    return { side, x: R * Math.sin(angle), depth: Math.cos(angle) };
  });

  const airpod = (ex: number, depth: number, key: number) =>
    depth < -0.3 ? null : (
      <g key={key} transform={`translate(${ex} ${2 + faceY * 0.25})`} opacity={depth < 0 ? 1 + depth * 2 : 1}>
        <rect x={-2.6} y={-3.6} width={5.2} height={6.4} rx={2.6} fill="#FFFFFF" stroke="#1D1C1A" strokeWidth={0.9} />
        <rect x={-1.1} y={2} width={2.2} height={5.2} rx={1.1} fill="#FFFFFF" stroke="#1D1C1A" strokeWidth={0.9} />
      </g>
    );

  return (
    <g transform={`translate(${x} ${y}) scale(${scale})`}>
      {withShoulders && (
        <path d="M-21 30 C-20 21 -12 18 0 18 C12 18 20 21 21 30 Z" fill="#8A857B" opacity={0.55} />
      )}
      <g transform={`rotate(${roll} 0 14)`}>
        {ears.filter((e) => e.depth < 0).map((e) => airpod(e.x, e.depth, e.side))}
        <circle r={R} fill="#2B2926" />
        <ellipse cx={faceX - eyeSpread} cy={faceY - 1.5} rx={1.7} ry={2} fill="#F3EFE6" />
        <ellipse cx={faceX + eyeSpread} cy={faceY - 1.5} rx={1.7} ry={2} fill="#F3EFE6" />
        <path
          d={`M${faceX - 3} ${faceY + 5.5} Q${faceX} ${faceY + 7.5} ${faceX + 3} ${faceY + 5.5}`}
          stroke="#F3EFE6"
          strokeWidth={1.2}
          strokeLinecap="round"
          fill="none"
          opacity={0.75}
        />
        {ears.filter((e) => e.depth >= 0).map((e) => airpod(e.x, e.depth, e.side))}
      </g>
    </g>
  );
}
