#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/config.sh"

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 <job_name>"
  exit 1
fi

JOB_NAME="$1"

# Query the job status from the REST API.
STATUS_JSON="$(
  curl -sS \
    -H "Authorization: Bearer ${PAI_TOKEN}" \
    "${PAI_REST}/api/v2/jobs/${PAI_USER}~${JOB_NAME}"
)"

echo "==== Raw Response ===="
echo "$STATUS_JSON"
echo

if command -v python3 >/dev/null 2>&1; then
  echo "==== Parsed Status ===="
  STATUS_JSON_ENV="$STATUS_JSON" python3 - <<'PY'
import json
import os

d = json.loads(os.environ["STATUS_JSON_ENV"])
js = d.get("jobStatus", {})
task_roles = d.get("taskRoles", {})

print(f"job_name      : {d.get('name')}")
print(f"job_state     : {js.get('state')}")
print(f"job_sub_state : {js.get('subState')}")
print(f"executionType : {js.get('executionType')}")
print(f"createdTime   : {js.get('createdTime')}")
print(f"launchedTime  : {js.get('launchedTime')}")
print(f"completedTime : {js.get('completedTime')}")
print(f"appExitCode   : {js.get('appExitCode')}")
print(f"appExitType   : {js.get('appExitType')}")
print(f"appExitMsg    : {js.get('appExitMessages')}")

if task_roles:
    tr_name = next(iter(task_roles))
    task = task_roles[tr_name]["taskStatuses"][0]
    print(f"task_role     : {tr_name}")
    print(f"task_state    : {task.get('taskState')}")
    print(f"container_ip  : {task.get('containerIp')}")
    ports = task.get('containerPorts') or {}
    print(f"ssh_port      : {ports.get('ssh')}")
    print(f"http_port     : {ports.get('http')}")
    print(f"container_log : {task.get('containerLog')}")
PY
fi
