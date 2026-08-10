---
name: taste-skill
description: The Anti-Slop Frontend Framework for AI Agents. Use when creating UI/UX components to avoid generic, uninspired, low-quality AI design templates and enforce distinctive typography, color palettes, and polished visual hierarchy.
---

# Taste Skill - Anti-Slop Frontend Framework for AI Agents

## Trigger Conditions
This skill automatically triggers whenever the AI Agent writes, refactors, or reviews frontend UI components (Flutter widgets, CSS, HTML, React/Next.js pages).

## Core Principles

### 1. Zero Generic AI Slop (Anti-Slop Mandate)
- **NO Default Browser Grays**: Never use `#888888`, `#CCCCCC`, or plain `Colors.grey`. Use curated slate/dark HSL swatches (`#0F172A`, `#1E293B`, `#334155`).
- **NO Raw Unconstrained Rectangles**: All containers must feature modern border radii (16px - 24px) or pill shapes.
- **NO Hardcoded Black Borders**: Border opacity must remain between `0.10` and `0.18` (e.g., `Colors.white.withValues(alpha: 0.12)`).

### 2. Distinctive Typography Hierarchy
- **Primary Headers**: Bold / Black font weight (`FontWeight.w900`), letter-spacing 0.5px.
- **Subtitles & Badges**: Medium / SemiBold font weight (`FontWeight.w600`), readable contrast.
- **Body Text**: Line-height minimum 1.5x for effortless reading.

### 3. Glassmorphism & Elevation Layering
- **Backdrop Blur**: Use glass opacity backdrop filters.
- **Multi-layered Shadows**: Combine ambient blur (20px - 30px) with directional shadow offsets (`Offset(0, 8)`).
- **Color Depth**: Dark mode surfaces use deep obsidian, carbon, and navy slate rather than flat black `#000000`.

### 4. Interactive Micro-Interactions
- Interactive elements must incorporate scale-up (1.02x - 1.05x) or scale-down (0.97x) feedback on press.
- Hover states must display smooth background color shifts within 150ms - 200ms.
