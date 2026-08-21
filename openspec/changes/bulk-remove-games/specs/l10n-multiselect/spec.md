## Purpose

Provides localized strings for the multiselect and bulk-remove flow in every locale the app already supports (en, es, fr, pt).

## ADDED Requirements

### Requirement: All multiselect strings are localized in en, es, fr, and pt
The app SHALL ship translations for the multiselect and bulk-remove user-facing strings in every locale the app already supports. Each locale SHALL define a translation for the app-bar entry tooltip, the selection-count title, the bulk-remove dialog title, the bulk-remove dialog message, and the removal snackbar.

#### Scenario: Every locale has a translation for the entry tooltip
- **WHEN** the app is running in en, es, fr, or pt
- **THEN** the app-bar selection entry tooltip is rendered in that locale

#### Scenario: Every locale has a translation for the selection-count title
- **WHEN** the Shelf is in selection mode and N games are selected, with the app running in en, es, fr, or pt
- **THEN** the app-bar title "{N} selected" is rendered in that locale

#### Scenario: Every locale has translations for dialog title, message, and snackbar
- **WHEN** the bulk-remove flow runs in en, es, fr, or pt
- **THEN** the dialog title, dialog message, and snackbar text are each rendered in that locale

### Requirement: Pluralized strings follow the project's existing intl plural rules
The selection-count title, dialog title, and snackbar text SHALL use the project's existing plural-aware `intl` style for any locale whose grammar requires plural forms, so the count reads naturally in languages that distinguish plural from singular.

#### Scenario: Singular and plural render correctly in locales with plural rules
- **WHEN** the bulk-remove flow runs in a locale with plural rules and the count crosses from 1 to 2 (or vice versa)
- **THEN** the rendered text uses the matching plural form
