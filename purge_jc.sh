#!/bin/bash
# JumpCloud Agent Cleanup Script

echo "Stopping JumpCloud agent..."
sudo systemctl stop jcagent 2>/dev/null
sudo systemctl disable jcagent 2>/dev/null

echo "Removing package..."
sudo apt remove --purge jcagent -y 2>/dev/null

echo "Removing files..."
sudo rm -rf /opt/jc
sudo rm -f /etc/systemd/system/jcagent.service
sudo rm -f /usr/lib/systemd/system/jcagent.service

echo "Reloading systemd..."
sudo systemctl daemon-reload

echo "Done! Ready for fresh install."