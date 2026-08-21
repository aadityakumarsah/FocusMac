import AppKit
import CoreGraphics
import Foundation

public enum ScreenCapture {

    public static func captureFrontmostWindowBase64(forPID pid: Int, maxWidth: Int = 640) -> String? {
        guard let windowID = frontmostWindowID(forPID: pid) else { return nil }
        guard let image = CGWindowListCreateImage(
            .null,
            .optionIncludingWindow,
            windowID,
            [.boundsIgnoreFraming, .bestResolution]
        ) else { return nil }
        let scaled = downscale(image, maxWidth: maxWidth)
        let rep = NSBitmapImageRep(cgImage: scaled)
        guard let data = rep.representation(using: .jpeg, properties: [.compressionFactor: 0.6]) else { return nil }
        return data.base64EncodedString()
    }

    public static func frontmostWindowID(forPID pid: Int) -> CGWindowID? {
        let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID)
            as? [[String: Any]] ?? []
        var best: (CGWindowID, Double)?
        for window in list {
            guard (window[kCGWindowOwnerPID as String] as? Int) == pid,
                  (window[kCGWindowLayer as String] as? Int) == 0,
                  let number = window[kCGWindowNumber as String] as? Int else { continue }
            let bounds = window[kCGWindowBounds as String] as? [String: Any]
            let width = (bounds?["Width"] as? NSNumber)?.doubleValue ?? 0
            let height = (bounds?["Height"] as? NSNumber)?.doubleValue ?? 0
            let area = width * height
            if let existing = best {
                if area > existing.1 { best = (CGWindowID(number), area) }
            } else {
                best = (CGWindowID(number), area)
            }
        }
        return best?.0
    }

    private static func downscale(_ image: CGImage, maxWidth: Int) -> CGImage {
        let scale = min(1, CGFloat(maxWidth) / CGFloat(image.width))
        guard scale < 1 else { return image }
        let width = max(1, Int(CGFloat(image.width) * scale))
        let height = max(1, Int(CGFloat(image.height) * scale))
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return image }
        context.interpolationQuality = .medium
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        return context.makeImage() ?? image
    }
}