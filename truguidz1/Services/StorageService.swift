import Foundation
import Supabase
import UIKit

// Thin wrapper around Supabase Storage for listing photos. Kept separate
// from ListingStore since it's a different concern (file bytes, not rows)
// even though CreateListingView calls both back to back.
enum StorageService {
    // A PhotosPicker item from a modern phone camera can be 4000px+ on a
    // side and several MB -- CreateListingView/EditListingView/
    // GuideApplicationView all used to just re-encode that as JPEG at the
    // original resolution, which meant slow uploads and needlessly large
    // Storage usage for what's ultimately displayed at a few hundred
    // points wide. Downscaling first (aspect-preserving, only when the
    // image is actually bigger than the cap) fixes that without any
    // visible quality loss for how these photos are actually shown.
    static func processImageForUpload(
        _ data: Data,
        maxDimension: CGFloat = 1600,
        compressionQuality: CGFloat = 0.8
    ) -> Data? {
        guard let image = UIImage(data: data) else { return nil }

        let longestSide = max(image.size.width, image.size.height)
        guard longestSide > maxDimension else {
            return image.jpegData(compressionQuality: compressionQuality)
        }

        let scale = maxDimension / longestSide
        let newSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        let resized = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
        return resized.jpegData(compressionQuality: compressionQuality)
    }

    // `index` is 1-based and picks which of a listing's (up to 3) photo
    // slots this upload fills -- galleryUploadListingImages below is what
    // actually calls this once per photo; kept as its own function since
    // GuidzDashboardView/CreateListingView's single-photo-at-a-time paths
    // still call it directly with index 1.
    static func uploadListingImage(guideId: String, listingId: String, data: Data, index: Int = 1) async throws -> String {
        let path = "\(guideId)/\(listingId)/photo\(index).jpg"

        try await supabase.storage
            .from("listing-images")
            .upload(path, data: data, options: FileOptions(contentType: "image/jpeg", upsert: true))

        let url = try supabase.storage
            .from("listing-images")
            .getPublicURL(path: path)

        return url.absoluteString
    }

    // Uploads up to 3 photos (in the order given -- the first becomes the
    // listing's cover photo everywhere it's shown as a single image: cards,
    // Featured Guides, etc.) and returns their public URLs in that same
    // order, ready to hand straight to ListingStore.updateListingImages.
    static func uploadListingImages(guideId: String, listingId: String, images: [Data]) async throws -> [String] {
        var urls: [String] = []
        for (offset, data) in images.enumerated() {
            let url = try await uploadListingImage(guideId: guideId, listingId: listingId, data: data, index: offset + 1)
            urls.append(url)
        }
        return urls
    }

    // guide-documents is a private bucket (unlike listing-images) -- there's
    // no public URL to hand back here, and nothing client-side needs one.
    // Only the storage path itself gets stored on the profile, for an admin
    // to look up later via the Supabase dashboard's own privileged access.
    @discardableResult
    static func uploadGuideVerificationDocument(guideId: String, data: Data) async throws -> String {
        let path = "\(guideId)/id-document.jpg"

        try await supabase.storage
            .from("guide-documents")
            .upload(path, data: data, options: FileOptions(contentType: "image/jpeg", upsert: true))

        return path
    }
}
