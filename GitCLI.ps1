# ============================
# GitCLI.ps1 - 单文件企业级版
# ============================

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
chcp 65001 > $null
Clear-Host
Set-Location -Path $PSScriptRoot

# ----------------------------
# 全局颜色方案
# ----------------------------
$ColorInfo    = "Cyan"
$ColorSuccess = "Green"
$ColorWarn    = "Yellow"
$ColorError   = "Red"
$ColorMenu    = "Magenta"
$ColorGray    = "Gray"

# ----------------------------
# 日志系统
# ----------------------------
$Global:LogDir  = Join-Path $PSScriptRoot "logs"
if (-not (Test-Path $Global:LogDir)) {
    New-Item -ItemType Directory -Path $Global:LogDir | Out-Null
}
$Global:LogFile = Join-Path $Global:LogDir "gitcli.log"

function Write-Log {
    param([string]$Message)

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Add-Content -Path $Global:LogFile -Value "[$timestamp] $Message"
}

# ----------------------------
# Git 执行封装（带日志 + 错误处理）
# ----------------------------
function Run-Git {
    param([string]$Cmd)

    Write-Log "EXEC: $Cmd"
    $output = Invoke-Expression "$Cmd 2>&1"

    if ($LASTEXITCODE -ne 0) {
        Write-Host "Git 命令失败: $Cmd" -ForegroundColor $ColorError
        if ($output) {
            Write-Host $output -ForegroundColor $ColorError
        }
        Write-Log "ERROR: $output"
        return $null
    }

    if ($output) {
        Write-Log "OK: $output"
    } else {
        Write-Log "OK: (no output)"
    }

    return $output
}

# ----------------------------
# 核心基础功能
# ----------------------------
function Get-CurrentBranch {
    $branch = Run-Git "git rev-parse --abbrev-ref HEAD"
    if (-not $branch) { return "no-git" }
    return $branch.Trim()
}

function Has-UncommittedChanges {
    $status = Run-Git "git status --porcelain"
    return ($status -ne "")
}

function Detect-Conflicts {
    $output = Run-Git "git diff --name-only --diff-filter=U"
    if ($output) {
        Write-Host "? 检测到冲突文件：" -ForegroundColor $ColorError
        $output | ForEach-Object {
            if ($_ -and $_.Trim().Length -gt 0) {
                Write-Host "   - $_" -ForegroundColor $ColorError
            }
        }
        return $true
    }
    return $false
}

# ----------------------------
# 自动 stash / pop
# ----------------------------
function Auto-Stash {
    if (Has-UncommittedChanges) {
        Write-Host "检测到未提交文件，是否自动 stash？(y/n，默认 n)" -ForegroundColor Yellow
        $ans = Read-Host
        if ($ans -eq "y" -or $ans -eq "Y") {
            Run-Git "git stash push -m 'Auto stash before operation'" | Out-Null
            return $true
        }
    }
    return $false
}

function Auto-Pop {
    param([bool]$DidStash)

    if ($DidStash) {
        Write-Host "正在恢复 stash..." -ForegroundColor $ColorInfo
        Run-Git "git stash pop"
    }
}

# ----------------------------
# 一键提交
# ----------------------------
function Commit-Changes {
    $msg = Read-Host "请输入提交信息（回车使用默认）"
    if (-not $msg) {
        $msg = "Update: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
    }

    Run-Git "git add ."
    Run-Git "git commit -m '$msg'"
}

# ----------------------------
# 本地分支选择器（支持搜索）
# ----------------------------
function Select-Branch {
    param([string]$Prompt = "选择分支")

    $branches = Run-Git "git branch --format='%(refname:short)'"
    if (-not $branches) { return $null }

    # Run-Git 可能返回 string 或 string[]
    if ($branches -is [string]) {
        $branches = $branches -split "`n" | ForEach-Object { $_.Trim() } | Where-Object { $_ }
    }

    while ($true) {
        Clear-Host
        Write-Host "$Prompt（输入关键词过滤，直接回车显示全部）" -ForegroundColor $ColorInfo
        $keyword = Read-Host "搜索"

        $filtered = if ($keyword) {
            $branches | Where-Object { $_ -like "*$keyword*" }
        } else {
            $branches
        }

        if (-not $filtered -or $filtered.Count -eq 0) {
            Write-Host "无匹配分支，按 Enter 重新搜索..." -ForegroundColor $ColorWarn
            [void](Read-Host)
            continue
        }

        Write-Host ""
        for ($i = 0; $i -lt $filtered.Count; $i++) {
            Write-Host ("{0,2}. {1}" -f ($i + 1), $filtered[$i])
        }

        $sel = Read-Host "`n输入序号（或空回车取消）"
        if (-not $sel) { return $null }

        if ($sel -match '^\d+$') {
            $idx = [int]$sel
            if ($idx -ge 1 -and $idx -le $filtered.Count) {
                return $filtered[$idx - 1]
            }
        }

        Write-Host "无效选择，按 Enter 重试..." -ForegroundColor $ColorWarn
        [void](Read-Host)
    }
}

