# Installation, compatibility and recovery

[Back to README](../README.md)

## Read this before installing

Notebook Dates revision 6 is running on the maintainer's Paper Pro and Paper
Pro Move with firmware **3.28.0.169**. Those are separately qualified
installations, not evidence that a generic installer supports every device
on that firmware.

**There is not yet a general first-install package for third-party tablets.**
The scripts in `ops/` deliberately pin the maintainer's device identity,
firmware, existing patch inventory, payload preimages and recovery machinery.
Do not run them after replacing an IP address, serial, hash, or patch count.
A refusal is a safety check, not something to work around.

If you want an ordinary download-and-install experience, wait for a portable
package with its own documented compatibility and recovery validation.
If you maintain XOVI/QMLDiff integrations, the source-build and qualification
workflow below is the current route. It is not a claim that deployment is
automatic or fully supported on your setup.

## Prerequisites

- Paper Pro/Ferrari or Paper Pro Move/Chiappa on the exact tested firmware.
  Other firmware/models need a port; do not downgrade just to try Dates.
- Developer/SSH access already configured by the device owner. Follow official
  device guidance and make backups before changing developer-mode settings.
- A separately qualified XOVI + QMLDiff runtime and a proven way to return to
  stock operation. Dates does not install or qualify this runtime for you.
- On Pro, the current sidebar hook assumes the qualified BetterTOC toolbar
  integration. Move has a separate menu-only hook and recovery setup.
- Private backups of native notebooks, existing hacks/settings, and Dates data
  if already installed. Keep an off-device copy.
- An independent timed recovery path established before any UI restart.
  Keeping an SSH window open is not a substitute for recovery.

Dates itself does not require an LLM, API key, OpenClaw, or a sync server.

## 1. Select the correct source

Once the repository is accessible to your account, clone the target branch:

```sh
# Paper Pro
git clone --branch beta/pro/3.28.0.169 --single-branch \
  https://github.com/guibor/notebook-date-index.git
```

For Move, use `--branch beta/move/3.28.0.169` instead.
Check `target.json` and [compatibility.json](../compatibility.json).
Do not treat a Pro build as a Move build merely because both are ARM64.

## 2. Run source checks and build the service

From the repository root:

```sh
bash scripts/test-portable.sh
```

This needs Bash, Go 1.24+, Node.js 18+, and a C compiler for the race detector.
The tested release toolchain was Go 1.24.6. An installed local toolchain is
used; the script does not download tools. For repeatable release hashes, use
the recorded toolchain and build flags, not merely a recent Go version.

The cross-built service is:

```text
build/portable/notebook-date-index
```

It is only the backend. Copying it to a tablet does **not** install the UI,
creation hooks, service configuration, or recovery mechanism.

## 3. Qualify the UI integration — required, not automated here

An experienced maintainer must:

1. Verify SSH host identity before authenticating, then read model, exact
   firmware and stock executable/resource hashes. Do not infer identity from IP.
2. Extract resources from their own exact firmware and keep them private.
   Stock reMarkable resources are not distributed by this repository.
3. Review `build-qmd.mjs` for the selected target. Its current resource paths
   reference the maintainer's sibling firmware caches; they are not a portable
   resource-discovery interface.
4. Build the Dates panel/helper and QMD, then hash/check/compose the QMD with
   the **entire actual installed patch set**, using the matching QMLDiff tool.
   Validate composed QML, hook call sites, and rejection of wrong firmware.
5. Run the Qt transport, creation-callback, UI and delayed-refresh tests as well
   as the portable source suite. See [contribution guidance](../CONTRIBUTING.md).
6. Review a device-specific deployment and rollback transaction, capture exact
   private preimages, and verify an off-device recovery archive before staging.
7. Activate only through that qualified runtime under independent rollback.
   Check stable stock/UI processes, expected mappings, logs, read-only root,
   unchanged unrelated settings, and exact installed payload hashes.
8. Physically test a disposable notebook: writing, page creation with tracking
   on/off and Dates unavailable, page navigation, delete/undo, and normal TOC.

