#!/bin/bash
# Activate/deactivate one guarded, reboot-volatile XOVI session on the Move.
set -Eeuo pipefail
umask 077

MODE=${1:-}
PROFILE=${PROFILE:-}
PROFILE_LIB=${PROFILE_LIB:-}
DROPIN_LIB=${DROPIN_LIB:-}
WATCHDOG_SCRIPT=${WATCHDOG_SCRIPT:-}
QMD_MANIFEST=${QMD_MANIFEST:-}
RUNTIME_ROOT=/run/remarkable-beta-os-xovi-session
CONTROL_ROOT=/run/systemd/system.control
SHADOW_UNIT="$CONTROL_ROOT/xochitl.service"
SHADOW_DROPIN_DIR="$CONTROL_ROOT/xochitl.service.d"
SHADOW_DROPIN="$SHADOW_DROPIN_DIR/xochitl-service-override.conf"
STAGE_DIR="$RUNTIME_ROOT/systemd-shadow-stage"
RETIRED_DIR="$RUNTIME_ROOT/retired-systemd-shadow"
RETIRED_UNIT="$RETIRED_DIR/xochitl.service"
RETIRED_DROPIN="$RETIRED_DIR/xochitl-service-override.conf"
VENDOR_UNIT=/usr/lib/systemd/system/xochitl.service
VENDOR_DROPIN=/usr/lib/systemd/system/xochitl.service.d/xochitl-service-override.conf
OLD_RUNTIME_UNIT=/run/systemd/system/xochitl.service
OLD_RUNTIME_DROPIN_DIR=/run/systemd/system/xochitl.service.d
OLD_RUNTIME_DROPIN="$OLD_RUNTIME_DROPIN_DIR/zz-remarkable-beta-os-xovi-session.conf"
OLD_RUNTIME_DROPIN_99="$OLD_RUNTIME_DROPIN_DIR/99-remarkable-beta-os-xovi-session.conf"
CANARY_EVIDENCE=/run/remarkable-beta-os-systemd-shadow-canary
CANARY_SUCCESS="$CANARY_EVIDENCE/canary.passed"
EXPECTED_CANARY_BASE_UNIT_SHA256=29b8433458e94d199eb1a6244015dc968a9aa5f9dbfce0e27f3315527bf86901
EXPECTED_CANARY_BASE_DROPIN_SHA256=f1a7f632dd36401a795ca86a11579fa38100396c68bc40a5fb75f1d835806b1b
EXPECTED_CANARY_SHADOW_UNIT_SHA256=2ac7d10983724dfc7d06e8cdca5edb5805c3f36c46b7cecadc2e4af302745b8f
EXPECTED_CANARY_SHADOW_DROPIN_SHA256=68193778340971b3a9183cd0b0e81e623654d7ef6693c20f64c91f9c7505e87f
WATCHDOG_UNIT=remarkable-beta-os-xovi-session-watchdog
WATCHDOG_READY="$RUNTIME_ROOT/watchdog.ready"
ACTIVATE_REQUEST="$RUNTIME_ROOT/activate.request"
SESSION_READY="$RUNTIME_ROOT/session.ready"
DEACTIVATE_REQUEST="$RUNTIME_ROOT/deactivate.request"
RECOVERY_DONE="$RUNTIME_ROOT/recovery.done"
RECOVERY_FAILED="$RUNTIME_ROOT/recovery.failed"
DEADLINE="$RUNTIME_ROOT/activation.deadline-monotonic"
xovi=/home/root/xovi
qrr_so="$xovi/extensions.d/qt-resource-rebuilder.so"
qrr_dir="$xovi/exthome/qt-resource-rebuilder"
hashtab="$qrr_dir/hashtab"
complete=0
watchdog_armed=0
mutation_started=0

for input in "$PROFILE" "$PROFILE_LIB" "$DROPIN_LIB" "$WATCHDOG_SCRIPT" \
    "$QMD_MANIFEST"; do
    test -f "$input"
    test ! -L "$input"
done
# shellcheck source=profile-lib.sh
source "$PROFILE_LIB"
# shellcheck source=xovi-session-dropins.sh
source "$DROPIN_LIB"
load_exact_move_profile "$PROFILE"

root_is_read_only() {
    local options
    options=$(findmnt -n -o OPTIONS /) || return 1
    case ",$options," in *,ro,*) ;; *) return 1 ;; esac
    case ",$options," in *,rw,*) return 1 ;; esac
    return 0
}

