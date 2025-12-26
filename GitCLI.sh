#!/usr/bin/env bash

# ============================
# GitCLI.sh - fzf 专业版 v2.0
# 作者: 你 + Grok 优化
# 日期: 2025-12-26
# ============================

set -euo pipefail

# ----------------------------
# 颜色定义
# ----------------------------
C_INFO="\033[36m"
C_SUCCESS="\033[32m"
C_WARN="\033[33m"
C_ERROR="\033[31m"
C_MENU="\033[35m"
C_RESET="\033[0m"

# ----------------------------
# 全局变量（缓存）
# ----------------------------
CURRENT_BRANCH=""
REPO_PATH=""
DEFAULT_BRANCH=""
GH_HEADER=""

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
        echo -e "${C_INFO}安装建议: sudo apt install fzf  或  brew install fzf${C_RESET}"
        exit 1
    fi

    if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        echo -e "${C_ERROR}当前目录不是 Git 仓库${C_RESET}"
        exit 1
    fi

    if ! command -v jq >/dev/null 2>&1; then
        echo -e "${C_WARN}未检测到 jq，GitHub PR 相关功能将降级使用 grep（不推荐）${C_RESET}"
        echo -e "${C_INFO}强烈建议安装: sudo apt install jq  或  brew install jq${C_RESET}"
    fi

    if ! command -v curl >/dev/null 2>&1; then
        echo -e "${C_WARN}未检测到 curl，GitHub 相关功能将不可用${C_RESET}"
    fi

    # 缓存变量
    CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
    REPO_PATH=$(git config --get remote.origin.url | sed 's/.*github.com[:/]\(.*\)\.git/\1/' || echo "")
    DEFAULT_BRANCH=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@' || echo "main")

    # GitHub Token 支持
    if [[ -n "${GITHUB_TOKEN:-}" ]]; then
        GH_HEADER="-H \"Authorization: token $GITHUB_TOKEN\""
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

# ----------------------------
# 基础工具函数
# ----------------------------
has_uncommitted() {
    [[ -n "$(git status --porcelain)" ]]
}

detect_conflicts() {
    local conflicts=$(git diff --name-only --diff-filter=U)
    if [[ -n "$conflicts" ]]; then
        echo -e "${C_ERROR}⚠️ 检测到冲突文件：${C_RESET}"
        echo "$conflicts"
        return 0
    fi
    return 1
}

# ----------------------------
# 仓库状态与分支健康
# ----------------------------
branch_health_score() {
    local score=100
    local ahead=0 behind=0

    if git rev-parse --verify "origin/$CURRENT_BRANCH" >/dev/null 2>&1; then
        read -r behind ahead <<<"$(git rev-list --left-right --count "origin/$CURRENT_BRANCH...$CURRENT_BRANCH" 2>/dev/null || echo "0 0")"
    fi

    [[ $behind -gt 0 ]] && score=$((score - 20))
    [[ $ahead -gt 20 ]] && score=$((score - 10))
    [[ $behind -gt 0 ]] && score=$((score - 20))

    if git status --porcelain | grep -q '^UU '; then
        score=$((score - 30))
    fi

    # PR 状态检测（支持 jq 优先）
    if [[ -n "$REPO_PATH" ]] && command -v curl >/dev/null 2>&1; then
        local api_url="https://api.github.com/repos/$REPO_PATH/pulls?head=${REPO_PATH%%/*}:$CURRENT_BRANCH"
        local pr_count=0
        if command -v jq >/dev/null 2>&1; then
            pr_count=$(curl -s $GH_HEADER -H "Accept: application/vnd.github+json" "$api_url" | jq 'length' 2>/dev/null || echo 0)
        else
            pr_count=$(curl -s $GH_HEADER "$api_url" | grep -c '"html_url"' || echo 0)
        fi
        [[ $pr_count -eq 0 ]] && score=$((score - 20))
    fi

    (( score < 0 )) && score=0
    echo "$score"
}

