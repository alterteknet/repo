#!/usr/bin/env bash
# ============================================================
# Restart Remote Assist
# - System service : root / sudoers
# - User service   : non-root & NON-sudoers
#   hanya jika DBUS user bus tersedia
# ============================================================

set -euo pipefail

REAL_USER="${SUDO_USER:-$USER}"
UID_NUM="$(id -u "$REAL_USER")"

is_sudoers() {
    id -nG "$REAL_USER" | grep -qw sudo
}

echo "[INFO] Real user : $REAL_USER"

# ------------------------------------------------------------
# 1) SYSTEM SERVICE
# ------------------------------------------------------------
if [[ "$EUID" -eq 0 ]]; then
    echo "[INFO] Restart system service (root)"
    systemctl restart remote-assist-service
elif is_sudoers; then
    echo "[INFO] Restart system service (sudo)"
    sudo systemctl restart remote-assist-service
else
    echo "[SKIP] User bukan sudoers → system service tidak direstart"
fi

# ------------------------------------------------------------
# 2) USER SERVICE (non-root & NON-sudoers only)
# ------------------------------------------------------------
if [[ "$REAL_USER" == "root" ]]; then
    echo "[SKIP] Root user → user service tidak dijalankan"
elif is_sudoers; then
    echo "[SKIP] '$REAL_USER' sudoers → user service tidak dijalankan"
else
    USER_BUS="/run/user/$UID_NUM/bus"

    if [[ ! -S "$USER_BUS" ]]; then
        echo "[SKIP] DBUS user bus tidak tersedia ($USER_BUS)"
        echo "       User kemungkinan belum login / tidak ada session"
        exit 0
    fi

    export XDG_RUNTIME_DIR="/run/user/$UID_NUM"
    export DBUS_SESSION_BUS_ADDRESS="unix:path=$USER_BUS"

    if [[ "$EUID" -eq 0 ]]; then
        echo "[INFO] Restart user service sebagai '$REAL_USER' (root → user)"
        runuser -u "$REAL_USER" -- \
            systemctl --user restart remote-assist-launcher
    else
        echo "[INFO] Restart user service (non-root)"
        systemctl --user restart remote-assist-launcher
    fi
fi

echo "[DONE] Semua proses selesai"
