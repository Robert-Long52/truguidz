import SwiftUI

// The default large-title nav bar (system San Francisco, huge, left-aligned)
// didn't fit this app's earthy branding -- this swaps it for a smaller,
// centered, rounded-font title instead. Only meant for screens whose
// toolbar background is the dark Color.appBackground (Bookings/Settings/
// Guide Dashboard) -- the color here assumes that dark backdrop.
extension View {
    func brandedNavTitle(_ title: String) -> some View {
        self
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(title)
                        .font(.system(.headline, design: .rounded))
                        .fontWeight(.bold)
                        .foregroundColor(.appTextOnDark)
                        .tracking(0.5)
                }
            }
    }
}
