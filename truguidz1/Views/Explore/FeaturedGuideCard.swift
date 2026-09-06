import SwiftUI

// A single card in the horizontal "Featured Guides" carousel.
// Image fills the card with a title/location overlay at the bottom,
// similar to the sketch's promo section at the top of the Explore screen.
struct FeaturedGuideCard: View {
    let listing: Listing

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            // GeometryReader forces the image into the exact pixel size of
            // its container before scaling, rather than trusting the
            // outer .frame() to propagate down through AsyncImage as
            // expected -- some source images (confirmed live: a couple of
            // real uploaded photos, not any code path tied to listing
            // data) report intrinsic-size metadata that AsyncImage
            // resolves in a way that lets the card's own layout balloon
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
                                placeholderBackground
                            }
                        }
                    } else {
                        placeholderBackground
                    }
                }
            }
            .frame(width: 260, height: 160)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .clipped()

            // Bottom gradient so text stays readable over any image
            LinearGradient(
                colors: [.black.opacity(0.55), .clear],
                startPoint: .bottom,
                endPoint: .center
            )
            .cornerRadius(20)

            VStack(alignment: .leading, spacing: 4) {
                Text(listing.category.rawValue.capitalized)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(.white.opacity(0.25))
                    .foregroundColor(.white)
                    .cornerRadius(20)

                Text(listing.title)
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .lineLimit(2)

                Text(listing.locationName)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.9))
            }
            .padding(16)
        }
        .frame(width: 260, height: 160)
    }

    private var placeholderBackground: some View {
        RoundedRectangle(cornerRadius: 20)
            .fill(
                LinearGradient(
                    colors: [categoryColor.opacity(0.8), categoryColor.opacity(0.4)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                Image(systemName: listing.category.icon)
                    .font(.system(size: 70))
                    .foregroundColor(.white.opacity(0.25))
                    .offset(x: 40, y: -10)
            )
    }

    private var categoryColor: Color { listing.category.color }
}

#Preview {
    ScrollView(.horizontal) {
        HStack(spacing: 16) {
            ForEach(Listing.mockListings) { listing in
                FeaturedGuideCard(listing: listing)
            }
        }
        .padding()
    }
}
