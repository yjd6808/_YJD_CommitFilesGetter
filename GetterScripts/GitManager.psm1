#작성자 : 윤정도
#작성일 : 20-02-25
#수정일 : 20-06-01
#목적   : 윤정환 팀장님이 만들라고 하신 깃 프로젝트를 수행하고자 만듬.

####################################################
# 현재 이 깃 매니저는 완성도가 높지않다.
# 깃 함수 실패여부를 제대로 받아내는 기능을 구현할 필요가 있다.
# 전부 갈아엎어야하는 코드임
# 우선 작동하는데로 구현해보자.
# $LASTEXITCODE 응용하면 해결가능 할 듯(팀장님 코드 참고) 언젠가.. 시간나면.. 
####################################################

####################################################
# 깃 매니저 기능 정리 (검색자로 쓸라고)
# 1. 현재 브랜치명 얻기                  - GetCurrentBranchName()
# 2. 브랜치 목록 가져오기                - GetBranches()
# 3. 원격 브랜치 목록 가져오기           - GetRemoteBranches()
# 4. 브랜치 존재여부                    - ExistBranch()
# 5. 브랜치 갯수 얻기                   - GetBranchesCount()
# 6. 브랜치 삭제                        - RemoveBranch()
# 7. 브랜치 생성                        - CreateBranch()
# 8. 브랜치 또는 커밋해쉬 체크아웃       - Checkout()
# 9. 머지                              - Merge()
# 10. 모든 파일 스테이지 올리기          - AddAllFiles()
# 11. 하나의 파일 스테이지 올리기        - AddFile()
# 13. 여러 파일 스테이지 올리기          - AddFiles()
# 14. 커밋                             - Commit()
# 15. 커밋되지 않은 파일 가져오기        - GetUnCommitedFiles()
# 16. 커밋되지 않은 파일갯수 가져오기    - GetUnCommitedFilesCount()
# 17. 현재 브랜치의 리비전 가져오기      - GetBranchHEADRevision()
# 18. 원격저장소와 동기화하기            - PushFirst() - 원격저장소에 해당 브랜치가 존재하지 않을 경우)      
# 19. 원격저장소와 동기화하기            - Push()      - 원격저장소에 해당 브랜치가 존재할 경우
# 20. 당겨오기                          - Pull()
# 21. 패치하기                          - Fetch()
# 22. 태그 지정하기                     - SetTag()
# 23. 커밋 해쉬의 커밋된 시간 가져오기   - GetCommitHashTimestamp()
# 24. 태그 값으로 커밋해쉬 값 가져오기   - GetCommitHashByTag()
# 25. 태그 목록 얻기                    - GetTags()
# 26. 원격저장소의 브랜치 삭제           - RemoveRemoteBranch()
# 27. 브랜치간 변경된 파일목록 가져오기   - GetDiffFilesBetweenBranch()
# 28. 커밋해쉬간 변경된 파일목록 가져오기 - GetDiffFilesBetweenCommitHash()
# 29. 깃 최상위 경로 얻기               - GetRootGitPath()
# 30. 커밋해쉬의 커밋된 파일들 가져오기   - GetCommitFiles()

using module ".\Logger.psm1"
using module ".\FileUtil.psm1"

using namespace System
using namespace System.IO
using namespace System.Text
using namespace System.Collections.Generic
using namespace System.Management.Automation


class GitCommandResult
{
    [object]$message        #결과 메시지
    [bool]$result           #결과
    [object]$tag1           #Out 매개변수1
    [object]$tag2           #Out 매개변수2
    [object]$tag3           #Out 매개변수3
    [object]$tag4           #Out 매개변수4

    GitCommandResult()
    {
        $this.message = [string]::Empty
        $this.result = $false
        $this.tag1 = $null
        $this.tag2 = $null
        $this.tag3 = $null
        $this.tag4 = $null
    }
}


class GitManager
{
    static [DefaultParameterDictionary] $s_DefaultParameterValues = $PSDefaultParameterValues
    static [bool]                       $s_IsBashInitialized = $false
    static [string]                     $s_GitCmdPath = ""
    static [string]                     $s_GitBashPath = ""
    
    [void] static Initialize()
    {
        #깃 설치 경로 지정
        [GitManager]::s_GitCmdPath = & (Join-Path -Path ([Environment]::SystemDirectory) -ChildPath 'where.exe') git

        if ((Test-Path ([GitManager]::s_GitCmdPath)) -eq $false)
        {
            [Logger]::WriteLineNotice("깃이 설치되어 있지 않습니다", "")
            exit -1
        }

        [GitManager]::s_GitBashPath = Join-Path -Path  ([Directory]::GetParent([Path]::GetDirectoryName([GitManager]::s_GitCmdPath))) -ChildPath 'bin/bash.exe'

        if ((Test-Path ([GitManager]::s_GitBashPath)) -eq $false)
        {
            [Logger]::WriteLineNotice("{0} 깃의 bash.exe 파일이 존재하지 않습니다" -f [GitManager]::s_GitBashPath, "")
            exit -1
        }

        [GitManager]::s_IsBashInitialized = $true
        [Logger]::WriteLineNotice("Git 설치 확인 및 Bash 경로지정 완료 (설치 경로 {0})" -f [GitManager]::s_GitBashPath)
    }

    [void] static SetOutputEncoding([string]$encodingType)
    {
        [GitManager]::s_DefaultParameterValues['Out-File:Encoding'] = $encodingType
        [Logger]::WriteLineNotice("Git 출력파일 인코딩 설정완료 (설정된 인코딩 타입 : " + $encodingType + ")")
    }

    hidden [bool] static IsCommandSuccess([string]$msg)
    {
    
        if (($msg.ToLower().StartsWith("fatal")                -eq $true) -or 
            ($msg.ToLower().StartsWith("error")                -eq $true) -or 
            ($msg.Contains("error")                  -eq $true) -or
            ($msg.ToLower().Contains("is not a git command")   -eq $true))
        {
            return $false
        }

        return $true
    }


    <#########################################################################
                                현재 브랜치명 얻기

    반환값 : 경로 [string]
    ##########################################################################>
    hidden [GitCommandResult] static GetCurrentBranchName([string]$gitPath)
    {
        [GitCommandResult]$result = [GitCommandResult]::new()

        if( (Test-Path $gitPath) -eq $false )
        {
            [Logger]::WriteLineErrorCovered($gitPath + "경로가 존재하지 않습니다", "올바른 깃 경로를 입력해주세요")
            exit -1
        }

        Set-Location -Path $gitPath

        $result.message = Invoke-Expression ("git rev-parse --abbrev-ref HEAD")
        $result.result = [GitManager]::IsCommandSuccess($result.message)
        $result.tag1 = $result.message.Trim()

        if ($result.result -eq $false)
        {
            [Logger]::WriteLineErrorCovered($gitPath + "의 브랜치 정보를 가져오는데 실패하였습니다", $result.message)
            exit -1
        }

        return $result
    }