function Switch-Branch {
    if (Detect-Conflicts) {
        Write-Host "请先解决冲突再切换分支。" -ForegroundColor $ColorError
        return
    }

    $target = Select-Branch "切换分支"
    if ($target) {
        Run-Git "git checkout $target"
    }
}

# ----------------------------
# 远程分支按时间排序
# ----------------------------
function Get-RemoteBranches {
    Write-Host "正在获取远程分支信息..." -ForegroundColor $ColorInfo
    Run-Git "git fetch --quiet" | Out-Null

    $ls = Run-Git "git ls-remote --heads origin"
    if (-not $ls) { return @() }

    if ($ls -is [string]) {
        $ls = $ls -split "`n" | ForEach-Object { $_.Trim() } | Where-Object { $_ }
    }

    $result = @()

    foreach ($line in $ls) {
        if ($line -match '^[0-9a-f]{40}\s+refs/heads/(.+)$') {
            $branch = $matches[1]
            $ref    = "origin/$branch"

            $log = Run-Git "git log -1 --format='%cd|%s' --date=iso-local $ref"
            if (-not $log) { continue }

            # Run-Git返回 string 或 string[]，这里只取第一行
            if ($log -is [array]) { $log = $log[0] }

            $parts = $log -split '\|', 2
            if ($parts.Count -lt 2) { continue }

            $date = $parts[0].Trim()
            $msg  = $parts[1].Trim()

            $dt = $null
            try {
                $dt = [DateTime]::ParseExact($date.Substring(0,19), "yyyy-MM-dd HH:mm:ss", $null)
            } catch {
                $dt = Get-Date "2000-01-01"
            }

            $shortMsg = if ($msg.Length -gt 60) { $msg.Substring(0,57) + "..." } else { $msg }

            $result += [PSCustomObject]@{
                Branch     = $branch
                FullRef    = $ref
                CommitDate = $dt
                Message    = $shortMsg
            }
        }
    }

    return $result | Sort-Object CommitDate -Descending
}

function Select-RemoteBranch {
    $list = Get-RemoteBranches
    if (-not $list -or $list.Count -eq 0) {
        Write-Host "无远程分支。" -ForegroundColor $ColorWarn
        return $null
    }

    Write-Host "`n远程分支（按最后提交时间排序，最新在前）：" -ForegroundColor $ColorSuccess
    Write-Host ("{0,-4} {1,-40} {2,-20} {3}" -f "序号", "分支名", "最后提交时间", "提交消息")
    for ($i = 0; $i -lt $list.Count; $i++) {
        $b = $list[$i]
        Write-Host ("{0,-4} {1,-40} {2,-20} {3}" -f ($i+1), $b.Branch, $b.CommitDate.ToString("yyyy-MM-dd HH:mm"), $b.Message)
    }

    $sel = Read-Host "`n输入序号选择（或空回车返回）"
    if (-not $sel) { return $null }

    if ($sel -match '^\d+$') {
        $idx = [int]$sel
        if ($idx -ge 1 -and $idx -le $list.Count) {
            return $list[$idx - 1]
        }
    }

    Write-Host "无效选择。" -ForegroundColor $ColorWarn
    return $null
}

function Pull-From-RemoteBranch-Interactive {
    $selected = Select-RemoteBranch
    if (-not $selected) { return }

    $localBranch = $selected.Branch
    $fullRef     = $selected.FullRef

    # 判断本地是否已有同名分支
    $existing = Run-Git "git branch --format='%(refname:short)'"
    if ($existing -is [string]) {
        $existing = $existing -split "`n" | ForEach-Object { $_.Trim() } | Where-Object { $_ }
    }

    if ($existing -contains $localBranch) {
        Write-Host "本地已存在同名分支 [$localBranch]，是否切换并拉取？(y/n)" -ForegroundColor $ColorWarn
        $ans = Read-Host
        if ($ans -eq "y" -or $ans -eq "Y") {
            Run-Git "git checkout $localBranch"
            Run-Git "git pull origin $localBranch"
        }
    } else {
        Write-Host "本地不存在分支 [$localBranch]，将从 $fullRef 创建并切换。" -ForegroundColor $ColorInfo
        Run-Git "git checkout -b $localBranch $fullRef"
    }
}

