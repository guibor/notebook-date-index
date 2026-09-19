#!/bin/bash
# Independent /run-only watchdog for the Move XOVI session.
set -Eeuo pipefail
umask 077

PROFILE=${PROFILE:-}
PROFILE_LIB=${PROFILE_LIB:-}
DROPIN_LIB=${DROPIN_LIB:-}
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
WATCHDOG_READY="$RUNTIME_ROOT/watchdog.ready"
ACTIVATE_REQUEST="$RUNTIME_ROOT/activate.request"
SESSION_READY="$RUNTIME_ROOT/session.ready"
DEACTIVATE_REQUEST="$RUNTIME_ROOT/deactivate.request"
RECOVERY_LOCK="$RUNTIME_ROOT/recovery.lock"
RECOVERY_REQUESTED="$RUNTIME_ROOT/recovery.requested"
RECOVERY_DONE="$RUNTIME_ROOT/recovery.done"
RECOVERY_DONE_STAGE="$RUNTIME_ROOT/.recovery.done.staged"
RECOVERY_FAILED="$RUNTIME_ROOT/recovery.failed"
DEADLINE="$RUNTIME_ROOT/activation.deadline-monotonic"
xovi=/home/root/xovi
qrr_so="$xovi/extensions.d/qt-resource-rebuilder.so"

for input in "$PROFILE" "$PROFILE_LIB" "$DROPIN_LIB"; do
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
        test "$rc" -eq 1 || return 1
    fi
    return 0
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

assert_shadow_layout() {
    local names
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
    return 0
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

assert_shadow_file() {
    local path=$1 expected=$2
    test -f "$path" || return 1
    test ! -L "$path" || return 1
    command_output_equals 0:0:600 stat -c %u:%g:%a "$path" || return 1
    sha256_file_equals "$expected" "$path" || return 1
    return 0
}

assert_vendor_onfailure_set() {
    local actual word count=0 found_emergency=0 found_remarkable=0
    actual=$(systemctl show xochitl -p OnFailure --value) || return 1
    for word in $actual; do
        count=$((count + 1))
        case "$word" in
            emergency.target) found_emergency=$((found_emergency + 1)) ;;
            remarkable-fail.service)
                found_remarkable=$((found_remarkable + 1))
                ;;
            *) return 1 ;;
        esac
    done
    test "$count" -eq 2 || return 1
    test "$found_emergency" -eq 1 || return 1
    test "$found_remarkable" -eq 1 || return 1
    return 0
}

assert_safety_environment() {
    local environment word count=0 found_malloc=0
    environment=$(systemctl show xochitl -p Environment --value) || return 1
    for word in $environment; do
        count=$((count + 1))
        case "$word" in
            MALLOC_ARENA_MAX=8) found_malloc=$((found_malloc + 1)) ;;
            *) return 1 ;;
        esac
    done
    test "$count" -eq 1 || return 1
    test "$found_malloc" -eq 1 || return 1
    return 0
}

assert_combined_environment() {
    local environment word count=0 malloc=0 preload=0 root=0 cache=0
    local xhr_write=0 xhr_read=0
    environment=$(systemctl show xochitl -p Environment --value) || return 1
    for word in $environment; do
        count=$((count + 1))
        case "$word" in
            MALLOC_ARENA_MAX=8) malloc=$((malloc + 1)) ;;
            LD_PRELOAD=/home/root/xovi/xovi.so) preload=$((preload + 1)) ;;
            XOVI_ROOT=/home/root/xovi/services/xochitl.service/)
                root=$((root + 1))
                ;;
            QML_DISABLE_DISK_CACHE=1) cache=$((cache + 1)) ;;
            QML_XHR_ALLOW_FILE_WRITE=1) xhr_write=$((xhr_write + 1)) ;;
            QML_XHR_ALLOW_FILE_READ=1) xhr_read=$((xhr_read + 1)) ;;
            *) return 1 ;;
        esac
    done
    test "$count" -eq 6 || return 1
    test "$malloc" -eq 1 || return 1
    test "$preload" -eq 1 || return 1
    test "$root" -eq 1 || return 1
    test "$cache" -eq 1 || return 1
    test "$xhr_write" -eq 1 || return 1
    test "$xhr_read" -eq 1 || return 1
    return 0
}

assert_shadow_pair_files() {
    local expected_dropin_hash=$1
    assert_vendor_files || return 1
    assert_shadow_layout || return 1
    assert_shadow_file "$SHADOW_UNIT" \
        "$EXPECTED_XOVI_SHADOW_UNIT_SHA256" || return 1
    assert_shadow_file "$SHADOW_DROPIN" "$expected_dropin_hash" || return 1
    return 0
}

assert_safety_policy() {
    assert_shadow_pair_files \
        "$EXPECTED_XOVI_SAFETY_DROPIN_SHA256" || return 1
    command_output_equals no \
        systemctl show xochitl -p Restart --value || return 1
    command_output_equals normal \
        systemctl show xochitl -p RestartMode --value || return 1
    command_output_equals 0 systemctl show xochitl \
        -p StartLimitIntervalUSec --value || return 1
    command_output_equals '' \
        systemctl show xochitl -p OnFailure --value || return 1
    command_output_equals "$SHADOW_UNIT" \
        systemctl show xochitl -p FragmentPath --value || return 1
    command_output_equals "$SHADOW_DROPIN" \
        systemctl show xochitl -p DropInPaths --value || return 1
    assert_safety_environment || return 1
    return 0
}

