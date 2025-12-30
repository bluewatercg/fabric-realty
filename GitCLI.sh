#!/usr/bin/env bash

# ======================================================
# GitCLI.sh - v2.6.1 (全功能终极版)
# 修复：Header 常驻显示、printf 兼容性、路径层级逻辑
# ======================================================

set -uo pipefail

# ----------------------------
# 颜色定义
# ----------------------------
C_INFO=$'\e[36m'
C_SUCCESS=$'\e[32m'
C_WARN=$'\e[33m'
C_ERROR=$'\e[31m'
C_MENU=$'\e[35m'
C_RESET=$'\e[0m'

# ----------------------------
# 全局环境变量
# ----------------------------
# 请确保已在系统环境变量中设置 DEEPSEEK_API_KEY
# export DEEPSEEK_API_KEY="您的密钥"

# ----------------------------
# 1. 基础环境检查
# ----------------------------
check_dependencies() {
    command -v git >/dev/null 2>&1 || { echo "未检测到 git"; exit 1; }
    command -v fzf >/dev/null 2>&1 || { echo "未检测到 fzf"; exit 1; }
    command -v jq >/dev/null 2>&1 || { echo "未检测到 jq (AI 功能需要)"; }
}

# ----------------------------
# 核心：状态面板构造 (返回 3 行极致简约版)
# ----------------------------
get_status_header() {
    # 1. 强制提取纯数字，剔除所有空格和换行
    local added=$(git status --porcelain | grep -c '^A ' | tr -d '[:space:]' || echo 0)
    local modified=$(git status --porcelain | awk '$1 ~ /^(M|MM|AM)/ {count++} END {print count+0}' | tr -d '[:space:]')
    local deleted=$(git status --porcelain | grep -c '^D ' | tr -d '[:space:]' || echo 0)
    local untracked=$(git status --porcelain | grep -c '^?? ' | tr -d '[:space:]' || echo 0)
    
    local branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "Unknown")
    local repo=$(git config --get remote.origin.url | sed 's/.*github.com[:/]\(.*\)\.git/\1/' | sed 's/\.git$//' | tr -d '[:space:]' || echo "Local")

    local ahead=0 behind=0
    if git rev-parse --verify "origin/$branch" >/dev/null 2>&1; then
        read -r behind ahead <<<"$(git rev-list --left-right --count "origin/$branch...$branch" 2>/dev/null | tr '\n' ' ' || echo "0 0")"
    fi

    # 2. 构造 UI
    local bar=$(echo -e "${C_MENU}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${C_RESET}")
    
    # 第一行：分支、同步、仓库名
    local line1=$(printf "${C_INFO} 🌿 分支: ${C_SUCCESS}%-15s${C_RESET} ${C_INFO}同步: ${C_WARN}↑%s ↓%s${C_RESET} ${C_INFO} 项目: ${C_SUCCESS}%s${C_RESET}" \
                 "$branch" "${ahead:-0}" "${behind:-0}" "$repo")
                 
    # 第二行：状态全部合并到一行 (新增、修改、删除、未跟踪)
    local line2=$(printf "${C_INFO} 📊 状态: ${C_SUCCESS}新增:%s ${C_WARN}修改:%s ${C_ERROR}删除:%s ${C_INFO}未跟踪:%s${C_RESET}" \
                 "${added:-0}" "${modified:-0}" "${deleted:-0}" "${untracked:-0}")
    
    echo -e "$bar\n$line1\n$line2\n$bar"
}
# ----------------------------
# 1. AI 提交逻辑
# ----------------------------
generate_ai_commit() {
    if [[ -z "${DEEPSEEK_API_KEY:-}" ]]; then
        echo -e "${C_ERROR}错误: 未设置 DEEPSEEK_API_KEY${C_RESET}" >&2; return 1
    fi
    local diff=$(git diff --cached | head -c 4000)
    [[ -z "$diff" ]] && { echo -e "${C_WARN}暂存区为空${C_RESET}" >&2; return 1; }

    echo -e "${C_INFO}🤖 AI 正在生成...${C_RESET}" >&2
    local payload=$(jq -n --arg sys "Short Conventional Commit message." --arg user "$diff" \
        '{model: "deepseek-chat", messages: [{role: "system", content: $sys}, {role: "user", content: $user}], temperature: 0.7}')

    curl -s -X POST "https://api.deepseek.com/chat/completions" \
        -H "Content-Type: application/json" -H "Authorization: Bearer $DEEPSEEK_API_KEY" -d "$payload" | jq -r '.choices[0].message.content' 2>/dev/null || echo "feat: updates"
}

