@echo off
chcp 65001 >nul
title Android 模拟器启动器

echo ========================================================
echo   正在启动 Android 模拟器...
echo ========================================================

cd /d H:\Android\Sdk\emulator

echo.
echo [1/2] 正在启动 模拟器 A (Pixel_6_API_36)...
start "" emulator.exe -avd Pixel_6_API_36 -gpu auto

echo.
echo 等待 6 秒后启动 模拟器 B...
timeout /t 6 /nobreak >nul

echo.
echo [2/2] 正在启动 模拟器 B (Pixel_6_B)...
start "" emulator.exe -avd Pixel_6_B -port 5556 -gpu auto

echo.
echo ========================================================
echo   启动完成！请查看桌面或任务栏是否有手机模拟器窗口。
echo ========================================================
pause
