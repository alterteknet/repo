#!/bin/bash
################################################################################
# JumpCloud Agent Installer (Ubuntu only)
# - Install JumpCloud Agent
# - Verify jcagent
# - Disable Wayland (force X11 for Remote Assist)
################################################################################
set -e

if [[ "${UID}" != 0 ]]; then
    (>&2 echo "Error: $0 must be run as root")
    exit 1
fi

echo "========================================="
echo " JumpCloud Agent Installer (Ubuntu)"
echo "========================================="

# ------------------------------------------------------------------
# Step 1: Update repo & install deps
# ------------------------------------------------------------------
echo "[1/7] Update repository..."
apt-get update -y >/dev/null
echo "✔ apt update done"

echo "[2/7] Install dependencies (curl + pv)..."
apt-get install -y curl pv >/dev/null
echo "✔ dependencies installed"

# ------------------------------------------------------------------
# Step 2: Install JumpCloud Agent
# ------------------------------------------------------------------
echo "[3/7] Install JumpCloud Agent (Kickstart)..."
echo "-----------------------------------------"

curl --tlsv1.2 --silent --show-error \
  --header 'x-connect-key: jcc_eyJwdWJsaWNLaWNrc3RhcnRVcmwiOiJodHRwczovL2tpY2tzdGFydC5qdW1wY2xvdWQuY29tIiwicHJpdmF0ZUtpY2tzdGFydFVybCI6Imh0dHBzOi8vcHJpdmF0ZS1raWNrc3RhcnQuanVtcGNsb3VkLmNvbSIsImNvbm5lY3RLZXkiOiIzYWIxNTA0YTI2MmFiM2E4YTNmMzViMzE0MTRiNjdjMDcwODU0YTg1In0g' \
  https://kickstart.jumpcloud.com/Kickstart \
| pv -p -t -e -b \
| bash

echo "-----------------------------------------"

# ------------------------------------------------------------------
# Step 3: Verify JumpCloud service
# ------------------------------------------------------------------
echo "[4/7] Verify JumpCloud service (jcagent)..."

systemctl daemon-reload >/dev/null 2>&1 || true

if systemctl is-active --quiet jcagent; then
    echo "✅ JumpCloud Agent aktif (jcagent)"
else
    echo "❌ JumpCloud Agent tidak aktif"
    systemctl status jcagent --no-pager || true
    journalctl -u jcagent --no-pager -n 50 || true
    exit 1
fi

# ------------------------------------------------------------------
# Step 4: Detect current windowing system
# ------------------------------------------------------------------
echo "[5/7] Detect current windowing system..."

windowingSystem="${XDG_SESSION_TYPE:-}"
if [[ -z "$windowingSystem" ]]; then
    windowingSystem="$(loginctl show-session \
        "$(loginctl list-sessions --no-legend | awk 'NR==1{print $1}')" \
        -p Type 2>/dev/null | awk -F= '{print $2}')"
fi

echo "Current windowing system: ${windowingSystem:-unknown}"

# ------------------------------------------------------------------
# Step 5: Disable Wayland (Ubuntu GDM3)
# ------------------------------------------------------------------
echo "[6/7] Disable Wayland (Ubuntu /etc/gdm3/custom.conf)..."

GDM_CONF="/etc/gdm3/custom.conf"

if [[ -f "$GDM_CONF" ]]; then
    BACKUP="${GDM_CONF}.bak.$(date +%F_%H%M%S)"
    cp -a "$GDM_CONF" "$BACKUP"
    echo "✔ Backup created: $BACKUP"

    if grep -qE '^\s*#?\s*WaylandEnable\s*=' "$GDM_CONF"; then
        sed -i 's/^\s*#\?\s*WaylandEnable\s*=.*/WaylandEnable=false/' "$GDM_CONF"
    else
        echo "" >> "$GDM_CONF"
        echo "WaylandEnable=false" >> "$GDM_CONF"
    fi

    echo "✔ Wayland disabled in config:"
    grep -nE '^\s*WaylandEnable\s*=' "$GDM_CONF" || true
else
    echo "⚠️ $GDM_CONF not found, skip Wayland configuration"
fi

# ------------------------------------------------------------------
# Step 6: Finish & apply notice
# ------------------------------------------------------------------
echo "[7/7] Finished"
echo "-----------------------------------------"
echo "IMPORTANT:"
echo "- Wayland config sudah diubah"
echo "- Session AKTIF masih: ${windowingSystem:-unknown}"
echo ""
echo "Agar JumpCloud Remote Assist berfungsi:"
echo "  (A) Reboot (disarankan): sudo reboot"
echo "  (B) Restart GDM3 (logout GUI): sudo systemctl restart gdm3"
echo ""
echo "Verifikasi setelah login:"
echo "  echo \$XDG_SESSION_TYPE   # harus: x11"
echo "========================================="

# Optional auto-apply
if [[ "${APPLY_GDM_RESTART:-0}" == "1" ]]; then
    echo "APPLY_GDM_RESTART=1 → Restarting gdm3 in 5 seconds..."
    sleep 5
    systemctl restart gdm3
fi

exit 0
