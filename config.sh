#!/usr/bin/env bash
# Shared configuration file sourced by all scripts.
# Hard-coded version.

export PAI_REST="http://10.100.197.19/rest-server"
export PAI_USER="bowen.zhang"
export PAI_BASE="http://10.100.197.19"
export PAI_LOG_TIMEOUT="10"
export PAI_TOKEN="PASTE_YOUR_FULL_TOKEN_HERE"

export PAI_REST="${PAI_REST%/}"
export PAI_BASE="${PAI_BASE%/}"

if [[ -z "${PAI_TOKEN}" ]]; then
  echo "Error: PAI_TOKEN is empty. Please fill it in config.sh."
  return 1 2>/dev/null || exit 1
fi
