#!/usr/bin/env bash
set -euo pipefail

# ── Validate required variables ────────────────────────────────────────────────
if [[ -z "${CTM_ENDPOINT:-}" || -z "${CTM_API_TOKEN:-}" ]]; then
  echo >&2 "ERROR: CTM_ENDPOINT and CTM_API_TOKEN must be set"
  exit 1
fi

CTM_ENV_NAME="${CTM_ENV_NAME:-default}"

# ── Register CTM environment (idempotent) ─────────────────────────────────────
# `ctm environment add` fails if the environment already exists. That happens on
# every container *restart* (not recreate), because ~/.ctm lives in the
# container's writable layer and survives restarts. Under `set -e` that used to
# kill the entrypoint and put the container into a restart loop.
#
# Behaviour now:
#   - not registered        -> add it
#   - already registered    -> delete + re-add, so a rotated token or changed
#                              endpoint in the stack env vars takes effect
#   - re-add fails          -> keep the existing registration and carry on
#   - any other add failure -> fail loudly (bad token, unreachable endpoint...)
register_env() {
  ctm environment add "${CTM_ENV_NAME}" "${CTM_ENDPOINT}" "${CTM_API_TOKEN}" 2>&1
}

if ! out=$(register_env); then
  if grep -qi "already exists" <<<"${out}"; then
    echo "CTM environment '${CTM_ENV_NAME}' already registered; refreshing it"
    if ctm environment delete "${CTM_ENV_NAME}" >/dev/null 2>&1 \
       && out=$(register_env); then
      echo "CTM environment '${CTM_ENV_NAME}' refreshed"
    else
      echo >&2 "WARN: could not refresh '${CTM_ENV_NAME}', keeping existing registration"
    fi
  else
    echo >&2 "ERROR: failed to register CTM environment '${CTM_ENV_NAME}':"
    echo >&2 "${out}"
    exit 1
  fi
else
  echo "CTM environment '${CTM_ENV_NAME}' registered"
fi

ctm environment set "${CTM_ENV_NAME}" >/dev/null 2>&1 || true

# ── Provision agent if not already installed ──────────────────────────────────
AGENT_DIR="${HOME}/ctm"
AGENT_EXE=$(find "${AGENT_DIR}" -maxdepth 1 -name "exe_*" -type d 2>/dev/null | head -1 || true)

if [[ -z "${AGENT_EXE}" ]]; then
  if [[ -z "${CTM_AGENT_TAG:-}" ]]; then
    # CLI-only mode: no agent requested, don't crash-loop over it
    echo "CTM_AGENT_TAG not set; skipping agent provisioning (CLI-only mode)"
  else
    echo "Provisioning Control-M Agent (image: Agent_Ubuntu.Linux, tag: ${CTM_AGENT_TAG})..."

    PROVISION_ARGS=(provision saas::install Agent_Ubuntu.Linux "${CTM_AGENT_TAG}")
    [[ -n "${CTM_AGENT_NAME:-}" ]] && PROVISION_ARGS+=("${CTM_AGENT_NAME}")
    ctm "${PROVISION_ARGS[@]}"

    # Ensure all agent directories are owned by controlm
    find "${AGENT_DIR}" -not -user controlm -exec chown controlm:controlm {} + 2>/dev/null || true
  fi
else
  echo "Control-M Agent already installed: ${AGENT_EXE}"
fi

# ── Execute command or keep container alive ───────────────────────────────────
if [[ $# -gt 0 ]]; then
  exec "$@"
else
  exec tail -f /dev/null
fi
