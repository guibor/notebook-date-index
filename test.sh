#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
export DEVELOPER_DIR=/Library/Developer/CommandLineTools
export GOTOOLCHAIN=go1.24.6
base=../remarkable-beta-os/.cache
qmldiff=$base/tools/qmldiff-25681c3-bin
fw=$base/firmware/3.28.0.169
test "$(shasum -a 256 "$fw/hashtab" | awk '{print $1}')" = ecb0cfbd6828c374e48139064436a12f2c04778a90192b9dd85887edbdbe256a
test "$(shasum -a 256 "$qmldiff" | awk '{print $1}')" = 5d48704b2b55702bf553f65e0fac46bc2eacd72d3d995ac52b379df7e0ce973d
(cd build/co-resident && shasum -a 256 -c ../../profiles/co-resident.sha256)
test "$(find build/co-resident -name '*.qmd' | wc -l | tr -d ' ')" = 8
go test -race -count=1 -v ./...
go vet ./...
CGO_ENABLED=0 go build -buildvcs=false -o build/notebook-date-index-host .
node transport-test.mjs
node --test qml-test.mjs date-tree-test.mjs
node ui-harness.mjs
QT_QUICK_CONTROLS_STYLE=Basic QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software qml --disable-context-sharing build/ui-harness.qml >build/ui-harness.log 2>&1
grep -q 'Dates UI runtime PASSED' build/ui-harness.log
if grep -Eq 'ReferenceError|TypeError|Cannot assign|is not a type|Error:' build/ui-harness.log; then cat build/ui-harness.log; exit 1; fi
for script in ops/*.sh; do bash -n "$script"; done
node build-qmd.mjs
qmlformat build/DatesPanel.qml >/dev/null
qmlformat build/DatesPanel-preview.qml >/dev/null
for variant in notebook-date-index notebook-date-index-preview; do
  cp "build/$variant.source.qmd" "build/$variant.qmd"
  "$qmldiff" hash-diffs "$fw/hashtab" "build/$variant.qmd"
  "$qmldiff" check-compatibility "$fw/hashtab" "build/$variant.qmd"
  "$qmldiff" apply-diffs --clean --hashtab "$fw/hashtab" --version 3.28.0.169 "$fw/resources" "build/$variant-composed" build/co-resident/*.qmd "build/$variant.qmd"
  while IFS= read -r f; do qmlformat "$f" >/dev/null; done < <(find "build/$variant-composed" -name '*.qml')
  "$qmldiff" apply-diffs --clean --hashtab "$fw/hashtab" --version 3.28.0.166 "$fw/resources" "build/$variant-wrong-version" "build/$variant.qmd"
  test "$(find "build/$variant-wrong-version" -type f | wc -l | tr -d ' ')" = 0
  grep -q 'requestTableOfContents(true)' "build/$variant-composed/qml/device/view/documentview/DocumentView.qml"
done
node creation-runtime-test.mjs
QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software qml --disable-context-sharing build/creation-runtime.qml >build/creation-runtime.log 2>&1
grep -q 'Creation runtime PASSED' build/creation-runtime.log
if grep -Eq 'ReferenceError|TypeError|Cannot assign|is not a type|Error:' build/creation-runtime.log; then cat build/creation-runtime.log; exit 1; fi
CGO_ENABLED=0 GOOS=linux GOARCH=arm64 go build -buildvcs=false -trimpath -ldflags='-s -w -buildid=' -o build/notebook-date-index .
shasum -a 256 build/notebook-date-index build/*.qmd
echo 'notebook-date-index offline gates PASSED'
