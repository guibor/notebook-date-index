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
Open an ordinary notebook, open toolbar **⋮ (Notebook settings)**, then **Dates**.
Check the panel, close it, write normally, and confirm BetterTOC/native PDF
outline still works. Do not interpret a healthy PID as these checks passing.

To refresh a preview that has not yet passed physical acceptance, use
`./ops/deploy.sh <verified-IP> refresh-preview <previous-preview-recovery-path>`.
This preserves preview mode, all index data and existing timezone settings.
It verifies the previous installed backend/panel/QMD and backs them up before
replacing them. Rollback covers the configuration's previous presence/absence.

For a writer-only repair with byte-identical QMD and panel, use
`./ops/deploy.sh <verified-IP> backend-preview <previous-preview-recovery-path>`.
This checks both UI artifacts against the live files, replaces only the writer,
probes JSON using Qt's UTF-8 Content-Type, and requires xochitl's PID to remain
unchanged. It does not restart the UI. Its independent rollback restores the
old backend and restarts only that service if needed.

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
displayed day matches the desired timezone before real use. The user selected
Israel time on 2026-09-18. The default is now `Asia/Jerusalem`, computed with
embedded IANA timezone data, not the tablet's UTC system timezone. The Dates
panel includes a timezone selector. The atomic, device-local `settings.json`
also accepts other valid IANA zone names. A change affects future dates only;
all older recorded day/offset/zone values remain unchanged.

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
- At that stage, physical preview acceptance, timezone choice, functional
  promotion and disposable-notebook acceptance remained pending.

## Preview refresh: configurable Israel time and visible menu

The user could not find More tools. Exact firmware source showed it is gated by
`toolbarProvider.hasEditingToolsGrouping && !hasEnoughVerticalSpace`, with
enough vertical space defined as container height >=1000. This was a placement
error in our preview, not evidence that XOVI or the app had disappeared.
Dates now also appears at the top of the notebook's three-dot settings menu.

User selected `Asia/Jerusalem`, with a configurable preference. The backend now
embeds IANA timezone data, defaults to Israel, and records each page's original
zone and UTC offset. The Dates dropdown offers Israel, UTC, London and New York;
other IANA zones can be set in its private `settings.json`. Settings changes
affect only future dates and do not alter the system clock.

Transaction `ndi-20260918T083432Z-refresh-preview` passed at PID `294628`,
`NRestarts=0`, nine QMDs and AppLoad active, root read-only. Both rollback timers
were inactive afterward. The eight prior QMDs, four runtime libraries, Vellum
files and both Gestik files were unchanged. Backend health reported
`{"enabled":false,"groups":[],"timezone":"Asia/Jerusalem"}`.

Backup SHA-256: `a361c32dd073b119342cccd4c9ca7225ef06ac46452fecd747e695bb2d9117a7`.
Backend SHA-256: `248598501dbd8022fc40e04ee264e439d45c00dcc5e7aac14b062b9c0b6b2f2e`.
Preview QMD: `035b0bcae5e9d0ade470d650f5a568afb18a39ced5d9b8cd53594ba538fd6936`.
Full manifest and off-device backup are in
`.cache/ndi-20260918T083432Z-refresh-preview/`.

All 11 Go tests including the race detector, six JS event tests, the popup
runtime test, both exact-resource compositions and wrong-version rejection
passed. The sandboxed Qt launcher failed CPU detection; the same local harness
passed outside the sandbox. No device write was needed for that test.
Physical acceptance of the relocated menu/panel and functional promotion are
still pending. Tracking remains disabled; timezone preferences can be changed.

## Qt transport repair: 2026-09-18

The user's screenshot confirmed that Dates opened, but showed the load/save
error and a disabled timezone selector. The background service was healthy.
Plain `application/json` returned HTTP 200, whereas Qt's valid
`application/json;charset=UTF-8` returned 403. The new `transport-test.mjs`
reproduced this with the actual QML queue against the actual Go service.
The old popup test had mocked this boundary and therefore missed the bug.

The handler now parses the media type instead of comparing the whole header
string. JSON with UTF-8 is accepted; token/Origin/method checks and body
validation remain intact. Non-JSON, malformed types and UTF-16 are rejected.
The genuine Qt-to-Go test now passes (HTTP 200). All 12 Go tests, six JS tests,
the popup harness and both exact-firmware composition/version gates pass.

Writer-only transaction `ndi-20260918T091158Z-backend-preview` passed in 12s.
The UI stayed at PID `294628` with zero restarts. QMD, panel, timezone settings,
all co-resident packages and Gestik bytes were preserved; root remained ro.
The Qt-style device probe returned the empty index with `Asia/Jerusalem`.
New backend SHA-256:
`3f4df0ae95d4d3a83301a968a43a5f7f078e0a258452ec6529f71262543d3cef`.
Backup SHA-256:
`9fcbf971b97c10ad790e33c9d962822cb027023aed4f6f071fdeb2384ad10a36`.
Full manifest/preimages are in the matching Mac `.cache/` transaction folder.
Use this transaction as the previous preview for subsequent promotion/repair.
The user must close/reopen Dates to retry the failed request. Tracking remains
disabled pending healthy panel/pen acceptance and functional promotion.

## Functional activation: 2026-09-18

The user confirmed "no loading error, all good" and requested activation.
`ndi-20260918T092752Z-functional` passed the existing guarded promotion:
UI PID `296229`, writer PID `296107`, zero restarts, root read-only, unchanged
eight co-resident QMDs, Vellum files, four libraries and both Gestik preimages.
The writer no longer has `--preview`. Tracking remains off until enabled per
notebook, and the timezone remains `Asia/Jerusalem`.

- Backend: `3f4df0ae95d4d3a83301a968a43a5f7f078e0a258452ec6529f71262543d3cef`
- Functional QMD: `5a6650458253748fb0dd0c0e3e30d4daeff02ca6190b04da2f64b454a043213b`
- Functional panel: `e4cf4998c1194ca5515b452dca07af230340ffbfb144253da86af7c0fbc476e5`
- Backup: `4e0d30af5f547992dab61ff7aa1ba710658fc16f04a4df855bf93dd8b9f10c73`

Matching local `.cache/` directory retains the manifest, backup and runtime log.
Existing one-time stock/co-resident `Values is not defined` warnings in Toolbar
and Experimental also appeared in the accepted preview; no new Dates error was
observed. Physical add-page/index/navigation acceptance is still outstanding.
The sibling RMStream shortcut adds a tenth QMD; consult its update recipe for
the later complete runtime inventory rather than rerunning this initial installer.
