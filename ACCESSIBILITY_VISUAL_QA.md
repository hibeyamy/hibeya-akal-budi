# HIBEYA Akal Budi â€” Accessibility & Visual Regression

## Purpose

Phase 006D turns visual quality and accessibility into automated release gates.

## Accessibility

Automated tests use axe-core against representative Storybook stories.

Blocking impacts:

- serious
- critical

The automated standard is WCAG 2.1 AA.

Automation does not replace manual accessibility review.

## Learner interaction

Learner controls use a preferred minimum touch target of 56px.

Reduced-motion behaviour is tested with the browser preference set to `reduce`.

## Visual regression

Reference screenshots are generated in Chromium with a deterministic test profile:

- 1280 Ã— 900 viewport
- device scale factor 1
- light colour scheme
- Malay locale
- Asia/Kuala_Lumpur timezone
- reduced motion enabled

## Baselines

Initial baselines are generated deliberately with:

```powershell
pnpm qa:visual:update
```

After baselines exist, normal validation uses:

```powershell
pnpm qa:visual
```

A baseline update must be reviewed as a visual change, not treated as an automatic fix.

## Local browser installation

Playwright Chromium is installed using:

```powershell
pnpm qa:browsers:install
```

## Commercial release principle

A release should not pass solely because TypeScript compiles.

The intended quality stack is:

```text
schema validation
â†’ typecheck
â†’ unit/integration tests
â†’ RLS security
â†’ accessibility
â†’ visual regression
â†’ production build
```
