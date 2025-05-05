@REM This little wrapper is to run a *.sh script in the GIT Bash environment
@REM Note that this must be in the directory of the bash script and have the
@REM same name - for example build.sh and build.cmd
@REM
@REM This does assume you have git installed in the default location.

"%PROGRAMFILES%\Git\bin\bash.exe" %~dp0%~n0.sh %*
@exit /b %ERRORLEVEL%