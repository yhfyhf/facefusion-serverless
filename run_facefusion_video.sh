#!/usr/bin/env bash
set -Eeuo pipefail

FACEFUSION_DIR="${FACEFUSION_DIR:-/facefusion}"
SOURCE_PATH="${1:?source image path is required}"
TARGET_PATH="${2:?target video path is required}"
OUTPUT_PATH="${3:?output video path is required}"

FACEFUSION_VIDEO_PRESET="${FACEFUSION_VIDEO_PRESET:-identity}"
FACE_SWAPPER_MODEL="${FACE_SWAPPER_MODEL:-inswapper_128_fp16}"
FACE_SWAPPER_PIXEL_BOOST="${FACE_SWAPPER_PIXEL_BOOST:-1024x1024}"
FACE_SWAPPER_WEIGHT="${FACE_SWAPPER_WEIGHT:-1.0}"
FACE_DETECTOR_MODEL="${FACE_DETECTOR_MODEL:-retinaface}"
FACE_DETECTOR_SCORE="${FACE_DETECTOR_SCORE:-0.4}"
FACE_DETECTOR_ANGLES="${FACE_DETECTOR_ANGLES:-0}"
FACE_LANDMARKER_MODEL="${FACE_LANDMARKER_MODEL:-2dfan4}"
FACE_LANDMARKER_SCORE="${FACE_LANDMARKER_SCORE:-0.5}"
FACE_SELECTOR_MODE="${FACE_SELECTOR_MODE:-one}"
FACE_SELECTOR_ORDER="${FACE_SELECTOR_ORDER:-best-worst}"
REFERENCE_FRAME_NUMBER="${REFERENCE_FRAME_NUMBER:-0}"
REFERENCE_FACE_POSITION="${REFERENCE_FACE_POSITION:-0}"
REFERENCE_FACE_DISTANCE="${REFERENCE_FACE_DISTANCE:-0.7}"
FACE_TRACKER_SCORE="${FACE_TRACKER_SCORE:-0.35}"
FACE_OCCLUDER_MODEL="${FACE_OCCLUDER_MODEL:-xseg_3}"
FACE_MASK_TYPES="${FACE_MASK_TYPES:-box occlusion}"
FACE_MASK_BLUR="${FACE_MASK_BLUR:-0.2}"
FACE_MASK_PADDING="${FACE_MASK_PADDING:-0 8 0 8}"
ENABLE_FACE_ENHANCER="${ENABLE_FACE_ENHANCER:-0}"
FACE_ENHANCER_MODEL="${FACE_ENHANCER_MODEL:-gpen_bfr_512}"
FACE_ENHANCER_BLEND="${FACE_ENHANCER_BLEND:-10}"
FACE_ENHANCER_WEIGHT="${FACE_ENHANCER_WEIGHT:-0.35}"
TEMP_FRAME_FORMAT="${TEMP_FRAME_FORMAT:-png}"
TEMP_PIXEL_FORMAT="${TEMP_PIXEL_FORMAT:-bgr24}"
TARGET_FRAME_AMOUNT="${TARGET_FRAME_AMOUNT:-0}"
OUTPUT_VIDEO_ENCODER="${OUTPUT_VIDEO_ENCODER:-libx264}"
OUTPUT_VIDEO_PRESET="${OUTPUT_VIDEO_PRESET:-fast}"
OUTPUT_VIDEO_QUALITY="${OUTPUT_VIDEO_QUALITY:-90}"
OUTPUT_AUDIO_ENCODER="${OUTPUT_AUDIO_ENCODER:-aac}"
OUTPUT_AUDIO_QUALITY="${OUTPUT_AUDIO_QUALITY:-100}"
WORKFLOW_STRATEGY="${WORKFLOW_STRATEGY:-disk}"
VIDEO_MEMORY_STRATEGY="${VIDEO_MEMORY_STRATEGY:-moderate}"
EXECUTION_PROVIDERS="${EXECUTION_PROVIDERS:-cuda}"
EXECUTION_THREAD_COUNT="${EXECUTION_THREAD_COUNT:-4}"

TRIM_ARGS=()
if [[ -n "${TRIM_FRAME_START:-}" ]]; then
  TRIM_ARGS+=(--trim-frame-start "${TRIM_FRAME_START}")
fi
if [[ -n "${TRIM_FRAME_END:-}" ]]; then
  TRIM_ARGS+=(--trim-frame-end "${TRIM_FRAME_END}")
fi

