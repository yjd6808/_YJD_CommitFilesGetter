@echo off

::��ũ��Ʈ ���� ���
set ps1ScriptRunner= "%cd%\RunnerScript\ScriptRunner.ps1"

::������ �Ŀ��� ��ũ��Ʈ ���
set ps1ScriptFile= "%cd%\GetterScripts\main.ps1"

::�Ŀ��� ��ũ��Ʈ ����
powershell "%ps1ScriptRunner% '%ps1ScriptFile%'" 