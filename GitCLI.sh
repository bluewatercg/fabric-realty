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

    # 2. 选择文件 (修复中文乱码 & 支持带空格的文件名)
    # ---------------------------------------------------------
    # 关键修改：
    # 1. git -c core.quotePath=false: 强制输出正常中文，不转义
    # 2. awk + sed: 更安全地剥离文件路径（哪怕文件名里有空格）
    # ---------------------------------------------------------
    local files=$(git -c core.quotePath=false status --porcelain -uall | fzf -m --ansi --prompt="选择文件 (Tab多选) > " \
        --preview="stat=\$(echo {} | awk '{print \$1}'); \
                   # 提取文件名，处理可能存在的空格
                   file=\$(echo {} | awk '{\$1=\"\"; print \$0}' | sed 's/^[ \t]*//'); \
                   if [[ \"\$stat\" == '??' ]]; then \
                       if command -v bat >/dev/null; then bat --color=always --style=numbers \"\$file\"; else cat \"\$file\"; fi; \
                   else \
                       git diff --color=always -- \"\$file\"; \
                   fi")
                   
    [[ -z "$files" ]] && return
    
    # 3. 提交选中的文件 (处理文件名中的空格)
    # 使用 while read 循环安全地处理每一行文件名
    echo "$files" | awk '{$1=""; print $0}' | sed 's/^[ \t]*//' | while read -r file; do
        git add "$file"
    done

    # 4. 生成 Message
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

    # 5. 提交并默认推送
    if [[ -n "$msg" ]]; then
        if git commit -m "$msg"; then
            echo -e "${C_SUCCESS}🎉 本地提交成功！${C_RESET}"
            echo ""
            echo -e "${C_WARN}🚀 是否立即推送到远程？ [Y/n] (默认: Yes)${C_RESET}"
            read -r push_ans
            
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
# 新增: 远程文件注射 (高级版：带颜色分组)
# ----------------------------
inject_file_to_remote() {
    # 0. 预备工作
    echo -e "${C_INFO}📡 正在获取最新远程分支信息...${C_RESET}"
    git fetch -q --all --prune

    # 1. 选择目标远程分支
    local target_remote=$(git branch -r | grep -v '\->' | sed 's/origin\///' | sed 's/^[ \t]*//' | \
        fzf --prompt="🎯 选择目标远程分支 (本地可能没有) > " --height=40% --layout=reverse)
    
    [[ -z "$target_remote" ]] && return

    echo -e "${C_INFO}🔍 正在对比差异并分组 (Local vs origin/$target_remote)...${C_RESET}"

    # 定义 ANSI 背景色
    local BG_BLUE=$'\e[44;97m'   # 蓝底白字
    local BG_GREEN=$'\e[42;97m'  # 绿底白字
    local BG_RESET=$'\e[0m'

    # 2. 构建分组列表
    # -----------------------------------------------------
    local display_list=""

    # A. [修改组] 获取差异文件 (并确保本地存在)
    local diff_files=$(git diff --name-only "origin/$target_remote" 2>/dev/null)
    if [[ -n "$diff_files" ]]; then
        # 逐行处理，只添加本地存在的文件
        while read -r f; do
            if [[ -f "$f" ]]; then
                display_list+="${BG_BLUE} MODIFIED ${BG_RESET} $f\n"
            fi
        done <<< "$diff_files"
    fi

    # B. [新增组] 获取未跟踪文件
    local new_files=$(git ls-files --others --exclude-standard)
    if [[ -n "$new_files" ]]; then
        while read -r f; do
             display_list+="${BG_GREEN} NEW FILE ${BG_RESET} $f\n"
        done <<< "$new_files"
    fi
    
    # 如果列表为空
    if [[ -z "$display_list" || "$display_list" == $'\n' ]]; then
        echo -e "${C_WARN}没有检测到任何差异或新文件。${C_RESET}"
        return
    fi

    # C. 调用 FZF
    # --ansi: 解析颜色代码
    # --no-sort: 保持我们可以构建的 [修改] 在前 [新增] 在后的顺序
    local selection=$(echo -e "$display_list" | fzf -m --ansi --no-sort \
        --prompt="💉 选择要注入的文件 (Tab多选) > " \
        --preview="file=\$(echo {} | sed 's/^.*] //; s/^.* //'); \
                   if command -v bat >/dev/null; then bat --color=always --style=numbers \"\$file\"; else cat \"\$file\"; fi")

    [[ -z "$selection" ]] && return

    # D. 清洗选中结果（去掉颜色标签，只提取文件名）
    # 逻辑：去掉每一行的第一个字段（标签），然后去除前导空格
    local clean_files=$(echo "$selection" | awk '{$1=""; print $0}' | sed 's/^[ \t]*//')

    # 3. 确认操作
    echo -e "${C_WARN}⚠️  即将执行高危操作：${C_RESET}"
    echo -e "   将把本地文件注入到远程: ${C_SUCCESS}origin/$target_remote${C_RESET}"
    echo -e "   这会产生一个新的 Commit 并直接推送。"
    read -p "确认继续? (y/N) " confirm
    [[ "$confirm" != "y" && "$confirm" != "Y" ]] && return

    # 4. 开始执行环境切换
    local current_branch=$(git rev-parse --abbrev-ref HEAD)
    local temp_branch="cli-inject-tmp-$(date +%s)"
    local payload_tar="/tmp/git_inject_payload.tar"

    # A. 打包 (使用清洗后的文件名)
    echo "$clean_files" | tr '\n' '\0' | xargs -0 tar -cf "$payload_tar"

    # B. 处理当前工作区
    local stashed=0
    if has_uncommitted; then
        echo -e "${C_INFO}暂存当前工作区...${C_RESET}"
        git stash push -u -m "Auto stash by Injector" >/dev/null
        stashed=1
    fi

    # C. 基于远程分支创建临时分支
    if ! git checkout -b "$temp_branch" "origin/$target_remote" 2>/dev/null; then
        echo -e "${C_ERROR}❌ 无法检出远程分支，可能该分支不存在或权限不足。${C_RESET}"
        rm "$payload_tar"
        [[ "$stashed" -eq 1 ]] && git stash pop
        return
    fi

    # D. 解包覆盖
    tar -xf "$payload_tar"
    rm "$payload_tar"

    # E. 提交并推送
    git add .
    if git commit -m "chore(inject): inject files from $current_branch"; then
        echo -e "${C_INFO}🚀 推送到远程...${C_RESET}"
        git push origin HEAD:"$target_remote"
        echo -e "${C_SUCCESS}✅ 注入成功！${C_RESET}"
    else
        echo -e "${C_WARN}没有检测到文件变化，跳过推送。${C_RESET}"
    fi

    # F. 清理现场
    git checkout "$current_branch" >/dev/null 2>&1
    git branch -D "$temp_branch" >/dev/null 2>&1

    # G. 恢复 Stash
    if [[ "$stashed" -eq 1 ]]; then
        echo -e "${C_INFO}恢复工作区...${C_RESET}"
        git stash pop >/dev/null 2>&1
    fi
    
    echo -e "${C_INFO}按任意键返回...${C_RESET}"
    read -n 1 -s -r
}

# ----------------------------
# 8. 主菜单 Loop
# ----------------------------
main_menu() {
    while true; do
        clear 
        local header_content=$(get_status_header)
        
        # 在这里加入 "💉 远程注射"
        local choice=$(printf "🔄 刷新状态\n📥 拉取代码 (Pull)\n🚀 智能提交 & 推送 (Smart Commit & Push)\n💉 远程注射 (Inject to Remote)\n📤 推送菜单 (Push Options)\n🌿 切换分支 (Checkout)\n🔍 文件审计 (Explorer)\n🍒 定向同步 (Sync Files)\n📜 查看日志 (Log)\n📂 结构迁移 (Migrate)\n❌ 退出" | \
            fzf --ansi --layout=reverse --border=rounded --margin=1 --header-first \
                --height=100% --prompt="✨ GitCLI > " --header="$header_content")

        [[ -z "$choice" ]] && choice="🔄 刷新状态"

        case "$choice" in
            *"刷新"*) continue ;;
            *"拉取"*) git pull ;;
            *"智能提交"*) smart_commit_and_push ;;
            *"远程注射"*) inject_file_to_remote ;;  # <--- 绑定新函数
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

        if [[ "$choice" != *"刷新"* && "$choice" != *"推送菜单"* && "$choice" != *"远程注射"* ]]; then
            echo -e "\n${C_INFO}按任意键继续...${C_RESET}"
            read -n 1 -s -r
        fi
    done
}
# 启动
main_menu