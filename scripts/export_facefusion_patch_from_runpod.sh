#!/usr/bin/env bash
set -Eeuo pipefail

SSH_TARGET="${1:?usage: scripts/export_facefusion_patch_from_runpod.sh root@IP -p PORT -i KEY}"
shift

OUT_PATH="${OUT_PATH:-patches/facefusion.patch}"

ssh "$@" "${SSH_TARGET}" 'cd /workspace/facefusion && git diff --binary' > "${OUT_PATH}"

if [[ ! -s "${OUT_PATH}" ]]; then
  echo "No FaceFusion diff was exported; ${OUT_PATH} is empty." >&2
  exit 1
fi

echo "Wrote ${OUT_PATH}"
