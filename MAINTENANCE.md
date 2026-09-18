# Dates ownership and device releases

Canonical repository: https://github.com/guibor/notebook-date-index (private).
This is our original application, not a patch carried inside another app's repo.
The firmware-marker repository links here but does not own this application's
source, tests, release history or local metadata.

## Shared features, separately qualified builds

Maintain one Dates feature set for Paper Pro and Paper Pro Move. Carry shared
backend/UI fixes to both targets, but never equate shared source with device
compatibility. `compatibility.json` records the current feature revision and
each device's actual qualification state; a pending target is not a release.

- Firmware branches: `beta/pro/<exact-firmware>` and
  `beta/move/<exact-firmware>`. Keep old qualified branches for recovery.
- App versions describe feature changes independently of firmware versions.
  Once accepted, release tags can be `v<app-version>-pro-fw<firmware>` or
  `v<app-version>-move-fw<firmware>`; do not tag untested artifacts as accepted.
- For a shared change, record its source commit and port it to every supported
  device branch. Keep device-specific dimensions, hooks, host identity, hashes,
  co-resident QMD inventory and deployment guard local to that target.
- Each firmware upgrade gets its own resource extraction, composition/tests,
  device backup, guarded deployment and physical acceptance. Pro success
  cannot qualify Move. Update the matrix and recipe with evidence afterward.
- Keep current Pro development on `beta/pro/3.28.0.169`. Create a Move target
  branch only after establishing its live exact firmware; do not invent a
  version or copy the Pro installer with only the model name changed.

## What sync means

Feature/release parity is the maintenance goal, not automatic deployment.
The Move implementation is currently pending qualification. It must receive
the same date grouping, per-notebook opt-in, pause/resume and timezone options.

Notebook content, date-index records, per-notebook opt-ins, timezone choice,
and Gestik settings remain device-local. Do not copy one device's settings or
private index onto the other. A future request to synchronize date metadata
would require a separate design for notebook/page identities and conflicts.

## Publication boundary

Commit source, tests, requirements, recipes and non-secret hash manifests.
Never publish `.cache/`, `build/`, notebook files, index JSON, access tokens,
credentials or device backup archives. The full on-device test still needs
the private exact-firmware resource cache and qualified co-resident artifacts;
publishing the source does not make these caches part of the repository.

## Immediate work

1. Complete physical Pro creation/navigation acceptance.
2. Read-only qualify Move's current model/firmware/runtime and independent settings.
3. Port and test the same feature revision on its exact Move branch, then use
   the preview/functional acceptance process before routine use.
