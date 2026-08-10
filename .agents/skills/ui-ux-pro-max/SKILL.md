---
name: ui-ux-pro-max
description: Design Intelligence for building professional UI/UX across multiple platforms and frameworks. Enforces responsive grid systems, card padding standards, full-screen desktop utilization, and mobile-friendly adaptation.
---

# UI/UX Pro Max - Design Intelligence System

## Trigger Conditions
Triggers whenever creating layout structures, grids, responsive forms, cards, dashboards, or navigation menus.

## Layout & Grid Standards

### 1. Responsive Multi-Column Breakpoints
- **Desktop (>= 1024px)**: Split-screen desktop layout (e.g. 40% Stage / 60% Form or 3-4 card grid per row). No wasted margin padding.
- **Tablet (768px - 1023px)**: 2-column balanced grid with adaptive sidebars.
- **Mobile (< 768px)**: Single column stacked layout with bottom navigation or collapsible sidebar drawer.

### 2. Spacing & Rhythm System
- **Card Insets**: 20px - 24px internal padding.
- **Section Gaps**: 16px - 28px vertical spacing.
- **Target Sizes**: Interactive buttons and touch targets must meet a minimum size of 44x44px.

### 3. Progressive Disclosure Form Pattern
- Group long complex forms into **Segmented Control Tabs** (0: Basic, 1: Business, 2: Badges, 3: Security).
- Use `IndexedStack` or persistent state views to achieve 0ms lag tab switching without state destruction.
- Provide real-time instant preview feedback on the adjacent card stage.
