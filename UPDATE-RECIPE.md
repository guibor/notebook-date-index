# Paper Pro Move notebook Dates update recipe

Exact branch: `beta/move/3.28.0.169`, model `reMarkable Chiappa`.
Read the Move firmware-maintenance knowledge base and dated log first.
Never use the Pro ReMagic wrapper, Pro profile or a copied Gestik configuration.

## Revision 5 installed on 2026-09-19

Dates is in **notebook ⋮ → Dates**, with the same compact layout action,
Created/Modified modes, calendar and settings as Pro. There is no Move sidebar
button. Recording defaults off per notebook; receiving shared history does not
enable it. Asia/Jerusalem is the default and remains configurable in Dates settings.

The host key, model, serial hash, firmware 3.28.0.169/build 20260806095513,
stock executable, XOVI, QRR, resource table and all nine prior QMDs were
independently verified. The current address was 10.100.102.96; rediscover it
rather than assuming the address or an old SSH alias is permanent.

Transaction: `dates-move-20260919-r5`.
Recovery directory: `/home/root/.codex-backups/dates-move-20260919-r5`.
Private Mac copy: `../notebook-date-index/.cache/dates-move-20260919-r5`.

| Artifact | SHA-256 |
| --- | --- |
| Complete preimage archive | `818f49cab9140dbd6406e4204bda35e68081eae9b565903983ce02b3820b2370` |
| Reviewed installation manifest | `4a64e20979906cd3cd7dbc3b3751030a9ea328b83b842fcff4d92532c64b9d9a` |
| Writer | `445f532f18a7bf26d429aff0a481ab02ea3b74bef9b73f956f9b5ad77a09f979` |
| Panel | `6ced2cd45df7513b0572b76a5f955cbdbc9d51ea4810a232511d5c362332944a` |
| DateTree | `a91dbdc403f9959490d879a1d52fb5bd2b683d020db2753b55127d678a0b09ce` |
| Move Dates QMD | `f6cba3190f3f690c2729539f0ecc3b629dd0d18366dc22fc5a89174df73731e0` |
| Ten-QMD manifest | `188b7121d18e3c10913071ffa1d0abc3221039deeccc4d48e44d1815c7eea7a7` |
| Dates Move profile | `8353dceed76691313bfdda83dc679ca4488af0596daa3ff9dd76683fc84e7dac` |

The complete ten-QMD composition produced 26 syntax-checked resources;
the sorted file-content-hash stream is
`08cc1d7174884f57445aa2ef1f73a24dd97e78acf374dc037b368733ed83ceaa`.

## Guarded first-install sequence (historical, do not blindly replay)

1. Verify the device read-only, including its own live/protected Gestik files.
   Capture XOVI, Vellum state, both Gestik files and the running /run guard/canary
   preimages. Copy the archive to the Mac and require matching full SHA-256.
2. Build with `target.json` selecting Move; run shared Go/Qt/JS tests and
   `ops/check-move-candidate.sh` against the exact Chiappa resources/table.
   No firmware or Vellum package changes are required for this Dates install.
3. Stage only the reviewed Dates binary/panel/helper/QMD, original nine-QMD
   manifest, new ten-QMD manifest and the **existing Move-specific private**
   client config. Never print the token or use Pro's client credential.
4. `install-move-dates.sh prepare` records unchanged-device fingerprints.
   The old qualified Move session controller then deactivates to verified stock.
   The old UI PID 32379 became stable stock PID 627531, zero unexpected restarts.
5. `qualify-move-stock.mjs` archives the old dummy-service proof and reruns
   the pinned experiment for the freshly captured stock PID/start. Only those
   two literals differ from the qualified source. It never signals xochitl.
6. `install-move-dates.sh publish` arms an independent ten-minute rollback,
   creates private Dates-only directories, starts the loopback writer as a
   transient bounded service and adds only the tenth QMD. All nine old QMDs,
   firmware, package state and Gestik remain byte-identical.
7. `ops/run-move-session.sh root@VERIFIED_IP activate` uploads the new exact
   inventory profile with the byte-identical qualified Move controller,
   watchdog and systemd-shadow helper. Only the parser's QMD count is ten
   rather than nine. It must observe the independent watchdog before restarting.
8. `install-move-dates.sh verify` checks payloads, inventory, logs and preserved
   state, then commits the transaction and cancels the temporary outer timer.
   The long-running Move watchdog deliberately stays active.

The accepted runtime was UI PID **629588**, writer PID **629024**, both active
with `NRestarts=0`, read-only root, exact XOVI/QRR mappings and no AppLoad.
Both Move Gestik files remained
`826211118322c6a84d899a9cf2f11e3e24d5223ac11ee96efaf47e45a47f5938`.
No settings were copied from Pro.

## Inspect or safely return to stock

Use this Dates branch's session runner, not the old nine-QMD firmware runner:

```sh
bash ops/run-move-session.sh root@VERIFIED_IP status
bash ops/run-move-session.sh root@VERIFIED_IP deactivate
```

Deactivation requests the qualified watchdog's stock recovery; it does not erase
Dates history. If the Mac runner is unavailable while the guard is healthy,
request that same recovery by creating
`/run/remarkable-beta-os-xovi-session/deactivate.request`. Never kill the watchdog
or substitute the Pro stock/start helpers. A reported recovery failure is a hard
stop: preserve its evidence and diagnose it, without reboot/remount shortcuts.

The first-install controller intentionally refuses existing Dates directories.
A subsequent upgrade needs the new exact preimage, with backup/rollback
preserving **all** token, settings, sync.json, notebook indexes and sync-events.
The app service and /run session are transient, not firmware-survival machinery.
Do not restart an old schema-1 writer over the current schema-2 history.

## Actual synchronization evidence and remaining acceptance

`ops/verify-pair.mjs` checked a real shared notebook containing 356 current
matching page IDs. All three Pro creation observations and canonical records
arrived on Move with exact timestamps/provenance. Move reported **Up to date**;
Pro tracking stayed on, Move tracking stayed off, and both native .content files
were unchanged. The independent native-metadata probe found 282 modified pages
in 113 days on each tablet, with the Israel timezone.

This proves actual device-to-hub-to-device delivery. It does **not** claim that
a physical newly created Move page, reverse-direction pen flow or offline merge
was exercised. For that check, enable tracking in the same test notebook on both
tablets, add a page on Move, allow normal notebook sync, and reopen Dates on Pro.
Repeat in reverse. UI/pen acceptance must be confirmed by the user.
