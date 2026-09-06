import SwiftUI

// Shared shell for static legal text -- Terms of Service and Privacy
// Policy are both just "show some text" screens, so one view covers both
// rather than duplicating the scaffolding. Real legal text still needs to
// come from a lawyer -- see the placeholder bodies below and the same
// caveat on LiabilityWaiverView.
struct LegalTextView: View {
    let title: String
    let text: String

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Label("Placeholder legal text", systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.orange)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.orange.opacity(0.15))
                    .cornerRadius(8)

                Text(text)
                    .font(.subheadline)
                    .foregroundColor(.primary)
            }
            .padding()
        }
        .background(Color.appCard)
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color.appBackground, for: .navigationBar)
        .toolbarBackgroundVisibility(.visible, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
    }
}

extension LegalTextView {
    static let termsOfService = LegalTextView(
        title: "Terms of Service",
        text: """
        [DRAFT -- not yet reviewed by a lawyer. Do not rely on this text for actual legal protection.]

        Terms & Conditions

        These terms and conditions apply to the TruGuidz app for mobile devices, together with any related services operated by Robert Long (collectively, the "Application"). Robert Long is hereby referred to as the "Service Provider".

        By downloading or using the Application, you agree to these Terms and Conditions. You should read them carefully before using the Application.

        What TruGuidz Is

        TruGuidz is a marketplace platform that connects independent outdoor guides ("Guides") with individuals seeking guided hunting, fishing, hiking, and trail-riding trips ("Explorers"). Guides are independent third parties -- they are not employees, agents, partners, or representatives of the Service Provider. The Service Provider does not itself provide guiding services, does not supervise Guides' conduct during a trip, and is not responsible for how a Guide conducts a trip. Guides are solely responsible for holding any licenses, permits, and insurance required by law to offer their services.

        "Verified" Guides have completed the Service Provider's current identity verification process, which consists of manual review of a submitted government-issued photo ID. This does not currently include a criminal background check. The Service Provider may introduce formal background checks in the future and will update this section if that changes.

        License to use the Application

        Subject to your compliance with these Terms, the Service Provider grants you a limited, non-exclusive, non-transferable, revocable license to install and use the Application on a mobile device for personal or internal business purposes. You may not reproduce, distribute, modify, create derivative works from, reverse engineer, decompile, or disassemble the Application, except as and only to the extent that such activity is expressly permitted by applicable law.

        Bookings, Payments, and Refunds

        Payments made through the Application are processed by Stripe, Inc. By making a booking, you authorize the Service Provider, via Stripe, to charge your selected payment method for the trip price shown at checkout. The Service Provider retains a service fee (currently 10%) from each completed booking; the remainder is paid to the Guide.

        A booking is not confirmed, and no charge is finalized, until the Guide accepts your request. If a Guide declines your request, any card authorization is released and you are not charged. If you cancel a confirmed (already-charged) booking, the amount paid is refunded to your original payment method, less any portion Stripe does not return on processed refunds where applicable. The Service Provider is not responsible for delays in refund processing caused by your bank or card issuer.

        The Service Provider will make reasonable efforts to prevent two Explorers from booking the same Guide for overlapping dates, but does not guarantee availability shown in the Application is error-free.

        Liability Waiver for Trip Participation

        Hunting, fishing, hiking, and trail-riding activities carry inherent risks, including risk of serious injury or death. Before completing a booking or applying to become a Guide, you will be required to separately review and accept the Application's Liability Waiver, which governs your assumption of these risks. That waiver is incorporated into these Terms by reference. Nothing in this section limits your rights under applicable law that cannot be lawfully excluded.

        Eligibility and Age Requirements

        You must be at least 13 years of age (or such higher age as required by applicable law) to browse or create an account on the Application. If you are below 13, a parent or legal guardian must review and accept these Terms on your behalf.

        Completing a paid booking, listing a trip as a Guide, or entering any other binding transaction through the Application requires that you be of legal age to enter into a contract in your jurisdiction (generally 18), or that a parent or legal guardian completes the transaction on your behalf and takes responsibility for it.

        Intellectual Property

        The Service Provider retains all intellectual property rights in the Application, including its code, design, trademarks, service marks, trade names, logos, and branding (the "IP"). Nothing in these Terms grants you any license or right to use the Service Provider's trademarks, logos, or branding for any purpose. You agree not to remove, alter, or obscure any copyright, trademark, or other proprietary notices displayed in or on the Application.

        Termination

        The Service Provider may suspend your access to the Application or services if you materially breach these Terms. The Service Provider will provide you with written notice of the breach and, where the breach is capable of cure, you will have 14 days from receipt of notice to remedy the breach. If you fail to cure the breach within that period, the Service Provider may terminate your access.

        The Service Provider may suspend or terminate your access immediately without notice if you violate applicable law, infringe intellectual property rights, engage in activity that could cause harm to other users or the Service Provider, or misrepresent your qualifications, licenses, or identity as a Guide.

        Upon termination, your right to use the Application will end and you must delete all copies from your devices. Termination of your account does not affect the Service Provider's or any Guide's rights or obligations regarding bookings that were already confirmed and completed before termination.

        Unauthorized copying, modification of the Application, any part of the Application, or the Service Provider's trademarks is strictly prohibited. Any attempts to extract the source code of the Application, translate the Application into other languages, or create derivative versions are not permitted. All trademarks, copyrights, database rights, and other intellectual property rights related to the Application remain the property of the Service Provider.

        User-Generated Content and Acceptable Use

        If this Application allows users to post, share, or upload content, you agree not to post content that:

        - Is illegal or violates third-party intellectual property rights (copyright, trademark, patents)
        - Is abusive, threatening, harassing, defamatory, or hate speech
        - Contains discrimination or incitement to violence or illegal activity
        - Is spam, phishing, or contains malware
        - Violates the privacy or personal data rights of others
        - Is misleading, false, or deceptive
        - Contains explicit violence or sexual content (unless age-gated appropriately)

        The Service Provider reserves the right to:

        - Remove or disable access to content that violates these guidelines
        - Suspend or terminate accounts of users who repeatedly violate these guidelines
        - Cooperate with law enforcement if illegal content is reported
        - Moderate, filter, or hide content that violates these Terms, applicable law, or the guidelines set out above

        Content submitted through the Application may be visible to other users or to the public, depending on how the Application functions. This includes listing photos and descriptions, guide bios, reviews, and profile information.

        If you believe content violates these Terms, infringes your rights, or is unlawful, you may report it to the Service Provider at longrobert346@yahoo.com. The report should include enough information for the Service Provider to identify the content, evaluate the complaint, and contact you if follow-up is required.

        Where the Application provides such features, you may also report content, block other users, or mute notifications directly through the Application's interface. The Service Provider will review in-app reports with the same standards described in these Terms.

        The Service Provider may review reported content, request additional information where necessary, remove or restrict access to content, and take action against the responsible account where appropriate. Users affected by moderation decisions may contact the Service Provider at longrobert346@yahoo.com to request further review. The Service Provider will respond to appeals within a reasonable period and provide the reasons for any upheld moderation decision, subject to applicable law.

        By submitting User-Generated Content you grant the Service Provider a non-exclusive, worldwide, royalty-free license to use, reproduce, distribute, prepare derivative works of, display and perform the content in connection with the Application and the Service Provider's business. This license does not grant the Service Provider the right to sell or sublicense your content to third parties independently of the Application. You represent and warrant that you own or control all rights in the content you post and that use of the content does not violate these Terms or applicable law.

        Your content may include personal data. Processing of personal data related to User-Generated Content is governed by the Privacy Policy. Do not post personal data of others without their consent.

        The Service Provider is dedicated to ensuring that the Application is as beneficial and efficient as possible. As such, they reserve the right to modify the Application, its service fee, or their services at any time and for any reason. The Service Provider assures you that any changes to fees will be clearly communicated to you before they take effect on new bookings.

        The Application stores and processes personal data that you have provided to the Service Provider in order to provide the Service. It is your responsibility to maintain the security of your mobile device and access to the Application.

        The Service Provider strongly advises against jailbreaking or rooting your mobile device, which involves removing software restrictions and limitations imposed by the official operating system of your mobile device. Such actions could expose your mobile device to malware, viruses, malicious programs, compromise your mobile device's security features, and may result in the Application not functioning correctly or at all.

        Please be aware that the Service Provider does not assume responsibility for certain aspects. Some functions of the Application require an active internet connection, which can be Wi-Fi or provided by your mobile network provider. The Service Provider cannot be held responsible if the Application does not function at full capacity due to lack of access to Wi-Fi or if you have exhausted your data allowance.

        If you are using the application outside of a Wi-Fi area, please be aware that your mobile network provider's agreement terms still apply. Consequently, you may incur charges from your mobile provider for data usage during the connection to the application, or other third-party charges. By using the application, you accept responsibility for any such charges, including roaming data charges if you use the application outside of your home territory (i.e., region or country) without disabling data roaming. If you are not the bill payer for the device on which you are using the application, they assume that you have obtained permission from the bill payer.

        Similarly, the Service Provider cannot always assume responsibility for your usage of the application. For instance, it is your responsibility to ensure that your device remains charged. If your device runs out of battery and you are unable to access the Service, the Service Provider cannot be held responsible.

        Nothing in these Terms shall limit any rights you have under applicable consumer protection laws that cannot be lawfully excluded.

        Limitation of Liability

        To the fullest extent permitted by law, the Service Provider shall not be liable for any indirect, incidental, special, consequential, or punitive damages, including but not limited to lost profits, data loss, or business interruption, even if advised of the possibility of such damages.

        The Service Provider is not a party to, and is not liable for, the actual conduct of any trip booked through the Application, including any injury, loss, or damage arising from a Guide's actions or a trip's inherent risks -- these are governed by the Liability Waiver referenced above and, where applicable, are the responsibility of the Guide providing the trip.

        However, the Service Provider retains full liability for:

        - Death or personal injury caused by the Service Provider's own negligence (as distinct from a Guide's conduct during a trip)
        - Fraud or fraudulent misrepresentation
        - Any other liability that cannot be excluded or limited under applicable law

        To the fullest extent permitted by law, the total liability of the Service Provider for any claim arising from use of the Application itself (as opposed to a trip's conduct) shall not exceed the service fees paid by you to the Service Provider in the 12 months preceding the claim, or the minimum amount that must be paid under applicable law, whichever is greater.

        The Service Provider accepts no liability for any loss, direct or indirect, that you experience as a result of relying entirely on third-party information provided through this Application, or for inaccuracies in content provided by third parties, including Guide-provided listing information.

        Indemnification

        To the fullest extent permitted by law, you agree to indemnify and hold harmless the Service Provider, its affiliates, officers, directors, employees and agents from and against any claims, liabilities, damages, losses and expenses, including reasonable legal fees, arising out of or directly related to your breach of these Terms or your intentional misuse of the Application, including User-Generated Content you submit in violation of these Terms. If you are a Guide, this includes claims arising from your conduct of a trip or your failure to hold required licenses, permits, or insurance.

        This indemnification does not apply to claims arising from the Service Provider's own negligence, breach of these Terms, or violation of applicable law. In jurisdictions where consumer indemnification is restricted by law, this clause shall be limited to the maximum extent permitted.

        The Service Provider may wish to update the application at some point. The application is currently available as per the requirements for the operating system (and for any additional systems they decide to extend the availability of the application to) may change, and you will need to download the updates if you want to continue using the application. The Service Provider does not guarantee that it will always update the application so that it is relevant to you and/or compatible with the particular operating system version installed on your device. You should accept updates when offered; if you choose not to, the Service Provider may cease to support earlier versions and the Application may not function properly. The Service Provider may also wish to cease providing the application and may terminate its use at any time without providing termination notice to you. Unless they inform you otherwise, upon any termination, (a) the rights and licenses granted to you in these terms will end; (b) you must cease using the application, and (if necessary) delete it from your device.

        Governing Law and Jurisdiction

        These Terms and Conditions are governed by the laws of the Commonwealth of Pennsylvania, United States, excluding conflict of law rules, except to the extent mandatory consumer protection laws provide otherwise.

        Any dispute arising out of or relating to these Terms will be brought before the courts that have jurisdiction under applicable law. Nothing in this clause limits any rights you may have to bring a claim in a court that is competent under mandatory law.

        Severability

        If any provision of these Terms and Conditions is held to be invalid, illegal, or unenforceable by a court of competent jurisdiction, such provision shall be modified to the minimum extent necessary to make it valid and enforceable, and the remaining provisions of these Terms shall remain in full force and effect.

        Entire Agreement

        These Terms and Conditions, together with the Privacy Policy and the Liability Waiver, constitute the entire agreement between you and the Service Provider concerning your use of the Application, superseding any prior agreements or understandings.

        Changes to These Terms and Conditions

        The Service Provider may periodically update their Terms and Conditions. Therefore, you are advised to review this page regularly for any changes. The Service Provider will notify you of any changes by posting the new Terms and Conditions on this page.

        Previous versions of these Terms and Conditions will be maintained and made available upon request by contacting the Service Provider at longrobert346@yahoo.com.

        These terms and conditions are effective as of 2026-08-11

        Contact Us

        If you have any questions or suggestions about the Terms and Conditions, please do not hesitate to contact the Service Provider at longrobert346@yahoo.com.

        This is a draft, not a substitute for real, lawyer-reviewed Terms of Service. Do not rely on this text for actual legal protection until it has been reviewed.
        """
    )

