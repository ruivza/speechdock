import SwiftUI

/// One system material, with an opaque semantic surface for accessibility modes.
struct PanelSurface: View {
    var opaque = false
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast
    var body: some View {
        if opaque || reduceTransparency || contrast == .increased {
            Color(nsColor: .windowBackgroundColor)
        } else {
            Rectangle().fill(.regularMaterial)
        }
    }
}
