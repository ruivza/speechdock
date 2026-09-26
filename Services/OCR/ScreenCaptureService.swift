import AppKit
import CoreGraphics
import ScreenCaptureKit

/// Asynchronous screenshot capture using the macOS 14 filter/configuration API.
@MainActor
enum ScreenCaptureService {
    enum CaptureError: LocalizedError {
        case captureFailed, invalidRect, noScreensAvailable
        var errorDescription: String? {
            switch self {
            case .captureFailed: return "Failed to capture screen region"
            case .invalidRect: return "Invalid capture region specified"
            case .noScreensAvailable: return "No screens available for capture"
            }
        }
    }

    /// AppKit coordinates to display-local ScreenCaptureKit source coordinates.
    static func sourceRect(_ region: CGRect, on screenFrame: CGRect) -> CGRect {
        CGRect(x: region.minX - screenFrame.minX, y: screenFrame.maxY - region.maxY,
               width: region.width, height: region.height)
    }

    static func capture(rect: CGRect, excludingWindowIDs: [CGWindowID] = []) async throws -> CGImage {
        guard rect.width.isFinite, rect.height.isFinite, rect.minX.isFinite, rect.minY.isFinite,
              rect.width >= 1, rect.height >= 1 else { throw CaptureError.invalidRect }
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        let excluded = content.windows.filter { excludingWindowIDs.contains($0.windowID) }
        let screens = NSScreen.screens
        guard !screens.isEmpty else { throw CaptureError.noScreensAvailable }
        // Match the previous nominal-resolution behavior, including mixed-scale displays.
        guard let context = CGContext(data: nil, width: Int(ceil(rect.width)), height: Int(ceil(rect.height)),
                                      bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { throw CaptureError.captureFailed }
        var captured = false
        for screen in screens {
            let region = screen.frame.intersection(rect)
            guard !region.isNull, region.width >= 1, region.height >= 1,
                  let id = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID,
                  let display = content.displays.first(where: { $0.displayID == id }) else { continue }
            try Task.checkCancellation()
            let filter = SCContentFilter(display: display, excludingWindows: excluded)
            let config = SCStreamConfiguration()
            config.sourceRect = sourceRect(region, on: screen.frame)
            config.width = Int(ceil(region.width))
            config.height = Int(ceil(region.height))
            config.showsCursor = false
            let image = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
            context.draw(image, in: CGRect(x: region.minX - rect.minX, y: region.minY - rect.minY,
                                          width: region.width, height: region.height))
            captured = true
        }
        guard captured, let image = context.makeImage() else { throw CaptureError.captureFailed }
        return image
    }

    static func capture(rect: CGRect, excludingWindows: [NSWindow]) async throws -> CGImage {
        try await capture(rect: rect, excludingWindowIDs: excludingWindows.compactMap {
            $0.windowNumber > 0 ? CGWindowID($0.windowNumber) : nil
        })
    }

    static func captureAllScreens() async throws -> CGImage {
        guard let first = NSScreen.screens.first else { throw CaptureError.noScreensAvailable }
        return try await capture(rect: NSScreen.screens.dropFirst().reduce(first.frame) { $0.union($1.frame) })
    }

    static var hasScreenRecordingPermission: Bool { CGPreflightScreenCaptureAccess() }
    static func requestScreenRecordingPermission() { CGRequestScreenCaptureAccess() }
}
