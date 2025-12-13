@echo off
set URL=http://localhost:8080

echo Testing %URL% ...

for /L %%i in (1,1,10) do (
    curl -sf %URL% >nul 2>&1
    if %ERRORLEVEL%==0 (
        echo SMOKE PASSED > smoke.log
        exit /b 0
    )
    timeout /t 1 >nul
)

echo SMOKE FAILED > smoke.log
exit /b 1
