import SwiftUI
import UIKit
import Supabase
import StripePaymentSheet

private struct CreatePaymentIntentRequest: Encodable {
    let listingId: String
    let numberOfGuests: Int
    let hours: Int?
}

private struct CreatePaymentIntentResponse: Decodable {
    let clientSecret: String
    let paymentIntentId: String
}

private struct GuideDateRangeParams: Encodable {
    let guideId: String
    enum CodingKeys: String, CodingKey {
        case guideId = "p_guide_id"
    }
}

private struct GuideDateRangeRow: Decodable {
    let startDate: Date
    let endDate: Date
    enum CodingKeys: String, CodingKey {
        case startDate = "start_date"
        case endDate = "end_date"
    }
}

struct BookingRequestView: View {
    let listing: Listing

    @EnvironmentObject var userSession: UserSession
    @EnvironmentObject var bookingStore: BookingStore
    @Environment(\.dismiss) private var dismiss

    init(listing: Listing) {
        self.listing = listing
        _blockedDates = State(initialValue: listing.blockedDateValues)
    }

    @State private var selectedDate: Date = Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()
    @State private var numberOfAdults: Int = 1
    @State private var numberOfChildren: Int = 0
    @State private var numberOfHours: Int = 4
    @State private var confirmedBooking: Booking?
    @State private var isSubmitting = false
    @State private var errorMessage: String?

    @State private var pendingPaymentIntentId: String?
    @State private var showWaiverSheet = false

    private var hoursIfApplicable: Int? {
        listing.pricingUnit == .perHour ? numberOfHours : nil
    }

    // Children count toward group size and price exactly like an adult --
    // no separate child pricing was asked for, this split is purely so the
    // guide can see who's actually showing up.
    private var numberOfGuests: Int { numberOfAdults + numberOfChildren }

    private var totalPrice: Double {
        listing.totalPrice(numberOfGuests: numberOfGuests, hours: hoursIfApplicable)
    }

    // Every calendar day this guide already has a confirmed/completed trip
    // on, across all their listings -- a guide can't be in two places at
    // once, so this needs to look at all of their bookings, not just ones
    // against this specific listing. This is the client-side UX half of
    // conflict prevention (black out days so an explorer never tries to
    // request one); the actual guarantee is a database exclusion
    // constraint checked at confirm time (see
    // supabase/add_booking_conflict_prevention.sql) -- this blackout can't
    // by itself prevent two people racing to request the same day, only
    // make it far less likely to happen by accident.
    //
    // Loaded via the guide_confirmed_date_ranges RPC, not filtered out of
    // bookingStore.bookings -- the bookings table's own RLS policy only
    // lets a caller see rows where *they* are the explorer or guide, so a
    // different explorer booking this same guide would never see the
    // guide's other confirmed bookings that way at all, and every day
    // would silently look open. The RPC is SECURITY DEFINER specifically
    // so it can see across that boundary, but it only ever returns the
    // date range, nothing else about the booking.
    // Starts pre-seeded with the listing's own manually-blocked dates (see
    // Listing.blockedDateValues) so those are already respected even
    // before loadBlockedDates' network call resolves -- loadBlockedDates
    // only ever adds to this set, never replaces it, so that seed data
    // can't be clobbered.
    @State private var blockedDates: Set<Date>

    private func loadBlockedDates() async {
        let calendar = Calendar.current
        do {
            let ranges: [GuideDateRangeRow] = try await supabase
                .rpc("guide_confirmed_date_ranges", params: GuideDateRangeParams(guideId: listing.guideId))
                .execute()
                .value
            for range in ranges {
                var day = calendar.startOfDay(for: range.startDate)
                let lastDay = calendar.startOfDay(for: range.endDate)
                while day <= lastDay {
                    blockedDates.insert(day)
                    guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
                    day = next
                }
            }
        } catch {
            print("Failed to load guide's blocked dates: \(error)")
        }
    }

