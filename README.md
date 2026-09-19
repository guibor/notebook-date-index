# Notebook Dates

**Remember the day, find the page.**

Notebook Dates adds a date navigator inside your reMarkable notebooks. Browse
a calendar or a compact date list, then jump straight to the page you want.
Your handwriting, normal table of contents, and PDF outlines stay unchanged.

![Notebook Dates calendar with one month and marked days. Synthetic example.](docs/images/dates-calendar.png)

> **Experimental, firmware-specific extension.** Installed on Paper Pro and Paper Pro
> Move running **3.28.0.169**, with separately qualified builds.
> This is not an official reMarkable app or a general one-click installation.
> Read the [installation and compatibility guide](docs/INSTALL.md) before
> changing a tablet. A nearby firmware version is not automatically compatible.

## At a glance

- **Created or Modified:** find pages by their recorded creation day or their
  latest saved modification day.
- **Calendar or list:** one month with arrow navigation, or days nested inside
  months and, for longer histories, years.
- **Direct page links:** marked calendar days open page choices; stable page IDs
  keep navigation working after pages are reordered.
- **Per-notebook tracking:** enable it where useful, pause without losing history.
- **Optional historical estimates:** initialize undated pages from their saved
  modification dates, clearly labelled as estimates.
- **Offline first:** no account, API key, LLM, or server is needed for local use.
- **Optional self-hosted sync:** share creation-date history for the same
  notebook between your devices, without uploading handwriting to the Dates hub.
- **E-ink-focused controls:** high-contrast controls, generous touch targets,
  settings behind a gear, and no animation-dependent navigation.

## Getting started

Already have a qualified installation?

1. Open a notebook.
2. On **Paper Pro**, tap the **calendar icon above BetterTOC** in the sidebar.
   On **Move**, open **⋮ → Dates**. Pro also has the menu fallback when the
   toolbar has too little room for the direct icon.
3. Choose **Modified** to browse existing saved page dates immediately.
4. To record future creation dates, open **Dates → ⚙ → Enable for this notebook**.

The **Created / Modified** control chooses what a date means. The two small
**list / calendar icons** choose how to display it. The black icon is the
current layout; tapping the other icon switches layouts.

New installation? Start with [INSTALL.md](docs/INSTALL.md), not a script in
`ops/`. Those scripts are guarded maintainer transactions for particular
starting states, not an installer for arbitrary tablets.

## What the dates mean

| View | Source | Tracking required? | After editing a page |
| --- | --- | --- | --- |
| **Created** | Creation observed by Dates after a successful native page-creation action | Yes, to record future pages | Its recorded creation day stays fixed |
| **Modified** | The notebook's built-in saved per-page modification metadata | No | It moves to the latest saved modification day |

**Old creation dates cannot be recovered reliably.** When enabling tracking,
you may check **Include undated pages using last-modified dates (estimates)**.
It starts unchecked. This takes a one-time snapshot for pages with no recorded
creation date; entries remain labelled **estimated**, and existing recorded
dates are never overwritten.

Modified is a latest-edit view, **not a full edit history**. An unsaved edit may
not appear until reMarkable saves its metadata. Missing timestamps stay undated.
Dates does not guess from file modification times.

## Finding pages

### Calendar

One month is shown at a time. Use **‹ / ›** to move through months, including
empty intervening months. A black dot means that day has matching pages.

Tap a marked day to choose a page. The lighter dates from the preceding or
following month are tappable too. Back returns to the month you were browsing.
Weeks start on Sunday. In **Modified → Calendar**, the selected day's pages are
ordered by their current page number.

### List

Days are nested inside collapsible months; years become an outer level when
needed. Recent history is expanded first.

Tap a day to open its first surviving page, or **+** to reveal individual page
links. Deleted pages are hidden; undo can reveal their original dates again.

![Dates list with nested months, days and page links. Synthetic example.](docs/images/dates-panel.png)

Reopening Dates keeps the matching notebook's loaded history visible while it
refreshes. A failed refresh is labelled as showing saved dates. Cached history
is never shared between different notebooks.

## Tracking, settings and timezone

Tracking is **per notebook and per device**, off by default. Pause keeps
existing history but stops recording new pages. Copies have new notebook IDs
and do not inherit tracking automatically. Imported or moved-in pages are not
mistaken for new creations; you can explicitly include undated pages in a
later estimated baseline.

