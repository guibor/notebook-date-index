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

Both feature/release parity and shared Dates history are maintenance goals,
not automatic deployment.
The Move implementation is currently pending qualification. It must receive
the same date grouping, per-notebook opt-in, pause/resume and timezone options.

The user clarified that date-index records for the same notebook must sync
between Pro and Move. This supersedes the earlier local-only data policy, but
is not enabled in the current deployed tablet build. The md-server hub is live
and the client merge code is tested; consult `SYNC-DEPLOYMENT.md` before rollout.
Merge individual page-date
records by verified notebook/page identity; never overwrite an entire index.
Native notebook content keeps its existing sync path and remains untouched by
Dates. Preserve original creation date/timezone and retain records for pages
that have not arrived yet or are temporarily missing after deletion.

Gestik and unrelated device settings remain independent. The authorized transport
is the private authenticated md-server HTTPS hub. Dates enable/pause preferences
remain per-device for this version; do not treat an app-version update as
metadata migration or automatically enable recording on the other device.

## Publication boundary

Commit source, tests, requirements, recipes and non-secret hash manifests.
Never publish `.cache/`, `build/`, notebook files, index JSON, access tokens,
credentials or device backup archives. The full on-device test still needs
the private exact-firmware resource cache and qualified co-resident artifacts;
publishing the source does not make these caches part of the repository.

## Immediate work

The transport and sampled notebook/page identities are validated. Shared history
must still receive its own on-device offline/merge/rollback acceptance.

1. Complete physical Pro creation/navigation acceptance.
2. Read-only qualify Move's current model/firmware/runtime and independent settings.
3. Port and test the same feature revision on its exact Move branch, then use
   the preview/functional acceptance process before routine use.
