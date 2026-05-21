@echo off

set MARKER=C:\Windows\Setup\Scripts\sysprep.done

REM If we've already run, exit immediately
if exist "%MARKER%" exit /b 0

echo First run of SetupComplete – running Sysprep...

REM Create marker so it never runs again

echo done > "%MARKER%"

REM Run Sysprep

C:\Windows\System32\Sysprep\sysprep.exe /generalize /oobe

timeout /t 5 /nobreak

shutdown /s /t 0 /f

exit /b 0