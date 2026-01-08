#!/bin/bash
# ============================================================
# Enable automatic login for user AI-SPPG on Ubuntu (GDM3)
# ============================================================

AUTOLOGIN_USER="AI-SPPG"
GDM_CONF="/etc/gdm3/custom.conf"

# Must be run as root
if [[ "$EUID" -ne 0 ]]; then
  echo "❌ This script must be run as root"
  exit 1
fi

echo "🔧 Enabling auto-login for user: $AUTOLOGIN_USER"

# Backup existing config
if [[ ! -f "${GDM_CONF}.bak" ]]; then
  cp "$GDM_CONF" "${GDM_CONF}.bak"
  echo "📦 Backup created: ${GDM_CONF}.bak"
fi

# Enable AutomaticLogin
sed -i 's/^#\?\s*AutomaticLoginEnable\s*=.*/AutomaticLoginEnable=true/' "$GDM_CONF"

# Set user
if grep -q "^AutomaticLogin=" "$GDM_CONF"; then
  sed -i "s/^AutomaticLogin=.*/AutomaticLogin=${AUTOLOGIN_USER}/" "$GDM_CONF"
else
  sed -i "/^\[daemon\]/a AutomaticLogin=${AUTOLOGIN_USER}" "$GDM_CONF"
fi

echo "✅ Auto-login configured for $AUTOLOGIN_USER"
echo "🔄 Please reboot to apply changes"