    <#########################################################################
                                 브랜치 목록 얻기
    반환값 : 브랜치배열 [List[string]]
    ##########################################################################>

    [GitCommandResult] static GetBranches([string]$gitPath)
    {
        if( (Test-Path $gitPath) -eq $false )
        {
            [Logger]::WriteLineErrorCovered($gitPath + "경로가 존재하지 않습니다", "올바른 깃 경로를 입력해주세요")
            exit -1
        }

        [GitCommandResult]$result = [GitCommandResult]::new()
        Set-Location -Path $gitPath

        $unRefinedBranches = [Array](Invoke-Expression ("git branch"))
        $refinedBranches = New-Object List[string]

        $result.message= [string]$unRefinedBranches
        $result.result = [GitManager]::IsCommandSuccess($result.message)

        if ($result.result -eq $true)
        {
            for ($i = 0; $i -lt $unRefinedBranches.Length; $i++ )
            {
                $branchName = [string]$unRefinedBranches[$i]
                $branchName = $branchName.Trim()
                if ($branchName.Contains("*"))
                {
                    $branchName = $branchName.Replace("*", "").Trim()
                }

                $refinedBranches.Add($branchName)
            }

            $result.tag1 = $refinedBranches
            [Logger]::WriteLineNoticeCovered($gitPath + "의 브랜치 목록을 가져오는데 성공하였습니다")
        }
        else
        {
            [Logger]::WriteLineErrorCovered($gitPath + "의 브랜치 목록을 가져오는데 실패하였습니다", $result.message)
            exit -1
        }

        return $result
    }

    <#########################################################################
                                 원격 브랜치 목록 얻기
    반환값 : 브랜치배열 [List[string]]
    ##########################################################################>

    [GitCommandResult] static GetRemoteBranches([string]$gitPath)
    {
        if( (Test-Path $gitPath) -eq $false )
        {
            [Logger]::WriteLineErrorCovered($gitPath + "경로가 존재하지 않습니다", "올바른 깃 경로를 입력해주세요")
            exit -1
        }

        [List[string]]$remoteBranches = New-Object List[string]
        [GitCommandResult]$result = [GitCommandResult]::new()
        Set-Location -Path $gitPath

        $result.message = git branch -r 
        $result.result = [GitManager]::IsCommandSuccess($result.message)

        if ( $result.result -eq $true)
        {
            [Logger]::WriteLineNoticeCovered($gitPath + " 경로의 원격 브랜치 목록을 가져오는데 성공했습니다.")

            if (([string]$result.message).Trim().Length -gt 0)
            {
                foreach ($remoteBranch in $result.message)
                {
                    $remoteBranches.Add(([string]$remoteBranch).Trim())
                }
            }

            $result.tag1 = $remoteBranches
        }
        else 
        {
            [Logger]::WriteLineErrorCovered($gitPath +  " 경로의 원격 브랜치 목록을 가져오는데 실패했습니다", $result.message)
            exit -1;
        }

        
        return $result
    }

    <#########################################################################
                                 브랜치 존재여부
    반환값 : isExist [bool]
    ##########################################################################>

    [GitCommandResult] static ExistBranch([string]$gitPath, [string]$branchName)
    {
        if( (Test-Path $gitPath) -eq $false )
        {
            [Logger]::WriteLineErrorCovered($gitPath + "경로가 존재하지 않습니다", "올바른 깃 경로를 입력해주세요")
            exit -1
        }

        [GitCommandResult]$result = [GitCommandResult]::new()
        [GitCommandResult]$getBranchesResult = [GitManager]::GetBranches($gitPath)

        if ($getBranchesResult.result -eq $true)
        {
             [List[string]]$refinedBranches = $getBranchesResult.tag1
             if ($refinedBranches.Exists([Predicate[string]]{ $args[0] -eq $branchName }))
             {
                $result.result = $true
                $result.message = "success"
                [Logger]::WriteLineNoticeCovered($gitPath + "의 경로에 " + $branchName + "라는 브랜치가 존재합니다")
             }
             else
             {
                [Logger]::WriteLineErrorCovered($gitPath + "의 경로에 " + $branchName + "라는 브랜치가 존재하지 않습니다", "")
                $result.result = $false
             }
        }
        return $result
    }

    <#########################################################################
                                 브랜치 갯수 얻기
    반환값 : 브랜치갯수 [int]
    ##########################################################################>

    [GitCommandResult] static GetBranchesCount([string]$gitPath)
    {
        if( (Test-Path $gitPath) -eq $false )
        {
            [Logger]::WriteLineErrorCovered($gitPath + "경로가 존재하지 않습니다", "올바른 깃 경로를 입력해주세요")
            exit -1
        }

        [GitCommandResult]$result = [GitCommandResult]::new()
        Set-Location -Path $gitPath

        $unRefinedBranches = [Array](Invoke-Expression ("git branch"))
        $result.message= [string]$unRefinedBranches
        $result.result = [GitManager]::IsCommandSuccess($unRefinedBranches)

        if ($result.result -eq $true)
        {
            $result.tag1 = $unRefinedBranches.Count
            #[Logger]::WriteLineNoticeCovered($gitPath + "의 브랜치수를 획득하는데 성공하였습니다")
        }
        else
        {
            [Logger]::WriteLineErrorCovered($gitPath + "의 브랜치수를 획득하는데 실패하였습니다", $result.message)
            exit -1
        }

        return $result
    }



