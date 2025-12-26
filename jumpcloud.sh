#!/usr/bin/env bash
set -e

echo "========================================="
echo " JumpCloud Agent Installation Script"
echo "========================================="

# Pastikan dijalankan sebagai root
if [ "$EUID" -ne 0 ]; then
  echo "[ERROR] Script harus dijalankan sebagai root (sudo)."
  exit 1
fi

echo "[1/4] Update repository..."
apt-get update -y >/dev/null
echo "✔ Repository updated"

echo "[2/4] Install curl & pv (progress bar)..."
apt-get install -y curl pv >/dev/null
echo "✔ curl dan pv terinstall"

echo "[3/4] Download & install JumpCloud Agent..."
echo "-----------------------------------------"
echo " Progress:"
echo "-----------------------------------------"

curl --tlsv1.2 --silent --show-error \
  --header 'x-connect-key: jcc_eyJwdWJsaWNLaWNrc3RhcnRVcmwiOiJodHRwczovL2tpY2tzdGFydC5qdW1wY2xvdWQuY29tIiwicHJpdmF0ZUtpY2tzdGFydFVybCI6Imh0dHBzOi8vcHJpdmF0ZS1raWNrc3RhcnQuanVtcGNsb3VkLmNvbSIsImNvbm5lY3RLZXkiOiIzYWIxNTA0YTI2MmFiM2E4YTNmMzViMzE0MTRiNjdjMDcwODU0YTg1In0g' \
  https://kickstart.jumpcloud.com/Kickstart \
| pv -p -t -e -b \
| bash

echo "-----------------------------------------"
echo "[4/4] Verifikasi instalasi..."

if systemctl status jumpcloud-agent >/dev/null 2>&1; then
  echo "✅ INSTALLATION SUCCESS"
  echo "JumpCloud Agent berjalan dengan 정상"
else
  echo "❌ INSTALLATION FAILED"
  echo "Cek log dengan:"
  echo "journalctl -u jumpcloud-agent --no-pager"
  exit 1
fi

echo "========================================="
echo " Selesai"
echo "========================================="

