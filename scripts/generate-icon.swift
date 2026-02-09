#!/usr/bin/env swift

import AppKit
import CoreGraphics

// MARK: - Icon Drawing

func drawMushroomIcon(size: CGFloat) -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()

    guard NSGraphicsContext.current?.cgContext != nil else {
        image.unlockFocus()
        return image
    }

    let s = size // shorthand

    // Background - teal/green rounded rect
    let bgColor = NSColor(red: 0.18, green: 0.75, blue: 0.65, alpha: 1.0) // teal
    bgColor.setFill()
    let bgPath = NSBezierPath(roundedRect: NSRect(x: 0, y: 0, width: s, height: s),
                               xRadius: s * 0.2, yRadius: s * 0.2)
    bgPath.fill()

    // Stem - cream colored rounded rectangle
    let stemColor = NSColor(red: 0.96, green: 0.91, blue: 0.78, alpha: 1.0)
    stemColor.setFill()
    let stemWidth = s * 0.30
    let stemHeight = s * 0.38
    let stemX = (s - stemWidth) / 2
    let stemY = s * 0.12
    let stemRect = NSRect(x: stemX, y: stemY, width: stemWidth, height: stemHeight)
    let stemPath = NSBezierPath(roundedRect: stemRect, xRadius: stemWidth * 0.25, yRadius: stemWidth * 0.15)
    stemPath.fill()

    // Stem shadow/detail line
    let stemDetailColor = NSColor(red: 0.88, green: 0.82, blue: 0.68, alpha: 1.0)
    stemDetailColor.setFill()
    let detailRect = NSRect(x: stemX + stemWidth * 0.6, y: stemY + stemHeight * 0.1,
                            width: stemWidth * 0.12, height: stemHeight * 0.7)
    let detailPath = NSBezierPath(roundedRect: detailRect, xRadius: detailRect.width * 0.5, yRadius: detailRect.width * 0.3)
    detailPath.fill()

    // Cap - red mushroom cap (half ellipse)
    let capColor = NSColor(red: 0.90, green: 0.22, blue: 0.21, alpha: 1.0)
    capColor.setFill()

    let capWidth = s * 0.78
    let capHeight = s * 0.42
    let capX = (s - capWidth) / 2
    let capY = s * 0.42

    // Draw cap as top half of ellipse
    let capPath = NSBezierPath()
    let capCenterX = capX + capWidth / 2
    let capCenterY = capY

    // Bottom edge (straight line)
    capPath.move(to: NSPoint(x: capX, y: capCenterY))

    // Arc over the top
    capPath.appendArc(withCenter: NSPoint(x: capCenterX, y: capCenterY),
                      radius: capWidth / 2,
                      startAngle: 180,
                      endAngle: 0,
                      clockwise: true)

    // Now draw a taller arc for the dome shape
    let capDomePath = NSBezierPath()
    capDomePath.move(to: NSPoint(x: capX, y: capCenterY))

    // Use a bezier curve for a nice dome shape
    capDomePath.curve(to: NSPoint(x: capX + capWidth, y: capCenterY),
                      controlPoint1: NSPoint(x: capX, y: capCenterY + capHeight * 1.8),
                      controlPoint2: NSPoint(x: capX + capWidth, y: capCenterY + capHeight * 1.8))
    capDomePath.close()
    capDomePath.fill()

    // Cap bottom rim - slightly darker red
    let rimColor = NSColor(red: 0.78, green: 0.18, blue: 0.18, alpha: 1.0)
    rimColor.setFill()
    let rimRect = NSRect(x: capX, y: capCenterY - s * 0.02, width: capWidth, height: s * 0.04)
    let rimPath = NSBezierPath(roundedRect: rimRect, xRadius: rimRect.height * 0.5, yRadius: rimRect.height * 0.5)
    rimPath.fill()

    // White spots on cap
    NSColor.white.setFill()

    // Spot positions (relative to cap center and size)
    let spots: [(dx: CGFloat, dy: CGFloat, r: CGFloat)] = [
        (-0.22, 0.28, 0.07),   // left upper
        (0.15, 0.32, 0.055),   // right upper
        (-0.05, 0.38, 0.065),  // center top
        (-0.28, 0.12, 0.04),   // far left lower
        (0.25, 0.15, 0.045),   // far right lower
        (0.08, 0.18, 0.035),   // center right lower
        (-0.14, 0.15, 0.04),   // center left lower
    ]

    for spot in spots {
        let spotX = capCenterX + spot.dx * s
        let spotY = capCenterY + spot.dy * s
        let spotR = spot.r * s
        let spotRect = NSRect(x: spotX - spotR, y: spotY - spotR, width: spotR * 2, height: spotR * 2)
        let spotPath = NSBezierPath(ovalIn: spotRect)
        spotPath.fill()
    }

    image.unlockFocus()
    return image
}

// MARK: - Main

let projectRoot = CommandLine.arguments.count > 1
    ? CommandLine.arguments[1]
    : FileManager.default.currentDirectoryPath

let assetDir = "\(projectRoot)/Marshroom/Marshroom/Resources/Assets.xcassets/AppIcon.appiconset"

// Verify the asset directory exists
guard FileManager.default.fileExists(atPath: assetDir) else {
    print("Error: AppIcon.appiconset not found at \(assetDir)")
    print("Usage: swift generate-icon.swift [project-root]")
    exit(1)
}

// Generate the master 1024x1024 icon
print("Generating master 1024x1024 icon...")
let masterIcon = drawMushroomIcon(size: 1024)

guard let tiffData = masterIcon.tiffRepresentation,
      let bitmapRep = NSBitmapImageRep(data: tiffData),
      let pngData = bitmapRep.representation(using: .png, properties: [:]) else {
    print("Error: Failed to create PNG data")
    exit(1)
}

let masterPath = "\(assetDir)/icon_512x512@2x.png"
try pngData.write(to: URL(fileURLWithPath: masterPath))
print("  Wrote \(masterPath)")

// Define all required sizes: (filename, pixel size)
let sizes: [(String, Int)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    // icon_512x512@2x.png is the master (1024)
]

// Resize using sips for each size
for (filename, pixelSize) in sizes {
    let outputPath = "\(assetDir)/\(filename)"

    // Copy master to output path first
    try FileManager.default.copyItem(atPath: masterPath, toPath: outputPath)

    // Resize with sips
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/sips")
    process.arguments = ["-z", "\(pixelSize)", "\(pixelSize)", outputPath]
    process.standardOutput = FileHandle.nullDevice
    process.standardError = FileHandle.nullDevice
    try process.run()
    process.waitUntilExit()

    print("  Wrote \(filename) (\(pixelSize)x\(pixelSize))")
}

// Strip extended attributes that cause codesign failures
print("Stripping extended attributes...")
let allIcons = try FileManager.default.contentsOfDirectory(atPath: assetDir)
    .filter { $0.hasSuffix(".png") }
for icon in allIcons {
    let iconPath = "\(assetDir)/\(icon)"
    let xattr = Process()
    xattr.executableURL = URL(fileURLWithPath: "/usr/bin/xattr")
    xattr.arguments = ["-c", iconPath]
    xattr.standardOutput = FileHandle.nullDevice
    xattr.standardError = FileHandle.nullDevice
    try xattr.run()
    xattr.waitUntilExit()
}

print("\nDone! Generated 10 icon files in AppIcon.appiconset/")
