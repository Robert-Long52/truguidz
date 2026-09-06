import SwiftUI

// Month-grid view of trip days -- confirmed (paid, locked in) vs. pending
// (requested, awaiting a decision) vs. open, at a glance. Used on both the
// guide dashboard (their incoming bookings) and the explorer Bookings tab
// (their own trips) -- same component, just handed a different bookings
// list, since "which days have something happening" is the same concept
// either way.
struct AvailabilityCalendarView: View {
    let bookings: [Booking]

    @State private var displayedMonth: Date = Calendar.current.dateInterval(of: .month, for: Date())?.start ?? Date()

    private let calendar = Calendar.current
    private let weekdaySymbols = ["S", "M", "T", "W", "T", "F", "S"]

    // Confirmed wins over pending when a day somehow has both -- a
    // confirmed trip is the one that's actually happening.
    //
    // Walks the full date...endDate span, not just the start day -- a
    // multi-day package's real span lives on endDate (see Booking.swift),
    // and only marking the start day made a 6-day trip look like it only
    // occupied its first day on this calendar, both on the guide
    // dashboard and the explorer's own Bookings tab. Same expansion
    // BookingRequestView.blockedDates already does correctly for the
    // day-picker's blackout calendar -- this view just never got it.
    private var statusByDay: [Date: BookingStatus] {
        var result: [Date: BookingStatus] = [:]
        for booking in bookings where booking.status == .pending || booking.status == .confirmed {
            var day = calendar.startOfDay(for: booking.date)
            let lastDay = calendar.startOfDay(for: booking.endDate)
            while day <= lastDay {
                if result[day] != .confirmed {
                    result[day] = booking.status
                }
                guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
                day = next
            }
        }
        return result
    }

    // Standard calendar-grid trick: walk from the start of the first full
    // week containing the 1st, through the end of the month, padding both
    // ends with nil so every row has exactly 7 slots.
    private var monthGrid: [Date?] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: displayedMonth),
              let firstWeek = calendar.dateInterval(of: .weekOfMonth, for: monthInterval.start) else {
            return []
        }
        var days: [Date?] = []
        var current = firstWeek.start
        while current < monthInterval.end {
            days.append(current >= monthInterval.start ? current : nil)
            current = calendar.date(byAdding: .day, value: 1, to: current)!
        }
        while days.count % 7 != 0 {
            days.append(nil)
        }
        return days
    }

    private var monthTitle: String {
        displayedMonth.formatted(.dateTime.month(.wide).year())
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(monthTitle)
                    .font(.headline)

                Spacer()

                // Bare SF Symbol buttons with no frame/padding have a
                // tappable area barely bigger than the glyph itself, and
                // sitting directly adjacent with no gap made it easy to
                // miss both or hit the wrong one -- a real usability bug,
                // not a logic one. Explicit frame + contentShape makes the
                // whole square tappable, not just the icon's rendered
                // pixels, and the gap keeps the two from being confused.
                HStack(spacing: 20) {
                    Button {
                        changeMonth(by: -1)
                    } label: {
                        Image(systemName: "chevron.left")
                            .frame(width: 32, height: 32)
                            .contentShape(Rectangle())
                    }

                    Button {
                        changeMonth(by: 1)
                    } label: {
                        Image(systemName: "chevron.right")
                            .frame(width: 32, height: 32)
                            .contentShape(Rectangle())
                    }
                }
            }

            HStack(spacing: 0) {
                ForEach(Array(weekdaySymbols.enumerated()), id: \.offset) { _, symbol in
                    Text(symbol)
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundColor(.appSecondaryText)
                        .frame(maxWidth: .infinity)
                }
            }

            // Explicit date-based identity, not just the ambient offset --
            // see BookingDayPickerView's comment on the real tap-
            // misattribution bug this caused there when the same offset
            // means a different date after changing months. This view has
            // no per-cell interaction today, but there's no reason to
            // leave the same latent footgun in place here too.
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7), spacing: 6) {
                ForEach(Array(monthGrid.enumerated()), id: \.offset) { index, day in
                    if let day {
                        dayCell(for: day)
                            .id(day.timeIntervalSince1970)
                    } else {
                        Color.clear.frame(height: 34)
                            .id("placeholder-\(index)")
                    }
                }
            }

            HStack(spacing: 16) {
                legendItem(color: fillColor(for: .confirmed), label: "Booked")
                legendItem(color: fillColor(for: .pending), label: "Pending")
                legendItem(color: fillColor(for: nil), label: "Open")
            }
            .padding(.top, 4)
        }
        .padding()
        .background(Color.appCard)
        .cornerRadius(16)
    }

    private func dayCell(for day: Date) -> some View {
        let status = statusByDay[day]
        let dayNumber = calendar.component(.day, from: day)

        return Text("\(dayNumber)")
            .font(.caption)
            .fontWeight(status == nil ? .regular : .bold)
            .foregroundColor(status == nil ? .primary : .white)
            .frame(height: 34)
            .frame(maxWidth: .infinity)
            .background(fillColor(for: status))
            .clipShape(Circle())
    }

    private func fillColor(for status: BookingStatus?) -> Color {
        switch status {
        case .confirmed, .completed: return .appBackground
        case .pending: return .accentColor
        case .cancelled, nil: return Color(.systemGray6)
        }
    }

    private func legendItem(color: Color, label: String) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 10, height: 10)
            Text(label)
                .font(.caption2)
                .foregroundColor(.appSecondaryText)
        }
    }

    private func changeMonth(by value: Int) {
        if let newMonth = calendar.date(byAdding: .month, value: value, to: displayedMonth) {
            displayedMonth = newMonth
        }
    }
}

#Preview {
    AvailabilityCalendarView(bookings: Booking.mockBookings)
        .padding()
        .background(Color.appBackground)
}