    <#########################################################################
                              브랜치 삭제
    ##########################################################################>
    [GitCommandResult] static RemoveBranch([string]$gitPath,  [string] $branchName)
    {
        if( (Test-Path $gitPath) -eq $false )
        {
            [Logger]::WriteLineErrorCovered($gitPath + "경로가 존재하지 않습니다", "올바른 깃 경로를 입력해주세요")
            exit -1
        }

        [GitCommandResult]$result = [GitCommandResult]::new()
        Set-Location -Path $gitPath

        $beforeBranchesCount = [int]([GitManager]::GetBranchesCount($gitPath).tag1)

        if ($beforeBranchesCount -eq 0)
        {
            [Logger]::WriteLineErrorCovered($gitPath + "의 브랜치" + $branchName + " 삭제에 실패하였습니다")
            exit -1
        }

        $result.message = Invoke-Expression ("git branch -D " + $branchName)
        $result.result = [GitManager]::IsCommandSuccess($result.message)

        $afterBranchesCount = [int]([GitManager]::GetBranchesCount($gitPath).tag1)

         #브랜치 수가 줄었으면 삭제된것이므로 성공
        if ($afterBranchesCount -lt $beforeBranchesCount)
        {
            $result.result = $true
            [Logger]::WriteLineNoticeCovered($gitPath + "의 브랜치 " + $branchName + " 삭제에 성공하였습니다")
        }
        else
        {
            [Logger]::WriteLineErrorCovered($gitPath + "의 브랜치 " + $branchName + " 삭제에 실패하였습니다.", $result.message)
            exit -1
        }

        return $result
    }


    <#########################################################################
                                브랜치 생성
    ##########################################################################>
    [GitCommandResult] static CreateBranch([string]$gitPath,  [string] $branchName)
    {
        if( (Test-Path $gitPath) -eq $false )
        {
            [Logger]::WriteLineErrorCovered($gitPath + "경로가 존재하지 않습니다", "올바른 깃 경로를 입력해주세요")
            exit -1
        }

        [GitCommandResult]$result = [GitCommandResult]::new()
        Set-Location -Path $gitPath

        $beforeBranchesCount = [int]([GitManager]::GetBranchesCount($gitPath).tag1)

        if ($beforeBranchesCount -eq 0)
        {
            [Logger]::WriteLineErrorCovered($gitPath + "의 " + $branchName + " 브랜치를 생성하는데 실패하였습니다")
            exit -1
        }

        $result.message = Invoke-Expression ("git branch " + $branchName)
        $result.result = [GitManager]::IsCommandSuccess($result.message)

            $afterBranchesCount = [int]([GitManager]::GetBranchesCount($gitPath).tag1)

        #브랜치 수가 늘었으면 생성된것이므로 성공
        if ($afterBranchesCount -gt $beforeBranchesCount)
        {
            $result.result = $true
            [Logger]::WriteLineNoticeCovered($gitPath + "에 브랜치 " + $branchName + "를 생성하였습니다")
        }
        else
        {
            [Logger]::WriteLineErrorCovered($gitPath + "에 브랜치 " + $branchName + "생성에 실패하였습니다.", $result.message)
            exit -1
        }

        return $result
    }


    <#########################################################################
                           브랜치 또는 커밋해쉬 체크아웃
    ##########################################################################>
    [GitCommandResult] static Checkout([string]$gitPath,  [string] $to)
    {
        if( (Test-Path $gitPath) -eq $false )
        {
            [Logger]::WriteLineErrorCovered($gitPath + "경로가 존재하지 않습니다", "올바른 깃 경로를 입력해주세요")
            exit -1
        }

        [GitCommandResult]$result = [GitCommandResult]::new()
        Set-Location -Path $gitPath

        $result.message = Invoke-Git ("git checkout " + $to)
        $result.result = [GitManager]::IsCommandSuccess($result.message)

        if ($result.result -eq $true)
        {
            [Logger]::WriteLineNoticeCovered($gitPath + "에 " + $to + "로 체크아웃에 성공하였습니다")
        }
        else 
        {
            [Logger]::WriteLineErrorCovered($gitPath + "에 " + $to + "로 체크아웃에 실패하였습니다.", $result.message)
            exit -1
        }

        return $result
    }

 
    <#########################################################################
                                 머지
    ##########################################################################>
    [GitCommandResult] static Merge([string]$gitPath,  [string] $src, [string] $dst)
    {
        if( (Test-Path $gitPath) -eq $false )
        {
            [Logger]::WriteLineErrorCovered($gitPath + "경로가 존재하지 않습니다", "올바른 깃 경로를 입력해주세요")
            exit -1
        }

        [GitCommandResult]$result = [GitCommandResult]::new()
        Set-Location -Path $gitPath
        [Logger]::WriteLineNoticeCovered("머지 하기위해 " +  $dst + " 로 체크아웃을 시작합니다...")
        [GitManager]::Checkout($gitPath, $dst)
        
        $result.message = git merge $src | Out-Host
        $result.result = [GitManager]::IsCommandSuccess($result.message)
        Write-Host  $result.message

       if ($result.result -eq $true)
        {
            [Logger]::WriteLineNoticeCovered($gitPath + "의 " +  $src + " 를 " + $dst + " 로 머지 하는데 성공하였습니다")
        }
        else 
        {
            [Logger]::WriteLineErrorCovered($gitPath + "에 " + $src + " 를 " + $dst + " 로 머지 하는데 실패했습니다", $result.message)
            exit -1
        }

        return $result
    }

    <#########################################################################
                            모든 파일 스테이지 올리기
    ##########################################################################>
    [GitCommandResult] static AddAllFiles([string]$gitPath)
    {
        if( (Test-Path $gitPath) -eq $false )
        {
            [Logger]::WriteLineErrorCovered($gitPath + "경로가 존재하지 않습니다", "올바른 깃 경로를 입력해주세요")
            exit -1
        }

        [GitCommandResult]$result = [GitCommandResult]::new()
        [string]$currentBranchName = [string]([GitManager]::GetCurrentBranchName($gitPath).tag1)
        Set-Location -Path $gitPath

        $result.message = git add . | Out-String
        $result.result = [GitManager]::IsCommandSuccess($result.message)

        if ($result.result -eq $true)
        {
            [Logger]::WriteLineNoticeCovered($gitPath + "경로의 " + $currentBranchName + " 브랜치의 스테이지에 모든 파일을 추가하였습니다")
        }
        else 
        {
            [Logger]::WriteLineErrorCovered($gitPath + "경로의 " + $currentBranchName + " 브랜치의 스테이지에 모든 파일을 추가하는데 실패하였습니다", $result.message)
            exit -1;
        }


        return $result
    }

