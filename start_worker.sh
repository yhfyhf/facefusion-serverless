#!/usr/bin/env bash
set -Eeuo pipefail

FACEFUSION_DIR="${FACEFUSION_DIR:-/facefusion}"
VOLUME_ROOT="${RUNPOD_VOLUME_PATH:-/runpod-volume}"
MODEL_ROOT="${FACEFUSION_MODEL_ROOT:-${VOLUME_ROOT}/facefusion-models}"
MODEL_LINK="${FACEFUSION_DIR}/.assets/models"

if [[ -d "${VOLUME_ROOT}" && -w "${VOLUME_ROOT}" ]]; then
  mkdir -p "${MODEL_ROOT}" "$(dirname "${MODEL_LINK}")"
  if [[ -e "${MODEL_LINK}" && ! -L "${MODEL_LINK}" ]]; then
    rm -rf "${MODEL_LINK}"
  fi
  ln -sfn "${MODEL_ROOT}" "${MODEL_LINK}"

  # One worker populates the shared model cache; all others wait for it.
  (
    flock -x 9
    cd "${FACEFUSION_DIR}"
    python facefusion.py force-download \
      --download-scope lite \
      --download-providers huggingface github
  ) 9>"${MODEL_ROOT}/.download.lock"
else
  echo "[facefusion] No writable RunPod volume; using ephemeral model storage." >&2
fi

exec python -u /workspace/handler.py
