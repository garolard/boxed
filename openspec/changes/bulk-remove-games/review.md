# Code Review — Bulk Remove Games

**Change:** `openspec/changes/bulk-remove-games/`
**Branch reviewed:** `bulk-remove-games`
**Parent branch:** `main`
**Commits in scope:** 7 (f7af2a1..78c41e6)
**Files changed:** 23
**Date:** 2026-08-21

## Summary

The change delivers exactly what `proposal.md` describes: Shelf-scoped multiselect, a single confirmed bulk remove with one batch-undo, bulk repository/notifier methods, one `bulk_games_removed` analytics event, and localization across all 6 supported locales. Seven parallel diff reviews (repository, notifier, home_screen, cover card, analytics, l10n, e2e test) found no correctness blockers — order of operations (snapshot-before-delete), atomicity (single DELETE / chunked-transaction fallback, single Batch insert), the no-analytics-on-undo policy, and BuildContext-across-await safety all check out against both the design decisions and the spec scenarios. The main gap is accessibility: the new selection badge and its InkWell carry no semantic labeling, so screen-reader users get no indication a card is selected or that tapping toggles it. A handful of Minor test-rigor and defensive-coding gaps round out the findings.

**Verdict:** Ready to merge — M1 has since been fixed.

**Findings count:** 0 Blockers · 1 Major (fixed) · 8 Minor · 0 Questions

---

## Domain Alignment Check

- **Goal coverage:** Met — every capability in `proposal.md`'s "What Changes" (selection state, app-bar morph, card selection visuals, `removeMany`/`addMany`, notifier bulk methods, one analytics event, confirm+undo UX, 6-locale l10n, 4 new test files) is present in the diff and matches its corresponding spec file under `specs/`.
- **Decisions respected:** Yes. Spot-checked against design.md: D1 (local `Set<int>` in `_SummaryTab`, not the notifier/a provider) ✓; D2 (`removeMany` returns the snapshot, UI passes it to `restoreMany`) ✓; D3 (single `DELETE ... WHERE id IN`, chunked-transaction fallback, `Batch` insert with `ConflictAlgorithm.replace`) ✓; D4 (one event, `_safe`-wrapped, no undo event) ✓; D5 (`FakeCollectionRepository extends CollectionRepository`, no interface extraction) ✓; D7 (all 6 ARBs, not just 4) ✓; D8 (`@`-metadata convention per file) ✓; D9 (plural form matches `gamesInShelf` precedent) ✓; D10 (`_recsStale` set on both bulk ops) ✓ (verified in `collection_provider.dart`, not independently re-checked in this pass but consistent with the pattern mirrored from `add`/`remove`).
- **Scope creep:** None. Diff is confined to the files listed in `proposal.md`'s Impact section, plus the expected generated `app_localizations*.dart` and `implementation.md`/`pubspec.lock` artifacts. Search, Recommendations, and Shared Collections tabs are untouched — confirmed via `git diff --stat`.

---

## Security Surface Triage

- **Surface touched:** No
- **Areas affected:** None. `removeMany`'s `WHERE id IN (?,?,...)` is built with parameterized `?` placeholders bound via `whereArgs`, not string interpolation — no SQL injection surface. The one new dependency (`sqflite_common_ffi`) is a `dev_dependencies`-only test seam, never shipped.
- **Recommendation:** Not required

---

## Performance Surface Triage

- **Surface touched:** Yes
- **Tiers affected:** backend (local DB)
- **Areas affected:** New bulk DB operations — `lib/services/collection_repository.dart` (`removeMany`/`addMany`). Both are correctly implemented as single operations (one `DELETE ... WHERE id IN` or one `Batch.commit`), with a chunked-transaction fallback for lists exceeding `SQLITE_MAX_VARIABLE_NUMBER`, matching the design's own risk mitigation. No blatant issue (no N+1, no per-id loop on the primary path).
- **Recommendation:** Not required — the surface is touched but the implementation already follows the design's stated mitigation; a dedicated performance pass would be low-yield here.

---

## Accessibility Surface Triage

- **Surface touched:** Yes
- **Areas affected:** interactive widgets — new selection-mode `IconButton`s, `AlertDialog`, `SnackBar` in `lib/screens/home_screen.dart`; new selection badge and whole-card tap target in `lib/widgets/game_cover_card.dart`.
- **Recommendation:** Run `/sai-8-accessibility bulk-remove-games` — one blatant gap already identified below (M1); a full WCAG pass may surface more around the app-bar mode switch and dialog/snackbar focus handling.

---

## Findings

### Major

#### M1 — Selection badge and card carry no accessible selection state — **FIXED**
- **Location:** `lib/widgets/game_cover_card.dart` (`_SelectionBadge`, the `InkWell` at the card root)
- **Category:** Accessibility
- **Problem:** The selection badge was a bare `Icon` with no `Semantics` wrapper, and the card's `InkWell` exposed no `Semantics(selected: ...)` when `selectable` was true — screen readers got no indication a card was selected or that tapping toggled it.
- **Fix applied:** The card is now wrapped in `Semantics(selected: selected, button: true, ...)` whenever `selectable` is true (non-selectable rendering is unaffected), so the toggle state merges into the existing accessibility tree without needing new label strings. The decorative `_SelectionBadge` icon is wrapped in `ExcludeSemantics` so it doesn't produce a redundant, unlabeled "check circle" announcement now that the parent conveys selection state. Verified with `flutter analyze` (clean) and the existing `game_cover_card_test.dart` / `bulk_remove_flow_test.dart` suites (all passing).
- **Spec reference:** `specs/shelf-multiselect/spec.md` — "Selected covers show a selection badge and an accent border."

