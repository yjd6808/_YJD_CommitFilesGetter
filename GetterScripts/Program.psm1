##�ۼ��� : ������
##�ۼ��� : 20-06-02

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

enum SaveEncodingType
{
    eUnknown
    eString
    eUnicode
    eUnicodeBigEndian
    eUTF7
    eUTF8
    eUTF32
    eASCII
    eDefault
    eOEM
}


class Program
{
    [SavePathType]$m_eSavePathType
    [SaveEncodingType]$m_eSaveEncodingType
    [string]$m_Log
    [Array]$m_Setting
    [HashTable]$m_EncodingMap =
    @{ 
            [SaveEncodingType]::eUnknown = 'unknown';
            [SaveEncodingType]::eString = 'string';
            [SaveEncodingType]::eUnicode = 'unicode';
            [SaveEncodingType]::eUnicodeBigEndian = 'bigendianunicode';
            [SaveEncodingType]::eUTF7 = 'utf7';
            [SaveEncodingType]::eUTF8 = 'utf8';
            [SaveEncodingType]::eUTF32 = 'utf32';
            [SaveEncodingType]::eDefault = 'default';
            [SaveEncodingType]::eASCII = 'ascii';
            [SaveEncodingType]::eOEM = 'oem';
    }

    Program()
    {
        $settingFilePath = [Path]::Combine([Directory]::GetParent($PSScriptRoot).FullName, "Setting.ini")
        $this.LoadSettingFile($settingFilePath)
        $this.m_eSavePathType = [Enum]::Parse([SavePathType], $this.m_Setting.Option.SavePathType) 
        $this.m_eSaveEncodingType = [Enum]::Parse([SaveEncodingType], $this.m_Setting.Option.SaveEncodingType) 
        [GitManager]::Initialize()
        [GitManager]::SetOutputEncoding($this.m_EncodingMap[$this.m_eSaveEncodingType])


    }

    hidden [void] LoadSettingFile([string]$path)
    {
        if ((Test-Path $path) -eq $false)
        {
            [Logger]::WriteLineErrorCovered("Setting.ini ������ �����ϴ�.", "")
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

        
        [Console]::Write("�̰��� Ŀ���ؽ� �Է� : ")
        $CommitHash = [Console]::ReadLine()

        if ($CommitHash.Trim().Length -le 0)
        {
            $CommitHash = "HEAD"
        }


        $CommitFileList = [GitManager]::GetCommitFiles($GitPath, $CommitHash).tag1
        $OutputPath = [Directory]::CreateDirectory([Path]::Combine($GetterPath, [DateTime]::Now.ToString("yyyy-MM-dd tt-HH-mm-ss - ���"))).FullName
        $completeFileCount = 0
        [Console]::Clear()

        
        $this.m_Log += "Ŀ�� �ؽ� : " + $CommitHash + " / " + "����� : " + [DateTime]::Now.ToString("yyyy-MM-dd tt-HH-mm-ss") + "`r`n`r`n"
        $this.m_Log += "[���ڵ�]`r`n {0} `r`n`r`n" -f $this.m_eSaveEncodingType.ToString()
        $this.m_Log += "[���]`r`n"

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
                [Logger]::WriteLineErrorCovered("�߸��� enum ���Դϴ�.", "")
                exit -1
            }

            [Logger]::NoLog = $true
            [GitManager]::SaveFileAsInSpecificCommitHash($GitPath, $CommitHash, $commitFile, $SaveasPath)
            [Logger]::NoLog = $false
            
            [Console]::CursorTop = 0
            [Logger]::WriteLineNotice("�۾� ����� : " + (++$completeFileCount) + " / " +  $CommitFileList.Count + " ( " +  [Math]::Round($completeFileCount / $CommitFileList.Count * 100, 2) + "% )")

            [Console]::CursorTop = 1 + $completeFileCount
            [Logger]::WriteLineNotice($commitFile + " ����Ϸ�")

            [FileInfo]$fileInfo = New-Object FileInfo($SaveasPath)
            $bytes = $fileInfo.Length
            $kiloBytes = [Math]::Ceiling($fileInfo.Length / 1024)

            $this.m_Log += "{0} --- {1}KB ({2}B)  `r`n" -f $commitFile, $kiloBytes, $bytes
            
        }

        [File]::WriteAllText([DateTime]::Now.ToString("[LOG] yyyy-MM-dd tt-HH-mm-ss") + ".txt", $this.m_Log)
        [Logger]::WriteLineNotice("�۾��� �Ϸ�Ǿ����ϴ� ^^")
    }
}