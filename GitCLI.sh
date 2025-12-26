#!/usr/bin/env bash

# ============================
# GitCLI.sh - fzf 专业版
# ============================

set -e

# ----------------------------
# 颜色
# ----------------------------
C_INFO="\033[36m"
C_SUCCESS="\033[32m"
C_WARN="\033[33m"
C_ERROR="\033[31m"
C_MENU="\033[35m"
C_RESET="\033[0m"

# ----------------------------
# 前置检查
# ----------------------------
check_dependencies() {
    if ! command -v git >/dev/null 2>&1; then
        echo -e "${C_ERROR}未检测到 git，请先安装 git${C_RESET}"
        exit 1
    fi

    if ! command -v fzf >/dev/null 2>&1; then
        echo -e "${C_ERROR}未检测到 fzf${C_RESET}"
        echo -e "${C_INFO}安装方式:${C_RESET}"
        echo "  sudo apt update && sudo apt install fzf"
        exit 1
    fi

    if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        echo -e "${C_ERROR}当前目录不是 Git 仓库${C_RESET}"
        exit 1
    fi

    # 可选：用于 PR / 分支健康评分
    if ! command -v curl >/dev/null 2>&1; then
        echo -e "${C_WARN}未检测到 curl，部分 GitHub 相关功能将不可用${C_RESET}"
    fi
}

check_dependencies

# ----------------------------
# 日志系统
# ----------------------------
LOG_DIR="./logs"
LOG_FILE="$LOG_DIR/gitcli.log"
mkdir -p "$LOG_DIR"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG_FILE"
}

run_git() {
    log "EXEC: git $*"
    if ! output=$(git "$@" 2>&1); then
        echo -e "${C_ERROR}Git 命令失败: git $*${C_RESET}"
        echo "$output"
        log "ERROR: $output"
        return 1
    fi
    log "OK: $output"
    echo "$output"
}

# ----------------------------
# 基础功能
# ----------------------------
current_branch() {
    git rev-parse --abbrev-ref HEAD
}

has_uncommitted() {
    [[ -n "$(git status --porcelain)" ]]
}

detect_conflicts() {
    conflicts=$(git diff --name-only --diff-filter=U)
    if [[ -n "$conflicts" ]]; then
        echo -e "${C_ERROR}⚠ 检测到冲突文件：${C_RESET}"
        echo "$conflicts"
        return 0
    fi
    return 1
}

# ----------------------------
# 仓库状态仪表盘 + 分支健康
# ----------------------------
branch_health_score() {
    local current_branch
    current_branch=$(current_branch)

    # 默认分数 100，逐项扣减
    local score=100

    # ahead / behind
    local ahead=0
    local behind=0
    if git rev-parse --verify "origin/$current_branch" >/dev/null 2>&1; then
        read -r behind ahead <<<"$(git rev-list --left-right --count "origin/$current_branch...$current_branch" 2>/dev/null)"
    fi

    # ahead/behind 影响
    [[ $behind -gt 0 ]] && score=$((score - 20))
    [[ $ahead -gt 20 ]] && score=$((score - 10))

    # rebase 需求
    [[ $behind -gt 0 ]] && score=$((score - 20))

    # 冲突风险
    if git status --porcelain | grep -q '^UU '; then
        score=$((score - 30))
    fi

    # PR 状态（无 PR 扣分）
    local repo_url api_url pr_count
    if command -v curl >/dev/null 2>&1; then
        repo_url=$(git config --get remote.origin.url | sed 's/.*github.com[:/]\(.*\)\.git/\1/')
        api_url="https://api.github.com/repos/${repo_url}/pulls?head=${repo_url%%/*}:$current_branch"
        pr_count=$(curl -s "$api_url" | grep -c '"html_url"')
        [[ $pr_count -eq 0 ]] && score=$((score - 20))
    fi

    (( score < 0 )) && score=0
    echo "$score"
}

check_pr_status() {
    if ! command -v curl >/dev/null 2>&1; then
        echo -e "${C_WARN}PR 状态：curl 不可用，跳过检测${C_RESET}"
        return
    fi

    local repo_url current_branch api_url pr_count
    repo_url=$(git config --get remote.origin.url | sed 's/.*github.com[:/]\(.*\)\.git/\1/')
    current_branch=$(current_branch)

    api_url="https://api.github.com/repos/${repo_url}/pulls?head=${repo_url%%/*}:${current_branch}"
    pr_count=$(curl -s "$api_url" | grep -c '"html_url"')

    if [[ "$pr_count" -gt 0 ]]; then
        echo -e "${C_SUCCESS}PR 状态：当前分支已有 Pull Request${C_RESET}"
    else
        echo -e "${C_WARN}PR 状态：当前分支尚未创建 PR${C_RESET}"
    fi
}

