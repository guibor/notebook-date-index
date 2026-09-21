# Pro 3.29.0.148 candidate

Status: local source/QMD port only, not installed. Firmware SHA-256:
`4f433281c71a29d07921665b4724420735f3c88aceb431067f3a432b3f89f6a4`.
The current maintenance owner must seal the runtime-derived table and qualify
the new recovery wrapper before activation. Move remains separate and unchanged.

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
No test uses real notebooks or device credentials. These are offline results,
not live deployment or physical pen/navigation acceptance.
