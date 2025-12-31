#!/usr/bin/env bash
# ============================================================
# JumpCloud Agent Cleanup Script
# Purpose : Remove JumpCloud agent completely before reinstall
# OS      : Debian / Ubuntu
# ============================================================

set -e

# ------------------------------------------------------------
# Root check
# ------------------------------------------------------------
if [[ "$EUID" -ne 0 ]]; then
    echo "[ERROR] This script must be run as root."
    echo "        Please run: sudo $0"
    exit 1
fi

echo "[INFO] Starting JumpCloud Agent cleanup..."

# ------------------------------------------------------------
# Stop & disable service if exists
# ------------------------------------------------------------
if systemctl list-unit-files | grep -q jcagent.service; then
    echo "[INFO] Stopping JumpCloud agent service..."
    systemctl stop jcagent 2>/dev/null || true
    systemctl disable jcagent 2>/dev/null || true
else
    echo "[INFO] jcagent service not found. Skipping service stop."
fi

# ------------------------------------------------------------
# Remove package if installed
# ------------------------------------------------------------
if dpkg -l | grep -q jcagent; then
    echo "[INFO] Removing jcagent package..."
    apt-get remove --purge jcagent -y
else
    echo "[INFO] jcagent package not installed. Skipping removal."
fi

# ------------------------------------------------------------
# Remove leftover files & directories
# ------------------------------------------------------------
echo "[INFO] Removing leftover files..."
rm -rf /opt/jc
rm -f /etc/systemd/system/jcagent.service
rm -f /usr/lib/systemd/system/jcagent.service
rm -rf /var/log/jcagent
rm -rf /var/lib/jcagent

# ------------------------------------------------------------
# Reload systemd
# ------------------------------------------------------------
echo "[INFO] Reloading systemd daemon..."
systemctl daemon-reexec
systemctl daemon-reload

echo "[SUCCESS] JumpCloud Agent cleanup completed."
echo "[INFO] System is ready for a fresh JumpCloud installation."