show_repo_status() {
    local current
    current=$(current_branch)

    local added modified deleted untracked
    added=$(git status --porcelain | grep '^A ' | wc -l)
    modified=$(git status --porcelain | grep '^ M ' | wc -l)
    deleted=$(git status --porcelain | grep '^ D ' | wc -l)
    untracked=$(git status --porcelain | grep '^?? ' | wc -l)

    local ahead=0 behind=0 need_rebase="No"
    if git rev-parse --verify "origin/$current" >/dev/null 2>&1; then
        read -r behind ahead <<<"$(git rev-list --left-right --count "origin/$current...$current" 2>/dev/null)"
        [[ "$behind" -gt 0 ]] && need_rebase="Yes"
    fi

    local conflict_risk="No"
    if git status --porcelain | grep -q '^UU '; then
        conflict_risk="Yes"
    fi

    local health
    health=$(branch_health_score)

    echo -e "${C_MENU}================ GitCLI 状态面板 ================${C_RESET}"
    echo -e "${C_INFO}当前分支：${C_SUCCESS}${current}${C_RESET}"
    echo -e "${C_INFO}远程状态：${C_RESET}ahead ${ahead}, behind ${behind}"
    echo -e "${C_INFO}是否需要 rebase：${C_RESET}${need_rebase}"
    echo -e "${C_INFO}冲突风险：${C_RESET}${conflict_risk}"
    check_pr_status
    echo -e "${C_INFO}分支健康评分：${C_SUCCESS}${health}/100${C_RESET}"
    echo -e "${C_INFO}变更统计：${C_RESET}"
    echo -e "  新增:     ${C_SUCCESS}${added}${C_RESET}"
    echo -e "  修改:     ${C_WARN}${modified}${C_RESET}"
    echo -e "  删除:     ${C_ERROR}${deleted}${C_RESET}"
    echo -e "  未跟踪:   ${C_WARN}${untracked}${C_RESET}"
    echo -e "${C_MENU}=================================================${C_RESET}"
}

# ----------------------------
# 自动 stash / pop
# ----------------------------
auto_stash() {
    if has_uncommitted; then
        echo -e "${C_WARN}检测到未提交文件，是否自动 stash？(y/n)${C_RESET}"
        read -r ans
        if [[ "$ans" == "y" ]]; then
            git stash push -m "Auto stash before operation" >/dev/null
            return 0
        fi
    fi
    return 1
}

auto_pop() {
    if [[ "$1" == "0" ]]; then
        echo -e "${C_INFO}正在恢复 stash...${C_RESET}"
        git stash pop || true
    fi
}

# ----------------------------
# 一键提交（原始版）
# ----------------------------
commit_changes() {
    echo "请输入提交信息（回车使用默认）:"
    read -r msg
    [[ -z "$msg" ]] && msg="Update: $(date '+%Y-%m-%d %H:%M:%S')"

    git add .
    git commit -m "$msg"
}

# ----------------------------
# 智能提交（自动 add + 摘要 + push）
# ----------------------------
smart_commit() {
    echo -e "${C_INFO}🔍 执行智能提交...${C_RESET}"

    # 先看是否有变更
    if [[ -z "$(git status --porcelain)" ]]; then
        echo -e "${C_WARN}当前没有任何变更，无需提交${C_RESET}"
        return
    fi

    git add -A

    local summary=""
    local added modified deleted untracked
    added=$(git status --porcelain | grep '^A ' | wc -l)
    modified=$(git status --porcelain | grep '^ M ' | wc -l)
    deleted=$(git status --porcelain | grep '^ D ' | wc -l)
    untracked=$(git status --porcelain | grep '^?? ' | wc -l)

    [[ $added -gt 0 ]] && summary+="新增:$added "
    [[ $modified -gt 0 ]] && summary+="修改:$modified "
    [[ $deleted -gt 0 ]] && summary+="删除:$deleted "
    [[ $untracked -gt 0 ]] && summary+="未跟踪:$untracked "

    [[ -z "$summary" ]] && summary="无变更"

    git commit -m "auto: $summary"

    echo -e "${C_INFO}⬆️ 推送中...${C_RESET}"
    git push

    echo -e "${C_SUCCESS}🎉 智能提交完成：$summary${C_RESET}"
}

