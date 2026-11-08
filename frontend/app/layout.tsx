import type { Metadata, Viewport } from "next";
import { Inter, Inter_Tight } from "next/font/google";
import type { ReactNode } from "react";
import { Providers } from "@/components/Providers";
import { SITE_URL } from "@/site.config";
import "./globals.css";

const display = Inter_Tight({ subsets: ["latin"], weight: ["600", "700"], variable: "--font-inter-tight", display: "swap" });
const sans = Inter({ subsets: ["latin"], variable: "--font-inter", display: "swap" });

const title = "HeadsUp: a hands-free Mac mouse for people with tetraplegia";
const description =
  "HeadsUp turns AirPods head tracking into a Mac mouse for people with tetraplegia. Turn your head to point, nod to click. Free, with the code on GitHub.";

export const metadata: Metadata = {
  metadataBase: new URL(SITE_URL),
  title,
  description,
  applicationName: "HeadsUp",
  keywords: ["tetraplegia", "hands-free mouse", "head mouse", "AirPods head tracking", "accessibility", "macOS", "assistive technology"],
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
  themeColor: "#0B1A30",
  colorScheme: "dark",
};

export default function RootLayout({ children }: { children: ReactNode }) {
  return (
    <html lang="en" className={`${display.variable} ${sans.variable}`}>
      <head>
        <noscript>
          <style>{`[style*="opacity:0"]{opacity:1!important;transform:none!important}`}</style>
        </noscript>
      </head>
      <body>
        <a href="#main" className="fixed left-4 top-3 z-[100] -translate-y-24 rounded-full bg-sky px-5 py-3 font-semibold text-navy transition-transform focus:translate-y-0">
          Skip to content
        </a>
        <Providers>{children}</Providers>
      </body>
    </html>
  );
}
