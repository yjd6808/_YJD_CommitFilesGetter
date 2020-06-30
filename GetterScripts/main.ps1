using module '.\Program.psm1'
using module '.\FileUtil.psm1'

using namespace System.Diagnostics
using namespace System.IO

$invokeGit= {
    Param (
        [Parameter(
            Mandatory=$true
        )]
        [string]$Reason,
        [Parameter(
            Mandatory=$true
        )]
        [string[]]$ArgumentsList
    )
    try
    {
        $gitPath = 'C:\Program Files\Git\git-cmd.exe'#& "C:\Windows\System32\where.exe" git
        $gitErrorPath=Join-Path $env:TEMP "stderr.txt"
        $gitOutputPath=Join-Path $env:TEMP "stdout.txt"
        if($gitPath.Count -gt 1)
        {
            $gitPath=$gitPath[0]
        }

        Write-Verbose "[Git][$Reason] Begin"
        Write-Verbose "[Git][$Reason] gitPath=$gitPath"
        Write-Host "git $arguments"
        $process=Start-Process $gitPath -ArgumentList $ArgumentsList
        $outputText=(Get-Content $gitOutputPath)
        $outputText | ForEach-Object {Write-Host $_}

        Write-Verbose "[Git][$Reason] process.ExitCode=$($process.ExitCode)"
        if($process.ExitCode -ne 0)
        {
            Write-Warning "[Git][$Reason] process.ExitCode=$($process.ExitCode)"
            $errorText=$(Get-Content $gitErrorPath)
            $errorText | ForEach-Object {Write-Host $_}

            if($errorText -ne $null)
            {
                exit $process.ExitCode
            }
        }
        return $outputText
    }
    catch
    {
        Write-Error "[Git][$Reason] Exception $_"
    }
    finally
    {
        Write-Verbose "[Git][$Reason] Done"
    }
}

[Program]::new().Run()
