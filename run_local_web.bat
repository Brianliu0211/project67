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
echo [2/2] Starting Flutter Web Dev Server...
echo Keep this window open for Hot Reload!
echo In this window, you can:
echo   - Press 'r' to Hot Reload (incremental rebuild in <1s)
echo   - Press 'R' to Hot Restart (full app restart)
echo   - Press 'q' to quit
echo.
call puro flutter run -d web-server --web-port=8080
pause
