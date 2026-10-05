#!/usr/bin/env bash
set -euo pipefail

# Persist the generated session key alongside application data.
if [[ -z "${WEBUI_SECRET_KEY:-}" && -z "${WEBUI_JWT_SECRET_KEY:-}" ]]; then
    key_file="${WEBUI_SECRET_KEY_FILE:-/app/backend/data/.webui_secret_key}"
    if [[ ! -s "$key_file" ]]; then
        (umask 077; python -c 'import secrets; print(secrets.token_hex(32))' > "$key_file")
    fi
    export WEBUI_SECRET_KEY
    WEBUI_SECRET_KEY="$(cat "$key_file")"
fi

exec python -m uvicorn open_webui.main:app \
    --host 0.0.0.0 \
    --port "${PORT:-10000}" \
    --workers 1 \
    --log-level "${UVICORN_LOG_LEVEL:-info}" \
    "$@"
