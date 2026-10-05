# Open WebUI — Backend API

Open WebUI v0.9.5 — samodzielne API backendu (Python/FastAPI). Frontend SvelteKit został usunięty; projekt zawiera wyłącznie kod serwerowy.

## Stack

- **Python** + **FastAPI** + **Uvicorn**
- **SQLAlchemy** + **Alembic** (SQLite domyślnie, PostgreSQL opcjonalnie)
- **Socket.IO** (WebSocket)
- Integracje: OpenAI, Anthropic, Google Gemini, Ollama, ChromaDB, Redis i wiele innych

## Struktura

```
backend/
  open_webui/
    main.py          # Punkt wejścia aplikacji FastAPI
    config.py        # Konfiguracja (env vars)
    env.py           # Zmienne środowiskowe
    routers/         # Endpointy API
    models/          # Modele bazy danych (SQLAlchemy)
    migrations/      # Migracje Alembic
    utils/           # Narzędzia pomocnicze
  requirements.txt   # Zależności Python
  start.sh           # Skrypt startowy
```

## Uruchamianie

```bash
cd backend
pip install -r requirements.txt
uvicorn open_webui.main:app --host 0.0.0.0 --port 8080
```

Lub przez skrypt:
```bash
cd backend && bash start.sh
```

## Dokumentacja API

Po uruchomieniu dostępna pod `/docs` (Swagger UI).

## User preferences

- Projekt ma być backend-only (bez frontendu).