The historical [Pro recipe](../PRO-UPDATE-RECIPE.md) and
[Move recipe](../UPDATE-RECIPE.md) document accepted transactions and
recovery design. **They are not replayable installation commands.** The Pro
recipe's revision-6 upgrade used eleven QMDs; a later unrelated Dispatch menu
made the maintainer's Pro inventory twelve. Do not replay the old controller
against that current stack or expand its guard to make it pass.

## Installed layout

| Purpose | Path |
| --- | --- |
| Backend, panel and helper | `/home/root/.local/lib/notebook-date-index/` |
| Dates QMD | `/home/root/xovi/exthome/qt-resource-rebuilder/notebook-date-index.qmd` |
| Private dates, token, settings and optional sync state | `/home/root/.local/share/notebook-date-index/` |
| Local tablet HTTP service | `127.0.0.1:18742` |
| Runtime service/recovery controls | Transient systemd state under `/run` |

Do not expose the tablet HTTP service to the network. A sync hub is a separate
optional service; see [SELF-HOSTING.md](SELF-HOSTING.md).

## First use

Open a notebook and use the sidebar calendar on Pro or **⋮ → Dates** on Move.
Modified view works without tracking. In settings, enable tracking separately
for each notebook/device where you want future creation dates.

The historical-estimates checkbox is intentionally off by default. It records
last-modified values as estimates, not recovered true creation times.
Installation must not silently enable tracking or initialize history.

## Settings and backups

Back up **all of** `/home/root/.local/share/notebook-date-index/` privately.
It includes authentication tokens, device settings, per-notebook indexes,
`.previous` recovery copies, and optional `sync.json` / `sync-events/`.
Regular notebook backups do not include this separate Dates history.

Prefer the qualified transaction's consistent backup procedure; stop or
coordinate the writer before an ad-hoc copy so index/journal files agree.
Keep private directories mode 0700 and secret/settings files mode 0600.
Never upload these backups to GitHub or attach them to a public issue.

Set timezone through **Dates → ⚙**. For an IANA zone not offered by the menu,
the private `settings.json` has this shape:

```json
{"schema":1,"timezone":"Europe/Paris"}
```

Preserve permissions and replace it atomically, not with an interrupted
in-place write. It is read on the next request. Do not copy one tablet's full
settings directory to another just to share date history.

## Troubleshooting

| Symptom | What to check |
| --- | --- |
| No Dates entry | Exact model/firmware, qualified runtime activation, QMD composition, and notebook type; Dates is not a PDF/EPUB date navigator |
| Dates cannot load/save | Local Dates service, matching token/payloads, and actual Qt-to-service request path; a server health check alone is insufficient |
| Created is empty | Tracking is off by default; existing pages are undated unless explicitly initialized as estimates |
| Recent edit missing from Modified | Let the notebook save, then reopen Dates; missing native metadata is not guessed |
| Sync is waiting/offline | Notebook IDs must match, pages must already exist locally, and HTTPS/device credentials must be valid |
| App disappeared after reboot/update | Runtime is intentionally transient; use a newly qualified reactivation/update path, never a stale installer |
| Native page creation misbehaves | Stop testing on important notes; return to stock using the qualified recovery path and preserve diagnostics |

A metadata-sync error must not block writing. Never paste tokens, real notebook
JSON, private URLs, or unredacted logs into a public issue.

## Pause, remove or recover

**Pause tracking** in Dates settings for ordinary day-to-day use. Existing
history remains browseable.

Removal requires disabling the Dates QMD and stopping the Dates service through
the same qualified recovery procedure used to install it. Preserve the whole
data folder unless you explicitly want to erase date history. Do not delete
shared XOVI/AppLoad files or another app's patches.

Schema-2 data must not be opened by an older schema-1 writer. A rollback should
stop Dates, preserve current data, restore only the reviewed payload preimages,
and recover stock UI if necessary. Do not overwrite newer history with an
older backup merely because the app version is being rolled back.

No bootloader, partition, firmware, kernel, stock executable, or writable-root
change is part of the reviewed Dates installation. Do not introduce those
changes to bypass a failed compatibility check.
