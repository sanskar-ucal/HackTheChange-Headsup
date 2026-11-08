import { readFile } from "node:fs/promises";
import path from "node:path";
import { ImageResponse } from "next/og";

export const dynamic = "force-static";

const size = { width: 1200, height: 630 };


const font = (file: string) =>
  readFile(path.join(process.cwd(), "node_modules/@fontsource/instrument-serif/files", file));

/** Open Graph card, rendered once at build time to /og.png. */
export async function GET() {
  const [regular, italic] = await Promise.all([
    font("instrument-serif-latin-400-normal.woff"),
    font("instrument-serif-latin-400-italic.woff"),
  ]);

  return new ImageResponse(
    (
      <div
        style={{
          width: "100%",
          height: "100%",
          display: "flex",
          flexDirection: "column",
          justifyContent: "space-between",
          background: "#F3EFE6",
          color: "#1D1C1A",
          padding: "72px 84px",
          fontFamily: "Instrument Serif",
        }}
      >
        <div style={{ display: "flex", alignItems: "center", gap: 16, fontSize: 44 }}>
          <div style={{ width: 20, height: 20, borderRadius: 999, background: "#2E7D5B" }} />
          HeadsUp
        </div>
        <div style={{ display: "flex", flexDirection: "column" }}>
          <div style={{ display: "flex", fontSize: 132, lineHeight: 1, letterSpacing: -2 }}>
            Your head is&nbsp;<span style={{ fontStyle: "italic", color: "#2E7D5B" }}>the mouse.</span>
          </div>
          <div style={{ display: "flex", marginTop: 32, fontSize: 38, color: "#5C5850" }}>
            A hands-free mouse for your Mac, powered by your AirPods.
          </div>
        </div>
        <div style={{ display: "flex", fontSize: 30, color: "#5C5850" }}>
          Free & open source · macOS 14+ · AirPods with head tracking
        </div>
      </div>
    ),
    {
      ...size,
      fonts: [
        { name: "Instrument Serif", data: regular, style: "normal", weight: 400 },
        { name: "Instrument Serif", data: italic, style: "italic", weight: 400 },
      ],
    },
  );
}
