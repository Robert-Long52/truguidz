import SwiftUI
import PhotosUI
import UIKit

struct CreateListingView: View {
    @EnvironmentObject var userSession: UserSession
    @EnvironmentObject var listingStore: ListingStore
    @Environment(\.dismiss) private var dismiss

    @State private var title: String = ""
    @State private var description: String = ""
    @State private var category: ExperienceType = .fishing
    @State private var pricePerPerson: String = ""
    @State private var pricingUnit: PricingUnit = .perPerson
    @State private var maxGroupSize: Int = 4
    @State private var locationName: String = ""
    @State private var tripLength: TripLength = .fullDay
    @State private var packageDays: Int = 3
    @State private var selectedDays: Set<Weekday> = Set(Weekday.allCases)

    @State private var selectedPhotoItems: [PhotosPickerItem] = []
    @State private var selectedImagesData: [Data] = []

    @State private var isSubmitted = false
    @State private var isSubmitting = false
    @State private var errorMessage: String?

    private var canSubmit: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty &&
        !description.trimmingCharacters(in: .whitespaces).isEmpty &&
        !locationName.trimmingCharacters(in: .whitespaces).isEmpty &&
        Double(pricePerPerson) != nil &&
        (Double(pricePerPerson) ?? 0) > 0 &&
        !selectedDays.isEmpty
    }

    var body: some View {
        NavigationStack {
            Group {
                if isSubmitted {
                    confirmationContent
                } else {
                    formContent
                }
            }
            .navigationTitle(isSubmitted ? "" : "New Listing")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.appBackground, for: .navigationBar)
            .toolbarBackgroundVisibility(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                if !isSubmitted {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { dismiss() }
                    }
                }
            }
        }
    }

    // MARK: - Form

    private var formContent: some View {
        Form {
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
                Text("Explorers see this on your listing's detail page.")
                    .font(.caption)
                    .foregroundColor(.appSecondaryText)
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

            // A multi-day package runs as one continuous block once booked --
            // there's no "which weekdays does this run on" for a guide who
            // doesn't pause a 6-day expedition every weekend, so this
            // picker only makes sense for a repeating single-day trip.
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
                    existingImageUrls: []
                )

                Text("Optional — you can add or change these later.")
                    .font(.caption)
                    .foregroundColor(.appSecondaryText)
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
                    submitListing()
                } label: {
                    if isSubmitting {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else {
                        Text("Publish Listing")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(!canSubmit || isSubmitting)
                .listRowInsets(EdgeInsets())
                .padding()
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.appBackground)
    }

    private func submitListing() {
        guard let guideId = userSession.currentUser?.id,
              let price = Double(pricePerPerson) else { return }

        errorMessage = nil
        isSubmitting = true

        Task {
            defer { isSubmitting = false }
            do {
                let inserted = try await listingStore.createListing(
                    guideId: guideId,
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
                            guideId: guideId,
                            listingId: inserted.id,
                            images: selectedImagesData
                        )
                        await listingStore.updateListingImages(listingId: inserted.id, imageUrls: urls)
                    } catch {
                        // The listing itself was created successfully -- don't fail the
                        // whole submission over a photo upload issue, just log it.
                        print("Listing created but photo upload failed: \(error)")
                    }
                }

                isSubmitted = true
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    // MARK: - Confirmation

    private var confirmationContent: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundColor(.green)

            Text("Listing Published")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.appTextOnDark)

            Text("\"\(title)\" is now live and explorers can book it.")
                .font(.subheadline)
                .foregroundColor(.appSecondaryTextOnDark)
                .multilineTextAlignment(.center)
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
}

#Preview {
    CreateListingView()
        .environmentObject(UserSession.previewApprovedGuide)
        .environmentObject(ListingStore())
}
