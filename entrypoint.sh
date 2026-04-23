#!/usr/bin/env bash
set -euo pipefail

# ── Validate required variables ───────────────────────────────────────────────
if [[ -z "${CTM_ENDPOINT:-}" || -z "${CTM_API_TOKEN:-}" ]]; then
  echo >&2 "ERROR: CTM_ENDPOINT and CTM_API_TOKEN must be set"
  exit 1
fi

# ── Register CTM environment (idempotent) ─────────────────────────────────────
ctm environment add "${CTM_ENV_NAME}" "${CTM_ENDPOINT}" "${CTM_API_TOKEN}"

# ── Provision agent if not already installed ──────────────────────────────────
AGENT_DIR="${HOME}/ctm"
AGENT_EXE=$(find "${AGENT_DIR}" -maxdepth 1 -name "exe_*" -type d 2>/dev/null | head -1)

if [[ -z "${AGENT_EXE}" ]]; then
  if [[ -z "${CTM_AGENT_TAG:-}" ]]; then
    echo >&2 "ERROR: CTM_AGENT_TAG must be set to provision the Control-M agent"
    exit 1
  fi

  echo "Provisioning Control-M Agent (image: Agent_Ubuntu.Linux, tag: ${CTM_AGENT_TAG})..."

  PROVISION_CMD="ctm provision saas::install Agent_Ubuntu.Linux ${CTM_AGENT_TAG}"
  [[ -n "${CTM_AGENT_NAME:-}" ]] && PROVISION_CMD="${PROVISION_CMD} ${CTM_AGENT_NAME}"
  eval "${PROVISION_CMD}"

  # Ensure all agent directories are owned by controlm
  find "${AGENT_DIR}" -not -user controlm -exec chown controlm:controlm {} + 2>/dev/null || true
else
  echo "Control-M Agent already installed: ${AGENT_EXE}"
fi

# ── Execute command or keep container alive ───────────────────────────────────
if [[ $# -gt 0 ]]; then
  exec "$@"
else
  exec tail -f /dev/null
fi