    <#########################################################################
                          하나의 파일 스테이지에 올리기
    ##########################################################################>
    [GitCommandResult] static AddFile([string]$gitPath,  [string] $addFilePath)
    {
        if( (Test-Path $gitPath) -eq $false )
        {
            [Logger]::WriteLineErrorCovered($gitPath + "경로가 존재하지 않습니다", "올바른 깃 경로를 입력해주세요")
            exit -1
        }

        [GitCommandResult]$result = [GitCommandResult]::new()
        [string]$currentBranchName = [string]([GitManager]::GetCurrentBranchName($gitPath).tag1)
        Set-Location -Path $gitPath

        $result.message = git add $addFilePath | Out-String
        $result.result = [GitManager]::IsCommandSuccess($result.message)

        if ($result.result -eq $true)
        {
            [Logger]::WriteLineNotice($gitPath + "경로의 " + $currentBranchName + " 브랜치의 스테이지에 " + $addFilePath + " 파일을 추가하였습니다")
        }
        else 
        {
            [Logger]::WriteLineErrorCovered($gitPath + "경로의 " + $currentBranchName + " 브랜치의 스테이지에 " + $addFilePath + " 파일을 추가하는데 실패하였습니다", $result.message)
            exit -1;
        }


        return $result
    }

    <#########################################################################
                                파일 리스트 추가
    ##########################################################################>
    [GitCommandResult] static AddFiles([string]$gitPath,  [System.Collections.Generic.List[string]] $addFiles)
    {
        if( (Test-Path $gitPath) -eq $false )
        {
            [Logger]::WriteLineErrorCovered($gitPath + "경로가 존재하지 않습니다", "올바른 깃 경로를 입력해주세요")
            exit -1
        }

        [GitCommandResult]$result = [GitCommandResult]::new()
        
        [string]$currentBranchName = [string]([GitManager]::GetCurrentBranchName($gitPath).tag1)
        Set-Location -Path $gitPath
        $result.result = $true

        foreach ($file in $addFiles)
        {
            $result.message = git add $file | Out-String
            $result.result = [GitManager]::IsCommandSuccess($result.message)

            if ($result.result -eq $false)
            {
                [Logger]::WriteLineErrorCovered($gitPath + "경로의 " + $currentBranchName + " 브랜치의 스테이지에 " + $file + " 파일을 추가하는데 실패하였습니다", $result.message)
                exit -1;
            }

            [Logger]::WriteLineNotice($gitPath + "경로의 " + $currentBranchName + " 브랜치의 스테이지에 " + $file + " 파일을 추가하였습니다")
        }
        return $result
    }

    <#########################################################################
                                커밋
    ##########################################################################>
    [GitCommandResult] static Commit([string]$gitPath, [string]$message)
    {
        if( (Test-Path $gitPath) -eq $false )
        {
            [Logger]::WriteLineErrorCovered($gitPath + "경로가 존재하지 않습니다", "올바른 깃 경로를 입력해주세요")
            exit -1
        }

        [GitCommandResult]$result = [GitCommandResult]::new()
        [string]$currentBranchName = [string]([GitManager]::GetCurrentBranchName($gitPath).tag1)

        Set-Location -Path $gitPath

        if ($message -eq [String]::Empty)
        {
            $message = "No message"
        }

        $result.message = git commit -m ""$message"" | Out-String
        $result.result = [GitManager]::IsCommandSuccess($result.message)

        if ($result.result -eq $true)
        {
            [Logger]::WriteLineNoticeCovered($gitPath + "경로의 " + $currentBranchName + " 브랜치에 커밋을 완료하였습니다")
        }
        else 
        {
            [Logger]::WriteLineErrorCovered($gitPath + "경로의 " + $currentBranchName + " 브랜치에 커밋을 실패하였습니다", $result.message)
            exit -1;
        }

        
        return $result
    }



    <#########################################################################
                        커밋되지 않은 파일 가져오기

    반환값 :  AddedList  [System.Collections.Generic.List[string]]
    반환값 : ModifiedList [System.Collections.Generic.List[string]]
    반환값 : UnStagedList [System.Collections.Generic.List[string]]
    반환값 :  DeletedList [System.Collections.Generic.List[string]]
    ##########################################################################>
    [GitCommandResult] static GetUnCommitedFiles([string]$gitPath)
    {
        if( (Test-Path $gitPath) -eq $false )
        {
            [Logger]::WriteLineErrorCovered($gitPath + "경로가 존재하지 않습니다", "올바른 깃 경로를 입력해주세요")
            exit -1
        }

        [GitCommandResult]$result = [GitCommandResult]::new()
        [string]$currentBranchName = [string](([GitManager]::GetCurrentBranchName($gitPath)).tag1)
        Set-Location -Path $gitPath
                

        $result.message = git status -s -u
        $result.result = [GitManager]::IsCommandSuccess($result.message)

        if ($result.result -eq $true)
        {
            [Logger]::WriteLineNoticeCovered($gitPath + "경로의 " + $currentBranchName + " 브랜치의 커밋되지 않은 파일들을 성공적으로 가져왔습니다")
        }
        else 
        {
            [Logger]::WriteLineErrorCovered($gitPath + "경로의 " + $currentBranchName + " 브랜치에 커밋되지 않은 파일들을 가져오는데 실패하였습니다", $result.message)
            exit -1;
        }

        
        $UnStagedList = New-Object System.Collections.Generic.List[string]
        $AddedList = New-Object  System.Collections.Generic.List[string]
        $ModifiedList = New-Object  System.Collections.Generic.List[string]
        $DeletedList = New-Object  System.Collections.Generic.List[string]

        [Array]$files = git status -s

        foreach ($file in $files)
        {
            [string]$fileName = ([string]$file).TrimStart()
            if($fileName.StartsWith("A"))
            {
                $AddedList.Add($fileName.Remove(0, 1).Replace('"', ' ').Trim())
            }
            elseif ($fileName.StartsWith('M'))
            {
                $ModifiedList.Add($fileName.Remove(0, 1).Replace('"', ' ').Trim())
            }
            elseif ($fileName.StartsWith('??'))
            {
                $UnStagedList.Add($fileName.Remove(0, 2).Replace('"', ' ').Trim())
            }
            elseif ($fileName.StartsWith('D'))
            {
                $DeletedList.Add($fileName.Remove(0, 1).Replace('"', ' ').Trim())
            }
        }

        $result.tag1 = $AddedList
        $result.tag2 = $ModifiedList
        $result.tag3 = $UnStagedList
        $result.tag4 = $DeletedList

        return $result
    }

