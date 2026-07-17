@echo off
echo ==============================================
echo   Starting Toolpack Verification
echo ==============================================
call puro dart tool/verify_toolpack.dart
set EXIT_CODE=%ERRORLEVEL%
if %EXIT_CODE% neq 0 (
  echo.
  echo [ERROR] Verification failed! Please check the output above.
  if "%1" neq "nopause" pause
  exit /b %EXIT_CODE%
)
echo.
echo [SUCCESS] Verification passed!
if "%1" neq "nopause" pause