one_xochitl_pid() {
    local expected=$1 output pid count=0
    output=$(pidof xochitl 2>/dev/null) || return 1
    for pid in $output; do
        test "$pid" = "$expected" || return 1
        count=$((count + 1))
    done
    test "$count" -eq 1 || return 1
    return 0
}

process_maps_exact_path() {
    local pid=$1 path=$2
    awk -v expected="$path" \
        '$NF == expected { found=1 } END { exit !found }' "/proc/$pid/maps" || \
        return 1
    return 0
}

grep_absent() {
    local rc
    if grep "$@"; then
        return 1
    else
        rc=$?
        test "$rc" -eq 1
    fi
}

command_output_equals() {
    local expected=$1 actual
    shift
    actual=$("$@") || return 1
    test "$actual" = "$expected" || return 1
    return 0
}

sha256_file_equals() {
    local expected=$1 path=$2 actual filename extra output
    test -f "$path" || return 1
    test ! -L "$path" || return 1
    output=$(sha256sum "$path") || return 1
    read -r actual filename extra <<<"$output" || return 1
    test "$filename" = "$path" || return 1
    test -z "${extra:-}" || return 1
    test "$actual" = "$expected" || return 1
    return 0
}

# BusyBox find on the Move lacks GNU find's filename-formatting action. Bash
# globbing gives us an exact top-level enumeration while still including dot
# files, FIFOs, directories, devices, and broken symlinks. Reject newline-bearing
# names so the newline-delimited comparison below cannot become ambiguous.
list_top_level_names() (
    local directory=$1 path name
    shopt -s dotglob nullglob
    for path in "$directory"/*; do
        name=${path##*/}
        case "$name" in
            ''|*$'\n'*) return 1 ;;
        esac
        printf '%s\n' "$name"
    done
)

process_start_time() {
    local pid=$1 value
    case "$pid" in ''|*[!0-9]*) return 1 ;; esac
    test -r "/proc/$pid/stat" || return 1
    value=$(awk '{print $22}' "/proc/$pid/stat") || return 1
    case "$value" in ''|*[!0-9]*) return 1 ;; esac
    printf '%s\n' "$value"
}

assert_vendor_files() {
    test -f "$VENDOR_UNIT" || return 1
    test ! -L "$VENDOR_UNIT" || return 1
    command_output_equals 0:0:644 stat -c %u:%g:%a "$VENDOR_UNIT" || \
        return 1
    sha256_file_equals "$EXPECTED_XOCHITL_VENDOR_UNIT_SHA256" \
        "$VENDOR_UNIT" || return 1
    test -f "$VENDOR_DROPIN" || return 1
    test ! -L "$VENDOR_DROPIN" || return 1
    command_output_equals 0:0:644 stat -c %u:%g:%a "$VENDOR_DROPIN" || \
        return 1
    sha256_file_equals "$EXPECTED_XOCHITL_VENDOR_DROPIN_SHA256" \
        "$VENDOR_DROPIN" || return 1
    return 0
}

assert_stock_onfailure_set() {
    local actual word count=0 found_emergency=0 found_remarkable=0
    actual=$(systemctl show xochitl -p OnFailure --value) || return 1
    for word in $actual; do
        count=$((count + 1))
        case "$word" in
            emergency.target)
                test "$found_emergency" -eq 0 || return 1
                found_emergency=1
                ;;
            remarkable-fail.service)
                test "$found_remarkable" -eq 0 || return 1
                found_remarkable=1
                ;;
            *) return 1 ;;
        esac
    done
    test "$count" -eq 2 || return 1
    test "$found_emergency" -eq 1 || return 1
    test "$found_remarkable" -eq 1 || return 1
    return 0
}

assert_unit_environment() {
    local expected=$1 environment word count=0 malloc=0 preload=0 root=0
    local disable_cache=0 xhr_write=0 xhr_read=0
    environment=$(systemctl show xochitl -p Environment --value) || return 1
    for word in $environment; do
        count=$((count + 1))
        case "$word" in
            MALLOC_ARENA_MAX=8) test "$malloc" -eq 0 || return 1; malloc=1 ;;
            LD_PRELOAD=/home/root/xovi/xovi.so)
                test "$preload" -eq 0 || return 1; preload=1 ;;
            XOVI_ROOT=/home/root/xovi/services/xochitl.service/)
                test "$root" -eq 0 || return 1; root=1 ;;
            QML_DISABLE_DISK_CACHE=1)
                test "$disable_cache" -eq 0 || return 1; disable_cache=1 ;;
            QML_XHR_ALLOW_FILE_WRITE=1)
                test "$xhr_write" -eq 0 || return 1; xhr_write=1 ;;
            QML_XHR_ALLOW_FILE_READ=1)
                test "$xhr_read" -eq 0 || return 1; xhr_read=1 ;;
            *) return 1 ;;
        esac
    done
    test "$malloc" -eq 1 || return 1
    case "$expected" in
        vendor|safety)
            test "$count:$preload:$root:$disable_cache:$xhr_write:$xhr_read" = \
                1:0:0:0:0:0 || return 1
            ;;
        combined)
            test "$count:$preload:$root:$disable_cache:$xhr_write:$xhr_read" = \
                6:1:1:1:1:1 || return 1
            ;;
        *) return 1 ;;
    esac
    return 0
}

