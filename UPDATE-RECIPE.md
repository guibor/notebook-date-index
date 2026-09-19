# Paper Pro notebook Dates update recipe

> **Maintainer transaction history, not a public installer.** New readers should
> start with [the installation guide](docs/INSTALL.md). A later independent
> Dispatch document-menu addition made the maintainer's Pro inventory twelve
> QMDs. The eleven-QMD r5-to-r6 transaction below remains historical and must
> not be replayed or loosened against that newer stack. It is a payload/receipt
> reference, not authorization for current-stack reactivation.

Exact branch: `beta/pro/3.28.0.169`, model `reMarkable Ferrari`.
Move revision 6 is separately installed; see [its recipe](MOVE-UPDATE-RECIPE.md).
This branch is not a Move build. Read the sibling
`remarkable-beta-os/KNOWLEDGE-BASE.md` and its current dated log first.

## Current state: calendar polish revision 6 (2026-09-19)

Installed with `dates-polish-20260919T142350Z`: one-month arrow navigation,
actionable adjacent-month dates, selected-state layout icons, and cache-preserving
opening without our own dim/fade or post-open clear. Settings writes no longer
hide loaded dates while their follow-up query is pending or fails.

Only **DatesPanel.qml** and **DateTree.js** changed. The writer remained PID
307144; the guarded UI became PID 323008, active with zero restarts and read-only
root. All eleven QMDs, other apps, private Dates settings/token/sync config and
both independent Gestik files were preserved. The new eleventh QMD belongs to
the separate Dispatch partial-repaint work, not Dates; its exact composition
was independently rechecked in both AppLoad load orders (29 parsed resources).

| Artifact | SHA-256 |
| --- | --- |
| Panel | `5280822baf8891bfb3f091d4c598f03413cc78373b76761eebe2fc133517b23a` |
| DateTree | `336c47e7f619734214467b9f30e5324b82deeccae4977106bf8c64310f1e87dd` |
| Writer (unchanged) | `445f532f18a7bf26d429aff0a481ab02ea3b74bef9b73f956f9b5ad77a09f979` |
| Pro Dates QMD (unchanged) | `2d4681414ac00b534b2f21d179365601ce9e876c7cfbf6c6c8d25a2f8738e580` |
| Exact eleven-QMD/runtime preimage profile | `ffda5bd48b76895cbeca0073c9deb4222015b37951f148ff804ba89a848e007f` |
| Verified preimage archive | `27f64635f8c975168aa96ab5f4c0fe3389de3c3215e1096c3d19bfba918ee887` |
| Reviewed staged manifest | `7f431910237b1558748113d23d0db0f6b3ccd0db3175379e8937f53027f871b8` |

`ops/deploy-polish.sh` is the **exact r5 + Dispatch → r6 transition**, not an
idempotent reinstall. Its new explicit eleven-QMD profile does not loosen older
ten-QMD controllers. It verifies the off-device backup before arming independent
rollback and ReMagic guards. Rollback proves its exact installer cgroup is empty
before restoring files, and rechecks whether the transaction already committed.
The tablets use `/sys/fs/cgroup/unified`; absence of that qualified layout fails
preflight. Do not substitute a mainline `/sys/fs/cgroup` cgroup2 assumption.

Backup/evidence: `/home/root/.codex-backups/dates-polish-20260919T142350Z`
and local `.cache/dates-polish-20260919T142350Z`. Rollback never restores older
Dates history over new records. No firmware or native notebook files were written.

Gates passed: 30 Go/race tests, 23 Node tests, real Qt transport/creation tests,
UI rendering at Pro/Move sizes, delayed callback/cache/settings-failure tests,
26 mocked rollback cases, exact-firmware composition and wrong-version rejection.
Live read-only notebook probe still found 356 pages, 282 modified pages in 113
days, tracking on, Israel timezone and sync **Up to date**, with unchanged native
metadata. Actual e-ink flash/touch acceptance remains a physical user check.

## Previous state: navigation revision 5 (2026-09-19)

