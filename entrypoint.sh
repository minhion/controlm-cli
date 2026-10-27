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
# CTM_AGENT_MODE selects the provision command:
#   saas  -> ctm provision saas::install  <image> [tag] [name]
#   agent -> ctm provision agent::install <image> [server] [name] [port]
#   none  -> CLI-only
# Defaults to saas when CTM_AGENT_TAG is set (backwards compatible), else none.
AGENT_DIR="${HOME}/ctm"
# Written only after provisioning succeeds; an exe_* dir without it is a
# leftover from a failed attempt (e.g. agent registration was rejected)
AGENT_MARKER="${HOME}/.ctm_agent_provisioned"
CTM_AGENT_IMAGE="${CTM_AGENT_IMAGE:-Agent_Alma.Linux}"
if [[ -n "${CTM_AGENT_TAG:-}" ]]; then
  CTM_AGENT_MODE="${CTM_AGENT_MODE:-saas}"
else
  CTM_AGENT_MODE="${CTM_AGENT_MODE:-none}"
fi

find_agent_exe() {
  find "${AGENT_DIR}" -maxdepth 1 -name "exe_*" -type d 2>/dev/null | head -1 || true
}

# Append optional positional args in order; a later one without an earlier
# one would shift into the wrong position, so refuse that.
append_positional() {
  local -n _args=$1; shift
  local gap="" name val
  for name in "$@"; do
    val="${!name:-}"
    if [[ -z "${val}" ]]; then
      [[ -z "${gap}" ]] && gap="${name}"
    elif [[ -n "${gap}" ]]; then
      echo >&2 "ERROR: ${name} is set but ${gap} is not; ${gap} is required before ${name}"
      exit 1
    else
      _args+=("${val}")
    fi
  done
}

AGENT_EXE=$(find_agent_exe)

if [[ -n "${AGENT_EXE}" && ! -f "${AGENT_MARKER}" ]]; then
  # Re-running the install over a partial one doesn't work, and exiting would
  # restart-loop (re-downloading the agent each time), so stay up as CLI-only
  echo >&2 "ERROR: a previous agent provisioning attempt failed (see ~/BMCINSTALL/log)."
  echo >&2 "       Fix the cause, then recreate the container: docker compose up -d --force-recreate"
  echo >&2 "       Continuing in CLI-only mode."
  AGENT_EXE=""
elif [[ -n "${AGENT_EXE}" ]]; then
  echo "Control-M Agent already installed: ${AGENT_EXE}"
  # Agent processes don't survive a container restart; bring them back up
  if [[ -x "${AGENT_DIR}/scripts/start-ag" ]]; then
    bash -lc "start-ag -u controlm -p ALL" >/dev/null 2>&1 \
      && echo "Control-M Agent started" \
      || echo >&2 "WARN: could not start Control-M Agent (run 'start-ag' manually)"
  fi
else
  PROVISION_ARGS=()
  case "${CTM_AGENT_MODE}" in
    none)
      echo "No agent requested; skipping agent provisioning (CLI-only mode)"
      ;;
    saas)
      if [[ -z "${CTM_AGENT_TAG:-}" ]]; then
        echo >&2 "ERROR: CTM_AGENT_MODE=saas requires CTM_AGENT_TAG"
        exit 1
      fi
      PROVISION_ARGS=(provision saas::install "${CTM_AGENT_IMAGE}")
      append_positional PROVISION_ARGS CTM_AGENT_TAG CTM_AGENT_NAME
      ;;
    agent)
      PROVISION_ARGS=(provision agent::install "${CTM_AGENT_IMAGE}")
      append_positional PROVISION_ARGS CTM_SERVER CTM_AGENT_NAME CTM_AGENT_PORT
      ;;
    *)
      echo >&2 "ERROR: CTM_AGENT_MODE must be saas, agent or none (got '${CTM_AGENT_MODE}')"
      exit 1
      ;;
  esac

  if [[ ${#PROVISION_ARGS[@]} -gt 0 ]]; then
    [[ -n "${CTM_AGENT_CONFIG_FILE:-}" ]] && PROVISION_ARGS+=(-f "${CTM_AGENT_CONFIG_FILE}")
    [[ -n "${CTM_AGENT_REPO:-}" ]] && PROVISION_ARGS+=(-r "${CTM_AGENT_REPO}")

    echo "Provisioning Control-M Agent: ctm ${PROVISION_ARGS[*]}"
    ctm "${PROVISION_ARGS[@]}"

    # Ensure all agent directories are owned by controlm
    find "${AGENT_DIR}" -not -user controlm -exec chown controlm:controlm {} + 2>/dev/null || true

    AGENT_EXE=$(find_agent_exe)
    if [[ -z "${AGENT_EXE}" ]]; then
      echo >&2 "ERROR: provisioning finished but no agent was found in ${AGENT_DIR}"
      exit 1
    fi
    date -u +%FT%TZ > "${AGENT_MARKER}"
    echo "Control-M Agent provisioned: ${AGENT_EXE}"
  fi
fi

# ── Deploy plugins (optional) ─────────────────────────────────────────────────
# CTM_DEPLOY_PLUGINS=true installs each image in CTM_PLUGINS (comma or space
# separated) with `ctm provision image`. Installed plugins are recorded next to
# the agent, so they are reinstalled whenever the agent is.
# A failed plugin only logs a warning and is retried on the next start.
if [[ "${CTM_DEPLOY_PLUGINS:-false}" == "true" ]]; then
  if [[ -z "${AGENT_EXE}" ]]; then
    echo >&2 "WARN: CTM_DEPLOY_PLUGINS=true but no agent is installed; skipping plugins"
  elif [[ -z "${CTM_PLUGINS:-}" ]]; then
    echo >&2 "WARN: CTM_DEPLOY_PLUGINS=true but CTM_PLUGINS is empty; skipping plugins"
  else
    PLUGIN_STATE_DIR="${HOME}/.ctm_plugins"
    mkdir -p "${PLUGIN_STATE_DIR}"
    for plugin in ${CTM_PLUGINS//,/ }; do
      if [[ -f "${PLUGIN_STATE_DIR}/${plugin}" ]]; then
        echo "Plugin already deployed: ${plugin}"
        continue
      fi
      echo "Deploying plugin: ${plugin}"
      if bash -lc 'ctm provision image "$1"' _ "${plugin}"; then
        date -u +%FT%TZ > "${PLUGIN_STATE_DIR}/${plugin}"
        echo "Plugin deployed: ${plugin}"
      else
        echo >&2 "WARN: failed to deploy plugin '${plugin}'; will retry on next start"
      fi
    done
  fi
fi

# ── Execute command or keep container alive ───────────────────────────────────
if [[ $# -gt 0 ]]; then
  exec "$@"
else
  exec tail -f /dev/null
fi
