import SwiftUI

// The main feed card shown while scrolling "Find your experience."
// Bigger than GuideCardView on purpose — a large image area up top,
// then details below, so each trip feels more like its own moment
// rather than a dense list row.
struct ListingFeedCard: View {
    let listing: Listing

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // Image area — real photo when the listing has one, otherwise
            // the category gradient + icon placeholder.
            //
            // GeometryReader forces the image into the exact pixel size of
            // its container before scaling, rather than trusting the
            // outer .frame() to propagate down through AsyncImage as
            // expected -- some source images (confirmed live: a couple of
            // real uploaded photos, not any code path tied to listing
            // data) report intrinsic-size metadata that AsyncImage
            // resolves in a way that let the whole card's layout balloon
            // past its frame. Measuring the real available space and
            // pinning the image to it directly closes that off regardless
            // of what any future uploaded photo's metadata looks like.
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
            .frame(height: 200)
            .frame(maxWidth: .infinity)
            .clipShape(
                .rect(topLeadingRadius: 20, bottomLeadingRadius: 0, bottomTrailingRadius: 0, topTrailingRadius: 20)
            )
            .clipped()

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(listing.category.rawValue.capitalized)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(categoryColor.opacity(0.15))
                        .foregroundColor(categoryColor)
                        .cornerRadius(20)

                    Spacer()

                    HStack(spacing: 3) {
                        Image(systemName: "star.fill")
                            .font(.caption2)
                            .foregroundColor(.yellow)
                        Text(String(format: "%.1f", listing.rating))
                            .fontWeight(.semibold)
                        Text("(\(listing.reviewCount))")
                            .foregroundColor(.appSecondaryText)
                    }
                    .font(.caption)
                }

                Text(listing.title)
                    .font(.title3)
                    .fontWeight(.bold)
                    .lineLimit(2)

                HStack(spacing: 4) {
                    Image(systemName: "mappin.and.ellipse")
                        .foregroundColor(.appSecondaryText)
                    Text(listing.locationName)
                }
                .font(.subheadline)
                .foregroundColor(.appSecondaryText)

                Divider()
                    .padding(.vertical, 4)

                HStack {
                    HStack(alignment: .bottom, spacing: 2) {
                        Text("$\(Int(listing.pricePerPerson))")
                            .font(.title3)
                            .fontWeight(.bold)
                        Text(listing.pricingUnit.priceSuffix)
                            .font(.caption)
                            .foregroundColor(.appSecondaryText)
                    }

                    Spacer()

                    Text("Tap for details")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.accentColor)
                }
            }
            .padding(16)
        }
        .background(Color.appCard)
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.08), radius: 10, x: 0, y: 6)
    }

    private var placeholderImage: some View {
        ZStack {
            LinearGradient(
                colors: [categoryColor.opacity(0.7), categoryColor.opacity(0.35)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Image(systemName: listing.category.icon)
                .font(.system(size: 60))
                .foregroundColor(.white.opacity(0.85))
        }
    }

    private var categoryColor: Color { listing.category.color }
}

#Preview {
    ScrollView {
        VStack(spacing: 20) {
            ForEach(Listing.mockListings) { listing in
                ListingFeedCard(listing: listing)
            }
        }
        .padding()
    }
    .background(Color(.systemGray6))
}
