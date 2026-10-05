# syntax=docker/dockerfile:1
# Initialize device type args
ARG USE_CUDA=false
ARG USE_SLIM=true
ARG USE_PERMISSION_HARDENING=false
ARG USE_CUDA_VER=cu128
ARG USE_EMBEDDING_MODEL=""
ARG USE_RERANKING_MODEL=""
ARG USE_AUXILIARY_EMBEDDING_MODEL=""
ARG USE_TIKTOKEN_ENCODING_NAME="cl100k_base"

ARG BUILD_HASH=dev-build
ARG UID=0
ARG GID=0

######## WebUI backend ########
FROM python:3.11-slim-bookworm AS base

# Use args
ARG USE_CUDA
ARG USE_CUDA_VER
ARG USE_SLIM
ARG USE_PERMISSION_HARDENING
ARG USE_EMBEDDING_MODEL
ARG USE_RERANKING_MODEL
ARG USE_AUXILIARY_EMBEDDING_MODEL
ARG UID
ARG GID

# Python settings
ENV PYTHONUNBUFFERED=1

## Basis ##
ENV ENV=prod \
    PORT=10000 \
    USE_CUDA_DOCKER=false \
    USE_SLIM_DOCKER=true \
    USE_CUDA_DOCKER_VER=${USE_CUDA_VER} \
    USE_EMBEDDING_MODEL_DOCKER="" \
    USE_RERANKING_MODEL_DOCKER="" \
    USE_AUXILIARY_EMBEDDING_MODEL_DOCKER=""

## Basis URL Config ##
ENV OPENAI_API_BASE_URL="https://generative-api.onrender.com/v1"

## API Key and Security Config ##
ENV OPENAI_API_KEY="connect" \
    WEBUI_SECRET_KEY="" \
    SCARF_NO_ANALYTICS=true \
    DO_NOT_TRACK=true \
    ANONYMIZED_TELEMETRY=false

## RAG Embedding model settings ##
ENV RAG_EMBEDDING_MODEL="" \
    RAG_RERANKING_MODEL="" \
    AUXILIARY_EMBEDDING_MODEL="" \
    SENTENCE_TRANSFORMERS_HOME="/app/backend/data/cache/embedding/models"

## Tiktoken model settings ##
ENV TIKTOKEN_ENCODING_NAME="cl100k_base" \
    TIKTOKEN_CACHE_DIR="/app/backend/data/cache/tiktoken"

## Hugging Face download cache ##
ENV HF_HOME="/app/backend/data/cache/embedding/models"

WORKDIR /app/backend

ENV HOME=/root
# Create user and group if not root
RUN if [ $UID -ne 0 ]; then \
    if [ $GID -ne 0 ]; then \
    addgroup --gid $GID app; \
    fi; \
    adduser --uid $UID --gid $GID --home $HOME --disabled-password --no-create-home app; \
    fi

RUN mkdir -p $HOME/.cache/chroma
RUN echo -n 00000000-0000-0000-0000-000000000000 > $HOME/.cache/chroma/telemetry_user_id

# Make sure the user has access to the app and root directory
RUN chown -R $UID:$GID /app $HOME

# Minimalne pakiety systemowe dla wersji slim (usunięto kompilatory i ffmpeg)
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    git netcat-openbsd curl jq ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Kopiowanie wymagań dla wersji SLIM (bez PyTorcha)
COPY --chown=$UID:$GID ./backend/requirements-slim.txt ./requirements.txt

# Set UV_LINK_MODE to copy to prevent 0-byte file corruption in QEMU arm64 cross-builds
ENV UV_LINK_MODE=copy

# Czyszczenie logiki instalacji — instalujemy wyłącznie paczki slim bez kompilacji i pobierania modeli
RUN set -e; \
    pip3 install --no-cache-dir uv; \
    uv pip install --system -r requirements.txt --no-cache-dir; \
    mkdir -p /app/backend/data; chown -R $UID:$GID /app/backend/data/; \
    rm -rf /var/lib/apt/lists/*

# copy backend metadata
COPY --chown=$UID:$GID ./CHANGELOG.md /app/CHANGELOG.md

# copy backend files
COPY --chown=$UID:$GID ./backend .

EXPOSE 8080
EXPOSE 10000

HEALTHCHECK CMD curl --silent --fail http://localhost:${PORT:-8080}/health | jq -ne 'input.status == true' || exit 1

# Minimal, atomic permission hardening for OpenShift (arbitrary UID):
RUN if [ "$USE_PERMISSION_HARDENING" = "true" ]; then \
    set -eux; \
    chgrp -R 0 /app /root || true; \
    chmod -R g+rwX /app /root || true; \
    find /app -type d -exec chmod g+s {} + || true; \
    find /root -type d -exec chmod g+s {} + || true; \
    fi

USER $UID:$GID

ARG BUILD_HASH
ENV WEBUI_BUILD_VERSION=${BUILD_HASH}
ENV DOCKER=true
ENV OFFLINE_MODE=true
ENV RAG_EMBEDDING_MODEL_AUTO_UPDATE=false
ENV RAG_RERANKING_MODEL_AUTO_UPDATE=false
ENV SCARF_NO_ANALYTICS=true
ENV DO_NOT_TRACK=true
ENV ANONYMIZED_TELEMETRY=false
ENV ENABLE_OTEL=false
ENV ENABLE_DB_MIGRATIONS=true

ENV WEBUI_ADMIN_EMAIL=oki692@icloud.com
ENV WEBUI_ADMIN_PASSWORD=ataner00
ENV WEBUI_ADMIN_NAME=Admin

CMD [ "bash", "start.sh"]
