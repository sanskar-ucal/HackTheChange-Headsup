import type { Metadata, Viewport } from "next";
import { Instrument_Serif, Inter } from "next/font/google";
import type { ReactNode } from "react";
import { Providers } from "@/components/Providers";
import { SITE_URL } from "@/site.config";
import "./globals.css";

const serif = Instrument_Serif({
  subsets: ["latin"],
  weight: "400",
  style: ["normal", "italic"],
  variable: "--font-instrument-serif",
  display: "swap",
});

const sans = Inter({ subsets: ["latin"], variable: "--font-inter", display: "swap" });

const title = "HeadsUp: your head is the mouse";
const description =
  "HeadsUp turns the AirPods already in your ears into a hands-free mouse for your Mac. Look to point, nod to click. Free, open source, on-device.";

export const metadata: Metadata = {
  metadataBase: new URL(SITE_URL),
  title,
  description,
  applicationName: "HeadsUp",
  keywords: ["hands-free mouse", "head mouse", "AirPods head tracking", "accessibility", "macOS", "assistive technology"],
  alternates: { canonical: "/" },
  openGraph: {
    type: "website",
    url: "/",
    siteName: "HeadsUp",
    title,
    description,
    locale: "en_US",
    images: [{ url: "/og.png", width: 1200, height: 630, alt: "HeadsUp: your head is the mouse." }],
  },
  twitter: { card: "summary_large_image", title, description, images: ["/og.png"] },
  robots: { index: true, follow: true },
};

export const viewport: Viewport = {
  themeColor: "#F3EFE6",
  colorScheme: "light",
};

export default function RootLayout({ children }: { children: ReactNode }) {
  return (
    <html lang="en" className={`${serif.variable} ${sans.variable}`}>
      <head>
        {/* Without JavaScript, scroll-reveal content must never stay invisible. */}
        <noscript>
          <style>{`[style*="opacity:0"]{opacity:1!important;transform:none!important}`}</style>
        </noscript>
      </head>
      <body>
        <a
          href="#main"
          className="fixed left-4 top-3 z-[100] -translate-y-24 rounded-full bg-ink px-5 py-3 font-medium text-paper transition-transform focus:translate-y-0"
        >
          Skip to content
        </a>
        <Providers>{children}</Providers>
      </body>
    </html>
  );
}
