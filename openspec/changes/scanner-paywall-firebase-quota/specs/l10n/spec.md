## ADDED Requirements

### Requirement: Paywall strings are added in en, es, fr
The system SHALL add the following keys to `lib/l10n/app_en.arb`, `lib/l10n/app_es.arb`, and `lib/l10n/app_fr.arb`:

- `paywallTitle` (String) — the screen's headline.
- `paywallSubtitle` (String) — one-sentence explanation under the title.
- `paywallFeature1`, `paywallFeature2`, `paywallFeature3` (String) — feature bullets.
- `paywallCta` (String) — primary Subscribe button label.
- `paywallRestore` (String) — Restore purchases affordance label.
- `freeScansRemaining` (String, with `int` placeholders `left` and `total`) — pill copy in `_ScanIntro`.
- `paywallComingSoon` (String) — SnackBar text on Subscribe tap.

#### Scenario: English ARB contains all eight keys
- **WHEN** `flutter gen-l10n` runs against the updated `app_en.arb`
- **THEN** all eight keys are present in the generated `AppLocalizations` for `en`

#### Scenario: Spanish ARB contains all eight keys
- **WHEN** `flutter gen-l10n` runs against the updated `app_es.arb`
- **THEN** all eight keys are present in the generated `AppLocalizations` for `es`

#### Scenario: French ARB contains all eight keys
- **WHEN** `flutter gen-l10n` runs against the updated `app_fr.arb`
- **THEN** all eight keys are present in the generated `AppLocalizations` for `fr`

### Requirement: freeScansRemaining takes two int placeholders
The `freeScansRemaining` key SHALL be defined with two integer placeholders, `left` and `total`, mirroring the existing `candidatesFound` / `sharedDetailCount` placeholder style (`{left}` and `{total}` in the string, with the corresponding `placeholders` block in the ARB).

#### Scenario: Pill renders with placeholders supplied
- **WHEN** the UI calls `context.l10n.freeScansRemaining(left: 3, total: 5)`
- **THEN** the generated string is the `en` value with both placeholders substituted

#### Scenario: Placeholders missing
- **WHEN** the placeholder block is missing from the ARB
- **THEN** `flutter gen-l10n` fails at build time, blocking the release

### Requirement: No other existing keys are removed or renamed
The system MUST NOT remove, rename, or change the meaning of any pre-existing key in the three ARB files. Only additive changes are allowed in this change. Existing `paywall*`, `freeScansRemaining`, or `paywallComingSoon` keys MUST NOT exist prior to this change; if any conflict is found, the change is blocked until resolved.

#### Scenario: Pre-change ARB scan
- **WHEN** the change is reviewed against a fresh checkout
- **THEN** none of the eight new keys exist in any of the three ARB files before this change
