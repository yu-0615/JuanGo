// Only the icons Lexi uses, copied from PulsoIcon (ISC License, see LICENSE) by scripts/trim.py.
// To add one: map it in Lexi/Icons.swift, then run scripts/trim.py again.

extension PulsoIcon {
    public static let arrowRight = PulsoIcon("ArrowRight", "arrow-right", nodes: [
        .path("M5 12h14", motion: IconMotion(.shoot, x: 1, a: 6, ox: 12, oy: 12)),
        .path("m12 5 7 7-7 7", motion: IconMotion(.shoot, x: 1, a: 6, ox: 12, oy: 12)),
    ], solid: [
        .path("M20.781 12.531l-6.75 6.75A0.75 0.75 0 0 1 12.75 18.75V12.75H3.75a0.75 0.75 0 0 1 0-1.5h9V5.25a0.75 0.75 0 0 1 1.281-0.531l6.75 6.75A0.75 0.75 0 0 1 20.781 12.531Z", motion: IconMotion(.shoot, x: 1, a: 6, ox: 12, oy: 12), stroke: false),
    ])
    public static let arrowUpDown = PulsoIcon("ArrowUpDown", "arrow-up-down", nodes: [
        .path("m21 16-4 4-4-4", motion: IconMotion(.slide, y: 1, a: 2, ox: 17, oy: 12)),
        .path("M17 20V4", motion: IconMotion(.slide, y: 1, a: 2, ox: 17, oy: 12)),
        .path("m3 8 4-4 4 4", motion: IconMotion(.slide, y: -1, a: 2, ox: 7, oy: 12)),
        .path("M7 4v16", motion: IconMotion(.slide, y: -1, a: 2, ox: 7, oy: 12)),
    ], solid: [
        .path("m21 16-4 4-4-4", motion: IconMotion(.slide, y: 1, a: 2, ox: 17, oy: 12), fill: false),
        .path("M17 20V4", motion: IconMotion(.slide, y: 1, a: 2, ox: 17, oy: 12), fill: false),
        .path("m3 8 4-4 4 4", motion: IconMotion(.slide, y: -1, a: 2, ox: 7, oy: 12), fill: false),
        .path("M7 4v16", motion: IconMotion(.slide, y: -1, a: 2, ox: 7, oy: 12), fill: false),
    ])
    public static let arrowUpRight = PulsoIcon("ArrowUpRight", "arrow-up-right", nodes: [
        .path("M7 7h10v10", motion: IconMotion(.shoot, x: 1, y: -1, a: 5, ox: 12, oy: 12)),
        .path("M7 17 17 7", motion: IconMotion(.shoot, x: 1, y: -1, a: 5, ox: 12, oy: 12)),
    ], solid: [
        .path("M18.75 6V15.75a0.75 0.75 0 0 1-1.281 0.531L13.125 11.935 6.531 18.531a0.75 0.75 0 0 1-1.061-1.061L12.065 10.875 7.719 6.531A0.75 0.75 0 0 1 8.25 5.25H18A0.75 0.75 0 0 1 18.75 6Z", motion: IconMotion(.shoot, x: 1, y: -1, a: 5, ox: 12, oy: 12), stroke: false),
    ])
    public static let badgeCheck = PulsoIcon("BadgeCheck", "badge-check", nodes: [
        .path("M3.85 8.62a4 4 0 0 1 4.78-4.77 4 4 0 0 1 6.74 0 4 4 0 0 1 4.78 4.78 4 4 0 0 1 0 6.74 4 4 0 0 1-4.77 4.78 4 4 0 0 1-6.75 0 4 4 0 0 1-4.78-4.77 4 4 0 0 1 0-6.76Z", motion: IconMotion(.press, a: 0.08, ox: 11.992, oy: 12.004)),
        .path("m16 9-5.5 5.5L8 12", motion: IconMotion(.draw, d: 0.15, ox: 12, oy: 11.75)),
    ], solid: [
        .path("M3.85 8.62a4 4 0 0 1 4.78-4.77 4 4 0 0 1 6.74 0 4 4 0 0 1 4.78 4.78 4 4 0 0 1 0 6.74 4 4 0 0 1-4.77 4.78 4 4 0 0 1-6.75 0 4 4 0 0 1-4.78-4.77 4 4 0 0 1 0-6.76Z", motion: IconMotion(.press, a: 0.08, ox: 11.992, oy: 12.004)),
        .path("m16 9-5.5 5.5L8 12", motion: IconMotion(.draw, d: 0.15, ox: 12, oy: 11.75), role: .line),
    ])
    public static let bell = PulsoIcon("Bell", "bell", nodes: [
        .path("M10.268 21a2 2 0 0 0 3.464 0", motion: IconMotion(.slide, d: 0.08, x: 1, a: 1.5, ox: 12, oy: 21.5)),
        .path("M3.262 15.326A1 1 0 0 0 4 17h16a1 1 0 0 0 .74-1.673C19.41 13.956 18 12.499 18 8A6 6 0 0 0 6 8c0 4.499-1.411 5.956-2.738 7.326", motion: IconMotion(.ring, a: 16, ox: 12, oy: 3)),
    ], solid: [
        .path("M10.268 21a2 2 0 0 0 3.464 0", motion: IconMotion(.slide, d: 0.08, x: 1, a: 1.5, ox: 12, oy: 21.5), fill: false),
        .path("M3.262 15.326A1 1 0 0 0 4 17h16a1 1 0 0 0 .74-1.673C19.41 13.956 18 12.499 18 8A6 6 0 0 0 6 8c0 4.499-1.411 5.956-2.738 7.326", motion: IconMotion(.ring, a: 16, ox: 12, oy: 3)),
    ])
    public static let bellRing = PulsoIcon("BellRing", "bell-ring", nodes: [
        .path("M10.268 21a2 2 0 0 0 3.464 0", motion: IconMotion(.ring, ox: 12, oy: 3)),
        .path("M22 8c0-2.3-.8-4.3-2-6", motion: IconMotion(.slide, d: 0.1, x: 1, a: 1.5, ox: 21, oy: 5)),
        .path("M3.262 15.326A1 1 0 0 0 4 17h16a1 1 0 0 0 .74-1.673C19.41 13.956 18 12.499 18 8A6 6 0 0 0 6 8c0 4.499-1.411 5.956-2.738 7.326", motion: IconMotion(.ring, ox: 12, oy: 3)),
        .path("M4 2C2.8 3.7 2 5.7 2 8", motion: IconMotion(.slide, d: 0.1, x: -1, a: 1.5, ox: 3, oy: 5)),
    ], solid: [
        .path("M10.268 21a2 2 0 0 0 3.464 0", motion: IconMotion(.ring, ox: 12, oy: 3), fill: false),
        .path("M22 8c0-2.3-.8-4.3-2-6", motion: IconMotion(.slide, d: 0.1, x: 1, a: 1.5, ox: 21, oy: 5), fill: false),
        .path("M3.262 15.326A1 1 0 0 0 4 17h16a1 1 0 0 0 .74-1.673C19.41 13.956 18 12.499 18 8A6 6 0 0 0 6 8c0 4.499-1.411 5.956-2.738 7.326", motion: IconMotion(.ring, ox: 12, oy: 3)),
        .path("M4 2C2.8 3.7 2 5.7 2 8", motion: IconMotion(.slide, d: 0.1, x: -1, a: 1.5, ox: 3, oy: 5), fill: false),
    ])
    public static let book = PulsoIcon("Book", "book", nodes: [
        .path("M4 19.5v-15A2.5 2.5 0 0 1 6.5 2H19a1 1 0 0 1 1 1v18a1 1 0 0 1-1 1H6.5a1 1 0 0 1 0-5H20", motion: IconMotion(.open, ox: 4, oy: 12)),
    ], solid: [
        .path("M4 19.5v-15A2.5 2.5 0 0 1 6.5 2H19a1 1 0 0 1 1 1v18a1 1 0 0 1-1 1H6.5A2.5 2.5 0 0 1 4 19.5z", motion: IconMotion(.open, ox: 4, oy: 12)),
        .path("M20 17H7", motion: IconMotion(.open, ox: 4, oy: 12), role: .cut),
    ])
    public static let bookA = PulsoIcon("BookA", "book-a", nodes: [
        .path("M4 19.5v-15A2.5 2.5 0 0 1 6.5 2H19a1 1 0 0 1 1 1v18a1 1 0 0 1-1 1H6.5a1 1 0 0 1 0-5H20", motion: IconMotion(.press, a: 0.05, ox: 12, oy: 12)),
        .path("m8 13 4-7 4 7", motion: IconMotion(.draw, d: 0.1, ox: 12, oy: 9.5)),
        .path("M9.1 11h5.7", motion: IconMotion(.growX, d: 0.3, ox: 11.95, oy: 11)),
    ], solid: [
        .path("M4 19.5v-15A2.5 2.5 0 0 1 6.5 2H19a1 1 0 0 1 1 1v18a1 1 0 0 1-1 1H6.5a1 1 0 0 1 0-5H20", motion: IconMotion(.press, a: 0.05, ox: 12, oy: 12), fill: false),
        .path("m8 13 4-7 4 7", motion: IconMotion(.draw, d: 0.1, ox: 12, oy: 9.5), fill: false),
        .path("M9.1 11h5.7", motion: IconMotion(.growX, d: 0.3, ox: 11.95, oy: 11), fill: false),
    ])
    public static let bookOpen = PulsoIcon("BookOpen", "book-open", nodes: [
        .path("M12 5v16", motion: IconMotion(.fade, ox: 12, oy: 13)),
        .path("M20.001 19A2 2 0 0022 17V5a2 2 0 00-1.999-2L16 3.002A5 5 0 0012 5a5 5 0 00-4-2H4a2 2 0 00-2 2v12a2 2 0 001.999 2H8a5 5 0 014 2 5 5 0 014-2z", motion: IconMotion(.open, ox: 12, oy: 12)),
    ], solid: [
        .path("M12 5v16", motion: IconMotion(.fade, ox: 12, oy: 13), role: .line),
        .path("M20.001 19A2 2 0 0022 17V5a2 2 0 00-1.999-2L16 3.002A5 5 0 0012 5a5 5 0 00-4-2H4a2 2 0 00-2 2v12a2 2 0 001.999 2H8a5 5 0 014 2 5 5 0 014-2z", motion: IconMotion(.open, ox: 12, oy: 12)),
    ])
    public static let bookOpenText = PulsoIcon("BookOpenText", "book-open-text", nodes: [
        .path("M12 5v16", motion: IconMotion(.press, a: 0.05, ox: 12, oy: 21)),
        .path("M16 13h2", motion: IconMotion(.growX, d: 0.1, ox: 17, oy: 13)),
        .path("M16 9h2", motion: IconMotion(.growX, d: 0.16, ox: 17, oy: 9)),
        .path("M20.001 19A2 2 0 0022 17V5a2 2 0 00-1.999-2L16 3.002A5 5 0 0012 5a5 5 0 00-4-2H4a2 2 0 00-2 2v12a2 2 0 001.999 2H8a5 5 0 014 2 5 5 0 014-2z", motion: IconMotion(.press, a: 0.05, ox: 12, oy: 21)),
        .path("M6 13h2", motion: IconMotion(.growX, d: 0.22, ox: 7, oy: 13)),
        .path("M6 9h2", motion: IconMotion(.growX, d: 0.28, ox: 7, oy: 9)),
    ], solid: [
        .path("M12 5v16", motion: IconMotion(.press, a: 0.05, ox: 12, oy: 21), role: .line),
        .path("M16 13h2", motion: IconMotion(.growX, d: 0.1, ox: 17, oy: 13), role: .line),
        .path("M16 9h2", motion: IconMotion(.growX, d: 0.16, ox: 17, oy: 9), role: .line),
        .path("M20.001 19A2 2 0 0022 17V5a2 2 0 00-1.999-2L16 3.002A5 5 0 0012 5a5 5 0 00-4-2H4a2 2 0 00-2 2v12a2 2 0 001.999 2H8a5 5 0 014 2 5 5 0 014-2z", motion: IconMotion(.press, a: 0.05, ox: 12, oy: 21)),
        .path("M6 13h2", motion: IconMotion(.growX, d: 0.22, ox: 7, oy: 13), role: .line),
        .path("M6 9h2", motion: IconMotion(.growX, d: 0.28, ox: 7, oy: 9), role: .line),
    ])
    public static let bookmark = PulsoIcon("Bookmark", "bookmark", nodes: [
        .path("M17 3a2 2 0 0 1 2 2v15a1 1 0 0 1-1.496.868l-4.512-2.578a2 2 0 0 0-1.984 0l-4.512 2.578A1 1 0 0 1 5 20V5a2 2 0 0 1 2-2z", motion: IconMotion(.drop, a: 3, ox: 12, oy: 12)),
    ], solid: [
        .path("M14 2a5 5 0 0 1 5 5v14a1 1 0 0 1 -1.555 .832l-5.445 -3.63l-5.444 3.63a1 1 0 0 1 -1.55 -.72l-.006 -.112v-14a5 5 0 0 1 5 -5h4z", motion: IconMotion(.drop, a: 3, ox: 12, oy: 12), stroke: false),
    ])
    public static let bookmarkX = PulsoIcon("BookmarkX", "bookmark-x", nodes: [
        .path("m14.5 7.5-5 5", motion: IconMotion(.draw, d: 0.1, ox: 12, oy: 10)),
        .path("M17 3a2 2 0 0 1 2 2v15a1 1 0 0 1-1.496.868l-4.512-2.578a2 2 0 0 0-1.984 0l-4.512 2.578A1 1 0 0 1 5 20V5a2 2 0 0 1 2-2z", motion: IconMotion(.shake, a: 1, ox: 12, oy: 12)),
        .path("m9.5 7.5 5 5", motion: IconMotion(.draw, d: 0.2, ox: 12, oy: 10)),
    ], solid: [
        .path("m14.5 7.5-5 5", motion: IconMotion(.draw, d: 0.1, ox: 12, oy: 10), role: .line),
        .path("M17 3a2 2 0 0 1 2 2v15a1 1 0 0 1-1.496.868l-4.512-2.578a2 2 0 0 0-1.984 0l-4.512 2.578A1 1 0 0 1 5 20V5a2 2 0 0 1 2-2z", motion: IconMotion(.shake, a: 1, ox: 12, oy: 12)),
        .path("m9.5 7.5 5 5", motion: IconMotion(.draw, d: 0.2, ox: 12, oy: 10), role: .line),
    ])
    public static let calendar = PulsoIcon("Calendar", "calendar", nodes: [
        .path("M8 2v3", motion: IconMotion(.lift, ox: 8, oy: 3.5)),
        .path("M16 2v3", motion: IconMotion(.lift, d: 0.08, ox: 16, oy: 3.5)),
        .rect(3, 3, 18, 18, rx: 2, ry: 2, motion: IconMotion(.press, a: 0.05, ox: 12, oy: 21)),
        .path("M3 9h18", motion: IconMotion(.redraw, d: 0.15, ox: 12, oy: 9)),
    ], solid: [
        .path("M8 2v3", motion: IconMotion(.lift, ox: 8, oy: 3.5), role: .line),
        .path("M16 2v3", motion: IconMotion(.lift, d: 0.08, ox: 16, oy: 3.5), role: .line),
        .rect(3, 3, 18, 18, rx: 2, ry: 2, motion: IconMotion(.press, a: 0.05, ox: 12, oy: 21)),
        .path("M3 9h18", motion: IconMotion(.redraw, d: 0.15, ox: 12, oy: 9), role: .line),
    ])
    public static let chartColumnBig = PulsoIcon("ChartColumnBig", "chart-column-big", nodes: [
        .path("M3 3v16a2 2 0 0 0 2 2h16", motion: IconMotion(.fade, ox: 12, oy: 12)),
        .rect(15, 5, 4, 12, rx: 1, ry: 1, motion: IconMotion(.grow, d: 0.1, ox: 17, oy: 17)),
        .rect(7, 8, 4, 9, rx: 1, ry: 1, motion: IconMotion(.grow, ox: 9, oy: 17)),
    ], solid: [
        .path("M3 3v16a2 2 0 0 0 2 2h16", motion: IconMotion(.fade, ox: 12, oy: 12), fill: false),
        .rect(15, 5, 4, 12, rx: 1, ry: 1, motion: IconMotion(.grow, d: 0.1, ox: 17, oy: 17)),
        .rect(7, 8, 4, 9, rx: 1, ry: 1, motion: IconMotion(.grow, ox: 9, oy: 17)),
    ])
    public static let check = PulsoIcon("Check", "check", nodes: [
        .path("M20 6 9 17l-5-5", motion: IconMotion(.draw, ox: 12, oy: 11.5)),
    ], solid: [
        .path("M20.707 6.293a1 1 0 0 1 0 1.414l-10 10a1 1 0 0 1 -1.414 0l-5 -5a1 1 0 0 1 1.414 -1.414l4.293 4.293l9.293 -9.293a1 1 0 0 1 1.414 0", motion: IconMotion(.draw, ox: 12, oy: 11.5), stroke: false),
    ])
    public static let chevronDown = PulsoIcon("ChevronDown", "chevron-down", nodes: [
        .path("m6 9 6 6 6-6", motion: IconMotion(.bounce, y: 1, a: 2, ox: 12, oy: 12)),
    ], solid: [
        .path("M18.707 8.293a1 1 0 0 1 0 1.414l-6 6a1 1 0 0 1 -1.414 0l-6 -6a1 1 0 0 1 1.414 -1.414l5.293 5.293l5.293 -5.293a1 1 0 0 1 1.414 0", motion: IconMotion(.bounce, y: 1, a: 2, ox: 12, oy: 12), stroke: false),
    ])
    public static let chevronLeft = PulsoIcon("ChevronLeft", "chevron-left", nodes: [
        .path("m15 18-6-6 6-6", motion: IconMotion(.bounce, x: -1, a: 2, ox: 12, oy: 12)),
    ], solid: [
        .path("m15 18-6-6 6-6", motion: IconMotion(.bounce, x: -1, a: 2, ox: 12, oy: 12), fill: false),
    ])
    public static let chevronRight = PulsoIcon("ChevronRight", "chevron-right", nodes: [
        .path("m9 18 6-6-6-6", motion: IconMotion(.bounce, x: 1, a: 2, ox: 12, oy: 12)),
    ], solid: [
        .path("M9.707 5.293l6 6a1 1 0 0 1 0 1.414l-6 6a1 1 0 1 1 -1.414 -1.414l5.293 -5.293l-5.293 -5.293a1 1 0 0 1 1.414 -1.414", motion: IconMotion(.bounce, x: 1, a: 2, ox: 12, oy: 12), stroke: false),
    ])
    public static let chevronUp = PulsoIcon("ChevronUp", "chevron-up", nodes: [
        .path("m18 15-6-6-6 6", motion: IconMotion(.bounce, y: -1, a: 2, ox: 12, oy: 12)),
    ], solid: [
        .path("m18 15-6-6-6 6", motion: IconMotion(.bounce, y: -1, a: 2, ox: 12, oy: 12), fill: false),
    ])
    public static let chevronsUpDown = PulsoIcon("ChevronsUpDown", "chevrons-up-down", nodes: [
        .path("m7 15 5 5 5-5", motion: IconMotion(.slide, y: 1, a: 2, ox: 12, oy: 17.5)),
        .path("m7 9 5-5 5 5", motion: IconMotion(.slide, y: -1, a: 2, ox: 12, oy: 6.5)),
    ], solid: [
        .path("m7 15 5 5 5-5", motion: IconMotion(.slide, y: 1, a: 2, ox: 12, oy: 17.5), fill: false),
        .path("m7 9 5-5 5 5", motion: IconMotion(.slide, y: -1, a: 2, ox: 12, oy: 6.5), fill: false),
    ])
    public static let circle = PulsoIcon("Circle", "circle", nodes: [
        .circle(12, 12, 10, motion: IconMotion(.draw, ox: 12, oy: 12)),
    ], solid: [
        .path("M7 3.34a10 10 0 1 1 -4.995 8.984l-.005 -.324l.005 -.324a10 10 0 0 1 4.995 -8.336z", motion: IconMotion(.draw, ox: 12, oy: 12), stroke: false),
    ])
    public static let circleCheck = PulsoIcon("CircleCheck", "circle-check", nodes: [
        .circle(12, 12, 10, motion: IconMotion(.press, a: 0.05, ox: 12, oy: 12)),
        .path("m16 9-5.5 5.5L8 12", motion: IconMotion(.draw, d: 0.1, ox: 12, oy: 11.75)),
    ], solid: [
        .circle(12, 12, 10, motion: IconMotion(.press, a: 0.05, ox: 12, oy: 12)),
        .path("m16 9-5.5 5.5L8 12", motion: IconMotion(.draw, d: 0.1, ox: 12, oy: 11.75), role: .line),
    ])
    public static let circlePlay = PulsoIcon("CirclePlay", "circle-play", nodes: [
        .path("M9 9.003a1 1 0 0 1 1.517-.859l4.997 2.997a1 1 0 0 1 0 1.718l-4.997 2.997A1 1 0 0 1 9 14.996z", motion: IconMotion(.pop, d: 0.1, a: 0.3, ox: 12, oy: 12)),
        .circle(12, 12, 10, motion: IconMotion(.press, a: 0.05, ox: 12, oy: 12)),
    ], solid: [
        .path("M9 9.003a1 1 0 0 1 1.517-.859l4.997 2.997a1 1 0 0 1 0 1.718l-4.997 2.997A1 1 0 0 1 9 14.996z", motion: IconMotion(.pop, d: 0.1, a: 0.3, ox: 12, oy: 12), role: .cut),
        .circle(12, 12, 10, motion: IconMotion(.press, a: 0.05, ox: 12, oy: 12)),
    ])
    public static let circlePlus = PulsoIcon("CirclePlus", "circle-plus", nodes: [
        .circle(12, 12, 10, motion: IconMotion(.press, a: 0.05, ox: 12, oy: 12)),
        .path("M8 12h8", motion: IconMotion(.spin, d: 0.1, a: 90, ox: 12, oy: 12)),
        .path("M12 8v8", motion: IconMotion(.spin, d: 0.1, a: 90, ox: 12, oy: 12)),
    ], solid: [
        .circle(12, 12, 10, motion: IconMotion(.press, a: 0.05, ox: 12, oy: 12)),
        .path("M8 12h8", motion: IconMotion(.spin, d: 0.1, a: 90, ox: 12, oy: 12), role: .line),
        .path("M12 8v8", motion: IconMotion(.spin, d: 0.1, a: 90, ox: 12, oy: 12), role: .line),
    ])
    public static let circleQuestionMark = PulsoIcon("CircleQuestionMark", "circle-question-mark", nodes: [
        .circle(12, 12, 10, motion: IconMotion(.wobble, ox: 12, oy: 12)),
        .path("M9.09 9a3 3 0 0 1 5.83 1c0 2-3 3-3 3", motion: IconMotion(.draw, d: 0.1, ox: 12.005, oy: 9.998)),
        .path("M12 17h.01", motion: IconMotion(.drop, d: 0.3, ox: 12.005, oy: 17)),
    ], solid: [
        .circle(12, 12, 10, motion: IconMotion(.wobble, ox: 12, oy: 12)),
        .path("M9.09 9a3 3 0 0 1 5.83 1c0 2-3 3-3 3", motion: IconMotion(.draw, d: 0.1, ox: 12.005, oy: 9.998), role: .line),
        .path("M12 17h.01", motion: IconMotion(.drop, d: 0.3, ox: 12.005, oy: 17), role: .line),
    ])
    public static let circleUserRound = PulsoIcon("CircleUserRound", "circle-user-round", nodes: [
        .path("M17.925 20.056a6 6 0 0 0-11.851.001", motion: IconMotion(.rise, d: 0.1, a: 1, ox: 12, oy: 17.528)),
        .circle(12, 11, 4, motion: IconMotion(.float, a: 1.5, ox: 12, oy: 11)),
        .circle(12, 12, 10, motion: IconMotion(.press, a: 0.04, ox: 12, oy: 12)),
    ], solid: [
        .path("M17.925 20.056a6 6 0 0 0-11.851.001", motion: IconMotion(.rise, d: 0.1, a: 1, ox: 12, oy: 17.528), role: .cut),
        .circle(12, 11, 4, motion: IconMotion(.float, a: 1.5, ox: 12, oy: 11), role: .cut),
        .circle(12, 12, 10, motion: IconMotion(.press, a: 0.04, ox: 12, oy: 12)),
    ])
    public static let circleX = PulsoIcon("CircleX", "circle-x", nodes: [
        .circle(12, 12, 10, motion: IconMotion(.spin, a: 90, ox: 12, oy: 12)),
        .path("m15 9-6 6", motion: IconMotion(.draw, d: 0.15, ox: 12, oy: 12)),
        .path("m9 9 6 6", motion: IconMotion(.draw, d: 0.25, ox: 12, oy: 12)),
    ], solid: [
        .circle(12, 12, 10, motion: IconMotion(.spin, a: 90, ox: 12, oy: 12)),
        .path("m15 9-6 6", motion: IconMotion(.draw, d: 0.15, ox: 12, oy: 12), role: .line),
        .path("m9 9 6 6", motion: IconMotion(.draw, d: 0.25, ox: 12, oy: 12), role: .line),
    ])
    public static let clock = PulsoIcon("Clock", "clock", nodes: [
        .circle(12, 12, 10, motion: IconMotion(.press, a: 0.04, ox: 12, oy: 12)),
        .path("M12 6v6l4 2", motion: IconMotion(.spin, a: 360, ox: 12, oy: 12)),
    ], solid: [
        .circle(12, 12, 10, motion: IconMotion(.press, a: 0.04, ox: 12, oy: 12)),
        .path("M12 6v6l4 2", motion: IconMotion(.spin, a: 360, ox: 12, oy: 12), role: .line),
    ])
    public static let compass = PulsoIcon("Compass", "compass", nodes: [
        .circle(12, 12, 10, motion: IconMotion(.press, a: 0.04, ox: 12, oy: 12)),
        .path("m16.24 7.76-1.804 5.411a2 2 0 0 1-1.265 1.265L7.76 16.24l1.804-5.411a2 2 0 0 1 1.265-1.265z", motion: IconMotion(.spin, d: 0.05, a: 360, ox: 12, oy: 12)),
    ], solid: [
        .circle(12, 12, 10, motion: IconMotion(.press, a: 0.04, ox: 12, oy: 12)),
        .path("m16.24 7.76-1.804 5.411a2 2 0 0 1-1.265 1.265L7.76 16.24l1.804-5.411a2 2 0 0 1 1.265-1.265z", motion: IconMotion(.spin, d: 0.05, a: 360, ox: 12, oy: 12), role: .cut),
    ])
    public static let crown = PulsoIcon("Crown", "crown", nodes: [
        .path("M11.562 3.266a.5.5 0 0 1 .876 0L15.39 8.87a1 1 0 0 0 1.516.294L21.183 5.5a.5.5 0 0 1 .798.519l-2.834 10.246a1 1 0 0 1-.956.734H5.81a1 1 0 0 1-.957-.734L2.02 6.02a.5.5 0 0 1 .798-.519l4.276 3.664a1 1 0 0 0 1.516-.294z", motion: IconMotion(.float, a: 2, ox: 12.001, oy: 10.003)),
        .path("M5 21h14", motion: IconMotion(.growX, d: 0.15, ox: 12, oy: 21)),
    ], solid: [
        .path("M11.562 3.266a.5.5 0 0 1 .876 0L15.39 8.87a1 1 0 0 0 1.516.294L21.183 5.5a.5.5 0 0 1 .798.519l-2.834 10.246a1 1 0 0 1-.956.734H5.81a1 1 0 0 1-.957-.734L2.02 6.02a.5.5 0 0 1 .798-.519l4.276 3.664a1 1 0 0 0 1.516-.294z", motion: IconMotion(.float, a: 2, ox: 12.001, oy: 10.003)),
        .path("M5 21h14", motion: IconMotion(.growX, d: 0.15, ox: 12, oy: 21), fill: false),
    ])
    public static let dices = PulsoIcon("Dices", "dices", nodes: [
        .rect(2, 10, 12, 12, rx: 2, ry: 2, motion: IconMotion(.spin, a: -90, ox: 8, oy: 16)),
        .path("m17.92 14 3.5-3.5a2.24 2.24 0 0 0 0-3l-5-4.92a2.24 2.24 0 0 0-3 0L10 6", motion: IconMotion(.spin, d: 0.1, a: 90, ox: 16, oy: 8)),
        .path("M6 18h.01", motion: IconMotion(.spin, a: -90, ox: 8, oy: 16)),
        .path("M10 14h.01", motion: IconMotion(.spin, a: -90, ox: 8, oy: 16)),
        .path("M15 6h.01", motion: IconMotion(.spin, d: 0.1, a: 90, ox: 16, oy: 8)),
        .path("M18 9h.01", motion: IconMotion(.spin, d: 0.1, a: 90, ox: 16, oy: 8)),
    ], solid: [
        .rect(2, 10, 12, 12, rx: 2, ry: 2, motion: IconMotion(.spin, a: -90, ox: 8, oy: 16)),
        .path("m17.92 14 3.5-3.5a2.24 2.24 0 0 0 0-3l-5-4.92a2.24 2.24 0 0 0-3 0L10 6", motion: IconMotion(.spin, d: 0.1, a: 90, ox: 16, oy: 8), fill: false),
        .path("M6 18h.01", motion: IconMotion(.spin, a: -90, ox: 8, oy: 16), role: .line),
        .path("M10 14h.01", motion: IconMotion(.spin, a: -90, ox: 8, oy: 16), role: .line),
        .path("M15 6h.01", motion: IconMotion(.spin, d: 0.1, a: 90, ox: 16, oy: 8), fill: false),
        .path("M18 9h.01", motion: IconMotion(.spin, d: 0.1, a: 90, ox: 16, oy: 8), fill: false),
    ])
    public static let download = PulsoIcon("Download", "download", nodes: [
        .path("M12 15V3", motion: IconMotion(.bounce, y: 1, a: 3, ox: 12, oy: 9)),
        .path("M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4", motion: IconMotion(.press, d: 0.15, a: 0.06, ox: 12, oy: 21)),
        .path("m7 10 5 5 5-5", motion: IconMotion(.bounce, y: 1, a: 3, ox: 12, oy: 9)),
    ], solid: [
        .path("M12 15V3", motion: IconMotion(.bounce, y: 1, a: 3, ox: 12, oy: 9), fill: false),
        .path("M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4", motion: IconMotion(.press, d: 0.15, a: 0.06, ox: 12, oy: 21), fill: false),
        .path("m7 10 5 5 5-5", motion: IconMotion(.bounce, y: 1, a: 3, ox: 12, oy: 9), fill: false),
    ])
    public static let droplet = PulsoIcon("Droplet", "droplet", nodes: [
        .path("M12 22a7 7 0 0 0 7-7c0-2-1-3.9-3-5.5s-3.5-4-4-6.5c-.5 2.5-2 4.9-4 6.5C6 11.1 5 13 5 15a7 7 0 0 0 7 7z", motion: IconMotion(.drop, a: 4, ox: 12, oy: 12.5)),
    ], solid: [
        .path("M10.708 2.372a2.382 2.382 0 0 0 -.71 .686l-4.892 7.26c-1.981 3.314 -1.22 7.466 1.767 9.882c2.969 2.402 7.286 2.402 10.254 0c2.987 -2.416 3.748 -6.569 1.795 -9.836l-4.919 -7.306c-.722 -1.075 -2.192 -1.376 -3.295 -.686z", motion: IconMotion(.drop, a: 4, ox: 12, oy: 12.5), stroke: false),
    ])
    public static let ellipsis = PulsoIcon("Ellipsis", "ellipsis", nodes: [
        .circle(12, 12, 1, motion: IconMotion(.bounce, d: 0.08, y: -1, a: 1.5, ox: 12, oy: 12)),
        .circle(19, 12, 1, motion: IconMotion(.bounce, d: 0.16, y: -1, a: 1.5, ox: 19, oy: 12)),
        .circle(5, 12, 1, motion: IconMotion(.bounce, y: -1, a: 1.5, ox: 5, oy: 12)),
    ], solid: [
        .circle(12, 12, 1, motion: IconMotion(.bounce, d: 0.08, y: -1, a: 1.5, ox: 12, oy: 12)),
        .circle(19, 12, 1, motion: IconMotion(.bounce, d: 0.16, y: -1, a: 1.5, ox: 19, oy: 12)),
        .circle(5, 12, 1, motion: IconMotion(.bounce, y: -1, a: 1.5, ox: 5, oy: 12)),
    ])
    public static let fileText = PulsoIcon("FileText", "file-text", nodes: [
        .path("M6 22a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2h8a2.4 2.4 0 0 1 1.704.706l3.588 3.588A2.4 2.4 0 0 1 20 8v12a2 2 0 0 1-2 2z", motion: IconMotion(.press, a: 0.04, ox: 12, oy: 22)),
        .path("M14 2v5a1 1 0 0 0 1 1h5", motion: IconMotion(.fold, ox: 17, oy: 5)),
        .path("M10 9H8", motion: IconMotion(.growX, d: 0.1, ox: 8, oy: 13)),
        .path("M16 13H8", motion: IconMotion(.growX, d: 0.16, ox: 8, oy: 13)),
        .path("M16 17H8", motion: IconMotion(.growX, d: 0.22, ox: 8, oy: 13)),
    ], solid: [
        .path("M6 22a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2h8a2.4 2.4 0 0 1 1.704.706l3.588 3.588A2.4 2.4 0 0 1 20 8v12a2 2 0 0 1-2 2z", motion: IconMotion(.press, a: 0.04, ox: 12, oy: 22)),
        .path("M14 2v5a1 1 0 0 0 1 1h5", motion: IconMotion(.fold, ox: 17, oy: 5), role: .line),
        .path("M10 9H8", motion: IconMotion(.growX, d: 0.1, ox: 8, oy: 13), role: .line),
        .path("M16 13H8", motion: IconMotion(.growX, d: 0.16, ox: 8, oy: 13), role: .line),
        .path("M16 17H8", motion: IconMotion(.growX, d: 0.22, ox: 8, oy: 13), role: .line),
    ])
    public static let flame = PulsoIcon("Flame", "flame", nodes: [
        .path("M12 3q1 4 4 6.5t3 5.5a1 1 0 0 1-14 0 5 5 0 0 1 1-3 1 1 0 0 0 5 0c0-2-1.5-3-1.5-5q0-2 2.5-4", motion: IconMotion(.sway, a: 6, ox: 12, oy: 22)),
    ], solid: [
        .path("M10 2c0 -.88 1.056 -1.331 1.692 -.722c1.958 1.876 3.096 5.995 1.75 9.12l-.08 .174l.012 .003c.625 .133 1.203 -.43 2.303 -2.173l.14 -.224a1 1 0 0 1 1.582 -.153c1.334 1.435 2.601 4.377 2.601 6.27c0 4.265 -3.591 7.705 -8 7.705s-8 -3.44 -8 -7.706c0 -2.252 1.022 -4.716 2.632 -6.301l.605 -.589c.241 -.236 .434 -.43 .618 -.624c1.43 -1.512 2.145 -2.924 2.145 -4.78", motion: IconMotion(.sway, a: 6, ox: 12, oy: 22), stroke: false),
    ])
    public static let folder = PulsoIcon("Folder", "folder", nodes: [
        .path("M20 20a2 2 0 0 0 2-2V8a2 2 0 0 0-2-2h-7.9a2 2 0 0 1-1.69-.9L9.6 3.9A2 2 0 0 0 7.93 3H4a2 2 0 0 0-2 2v13a2 2 0 0 0 2 2Z", motion: IconMotion(.lift, ox: 12, oy: 11.5)),
    ], solid: [
        .path("M9 3a1 1 0 0 1 .608 .206l.1 .087l2.706 2.707h6.586a3 3 0 0 1 2.995 2.824l.005 .176v8a3 3 0 0 1 -2.824 2.995l-.176 .005h-14a3 3 0 0 1 -2.995 -2.824l-.005 -.176v-11a3 3 0 0 1 2.824 -2.995l.176 -.005h4z", motion: IconMotion(.lift, ox: 12, oy: 11.5), stroke: false),
    ])
    public static let folderPlus = PulsoIcon("FolderPlus", "folder-plus", nodes: [
        .path("M12 10v6", motion: IconMotion(.spin, d: 0.1, a: 90, ox: 12, oy: 13)),
        .path("M9 13h6", motion: IconMotion(.spin, d: 0.1, a: 90, ox: 12, oy: 13)),
        .path("M20 20a2 2 0 0 0 2-2V8a2 2 0 0 0-2-2h-7.9a2 2 0 0 1-1.69-.9L9.6 3.9A2 2 0 0 0 7.93 3H4a2 2 0 0 0-2 2v13a2 2 0 0 0 2 2Z", motion: IconMotion(.press, a: 0.04, ox: 12, oy: 20)),
    ], solid: [
        .path("M12 10v6", motion: IconMotion(.spin, d: 0.1, a: 90, ox: 12, oy: 13), role: .line),
        .path("M9 13h6", motion: IconMotion(.spin, d: 0.1, a: 90, ox: 12, oy: 13), role: .line),
        .path("M20 20a2 2 0 0 0 2-2V8a2 2 0 0 0-2-2h-7.9a2 2 0 0 1-1.69-.9L9.6 3.9A2 2 0 0 0 7.93 3H4a2 2 0 0 0-2 2v13a2 2 0 0 0 2 2Z", motion: IconMotion(.press, a: 0.04, ox: 12, oy: 20)),
    ])
    public static let graduationCap = PulsoIcon("GraduationCap", "graduation-cap", nodes: [
        .path("M21.42 10.922a1 1 0 0 0-.019-1.838L12.83 5.18a2 2 0 0 0-1.66 0L2.6 9.08a1 1 0 0 0 0 1.832l8.57 3.908a2 2 0 0 0 1.66 0z", motion: IconMotion(.float, a: 2, ox: 12.009, oy: 10)),
        .path("M22 10v6", motion: IconMotion(.swing, d: 0.05, a: 20, ox: 22, oy: 10)),
        .path("M6 12.5V16a6 3 0 0 0 12 0v-3.5", motion: IconMotion(.press, d: 0.1, a: 0.05, ox: 12, oy: 19)),
    ], solid: [
        .path("M21.42 10.922a1 1 0 0 0-.019-1.838L12.83 5.18a2 2 0 0 0-1.66 0L2.6 9.08a1 1 0 0 0 0 1.832l8.57 3.908a2 2 0 0 0 1.66 0z", motion: IconMotion(.float, a: 2, ox: 12.009, oy: 10)),
        .path("M22 10v6", motion: IconMotion(.swing, d: 0.05, a: 20, ox: 22, oy: 10), fill: false),
        .path("M6 12.5V16a6 3 0 0 0 12 0v-3.5", motion: IconMotion(.press, d: 0.1, a: 0.05, ox: 12, oy: 19), fill: false),
    ])
    public static let hand = PulsoIcon("Hand", "hand", svg: IconMotion(.ring, a: 10, ox: 12, oy: 20), nodes: [
        .path("M18 11V6a2 2 0 0 0-2-2a2 2 0 0 0-2 2"),
        .path("M14 10V4a2 2 0 0 0-2-2a2 2 0 0 0-2 2v2"),
        .path("M10 10.5V6a2 2 0 0 0-2-2a2 2 0 0 0-2 2v8"),
        .path("M18 8a2 2 0 1 1 4 0v6a8 8 0 0 1-8 8h-2c-2.8 0-4.5-.86-5.99-2.34l-3.6-3.6a2 2 0 0 1 2.83-2.82L7 15"),
    ], solid: [
        .path("M20.25 6v8.525c0 4.331-3.455 7.927-7.781 7.974A7.848 7.848 0 0 1 6.806 20.194C4.762 18.031 2.452 12.75 2.452 12.75a1.5 1.5 0 0 1 0.612-2.084c0.718-0.375 1.603-0.079 2.006 0.621l1.969 3.416a0.571 0.571 0 0 0 0.563 0.29l0.011 0A0.768 0.768 0 0 0 8.25 14.226V4.5a1.5 1.5 0 0 1 1.572-1.5c0.807 0.038 1.428 0.733 1.428 1.54V10.5a0.75 0.75 0 0 0 0.8 0.75 0.766 0.766 0 0 0 0.7-0.773V3a1.5 1.5 0 0 1 1.572-1.5c0.807 0.038 1.428 0.733 1.428 1.54V11.25a0.75 0.75 0 0 0 0.8 0.75 0.766 0.766 0 0 0 0.7-0.773V6.042c0-0.807 0.621-1.5 1.428-1.54A1.5 1.5 0 0 1 20.25 6Z", stroke: false),
    ])
    public static let headphones = PulsoIcon("Headphones", "headphones", nodes: [
        .path("M3 14h3a2 2 0 0 1 2 2v3a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-7a9 9 0 0 1 18 0v7a2 2 0 0 1-2 2h-1a2 2 0 0 1-2-2v-3a2 2 0 0 1 2-2h3", motion: IconMotion(.jelly, a: 0.1, ox: 12, oy: 21)),
    ], solid: [
        .path("M21 18a3 3 0 0 1 -2.824 2.995l-.176 .005h-1a3 3 0 0 1 -2.995 -2.824l-.005 -.176v-3a3 3 0 0 1 2.824 -2.995l.176 -.005h1c.351 0 .688 .06 1 .171v-.171a7 7 0 0 0 -13.996 -.24l-.004 .24v.17c.25 -.088 .516 -.144 .791 -.163l.209 -.007h1a3 3 0 0 1 2.995 2.824l.005 .176v3a3 3 0 0 1 -2.824 2.995l-.176 .005h-1a3 3 0 0 1 -2.995 -2.824l-.005 -.176v-6a9 9 0 0 1 17.996 -.265l.004 .265v6z", motion: IconMotion(.jelly, a: 0.1, ox: 12, oy: 21), stroke: false),
    ])
    public static let heart = PulsoIcon("Heart", "heart", nodes: [
        .path("M2 9.5a5.5 5.5 0 0 1 9.591-3.676.56.56 0 0 0 .818 0A5.49 5.49 0 0 1 22 9.5c0 2.29-1.5 4-3 5.5l-5.492 5.313a2 2 0 0 1-3 .019L5 15c-1.5-1.5-3-3.2-3-5.5", motion: IconMotion(.beat, a: 0.2, ox: 12, oy: 12.492)),
    ], solid: [
        .path("M6.979 3.074a6 6 0 0 1 4.988 1.425l.037 .033l.034 -.03a6 6 0 0 1 4.733 -1.44l.246 .036a6 6 0 0 1 3.364 10.008l-.18 .185l-.048 .041l-7.45 7.379a1 1 0 0 1 -1.313 .082l-.094 -.082l-7.493 -7.422a6 6 0 0 1 3.176 -10.215z", motion: IconMotion(.beat, a: 0.2, ox: 12, oy: 12.492), stroke: false),
    ])
    public static let images = PulsoIcon("Images", "images", nodes: [
        .path("m22 11-1.296-1.296a2.4 2.4 0 0 0-3.408 0L11 16", motion: IconMotion(.draw, d: 0.2, ox: 16.5, oy: 12.497)),
        .path("M4 8a2 2 0 0 0-2 2v10a2 2 0 0 0 2 2h10a2 2 0 0 0 2-2", motion: IconMotion(.slide, x: -1, y: 1, a: 1, ox: 9, oy: 15)),
        .circle(13, 7, 1, motion: IconMotion(.pop, d: 0.15, ox: 13, oy: 7), fill: true),
        .rect(8, 2, 14, 14, rx: 2, ry: 2, motion: IconMotion(.slide, x: 1, y: -1, a: 1, ox: 15, oy: 9)),
    ], solid: [
        .path("m22 11-1.296-1.296a2.4 2.4 0 0 0-3.408 0L11 16", motion: IconMotion(.draw, d: 0.2, ox: 16.5, oy: 12.497), role: .line),
        .path("M4 8a2 2 0 0 0-2 2v10a2 2 0 0 0 2 2h10a2 2 0 0 0 2-2", motion: IconMotion(.slide, x: -1, y: 1, a: 1, ox: 9, oy: 15), fill: false),
        .circle(13, 7, 1, motion: IconMotion(.pop, d: 0.15, ox: 13, oy: 7), fill: true, role: .cut),
        .rect(8, 2, 14, 14, rx: 2, ry: 2, motion: IconMotion(.slide, x: 1, y: -1, a: 1, ox: 15, oy: 9)),
    ])
    public static let inbox = PulsoIcon("Inbox", "inbox", nodes: [
        .polyline([22, 12, 16, 12, 14, 15, 10, 15, 8, 12, 2, 12], motion: IconMotion(.bounce, d: 0.05, y: 1, a: 1.5, ox: 12, oy: 13.5)),
        .path("M5.45 5.11 2 12v6a2 2 0 0 0 2 2h16a2 2 0 0 0 2-2v-6l-3.45-6.89A2 2 0 0 0 16.76 4H7.24a2 2 0 0 0-1.79 1.11z", motion: IconMotion(.press, a: 0.05, ox: 12, oy: 12)),
    ], solid: [
        .polyline([22, 12, 16, 12, 14, 15, 10, 15, 8, 12, 2, 12], motion: IconMotion(.bounce, d: 0.05, y: 1, a: 1.5, ox: 12, oy: 13.5), role: .line),
        .path("M5.45 5.11 2 12v6a2 2 0 0 0 2 2h16a2 2 0 0 0 2-2v-6l-3.45-6.89A2 2 0 0 0 16.76 4H7.24a2 2 0 0 0-1.79 1.11z", motion: IconMotion(.press, a: 0.05, ox: 12, oy: 12)),
    ])
    public static let infinity = PulsoIcon("Infinity", "infinity", nodes: [
        .path("M6 16c5 0 7-8 12-8a4 4 0 0 1 0 8c-5 0-7-8-12-8a4 4 0 1 0 0 8", motion: IconMotion(.redraw, ox: 12, oy: 12)),
    ], solid: [
        .path("M6 16c5 0 7-8 12-8a4 4 0 0 1 0 8c-5 0-7-8-12-8a4 4 0 1 0 0 8", motion: IconMotion(.redraw, ox: 12, oy: 12), fill: false),
    ])
    public static let lasso = PulsoIcon("Lasso", "lasso", nodes: [
        .path("M3.704 14.467a10 8 0 1 1 3.115 2.375", motion: IconMotion(.spin, a: 40, ox: 12, oy: 9)),
        .path("M7 22a5 5 0 0 1-2-3.994", motion: IconMotion(.swing, d: 0.1, a: 14, ox: 5, oy: 16)),
        .circle(5, 16, 2, motion: IconMotion(.swing, d: 0.1, a: 14, ox: 5, oy: 16)),
    ], solid: [
        .path("M3.704 14.467a10 8 0 1 1 3.115 2.375", motion: IconMotion(.spin, a: 40, ox: 12, oy: 9), fill: false),
        .path("M7 22a5 5 0 0 1-2-3.994", motion: IconMotion(.swing, d: 0.1, a: 14, ox: 5, oy: 16), fill: false),
        .circle(5, 16, 2, motion: IconMotion(.swing, d: 0.1, a: 14, ox: 5, oy: 16)),
    ])
    public static let list = PulsoIcon("List", "list", nodes: [
        .path("M3 5h.01", motion: IconMotion(.pop, ox: 3.005, oy: 5)),
        .path("M3 12h.01", motion: IconMotion(.pop, d: 0.06, ox: 3.005, oy: 12)),
        .path("M3 19h.01", motion: IconMotion(.pop, d: 0.12, ox: 3.005, oy: 19)),
        .path("M8 5h13", motion: IconMotion(.growX, d: 0.05, ox: 8, oy: 12)),
        .path("M8 12h13", motion: IconMotion(.growX, d: 0.11, ox: 8, oy: 12)),
        .path("M8 19h13", motion: IconMotion(.growX, d: 0.17, ox: 8, oy: 12)),
    ], solid: [
        .path("M3 5h.01", motion: IconMotion(.pop, ox: 3.005, oy: 5), fill: false),
        .path("M3 12h.01", motion: IconMotion(.pop, d: 0.06, ox: 3.005, oy: 12), fill: false),
        .path("M3 19h.01", motion: IconMotion(.pop, d: 0.12, ox: 3.005, oy: 19), fill: false),
        .path("M8 5h13", motion: IconMotion(.growX, d: 0.05, ox: 8, oy: 12), fill: false),
        .path("M8 12h13", motion: IconMotion(.growX, d: 0.11, ox: 8, oy: 12), fill: false),
        .path("M8 19h13", motion: IconMotion(.growX, d: 0.17, ox: 8, oy: 12), fill: false),
    ])
    public static let listChecks = PulsoIcon("ListChecks", "list-checks", nodes: [
        .path("M13 5h8", motion: IconMotion(.growX, d: 0.1, ox: 13, oy: 12)),
        .path("M13 12h8", motion: IconMotion(.growX, d: 0.15, ox: 13, oy: 12)),
        .path("M13 19h8", motion: IconMotion(.growX, d: 0.2, ox: 13, oy: 12)),
        .path("m3 17 2 2 4-4", motion: IconMotion(.draw, d: 0.15, ox: 6, oy: 17)),
        .path("m3 7 2 2 4-4", motion: IconMotion(.draw, ox: 6, oy: 7)),
    ], solid: [
        .path("M13 5h8", motion: IconMotion(.growX, d: 0.1, ox: 13, oy: 12), fill: false),
        .path("M13 12h8", motion: IconMotion(.growX, d: 0.15, ox: 13, oy: 12), fill: false),
        .path("M13 19h8", motion: IconMotion(.growX, d: 0.2, ox: 13, oy: 12), fill: false),
        .path("m3 17 2 2 4-4", motion: IconMotion(.draw, d: 0.15, ox: 6, oy: 17), fill: false),
        .path("m3 7 2 2 4-4", motion: IconMotion(.draw, ox: 6, oy: 7), fill: false),
    ])
    public static let listFilter = PulsoIcon("ListFilter", "list-filter", nodes: [
        .path("M2 5h20", motion: IconMotion(.growX, ox: 12, oy: 5)),
        .path("M6 12h12", motion: IconMotion(.growX, d: 0.08, ox: 12, oy: 12)),
        .path("M9 19h6", motion: IconMotion(.growX, d: 0.16, ox: 12, oy: 19)),
    ], solid: [
        .path("M2 5h20", motion: IconMotion(.growX, ox: 12, oy: 5), fill: false),
        .path("M6 12h12", motion: IconMotion(.growX, d: 0.08, ox: 12, oy: 12), fill: false),
        .path("M9 19h6", motion: IconMotion(.growX, d: 0.16, ox: 12, oy: 19), fill: false),
    ])
    public static let minimize2 = PulsoIcon("Minimize2", "minimize-2", nodes: [
        .path("m14 10 7-7", motion: IconMotion(.slide, x: -1, y: 1, a: 1.5, ox: 17.5, oy: 6.5)),
        .path("M20 10h-6V4", motion: IconMotion(.slide, x: -1, y: 1, a: 1.5, ox: 17.5, oy: 6.5)),
        .path("m3 21 7-7", motion: IconMotion(.slide, x: 1, y: -1, a: 1.5, ox: 6.5, oy: 17.5)),
        .path("M4 14h6v6", motion: IconMotion(.slide, x: 1, y: -1, a: 1.5, ox: 6.5, oy: 17.5)),
    ], solid: [
        .path("m14 10 7-7", motion: IconMotion(.slide, x: -1, y: 1, a: 1.5, ox: 17.5, oy: 6.5), fill: false),
        .path("M20 10h-6V4", motion: IconMotion(.slide, x: -1, y: 1, a: 1.5, ox: 17.5, oy: 6.5), fill: false),
        .path("m3 21 7-7", motion: IconMotion(.slide, x: 1, y: -1, a: 1.5, ox: 6.5, oy: 17.5), fill: false),
        .path("M4 14h6v6", motion: IconMotion(.slide, x: 1, y: -1, a: 1.5, ox: 6.5, oy: 17.5), fill: false),
    ])
    public static let notebookText = PulsoIcon("NotebookText", "notebook-text", nodes: [
        .path("M2 6h4", motion: IconMotion(.growX, d: 0.05, ox: 2, oy: 12)),
        .path("M2 10h4", motion: IconMotion(.growX, d: 0.09, ox: 2, oy: 12)),
        .path("M2 14h4", motion: IconMotion(.growX, d: 0.13, ox: 2, oy: 12)),
        .path("M2 18h4", motion: IconMotion(.growX, d: 0.17, ox: 2, oy: 12)),
        .rect(4, 2, 16, 20, rx: 2, ry: 2, motion: IconMotion(.press, a: 0.04, ox: 12, oy: 22)),
        .path("M9.5 8h5", motion: IconMotion(.growX, d: 0.15, ox: 9.5, oy: 12)),
        .path("M9.5 12H16", motion: IconMotion(.growX, d: 0.2, ox: 9.5, oy: 12)),
        .path("M9.5 16H14", motion: IconMotion(.growX, d: 0.25, ox: 9.5, oy: 12)),
    ], solid: [
        .path("M2 6h4", motion: IconMotion(.growX, d: 0.05, ox: 2, oy: 12), role: .line),
        .path("M2 10h4", motion: IconMotion(.growX, d: 0.09, ox: 2, oy: 12), role: .line),
        .path("M2 14h4", motion: IconMotion(.growX, d: 0.13, ox: 2, oy: 12), role: .line),
        .path("M2 18h4", motion: IconMotion(.growX, d: 0.17, ox: 2, oy: 12), role: .line),
        .rect(4, 2, 16, 20, rx: 2, ry: 2, motion: IconMotion(.press, a: 0.04, ox: 12, oy: 22)),
        .path("M9.5 8h5", motion: IconMotion(.growX, d: 0.15, ox: 9.5, oy: 12), role: .line),
        .path("M9.5 12H16", motion: IconMotion(.growX, d: 0.2, ox: 9.5, oy: 12), role: .line),
        .path("M9.5 16H14", motion: IconMotion(.growX, d: 0.25, ox: 9.5, oy: 12), role: .line),
    ])
    public static let play = PulsoIcon("Play", "play", nodes: [
        .path("M5 5a2 2 0 0 1 3.008-1.728l11.997 6.998a2 2 0 0 1 .003 3.458l-12 7A2 2 0 0 1 5 19z", motion: IconMotion(.pop, a: 0.3, ox: 13.001, oy: 12)),
    ], solid: [
        .path("M6 4v16a1 1 0 0 0 1.524 .852l13 -8a1 1 0 0 0 0 -1.704l-13 -8a1 1 0 0 0 -1.524 .852z", motion: IconMotion(.pop, a: 0.3, ox: 13.001, oy: 12), stroke: false),
    ])
    public static let plus = PulsoIcon("Plus", "plus", nodes: [
        .path("M5 12h14", motion: IconMotion(.spin, a: 90, ox: 12, oy: 12)),
        .path("M12 5v14", motion: IconMotion(.spin, a: 90, ox: 12, oy: 12)),
    ], solid: [
        .path("M12 4a1 1 0 0 1 1 1v6h6a1 1 0 0 1 0 2h-6v6a1 1 0 0 1 -2 0v-6h-6a1 1 0 0 1 0 -2h6v-6a1 1 0 0 1 1 -1", motion: IconMotion(.spin, a: 90, ox: 12, oy: 12), stroke: false),
    ])
    public static let pointer = PulsoIcon("Pointer", "pointer", nodes: [
        .path("M22 14a8 8 0 0 1-8 8", motion: IconMotion(.press, a: 0.08, ox: 12, oy: 16)),
        .path("M18 11v-1a2 2 0 0 0-2-2a2 2 0 0 0-2 2", motion: IconMotion(.float, d: 0.15, a: 1.5, ox: 16, oy: 9.5)),
        .path("M14 10V9a2 2 0 0 0-2-2a2 2 0 0 0-2 2v1", motion: IconMotion(.float, d: 0.1, a: 1.5, ox: 12, oy: 8.5)),
        .path("M10 9.5V4a2 2 0 0 0-2-2a2 2 0 0 0-2 2v10", motion: IconMotion(.float, d: 0.05, a: 1.5, ox: 8, oy: 8)),
        .path("M18 11a2 2 0 1 1 4 0v3a8 8 0 0 1-8 8h-2c-2.8 0-4.5-.86-5.99-2.34l-3.6-3.6a2 2 0 0 1 2.83-2.82L7 15", motion: IconMotion(.press, a: 0.08, ox: 12, oy: 16)),
    ], solid: [
        .path("M22 14a8 8 0 0 1-8 8", motion: IconMotion(.press, a: 0.08, ox: 12, oy: 16), fill: false),
        .path("M18 11v-1a2 2 0 0 0-2-2a2 2 0 0 0-2 2", motion: IconMotion(.float, d: 0.15, a: 1.5, ox: 16, oy: 9.5), fill: false),
        .path("M14 10V9a2 2 0 0 0-2-2a2 2 0 0 0-2 2v1", motion: IconMotion(.float, d: 0.1, a: 1.5, ox: 12, oy: 8.5), fill: false),
        .path("M10 9.5V4a2 2 0 0 0-2-2a2 2 0 0 0-2 2v10", motion: IconMotion(.float, d: 0.05, a: 1.5, ox: 8, oy: 8), fill: false),
        .path("M18 11a2 2 0 1 1 4 0v3a8 8 0 0 1-8 8h-2c-2.8 0-4.5-.86-5.99-2.34l-3.6-3.6a2 2 0 0 1 2.83-2.82L7 15", motion: IconMotion(.press, a: 0.08, ox: 12, oy: 16), fill: false),
    ])
    public static let rabbit = PulsoIcon("Rabbit", "rabbit", nodes: [
        .path("M13 16a3 3 0 0 1 2.24 5", motion: IconMotion(.fade, ox: 14.502, oy: 18.5)),
        .path("M18 12h.01", motion: IconMotion(.blink, d: 0.15, ox: 18.005, oy: 12)),
        .path("M18 21h-8a4 4 0 0 1-4-4 7 7 0 0 1 7-7h.2L9.6 6.4a1 1 0 1 1 2.8-2.8L15.8 7h.2c3.3 0 6 2.7 6 6v1a2 2 0 0 1-2 2h-1a3 3 0 0 0-3 3", motion: IconMotion(.bounce, y: -1, a: 2.5, ox: 12, oy: 11.5)),
        .path("M20 8.54V4a2 2 0 1 0-4 0v3", motion: IconMotion(.bounce, y: -1, a: 2.5, ox: 12, oy: 11.5)),
        .path("M7.612 12.524a3 3 0 1 0-1.6 4.3", motion: IconMotion(.bounce, y: -1, a: 2.5, ox: 12, oy: 11.5)),
    ], solid: [
        .path("M13 16a3 3 0 0 1 2.24 5", motion: IconMotion(.fade, ox: 14.502, oy: 18.5), fill: false),
        .path("M18 12h.01", motion: IconMotion(.blink, d: 0.15, ox: 18.005, oy: 12), fill: false),
        .path("M18 21h-8a4 4 0 0 1-4-4 7 7 0 0 1 7-7h.2L9.6 6.4a1 1 0 1 1 2.8-2.8L15.8 7h.2c3.3 0 6 2.7 6 6v1a2 2 0 0 1-2 2h-1a3 3 0 0 0-3 3", motion: IconMotion(.bounce, y: -1, a: 2.5, ox: 12, oy: 11.5), fill: false),
        .path("M20 8.54V4a2 2 0 1 0-4 0v3", motion: IconMotion(.bounce, y: -1, a: 2.5, ox: 12, oy: 11.5)),
        .path("M7.612 12.524a3 3 0 1 0-1.6 4.3", motion: IconMotion(.bounce, y: -1, a: 2.5, ox: 12, oy: 11.5), fill: false),
    ])
    public static let refreshCw = PulsoIcon("RefreshCw", "refresh-cw", nodes: [
        .path("M3 12a9 9 0 0 1 9-9 9.75 9.75 0 0 1 6.74 2.74L21 8", motion: IconMotion(.spin, a: 360, ox: 12, oy: 12)),
        .path("M21 3v5h-5", motion: IconMotion(.spin, a: 360, ox: 12, oy: 12)),
        .path("M21 12a9 9 0 0 1-9 9 9.75 9.75 0 0 1-6.74-2.74L3 16", motion: IconMotion(.spin, a: 360, ox: 12, oy: 12)),
        .path("M8 16H3v5", motion: IconMotion(.spin, a: 360, ox: 12, oy: 12)),
    ], solid: [
        .path("M3 12a9 9 0 0 1 9-9 9.75 9.75 0 0 1 6.74 2.74L21 8", motion: IconMotion(.spin, a: 360, ox: 12, oy: 12), fill: false),
        .path("M21 3v5h-5", motion: IconMotion(.spin, a: 360, ox: 12, oy: 12), fill: false),
        .path("M21 12a9 9 0 0 1-9 9 9.75 9.75 0 0 1-6.74-2.74L3 16", motion: IconMotion(.spin, a: 360, ox: 12, oy: 12), fill: false),
        .path("M8 16H3v5", motion: IconMotion(.spin, a: 360, ox: 12, oy: 12), fill: false),
    ])
    public static let rotateCcw = PulsoIcon("RotateCcw", "rotate-ccw", nodes: [
        .path("M3 12a9 9 0 1 0 9-9 9.75 9.75 0 0 0-6.74 2.74L3 8", motion: IconMotion(.spin, a: -360, ox: 12, oy: 12)),
        .path("M3 3v5h5", motion: IconMotion(.spin, a: -360, ox: 12, oy: 12)),
    ], solid: [
        .path("M3 12a9 9 0 1 0 9-9 9.75 9.75 0 0 0-6.74 2.74L3 8", motion: IconMotion(.spin, a: -360, ox: 12, oy: 12), fill: false),
        .path("M3 3v5h5", motion: IconMotion(.spin, a: -360, ox: 12, oy: 12), fill: false),
    ])
    public static let scan = PulsoIcon("Scan", "scan", nodes: [
        .path("M3 7V5a2 2 0 0 1 2-2h2", motion: IconMotion(.slide, x: -1, y: -1, a: 1.5, ox: 5, oy: 5)),
        .path("M17 3h2a2 2 0 0 1 2 2v2", motion: IconMotion(.slide, x: 1, y: -1, a: 1.5, ox: 19, oy: 5)),
        .path("M21 17v2a2 2 0 0 1-2 2h-2", motion: IconMotion(.slide, x: 1, y: 1, a: 1.5, ox: 19, oy: 19)),
        .path("M7 21H5a2 2 0 0 1-2-2v-2", motion: IconMotion(.slide, x: -1, y: 1, a: 1.5, ox: 5, oy: 19)),
    ], solid: [
        .path("M3 7V5a2 2 0 0 1 2-2h2", motion: IconMotion(.slide, x: -1, y: -1, a: 1.5, ox: 5, oy: 5), fill: false),
        .path("M17 3h2a2 2 0 0 1 2 2v2", motion: IconMotion(.slide, x: 1, y: -1, a: 1.5, ox: 19, oy: 5), fill: false),
        .path("M21 17v2a2 2 0 0 1-2 2h-2", motion: IconMotion(.slide, x: 1, y: 1, a: 1.5, ox: 19, oy: 19), fill: false),
        .path("M7 21H5a2 2 0 0 1-2-2v-2", motion: IconMotion(.slide, x: -1, y: 1, a: 1.5, ox: 5, oy: 19), fill: false),
    ])
    public static let scanText = PulsoIcon("ScanText", "scan-text", nodes: [
        .path("M3 7V5a2 2 0 0 1 2-2h2", motion: IconMotion(.pulse, a: 0.08, ox: 12, oy: 12)),
        .path("M17 3h2a2 2 0 0 1 2 2v2", motion: IconMotion(.pulse, a: 0.08, ox: 12, oy: 12)),
        .path("M21 17v2a2 2 0 0 1-2 2h-2", motion: IconMotion(.pulse, a: 0.08, ox: 12, oy: 12)),
        .path("M7 21H5a2 2 0 0 1-2-2v-2", motion: IconMotion(.pulse, a: 0.08, ox: 12, oy: 12)),
        .path("M7 8h8", motion: IconMotion(.growX, d: 0.05, ox: 7, oy: 12)),
        .path("M7 12h10", motion: IconMotion(.growX, d: 0.11, ox: 7, oy: 12)),
        .path("M7 16h6", motion: IconMotion(.growX, d: 0.17, ox: 7, oy: 12)),
    ], solid: [
        .path("M3 7V5a2 2 0 0 1 2-2h2", motion: IconMotion(.pulse, a: 0.08, ox: 12, oy: 12), fill: false),
        .path("M17 3h2a2 2 0 0 1 2 2v2", motion: IconMotion(.pulse, a: 0.08, ox: 12, oy: 12), fill: false),
        .path("M21 17v2a2 2 0 0 1-2 2h-2", motion: IconMotion(.pulse, a: 0.08, ox: 12, oy: 12), fill: false),
        .path("M7 21H5a2 2 0 0 1-2-2v-2", motion: IconMotion(.pulse, a: 0.08, ox: 12, oy: 12), fill: false),
        .path("M7 8h8", motion: IconMotion(.growX, d: 0.05, ox: 7, oy: 12), fill: false),
        .path("M7 12h10", motion: IconMotion(.growX, d: 0.11, ox: 7, oy: 12), fill: false),
        .path("M7 16h6", motion: IconMotion(.growX, d: 0.17, ox: 7, oy: 12), fill: false),
    ])
    public static let search = PulsoIcon("Search", "search", nodes: [
        .path("m21 21-4.34-4.34", motion: IconMotion(.swing, a: 14, ox: 11, oy: 11)),
        .circle(11, 11, 8, motion: IconMotion(.swing, a: 14, ox: 11, oy: 11)),
    ], solid: [
        .path("M14 3.072a8 8 0 0 1 2.32 11.834l5.387 5.387a1 1 0 0 1 -1.414 1.414l-5.388 -5.387a8 8 0 1 1 -.905 -13.249", motion: IconMotion(.swing, a: 14, ox: 11, oy: 11), stroke: false),
    ])
    public static let share = PulsoIcon("Share", "share", nodes: [
        .path("M12 2v13", motion: IconMotion(.bounce, y: -1, a: 2, ox: 12, oy: 8.5)),
        .path("m16 6-4-4-4 4", motion: IconMotion(.bounce, y: -1, a: 2, ox: 12, oy: 8.5)),
        .path("M4 12v8a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2v-8", motion: IconMotion(.press, d: 0.1, a: 0.04, ox: 12, oy: 17)),
    ], solid: [
        .path("M12 2v13", motion: IconMotion(.bounce, y: -1, a: 2, ox: 12, oy: 8.5), fill: false),
        .path("m16 6-4-4-4 4", motion: IconMotion(.bounce, y: -1, a: 2, ox: 12, oy: 8.5), fill: false),
        .path("M4 12v8a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2v-8", motion: IconMotion(.press, d: 0.1, a: 0.04, ox: 12, oy: 17), fill: false),
    ])
    public static let slidersHorizontal = PulsoIcon("SlidersHorizontal", "sliders-horizontal", nodes: [
        .path("M10 5H3", motion: IconMotion(.slide, x: 1, a: 2, ox: 12, oy: 5)),
        .path("M12 19H3", motion: IconMotion(.slide, d: 0.12, x: 1, a: 2, ox: 12, oy: 19)),
        .path("M14 3v4", motion: IconMotion(.slide, x: 1, a: 2, ox: 12, oy: 5)),
        .path("M16 17v4", motion: IconMotion(.slide, d: 0.12, x: 1, a: 2, ox: 12, oy: 19)),
        .path("M21 12h-9", motion: IconMotion(.slide, d: 0.06, x: -1, a: 2, ox: 12, oy: 12)),
        .path("M21 19h-5", motion: IconMotion(.slide, d: 0.12, x: 1, a: 2, ox: 12, oy: 19)),
        .path("M21 5h-7", motion: IconMotion(.slide, x: 1, a: 2, ox: 12, oy: 5)),
        .path("M8 10v4", motion: IconMotion(.slide, d: 0.06, x: -1, a: 2, ox: 12, oy: 12)),
        .path("M8 12H3", motion: IconMotion(.slide, d: 0.06, x: -1, a: 2, ox: 12, oy: 12)),
    ], solid: [
        .path("M10 5H3", motion: IconMotion(.slide, x: 1, a: 2, ox: 12, oy: 5), fill: false),
        .path("M12 19H3", motion: IconMotion(.slide, d: 0.12, x: 1, a: 2, ox: 12, oy: 19), fill: false),
        .path("M14 3v4", motion: IconMotion(.slide, x: 1, a: 2, ox: 12, oy: 5), fill: false),
        .path("M16 17v4", motion: IconMotion(.slide, d: 0.12, x: 1, a: 2, ox: 12, oy: 19), fill: false),
        .path("M21 12h-9", motion: IconMotion(.slide, d: 0.06, x: -1, a: 2, ox: 12, oy: 12), fill: false),
        .path("M21 19h-5", motion: IconMotion(.slide, d: 0.12, x: 1, a: 2, ox: 12, oy: 19), fill: false),
        .path("M21 5h-7", motion: IconMotion(.slide, x: 1, a: 2, ox: 12, oy: 5), fill: false),
        .path("M8 10v4", motion: IconMotion(.slide, d: 0.06, x: -1, a: 2, ox: 12, oy: 12), fill: false),
        .path("M8 12H3", motion: IconMotion(.slide, d: 0.06, x: -1, a: 2, ox: 12, oy: 12), fill: false),
    ])
    public static let sparkles = PulsoIcon("Sparkles", "sparkles", nodes: [
        .path("M11.017 2.814a1 1 0 0 1 1.966 0l1.051 5.558a2 2 0 0 0 1.594 1.594l5.558 1.051a1 1 0 0 1 0 1.966l-5.558 1.051a2 2 0 0 0-1.594 1.594l-1.051 5.558a1 1 0 0 1-1.966 0l-1.051-5.558a2 2 0 0 0-1.594-1.594l-5.558-1.051a1 1 0 0 1 0-1.966l5.558-1.051a2 2 0 0 0 1.594-1.594z", motion: IconMotion(.twinkle, a: 20, ox: 12, oy: 12)),
        .path("M20 2v4", motion: IconMotion(.twinkle, d: 0.1, ox: 20, oy: 4)),
        .path("M22 4h-4", motion: IconMotion(.twinkle, d: 0.1, ox: 20, oy: 4)),
        .circle(4, 20, 2, motion: IconMotion(.pop, d: 0.2, ox: 4, oy: 20)),
    ], solid: [
        .path("M11.017 2.814a1 1 0 0 1 1.966 0l1.051 5.558a2 2 0 0 0 1.594 1.594l5.558 1.051a1 1 0 0 1 0 1.966l-5.558 1.051a2 2 0 0 0-1.594 1.594l-1.051 5.558a1 1 0 0 1-1.966 0l-1.051-5.558a2 2 0 0 0-1.594-1.594l-5.558-1.051a1 1 0 0 1 0-1.966l5.558-1.051a2 2 0 0 0 1.594-1.594z", motion: IconMotion(.twinkle, a: 20, ox: 12, oy: 12)),
        .path("M20 2v4", motion: IconMotion(.twinkle, d: 0.1, ox: 20, oy: 4), fill: false),
        .path("M22 4h-4", motion: IconMotion(.twinkle, d: 0.1, ox: 20, oy: 4), fill: false),
        .circle(4, 20, 2, motion: IconMotion(.pop, d: 0.2, ox: 4, oy: 20)),
    ])
    public static let squarePen = PulsoIcon("SquarePen", "square-pen", nodes: [
        .path("M12 3H5a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2v-7", motion: IconMotion(.press, a: 0.04, ox: 12, oy: 12)),
        .path("M18.375 2.625a1 1 0 0 1 3 3l-9.013 9.014a2 2 0 0 1-.853.505l-2.873.84a.5.5 0 0 1-.62-.62l.84-2.873a2 2 0 0 1 .506-.852z", motion: IconMotion(.tilt, d: 0.05, a: 14, ox: 9, oy: 15)),
    ], solid: [
        .path("M12 3H5a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2v-7", motion: IconMotion(.press, a: 0.04, ox: 12, oy: 12), fill: false),
        .path("M18.375 2.625a1 1 0 0 1 3 3l-9.013 9.014a2 2 0 0 1-.853.505l-2.873.84a.5.5 0 0 1-.62-.62l.84-2.873a2 2 0 0 1 .506-.852z", motion: IconMotion(.tilt, d: 0.05, a: 14, ox: 9, oy: 15)),
    ])
    public static let sunrise = PulsoIcon("Sunrise", "sunrise", nodes: [
        .path("M12 2v8", motion: IconMotion(.bounce, d: 0.05, y: -1, a: 2, ox: 12, oy: 6)),
        .path("m4.93 10.93 1.41 1.41", motion: IconMotion(.fade, d: 0.15, ox: 12, oy: 14.465)),
        .path("M2 18h2", motion: IconMotion(.fade, d: 0.23, ox: 12, oy: 14.465)),
        .path("M20 18h2", motion: IconMotion(.fade, d: 0.27, ox: 12, oy: 14.465)),
        .path("m19.07 10.93-1.41 1.41", motion: IconMotion(.fade, d: 0.19, ox: 12, oy: 14.465)),
        .path("M22 22H2", motion: IconMotion(.growX, ox: 12, oy: 22)),
        .path("m8 6 4-4 4 4", motion: IconMotion(.bounce, d: 0.05, y: -1, a: 2, ox: 12, oy: 6)),
        .path("M16 18a4 4 0 0 0-8 0", motion: IconMotion(.rise, a: 3, ox: 12, oy: 16)),
    ], solid: [
        .path("M12 2v8", motion: IconMotion(.bounce, d: 0.05, y: -1, a: 2, ox: 12, oy: 6), fill: false),
        .path("m4.93 10.93 1.41 1.41", motion: IconMotion(.fade, d: 0.15, ox: 12, oy: 14.465), fill: false),
        .path("M2 18h2", motion: IconMotion(.fade, d: 0.23, ox: 12, oy: 14.465), fill: false),
        .path("M20 18h2", motion: IconMotion(.fade, d: 0.27, ox: 12, oy: 14.465), fill: false),
        .path("m19.07 10.93-1.41 1.41", motion: IconMotion(.fade, d: 0.19, ox: 12, oy: 14.465), fill: false),
        .path("M22 22H2", motion: IconMotion(.growX, ox: 12, oy: 22), fill: false),
        .path("m8 6 4-4 4 4", motion: IconMotion(.bounce, d: 0.05, y: -1, a: 2, ox: 12, oy: 6), fill: false),
        .path("M16 18a4 4 0 0 0-8 0", motion: IconMotion(.rise, a: 3, ox: 12, oy: 16)),
    ])
    public static let target = PulsoIcon("Target", "target", nodes: [
        .circle(12, 12, 10, motion: IconMotion(.press, a: 0.04, ox: 12, oy: 12)),
        .circle(12, 12, 6, motion: IconMotion(.press, d: 0.06, a: 0.08, ox: 12, oy: 12)),
        .circle(12, 12, 2, motion: IconMotion(.pop, d: 0.12, a: 0.5, ox: 12, oy: 12)),
    ], solid: [
        .circle(12, 12, 10, motion: IconMotion(.press, a: 0.04, ox: 12, oy: 12)),
        .circle(12, 12, 6, motion: IconMotion(.press, d: 0.06, a: 0.08, ox: 12, oy: 12), role: .cut),
        .circle(12, 12, 2, motion: IconMotion(.pop, d: 0.12, a: 0.5, ox: 12, oy: 12), role: .cut),
    ])
    public static let textCursorInput = PulsoIcon("TextCursorInput", "text-cursor-input", nodes: [
        .path("M12 20h-1a2 2 0 0 1-2-2 2 2 0 0 1-2 2H6", motion: IconMotion(.flicker, ox: 9, oy: 12)),
        .path("M13 8h7a2 2 0 0 1 2 2v4a2 2 0 0 1-2 2h-7", motion: IconMotion(.slide, d: 0.05, x: 1, a: 1, ox: 17.5, oy: 12)),
        .path("M5 16H4a2 2 0 0 1-2-2v-4a2 2 0 0 1 2-2h1", motion: IconMotion(.fade, d: 0.05, ox: 3.5, oy: 12)),
        .path("M6 4h1a2 2 0 0 1 2 2 2 2 0 0 1 2-2h1", motion: IconMotion(.flicker, ox: 9, oy: 12)),
        .path("M9 6v12", motion: IconMotion(.flicker, ox: 9, oy: 12)),
    ], solid: [
        .path("M12 20h-1a2 2 0 0 1-2-2 2 2 0 0 1-2 2H6", motion: IconMotion(.flicker, ox: 9, oy: 12), fill: false),
        .path("M13 8h7a2 2 0 0 1 2 2v4a2 2 0 0 1-2 2h-7", motion: IconMotion(.slide, d: 0.05, x: 1, a: 1, ox: 17.5, oy: 12), fill: false),
        .path("M5 16H4a2 2 0 0 1-2-2v-4a2 2 0 0 1 2-2h1", motion: IconMotion(.fade, d: 0.05, ox: 3.5, oy: 12), fill: false),
        .path("M6 4h1a2 2 0 0 1 2 2 2 2 0 0 1 2-2h1", motion: IconMotion(.flicker, ox: 9, oy: 12), fill: false),
        .path("M9 6v12", motion: IconMotion(.flicker, ox: 9, oy: 12), fill: false),
    ])
    public static let trash = PulsoIcon("Trash", "trash", nodes: [
        .path("M10 11v6", motion: IconMotion(.press, d: 0.05, a: 0.05, ox: 12, oy: 22)),
        .path("M14 11v6", motion: IconMotion(.press, d: 0.05, a: 0.05, ox: 12, oy: 22)),
        .path("M19 6v14a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V6", motion: IconMotion(.press, d: 0.05, a: 0.05, ox: 12, oy: 22)),
        .path("M3 6h18", motion: IconMotion(.lift, a: -12, ox: 3, oy: 6)),
        .path("M8 6V4a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2", motion: IconMotion(.lift, a: -12, ox: 3, oy: 6)),
    ], solid: [
        .path("M10 11v6", motion: IconMotion(.press, d: 0.05, a: 0.05, ox: 12, oy: 22), role: .line),
        .path("M14 11v6", motion: IconMotion(.press, d: 0.05, a: 0.05, ox: 12, oy: 22), role: .line),
        .path("M19 6v14a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V6", motion: IconMotion(.press, d: 0.05, a: 0.05, ox: 12, oy: 22)),
        .path("M3 6h18", motion: IconMotion(.lift, a: -12, ox: 3, oy: 6), fill: false),
        .path("M8 6V4a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2", motion: IconMotion(.lift, a: -12, ox: 3, oy: 6), fill: false),
    ])
    public static let turtle = PulsoIcon("Turtle", "turtle", nodes: [
        .path("m12 10 2 4v3a1 1 0 0 0 1 1h2a1 1 0 0 0 1-1v-3a8 8 0 1 0-16 0v3a1 1 0 0 0 1 1h2a1 1 0 0 0 1-1v-3l2-4h4Z", motion: IconMotion(.slide, x: 1, a: 1, ox: 10, oy: 12)),
        .path("M4.82 7.9 8 10", motion: IconMotion(.slide, x: 1, a: 1, ox: 10, oy: 12)),
        .path("M15.18 7.9 12 10", motion: IconMotion(.slide, x: 1, a: 1, ox: 10, oy: 12)),
        .path("M16.93 10H20a2 2 0 0 1 0 4H2", motion: IconMotion(.jelly, d: 0.05, a: 0.06, ox: 12, oy: 12)),
    ], solid: [
        .path("m12 10 2 4v3a1 1 0 0 0 1 1h2a1 1 0 0 0 1-1v-3a8 8 0 1 0-16 0v3a1 1 0 0 0 1 1h2a1 1 0 0 0 1-1v-3l2-4h4Z", motion: IconMotion(.slide, x: 1, a: 1, ox: 10, oy: 12)),
        .path("M4.82 7.9 8 10", motion: IconMotion(.slide, x: 1, a: 1, ox: 10, oy: 12), role: .line),
        .path("M15.18 7.9 12 10", motion: IconMotion(.slide, x: 1, a: 1, ox: 10, oy: 12), role: .line),
        .path("M16.93 10H20a2 2 0 0 1 0 4H2", motion: IconMotion(.jelly, d: 0.05, a: 0.06, ox: 12, oy: 12), role: .line),
    ])
    public static let undo2 = PulsoIcon("Undo2", "undo-2", nodes: [
        .path("M9 14 4 9l5-5", motion: IconMotion(.slide, x: -1, a: 2, ox: 6.5, oy: 9)),
        .path("M4 9h10.5a5.5 5.5 0 0 1 5.5 5.5a5.5 5.5 0 0 1-5.5 5.5H11", motion: IconMotion(.redraw, d: 0.1, ox: 12, oy: 14.5)),
    ], solid: [
        .path("M9 14 4 9l5-5", motion: IconMotion(.slide, x: -1, a: 2, ox: 6.5, oy: 9), fill: false),
        .path("M4 9h10.5a5.5 5.5 0 0 1 5.5 5.5a5.5 5.5 0 0 1-5.5 5.5H11", motion: IconMotion(.redraw, d: 0.1, ox: 12, oy: 14.5), fill: false),
    ])
    public static let volume2 = PulsoIcon("Volume2", "volume-2", nodes: [
        .path("M11 4.702a.705.705 0 0 0-1.203-.498L6.413 7.587A1.4 1.4 0 0 1 5.416 8H3a1 1 0 0 0-1 1v6a1 1 0 0 0 1 1h2.416a1.4 1.4 0 0 1 .997.413l3.383 3.384A.705.705 0 0 0 11 19.298z", motion: IconMotion(.press, a: 0.06, ox: 6, oy: 12)),
        .path("M16 9a5 5 0 0 1 0 6", motion: IconMotion(.draw, d: 0.1, ox: 16.5, oy: 12)),
        .path("M19.364 18.364a9 9 0 0 0 0-12.728", motion: IconMotion(.draw, d: 0.2, ox: 20.682, oy: 12)),
    ], solid: [
        .path("M11 4.702a.705.705 0 0 0-1.203-.498L6.413 7.587A1.4 1.4 0 0 1 5.416 8H3a1 1 0 0 0-1 1v6a1 1 0 0 0 1 1h2.416a1.4 1.4 0 0 1 .997.413l3.383 3.384A.705.705 0 0 0 11 19.298z", motion: IconMotion(.press, a: 0.06, ox: 6, oy: 12)),
        .path("M16 9a5 5 0 0 1 0 6", motion: IconMotion(.draw, d: 0.1, ox: 16.5, oy: 12), fill: false),
        .path("M19.364 18.364a9 9 0 0 0 0-12.728", motion: IconMotion(.draw, d: 0.2, ox: 20.682, oy: 12), fill: false),
    ])
    public static let volumeX = PulsoIcon("VolumeX", "volume-x", nodes: [
        .path("M11 4.702a.7.7 0 0 0-1.203-.498L6.413 7.587A1.4 1.4 0 0 1 5.416 8H3a1 1 0 0 0-1 1v6a1 1 0 0 0 1 1h2.416a1.4 1.4 0 0 1 .997.413l3.383 3.384A.7.7 0 0 0 11 19.298z", motion: IconMotion(.press, a: 0.06, ox: 6, oy: 12)),
        .path("m16.5 14.5 5-5", motion: IconMotion(.draw, d: 0.1, ox: 19, oy: 12)),
        .path("m16.5 9.5 5 5", motion: IconMotion(.draw, d: 0.2, ox: 19, oy: 12)),
    ], solid: [
        .path("M11 4.702a.7.7 0 0 0-1.203-.498L6.413 7.587A1.4 1.4 0 0 1 5.416 8H3a1 1 0 0 0-1 1v6a1 1 0 0 0 1 1h2.416a1.4 1.4 0 0 1 .997.413l3.383 3.384A.7.7 0 0 0 11 19.298z", motion: IconMotion(.press, a: 0.06, ox: 6, oy: 12)),
        .path("m16.5 14.5 5-5", motion: IconMotion(.draw, d: 0.1, ox: 19, oy: 12), fill: false),
        .path("m16.5 9.5 5 5", motion: IconMotion(.draw, d: 0.2, ox: 19, oy: 12), fill: false),
    ])
    public static let wandSparkles = PulsoIcon("WandSparkles", "wand-sparkles", nodes: [
        .path("m21.64 3.64-1.28-1.28a1.21 1.21 0 0 0-1.72 0L2.36 18.64a1.21 1.21 0 0 0 0 1.72l1.28 1.28a1.2 1.2 0 0 0 1.72 0L21.64 5.36a1.2 1.2 0 0 0 0-1.72", motion: IconMotion(.tilt, a: 10, ox: 3, oy: 21)),
        .path("m14 7 3 3", motion: IconMotion(.tilt, a: 10, ox: 3, oy: 21)),
        .path("M5 6v4", motion: IconMotion(.twinkle, d: 0.1, ox: 5, oy: 8)),
        .path("M19 14v4", motion: IconMotion(.twinkle, d: 0.14, ox: 19, oy: 16)),
        .path("M10 2v2", motion: IconMotion(.twinkle, d: 0.18, ox: 10, oy: 3)),
        .path("M7 8H3", motion: IconMotion(.twinkle, d: 0.22, ox: 5, oy: 8)),
        .path("M21 16h-4", motion: IconMotion(.twinkle, d: 0.26, ox: 19, oy: 16)),
        .path("M11 3H9", motion: IconMotion(.twinkle, d: 0.3, ox: 10, oy: 3)),
    ], solid: [
        .path("m21.64 3.64-1.28-1.28a1.21 1.21 0 0 0-1.72 0L2.36 18.64a1.21 1.21 0 0 0 0 1.72l1.28 1.28a1.2 1.2 0 0 0 1.72 0L21.64 5.36a1.2 1.2 0 0 0 0-1.72", motion: IconMotion(.tilt, a: 10, ox: 3, oy: 21)),
        .path("m14 7 3 3", motion: IconMotion(.tilt, a: 10, ox: 3, oy: 21), role: .line),
        .path("M5 6v4", motion: IconMotion(.twinkle, d: 0.1, ox: 5, oy: 8), fill: false),
        .path("M19 14v4", motion: IconMotion(.twinkle, d: 0.14, ox: 19, oy: 16), fill: false),
        .path("M10 2v2", motion: IconMotion(.twinkle, d: 0.18, ox: 10, oy: 3), fill: false),
        .path("M7 8H3", motion: IconMotion(.twinkle, d: 0.22, ox: 5, oy: 8), fill: false),
        .path("M21 16h-4", motion: IconMotion(.twinkle, d: 0.26, ox: 19, oy: 16), fill: false),
        .path("M11 3H9", motion: IconMotion(.twinkle, d: 0.3, ox: 10, oy: 3), fill: false),
    ])
    public static let x = PulsoIcon("X", "x", nodes: [
        .path("M18 6 6 18", motion: IconMotion(.spin, a: 90, ox: 12, oy: 12)),
        .path("m6 6 12 12", motion: IconMotion(.spin, a: 90, ox: 12, oy: 12)),
    ], solid: [
        .path("M6.707 5.293l5.293 5.292l5.293 -5.292a1 1 0 0 1 1.414 1.414l-5.292 5.293l5.292 5.293a1 1 0 0 1 -1.414 1.414l-5.293 -5.292l-5.293 5.292a1 1 0 1 1 -1.414 -1.414l5.292 -5.293l-5.292 -5.293a1 1 0 0 1 1.414 -1.414", motion: IconMotion(.spin, a: 90, ox: 12, oy: 12), stroke: false),
    ])

