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
if [[ -f "${REPO_DIR}/.env" ]]; then
  set -a
  # shellcheck disable=SC1091
  source "${REPO_DIR}/.env"
  set +a
fi

: "${RUNPOD_API_KEY:?RUNPOD_API_KEY is required in ../.env, .env, or environment}"

IMAGE="${RUNPOD_IMAGE:-ghcr.io/yhfyhf/facefusion-serverless}"
TAG="${RUNPOD_IMAGE_TAG:-latest}"
ENDPOINT_NAME="${RUNPOD_ENDPOINT_NAME:-facefusion-serverless}"
GPU_TYPE_IDS="${RUNPOD_GPU_TYPE_IDS:-}"
DATA_CENTER_IDS="${RUNPOD_DATA_CENTER_IDS:-}"

python - <<'PY'
import json
import os
import sys
import requests

api_key = os.environ["RUNPOD_API_KEY"]
image = f"{os.environ.get('RUNPOD_IMAGE', 'ghcr.io/yhfyhf/facefusion-serverless')}:{os.environ.get('RUNPOD_IMAGE_TAG', 'latest')}"
endpoint_name = os.environ.get("RUNPOD_ENDPOINT_NAME", "facefusion-serverless")

def csv(value):
    return [item.strip() for item in value.split(",") if item.strip()]

headers = {"Authorization": f"Bearer {api_key}", "Content-Type": "application/json"}

template_payload = {
    "imageName": image,
    "name": f"{endpoint_name}-template",
    "category": "NVIDIA",
    "containerDiskInGb": 60,
    "dockerEntrypoint": [],
    "dockerStartCmd": [],
    "env": {},
    "isPublic": False,
    "isServerless": True,
    "ports": [],
    "readme": "FaceFusion Serverless worker for queue-based video face swap jobs.",
    "volumeInGb": 0,
    "volumeMountPath": "/workspace",
}

template_response = requests.post(
    "https://rest.runpod.io/v1/templates",
    headers=headers,
    json=template_payload,
    timeout=60,
)
if not template_response.ok:
    print(template_response.text, file=sys.stderr)
    template_response.raise_for_status()
template = template_response.json()
template_id = template["id"]

endpoint_payload = {
    "templateId": template_id,
    "allowedCudaVersions": ["12.8"],
    "computeType": "GPU",
    "cpuFlavorIds": [],
    "dataCenterIds": csv(os.environ.get("RUNPOD_DATA_CENTER_IDS", "")),
    "executionTimeoutMs": int(os.environ.get("RUNPOD_EXECUTION_TIMEOUT_MS", "1800000")),
    "flashboot": True,
    "gpuCount": 1,
    "gpuTypeIds": csv(os.environ.get("RUNPOD_GPU_TYPE_IDS", "")),
    "idleTimeout": int(os.environ.get("RUNPOD_IDLE_TIMEOUT", "5")),
    "name": endpoint_name,
    "networkVolumeIds": [],
    "scalerType": "QUEUE_DELAY",
    "scalerValue": int(os.environ.get("RUNPOD_SCALER_VALUE", "4")),
    "vcpuCount": int(os.environ.get("RUNPOD_VCPU_COUNT", "8")),
    "workersMax": int(os.environ.get("RUNPOD_WORKERS_MAX", "1")),
    "workersMin": int(os.environ.get("RUNPOD_WORKERS_MIN", "0")),
}

endpoint_response = requests.post(
    "https://rest.runpod.io/v1/endpoints",
    headers=headers,
    json=endpoint_payload,
    timeout=60,
)
if not endpoint_response.ok:
    print(endpoint_response.text, file=sys.stderr)
    endpoint_response.raise_for_status()
endpoint = endpoint_response.json()

state_path = ".runpod-serverless.env"
with open(state_path, "w", encoding="utf-8") as file:
    file.write(f"RUNPOD_TEMPLATE_ID={template_id}\n")
    file.write(f"RUNPOD_ENDPOINT_ID={endpoint['id']}\n")
    file.write(f"RUNPOD_IMAGE={image}\n")

print(json.dumps({
    "template_id": template_id,
    "endpoint_id": endpoint["id"],
    "endpoint_name": endpoint_name,
    "image": image,
    "state_file": state_path,
}, indent=2))
PY
