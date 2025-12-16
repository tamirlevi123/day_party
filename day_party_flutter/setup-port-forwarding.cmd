@echo off
REM Port Forwarding Script for Android Emulator OAuth Testing
REM Wrapper script that bypasses PowerShell execution policy
REM
REM This is the recommended way to run the port forwarding script on Windows
REM as it bypasses PowerShell execution policy restrictions.
REM
REM Usage: setup-port-forwarding.cmd
REM
REM See EMULATOR_SETUP.md in the project root for complete documentation.

powershell -ExecutionPolicy Bypass -File "%~dp0setup-port-forwarding.ps1"
