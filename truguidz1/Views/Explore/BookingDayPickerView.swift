import SwiftUI

// SwiftUI's native DatePicker only supports a single continuous open
// range (`in: Date()...`) -- it has no way to black out individual dates
// scattered inside that range, which is exactly what's needed here (a
// guide's already-confirmed days). This is a small custom month-grid
// picker instead, similar in spirit to AvailabilityCalendarView but
// interactive: tapping a day selects it, tapping a blacked-out day does
// nothing at all.
struct BookingDayPickerView: View {
    let listing: Listing
    // Start-of-day dates (in the current calendar) that are unavailable --
    // either a day this guide already has a confirmed/completed trip on,
    // computed by the caller from BookingStore, since this view has no
    // store access of its own and shouldn't need any.
    let blockedDates: Set<Date>
    @Binding var selectedDate: Date

    @State private var displayedMonth: Date

    private let calendar = Calendar.current
    private let weekdaySymbols = ["S", "M", "T", "W", "T", "F", "S"]

    init(listing: Listing, blockedDates: Set<Date>, selectedDate: Binding<Date>) {
        self.listing = listing
        self.blockedDates = blockedDates
        self._selectedDate = selectedDate
        self._displayedMonth = State(
            initialValue: Calendar.current.dateInterval(of: .month, for: selectedDate.wrappedValue)?.start ?? Date()
        )
    }

    // Split into two "can't tap this" reasons instead of one -- a day can
    // be unselectable either because it's genuinely part of a confirmed
    // trip (occupied), or because it's merely a bad *starting* point for
    // a multi-day package that would run into an occupied day further
    // out, while the day itself is perfectly free. Collapsing both into
    // one "unavailable" gray (as this used to do) made a legitimate,
    // non-conflicting booking that happened to pass through a
    // blockedStart day look like it had booked through something taken,
    // which is exactly the confusion a user hit in testing.
    private enum DayState {
        case occupied, blockedStart, available, selected
    }

    // The full span a booking starting on `day` would actually occupy --
    // just [day] for a single-day trip, or `packageDayCount` consecutive
    // days for a multi-day package. A start day is only pickable if every
    // day in this span is free, not just the start day itself.
    private func range(startingAt day: Date) -> [Date] {
        (0..<listing.packageDayCount).compactMap {
            calendar.date(byAdding: .day, value: $0, to: day)
        }
    }

    private func isWithinListingSchedule(_ day: Date) -> Bool {
        let weekdayIndex = calendar.component(.weekday, from: day) - 1
        guard let weekday = Weekday(rawValue: weekdayIndex) else { return false }
        return listing.availableDays.contains(weekday)
    }

    private func isSelectable(_ day: Date) -> Bool {
        let today = calendar.startOfDay(for: Date())
        guard day >= today else { return false }

        // A multi-day package runs as one continuous block -- a guide
        // doesn't pause a 6-day expedition every weekend, so "which
        // weekdays this runs on" doesn't apply the way it does for a
        // repeating single-day trip (and worse, requiring every day in a
        // 6-or-7-day span to individually fall on an available weekday can
        // make a package mathematically unbookable if any weekday is
        // excluded at all). Only single-day trip lengths are restricted to
        // specific weekdays.
        if listing.tripLength != .multiDay {
            guard isWithinListingSchedule(day) else { return false }
        }

        return range(startingAt: day).allSatisfy { !blockedDates.contains(calendar.startOfDay(for: $0)) }
    }

    private func state(for day: Date) -> DayState {
        // Only trust the current selection's range if its *start* day is
        // still actually selectable -- otherwise a stale/default
        // selectedDate (e.g. one that predates a fresh blockedDates load)
        // would paint its whole range blue as "selected" without ever
        // being checked, which is exactly how an invalid range could look
        // valid and sail through to submission.
        let startOfSelection = calendar.startOfDay(for: selectedDate)
        if isSelectable(startOfSelection) {
            let normalizedSelectedRange = Set(range(startingAt: startOfSelection).map { calendar.startOfDay(for: $0) })
            if normalizedSelectedRange.contains(calendar.startOfDay(for: day)) {
                return .selected
            }
        }
        if blockedDates.contains(calendar.startOfDay(for: day)) {
            return .occupied
        }
        return isSelectable(day) ? .available : .blockedStart
    }

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