CUDA_LIBRARY_PATHS=(
  /usr/local/cuda/lib64
  /usr/local/lib/python3.12/dist-packages/nvidia/cublas/lib
  /usr/local/lib/python3.12/dist-packages/nvidia/cuda_runtime/lib
  /usr/local/lib/python3.12/dist-packages/nvidia/cudnn/lib
  /usr/local/lib/python3.12/dist-packages/nvidia/cufft/lib
  /usr/local/lib/python3.12/dist-packages/nvidia/curand/lib
)

for CUDA_LIBRARY_PATH in "${CUDA_LIBRARY_PATHS[@]}"; do
  if [[ -d "${CUDA_LIBRARY_PATH}" ]]; then
    export LD_LIBRARY_PATH="${CUDA_LIBRARY_PATH}:${LD_LIBRARY_PATH:-}"
  fi
done

[[ -f "${SOURCE_PATH}" ]] || { echo "Source image not found: ${SOURCE_PATH}" >&2; exit 1; }
[[ -f "${TARGET_PATH}" ]] || { echo "Target video not found: ${TARGET_PATH}" >&2; exit 1; }
mkdir -p "$(dirname "${OUTPUT_PATH}")" /tmp/facefusion_temp

FACE_PROCESSORS=(face_swapper)
FACE_ENHANCER_ARGS=()
if [[ "${ENABLE_FACE_ENHANCER}" == "1" ]]; then
  FACE_PROCESSORS+=(face_enhancer)
  FACE_ENHANCER_ARGS=(--face-enhancer-model "${FACE_ENHANCER_MODEL}" --face-enhancer-blend "${FACE_ENHANCER_BLEND}" --face-enhancer-weight "${FACE_ENHANCER_WEIGHT}")
fi

cd "${FACEFUSION_DIR}"

python facefusion.py headless-run \
  --source-paths "${SOURCE_PATH}" \
  --target-path "${TARGET_PATH}" \
  --output-path "${OUTPUT_PATH}" \
  --temp-path /tmp/facefusion_temp \
  --workflow-strategy "${WORKFLOW_STRATEGY}" \
  --processors "${FACE_PROCESSORS[@]}" \
  --face-detector-model "${FACE_DETECTOR_MODEL}" \
  --face-detector-score "${FACE_DETECTOR_SCORE}" \
  --face-detector-angles ${FACE_DETECTOR_ANGLES} \
  --face-landmarker-model "${FACE_LANDMARKER_MODEL}" \
  --face-landmarker-score "${FACE_LANDMARKER_SCORE}" \
  --face-selector-mode "${FACE_SELECTOR_MODE}" \
  --face-selector-order "${FACE_SELECTOR_ORDER}" \
  --reference-frame-number "${REFERENCE_FRAME_NUMBER}" \
  --reference-face-position "${REFERENCE_FACE_POSITION}" \
  --reference-face-distance "${REFERENCE_FACE_DISTANCE}" \
  --face-tracker-score "${FACE_TRACKER_SCORE}" \
  --face-occluder-model "${FACE_OCCLUDER_MODEL}" \
  --face-mask-types ${FACE_MASK_TYPES} \
  --face-mask-blur "${FACE_MASK_BLUR}" \
  --face-mask-padding ${FACE_MASK_PADDING} \
  --face-swapper-model "${FACE_SWAPPER_MODEL}" \
  --face-swapper-pixel-boost "${FACE_SWAPPER_PIXEL_BOOST}" \
  --face-swapper-weight "${FACE_SWAPPER_WEIGHT}" \
  "${FACE_ENHANCER_ARGS[@]}" \
  "${TRIM_ARGS[@]}" \
  --temp-frame-format "${TEMP_FRAME_FORMAT}" \
  --temp-pixel-format "${TEMP_PIXEL_FORMAT}" \
  --target-frame-amount "${TARGET_FRAME_AMOUNT}" \
  --output-video-encoder "${OUTPUT_VIDEO_ENCODER}" \
  --output-video-preset "${OUTPUT_VIDEO_PRESET}" \
  --output-video-quality "${OUTPUT_VIDEO_QUALITY}" \
  --output-audio-encoder "${OUTPUT_AUDIO_ENCODER}" \
  --output-audio-quality "${OUTPUT_AUDIO_QUALITY}" \
  --execution-providers "${EXECUTION_PROVIDERS}" \
  --execution-thread-count "${EXECUTION_THREAD_COUNT}" \
  --video-memory-strategy "${VIDEO_MEMORY_STRATEGY}" \
  --download-providers huggingface github \
  --log-level info

echo "Output written to ${OUTPUT_PATH}"
