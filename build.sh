#!/usr/bin/env bash
# Builds ONE self-contained executable for the OS you run this on:  dist/yatralens  (Windows: use build.ps1)
# Needs: Python 3.11+, Node 18+, internet for pip/npm. No Postgres / C++ / API keys needed to RUN the result.
set -euo pipefail
cd "$(dirname "$0")"
( cd web && { [ -f package-lock.json ] && npm ci || npm install; } && npm run build )
python3 -m venv .venv && . .venv/bin/activate
pip install -q fastapi "uvicorn[standard]" pydantic pydantic-settings slowapi httpx anthropic google-genai pyinstaller
( cd api && python -m PyInstaller --noconfirm --distpath ../dist --workpath ../build/pyi yatralens.spec )
echo "Built: $(pwd)/dist/yatralens"
