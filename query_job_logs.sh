#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/config.sh"

if [[ $# -lt 1 || $# -gt 2 ]]; then
  echo "Usage: $0 <job_name> [stdout|stderr|all|both]"
  exit 1
fi

JOB_NAME="$1"
MODE="${2:-both}"

if ! command -v python3 >/dev/null 2>&1; then
  echo "Error: this script requires python3"
  exit 1
fi

# Query the current job status to get the container log index path.
STATUS_JSON="$(
  curl -sS \
    -H "Authorization: Bearer ${PAI_TOKEN}" \
    "${PAI_REST}/api/v2/jobs/${PAI_USER}~${JOB_NAME}"
)"

JOB_STATE="$(STATUS_JSON_ENV="$STATUS_JSON" python3 - <<'PY'
import json, os
d = json.loads(os.environ["STATUS_JSON_ENV"])
print(d["jobStatus"]["state"])
PY
)"

CONTAINER_LOG_PATH="$(STATUS_JSON_ENV="$STATUS_JSON" python3 - <<'PY'
import json, os
d = json.loads(os.environ["STATUS_JSON_ENV"])
task_roles = d["taskRoles"]
tr_name = next(iter(task_roles))
task = task_roles[tr_name]["taskStatuses"][0]
print(task["containerLog"])
PY
)"

echo "JOB_NAME=${JOB_NAME}"
echo "JOB_STATE=${JOB_STATE}"
echo "CONTAINER_LOG_PATH=${CONTAINER_LOG_PATH}"
echo

# Query the log index endpoint to get signed URIs for stdout/stderr/all.
LOG_INDEX_JSON="$(
  curl -sS \
    -H "Authorization: Bearer ${PAI_TOKEN}" \
    "${PAI_REST}${CONTAINER_LOG_PATH}"
)"

get_log_uri() {
  local target_name="$1"
  LOG_INDEX_JSON_ENV="$LOG_INDEX_JSON" TARGET_NAME_ENV="$target_name" python3 - <<'PY'
import json, os
d = json.loads(os.environ["LOG_INDEX_JSON_ENV"])
target = os.environ["TARGET_NAME_ENV"]
for x in d.get("locations", []):
    if x.get("name") == target:
        print(x.get("uri"))
        break
PY
}

fetch_one() {
  local log_name="$1"
  local uri
  uri="$(get_log_uri "$log_name")"

  if [[ -z "${uri:-}" ]]; then
    echo "Log type not found: ${log_name}"
    return 1
  fi

  echo "========== ${log_name} =========="
  curl -sS --max-time "${PAI_LOG_TIMEOUT}" "${PAI_BASE}${uri}" || true
  echo
  echo
}

case "$MODE" in
  stdout)
    fetch_one "stdout"
    ;;
  stderr)
    fetch_one "stderr"
    ;;
  all)
    fetch_one "all"
    ;;
  both)
    fetch_one "stdout"
    fetch_one "stderr"
    ;;
  *)
    echo "Error: MODE must be one of stdout / stderr / all / both"
    exit 1
    ;;
esac
