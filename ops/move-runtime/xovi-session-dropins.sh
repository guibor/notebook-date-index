#!/bin/bash
# Pure helpers for staging and publishing the two approved volatile systemd
# shadow files. The caller owns daemon-reload and all service transitions.

_xovi_shadow_sha256_equals() {
    local expected=${1:-} path=${2:-} output actual filename extra

    test "$#" -eq 2 || return 2
    test -n "$expected" || return 2
    test -n "$path" || return 2
    test -f "$path" || return 1
    test ! -L "$path" || return 1
    output=$(sha256sum "$path") || return 1
    read -r actual filename extra <<<"$output" || return 1
    test "$filename" = "$path" || return 1
    test -z "${extra:-}" || return 1
    test "$actual" = "$expected" || return 1
    return 0
}

_xovi_shadow_stage_is_outside_systemd_search() {
    local stage_dir=${1:-} canonical

    test "$#" -eq 1 || return 2
    test -n "$stage_dir" || return 2
    canonical=$(readlink -f "$stage_dir") || return 1
    case "$canonical" in
        /etc/systemd/system.control|/etc/systemd/system.control/*|\
        /etc/systemd/system|/etc/systemd/system/*|\
        /etc/systemd/system.attached|/etc/systemd/system.attached/*|\
        /run/systemd/system|/run/systemd/system/*|\
        /run/systemd/system.control|/run/systemd/system.control/*|\
        /run/systemd/system.attached|/run/systemd/system.attached/*|\
        /run/systemd/transient|/run/systemd/transient/*|\
        /run/systemd/generator|/run/systemd/generator/*|\
        /run/systemd/generator.early|/run/systemd/generator.early/*|\
        /run/systemd/generator.late|/run/systemd/generator.late/*|\
        /usr/local/lib/systemd/system|/usr/local/lib/systemd/system/*|\
        /usr/lib/systemd/system|/usr/lib/systemd/system/*)
            return 1
            ;;
    esac
    return 0
}

_xovi_shadow_assert_stage_entries() (
    local stage_dir=${1:-} path name

    test "$#" -eq 1 || return 2
    test -d "$stage_dir" || return 1
    test ! -L "$stage_dir" || return 1
    shopt -s dotglob nullglob
    for path in "$stage_dir"/*; do
        name=${path##*/}
        case "$name" in
            xochitl.service|xochitl-service-override.conf) ;;
            *) return 1 ;;
        esac
        test -f "$path" || return 1
        test ! -L "$path" || return 1
    done
    return 0
)

_xovi_shadow_assert_dropin_entries() (
    local directory=${1:-} expected_name=${2:-} path name

    test "$#" -eq 2 || return 2
    test -n "$expected_name" || return 2
    test -d "$directory" || return 1
    test ! -L "$directory" || return 1
    shopt -s dotglob nullglob
    for path in "$directory"/*; do
        name=${path##*/}
        test "$name" = "$expected_name" || return 1
        test -f "$path" || return 1
        test ! -L "$path" || return 1
    done
    return 0
)

_xovi_shadow_reset_stage_file() {
    local path=${1:-}

    test "$#" -eq 1 || return 2
    test -n "$path" || return 2
    if test -e "$path" || test -L "$path"; then
        test -f "$path" || return 1
        test ! -L "$path" || return 1
        rm -f "$path" || return 1
    fi
    test ! -e "$path" || return 1
    test ! -L "$path" || return 1
    return 0
}

_xovi_shadow_assert_unit_destination() {
    local path=${1:-}

    test "$#" -eq 1 || return 2
    test -n "$path" || return 2
    if test -e "$path" || test -L "$path"; then
        test -f "$path" || return 1
        test ! -L "$path" || return 1
        _xovi_shadow_sha256_equals \
            53813c186d33c6ffc4f12760818cba84c687a9b822f918a30d3f055ad651ba0b \
            "$path" || return 1
    fi
    return 0
}

