import AppKit
import Foundation

guard CommandLine.arguments.count == 2 else {
    fputs("usage: check_macos_screenshot.swift PNG_PATH\n", stderr)
    exit(2)
}

let path = CommandLine.arguments[1]
guard let image = NSImage(contentsOfFile: path),
      let tiff = image.tiffRepresentation,
      let bitmap = NSBitmapImageRep(data: tiff) else {
    fputs("Unable to decode screenshot.\n", stderr)
    exit(1)
}

let horizontalStep = max(1, bitmap.pixelsWide / 64)
let verticalStep = max(1, bitmap.pixelsHigh / 64)
var visibleSamples = 0
var pixel = [Int](repeating: 0, count: max(4, bitmap.samplesPerPixel))

for y in stride(from: 0, to: bitmap.pixelsHigh, by: verticalStep) {
    for x in stride(from: 0, to: bitmap.pixelsWide, by: horizontalStep) {
        bitmap.getPixel(&pixel, atX: x, y: y)
        if max(pixel[0], pixel[1], pixel[2]) > 20 {
            visibleSamples += 1
        }
    }
}

guard visibleSamples >= 10 else {
    fputs("Screenshot is blank or nearly black (\(visibleSamples) visible samples).\n", stderr)
    exit(1)
}

print("\(visibleSamples) visible samples")
