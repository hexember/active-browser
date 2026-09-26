# Assets

Source of truth is SVG; the binary formats below are generated from it.

| File | What it is |
| --- | --- |
| `icon.svg` | App icon artwork, 1024×1024 |
| `icon-1024.png` | Flat preview / upload asset |
| `AppIcon.icns` | Generated app icon for `Contents/Resources/` |
| `menubar-icon.svg` | Menu bar glyph, 18×18pt, black + alpha (template image) |
| `menubar/MenuBarIconTemplate{,@2x,@3x}.png` | Generated menu bar images |
| `tools/render.swift` | AppKit-only SVG→PNG rasteriser (no third-party deps) |
| `tools/showcase.swift` | AppKit + AVFoundation renderer for the README showcase video (`media/`); never compiled |

## Regenerating

Run these from `assets/`; the paths are relative.

```sh
rm -rf /tmp/AppIcon.iconset && mkdir -p /tmp/AppIcon.iconset
for s in 16 32 128 256 512; do
  swift tools/render.swift icon.svg /tmp/AppIcon.iconset/icon_${s}x${s}.png $s
  swift tools/render.swift icon.svg /tmp/AppIcon.iconset/icon_${s}x${s}@2x.png $((s*2))
done
iconutil -c icns /tmp/AppIcon.iconset -o AppIcon.icns
swift tools/render.swift menubar-icon.svg menubar/MenuBarIconTemplate.png 18
swift tools/render.swift menubar-icon.svg menubar/MenuBarIconTemplate@2x.png 36
swift tools/render.swift menubar-icon.svg menubar/MenuBarIconTemplate@3x.png 54
```

## Showcase video

`media/showcase.mp4` (1280×720, H.264, faststart) and its poster `media/showcase-poster.jpg`
(1280×720 JPEG) are the video embedded at the top of `README.md`. Regenerate them with these
commands, run from the repo root. `<scratchpad>` is any scratch directory outside the repo;
never commit intermediate renders.

```sh
OUT_SCALE=0.6666667 BITRATE=1400000 swift assets/tools/showcase.swift "$PWD" <scratchpad>/showcase.mp4 <scratchpad>/poster.png
sips -Z 1280 <scratchpad>/poster.png --out <scratchpad>/poster-720.png
sips -s format jpeg -s formatOptions 85 <scratchpad>/poster-720.png --out media/showcase-poster.jpg
cp <scratchpad>/showcase.mp4 media/showcase.mp4
```

The script always writes the poster at 1920×1080; the two `sips` calls scale it to 1280×720
and encode it as JPEG at quality 85. Keep them as two calls: that is how the shipped poster
was made, and it reproduces it byte for byte. A single
`sips -Z 1280 -s format jpeg -s formatOptions 85` call also gives a 1280×720 JPEG, but its
bytes differ slightly. The mp4 is not byte-reproducible (the encoder varies between runs),
but it comes out at about the same size.

To check a frame without encoding, pass timestamps in seconds after the poster path and set
`PREVIEW_ONLY=1`. The script then writes `<poster>-<seconds>.png` next to the poster and exits.
A full render takes well under a minute.

The Arc, Brave and Safari icons come from the local `/Applications`, so on a machine without
Arc or Brave installed the video renders generic app icons instead. Render only on a machine
that has all three.

`media/` is published by the Pages site. Adding or renaming a file there also needs the
allowlist (and its presence check) in `.github/workflows/pages.yml` updated, or the site
build fails.

## Design

Both marks are the same idea: browser chrome (title bar + three dots) with the active
pointer inside it. The app icon adds the receding stack and colour; the menu bar glyph is the
monochrome reduction — the app icon's tinted title-bar strip becomes a divider line, since a
template image has only black and alpha to work with.

## How the bundle uses these

`make bundle` copies `AppIcon.icns` and the three `MenuBarIconTemplate` PNGs into
`Contents/Resources/` before it runs `codesign`. `Support/Info.plist` names the app icon
through `CFBundleIconFile` (`AppIcon`), and `MenuBarManager` loads the menu bar glyph by
name, falling back to the `globe` SF Symbol when `Contents/Resources` is missing (an
unbundled build).

The menu bar image must be loaded with `isTemplate = true` so macOS tints it for light/dark
menu bars and for the highlighted state.