    <#########################################################################
                        커밋되지 않은 파일갯수 가져오기
    반환값 : unCommitedFilesCount [int]                   
    ##########################################################################>
    [GitCommandResult] static GetUnCommitedFilesCount([string]$gitPath)
    {
        if( (Test-Path $gitPath) -eq $false )
        {
            [Logger]::WriteLineErrorCovered($gitPath + "경로가 존재하지 않습니다", "올바른 깃 경로를 입력해주세요")
            exit -1
        }

        [GitCommandResult]$result = [GitCommandResult]::new()
        [string]$currentBranchName = [string](([GitManager]::GetCurrentBranchName($gitPath)).tag1)
        Set-Location -Path $gitPath
                
        $result.message = git status -s 
        $result.result = [GitManager]::IsCommandSuccess($result.message)
        $unCommitedFilesCount = 0
        if ($result.result -eq $true)
        {
            [Array]$files = git status -s

            foreach ($file in $files)
            {
                [string]$fileName = ([string]$file).TrimStart()
                if($fileName.StartsWith("A"))
                {
                    $unCommitedFilesCount++
                }
                elseif ($fileName.StartsWith('M'))
                {
                    $unCommitedFilesCount++
                }
                elseif ($fileName.StartsWith('??'))
                {
                    $unCommitedFilesCount++
                }
                elseif ($fileName.StartsWith('D'))
                {
                    $unCommitedFilesCount++
                }
            }

            [Logger]::WriteLineNoticeCovered($gitPath + "경로의 " + $currentBranchName + " 브랜치의 커밋되지 않은 파일들의 갯수는 " + $unCommitedFilesCount + "개 입니다")
            $result.tag1 = $unCommitedFilesCount
        }
        else 
        {
            [Logger]::WriteLineErrorCovered($gitPath + "경로의 " + $currentBranchName + " 브랜치에 커밋되지 않은 파일들을 가져오는데 실패하였습니다", $result.message)
            exit -1;
        }

        
       

        return $result
    }

    <#########################################################################
                        현재 브랜치의 리비전 가져오기
    반환값 : 커밋 리비전 [string]
    ##########################################################################>
    [GitCommandResult] static GetBranchHEADRevision([string]$gitPath, [string]$branchName)
    {
        if( (Test-Path $gitPath) -eq $false )
        {
            [Logger]::WriteLineErrorCovered($gitPath + "경로가 존재하지 않습니다", "올바른 깃 경로를 입력해주세요")
            exit -1
        }

        [GitCommandResult]$result = [GitCommandResult]::new()
        Set-Location -Path $gitPath
        $result.message = (git rev-parse $branchName | Out-String).Trim()
        if ($result.message -eq $branchName)
        {
            $result.result = $false
        }
        else
        {
            $result.result = $true
        }

        $result.tag1 = $result.message

        if ($result.result -eq $true)
        {
            [Logger]::WriteLineNoticeCovered($gitPath + "경로의 " + $branchName + " 브랜치의 커밋 리비전은 " + $result.message + " 입니다")
        }
        else 
        {
            [Logger]::WriteLineErrorCovered($gitPath + "경로의 " + $branchName + " 브랜치의 리비전을 불러오는데 실패하였습니다", "올바른 깃 경로인지 올바른 브랜치 명인지 확인해주세요")
            exit -1;
        }

        return $result
    }

    <#########################################################################
         원격저장소와 동기화하기 (원격저장소에 해당 브랜치가 존재하지 않을 경우)
    ##########################################################################>
    [GitCommandResult] static PushFirst([string]$gitPath, [string]$branchName)
    {
        if( (Test-Path $gitPath) -eq $false )
        {
            [Logger]::WriteLineErrorCovered($gitPath + "경로가 존재하지 않습니다", "올바른 깃 경로를 입력해주세요")
            exit -1
        }

        [GitCommandResult]$result = [GitCommandResult]::new()
        [string]$currentBranchName = [string](([GitManager]::GetCurrentBranchName($gitPath)).tag1)
        Set-Location -Path $gitPath

        $result.message = Invoke-Git ("git push -u origin " + $branchName)
        $result.result = [GitManager]::IsCommandSuccess($result.message)
        $result.tag1 = $result.message

        if ($result.result -eq $true)
        {
            [Logger]::WriteLineNoticeCovered($gitPath + "경로의 " + $currentBranchName + " 브랜치의 원격저장소와 처음 동기화에 성공했습니다")
        }
        else 
        {
            [Logger]::WriteLineErrorCovered($gitPath + "경로의 " + $currentBranchName + " 브랜치의 원격저장소와 처음 동기화에 실패했습니다", $result.message)
            exit -1;
        }

        return $result
    }

    <#########################################################################
         로컬 저장소 -> 원격저장소와 동기화 (원격저장소에 해당 브랜치가 존재하고있을 경우)
    ##########################################################################>
    [GitCommandResult] static Push([string]$gitPath)
    {
        if( (Test-Path $gitPath) -eq $false )
        {
            [Logger]::WriteLineErrorCovered($gitPath + "경로가 존재하지 않습니다", "올바른 깃 경로를 입력해주세요")
            exit -1
        }

        [GitCommandResult]$result = [GitCommandResult]::new()
        [string]$currentBranchName = [string](([GitManager]::GetCurrentBranchName($gitPath)).tag1)
        Set-Location -Path $gitPath

        $result.message = Invoke-Git ("git push")
        $result.result = [GitManager]::IsCommandSuccess($result.message)
        $result.tag1 = $result.message

        if ($result.result -eq $true)
        {
            [Logger]::WriteLineNoticeCovered($gitPath + "경로의 " + $currentBranchName + " 브랜치의 로컬저장소 -> 원격저장소와 동기화에 성공했습니다")
        }
        else 
        {
            [Logger]::WriteLineErrorCovered($gitPath + "경로의 " + $currentBranchName + " 브랜치의 로컬저장소 -> 원격저장소와 동기화에 실패했습니다", $result.message)
            exit -1;
        }

        return $result
    }

    <#########################################################################
         원격 저장소 -> 로컬저장소와 동기화 (원격저장소에 해당 브랜치가 존재하고있을 경우)
    ##########################################################################>
    [GitCommandResult] static Pull([string]$gitPath)
    {
        if( (Test-Path $gitPath) -eq $false )
        {
            [Logger]::WriteLineErrorCovered($gitPath + "경로가 존재하지 않습니다", "올바른 깃 경로를 입력해주세요")
            exit -1
        }

        [GitCommandResult]$result = [GitCommandResult]::new()
        [string]$currentBranchName = [string](([GitManager]::GetCurrentBranchName($gitPath)).tag1)
        Set-Location -Path $gitPath

        $result.message = git pull
        $result.result = [GitManager]::IsCommandSuccess($result.message)
        $result.tag1 = $result.message

        if ($result.result -eq $true)
        {
            [Logger]::WriteLineNoticeCovered($gitPath + "경로의 " + $currentBranchName + " 브랜치의 원격저장소 -> 로컬저장소와 동기화에 성공했습니다")
        }
        else 
        {
            [Logger]::WriteLineErrorCovered($gitPath + "경로의 " + $currentBranchName + " 브랜치의 원격저장소 -> 로컬저장소와 동기화에 실패했습니다", $result.message)
            exit -1;
        }

        return $result
    }


