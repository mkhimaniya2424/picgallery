@echo off
cd /d D:\picgallery\backend
call venv\Scripts\activate

:: Production: 2 workers so a slow upload doesn't block other requests,
:: but both workers share the same D:\picgallery_data disk volume so
:: chunked upload temp folders are visible to whichever worker handles
:: each subsequent chunk — no more "Upload session not found" 404s.
:: --reload is intentionally OFF for production.
uvicorn app.main:app --host 0.0.0.0 --port 8000 --workers 2
pause
