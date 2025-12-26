#!/usr/bin/env bash
set -euo pipefail

echo "========================================="
echo " JumpCloud Agent Installation Script"
echo "========================================="

# Harus root
if [ "${EUID}" -ne 0 ]; then
  echo "[ERROR] Jalankan sebagai root: sudo $0"
  exit 1
fi

echo "[1/5] Update repository..."
apt-get update -y >/dev/null
echo "✔ Repository updated"

echo "[2/5] Install dependencies (curl + pv)..."
apt-get install -y curl pv >/dev/null
echo "✔ curl dan pv terinstall"

echo "[3/5] Download & install JumpCloud Agent..."
echo "-----------------------------------------"
echo " Progress (download stream):"
echo "-----------------------------------------"

curl --tlsv1.2 --silent --show-error \
  --header 'x-connect-key: jcc_eyJwdWJsaWNLaWNrc3RhcnRVcmwiOiJodHRwczovL2tpY2tzdGFydC5qdW1wY2xvdWQuY29tIiwicHJpdmF0ZUtpY2tzdGFydFVybCI6Imh0dHBzOi8vcHJpdmF0ZS1raWNrc3RhcnQuanVtcGNsb3VkLmNvbSIsImNvbm5lY3RLZXkiOiIzYWIxNTA0YTI2MmFiM2E4YTNmMzViMzE0MTRiNjdjMDcwODU0YTg1In0g' \
  https://kickstart.jumpcloud.com/Kickstart \
| pv -p -t -e -b \
| bash

echo "-----------------------------------------"
echo "[4/5] Verifikasi instalasi JumpCloud Agent..."

if systemctl is-active --quiet jcagent; then
  echo "✅ JumpCloud Agent aktif (jcagent)"
else
  echo "❌ JumpCloud Agent tidak aktif"
  echo "Cek log:"
  journalctl -u jcagent --no-pager -n 50
  exit 1
fi

echo "-----------------------------------------"
echo "[5/5] Disable Wayland (GDM3)..."

GDM_CONF="/etc/gdm3/custom.conf"
BACKUP="${GDM_CONF}.bak.$(date +%F_%H%M%S)"

# Backup config
cp "$GDM_CONF" "$BACKUP"
echo "✔ Backup dibuat: $BACKUP"

# Jika ada WaylandEnable (comment/uncomment), set ke false
if grep -Eq '^\s*#?\s*WaylandEnable\s*=' "$GDM_CONF"; then
  sed -i 's/^\s*#\?\s*WaylandEnable\s*=.*/WaylandEnable=false/' "$GDM_CONF"
  echo "✔ WaylandEnable diset ke false"
else
  echo "WaylandEnable=false" >> "$GDM_CONF"
  echo "✔ WaylandEnable ditambahkan ke file"
fi

echo "========================================="
echo " SEMUA STEP SELESAI"
echo "========================================="
echo "⚠️ REBOOT diperlukan agar perubahan Wayland berlaku"
echo "   Jalankan: sudo reboot"
