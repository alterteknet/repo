#!/usr/bin/env bash
set -euo pipefail

echo "========================================="
echo " Disable Wayland (GDM) Script"
echo " Targets: /etc/gdm3/custom.conf & /etc/gdm/custom.conf"
echo "========================================="

# Must be root
if [ "${EUID}" -ne 0 ]; then
  echo "[ERROR] Jalankan sebagai root: sudo $0"
  exit 1
fi

TS="$(date +%F_%H%M%S)"

update_gdm_conf() {
  local conf="$1"

  if [ ! -f "$conf" ]; then
    echo "[-] Skip (tidak ada): $conf"
    return 0
  fi

  local backup="${conf}.bak.${TS}"
  cp -a "$conf" "$backup"
  echo "[+] Backup dibuat: $backup"

  # Pastikan WaylandEnable=false
  if grep -qE '^\s*#\s*WaylandEnable\s*=\s*false\s*$' "$conf"; then
    sed -i 's/^\s*#\s*WaylandEnable\s*=\s*false\s*$/WaylandEnable=false/' "$conf"
  elif grep -qE '^\s*#\s*WaylandEnable\s*=' "$conf"; then
    sed -i 's/^\s*#\s*WaylandEnable\s*=.*/WaylandEnable=false/' "$conf"
  elif grep -qE '^\s*WaylandEnable\s*=' "$conf"; then
    sed -i 's/^\s*WaylandEnable\s*=.*/WaylandEnable=false/' "$conf"
  else
    printf "\nWaylandEnable=false\n" >> "$conf"
  fi

  echo "[+] Updated: $conf"
  echo "    Baris aktif:"
  grep -nE '^\s*WaylandEnable\s*=' "$conf" || true
}

echo "[1/2] Update konfigurasi GDM..."
update_gdm_conf "/etc/gdm3/custom.conf"
update_gdm_conf "/etc/gdm/custom.conf"

echo "[2/2] Selesai"
echo "-----------------------------------------"
echo "Agar perubahan aktif, pilih salah satu:"
echo "  (A) Reboot (disarankan):  sudo reboot"
echo "  (B) Restart GDM (logout GUI): sudo systemctl restart gdm3"
echo "-----------------------------------------"
echo "Verifikasi setelah login:"
echo "  echo \$XDG_SESSION_TYPE   # harusnya: x11"
echo "========================================="
