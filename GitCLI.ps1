# GitCLI.ps1 - 最终全能推送版
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
chcp 65001 > $null

Clear-Host
Write-Host "===========================================" -ForegroundColor Cyan
Write-Host "         Git 菜单工具（全能推送版）" -ForegroundColor Green
Write-Host "===========================================" -ForegroundColor Cyan

Set-Location -Path $PSScriptRoot

function Get-CurrentBranch {
    try {
        $branch = git rev-parse --abbrev-ref HEAD 2>$null
        if ($LASTEXITCODE -eq 0 -and $branch) { return $branch.Trim() }
        return "detached"
    } catch { return "no-git" }
}

function Invoke-GitQuietly {
    param([string]$Command)
    Invoke-Expression "$Command 2>&1" | ForEach-Object { "$_" }
}

while ($true) {
    Clear-Host
    $branch = Get-CurrentBranch
    Write-Host "当前分支: [$branch]" -ForegroundColor Yellow
    Write-Host "仓库路径: $(Get-Location)" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "请选择操作（输入数字后回车）：" -ForegroundColor Green
    Write-Host "1. 拉取最新代码       (git pull)"
    Write-Host "2. 推送选项菜单       (Push / Commit+Push)" -ForegroundColor Magenta
    Write-Host "3. 拉取远程分支       (最新在前，显示时间+消息)"
    Write-Host "4. 切换本地分支"
    Write-Host "5. 查看状态           (git status)"
    Write-Host "6. 查看日志           (git log --oneline --graph)"
    Write-Host "0. 退出程序"
    Write-Host ""

    $choice = Read-Host "请输入 0-6"

    switch ($choice) {
        "1" { 
            Write-Host "正在拉取代码..." -ForegroundColor Cyan
            Invoke-GitQuietly "git pull"
        }
        
        "2" {
            Write-Host "`n--- 推送功能细分 ---" -ForegroundColor Magenta
            Write-Host "1. 普通推送 (仅推送已有的 Commit)"
            Write-Host "2. 强制推送 (仅推送已有的 Commit - 覆盖远端)" -ForegroundColor Red
            Write-Host "3. [一键提交] + 普通推送" -ForegroundColor Cyan
            Write-Host "4. [一键提交] + 强制推送 (覆盖远端)" -ForegroundColor Yellow
            Write-Host "0. 返回主菜单"
            $pushChoice = Read-Host "请选择"
            
            if ($pushChoice -match '^[1234]$') {
                $commitMsg = ""
                # 如果选择 3 或 4，先询问提交信息
                if ($pushChoice -eq "3" -or $pushChoice -eq "4") {
                    $commitMsg = Read-Host "请输入提交信息 (直接回车使用默认)"
                    if (-not $commitMsg) { $commitMsg = "Update: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" }
                    Write-Host "正在暂存并提交..." -ForegroundColor Gray
                    git add .
                    git commit -m "$commitMsg"
                }

                # 执行推送逻辑
                switch ($pushChoice) {
                    "1" { 
                        Write-Host "执行普通推送..." -ForegroundColor Cyan
                        Invoke-GitQuietly "git push" 
                    }
                    "2" { 
                        Write-Host "确认强制推送吗？(y/n)" -ForegroundColor Red
                        if ((Read-Host) -eq "y") { Invoke-GitQuietly "git push --force-with-lease" }
                    }
                    "3" { 
                        Write-Host "提交完成，正在普通推送..." -ForegroundColor Cyan
                        Invoke-GitQuietly "git push" 
                    }
                    "4" { 
                        Write-Host "提交完成，确认强制覆盖远端吗？(y/n)" -ForegroundColor Red
                        if ((Read-Host) -eq "y") { Invoke-GitQuietly "git push --force-with-lease" }
                    }
                }
            }
        }

        "5" { git status }
        "6" { git log --oneline --graph --decorate --all -20 }

        "3" {
            Write-Host "`n正在更新远程信息..." -ForegroundColor Yellow
            git fetch --quiet 2>&1 | Out-Null
            $lsOutput = git ls-remote --heads origin 2>$null
            $remoteBranches = @()
            foreach ($line in $lsOutput) {
                if ($line -match '^[0-9a-f]{40}\s+refs/heads/(.+)$') {
                    $branchName = $matches[1]
                    $fullRef = "origin/$branchName"
                    $logLine = git log -1 --format="%cd|%s" --date=iso-local $fullRef 2>$null
                    if ($logLine) {
                        $parts = $logLine -split '\|', 2
                        $isoDate = $parts[0].Trim()
                        $message = $parts[1].Trim()
                        $displayTime = "unknown"
                        if ($isoDate -match '^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}') {
                            try {
                                $commitDate = [DateTime]::ParseExact($isoDate.Substring(0,19), "yyyy-MM-dd HH:mm:ss", $null)
                                $span = New-TimeSpan -Start $commitDate -End (Get-Date)
                                if ($span.TotalMinutes -lt 60) { $displayTime = "{0} m ago" -f [math]::Round($span.TotalMinutes) }
                                elseif ($span.TotalHours -lt 24) { $displayTime = "{0} h ago" -f [math]::Round($span.TotalHours) }
                                else { $displayTime = "{0} d ago" -f [math]::Floor($span.TotalDays) }
                            } catch { $displayTime = $isoDate.Substring(0,10) }
                        }
                        $shortMsg = if ($message.Length -gt 60) { $message.Substring(0,57) + "..." } else { $message }
                        $remoteBranches += [PSCustomObject]@{ FullName=$fullRef; DisplayName=$branchName; Time=$displayTime; Message=$shortMsg; CommitDate=$commitDate }
                    }
                }
            }
            $remoteBranches = $remoteBranches | Sort-Object CommitDate -Descending
            if ($remoteBranches.Count -gt 0) {
                Write-Host "远程分支列表：`n" -ForegroundColor Green
                Write-Host ("{0,-3} {1,-50} {2,-15} {3}" -f "序号", "分支名", "最后提交", "提交消息")
                for ($i=0; $i -lt $remoteBranches.Count; $i++) {
                    $b = $remoteBranches[$i]
                    Write-Host ("{0,-3} {1,-50} {2,-15} {3}" -f ($i+1), $b.DisplayName, $b.Time, $b.Message)
                }
                $select = Read-Host "`n输入序号拉取"
                if ($select -match '^\d+$' -and [int]$select -le $remoteBranches.Count) {
                    $selected = $remoteBranches[[int]$select-1]
                    $local = $selected.DisplayName
                    if (git branch --list $local) {
                        if ((Get-CurrentBranch) -ne $local) { Invoke-GitQuietly "git checkout $local" }
                        Invoke-GitQuietly "git pull origin $local"
                    } else {
                        Invoke-GitQuietly "git checkout -b $local $($selected.FullName)"
                    }
                }
            }
        }

        "4" {
            $localBranches = git branch --format='%(refname:short)'
            $current = Get-CurrentBranch
            for ($i=0; $i -lt $localBranches.Count; $i++) {
                $name = $localBranches[$i]
                Write-Host "$($i+1). $(if($name -eq $current){"* "}) $name"
            }
            $select = Read-Host "`n输入序号切换"
            if ($select -match '^\d+$' -and [int]$select -le $localBranches.Count) {
                Invoke-GitQuietly "git checkout $($localBranches[[int]$select-1])"
            }
        }

        "0" { return }
    }
    Write-Host ""
    Read-Host "按 Enter 键继续..."
}