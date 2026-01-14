#!/bin/bash

###############################################################################
# Voyager SDK Device Validation Script
# This script validates that the Voyager SDK can detect devices correctly
###############################################################################

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# ===========================================================================
# CONFIGURATION - MODIFY THESE LINES FOR YOUR ENVIRONMENT
# ===========================================================================

# Docker container name - CHANGE THIS to match your container
DOCKER_CONTAINER="your-voyager-container-name"

# Path to voyager-sdk inside the docker container - CHANGE THIS if different
VOYAGER_SDK_PATH="/path/to/voyager-sdk"

# ===========================================================================

echo "========================================"
echo "Voyager SDK Device Validation"
echo "========================================"
echo ""

# Check if Docker is available
if ! command -v docker &> /dev/null; then
    echo -e "${RED}[FAILED]${NC} Docker is not installed or not in PATH"
    exit 1
fi

# Check if the container exists and is running
if ! docker ps --format '{{.Names}}' | grep -q "^${DOCKER_CONTAINER}$"; then
    echo -e "${RED}[FAILED]${NC} Docker container '${DOCKER_CONTAINER}' is not running"
    echo "Please check your container name and ensure it's running with: docker ps"
    exit 1
fi

echo -e "${GREEN}[OK]${NC} Docker container '${DOCKER_CONTAINER}' is running"
echo ""

# Execute the validation command in the Docker container
echo "Executing device detection command..."
echo "Command: cd ${VOYAGER_SDK_PATH} && source venv/bin/activate && axdevice"
echo ""

# Run the command and capture output
DEVICE_OUTPUT=$(docker exec ${DOCKER_CONTAINER} bash -c "cd ${VOYAGER_SDK_PATH} && source venv/bin/activate && axdevice 2>&1")
EXIT_CODE=$?

# Display the output
echo "Output:"
echo "----------------------------------------"
echo "${DEVICE_OUTPUT}"
echo "----------------------------------------"
echo ""

# Check if command execution failed
if [ $EXIT_CODE -ne 0 ]; then
    echo -e "${RED}[FAILED]${NC} Command execution failed with exit code: ${EXIT_CODE}"
    echo "Please verify:"
    echo "  1. The path to voyager-sdk (${VOYAGER_SDK_PATH}) is correct"
    echo "  2. The virtual environment exists in voyager-sdk/venv"
    echo "  3. The axdevice command is properly installed"
    exit 1
fi

# Check if the expected device pattern is found
if echo "${DEVICE_OUTPUT}" | grep -q "^Device 0: metis-0:1:0"; then
    echo -e "${GREEN}[PASS]${NC} Voyager SDK device detected successfully!"
    echo "Device validation completed successfully."
    exit 0
else
    echo -e "${RED}[FAILED]${NC} Expected device pattern not found"
    echo "Expected output starting with: 'Device 0: metis-0:1:0'"
    echo ""
    echo "Please check:"
    echo "  1. Device drivers are properly installed"
    echo "  2. Device permissions are correctly configured"
    echo "  3. The Voyager SDK is properly set up"
    exit 1
fi
