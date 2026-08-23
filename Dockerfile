FROM nvidia/cuda:12.8.1-cudnn-runtime-ubuntu24.04

ARG FACEFUSION_VERSION=3.7.1
ARG PRELOAD_MODELS=1

ENV DEBIAN_FRONTEND=noninteractive
ENV PIP_BREAK_SYSTEM_PACKAGES=1
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
  && rm -rf /var/lib/apt/lists/*

RUN git clone https://github.com/facefusion/facefusion.git --branch "${FACEFUSION_VERSION}" --single-branch /facefusion

WORKDIR /facefusion
RUN python install.py cuda --skip-conda

WORKDIR /workspace
COPY requirements.txt /workspace/requirements.txt
RUN python -m pip install --no-cache-dir -r /workspace/requirements.txt

COPY run_facefusion_video.sh /workspace/run_facefusion_video.sh
COPY handler.py /workspace/handler.py
RUN chmod +x /workspace/run_facefusion_video.sh

RUN if [ "${PRELOAD_MODELS}" = "1" ]; then \
    cd /facefusion && python facefusion.py force-download --download-scope lite --download-providers huggingface github; \
  fi

CMD ["python", "-u", "/workspace/handler.py"]