# ----------------------------
# 推送相关
# ----------------------------
function Push-Normal {
    Run-Git "git push"
}

function Push-Force {
    Write-Host "确认强制推送覆盖远端？(y/n)" -ForegroundColor $ColorError
    $ans = Read-Host
    if ($ans -eq "y" -or $ans -eq "Y") {
        Run-Git "git push --force-with-lease"
    }
}

function Push-To-NewBranch {
    $current = Get-CurrentBranch
    if (-not $current -or $current -eq "no-git" -or $current -eq "HEAD" -or $current -eq "detached") {
        Write-Host "当前不在有效分支上，无法创建远程新分支。" -ForegroundColor $ColorError
        return
    }

    $timestamp   = Get-Date -Format "yyyyMMdd-HHmm"
    $defaultName = "backup/$current/$timestamp"

    Write-Host "将当前分支推送到远程新分支（阶段性备份）" -ForegroundColor $ColorInfo
    $name = Read-Host "输入新分支名（回车使用默认：$defaultName）"
    if (-not $name) { $name = $defaultName }

    Run-Git "git push origin HEAD:$name"
    Write-Host "远程已创建分支：$name" -ForegroundColor $ColorSuccess
}

function Show-PushMenu {
    if (Detect-Conflicts) {
        Write-Host "存在冲突文件，请先解决冲突再推送。" -ForegroundColor $ColorError
        return
    }

    if (Has-UncommittedChanges) {
        Write-Host "? 当前存在未提交修改。" -ForegroundColor $ColorWarn
    }

    Write-Host "`n--- 推送功能 ---" -ForegroundColor $ColorMenu
    Write-Host "1. 普通推送"
    Write-Host "2. 强制推送"
    Write-Host "3. 一键提交 + 普通推送"
    Write-Host "4. 一键提交 + 强制推送"
    Write-Host "5. 推送到远程新分支（阶段性备份）"
    Write-Host "0. 返回"
    $c = Read-Host "请选择"

    if ($c -eq "0") { return }

    $didStash = Auto-Stash

    switch ($c) {
        "1" { Push-Normal }
        "2" { Push-Force }
        "3" { Commit-Changes; Push-Normal }
        "4" { Commit-Changes; Push-Force }
        "5" { Push-To-NewBranch }
        default { Write-Host "无效选择。" -ForegroundColor $ColorWarn }
    }

    Auto-Pop $didStash
}

# ----------------------------
# 主菜单
# ----------------------------
function Show-MainMenu {
    while ($true) {
        Clear-Host
        $branch = Get-CurrentBranch

        Write-Host "===========================================" -ForegroundColor $ColorInfo
        Write-Host " Git 菜单工具（单文件模块化企业级版）" -ForegroundColor $ColorSuccess
        Write-Host "===========================================" -ForegroundColor $ColorInfo

        Write-Host "当前分支: [$branch]" -ForegroundColor $ColorWarn
        Write-Host "仓库路径: $(Get-Location)" -ForegroundColor $ColorInfo
        Write-Host ""

        Write-Host "1. 拉取最新代码 (git pull)"
        Write-Host "2. 推送选项菜单 (Push / Commit+Push)" -ForegroundColor $ColorMenu
        Write-Host "3. 远程分支浏览 + 拉取（按时间排序）"
        Write-Host "4. 切换本地分支（交互搜索）"
        Write-Host "5. 查看状态 (git status)"
        Write-Host "6. 查看日志 (git log --oneline --graph --decorate --all -20)"
        Write-Host "0. 退出"
        Write-Host ""

        $choice = Read-Host "请输入 0-6"

        switch ($choice) {
            "1" {
                if (Detect-Conflicts) {
                    Write-Host "存在冲突文件，请先解决冲突再拉取。" -ForegroundColor $ColorError
                } else {
                    $didStash = Auto-Stash
                    Run-Git "git pull"
                    Auto-Pop $didStash
                }
            }
            "2" { Show-PushMenu }
            "3" { Pull-From-RemoteBranch-Interactive }
            "4" { Switch-Branch }
            "5" { Run-Git "git status" | ForEach-Object { Write-Host $_ } }
            "6" { Run-Git "git log --oneline --graph --decorate --all -20" | ForEach-Object { Write-Host $_ } }
            "0" { return }
            default {
                Write-Host "无效选择。" -ForegroundColor $ColorWarn
            }
        }

        Write-Host ""
        Read-Host "按 Enter 键继续..."
    }
}

# ----------------------------
# 启动
# ----------------------------
Show-MainMenu
