# HIBEYA Akal Budi â€” Design System Foundation

## Purpose

The design system separates visual decisions from feature implementation.

Learner and parent experiences share a brand language but use different interaction contracts.

## Learner design principles

- very low reading density;
- large touch targets;
- calm visual hierarchy;
- low sensory load;
- minimal motion;
- no time pressure;
- no streak pressure;
- no infinite-scroll pattern;
- no forced autoplay;
- no behavioural advertising;
- mistakes receive gentle, non-punitive feedback.

## Parent design principles

- higher information density than learner UI;
- clear progress interpretation;
- explicit destructive-action confirmation;
- accessible focus states;
- no vanity metrics that encourage unhealthy child engagement.

## Semantic tokens

Application code should migrate toward semantic tokens instead of raw colours.

Example:

```text
surface-card
text-primary
feedback-success-surface
feedback-gentle-text
focus-ring
```

Do not build product identity around arbitrary Tailwind colour names.

## Illustration boundary

Core learner artwork must eventually be sourced through the HIBEYA asset/provenance pipeline.

Stock imagery, emoji and generated placeholders are not the final commercial visual system.

Phase 006A does not replace current assets yet.

## Motion

Motion supports comprehension only.

Acceptable examples:

- gentle selection transition;
- short state change;
- low-intensity progress acknowledgement.

Not acceptable:

- flashing;
- celebratory loops;
- forced confetti;
- engagement-driven autoplay;
- reward escalation.

## Future phases

006B:
Shared React primitives and Storybook.

006C:
Application token adoption and accessibility regression.

007:
Original illustration system and provenance pipeline.
