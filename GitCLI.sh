#!/usr/bin/env bash

# ======================================================
# GitCLI.sh - v3.0 (极致顺滑版)
# 优化：智能提交后默认回车即推送 (Enter = Yes)
# 结构：清爽菜单 + 目录浏览 + 自动Stash + DeepSeek
# ======================================================

set -u

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
# 1. 基础环境检查
# ----------------------------
check_dependencies() {
    command -v git >/dev/null 2>&1 || { echo -e "${C_ERROR}未检测到 git${C_RESET}"; exit 1; }
    command -v fzf >/dev/null 2>&1 || { echo -e "${C_ERROR}未检测到 fzf${C_RESET}"; exit 1; }
    
    if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        echo -e "${C_ERROR}当前目录不是 Git 仓库${C_RESET}"; exit 1
    fi
    
    if ! command -v jq >/dev/null 2>&1; then
        echo -e "${C_WARN}未检测到 jq，AI 提交功能受限${C_RESET}"
    fi
    
    if [[ -n "${GITHUB_TOKEN:-}" ]]; then
        GH_HEADER="-H \"Authorization: token $GITHUB_TOKEN\""
    else
        GH_HEADER=""
    fi
}

check_dependencies

# ----------------------------
# 2. 核心 UI 面板
# ----------------------------
get_status_header() {
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

    local bar=$(echo -e "${C_MENU}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${C_RESET}")
    
    local line1=$(printf "${C_INFO} 🌿 分支: ${C_SUCCESS}%-15s${C_RESET} ${C_INFO}同步: ${C_WARN}↑%s ↓%s${C_RESET} ${C_INFO} 项目: ${C_SUCCESS}%s${C_RESET}" \
                 "$branch" "${ahead:-0}" "${behind:-0}" "$repo")
                 
    local line2=$(printf "${C_INFO} 📊 状态: ${C_SUCCESS}新增:%s ${C_WARN}修改:%s ${C_ERROR}删除:%s ${C_INFO}未跟踪:%s${C_RESET}" \
                 "${added:-0}" "${modified:-0}" "${deleted:-0}" "${untracked:-0}")
    
    echo -e "$bar\n$line1\n$line2\n$bar"
}

# ----------------------------
# 3. 辅助工具 (自动 Stash)
# ----------------------------
has_uncommitted() {
    [[ -n "$(git status --porcelain)" ]]
}

auto_stash() {
    if has_uncommitted; then
        echo -e "${C_WARN}⚠️  检测到未提交变更，切换分支需暂存。${C_RESET}"
        echo -e "${C_INFO}是否自动暂存(stash)？(y/n)${C_RESET}"
        read -r -t 10 ans || ans="n"
        if [[ "$ans" == "y" || "$ans" == "Y" ]]; then
            git stash push -u -m "Auto stash by GitCLI" >/dev/null
            echo -e "${C_SUCCESS}✅ 已暂存变更。${C_RESET}"
            return 0
        else
            echo -e "${C_ERROR}❌ 已取消。Git 可能会拒绝操作。${C_RESET}"
            return 1
        fi
    fi
    return 1
}

# ----------------------------
# 4. 智能提交与 AI (集成 DeepSeek)
# ----------------------------
generate_ai_commit() {
    if [[ -z "${DEEPSEEK_API_KEY:-}" ]]; then
        echo -e "${C_ERROR}错误: 未设置 DEEPSEEK_API_KEY${C_RESET}" >&2; return 1
    fi
    local diff=$(git diff --cached | head -c 4000)
    [[ -z "$diff" ]] && { echo -e "${C_WARN}暂存区为空${C_RESET}" >&2; return 1; }

    echo -e "${C_INFO}🤖 AI (DeepSeek) 正在分析...${C_RESET}" >&2
    
    local system_prompt="你是一个资深开发者。请根据 git diff 生成一个符合 Conventional Commits 规范的英文 Commit Message。要求：1. 仅输出 Message 本身，不要Markdown，不要解释。 2. 只有一行总结。"
    
    local payload=$(jq -n --arg sys "$system_prompt" --arg user "$diff" \
        '{model: "deepseek-chat", messages: [{role: "system", content: $sys}, {role: "user", content: $user}], temperature: 0.7, stream: false}')

    local res=$(curl -s -X POST "https://api.deepseek.com/chat/completions" \
        -H "Content-Type: application/json" -H "Authorization: Bearer $DEEPSEEK_API_KEY" -d "$payload")
        
    echo "$res" | jq -r '.choices[0].message.content' 2>/dev/null
}

