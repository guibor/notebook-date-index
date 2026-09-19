# Privacy, security and reporting

Notebook Dates modifies an unofficial tablet UI integration. It is not
supported by reMarkable and does not promise a risk-free installation.

## Data boundaries

- The tablet API binds to `127.0.0.1:18742` and requires its private local token.
- Native notebook metadata is read for Modified view; Dates stores its own
  separate indexes and does not write native notebook, TOC, or PDF files.
- Optional sync sends creation-history metadata to the endpoint you configure.
  It does not send handwriting, titles, document text, or PDF content.
- Notebook/page identifiers and date history are still private information.
  Protect them even though they are not document contents.
- Device credentials share one trusted owner's hub namespace. This is not
  tenant isolation for strangers. The reserved probe credential is separate.

Offline and sync failures must not block native page creation. A regression
that does is a release blocker; return to stock through the qualified recovery
path rather than continue testing on important notebooks.

## What not to publish

Never post local tokens, `sync.json`, generated client credentials,
`devices.json`, real Dates indexes/journals, native notebook files, device
backups, or unredacted operational logs. Do not add extracted firmware resources
or stock binaries to this repository.

Public issue reports should use synthetic notebook/page IDs and test content.
Screenshots in this repo are synthetic UI examples, not real notes.

## Reporting a sensitive issue

If private vulnerability reporting is available on the repository's Security
tab, use it. **Its availability has not yet been verified/enabled for a public
release.** Otherwise, ask the maintainer for a private reporting channel without
posting the exploit or private data. No dedicated security mailbox or response
SLA is promised.

Do not open a public issue containing secrets simply because a private channel
is unavailable. For ordinary bugs, use [the contribution checklist](CONTRIBUTING.md).

## Version and deployment policy

Only the exact model/firmware combinations in [compatibility.json](compatibility.json)
have deployment evidence. There is no security-support guarantee for other
builds. A source-test pass is not a device/recovery qualification.

Keep payload/runtime guards, independent rollback, private backups and each
tablet's own settings intact. Never remove identity or hash checks to make a
community install proceed. See [INSTALL.md](docs/INSTALL.md) for boundaries.