assert_control_pair_files() {
    local expected_dropin_hash=$1 names
    test -d "$CONTROL_ROOT" || return 1
    test ! -L "$CONTROL_ROOT" || return 1
    command_output_equals 0:0:755 stat -c %u:%g:%a "$CONTROL_ROOT" || \
        return 1
    test -d "$SHADOW_DROPIN_DIR" || return 1
    test ! -L "$SHADOW_DROPIN_DIR" || return 1
    command_output_equals 0:0:755 stat -c %u:%g:%a \
        "$SHADOW_DROPIN_DIR" || return 1
    names=$(list_top_level_names "$SHADOW_DROPIN_DIR") || return 1
    test "$names" = xochitl-service-override.conf || return 1
    test -f "$SHADOW_UNIT" || return 1
    test ! -L "$SHADOW_UNIT" || return 1
    command_output_equals 0:0:600 stat -c %u:%g:%a "$SHADOW_UNIT" || \
        return 1
    sha256_file_equals "$EXPECTED_XOVI_SHADOW_UNIT_SHA256" \
        "$SHADOW_UNIT" || return 1
    test -f "$SHADOW_DROPIN" || return 1
    test ! -L "$SHADOW_DROPIN" || return 1
    command_output_equals 0:0:600 stat -c %u:%g:%a "$SHADOW_DROPIN" || \
        return 1
    sha256_file_equals "$expected_dropin_hash" "$SHADOW_DROPIN" || return 1
    return 0
}

assert_legacy_assets_absent() {
    local path
    for path in "$OLD_RUNTIME_UNIT" "$OLD_RUNTIME_DROPIN" \
        "$OLD_RUNTIME_DROPIN_99"; do
        test ! -e "$path" || return 1
        test ! -L "$path" || return 1
    done
    return 0
}

assert_control_assets_absent() {
    local path names
    for path in "$SHADOW_UNIT" "$SHADOW_DROPIN" "$STAGE_DIR"; do
        test ! -e "$path" || return 1
        test ! -L "$path" || return 1
    done
    if test -e "$CONTROL_ROOT" || test -L "$CONTROL_ROOT"; then
        test -d "$CONTROL_ROOT" || return 1
        test ! -L "$CONTROL_ROOT" || return 1
        command_output_equals 0:0:755 stat -c %u:%g:%a "$CONTROL_ROOT" || \
            return 1
    fi
    if test -e "$SHADOW_DROPIN_DIR" || test -L "$SHADOW_DROPIN_DIR"; then
        test -d "$SHADOW_DROPIN_DIR" || return 1
        test ! -L "$SHADOW_DROPIN_DIR" || return 1
        command_output_equals 0:0:755 stat -c %u:%g:%a \
            "$SHADOW_DROPIN_DIR" || return 1
        names=$(list_top_level_names "$SHADOW_DROPIN_DIR") || return 1
        test -z "$names" || return 1
    fi
    assert_legacy_assets_absent || return 1
    return 0
}

assert_vendor_policy() {
    assert_vendor_files || return 1
    command_output_equals "$EXPECTED_XOCHITL_RESTART" \
        systemctl show xochitl -p Restart --value || return 1
    command_output_equals "$EXPECTED_XOCHITL_RESTART_MODE" \
        systemctl show xochitl -p RestartMode --value || return 1
    assert_stock_onfailure_set || return 1
    command_output_equals "$EXPECTED_XOCHITL_FRAGMENT" \
        systemctl show xochitl -p FragmentPath --value || return 1
    command_output_equals "$EXPECTED_XOCHITL_DROPIN" \
        systemctl show xochitl -p DropInPaths --value || return 1
    assert_unit_environment vendor || return 1
    assert_control_assets_absent || return 1
    return 0
}

