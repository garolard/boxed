# Move scan-quota enforcement into the cover-scan worker

## Problem

After moving the OpenAI call into `worker/`, the free-scan quota is still enforced
**only client-side**:

- `lib/screens/scan_screen.dart:46-109` reads `scanQuotaProvider`, gates on
  `kFreeScanLimit`, then calls `tryRecordScan()` / `decrementScan()` against Firestore.
- `worker/src/index.js` knows nothing about quota. It accepts any request carrying the
  optional `X-App-Token`.

`COVER_SCAN_ENDPOINT` and `COVER_SCAN_TOKEN` are compile-time `String.fromEnvironment`
values, so both are extractable from the shipped APK/IPA. Anyone who pulls them can call
the worker directly, unlimited, without ever touching Firestore — the paywall is bypassed
and the OpenAI bill is ours.

Not a regression: before this change the app shipped the OpenAI key itself, which was
strictly worse. But the quota is currently decorative against anyone willing to unzip the
binary.

## Fix

Enforce the quota where the spend happens — in the worker:

1. App sends the Firebase **anonymous ID token** (`FirebaseAuth.instance.currentUser
   ?.getIdToken()`) on the scan request, e.g. `Authorization: Bearer <idToken>`.
2. Worker verifies it: fetch Google's public JWKS
   (`https://www.googleapis.com/service_accounts/v1/jwk/securetoken@system.gserviceaccount.com`),
   verify RS256 via WebCrypto, check `aud` = Firebase project id, `iss`, and `exp`.
   Cache the JWKS in the Cache API / a KV binding — do not fetch it per request.
3. Worker does the transactional `users/{uid}.scansUsed` check-and-increment itself
   (Firestore REST API with a service-account JWT, or a Cloudflare KV/D1 mirror), and
   returns **402/429** when the free limit is exhausted so the app can show the paywall.
4. App's client-side check stays as a fast local gate + UI counter, but stops being the
   source of truth. `tryRecordScan()` / `decrementScan()` in `ScanQuotaService` either move
   behind the worker or are dropped for the scan path.

Keep the existing fail-closed behaviour: a quota read that errors must block the scan, not
grant it (see `ScanQuotaService` in `lib/services/scan_quota_service.dart`).

## Interim mitigations (cheap, do these regardless)

- Cloudflare rate-limit rule on the `/scan` route (per-IP, per-minute).
- Keep `APP_SHARED_SECRET` set, and rotate it on each release.
- A Workers Analytics alert on request volume, so runaway use is visible before the invoice.

## Related

- `worker/src/index.js`, `worker/README.md` ("Note on abuse")
- `lib/services/cover_scan_service.dart`
- `lib/services/scan_quota_service.dart`
- CLAUDE.md § "Premium & scan quota"
