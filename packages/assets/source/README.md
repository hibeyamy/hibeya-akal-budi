# Authoritative artwork sources

This directory is the future source-of-truth boundary for approved HIBEYA
learning artwork.

Policy:

- Rich learning illustrations use lossless PNG masters when appropriate.
- Runtime delivery should normally use optimised WebP derivatives.
- SVG remains suitable for simple UI/iconography, not as the default rich
  illustration format.
- Activities never reference physical filenames or formats. They reference
  stable semantic asset IDs resolved through `getAsset()`.
- Files are migrated here only through a governed migration phase. Existing
  generated assets are intentionally not moved by Phase 008R3A.2.