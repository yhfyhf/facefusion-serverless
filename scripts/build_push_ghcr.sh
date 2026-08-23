#!/usr/bin/env bash
set -Eeuo pipefail

IMAGE="${RUNPOD_IMAGE:-ghcr.io/yhfyhf/facefusion-serverless}"
TAG="${RUNPOD_IMAGE_TAG:-$(git rev-parse --short HEAD 2>/dev/null || date +%Y%m%d%H%M%S)}"
PLATFORM="${DOCKER_PLATFORM:-linux/amd64}"
PRELOAD_MODELS="${PRELOAD_MODELS:-1}"

docker build \
  --platform "${PLATFORM}" \
  --build-arg PRELOAD_MODELS="${PRELOAD_MODELS}" \
  -t "${IMAGE}:${TAG}" \
  -t "${IMAGE}:latest" \
  .

docker push "${IMAGE}:${TAG}"
docker push "${IMAGE}:latest"

printf 'Pushed %s:%s\n' "${IMAGE}" "${TAG}"