    public static let iconNames: [String] = [
        "arrow-right",
        "arrow-up-down",
        "arrow-up-right",
        "badge-check",
        "bell",
        "bell-ring",
        "book",
        "book-a",
        "book-open",
        "book-open-text",
        "bookmark",
        "bookmark-x",
        "calendar",
        "chart-column-big",
        "check",
        "chevron-down",
        "chevron-left",
        "chevron-right",
        "chevron-up",
        "chevrons-up-down",
        "circle",
        "circle-check",
        "circle-play",
        "circle-plus",
        "circle-question-mark",
        "circle-user-round",
        "circle-x",
        "clock",
        "compass",
        "crown",
        "dices",
        "download",
        "droplet",
        "ellipsis",
        "file-text",
        "flame",
        "folder",
        "folder-plus",
        "graduation-cap",
        "hand",
        "headphones",
        "heart",
        "images",
        "inbox",
        "infinity",
        "lasso",
        "list",
        "list-checks",
        "list-filter",
        "minimize-2",
        "notebook-text",
        "play",
        "plus",
        "pointer",
        "rabbit",
        "refresh-cw",
        "rotate-ccw",
        "scan",
        "scan-text",
        "search",
        "share",
        "sliders-horizontal",
        "sparkles",
        "square-pen",
        "sunrise",
        "target",
        "text-cursor-input",
        "trash",
        "turtle",
        "undo-2",
        "volume-2",
        "volume-x",
        "wand-sparkles",
        "x",
    ]

