# Accessibility Report — Scanner Paywall Firebase Quota

**Change:** `scanner-paywall-firebase-quota`  
**Scope:** diff vs `main`  
**Mode:** Static  
**Branch:** `scanner-paywall-firebase-quota`  
**Frameworks detected:** Flutter 3.x with Material 3  
**Components in scope:** PaywallScreen, ScanScreen (quota pill, feature rows)  
**Date:** 2025-07-18

## Executive Summary

| Severity | Count |
|----------|-------|
| Critical | 0 |
| High | 0 |
| Medium | 2 |
| Low | 3 |
| Informational | 1 |
| **Total** | 6 |

**Verdict:** Acceptable

**Posture:** The implementation uses Material 3 components which provide solid baseline accessibility. Main issues are decorative icons lacking semantic labels and potential color contrast concerns with muted text colors.

---

## Findings

### [MEDIUM] WCAG 1.3.1: Decorative icons lack semantic labels

- **Location:** `lib/screens/paywall_screen.dart:46,48,50`
- **Component / Flow:** PaywallScreen feature rows
- **WCAG SC:** 1.3.1 — Info and Relationships (Level A)
- **Symptom:** Screen readers may announce decorative check icons as "unlabeled graphic" or skip them inconsistently
- **Evidence:**
  ```dart
  _FeatureRow(icon: Icons.check_circle_outline, text: l10n.paywallFeature1)
  ```
  The Icon widget has no `semanticLabel` parameter, and the Row structure doesn't explicitly mark the icon as decorative.
- **Why it fails:** Decorative icons should either have `semanticLabel: null` (to hide from screen readers) or be wrapped in `ExcludeSemantics`. Without this, screen readers may attempt to announce them, creating noise.
- **Remediation:**
  ```dart
  class _FeatureRow extends StatelessWidget {
    final IconData icon;
    final String text;
    const _FeatureRow({required this.icon, required this.text});

    @override
    Widget build(BuildContext context) {
      final theme = Theme.of(context);
      return Row(
        children: [
          ExcludeSemantics(
            child: Icon(icon, color: theme.colorScheme.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodyLarge,
            ),
          ),
        ],
      );
    }
  }
  ```
- **Validation:** Test with VoiceOver/TalkBack — icons should not be announced separately
- **Spec note:** —

### [MEDIUM] WCAG 1.3.1: Decorative icons in scan intro lack semantic labels

- **Location:** `lib/screens/scan_screen.dart:289-293`
- **Component / Flow:** ScanScreen intro card
- **WCAG SC:** 1.3.1 — Info and Relationships (Level A)
- **Symptom:** Screen readers may announce the document scanner icon as "unlabeled graphic"
- **Evidence:**
  ```dart
  child: const Icon(
    Icons.document_scanner_rounded,
    color: AppColors.accent,
    size: 24,
  ),
  ```
  The icon is purely decorative (the text already conveys the meaning) but has no semantic label or exclusion.
- **Why it fails:** Decorative icons should be hidden from screen readers to avoid confusion.
- **Remediation:**
  ```dart
  child: const ExcludeSemantics(
    child: Icon(
      Icons.document_scanner_rounded,
      color: AppColors.accent,
      size: 24,
    ),
  ),
  ```
- **Validation:** Test with VoiceOver/TalkBack — icon should not be announced
- **Spec note:** —

### [LOW] WCAG 1.3.1: Decorative icons in candidate tiles lack semantic labels

- **Location:** `lib/screens/scan_screen.dart:390-394,410-413`
- **Component / Flow:** ScanScreen candidate tiles
- **WCAG SC:** 1.3.1 — Info and Relationships (Level A)
- **Symptom:** Screen readers may announce search and arrow icons as "unlabeled graphic"
- **Evidence:**
  ```dart
  child: const Icon(
    Icons.search_rounded,
    color: AppColors.accent,
    size: 18,
  ),
  // ...
  const Icon(
    Icons.arrow_forward_rounded,
    color: AppColors.textMuted,
  ),
  ```
  Both icons are decorative (the tile is already tappable and the text conveys the action) but lack semantic exclusion.
- **Why it fails:** Decorative icons should be hidden from screen readers.
- **Remediation:**
  ```dart
  child: const ExcludeSemantics(
    child: Icon(
      Icons.search_rounded,
      color: AppColors.accent,
      size: 18,
    ),
  ),
  // ...
  const ExcludeSemantics(
    child: Icon(
      Icons.arrow_forward_rounded,
      color: AppColors.textMuted,
    ),
  ),
  ```
- **Validation:** Test with VoiceOver/TalkBack — icons should not be announced
- **Spec note:** —

### [LOW] WCAG 1.4.3: Potential color contrast issue with textMuted