check_pr_status() {
    if [[ -z "$REPO_PATH" ]]; then
        echo -e "${C_WARN}PR 状态：非 GitHub 仓库，跳过检测${C_RESET}"
        return
    fi

    local api_url="https://api.github.com/repos/$REPO_PATH/pulls?head=${REPO_PATH%%/*}:$CURRENT_BRANCH"
    local pr_count=0

    if command -v jq >/dev/null 2>&1; then
        pr_count=$(curl -s $GH_HEADER -H "Accept: application/vnd.github+json" "$api_url" | jq 'length' 2>/dev/null || echo 0)
    else
        pr_count=$(curl -s $GH_HEADER "$api_url" | grep -c '"html_url"' || echo 0)
    fi

    if [[ $pr_count -gt 0 ]]; then
        echo -e "${C_SUCCESS}PR 状态：当前分支已有 $pr_count 个 Pull Request${C_RESET}"
    else
        echo -e "${C_WARN}PR 状态：当前分支尚未创建 PR${C_RESET}"
    fi
}

show_repo_status() {
    local added modified deleted untrackedQQ
    added=$(git status --porcelain 2>/dev/null | grep -c '^A ' || echo 0)
    modified=$(git status --porcelain 2>/dev/null | grep -c '^ M' || echo 0)
    deleted=$(git status --porcelain 2>/dev/null | grep -c '^ D ' || echo 0)
    untracked=$(git status --porcelain 2>/dev/null | grep -c '^?? ' || echo 0)

    local ahead=0 behind=0 need_rebase="No"
    if git rev-parse --verify "origin/$CURRENT_BRANCH" >/dev/null 2>&1; then
        read -r behind ahead <<<"$(git rev-list --left-right --count "origin/$CURRENT_BRANCH...$CURRENT_BRANCH" 2>/dev/null || echo "0 0")"
        [[ $behind -gt 0 ]] && need_rebase="Yes"
    fi

    local conflict_risk="No"
    if git status --porcelain | grep -q '^UU '; then
        conflict_risk="Yes"
    fi

    local health=$(branch_health_score)

    echo -e "${C_MENU}================ GitCLI 状态面板 ================${C_RESET}"
    echo -e "${C_INFO}当前分支：${C_SUCCESS}${CURRENT_BRANCH}${C_RESET}"
    echo -e "${C_INFO}默认分支：${C_SUCCESS}${DEFAULT_BRANCH}${C_RESET}"
    echo -e "${C_INFO}远程状态：${C_RESET}ahead $ahead, behind $behind"
    echo -e "${C_INFO}是否需要 rebase：${C_RESET}$need_rebase"
    echo -e "${C_INFO}冲突风险：${C_RESET}$conflict_risk"
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
        echo -e "${C_WARN}检测到未提交变更，是否自动 stash？(y/n，默认 n)${C_RESET}"
        read -r -t 10 ans || ans="n"
        if [[ "$ans" == "y" || "$ans" == "Y" ]]; then
            git stash push -m "Auto stash by GitCLI" >/dev/null
            return 0
        fi
    fi
    return 1
}

auto_pop() {
    [[ "$1" == "0" ]] || return
    echo -e "${C_INFO}正在恢复 stash...${C_RESET}"
    if ! git stash pop --quiet; then
        echo -e "${C_ERROR}⚠️  stash pop 失败！你的修改可能无法自动恢复${C_RESET}"
        echo -e "${C_ERROR}请立即执行以下命令尝试手动恢复：${C_RESET}"
        echo -e "${C_INFO}git stash apply \$(git fsck --no-reflog | awk '/dangling commit/ {print \$3}' | tail -1)${C_RESET}"
        echo -e "${C_WARN}或者查看 git reflog stash 找回丢失的修改${C_RESET}"
    fi
}

