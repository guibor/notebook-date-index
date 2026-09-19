# Public-sharing checklist

Status: **preparation, not a public release**. Checked 2026-09-20.
The existing GitHub repository is private. No visibility change, history rewrite,
public release, Reddit submission, or moderator message was made by this task.

## Completed preparation

- [x] User-facing README: feature tour, screenshots, date semantics, opt-in,
  timezone, privacy, compatibility and explicit installation limits.
- [x] Dedicated installation/recovery and owner-neutral self-hosting guides.
- [x] Portable source-test entry point, tested in clean exports without the
  maintainer's sibling repositories or private firmware caches.
- [x] Contributing/security guidance and dependency/vendored-file provenance.
- [x] Draft Reddit post and moderator-permission message, not submitted.
- [x] Targeted review of all 22 pre-preparation reachable commits (225 blobs,
  301 objects, including 10 historical synthetic screenshot PNGs).
  No candidate raw credentials, private notebook files or stock firmware
  resource dumps were found. This is a scoped audit, not a universal guarantee.

## Decisions before public access

- [ ] Owner chooses a license for original Dates code and reviews vendored scope.
- [ ] Owner authorizes the publication destination and visibility change.
- [ ] Resolve historical personal infrastructure/author metadata exposure.
- [ ] Verify the final public URL as a signed-out reader.
- [ ] Configure/verify private security reporting before claiming it is available.

The operational history includes personal server topology/account paths, device
identity pins, LAN addresses and Git author metadata. These are not raw secrets,
but changing only today's README does not remove them from earlier commits.

**Recommended publication route:** preserve this private operations/recovery
repository and prepare a separate clean public source repository from reviewed
files. Exclude owner deployment evidence, exact-device profiles, private
runbooks and historical metadata. Include the selected license, public docs,
source, tests and synthetic screenshots. Adapt the portable tests if private
recovery fixtures are omitted; do not silently weaken the private device guards.
Creating that repository and choosing its name need owner approval.

Alternative: publish this existing history only after the owner explicitly
accepts those disclosures. Do not rewrite accepted device-release history or
remove live safety pins just to make a repository look generic.

## Separate community-installation gate

A good README does not manufacture a safe installer. This remains an advanced
exact-firmware source project until the following work is independently done:

- [ ] Configurable, non-personal firmware-resource/tool discovery.
- [ ] Build/release packaging with per-model manifests and checksums.
- [ ] Reviewed first-install path that does not depend on the owner's other apps,
  or a clear supported dependency contract (including Pro BetterTOC integration).
- [ ] Independent rollback/recovery validated on an additional qualified setup.
- [ ] Cold-start/reboot/update/removal instructions actually exercised.
- [ ] Physical creation/navigation and two-device/offline acceptance recorded.
- [ ] Public release/tag only after its stated gates pass.

Do not call current `ops/` transactions a general installer, replace personal
pins with wildcards, add an unreviewed boot service, or run them on a reader's
tablet. The working maintainer installations should remain unchanged while
community distribution is developed.

## Reddit

r/Remarkable's visible rules prohibit self-promotion, including promoting one's
own project. Ask moderators whether a free, non-commercial technical write-up
is permitted; do not disguise authorship. The drafted message and post are in
[REDDIT-DRAFT.md](REDDIT-DRAFT.md). Recheck rules immediately before posting.
