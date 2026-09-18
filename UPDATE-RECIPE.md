# Paper Pro notebook Dates update recipe

Exact branch: `beta/pro/3.28.0.169`, model `reMarkable Ferrari`.
This branch is not a Move build. Read the sibling
`remarkable-beta-os/KNOWLEDGE-BASE.md` and its current dated log first.

## Build and preserve

1. Match the candidate's Ed25519 host key **before authentication**:
   `SHA256:dByHweKZkjDlZRBHdBisT5VD2kV85lClgtJExnDaTeE`.
2. Verify firmware/build and stock hash against `ops/install-device.sh`.
   Verify XOVI, QRR, AppLoad, broker, framebuffer-spy and hashtable pins.
3. Save current device-local Dates data, live Gestik settings and protected
   Gestik backup separately. Never overlay the Move's data or settings.
4. Export the eight actual Pro QMDs to `build/co-resident/`; their manifest
   must match `profiles/co-resident.sha256` before compilation.
5. Run `./test.sh`. It must finish with `offline gates PASSED`; retain its log.
   Both preview and functional QMDs are version-restricted and separately
   composed against every existing patch. The Mac harness uses Qt's Basic
   controls style/offscreen software rendering; it is not physical acceptance.
6. Keep `build/notebook-date-index`, the two compiled QMDs and source QMDs plus
   exact SHA-256s in the release evidence. Never reuse on an adjacent firmware.

## First installation: preview

`./ops/deploy.sh <verified-IP> preview`

The Mac helper uses strict key-only SSH, checks the host fingerprint, stages
the manifest-bound payload, runs read-only preflight, then pulls and hash-checks
the complete QMD/Gestik recovery archive before activation. The device
controller runs under a transient systemd unit. A separate 180-second rollback
timer is armed before payload activation; the existing ReMagic wrapper adds
its own shorter stock-recovery guard before the single UI restart.

Installed paths:

- `/home/root/.local/lib/notebook-date-index/notebook-date-index`
- `/home/root/.local/lib/notebook-date-index/DatesPanel.qml`
- `/home/root/xovi/exthome/qt-resource-rebuilder/notebook-date-index.qmd`
- `/home/root/.local/share/notebook-date-index/` (private local data and token)
- transient `notebook-date-index.service`; no boot registration.

Preview disables the enable button and creation recorder in QML. The service
also runs with `--preview` and independently rejects all tracking changes.
Open an ordinary notebook, open toolbar **More tools (+)**, then **Dates**.
Check the panel, close it, write normally, and confirm BetterTOC/native PDF
outline still works. Do not interpret a healthy PID as these checks passing.

## Functional promotion

Only after the exact preview has been physically accepted:

`./ops/deploy.sh <verified-IP> functional /home/root/.codex-backups/ndi-PREVIEW-TRANSACTION-preview`

The final argument is the actual accepted preview recovery path, not the
literal example. The controller requires its committed-preview marker and
exact candidate QMD hash, and preserves the same backend and all local data.
It promotes only the separately tested QMD and removes `--preview` from the
transient writer service. Tracking remains off in all notebooks until the
user enables one.

Use a disposable notebook first: enable Dates, add three pages, verify one
group; expand and navigate; duplicate; reorder; delete/undo; close/reopen;
pause/add/resume. Test Page Overview, handwriting conversion and Quick Sheets.
The backend and event unit tests cover midnight/timezone logic, but verify the
displayed day matches the desired timezone before real use. The tablet was
observed using UTC on 2026-09-18; an explicit user timezone preference remains
to be selected before functional promotion if UTC is not desired.

## Recovery and reboot

On failed activation, let both watchdogs settle. The outer guard removes only
the new QMD (or restores the prior preview QMD) and returns the UI to stock if
activation was attempted. Confirm `rolled-back`, `NRestarts=0`, read-only root,
and no candidate QMD before stopping a leftover timer. Keep failed logs.
An uncommitted service/binary/data directory is retained for diagnosis rather
than deleted. If it contains only the preview token/lock and no index, it may
be moved into that transaction's recovery folder before retrying. Do not use
this cleanup on real notebook index data.

A tablet reboot clears the transient writer and XOVI activation. Payload and
index remain. Revalidate all exact pins and the installed ninth QMD before
restarting the writer with the accepted mode and invoking the guarded ReMagic
wrapper. Do not run an old helper that assumes exactly eight QMDs unmodified.
After an OS update, re-extract resources/rebuild/test on a new qualified branch
and preserve the whole data directory; the initial-install script deliberately
refuses to overwrite an existing data directory.

## Execution log: 2026-09-18

- Go persistence/security tests (including race detector), JS creation-hook
  tests, both exact-firmware compositions, 25 generated QML files per variant,
  wrong-version rejection and preserved BetterTOC initialization passed.
- `ndi-20260918T001212Z-preview`: service health check found `curl` was not in
  systemd's PATH. No candidate QMD was installed. The outer guard returned to
  stock; recovery and all existing settings were verified. Installer now uses
  `/home/root/.vellum/bin/curl` and checks it before preparing changes.
- `ndi-20260918T001309Z-preview`: runtime rejected the unqualified `Popup` name,
  which resolved to a different reMarkable type without `contentItem`. Guarded
  stock recovery completed, zero automatic restarts, root still read-only.
  Candidate removed, no index files created. The code now aliases all standard
  Qt controls explicitly and includes a passing local popup runtime harness.
- A subsequent preflight counted three pre-existing AppleDouble `._*.so`
  metadata files as extensions and stopped without changing the device. The
  enabled-extension inventory now uses the same four visible `.so` files as
  the hash manifest; the metadata was left untouched.
- `ndi-20260918T001713Z-preview`: guarded preview **passed** at PID `293100`,
  `NRestarts=0`, nine QMDs, AppLoad loaded, root read-only. Eight prior QMDs,
  Vellum files, four runtime libraries and both independent Gestik preimages
  matched exactly afterward. Loopback service is active in write-forbidden
  preview mode; no notebook index JSON exists. Both rollback timers stopped.
  Mac recovery/evidence: `.cache/ndi-20260918T001713Z-preview/`.
  Backup SHA-256: `fa0fd95458a65f8fac0b3b481f91abd422472932b41ace58b0e934aa87412837`.
  Deployed backend SHA-256: `df7e5e91f790a1dbeb79361b4f564e1b23bb766424f4ce9c93c8bfef6ec99624`.
  Deployed preview QMD: `81b8f7e3568d9c41dd7c17bfb0e0dbc280a72777eb777034d34ad39a880b0bf5`.
  Deployed preview panel: `78e61f02331968bcc3a2c105d3a483d2503fd85dfd4b2c9c8d37463c80b3d9b5`.
- The post-deployment source adds tested accumulation of split duplicate-page
  success signals for functional promotion. It has **not** replaced the above
  preview artifacts; use their recorded hashes for current-device checks.
- Physical preview acceptance, date timezone choice, functional promotion and
  disposable-notebook acceptance remain pending. Recording is not enabled.
