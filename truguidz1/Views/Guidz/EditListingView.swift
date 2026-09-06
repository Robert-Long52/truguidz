import SwiftUI
import PhotosUI
import UIKit

struct EditListingView: View {
    let listing: Listing

    @EnvironmentObject var listingStore: ListingStore
    @EnvironmentObject var bookingStore: BookingStore
    @Environment(\.dismiss) private var dismiss

    @State private var title: String
    @State private var description: String
    @State private var category: ExperienceType
    @State private var pricePerPerson: String
    @State private var pricingUnit: PricingUnit
    @State private var maxGroupSize: Int
    @State private var locationName: String
    @State private var tripLength: TripLength
    @State private var packageDays: Int
    @State private var selectedDays: Set<Weekday>

    @State private var selectedPhotoItems: [PhotosPickerItem] = []
    @State private var selectedImagesData: [Data] = []

    @State private var isSaving = false
    @State private var errorMessage: String?

    init(listing: Listing) {
        self.listing = listing
        _title = State(initialValue: listing.title)
        _description = State(initialValue: listing.description)
        _category = State(initialValue: listing.category)
        _pricePerPerson = State(initialValue: String(format: "%.2f", listing.pricePerPerson))
        _pricingUnit = State(initialValue: listing.pricingUnit)
        _maxGroupSize = State(initialValue: listing.maxGroupSize)
        _locationName = State(initialValue: listing.locationName)
        _tripLength = State(initialValue: listing.tripLength)
        _packageDays = State(initialValue: listing.packageDays ?? 3)
        _selectedDays = State(initialValue: Set(listing.availableDays))
    }

    // Pending bookings already locked in their own price/guest count when
    // they were requested, so editing this listing can't touch them --
    // this is purely informational, not a block.
    private var pendingBookingCount: Int {
        bookingStore.bookings.filter { $0.listingId == listing.id && $0.status == .pending }.count
    }

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty &&
        !description.trimmingCharacters(in: .whitespaces).isEmpty &&
        !locationName.trimmingCharacters(in: .whitespaces).isEmpty &&
        Double(pricePerPerson) != nil &&
        (Double(pricePerPerson) ?? 0) > 0 &&
        !selectedDays.isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                if pendingBookingCount > 0 {
                    Section {
                        Label(
                            "\(pendingBookingCount) pending booking request\(pendingBookingCount == 1 ? "" : "s") for this listing. Their price and guest count are already locked in and won't change — this only affects future bookings.",
                            systemImage: "info.circle.fill"
                        )
                        .font(.caption)
                        .foregroundColor(.appSecondaryText)
                    }
                }

                Section {
                    TextField("Title (e.g. Susquehanna Bass Excursion)", text: $title)

                    Picker("Category", selection: $category) {
                        Text("Fishing").tag(ExperienceType.fishing)
                        Text("Hunting").tag(ExperienceType.hunting)
                        Text("Hiking").tag(ExperienceType.hiking)
                        Text("Trail Riding").tag(ExperienceType.trailRiding)
                    }

                    Picker("Trip Length", selection: $tripLength) {
                        ForEach(TripLength.allCases, id: \.self) { length in
                            Text(length.label).tag(length)
                        }
                    }

                    if tripLength == .multiDay {
                        Stepper(value: $packageDays, in: 2...30) {
                            Text("\(packageDays) days")
                        }
                    }

                    TextField("Location (e.g. Catawissa, PA)", text: $locationName)
                } header: {
                    Text.darkSectionLabel("Trip Basics")
                }

                Section {
                    TextEditor(text: $description)
                        .frame(height: 120)
                } header: {
                    Text.darkSectionLabel("Description")
                }

                Section {
                    Picker("Charge", selection: $pricingUnit) {
                        ForEach(PricingUnit.allCases, id: \.self) { unit in
                            Text(unit.label).tag(unit)
                        }
                    }

                    HStack {
                        Text("$")
                        TextField("Price", text: $pricePerPerson)
                            .keyboardType(.decimalPad)
                        Text(pricingUnit.priceSuffix)
                            .foregroundColor(.appSecondaryText)
                    }

                    Stepper(value: $maxGroupSize, in: 1...20) {
                        Text("Max group size: \(maxGroupSize)")
                    }
                } header: {
                    Text.darkSectionLabel("Pricing & Group Size")
                }

                // A multi-day package runs as one continuous block once
                // booked -- there's no "which weekdays does this run on"
                // for a guide who doesn't pause a 6-day expedition every
                // weekend, so this picker only makes sense for a repeating
                // single-day trip.
                if tripLength != .multiDay {
                    Section {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Days")
                                .font(.caption)
                                .foregroundColor(.appSecondaryText)
                            MultiSelectChipRow(options: Weekday.allCases, selection: $selectedDays) { $0.short }
                        }
                    } header: {
                        Text.darkSectionLabel("Availability")
                    }
                }

                Section {
                    MultiPhotoPickerSection(
                        selectedItems: $selectedPhotoItems,
                        newImagesData: $selectedImagesData,
                        existingImageUrls: listing.imageUrls
                    )
                } header: {
                    Text.darkSectionLabel("Photos")
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }

                Section {
                    Button {
                        saveChanges()
                    } label: {
                        if isSaving {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                        } else {
                            Text("Save Changes")
                                .fontWeight(.semibold)
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!canSave || isSaving)
                    .listRowInsets(EdgeInsets())
                    .padding()
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.appBackground)
            .navigationTitle("Edit Listing")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.appBackground, for: .navigationBar)
            .toolbarBackgroundVisibility(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private func saveChanges() {
        guard let price = Double(pricePerPerson) else { return }

        errorMessage = nil
        isSaving = true

        Task {
            defer { isSaving = false }
            do {
                try await listingStore.updateListing(
                    listingId: listing.id,
                    title: title,
                    description: description,
                    category: category,
                    pricePerPerson: price,
                    pricingUnit: pricingUnit,
                    maxGroupSize: maxGroupSize,
                    locationName: locationName,
                    tripLength: tripLength,
                    packageDays: tripLength == .multiDay ? packageDays : nil,
                    availableDays: Array(selectedDays).sorted { $0.rawValue < $1.rawValue }
                )

                if !selectedImagesData.isEmpty {
                    do {
                        let urls = try await StorageService.uploadListingImages(
                            guideId: listing.guideId,
                            listingId: listing.id,
                            images: selectedImagesData
                        )
                        await listingStore.updateListingImages(listingId: listing.id, imageUrls: urls)
                    } catch {
                        print("Listing updated but photo upload failed: \(error)")
                    }
                }

                dismiss()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}

#Preview {
    EditListingView(listing: Listing.mockListings[0])
        .environmentObject(ListingStore())
        .environmentObject(BookingStore())
}
