# Dates metadata sync: server deployment and tablet rollout

## Current state (2026-09-19)

The user explicitly authorized md-server as the private metadata sync point.
The estimate-aware hub is deployed and live HTTPS tests pass. **The Pro sync
client is enabled**, and three real page-creation observations reached the hub
with their exact timestamps/provenance. A real HTTPS read using the Move's
credential returned those records. The Pro then reported **Up to date**.
The physical Move remains unreachable and still needs its separately guarded
Dates app port/configuration. Do not report two-tablet delivery as complete.

The v3 Created/Modified UI and metadata/backfill service were installed under
separate guarded payload/panel transactions; see `UPDATE-RECIPE.md` for current
hashes. The later Calendar/sync rollout upgraded the hub before enabling Pro.
The new credential
generator requires an explicit `--sync-endpoint`; it never changes existing
private credentials/configuration. For the initial-only host-qualified installer,
pass endpoint and existing health URL as arguments 3 and 4. Generic self-hosting
instructions/examples are in README; do not run the maintainer's pinned installer
on an arbitrary server.

Read-only checks matched both device host keys and models, exact firmware
3.28.0.169, and their different stock xochitl hashes. There were 1,331 shared
document UUIDs; two sampled notebooks had matching valid page UUIDs (8/8 and
15/15). A third notebook had not reached the other device, reinforcing why
absence must not be interpreted as deletion. Both tablets successfully
validated TLS and received the expected unauthenticated HTTP 401 from the hub.

## Server boundary

- HTTPS: `https://anki-mdf.duckdns.org/dates/v1/exchange`
- Backend bind: `127.0.0.1:18743` only; no new public/firewall port.
- User service: `notebook-date-sync.service`, running as `mdf`, enabled at boot.
- Binary: `/home/mdf/.local/lib/notebook-date-sync/notebook-date-index`
- Data: `/home/mdf/.local/share/notebook-date-sync/history/`
- Credentials: private sibling `credentials/`; separate Pro, Move, and probe
  secrets. The hub reads token hashes from `devices.json`; raw client credentials
  remain in mode-0600 files in the mode-0700 directory. Never print/commit them.
- Probe records live under `history/probe/`, inaccessible with real device
  tokens. Initial qualification used synthetic data only. The authorized Pro
  rollout now also uploads real creation-history metadata to the owner namespace.
- TLS routing: `/etc/nginx/snippets/dates-sync-location.conf`, included once
  in the existing TLS server in `/etc/nginx/sites-enabled/anki-mcp`.
  That active file is a regular file, NOT the similarly named sites-available
  file. Do not infer a symlink or overwrite a concurrent configuration change.
- Existing protected `/health` returns 401 without credentials; its status
  and nginx/Anki services were unchanged. OpenClaw was not restarted/modified.

The service is restricted by systemd to the history write path, private temp,
no new privileges, a private umask, memory/CPU bounds and automatic restart.
nginx access logging is disabled for the metadata endpoint. Payloads contain
only notebook/page UUIDs, creation date/time/zone and origin—not notebook titles,
handwriting or contents. Strict authentication, provenance, JSON and size gates
apply before a history mutation.

## Server installation / recovery

`ops/install-hub.sh` is initial-only. Stage its tested Linux-amd64 binary,
service, route snippet and scripts in a private unique `hub-*` directory under
`/home/mdf/.local/share/notebook-date-sync-staging/`. Retrieve the actual active
nginx file as `nginx.before`; create `nginx.after` using only the single include
addition inside its TLS server. Bind all stage files in `SHA256SUMS`, verify
its hash and invoke the controller under a bounded transient user systemd unit.

The controller requires matching live preimages, absent destinations, existing
service health and a free loopback port. It arms an independent rollback timer
before mutations, tests nginx before reload, and verifies HTTPS/authentication
plus existing health afterward. The rollback restores only an exact matching
candidate nginx file, disables the new hub, and retains data/evidence.

