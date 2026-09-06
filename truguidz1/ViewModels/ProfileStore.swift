import Foundation
import SwiftUI
import Supabase

// Resolves a User by id (a listing's guide, a booking's explorer/guide)
// against the profiles table, caching results so the same id is never
// fetched twice in a session. Replaces the old User.mockUsers/mockGuides
// array lookups now that accounts are real.
@MainActor
final class ProfileStore: ObservableObject {
    @Published private(set) var cache: [String: User] = [:]

    func profile(for id: String) async -> User? {
        if let cached = cache[id] {
            return cached
        }
        do {
            let user: User = try await supabase
                .from("profiles")
                .select()
                .eq("id", value: id)
                .single()
                .execute()
                .value
            cache[id] = user
            return user
        } catch {
            print("Failed to load profile \(id): \(error)")
            return nil
        }
    }
}
