#!/usr/bin/env bash
set -euo pipefail

# Ensure required vars are set
if [[ -z "${CTM_ENDPOINT:-}" || -z "${CTM_API_TOKEN:-}" ]]; then
  echo >&2 "ERROR: CTM_ENDPOINT and CTM_API_TOKEN must be set"
  exit 1
fi

# Register the SaaS environment
ctm environment add "${CTM_ENV_NAME}" "${CTM_ENDPOINT}" "${CTM_API_TOKEN}"

# Execute any passed-in command, or keep the container alive
if [[ $# -gt 0 ]]; then
  exec "$@"
else
  exec tail -f /dev/null
fi
