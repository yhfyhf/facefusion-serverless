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

JOB_ID="${1:?usage: scripts/get_job_status.sh JOB_ID}"

curl --fail-with-body \
  --request GET \
  --url "https://api.runpod.ai/v2/${RUNPOD_ENDPOINT_ID}/status/${JOB_ID}" \
  --header "Authorization: Bearer ${RUNPOD_API_KEY}"
