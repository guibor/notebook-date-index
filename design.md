# Design

## Navigation refinement (revision 5)

The header's `layoutButton` toggles List / Calendar; Created / Modified remains
the sole segmented control. `pagesForDay` copies a day's page array and sorts it
numerically only for Modified-calendar navigation. The original response/list
order and all stored dates are unchanged. Stable page IDs are still resolved at
tap time, including after notebook page reordering.

`build-qmd.mjs` accepts the exact `NDI_TARGET=pro|move` target. Pro adds a calendar
tool immediately before BetterTOC, participates in its existing extension-slot
accounting, and retains a notebook-menu fallback on short toolbars. Move adds no
sidebar tool and keeps the notebook-menu entry. Both targets use identical panel,
helper and backend bytes; only their independently qualified QMD hooks differ.

The Pro `deploy-navigation` transaction replaces only its panel, helper and
Dates QMD. It preserves the running writer, token, sync config, tracking history,
all other QMDs, RMStream and both Gestik files, using independent rollback.
Move's first install uses `install-move-dates` for Dates-only payloads and its own
credential, after a complete off-device preimage and verified stock recovery.
`ops/move-runtime` vendors the accepted Move watchdog/controller/shadow writer
byte-for-byte. `move-profile-lib` changes only its exact inventory count to ten;
the Dates-specific profile binds the new complete manifest. `run-move-session`
uses that profile without changing any recovery semantics. An independent
ten-minute outer rollback asks the Move watchdog to recover stock, disables
only the new Dates QMD and preserves all Dates data if first installation fails.

## Calendar presentation

Date basis (Created/Modified) and presentation (List/Calendar) are independent
panel state. `dayGroups` indexes the existing response without changing it;
`calendarRange` supplies a numeric, lazy month model spanning all dated pages;
`calendarMonth` produces a Sunday-first 42-cell UTC-safe grid, including leap
days and empty intervening months. It allocates only visible month delegates,
not a day model for the whole history. A dot represents one or more available
pages, never the number of events or a guessed date. Empty history shows the
current month without inventing records. `selectDay` opens an in-panel page
picker; the calendar stays instantiated so Back preserves its scroll position.
All page actions use the existing stable-ID resolver. Calendar browsing makes
no writes, requires no new QMD hooks, and never changes the selected date basis.

`ops/deploy-calendar.sh` installs just the Pro panel/helper against the exact
v3 preimage, with verified off-device backup, an independent rollback timer and
the pinned ReMagic UI watchdog. It preserves the writer PID, data and every QMD.

`queueSyncLocked` signals a bounded background channel when a notebook is first
viewed or its Dates index changes. `syncAttempt` keeps status per notebook and
uses a local revision to avoid saying “Up to date” if a page was created while
the request was in flight. A failure in one notebook cannot overwrite another
notebook's sync status. Minute-based retries remain available while offline;
no network operation runs under the native page-creation or local writer lock.
Release builds disable Go's implicit VCS stamps, so the same source/toolchain
produces identical payload bytes regardless of unrelated uncommitted docs.

The service-only `ops/deploy-pro-sync.sh` controller backs up the schema-2
payload/history, verifies the calendar preimage, installs only the matching
private Pro config and new writer, and preserves the xochitl PID. Its independent
rollback removes only that newly installed config, restores the schema-2-aware
prior writer, and retains all current indexes/journals. The estimate-aware hub
upgrade runs first through `ops/deploy-hub-v3.sh`, preserves nginx/credentials,
and tests estimates in the isolated probe namespace before real clients start.

## Page-creation regression repair

Device logs exposed a missing lexical import: Values does not import the native
DocumentController singleton used by the four stock creation callers. The hook
now receives that controller from each original call site. `ndiAddPage` invokes
the controller as its original receiver, returns its result, and forwards all
callback arguments and context. Both observer entry points are exception-isolated;
the stock callback runs before recording. No storage/network result is awaited
by page creation. Tests deliberately omit any global DocumentController, unlike
the original mock that concealed this bug. Generated call-site tests bind this
contract to every exact-firmware replacement.

The panel defines a qualified, inline `DatesButton` with flat black/white states,
64-pixel touch targets and explicit typography. The timezone picker uses the
same treatment. No global Qt style or other app's controls are changed.
`creation-runtime-test.mjs` exercises the lexical boundary in an actual Qt
runtime and asserts every generated caller passes its native controller.
The paired four-file deployment controller is owned by the sibling
`appload-rmstream-beta/ops/repair-notebook-ui.sh`; it leaves the already-running
local-only writer untouched. Source sync support is not deployed by this repair.

## Repository and target ownership