# ----------------------------
# 智能提交系列
# ----------------------------
# ----------------------------
# 增强版智能提交（交互式选择文件）
# ----------------------------
smart_commit() {
    echo -e "${C_INFO}🔍 执行智能提交（交互式）...${C_RESET}"

    # 检查是否有变更
    if [[ -z "$(git status --porcelain)" ]]; then
        echo -e "${C_WARN}当前无任何变更，无需提交${C_RESET}"
        return
    fi

    # 用 fzf 多选要提交的文件（支持预览 diff）
    local selected_files=$(git status --porcelain | \
        fzf -m --prompt="多选要提交的文件（Tab 选中，Enter 确认）: " \
            --preview="echo {} | awk '{print \$2}' | xargs git diff --color=always" \
            --preview-window=right:60% | \
        awk '{print $2}')

    # 如果没选任何文件，取消提交
    if [[ -z "$selected_files" ]]; then
        echo -e "${C_WARN}未选择任何文件，取消提交${C_RESET}"
        return
    fi

    # 添加选中的文件
    echo "$selected_files" | xargs git add

    # 生成变更摘要
    local summary=""
    local added=$(git diff --cached --name-only | wc -l)
    local modified=$(git diff --cached --name-only | grep -v '^$' | wc -l)  # 实际上 added 和 modified 都计入 staged
    local deleted=$(git status --porcelain | grep '^D ' | wc -l || echo 0)

    [[ $added -gt 0 ]] && summary+="新增/修改:$added "
    [[ $deleted -gt 0 ]] && summary+="删除:$deleted "

    [[ -z "$summary" ]] && summary="部分文件变更"

    # 让用户确认或编辑 commit message
    echo -e "${C_INFO}已暂存文件：${C_SUCCESS}${added} 个${C_RESET}"
    echo -e "${C_INFO}建议提交信息：${C_SUCCESS}auto: $summary${C_RESET}"
    echo -e "${C_WARN}是否现在提交？(y/n，回车使用建议消息，或直接输入自定义消息)${C_RESET}"
    read -r user_input

    if [[ "$user_input" == "n" || "$user_input" == "N" ]]; then
        echo -e "${C_WARN}提交已取消（已暂存的文件仍保留，可手动 commit）${C_RESET}"
        return
    fi

    local commit_msg
    if [[ -z "$user_input" || "$user_input" == "y" || "$user_input" == "Y" ]]; then
        commit_msg="auto: $summary"
    else
        commit_msg="$user_input"
    fi

    git commit -m "$commit_msg"

    # 询问是否推送
    echo -e "${C_WARN}是否立即推送到远程？(y/n)${C_RESET}"
    read -r push_ans
    if [[ "$push_ans" == "y" || "$push_ans" == "Y" ]]; then
        git push && echo -e "${C_SUCCESS}🎉 提交并推送完成！${C_RESET}"
    else
        echo -e "${C_SUCCESS}🎉 提交完成（未推送）${C_RESET}"
    fi
}
# ----------------------------
# 文件结构智能迁移（核心升级）
# ----------------------------
detect_migration_type() {
    local untracked=$(git status --porcelain | grep '^?? ' | awk '{print $2}')

    if [[ -z "$untracked" ]]; then
        echo "none"
        return
    fi

    local counts=(docs:0 src:0 config:0 ci:0 archive:0 other:0)

    while IFS= read -r file; do
        if [[ "$file" =~ ^docs/ ]]; then ((counts[0]++))
        elif [[ "$file" =~ ^src/ ]]; then ((counts[1]++))
        elif [[ "$file" =~ ^(config/|\.ya?ml$|\.json$) ]]; then ((counts[2]++))
        elif [[ "$file" =~ ^(\.github/workflows|ci/) ]]; then ((counts[3]++))
        elif [[ "$file" =~ (archive/|DEPRECATED) ]]; then ((counts[4]++))
        else ((counts[5]++)); fi
    done <<< "$untracked"

    local max=0 max_type="refactor"
    for i in "${!counts[@]}"; do
        local type=${counts[i]%:*}
        local count=${counts[i]#*:}
        if (( count > max )); then
            max=$count
            case $type in
                docs) max_type="docs-migration" ;;
                src) max_type="src-migration" ;;
                config) max_type="config-migration" ;;
                ci) max_type="ci-migration" ;;
                archive) max_type="archive" ;;
                *) max_type="refactor" ;;
            esac
        fi
    done

    # 如果其他类型占比高，提示混合
    if (( ${counts[5]#*:} > max / 2 && max > 0 )); then
        echo "mixed-$max_type"
    else
        echo "$max_type"
    fi
}

generate_smart_commit_message() {
    local type=$1
    local added=$(git status --porcelain | grep '^A ' | wc -l)
    local deleted=$(git status --porcelain | grep -E '^ D |^R' | wc -l)

    case "$type" in
        docs-migration|mixed-docs-migration)
            echo "docs: migrate documentation structure ($added added, $deleted removed)" ;;
        src-migration|mixed-src-migration)
            echo "refactor(src): restructure source code ($added added, $deleted removed)" ;;
        config-migration|mixed-config-migration)
            echo "chore(config): reorganize configuration files ($added added, $deleted removed)" ;;
        ci-migration|mixed-ci-migration)
            echo "ci: update workflows and scripts ($added added, $deleted removed)" ;;
        archive|mixed-archive)
            echo "chore(archive): archive deprecated components ($added added, $deleted removed)" ;;
        *)
            echo "refactor: structural changes and cleanup ($added added, $deleted removed)" ;;
    esac
}

