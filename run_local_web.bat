@echo off
echo ==============================================
echo   Starting Local Flutter Web Preview (Port 8080)
echo ==============================================
echo Compiling Web app in debug mode...
call puro flutter build web --debug
if %ERRORLEVEL% neq 0 (
  echo Compilation failed!
  pause
  exit /b %ERRORLEVEL%
)
echo Starting local web server...
where python >nul 2>nul
if %ERRORLEVEL% equ 0 (
  python -m http.server 8080 --directory build/web
) else (
  npx http-server build/web -p 8080
)
pause
