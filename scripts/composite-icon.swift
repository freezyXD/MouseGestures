#!/usr/bin/env swift
import AppKit
import Foundation

guard CommandLine.arguments.count == 3 else {
    FileHandle.standardError.write("Usage: composite-icon <input.png> <output.png>\n".data(using: .utf8)!)
    exit(1)
}

let inputPath = CommandLine.arguments[1]
let outputPath = CommandLine.arguments[2]
let size: CGFloat = 1024

guard let inputImage = NSImage(contentsOfFile: inputPath) else {
    FileHandle.standardError.write("Failed to load \(inputPath)\n".data(using: .utf8)!)
    exit(1)
}

guard let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: Int(size),
    pixelsHigh: Int(size),
    bitsPerSample: 8,
    samplesPerPixel: 4,
    hasAlpha: true,
    isPlanar: false,
    colorSpaceName: .deviceRGB,
    bytesPerRow: 0,
    bitsPerPixel: 32
) else {
    FileHandle.standardError.write("Failed to create bitmap context\n".data(using: .utf8)!)
    exit(1)
}

NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

if let gradient = NSGradient(colors: [
    NSColor(srgbRed: 0.49, green: 0.32, blue: 0.94, alpha: 1.0),
    NSColor(srgbRed: 0.18, green: 0.49, blue: 0.96, alpha: 1.0)
]) {
    gradient.draw(in: NSRect(x: 0, y: 0, width: size, height: size), angle: -45)
}

inputImage.draw(
    in: NSRect(x: 0, y: 0, width: size, height: size),
    from: NSRect(origin: .zero, size: inputImage.size),
    operation: .sourceOver,
    fraction: 1.0
)

NSGraphicsContext.restoreGraphicsState()

guard let png = rep.representation(using: .png, properties: [:]) else {
    FileHandle.standardError.write("Failed to create PNG output\n".data(using: .utf8)!)
    exit(1)
}

try png.write(to: URL(fileURLWithPath: outputPath))
print("Composited icon saved to \(outputPath)")
