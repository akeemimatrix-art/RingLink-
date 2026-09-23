# RingLink Android release guide

This repository is source-complete for the Flutter application and Supabase database foundation. The Android platform folder is generated from the Flutter SDK so it stays aligned with the installed Flutter version.

## 1. Local prerequisites

- Flutter stable SDK
- Android Studio and an Android SDK that includes API 36
- A Supabase project
- A GitHub repository
- A Google Play Console developer account

Flutter's current stable documentation lists Flutter 3.47.x as the current stable line. Google Play requires new Android apps and updates to target Android 16 / API 36 or higher as of 31 August 2026.

## 2. Generate the Android folder

From the repository root:

```bash
bash scripts/bootstrap_android.sh
```

The script runs `flutter create --platforms=android` and patches the generated Android project for the current Play target requirement.

## 3. Configure Supabase

Create a Supabase project and open the SQL Editor. Paste and run:

```text
supabase/migrations/202609230001_initial_schema.sql
supabase/seed.sql
```

The app uses only the Supabase project URL and publishable client key. Never put a Supabase service-role/secret key in the mobile app.

## 4. Configure the app

Copy:

```text
config/dev.example.json -> config/dev.json
```

Fill in the project URL and publishable key.

Run:

```bash
flutter run --dart-define-from-file=config/dev.json
```

For CI/release automation, supply the same values through build-time secrets/defines rather than committing them.

## 5. Create the first administrator

Sign up normally in the app. In the Supabase SQL Editor, promote the account to admin by UUID:

```sql
update public.profiles
set account_role = 'admin'
where id = 'YOUR_USER_UUID';
```

Only do this manually in a trusted admin environment. The database trigger blocks ordinary users from self-promoting to admin.

## 6. Verify the first provider

1. Create a provider account.
2. Complete the provider profile and location.
3. Submit verification documents.
4. In the admin dashboard, approve the verification request.
5. Activate the individual subscription for the provider.
6. Confirm the provider appears in directory search.

## 7. Build a release

Create and protect an upload keystore. Do not commit the keystore or passwords. Configure signing in the Android Gradle project and then build an Android App Bundle:

```bash
flutter build appbundle --release --dart-define-from-file=config/dev.json
```

Upload the generated `.aab` to Google Play Console.

## 8. Before publishing

Complete all Google Play Console declarations, including app content, data safety, content rating, privacy policy, target API, store listing, screenshots and testing requirements. Because RingLink uses location, profiles, phone numbers and verification documents, the privacy/data-safety declarations must describe the actual production behavior.
