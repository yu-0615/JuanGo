import SwiftUI
import UIKit
import PulsoIcon

/// Every icon in Lexi is a PulsoIcon. Call sites keep the short SF-style names they always used,
/// and this table turns each one into a PulsoIcon key (plus whether to draw the solid version).
enum Icons {
    static let table: [String: (key: String, solid: Bool)] = [
        // navigation and chrome
        "sun.horizon.fill": ("sunrise", false),
        "sparkles.rectangle.stack.fill": ("sparkles", false),
        "sparkles": ("sparkles", false),
        "plus.circle.fill": ("circle-plus", false),
        "character.book.closed.fill": ("book-a", false),
        "character.book.closed": ("book-a", false),
        "person.crop.circle.fill": ("circle-user-round", false),
        "slider.horizontal.3": ("sliders-horizontal", false),
        "ellipsis": ("ellipsis", false),
        "xmark": ("x", false),
        "xmark.circle": ("circle-x", false),
        "xmark.circle.fill": ("circle-x", true),
        "checkmark": ("check", false),
        "checkmark.circle": ("circle-check", false),
        "checkmark.circle.fill": ("circle-check", true),
        "circle": ("circle", false),
        "questionmark": ("circle-question-mark", false),
        "questionmark.circle": ("circle-question-mark", false),
        "chevron.left": ("chevron-left", false),
        "chevron.right": ("chevron-right", false),
        "chevron.up": ("chevron-up", false),
        "chevron.down": ("chevron-down", false),
        "chevron.up.chevron.down": ("chevrons-up-down", false),
        "arrow.right": ("arrow-right", false),
        "arrow.up.right": ("arrow-up-right", false),
        "arrow.up.arrow.down": ("arrow-up-down", false),
        "arrow.uturn.backward": ("undo-2", false),
        "arrow.counterclockwise": ("rotate-ccw", false),
        "arrow.triangle.2.circlepath": ("refresh-cw", false),
        "arrow.down.right.and.arrow.up.left": ("minimize-2", false),
        "line.3.horizontal.decrease": ("list-filter", false),
        "line.3.horizontal.decrease.circle": ("list-filter", false),
        "line.3.horizontal.decrease.circle.fill": ("list-filter", false),
        "magnifyingglass": ("search", false),
        "plus": ("plus", false),
        "trash": ("trash", false),
        "square.and.pencil": ("square-pen", false),
        "square.and.arrow.up": ("share", false),
        "square.and.arrow.down.fill": ("download", false),
        // words and study
        "speaker.wave.2": ("volume-2", false),
        "speaker.wave.2.fill": ("volume-2", false),
        "speaker.wave.3.fill": ("volume-2", false),
        "speaker.slash.fill": ("volume-x", false),
        "heart": ("heart", false),
        "heart.fill": ("heart", true),
        "bookmark.fill": ("bookmark", true),
        "bookmark.slash": ("bookmark-x", false),
        "folder": ("folder", false),
        "folder.fill": ("folder", false),
        "folder.badge.plus": ("folder-plus", false),
        "flame.fill": ("flame", true),
        "drop.fill": ("droplet", true),
        "play.fill": ("play", true),
        "play.circle.fill": ("circle-play", false),
        "book.fill": ("book-open", false),
        "book.closed.fill": ("book", false),
        "book.pages": ("book-open-text", false),
        "text.book.closed": ("notebook-text", false),
        "checkmark.seal.fill": ("badge-check", false),
        "checklist": ("list-checks", false),
        "crown": ("crown", false),
        "chart.bar.fill": ("chart-column-big", false),
        "calendar": ("calendar", false),
        "clock": ("clock", false),
        "headphones": ("headphones", false),
        "wand.and.stars": ("wand-sparkles", false),
        "text.cursor": ("text-cursor-input", false),
        "tray": ("inbox", false),
        // import and scan
        "camera.viewfinder": ("scan", false),
        "photo.stack": ("images", false),
        "doc.text": ("file-text", false),
        "text.viewfinder": ("scan-text", false),
        "lasso": ("lasso", false),
        "hand.draw": ("hand", false),
        "hand.tap": ("pointer", false),
        // settings
        "smallcircle.filled.circle": ("target", false),
        "graduationcap.fill": ("graduation-cap", false),
        "bell.fill": ("bell", false),
        "bell.badge.fill": ("bell-ring", false),
        "list.bullet.rectangle.fill": ("list", false),
        "safari.fill": ("compass", false),
        "tortoise": ("turtle", false),
        "hare": ("rabbit", false),
    ]

