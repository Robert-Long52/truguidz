import StripePaymentSheet

// Stripe's publishable key is the client-side counterpart to the secret
// key that only lives as an Edge Function secret -- same public/private
// split as Supabase's anon key vs service_role key. Safe to embed here;
// it can only create PaymentIntents your backend already authorized, not
// move money on its own.
enum StripeConfig {
    static func configure() {
        StripeAPI.defaultPublishableKey = "pk_live_51U0uEj1ttq1bGPtREvwibQXb0etTtFemWeMGg4eEKxyXXYh12TQ5U468TcUEsE8MF9cDYYpxNDu3OdkBMGXsDzTJ00f732VYq8"
    }
}