# ----------------------------
# 自动 rebase + 冲突检测
# ----------------------------
auto_rebase() {
    local current
    current=$(current_branch)

    echo -e "${C_INFO}🔄 正在 rebase origin/$current...${C_RESET}"
    if git fetch && git rebase "origin/$current"; then
        echo -e "${C_SUCCESS}🎉 rebase 成功，无冲突${C_RESET}"
    else
        echo -e "${C_ERROR}⚠️ 检测到冲突，请手动解决${C_RESET}"
        git status --porcelain | grep '^UU ' || true
    fi
}

# ----------------------------
# 自动创建 Pull Request（GitHub API）
# 需要环境变量：GITHUB_TOKEN
# ----------------------------
create_pr() {
    if ! command -v curl >/dev/null 2>&1; then
        echo -e "${C_ERROR}curl 不可用，无法创建 PR${C_RESET}"
        return
    fi

    if [[ -z "$GITHUB_TOKEN" ]]; then
        echo -e "${C_ERROR}未检测到 GITHUB_TOKEN 环境变量，无法调用 GitHub API${C_RESET}"
        return
    fi

    local repo_url current_branch title body response pr_url
    repo_url=$(git config --get remote.origin.url | sed 's/.*github.com[:/]\(.*\)\.git/\1/')
    current_branch=$(current_branch)

    title="PR: $current_branch"
    body="Auto-generated PR for branch $current_branch"

    echo -e "${C_INFO}📮 创建 PR 中...${C_RESET}"

    response=$(curl -s -X POST \
        -H "Authorization: token $GITHUB_TOKEN" \
        -H "Accept: application/vnd.github+json" \
        -d "{\"title\":\"$title\",\"body\":\"$body\",\"head\":\"$current_branch\",\"base\":\"main\"}" \
        "https://api.github.com/repos/$repo_url/pulls")

    if echo "$response" | grep -q '"html_url"'; then
        pr_url=$(echo "$response" | grep '"html_url"' | head -1 | sed 's/.*"html_url": "\(.*\)".*/\1/')
        echo -e "${C_SUCCESS}🎉 PR 创建成功：$pr_url${C_RESET}"
    else
        echo -e "${C_ERROR}❌ PR 创建失败${C_RESET}"
        echo "$response"
    fi
}

# ----------------------------
#🟦 ① 自动识别迁移类型（detect_migration_type）
# ----------------------------
detect_migration_type() {
    local deleted_files untracked_files
    deleted_files=$(git status --porcelain | grep '^ D ' | awk '{print $2}')
    untracked_files=$(git status --porcelain | grep '^?? ' | awk '{print $2}')

    if echo "$untracked_files" | grep -q '^docs/'; then
        echo "docs-migration"
    elif echo "$untracked_files" | grep -q '^src/'; then
        echo "src-migration"
    elif echo "$untracked_files" | grep -q -e '^config/' -e '\.ya\?ml$' -e '\.json$'; then
        echo "config-migration"
    elif echo "$untracked_files" | grep -q -e '^ci/' -e '^\.github/workflows'; then
        echo "ci-migration"
    elif echo "$untracked_files" | grep -q -e 'archive/' -e 'DEPRECATED'; then
        echo "archive"
    else
        echo "refactor"
    fi
}

# ----------------------------
#🟩 ② 自动判断“重构 / 归档 / 清理”
# ----------------------------
detect_refactor_or_archive() {
    local untracked deleted

    untracked=$(git status --porcelain | grep '^?? ' | awk '{print $2}')
    deleted=$(git status --porcelain | grep '^ D ' | awk '{print $2}')

    # ① 明确归档场景：archive/ 或 DEPRECATED
    if echo "$untracked" | grep -E -q '(^|/)archive/|DEPRECATED'; then
        echo "archive"
        return
    fi

    # ② rename 检测（Git rename detection）
    if git diff --name-status --find-renames | grep -q '^R'; then
        echo "refactor"
        return
    fi

    # ③ 如果 deleted + untracked 数量接近 → 结构迁移（不是 cleanup）
    if [[ -n "$deleted" && -n "$untracked" ]]; then
        echo "refactor"
        return
    fi

    # ④ 默认：清理
    echo "cleanup"
}



