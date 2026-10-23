#!/bin/bash
set -euo pipefail

export NVM_DIR="/usr/local/nvm"
source "$NVM_DIR/nvm.sh"
nvm use default >/dev/null

exec openchamber --foreground