smart_commit_and_push() {
    # 1. 检查自动 Stash
    if [[ -n "$(git stash list | grep 'Auto stash by GitCLI' | tail -1)" ]]; then
         echo -e "${C_WARN}检测到自动 Stash，是否恢复？(y/n)${C_RESET}"
         read -r ans; [[ "$ans" == "y" ]] && git stash pop
    fi

    # 2. 选择文件
    local files=$(git status --porcelain | fzf -m --ansi --prompt="选择文件 (Tab多选) > " \
        --preview="echo {} | awk '{print \$2}' | xargs git diff --color=always")
    [[ -z "$files" ]] && return
    echo "$files" | awk '{print $2}' | xargs git add

    # 3. 生成 Message
    local mode=$(printf "✨ AI 生成 (DeepSeek)\n📝 手动输入\n🔙 取消" | fzf --prompt="Commit Message > ")
    local msg=""
    
    case "$mode" in
        *"AI"*) 
            msg=$(generate_ai_commit)
            [[ -z "$msg" || "$msg" == "null" ]] && { echo "AI 生成失败"; return; }
            read -e -p "确认或编辑消息: " -i "$msg" final_msg
            msg="$final_msg"
            ;;
        *"手动"*) read -p "Message: " msg ;;
        *) git reset; return ;;
    esac

    # 4. 提交并默认推送
    if [[ -n "$msg" ]]; then
        if git commit -m "$msg"; then
            echo -e "${C_SUCCESS}🎉 本地提交成功！${C_RESET}"
            echo ""
            # 重点修改：默认 Yes，提示符改为 [Y/n]
            echo -e "${C_WARN}🚀 是否立即推送到远程？ [Y/n] (默认: Yes)${C_RESET}"
            read -r push_ans
            
            # 如果输入为空，默认为 Y
            [[ -z "$push_ans" ]] && push_ans="Y"
            
            if [[ "$push_ans" =~ ^[Yy] ]]; then
                echo -e "${C_INFO}⏳ 正在推送...${C_RESET}"
                git push
            else
                echo -e "${C_INFO}👌 已保留在本地，未推送。${C_RESET}"
            fi
        fi
    fi
}

# ----------------------------
# 5. 目录级文件审计
# ----------------------------
file_history_explorer() {
    local path="."
    while true; do
        local list=$(ls -F "$path" | grep -v '^\./$' | grep -v '^../$')
        local sel=$(printf ".. (返回上一级)\n%s" "$list" | fzf --ansi --prompt="📂 浏览: $path > " \
            --header="Enter进入目录/查看历史 | 预览窗口显示内容" \
            --preview="target='${path}/{}'; target=\${target%*}; if [[ -d \$target ]]; then ls -C --color=always \$target; else if command -v bat >/dev/null; then bat --color=always --style=numbers \$target; else cat \$target; fi; fi")
            
        [[ -z "$sel" ]] && break
        
        if [[ "$sel" == ".. (返回上一级)" ]]; then 
            [[ "$path" == "." ]] && break 
            path=$(dirname "$path")
            continue
        fi
        
        local clean_sel=${sel%*} 
        local full="${path}/${clean_sel}"
        full=${full#./} 

        if [[ -d "$full" ]]; then
            path="$full"
        else
            git log --oneline --color=always --follow -- "$full" | fzf --ansi \
                --prompt="📅 $full 变更记录 > " \
                --preview="git show --color=always {1} -- \"$full\"" \
                --bind "enter:execute(git show --color=always {1} -- \"$full\" | less -R)"
        fi
    done
}

# ----------------------------
# 6. 推送功能组
# ----------------------------
smart_force_push() {
    local action=$(printf "👉 当前分支\n🔀 其他分支" | fzf --prompt="推送到哪里? > ")
    local target=$(git rev-parse --abbrev-ref HEAD)
    
    if [[ "$action" == *"其他"* ]]; then
        target=$(git branch --format='%(refname:short)' | fzf --prompt="选择分支 > ")
    fi
    [[ -z "$target" ]] && return

    echo -e "${C_ERROR}⚠️  高危操作：强制推送 (Force Push)${C_RESET}"
    echo -e "目标: origin/${C_WARN}$target${C_RESET}"
    echo -e "${C_WARN}请输入 YES 确认:${C_RESET}"
    read -r confirm
    [[ "$confirm" == "YES" ]] && git push --force-with-lease origin "$target" && echo -e "${C_SUCCESS}完成${C_RESET}"
}

push_backup_branch() {
    local current_branch=$(git rev-parse --abbrev-ref HEAD)
    local timestamp=$(date '+%Y%m%d-%H%M')
    local default="backup/$current_branch/$timestamp"
    
    echo -e "${C_INFO}创建一个远程备份分支 (不影响当前本地工作区)${C_RESET}"
    echo -e "输入新分支名 (回车默认: ${C_SUCCESS}$default${C_RESET}):"
    read -r name
    [[ -z "$name" ]] && name="$default"
    
    echo -e "${C_INFO}⏳ 正在推送 HEAD 到 origin/$name ...${C_RESET}"
    if git push origin HEAD:"$name"; then
        echo -e "${C_SUCCESS}✅ 备份完成！远程分支已创建：$name${C_RESET}"
    else
        echo -e "${C_ERROR}❌ 备份失败${C_RESET}"
    fi
}

show_push_menu() {
    while true; do
        local header_content=$(get_status_header)
        local choice=$(printf "📤 普通推送 (Standard Push)\n💾 备份推送 (Backup to New Branch)\n🧨 强制推送 (Force Push)\n🔙 返回主菜单 (Back)" | \
            fzf --ansi --layout=reverse --border=rounded --margin=1 --header-first \
                --height=100% --prompt="🚀 推送菜单 > " --header="$header_content")
        
        [[ -z "$choice" ]] && return

        case "$choice" in
            *"普通推送"*) git push; read -n 1 -s -r; return ;; 
            *"备份推送"*) push_backup_branch; read -n 1 -s -r; return ;;
            *"强制推送"*) smart_force_push; read -n 1 -s -r; return ;;
            *"返回"*) return ;;
        esac
    done
}