smart_file_migration() {
    echo -e "${C_INFO}🔍 正在分析文件结构迁移...${C_RESET}"

    if [[ -z "$(git status --porcelain)" ]]; then
        echo -e "${C_WARN}无变更，无法执行迁移提交${C_RESET}"
        return
    fi

    local type=$(detect_migration_type)
    [[ "$type" == "none" ]] && { echo -e "${C_WARN}无新增文件迁移迹象${C_RESET}"; return; }

    local commit_msg=$(generate_smart_commit_message "$type")

    echo -e "${C_INFO}检测迁移类型：${C_SUCCESS}${type}${C_RESET}"
    echo -e "${C_INFO}建议提交信息：${C_SUCCESS}${commit_msg}${C_RESET}"
    echo ""
    echo -e "${C_INFO}变更预览：${C_RESET}"
    git status --short

    echo ""
    echo -e "${C_WARN}是否执行迁移提交并推送？(y/n)${C_RESET}"
    read -r ans
    [[ "$ans" != "y" && "$ans" != "Y" ]] && return

    git add -A
    git commit -m "$commit_msg"
    git push

    echo -e "${C_SUCCESS}🎉 文件结构迁移提交完成！${C_RESET}"
}

# ----------------------------
# 其他功能
# ----------------------------
auto_rebase() {
    echo -e "${C_INFO}🔄 正在 rebase origin/$CURRENT_BRANCH...${C_RESET}"
    git fetch && git rebase "origin/$CURRENT_BRANCH" && echo -e "${C_SUCCESS}rebase 成功${C_RESET}" || {
        echo -e "${C_ERROR}rebase 冲突，请手动解决${C_RESET}"
        git status --porcelain | grep '^UU ' || true
    }
}

create_pr() {
    [[ -z "$REPO_PATH" ]] && { echo -e "${C_ERROR}非 GitHub 仓库${C_RESET}"; return; }
    [[ -z "${GITHUB_TOKEN:-}" ]] && { echo -e "${C_ERROR}请设置 GITHUB_TOKEN 环境变量${C_RESET}"; return; }

    local title="feat: updates from branch $CURRENT_BRANCH"
    local body="Auto-generated PR from GitCLI tool."

    echo -e "${C_INFO}📮 创建 PR（base: $DEFAULT_BRANCH）...${C_RESET}"

    local response=$(curl -s -X POST $GH_HEADER \
        -H "Accept: application/vnd.github+json" \
        -d "{\"title\":\"$title\",\"body\":\"$body\",\"head\":\"$CURRENT_BRANCH\",\"base\":\"$DEFAULT_BRANCH\"}" \
        "https://api.github.com/repos/$REPO_PATH/pulls")

    if echo "$response" | grep -q '"html_url"'; then
        local pr_url=$(echo "$response" | grep '"html_url"' | head -1 | sed 's/.*"html_url": "\(.*\)".*/\1/')
        echo -e "${C_SUCCESS}🎉 PR 创建成功：$pr_url${C_RESET}"
    else
        echo -e "${C_ERROR}PR 创建失败${C_RESET}"
        echo "$response"
    fi
}

