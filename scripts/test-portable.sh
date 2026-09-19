#!/usr/bin/env bash
# Source-only checks. This script never installs or activates tablet payloads.
set -euo pipefail

usage() {
  printf '%s\n' \
    'Usage: bash scripts/test-portable.sh [--help]' \
    '' \
    'Requirements: installed Go 1.24+, Node.js 18+, Bash, and a C compiler for Go race tests.' \
    'Run from any directory; all source paths are relative to this repository.' \
    'Go toolchain/module downloads are disabled. Select an installed Go using PATH.' \
    '' \
    'Checks: Go race tests and vet; Node creation/calendar/recovery tests;' \
    'mocked rollback checks; shell syntax; static Linux ARM64 backend build.' \
    'Tests use synthetic files and local loopback TLS servers. No external network,' \
    'SSH, tablet, or deployed server access occurs.' \
    '' \
    'Output: build/portable/notebook-date-index (not an installable app bundle).' \
    'Excluded: Qt transport/UI tests, firmware resources, QMLDiff generation/' \
    'composition, physical tablet acceptance, and deployment/recovery qualification.' \
    'The existing maintainer test.sh and exact-device update recipes remain separate.'
}

case "${1:-}" in
  --help|-h) test "$#" -eq 1 || { usage >&2; exit 2; }; usage; exit 0 ;;
  '') test "$#" -eq 0 || { usage >&2; exit 2; } ;;
  *) usage >&2; exit 2 ;;
esac

cd "$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
for tool in go node bash; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    printf 'Missing dependency: %s. See --help.\n' "$tool" >&2
    exit 1
  fi
done

# Do not inherit automatic toolchain downloads or a surrounding Go workspace.
export GOTOOLCHAIN=local GOWORK=off GOPROXY=off GOSUMDB=off
export GONOPROXY=none GOVCS='*:off'
go_version=$(go env GOVERSION)
if [[ ! "$go_version" =~ ^go1\.([0-9]+) ]] || (( BASH_REMATCH[1] < 24 )); then
  printf 'Go 1.24+ must already be installed (found %s). Select it using PATH; this script does not download it.\n' "$go_version" >&2
  exit 1
fi
if ! node -e 'process.exit(Number(process.versions.node.split(".")[0]) >= 18 ? 0 : 1)'; then
  printf 'Node.js 18+ is required.\n' >&2
  exit 1
fi

mkdir -p build/portable
export GOCACHE="${GOCACHE:-$PWD/build/portable/go-cache}"
export GOOS="$(go env GOHOSTOS)" GOARCH="$(go env GOHOSTARCH)"
printf 'Source checks with %s and Node %s; no firmware cache required.\n' "$go_version" "$(node --version)"

CGO_ENABLED=1 go test -race -count=1 ./...
go vet ./...
node --test qml-test.mjs date-tree-test.mjs move-policy-test.mjs
node ops/move-polish-test.mjs
node ops/polish-rollback-test.mjs
for script in ops/*.sh scripts/*.sh; do bash -n "$script"; done
CGO_ENABLED=0 GOOS=linux GOARCH=arm64 go build -buildvcs=false -trimpath \
  -ldflags='-s -w -buildid=' -o build/portable/notebook-date-index .
printf '%s\n' 'Portable source checks PASSED. Tablet/firmware qualification was not performed.'
