#!/usr/bin/env bash
set -euo pipefail

echo "========================================="
echo " Disable Wayland (GDM3) Script"
echo "========================================="

# Harus root
if [ "${EUID}" -ne 0 ]; then
  echo "[ERROR] Jalankan sebagai root: sudo $0"
  exit 1
fi

GDM_CONF="/etc/gdm3/custom.conf"
BACKUP="${GDM_CONF}.bak.$(date +%F_%H%M%S)"

if [ ! -f "$GDM_CONF" ]; then
  echo "[ERROR] File tidak ditemukan: $GDM_CONF"
  exit 1
fi

echo "[1/3] Backup config..."
cp "$GDM_CONF" "$BACKUP"
echo "✔ Backup dibuat: $BACKUP"

echo "[2/3] Set WaylandEnable=false ..."
# Jika ada baris WaylandEnable (comment/uncomment), set jadi false
if grep -Eq '^\s*#?\s*WaylandEnable\s*=' "$GDM_CONF"; then
  sed -i 's/^\s*#\?\s*WaylandEnable\