assert_combined_policy() {
    assert_shadow_pair_files \
        "$EXPECTED_XOVI_COMBINED_DROPIN_SHA256" || return 1
    command_output_equals no \
        systemctl show xochitl -p Restart --value || return 1
    command_output_equals normal \
        systemctl show xochitl -p RestartMode --value || return 1
    command_output_equals 0 systemctl show xochitl \
        -p StartLimitIntervalUSec --value || return 1
    command_output_equals '' \
        systemctl show xochitl -p OnFailure --value || return 1
    command_output_equals "$SHADOW_UNIT" \
        systemctl show xochitl -p FragmentPath --value || return 1
    command_output_equals "$SHADOW_DROPIN" \
        systemctl show xochitl -p DropInPaths --value || return 1
    assert_combined_environment || return 1
    return 0
}

assert_vendor_policy() {
    assert_vendor_files || return 1
    test ! -e "$SHADOW_UNIT" || return 1
    test ! -L "$SHADOW_UNIT" || return 1
    test ! -e "$SHADOW_DROPIN" || return 1
    test ! -L "$SHADOW_DROPIN" || return 1
    test ! -e "$SHADOW_DROPIN_DIR" || return 1
    test ! -L "$SHADOW_DROPIN_DIR" || return 1
    command_output_equals "$EXPECTED_XOCHITL_RESTART" \
        systemctl show xochitl -p Restart --value || return 1
    command_output_equals "$EXPECTED_XOCHITL_RESTART_MODE" \
        systemctl show xochitl -p RestartMode --value || return 1
    assert_vendor_onfailure_set || return 1
    command_output_equals "$EXPECTED_XOCHITL_FRAGMENT" \
        systemctl show xochitl -p FragmentPath --value || return 1
    command_output_equals "$EXPECTED_XOCHITL_DROPIN" \
        systemctl show xochitl -p DropInPaths --value || return 1
    assert_safety_environment || return 1
    return 0
}

assert_same_running_process() {
    local pid=$1 start=$2 invocation=$3 start_monotonic=$4
    command_output_equals active systemctl show xochitl \
        -p ActiveState --value || return 1
    command_output_equals running systemctl show xochitl \
        -p SubState --value || return 1
    command_output_equals '' systemctl show xochitl -p Job --value || return 1
    command_output_equals "$pid" \
        systemctl show xochitl -p MainPID --value || return 1
    command_output_equals 0 \
        systemctl show xochitl -p NRestarts --value || return 1
    command_output_equals "$start" process_start_time "$pid" || return 1
    command_output_equals "$invocation" systemctl show xochitl \
        -p InvocationID --value || return 1
    command_output_equals "$start_monotonic" systemctl show xochitl \
        -p ExecMainStartTimestampMonotonic --value || return 1
    test -r "/proc/$pid/maps" || return 1
    command_output_equals /usr/bin/xochitl \
        readlink -f "/proc/$pid/exe" || return 1
    one_xochitl_pid "$pid" || return 1
    root_is_read_only || return 1
    return 0
}

capture_running_process_identity() {
    local pid=$1 start invocation start_monotonic
    start=$(process_start_time "$pid") || return 1
    invocation=$(systemctl show xochitl -p InvocationID --value) || return 1
    case "$invocation" in ''|*[!0-9a-f]*) return 1 ;; esac
    test "${#invocation}" -eq 32 || return 1
    start_monotonic=$(systemctl show xochitl \
        -p ExecMainStartTimestampMonotonic --value) || return 1
    case "$start_monotonic" in ''|0|*[!0-9]*) return 1 ;; esac
    assert_same_running_process "$pid" "$start" "$invocation" \
        "$start_monotonic" || return 1
    printf '%s %s %s\n' "$start" "$invocation" "$start_monotonic"
}

assert_process_has_no_xovi_environment() {
    local pid=$1 process_environment malloc_count
    test -r "/proc/$pid/environ" || return 1
    process_environment=$(tr '\000' '\n' <"/proc/$pid/environ") || return 1
    malloc_count=$(printf '%s\n' "$process_environment" | \
        awk '$0 == "MALLOC_ARENA_MAX=8" { count++ } END { print count+0 }') || \
        return 1
    test "$malloc_count" -eq 1 || return 1
    grep_absent -Eq \
        '^(LD_PRELOAD|XOVI_ROOT|QML_DISABLE_DISK_CACHE|QML_XHR_ALLOW_FILE_WRITE|QML_XHR_ALLOW_FILE_READ)=' \
        <<<"$process_environment" || return 1
    return 0
}

