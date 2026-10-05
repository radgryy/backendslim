# syntax=docker/dockerfile:1
# Backend-only, CPU-only image. Local embedding/reranking models are not included.
FROM python:3.11-slim-bookworm AS builder

ENV PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1
WORKDIR /build
COPY backend/requirements.txt ./requirements-full.txt

# Keep the existing pinned backend dependencies, excluding local ML and tests.
# Do not use requirements-min.txt: it is an incomplete WIP list.
RUN python -c "from pathlib import Path; excluded={'transformers','sentence-transformers','accelerate','einops','sentencepiece','colbert-ai','docker','pytest','pytest-docker'}; lines=Path('requirements-full.txt').read_text().splitlines(); import re; Path('requirements.txt').write_text('\n'.join(line for line in lines if re.split(r'[<>=~!\[ ]',line.strip(),maxsplit=1)[0].lower() not in excluded)+'\n')" \
    && python -m venv /opt/venv \
    && /opt/venv/bin/pip install --prefer-binary -r requirements.txt \
    && /opt/venv/bin/pip check \
    && /opt/venv/bin/python -c "import importlib.util; assert importlib.util.find_spec('torch') is None, 'A dependency pulled in PyTorch; review the slim dependency list'"

FROM python:3.11-slim-bookworm AS runtime

ARG BUILD_HASH=dev-build
ENV PATH="/opt/venv/bin:$PATH" \
    PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    ENV=prod \
    DOCKER=true \
    PORT=10000 \
    USE_SLIM_DOCKER=true \
    USE_CUDA_DOCKER=false \
    USE_OLLAMA_DOCKER=false \
    UVICORN_WORKERS=1 \
    THREAD_POOL_SIZE=4 \
    ENABLE_BASE_MODELS_CACHE=false \
    OMP_NUM_THREADS=1 \
    OPENBLAS_NUM_THREADS=1 \
    MKL_NUM_THREADS=1 \
    NUMEXPR_NUM_THREADS=1 \
    TOKENIZERS_PARALLELISM=false \
    MALLOC_ARENA_MAX=2 \
    RAG_EMBEDDING_ENGINE=openai \
    RAG_EMBEDDING_MODEL="" \
    RAG_RERANKING_MODEL="" \
    RAG_EMBEDDING_MODEL_AUTO_UPDATE=false \
    RAG_RERANKING_MODEL_AUTO_UPDATE=false \
    ENABLE_OTEL=false \
    ENABLE_DB_MIGRATIONS=true \
    SCARF_NO_ANALYTICS=true \
    DO_NOT_TRACK=true \
    ANONYMIZED_TELEMETRY=false \
    WEBUI_BUILD_VERSION=${BUILD_HASH} \
    WEBUI_SECRET_KEY_FILE=/app/backend/data/.webui_secret_key

# Existing administrator configuration retained at the user's request.
ENV WEBUI_ADMIN_EMAIL=oki692@icloud.com \
    WEBUI_ADMIN_PASSWORD=ataner00 \
    WEBUI_ADMIN_NAME=Admin
    OPENAI_API_BASE_URL=https://generative-api.onrender.com/v1

RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates libgomp1 \
    && rm -rf /var/lib/apt/lists/* \
    && groupadd --gid 10001 app \
    && useradd --uid 10001 --gid app --create-home app

WORKDIR /app/backend
COPY --from=builder /opt/venv /opt/venv
COPY --chown=app:app CHANGELOG.md /app/CHANGELOG.md
COPY --chown=app:app backend/ ./
COPY --chown=app:app docker-entrypoint-slim.sh /app/docker-entrypoint-slim.sh
RUN mkdir -p /app/backend/data && chown app:app /app/backend/data

USER app
EXPOSE 10000
HEALTHCHECK --interval=30s --timeout=5s --start-period=120s --retries=3 \
    CMD python -c "import json,os,urllib.request; r=urllib.request.urlopen('http://127.0.0.1:'+os.getenv('PORT','10000')+'/health',timeout=4); assert json.load(r).get('status') is True"
ENTRYPOINT ["bash", "/app/docker-entrypoint-slim.sh"]
