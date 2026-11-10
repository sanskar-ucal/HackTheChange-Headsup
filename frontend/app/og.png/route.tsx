import { readFile } from "node:fs/promises";
import path from "node:path";
import { ImageResponse } from "next/og";

export const dynamic = "force-static";

const size = { width: 1200, height: 630 };

const font = (file: string) => readFile(path.join(process.cwd(), "node_modules/@fontsource/inter-tight/files", file));

/** Open Graph card, rendered once at build time to /og.png. */
export async function GET() {
  const [bold, medium] = await Promise.all([font("inter-tight-latin-700-normal.woff"), font("inter-tight-latin-500-normal.woff")]);

  return new ImageResponse(
    (
      <div style={{ width: "100%", height: "100%", display: "flex", flexDirection: "column", justifyContent: "space-between", background: "#0B1A30", color: "#FFFFFF", padding: "72px 84px", fontFamily: "Inter Tight" }}>
        <div style={{ display: "flex", alignItems: "center", gap: 16, fontSize: 40, fontWeight: 700, letterSpacing: -1 }}>
          <div style={{ width: 30, height: 30, borderRadius: 999, border: "4px solid #A8C6F0", background: "rgba(168,198,240,0.25)" }} />
          HeadsUp
        </div>
        <div style={{ display: "flex", flexDirection: "column" }}>
          <div style={{ display: "flex", fontSize: 128, fontWeight: 700, lineHeight: 0.95, letterSpacing: -5 }}>Your head is the mouse.</div>
          <div style={{ display: "flex", marginTop: 36, fontSize: 36, fontWeight: 500, color: "#A8C6F0" }}>
            A hands-free Mac mouse for people with tetraplegia.
          </div>
        </div>
        <div style={{ display: "flex", fontSize: 28, fontWeight: 500, color: "rgba(255,255,255,0.7)" }}>
          AirPods head tracking · macOS 14+ · Free, code on GitHub
        </div>
      </div>
    ),
    {
      ...size,
      fonts: [
        { name: "Inter Tight", data: bold, style: "normal", weight: 700 },
        { name: "Inter Tight", data: medium, style: "normal", weight: 500 },
      ],
    },
  );
}