assert_stock_process() {
    local pid=$1 restarts=$2 process_environment
    test "$restarts" -eq 0 || return 1
    assert_exact_move_identity || return 1
    root_is_read_only || return 1
    command_output_equals active systemctl show xochitl \
        -p ActiveState --value || return 1
    command_output_equals running systemctl show xochitl \
        -p SubState --value || return 1
    command_output_equals '' systemctl show xochitl -p Job --value || return 1
    command_output_equals "$pid" \
        systemctl show xochitl -p MainPID --value || return 1
    command_output_equals "$restarts" \
        systemctl show xochitl -p NRestarts --value || return 1
    test -r "/proc/$pid/maps" || return 1
    command_output_equals /usr/bin/xochitl \
        readlink -f "/proc/$pid/exe" || return 1
    grep_absent -q '/home/root/xovi/' "/proc/$pid/maps" || return 1
    process_environment=$(tr '\000' '\n' <"/proc/$pid/environ") || return 1
    if printf '%s\n' "$process_environment" | \
       grep -Eq '^(LD_PRELOAD|XOVI_ROOT|QML_DISABLE_DISK_CACHE|QML_XHR_ALLOW_FILE_WRITE|QML_XHR_ALLOW_FILE_READ)='; then
        return 1
    fi
    one_xochitl_pid "$pid" || return 1
    return 0
}

assert_process_identity() {
    local pid=$1 start=$2 invocation=$3 start_monotonic=$4
    command_output_equals "$pid" systemctl show xochitl \
        -p MainPID --value || return 1
    command_output_equals "$start" process_start_time "$pid" || return 1
    command_output_equals "$invocation" systemctl show xochitl \
        -p InvocationID --value || return 1
    command_output_equals "$start_monotonic" systemctl show xochitl \
        -p ExecMainStartTimestampMonotonic --value || return 1
    command_output_equals '' systemctl show xochitl -p Job --value || return 1
    return 0
}

assert_vendor_stock() {
    local pid=$1 restarts=$2
    assert_stock_process "$pid" "$restarts" || return 1
    assert_vendor_policy || return 1
    return 0
}

canary_value() {
    local key=$1
    awk -F= -v key="$key" '
        $1 == key { count++; value=substr($0, length(key) + 2) }
        END { if (count != 1) exit 1; print value }
    ' "$CANARY_SUCCESS"
}

assert_shadow_canary_evidence() {
    local pid=$1 start=$2 invocation=$3 start_monotonic=$4 names
    local dummy_pid dummy_start dummy_invocation dummy_start_monotonic saved
    test -d "$CANARY_EVIDENCE" || return 1
    test ! -L "$CANARY_EVIDENCE" || return 1
    command_output_equals 0:0:700 stat -c %u:%g:%a \
        "$CANARY_EVIDENCE" || return 1
    names=$(list_top_level_names "$CANARY_EVIDENCE" | LC_ALL=C sort) || \
        return 1
    test "$names" = \
'base-dropin.saved
base-unit.saved
canary.passed
shadow-dropin.saved
shadow-unit.saved' || return 1
    test -f "$CANARY_SUCCESS" || return 1
    test ! -L "$CANARY_SUCCESS" || return 1
    command_output_equals 0:0:600 stat -c %u:%g:%a "$CANARY_SUCCESS" || \
        return 1
    for saved in base-unit.saved base-dropin.saved shadow-unit.saved \
        shadow-dropin.saved; do
        command_output_equals 0:0:600 stat -c %u:%g:%a \
            "$CANARY_EVIDENCE/$saved" || return 1
    done
    sha256_file_equals "$EXPECTED_CANARY_BASE_UNIT_SHA256" \
        "$CANARY_EVIDENCE/base-unit.saved" || return 1
    sha256_file_equals "$EXPECTED_CANARY_BASE_DROPIN_SHA256" \
        "$CANARY_EVIDENCE/base-dropin.saved" || return 1
    sha256_file_equals "$EXPECTED_CANARY_SHADOW_UNIT_SHA256" \
        "$CANARY_EVIDENCE/shadow-unit.saved" || return 1
    sha256_file_equals "$EXPECTED_CANARY_SHADOW_DROPIN_SHA256" \
        "$CANARY_EVIDENCE/shadow-dropin.saved" || return 1
    command_output_equals "$pid" canary_value stock_pid || return 1
    command_output_equals "$start" canary_value stock_start || return 1
    command_output_equals "$invocation" canary_value stock_invocation || return 1
    command_output_equals "$start_monotonic" \
        canary_value stock_start_monotonic || return 1
    dummy_pid=$(canary_value dummy_pid) || return 1
    dummy_start=$(canary_value dummy_start) || return 1
    dummy_invocation=$(canary_value dummy_invocation) || return 1
    dummy_start_monotonic=$(canary_value dummy_start_monotonic) || return 1
    case "$dummy_pid" in ''|0|*[!0-9]*) return 1 ;; esac
    case "$dummy_start" in ''|0|*[!0-9]*) return 1 ;; esac
    case "$dummy_start_monotonic" in ''|0|*[!0-9]*) return 1 ;; esac
    case "$dummy_invocation" in ''|*[!0-9a-f]*) return 1 ;; esac
    test "${#dummy_invocation}" -eq 32 || return 1
    test "$(wc -l <"$CANARY_SUCCESS")" -eq 8 || return 1
    return 0
}