The gear contains tracking, estimated initialization, timezone, and sync
status. The default timezone is **Asia/Jerusalem**, including daylight-saving
rules, and is configurable. Changing it immediately regroups Modified view
and affects future creation observations; previously stored creation days do
not move. The tablet's system clock/timezone is never changed.

See [settings and backup details](docs/INSTALL.md#settings-and-backups) for the
private configuration path and custom IANA timezone names.

## Optional sync: your server, your devices

Without a private `sync.json`, Dates stays local-only. There is no built-in
personal server endpoint or fallback account.

The optional hub exchanges **creation-history metadata only**: notebook/page
IDs, times, dates, timezones, estimate flags, and originating device names.
It does not receive handwriting, notebook titles, document text, or PDF contents.
Modified view is computed locally; an explicitly saved creation estimate can
be synchronized as creation-history metadata.

Your normal reMarkable sync continues unchanged. **Dates does not sync notebooks
or pages**: matching notebook/page IDs must already be present through your
existing notebook-sync method. Offline date observations merge rather than
replacing the other device's whole history. Tracking switches, timezones,
Gestik, and unrelated preferences remain device-local.

Read the [self-hosting guide](docs/SELF-HOSTING.md) for server setup, independent
device credentials, private configuration, and synchronization limits.
No hosted service is included.

## Compatibility and installation status

This checkout is the **Move** branch; use the Pro branch for a Paper Pro.

| Device | Firmware tested here | Branch | Entry point |
| --- | --- | --- | --- |
| Paper Pro / Ferrari | `3.28.0.169` | `beta/pro/3.28.0.169` | Sidebar calendar; menu fallback |
| Paper Pro Move / Chiappa | `3.28.0.169` | `beta/move/3.28.0.169` | Notebook ⋮ menu |
| Other models or firmware | Not qualified | — | Do not use these deployment scripts |

Both devices have feature revision **6**. Matching firmware alone is not a
complete installation check: the existing XOVI/QMLDiff setup and other patches
also matter. The Pro sidebar integration currently assumes the qualified
BetterTOC toolbar patch.

There is **no general ReManager/Vellum package or public one-command tablet
installer yet**. The [installation guide](docs/INSTALL.md) explains the source
build, required qualification, layout, backups, and recovery boundaries.
The [compatibility matrix](compatibility.json) separates installed artifacts,
automated evidence, and outstanding physical checks. Successful sampled
Pro-to-Move history delivery does not prove every offline or reverse-direction case.

## Development

The portable source checks need Bash, **Go 1.24+**, **Node.js 18+**, and a C
compiler for Go's race detector:

```sh
bash scripts/test-portable.sh
```

They need no tablet, SSH credentials, Qt installation, private firmware cache,
or sibling repository. They test storage, metadata, synchronization, creation
wrappers and calendar logic, check recovery-policy fixtures, and cross-build
the Go service for Linux ARM64.

This is **not tablet compatibility certification**. The full Qt/QMLDiff gates
still need exact, privately extracted firmware resources and a reviewed
co-resident patch set. See [CONTRIBUTING.md](CONTRIBUTING.md) for both levels,
source layout, and reporting bugs without private notebook data.

## Safety and recovery

Dates is an unofficial modification, not supported by reMarkable. No hack is
risk-free. App files stay under `/home/root`; the reviewed installation does
not modify the bootloader, kernel, firmware, or stock executable. Runtime
services are transient: reboot may require guarded reactivation, and a firmware
update requires new qualification.

Back up the entire private Dates data directory, not just your notebooks.
Do not restart an old writer over newer schema-2 history or restore an old
archive over dates recorded since that backup. For everyday use, **Pause
tracking** is the reversible way to stop recording.

- [Installation, backups, troubleshooting and removal](docs/INSTALL.md)
- [Privacy and security reporting](SECURITY.md)
- [Design and main functions](design.md)
- [Requirements and next steps](prd.org)
- [Branch and release maintenance](MAINTENANCE.md)

Repository: [guibor/notebook-date-index](https://github.com/guibor/notebook-date-index).

**Publication status:** this repository is public as of 2026-09-20. No license
grant has been selected yet; public visibility alone is not an open-source
license. See the [publication checklist](docs/PUBLICATION.md) for the remaining
licensing and community-installation work.