    static func resolve(_ name: String) -> (icon: PulsoIcon, solid: Bool) {
        if let m = table[name], let icon = PulsoIcon.byKey(m.key) { return (icon, m.solid) }
        if let icon = PulsoIcon.byKey(name) { return (icon, false) }
        #if DEBUG
        print("⚠️ no PulsoIcon for \(name)")
        #endif
        return (.circle, false)
    }

    /// Stroke width that matches the surrounding font weight, so icons look as heavy as the text next to them.
    static func stroke(for weight: Font.Weight) -> CGFloat {
        switch weight {
        case .ultraLight, .thin: 1.4
        case .light: 1.7
        case .medium: 2.2
        case .semibold: 2.4
        case .bold: 2.6
        case .heavy, .black: 2.8
        default: 2
        }
    }
}

/// Drop-in replacement for `Image(systemName:)`: a PulsoIcon that sizes and weights itself from the
/// surrounding font (so it follows Dynamic Type like an SF Symbol) and takes the foreground style.
struct LIcon: View {
    let name: String
    var size: CGFloat?
    var play: Bool?
    @Environment(\.font) private var font
    @Environment(\.fontResolutionContext) private var fontContext

    init(_ name: String, size: CGFloat? = nil, play: Bool? = nil) {
        self.name = name; self.size = size; self.play = play
    }

    var body: some View {
        let (icon, solid) = Icons.resolve(name)
        let resolved = (font ?? .body).resolve(in: fontContext)
        PulsoIconView(icon, size: size ?? (resolved.pointSize * 1.2).rounded(),
                      strokeWidth: Icons.stroke(for: resolved.weight), solid: solid, play: play)
    }
}

/// PulsoIcons drawn into template images, for the places SwiftUI only accepts an `Image`
/// (tab bar, menus, toolbars, context menus). Cached, since the same few icons are drawn again and again.
@MainActor enum PulsoImageCache {
    static var images: [String: UIImage] = [:]

    static func image(_ name: String, size: CGFloat) -> Image {
        let key = "\(name)@\(size)"
        if let ui = images[key] { return Image(uiImage: ui) }
        let (icon, solid) = Icons.resolve(name)
        let renderer = ImageRenderer(content: PulsoIconView(icon, size: size, color: .black, strokeWidth: 2, solid: solid, animated: false))
        renderer.scale = UITraitCollection.current.displayScale > 0 ? UITraitCollection.current.displayScale : 3
        let ui = (renderer.uiImage ?? UIImage()).withRenderingMode(.alwaysTemplate)
        images[key] = ui
        return Image(uiImage: ui)
    }
}

extension Image {
    static func pulso(_ name: String, size: CGFloat = 20) -> Image { PulsoImageCache.image(name, size: size) }
}

extension Label where Title == Text, Icon == Image {
    /// `Label(_:systemImage:)` with a PulsoIcon.
    init(_ title: String, pulso: String, size: CGFloat = 20) {
        self.init { Text(title) } icon: { Image.pulso(pulso, size: size) }
    }
}

extension Button where Label == SwiftUI.Label<Text, Image> {
    /// `Button(_:systemImage:action:)` with a PulsoIcon.
    init(_ title: String, pulso: String, role: ButtonRole? = nil, action: @escaping () -> Void) {
        self.init(role: role, action: action) { SwiftUI.Label(title, pulso: pulso) }
    }
}

/// `ContentUnavailableView` with a PulsoIcon.
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
                Text(title).font(.title3.bold())
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
