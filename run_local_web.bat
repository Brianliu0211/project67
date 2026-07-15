@echo off
echo ==============================================
echo   啟動本地 Flutter Web 測試版預覽 (Port 8080)
echo ==============================================
set FLUTTER_ROOT=%USERPROFILE%\.puro\envs\stable\flutter
"%USERPROFILE%\.puro\envs\stable\flutter\bin\cache\dart-sdk\bin\dart.exe" --packages="%USERPROFILE%\.puro\envs\stable\flutter\packages\flutter_tools\.dart_tool\package_config.json" "%USERPROFILE%\.puro\shared\flutter_tools\ee80f08bbf97172ec030b8751ceab557177a34a6\flutter_tools.snapshot" run -d web-server --web-port=8080
pause