    <#########################################################################
                               패치하기
    ##########################################################################>
    [GitCommandResult] static Fetch([string]$gitPath)
    {
        if( (Test-Path $gitPath) -eq $false )
        {
            [Logger]::WriteLineErrorCovered($gitPath + "경로가 존재하지 않습니다", "올바른 깃 경로를 입력해주세요")
            exit -1
        }

        [GitCommandResult]$result = [GitCommandResult]::new()
        Set-Location -Path $gitPath

        $result.message = git fetch
        $result.result = [GitManager]::IsCommandSuccess($result.message)

        if ($result.result -eq $true)
        {
            [Logger]::WriteLineNoticeCovered($gitPath + " 저장소를 원격저장소로부터 패치하였습니다.")
        }
        else 
        {
            [Logger]::WriteLineErrorCovered($gitPath + " 저장소를 원격저장소로부터 패치하는데 실패했습니다.", $result.message)
            exit -1;
        }

        return $result
    }

    <#########################################################################
                               태그 지정
    ##########################################################################>
    [GitCommandResult] static SetTag([string]$gitPath, [string]$tag)
    {
        if( (Test-Path $gitPath) -eq $false )
        {
            [Logger]::WriteLineErrorCovered($gitPath + "경로가 존재하지 않습니다", "올바른 깃 경로를 입력해주세요")
            exit -1
        }

        [GitCommandResult]$result = [GitCommandResult]::new()
        Set-Location -Path $gitPath

        $result.message = git tag $tag
        $result.result = [GitManager]::IsCommandSuccess($result.message)
        $result.tag1 = $result.message

        if ($result.result -eq $true)
        {
            [Logger]::WriteLineNoticeCovered($gitPath + "경로의 HEAD 리비전에 태그 " + $tag + "를 지정하였습니다")
        }
        else 
        {
            [Logger]::WriteLineErrorCovered($gitPath + "경로의 HEAD 리비전에 태그 " + $tag + "를 지정하는데 실패했습니다.", $result.message)
            exit -1;
        }

        return $result
    }

    <#########################################################################
                          커밋 해쉬의 커밋된 시간 가져오기
    ##########################################################################>
    [GitCommandResult] static GetCommitHashTimestamp([string]$gitPath, [string]$revision)
    {
        if( (Test-Path $gitPath) -eq $false )
        {
            [Logger]::WriteLineErrorCovered($gitPath + "경로가 존재하지 않습니다", "올바른 깃 경로를 입력해주세요")
            exit -1
        }

        [GitCommandResult]$result = [GitCommandResult]::new()
        Set-Location -Path $gitPath

        $result.message = Invoke-Git ("git show -s --format=%ct " + $revision) 
        $result.result = [GitManager]::IsCommandSuccess($result.message)
        $result.tag1 = ([string]$result.message).Trim()

        if ($result.result -eq $true)
        {
            [Logger]::WriteLineNoticeCovered($gitPath + "경로의 리비 " + $revision + "에 해당하는 타임스탬프 값은 " + $result.message + " 입니다.")
        }
        else 
        {
            [Logger]::WriteLineErrorCovered($gitPath + "경로의 리비 " + $revision + "에 해당하는 타임스탬프 값을 얻는데 실패했습니다.", $result.message)
            exit -1;
        }

        return $result
    }

    <#########################################################################
                            태그 값으로 커밋해쉬 값 가져오기
    ##########################################################################>
    [GitCommandResult] static GetCommitHashByTag([string]$gitPath, [string]$tag)
    {
        if( (Test-Path $gitPath) -eq $false )
        {
            [Logger]::WriteLineErrorCovered($gitPath + "경로가 존재하지 않습니다", "올바른 깃 경로를 입력해주세요")
            exit -1
        }

        [GitCommandResult]$result = [GitCommandResult]::new()
        Set-Location -Path $gitPath

        $result.message = Invoke-Git ("git rev-list -n 1 " + $tag) #git rev-list -n 1 $tag
        $result.result = [GitManager]::IsCommandSuccess($result.message)
        $result.tag1 = ([string]$result.message).Trim()

        if ($result.result -eq $true)
        {
            [Logger]::WriteLineNoticeCovered($gitPath + "경로의 태그 " + $tag + "에 해당하는 커밋해쉬는 " + $result.message + " 입니다.")
        }
        else 
        {
            [Logger]::WriteLineErrorCovered($gitPath + "경로의 태그 " + $tag + "에 해당하는 커밋해쉬를 가져오는데 실패했습니다.", $result.message)
            exit -1;
        }

        return $result
    }

    <#########################################################################
                                 태그 목록 얻기
    반환값 : 태그 목록 [List[string]]
    ##########################################################################>

    [GitCommandResult] static GetTags([string]$gitPath)
    {
        if( (Test-Path $gitPath) -eq $false )
        {
            [Logger]::WriteLineErrorCovered($gitPath + "경로가 존재하지 않습니다", "올바른 깃 경로를 입력해주세요")
            exit -1
        }

        [GitCommandResult]$result = [GitCommandResult]::new()
        [string]$currentBranchName = [string](([GitManager]::GetCurrentBranchName($gitPath)).tag1)
        Set-Location -Path $gitPath

        $tagList = New-Object List[string]

        $result.message = git tag
        $result.result = [GitManager]::IsCommandSuccess($result.message)

        if ($result.result -eq $true)
        {
            [Logger]::WriteLineNoticeCovered($gitPath + " 경로의 태그 목록을 가져오는데 성공했습니다.")

            foreach ($tag in $result.message)
            {
                $tagList.Add($tag)
            }

            $result.tag1 = $tagList
        }
        else 
        {
            [Logger]::WriteLineErrorCovered($gitPath +  " 경로의 태그 목록을 가져오는데 실패했습니다", $result.message)
            exit -1;
        }

        
        return $result
    }