assert_combined_policy() {
    assert_control_pair_files "$EXPECTED_XOVI_COMBINED_DROPIN_SHA256" || \
        return 1
    command_output_equals no \
        systemctl show xochitl -p Restart --value || return 1
    command_output_equals normal \
        systemctl show xochitl -p RestartMode --value || return 1
    command_output_equals 0 \
        systemctl show xochitl -p StartLimitIntervalUSec --value || return 1
    command_output_equals '' \
        systemctl show xochitl -p OnFailure --value || return 1
    command_output_equals "$SHADOW_UNIT" \
        systemctl show xochitl -p FragmentPath --value || return 1
    command_output_equals "$SHADOW_DROPIN" \
        systemctl show xochitl -p DropInPaths --value || return 1
    assert_unit_environment combined || return 1
    assert_legacy_assets_absent || return 1
    return 0
}

assert_xovi_payload() {
    local actual_names all_names extension_names service_names expected_names
    local hash filename extra qmd_count=0
    sha256_file_equals "$EXPECTED_XOVI_SHA256" \
        "$xovi/xovi.so" || return 1
    sha256_file_equals "$EXPECTED_QRR_SHA256" "$qrr_so" || return 1
    test -d "$xovi/extensions.d" || return 1
    test ! -L "$xovi/extensions.d" || return 1
    extension_names=$(list_top_level_names "$xovi/extensions.d") || return 1
    test "$extension_names" = qt-resource-rebuilder.so || return 1
    test -d "$qrr_dir" || return 1
    test ! -L "$qrr_dir" || return 1
    sha256_file_equals "$EXPECTED_CANDIDATE_HASHTAB_SHA256" \
        "$hashtab" || return 1
    sha256_file_equals "$EXPECTED_QMD_MANIFEST_SHA256" \
        "$QMD_MANIFEST" || return 1

    while read -r hash filename extra || test -n "${hash:-}"; do
        test -z "${extra:-}" || return 1
        [[ "$hash" =~ ^[0-9a-f]{64}$ ]] || return 1
        [[ "$filename" =~ ^[A-Za-z0-9._-]+\.qmd$ ]] || return 1
        test -f "$qrr_dir/$filename" || return 1
        test ! -L "$qrr_dir/$filename" || return 1
        qmd_count=$((qmd_count + 1))
    done <"$QMD_MANIFEST"
    test "$qmd_count" -eq "$EXPECTED_QMD_COUNT" || return 1
    # Enumerate every matching directory entry, not only regular files. A FIFO,
    # directory, device, or symlink with a QMD name must make the exact-set gate
    # fail rather than hiding from it.
    all_names=$(list_top_level_names "$qrr_dir") || return 1
    actual_names=$(printf '%s\n' "$all_names" | \
        awk '/\.qmd$/ { print }' | LC_ALL=C sort) || return 1
    expected_names=$(awk '{print $2}' "$QMD_MANIFEST" | LC_ALL=C sort) || \
        return 1
    test "$actual_names" = "$expected_names" || return 1
    (cd "$qrr_dir" && sha256sum -c "$QMD_MANIFEST" >/dev/null) || return 1

    test -d "$xovi/services/xochitl.service" || return 1
    test ! -L "$xovi/services/xochitl.service" || return 1
    service_names=$(list_top_level_names \
        "$xovi/services/xochitl.service" | LC_ALL=C sort) || return 1
    test "$service_names" = \
'extensions.d
exthome
qt-resource-rebuilder.conf' || return 1
    test -L "$xovi/services/xochitl.service/extensions.d" || return 1
    command_output_equals /home/root/xovi/extensions.d readlink \
        "$xovi/services/xochitl.service/extensions.d" || return 1
    test -L "$xovi/services/xochitl.service/exthome" || return 1
    command_output_equals /home/root/xovi/exthome readlink \
        "$xovi/services/xochitl.service/exthome" || return 1
    test -f "$xovi/services/xochitl.service/qt-resource-rebuilder.conf" || \
        return 1
    test ! -L "$xovi/services/xochitl.service/qt-resource-rebuilder.conf" || \
        return 1
    command_output_equals \
'[Service]
Environment="QML_DISABLE_DISK_CACHE=1"
Environment="QML_XHR_ALLOW_FILE_WRITE=1"
Environment="QML_XHR_ALLOW_FILE_READ=1"' \
        cat "$xovi/services/xochitl.service/qt-resource-rebuilder.conf" || \
        return 1
    return 0
}