The Pro is on revision 5, transaction `dates-navigation-20260919T111620Z`.
Its header has a compact layout button, Modified-calendar day pages are numeric
page order, and its sidebar has a calendar icon immediately above BetterTOC.
Short toolbars retain a notebook-menu fallback. Move retains the menu only.

Final read-only check: a separate `dispatch-appload-latency` installation and
rollback performed later managed Pro UI restarts at 11:26–11:28 UTC. Those were
not this Dates transaction. UI PID was then 315000, active, `NRestarts=0`, with
all four XOVI extensions still mapped and root read-only. Dates QMD remained
the revision-5 hash below, writer PID 307144 and both Gestik hashes were unchanged,
and the real paired delivery probe passed again. No attempt was made here to
modify or override that separate deployment.

Guarded Pro activation passed at UI PID 310895, `NRestarts=0`. Writer PID 307144
was preserved, as were all other QMDs, native notebook bytes, RMStream, private
sync/settings/token files and each independent Gestik file. Root stayed read-only.
The live real-notebook probe still found 356 pages, 282 native modified dates,
113 modified days and the existing creation history, with sync Up to date.

| Artifact | SHA-256 |
| --- | --- |
| Writer (unchanged) | `445f532f18a7bf26d429aff0a481ab02ea3b74bef9b73f956f9b5ad77a09f979` |
| Panel | `6ced2cd45df7513b0572b76a5f955cbdbc9d51ea4810a232511d5c362332944a` |
| DateTree | `a91dbdc403f9959490d879a1d52fb5bd2b683d020db2753b55127d678a0b09ce` |
| Pro Dates QMD | `2d4681414ac00b534b2f21d179365601ce9e876c7cfbf6c6c8d25a2f8738e580` |
| Pro backup | `a53fa54d01d79af5895409ca43b1afd1b877e9b2b9b36452abbeab2e61c50be8` |

`ops/deploy-navigation.sh` is the exact revision-4-to-5 one-time controller,
not a generic updater. Do not rerun it against revision 5. Pro's new sidebar
requires the qualified BetterTOC QMD and was composed with all ten installed
QMDs, including RMStream. Physical sidebar/pen acceptance is still distinct.

## Previous state: Calendar and Pro sync (2026-09-19)

Feature revision 4 is on the same Pro branch. Dates now has independent
Created/Modified and List/Calendar switches. The Pro sync client is enabled;
Move is not yet installed or live-qualified. **Do not replay any historical
installer against this new preimage.** Each controller below is a one-time,
exact-starting-state transition, not an idempotent reinstall script.

Current Pro payload SHA-256 values:

| Payload | SHA-256 |
| --- | --- |
| `notebook-date-index` | `445f532f18a7bf26d429aff0a481ab02ea3b74bef9b73f956f9b5ad77a09f979` |
| `DatesPanel.qml` | `8339b3c6b39363a88e2994f6604693890bf210cf7a0ecb3c2c38b53417cd090b` |
| `DateTree.js` | `f37b64247f098c933f3dafe8978f0bc82ca7afda890b8b0f4c7fdcdeedd693e6` |
| `notebook-date-index.qmd` (unchanged) | `f6cba3190f3f690c2729539f0ecc3b629dd0d18366dc22fc5a89174df73731e0` |

