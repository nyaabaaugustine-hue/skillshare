/// Detects the explicit guest-launch deep link on web.
///
/// A web install can be opened with `?guest=1` to reach the course path
/// without an account. Only the exact value `1` opts in: a missing parameter,
/// `true` or `0` all keep the normal sign-in flow.
///
/// Nothing calls this yet — the guest entry point is not wired into the
/// bootstrap, so the behaviour stays as it was. The predicate is kept because
/// it is the contract the web deep-link work will build on.
bool guestLaunchRequested(Uri uri) => uri.queryParameters['guest'] == '1';
