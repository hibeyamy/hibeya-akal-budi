# HIBEYA Akal Budi â€” Original Asset & Provenance Standard

## Purpose

Every learner-facing production asset must have an auditable origin and explicit commercial-use status.

Phase 007A establishes the governance layer before large-scale illustration production starts.

## Core rule

A file being visually attractive does not make it commercially ready.

A production asset must be:

- original or commissioned for HIBEYA;
- commercially usable;
- traceable to a creator/source process;
- reviewed for originality;
- reviewed for child suitability;
- culturally reviewed when relevant;
- represented by a provenance manifest.

## Source types

Commercially approved:

- `original-internal`
- `original-ai-assisted`
- `commissioned-original`

Prototype only:

- `unicode-emoji`
- `legacy-placeholder`

Prototype assets may remain during development but block the later commercial asset release gate.

## Directory model

```text
assets/
â”œâ”€â”€ manifests/       machine-readable provenance
â”œâ”€â”€ source/          editable source material / working files
â”œâ”€â”€ masters/         approved master artwork
â”œâ”€â”€ exports/         runtime-ready SVG/PNG/WebP
â””â”€â”€ review/          review notes and approval evidence
```

## Commercial gate

Normal provenance validation:

```powershell
pnpm assets:validate
```

Strict commercial-release check:

```powershell
pnpm assets:commercial:validate
```

The commercial gate is expected to remain blocked until the current prototype learner assets are replaced.

## AI-assisted artwork

AI-assisted artwork is permitted only when:

- the final composition is created specifically for HIBEYA;
- no request is made to imitate a living artist or protected character;
- prompts and source context do not intentionally reproduce third-party IP;
- the asset receives an originality review;
- commercial rights are confirmed for the production workflow;
- culturally sensitive Malaysian elements receive human review.

## Copyright boundary

Do not copy:

- worksheets;
- educational app artwork;
- children's characters;
- book illustrations;
- branded mascots;
- icon packs without a verified licence.

Reference material may inform general factual or cultural accuracy, but the final visual expression must be independently created.

## Current status after Phase 007A

Existing emoji/legacy learner assets are catalogued as prototypes.

They are deliberately **not** marked commercial-ready.

The next phases create the original HIBEYA illustration language and replacement asset production workflow.