assert_stock_process() {
    local pid=$1 start=$2 invocation=$3 start_monotonic=$4
    assert_exact_move_identity || return 1
    assert_same_running_process "$pid" "$start" "$invocation" \
        "$start_monotonic" || return 1
    grep_absent -q '/home/root/xovi/' "/proc/$pid/maps" || return 1
    assert_process_has_no_xovi_environment "$pid" || return 1
    return 0
}

assert_xovi_process() {
    local pid process_environment
    command_output_equals active systemctl show xochitl \
        -p ActiveState --value || return 1
    command_output_equals running systemctl show xochitl \
        -p SubState --value || return 1
    command_output_equals '' systemctl show xochitl -p Job --value || return 1
    pid=$(systemctl show xochitl -p MainPID --value) || return 1
    case "$pid" in ''|0|*[!0-9]*) return 1 ;; esac
    command_output_equals 0 \
        systemctl show xochitl -p NRestarts --value || return 1
    test -r "/proc/$pid/maps" || return 1
    command_output_equals /usr/bin/xochitl \
        readlink -f "/proc/$pid/exe" || return 1
    process_maps_exact_path "$pid" "$xovi/xovi.so" || return 1
    process_maps_exact_path "$pid" "$qrr_so" || return 1
    grep_absent -Fqi '/appload' "/proc/$pid/maps" || return 1
    one_xochitl_pid "$pid" || return 1
    root_is_read_only || return 1
    test -r "/proc/$pid/environ" || return 1
    process_environment=$(tr '\000' '\n' <"/proc/$pid/environ") || return 1
    for expected in \
        'MALLOC_ARENA_MAX=8' \
        'LD_PRELOAD=/home/root/xovi/xovi.so' \
        'XOVI_ROOT=/home/root/xovi/services/xochitl.service/' \
        'QML_DISABLE_DISK_CACHE=1' \
        'QML_XHR_ALLOW_FILE_WRITE=1' \
        'QML_XHR_ALLOW_FILE_READ=1'; do
        printf '%s\n' "$process_environment" | grep -Fxq "$expected" || return 1
    done
    assert_combined_policy || return 1
    return 0
}

process_start_time() {
    local pid=$1 value
    case "$pid" in ''|*[!0-9]*) return 1 ;; esac
    test -r "/proc/$pid/stat" || return 1
    value=$(awk '{print $22}' "/proc/$pid/stat") || return 1
    case "$value" in ''|*[!0-9]*) return 1 ;; esac
    printf '%s\n' "$value"
}

monotonic_seconds() {
    local value
    value=$(cut -d. -f1 /proc/uptime) || return 1
    case "$value" in ''|*[!0-9]*) return 1 ;; esac
    printf '%s\n' "$value"
}

lock_owner_is_live() {
    # Return 0 for the same live process, 1 only for a proven-stale owner, and
    # 2 for malformed or otherwise unprovable state. Callers may reclaim only
    # status 1.
    local owner_pid owner_start extra live_start trailing
    test -f "$RECOVERY_LOCK/owner" || return 2
    test ! -L "$RECOVERY_LOCK/owner" || return 2
    command_output_equals 0:0 stat -c %u:%g "$RECOVERY_LOCK/owner" || return 2
    command_output_equals 600 stat -c %a "$RECOVERY_LOCK/owner" || return 2
    {
        read -r owner_pid owner_start extra || return 2
        trailing=
        if IFS= read -r trailing || test -n "$trailing"; then
            return 2
        fi
    } <"$RECOVERY_LOCK/owner"
    test -z "${extra:-}" || return 2
    case "$owner_pid" in ''|*[!0-9]*) return 2 ;; esac
    case "$owner_start" in ''|*[!0-9]*) return 2 ;; esac
    if test ! -e "/proc/$owner_pid"; then
        return 1
    fi
    live_start=$(process_start_time "$owner_pid") || return 2
    test "$live_start" = "$owner_start" || return 1
    return 0
}

acquire_recovery_lock() {
    local self_start stale owner_status owner_tmp
    self_start=$(process_start_time $$) || return 12
    while :; do
        if mkdir -m 0700 "$RECOVERY_LOCK" 2>/dev/null; then
            owner_tmp="$RECOVERY_LOCK/.owner.$$"
            printf '%s %s\n' "$$" "$self_start" >"$owner_tmp" || return 12
            sync || return 12
            mv "$owner_tmp" "$RECOVERY_LOCK/owner" || return 12
            sync || return 12
            return 0
        fi
        test -d "$RECOVERY_LOCK" || return 12
        test ! -L "$RECOVERY_LOCK" || return 12
        # The creator publishes owner metadata immediately after mkdir. Give
        # that bounded window time to close; never delete an ownerless lock.
        for _ in 1 2 3 4 5; do
            test -e "$RECOVERY_LOCK/owner" && break
            sleep 1 || return 12
        done
        owner_status=0
        lock_owner_is_live || owner_status=$?
        case "$owner_status" in
            0)
                while :; do
                    test -e "$RECOVERY_FAILED" && return 11
                    test -e "$RECOVERY_DONE" && return 10
                    sleep 1 || return 12
                    owner_status=0
                    lock_owner_is_live || owner_status=$?
                    case "$owner_status" in
                        0) continue ;;
                        1) break ;;
                        *) return 12 ;;
                    esac
                done
                ;;
            1) ;;
            *) return 12 ;;
        esac
        # A killed watchdog can leave the directory behind. Rename first so
        # only one successor can claim and remove that proven-stale inode.
        stale="$RECOVERY_LOCK.stale-$$-$self_start"
        test ! -e "$stale" || return 12
        test ! -L "$stale" || return 12
        if mv "$RECOVERY_LOCK" "$stale" 2>/dev/null; then
            rm -rf "$stale" || return 12
        fi
    done
}

