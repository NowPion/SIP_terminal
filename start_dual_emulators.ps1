$env:ANDROID_HOME = "H:\Android\Sdk"
$env:ANDROID_SDK_ROOT = "H:\Android\Sdk"
Set-Location "H:\Android\Sdk\emulator"

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "  正在启动 Android 双模拟器窗口..." -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan

Write-Host "`n[1/2] 启动模拟器 1 (Pixel_6_API_36:5554)..." -ForegroundColor Yellow
Start-Process -FilePath ".\emulator.exe" -ArgumentList "-avd", "Pixel_6_API_36", "-gpu", "host"

Start-Sleep -Seconds 5

Write-Host "[2/2] 启动模拟器 2 (Pixel_6_B:5556)..." -ForegroundColor Yellow
Start-Process -FilePath ".\emulator.exe" -ArgumentList "-avd", "Pixel_6_B", "-port", "5556", "-gpu", "host"

Write-Host "`n两个模拟器窗口已唤起！" -ForegroundColor Green
Read-Host "按回车键退出"
