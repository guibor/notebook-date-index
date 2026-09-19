# Contributing to Notebook Dates

Thanks for helping make date navigation useful on e-ink. Start with the
[README](README.md) and [installation boundary](docs/INSTALL.md).

## Two levels of validation

### Portable source checks

Install **Go 1.24+**, **Node.js 18+**, Bash, and a race-capable C compiler.
The current release was tested with Go 1.24.6. No external Go modules are used.

```sh
bash scripts/test-portable.sh
```

You may invoke the script from any directory. It uses an already installed
toolchain (`GOTOOLCHAIN=local`), disables Go dependency downloads, and ignores
surrounding Go workspaces. Its HTTP tests open synthetic loopback listeners,
not external connections. Some sandboxes need permission for those listeners.

Checks include Go race tests/vet; JavaScript creation-wrapper/calendar tests;
pinned recovery-policy and mocked rollback checks; shell syntax; and a static
Linux ARM64 backend build at `build/portable/notebook-date-index`.
It does not overwrite the maintainer's release binary at `build/notebook-date-index`.

The source-tests workflow runs this gate on Linux. Passing it means source
tests passed—not that a tablet, firmware, or installation was qualified.

### Firmware and physical checks

`test.sh`, the Qt harnesses, and `ops/check-move-candidate.sh` belong to the
maintainer's exact-resource workflow. They require private stock resource
extractions and the reviewed co-resident patch set. Do not upload those resources.

In particular, **`test.sh` is Pro-oriented even in the Move checkout**.
It cannot replace the independent Move composition/runtime gates. The Qt UI
and flash harnesses also refer to the maintainer's Pro resource cache for icons.

A UI/hook/runtime change needs all applicable exact-target checks:
real Qt request transport, creation callbacks, UI/refresh behavior, QMLDiff
composition with every installed patch, wrong-firmware rejection, guarded
deployment/recovery, preserved settings, and physical pen/navigation acceptance.
Do not weaken a guard or edit expected hashes merely to turn a failing test green.

## Source map

| File/module | Responsibility |
| --- | --- |
| `main.go` | Local authenticated API, per-notebook store, atomic writes, settings |
| `metadata.go` | Read-only native per-page modification metadata |
| `sync.go` | Optional hub, per-device auth, background merge and provenance |
| `qml/values.qml.inc` | Request queue and exception-isolated native creation hooks |
| `qml/popup.qml.inc` | Dates panel, calendar/list, settings, cached refresh |
| `qml/date-tree.js` | Pure grouping/calendar/page-order logic |
| `build-qmd.mjs` | Exact-target QMD and external panel generation |
| `target.json` | Branch's device/firmware target |
| `ops/`, `profiles/` | Maintainer-only exact-state deployment/recovery evidence |

See [design.md](design.md) for the main functions and [prd.org](prd.org) for
behavior, changed requirements, and next steps.

## Branches and scope

Keep Pro and Move on their independent exact-firmware branches. Share backend
and panel improvements intentionally; preserve each target's hook, resource,
inventory, and recovery differences. A working Pro commit is not Move approval.

For a contribution:

1. State the problem and whether it affects date meaning, UI, storage, sync, or
   installation. Avoid combining unrelated runtime and presentation changes.
2. Add regression coverage for the failure before or alongside the fix.
3. Update requirements/design and user-facing docs when behavior changes.
4. Run the portable gate. List any Qt/firmware/physical checks not performed.
5. Do not include generated binaries, stock resources, notebook content, private
   configuration, logs with identifiers, or device backups in the change.

## Reporting a bug

Include model, exact firmware, Dates branch/commit, date basis/layout, a small
reproduction using synthetic data, expected/actual behavior, and whether stock
writing still works. Describe other patches by name/version, not by attaching
their private installation archive.

Redact notebook/page UUIDs, titles, handwritten content, tokens, personal server
addresses, SSH identifiers, and account paths. Do not attach real `.content`,
`.rm`, Dates indexes, `sync.json`, or raw journals.

Security-sensitive findings belong in the private reporting process described
in [SECURITY.md](SECURITY.md), not a public issue.

## Licensing and credits

An open-source license is pending owner choice; this preparation does not
grant one. See [THIRD_PARTY.md](THIRD_PARTY.md) for dependencies, runtime assets,
and vendored recovery-file provenance. Do not assume a future Dates license
also licenses extracted reMarkable firmware or other projects.
