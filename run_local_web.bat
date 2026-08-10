@echo off
echo ==============================================
echo   Starting Local Flutter Dev Server (Port 8080)
echo ==============================================
echo [1/2] Running Toolpack verification check...
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
echo [2/3] Compiling Web release build (to bypass Puro path conflicts)...
call puro flutter build web --release
if %ERRORLEVEL% neq 0 (
  echo.
  echo [ERROR] Compilation failed!
  pause
  exit /b %ERRORLEVEL%
)
echo.
echo [3/3] Starting HTTP Server on Port 8080...
echo You can preview the web app at http://localhost:8080
echo Keep this window open. Press Ctrl+C to stop.
echo.
where npx >nul 2>nul
if %ERRORLEVEL% equ 0 (
  npx -y http-server build/web -p 8080
) else (
  python -m http.server 8080 --directory build/web
)
pause
