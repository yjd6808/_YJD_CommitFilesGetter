##작성자 : 윤정도
##작성일 : 20-06-02

using module '.\Logger.psm1'
using module ".\FileUtil.psm1"
using module '.\GitManager.psm1'

using namespace System
using namespace System.IO
using namespace System.Threading
using namespace System.Text
using namespace System.Threading.Tasks
using namespace System.Collections.Generic
using namespace System.Management.Automation

enum SavePathType
{
    eAbsolutePath
    eIgnorePath
}

class Program
{
    [SavePathType]$m_eSavePathType
    [string]$m_Log
    [Array]$m_Setting

    Program()
    {
        $settingFilePath = [Path]::Combine([Directory]::GetParent($PSScriptRoot).FullName, "Setting.ini")
        $this.LoadSettingFile($settingFilePath)
        $this.m_eSavePathType = [Enum]::Parse([SavePathType], $this.m_Setting.Option.SavePathType) 
        [GitManager]::Initialize()
    }

    hidden [void] LoadSettingFile([string]$path)
    {
        if ((Test-Path $path) -eq $false)
        {
            [Logger]::WriteLineErrorCovered("Setting.ini 파일이 없습니다.", "")
            exit -1
        }

        
        $this.m_Setting = [FileUtil]::ReadInifile($path)
    }

    [void] Run()
    {
        [string]$GitPath = [GitManager]::GetRootGitPath($PSScriptRoot).tag1
        [string]$GetterPath = [Directory]::GetParent($PSScriptRoot).FullName
        [string]$OutputPath = ""
        [string]$CommitHash = ""
        [List[string]]$CommitFileList = New-Object List[string]

        
        [Console]::Write("뽑고자 커밋해쉬 입력 : ")
        $CommitHash = [Console]::ReadLine()

        if ($CommitHash.Trim().Length -le 0)
        {
            $CommitHash = "HEAD"
        }

        
        $CommitFileList = [GitManager]::GetCommitFiles($GitPath, $CommitHash).tag1
        $OutputPath = [Directory]::CreateDirectory([Path]::Combine($GetterPath, $CommitHash)).FullName
        $completeFileCount = 0
        [Console]::Clear()

        
        $this.m_Log += "커밋 해쉬 : " + $CommitHash + " / " + "출력일 : " + [DateTime]::Now.ToString("yyyy-MM-dd tt-HH-mm-ss") + "`r`n`r`n"
        $this.m_Log += "[목록]`r`n"

        foreach ($commitFile in $CommitFileList)
        {
            [string]$CommitFileName = [Path]::GetFileName($commitFile)
            [string]$CommitFileDirectory = [Path]::GetDirectoryname($commitFile)
            [string]$SaveasPath = ""

            if ($this.m_eSavePathType -eq [SavePathType]::eIgnorePath)
            {
                $SaveasPath = [Path]::Combine($OutputPath, $CommitFileName).Replace('\', '/')
            }
            elseif ($this.m_eSavePathType -eq [SavePathType]::eAbsolutePath)
            {
                $SaveasPath = [Path]::Combine([Path]::Combine($OutputPath, $CommitFileDirectory), $CommitFileName).Replace('\', '/')
                $directoryPath = [Path]::GetDirectoryname($SaveasPath)
                if ((Test-Path $directoryPath) -eq $false)
                {
                    [Directory]::CreateDirectory($directoryPath)
                }
            }
            else
            {
                [Logger]::WriteLineErrorCovered("잘못된 enum 값입니다.", "")
                exit -1
            }

            [Logger]::NoLog = $true
            [GitManager]::SaveFileAsInSpecificCommitHash($GitPath, $CommitHash, $commitFile, $SaveasPath)
            [Logger]::NoLog = $false
            
            [Console]::CursorTop = 0
            [Logger]::WriteLineNotice("작업 진행률 : " + (++$completeFileCount) + " / " +  $CommitFileList.Count + " ( " +  [Math]::Round($completeFileCount / $CommitFileList.Count * 100, 2) + "% )")

            [Console]::CursorTop = 1 + $completeFileCount
            [Logger]::WriteLineNotice($commitFile + " 복사완료")

            [FileInfo]$fileInfo = New-Object FileInfo($SaveasPath)
            $bytes = $fileInfo.Length
            $kiloBytes = [Math]::Ceiling($fileInfo.Length / 1024)

            $this.m_Log += "{0} --- {1}KB ({2}B)  `r`n" -f $commitFile, $kiloBytes, $bytes
            
        }

        [File]::WriteAllText([DateTime]::Now.ToString("[LOG] yyyy-MM-dd tt-HH-mm-ss") + ".txt", $this.m_Log)
        [Logger]::WriteLineNotice("작업이 완료되었습니다 ^^")
    }
}