assert_xovi_runtime() {
    local pid restarts
    systemctl is-active --quiet xochitl || return 1
    pid=$(systemctl show xochitl -p MainPID --value) || return 1
    restarts=$(systemctl show xochitl -p NRestarts --value) || return 1
    case "$pid:$restarts" in ''|0:*|*[!0-9:]*) return 1 ;; esac
    test "$restarts" -eq 0 || return 1
    test -r "/proc/$pid/maps" || return 1
    command_output_equals /usr/bin/xochitl \
        readlink -f "/proc/$pid/exe" || return 1
    process_maps_exact_path "$pid" "$xovi/xovi.so" || return 1
    process_maps_exact_path "$pid" "$qrr_so" || return 1
    grep_absent -Fqi '/appload' "/proc/$pid/maps" || return 1
    one_xochitl_pid "$pid" || return 1
    root_is_read_only || return 1
    assert_combined_policy || return 1
    return 0
}

monotonic_seconds() {
    local value
    value=$(cut -d. -f1 /proc/uptime) || return 1
    case "$value" in ''|*[!0-9]*) return 1 ;; esac
    printf '%s\n' "$value"
}

assert_watchdog_unit() {
    systemctl is-active --quiet "$WATCHDOG_UNIT.service" || return 1
    command_output_equals on-failure systemctl show \
        "$WATCHDOG_UNIT.service" -p Restart --value || return 1
    command_output_equals 0 systemctl show \
        "$WATCHDOG_UNIT.service" -p StartLimitIntervalUSec --value || return 1
    command_output_equals control-group systemctl show \
        "$WATCHDOG_UNIT.service" -p KillMode --value || return 1
    return 0
}

wait_for_qrr_journal() {
    local cursor=$1 log="$RUNTIME_ROOT/xochitl-activation.log" filename
    for _ in $(seq 1 45); do
        journalctl -u xochitl --after-cursor="$cursor" --no-pager >"$log"
        if grep -Eqi \
            'Failed to load hashtab|Failed to load file|Error loading rules|panic|core dumped|aborted' \
            "$log"; then
            return 1
        fi
        if grep -Fq 'Hashtab loaded! Cached' "$log"; then
            all_loaded=1
            while read -r _ filename _; do
                grep -Fq "$filename" "$log" || all_loaded=0
            done <"$QMD_MANIFEST"
            test "$all_loaded" -eq 1 && return 0
        fi
        sleep 1
    done
    return 1
}

wait_for_recovery() {
    # Three watchdog attempts can consume 3 * (20 + 30) seconds before daemon
    # reload and final verification. Stay beyond that proven upper bound.
    for _ in $(seq 1 240); do
        test -e "$RECOVERY_FAILED" && return 1
        test -e "$RECOVERY_DONE" && return 0
        sleep 1
    done
    return 1
}

prepare_control_directories() {
    local names
    if test -e "$CONTROL_ROOT" || test -L "$CONTROL_ROOT"; then
        test -d "$CONTROL_ROOT" || return 1
        test ! -L "$CONTROL_ROOT" || return 1
        command_output_equals 0:0:755 stat -c %u:%g:%a "$CONTROL_ROOT" || \
            return 1
    else
        mkdir -m 0755 "$CONTROL_ROOT" || return 1
    fi
    if test -e "$SHADOW_DROPIN_DIR" || test -L "$SHADOW_DROPIN_DIR"; then
        test -d "$SHADOW_DROPIN_DIR" || return 1
        test ! -L "$SHADOW_DROPIN_DIR" || return 1
        command_output_equals 0:0:755 stat -c %u:%g:%a \
            "$SHADOW_DROPIN_DIR" || return 1
        names=$(list_top_level_names "$SHADOW_DROPIN_DIR") || return 1
        test -z "$names" || return 1
    else
        mkdir -m 0755 "$SHADOW_DROPIN_DIR" || return 1
    fi
    return 0
}

