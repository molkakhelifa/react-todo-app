@echo off
setlocal enabledelayedexpansion

REM URL de l'application
set URL=http://localhost:8082
set MAX_RETRIES=15
set WAIT_SECONDS=2

echo =====================================
echo Running SMOKE TEST on %URL%
echo =====================================

for /l %%i in (1,1,%MAX_RETRIES%) do (

    powershell -Command ^
        "try { ^
            $r = Invoke-WebRequest -Uri '%URL%' -UseBasicParsing -TimeoutSec 5; ^
            if ($r.StatusCode -eq 200) { exit 0 } else { exit 1 } ^
        } catch { exit 1 }" >nul 2>&1

    if !errorlevel! equ 0 (
        echo SMOKE PASSED > smoke.log
        echo Smoke test PASSED
        exit /b 0
    )

    echo Waiting for application... attempt %%i/%MAX_RETRIES%
    timeout /t %WAIT_SECONDS% /nobreak >nul
)

echo SMOKE FAILED > smoke.log
exit /b 1
