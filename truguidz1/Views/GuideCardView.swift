import SwiftUI

struct GuideCardView: View {
    // 1. Pass a specific listing item into this card
    let listing: Listing
    
    var body: some View {
        HStack(alignment: .top, spacing: 16) {

            // Left Column: Text Information
            VStack(alignment: .leading, spacing: 6) {

                if !listing.isActive {
                    Text("Inactive")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.gray.opacity(0.2))
                        .foregroundColor(.appSecondaryText)
                        .clipShape(Capsule())
                }

                // Trip Title
                Text(listing.title)
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                    .lineLimit(2) // Prevents long titles from breaking the card

                // Location & Category Tag
                HStack(spacing: 4) {
                    Image(systemName: "mappin.and.ellipse")
                        .foregroundColor(.appSecondaryText)
                    Text("\(listing.locationName) • \(listing.category.rawValue.capitalized)")
                }
                .font(.subheadline)
                .foregroundColor(.appSecondaryText)
                
                Spacer()
                
                // Pricing Layout
                HStack(alignment: .bottom, spacing: 2) {
                    Text("$\(Int(listing.pricePerPerson))")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    Text(listing.pricingUnit.priceSuffix)
                        .font(.caption)
                        .foregroundColor(.appSecondaryText)
                        .padding(.bottom, 2)
                }
            }
            
            Spacer()
            
            // Right Column: real photo if the listing has one, otherwise a
            // placeholder shape.
            //
            // GeometryReader forces the image into the exact pixel size of
            // its container before scaling, rather than trusting the outer
            // .frame() to propagate down through AsyncImage as expected --
            // some source images report intrinsic-size metadata that
            // AsyncImage resolves in a way that lets the card's layout
            // balloon past its frame (confirmed live on the Explore cards).
            // Measuring the real available space and pinning the image to
            // it directly closes that off here too.
            GeometryReader { geo in
                Group {
                    if let imageURL = listing.imageUrls.first.flatMap(URL.init) {
                        AsyncImage(url: imageURL) { phase in
                            if let image = phase.image {
                                image
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: geo.size.width, height: geo.size.height)
                            } else {
                                placeholderImage
                            }
                        }
                    } else {
                        placeholderImage
                    }
                }
            }
            .frame(width: 110, height: 110)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .clipped()
        }
        .padding()
        .background(Color.appCard)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
        .opacity(listing.isActive ? 1 : 0.6)
    }

    private var placeholderImage: some View {
        ZStack {
            listing.category.color.opacity(0.25)
            Image(systemName: listing.category.icon)
                .font(.largeTitle)
                .foregroundColor(listing.category.color)
        }
    }
}

// 2. The Canvas Preview: Tell Xcode to display our mock data card
#Preview {
    GuideCardView(listing: Listing.mockListings[0])
        .padding()
        .background(Color(.systemGray6)) // Background to see the card shadow clearly
}
