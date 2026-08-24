#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

if [[ -f "${REPO_DIR}/../.env" ]]; then
  set -a
  source "${REPO_DIR}/../.env"
  set +a
fi
if [[ -f "${REPO_DIR}/.runpod-serverless.env" ]]; then
  set -a
  source "${REPO_DIR}/.runpod-serverless.env"
  set +a
fi

: "${RUNPOD_API_KEY:?RUNPOD_API_KEY is required}"
: "${RUNPOD_ENDPOINT_ID:?RUNPOD_ENDPOINT_ID is required}"

export RUNPOD_MODEL_VOLUME_NAME="${RUNPOD_MODEL_VOLUME_NAME:-facefusion-model-cache}"
export RUNPOD_MODEL_VOLUME_SIZE_GB="${RUNPOD_MODEL_VOLUME_SIZE_GB:-20}"
export RUNPOD_MODEL_VOLUME_DATACENTER="${RUNPOD_MODEL_VOLUME_DATACENTER:-US-GA-1}"

python3 - <<'PY'
import json
import os
import urllib.request

api_key = os.environ["RUNPOD_API_KEY"]
endpoint_id = os.environ["RUNPOD_ENDPOINT_ID"]
name = os.environ["RUNPOD_MODEL_VOLUME_NAME"]
size = int(os.environ["RUNPOD_MODEL_VOLUME_SIZE_GB"])
datacenter = os.environ["RUNPOD_MODEL_VOLUME_DATACENTER"]
headers = {"Authorization": f"Bearer {api_key}", "Content-Type": "application/json"}

def request(method, path, payload=None):
    body = json.dumps(payload).encode() if payload is not None else None
    req = urllib.request.Request(f"https://rest.runpod.io/v1/{path}", data=body, headers=headers, method=method)
    with urllib.request.urlopen(req, timeout=60) as response:
        return json.loads(response.read().decode())

volumes = request("GET", "networkvolumes")
volume = next((v for v in volumes if v.get("name") == name and v.get("dataCenterId") == datacenter), None)
if volume is None:
    volume = request("POST", "networkvolumes", {"name": name, "size": size, "dataCenterId": datacenter})

endpoint = request("PATCH", f"endpoints/{endpoint_id}", {
    "networkVolumeIds": [volume["id"]],
    "dataCenterIds": [datacenter],
})
print(json.dumps({
    "endpoint_id": endpoint.get("id"),
    "volume_id": volume.get("id"),
    "volume_name": volume.get("name"),
    "volume_size_gb": volume.get("size"),
    "datacenter": volume.get("dataCenterId"),
}, indent=2))
PY
