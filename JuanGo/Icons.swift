import SwiftUI

/// Every icon in JuanGo is an SF Symbol. `LIcon` keeps the call sites short and lets a few icons be given an
/// exact size; otherwise the symbol sizes and weights itself from the surrounding font like any `Image(systemName:)`.
struct LIcon: View {
    let name: String
    var size: CGFloat?
    var play: Bool?

    init(_ name: String, size: CGFloat? = nil, play: Bool? = nil) {
        self.name = name; self.size = size; self.play = play
    }

    var body: some View {
        let image = Image(systemName: name)
        Group {
            if let size {
                image.font(.system(size: size * 0.85)).frame(width: size, height: size)
            } else {
                image
            }
        }
        .symbolEffect(.breathe, isActive: play == true)
        .accessibilityHidden(true)
    }
}

extension Image {
    static func pulso(_ name: String, size: CGFloat = 20) -> Image { Image(systemName: name) }
}

extension Label where Title == Text, Icon == Image {
    /// Same as `Label(_:systemImage:)`; kept so the call sites didn't change when the icons went back to SF Symbols.
    init(_ title: String, pulso: String, size: CGFloat = 20) {
        self.init(title, systemImage: pulso)
    }
}

extension Button where Label == SwiftUI.Label<Text, Image> {
    /// Same as `Button(_:systemImage:action:)`.
    init(_ title: String, pulso: String, role: ButtonRole? = nil, action: @escaping () -> Void) {
        self.init(role: role, action: action) { SwiftUI.Label(title, systemImage: pulso) }
    }
}

/// `ContentUnavailableView` with a large symbol.
struct EmptyState: View {
    let title: String
    let icon: String
    var message: String?

    init(_ title: String, icon: String, message: String? = nil) {
        self.title = title; self.icon = icon; self.message = message
    }

    var body: some View {
        ContentUnavailableView {
            VStack(spacing: 10) {
                LIcon(icon, size: 44).foregroundStyle(.secondary)
                Text(title).font(.app(.title3, .bold))
            }
        } description: {
            if let message { Text(message) }
        }
    }
}

/// A grid built only from stacks: rows of `columns` equal-width cells.
struct StackGrid<Item, Cell: View>: View {
    let items: [Item]
    var columns: Int = 2
    var spacing: CGFloat = 12
    @ViewBuilder let cell: (Item) -> Cell

    var body: some View {
        VStack(spacing: spacing) {
            ForEach(Array(stride(from: 0, to: items.count, by: columns)), id: \.self) { start in
                HStack(spacing: spacing) {
                    ForEach(start..<(start + columns), id: \.self) { i in
                        if i < items.count {
                            cell(items[i]).frame(maxWidth: .infinity)
                        } else {
                            Color.clear.frame(maxWidth: .infinity, maxHeight: 1)
                        }
                    }
                }
            }
        }
    }
}
