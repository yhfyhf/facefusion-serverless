FROM nvidia/cuda:12.8.1-cudnn-runtime-ubuntu24.04

ARG FACEFUSION_REPO=https://github.com/yhfyhf/Facefusion.git
ARG FACEFUSION_VERSION=yhf-custom-3.8.2
ARG PRELOAD_MODELS=1

ENV DEBIAN_FRONTEND=noninteractive
ENV PIP_BREAK_SYSTEM_PACKAGES=1
ENV PIP_NO_CACHE_DIR=1
ENV PYTHONUNBUFFERED=1
ENV FACEFUSION_DIR=/facefusion

WORKDIR /workspace

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    ffmpeg \
    git \
    python-is-python3 \
    python3.12 \
    python3-pip \
    util-linux \
  && rm -rf /var/lib/apt/lists/*

RUN git clone "${FACEFUSION_REPO}" --branch "${FACEFUSION_VERSION}" --single-branch /facefusion

COPY patches /workspace/patches
RUN if [ -s /workspace/patches/facefusion.patch ]; then \
    cd /facefusion && git apply /workspace/patches/facefusion.patch; \
  fi

WORKDIR /facefusion
RUN python install.py cuda@12 --skip-conda \
  && rm -rf /root/.cache /tmp/*

WORKDIR /workspace
COPY requirements.txt /workspace/requirements.txt
RUN python -m pip install --no-cache-dir -r /workspace/requirements.txt

COPY run_facefusion_video.sh /workspace/run_facefusion_video.sh
COPY run_facefusion_image.sh /workspace/run_facefusion_image.sh
COPY start_worker.sh /workspace/start_worker.sh
COPY handler.py /workspace/handler.py
RUN chmod +x /workspace/run_facefusion_video.sh /workspace/run_facefusion_image.sh /workspace/start_worker.sh

RUN if [ "${PRELOAD_MODELS}" = "1" ]; then \
    cd /facefusion && python facefusion.py force-download --download-scope lite --download-providers huggingface github; \
  fi

CMD ["/workspace/start_worker.sh"]
