import SwiftUI
import PhotosUI
import UIKit
import Supabase
import StripePaymentSheet

private struct VerificationFeeIntentResponse: Decodable {
    let feeRequired: Bool
    let clientSecret: String?
    let paymentIntentId: String?
}

private struct VerificationSubmitRequest: Encodable {
    let paymentIntentId: String?
    let phoneNumber: String
    let yearsExperience: Int
    let bio: String
    let idDocumentPath: String
}

struct GuideApplicationView: View {
    @EnvironmentObject var userSession: UserSession
    @Environment(\.dismiss) private var dismiss

    @State private var phoneNumber: String = ""
    @State private var yearsExperience: Int = 1
    @State private var bio: String = ""
    @State private var agreedToBackgroundCheck = false

    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var selectedImageData: Data?

    @State private var isSubmitted = false
    @State private var isSubmitting = false
    @State private var errorMessage: String?
    @State private var showWaiverSheet = false

    private var previewImage: Image? {
        guard let selectedImageData, let uiImage = UIImage(data: selectedImageData) else { return nil }
        return Image(uiImage: uiImage)
    }

    private var canSubmit: Bool {
        !phoneNumber.trimmingCharacters(in: .whitespaces).isEmpty &&
        !bio.trimmingCharacters(in: .whitespaces).isEmpty &&
        selectedImageData != nil &&
        agreedToBackgroundCheck
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
            .navigationTitle(isSubmitted ? "" : "Guide Application")
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
                Text("Tell us a bit about yourself and upload a photo ID. We manually review every application before you can list trips.")
                    .font(.subheadline)
                    .foregroundColor(.appSecondaryText)
            }

            Section {
                TextField("Phone Number", text: $phoneNumber)
                    .keyboardType(.phonePad)
            } header: {
                Text.darkSectionLabel("Contact")
            }

            Section {
                Stepper(value: $yearsExperience, in: 0...50) {
                    Text("\(yearsExperience) year\(yearsExperience == 1 ? "" : "s") guiding")
                }
            } header: {
                Text.darkSectionLabel("Experience")
            }

            Section {
                TextEditor(text: $bio)
                    .frame(height: 120)
                Text("Explorers will see this on your listings, so make it count.")
                    .font(.caption)
                    .foregroundColor(.appSecondaryText)
            } header: {
                Text.darkSectionLabel("Bio")
            }

            Section {
                PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                    if let previewImage {
                        previewImage
                            .resizable()
                            .scaledToFill()
                            .frame(height: 160)
                            .frame(maxWidth: .infinity)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .clipped()
                    } else {
                        HStack {
                            Image(systemName: "person.text.rectangle")
                            Text("Upload a Government-Issued Photo ID")
                        }
                        .foregroundColor(.accentColor)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                    }
                }
                .onChange(of: selectedPhotoItem) { _, newItem in
                    Task {
                        guard let newItem,
                              let data = try? await newItem.loadTransferable(type: Data.self),
                              // A higher cap than the default (1600) -- an ID
                              // needs to stay legible for manual review, unlike
                              // a trip photo shown small in a card.
                              let jpegData = StorageService.processImageForUpload(data, maxDimension: 2200) else { return }
                        selectedImageData = jpegData
                    }
                }

                Text("Only used to verify your identity. Never shown publicly.")
                    .font(.caption)
                    .foregroundColor(.appSecondaryText)
            } header: {
                Text.darkSectionLabel("Photo ID")
            }

            Section {
                Toggle(isOn: $agreedToBackgroundCheck) {
                    Text("I consent to identity verification as part of the guide application process.")
                        .font(.subheadline)
                }
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
                    if userSession.currentUser?.hasAcceptedCurrentWaiver == true {
                        submitApplication()
                    } else {
                        showWaiverSheet = true
                    }
                } label: {
                    if isSubmitting {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else {
                        Text("Submit Application")
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
        .sheet(isPresented: $showWaiverSheet) {
            LiabilityWaiverView(onAccepted: submitApplication)
        }
        .scrollContentBackground(.hidden)
        .background(Color.appBackground)
    }

    // Step 1 of 2 (only when a fee is actually configured -- it's waived
    // right now, see guide-verification-fee-intent): charge it via
    // PaymentSheet, presented directly through its UIKit API rather than
    // the .paymentSheet() SwiftUI modifier -- that modifier caused a real,
    // reproducible bug in BookingRequestView (see the comment there), so
    // this mirrors the fix rather than risk hitting it again here.
    private func submitApplication() {
        errorMessage = nil
        isSubmitting = true
        Task {
            do {
                let response: VerificationFeeIntentResponse = try await supabase.functions.invoke(
                    "guide-verification-fee-intent"
                )

                guard response.feeRequired else {
                    await finishSubmitting(paymentIntentId: nil)
                    return
                }

                guard let clientSecret = response.clientSecret, let paymentIntentId = response.paymentIntentId else {
                    isSubmitting = false
                    errorMessage = "Something went wrong setting up payment. Try again."
                    return
                }

                var configuration = PaymentSheet.Configuration()
                configuration.merchantDisplayName = "TruGuidz"
                let sheet = PaymentSheet(
                    paymentIntentClientSecret: clientSecret,
                    configuration: configuration
                )
                isSubmitting = false

                guard let presenter = Self.topMostViewController() else {
                    errorMessage = "Could not find a screen to present payment on."
                    return
                }

                sheet.present(from: presenter) { result in
                    Task { @MainActor in
                        await handlePaymentResult(result, paymentIntentId: paymentIntentId)
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

    private func handlePaymentResult(_ result: PaymentSheetResult, paymentIntentId: String) async {
        switch result {
        case .completed:
            await finishSubmitting(paymentIntentId: paymentIntentId)
        case .canceled:
            break
        case .failed(let error):
            errorMessage = error.localizedDescription
        }
    }

    // Step 2 of 2: fee succeeded (or was waived) -- upload the ID document,
    // then submit the application. guide-verification-submit re-verifies
    // the PaymentIntent server-side when one exists, writes the profile
    // fields, and (once real Checkr is wired up) will create the candidate
    // + invitation -- for now, an admin reviews id_document_path by hand.
    private func finishSubmitting(paymentIntentId: String?) async {
        guard let guideId = userSession.currentUser?.id, let selectedImageData else { return }

        isSubmitting = true
        do {
            let idDocumentPath = try await StorageService.uploadGuideVerificationDocument(
                guideId: guideId,
                data: selectedImageData
            )

            try await supabase.functions.invoke(
                "guide-verification-submit",
                options: FunctionInvokeOptions(
                    body: VerificationSubmitRequest(
                        paymentIntentId: paymentIntentId,
                        phoneNumber: phoneNumber,
                        yearsExperience: yearsExperience,
                        bio: bio,
                        idDocumentPath: idDocumentPath
                    )
                )
            )

            if var user = userSession.currentUser {
                user.role = .guide
                user.verificationStatus = .pending
                user.phoneNumber = phoneNumber
                user.yearsExperience = yearsExperience
                user.bio = bio
                userSession.currentUser = user
            }

            isSubmitting = false
            isSubmitted = true
        } catch {
            isSubmitting = false
            let paidNote = paymentIntentId != nil ? " Contact support — you won't be charged again." : ""
            errorMessage = "We couldn't submit your application: \(error.localizedDescription).\(paidNote)"
        }
    }

    // MARK: - Confirmation

    private var confirmationContent: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundColor(.green)

            Text("Application Submitted")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.appTextOnDark)

            Text("We're reviewing your application now. You'll be notified once it's complete.")
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
    GuideApplicationView()
        .environmentObject(UserSession.previewExplorer)
}