    static let privacyPolicy = LegalTextView(
        title: "Privacy Policy",
        text: """
        [DRAFT -- not yet reviewed by a lawyer. Do not rely on this text for actual legal or regulatory compliance.]

        Privacy Policy

        This privacy policy applies to the TruGuidz app for mobile devices, together with any related services operated by Robert Long (collectively, the "Application"). Robert Long is hereby referred to as the "Service Provider".

        Information Collection and Use

        The Application collects information when you download and use it. This information may include:

        - Your device's Internet Protocol address
        - Your mobile operating system
        - Standard server/hosting logs collected automatically by our infrastructure providers

        The Application does not currently use dedicated analytics tools to track which screens you visit or how long you spend on them.

        Cookies and tracking technologies

        TruGuidz does not currently use any third-party analytics or advertising SDKs, cookies, pixels, or similar tracking technologies. If this changes in the future, the Service Provider will update this policy and, where required by applicable law, obtain consent before using non-essential tracking technologies.

        Your Rights

        You may request access to, correction of, or deletion of your personal data held by the Service Provider. To exercise these rights, or to withdraw consent where processing is based on consent, contact the Service Provider at longrobert346@yahoo.com.

        Your California privacy rights (CCPA/CPRA)

        If you are a California resident, you have the right to know what personal information is collected, the right to delete personal information, the right to opt out of the sale or sharing of personal information, and the right to non-discrimination for exercising these rights. To exercise your CCPA/CPRA rights, contact the Service Provider at longrobert346@yahoo.com.

        The Service Provider may use the information you provide to send important information, required notices, and, where permitted by law, marketing communications.

        For a better experience while using the Application, the Service Provider may require you to provide certain personally identifiable information, including but not limited to: full name, email address, phone number, profile photo, government-issued photo ID (guide applicants), date of birth or age if visible on that ID, bio/years of experience (guide applicants), messages sent through the app to other users, payment card details (collected and stored by Stripe, not by TruGuidz directly), Stripe Connect account ID (guides), IP address and device data (collected automatically by our hosting infrastructure), and the address of the trip location associated with a booking (this is information entered by guides about where a trip takes place, not a record of your device's location). The information the Service Provider requests will be retained and used as described in this privacy policy.

        Information visible to other users

        Some information is visible to other users of the Application, not only to the Service Provider and its service providers. This includes: your name and profile photo, your bio and years of experience (guides), listing photos and descriptions (guides), and reviews you write or receive. Payment details, ID documents, phone number, and private messages are never shown to other users.

        Third Party Access

        The Service Provider works with trusted third-party service providers to operate the Application, including:

        - Stripe, which processes payments and guide payouts and receives the personal and payment information necessary to do so (name, email, and payment details).
        - Supabase, which hosts the Application's database, authentication, and file storage, and by necessity processes the personal data described in this policy.

        These providers do not have an independent use of the information the Service Provider discloses to them and have agreed to adhere to the rules set forth in this privacy statement. Aside from these service providers, the Service Provider does not sell or share your personal information with other third parties, except as described below.

        International Data Transfers

        The Service Provider or its third-party service providers may transfer personal data to countries outside your country of residence, including outside the European Economic Area (EEA). Where applicable law requires safeguards for international transfers, the Service Provider will use appropriate mechanisms:

        - Standard Contractual Clauses (SCCs) approved by the European Commission
        - Adequacy decisions or other legally recognized transfer mechanisms
        - Your consent, where required and legally permitted

        Data protection laws in other countries may differ from those in your jurisdiction. Where required by law, the Service Provider will apply appropriate safeguards and obtain any consent required for the transfer.

        The Service Provider may disclose User Provided and Automatically Collected Information:

        - as required by law, such as to comply with a subpoena, or similar legal process;
        - when they believe in good faith that disclosure is necessary to protect their rights, protect your safety or the safety of others, investigate fraud, or respond to a government request;
        - with their trusted service providers who work on their behalf, do not have an independent use of the information the Service Provider discloses to them, and have agreed to adhere to the rules set forth in this privacy statement.

        Opt-Out Rights

        You can stop further collection of information from your mobile device by uninstalling the Application. Uninstalling will stop the Application from collecting data from your device, but it does not automatically delete information that has already been transmitted to the Service Provider or to third parties.

        To request deletion of your personal data, to withdraw consent, or to exercise any of your rights, contact the Service Provider at longrobert346@yahoo.com.

        Data Retention Policy

        The Service Provider retains personal data based on its necessity for the stated purposes:

        - User Provided Data: Retained for the duration of your use of the Application plus 12 months thereafter, unless longer retention is required by law
        - Automatically Collected Data: Retained for up to 24 months from collection, unless longer retention is required for legal compliance
        - Aggregated and Anonymized Data: Retained indefinitely as it no longer identifies you
        - Data required for legal compliance: Retained as long as required by applicable law

        You may request deletion of your personal data, subject to any legal obligation to retain it. If you want the Service Provider to delete User Provided Data submitted through the Application, please contact them at longrobert346@yahoo.com. Please note that some User Provided Data may be required for the Application to function properly.

        Children

        The Application is not intended for children under 13 years of age, or such higher age as required by applicable law. The Service Provider does not knowingly solicit data from children or market the Application to them.

        The Service Provider does not knowingly collect personally identifiable information from children. The Service Provider encourages all children to never submit any personally identifiable information through the Application and/or Services. The Service Provider encourages parents and legal guardians to monitor their children's Internet usage and to help enforce this Policy by instructing their children never to provide personally identifiable information through the Application and/or Services without their permission. If you have reason to believe that a child has provided personally identifiable information to the Service Provider through the Application and/or Services, please contact the Service Provider so that they will be able to take the necessary actions. If you are under 13 years of age, your parent or guardian must provide consent on your behalf where permitted by law.

        Security

        The Service Provider is concerned about safeguarding the confidentiality of your information. The Service Provider provides physical, electronic, and procedural safeguards to protect information the Service Provider processes and maintains.

        Data Breach Notification

        If a data breach occurs that affects your personal data, the Service Provider will notify you in accordance with applicable legal requirements, including, where required, providing information about the nature of the breach and the steps being taken to address it.

        Changes

        The Service Provider may update this Privacy Policy from time to time. The Service Provider will notify you of material changes by posting the updated Privacy Policy with an effective date. Where required by law, the Service Provider will seek your consent to material changes before they take effect.

        Previous versions of this Privacy Policy will be maintained and made available upon request by contacting the Service Provider at longrobert346@yahoo.com.

        This privacy policy is effective as of 2026-08-11

        Your Consent

        Where processing is based on consent, you provide that consent by affirmatively opting in to the relevant feature or action. You may withdraw consent at any time without affecting processing carried out before withdrawal. Processing based on other lawful bases is carried out as described above.

        Contact Us

        If you have any questions regarding privacy while using the Application, or have questions about the practices, please contact the Service Provider via email at longrobert346@yahoo.com.

        This is a draft, not a substitute for a real, lawyer-reviewed Privacy Policy. Do not rely on this text for actual legal or regulatory compliance (including GDPR/CCPA obligations) until it has been reviewed.
        """
    )
}

#Preview {
    NavigationStack {
        LegalTextView.termsOfService
    }
}
