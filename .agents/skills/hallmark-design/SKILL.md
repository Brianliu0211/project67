---
name: hallmark-design
description: Design skill for AI agents that refuses to look AI-generated. Enforces 20 custom visual themes, slop-test gates, and pre-emit self-critique.
---

# Hallmark Design - Anti-Template Self-Critique Rules

## Trigger Conditions
Triggers prior to emitting UI code to perform a strict self-critique against generic AI templates.

## Pre-Emit Self-Critique Gate

1. **"Does this UI look like a generic Material/Bootstrap default template?"**
   - If yes: Refactor typography, border opacity, and color palette immediately.
2. **"Are buttons taking up half of the content space inappropriately?"**
   - If yes: Move action buttons to dedicated toolbars.
3. **"Is information hierarchy clear at first glance?"**
   - Primary data must stand out (20px+ font), secondary data must use muted tones.
4. **"Does dark mode feel rich and luxurious?"**
   - Ensure surface colors use deep carbon (`#0F172A`, `#161B22`) rather than flat gray.
