@echo off
setlocal
if not defined JULIA_EXE set "JULIA_EXE=julia"
"%JULIA_EXE%" --startup-file=no "%~dp0run.jl" %*
exit /b %errorlevel%
