@echo off
if "%1"=="version" (
    echo git version 2.42.0.windows.1
    exit /b 0
)
if "%1"=="--version" (
    echo git version 2.42.0.windows.1
    exit /b 0
)
if "%1"=="rev-parse" (
    exit /b 0
)
if "%1"=="log" (
    exit /b 0
)
echo stub: %*
exit /b 0
