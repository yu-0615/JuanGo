// swift-tools-version: 6.0
import PackageDescription

// A trimmed copy of PulsoIcon (https://github.com/CityPulso/PulsoIcon, ISC License) with only the icons Lexi uses,
// so the app builds in seconds instead of compiling all 9955 icons. The runtime files are unchanged.
let package = Package(
    name: "PulsoIcon",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [.library(name: "PulsoIcon", targets: ["PulsoIcon"])],
    dependencies: [.package(url: "https://github.com/nicklockwood/SVGPath.git", from: "1.3.1")],
    targets: [.target(name: "PulsoIcon", dependencies: ["SVGPath"], path: "Sources/PulsoIcon")]
)
