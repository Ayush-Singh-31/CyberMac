import SwiftUI

struct PrimaryButton: View {
    let title: String
    let systemImage: String
    let disabled: Bool
    let variant: CyberButtonVariant
    let accent: CyberAccent
    let action: () -> Void

    init(
        title: String,
        systemImage: String,
        disabled: Bool,
        variant: CyberButtonVariant = .primary,
        accent: CyberAccent = .blue,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.systemImage = systemImage
        self.disabled = disabled
        self.variant = variant
        self.accent = accent
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
        }
        .buttonStyle(CyberButtonStyle(disabled ? .secondary : variant, accent: accent, minWidth: 150))
        .disabled(disabled)
        .opacity(disabled ? 0.48 : 1.0)
    }
}
