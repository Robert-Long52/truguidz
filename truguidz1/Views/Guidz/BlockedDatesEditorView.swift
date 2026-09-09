import SwiftUI

// A guide's own "black out a day" picker -- similar month-grid shape to
// AvailabilityCalendarView/BookingDayPickerView, but this one is a
// multi-select toggle rather than a single blackout-aware pick: tapping an
// open day blocks it, tapping a blocked day unblocks it. A day that
// already has a confirmed trip on it can't be toggled either way here --
// blocking it wouldn't do anything (the trip's already happening) and
// unblocking isn't a concept that applies to it.
struct BlockedDatesEditorView: View {
    @Binding var blockedDates: Set<String>
    let occupiedDates: Set<String>

    @Environment(\.dismiss) private var dismiss
    @State private var displayedMonth = Calendar.current.dateInterval(of: .month, for: Date())?.start ?? Date()

    private let calendar = Calendar.current
    private let weekdaySymbols = ["S", "M", "T", "W", "T", "F", "S"]

    private enum DayState {
        case past, occupied, blocked, open
    }

    private func key(for day: Date) -> String {
        ListingDateFormat.formatter.string(from: day)
    }

    private func state(for day: Date) -> DayState {
        let today = calendar.startOfDay(for: Date())
        if day < today { return .past }
        let dayKey = key(for: day)
        if occupiedDates.contains(dayKey) { return .occupied }
        if blockedDates.contains(dayKey) { return .blocked }
        return .open
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

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text("Tap any day to block it off. Explorers won't be able to request a trip on a blocked day.")
                    .font(.subheadline)
                    .foregroundColor(.appSecondaryText)
                    .padding(.horizontal)
                    .padding(.top, 8)

                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text(monthTitle)
                            .font(.headline)
                        Spacer()
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

                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7), spacing: 6) {
                        ForEach(Array(monthGrid.enumerated()), id: \.offset) { index, day in
                            if let day {
                                dayCell(for: day).id(day.timeIntervalSince1970)
                            } else {
                                Color.clear.frame(height: 36).id("placeholder-\(index)")
                            }
                        }
                    }

                    HStack(spacing: 16) {
                        legendItem(color: .red.opacity(0.7), label: "Blocked")
                        legendItem(color: Color(.systemGray5), label: "Booked")
                        legendItem(color: .clear, label: "Open", outlined: true)
                    }
                    .padding(.top, 4)
                }
                .padding()
                .background(Color.appCard)
                .cornerRadius(16)
                .padding(.horizontal)

                if !blockedDates.isEmpty {
                    Button(role: .destructive) {
                        blockedDates.removeAll()
                    } label: {
                        Text("Clear All Blocked Dates")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .padding(.horizontal)
                }

                Spacer()
            }
            .background(Color.appBackground)
            .navigationTitle("Blocked Dates")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.appBackground, for: .navigationBar)
            .toolbarBackgroundVisibility(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func dayCell(for day: Date) -> some View {
        let dayState = state(for: day)
        let dayNumber = calendar.component(.day, from: day)

        return Button {
            let dayKey = key(for: day)
            if blockedDates.contains(dayKey) {
                blockedDates.remove(dayKey)
            } else {
                blockedDates.insert(dayKey)
            }
        } label: {
            Text("\(dayNumber)")
                .font(.subheadline)
                .fontWeight(dayState == .blocked ? .bold : .regular)
                .foregroundColor(textColor(for: dayState))
                .frame(height: 36)
                .frame(maxWidth: .infinity)
                .background(fillColor(for: dayState))
                .clipShape(Circle())
        }
        .disabled(dayState == .past || dayState == .occupied)
    }

    private func textColor(for dayState: DayState) -> Color {
        switch dayState {
        case .blocked: return .white
        case .open: return .primary
        case .occupied: return .appSecondaryText.opacity(0.5)
        case .past: return .appSecondaryText.opacity(0.3)
        }
    }

    private func fillColor(for dayState: DayState) -> Color {
        switch dayState {
        case .blocked: return .red.opacity(0.7)
        case .open, .past: return .clear
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
    @Previewable @State var blocked: Set<String> = []
    return BlockedDatesEditorView(blockedDates: $blocked, occupiedDates: [])
}