select_branch() {
    git branch --sort=-committerdate --format='%(refname:short)' |
        fzf --prompt="选择本地分支: " --preview="git log --oneline --graph --decorate --color=always {}" --preview-window=right:60%
}

switch_branch() {
    detect_conflicts && return
    local target=$(select_branch)
    [[ -n "$target" ]] && git checkout "$target"
}

select_remote_branch() {
    git fetch --quiet
    git ls-remote --heads origin | awk '{print $2}' | sed 's@refs/heads/@@' |
        fzf --prompt="选择远程分支: " --preview="git log --oneline --graph --decorate --color=always origin/{}" --preview-window=right:60%
}

pull_remote_branch() {
    local branch=$(select_remote_branch)
    [[ -z "$branch" ]] && return
    if git branch --list | grep -q "^$branch\$"; then
        git checkout "$branch" && git pull
    else
        git checkout -b "$branch" "origin/$branch"
    fi
}

push_new_branch() {
    local timestamp=$(date '+%Y%m%d-%H%M')
    local default="backup/$CURRENT_BRANCH/$timestamp"
    echo "输入新分支名（回车使用默认：$default）："
    read -r name
    [[ -z "$name" ]] && name="$default"
    git push origin HEAD:"$name"
    echo -e "${C_SUCCESS}已推送到远程分支：$name${C_RESET}"
}

# ----------------------------
# 推送菜单
# ----------------------------
push_menu() {
    detect_conflicts && { echo -e "${C_ERROR}存在冲突，请先解决${C_RESET}"; return; }

    local choice=$(printf "普通推送\n强制推送（--force-with-lease）\n智能提交 + 推送\n推送到新分支（备份）\n智能文件结构迁移并推送\n返回主菜单" |
        fzf --prompt="选择推送操作: ")

    local did_stash=1
    auto_stash && did_stash=0

    case "$choice" in
        "普通推送") git push ;;
        "强制推送（--force-with-lease）") git push --force-with-lease ;;
        "智能提交 + 推送") smart_commit ;;
        "推送到新分支（备份）") push_new_branch ;;
        "智能文件结构迁移并推送") smart_file_migration ;;
        *) auto_pop "$did_stash"; return ;;
    esac

    auto_pop "$did_stash"
}

# ----------------------------
# 主菜单
# ----------------------------
main_menu() {
    while true; do
        clear
        show_repo_status
        echo ""
        echo -e "${C_SUCCESS}🚀 GitCLI 专业工具 v2.0${C_RESET}"
        echo ""

        local choice=$(printf "拉取最新代码\n推送选项菜单\n远程分支浏览 + 拉取\n切换本地分支\n查看详细状态\n查看日志 (graph)\n自动 rebase\n创建 Pull Request\n分支健康评分\n智能文件结构迁移\n退出" |
            fzf --prompt="选择操作 > ")

        case "$choice" in
            "拉取最新代码") git pull ;;
            "推送选项菜单") push_menu ;;
            "远程分支浏览 + 拉取") pull_remote_branch ;;
            "切换本地分支") switch_branch ;;
            "查看详细状态") git status ;;
            "查看日志 (graph)") git log --oneline --graph --decorate --all -20 ;;
            "自动 rebase") auto_rebase ;;
            "创建 Pull Request") create_pr ;;
            "分支健康评分") echo -e "${C_INFO}当前健康评分：${C_SUCCESS}$(branch_health_score)/100${C_RESET}" ;;
            "智能文件结构迁移") smart_file_migration ;;
            "退出") echo -e "${C_SUCCESS}再见！${C_RESET}"; exit 0 ;;
        esac

        echo ""
        read -n 1 -s -r -p "按任意键继续..."
    done
}

main_menu