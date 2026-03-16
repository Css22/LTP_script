#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/config.sh"

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 <job_identifier>" >&2
  exit 1
fi

JOB_ID="$1"

STATUS_JSON="$(
  curl -sS \
    -H "Authorization: Bearer ${PAI_TOKEN}" \
    "${PAI_REST}/api/v2/jobs/${JOB_ID}"
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

LOG_INDEX_JSON="$(
  curl -sS \
    -H "Authorization: Bearer ${PAI_TOKEN}" \
    "${PAI_REST}${CONTAINER_LOG_PATH}"
)"

STDOUT_URI="$(LOG_INDEX_JSON_ENV="$LOG_INDEX_JSON" python3 - <<'PY'
import json, os
d = json.loads(os.environ["LOG_INDEX_JSON_ENV"])
for x in d["locations"]:
    if x["name"] == "stdout":
        print(x["uri"])
        break
PY
)"

STDERR_URI="$(LOG_INDEX_JSON_ENV="$LOG_INDEX_JSON" python3 - <<'PY'
import json, os
d = json.loads(os.environ["LOG_INDEX_JSON_ENV"])
for x in d["locations"]:
    if x["name"] == "stderr":
        print(x["uri"])
        break
PY
)"

STDOUT_CONTENT="$(curl -sS --max-time "${PAI_LOG_TIMEOUT}" "${PAI_BASE}${STDOUT_URI}" || true)"
STDERR_CONTENT="$(curl -sS --max-time "${PAI_LOG_TIMEOUT}" "${PAI_BASE}${STDERR_URI}" || true)"

STDOUT_ENV="$STDOUT_CONTENT" STDERR_ENV="$STDERR_CONTENT" python3 - <<'PY'
import json, os
print(json.dumps({
    "stdout": os.environ["STDOUT_ENV"],
    "stderr": os.environ["STDERR_ENV"],
}, ensure_ascii=False))
PY