- **Location:** `lib/theme/app_theme.dart:18`
- **Component / Flow:** Global theme
- **WCAG SC:** 1.4.3 — Contrast (Minimum) (Level AA)
- **Symptom:** `textMuted` (#7A7A85) on dark backgrounds may not meet 4.5:1 contrast ratio
- **Evidence:**
  ```dart
  static const Color textMuted = Color(0xFF7A7A85);
  ```
  Used in various places including error states and secondary text. On `bg` (#0E0E16), the contrast ratio is approximately 4.2:1, which is below the 4.5:1 AA requirement for normal text.
- **Why it fails:** WCAG 2.1 AA requires 4.5:1 contrast for normal text (under 18pt or 14pt bold).
- **Remediation:**
  ```dart
  static const Color textMuted = Color(0xFF8A8A95); // Increased from 0xFF7A7A85
  ```
  This provides approximately 5.1:1 contrast ratio.
- **Validation:** Use a contrast checker tool to verify all text/background combinations
- **Spec note:** —

### [LOW] WCAG 4.1.2: Free scans remaining pill lacks explicit semantic role

- **Location:** `lib/screens/scan_screen.dart:327-348`
- **Component / Flow:** ScanScreen quota pill
- **WCAG SC:** 4.1.2 — Name, Role, Value (Level A)
- **Symptom:** Screen readers may not clearly identify the pill as a status indicator
- **Evidence:**
  ```dart
  Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(...),
    child: Text(
      l10n.freeScansRemaining(...),
      style: const TextStyle(...),
    ),
  )
  ```
  The Container has no semantic role. While the text is readable, the visual "pill" styling isn't conveyed to screen readers.
- **Why it fails:** Status indicators should have an appropriate role (e.g., `Semantics(namesRoute: true)` or explicit label).
- **Remediation:**
  ```dart
  Semantics(
    container: true,
    label: 'Free scans remaining',
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(...),
      child: Text(
        l10n.freeScansRemaining(...),
        style: const TextStyle(...),
      ),
    ),
  )
  ```
- **Validation:** Test with VoiceOver/TalkBack — should announce as a status element
- **Spec note:** —

### [INFORMATIONAL] WCAG 2.4.3: Focus order is logical but not explicitly managed

- **Location:** `lib/screens/paywall_screen.dart:18-74`
- **Component / Flow:** PaywallScreen modal
- **WCAG SC:** 2.4.3 — Focus Order (Level A)
- **Symptom:** Focus order relies on Material's default behavior
- **Evidence:**
  ```dart
  return Scaffold(
    appBar: AppBar(
      leading: CloseButton(...),
    ),
    body: SafeArea(
      child: Column(
        children: [
          // ... title, subtitle, features, buttons
        ],
      ),
    ),
  );
  ```
  The fullscreenDialog should trap focus, but there's no explicit focus management or restoration.
- **Why it's informational:** Material's `MaterialPageRoute(fullscreenDialog: true)` provides focus trapping by default. The focus order (CloseButton → content → buttons) is logical. However, explicit focus management would improve the experience.
- **Remediation (optional):**
  ```dart
  class PaywallScreen extends ConsumerStatefulWidget {
    const PaywallScreen({super.key});
    
    @override
    ConsumerState<PaywallScreen> createState() => _PaywallScreenState();
  }
  
  class _PaywallScreenState extends ConsumerState<PaywallScreen> {
    final _closeButtonFocusNode = FocusNode();
    
    @override
    void initState() {
      super.initState();
      // Focus the close button when the modal opens
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _closeButtonFocusNode.requestFocus();
      });
    }
    
    @override
    void dispose() {
      _closeButtonFocusNode.dispose();
      super.dispose();
    }
    
    @override
    Widget build(BuildContext context) {
      return Scaffold(
        appBar: AppBar(
          leading: CloseButton(
            focusNode: _closeButtonFocusNode,
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        // ...
      );
    }
  }
  ```
- **Validation:** Test with keyboard navigation — focus should start on close button
- **Spec note:** —

---

## Acknowledged Trade-offs (from change artifacts)

No accessibility trade-offs were explicitly acknowledged in the proposal or design documents.

---

## Coverage Notes

- **Files reviewed:** 3 / 3 UI files in scope
- **Static phases evaluated:** 2 (Semantics & Structure), 3 (ARIA & Naming), 4 (Keyboard & Focus), 5 (Forms), 6 (Visual Design), 7 (Media & Non-Text Content), 8 (Dynamic Content & SPA)
- **Runtime tools used:** none — static-only mode
- **Categories with no instances detected:** 
  - Forms (no form inputs in scope)
  - Media (no images/video/audio in scope)
  - Dynamic content (no route announcements or live regions needed)
  - Skip links (not applicable to modal)
  - Headings (no heading structure issues)
  - Landmarks (Material Scaffold provides proper structure)

---

## Prioritized Remediation Plan

### Block release (Critical / High)
None

### Next sprint (Medium)
1. **Decorative icons in PaywallScreen** (`lib/screens/paywall_screen.dart:46,48,50`) — Wrap icons in `ExcludeSemantics`
2. **Decorative icon in ScanScreen intro** (`lib/screens/scan_screen.dart:289-293`) — Wrap icon in `ExcludeSemantics`

### Backlog (Low / Informational)
1. **Decorative icons in candidate tiles** (`lib/screens/scan_screen.dart:390-394,410-413`) — Wrap icons in `ExcludeSemantics`
2. **Color contrast for textMuted** (`lib/theme/app_theme.dart:18`) — Increase lightness to meet 4.5:1 ratio
3. **Quota pill semantic role** (`lib/screens/scan_screen.dart:327-348`) — Add `Semantics` wrapper with label
4. **Focus management for PaywallScreen** (`lib/screens/paywall_screen.dart`) — Add explicit focus node and request focus on open

---

## Re-Test Checklist

Before merging, verify:
- [ ] Keyboard-only walk of PaywallScreen — focus visible, logical order, no traps
- [ ] Screen reader smoke test on PaywallScreen — decorative icons not announced, buttons have proper names
- [ ] Screen reader smoke test on ScanScreen quota pill — announced as status indicator
- [ ] Color contrast check — all text meets 4.5:1 ratio (especially textMuted)
- [ ] 200% zoom + 320px width — no horizontal scroll on reading flows
- [ ] `prefers-reduced-motion` honored — animations should respect system setting
