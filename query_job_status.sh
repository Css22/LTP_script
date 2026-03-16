#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/config.sh"

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 <job_identifier>" >&2
  exit 1
fi

JOB_IDENTIFIER="$1"

STATUS_JSON="$(
  curl -sS \
    -H "Authorization: Bearer ${PAI_TOKEN}" \
    "${PAI_REST}/api/v2/jobs/${JOB_IDENTIFIER}"
)"

if command -v python3 >/dev/null 2>&1; then
  STATUS_JSON_ENV="$STATUS_JSON" python3 - <<'PY'
import json
import os
import sys

d = json.loads(os.environ["STATUS_JSON_ENV"])
state = (d.get("jobStatus") or {}).get("state")

if not state:
    sys.exit(1)

print(state)
PY
else
  echo "Error: python3 is required" >&2
  exit 1
fi
