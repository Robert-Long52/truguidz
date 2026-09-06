import SwiftUI
import PhotosUI

// Reusable "up to 3 photos" picker used by CreateListingView and
// EditListingView. Shows whichever of these is currently relevant:
// newly-picked local photos (once the guide has selected any), the
// listing's existing remote photos (Edit, before any new pick), or a
// placeholder if there's nothing yet. Whichever set is showing, its first
// photo is the cover photo used everywhere the listing appears as a
// single image (cards, Featured Guides) -- ListingDetailView is the only
// place all of them show, in a swipeable gallery.
//
// Picking new photos replaces the whole set rather than editing individual
// slots -- same "tap to change your photo(s)" model the single-photo
// version already had, just generalized to up to 3.
struct MultiPhotoPickerSection: View {
    @Binding var selectedItems: [PhotosPickerItem]
    @Binding var newImagesData: [Data]
    let existingImageUrls: [String]

    private var hasNewSelection: Bool { !newImagesData.isEmpty }
    private var displayCount: Int {
        hasNewSelection ? newImagesData.count : existingImageUrls.count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if displayCount == 0 {
                PhotosPicker(selection: $selectedItems, maxSelectionCount: 3, matching: .images) {
                    HStack {
                        Image(systemName: "photo.badge.plus")
                        Text("Add up to 3 Photos")
                    }
                    .foregroundColor(.accentColor)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
            } else {
                HStack(spacing: 10) {
                    ForEach(0..<displayCount, id: \.self) { index in
                        thumbnail(at: index)
                    }
                    Spacer(minLength: 0)
                }

                PhotosPicker(selection: $selectedItems, maxSelectionCount: 3, matching: .images) {
                    Text(hasNewSelection ? "Change Photos" : "Add New Photos")
                        .font(.subheadline)
                }
            }

            Text("The first photo is used as the cover on your listing card.")
                .font(.caption)
                .foregroundColor(.appSecondaryText)
        }
        .onChange(of: selectedItems) { _, newItems in
            Task {
                var datas: [Data] = []
                for item in newItems {
                    guard let raw = try? await item.loadTransferable(type: Data.self),
                          let processed = StorageService.processImageForUpload(raw) else { continue }
                    datas.append(processed)
                }
                newImagesData = datas
            }
        }
    }

    @ViewBuilder
    private func thumbnail(at index: Int) -> some View {
        ZStack(alignment: .topLeading) {
            Group {
                if hasNewSelection, let uiImage = UIImage(data: newImagesData[index]) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                } else if !hasNewSelection, let url = URL(string: existingImageUrls[index]) {
                    AsyncImage(url: url) { phase in
                        if let image = phase.image {
                            image.resizable().scaledToFill()
                        } else {
                            Color(.systemGray5)
                        }
                    }
                } else {
                    Color(.systemGray5)
                }
            }
            .frame(width: 88, height: 88)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .clipped()

            if index == 0 {
                Text("Cover")
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.black.opacity(0.6))
                    .foregroundColor(.white)
                    .clipShape(Capsule())
                    .padding(5)
            }
        }
    }
}
