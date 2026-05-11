import SwiftUI

struct PrimaryButton: View {
    let title: String
    let systemImage: String
    let disabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.headline)
                .padding(.horizontal, 18)
                .padding(.vertical, 12)
                .frame(minWidth: 150)
        }
        .buttonStyle(.plain)
        .foregroundStyle(.white)
        .background(disabled ? Color.gray.opacity(0.35) : Color.accentColor, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .disabled(disabled)
    }
}
