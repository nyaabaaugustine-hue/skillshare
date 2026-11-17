# Feature: Neon Auth for Flutter and tutor AI

## Requirements

- While a learner has no account session, the Flutter app shall keep its offline
  tutor and guest mode.
- When a learner registers or signs in, Flutter shall authenticate against the
  existing Managed Neon Auth service used by the website.
- When email verification is required, registration shall collect and verify
  the emailed code before opening the signed-in app.
- The app shall persist the Neon Auth session securely and obtain a fresh,
  short-lived JWT when calling the tutor Worker.
- The Worker shall verify JWT signature, issuer, and audience using Neon Auth
  JWKS, and shall serve AI only to a signed-in student organization owner.
- Guardian organization members and accounts without an active student
  organization shall be denied remote tutor access.
- The app shall not contain a Neon database connection string or server secret.
- Browser calls shall be limited to the approved SkillBridge origin.

## Architecture

### Frontend

- Keep Flutter's existing account controller and offline guest behavior.
- Replace Supabase-specific auth with a Neon Managed Auth HTTP client.
- Handle Neon email verification, restored sessions, sign-out, and organization
  selection.
- Treat family organization owners as students and members as guardians; the
  server remains authoritative for AI authorization.
- Build Android and Flutter web with the public Neon Auth URL and tutor Worker
  URL only.

### Backend

- Keep the website's existing Managed Neon Auth service and family
  organizations.
- Set the active family organization after accepting a guardian invitation so
  JWTs carry the correct organization role.
- Replace Supabase `/auth/v1/user` validation in the Cloudflare Worker with
  EdDSA JWT verification against the branch JWKS, including issuer/audience
  validation.
- Enforce `o.role === "owner"` before rate limiting or invoking Workers AI.
- Keep Neon `DATABASE_URL` server-side; the tutor Worker does not need SQL
  access for this authorization design.

### Security

- Never put Neon `DATABASE_URL`, the website cookie secret, or provider
  credentials in Flutter or committed config.
- Verify JWTs cryptographically; do not trust user role data supplied in the
  request body or unsigned token claims.
- Require the active organization role to be `owner` for remote tutoring;
  deny members, missing roles, expired tokens, and invalid signatures.
- Validate browser origins against the exact allowlist while allowing native
  requests without an `Origin` header.
- Continue rate-limiting by verified Neon user ID and avoid logging prompts or
  bearer tokens.

## Implementation plan

1. Implement and test Flutter's Neon Auth session, email verification, and
   active-organization flow; remove obsolete Supabase auth wiring.
2. Ensure website invitation acceptance activates the guardian's organization.
3. Implement and test Worker's Neon JWT verification and student-role gate.
4. Configure the production Neon trusted origin and Worker secrets/config,
   deploy, verify health/auth behavior, and build the Android and web apps.

## Verification

- Flutter unit/widget tests cover email verification, session restore, sign-out,
  and role mapping.
- Worker tests cover valid student JWTs, guardian/member JWTs, wrong issuer,
  expired/invalid signatures, and rate limiting.
- Production smoke checks cover `/health`, unauthenticated denial, and a
  signed-in student tutor request.
- A real account sign-up/OTP flow must be exercised before declaring the auth
  migration fully verified.