_xovi_shadow_assert_dropin_destination() {
    local path=${1:-} output actual filename extra

    test "$#" -eq 1 || return 2
    test -n "$path" || return 2
    if test -e "$path" || test -L "$path"; then
        test -f "$path" || return 1
        test ! -L "$path" || return 1
        output=$(sha256sum "$path") || return 1
        read -r actual filename extra <<<"$output" || return 1
        test "$filename" = "$path" || return 1
        test -z "${extra:-}" || return 1
        case "$actual" in
            def590c15f95582878df2f770891b0ecda0f766ee320168f515cb2a09242c9ff|\
            4c64e69fae9cac524256c17e9977b17ffe0526cda4a2824308fa8b7eb2bbba68)
                ;;
            *) return 1 ;;
        esac
    fi
    return 0
}

_xovi_shadow_write_unit_stage() {
    local path=${1:-}

    test "$#" -eq 1 || return 2
    test -n "$path" || return 2
    test ! -e "$path" || return 1
    test ! -L "$path" || return 1
    cat >"$path" <<'EOF' || return 1
[Unit]
Description=reMarkable main application
StartLimitIntervalSec=0
StartLimitBurst=4
DefaultDependencies=no
Conflicts=shutdown.target
Before=shutdown.target
Wants=rm-sync.service
After=data.mount dbus.socket
Requires=dbus.socket

[Service]
ExecStart=/usr/bin/xochitl --system
Restart=no
WatchdogSec=60
NotifyAccess=all

[Install]
WantedBy=multi-user.target
EOF
    chmod 0600 "$path" || return 1
    _xovi_shadow_sha256_equals \
        53813c186d33c6ffc4f12760818cba84c687a9b822f918a30d3f055ad651ba0b \
        "$path" || return 1
    return 0
}

_xovi_shadow_write_combined_dropin_stage() {
    local path=${1:-}

    test "$#" -eq 1 || return 2
    test -n "$path" || return 2
    test ! -e "$path" || return 1
    test ! -L "$path" || return 1
    cat >"$path" <<'EOF' || return 1
[Unit]
Requires=dev-dri-card0.device
After=dev-dri-card0.device tee-supplicant.service
Wants=tee-supplicant.service
JobTimeoutSec=60s
StartLimitIntervalSec=0

[Service]
Environment="MALLOC_ARENA_MAX=8"
Environment="LD_PRELOAD=/home/root/xovi/xovi.so"
Environment="XOVI_ROOT=/home/root/xovi/services/xochitl.service/"
Environment="QML_DISABLE_DISK_CACHE=1"
Environment="QML_XHR_ALLOW_FILE_WRITE=1"
Environment="QML_XHR_ALLOW_FILE_READ=1"
Restart=no
RestartMode=normal
EOF
    chmod 0600 "$path" || return 1
    _xovi_shadow_sha256_equals \
        def590c15f95582878df2f770891b0ecda0f766ee320168f515cb2a09242c9ff \
        "$path" || return 1
    return 0
}

_xovi_shadow_write_safety_dropin_stage() {
    local path=${1:-}

    test "$#" -eq 1 || return 2
    test -n "$path" || return 2
    test ! -e "$path" || return 1
    test ! -L "$path" || return 1
    cat >"$path" <<'EOF' || return 1
[Unit]
Requires=dev-dri-card0.device
After=dev-dri-card0.device tee-supplicant.service
Wants=tee-supplicant.service
JobTimeoutSec=60s
StartLimitIntervalSec=0

[Service]
Environment="MALLOC_ARENA_MAX=8"
Restart=no
RestartMode=normal
EOF
    chmod 0600 "$path" || return 1
    _xovi_shadow_sha256_equals \
        4c64e69fae9cac524256c17e9977b17ffe0526cda4a2824308fa8b7eb2bbba68 \
        "$path" || return 1
    return 0
}

