#!/usr/bin/env bash
set -Eeuo pipefail

GRUB_FILE="/etc/default/grub"
KEY="GRUB_CMDLINE_LINUX"
STEP="INIT"
BACKUP=""

# ================================
# ERROR HANDLER: tampilkan error tiap phase
# ================================
on_error() {
  local ec=$?
  local line=${BASH_LINENO[0]:-?}
  local cmd=${BASH_COMMAND:-?}

  echo
  echo "❌ ERROR TERJADI!"
  echo "   Phase     : $STEP"
  echo "   Line      : $line"
  echo "   Command   : $cmd"
  echo "   Exit code : $ec"
  if [[ -n "${BACKUP:-}" && -f "${BACKUP:-}" ]]; then
    echo "   Backup    : $BACKUP"
    echo "   Restore   : sudo cp -a '$BACKUP' '$GRUB_FILE'"
  fi
  echo
  exit "$ec"
}
trap on_error ERR

phase() {
  STEP="$1"
  echo
  echo "▶ PHASE: $STEP"
}

ok() {
  echo "✅ OK: $STEP"
}

# ================================
# Secure Boot check helper
# ================================
detect_secure_boot() {
  # returns:
  # 0 => enabled
  # 1 => disabled
  # 2 => unknown / cannot detect
  if command -v mokutil >/dev/null 2>&1; then
    if mokutil --sb-state 2>/dev/null | grep -qi "enabled"; then
      return 0
    elif mokutil --sb-state 2>/dev/null | grep -qi "disabled"; then
      return 1
    else
      return 2
    fi
  fi

  # fallback: efivars (UEFI only)
  if [[ -r /sys/firmware/efi/efivars ]] && compgen -G "/sys/firmware/efi/efivars/SecureBoot-*" >/dev/null; then
    # value is last byte; 01 enabled, 00 disabled (best-effort)
    local val
    val="$(hexdump -v -e '1/1 "%02x"' /sys/firmware/efi/efivars/SecureBoot-* 2>/dev/null | tail -c 2 || true)"
    [[ "$val" == "01" ]] && return 0
    [[ "$val" == "00" ]] && return 1
    return 2
  fi

  # fallback: bootctl (systemd-boot env)
  if command -v bootctl >/dev/null 2>&1; then
    if bootctl status 2>/dev/null | grep -qi "Secure Boot:.*enabled"; then
      return 0
    elif bootctl status 2>/dev/null | grep -qi "Secure Boot:.*disabled"; then
      return 1
    else
      return 2
    fi
  fi

  return 2
}

# ================================
# PHASE 1: ROOT CHECK
# ================================
phase "ROOT CHECK"
if [[ "${EUID}" -ne 0 ]]; then
  echo "❌ Script harus dijalankan sebagai root."
  echo "   Jalankan: sudo bash $0"
  exit 1
fi
ok

# ================================
# PHASE 2: SECURE BOOT CHECK (warning only)
# ================================
phase "SECURE BOOT CHECK"
if command -v mokutil >/dev/null 2>&1; then
  SB_RAW="$(mokutil --sb-state 2>/dev/null || true)"
  echo "▶ mokutil: ${SB_RAW:-"(no output)"}"
else
  echo "ℹ️  mokutil belum terpasang. (Opsional) install: sudo apt install mokutil"
fi

if detect_secure_boot; then
  echo "⚠️  Secure Boot terdeteksi: ENABLED"
  echo "   Disarankan DISABLE Secure Boot di BIOS untuk kompatibilitas driver/boot tertentu."
elif [[ $? -eq 1 ]]; then
  echo "✅ Secure Boot terdeteksi: DISABLED"
else
  echo "ℹ️  Secure Boot status: UNKNOWN (mungkin BIOS legacy/non-UEFI, atau akses efivars dibatasi)"
fi
ok

# ================================
# PHASE 3: CHECK GRUB FILE
# ================================
phase "CHECK GRUB FILE"
[[ -f "$GRUB_FILE" ]] || { echo "❌ File tidak ditemukan: $GRUB_FILE"; exit 1; }
ok