# ----------------------------
#🟧 ③ 自动生成智能 commit message
# ----------------------------
 generate_smart_commit_message() {
    local type summary
    type=$(detect_migration_type)

    local added modified deleted
    added=$(git status --porcelain | grep '^A ' | wc -l)
    modified=$(git status --porcelain | grep '^ M ' | wc -l)
    deleted=$(git status --porcelain | grep -E '^ D |^R' | wc -l)

    case "$type" in
        docs-migration)
            summary="docs: migrate documentation structure ($added added, $deleted removed)"
            ;;
        src-migration)
            summary="refactor(src): restructure source code modules ($added added, $deleted removed)"
            ;;
        config-migration)
            summary="chore(config): reorganize configuration files ($added added, $deleted removed)"
            ;;
        ci-migration)
            summary="ci: restructure CI/CD workflows ($added added, $deleted removed)"
            ;;
        archive)
            summary="chore(archive): archive deprecated files ($added added, $deleted removed)"
            ;;
        refactor)
            summary="refactor: structural file changes ($added added, $deleted removed)"
            ;;
    esac

    echo "$summary"
}




# ----------------------------
#🟨 ④ 自动生成迁移报告
# ----------------------------
generate_migration_report() {
    local type
    type=$(detect_migration_type)

    echo "迁移类型: $type"
    echo "----------------------------------"
    echo "删除文件:"
    git status --porcelain | grep '^ D ' | awk '{print $2}'
    echo ""
    echo "新增文件:"
    git status --porcelain | grep '^?? ' | awk '{print $2}'
    echo ""
    echo "Git rename 检测:"
    git diff --name-status --find-renames | grep '^R' || echo "无 rename"
    echo "----------------------------------"
}



# ----------------------------
#✅ 第 2 步：加入智能迁移主函数（Smart File Migration）
# ----------------------------
smart_file_migration() {
    echo -e "${C_INFO}🔍 正在分析文件结构迁移...${C_RESET}"

    local type ref_or_arch commit_msg
    type=$(detect_migration_type)
    ref_or_arch=$(detect_refactor_or_archive)
    commit_msg=$(generate_smart_commit_message)

    echo -e "${C_INFO}迁移类型：${C_SUCCESS}$type${C_RESET}"
    echo -e "${C_INFO}重构/归档判断：${C_SUCCESS}$ref_or_arch${C_RESET}"
    echo -e "${C_INFO}生成的提交信息：${C_SUCCESS}$commit_msg${C_RESET}"
    echo ""

    echo -e "${C_INFO}迁移报告:${C_RESET}"
    generate_migration_report
    echo ""

    echo -e "${C_WARN}是否执行迁移提交？(y/n)${C_RESET}"
    read -r ans
    [[ "$ans" != "y" ]] && return

    # 变更检查
    if [[ -z "$(git status --porcelain)" ]]; then
        echo -e "${C_WARN}没有可提交的迁移变更${C_RESET}"
        return
    fi

    git add -A
    git commit -m "$commit_msg"
    git push

    echo -e "${C_SUCCESS}🎉 文件结构迁移提交完成${C_RESET}"
}



# ----------------------------
# 文档迁移自动提交（根 → docs/）
# ----------------------------
auto_commit_docs_migration() {
    echo -e "${C_INFO}🔍 检查文档迁移状态...${C_RESET}"

    local deleted_count untracked_docs
    deleted_count=$(git status --porcelain | grep '^ D ' | wc -l)
    untracked_docs=$(git status --porcelain | grep '^?? docs/' | wc -l)

    if [[ $deleted_count -eq 0 && $untracked_docs -eq 0 ]]; then
        echo -e "${C_WARN}未检测到文档迁移相关变更，无需自动提交${C_RESET}"
        return
    fi

    echo -e "${C_INFO}📁 检测到文档迁移：${deleted_count} 个删除，${untracked_docs} 个新增${C_RESET}"

    echo -e "${C_INFO}➡️ 添加 docs/ 下的新文档...${C_RESET}"
    git add docs/

    echo -e "${C_INFO}➡️ 标记旧文档删除 (git add -u)...${C_RESET}"
    git add -u

    echo -e "${C_INFO}📝 创建提交...${C_RESET}"
    git commit -m "docs: restructure documentation into docs/ directory"

    echo -e "${C_INFO}⬆️ 推送到远程...${C_RESET}"
    git push

    echo -e "${C_SUCCESS}🎉 文档迁移自动提交完成！${C_RESET}"
}