    public static func byKey(_ key: String) -> PulsoIcon? {
        switch key {
        case "arrow-right": .arrowRight
        case "arrow-up-down": .arrowUpDown
        case "arrow-up-right": .arrowUpRight
        case "badge-check": .badgeCheck
        case "bell": .bell
        case "bell-ring": .bellRing
        case "book": .book
        case "book-a": .bookA
        case "book-open": .bookOpen
        case "book-open-text": .bookOpenText
        case "bookmark": .bookmark
        case "bookmark-x": .bookmarkX
        case "calendar": .calendar
        case "chart-column-big": .chartColumnBig
        case "check": .check
        case "chevron-down": .chevronDown
        case "chevron-left": .chevronLeft
        case "chevron-right": .chevronRight
        case "chevron-up": .chevronUp
        case "chevrons-up-down": .chevronsUpDown
        case "circle": .circle
        case "circle-check": .circleCheck
        case "circle-play": .circlePlay
        case "circle-plus": .circlePlus
        case "circle-question-mark": .circleQuestionMark
        case "circle-user-round": .circleUserRound
        case "circle-x": .circleX
        case "clock": .clock
        case "compass": .compass
        case "crown": .crown
        case "dices": .dices
        case "download": .download
        case "droplet": .droplet
        case "ellipsis": .ellipsis
        case "file-text": .fileText
        case "flame": .flame
        case "folder": .folder
        case "folder-plus": .folderPlus
        case "graduation-cap": .graduationCap
        case "hand": .hand
        case "headphones": .headphones
        case "heart": .heart
        case "images": .images
        case "inbox": .inbox
        case "infinity": .infinity
        case "lasso": .lasso
        case "list": .list
        case "list-checks": .listChecks
        case "list-filter": .listFilter
        case "minimize-2": .minimize2
        case "notebook-text": .notebookText
        case "play": .play
        case "plus": .plus
        case "pointer": .pointer
        case "rabbit": .rabbit
        case "refresh-cw": .refreshCw
        case "rotate-ccw": .rotateCcw
        case "scan": .scan
        case "scan-text": .scanText
        case "search": .search
        case "share": .share
        case "sliders-horizontal": .slidersHorizontal
        case "sparkles": .sparkles
        case "square-pen": .squarePen
        case "sunrise": .sunrise
        case "target": .target
        case "text-cursor-input": .textCursorInput
        case "trash": .trash
        case "turtle": .turtle
        case "undo-2": .undo2
        case "volume-2": .volume2
        case "volume-x": .volumeX
        case "wand-sparkles": .wandSparkles
        case "x": .x
        default: nil
        }
    }
}
