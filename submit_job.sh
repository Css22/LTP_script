#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/config.sh"

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 <job.yaml>" >&2
  exit 1
fi

YAML_FILE="$1"

if [[ ! -f "$YAML_FILE" ]]; then
  echo "Error: file not found: $YAML_FILE" >&2
  exit 1
fi

# Extract the top-level job name from the YAML file.
JOB_NAME="$(awk '/^name:[[:space:]]*/{print $2; exit}' "$YAML_FILE")"

if [[ -z "${JOB_NAME:-}" ]]; then
  echo "Error: failed to parse job name from YAML" >&2
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

if [[ "$HTTP_CODE" != "202" && "$HTTP_CODE" != "200" ]]; then
  cat "$TMP_RESP" >&2 || true
  rm -f "$TMP_RESP"
  exit 1
fi

rm -f "$TMP_RESP"

# Print the canonical job identifier used by follow-up APIs.
printf '%s~%s\n' "${PAI_USER}" "${JOB_NAME}"
