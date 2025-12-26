#!/usr/bin/env bash
set -euo pipefail

echo "========================================="
echo " Disable Wayland (GDM3) - WaylandOnly"
echo "========================================="

# Must be root
if [ "${EUID}" -ne 0 ]; then
  echo "[ERROR] Jalankan sebagai root: sudo $0"
  exit 1
fi

GDM_CONF="/etc/gdm3/custom.conf"

if [ ! -f "$GDM_CONF" ]; then
  echo "[ERROR] File tidak ditemukan: $GDM_CONF"
  exit 1
fi

BACKUP="${GDM_CONF}.bak.$(date +%F_%H%M%S)"

echo "[1/4] Backup file..."
cp -a "$GDM_CONF" "$BACKUP"
echo "✔ Backup dibuat: $BACKUP"

echo "[2/4] Set WaylandEnable=false ..."

# Prioritas: jika ada "#WaylandEnable=false" -> uncomment
if grep -qE '^\s*#\s*WaylandEnable\s*=\s*false\s*$' "$GDM_CONF"; then
  sed -i 's/^\s*#\s*WaylandEnable\s*=\s*false\s*$/WaylandEnable=false/' "$GDM_CONF"

# Jika ada "#WaylandEnable=true" atau uncomment apapun -> paksa false
elif grep -qE '^\s*#\s*WaylandEnable\s*=' "$GDM_CONF"; then
  sed -i 's/^\s*#\s*WaylandEnable\s*=.*/WaylandEnable=false/' "$GDM_CONF"

# Jika sudah ada "WaylandEnable=..." -> paksa false
elif grep -qE '^\s*WaylandEnable\s*=' "$GDM_CONF"; then
  sed -i 's/^\s*WaylandEnable\s*=.*/WaylandEnable=false/' "$GDM_CONF"

# Jika tidak ada sama sekali -> tambahkan di akhir (rapi)
else
  printf "\nWaylandEnable=false\n" >> "$GDM_CONF"
fi

echo "✔ Konfigurasi diperbarui"

echo "[3/4] Tampilkan baris terkait..."
grep -nE '^\s*#?\s*WaylandEnable\s*=' "$GDM_CONF" || true

echo "[4/4] Selesai"
echo "-----------------------------------------"
echo "Agar perubahan aktif, pilih salah satu:"
echo "  (A) Reboot (disarankan):  sudo reboot"
echo "  (B) Restart GDM (logout GUI): sudo systemctl restart gdm3"
echo "-----------------------------------------"
echo "Verifikasi setelah login:"
echo "  echo \$XDG_SESSION_TYPE   # harusnya: x11"
