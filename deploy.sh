#!/usr/bin/env bash

set -Eeuo pipefail  # Exit on error, unset variables, pipe failures
# set -x		 	# Print commands and their arguments as they are executed.

die() {
    set +xe
    echo '================================ DIE ===============================' >&2
    echo >&2 "$*"
    echo >&2 "Call stack:"
    local n=$((${#BASH_LINENO[@]} - 1))
    local i=0
    while [ $i -lt $n ]; do
        echo >&2 "    [$i] -- line ${BASH_LINENO[i]} -- ${FUNCNAME[i + 1]}"
        i=$((i + 1))
    done
    echo >&2 '================================ END ==============================='
    exit 1
}

# Absolute, so the script works no matter which directory it is called from.
SRC_DIR="$(CDPATH='' cd "$(dirname "$0")" && pwd -P)"
DST_DIR=
LOCAL_MODE=

while [ $# -gt 0 ] && [[ "$1" = -* ]]; do
    case "$1" in
        -l|--local)  LOCAL_MODE=1 ;;
        *) die "Unrecognized opt: $1, showing usage." "$(help)" ;;
    esac
    shift
done

case $(uname) in
    Linux)
        if [[ -n "${LOCAL_MODE}" ]]; then
            DST_DIR="${HOME}/.config/koreader/plugins"
        else
            DST_DIR="/var/run/media/${USER}/Kindle/koreader/plugins"
        fi
        ;;
    *) ;;
esac


[[ -z "${DST_DIR}" ]] && die "Failed to detect destination directory for $(uname)\n"
[[ -e "${DST_DIR}" ]] || die "Destination director does not exist: ${DST_DIR}"

KOR_ROOT="${DST_DIR%/plugins}"

# Plugin submodules live in <repo>/plugins and deploy as the device's koreader/plugins.
for fn in "${SRC_DIR}"/plugins/*; do
    if ! [[ -d "$fn" ]]; then
        continue
    fi
    echo "Deploying: ${fn##*/}"
    rsync -Pavh -c --delete --delete-excluded --exclude-from="${SRC_DIR}/rsync-excludes.txt" "${fn}" "${DST_DIR}/"
done

# User patches and their icons live outside koreader/plugins: patches are read from
# <koreader>/patches (DataStorage:getPatchesDir()), icons from <koreader>/icons
# (IconWidget's user icon dir). No --delete: the device may carry patches of its own.
if [[ -d "${SRC_DIR}/patches" ]]; then
    mkdir -p "${KOR_ROOT}/patches" "${KOR_ROOT}/icons"
    echo "Deploying: patches -> ${KOR_ROOT}/patches"
    rsync -Pavh -c --exclude=/icons/ "${SRC_DIR}/patches/" "${KOR_ROOT}/patches/"
    echo "Deploying: patches/icons -> ${KOR_ROOT}/icons"
    rsync -Pavh -c "${SRC_DIR}/patches/icons/" "${KOR_ROOT}/icons/"
fi
