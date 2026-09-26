import AppKit
import SwiftUI
import XCTest
@testable import SpeechDock

@MainActor
final class PanelAppearanceTests: XCTestCase {
    func testPanelAppearanceVariants() throws {
        let state = AppState(startServices: false)
        for (name, appearance, opaque) in [
            ("light", NSAppearance.Name.aqua, false),
            ("dark", NSAppearance.Name.darkAqua, false),
            ("opaque", NSAppearance.Name.aqua, true),
            ("contrast-dark", NSAppearance.Name.accessibilityHighContrastDarkAqua, true)
        ] {
            state.panelStyle = opaque ? .standardWindow : .floating
            let view = TTSFloatingView(appState: state, onClose: {})
            let host = NSHostingView(rootView: view)
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 920, height: 440), styleMask: .borderless, backing: .buffered, defer: false)
            window.isReleasedWhenClosed = false
            window.contentView = host
            window.appearance = NSAppearance(named: appearance)
            host.frame = NSRect(x: 0, y: 0, width: 920, height: 440)
            host.layoutSubtreeIfNeeded()
            let bitmap = try XCTUnwrap(host.bitmapImageRepForCachingDisplay(in: host.bounds))
            host.cacheDisplay(in: host.bounds, to: bitmap)
            let png = try XCTUnwrap(bitmap.representation(using: .png, properties: [:]), name)
            XCTAssertFalse(png.isEmpty, name)
            XCTAssertGreaterThan(bitmap.pixelsWide, 800)
            window.orderOut(nil)
        }
    }
}
