# README header

`render.mjs` draws the hand-drawn “Sketchy!” banner with opentype.js, rough.js, and `@resvg/resvg-js`. The README uses the PNG, `docs/images/header.png` (1600×400). A local `header.svg` is written beside this script and is not committed.

## Font

The letters are set in Bungee. Download `Bungee-Regular.ttf` from [google/fonts `ofl/bungee`](https://github.com/google/fonts/tree/main/ofl/bungee) and save it next to `render.mjs`:

```bash
curl -fsSL -o Bungee-Regular.ttf \
  https://github.com/google/fonts/raw/main/ofl/bungee/Bungee-Regular.ttf
```

## Run

From this directory:

```bash
npm install
node render.mjs
```

That refreshes `docs/images/header.png`. Leave out `node_modules`, the font, and the lockfile.

`scripts/render-docs.sh` rebuilds `docs/images` and keeps `header.png`. The 120 KB catalog-tile cap does not apply to this banner; the folder still has to stay under 10 MB.
