import SwiftUI

struct SettingsWindow: View {
    @Bindable var navigation: SettingsNavigation

    var body: some View {
        UnifiedSettingsView(navigation: navigation)
            .frame(minWidth: 700, idealWidth: 850, maxWidth: .infinity, minHeight: 450, idealHeight: 500, maxHeight: .infinity)
    }
}