_write_xovi_shadow_pair() {
    local mode=${1:-} shadow_unit=${2:-} shadow_dropin=${3:-}
    local stage_dir=${4:-} unit_parent dropin_dir dropin_name
    local stage_unit stage_dropin expected_dropin_hash path

    test "$#" -eq 4 || return 2
    case "$mode" in combined|safety) ;; *) return 2 ;; esac
    for path in "$shadow_unit" "$shadow_dropin" "$stage_dir"; do
        case "$path" in ''|*$'\n'*) return 2 ;; esac
    done
    test "${shadow_unit##*/}" = xochitl.service || return 2
    dropin_name=${shadow_dropin##*/}
    test "$dropin_name" = xochitl-service-override.conf || return 2
    dropin_dir=${shadow_dropin%/*}
    test "$dropin_dir" = "$shadow_unit.d" || return 2
    unit_parent=${shadow_unit%/*}
    test "$unit_parent" != "$shadow_unit" || return 2
    test -d "$unit_parent" || return 1
    test ! -L "$unit_parent" || return 1
    test "$(stat -c %u:%g:%a "$unit_parent")" = 0:0:755 || return 1
    test -d "$dropin_dir" || return 1
    test ! -L "$dropin_dir" || return 1
    test "$(stat -c %u:%g:%a "$dropin_dir")" = 0:0:755 || return 1
    test -d "$stage_dir" || return 1
    test ! -L "$stage_dir" || return 1
    test "$(stat -c %u:%g:%a "$stage_dir")" = 0:0:700 || return 1
    _xovi_shadow_stage_is_outside_systemd_search "$stage_dir" || return 1
    _xovi_shadow_assert_stage_entries "$stage_dir" || return 1
    _xovi_shadow_assert_dropin_entries "$dropin_dir" \
        "$dropin_name" || return 1
    _xovi_shadow_assert_unit_destination "$shadow_unit" || return 1
    _xovi_shadow_assert_dropin_destination "$shadow_dropin" || return 1

    stage_unit="$stage_dir/xochitl.service"
    stage_dropin="$stage_dir/xochitl-service-override.conf"
    test "$stage_unit" != "$shadow_unit" || return 1
    test "$stage_dropin" != "$shadow_dropin" || return 1
    _xovi_shadow_reset_stage_file "$stage_unit" || return 1
    _xovi_shadow_reset_stage_file "$stage_dropin" || return 1
    _xovi_shadow_assert_stage_entries "$stage_dir" || return 1

    _xovi_shadow_write_unit_stage "$stage_unit" || return 1
    case "$mode" in
        combined)
            _xovi_shadow_write_combined_dropin_stage "$stage_dropin" || \
                return 1
            expected_dropin_hash=def590c15f95582878df2f770891b0ecda0f766ee320168f515cb2a09242c9ff
            ;;
        safety)
            _xovi_shadow_write_safety_dropin_stage "$stage_dropin" || \
                return 1
            expected_dropin_hash=4c64e69fae9cac524256c17e9977b17ffe0526cda4a2824308fa8b7eb2bbba68
            ;;
        *) return 2 ;;
    esac
    _xovi_shadow_assert_stage_entries "$stage_dir" || return 1
    sync || return 1

    # Publish the same-basename drop-in before the main unit. The caller must
    # perform one daemon-reload only after this function has returned success.
    mv "$stage_dropin" "$shadow_dropin" || return 1
    sync || return 1
    _xovi_shadow_sha256_equals "$expected_dropin_hash" \
        "$shadow_dropin" || return 1
    _xovi_shadow_assert_dropin_entries "$dropin_dir" \
        "$dropin_name" || return 1

    mv "$stage_unit" "$shadow_unit" || return 1
    sync || return 1
    _xovi_shadow_sha256_equals \
        53813c186d33c6ffc4f12760818cba84c687a9b822f918a30d3f055ad651ba0b \
        "$shadow_unit" || return 1
    _xovi_shadow_sha256_equals "$expected_dropin_hash" \
        "$shadow_dropin" || return 1
    _xovi_shadow_assert_stage_entries "$stage_dir" || return 1
    _xovi_shadow_assert_dropin_entries "$dropin_dir" \
        "$dropin_name" || return 1
    rmdir "$stage_dir" || return 1
    sync || return 1
    return 0
}

write_xovi_combined_shadow_pair() {
    test "$#" -eq 3 || return 2
    _write_xovi_shadow_pair combined "$1" "$2" "$3" || return 1
    return 0
}

write_xovi_safety_shadow_pair() {
    test "$#" -eq 3 || return 2
    _write_xovi_shadow_pair safety "$1" "$2" "$3" || return 1
    return 0
}
