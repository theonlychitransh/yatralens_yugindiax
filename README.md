# YatraLens

Constraint-aware heritage-day planner. Deterministic engine decides; Claude and Gemini propose and explain; every output is validated.

```
db/        PostgreSQL 16 + PostGIS schema (RLS, least-privilege roles, append-only audit), demo seed
secure/    C++20 pybind11 module `ylsec`: HMAC request auth, replay cache, keyed audit chain, key hygiene
api/app/   engine.py (gates+score, no I/O) · guard.py · llm.py (Gemini+Claude) · main.py (public) · admin.py (signed ingest)
           adaption_loop.py (Adaption cycle) · bench.py (measured metrics) · audit.py
web/       React 18 + Vite + react-leaflet, Tokyo Night, self-hosted fonts, CSP injected at build
```

## Run
```bash
createdb yatralens && psql yatralens -f db/001_schema.sql -f db/002_seed_demo.sql
cmake -S secure -B secure/build -DCMAKE_BUILD_TYPE=Release && cmake --build secure/build && cp secure/build/ylsec*.so api/
for k in audit admin; do openssl rand -hex 32 | install -m 0400 /dev/stdin /run/secrets/yl_${k}_key; done   # owner = service user
cd api && pip install -r requirements.txt
export GEMINI_API_KEY=... ANTHROPIC_API_KEY=... ADAPTION_API_KEY=...
YL_DATABASE_URL='postgresql://yl_api@host/yatralens?sslmode=verify-full&sslrootcert=ca.pem&sslcert=api.pem&sslkey=api.key' uvicorn app.main:app --port 8000
YL_INGEST_DATABASE_URL='postgresql://yl_ingest@host/...' uvicorn app.admin:app --host 127.0.0.1 --port 8001
python -m app.bench                                   # engine vs popularity baseline, independent oracle
python -m app.adaption_loop --estimate-only           # then without the flag
cd ../web && npm install && VITE_API_URL=https://localhost:8000 npm run dev    # commit package-lock.json; CI uses `npm ci`
```

## Trust boundaries
| Threat | Control |
|---|---|
| Prompt injection via scraped / contributed text | Sentinel (Claude Haiku) screen; `canon()` strips bidi/zero-width; `<untrusted_document>` framing; forced tool/JSON schema; extracted claims need verbatim span + second-vendor agreement; inserted as PENDING only |
| LLM invents hours, prices, times | Engine owns every number; `validate_note()` rejects any digit not in FACTS and any unknown/missing citation; deterministic template fallback |
| LLM bypasses a gate | Gates are code (`engine.gate`); `adjudicate()` output re-checked against authority rules |
| Public-process compromise | Separate processes/roles: `yl_api` reads ACCEPTED claims + appends audit; no ingest, no provider admin, different HMAC key |
| Forged / replayed ingest | HMAC-SHA256 over method, path, ts, nonce, body hash; constant-time compare; ±60 s; nonce cache (C++) |
| Audit tampering by a DB admin | keyed hash chain, key only in C++ Keyring (mlock, cleansed, no core dumps); `scripts/verify_audit.py` |
| XSS / supply chain (web) | React escaping only, no `dangerouslySetInnerHTML`, no HTML-string popups, bundled deps + lockfile, CSP `script-src 'self'`, no CDN scripts |
| Cost / abuse | slowapi 20/min, strict pydantic (`extra=forbid`, bounded ranges), 64 KB body cap, Adaption credit cap + estimate-first |

## Status (be honest in the demo)
Seed claims are `DEMO-FIXTURE`; replace with claims verified against the cited official source before presenting them as evidence.
Engine, guards and bench ran against fixtures. Not exercised here: live Claude/Gemini/Adaption calls, Postgres, `npm run build`, a linked C++ build (syntax and warnings checked against stub headers).

## Prototype executable (no Postgres, no C++ build, no API keys)
`./build.sh` (macOS/Linux) or `.\build.ps1` (Windows) builds the web UI and freezes `api/launcher.py` with PyInstaller into
`dist/yatralens[.exe]`. Run it: it serves API + UI on http://127.0.0.1:8000 and opens the browser.
Without `YL_DATABASE_URL` it runs in **demo mode**: fixtures from `db/002_seed_demo.sql` held in memory (`api/app/demo.py`),
an in-memory keyed audit chain, and a pure-Python `seclib` fallback when the C++ `ylsec` module is absent.
Without `ANTHROPIC_API_KEY` / `GEMINI_API_KEY` the note is the deterministic template (same facts, no LLM).
PyInstaller does not cross-compile: build on each OS you want to ship for. Offline tests: `cd api && python -m pytest tests`.
Map tiles need internet (OpenStreetMap).
