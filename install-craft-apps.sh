#!/usr/bin/env bash
# Installs the ArtCraft suite apps named in CRAFT_APPS as RPMs and registers
# each of them as an MCP server for opencode.

set -euo pipefail

APPS="${CRAFT_APPS:-}"
CONFIG_DIR="/etc/opencode"
CONFIG_PATH="${CONFIG_DIR}/opencode.jsonc"
RELEASE_BASE="https://github.com/storytold"

if [ -z "${APPS// /}" ]; then
    echo "No craft apps requested, skipping installation."
    exit 0
fi

ARCH="$(uname -m)"
WORKDIR="$(mktemp -d)"
trap 'rm -rf "${WORKDIR}"' EXIT

install_app() {
    local app="$1"
    local tag version rpm_url rpm_file

    # The releases/latest URL redirects to the tag of the newest release.
    tag="$(curl -fsSL -o /dev/null -w '%{url_effective}' "${RELEASE_BASE}/${app}/releases/latest" | sed 's|.*/tag/||')"
    version="${tag#v}"

    rpm_url="${RELEASE_BASE}/${app}/releases/download/${tag}/${app}-${version}-linux-${ARCH}.rpm"
    rpm_file="${WORKDIR}/${app}-${version}-linux-${ARCH}.rpm"

    echo "  ${app} ${version} (linux-${ARCH})"
    curl -fsSL -o "${rpm_file}" "${rpm_url}"

    # A local file keeps dnf resolving the RPM's dependencies from the repos.
    dnf install -y "${rpm_file}"
}

echo "Installing craft apps: ${APPS}"
for app in ${APPS}; do
    install_app "${app}"
done

# Register each app as an MCP server. opencode merges mcp.servers across all
# config layers, so this file adds to the user's own config instead of
# replacing it.
#
# The file lives in the system config directory under the name opencode looks
# for there, so it is picked up without an OPENCODE_CONFIG environment
# variable. opencode only reads opencode.json and opencode.jsonc from a config
# directory, and setting OPENCODE_CONFIG would make OpenChamber give up its own
# managed config file, which turns its tool toggles into restarts.
mkdir -p "${CONFIG_DIR}"
{
    printf '{\n  "mcp": {\n    "servers": {\n'
    separator=""
    for app in ${APPS}; do
        printf '%s      "%s": {\n' "${separator}" "${app}"
        printf '        "type": "local",\n'
        printf '        "command": ["%s-cli", "mcp", "--root", "/projects"]\n' "${app}"
        printf '      }'
        separator=$',\n'
    done
    printf '\n    }\n  }\n}\n'
} > "${CONFIG_PATH}"

dnf clean all
echo "Craft MCP config written to ${CONFIG_PATH}"
