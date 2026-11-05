#!/usr/bin/env bash
# Exact-resource gate only. No device or deployed service access.
set -euo pipefail
cd "$(dirname "$0")/.."
: "${FIRMWARE_ROOT:?Exact extracted 3.30.0.108 root required}"
: "${BETTERTOC_QMD:?Qualified 3.30 BetterTOC QMD required}"
: "${QMLDIFF:?QMLDiff executable required}"
test "$(shasum -a 256 "$FIRMWARE_ROOT/xochitl" | awk '{print $1}')" = 31d33b05e85af85b06a5a92edf710532a0a122ed4cf51e702c19eed0feb6753b
test "$(shasum -a 256 "$FIRMWARE_ROOT/hashtab" | awk '{print $1}')" = d13c4ce53669d4b72fb26fdc94678d400fd395224476e7f6a69b805fce3d0c25
test "$(shasum -a 256 "$BETTERTOC_QMD" | awk '{print $1}')" = e260c2d918f8e1220f35d7cc7a999ffdb7a30e2d23bf8321e2b92749d279c5c5
export NDI_RESOURCES="$FIRMWARE_ROOT/resources"
node build-qmd.mjs
node --test qml-test.mjs date-tree-test.mjs move-policy-test.mjs
for variant in notebook-date-index notebook-date-index-preview; do
  cp "build/$variant.source.qmd" "build/$variant.qmd"
  "$QMLDIFF" hash-diffs "$FIRMWARE_ROOT/hashtab" "build/$variant.qmd"
  test "$("$QMLDIFF" check-compatibility "$FIRMWARE_ROOT/hashtab" "build/$variant.qmd")" = 'No compatibility errors found.'
  "$QMLDIFF" apply-diffs --clean --hashtab "$FIRMWARE_ROOT/hashtab" --version 3.30.0.108 "$NDI_RESOURCES" "build/$variant-composed" "$BETTERTOC_QMD" "build/$variant.qmd"
  while IFS= read -r f; do qmlformat "$f" >/dev/null; done < <(find "build/$variant-composed" -name '*.qml')
  "$QMLDIFF" apply-diffs --clean --hashtab "$FIRMWARE_ROOT/hashtab" --version 3.29.1.0 "$NDI_RESOURCES" "build/$variant-wrong-version" "build/$variant.qmd"
  test "$(find "build/$variant-wrong-version" -type f | wc -l | tr -d ' ')" = 0
done
node creation-runtime-test.mjs
export QT_QUICK_CONTROLS_STYLE=Basic QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software
qml --disable-context-sharing build/creation-runtime.qml >build/creation-runtime.log 2>&1
grep -q 'Creation runtime PASSED' build/creation-runtime.log
for harness in ui flash; do
  node "$harness-harness.mjs"
  qml --disable-context-sharing "build/$harness-harness.qml" >"build/$harness-harness.log" 2>&1
  grep -q 'runtime PASSED' "build/$harness-harness.log"
  if grep -Eq 'ReferenceError|TypeError|Cannot assign|is not a type|Error:' "build/$harness-harness.log"; then
    cat "build/$harness-harness.log"; exit 1
  fi
done
echo 'PASS: Dates 3.30 exact composition, creation, calendar, UI and flash gates'
