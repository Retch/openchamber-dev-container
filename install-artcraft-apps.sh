#!/usr/bin/env bash
# Installs the ArtCraft suite apps named in ARTCRAFT_APPS as RPMs and registers
# each of them as an MCP server for opencode.

set -euo pipefail

APPS="${ARTCRAFT_APPS:-}"
CONFIG_DIR="${CONFIG_DIR:-/etc/opencode}"
CONFIG_PATH="${CONFIG_DIR}/opencode.jsonc"
TEMPLATE_DIR="${TEMPLATE_DIR:-/usr/local/share/artcraft_mcp_templates}"
RELEASE_BASE="https://github.com/storytold"

if [ -z "${APPS// /}" ]; then
    echo "No ArtCraft apps requested, skipping installation."
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

echo "Installing ArtCraft apps: ${APPS}"
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
# The entries themselves come from the MCP templates in ${TEMPLATE_DIR}:
# <app>.jsonc replaces default.jsonc for that app. A template is the JSON
# object of one server and has to start with { and end with }.

template_for() {
    local app="$1"
    if [ -f "${TEMPLATE_DIR}/${app}.jsonc" ]; then
        echo "${TEMPLATE_DIR}/${app}.jsonc"
    elif [ -f "${TEMPLATE_DIR}/default.jsonc" ]; then
        echo "${TEMPLATE_DIR}/default.jsonc"
    else
        echo "No MCP template for ${app} in ${TEMPLATE_DIR} (expected ${app}.jsonc or default.jsonc)." >&2
        return 1
    fi
}

entry_for() {
    local app="$1" template="$2"
    # __APP_CLI__ first, so its __APP_ prefix cannot swallow the __APP__ token.
    # Every line but the first indents one level under the server key.
    sed -e "s|__APP_CLI__|${app}-cli|g" \
        -e "s|__APP__|${app}|g" \
        -e '1!s/^/      /' \
        "${template}"
}

# Resolve every template first, so a missing one fails before the config is
# written.
for app in ${APPS}; do
    template_for "${app}" >/dev/null
done

mkdir -p "${CONFIG_DIR}"
{
    printf '{\n  "mcp": {\n    "servers": {\n'
    separator=""
    for app in ${APPS}; do
        printf '%s      "%s": %s' "${separator}" "${app}" "$(entry_for "${app}" "$(template_for "${app}")")"
        separator=$',\n'
    done
    printf '\n    }\n  }\n}\n'
} > "${CONFIG_PATH}"

dnf clean all
echo "ArtCraft MCP config written to ${CONFIG_PATH}"