    // The calendar UI is only as correct as the booking data it was drawn
    // from -- if this screen opened before BookingStore's one-time,
    // app-launch load finished (or before it picked up a booking made
    // elsewhere since then), blockedDates could be stale or incomplete at
    // the moment a day was tapped. This re-checks the actual selected
    // range against the current data right before money changes hands, so
    // a stale render can't turn into a real conflicting booking.
    private var isSelectedRangeFullyAvailable: Bool {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: selectedDate)
        let days = (0..<listing.packageDayCount).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
        return days.allSatisfy { !blockedDates.contains(calendar.startOfDay(for: $0)) }
    }

    private var priceSummaryLine: String {
        switch listing.pricingUnit {
        case .perPerson: return "$\(Int(listing.pricePerPerson)) × \(numberOfGuests) guest\(numberOfGuests == 1 ? "" : "s")"
        case .perHour: return "$\(Int(listing.pricePerPerson)) × \(numberOfHours) hour\(numberOfHours == 1 ? "" : "s")"
        case .perDay:
            return listing.tripLength == .multiDay
                ? "$\(Int(listing.pricePerPerson)) × \(listing.packageDayCount) days"
                : "$\(Int(listing.pricePerPerson)) flat rate"
        case .flatRate: return "$\(Int(listing.pricePerPerson)) flat rate"
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if let confirmedBooking {
                    confirmationContent(for: confirmedBooking)
                } else {
                    formContent
                }
            }
            .navigationTitle(confirmedBooking == nil ? "Request Booking" : "")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.appBackground, for: .navigationBar)
            .toolbarBackgroundVisibility(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                if confirmedBooking == nil {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { dismiss() }
                    }
                }
            }
        }
    }

    // MARK: - Form

    // Was a Form/List -- switched to a plain ScrollView + custom "card"
    // sections (same visual language as GuidzDashboardView's payoutsSection)
    // after a real, user-reported bug: a List/Form row isn't built to host
    // a whole grid of ~40 independent tappable buttons the way
    // BookingDayPickerView needs to. Every booking attempt showed the same
    // symptom regardless of listing -- tapping any day in the picker
    // selected the wrong one and the picker eventually locked up entirely
    // -- which pointed at the row's own tap handling fighting with the
    // grid's buttons for which one actually receives a touch, not at
    // anything date-specific. Taking the picker out of Form/List rows
    // entirely removes that conflict at the root instead of continuing to
    // patch symptoms of it.
    private func card<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(.appTextOnDark)
                .padding(.horizontal)

            content()
                .padding()
                .background(Color.appCard)
                .cornerRadius(16)
                .padding(.horizontal)
        }
    }

    private var formContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(listing.title)
                        .font(.headline)
                    Text(listing.locationName)
                        .font(.subheadline)
                        .foregroundColor(.appSecondaryText)
                }
                .padding()
                .background(Color.appCard)
                .cornerRadius(16)
                .padding(.horizontal)
                .padding(.top)

                card(listing.tripLength == .multiDay ? "Start Date" : "Trip Date") {
                    BookingDayPickerView(
                        listing: listing,
                        blockedDates: blockedDates,
                        selectedDate: $selectedDate
                    )
                }

                card("Guests") {
                    VStack(alignment: .leading, spacing: 8) {
                        Stepper(value: $numberOfAdults, in: 1...(listing.maxGroupSize - numberOfChildren)) {
                            Text("\(numberOfAdults) adult\(numberOfAdults == 1 ? "" : "s")")
                        }
                        Stepper(value: $numberOfChildren, in: 0...(listing.maxGroupSize - numberOfAdults)) {
                            Text("\(numberOfChildren) child\(numberOfChildren == 1 ? "" : "ren")")
                        }
                        Text("Max group size: \(listing.maxGroupSize)")
                            .font(.caption)
                            .foregroundColor(.appSecondaryText)

                        if listing.pricingUnit == .perHour {
                            Stepper(value: $numberOfHours, in: 1...12) {
                                Text("\(numberOfHours) hour\(numberOfHours == 1 ? "" : "s")")
                            }
                        }
                    }
                }

                card("Price Summary") {
                    VStack(spacing: 8) {
                        HStack {
                            Text(priceSummaryLine)
                            Spacer()
                            Text("$\(Int(totalPrice))")
                        }
                        Divider()
                        HStack {
                            Text("Total")
                                .fontWeight(.bold)
                            Spacer()
                            Text("$\(Int(totalPrice))")
                                .fontWeight(.bold)
                        }
                    }
                }

                if let errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundColor(.red)
                        .padding(.horizontal)
                }

                Button {
                    if userSession.currentUser?.hasAcceptedCurrentWaiver == true {
                        submitBooking()
                    } else {
                        showWaiverSheet = true
                    }
                } label: {
                    if isSubmitting {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else {
                        Text("Confirm Booking Request")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isSubmitting)
                .padding(.horizontal)
                .padding(.bottom, 20)
            }
        }
        .background(Color.appBackground)
        .sheet(isPresented: $showWaiverSheet) {
            LiabilityWaiverView(onAccepted: submitBooking)
        }
        .task {
            await loadBlockedDates()
        }
    }

    // Step 1 of 2: ask the backend to authorize a card for this trip's
    // price (computed server-side, never trusted from here), then present
    // Stripe's UI to actually collect the card. The booking row itself
    // only gets created once that authorization succeeds -- see
    // handlePaymentResult below.
    //
    // Presents PaymentSheet directly via its UIKit API (present(from:))
    // instead of the .paymentSheet() SwiftUI modifier -- that modifier
    // reassigns a @State PaymentSheet and flips isPresented as two
    // separate state changes, which triggered "Modifying state during view
    // update" here and silently failed to present (this view is itself
    // already inside a sheet, which may be why). Calling the underlying
    // API directly sidesteps that whole SwiftUI/UIKit bridging path.
    private func submitBooking() {
        errorMessage = nil
        isSubmitting = true
        Task {
            do {
                let response: CreatePaymentIntentResponse = try await supabase.functions.invoke(
                    "stripe-create-payment-intent",
                    options: FunctionInvokeOptions(
                        body: CreatePaymentIntentRequest(listingId: listing.id, numberOfGuests: numberOfGuests, hours: hoursIfApplicable)
                    )
                )

                pendingPaymentIntentId = response.paymentIntentId

                var configuration = PaymentSheet.Configuration()
                configuration.merchantDisplayName = "TruGuidz"
                let sheet = PaymentSheet(
                    paymentIntentClientSecret: response.clientSecret,
                    configuration: configuration
                )
                isSubmitting = false

                guard let presenter = Self.topMostViewController() else {
                    errorMessage = "Could not find a screen to present payment on."
                    return
                }

                sheet.present(from: presenter) { result in
                    Task { @MainActor in
                        handlePaymentResult(result)
                    }
                }
            } catch {
                isSubmitting = false
                errorMessage = error.localizedDescription
            }
        }
    }

    private static func topMostViewController() -> UIViewController? {
        guard let scene = UIApplication.shared.connectedScenes
            .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene,
            let root = scene.windows.first(where: { $0.isKeyWindow })?.rootViewController else {
            return nil
        }
        var top = root
        while let presented = top.presentedViewController {
            top = presented
        }
        return top
    }

    // Step 2 of 2: Stripe's sheet handled the actual card entry and
    // authorization -- this just reacts to how it went.
    private func handlePaymentResult(_ result: PaymentSheetResult) {
        switch result {
        case .completed:
            guard let explorerId = userSession.currentUser?.id,
                  let paymentIntentId = pendingPaymentIntentId else { return }
            Task {
                do {
                    confirmedBooking = try await bookingStore.createBooking(
                        listing: listing,
                        explorerId: explorerId,
                        date: selectedDate,
                        numberOfAdults: numberOfAdults,
                        numberOfChildren: numberOfChildren,
                        hours: hoursIfApplicable,
                        stripePaymentIntentId: paymentIntentId
                    )
                } catch {
                    errorMessage = error.localizedDescription
                }
            }
        case .canceled:
            break
        case .failed(let error):
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Confirmation

    private func confirmationContent(for booking: Booking) -> some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundColor(.green)

            Text("Booking Requested")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.appTextOnDark)

            Text("Your request for \(listing.title) has been sent. You'll be notified once the guide confirms.")
                .font(.subheadline)
                .foregroundColor(.appSecondaryTextOnDark)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            VStack(spacing: 8) {
                summaryRow(label: "Date", value: booking.date.formatted(date: .abbreviated, time: .omitted))
                summaryRow(label: "Guests", value: booking.guestSummary)
                summaryRow(label: "Total", value: "$\(Int(booking.totalPrice))")
            }
            .padding()
            .background(Color.appCard)
            .cornerRadius(16)
            .padding(.horizontal, 32)

            Spacer()

            Button {
                dismiss()
            } label: {
                Text("Done")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .padding(.horizontal, 32)
            .padding(.bottom, 20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.appBackground)
    }

    private func summaryRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .foregroundColor(.appSecondaryText)
            Spacer()
            Text(value)
                .fontWeight(.semibold)
        }
    }
}

#Preview {
    BookingRequestView(listing: Listing.mockListings[0])
        .environmentObject(UserSession.previewExplorer)
        .environmentObject(BookingStore())
}