Rebuild with Go 1.24.6, `CGO_ENABLED=0`, `GOOS=linux`, `GOARCH=arm64`,
`-buildvcs=false -trimpath -ldflags='-s -w -buildid='`. Keep firmware guards,
the current ten-QMD inventory, all runtime pins and each device's settings.
Preserve the entire private data directory, now including **sync.json** and
**sync-events/**. Do not regenerate tokens, discard journals, or replace
device-local tracking/timezone preferences with another device's files.

Completed sequence:

1. `bash test.sh` passed 30 Go/race tests, real Qt transport and creation
   callback tests, 16 JS tests, calendar navigation/compact geometry checks,
   exact-Pro composition, syntax and wrong-version rejection.
2. `ops/deploy-calendar.sh` changed only the external panel and JS helper,
   retaining the writer PID. Transaction `dates-calendar-20260919T095303Z`
   passed its independent recovery timer and ReMagic guard, leaving UI PID
   306456, writer PID 303054, zero restarts. No Dates source-located warnings.
3. `ops/deploy-hub-v3.sh` upgraded only the server binary in
   `hub-estimates-20260919T095749Z`. Real HTTPS authentication, estimated-field
   preservation, retry/read persistence and probe isolation passed. nginx,
   credentials, Anki and OpenClaw were unchanged. See `SYNC-DEPLOYMENT.md`.
4. Transfer only `pro-client.json` from the existing private server credentials
   to a mode-0600 ignored local file; never print its token. Then
   `ops/deploy-pro-sync.sh <verified-Pro-IP> <private-config>` backed up Dates,
   replaced its writer and installed that file as private `sync.json`.
   Transaction `dates-sync-pro-20260919T095839Z` preserved UI PID 306456 and
   started writer PID 307144, zero restarts. No UI restart for this step.
5. Read-only real-notebook queries verified 356 current pages, 282 native
   modification dates grouped into 113 days, and three creation observations.
   `ops/verify-pro-sync.mjs` verified all three exact Pro observations through
   the HTTPS hub using the Move credential, without changing local history.
   Pro status then read **Up to date**. This is not physical Move delivery.

Private rollback archives are on-device below
`/home/root/.codex-backups/<transaction>/` and copied to `.cache/<transaction>/`.
Their SHA-256 values are:

- Calendar: `02d219c34eb654e21c8578bf3126cc4125ccb6d7cb4b63f4cfe471bf6b5c22ae`
- Pro sync: `baa388fc9feb7a195e9674ca50217f346cac135204c6c72f24f1c304920cf9e3`

The calendar rollback restores only its panel/helper and returns to stock UI
if activation was attempted. The sync rollback stops only Dates, disables only
the newly installed matching config, restores the schema-2-aware v3 writer and
recreates its transient unit. Neither rollback restores old history over newer
records. Completed transaction markers prevent accidental replay of rollback.
All temporary recovery timers ended inactive; root stayed read-only, all ten
QMDs and Vellum state were identical, and the Pro's live/protected Gestik files
retained their separate `17dbbdd7…` / `82621111…` fingerprints.

### Move continuation

Credential-free discovery on 2026-09-19 found the Pro and another nonmatching
SSH host but no Move key anywhere on the current /24 network. Its last address
`.96` did not answer. Do not send credentials to a guessed host or install the
Pro controller on the Move. `ops/check-move-candidate.sh` passed composition
and QML syntax using the previously captured exact .169 Move ELF, resource
manifest, table and nine co-resident QMDs. The Dates QMD happens to hash to the
same bytes, but the Move runtime/watchdog/extension inventory is different.
This is offline preparation only; no Move branch was created before fresh
live identity/firmware qualification, per `MAINTENANCE.md`.

When it is reachable: match its known host key; qualify model/current firmware,
stock/runtime/table/QMD hashes and its own settings; create its exact Dates
branch; adapt the existing Move QRR-only session guard; then install and enable
only its `move-client.json`. Test one shared disposable notebook physically in
both directions, offline/reconnect, and ensure receiving history does not
silently enable tracking. Calendar aesthetics/touch behavior on Pro and all
physical two-tablet acceptance remain explicit user checks.

## Historical upgrade: date-focused v3 (2026-09-19)

For the already accepted v2 ten-QMD Pro inventory, use
`bash ops/deploy-dates-v3.sh <verified-Pro-IP>` after the local gates pass.
This is not a reusable fresh installer: it deliberately pins the exact v2
payload and refuses any other starting state. It replaces only the Dates
service binary and external panel, and adds `DateTree.js` alongside the panel.
The repaired Dates QMD stays at `f6cba319…`; all ten QMD bytes remain unchanged.
RMStream, firmware, native notebooks, timezone/token and each of the two Pro
Gestik files stay untouched. The Move is out of scope for this controller.

The new service reads native `.content` metadata only for Modified view and
explicit optional initialization. There is no native-file write path. Native
`cPages.pages[].modifed` is a string of epoch milliseconds; missing/bad values
remain undated. Created estimates are saved only after the user selects the
unchecked setting when enabling tracking. Never automatically backfill users'
notebooks during install or convert modification timestamps into observed creation.

The launcher verifies the SSH host key, stages a bound manifest, captures a
private rollback archive and verifies an off-device copy before activation.
Activation runs in a transient 150-second controller with a separate 180-second
rollback timer and the existing ReMagic stock watchdog. It recreates the writer
with `systemd-run --collect` after replacing the executable: stopping the old
collected transient writer removes its service registration, so `systemctl start`
alone is insufficient. Verify new writer/UI PIDs, zero restarts, unchanged
co-resident files, a real read-only notebook Modified query, and root still ro.

New writes use index schema 2. **Do not restart an old writer over new history.**
Rollback stops Dates (including safely handling an already-absent unit), retains
all data, restores payload preimages and returns to stock UI if activation was
attempted. Recovery should install a schema-2-aware writer. Only if it is proven
the candidate writer never ran and all indexes are still schema 1 may the old
writer safely be recreated. Never restore an old data archive over new records.

`ops/probe-device.mjs <verified-IP> <notebook-UUID>` compares the real service's
Modified groups, timezone dates and page links against native metadata without
printing notebook contents or tokens. It asserts the native file's hash stayed
unchanged. The node/QML test harness also exercises baseline save/load through
the actual HTTP service using synthetic metadata, not a user's notebook.

Sync remains opt-in through private `sync.json`. The current preimage has none;
the v3 controller asserts that remains true, rather than unexpectedly activating
the newer optional worker. Upgrade the private hub to the same source before
enabling estimate-aware clients; use its separate guarded service-only recipe.
Credential generation now requires explicit `--sync-endpoint`; existing
credential files and personal endpoints are never regenerated on upgrade.

## Historical build and preserve

For the 2026-09-18 Add page regression, use the paired four-file repair in
`../appload-rmstream-beta/ops/deploy-notebook-ui-repair.sh`, not an old preview or
promotion controller. It pins the current ten-QMD Pro state and changes only
the two UI payloads for Dates and sharing. The deployed local-only writer stays
at `3f4df0ae...`; do not accidentally deploy the newer sync-capable source build
as part of this UI repair. Opt-ins, timezone, history and Gestik remain intact.

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

## Add page blocker and control redesign: 2026-09-18 UTC

Live errors at `Values.qml:124` proved `DocumentController is not defined` when
adding a page. The former JS mock exposed a global that the real singleton did
not have. Each stock call site now passes its native controller explicitly;
observer failures are isolated and the stock callback runs before recording.
Nine JS tests plus an actual QML lexical-boundary test pass, including missing
global controller, native receiver/return/callback forwarding and thrown recorder.
All 21 Go tests, real Qt HTTP transport, styled panel runtime, exact-resource
composition and wrong-firmware rejection also pass. The Go build is NOT deployed.

The paired UI-only repair `notebook-ui-repair-20260918T205836Z` passed, with UI
PID `300139`, `NRestarts=0`, ten QMDs, four extensions and read-only root.
Writer PID `296107` and binary `3f4df0ae…` stayed unchanged; no metadata or
preferences were overwritten. Large flat e-ink controls replace the tiny
desktop-default buttons and timezone selector.

- QMD: `f6cba3190f3f690c2729539f0ecc3b629dd0d18366dc22fc5a89174df73731e0`
- Panel: `4c54d26c75fa506375442dc608634187ef81fa6fd688a9d0031aa43051cd409e`
- Backup: `dab755a5fe8885715caa706b6d40192e9e2217244c9f51a66d61086e63f9673f`

Recovery/evidence belongs to `../appload-rmstream-beta/.cache/` under that ID;
its recipe/controller pins all four old/new files and restores only UI bytes.
The original bad hook must not be promoted on Move. Physical creation/index
navigation tests remain pending. Shared metadata client rollout remains pending.

## Dates v3 execution: 2026-09-19 UTC

User authorized the current branch and direct implementation (no preview).
The Pro was freshly identified by the pinned Ed25519 key, Ferrari model,
3.28.0.169/build 20260806095513, exact stock hash and ten-QMD/four-extension
inventory. Its two Gestik files had different valid hashes and were preserved
independently. No Move connection, configuration, firmware or payload was changed.

**Final payloads:**

| Artifact | SHA-256 |
| --- | --- |
| `notebook-date-index` | `3fb46a9ca713baf80e581ddd423b660fc45aefe97b7cc1ea9e21a22a95f959e0` |
| `DatesPanel.qml` | `dc1460092f72db8bc3e10295ca0467bce94cbfc18cd66d0746be84290b9e1e00` |
| `DateTree.js` | `340239c6fadf7ba761e30a7b77a02de2dd2aa4d21658a57e6575b8a30e93e2d3` |
| Dates QMD (unchanged) | `f6cba3190f3f690c2729539f0ecc3b629dd0d18366dc22fc5a89174df73731e0` |

The final local suite passed 28 Go tests (race detector), vet, 14 JavaScript
tests, real Qt-to-service Created/Modified/optional-baseline requests, rendered
QML interaction/navigation, native creation-callback isolation, both exact-QMD
compositions and wrong-firmware rejection. Compact/landscape panel fixtures
also passed before the final unsupported-attachment removal/header refinement.
These rendered fixtures are not a Move qualification or physical pen test.

1. `dates-v3-20260919T085736Z` stopped before a UI restart: stopping the collected
   transient writer removed its unit, so `systemctl start` failed. The first
   rollback also assumed a unit existed. Corrected recovery restored both old
   payloads, preserved all data, and confirmed the candidate writer had never
   run/all indexes remained schema 1 before recreating the old writer. UI PID
   300139 and `NRestarts=0` stayed unchanged throughout. Failed evidence remains
   in the transaction; the updater now recreates the service explicitly and
   rollback tolerates an absent unit but refuses a surviving writer PID.
2. `dates-v3-20260919T085936Z` installed the new writer, panel and JS helper.
   Its machine guard passed at UI PID 303169, writer PID 303054, zero restarts.
   Later detailed log review found `Accessible.name` was unsupported by the
   tablet Qt build, so this was **not accepted as a working panel**. The initial
   narrow error matcher missed `Non-existent attached object`; the gate now
   rejects every source-located DatesPanel/DateTree diagnostic.
   Backup SHA: `28955080c1d5b53e549247dafe62e6903a47f38870729c4acdbad0dd7d93cbbb`.
3. `dates-v3-panel-20260919T090351Z` changed only the external QML panel,
   removing the unsupported attachments and explicitly positioning header
   controls. Its independent rollback and pinned ReMagic checks passed at UI
   PID **304002**, zero restarts; writer PID **303054** remained unchanged.
   No DatesPanel/DateTree diagnostics remained. Known pre-existing Toolbar,
   Experimental and StatusIndicator startup warnings were unchanged.
   Backup SHA: `8dbd731c2726ca88ae7335e906fe4a3f513c64e66786805dbb9f0492b7133b46`.

All ten QMDs, runtime libraries, RMStream payloads, Vellum files, saved timezone,
token, and independent live/protected Gestik files matched their preimages.
Root stayed read-only and all temporary rollback timers were inactive afterward.
Private backups/manifests/runtime logs are retained under `.cache/<transaction>`
on the Mac and `/home/root/.codex-backups/<transaction>` on the Pro.

A real-notebook read-only service probe verified **356 current pages**, of which
**282** have native modification dates grouped into **113 days**. Their dates
matched `Asia/Jerusalem`, page links matched stable IDs, the existing Created
view retained its one recorded day and tracking-on state, and the native file's
hash was unchanged. No initialization was performed on the user's notebook.
Backfill save/load and provenance were tested only with synthetic fixtures.

Remaining: user physical acceptance of the redesigned panel, date navigation,
and optional baseline on a disposable notebook. The user accepted single-device
functionality before this visual revision, not these new controls. Sync is
still unconfigured on Pro; the hub and Move were untouched and must receive
their own qualification/upgrade before two-device acceptance can be claimed.
