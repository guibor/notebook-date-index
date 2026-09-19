# Credits, dependencies and source provenance

Notebook Dates builds on the reMarkable community's extension tooling:

- [XOVI](https://github.com/asivery/xovi), by asivery: extension framework.
- [QMLDiff](https://github.com/asivery/qmldiff), by asivery: QML patch tooling.
- [rm-xovi-extensions](https://github.com/asivery/rm-xovi-extensions):
  the Qt resource rebuilder used by the qualified runtime.
- [Qt](https://www.qt.io/): the QML/Qt Quick runtime and desktop validation tools.
- [Go](https://go.dev/): the backend, embedded timezone data and test tooling.
- [Node.js](https://nodejs.org/): source generation and JavaScript tests.

These projects retain their own licenses. They are not relicensed by Dates.
The Go module currently has no third-party module dependencies.
The current Pro sidebar hook also depends on the independently qualified
BetterTOC toolbar integration; it is not a standalone stock-toolbar patch.

## Vendored Move recovery files

The three shell files under `ops/move-runtime/` are unchanged copies from the
owner's `remarkable-beta-os` repository, commit
`43520445f98e5bbd20d3e8d3576e7bc0d27d94d8`. Their SHA-256 values are recorded in
[the recovery README](ops/move-runtime/README.md) and enforced by source tests.

They were copied to retain an exact qualified recovery implementation, not to
make that implementation portable. Licensing these copies is part of the
owner's pending publication/license review. Their checksums and guards must
not be changed as documentation cleanup.

## Stock runtime and images

reMarkable firmware resources, runtime modules and stock icons are not original
Dates assets. They are referenced by the integration or loaded from an owner's
private resource extraction for tests; complete stock resources/binaries are
not distributed here.

The checked-in screenshots depict synthetic Dates data. Some runtime controls
may render stock iconography; no license to reMarkable assets or trademarks is
granted. The project is unofficial and is not endorsed by reMarkable.

## Dates license status

No project license has been selected yet. Do not describe the current repository
as open source or infer a reuse grant from its visibility. Add the owner's
chosen license and confirm the vendored-file scope before public release.
