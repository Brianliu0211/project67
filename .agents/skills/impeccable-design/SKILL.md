---
name: impeccable-design
description: 59 Deterministic detector rules for AI-generated frontend design. Prevents dialog jittering, unconstrained popups, hardcoded colors, broken padding, and layout jump.
---

# Impeccable Design - 59 Deterministic Anti-Slop Detector Rules

## Trigger Conditions
Triggers during every code generation, code edit, and automated code audit phase to catch and eliminate low-quality AI design anti-patterns.

## Core Detector Rules

### Rule Group 1: Dialogs & Modals (Rules 1-15)
- **Rule 1.1**: Dialogs MUST specify explicit `BoxConstraints` (`minWidth`, `maxWidth`, `maxHeight`).
- **Rule 1.2**: Dialog scrollable content MUST use `ClampingScrollPhysics` to eliminate layout jitter during IME text input.
- **Rule 1.3**: Dialog headers MUST include a clear close button (`Icons.close_rounded`) top-right.

### Rule Group 2: Color Token & Theme Hygiene (Rules 16-30)
- **Rule 2.1**: Never hardcode hex colors inline in widgets (`Color(0xFF123456)`). Always consume `Theme.of(context)` or `AppSettings.instance.primaryColor`.
- **Rule 2.2**: Text colors on custom badge background MUST dynamically compute luminance (`computeLuminance() > 0.5`) to choose high-contrast text.

### Rule Group 3: Dynamic Data & Empty States (Rules 31-45)
- **Rule 31.1**: Optional string fields (phone, lineId, email, address, website) MUST be wrapped in conditional render checks (`if (field.isNotEmpty)`). Never display empty labels or empty rows.
- **Rule 31.2**: Long string titles MUST declare `maxLines` and `TextOverflow.ellipsis`.

### Rule Group 4: Interactive Affordance & Tooltips (Rules 46-59)
- **Rule 46.1**: All icon-only buttons MUST include a descriptive `tooltip` attribute.
- **Rule 46.2**: Buttons inside card previews MUST NOT crowd or obscure printed design content. Action buttons belong outside card stages.