activation_exit() {
    local rc=$? pid restarts recovered=0
    trap - EXIT HUP INT TERM
    trap '' HUP INT TERM
    if test "$complete" -ne 1; then
        if test "$mutation_started" -eq 1; then
            : >"$DEACTIVATE_REQUEST"
            sync
            if wait_for_recovery; then
                systemctl stop "$WATCHDOG_UNIT.service" 2>/dev/null || true
                systemctl reset-failed "$WATCHDOG_UNIT.service" 2>/dev/null || true
                pid=$(systemctl show xochitl -p MainPID --value)
                restarts=$(systemctl show xochitl -p NRestarts --value)
                if assert_vendor_stock "$pid" "$restarts" &&
                   assert_control_assets_absent; then
                    recovered=1
                fi
            fi
        elif test "$watchdog_armed" -eq 1; then
            systemctl stop "$WATCHDOG_UNIT.service" 2>/dev/null || true
            systemctl reset-failed "$WATCHDOG_UNIT.service" 2>/dev/null || true
            pid=$(systemctl show xochitl -p MainPID --value)
            restarts=$(systemctl show xochitl -p NRestarts --value)
            if assert_vendor_stock "$pid" "$restarts" &&
               assert_control_assets_absent; then
                recovered=1
            fi
        elif ! systemctl is-active --quiet "$WATCHDOG_UNIT.service" &&
             assert_control_assets_absent; then
            pid=$(systemctl show xochitl -p MainPID --value)
            restarts=$(systemctl show xochitl -p NRestarts --value)
            if assert_vendor_stock "$pid" "$restarts"; then
                recovered=1
            fi
        fi
        test "$recovered" -ne 1 || rm -rf "$RUNTIME_ROOT"
        rc=1
    fi
    exit "$rc"
}

activate() {
    local stock_pid stock_restarts stock_start stock_invocation
    local stock_start_monotonic journal_cursor deadline
    assert_control_assets_absent
    test ! -e "$RETIRED_UNIT"
    test ! -L "$RETIRED_UNIT"
    test ! -e "$RETIRED_DROPIN"
    test ! -L "$RETIRED_DROPIN"
    test ! -e "$RETIRED_DIR"
    test ! -L "$RETIRED_DIR"
    test ! -e "$WATCHDOG_READY"
    test ! -e "$ACTIVATE_REQUEST"
    test ! -e "$SESSION_READY"
    test ! -e "$DEACTIVATE_REQUEST"
    test ! -e "$RECOVERY_DONE"
    test ! -e "$RECOVERY_FAILED"
    stock_pid=$(systemctl show xochitl -p MainPID --value)
    stock_restarts=$(systemctl show xochitl -p NRestarts --value)
    case "$stock_pid:$stock_restarts" in ''|0:*|*[!0-9:]*) return 1 ;; esac
    test "$stock_restarts" -eq 0
    stock_start=$(process_start_time "$stock_pid")
    stock_invocation=$(systemctl show xochitl -p InvocationID --value)
    case "$stock_invocation" in ''|*[!0-9a-f]*) return 1 ;; esac
    test "${#stock_invocation}" -eq 32
    stock_start_monotonic=$(systemctl show xochitl \
        -p ExecMainStartTimestampMonotonic --value)
    case "$stock_start_monotonic" in ''|0|*[!0-9]*) return 1 ;; esac
    assert_vendor_stock "$stock_pid" "$stock_restarts"
    assert_process_identity "$stock_pid" "$stock_start" \
        "$stock_invocation" "$stock_start_monotonic"
    assert_shadow_canary_evidence "$stock_pid" "$stock_start" \
        "$stock_invocation" "$stock_start_monotonic"
    assert_xovi_payload
    sleep 2
    assert_vendor_stock "$stock_pid" "$stock_restarts"
    assert_process_identity "$stock_pid" "$stock_start" \
        "$stock_invocation" "$stock_start_monotonic"

    systemctl reset-failed "$WATCHDOG_UNIT.service" 2>/dev/null || true
    systemd-run --unit="$WATCHDOG_UNIT" \
        --property=Type=exec \
        --property=KillMode=control-group \
        --property=Restart=on-failure \
        --property=RestartSec=1s \
        --property=StartLimitIntervalSec=0 \
        /usr/bin/env \
        PROFILE="$PROFILE" \
        PROFILE_LIB="$PROFILE_LIB" \
        DROPIN_LIB="$DROPIN_LIB" \
        /bin/bash "$WATCHDOG_SCRIPT" watch
    watchdog_armed=1
    for _ in $(seq 1 20); do
        test -e "$WATCHDOG_READY" && assert_watchdog_unit && break
        sleep 1
    done
    test -e "$WATCHDOG_READY"
    assert_watchdog_unit

    journal_cursor=$(journalctl -n 0 --show-cursor --no-pager |
        sed -n 's/^-- cursor: //p')
    test -n "$journal_cursor"
    # Use boot-relative time so wall-clock/NTP changes cannot extend or expire
    # the guard. 180 seconds covers both 45-second runtime/journal waits plus
    # controlled restart and setup margin.
    deadline=$(($(monotonic_seconds) + 180))
    printf '%s\n' "$deadline" >"$DEADLINE"
    : >"$ACTIVATE_REQUEST"
    sync

    prepare_control_directories
    test ! -e "$STAGE_DIR"
    test ! -L "$STAGE_DIR"
    mkdir -m 0700 "$STAGE_DIR"
    command_output_equals 0:0:700 stat -c %u:%g:%a "$STAGE_DIR"
    mutation_started=1
    write_xovi_combined_shadow_pair "$SHADOW_UNIT" "$SHADOW_DROPIN" \
        "$STAGE_DIR"
    systemctl daemon-reload
    assert_combined_policy
    assert_stock_process "$stock_pid" "$stock_restarts"
    assert_process_identity "$stock_pid" "$stock_start" \
        "$stock_invocation" "$stock_start_monotonic"
    sleep 2
    assert_combined_policy
    assert_stock_process "$stock_pid" "$stock_restarts"
    assert_process_identity "$stock_pid" "$stock_start" \
        "$stock_invocation" "$stock_start_monotonic"
    systemctl restart xochitl

    for _ in $(seq 1 45); do
        assert_xovi_runtime && break
        sleep 1
    done
    assert_xovi_runtime
    wait_for_qrr_journal "$journal_cursor"
    assert_xovi_runtime
    : >"$SESSION_READY"
    sync
    assert_watchdog_unit
    complete=1
    echo "xovi_session=active"
    echo "watchdog=$WATCHDOG_UNIT.service"
}

