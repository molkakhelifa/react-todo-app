cat > smoke/smoke-test.bat << 'EOF'
@echo off
set URL=http://localhost:8082
set MAX_RETRIES=10

echo Testing %URL% ...

for /l %%i in (1,1,%MAX_RETRIES%) do (
    powershell -Command "try {$response = Invoke-WebRequest -Uri '%URL%' -UseBasicParsing -TimeoutSec 5; if ($response.StatusCode -eq 200) {exit 0} else {exit 1}} catch {exit 1}" > nul 2>&1
    if !errorlevel! equ 0 (
        echo SMOKE PASSED > smoke.log
        exit /b 0
    )
    
    if %%i lss %MAX_RETRIES% (
        echo Waiting for application... Attempt %%i of %MAX_RETRIES%
        ping -n 2 127.0.0.1 > nul
    )
)

echo SMOKE FAILED > smoke.log
exit /b 1
EOF