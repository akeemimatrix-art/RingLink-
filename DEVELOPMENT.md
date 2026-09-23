# RingLink development workflow

## Recommended setup

Use a Flutter 3.47.2 (stable) for the checked-in CI configuration. The repository is written against Dart 3.10+.

## First run

```bash
cp config/dev.example.json config/dev.json
# edit config/dev.json with your Supabase URL and publishable key
bash scripts/bootstrap_android.sh
flutter pub get
flutter run --dart-define-from-file=config/dev.json
```

## Database setup

Run these in Supabase SQL Editor, in this order:

```text
supabase/migrations/202609230001_initial_schema.sql
supabase/seed.sql
```

## Checks

```bash
bash scripts/check.sh
flutter analyze
flutter test
```

A GitHub Action also runs analysis and tests on pushes and pull requests. It generates the Android platform folder in CI, patches it to target API 36, and performs a debug APK build with placeholder Supabase build-time values.

## What the repository currently implements

- Customer/provider/business authentication flows.
- Provider and business directory profiles.
- Supabase PostgreSQL data model with RLS.
- Profile and verification document uploads.
- Location-aware provider/business search.
- Categories and service listings.
- Calls history and direct phone dialer handoff.
- In-app text chat with Supabase Realtime.
- Database-enforced Ring first-acceptance locking.
- Customer Ring status and provider incoming Ring queue.
- Reviews and provider rating aggregation.
- Subscription request/admin activation foundation.
- Admin dashboard for verification and subscription activation.

## Deliberately not included yet

The following require production integrations or an additional product decision and are not faked in the repository:

- Live Mobile Money/card payment gateway.
- SMS OTP vendor beyond the Supabase Auth provider configuration.
- True carrier/VoIP simultaneous incoming Ring calls and wake-up behavior.
- Push notification delivery infrastructure.
- Automated identity/KYC provider integration.
- Team invitations and full multi-member business administration.
- Production analytics/crash reporting.

Build these only after the corresponding provider and legal requirements are selected.
