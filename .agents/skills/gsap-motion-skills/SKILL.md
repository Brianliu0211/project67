---
name: gsap-motion-skills
description: Official animation principles for GreenSock and Flutter motion. Enforces correct easing curves, micro-interaction timelines, spotlight hole cutouts, and smooth UI transitions.
---

# GSAP Motion Skills - Micro-Animation Timelines

## Trigger Conditions
Triggers whenever coding animations, state transitions, hover effects, card flips, or guided walkthrough spotlight cutouts.

## Core Motion Directives

1. **Easing Curve Discipline**:
   - Never use linear curves for UI elements. Use `Curves.easeOutCubic` or `Curves.easeInOutCubic`.
2. **Animation Duration Standard**:
   - Micro-interactions (press, scale): 150ms - 180ms.
   - Screen & Tab switching: 200ms - 300ms.
   - Spotlight Hole Cutout transitions: 300ms cubic bezier.
3. **Smooth Timeline Chaining**:
   - Action triggers must animate smoothly without layout snapping or frame drops.
