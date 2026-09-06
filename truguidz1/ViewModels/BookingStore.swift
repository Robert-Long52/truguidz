import Foundation
import SwiftUI
import Supabase

// Holds bookings for the whole app session, the same way UserSession holds
// the current user. Injected once at the root so both the booking-creation
// flow (writes) and BookingsView (reads) share the same list.
@MainActor
final class BookingStore: ObservableObject {
    @Published var bookings: [Booking] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    // Booking ids that have at least one unread incoming message -- lets
    // BookingCardView/GuideBookingCardView show a small unread dot without
    // either card needing to open a ChatViewModel just to check. One cheap
    // query (RLS already scopes it to bookings the caller participates in,
    // so no client-side booking-id filtering is needed).
    @Published var bookingIdsWithUnreadMessages: Set<String> = []

    private struct UnreadMessageRow: Decodable {
        let bookingId: String
        enum CodingKeys: String, CodingKey { case bookingId = "booking_id" }
    }

    func refreshUnreadMessageIndicators(currentUserId: String) async {
        do {
            let rows: [UnreadMessageRow] = try await supabase
                .from("messages")
                .select("booking_id")
                .is("read_at", value: nil)
                .neq("sender_id", value: currentUserId)
                .execute()
                .value
            bookingIdsWithUnreadMessages = Set(rows.map(\.bookingId))
        } catch {
            print("Failed to load unread message indicators: \(error)")
        }
    }

    func loadBookings() async {
        isLoading = true
        defer { isLoading = false }
        do {
            bookings = try await supabase
                .from("bookings")
                .select()
                .order("date", ascending: true)
                .execute()
                .value
        } catch {
            print("Failed to load bookings: \(error)")
        }
    }

    // stripePaymentIntentId comes from BookingRequestView, which gets it by
    // calling the stripe-create-payment-intent Edge Function and running
    // Stripe's PaymentSheet *before* this is ever called -- the card is
    // already authorized (held, not charged) by the time a booking row
    // exists at all.
    @discardableResult
    func createBooking(
        listing: Listing,
        explorerId: String,
        date: Date,
        numberOfGuests: Int,
        hours: Int? = nil,
        stripePaymentIntentId: String
    ) async throws -> Booking {
        // Snapshotted alongside totalPrice/numberOfGuests -- see Booking.endDate.
        let endDate = Calendar.current.date(byAdding: .day, value: listing.packageDayCount - 1, to: date) ?? date

        let newBooking = Booking(
            id: UUID().uuidString,
            listingId: listing.id,
            explorerId: explorerId,
            guideId: listing.guideId,
            date: date,
            endDate: endDate,
            numberOfGuests: numberOfGuests,
            totalPrice: listing.totalPrice(numberOfGuests: numberOfGuests, hours: hours),
            status: .pending,
            createdAt: Date(),
            stripePaymentIntentId: stripePaymentIntentId
        )

        let inserted: Booking = try await supabase
            .from("bookings")
            .insert(newBooking)
            .select()
            .single()
            .execute()
            .value

        bookings.append(inserted)
        return inserted
    }

    // Lets a guide accept a pending booking. The card was already
    // authorized back when the explorer requested it (see createBooking
    // above) -- this is the moment that authorization actually turns into
    // a real charge, via the stripe-capture-payment Edge Function.
    // Messaging only unlocks once status is "confirmed", which only
    // happens after a real capture succeeds -- never just a UI label
    // flip -- so there's no window where contact info leaks before money
    // has actually moved (that's how off-platform booking/fee-skipping
    // happens on marketplaces if you're not careful about it).
    func confirmBooking(bookingId: String) async {
        errorMessage = nil
        do {
            try await supabase.functions.invoke(
                "stripe-capture-payment",
                options: FunctionInvokeOptions(body: ["bookingId": bookingId])
            )
            if let index = bookings.firstIndex(where: { $0.id == bookingId }) {
                bookings[index].status = .confirmed
            }
        } catch {
            // FunctionsError.httpError's default localizedDescription is
            // just "non-2xx status code: 409" -- not useful for something
            // like the booking-conflict rejection, where the actual point
            // is telling the guide *why* (see stripe-capture-payment's
            // "already have a confirmed trip that overlaps this date").
            // Decode the real message out of the response body instead.
            errorMessage = "Could not confirm booking: \(Self.serverErrorMessage(from: error))"
            print("Failed to confirm booking \(bookingId): \(error)")
        }
    }

    // Lets a guide decline a pending booking -- releases the authorization
    // hold via stripe-cancel-payment. Nothing was ever actually charged,
    // so there's nothing to refund, just a hold to let go of.
    func declineBooking(bookingId: String) async {
        errorMessage = nil
        do {
            try await supabase.functions.invoke(
                "stripe-cancel-payment",
                options: FunctionInvokeOptions(body: ["bookingId": bookingId])
            )
            if let index = bookings.firstIndex(where: { $0.id == bookingId }) {
                bookings[index].status = .cancelled
            }
        } catch {
            errorMessage = "Could not decline booking: \(Self.serverErrorMessage(from: error))"
            print("Failed to decline booking \(bookingId): \(error)")
        }
    }

    // Lets an explorer cancel a booking that's already been confirmed and
    // charged -- unlike updateStatus below, this actually issues a Stripe
    // refund (via stripe-refund-payment, which also reverses the guide's
    // payout and the platform's own fee) before the booking is marked
    // cancelled. Only valid for a confirmed booking; a still-pending one
    // was only ever authorized, not charged, so plain updateStatus (no
    // money involved) is correct for that case.
    func refundAndCancelBooking(bookingId: String) async {
        errorMessage = nil
        do {
            try await supabase.functions.invoke(
                "stripe-refund-payment",
                options: FunctionInvokeOptions(body: ["bookingId": bookingId])
            )
            if let index = bookings.firstIndex(where: { $0.id == bookingId }) {
                bookings[index].status = .cancelled
            }
        } catch {
            errorMessage = "Could not refund and cancel booking: \(Self.serverErrorMessage(from: error))"
            print("Failed to refund booking \(bookingId): \(error)")
        }
    }

    // For status changes that aren't tied to a fresh payment decision,
    // e.g. an explorer cancelling their own still-pending (not yet
    // charged) booking -- see refundAndCancelBooking above for the
    // already-paid case, which needs an actual Stripe refund first.
    func updateStatus(bookingId: String, to newStatus: BookingStatus) async {
        do {
            try await supabase
                .from("bookings")
                .update(["status": newStatus.rawValue])
                .eq("id", value: bookingId)
                .execute()
            if let index = bookings.firstIndex(where: { $0.id == bookingId }) {
                bookings[index].status = newStatus
            }
        } catch {
            print("Failed to update booking \(bookingId): \(error)")
        }
    }

    // Edge Functions in this project always respond to a rejected request
    // with a JSON body shaped {"error": "..."} -- pulling that out gives a
    // real, specific message (e.g. the booking-conflict rejection) instead
    // of FunctionsError's generic "non-2xx status code: 409".
    private static func serverErrorMessage(from error: Error) -> String {
        if case let FunctionsError.httpError(_, data) = error,
           let body = try? JSONDecoder().decode([String: String].self, from: data),
           let message = body["error"] {
            return message
        }
        return error.localizedDescription
    }
}
