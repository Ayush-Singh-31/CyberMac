import AppKit
import SwiftUI

struct CommandBox: View {
    let command: String
    var title: String = "Manual command"
    var collapsedByDefault: Bool = false
    @State private var isExpanded: Bool
    @State private var copied = false

    init(command: String, title: String = "Manual command", collapsedByDefault: Bool = false) {
        self.command = command
        self.title = title
        self.collapsedByDefault = collapsedByDefault
        _isExpanded = State(initialValue: !collapsedByDefault)
    }

    var body: some View {
        CyberPanel(accent: .cyan) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label(title, systemImage: "terminal")
                        .font(.headline)
                    Spacer()
                    if collapsedByDefault {
                        Button(isExpanded ? "Hide command" : "Show command") {
                            isExpanded.toggle()
                        }
                        .buttonStyle(CyberButtonStyle(.ghost, accent: .cyan))
                    }
                    Button {
                        copyCommand()
                    } label: {
                        Label(copied ? "Copied" : "Copy", systemImage: copied ? "checkmark" : "doc.on.doc")
                    }
                    .buttonStyle(CyberButtonStyle(.secondary, accent: .cyan))
                    .help("Copy command")
                }

                if isExpanded {
                    ScrollView([.horizontal, .vertical]) {
                        Text(command)
                            .font(.system(.callout, design: .monospaced))
                            .textSelection(.enabled)
                            .padding(16)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(maxHeight: 260)
                    .background(Color.black.opacity(0.28), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(.white.opacity(0.08), lineWidth: 1)
                    }
                }
            }
        }
    }

    private func copyCommand() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(command, forType: .string)
        copied = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            copied = false
        }
    }
}
