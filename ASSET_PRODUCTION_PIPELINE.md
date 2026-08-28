# Phase 007C â€” Production Asset Pipeline

Phase 007C converts prototype-replacement requirements into deterministic production briefs.

## Commands

Generate/reconcile the queue:

```powershell
pnpm assets:queue
```

Validate all briefs and queue references:

```powershell
pnpm assets:pipeline:validate
```

After a human reviewer has completed the provenance checks for an asset:

```powershell
pnpm assets:approve <asset-id>
```

## Important boundary

The system does **not** automatically mark AI-generated artwork as original, safe or commercially approved.

Those judgements remain explicit review gates.

## Next production loop

For each queued asset:

1. review/edit the generated brief;
2. create original artwork;
3. save the editable master under `assets/masters`;
4. export runtime variants under `assets/exports`;
5. update the Phase 007A provenance manifest;
6. complete human review;
7. run `pnpm assets:approve <asset-id>`;
8. integrate into `@akal-budi/assets`;
9. run accessibility and visual-regression gates.

This pipeline can later be batch-driven without weakening the commercial approval controls.
