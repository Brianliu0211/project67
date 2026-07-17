@echo off
echo ==============================================
echo   Starting Local Flutter Web Preview (Port 8080)
echo ==============================================
echo [1/3] Running Toolpack verification check...
call verify_toolpack.bat nopause
if %ERRORLEVEL% neq 0 (
  echo.
  echo [WARNING] TOOLPACK VERIFICATION FAILED!
  echo There are version discrepancies between docs/工具包.md and the codebase configuration.
  echo Please run verify_toolpack.bat to check details.
  echo Continuing preview startup in 5 seconds...
  timeout /t 5
)
echo.
echo [2/3] Compiling Web app in debug mode...
call puro flutter build web --debug
if %ERRORLEVEL% neq 0 (
  echo Compilation failed!
  pause
  exit /b %ERRORLEVEL%
)
echo [3/3] Starting local web server...
where python >nul 2>nul
if %ERRORLEVEL% equ 0 (
  python -m http.server 8080 --directory build/web
) else (
  npx http-server build/web -p 8080
)
pause