    private var canGoToPreviousMonth: Bool {
        let currentMonthStart = calendar.dateInterval(of: .month, for: Date())?.start ?? Date()
        return displayedMonth > currentMonthStart
    }

    private var packageEndDate: Date? {
        guard listing.tripLength == .multiDay else { return nil }
        return calendar.date(byAdding: .day, value: listing.packageDayCount - 1, to: selectedDate)
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
                    .disabled(!canGoToPreviousMonth)

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

            // Cells are identified by offset (position in the grid), but
            // which *date* sits at a given offset changes every time
            // displayedMonth changes -- e.g. offset 10 might be Aug 11 one
            // render and Sep 8 the next. Confirmed live that this caused
            // real tap misattribution: every tap "selected" the same wrong
            // range regardless of which day was actually tapped, then
            // locked up entirely after a couple of taps. Forcing each
            // cell's true identity to the date it represents (`.id(...)`)
            // instead of trusting the ambient offset-based identity to
            // carry across a month change fixes this at the root.
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7), spacing: 6) {
                ForEach(Array(monthGrid.enumerated()), id: \.offset) { index, day in
                    if let day {
                        dayCell(for: day)
                            .id(day.timeIntervalSince1970)
                    } else {
                        Color.clear.frame(height: 36)
                            .id("placeholder-\(index)")
                    }
                }
            }

            if listing.tripLength == .multiDay, let packageEndDate {
                HStack {
                    Text("\(listing.packageDayCount)-day package, ends")
                    Spacer()
                    Text(packageEndDate.formatted(date: .abbreviated, time: .omitted))
                        .fontWeight(.semibold)
                }
                .font(.subheadline)
                .foregroundColor(.appSecondaryText)
            }

            HStack(spacing: 16) {
                legendItem(color: .accentColor, label: "Selected")
                legendItem(color: Color(.systemGray5), label: "Booked")
                if listing.tripLength == .multiDay {
                    legendItem(color: .clear, label: "Too close to a trip", outlined: true)
                }
            }
            .padding(.top, 4)
        }
    }

    private func dayCell(for day: Date) -> some View {
        let dayState = state(for: day)
        let dayNumber = calendar.component(.day, from: day)

        return Button {
            selectedDate = calendar.date(bySettingHour: 12, minute: 0, second: 0, of: day) ?? day
        } label: {
            Text("\(dayNumber)")
                .font(.subheadline)
                .fontWeight(dayState == .selected ? .bold : .regular)
                .foregroundColor(textColor(for: dayState))
                .frame(height: 36)
                .frame(maxWidth: .infinity)
                .background(fillColor(for: dayState))
                .clipShape(Circle())
                .overlay(
                    Circle().stroke(Color(.systemGray4), lineWidth: dayState == .blockedStart ? 1 : 0)
                )
        }
        .disabled(dayState == .occupied || dayState == .blockedStart)
    }

    private func textColor(for dayState: DayState) -> Color {
        switch dayState {
        case .selected: return .white
        case .available: return .primary
        case .occupied: return .appSecondaryText.opacity(0.5)
        case .blockedStart: return .appSecondaryText.opacity(0.6)
        }
    }

    private func fillColor(for dayState: DayState) -> Color {
        switch dayState {
        case .selected: return .accentColor
        case .available, .blockedStart: return .clear
        case .occupied: return Color(.systemGray6)
        }
    }

    private func legendItem(color: Color, label: String, outlined: Bool = false) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 10, height: 10)
                .overlay(Circle().stroke(Color(.systemGray4), lineWidth: outlined ? 1 : 0))
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
    @Previewable @State var selectedDate = Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()
    return BookingDayPickerView(
        listing: Listing.mockListings[0],
        blockedDates: [Calendar.current.startOfDay(for: Calendar.current.date(byAdding: .day, value: 3, to: Date())!)],
        selectedDate: $selectedDate
    )
    .padding()
    .background(Color.appCard)
}