# ----------------------------
# 本地分支选择器（fzf + log 预览）
# ----------------------------
select_branch() {
    git branch --format='%(refname:short)' \
        | fzf --prompt="选择分支: " \
              --preview="git log --oneline --graph --decorate --color=always {}" \
              --preview-window=right:60%
}

switch_branch() {
    if detect_conflicts; then
        echo -e "${C_ERROR}请先解决冲突再切换分支。${C_RESET}"
        return
    fi

    target=$(select_branch)
    [[ -n "$target" ]] && git checkout "$target"
}

# ----------------------------
# 远程分支选择器（fzf + log 预览）
# ----------------------------
get_remote_branches() {
    git fetch --quiet
    git ls-remote --heads origin | while read -r hash ref; do
        branch="${ref#refs/heads/}"
        echo "$branch"
    done
}

select_remote_branch() {
    get_remote_branches \
        | fzf --prompt="选择远程分支: " \
              --preview="git log --oneline --graph --decorate --color=always origin/{}" \
              --preview-window=right:60%
}

pull_remote_branch() {
    branch=$(select_remote_branch)
    [[ -z "$branch" ]] && return

    if git branch --list | grep -q "$branch"; then
        git checkout "$branch"
        git pull origin "$branch"
    else
        git checkout -b "$branch" "origin/$branch"
    fi
}

# ----------------------------
# 推送到远程新分支（阶段性备份）
# ----------------------------
push_new_branch() {
    current=$(current_branch)
    timestamp=$(date '+%Y%m%d-%H%M')
    default="backup/$current/$timestamp"

    echo "输入新分支名（回车使用默认：$default）："
    read -r name
    [[ -z "$name" ]] && name="$default"

    git push origin HEAD:"$name"
    echo -e "${C_SUCCESS}远程已创建分支：$name${C_RESET}"
}

# ----------------------------
# 推送菜单（fzf）
# ----------------------------
push_menu() {
    if detect_conflicts; then
        echo -e "${C_ERROR}存在冲突文件，请先解决冲突。${C_RESET}"
        return
    fi

    choice=$(printf "普通推送\n强制推送\n一键提交 + 普通推送\n一键提交 + 强制推送\n推送到远程新分支（阶段性备份）\n智能提交 (auto add + commit + push)\n文档迁移自动提交" \
        | fzf --prompt="选择推送操作: ")

    auto_stash
    did_stash=$?

    case "$choice" in
        "普通推送") git push ;;
        "强制推送") git push --force-with-lease ;;
        "一键提交 + 普通推送") commit_changes; git push ;;
        "一键提交 + 强制推送") commit_changes; git push --force-with-lease ;;
        "推送到远程新分支（阶段性备份）") push_new_branch ;;
        "智能提交 (auto add + commit + push)") smart_commit ;;
        "文档迁移自动提交") auto_commit_docs_migration ;;
    esac

    auto_pop "$did_stash"
}

# ----------------------------
# 主菜单（fzf）
# ----------------------------
main_menu() {
    while true; do
        clear
        show_repo_status

        echo ""
        echo -e "${C_SUCCESS} Git 菜单工具（WSL + fzf 专业版）${C_RESET}"
        echo ""

        choice=$(printf "拉取最新代码\n推送选项菜单\n远程分支浏览 + 拉取\n切换本地分支（搜索）\n查看状态\n查看日志\n自动 rebase + 冲突检测\n创建 Pull Request (auto PR)\n分支健康评分\n文件结构智能迁移（Smart File Migration）\n退出" \
            | fzf --prompt="选择操作: ")

        case "$choice" in
            "拉取最新代码") git pull ;;
            "推送选项菜单") push_menu ;;
            "远程分支浏览 + 拉取") pull_remote_branch ;;
            "切换本地分支（搜索）") switch_branch ;;
            "查看状态") git status ;;
            "查看日志") git log --oneline --graph --decorate --all -20 ;;
            "自动 rebase + 冲突检测") auto_rebase ;;
            "创建 Pull Request (auto PR)") create_pr ;;
            "分支健康评分") 
                echo -e "${C_INFO}当前分支健康评分：${C_SUCCESS}$(branch_health_score)/100${C_RESET}"
                ;;
            "文件结构智能迁移（Smart File Migration）")
                smart_file_migration
                ;;
            "退出") exit 0 ;;
        esac

        echo "按 Enter 继续..."
        read -r
    done
}


main_menu
