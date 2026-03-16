#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/config.sh"

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 <job.yaml>"
  exit 1
fi

YAML_FILE="$1"

if [[ ! -f "$YAML_FILE" ]]; then
  echo "Error: file not found: $YAML_FILE"
  exit 1
fi

# Extract the top-level job name from the YAML file.
JOB_NAME="$(awk '/^name:[[:space:]]*/{print $2; exit}' "$YAML_FILE")"

if [[ -z "${JOB_NAME:-}" ]]; then
  echo "Error: failed to parse job name from YAML"
  exit 1
fi

TMP_RESP="$(mktemp)"
HTTP_CODE="$(
  curl -sS \
    -o "$TMP_RESP" \
    -w '%{http_code}' \
    -X POST "${PAI_REST}/api/v2/jobs" \
    -H "Authorization: Bearer ${PAI_TOKEN}" \
    -H "Content-Type: text/yaml" \
    --data-binary @"$YAML_FILE"
)"

echo "HTTP_CODE=${HTTP_CODE}"
echo "JOB_NAME=${JOB_NAME}"
echo "RESPONSE:"
cat "$TMP_RESP"
echo

if [[ "$HTTP_CODE" != "202" && "$HTTP_CODE" != "200" ]]; then
  echo "Job submission failed"
  rm -f "$TMP_RESP"
  exit 1
fi

rm -f "$TMP_RESP"

echo "Job submitted successfully"
echo "Next commands:"
echo "  bash query_job_status.sh ${JOB_NAME}"
echo "  bash query_job_logs.sh ${JOB_NAME} both"
