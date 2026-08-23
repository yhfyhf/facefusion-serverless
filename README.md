# FaceFusion Serverless

RunPod Serverless worker for the face swap pipeline.

## Defaults

The worker uses the currently accepted stable video configuration:

```bash
FACEFUSION_VIDEO_PRESET=identity
FACE_SWAPPER_MODEL=inswapper_128_fp16
FACE_SWAPPER_PIXEL_BOOST=1024x1024
FACE_SWAPPER_WEIGHT=1.0
FACE_SELECTOR_MODE=one
REFERENCE_FACE_DISTANCE=0.7
FACE_DETECTOR_SCORE=0.4
FACE_MASK_TYPES="box occlusion"
FACE_MASK_BLUR=0.2
FACE_MASK_PADDING="0 8 0 8"
ENABLE_FACE_ENHANCER=0
OUTPUT_VIDEO_ENCODER=libx264
```

The default image builds from FaceFusion `3.8.2`.

By default, jobs process frames `0..80` for quality checks. Pass `trim_end: null`
or a larger frame number for longer jobs.

## Job Input

Use signed URLs from your control server:

```json
{
  "input": {
    "source_url": "https://...",
    "target_url": "https://...",
    "output_upload_url": "https://...",
    "trim_start": 0,
    "trim_end": 80,
    "params": {}
  }
}
```

If `output_upload_url` is provided, the worker uploads the result with HTTP PUT.
For tiny tests only, set `return_base64: true`.

## Publish Image

## Custom FaceFusion Source

If you need custom FaceFusion source changes, do not edit a running pod by hand
for production. Use one of these reproducible paths:

1. Fork FaceFusion and build with your fork:

```bash
docker build \
  --build-arg FACEFUSION_REPO=https://github.com/yhfyhf/facefusion.git \
  --build-arg FACEFUSION_VERSION=your-branch-or-tag \
  .
```

2. Or save your source changes as `patches/facefusion.patch`. The Dockerfile
applies that patch after cloning FaceFusion.

To export a patch from a live RunPod pod before shutting it down:

```bash
scripts/export_facefusion_patch_from_runpod.sh root@POD_IP -p POD_PORT -i ~/.ssh/id_ed25519
```

This repo publishes to:

```bash
ghcr.io/yhfyhf/facefusion-serverless:latest
```

Use the GitHub Actions `Publish GHCR image` workflow, or build locally:

```bash
scripts/build_push_ghcr.sh
```

## Deploy RunPod Endpoint

Put `RUNPOD_API_KEY` in the parent project `.env` or this repo's `.env`, then run:

```bash
scripts/deploy_runpod_serverless.sh
```

The script creates a private RunPod template and a queue-based endpoint with:

- `workersMin=0`
- `workersMax=1`
- `idleTimeout=5`
- CUDA `12.8`
- no network volume

It writes endpoint metadata to `.runpod-serverless.env`.
