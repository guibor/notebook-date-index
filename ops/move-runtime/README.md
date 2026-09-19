# Pinned Move recovery runtime

These three files are byte-identical vendored copies from
`remarkable-beta-os`, branch `beta/move/3.28.0.169`, the qualified August 15
runtime. Dates does not change systemd shadow contents, recovery ordering,
watchdog policy, or activation/stock-process checks.

| File | SHA-256 |
| --- | --- |
| xovi-session-safe.sh | c5f75ed51175e843704f774e5d37ea78963738ce6fe457d913aa07285438f172 |
| xovi-session-watchdog.sh | 6d510f3a90b8af418bd90683726b1e4a8275cd1097aba2a3f4e1a4d2c3dd5300 |
| xovi-session-dropins.sh | 90a04ab72b8ea93349393fc3150cc0ddd43cd2405d8eb73e26128c8cf93a3ff1 |

`../move-profile-lib.sh` retains every original parser check but requires ten
QMDs rather than nine. The separate Dates profile pins the complete ten-QMD
manifest and re-composed resource hash. The legacy `EXPECTED_NINE_*` field names
remain to preserve the original controller interface; output still has 26 files.
The original nine-QMD profile/parser and old session remain historical preimages,
not silently widened to accept arbitrary inventories.

`../run-move-session.sh` is the existing runner with repository paths rebound
to these copies and explicit key-only SSH. A fresh same-boot stock canary must
precede activation. All runtime shadows are volatile `/run` files. Do not use
this guard or its profile on a Pro or another firmware build.
