# FocusMac website

Launch site for [FocusMac](https://github.com/aadityakumarsah/FocusMac) — React + Vite + Bun.

```bash
cd "front end"
bun install
bun run dev
```

## Deploy (Cloudflare Pages)

```bash
bun run deploy
```

Live URL: **https://focusmac.pages.dev**

## Routes

| Path | Page |
|------|------|
| `/` | Home + demo + install |
| `/features` | Feature mosaic + benchmarks |
| `/how-it-works` | Setup wizard |
| `/install` | Terminal install prompt |
| `/#faq` | FAQ |

To replace the demo later, overwrite `public/demo-video.mov` with the same filename.
