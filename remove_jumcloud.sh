#!/bin/bash

# Cek apakah dijalankan sebagai root
if [ "$EUID" -ne 0 ]; then
  echo "Script ini harus dijalankan sebagai root."
  echo "Silakan jalankan: sudo su"
  exit 1
fi

set -e

echo "Stopping jcagent service..."
service jcagent stop || true

echo "Purging jecagent package..."
apt-get purge -y jcagent

echo "Removing /opt/jc directory..."
rm -rf /opt/jc

echo "Removing jc_user_ro..."
rm -rf jc_user_ro

echo "System akan reboot dalam:"
for i in 4 3 2 1; do
  echo "$i..."
  sleep 1
done

echo "Rebooting now!"
reboot
