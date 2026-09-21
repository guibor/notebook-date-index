# Pro 3.29.0.148 restoration receipt

Status: exact Pro runtime restored and committed, physical checks pending.
Firmware SHA-256:
`4f433281c71a29d07921665b4724420735f3c88aceb431067f3a432b3f89f6a4`.
The runtime-derived table, full stack and independent stock recovery were
qualified before acceptance. Move remains separate and unchanged.

The maintenance owner committed transaction `20260921T193500Z-3`. At 19:37:47 UTC
on 2026-09-21, xochitl PID 14472 and the unchanged r6 Dates writer PID 14463 were
active with zero automatic restarts, inactive transaction/watchdog units, no lock
and read-only root. All exact mappings/QMD/log checks passed; private configuration
and Gestik hashes were unchanged. The full eleven-QMD inventory is
`5fe7e2ec3291efa692c90df769ea521d9e399d3da6e7448f9a9071caca71652d`;
its safety archive was independently verified on the Mac at
`77df2b4108f7dc82276a3bf1ec516b09aa728a142f73e6a028744e3b4779966d`.
No history/schema migration, server change or Move deployment occurred.
At 19:39:06 UTC, the post-deadline check confirmed the same stable PIDs and zero
restarts, all eleven QMD hashes and five runtime libraries, with root read-only.
Physical creation/calendar/navigation and cross-device behavior were not tested
by this restore. Cross-notebook transfer remains unimplemented.

Run source tests with `bash scripts/test-portable.sh`. Build exact Pro QMD source
with `node build-qmd.mjs`. For full-stack composition use the sibling isolated
Smart worktree's `tests/pro-3.29-apps-test.mjs`, setting `RM_PRO_HASHTAB` to the
verified runtime table and `RM_PRO_PEERS` to the explicit seven-package QMD set.
An extracted-resource diagnostic table is structural evidence only.

Keep these accepted r6 payloads byte-identical:

- Writer: `445f532f18a7bf26d429aff0a481ab02ea3b74bef9b73f956f9b5ad77a09f979`
- DatesPanel: `5280822baf8891bfb3f091d4c598f03413cc78373b76761eebe2fc133517b23a`
- DateTree: `336c47e7f619734214467b9f30e5324b82deeccae4977106bf8c64310f1e87dd`

Back up and retain the entire `/home/root/.local/share/notebook-date-index/`,
including notebook indexes, `.previous` copies, settings, token, sync config and
sync-event journals. No firmware restore may overwrite these with defaults or
copy the other tablet's settings. The existing `UPDATE-RECIPE.md` and controllers
describe 3.28 deployments and must not be run against 3.29.

Cross-notebook page transfer is newly requested but intentionally separate.
The current backend keeps history per notebook: source links disappear when a
page is absent, but destination Created remains undated. Modified still projects
native metadata. Never present this QMD port as a page-transfer implementation.

Offline results on 2026-09-21: the independently captured raw table
`1f2a0f7177dac3cdfc030ff32b4643170dd2ef6e2f6c6369b4c4168513ce01f0` passes
the shared full-stack gate (three orders and preview, 29 resources each), all
generated QML parsing and firmware rejection. Source/race/vet, 23 Node checks,
recovery-policy tests, and real Qt UI/flash/creation/transport harnesses pass.
`ui-harness.mjs` and `flash-harness.mjs` resolve 3.29 icons with an overridable
`NDI_RESOURCES`; the creation harness accepts explicit composed-tree paths.
No offline test uses real notebooks or device credentials. Those tests alone do
not prove deployment; the separate live receipt above establishes runtime
restoration, not physical pen/navigation acceptance.
