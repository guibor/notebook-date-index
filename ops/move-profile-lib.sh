# NOTE: Dates revision 5 exact ten-QMD derivative of the qualified Move parser.
# All original checks remain; only the inventory count changes from nine to ten.
#!/bin/bash
# Parse the checked-in exact-device profile without evaluating it as shell code.

load_exact_move_profile() {
    local profile=${1:-}
    local line key value seen

    [ -n "$profile" ] || {
        echo "Profile path is required" >&2
        return 2
    }
    [ -f "$profile" ] && [ ! -L "$profile" ] || {
        echo "Profile must be a regular, non-symlink file: $profile" >&2
        return 2
    }
    case "$(LC_ALL=C file -b "$profile" 2>/dev/null || true)" in
        *CRLF*)
            echo "Profile must use Unix line endings" >&2
            return 2
            ;;
    esac

    seen=' '
    while IFS= read -r line || [ -n "$line" ]; do
        case "$line" in
            ''|'#'*) continue ;;
            *'='*) ;;
            *)
                echo "Malformed profile line: $line" >&2
                return 2
                ;;
        esac
        key=${line%%=*}
        value=${line#*=}
        case "$key" in
            PROFILE_SCHEMA|PROFILE_ID|DEVICE_KIND|DEVICE_VIRTUAL|\
            EXPECTED_MODEL|EXPECTED_SERIAL_SHA256|FIRMWARE_VERSION|EXPECTED_BUILD|\
            EXPECTED_XOCHITL_SHA256|EXPECTED_XOCHITL_BUILD_ID|\
            EXPECTED_XOVI_SHA256|EXPECTED_QRR_SHA256|\
            EXPECTED_ACTIVE_HASHTAB_SHA256|\
            EXPECTED_CANDIDATE_HASHTAB_SHA256|EXPECTED_VELLUM_VERSION|\
            EXPECTED_VELLUM_SHA256|EXPECTED_APK_VELLUM_SHA256|\
            EXPECTED_VELLUM_INSTALLED_DB_SHA256|\
            EXPECTED_REMARKABLE_OS_MARKER|EXPECTED_PREVIOUS_MARKER_VERSION|\
            EXPECTED_XOCHITL_RESTART|\
            EXPECTED_XOCHITL_RESTART_MODE|EXPECTED_XOCHITL_ON_FAILURE|\
            EXPECTED_XOCHITL_FRAGMENT|EXPECTED_XOCHITL_DROPIN|\
            EXPECTED_XOCHITL_VENDOR_UNIT_SHA256|\
            EXPECTED_XOCHITL_VENDOR_DROPIN_SHA256|\
            EXPECTED_XOVI_SHADOW_UNIT_SHA256|\
            EXPECTED_XOVI_COMBINED_DROPIN_SHA256|\
            EXPECTED_XOVI_SAFETY_DROPIN_SHA256|\
            QMLDIFF_COMMIT|QMLDIFF_SHA256|\
            QRC_COMMIT|QRC2ZIP_GO_VERSION|QRC2ZIP_BUILD_FLAGS|\
            QRC2ZIP_BUILD_TARGET|QRC2ZIP_BUILD_ID|QRC2ZIP_MACHO_UUID|\
            QRC2ZIP_CODESIGN_IDENTIFIER|QRC2ZIP_SHA256|\
            EXPECTED_QREGISTER_CALLS|EXPECTED_QRC_ROOTS|\
            EXPECTED_RESOURCE_FILE_COUNT|\
            EXPECTED_RESOURCE_IDENTICAL_DUPLICATES|\
            EXPECTED_RESOURCE_MANIFEST_SHA256|EXPECTED_QMD_COUNT|\
            EXPECTED_OLD_QMD_MANIFEST_SHA256|\
            EXPECTED_QMD_MANIFEST_SHA256|\
            EXPECTED_NINE_QMD_OUTPUT_COUNT|\
            EXPECTED_NINE_QMD_FILE_HASH_STREAM_SHA256)
                ;;
            *)
                echo "Unknown profile key: $key" >&2
                return 2
                ;;
        esac
        case "$seen" in
            *" $key "*)
                echo "Duplicate profile key: $key" >&2
                return 2
                ;;
        esac
        seen="$seen$key "
        printf -v "$key" '%s' "$value"
        export "$key"
    done <"$profile"

    [ "${PROFILE_SCHEMA:-}" = 1 ]
    [ "${PROFILE_ID:-}" = move-3.28.0.169 ]
    [ "${DEVICE_KIND:-}" = move ]
    [ "${DEVICE_VIRTUAL:-}" = rmppm ]
    [ "${EXPECTED_MODEL:-}" = 'reMarkable Chiappa' ]
    [[ "${EXPECTED_SERIAL_SHA256:-}" =~ ^[0-9a-f]{64}$ ]]
    [ "${FIRMWARE_VERSION:-}" = 3.28.0.169 ]
    [[ "${EXPECTED_BUILD:-}" =~ ^[0-9]{14}$ ]]
    for key in \
        EXPECTED_XOCHITL_SHA256 \
        EXPECTED_XOVI_SHA256 \
        EXPECTED_QRR_SHA256 \
        EXPECTED_ACTIVE_HASHTAB_SHA256 \
        EXPECTED_CANDIDATE_HASHTAB_SHA256 \
        EXPECTED_VELLUM_SHA256 \
        EXPECTED_APK_VELLUM_SHA256 \
        EXPECTED_VELLUM_INSTALLED_DB_SHA256 \
        EXPECTED_XOCHITL_VENDOR_UNIT_SHA256 \
        EXPECTED_XOCHITL_VENDOR_DROPIN_SHA256 \
        EXPECTED_XOVI_SHADOW_UNIT_SHA256 \
        EXPECTED_XOVI_COMBINED_DROPIN_SHA256 \
        EXPECTED_XOVI_SAFETY_DROPIN_SHA256 \
        QMLDIFF_SHA256 \
        QRC2ZIP_SHA256 \
        EXPECTED_RESOURCE_MANIFEST_SHA256 \
        EXPECTED_OLD_QMD_MANIFEST_SHA256 \
        EXPECTED_QMD_MANIFEST_SHA256 \
        EXPECTED_NINE_QMD_FILE_HASH_STREAM_SHA256
    do
        [[ "${!key:-}" =~ ^[0-9a-f]{64}$ ]] || {
            echo "Invalid SHA-256 in profile: $key" >&2
            return 2
        }
    done
    for key in EXPECTED_XOCHITL_BUILD_ID QMLDIFF_COMMIT QRC_COMMIT; do
        [[ "${!key:-}" =~ ^[0-9a-f]{40}$ ]] || {
            echo "Invalid 40-character identifier in profile: $key" >&2
            return 2
        }
    done
    [ "${EXPECTED_VELLUM_VERSION:-}" = 0.2.4-r0 ]
    [ "${EXPECTED_REMARKABLE_OS_MARKER:-}" = 3.26.0.68-r0 ]
    [ "${EXPECTED_PREVIOUS_MARKER_VERSION:-}" = \
        3.28.0.164_beta1-r0 ]
    [ "${EXPECTED_XOCHITL_RESTART:-}" = on-failure ]
    [ "${EXPECTED_XOCHITL_RESTART_MODE:-}" = direct ]
    [ "${EXPECTED_XOCHITL_ON_FAILURE:-}" = \
        'emergency.target remarkable-fail.service' ]
    [ "${EXPECTED_XOCHITL_FRAGMENT:-}" = \
        /usr/lib/systemd/system/xochitl.service ]
    [ "${EXPECTED_XOCHITL_DROPIN:-}" = \
        /usr/lib/systemd/system/xochitl.service.d/xochitl-service-override.conf ]
    [ "${QRC2ZIP_GO_VERSION:-}" = go1.22.2 ]
    [ "${QRC2ZIP_BUILD_FLAGS:-}" = -trimpath ]
    [ "${QRC2ZIP_BUILD_TARGET:-}" = ./cmd/qrc2zip ]
    [ "${QRC2ZIP_BUILD_ID:-}" = \
        qrc-aa2fe41e9e6ce60f98b8eb7e137abc754cb65431 ]
    [ "${QRC2ZIP_MACHO_UUID:-}" = \
        71d9f7c8-d85e-5e8c-bf13-fd34da77f409 ]
    [ "${QRC2ZIP_CODESIGN_IDENTIFIER:-}" = \
        org.remarkable-beta-os.qrc2zip ]
    [ "${EXPECTED_QREGISTER_CALLS:-}" = 197 ]
    [ "${EXPECTED_QRC_ROOTS:-}" = 99 ]
    [ "${EXPECTED_RESOURCE_FILE_COUNT:-}" = 1340 ]
    [ "${EXPECTED_RESOURCE_IDENTICAL_DUPLICATES:-}" = 2 ]
    [ "${EXPECTED_QMD_COUNT:-}" = 10 ]
    [ "${EXPECTED_NINE_QMD_OUTPUT_COUNT:-}" = 26 ]
}

assert_exact_move_identity() {
    local os_version actual
    actual=$(tr -d '\r\n' </sys/devices/soc0/machine) || return 1
    [ "$actual" = "$EXPECTED_MODEL" ] || return 1
    actual=$(tr -d '[:space:]' </sys/devices/soc0/serial_number) || return 1
    actual=$(printf '%s' "$actual" | sha256sum) || return 1
    actual=${actual%% *}
    [ "$actual" = "$EXPECTED_SERIAL_SHA256" ] || return 1
    os_version=$(
        awk -F= '$1 == "IMG_VERSION" {
            gsub(/^"|"$/, "", $2)
            print $2
        }' /etc/os-release
    ) || return 1
    [ "$os_version" = "$FIRMWARE_VERSION" ] || return 1
    actual=$(tr -d '[:space:]' </etc/version) || return 1
    [ "$actual" = "$EXPECTED_BUILD" ] || return 1
    actual=$(sha256sum /usr/bin/xochitl) || return 1
    actual=${actual%% *}
    [ "$actual" = "$EXPECTED_XOCHITL_SHA256" ] || return 1
    return 0
}