# ================================
# PHASE 4: CHECK KEY EXISTS (kalau tidak ada, tambahkan)
# ================================
phase "CHECK KEY EXISTS"
if ! grep -Eq "^${KEY}=" "$GRUB_FILE"; then
  echo "ℹ️  ${KEY} tidak ditemukan, menambahkan baris default..."
  echo "${KEY}=\"\"" >> "$GRUB_FILE"
fi
ok

# ================================
# PHASE 5: READ CURRENT
# ================================
phase "READ CURRENT VALUE"
CURRENT="$(grep -E "^${KEY}=" "$GRUB_FILE" | head -n1)"
echo "▶ Current: $CURRENT"
ok

# ================================
# PHASE 6: CPU DETECTION (FIX multi-line issue)
# ================================
phase "CPU DETECTION"

CPU_VENDOR="$(
  lscpu 2>/dev/null \
  | awk -F: '/^Vendor ID:/ {gsub(/^[ \t]+/, "", $2); print $2; exit}'
)"

# fallback kalau format lscpu berbeda
if [[ -z "${CPU_VENDOR:-}" ]]; then
  CPU_VENDOR="$(grep -m1 -E '^vendor_id' /proc/cpuinfo | awk '{print $3}' || true)"
fi

echo "▶ Vendor ID: ${CPU_VENDOR:-UNKNOWN}"

if [[ "$CPU_VENDOR" == "GenuineIntel" ]]; then
  NEW_VALUE="${KEY}=\"intel_iommu=off\""
  CPU_NAME="INTEL"
elif [[ "$CPU_VENDOR" == "AuthenticAMD" ]]; then
  NEW_VALUE="${KEY}=\"amd_iommu=off\""
  CPU_NAME="AMD"
else
  echo "❌ CPU vendor tidak dikenali. Vendor ID terbaca: '${CPU_VENDOR:-KOSONG}'"
  exit 1
fi

echo "▶ CPU detected : $CPU_NAME"
echo "▶ New setting  : $NEW_VALUE"
ok

# ================================
# PHASE 7: BACKUP
# ================================
phase "BACKUP GRUB"
BACKUP="/etc/default/grub.backup.$(date +%Y%m%d_%H%M%S)"
cp -a "$GRUB_FILE" "$BACKUP"
echo "📦 Backup: $BACKUP"
ok

# ================================
# PHASE 8: UPDATE ONLY THAT LINE
# ================================
phase "UPDATE ${KEY} LINE"
sed -i "s|^${KEY}=.*|${NEW_VALUE}|" "$GRUB_FILE"
ok

# ================================
# PHASE 9: VERIFY
# ================================
phase "VERIFY RESULT"
AFTER="$(grep -E "^${KEY}=" "$GRUB_FILE" | head -n1)"
echo "▶ Updated: $AFTER"

if [[ "$AFTER" != "$NEW_VALUE" ]]; then
  echo "❌ Verifikasi gagal."
  echo "   Target : $NEW_VALUE"
  echo "   Actual : $AFTER"
  exit 1
fi
ok

# ================================
# PHASE 10: UPDATE GRUB
# ================================
phase "RUN update-grub"
if command -v update-grub >/dev/null 2>&1; then
  update-grub
elif command -v grub2-mkconfig >/dev/null 2>&1; then
  if [[ -f /boot/grub2/grub.cfg ]]; then
    grub2-mkconfig -o /boot/grub2/grub.cfg
  elif compgen -G "/boot/efi/EFI/*/grub.cfg" >/dev/null; then
    grub2-mkconfig -o /boot/efi/EFI/*/grub.cfg
  else
    echo "❌ Tidak bisa menentukan path grub.cfg untuk grub2-mkconfig."
    exit 1
  fi
else
  echo "❌ Perintah update-grub / grub2-mkconfig tidak ditemukan."
  exit 1
fi
ok

# ================================
# DONE + BIOS REMINDER
# ================================
phase "DONE"
echo
echo "=============================================="
echo "✅ CONFIGURATION DONE"
echo
echo "PLEASE CHECK BIOS SETTINGS:"
echo "- ReBAR             : ENABLE"
echo "- Above 4G Decoding : ENABLE"
echo "- Secure Boot       : DISABLE"
echo "=============================================="
echo
echo "Please reboot using command:"
echo "sudo reboot"
echo
ok