`ops/upgrade-hub.sh` upgrades an existing hub binary only: supply exact old and
candidate SHA-256 values, retain the prior binary/history archive, arm its
independent rollback timer, then swap/restart and run the HTTPS smoke test.
It does not alter nginx or credentials. Rollback refuses unexpected binary
drift and restores only the known prior binary; never rewinds recorded history.

`ops/smoke-hub.mjs`, run on md-server, reads private credentials without printing
them and checks real HTTPS authentication, forged-origin rejection, repeated
durable writes/reads, and probe/production isolation using synthetic IDs only.

Retained transactions:

- `hub-20260918-initial`: preflight refused the false symlink assumption;
  no mutation/rollback timer was reached.
- `hub-20260918-active-config`: successful initial deployment and smoke checks.
- `hub-20260918-journal-guard`: binary-only upgrade adding fail-closed handling
  of a missing primary when a journal backup exists.
- `hub-estimates-20260919T095749Z`: estimate-aware binary-only upgrade,
  independent rollback, authenticated HTTPS estimate/retry/isolation test.
  Server PID 2088822, zero restarts; rollback timer inactive.
- `dates-sync-pro-20260919T095839Z`: guarded Pro service-only client enablement,
  writer PID 307144, preserved UI PID 306456, zero restarts and read-only root.

Final server binary SHA-256:
`608c98281c8dc49074318abc1376c9fdc384a42791ebb316e27609e2b14db75e`.
Route snippet SHA-256:
`dc0ad5f8cde5ace027d320ae1b75f3392a532e13b988a1e6d8e873d5f84ff640`.
The active nginx preimage and initial staging manifest are preserved privately
in local `.cache/hub-deploy/` as well as the server transaction directory.

## Remaining tablet rollout gates

1. Qualify each exact target against its own recipe. Pro currently has ten
   QMDs/four extensions. Move has a different QRR/extension stack and must not
   receive the Pro installer or AppLoad assumptions.
2. Back up each entire Dates directory independently, including `sync-events/`
   after rollout. Keep tokens, journals and device backup archives out of Git.
3. Transfer only that device's private `*-client.json` as its mode-0600
   `/home/root/.local/share/notebook-date-index/sync.json`. Do not activate it
   before the appropriate writer/panel/Move-port qualification is complete.
4. The settings page now shows status for its own notebook. Pro's worker wakes
   promptly after local changes/newly viewed notebooks, retries every minute,
   and does not claim a concurrent new creation has already synced. Reopen Dates
   to refresh the visible status. Hub/Pro upgrade passed; physical offline/reconnect
   and Move acceptance remain before calling the two-tablet rollout complete.
5. Validate one shared disposable notebook physically: create on Pro then Move,
   offline on both, reconnect/retry, and check the same dates without duplicates.
   Check delayed page content, reorder, delete/undo, copied notebook isolation,
   pause/resume and original dates across timezone changes.
6. Keep enabling/pausing new recording local to each device for this version;
   receiving history must not enable recording silently. Default Israel time
   remains configurable per device and old entries keep their recorded day/zone.

The client uses an append-only event journal alongside the schema-2
index, synchronizes watched/indexed notebooks on queued changes and once per minute, and keeps network
I/O outside the writer lock. Requests require verified HTTPS and never follow
redirects. Reopening Dates refreshes its local view. Conflict resolution chooses
observed creation over estimates, then earliest UTC with a deterministic tie-break while retaining all source
observations; it cannot know which device clock was truly correct.

Thirty Go tests (race detector), static analysis, sixteen JS tests, real
Qt transport/popup/creation tests, firmware composition/syntax and wrong-version
gates passed. A real Pro notebook's native file remained byte-identical during
the read-only integration probe. These are not substitutes for the physical
two-tablet test above. `ops/verify-pro-sync.mjs` explicitly reports
`physicalMoveVerified:false` even when the Move credential can read hub history.
