import SwiftUI
import UIKit

// A hand-drawn-style "Z" with a horizontal dash through the diagonal —
// the same convention people use to distinguish a written Z from a 2.
// Doubles as the Truguidz brand mark.
struct ZBrandMark: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height

        let left = rect.minX + w * 0.16
        let right = rect.maxX - w * 0.16
        let top = rect.minY + h * 0.22
        let bottom = rect.maxY - h * 0.22
        let midY = (top + bottom) / 2

        // Top bar
        path.move(to: CGPoint(x: left, y: top))
        path.addLine(to: CGPoint(x: right, y: top))

        // Diagonal
        path.addLine(to: CGPoint(x: left, y: bottom))

        // Bottom bar
        path.addLine(to: CGPoint(x: right, y: bottom))

        // Cross-dash through the diagonal's midpoint
        let dashHalfWidth = w * 0.15
        path.move(to: CGPoint(x: (left + right) / 2 - dashHalfWidth, y: midY))
        path.addLine(to: CGPoint(x: (left + right) / 2 + dashHalfWidth, y: midY))

        return path
    }
}

struct ZBrandIcon: View {
    var lineWidth: CGFloat = 2.5
    var color: Color = .primary

    var body: some View {
        ZBrandMark()
            .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
    }
}

extension ZBrandIcon {
    // UITabBar expects its icons as a bitmapped template image (like the
    // SF Symbols the other tabs use) so it can recolor them for the
    // selected/unselected state itself. Handing it an arbitrary SwiftUI
    // Shape/View directly via .tabItem's icon closure renders fine in
    // Xcode's canvas preview but comes out blank in the actual running
    // app -- rasterizing it ourselves with ImageRenderer and marking the
    // result .alwaysTemplate sidesteps that entirely. Cached since the
    // mark itself never changes between renders.
    @MainActor
    private static var cache: [CGFloat: Image] = [:]

    @MainActor
    static func tabBarImage(size: CGFloat = 24, lineWidth: CGFloat = 2.2) -> Image {
        if let cached = cache[size] {
            return cached
        }

        let renderer = ImageRenderer(content:
            ZBrandMark()
                .stroke(Color.black, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
                .frame(width: size, height: size)
        )
        renderer.scale = UIScreen.main.scale

        guard let uiImage = renderer.uiImage else {
            return Image(systemName: "questionmark.circle")
        }

        let image = Image(uiImage: uiImage.withRenderingMode(.alwaysTemplate))
        cache[size] = image
        return image
    }
}

#Preview {
    VStack(spacing: 20) {
        ZBrandIcon()
            .frame(width: 60, height: 60)
        ZBrandIcon(lineWidth: 2, color: .accentColor)
            .frame(width: 24, height: 24)
    }
    .padding()
}