smart_commit() {
    local files=$(git status --porcelain | fzf -m --ansi --prompt="选择文件 > " --preview="echo {} | awk '{print \$2}' | xargs git diff --color=always")
    [[ -z "$files" ]] && return
    echo "$files" | awk '{print $2}' | xargs git add

    local mode=$(printf "✨ AI 生成\n📝 手动输入\n🖊️ 编辑器\n🔙 取消" | fzf --prompt="Commit > ")
    case "$mode" in
        *"AI"*) local msg=$(generate_ai_commit); git commit -m "$msg" ;;
        *"手动"*) read -p "Message: " msg; git commit -m "$msg" ;;
        *"编辑器"*) git commit ;;
        *) git reset ;;
    esac
}

# ----------------------------
# 2. 层级化文件审计
# ----------------------------
file_history_explorer() {
    local path="."
    while true; do
        local list=$(ls -F "$path" | grep -v '^[./]')
        local sel=$(printf ".. (返回)\n%s" "$list" | fzf --ansi --prompt="📂 $path > " \
            --preview="i='${path}/{}'; i=\${i%*}; [[ -d \$i ]] && ls -C --color=always \$i || git log --oneline --color=always -n 10 -- \$i")
        [[ -z "$sel" ]] && break
        if [[ "$sel" == ".. (返回)" ]]; then [[ "$path" == "." ]] && break || path=$(dirname "$path"); continue; fi
        local full="${path}/${sel%*}"; full=${full#./}
        if [[ -d "$full" ]]; then path="$full"; else
            git log --oneline --color=always --follow -- "$full" | fzf --ansi --prompt="📅 $full > " \
                --preview="git show --color=always {1} -- \"$full\"" --bind "enter:execute(git show --color=always {1} -- \"$full\" | less -R)"
        fi
    done
}

# ----------------------------
# 5. 其他功能函数
# ----------------------------
sync_files() {
    local branch=$(git branch -a --format='%(refname:short)' | grep -v "origin/HEAD" | fzf --prompt="源分支 > ")
    [[ -z "$branch" ]] && return
    local files=$(git diff --name-only HEAD "$branch" | fzf -m --prompt="选择同步文件 > ")
    [[ -n "$files" ]] && echo "$files" | xargs git checkout "$branch" -- && echo "同步完成"
}

smart_migration() {
    local files=$(git status --porcelain | grep '^?? ' | awk '{print $2}')
    [[ -z "$files" ]] && { echo "无新文件"; return; }
    echo -e "${C_INFO}检测到新文件，执行自动化迁移提交？(y/n)${C_RESET}"
    read -r ans; [[ "$ans" == "y" ]] && git add -A && git commit -m "refactor: structural migration" && git push
}
 
# ----------------------------
# 主菜单 (彻底解决对齐与显示问题)
# ----------------------------
main_menu() {
    while true; do
        clear
        # 1. 获取 Header 字符串
        local header_content=$(get_status_header)
        
        # 2. 通过 --header 传入，确保居顶且不乱序
        local choice=$(printf "🔄 刷新状态\n📥 拉取 (Pull)\n🚀 提交 (Commit)\n📤 推送 (Push)\n🔍 审计 (History)\n🍒 同步 (Sync)\n🌿 分支 (Branch)\n📜 日志 (Log)\n📂 迁移 (Migrate)\n❌ 退出" | \
            fzf --ansi --layout=reverse --border=rounded --margin=1 --header-first \
                --height=100% --prompt="✨ 操作 > " --header="$header_content") || choice="🔄 刷新状态"

        case "$choice" in
            *"刷新"*) continue ;;
            *"拉取"*) git pull ;;
            *"提交"*) smart_commit ;;
            *"推送"*) git push ;;
            *"审计"*) file_history_explorer ;;
            *"同步"*) 
                local br=$(git branch -a --format='%(refname:short)' | fzf --prompt="源分支 > ")
                [[ -n "$br" ]] && git diff --name-only HEAD "$br" | fzf -m | xargs -I {} git checkout "$br" -- {} ;;
            *"分支"*) local t=$(git branch --format='%(refname:short)' | fzf); [[ -n "$t" ]] && git checkout "$t" ;;
            *"日志"*) git log --oneline --graph --all --color=always | fzf --ansi --preview="echo {} | grep -o '[a-f0-9]\{7\}' | head -1 | xargs -I % git show --color=always %" ;;
            *"迁移"*) git add -A && git commit -m "refactor: structural migration" ;;
            *"退出"*) exit 0 ;;
        esac

        if [[ "$choice" != *"刷新"* ]]; then
            echo -e "\n${C_INFO}按任意键继续...${C_RESET}"
            read -n 1 -s -r
        fi
    done
}

# 启动
main_menu