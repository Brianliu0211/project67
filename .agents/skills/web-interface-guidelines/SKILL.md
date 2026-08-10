---
name: web-interface-guidelines
description: Living list of interface guidelines framework-agnostic and specific to web/mobile. Enforces full keyboard navigation, WAI-ARIA accessibility, clear focus rings, and explicit semantic structure.
---

# Web Interface Guidelines - Accessibility & Focus Standards

## Trigger Conditions
Triggers whenever coding forms, interactive buttons, modal dialogs, or keyboard navigation handlers.

## Directives
1. **Keyboard Accessibility**:
   - All interactive items must be focusable via `Tab` key.
   - Text form fields must support `onSubmitted` / `Enter` key execution.
2. **Visible Focus Rings**:
   - Focusable widgets must render visible focus indicators when navigated via keyboard.
3. **Semantic Tooltips**:
   - Icon-only buttons must provide explicit `tooltip` parameters.
