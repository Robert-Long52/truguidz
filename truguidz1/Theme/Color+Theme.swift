import SwiftUI

// Earthy brand palette for an outdoors trip marketplace -- deep forest
// green + warm parchment cards + mud/leather brown accents, instead of
// the generic system gray/white/blue defaults everything started on.
// AccentColor.colorset itself is also set to the mud brown below, so
// every .borderedProminent button, link, and tab-bar selection tint
// picks it up automatically without per-view changes.
extension Color {
    static let appBackground = Color(red: 0.118, green: 0.169, blue: 0.102)
    static let appCard = Color(red: 0.953, green: 0.925, blue: 0.867)
    static let appTextOnDark = Color(red: 0.953, green: 0.925, blue: 0.867)
    static let appSecondaryTextOnDark = Color(red: 0.780, green: 0.749, blue: 0.627)

    // System .secondary is a cool ~55% gray tuned for a plain white
    // background -- against this app's warm parchment cards it reads as
    // low-contrast/washed out. This is a darker, warmer taupe standing in
    // for "secondary" everywhere on a light/card surface in this app.
    static let appSecondaryText = Color(red: 0.42, green: 0.38, blue: 0.30)
}

// Every Form/List screen in this app floats light rows on the dark
// Color.appBackground scroll canvas -- but a plain `Section("Title")`
// header/footer renders OUTSIDE those rows, directly on that dark canvas,
// using system default gray tuned for a white background. A UIKit
// UILabel.appearance() proxy (the trick that fixed the tab bar) does NOT
// reach these -- modern SwiftUI List headers aren't backed by
// UITableViewHeaderFooterView the way that fix assumed, confirmed by it
// having zero effect. The only reliable fix is recoloring each one
// explicitly via the closure-based header/footer form; this helper keeps
// that a one-line change at each call site instead of repeating
// `.foregroundColor(.appSecondaryTextOnDark)` everywhere by hand.
extension Text {
    static func darkSectionLabel(_ title: String) -> Text {
        Text(title).foregroundColor(.appSecondaryTextOnDark)
    }
}

// Category color/icon lived as a duplicated private switch in four
// different card views -- centralizing it here means every card stays
// in sync if a category's look ever changes.
extension ExperienceType {
    var color: Color {
        switch self {
        case .fishing: return Color(red: 0.243, green: 0.431, blue: 0.431)      // river slate-teal
        case .hunting: return Color(red: 0.361, green: 0.227, blue: 0.129)      // walnut
        case .hiking: return Color(red: 0.290, green: 0.420, blue: 0.227)       // moss green
        case .trailRiding: return Color(red: 0.710, green: 0.396, blue: 0.114)  // rust/terracotta
        }
    }

    var icon: String {
        switch self {
        case .fishing: return "fish.fill"
        case .hunting: return "scope"
        case .hiking: return "mountain.2.fill"
        case .trailRiding: return "hare.fill"
        }
    }
}
