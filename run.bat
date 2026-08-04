@echo off
title DPZ Platform Full-Stack Runner
echo ===================================================
echo 🚀 Launching DPZ Full-Stack E-Commerce Platform
echo ===================================================
echo.
echo Starting Backend API Server (Port 5000)...
start "DPZ Backend API" cmd /k "cd dpz-api && npm run dev"
echo.
echo Starting Frontend Web & Admin (Port 3000)...
start "DPZ Frontend Web & Admin" cmd /k "cd dpz-web && npm run dev"
echo.
echo ===================================================
echo 🎉 Both servers launched in separate terminal windows!
echo backend:  http://localhost:5000
echo frontend: http://localhost:3000
echo admin:    http://localhost:3000/admin
echo ===================================================
pause
