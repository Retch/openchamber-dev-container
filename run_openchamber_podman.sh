#!/usr/bin/env bash

set -e

# ==========================================
# CONFIGURATION
# ==========================================
IMAGE_NAME="openchamber-fedora:latest"
CONTAINER_NAME="openchamber-server"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

HOST_PORT="3000"
UI_PASSWORD="SecurePassword42"
CONTAINER_CONFIG_FILE="${SCRIPT_DIR}/container.conf"
if [ -f "${CONTAINER_CONFIG_FILE}" ]; then
    # shellcheck source=/dev/null
    source "${CONTAINER_CONFIG_FILE}"
fi

# The environment variable wins over the config file.
UI_PASSWORD="${OPENCHAMBER_UI_PASSWORD:-${UI_PASSWORD}}"

# The version conf files are the single source of truth, there is no fallback
# version in this script or in the Dockerfile.
load_version_config() {
    local config_file="$1"
    if [ ! -f "${config_file}" ]; then
        echo "ERROR: ${config_file} is missing." >&2
        exit 1
    fi
    # shellcheck source=/dev/null
    source "${config_file}"
}

load_version_config "${SCRIPT_DIR}/node-versions.conf"
: "${NODE_VERSION:?NODE_VERSION is not set in node-versions.conf}"
EXTRA_NODE_VERSIONS="${EXTRA_NODE_VERSIONS:-}"

load_version_config "${SCRIPT_DIR}/python-versions.conf"
: "${PYTHON_VERSION:?PYTHON_VERSION is not set in python-versions.conf}"
EXTRA_PYTHON_VERSIONS="${EXTRA_PYTHON_VERSIONS:-}"

ARTCRAFT_APPS=""
ARTCRAFT_CONFIG_FILE="${SCRIPT_DIR}/artcraft-apps.conf"
if [ -f "${ARTCRAFT_CONFIG_FILE}" ]; then
    # shellcheck source=/dev/null
    source "${ARTCRAFT_CONFIG_FILE}"
fi

PROJECTS_DIR="./projects"
CONFIG_DIR="./config_openchamber"
SSH_DIR="./config_ssh"
GITCONFIG_DIR="./config_gitconfig"
GITCONFIG_FILE="${GITCONFIG_DIR}/gitconfig"

mkdir -p "${PROJECTS_DIR}" "${CONFIG_DIR}" "${SSH_DIR}" "${GITCONFIG_DIR}"

if [ ! -f "${GITCONFIG_FILE}" ]; then
    touch "${GITCONFIG_FILE}"
fi

echo "==> Build container image (${IMAGE_NAME})..."
echo "    Node ${NODE_VERSION} (default), additional: ${EXTRA_NODE_VERSIONS:-none}"
echo "    Python ${PYTHON_VERSION} (default), additional: ${EXTRA_PYTHON_VERSIONS:-none}"
echo "    ArtCraft apps: ${ARTCRAFT_APPS:-none}"
podman build \
    --build-arg "NODE_VERSION=${NODE_VERSION}" \
    --build-arg "EXTRA_NODE_VERSIONS=${EXTRA_NODE_VERSIONS}" \
    --build-arg "PYTHON_VERSION=${PYTHON_VERSION}" \
    --build-arg "EXTRA_PYTHON_VERSIONS=${EXTRA_PYTHON_VERSIONS}" \
    --build-arg "ARTCRAFT_APPS=${ARTCRAFT_APPS}" \
    -t "${IMAGE_NAME}" "${SCRIPT_DIR}"

if podman ps -a --format '{{.Names}}' | grep -Eq "^${CONTAINER_NAME}\$"; then
    echo "==> Found container. Stop and remove..."
    podman stop "${CONTAINER_NAME}" >/dev/null 2>&1 || true
    podman rm "${CONTAINER_NAME}" >/dev/null 2>&1 || true
fi

echo "==> Start OpenChamber in background..."
# OpenChamber always listens on 3000 inside the container, HOST_PORT is the
# host side of the mapping.
podman run -d \
  --name "${CONTAINER_NAME}" \
  --restart unless-stopped \
  -p "127.0.0.1:${HOST_PORT}:3000" \
  -v "${PROJECTS_DIR}:/projects:Z" \
  -v "${CONFIG_DIR}:/root/.config:Z" \
  -v "${SSH_DIR}:/root/.ssh:ro,Z" \
  -v "${GITCONFIG_FILE}:/root/.gitconfig:ro,Z" \
  -e OPENCHAMBER_UI_PASSWORD="${UI_PASSWORD}" \
  "${IMAGE_NAME}"

echo "--------------------------------------------------"
echo "✅ Success! OpenChamber runs in background."
echo "   URL: http://127.0.0.1:${HOST_PORT}"
echo "--------------------------------------------------"