This application owns `guibor/notebook-date-index`. `MAINTENANCE.md` defines
shared Pro/Move feature development and target-specific release gates;
`compatibility.json` records actual deployment/acceptance status without
claiming an untested Move build. Shared logic remains in the backend and QML
modules below, while each firmware branch owns its exact hooks and deployment
pins. The Pro now exchanges Dates history with the private hub; the physical
Move rollout is pending. This is not permission to merge unrelated device-local settings.
The existing source history was published privately on 2026-09-18, retaining
`beta/pro/3.28.0.169` as the current branch rather than renaming a deployed target.

## Date-focused revision (2026-09-19)

`metadata.go` adds a bounded, no-symlink, read-only `.content` reader. It uses
only `cPages.pages[].modifed` (the firmware's spelling), a string of epoch
milliseconds, filters by the current notebook's stable page IDs and ignores
missing/invalid/duplicate page records. It never falls back to filesystem times,
scroll time, notebook timestamps or CRDT counters, and never writes native files.

`modifiedPages` returns transient page/date records in the selected IANA zone.
`Store.apply` exposes a `mode` query (created by default, modified independently
of tracking). An explicit off-to-on `initializeFromModified` request adds only
undated pages as `estimated:true`, once. A metadata read failure aborts this
toggle before any save. Later edits, re-enabling and timezone changes cannot
overwrite a saved creation date. View results include undated and estimated
counts; page links carry estimate provenance.

New saves use index schema 2; both schema 1 and 2 can be read. Deployment must
not start a legacy writer over schema 2 during rollback (its old backup recovery
would discard newer state). Emergency rollback stops Dates, preserves all its
data, restores payload preimages, and returns the UI to stock; explicit recovery
uses a schema-2-aware service. The ordinary old schema-1 data remains intact
until the first real tracking write; a query does not migrate it.

`qml/date-tree.js` is pure presentation logic: latest-first month groups, a year
level for multi-year histories, stable expansion keys, and page estimate labels.
The builder installs it as `DateTree.js` next to the external `DatesPanel.qml`.
`qml/popup.qml.inc` has a Created/Modified switch, a list-first view and an
in-panel settings page (not another modal). Its request generation guard rejects
stale responses after a view/notebook switch. All navigation resolves page IDs
again when tapped. Scrolling settings accommodates smaller/landscape viewports.

`canonicalPages` now prefers recorded creation over an estimated baseline,
then earliest UTC and stable event hash. Journals retain both observations.
An older hub rejects the unknown estimate field rather than accepting it without
provenance; upgrade hub/clients together before enabling this path. New credential
generation requires `--sync-endpoint` and supports custom `--devices` names.
No personal endpoint is compiled into the service. Existing private `sync.json`
files are preserved; no file means local-only. Modified view is never uploaded.

`ops/deploy-dates-v3.sh` owns the exact existing Pro upgrade: host-key validation,
manifest-bound staging and off-device backup verification precede a transient
device controller. `upgrade-dates-v3.sh` pins the accepted ten-QMD inventory and
old Dates payload, backs up all private Dates data, replaces only the binary,
panel and new JS helper, and uses both an independent 180-second rollback and
the pinned ReMagic watchdog. All QMDs, RMStream, package state, timezone/token,
Gestik and firmware remain byte-identical. `rollback-dates-v3.sh` stops Dates
before restoring old payloads and never overwrites newly recorded history.
The guarded upgrade is deliberately not a general installer or a Move port.
The writer is a collected transient unit: a stop removes its registration.
Activation must recreate it with `systemd-run`, and rollback must safely accept
an already-absent service while still refusing to proceed if a writer PID exists.
The tablet Qt build omits `Accessible` attached properties; do not add them based
on desktop Qt support. Gate every source-located DatesPanel/DateTree diagnostic,
including `Non-existent attached object`, not only ReferenceError/TypeError.
`ops/deploy-v3-panel.sh` applies that one-file correction against the exact first
v3 payload, preserving the writer PID and all history. Its independently guarded
controller/rollback never replaces the service or touches schema-2 data.

`examples/` provides owner-neutral sync/settings JSON and a hardened user-service
template. `ops/install-hub.sh` remains an exact, host-qualified historical
operator controller; it now requires explicit endpoint/health URLs rather than
supplying a personal default. It is not the generic third-party install path.

## Modules

### Cross-device Dates synchronization (hub and Pro deployed; Move pending)

The local store remains the offline source for the UI. The sync layer exchanges
individual creation records keyed by verified notebook/page identity,
preserving the originating timestamp, calendar day, timezone and offset.
Receiving notebook content or metadata must never create a new date event.
The existing local single-writer/atomic-save boundary must also serialize merges.
Do not use whole-file last-writer-wins synchronization: it can lose offline
events from either tablet. Conflicting records need a documented deterministic
policy with retained provenance, rather than silently guessing the true date.

Page absence on one tablet may mean content has not synced yet, not deletion.
Keep such records; resolve navigation against locally available page IDs and
do not propagate inferred deletions. A copied notebook must not inherit another
notebook's history solely because its name or page numbers match.

The user authorized md-server on 2026-09-18. `sync.go` implements an authenticated
loopback hub behind the existing HTTPS origin at `/dates/v1/exchange`, plus an
optional tablet worker enabled by private `sync.json`. Independent Pro/Move
tokens authorize a shared history namespace; a probe token has a separate test
namespace. Tokens are generated on the server, stored privately and never logged.
No handwriting, notebook titles or document content is transmitted. Native
notebook/cloud sync is unchanged. Enable/pause and future-event timezone choices
remain per-device; receiving history never enables tracking automatically.

`captureLocked` records local observations in `sync-events/<notebook>.json`
before network I/O and again afterward, so concurrent creation cannot be lost.
`mergeEvents` forms a sorted, deduplicated append-only set keyed by event hash;
received observations are not reattributed to the receiving device.
`canonicalPages` selects observed creation over an estimated baseline, then
the earliest UTC for each page with a stable hash tie-break. All conflicting observations/provenance remain in the journal;
an incorrect device clock cannot be inferred or repaired automatically.
`syncNotebook` merges journals before updating the schema-2 local
index through its existing single-writer lock and atomic save. Corrupt journals
fail closed and retain their bytes and prior backups. No inferred deletion sync.
`syncLoop` checks watched/indexed notebooks after queued changes and once per minute; network calls never
hold the UI writer lock. TLS verification is mandatory and redirects forbidden.
Preview mode never starts the sync worker. Existing local-only deployments are
unchanged until explicitly supplied a sync configuration and compatible writer.

`SyncHub.ServeHTTP` authenticates per-device credentials, rejects foreign origin
claims and unknown content fields, bounds requests/events, atomically persists
before acknowledging, and does not create notebook files for empty reads.
`ops/install-hub.sh` deploys a restricted user service on loopback port 18743,
backs up/pins the shared nginx config, adds one TLS-only include, validates nginx
and existing health before/after, and uses an independent timed rollback.
No extra public port is opened and no OpenClaw service is changed.
`ops/upgrade-hub.sh` provides independently guarded binary-only hub updates;
`ops/smoke-hub.mjs` validates authentication/persistence/isolation using only
synthetic data. `SYNC-DEPLOYMENT.md` distinguishes live server evidence from
the unperformed tablet rollout, and records exact paths/hashes and recovery.

Read-only identity checks found both devices on 3.28.0.169 and 1,331 shared
document UUIDs. Two sampled notebooks matched all 8/8 and 15/15 page UUIDs.
This validates the identity approach for those notebooks, not physical sync
acceptance or Move compatibility of the current Pro QMD.

### Current implementation

- `main.go`: static Go loopback service on `127.0.0.1:18742`. A private random
  token authorizes JSON POSTs; no CORS, no external bind, no native notebook writes.
  It owns a process lock and serializes read/validate/atomic-save transactions.
- `qml/values.qml.inc`: shared async request queue and isolated page-creation
  wrappers in the existing `Values` singleton. Recorder failures cannot block
  the original creation callback. Page snapshots are bounded at 20,000 IDs;
  ambiguous or stale (>10s) events are skipped, never assigned guessed dates.
- `qml/popup.qml.inc`: notebook-specific Dates panel, enable/pause and stable-ID
  navigation. No BetterTOC source changes. Stock PDF actions remain untouched.
  The builder emits a standalone `DatesPanel.qml`, loaded from the private
  payload directory, so its qualified Qt Controls imports cannot conflict with
  the firmware's own similarly named types or QMLDiff's import merger.
- `build-qmd.mjs`: exact `.169` QMLDiff source builder. Replaces only explicit
  stock creation calls and observes the existing Page Overview duplication
  success signal. Adds Dates to the Notebook settings (three dots) menu and
  also to More tools where available. It does not alter the firmware's toolbar
  grouping rule: More tools is hidden when the container height is >=1000.
- `main_test.go`, `qml-test.mjs`, `test.sh`: persistence/security/event tests and
  composition against the eight actual co-resident QMDs plus exact resources.
- `ui-harness.mjs`: local Qt runtime test for the actual popup with synthetic
  date groups. Standard controls are qualified as `NdiControls` because the
  tablet imports an unrelated `Popup` type with the same short name.
- `transport-test.mjs`: actual QML `ndiRequest`/`ndiPump` code against a native
  build of the real Go service, with a private synthetic token/data directory.
  This catches protocol mismatches that the mocked visual harness cannot.
- `ops/deploy.sh`, `install-device.sh`, `rollback-device.sh`: strict key-only
  host verification, exact-state preflight, off-device backup proof, transient
  controller and independent timer. The initial preview service rejects writes
  as well as disabling recording in QML; physical acceptance gates promotion.

## Main functions

`Store.apply` validates IDs and event provenance, serializes state changes,
and returns current surviving date groups. `toggle` establishes an undated
baseline unless the optional estimated initialization was explicitly selected.
`record` is idempotent by notebook/page UUID and only commits for an
enabled notebook. `query` never dates pages or writes a healthy index.

`load` validates schema and stored entries. A corrupt primary can recover a
validated `.previous` file; it retains the corrupt bytes for diagnosis. With
no valid backup it fails closed. `save` preserves the last valid version;
`atomicWrite` writes a mode-0600 same-filesystem temporary, fsyncs, renames,
then fsyncs the directory. A power failure can lose the latest event but not
silently turn partial JSON into a new empty index.

`view` groups by the date/UTC offset captured at creation, filters missing IDs,
and maps surviving IDs to current page numbers. Creation ordering, not current
position, determines the day's first page. Missing records remain on disk for
undo. Notebook ID is the storage boundary; duplication cannot inherit opt-in.

`settings` reads device-local `settings.json` (schema 1). `saveTimezone`
validates an IANA timezone and atomically saves it; missing settings default
to `Asia/Jerusalem`. Go embeds tzdata, so the tablet's UTC-only system files
do not limit Israel daylight-saving support. At each creation event the writer
converts its UTC timestamp to that configured zone and saves the original day,
offset and zone alongside the page. Later settings changes leave old records
unchanged. The authenticated `/v1/settings` endpoint and Dates-panel selector
work in preview mode, but preview still rejects page tracking/enablement.
No OS timezone, notebook data or other device's preferences are changed.

`ndiBegin` snapshots page IDs immediately before an explicit stock create/copy
operation. `ndiFinish` runs after its success callback/signal and accepts only
the expected set of new IDs. Duplication additionally requires signal-provided
page positions to match. Timestamp/offset are captured at success, not at
request initiation. A timeout, unexpected change or missing callback produces
no invented date. `ndiAddPage` preserves all original arguments and callback.
Duplicate tickets accumulate success IDs if the firmware splits a batch across
several single-page signals; unexpected IDs make that ticket fail closed.

`ndiRequest`/`ndiPump` serialize HTTP requests so opt-in changes and records stay
ordered. `ndiRefresh` queries just the current notebook and rejects stale UI
responses after switching documents. Navigation re-resolves IDs at tap time.
The HTTP gate parses Content-Type with `mime.ParseMediaType`, accepting JSON
with an absent or UTF-8 charset (which Qt appends), while still rejecting
non-JSON, malformed content types, other charsets, any Origin, non-POST requests
and invalid tokens. The service remains bound to loopback only.

## Deployment boundary

Payloads/data stay under `/home/root`; services/watchdogs are transient `/run`
systemd units. No automatic boot activation. First preview forbids recording
and enablement, then physical layout acceptance gates functional promotion.
Both variants use the same exact firmware, host-key, stock executable, runtime,
hashtable, co-resident QMD and protected-settings preflight. Independent rollback
returns to stock if the controller vanishes or the guarded UI fails.
`refresh-preview` replaces a hash-matched existing preview without claiming
physical acceptance. Its rollback preimages also cover the old backend,
panel and presence/absence of settings.json; the service stays in preview.
`backend-preview` additionally requires byte-identical candidate QMD/panel and
does not replace or reload either. It swaps only the backend, health-checks
the Qt-style JSON header, and requires the same live xochitl PID throughout.
Rollback restores and restarts only the previous writer in this mode, leaving
the tablet UI alone. Both variants retain the independent recovery timer.

The user accepted the healthy preview and requested activation on 2026-09-18.
The functional QMD/panel and non-preview writer passed guarded promotion in
`ndi-20260918T092752Z-functional`. Per-notebook enablement remains explicit;
this is not a global tracking switch or a claim of creation-event acceptance.
An independently maintained RMStream document shortcut is being added by the
sibling `appload-rmstream-beta` project; its composition tests include this
functional Dates QMD. Do not reuse the nine-QMD install guard after adding a
tenth patch without qualifying the new exact inventory.
