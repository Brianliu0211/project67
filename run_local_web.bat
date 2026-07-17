@echo off
echo ==============================================
echo   啟動本地 Flutter Web 測試版預覽 (Port 8080)
echo ==============================================
set FLUTTER_ROOT=%USERPROFILE%\.puro\envs\stable\flutter
"%USERPROFILE%\.puro\envs\stable\flutter\bin\cache\dart-sdk\bin\dart.exe" --packages="%USERPROFILE%\.puro\envs\stable\flutter\packages\flutter_tools\.dart_tool\package_config.json" "%USERPROFILE%\.puro\shared\flutter_tools\f94f4fc76b4d74543ed9b085bbd75341ef65de22\flutter_tools.snapshot" run -d web-server --web-port=8080
pause
