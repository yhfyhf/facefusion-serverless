from __future__ import annotations

import base64
import os
import shutil
import subprocess
import tempfile
import time
from pathlib import Path
from urllib.parse import urlparse

import requests
import runpod


DOWNLOAD_HEADERS = {
    "User-Agent": "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 Chrome/131 Safari/537.36"
}


DEFAULT_ENV = {
    "FACEFUSION_VIDEO_PRESET": "identity",
    "FACE_SWAPPER_MODEL": "inswapper_128_fp16",
    "FACE_SWAPPER_PIXEL_BOOST": "1024x1024",
    "FACE_SWAPPER_WEIGHT": "1.0",
    "FACE_SELECTOR_MODE": "one",
    "REFERENCE_FACE_DISTANCE": "0.7",
    "FACE_DETECTOR_SCORE": "0.4",
    "FACE_MASK_TYPES": "box occlusion",
    "FACE_MASK_BLUR": "0.2",
    "FACE_MASK_PADDING": "0 8 0 8",
    "ENABLE_FACE_ENHANCER": "0",
    "OUTPUT_VIDEO_ENCODER": "libx264",
}

PARAM_TO_ENV = {
    "preset": "FACEFUSION_VIDEO_PRESET",
    "swapper_model": "FACE_SWAPPER_MODEL",
    "pixel_boost": "FACE_SWAPPER_PIXEL_BOOST",
    "face_swapper_weight": "FACE_SWAPPER_WEIGHT",
    "face_selector_mode": "FACE_SELECTOR_MODE",
    "reference_frame": "REFERENCE_FRAME_NUMBER",
    "reference_distance": "REFERENCE_FACE_DISTANCE",
    "detector_score": "FACE_DETECTOR_SCORE",
    "mask_types": "FACE_MASK_TYPES",
    "mask_blur": "FACE_MASK_BLUR",
    "mask_padding": "FACE_MASK_PADDING",
    "enable_enhancer": "ENABLE_FACE_ENHANCER",
    "enhancer_blend": "FACE_ENHANCER_BLEND",
    "output_video_encoder": "OUTPUT_VIDEO_ENCODER",
}


def _suffix_from_url(url: str, fallback: str) -> str:
    suffix = Path(urlparse(url).path).suffix
    return suffix if suffix else fallback


def _is_video_path(path: Path) -> bool:
    return path.suffix.lower() in {".mp4", ".mov", ".m4v", ".webm", ".avi", ".mkv"}


def _output_suffix_for_target(path: Path) -> str:
    return ".mp4" if _is_video_path(path) else (path.suffix or ".png")


def _download(url: str, path: Path) -> None:
    with requests.get(url, headers=DOWNLOAD_HEADERS, stream=True, timeout=(15, 300)) as response:
        response.raise_for_status()
        with path.open("wb") as file:
            shutil.copyfileobj(response.raw, file)


def _upload(url: str, path: Path, headers: dict[str, str] | None = None) -> None:
    with path.open("rb") as file:
        response = requests.put(url, data=file, headers=headers or {}, timeout=(15, 600))
    response.raise_for_status()


def _bool_env(value: object) -> str:
    return "1" if value in (True, "1", "true", "True", "yes", "on") else "0"


def handler(job: dict) -> dict:
    started = time.time()
    job_input = job.get("input") or {}
    source_url = job_input.get("source_url")
    target_url = job_input.get("target_url")
    output_upload_url = job_input.get("output_upload_url")
    output_upload_headers = job_input.get("output_upload_headers") or {}
    return_base64 = bool(job_input.get("return_base64", False))

    if not source_url or not target_url:
        raise ValueError("source_url and target_url are required")

    with tempfile.TemporaryDirectory(prefix="facefusion-job-") as tmpdir:
        workdir = Path(tmpdir)
        source_path = workdir / f"source{_suffix_from_url(source_url, '.jpg')}"
        target_path = workdir / f"target{_suffix_from_url(target_url, '.mp4')}"

        _download(source_url, source_path)
        _download(target_url, target_path)

        is_video_job = _is_video_path(target_path)
        output_path = workdir / f"output{_output_suffix_for_target(target_path)}"

        env = os.environ.copy()
        env.update(DEFAULT_ENV)

        params = job_input.get("params") or {}
        for key, env_key in PARAM_TO_ENV.items():
            if key in params and params[key] is not None:
                value = params[key]
                env[env_key] = _bool_env(value) if key == "enable_enhancer" else str(value)

        if is_video_job:
            trim_start = job_input.get("trim_start", params.get("trim_start", 0))
            trim_end = job_input.get("trim_end", params.get("trim_end", 80))
            if trim_start is not None:
                env["TRIM_FRAME_START"] = str(trim_start)
            if trim_end is not None:
                env["TRIM_FRAME_END"] = str(trim_end)
            command = [
                "/workspace/run_facefusion_video.sh",
                str(source_path),
                str(target_path),
                str(output_path),
            ]
        else:
            command = [
                "/workspace/run_facefusion_image.sh",
                str(source_path),
                str(target_path),
                str(output_path),
            ]
        completed = subprocess.run(
            command,
            env=env,
            cwd="/facefusion",
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            check=False,
        )

        log_tail = (completed.stdout or "")[-8000:]
        if completed.returncode != 0:
            return {
                "ok": False,
                "returncode": completed.returncode,
                "log_tail": log_tail,
                "elapsed_sec": round(time.time() - started, 2),
            }
        if not output_path.exists():
            return {
                "ok": False,
                "returncode": 0,
                "error": "FaceFusion completed but output.mp4 was not created",
                "log_tail": log_tail,
                "elapsed_sec": round(time.time() - started, 2),
            }

        result: dict = {
            "ok": True,
            "job_type": "video" if is_video_job else "image",
            "output_filename": output_path.name,
            "size_bytes": output_path.stat().st_size,
            "elapsed_sec": round(time.time() - started, 2),
            "log_tail": log_tail,
        }

        if output_upload_url:
            _upload(output_upload_url, output_path, output_upload_headers)
            result["uploaded"] = True

        if return_base64:
            result["output_base64"] = base64.b64encode(output_path.read_bytes()).decode("ascii")

        if not output_upload_url and not return_base64:
            result["warning"] = "No output_upload_url or return_base64 was provided; output was generated but not exported."

        return result


if __name__ == "__main__":
    runpod.serverless.start({"handler": handler})
