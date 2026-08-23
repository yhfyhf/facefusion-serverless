#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

if [[ -f "${REPO_DIR}/../.env" ]]; then
  set -a
  # shellcheck disable=SC1091
  source "${REPO_DIR}/../.env"
  set +a
fi
if [[ -f "${REPO_DIR}/.runpod-serverless.env" ]]; then
  set -a
  # shellcheck disable=SC1091
  source "${REPO_DIR}/.runpod-serverless.env"
  set +a
fi

: "${RUNPOD_API_KEY:?RUNPOD_API_KEY is required}"
: "${RUNPOD_ENDPOINT_ID:?RUNPOD_ENDPOINT_ID is required}"

INPUT_JSON="${1:-test_input.json}"

curl --fail-with-body \
  --request POST \
  --url "https://api.runpod.ai/v2/${RUNPOD_ENDPOINT_ID}/run" \
  --header "Authorization: Bearer ${RUNPOD_API_KEY}" \
  --header "Content-Type: application/json" \
  --data @"${INPUT_JSON}"