xochitl_absent() {
    # Return 0 only for pidof's documented no-process state, 1 when a PID is
    # present, and 2 for a command failure that cannot prove absence.
    local output rc
    if output=$(pidof xochitl 2>/dev/null); then
        test -n "$output" || return 2
        return 1
    else
        rc=$?
        test "$rc" -eq 1 || return 2
        return 0
    fi
}

prove_stable_process_under_safety() {
    local attempt pid identity start invocation start_monotonic extra
    local absent_status

    for attempt in 1 2 3; do
        assert_safety_policy || return 1
        pid=$(systemctl show xochitl -p MainPID --value) || return 1
        case "$pid" in ''|*[!0-9]*) return 1 ;; esac
        if test "$pid" = 0; then
            absent_status=0
            xochitl_absent || absent_status=$?
            if test "$absent_status" -eq 0; then
                printf 'absent\n'
                return 0
            fi
            test "$absent_status" -eq 1 || return 1
            sleep 1 || return 1
            continue
        fi
        if ! identity=$(capture_running_process_identity "$pid"); then
            sleep 1 || return 1
            continue
        fi
        extra=
        if ! read -r start invocation start_monotonic extra \
            <<<"$identity" || test -n "${extra:-}"; then
            return 1
        fi
        # Re-read the complete safety pair into systemd between capture and
        # proof. Only an absent process or the same PID/start/invocation tuple
        # may reach a later stop/kill operation.
        assert_safety_policy || return 1
        systemctl daemon-reload || return 1
        assert_safety_policy || return 1
        if assert_same_running_process "$pid" "$start" "$invocation" \
            "$start_monotonic"; then
            printf 'running %s %s %s %s\n' \
                "$pid" "$start" "$invocation" "$start_monotonic"
            return 0
        fi
        sleep 1 || return 1
    done
    return 1
}

ensure_control_directories() {
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
        case "$names" in
            ''|xochitl-service-override.conf) ;;
            *) return 1 ;;
        esac
    else
        mkdir -m 0755 "$SHADOW_DROPIN_DIR" || return 1
    fi
    return 0
}

assert_runtime_root() {
    test -d "$RUNTIME_ROOT" || return 1
    test ! -L "$RUNTIME_ROOT" || return 1
    command_output_equals 0:0:700 stat -c %u:%g:%a "$RUNTIME_ROOT" || \
        return 1
    return 0
}