    <#########################################################################
                        원격저장소의 브랜치 삭제
    ##########################################################################>
    [GitCommandResult] static RemoveRemoteBranch([string]$gitPath, [string]$remoteBranchName)
    {
        if( (Test-Path $gitPath) -eq $false )
        {
            [Logger]::WriteLineErrorCovered($gitPath + "경로가 존재하지 않습니다", "올바른 깃 경로를 입력해주세요")
            exit -1
        }

        [GitCommandResult]$result = [GitCommandResult]::new()
        [string]$currentBranchName = [string](([GitManager]::GetCurrentBranchName($gitPath)).tag1)
        Set-Location -Path $gitPath

        $result.message = Invoke-Git ("git push -d origin " + $remoteBranchName)
        $result.result = [GitManager]::IsCommandSuccess($result.message)
        $result.tag1 = $result.message

        if ($result.result -eq $true)
        {
            [Logger]::WriteLineNoticeCovered($gitPath + "경로의 " + $currentBranchName + " 브랜치를 원격저장소에서 삭제하는데 성공했습니다.")
        }
        else 
        {
            [Logger]::WriteLineErrorCovered($gitPath + "경로의 " + $currentBranchName + " 브랜치를 원격저장소에서 삭제하는데 실패했습니다.", $result.message)
            exit -1;
        }

        return $result
    }

    <#########################################################################
                     브랜치간 변경된 파일목록 가져오기
    반환값 : 브랜치간 변경사항있는 파일 List[string]
    ##########################################################################>
     [GitCommandResult] static GetDiffFilesBetweenBranch([string]$gitPath, [string]$lhsBranchName, [string]$rhsBranchName)
     {
        if( (Test-Path $gitPath) -eq $false )
        {
            [Logger]::WriteLineErrorCovered($gitPath + "경로가 존재하지 않습니다", "올바른 깃 경로를 입력해주세요")
            exit -1
        }

        [GitCommandResult]$result = [GitCommandResult]::new()
        Set-Location -Path $gitPath

        [string]$lhsBranchHEADRevision = [string]([GitManager]::GetBranchHEADRevision($gitPath, $lhsBranchName).tag1)
        [string]$rhsBranchHEADRevision = [string]([GitManager]::GetBranchHEADRevision($gitPath, $rhsBranchName).tag1)

        if ($lhsBranchHEADRevision -eq $rhsBranchHEADRevision)
        {
            [Logger]::WriteLineErrorCovered($gitPath + "경로의 " + $lhsBranchName + " 브랜치와 " + $rhsBranchName + " 브랜치간 변경사항이 있는 파일 목록을 가져오는데 실패했습니다 ㅠㅠ", "두 브랜치간 리비전이 동일합니다.")
            exit -1
        }

        [Array]$diffFilesArray = git diff --name-only $lhsBranchHEADRevision $rhsBranchHEADRevision
        $result.message = $diffFilesArray
        $result.result = [GitManager]::IsCommandSuccess($result.message)

        [List[string]]$diffFilesList = New-Object List[string]

        foreach ($diffFile in $diffFilesArray)
        {
             $fileTrimed = ([string]$diffFile).Trim()
            if ($fileTrimed.Length -gt 0)
            {
                $diffFilesList.Add($fileTrimed)
            }
        }

        $result.tag1 = $diffFilesList

        if ($result.result -eq $true)
        {
            [Logger]::WriteLineNoticeCovered($gitPath + "경로의 " + $lhsBranchName + " 브랜치와 " + $rhsBranchName + " 브랜치간 변경사항이 있는 파일 목록을 가져오는데 성공했습니다")
        }
        else 
        {
            [Logger]::WriteLineErrorCovered($gitPath + "경로의 " + $lhsBranchName + " 브랜치와 " + $rhsBranchName + " 브랜치간 변경사항이 있는 파일 목록을 가져오는데 실패했습니다 ㅠㅠ", $result.message)
            exit -1;
        }

        return $result
     }

    <#########################################################################
                      커밋간 변경된 파일 목록 가져오기
    반환값 : 브랜치간 변경사항있는 파일 List[string]
    ##########################################################################>
     [GitCommandResult] static GetDiffFilesBetweenCommitHash([string]$gitPath, [string]$lhsCommitHash, [string]$rhsCommitHash)
     {
        if( (Test-Path $gitPath) -eq $false )
        {
            [Logger]::WriteLineErrorCovered($gitPath + "경로가 존재하지 않습니다", "올바른 깃 경로를 입력해주세요")
            exit -1
        }

        [GitCommandResult]$result = [GitCommandResult]::new()
        Set-Location -Path $gitPath

        if ($lhsCommitHash -eq $rhsCommitHash)
        {
            [Logger]::WriteLineErrorCovered("리비전이 서로 동일합니다.", "")
            exit -1
        }

        [Array]$diffFilesArray = git diff --name-only $lhsCommitHash $rhsCommitHash
        $result.message = $diffFilesArray
        $result.result = [GitManager]::IsCommandSuccess($result.message)
        [List[string]]$diffFilesList = New-Object List[string]

        foreach ($diffFile in $diffFilesArray)
        {
             $fileTrimed = ([string]$diffFile).Trim()
            if ($fileTrimed.Length -gt 4) #확장자명 보통 확장자명만 넣어도 4자 넘으니까..
            {
                $diffFilesList.Add($fileTrimed)
            }
        }
        $result.tag1 = $diffFilesList

        if ($result.result -eq $true)
        {
            [Logger]::WriteLineNoticeCovered($gitPath + "경로의 " + $lhsCommitHash + " 커밋해쉬와 " + $rhsCommitHash + " 커밋해쉬간 변경사항이 있는 파일 목록을 가져오는데 성공했습니다")
        }
        else 
        {
            [Logger]::WriteLineErrorCovered($gitPath + "경로의 " + $lhsCommitHash + " 커밋해쉬와 " + $rhsCommitHash + " 커밋해쉬간 변경사항이 있는 파일 목록을 가져오는데 실패했습니다 ㅠㅠ", $result.message)
            exit -1;
        }

        return $result
     }

    <#########################################################################
                                 깃 최상위 경로 얻기
    반환값 : 현재 깃의 최상위 경로
    ##########################################################################>
    [GitCommandResult] static GetRootGitPath([string]$gitPath)
    {
        [GitCommandResult]$result = [GitCommandResult]::new()
        Set-Location $gitPath

        $result.message = git rev-parse --show-toplevel | Out-String
        $result.result = [GitManager]::IsCommandSuccess($result.message)
        $result.tag1 = ([string]$result.message).Trim()

        if (([string]$result.message).Trim().Length -eq 0)
        {
            $result.result = $false
        }


        if ($result.result -eq $true)
        {
            [Logger]::WriteLineNoticeCovered("해당 깃 경로의 최상위 경로는 " + $result.message + " 입니다.")
        }
        else 
        {
            [Logger]::WriteLineErrorCovered("최상위 깃 경로를 얻지 못했습니다. 올바른 경로인지 확인해주세요", $result.message)
            exit -1;
        }

        return $result
    }

