# Shared accounts: one login on the phone and in the browser

> **Migration notice (2026-11-18):** This page documents the previous Supabase
> implementation and is not current setup guidance. The website and Flutter
> app now use Neon Auth. Accounts created in the former Supabase or device-local
> account stores have not been imported into Neon Auth; those accounts cannot
> sign in until they are migrated or recreated there. Production registration
> and login still need end-to-end verification with a test account.

The Android app and the Flutter web build sign in against the **same Supabase
project**, so an account created on a phone works on a computer and the other
way round. Facebook is supported on both through the same OAuth flow.

Debug development and tests can use offline mock authentication when the two
build-time values below are missing. Release builds and `SB_ENV=production`
fail closed instead of creating device-only accounts. Guest mode remains
available and device-local.

## What the code does

| Piece | Where |
| --- | --- |
| Supabase SDK client, email/password, Facebook, restore-on-launch | `lib/features/auth/cloud_auth.dart` |
| Routes sign-in/signup to the shared backend when configured | `lib/features/auth/auth_controller.dart` (`initCloudAuth`, `_post`) |
| "Continue with Facebook" button | `lib/features/auth/login_register_screen.dart` |
| Android return deep link (`skillsbridge://login-callback`) | `android/app/src/main/AndroidManifest.xml` |
| Build-time settings | `SB_SUPABASE_URL`, `SB_SUPABASE_ANON_KEY` (`lib/core/config/app_config.dart`) |

- **Email/password** works in the app and on the web; the role (`student` or
  `guardian`) is stored in account metadata, so the web build opens the same
  home screen as the app.
- **Website registration** creates a student account and stores the entered
  Parent / Guardian email on that account. After the student confirms their
  email (when confirmation is enabled), the site creates a separate guardian
  account and Resend emails a one-time setup link. The guardian chooses their
  own password. The confirmation screen displays the guardian login email and
  offers a copy button; reusable passwords are never emailed or shown.
- **Facebook** opens the provider in the browser: on the web the page returns
  to itself, on Android it returns through the deep link above. The session is
  then adopted by `AuthController`, which rebuilds the app.
- **Sessions persist across reloads** in this mode, unlike the offline mock,
  which intentionally starts at the login screen every launch.
- **Guest** still works and stays device-local.
- The built-in demo logins have been removed. Shared sign-in accepts email
  accounts only; locally-generated guardian credentials are not accepted as
  shared accounts.

## Family links

Website student registration requires a Parent / Guardian email. After the
student account is confirmed (if email confirmation is enabled), the site
creates a separate Supabase guardian account and uses Resend to send the login
email and one-time password-setup link. The guardian chooses their password;
reusable passwords are never emailed. The student account keeps the guardian
email in Supabase metadata so the Flutter app can send progress reports through
the configured Resend mailer.

Offline family links (`FamilyLinkStore`) remain device-local. The Neon
`family_links` table is still only a scaffold, so guardian progress dashboards
and family links are not yet synchronized across devices.

## Setup

1. Create a free project at <https://supabase.com/dashboard>. Note the
   **Project URL** and the **anon public key** (Project Settings → API).
2. Authentication → Providers → **Email**: enable. Keep *Confirm email* on
   for production so new Parent / Guardian accounts receive a verification
   link. For local testing it can be turned off; signup then completes without
   an activation email.
3. Create a Facebook app at <https://developers.facebook.com/apps> (type
   *Consumer*), add the **Facebook Login** product, and copy the App ID and App
   secret.
4. In Facebook Login → Settings, add this **Valid OAuth Redirect URI** exactly:
   `https://<project-ref>.supabase.co/auth/v1/callback`
5. Authentication → Providers → **Facebook**: enable, paste App ID and secret.
6. Authentication → URL Configuration:
   - **Site URL**: the address the web build is served from (for local testing
     `http://localhost:8080`).
   - **Additional Redirect URLs**: every origin and deep link that may come
     back, one per line:
     ```
     http://localhost:8080
     http://localhost:3001/learn
     http://localhost:3001/login*
     http://localhost:3001/guardian/accept
     https://<your-website-domain>/learn
     https://<your-website-domain>/login*
     https://<your-website-domain>/guardian/accept
     https://<your-flutter-web-domain>
     skillsbridge://login-callback
     ```
   The `skillsbridge://` entry is required for Android. Add both the Flutter
   web origin and the Next.js website `/learn` redirect.

For the Next.js website, merge the relevant entries from
`website/.env.example` into `website/.env.local`, preserving any existing
values such as `NEXT_PUBLIC_LEARN_URL`. If `.env.local` does not exist, copy
the example to create it. Add the Supabase service-role key and Resend API key
only to the Next.js server environment, and configure `MAIL_FROM` to a verified
Resend sender. Never use the Supabase service-role key in browser code or
Flutter builds.

The Supabase redirect allowlist must also accept the student confirmation
return (`/login?confirm=student`) and Parent / Guardian setup route
(`/guardian/accept`) on the Next.js website.

## Building with shared accounts

Android:

```bash
flutter build appbundle --release \
  --dart-define=SB_ENV=production \
  --dart-define=SB_SUPABASE_URL=https://<project-ref>.supabase.co \
  --dart-define=SB_SUPABASE_ANON_KEY=<anon-key> \
  --dart-define=SB_LMS_BASE_URL=<lms-url-or-empty>
```

Web:

```bash
flutter build web --release \
  --dart-define=SB_ENV=production \
  --dart-define=SB_SUPABASE_URL=https://<project-ref>.supabase.co \
  --dart-define=SB_SUPABASE_ANON_KEY=<anon-key>
```

The anon key is a publishable key and is safe in a client build; row-level
security and provider secrets stay on the server. Never put the **service
role** key or the Facebook app secret in the app.

## Neon Postgres scaffold

The website includes a server-only Neon query helper and an initial profile and
family-link schema at `website/db/migrations/0001_identity.sql`. Add the Neon
pooled connection string as `DATABASE_URL` in `website/.env.local`; use the
direct (unpooled) string as `DATABASE_URL_UNPOOLED` for migrations. Never expose
either value with a `NEXT_PUBLIC_` prefix or in the Flutter app.

This is schema scaffolding only: profiles and family links are not yet written
or read by the app. Supabase remains the identity provider and password store.
Apply the migration only after entering the Neon connection details and
implementing authenticated, ownership-checked server endpoints.
