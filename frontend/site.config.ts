/**
 * Single source of truth for outbound links.
 * Replace OWNER with the GitHub user or org that hosts the repo.
 */
export const GITHUB_URL = "https://github.com/OWNER/HeadsUp";

/** Every "Download for macOS" button points here. */
export const DOWNLOAD_URL = `${GITHUB_URL}/releases/latest`;

/** The README's install guide (anchor of the `## Installation` heading). */
export const INSTALL_GUIDE_URL = `${GITHUB_URL}#installation`;

/** Public URL of the deployed site. Used for canonical, Open Graph and sitemap URLs. */
export const SITE_URL = "https://headsup.vercel.app";