deactivate() {
    test -e "$WATCHDOG_READY"
    test -e "$ACTIVATE_REQUEST"
    test -e "$SESSION_READY"
    test -e "$SHADOW_UNIT"
    test -e "$SHADOW_DROPIN"
    systemctl is-active --quiet "$WATCHDOG_UNIT.service"
    : >"$DEACTIVATE_REQUEST"
    sync
    wait_for_recovery
    systemctl stop "$WATCHDOG_UNIT.service" 2>/dev/null || true
    systemctl reset-failed "$WATCHDOG_UNIT.service" 2>/dev/null || true
    stock_pid=$(systemctl show xochitl -p MainPID --value)
    stock_restarts=$(systemctl show xochitl -p NRestarts --value)
    case "$stock_pid:$stock_restarts" in ''|0:*|*[!0-9:]*) return 1 ;; esac
    assert_vendor_stock "$stock_pid" "$stock_restarts"
    assert_control_assets_absent
    rm -rf "$RUNTIME_ROOT"
    echo "xovi_session=inactive"
}

status() {
    local pid restarts
    if test -e "$RECOVERY_FAILED"; then
        echo "xovi_session=recovery-failed"
        return 1
    fi
    if test -e "$SESSION_READY" && test -e "$SHADOW_UNIT" &&
       test -e "$SHADOW_DROPIN" && test ! -e "$STAGE_DIR" &&
       test ! -e "$RETIRED_DIR" &&
       systemctl is-active --quiet "$WATCHDOG_UNIT.service" &&
       assert_xovi_runtime; then
        echo "xovi_session=active"
        return
    fi
    if test -e "$SHADOW_UNIT" || test -L "$SHADOW_UNIT" ||
       test -e "$SHADOW_DROPIN" || test -L "$SHADOW_DROPIN" ||
       test -e "$STAGE_DIR" || test -L "$STAGE_DIR" ||
       test -e "$RETIRED_DIR" || test -L "$RETIRED_DIR" ||
       systemctl is-active --quiet "$WATCHDOG_UNIT.service"; then
        echo "xovi_session=inconsistent"
        return 1
    fi
    pid=$(systemctl show xochitl -p MainPID --value)
    restarts=$(systemctl show xochitl -p NRestarts --value)
    case "$pid:$restarts" in ''|0:*|*[!0-9:]*) return 1 ;; esac
    assert_vendor_stock "$pid" "$restarts"
    assert_control_assets_absent
    echo "xovi_session=inactive"
}

case "$MODE" in
    activate)
        trap activation_exit EXIT HUP INT TERM
        activate
        trap - EXIT HUP INT TERM
        ;;
    deactivate) deactivate ;;
    status) status ;;
    *) echo "usage: $0 {activate|deactivate|status}" >&2; exit 2 ;;
esac
