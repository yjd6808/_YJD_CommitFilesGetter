Param (
    [Parameter(Mandatory=$true)]
    [string] $scriptPath
)

Write-Host =======================================================================================================
Write-Host $scriptPath 스크립트가 실행되었습니다
Write-Host =======================================================================================================
Write-Host

& $scriptPath
Write-Host 아무키나 입력시 종료됩니다.
[Console]::ReadLine()