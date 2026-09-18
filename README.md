# Notebook Dates — Paper Pro beta

Separate, opt-in date navigation for notebooks. It does **not** modify normal
TOC entries, PDF outlines, native tags, or notebook files. RMStream remains a
separate app in `../remarkable-beta-os/playbook/RMSTREAM.md`.

On a qualified functional build, open a notebook → toolbar **More tools (+)**
→ **Dates** → **Enable for this notebook**. Only newly created pages are dated.
Tap a date to jump to its first surviving page; tap **+** to expand the day's
pages. Pause tracking using the same panel. Dates remain available while paused.

Local data: `/home/root/.local/share/notebook-date-index/`. Back it up separately;
v1 does not sync to cloud or another device. Existing pages and imported/moved-in
pages stay undated. Dates use the tablet's local clock at successful creation;
check its date/time if the date differs from your expectation.

Exact target: Ferrari / `3.28.0.169`. Move is **not** qualified by this branch.
No boot persistence is added; the loopback writer must be restarted with the
qualified XOVI stack after reboot. Firmware updates need a fresh port.

## Development

`./test.sh` runs Go tests, JS event tests, exact-resource QMLDiff composition,
generated-QML syntax checks, wrong-version rejection, and static ARM64 build.
It expects the sibling firmware cache and `build/co-resident/` containing the
eight hash-verified currently installed Pro QMDs. No device writes occur.

The first on-device trial uses the `preview` QMD: Dates UI works but the enable
button and recording are disabled. Confirm its layout and normal writing before
promoting the separately built functional QMD. Machine health is not physical
feature acceptance.