    <#########################################################################
                        지정된 머지 커밋해쉬의 파일들 가져오기
    반환값 : 파일 목록 [List[string]]
    ##########################################################################>

    hidden [GitCommandResult] static GetMergeCommitFiles([string]$gitPath, [string]$commitHash)
    {
        if( (Test-Path $gitPath) -eq $false )
        {
            [Logger]::WriteLineErrorCovered($gitPath + "경로가 존재하지 않습니다", "올바른 깃 경로를 입력해주세요")
            exit -1
        }

        [GitCommandResult]$result = [GitCommandResult]::new()
        Set-Location -Path $gitPath

        [Array]$commitFiles = git log -m -1 --name-only --pretty="format:" $commitHash
        $result.message = $commitFiles
        $result.result = [GitManager]::IsCommandSuccess($result.message)
        [List[string]]$commitFileList = New-Object List[string]

        if ($commitFiles.Count -eq 0)
        {
            $result.result = $false
        }

        foreach ($commitfile in $commitFiles)
        {
            if (([string]$commitFile).Trim().Length -eq 0)
            {
                break
            }
            $commitFileList.Add($commitfile)
        }
        $result.tag1 = $commitFileList
        return $result
    }


    <#########################################################################
                        지정된 커밋해쉬의 파일들 가져오기
    반환값 : 파일 목록 [List[string]]
    ##########################################################################>

    [GitCommandResult] static GetCommitFiles([string]$gitPath, [string]$commitHash)
    {
        if( (Test-Path $gitPath) -eq $false )
        {
            [Logger]::WriteLineErrorCovered($gitPath + "경로가 존재하지 않습니다", "올바른 깃 경로를 입력해주세요")
            exit -1
        }

        [GitCommandResult]$result = [GitCommandResult]::new()
        Set-Location -Path $gitPath

        [Array]$commitFiles = git diff-tree --no-commit-id --name-only -r $commitHash
        $result.message = $commitFiles
        $result.result = [GitManager]::IsCommandSuccess($result.message)
        [List[string]]$commitFileList = New-Object List[string]

       
        
        if ($commitFiles.Count -eq 0)
        {
            [GitCommandResult]$getMergeCommitFilesResult = [GitManager]::GetMergeCommitFiles([string]$gitPath, [string]$commitHash)

            if ($getMergeCommitFilesResult.result -eq $false)
            {
                $result.result = $false
            }
            else
            {
                [List[string]]$mergeCommitFiles = $getMergeCommitFilesResult.tag1
                foreach ($commitfile in $mergeCommitFiles)
                {
                    $commitFileList.Add($commitfile)
                }
            }
        }
        else
        {
            foreach ($commitfile in $commitFiles)
            {
                $commitFileList.Add($commitfile)
            }
        }

        $result.tag1 = $commitFileList

        if ($result.result -eq $true)
        {
            [Logger]::WriteLineNoticeCovered($gitPath + "경로의 " + $commitHash + " 커밋해쉬의 파일 목록을 가져오는데 성공했습니다")
        }
        else 
        {
            [Logger]::WriteLineNoticeCovered($gitPath + "경로의 " + $commitHash + " 커밋해쉬의 파일 목록을 가져오는데 실패했습니다")
            exit -1
        }
        
        return $result
    }

    <#########################################################################
                    특정 커밋해쉬의 파일을 다른이름으로 저장하기
    반환값 : 파일 목록 [List[string]]
    ##########################################################################>
    # srcFileMiddlePath : 깃 경로의 기준으로부터 시작된 경로를 입력해줘야함 (ex) 깃경로 : C:/skidrush이고 옮길파일이 C:/skidrush/Resource/text.txt 이라면 Resource/text.txt가 MiddlePath이다.)
    
    [GitCommandResult] static SaveFileAsInSpecificCommitHash([string]$gitPath, [string]$commitHash, [string]$srcFileMiddlePath, [string]$dstFileFullPath)
    {
        if ([GitManager]::s_IsBashInitialized -eq $false)
        {
            [Logger]::WriteLineErrorCovered("깃 배쉬경로가 초기화 되지 않았습니다. [GitMananger]::Initialize() 함수를 호출하여 먼저 배요쉬 경로를 지정해주세", "이 기능은 bash 명령어를 사용합니다")
        }

        if( (Test-Path $gitPath) -eq $false )
        {
            [Logger]::WriteLineErrorCovered($gitPath + "경로가 존재하지 않습니다", "올바른 깃 경로를 입력해주세요")
            exit -1
        }

        [GitCommandResult]$result = [GitCommandResult]::new()
        Set-Location -Path $gitPath

        [string]$hashWithMiddlePath = $commitHash + ":" + $srcFileMiddlePath
        [Directory]::CreateDirectory([Path]::GetDirectoryName($dstFileFullPath))

        $gitCmdScript = 
        '
            git show {0} > {1}
        '  -f $hashWithMiddlePath, $dstFileFullPath -replace "`r", ""
        & ([GitManager]::s_GitBashPath) -c $gitCmdScript | Out-String

        if ($LASTEXITCODE -eq 0)
        {
            $result.result = $true
        }
        else
        {
            $result.result = $false
        }

        if ($result.result -eq $true)
        {
            [Logger]::WriteLineNoticeCovered($gitPath + "경로의 " + $commitHash + " 커밋해쉬의 파일 : " + $srcFileMiddlePath + "을 " + $dstFileFullPath + "경로에 저장하는데 성공했습니다.")
        }
        else 
        {
            [Logger]::WriteLineNoticeCovered($gitPath + "경로의 " + $commitHash + " 커밋해쉬의 파일 : " + $srcFileMiddlePath + "을 새로운 경로로 저장하는데 실패했습니다.")
            exit -1
        }
        
        return $result
    }
}





function Invoke-Git { 
    param (
        [Parameter(Mandatory)]
        [string] $Command  
    )

    [string]$content = ""
    try {
        $exit = 0
        $path = [System.IO.Path]::GetTempFileName()
        Invoke-Expression "$Command 2> $path"
        $exit = $LASTEXITCODE
        $content = ([string](Get-Content $path))
        if ($content.Length -gt 7 -and $content.Contains("~~~~~~~~~~~~~~~~"))
        {
            $content = $content.Remove(0, 6).TrimStart().Split(@("~~~~~~~~~~~~~~~~"), [StringSplitOptions]::None)[0]
        }
        return $content
    }
    catch
    {
        Write-Host "Error: $_`n$($_.ScriptStackTrace)"
        return $returnMessag
    }
    finally
    {
        if ( Test-Path $path )
        {
            Remove-Item $path
        }
    }


}
