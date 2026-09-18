# Design

## Modules

- `main.go`: static Go loopback service on `127.0.0.1:18742`. A private random
  token authorizes JSON POSTs; no CORS, no external bind, no notebook file access.
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
- `ops/deploy.sh`, `install-device.sh`, `rollback-device.sh`: strict key-only
  host verification, exact-state preflight, off-device backup proof, transient
  controller and independent timer. The initial preview service rejects writes
  as well as disabling recording in QML; physical acceptance gates promotion.

## Main functions

`Store.apply` validates IDs and event provenance, serializes state changes,
and returns current surviving date groups. `toggle` establishes an undated
baseline. `record` is idempotent by notebook/page UUID and only commits for an
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
