import AppKit
import SwiftUI

struct HoverCursorModifier: ViewModifier {
    let cursor: NSCursor
    @State private var isHovering = false

    func body(content: Content) -> some View {
        content
            .onHover { hovering in
                if hovering {
                    guard !isHovering else { return }
                    cursor.push()
                    isHovering = true
                } else {
                    popIfNeeded()
                }
            }
            .onDisappear {
                popIfNeeded()
            }
    }

    private func popIfNeeded() {
        guard isHovering else { return }
        NSCursor.pop()
        isHovering = false
    }
}

extension View {
    func hoverCursor(_ cursor: NSCursor) -> some View {
        modifier(HoverCursorModifier(cursor: cursor))
    }

    func cyberCursor(_ cursor: NSCursor = .pointingHand) -> some View {
        hoverCursor(cursor)
    }
}