### Minor

#### m1 — Chunking test doesn't verify the chunked/transactional code path
- **Location:** `test/services/collection_repository_test.dart` (chunk-at-500 test)
- **Suggestion:** The test only asserts the end-state (600 rows removed via 600 sequential `repo.add` calls), not that `removeMany` actually took the chunked `db.transaction` path rather than looping per-id outside a transaction. A regression that silently dropped the transaction wrapper would still pass. Consider asserting call count/behavior via a spy, or reducing the threshold in a test-only constructor param to make the chunking path exercised more directly.

#### m2 — `addMany` silently defaults a missing `addedAt` to now
- **Location:** `lib/services/collection_repository.dart:127`
- **Suggestion:** `entry.addedAt ?? DateTime.now()` masks a caller bug (an undo snapshot missing `addedAt`) instead of surfacing it. Low risk today since `restoreMany`'s snapshot always carries a real `addedAt`, but worth a comment noting the invariant it relies on.

#### m3 — `collectionSizeAfter` only tested for full-collection removal
- **Location:** `test/providers/collection_provider_test.dart:134-149`
- **Suggestion:** The one analytics-count test removes 2 of 2 games (`collectionSizeAfter == 0`). Add a partial-removal case (e.g. 1 of 2) to prove the value reflects the post-removal size rather than a hardcoded zero or the pre-removal count.

#### m4 — `_QuickAddButton` hiding relies on caller convention, not an internal guard
- **Location:** `lib/widgets/game_cover_card.dart:288`
- **Suggestion:** `if (onAddPressed != null)` has no `&& !selectable` check. It works correctly today only because the sole call site (`lib/screens/home_screen.dart:554-555`) passes `onAddPressed: null` whenever `_inSelectionMode` is true. Add `if (onAddPressed != null && !selectable)` so the widget defends itself if a future caller passes both `selectable: true` and a non-null `onAddPressed`.

#### m5 — Accent border keyed on `selected` alone, not `selectable && selected`
- **Location:** `lib/widgets/game_cover_card.dart:56-59`
- **Suggestion:** Same shape as m4 — works today because the only caller pairs `selected: true` with `selectable: true`, but nothing in the widget itself prevents a border render outside selection mode. Consider gating on `selectable && selected` for defense-in-depth.

#### m6 — No widget test for the `selectable: false` (default) path
- **Location:** `test/widgets/game_cover_card_test.dart`
- **Suggestion:** All new tests pump `selectable: true` (selected/unselected). Nothing regression-protects the default path — that `_OwnedPill`/`_QuickAddButton` still render and tap still navigates to `GameDetailScreen` when `selectable` is omitted. Also no test taps the card in selectable mode to confirm `onToggleSelection` actually fires.

#### m7 — E2E test doesn't assert per-field restore correctness
- **Location:** `test/widgets/bulk_remove_flow_test.dart:126,141,143`
- **Suggestion:** Undo assertions check `find.text(name)` presence and `hasLength(2)` on the restored batch, not that `ownedPlatformName`/`addedAt` match the pre-removal values through the full UI flow. This is already covered at the notifier unit level (`test/providers/collection_provider_test.dart:165` asserts `ownedPlatformName` round-trips), so it's not a correctness gap — but the flagship end-to-end test doesn't independently prove the UI wiring preserves those fields, which is exactly what `specs/bulk-remove-flow/spec.md`'s "same owned platform and same original addedAt" scenario describes at this layer.

#### m8 — Magic-number pump duration in the e2e test
- **Location:** `test/widgets/bulk_remove_flow_test.dart:86-93`
- **Suggestion:** Uses fixed `pump(700ms)`/`pump(350ms)` instead of `pumpAndSettle()` (documented via comment as a workaround for an offstage tab's infinite animation). Reasonable given the constraint, but the 350ms interaction pump has no assertion that the relevant transition actually finished — could flake on slower CI. Consider a bounded `pumpAndSettle(Duration)` scoped to avoid the infinite-animation issue, if one exists for this Flutter version.

---

## Mutation Analysis (Pass 11)

*Mutation Analysis (Pass 11): skipped — no test command could be detected. The project is a Flutter/Dart app (`pubspec.yaml`); this protocol's Tier-1 (mutation tool) and Tier-2 (test command) manifest-detection tables cover Node/JVM/Python/Go/Rust/C++ toolchains only and do not include a `pubspec.yaml` entry, so no supported detection path applies. No mutation findings.*

---

## Coverage Notes

- **Files reviewed:** 16 / 16 substantive files (14 `lib/`+`test/` files individually diff-reviewed across 7 parallel passes; `pubspec.yaml` diff read directly)
- **Files skipped:** `lib/l10n/app_localizations*.dart` (generated, spot-checked for key presence rather than line-by-line diffed), `pubspec.lock` (lockfile, dependency addition matches `pubspec.yaml`), `openspec/changes/bulk-remove-games/implementation.md` (planning artifact, not shipped code)
- **Tests inspected:** Yes — all 4 new test files read/reviewed; coverage against every scenario in `specs/tests-multiselect-bulk/spec.md` confirmed present, with the rigor gaps noted in m1, m3, m6, m7 above.

---

## Next Steps

1. ~~Fix M1 (selection accessibility)~~ — done.
2. Optionally run `/sai-8-accessibility bulk-remove-games` for a full pass on the new selection-mode UI beyond M1.
3. Optionally address m1-m8 (test rigor + defensive guards) — none block merge.
4. Performance and security audits are not recommended for this change.
