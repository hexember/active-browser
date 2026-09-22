// Renders an SVG to PNG at a given pixel size using AppKit only (no third-party deps).
// usage: swift render.swift <in.svg> <out.png> <size>
import AppKit

let a = CommandLine.arguments
guard a.count == 4, let size = Int(a[3]) else { fputs("usage: render.swift in.svg out.png size\n", stderr); exit(2) }
guard let src = NSImage(contentsOf: URL(fileURLWithPath: a[1])) else { fputs("cannot load \(a[1])\n", stderr); exit(1) }

guard let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size,
                                 bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                 colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0) else { exit(1) }
rep.size = NSSize(width: size, height: size)
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
NSGraphicsContext.current?.imageInterpolation = .high
src.draw(in: NSRect(x: 0, y: 0, width: size, height: size),
         from: .zero, operation: .sourceOver, fraction: 1.0)
NSGraphicsContext.restoreGraphicsState()

guard let png = rep.representation(using: .png, properties: [:]) else { exit(1) }
try png.write(to: URL(fileURLWithPath: a[2]))
