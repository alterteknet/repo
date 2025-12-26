#!/usr/bin/env bash
set -euo pipefail

echo "========================================="
echo " JumpCloud Agent + Disable Wayland Script"
echo "========================================="

# Pastikan root
if [ "${EUID}" -ne 0 ]; then
  echo "[ERROR] Jalankan sebagai root: sudo $0"
  exit 1
fi

# ---------- STEP 1: Update repo ----------
echo "[1/6] apt-get update..."
apt-get update -y >/dev/null
echo "✔ Repository updated"

# ---------- STEP 2: Install deps ----------
echo "[2/6] Install dependencies (curl + pv)..."
apt-get install -y curl pv >/dev/null
echo "✔ curl dan pv terinstall"

# ---------- STEP 3: Run JumpCloud Kickstart ----------
echo "[3/6] Install JumpCloud Agent (Kickstart)..."
echo "-----------------------------------------"
echo " Progress (download stream):"
echo "-----------------------------------------"

curl --tlsv1.2 --silent --show-error \
  --header 'x-connect-key: jcc_eyJwdWJsaWNLaWNrc3RhcnRVcmwiOiJodHRwczovL2tpY2tzdGFydC5qdW1wY2xvdWQuY29tIiwicHJpdmF0ZUtpY2tzdGFydFVybCI6Imh0dHBzOi8vcHJpdmF0ZS1raWNrc3RhcnQuanVtcGNsb3VkLmNvbSIsImNvbm5lY3RLZXkiOiIzYWIxNTA0YTI2MmFiM2E4YTNmMzViMzE0MTRiNjdjMDcwODU0YTg1In0g' \
  https://kickstart.jumpcloud.com/Kickstart \
| pv -p -t -e -b \
| bash

echo "-----------------------------------------"
echo "[4/6] Verifikasi JumpCloud service (jcagent)..."

# pastikan systemd kenal service terbaru
systemctl daemon-reload >/dev/null 2>&1 || true

if systemctl is-active --quiet jcagent; then
  echo "✅ JumpCloud Agent aktif (jcagent)"
else
  echo "❌ JumpCloud Agent tidak aktif (jcagent)"
  echo "Cek status:"
  systemctl status jcagent --no-pager || true
  echo "Cek log:"
  journalctl -u jcagent --no-pager -n 100 || true
  exit 1
fi

# ---------- STEP 5: Disable Wayland ----------
echo "-----------------------------------------"
echo "[5/6] Disable Wayland (GDM3) ..."

GDM_CONF="/etc/gdm3/custom.conf"

if [ -f "$GDM_CONF" ]; then
  BACKUP="${GDM_CONF}.bak.$(date +%F_%H%M%S)"
  cp -a "$GDM_CONF" "$BACKUP"
  echo "✔ Backup dibuat: $BACKUP"

  # Ubah #WaylandEnable=false -> WaylandEnable=false
  if grep -qE '^\s*#\s*WaylandEnable\s*=\s*false\s*$' "$GDM_CONF"; then
    sed -i 's/^\s*#\s*WaylandEnable\s*=\s*false\s*$/WaylandEnable=false/' "$GDM_CONF"
  # Kalau ada parameter lain (true/false, comment/uncomment), paksa false
  elif grep -qE '^\s*#?\s*WaylandEnable\s*=' "$GDM_CONF"; then
    sed -i 's/^\s*#\?\s*WaylandEnable\s*=.*/WaylandEnable=false/' "$GDM_CONF"
  else
    printf "\nWaylandEnable=false\n" >> "$GDM_CONF"
  fi

  echo "✔ WaylandEnable diset ke false"
  echo "Baris aktif:"
  grep -nE '^\s*WaylandEnable\s*=' "$GDM_CONF" || true
else
  echo "⚠️ File $GDM_CONF tidak ditemukan. Skip disable Wayland."
fi

# ---------- STEP 6: Finish ----------
echo "-----------------------------------------"
echo "[6/6] Selesai"
echo "✅ JumpCloud: OK"
echo "✅ Wayland: konfigurasi sudah di-set (butuh reboot / restart gdm3)"
echo ""
echo "Agar perubahan Wayland aktif, pilih salah satu:"
echo "  (A) Reboot (disarankan):  sudo reboot"
echo "  (B) Restart GDM (logout GUI): sudo systemctl restart gdm3"
echo "Verifikasi setelah login:"
echo "  echo \$XDG_SESSION_TYPE   # harusnya: x11"
echo "========================================="
