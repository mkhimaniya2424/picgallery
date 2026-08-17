@echo off 
cd /d D:\picgallery\backend
call D:\picgallery\venv\Scripts\activate.bat
uvicorn app.main:app --host 0.0.0.0 --port 8000