# ----------------------------
# 7. 其他逻辑
# ----------------------------
switch_branch_safe() {
    local target=$(git branch --format='%(refname:short)' | fzf --prompt="切换分支 > " --preview="git log --oneline --graph --color=always {} | head -20")
    if [[ -n "$target" ]]; then
        if has_uncommitted; then
            auto_stash || return
        fi
        git checkout "$target"
    fi
}

sync_specific_files() {
    local br=$(git branch -a --format='%(refname:short)' | grep -v "origin/HEAD" | fzf --prompt="源分支 > ")
    [[ -z "$br" ]] && return
    
    local files=$(git diff --name-only HEAD "$br" | fzf -m --prompt="选择文件 > " --preview="git diff --color=always HEAD $br -- {}")
    [[ -z "$files" ]] && return
    
    local mode=$(printf "🔥 覆盖\n🧬 合并" | fzf --prompt="策略 > ")
    if [[ "$mode" == *"覆盖"* ]]; then
        echo "$files" | xargs git checkout "$br" -- 
    else
        echo "$files" | xargs git checkout --merge "$br" -- 
    fi
    echo -e "${C_SUCCESS}同步完成${C_RESET}"
}

# ----------------------------
# 8. 主菜单 Loop
# ----------------------------
main_menu() {
    while true; do
        clear 
        local header_content=$(get_status_header)
        
        # 将 "智能提交" 改名为 "智能提交 & 推送"，更符合逻辑
        local choice=$(printf "🔄 刷新状态\n📥 拉取代码 (Pull)\n🚀 智能提交 & 推送 (Smart Commit & Push)\n📤 推送菜单 (Push Options)\n🌿 切换分支 (Checkout)\n🔍 文件审计 (Explorer)\n🍒 定向同步 (Sync Files)\n📜 查看日志 (Log)\n📂 结构迁移 (Migrate)\n❌ 退出" | \
            fzf --ansi --layout=reverse --border=rounded --margin=1 --header-first \
                --height=100% --prompt="✨ GitCLI > " --header="$header_content")

        [[ -z "$choice" ]] && choice="🔄 刷新状态"

        case "$choice" in
            *"刷新"*) continue ;;
            *"拉取"*) git pull ;;
            *"智能提交"*) smart_commit_and_push ;;
            *"推送菜单"*) show_push_menu ;; 
            *"切换分支"*) switch_branch_safe ;;
            *"文件审计"*) file_history_explorer ;;
            *"定向同步"*) sync_specific_files ;;
            *"查看日志"*) git log --oneline --graph --all --color=always | fzf --ansi --preview="echo {} | grep -o '[a-f0-9]\{7\}' | head -1 | xargs -I % git show --color=always %" ;;
            *"结构迁移"*) 
                git add -A && git commit -m "refactor: structural migration" && echo "本地已提交" 
                ;;
            *"退出"*) exit 0 ;;
        esac

        if [[ "$choice" != *"刷新"* && "$choice" != *"推送菜单"* ]]; then
            echo -e "\n${C_INFO}按任意键继续...${C_RESET}"
            read -n 1 -s -r
        fi
    done
}

# 启动
main_menu