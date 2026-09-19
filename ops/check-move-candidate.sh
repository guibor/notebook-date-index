#!/bin/bash
# Offline preparation only. This neither qualifies a live Move nor installs it.
set -euo pipefail
cd "$(dirname "$0")/.."
export DEVELOPER_DIR=/Library/Developer/CommandLineTools
move=../.worktrees/remarkable-beta-os-move-3280169
fw=$move/.cache/firmware/move/3.28.0.169
qmds=$move/.cache/composition/move-3.28.0.169/qmds
tool=../remarkable-beta-os/.cache/tools/qmldiff-25681c3-bin
hash_is() { test "$(shasum -a 256 "$2" | awk '{print $1}')" = "$1"; }
hash_is 6361610111c381ce730a8bfcc889bd933ef5fef173563a9156e435233714e7ee "$fw/xochitl.stock"
hash_is 463e5544ba9be0cd6914f87f37e24e8c5f7db847ac7a847e603a43b59ab1fd88 "$fw/hashtab-captures/hashtab.1"
hash_is 1a946da17a2e69af24343f97875caf3db2551270fe446ef967d2dca61f878806 "$fw/resource-SHA256SUMS"
hash_is 5d48704b2b55702bf553f65e0fac46bc2eacd72d3d995ac52b379df7e0ce973d "$tool"
(cd "$fw/resources" && shasum -a 256 -c ../resource-SHA256SUMS)
manifest=$(cd "$move/profiles" && pwd)/move-3.28.0.169-qmd-sha256.txt
(cd "$qmds" && shasum -a 256 -c "$manifest")
test "$(find "$qmds" -name '*.qmd' | wc -l | tr -d ' ')" = 9
mkdir -p build/move-candidate
# Read the current source hooks, then hash them against Move's own resource table.
NDI_TARGET=move node build-qmd.mjs
cp build/notebook-date-index.source.qmd build/move-candidate/notebook-date-index.qmd
candidate=build/move-candidate/notebook-date-index.qmd
"$tool" hash-diffs "$fw/hashtab-captures/hashtab.1" "$candidate"
"$tool" check-compatibility "$fw/hashtab-captures/hashtab.1" "$candidate"
"$tool" apply-diffs --clean --hashtab "$fw/hashtab-captures/hashtab.1" --version 3.28.0.169 "$fw/resources" build/move-candidate/composed "$qmds/"*.qmd "$candidate"
while IFS= read -r file; do qmlformat "$file" >/dev/null; done < <(find build/move-candidate/composed -name '*.qml')
shasum -a 256 "$candidate"
echo 'Move historical .169 fixture composition PASSED; live identity/runtime qualification and installation are still required'
