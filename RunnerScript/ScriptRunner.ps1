Param (
    [Parameter(Mandatory=$true)]
    [string] $scriptPath
)

Write-Host =======================================================================================================
Write-Host $scriptPath ��ũ��Ʈ�� ����Ǿ����ϴ�
Write-Host =======================================================================================================
Write-Host

& $scriptPath
Write-Host �ƹ�Ű�� �Է½� ����˴ϴ�.
[Console]::ReadLine()