ensure_stage_directory() {
    local names path name has_unit=0 has_dropin=0
    assert_runtime_root || return 1
    case "$STAGE_DIR" in "$RUNTIME_ROOT"/*) ;; *) return 1 ;; esac
    if test -e "$STAGE_DIR" || test -L "$STAGE_DIR"; then
        test -d "$STAGE_DIR" || return 1
        test ! -L "$STAGE_DIR" || return 1
        command_output_equals 0:0:700 stat -c %u:%g:%a "$STAGE_DIR" || \
            return 1
    else
        mkdir -m 0700 "$STAGE_DIR" || return 1
    fi
    names=$(list_top_level_names "$STAGE_DIR") || return 1
    while IFS= read -r name; do
        test -n "$name" || continue
        case "$name" in
            xochitl.service|xochitl-service-override.conf) ;;
            *) return 1 ;;
        esac
        path="$STAGE_DIR/$name"
        case "$name" in
            xochitl.service)
                assert_shadow_file "$path" \
                    "$EXPECTED_XOVI_SHADOW_UNIT_SHA256" || return 1
                has_unit=1
                ;;
            xochitl-service-override.conf)
                test -f "$path" || return 1
                test ! -L "$path" || return 1
                command_output_equals 0:0:600 stat -c %u:%g:%a \
                    "$path" || return 1
                if sha256_file_equals \
                    "$EXPECTED_XOVI_COMBINED_DROPIN_SHA256" "$path"; then
                    :
                elif sha256_file_equals \
                    "$EXPECTED_XOVI_SAFETY_DROPIN_SHA256" "$path"; then
                    :
                else
                    return 1
                fi
                has_dropin=1
                ;;
        esac
    done <<<"$names"
    # The writer creates the main stage before the drop-in and publishes the
    # drop-in before the main. Empty, main-only, and the full pair are the only
    # exact interruption states; a lone staged drop-in is impossible.
    test "$has_dropin" -eq 0 || test "$has_unit" -eq 1 || return 1
    return 0
}

assert_retired_directory() {
    local names path name has_unit=0 has_dropin=0
    test -d "$RETIRED_DIR" || return 1
    test ! -L "$RETIRED_DIR" || return 1
    command_output_equals 0:0:700 stat -c %u:%g:%a "$RETIRED_DIR" || \
        return 1
    names=$(list_top_level_names "$RETIRED_DIR") || return 1
    while IFS= read -r name; do
        test -n "$name" || continue
        path="$RETIRED_DIR/$name"
        case "$name" in
            xochitl.service)
                test "$has_unit" -eq 0 || return 1
                assert_shadow_file "$path" \
                    "$EXPECTED_XOVI_SHADOW_UNIT_SHA256" || return 1
                has_unit=1
                ;;
            xochitl-service-override.conf)
                test "$has_dropin" -eq 0 || return 1
                assert_shadow_file "$path" \
                    "$EXPECTED_XOVI_SAFETY_DROPIN_SHA256" || return 1
                has_dropin=1
                ;;
            *) return 1 ;;
        esac
    done <<<"$names"
    # Main-first retirement and drop-in-first restoration can produce an empty
    # directory, a retained main only, or the complete retained pair. A lone
    # retained drop-in is never a legitimate crash state.
    test "$has_dropin" -eq 0 || test "$has_unit" -eq 1 || return 1
    return 0
}

ensure_retired_directory() {
    assert_runtime_root || return 1
    case "$RETIRED_DIR" in "$RUNTIME_ROOT"/*) ;; *) return 1 ;; esac
    if test -e "$RETIRED_DIR" || test -L "$RETIRED_DIR"; then
        assert_retired_directory || return 1
    else
        mkdir -m 0700 "$RETIRED_DIR" || return 1
    fi
    return 0
}

restore_retired_safety_pair_files() {
    local has_unit=0 has_dropin=0
    assert_runtime_root || return 1
    case "$RETIRED_DIR" in "$RUNTIME_ROOT"/*) ;; *) return 1 ;; esac
    if test ! -e "$RETIRED_DIR" && test ! -L "$RETIRED_DIR"; then
        return 0
    fi
    assert_retired_directory || return 1
    if test -e "$RETIRED_UNIT" || test -L "$RETIRED_UNIT"; then
        has_unit=1
    fi
    if test -e "$RETIRED_DROPIN" || test -L "$RETIRED_DROPIN"; then
        has_dropin=1
    fi
    if test "$has_unit" -eq 0 && test "$has_dropin" -eq 0; then
        rmdir "$RETIRED_DIR" || return 1
        sync || return 1
        return 0
    fi
    test "$has_unit" -eq 1 || return 1

    ensure_control_directories || return 1
    if test "$has_dropin" -eq 1; then
        test ! -e "$SHADOW_DROPIN" || return 1
        test ! -L "$SHADOW_DROPIN" || return 1
    else
        assert_shadow_file "$SHADOW_DROPIN" \
            "$EXPECTED_XOVI_SAFETY_DROPIN_SHA256" || return 1
    fi
    if test "$has_unit" -eq 1; then
        test ! -e "$SHADOW_UNIT" || return 1
        test ! -L "$SHADOW_UNIT" || return 1
    else
        assert_shadow_file "$SHADOW_UNIT" \
            "$EXPECTED_XOVI_SHADOW_UNIT_SHA256" || return 1
    fi
    # Restore the same-name drop-in first and the main shadow second, without a
    # reload between them. All collision checks above complete before either move.
    if test "$has_dropin" -eq 1; then
        mv "$RETIRED_DROPIN" "$SHADOW_DROPIN" || return 1
    fi
    if test "$has_unit" -eq 1; then
        mv "$RETIRED_UNIT" "$SHADOW_UNIT" || return 1
    fi
    rmdir "$RETIRED_DIR" || return 1
    sync || return 1
    return 0
}

publish_and_load_safety_pair() {
    local attempt
    # A malformed retained state must not prevent an independent attempt to
    # publish and load a complete safety pair. It remains fail-visible because
    # retirement below accepts only an empty exact retained directory.
    restore_retired_safety_pair_files || :
    ensure_control_directories || return 1
    for attempt in 1 2; do
        ensure_stage_directory || break
        write_xovi_safety_shadow_pair \
            "$SHADOW_UNIT" "$SHADOW_DROPIN" "$STAGE_DIR" && break
    done
    # A late writer failure may occur after both exact files were published.
    # Load them if and only if the complete pair is independently proven; any
    # remaining stage state still forces a visible failure after safety loads.
    assert_shadow_pair_files "$EXPECTED_XOVI_SAFETY_DROPIN_SHA256" || \
        return 1
    sync || return 1
    systemctl daemon-reload || return 1
    assert_safety_policy || return 1
    test ! -e "$STAGE_DIR" || return 1
    test ! -L "$STAGE_DIR" || return 1
    return 0
}

retire_safety_pair() {
    local restore_rc=0
    assert_safety_policy || return 1
    test ! -e "$STAGE_DIR" || return 1
    test ! -L "$STAGE_DIR" || return 1
    ensure_retired_directory || return 1
    test ! -e "$RETIRED_UNIT" || return 1
    test ! -L "$RETIRED_UNIT" || return 1
    test ! -e "$RETIRED_DROPIN" || return 1
    test ! -L "$RETIRED_DROPIN" || return 1

    # Main first is the safer unpublication order. There is deliberately no
    # daemon reload until both exact safety shadows have moved aside.
    mv "$SHADOW_UNIT" "$RETIRED_UNIT" || return 1
    if ! mv "$SHADOW_DROPIN" "$RETIRED_DROPIN"; then
        restore_retired_safety_pair_files || restore_rc=1
        assert_safety_policy || restore_rc=1
        test "$restore_rc" -eq 0 || return 1
        return 1
    fi
    if ! rmdir "$SHADOW_DROPIN_DIR"; then
        restore_retired_safety_pair_files || restore_rc=1
        test "$restore_rc" -eq 0 || return 1
        return 1
    fi
    if ! sync; then
        restore_retired_safety_pair_files || restore_rc=1
        assert_safety_policy || restore_rc=1
        test "$restore_rc" -eq 0 || return 1
        return 1
    fi
    assert_retired_directory || {
        restore_retired_safety_pair_files || restore_rc=1
        assert_safety_policy || restore_rc=1
        test "$restore_rc" -eq 0 || return 1
        return 1
    }
    test ! -e "$SHADOW_UNIT" || return 1
    test ! -L "$SHADOW_UNIT" || return 1
    test ! -e "$SHADOW_DROPIN" || return 1
    test ! -L "$SHADOW_DROPIN" || return 1
    test ! -e "$SHADOW_DROPIN_DIR" || return 1
    test ! -L "$SHADOW_DROPIN_DIR" || return 1
    return 0
}

restore_safety_after_vendor_failure() {
    local pid=$1 start=$2 invocation=$3 start_monotonic=$4
    local anomaly=0 publish_rc=0 attempt

    # Reconcile the retained pair when possible, but independently recreate the
    # complete pair as well. Thus an unexpected retained entry is fail-visible
    # without preventing the best possible restoration of loaded safety policy.
    restore_retired_safety_pair_files || anomaly=1
    if ensure_control_directories; then
        for attempt in 1 2; do
            ensure_stage_directory || break
            write_xovi_safety_shadow_pair \
                "$SHADOW_UNIT" "$SHADOW_DROPIN" "$STAGE_DIR" && break
        done
    else
        publish_rc=1
    fi
    if test "$publish_rc" -eq 0; then
        assert_shadow_pair_files \
            "$EXPECTED_XOVI_SAFETY_DROPIN_SHA256" || publish_rc=1
    fi
    if test "$publish_rc" -eq 0; then
        sync || publish_rc=1
    fi
    if test "$publish_rc" -eq 0; then
        systemctl daemon-reload || publish_rc=1
    fi
    if test "$publish_rc" -eq 0; then
        assert_safety_policy || publish_rc=1
    fi
    if test "$publish_rc" -eq 0; then
        assert_stock_process "$pid" "$start" "$invocation" \
            "$start_monotonic" || publish_rc=1
    fi
    if test "$publish_rc" -eq 0; then
        test ! -e "$STAGE_DIR" || publish_rc=1
        test ! -L "$STAGE_DIR" || publish_rc=1
    fi
    test "$publish_rc" -eq 0 || return 1
    test "$anomaly" -eq 0 || return 1
    return 0
}

recover_stock_once() {
    local attempt wait_index pid pid_start pid_invocation
    local pid_start_monotonic recovered=0
    local original_pid=0 original_start= original_invocation=
    local original_start_monotonic= original_proven=0
    local candidate_pid identity extra lock_result=0 absent_status
    local vendor_transition_failed=0
    local stable_record stable_kind stable_pid stable_start
    local stable_invocation stable_start_monotonic

    : >"$RECOVERY_REQUESTED" || return 1
    sync || return 1
    acquire_recovery_lock || lock_result=$?
    case "$lock_result" in
        0) ;;
        10) return 0 ;;
        11) return 1 ;;
        *) return 1 ;;
    esac

    rm -f "$RECOVERY_DONE_STAGE" "$RECOVERY_DONE" \
        "$RECOVERY_FAILED" || return 1
    # PID identity is an optimization only until safety is loaded. If xochitl
    # exits or changes during capture, do not strand the combined policy: load
    # safety first, then recover through the bounded stop/start path below.
    if candidate_pid=$(systemctl show xochitl -p MainPID --value); then
        case "$candidate_pid" in
            ''|*[!0-9]*) ;;
            *)
                original_pid=$candidate_pid
                if test "$original_pid" != 0; then
                    if identity=$(capture_running_process_identity \
                        "$original_pid"); then
                        extra=
                        if read -r original_start original_invocation \
                            original_start_monotonic extra <<<"$identity" &&
                           test -z "${extra:-}"; then
                            original_proven=1
                        fi
                    fi
                fi
                ;;
        esac
    fi

    # Reconcile any interrupted retirement and load the complete safety pair
    # before stopping, killing, or starting xochitl.
    publish_and_load_safety_pair || return 1
    if test "$original_proven" -eq 1; then
        if assert_stock_process "$original_pid" "$original_start" \
            "$original_invocation" "$original_start_monotonic"; then
            pid=$original_pid
            pid_start=$original_start
            pid_invocation=$original_invocation
            pid_start_monotonic=$original_start_monotonic
            recovered=1
        fi
    fi

    for attempt in 1 2 3; do
        test "$recovered" -eq 0 || break
        assert_safety_policy || return 1
        stable_record=$(prove_stable_process_under_safety) || return 1
        extra=
        read -r stable_kind stable_pid stable_start stable_invocation \
            stable_start_monotonic extra <<<"$stable_record" || return 1
        case "$stable_kind" in
            absent)
                test -z "${stable_pid:-}${stable_start:-}${stable_invocation:-}${stable_start_monotonic:-}${extra:-}" || \
                    return 1
                ;;
            running)
                test -n "${stable_pid:-}" || return 1
                test -n "${stable_start:-}" || return 1
                test -n "${stable_invocation:-}" || return 1
                test -n "${stable_start_monotonic:-}" || return 1
                test -z "${extra:-}" || return 1
                if assert_stock_process "$stable_pid" "$stable_start" \
                    "$stable_invocation" "$stable_start_monotonic"; then
                    pid=$stable_pid
                    pid_start=$stable_start
                    pid_invocation=$stable_invocation
                    pid_start_monotonic=$stable_start_monotonic
                    recovered=1
                    break
                fi
                assert_safety_policy || return 1
                assert_same_running_process "$stable_pid" "$stable_start" \
                    "$stable_invocation" "$stable_start_monotonic" || \
                    continue
                systemctl stop xochitl 2>/dev/null || :
                ;;
            *) return 1 ;;
        esac

        # Give a proven process a short graceful-stop window. If it remains,
        # re-capture, reload, and re-prove its identity before using kill.
        for ((wait_index = 0; wait_index < 5; wait_index++)); do
            absent_status=0
            xochitl_absent || absent_status=$?
            test "$absent_status" -eq 0 && break
            test "$absent_status" -eq 1 || return 1
            sleep 1 || return 1
        done
        absent_status=0
        xochitl_absent || absent_status=$?
        test "$absent_status" -eq 2 && return 1
        if test "$absent_status" -eq 1; then
            stable_record=$(prove_stable_process_under_safety) || return 1
            extra=
            read -r stable_kind stable_pid stable_start stable_invocation \
                stable_start_monotonic extra <<<"$stable_record" || return 1
            case "$stable_kind" in
                absent)
                    test -z "${stable_pid:-}${stable_start:-}${stable_invocation:-}${stable_start_monotonic:-}${extra:-}" || \
                        return 1
                    ;;
                running)
                    test -n "${stable_pid:-}" || return 1
                    test -n "${stable_start:-}" || return 1
                    test -n "${stable_invocation:-}" || return 1
                    test -n "${stable_start_monotonic:-}" || return 1
                    test -z "${extra:-}" || return 1
                    if assert_stock_process "$stable_pid" "$stable_start" \
                        "$stable_invocation" \
                        "$stable_start_monotonic"; then
                        pid=$stable_pid
                        pid_start=$stable_start
                        pid_invocation=$stable_invocation
                        pid_start_monotonic=$stable_start_monotonic
                        recovered=1
                        break
                    fi
                    assert_safety_policy || return 1
                    assert_same_running_process "$stable_pid" \
                        "$stable_start" "$stable_invocation" \
                        "$stable_start_monotonic" || continue
                    systemctl kill --kill-who=all xochitl \
                        2>/dev/null || :
                    ;;
                *) return 1 ;;
            esac
        fi
        test "$recovered" -eq 0 || break
        for ((wait_index = 0; wait_index < 20; wait_index++)); do
            absent_status=0
            xochitl_absent || absent_status=$?
            test "$absent_status" -eq 0 && break
            test "$absent_status" -eq 1 || return 1
            sleep 1 || return 1
        done
        absent_status=0
        xochitl_absent || absent_status=$?
        test "$absent_status" -eq 2 && return 1
        test "$absent_status" -eq 0 || continue
        assert_safety_policy || return 1
        systemctl start xochitl 2>/dev/null || :
        for ((wait_index = 0; wait_index < 30; wait_index++)); do
            if systemctl is-active --quiet xochitl; then
                pid=$(systemctl show xochitl -p MainPID --value) || return 1
                case "$pid" in
                    ''|0|*[!0-9]*) ;;
                    *)
                        if identity=$(capture_running_process_identity \
                            "$pid"); then
                            extra=
                            if read -r pid_start pid_invocation \
                                pid_start_monotonic extra <<<"$identity" &&
                               test -z "${extra:-}" &&
                               assert_safety_policy &&
                               assert_stock_process "$pid" "$pid_start" \
                                   "$pid_invocation" \
                                   "$pid_start_monotonic"; then
                                recovered=1
                                break
                            fi
                        fi
                        ;;
                esac
            fi
            sleep 1 || return 1
        done
        test "$recovered" -eq 1 && break
    done

    if test "$recovered" -ne 1; then
        return 1
    fi
    sleep 2 || return 1
    assert_safety_policy || return 1
    assert_stock_process "$pid" "$pid_start" "$pid_invocation" \
        "$pid_start_monotonic" || return 1

    # Restore vendor policy only around the exact stock process verified above.
    # If any part of the transition fails, republish and load the complete safety
    # pair before returning a visible recovery failure.
    retire_safety_pair || vendor_transition_failed=1
    if test "$vendor_transition_failed" -eq 0; then
        systemctl daemon-reload || vendor_transition_failed=1
    fi
    if test "$vendor_transition_failed" -eq 0; then
        assert_vendor_policy || vendor_transition_failed=1
    fi
    if test "$vendor_transition_failed" -eq 0; then
        assert_stock_process "$pid" "$pid_start" "$pid_invocation" \
            "$pid_start_monotonic" || vendor_transition_failed=1
    fi
    if test "$vendor_transition_failed" -eq 0; then
        sleep 2 || vendor_transition_failed=1
    fi
    if test "$vendor_transition_failed" -eq 0; then
        assert_vendor_policy || vendor_transition_failed=1
    fi
    if test "$vendor_transition_failed" -eq 0; then
        assert_stock_process "$pid" "$pid_start" "$pid_invocation" \
            "$pid_start_monotonic" || vendor_transition_failed=1
    fi
    if test "$vendor_transition_failed" -ne 0; then
        restore_safety_after_vendor_failure "$pid" "$pid_start" \
            "$pid_invocation" "$pid_start_monotonic" || return 1
        return 1
    fi
    rm -f \
        "$ACTIVATE_REQUEST" \
        "$SESSION_READY" \
        "$DEACTIVATE_REQUEST" \
        "$DEADLINE" || return 1
    test ! -e "$RECOVERY_DONE_STAGE" || return 1
    test ! -L "$RECOVERY_DONE_STAGE" || return 1
    printf '%s\n' \
        "stock_pid=$pid" \
        "stock_start=$pid_start" \
        "stock_invocation=$pid_invocation" \
        "stock_start_monotonic=$pid_start_monotonic" \
        >"$RECOVERY_DONE_STAGE" || return 1
    sync || return 1
    rm -f "$RECOVERY_REQUESTED" || return 1
    sync || return 1
    test ! -e "$RECOVERY_DONE" || return 1
    test ! -L "$RECOVERY_DONE" || return 1
    mv "$RECOVERY_DONE_STAGE" "$RECOVERY_DONE" || return 1
    return 0
}

mark_recovery_failed() {
    local reason=$1
    printf '%s\n' "$reason" >"$RECOVERY_FAILED" || {
        echo "FAIL: could not publish XOVI recovery failure marker" >&2
        return 1
    }
    sync || {
        echo "FAIL: could not sync XOVI recovery failure marker" >&2
        return 1
    }
    echo "FAIL: $reason" >&2
    return 1
}

recover_stock() {
    local rc=0
    # A fresh Bash prevents a caller's `recover_stock || ...` conditional from
    # disabling errexit inside the safety-critical state machine.
    /bin/bash "$0" recover-once || rc=$?
    test "$rc" -ne 0 || return 0
    mark_recovery_failed \
        "stock recovery stopped safely with visible failure (rc=$rc)" || true
    return 1
}

watch_session() {
    local deadline now

    printf 'watchdog_pid=%s\n' "$$" >"$WATCHDOG_READY" || return 1
    sync || return 1

    if test -e "$RECOVERY_FAILED"; then
        # Remain visible and block a new activation until manual inspection.
        while :; do sleep 3600; done
    fi
    if test -e "$RECOVERY_DONE"; then
        return
    fi
    if test -e "$RECOVERY_REQUESTED"; then
        recover_stock || return 1
        return 0
    fi

    while test ! -e "$ACTIVATE_REQUEST"; do
        if test -e "$DEACTIVATE_REQUEST"; then
            recover_stock || return 1
            return 0
        fi
        sleep 1
    done

    if ! test -f "$DEADLINE" || test -L "$DEADLINE"; then
        recover_stock || return 1
        return 0
    fi
    if ! deadline=$(cat "$DEADLINE"); then
        recover_stock || return 1
        return 0
    fi
    case "$deadline" in
        ''|*[!0-9]*)
            recover_stock || return 1
            return 0
            ;;
    esac

    while test ! -e "$SESSION_READY"; do
        if test -e "$DEACTIVATE_REQUEST"; then
            recover_stock || return 1
            return 0
        fi
        if ! now=$(monotonic_seconds); then
            recover_stock || return 1
            return 0
        fi
        if test "$now" -ge "$deadline"; then
            recover_stock || return 1
            return 0
        fi
        sleep 1
    done

    while :; do
        if test -e "$DEACTIVATE_REQUEST" || ! assert_xovi_process; then
            recover_stock || return 1
            return 0
        fi
        sleep 2
    done
}

case "${1:-watch}" in
    watch) watch_session ;;
    recover) recover_stock ;;
    recover-once) recover_stock_once ;;
    *) echo "usage: $0 [watch|recover]" >&2; exit 2 ;;
esac
