@echo off

::스크립트 러너 경로
set ps1ScriptRunner= "%cd%\RunnerScript\ScriptRunner.ps1"

::실행할 파워쉘 스크립트 경로
set ps1ScriptFile= "%cd%\GetterScripts\main.ps1"

::파워쉘 스크립트 실행
powershell "%ps1ScriptRunner% '%ps1ScriptFile%'" 