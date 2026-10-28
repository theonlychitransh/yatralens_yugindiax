# Windows build -> dist\yatralens.exe   (Python 3.11+, Node 18+, internet)
$ErrorActionPreference = "Stop"; Set-Location $PSScriptRoot
Push-Location web; if (Test-Path package-lock.json) { npm ci } else { npm install }; npm run build; Pop-Location
python -m venv .venv; .\.venv\Scripts\Activate.ps1
pip install -q fastapi "uvicorn[standard]" pydantic pydantic-settings slowapi httpx anthropic google-genai pyinstaller
Push-Location api; python -m PyInstaller --noconfirm --distpath ..\dist --workpath ..\build\pyi yatralens.spec; Pop-Location
Write-Host "Built: $PWD\dist\yatralens.exe"
