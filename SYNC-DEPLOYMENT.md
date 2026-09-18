# Dates metadata sync: server deployment and tablet rollout

## Current state (2026-09-18)

The user explicitly authorized md-server as the private metadata sync point.
The hub is deployed and live HTTPS synthetic tests pass. The optional tablet
client is implemented and regression-tested, **but is not installed or enabled
on either tablet**. The Pro continues running its accepted local-only writer;
the Move still needs its separate Dates app port. Do not report end-to-end
tablet synchronization as complete.

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
  tokens. No real notebook metadata has been uploaded during qualification.
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

Final server binary SHA-256:
`4628886cdbd5c604d348e596df295ccd96158a9a187507445d05f60c32a89eff`.
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
4. Update the panel's current local-only text and display per-notebook sync
   progress/errors before claiming the user-facing sync rollout complete.
5. Validate one shared disposable notebook physically: create on Pro then Move,
   offline on both, reconnect/retry, and check the same dates without duplicates.
   Check delayed page content, reorder, delete/undo, copied notebook isolation,
   pause/resume and original dates across timezone changes.
6. Keep enabling/pausing new recording local to each device for this version;
   receiving history must not enable recording silently. Default Israel time
   remains configurable per device and old entries keep their recorded day/zone.

The client uses an append-only event journal alongside the unchanged schema-1
index, synchronizes watched/indexed notebooks once per minute, and keeps network
I/O outside the writer lock. Requests require verified HTTPS and never follow
redirects. Reopening Dates refreshes its local view. Conflict resolution chooses
earliest recorded UTC with a deterministic tie-break while retaining all source
observations; it cannot know which device clock was truly correct.

Twenty-one Go tests (race detector), static analysis, six JS event tests, real
Qt transport/popup tests, firmware composition/syntax and wrong-version gates
passed during implementation. These are not substitutes for the two-tablet
physical test above.
