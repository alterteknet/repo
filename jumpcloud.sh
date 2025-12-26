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

echo "[1/4] Update repository..."
apt-get update -y >/dev/null
echo "✔ Repository updated"

echo "[2/4] Install dependencies (curl + pv)..."
apt-get install -y curl pv >/dev/null
echo "✔ curl dan pv terinstall"

echo "[3/4] Download & install JumpCloud Agent..."
echo "-----------------------------------------"
echo " Progress (download stream):"
echo "-----------------------------------------"

# Jalankan Kickstart + progress bar
curl --tlsv1.2 --silent --show-error \
  --header 'x-connect-key: jcc_eyJwdWJsaWNLaWNrc3RhcnRVcmwiOiJodHRwczovL2tpY2tzdGFydC5qdW1wY2xvdWQuY29tIiwicHJpdmF0ZUtpY2tzdGFydFVybCI6Imh0dHBzOi8vcHJpdmF0ZS1raWNrc3RhcnQuanVtcGNsb3VkLmNvbSIsImNvbm5lY3RLZXkiOiIzYWIxNTA0YTI2MmFiM2E4YTNmMzViMzE0MTRiNjdjMDcwODU0YTg1In0g' \
  https://kickstart.jumpcloud.com/Kickstart \
| pv -p -t -e -b \
| bash

echo "-----------------------------------------"
echo "[4/4] Verifikasi instalasi..."

# Service JumpCloud yang benar biasanya "jcagent"
if systemctl is-active --quiet jcagent; then
  echo "✅ INSTALLATION SUCCESS"
  echo "Service: jcagent (active)"
else
  echo "⚠️ Agent terinstall, tapi service belum aktif / nama service berbeda."
  echo "Coba cek service yang ada:"
  echo "  systemctl list-units --type=service | grep -i jc"
  echo ""
  echo "Log (jcagent):"
  echo "  journalctl -u jcagent --no-pager -n 100"
  exit 1
fi

echo "========================================="
echo " Selesai"
echo "========================================="
