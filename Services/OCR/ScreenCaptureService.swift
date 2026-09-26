import Foundation
import AppKit
import CoreGraphics

/// Service for capturing screen regions
///
/// NOTE on CGWindowListCreateImage deprecation (macOS 14): the calls below emit
/// deprecation warnings. Migration to SCScreenshotManager is deliberately
/// deferred while the app supports macOS 14 — the macOS 15+ rect-capture API
/// isn't available there, so we'd have to keep this exact code as the macOS 14
/// fallback anyway (same warnings, more code). Revisit when the deployment
/// target moves to macOS 15+.
enum ScreenCaptureService {

    /// Capture error types
    enum CaptureError: LocalizedError {
        case captureFailed
        case invalidRect
        case noScreensAvailable

        var errorDescription: String? {
            switch self {
            case .captureFailed:
                return "Failed to capture screen region"
            case .invalidRect:
                return "Invalid capture region specified"
            case .noScreensAvailable:
                return "No screens available for capture"
            }
        }
    }

    /// Capture a specific region of the screen
    /// - Parameters:
    ///   - rect: The rectangle to capture in screen coordinates (origin at bottom-left)
    ///   - excludingWindowIDs: Window IDs to exclude from capture (e.g., overlay windows)
    /// - Returns: Captured image as CGImage
    static func capture(rect: CGRect, excludingWindowIDs: [CGWindowID] = []) throws -> CGImage {
        guard rect.width >= 1 && rect.height >= 1 else {
            throw CaptureError.invalidRect
        }

        // Convert from bottom-left origin (AppKit) to top-left origin (CGImage)
        // Quartz uses the primary screen's height as the reference for the flip
        let screenHeight = NSScreen.screens.first?.frame.height ?? 0
        let flippedRect = CGRect(
            x: rect.origin.x,
            y: screenHeight - rect.origin.y - rect.height,
            width: rect.width,
            height: rect.height
        )

        // Capture the screen region
        // Using kCGWindowListOptionOnScreenOnly to capture only visible content
        guard let image = CGWindowListCreateImage(
            flippedRect,
            .optionOnScreenOnly,
            kCGNullWindowID,
            [.boundsIgnoreFraming, .nominalResolution]
        ) else {
            throw CaptureError.captureFailed
        }

        return image
    }

    /// Capture a specific region, excluding specified windows
    /// - Parameters:
    ///   - rect: The rectangle to capture in screen coordinates
    ///   - excludingWindows: Windows to exclude from capture
    /// - Returns: Captured image as CGImage
    static func capture(rect: CGRect, excludingWindows: [NSWindow]) throws -> CGImage {
        guard rect.width >= 1 && rect.height >= 1 else {
            throw CaptureError.invalidRect
        }

        // Get screen height for coordinate conversion
        // Quartz uses the primary screen's height as the reference for the flip
        let screenHeight = NSScreen.screens.first?.frame.height ?? 0

        // Convert from bottom-left origin (AppKit) to top-left origin (CGImage)
        let flippedRect = CGRect(
            x: rect.origin.x,
            y: screenHeight - rect.origin.y - rect.height,
            width: rect.width,
            height: rect.height
        )

        // Get window IDs to exclude
        let excludeWindowIDs = excludingWindows.compactMap { window -> CGWindowID? in
            let windowNumber = window.windowNumber
            guard windowNumber > 0 else { return nil }
            return CGWindowID(windowNumber)
        }

        // Capture below the first excluded window so overlay windows are not
        // included. Fall back to a plain on-screen capture if that fails or if
        // there are no windows to exclude.
        if let belowWindowID = excludeWindowIDs.first,
           let image = CGWindowListCreateImage(
               flippedRect,
               .optionOnScreenBelowWindow,
               belowWindowID,
               [.boundsIgnoreFraming, .nominalResolution]
           ) {
            return image
        }

        // Fallback to capturing all on-screen content
        guard let fallbackImage = CGWindowListCreateImage(
            flippedRect,
            .optionOnScreenOnly,
            kCGNullWindowID,
            [.boundsIgnoreFraming, .nominalResolution]
        ) else {
            throw CaptureError.captureFailed
        }
        return fallbackImage
    }

    /// Capture the entire screen (all displays combined)
    /// - Returns: Captured image as CGImage
    static func captureAllScreens() throws -> CGImage {
        guard !NSScreen.screens.isEmpty else {
            throw CaptureError.noScreensAvailable
        }

        // Get the bounding rect of all screens
        let allScreensRect = NSScreen.screens.reduce(CGRect.zero) { result, screen in
            result.union(screen.frame)
        }

        return try capture(rect: allScreensRect)
    }

    /// Check if screen recording permission is granted
    static var hasScreenRecordingPermission: Bool {
        // CGWindowListCreateImage returns an image even without permission
        // (showing only our own windows), so use the preflight API like
        // PermissionService does.
        CGPreflightScreenCaptureAccess()
    }

    /// Request screen recording permission by triggering a capture
    static func requestScreenRecordingPermission() {
        // Attempting to capture triggers the permission dialog
        _ = CGWindowListCreateImage(
            CGRect(x: 0, y: 0, width: 1, height: 1),
            .optionOnScreenOnly,
            kCGNullWindowID,
            .nominalResolution
        )
    }
}
