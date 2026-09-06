import SwiftUI
 
struct ListingDetailView: View {
    let listing: Listing
    @EnvironmentObject var userSession: UserSession
    @EnvironmentObject var profileStore: ProfileStore
    @EnvironmentObject var reviewStore: ReviewStore
    @State private var showBookingSheet = false
    @State private var guide: User?
    @State private var reviewerNames: [String: String] = [:]

    private var reviews: [Review] {
        reviewStore.reviewsByListing[listing.id] ?? []
    }

    private var categoryColor: Color { listing.category.color }

    private var galleryImageURLs: [URL] {
        listing.imageUrls.compactMap(URL.init)
    }

    @State private var currentPhotoIndex: Int?

    private var heroPlaceholder: some View {
        ZStack {
            LinearGradient(
                colors: [categoryColor.opacity(0.75), categoryColor.opacity(0.4)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Image(systemName: listing.category.icon)
                .font(.system(size: 80))
                .foregroundColor(.white.opacity(0.85))
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
 
                // Hero gallery — swipeable through every photo the guide
                // uploaded (cards/Featured Guides only ever show
                // imageUrls[0] as the cover; this is the one place all of
                // them show), or the category gradient + icon placeholder
                // if there are none yet.
                //
                // Each page still gets its own GeometryReader forcing the
                // image into the exact pixel size of its container before
                // scaling, rather than trusting the outer .frame() to
                // propagate down through AsyncImage as expected -- some
                // source images (confirmed live: a couple of real uploaded
                // photos, not any code path tied to listing data) report
                // intrinsic-size metadata that AsyncImage resolves in a way
                // that let this whole screen's content shift and clip past
                // its own bounds. Measuring the real available space and
                // pinning the image to it directly closes that off
                // regardless of what any future uploaded photo's metadata
                // looks like.
                //
                // A TabView(.page) here (the obvious first choice) turned
                // out not to work at all once nested inside this screen's
                // own vertical ScrollView -- confirmed live with several
                // swipe/drag attempts that never advanced a page. That's a
                // known SwiftUI gap, not a fluke: a paging TabView's
                // internal UIScrollView loses the swipe gesture to the
                // enclosing ScrollView's own pan recognizer. A horizontal
                // ScrollView with .paging behavior, same family of control
                // already used for Featured Guides on Explore, composes
                // with an outer vertical ScrollView correctly, so this
                // builds the same gallery UI out of that instead, tracking
                // the current page via .scrollPosition to draw dots by hand.
                Group {
                    if galleryImageURLs.isEmpty {
                        heroPlaceholder
                    } else {
                        ZStack(alignment: .bottom) {
                            ScrollView(.horizontal, showsIndicators: false) {
                                LazyHStack(spacing: 0) {
                                    ForEach(Array(galleryImageURLs.enumerated()), id: \.offset) { index, imageURL in
                                        GeometryReader { geo in
                                            AsyncImage(url: imageURL) { phase in
                                                if let image = phase.image {
                                                    image
                                                        .resizable()
                                                        .scaledToFill()
                                                        .frame(width: geo.size.width, height: geo.size.height)
                                                } else {
                                                    heroPlaceholder
                                                }
                                            }
                                        }
                                        .containerRelativeFrame(.horizontal)
                                        .frame(height: 280)
                                        .clipped()
                                        .id(index)
                                    }
                                }
                                .scrollTargetLayout()
                            }
                            .scrollTargetBehavior(.paging)
                            .scrollPosition(id: $currentPhotoIndex)

                            if galleryImageURLs.count > 1 {
                                HStack(spacing: 6) {
                                    ForEach(0..<galleryImageURLs.count, id: \.self) { index in
                                        Circle()
                                            .fill(index == (currentPhotoIndex ?? 0) ? Color.white : Color.white.opacity(0.4))
                                            .frame(width: 6, height: 6)
                                    }
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color.black.opacity(0.3), in: Capsule())
                                .padding(.bottom, 12)
                            }
                        }
                    }
                }
                .frame(height: 280)
                .frame(maxWidth: .infinity)
                .clipped()
 
                VStack(alignment: .leading, spacing: 16) {
 
                    // Title + rating
                    VStack(alignment: .leading, spacing: 6) {
                        Text(listing.category.rawValue.capitalized)
                            .font(.caption)
                            .fontWeight(.semibold)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(categoryColor.opacity(0.15))
                            .foregroundColor(categoryColor)
                            .cornerRadius(20)
 
                        Text(listing.title)
                            .font(.title)
                            .fontWeight(.bold)
 
                        HStack(spacing: 12) {
                            HStack(spacing: 3) {
                                Image(systemName: "star.fill")
                                    .foregroundColor(.yellow)
                                Text(String(format: "%.1f", listing.rating))
                                    .fontWeight(.semibold)
                                Text("(\(listing.reviewCount) reviews)")
                                    .foregroundColor(.appSecondaryText)
                            }
                            .font(.subheadline)
 
                            HStack(spacing: 3) {
                                Image(systemName: "mappin.and.ellipse")
                                Text(listing.locationName)
                            }
                            .font(.subheadline)
                            .foregroundColor(.appSecondaryText)
                        }
                    }
 
                    Divider()
 
                    // Guide info
                    if let guide {
                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(Color(.systemGray5))
                                    .frame(width: 50, height: 50)
                                Text(guide.name.prefix(1))
                                    .font(.headline)
                                    .foregroundColor(.appSecondaryText)
                            }
 
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 4) {
                                    Text("Hosted by \(guide.name)")
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                    if guide.isVerifiedGuide {
                                        Image(systemName: "checkmark.seal.fill")
                                            .font(.caption)
                                            .foregroundColor(.blue)
                                    }
                                }
                                if let years = guide.yearsExperience {
                                    Text("\(years) years experience")
                                        .font(.caption)
                                        .foregroundColor(.appSecondaryText)
                                }
                            }
                        }
 
                        if let bio = guide.bio {
                            Text(bio)
                                .font(.subheadline)
                                .foregroundColor(.appSecondaryText)
                        }
 
                        Divider()
                    }
 
                    // Description
                    VStack(alignment: .leading, spacing: 6) {
                        Text("About this trip")
                            .font(.headline)
                        Text(listing.description)
                            .font(.subheadline)
                            .foregroundColor(.appSecondaryText)
                    }
 
                    Divider()
 
                    // Trip logistics
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Trip Details")
                            .font(.headline)
 
                        HStack {
                            Image(systemName: "person.2.fill")
                                .foregroundColor(.appSecondaryText)
                            Text("Up to \(listing.maxGroupSize) guests")
                            Spacer()
                        }
                        .font(.subheadline)
 
                        HStack {
                            Image(systemName: "mappin.circle.fill")
                                .foregroundColor(.appSecondaryText)
                            Text(listing.locationName)
                            Spacer()
                        }
                        .font(.subheadline)

                        HStack(alignment: .top) {
                            Image(systemName: "clock.fill")
                                .foregroundColor(.appSecondaryText)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(listing.tripLength == .multiDay
                                     ? "\(listing.packageDayCount)-day package"
                                     : listing.tripLength.label)
                                // A multi-day package runs as one continuous
                                // block once booked, so there's no "which
                                // weekdays" schedule to show the way there is
                                // for a repeating single-day trip.
                                if listing.tripLength != .multiDay {
                                    Text(listing.availableDays.count == 7
                                         ? "Runs every day"
                                         : "Runs " + listing.availableDays.sorted { $0.rawValue < $1.rawValue }.map(\.short).joined(separator: ", "))
                                        .foregroundColor(.appSecondaryText)
                                }
                            }
                            Spacer()
                        }
                        .font(.subheadline)
                    }

                    Divider()

                    // Reviews
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 4) {
                            Image(systemName: "star.fill")
                                .foregroundColor(.yellow)
                            Text("\(String(format: "%.1f", listing.rating)) · \(listing.reviewCount) review\(listing.reviewCount == 1 ? "" : "s")")
                                .font(.headline)
                        }

                        if reviews.isEmpty {
                            Text("No reviews yet.")
                                .font(.subheadline)
                                .foregroundColor(.appSecondaryText)
                        } else {
                            ForEach(reviews) { review in
                                reviewRow(review)
                                if review.id != reviews.last?.id {
                                    Divider()
                                }
                            }
                        }
                    }
                }
                .padding(20)
            }
        }
        .task(id: listing.guideId) {
            guide = await profileStore.profile(for: listing.guideId)
        }
        .task(id: listing.id) {
            await reviewStore.loadReviews(forListing: listing.id)
            for review in reviews where reviewerNames[review.explorerId] == nil {
                reviewerNames[review.explorerId] = await profileStore.profile(for: review.explorerId)?.name
            }
        }
        .background(Color.appCard)
        .ignoresSafeArea(edges: .top)
        .safeAreaInset(edge: .bottom) {
            // Sticky booking bar
            HStack {
                VStack(alignment: .leading, spacing: 0) {
                    HStack(alignment: .bottom, spacing: 2) {
                        Text("$\(Int(listing.pricePerPerson))")
                            .font(.title3)
                            .fontWeight(.bold)
                        Text(listing.pricingUnit.priceSuffix)
                            .font(.caption)
                            .foregroundColor(.appSecondaryText)
                    }
                }

                Spacer()
 
                Button {
                    showBookingSheet = true
                } label: {
                    Text("Book Now")
                        .fontWeight(.semibold)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(Color.accentColor)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
            }
            .padding()
            .background(.regularMaterial)
        }
        .sheet(isPresented: $showBookingSheet) {
            if userSession.currentUser != nil {
                BookingRequestView(listing: listing)
            } else {
                LoginRequiredView(message: "Log in to book \(listing.title).")
            }
        }
    }

    private func reviewRow(_ review: Review) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(reviewerNames[review.explorerId] ?? "Explorer")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Spacer()
                Text(review.createdAt.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption)
                    .foregroundColor(.appSecondaryText)
            }
            HStack(spacing: 2) {
                ForEach(1...5, id: \.self) { star in
                    Image(systemName: star <= review.rating ? "star.fill" : "star")
                        .font(.caption)
                        .foregroundColor(.yellow)
                }
            }
            if let comment = review.comment, !comment.isEmpty {
                Text(comment)
                    .font(.subheadline)
                    .foregroundColor(.appSecondaryText)
            }
        }
    }
}
 
#Preview {
    NavigationStack {
        ListingDetailView(listing: Listing.mockListings[0])
    }
    .environmentObject(UserSession.previewExplorer)
    .environmentObject(ProfileStore())
    .environmentObject(ReviewStore())
}
