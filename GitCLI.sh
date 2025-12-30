#!/usr/bin/env bash

# ======================================================
# GitCLI.sh - v2.4 (层级导航增强版)
# 更新：文件审计改为层级化目录浏览，解决大项目文件查找难问题
# ======================================================

set -uo pipefail # 去掉 -e 避免 fzf 取消时退出脚本

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

# 新增：通用的推送确认函数
confirm_and_push() {
    echo ""
    echo -e "${C_WARN}本地提交已完成。是否推送到远程 (origin/$CURRENT_BRANCH)？(Y/n)${C_RESET}"
    read -r push_ans
    
    if [[ -z "$push_ans" || "$push_ans" == "y" || "$push_ans" == "Y" ]]; then
        echo -e "${C_INFO}🚀 正在推送...${C_RESET}"
        if git push; then
            echo -e "${C_SUCCESS}✅ 推送完成！${C_RESET}"
        else
            echo -e "${C_ERROR}❌ 推送失败（可能是网络问题或需要拉取最新代码）${C_RESET}"
        fi
    else
        echo -e "${C_INFO}👌 已跳过推送，变更仅保留在本地。${C_RESET}"
    fi
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

    if (( behind > 0 )); then
        (( score -= 40 ))
        (( score < 60 )) && score=60
    fi

    if (( ahead > 15 )); then
        (( score -= (ahead - 15) * 2 ))
        (( score < 80 )) && score=80
    fi

    if git status --porcelain | grep -q '^UU '; then
        (( score -= 30 ))
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

# ----------------------------
# 状态面板函数 (支持多行)
# ----------------------------
show_repo_status() {
    local branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "Unknown")
    local added=$(git status --porcelain | grep -c '^A ' || echo 0)
    local modified=$(git status --porcelain | awk '$1 ~ /^(M|MM|AM)/ {count++} END {print count+0}' || echo 0)
    local deleted=$(git status --porcelain | grep -c '^D ' || echo 0)
    local untracked=$(git status --porcelain | grep -c '^?? ' || echo 0)

    local ahead=0 behind=0
    if git rev-parse --verify "origin/$branch" >/dev/null 2>&1; then
        read -r behind ahead <<<"$(git rev-list --left-right --count "origin/$branch...$branch" 2>/dev/null || echo "0 0")"
    fi

    echo -e "${C_MENU}┌──────────────── Git 状态面板 ────────────────┐${C_RESET}"
    echo -e "${C_MENU}│${C_RESET} 分支: ${C_SUCCESS}${branch}${C_RESET}  同步: ${C_WARN}↑$ahead ↓$behind${C_RESET}                 ${C_MENU}│${C_RESET}"
    echo -e "${C_MENU}│${C_RESET} 变更: ${C_SUCCESS}A:$added${C_RESET} ${C_WARN}M:$modified${C_RESET} ${C_ERROR}D:$deleted${C_RESET} ${C_INFO}?:$untracked${C_RESET}            ${C_MENU}│${C_RESET}"
    echo -e "${C_MENU}└──────────────────────────────────────────────┘${C_RESET}"
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
    fi
}

# ----------------------------
# DeepSeek AI 提交助手
# ----------------------------
generate_ai_commit() {
    if [[ -z "${DEEPSEEK_API_KEY:-}" ]]; then
        echo -e "${C_ERROR}❌ 未检测到 DEEPSEEK_API_KEY 环境变量${C_RESET}" >&2
        echo -e "${C_INFO}请在终端执行: export DEEPSEEK_API_KEY='你的sk-key'${C_RESET}" >&2
        return 1
    fi

    local diff_content=$(git diff --cached | head -c 4000)
    
    if [[ -z "$diff_content" ]]; then
        echo -e "${C_WARN}⚠️ 暂存区为空，请先 git add 文件${C_RESET}" >&2
        return 1
    fi

    echo -e "${C_INFO}🤖 正在请求 DeepSeek 分析代码变更...${C_RESET}" >&2

    local system_prompt="你是一个资深开发者。请根据 git diff 生成一个符合 Conventional Commits 规范的英文 Commit Message。要求：1. 仅输出 Message 本身，不要Markdown，不要解释。 2. 只有一行总结。"
    
    local payload=$(jq -n \
                  --arg sys "$system_prompt" \
                  --arg user "$diff_content" \
                  '{
                    model: "deepseek-chat",
                    messages: [
                      {role: "system", content: $sys},
                      {role: "user", content: $user}
                    ],
                    temperature: 0.7,
                    stream: false
                  }')

    local response=$(curl -s -X POST "https://api.deepseek.com/chat/completions" \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer $DEEPSEEK_API_KEY" \
        -d "$payload")

    local ai_msg=$(echo "$response" | jq -r '.choices[0].message.content' 2>/dev/null)

    if [[ -z "$ai_msg" || "$ai_msg" == "null" ]]; then
        echo -e "${C_ERROR}❌ API 调用失败或返回为空${C_RESET}" >&2
        echo "调试信息: $response" >&2
        return 1
    fi

    echo "$ai_msg"
    return 0
}

# ----------------------------
# 增强版智能提交
# ----------------------------
smart_commit() {
    if [[ -n "$(git stash list | grep 'Auto stash by GitCLI' | tail -1)" ]]; then
        echo -e "${C_WARN}检测到最近的 stash 是工具自动创建的${C_RESET}"
        echo -e "${C_INFO}是否立即恢复 stash 并继续？(y/n)${C_RESET}"
        read -r ans
        [[ "$ans" == "y" ]] && git stash pop
    fi

    if [[ -z "$(git status --porcelain)" ]]; then
        echo -e "${C_WARN}当前工作区无任何变更，无需提交${C_RESET}"
        return
    fi

    echo -e "${C_INFO}🔍 准备提交...${C_RESET}"

    local selected_files=$(git status --porcelain | \
        fzf -m --prompt="多选要提交的文件（Tab 选中，Enter 确认）: " \
            --preview="echo {} | awk '{print \$2}' | xargs git diff --color=always" \
            --preview-window=right:60% | \
        awk '{print $2}')

    if [[ -z "$selected_files" ]]; then
        echo -e "${C_WARN}未选择文件，取消操作${C_RESET}"
        return
    fi

    echo "$selected_files" | xargs git add

    local commit_msg=""
    
    echo -e "${C_MENU}请选择 Commit Message 来源：${C_RESET}"
    local msg_source=$(printf "✨ AI 自动生成 (DeepSeek)\n📝 手动输入\n🔙 取消" | fzf --prompt="选择方式 > ")

    if [[ "$msg_source" == "✨ AI 自动生成 (DeepSeek)" ]]; then
        local ai_result=$(generate_ai_commit)
        if [[ $? -eq 0 ]]; then
            echo -e "${C_SUCCESS}AI 建议: ${ai_result}${C_RESET}"
            echo -e "${C_INFO}按 Enter 采用，输入 e 编辑，输入 n 取消${C_RESET}"
            read -r confirm
            if [[ "$confirm" == "e" || "$confirm" == "E" ]]; then
                commit_msg="$ai_result"
                git commit -e -m "$commit_msg"
                # 编辑模式下，commit 成功后也要询问推送，所以这里不return，往下走
            elif [[ "$confirm" == "n" || "$confirm" == "N" ]]; then
                echo -e "${C_WARN}已取消提交${C_RESET}"
                git reset 
                return
            else
                commit_msg="$ai_result"
            fi
        else
            echo -e "${C_WARN}转为手动输入...${C_RESET}"
            read -r -p "请输入提交信息: " commit_msg
        fi
    elif [[ "$msg_source" == "📝 手动输入" ]]; then
        read -r -p "请输入提交信息: " commit_msg
    else
        echo -e "${C_WARN}操作已取消${C_RESET}"
        git reset
        return
    fi

    # 执行提交
    if [[ -n "$commit_msg" ]]; then
        # 如果刚才已经是 git commit -e 执行过了，这里就要判断一下是否还需要 commit
        # 简单起见，如果上面 msg_source 走了编辑逻辑，git commit 已经执行，
        # 我们只在 手动输入 或者 AI 确认采用 的时候执行这里的 commit
        
        # 优化逻辑：检查是否已经提交成功 (通过比较 HEAD 变化有点复杂，简单做)
        # 实际上上面的 git commit -e 执行完，这个函数就可以接询问了。
        
        # 为防止重复提交，我们调整一下上面的逻辑结构：
        # 如果是编辑模式，已经commit了。
        # 如果是手动输入或AI直接采用，这里执行commit。
        
        if [[ "$confirm" != "e" && "$confirm" != "E" ]]; then
             git commit -m "$commit_msg"
        fi
        
        echo -e "${C_SUCCESS}🎉 提交成功！${C_RESET}"
        
        # 调用统一的推送确认
        confirm_and_push
    fi
}

# ----------------------------
# 文件结构智能迁移
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
    echo -e "${C_WARN}是否执行迁移提交？(y/n)${C_RESET}"
    read -r ans
    [[ "$ans" != "y" && "$ans" != "Y" ]] && return

    git add -A
    git commit -m "$commit_msg"
    
    # 以前是直接 push，现在改为询问
    confirm_and_push
}

# ----------------------------
# 定向文件同步向导
# ----------------------------
sync_specific_files() {
    echo -e "${C_INFO}🔍 步骤 1/3: 选择代码来源分支...${C_RESET}"
    local source_branch=$(git branch -a --format='%(refname:short)' | \
        grep -v "origin/HEAD" | \
        grep -v "^$CURRENT_BRANCH$" | \
        sort -u | \
        fzf --prompt="从哪个分支同步? > " \
            --preview="git log --oneline --graph --color=always {} | head -20" \
            --height=40% --layout=reverse --border)
    if [[ -z "$source_branch" ]]; then echo -e "${C_WARN}未选择分支，已取消${C_RESET}"; return; fi

    echo -e "${C_INFO}🔍 步骤 2/3: 选择文件 (支持模糊搜索)...${C_RESET}"
    local diff_files=$(git diff --name-only "$CURRENT_BRANCH" "$source_branch")
    if [[ -z "$diff_files" ]]; then echo -e "${C_SUCCESS}✅ 当前分支与 $source_branch 完全一致，无需同步。${C_RESET}"; return; fi

    local selected_files=$(echo "$diff_files" | \
        fzf -m --prompt="输入文件名模糊搜索 (Tab多选) > " \
            --preview="git diff --color=always $CURRENT_BRANCH $source_branch -- {}" \
            --preview-window=right:70% --height=80% --layout=reverse --border)
    if [[ -z "$selected_files" ]]; then echo -e "${C_WARN}未选择文件，已取消${C_RESET}"; return; fi

    echo -e "${C_INFO}🔍 步骤 3/3: 选择同步策略...${C_RESET}"
    local mode=$(printf "🔥 覆盖 (Overwrite)\n🧬 合并 (Merge)" | \
        fzf --prompt="对选中文件执行什么操作? > " --height=30% --layout=reverse --border)
    if [[ -z "$mode" ]]; then return; fi

    echo ""
    local count=0
    while IFS= read -r file; do
        ((count++))
        if [[ "$mode" == *"覆盖"* ]]; then
            git checkout "$source_branch" -- "$file"
            echo -e "${C_SUCCESS}[$count] 已覆盖: $file${C_RESET}"
        elif [[ "$mode" == *"合并"* ]]; then
            if git checkout --merge "$source_branch" -- "$file" 2>/dev/null; then
                echo -e "${C_SUCCESS}[$count] 已合并: $file${C_RESET}"
            else
                echo -e "${C_ERROR}[$count] 合并冲突: $file (请手动解决)${C_RESET}"
            fi
        fi
    done <<< "$selected_files"
    echo ""
    echo -e "${C_INFO}✨ 操作完成！文件状态已更新。${C_RESET}"
}

# ----------------------------
# 层级化文件变更时光机 (v2.4 升级版)
# ----------------------------
file_history_explorer() {
    local current_path="."
    
    while true; do
        # 获取当前路径下的内容（文件夹加 / 标识）
        # ls -F 会给目录加 /，给可执行文件加 *
        local list=$(ls -F "$current_path" | grep -v '^[./]')
        
        # 加上“返回上级”和“查看当前目录下所有变更”选项
        local selection=$(printf ".. (返回上级)\n%s" "$list" | \
            fzf --prompt="📂 $current_path > " \
                --header="Enter: 进入/选择 | Esc: 返回主菜单" \
                --preview="
                    item='${current_path}/{}';
                    item=\${item%*}; # 去掉 ls -F 可能带的 *
                    if [[ -d \$item ]]; then
                        ls -C --color=always \$item;
                    else
                        git log --oneline --color=always -n 10 -- \$item;
                    fi
                " --preview-window=right:60%)

        # 1. 处理取消/退出
        if [[ -z "$selection" ]]; then break; fi

        # 2. 处理返回上级
        if [[ "$selection" == ".. (返回上级)" ]]; then
            if [[ "$current_path" == "." ]]; then
                break # 已经在根目录，按返回直接退出
            else
                current_path=$(dirname "$current_path")
                continue
            fi
        fi

        # 3. 处理选中的路径
        local clean_name=$(echo "$selection" | sed 's/[*]$//') # 去掉可执行文件标记
        local full_path="${current_path}/${clean_name}"
        full_path=$(echo "$full_path" | sed 's#\./##') # 清理路径中的 ./

        if [[ -d "$full_path" ]]; then
            # 如果是目录，更新当前路径并继续循环
            current_path="$full_path"
        else
            # 如果是文件，进入时光机展示历史
            echo -e "${C_INFO}⏳ 正在分析 $full_path 的历史记录...${C_RESET}"
            git log --oneline --color=always --follow -- "$full_path" | \
                fzf --ansi --layout=reverse --border \
                    --prompt="📅 $full_path 的变更记录 > " \
                    --header="Enter: 详情模式(Less) | Esc: 返回目录" \
                    --preview="git show --color=always {1} -- \"$full_path\"" \
                    --preview-window=right:65% \
                    --bind "enter:execute(git show --color=always {1} -- \"$full_path\" | less -R)"
            
            # 查看完历史后，依然留在当前目录，方便查看同目录其他文件
            continue
        fi
    done
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
    local response=$(curl -s -X POST $GH_HEADER -H "Accept: application/vnd.github+json" \
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

pull_remote_branch() {
    git fetch --quiet
    local branch=$(git ls-remote --heads origin | awk '{print $2}' | sed 's@refs/heads/@@' | \
        fzf --prompt="选择远程分支: " --preview="git log --oneline --graph --decorate --color=always origin/{}" --preview-window=right:60%)
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

browse_log() {
    local selected_commit=$(git log --oneline --graph --color=always --all | \
        fzf --ansi --no-sort --reverse --prompt="浏览历史 (Enter 查看详情, Esc 退出): " \
        --preview="echo {} | grep -o '[a-f0-9]\{7\}' | head -1 | xargs -I % git show --color=always %" \
        --preview-window=right:65%)
    if [[ -n "$selected_commit" ]]; then
        local commit_hash=$(echo "$selected_commit" | grep -o '[a-f0-9]\{7\}' | head -1)
        echo -e "${C_INFO}正在查看 Commit: ${C_SUCCESS}$commit_hash${C_RESET}"
        git show "$commit_hash"
    fi
}

# ----------------------------
# 智能强制推送 (新功能)
# ----------------------------
smart_force_push() {
    local action=$(printf "👉 当前分支 ($CURRENT_BRANCH)\n🔀 选择其他分支..." | \
        fzf --prompt="强制推送目标 > " --height=20% --layout=reverse --border)

    local target_branch="$CURRENT_BRANCH"

    if [[ "$action" == *"选择其他"* ]]; then
        target_branch=$(git branch --format='%(refname:short)' | \
            fzf --prompt="选择要强制推送的本地分支 > " \
                --preview="git log --oneline --graph --color=always {} | head -20" \
                --height=50% --layout=reverse --border)
    fi

    [[ -z "$target_branch" ]] && return

    echo ""
    echo -e "${C_ERROR}⚠️  高危操作警告 ⚠️${C_RESET}"
    echo -e "你即将执行: git push ${C_ERROR}--force-with-lease${C_RESET} origin ${C_WARN}${target_branch}${C_RESET}"
    echo -e "这将用本地代码覆盖远程，请确保没有他人在该分支提交代码。"
    echo ""
    echo -e "${C_WARN}请输入 YES (大写) 确认执行，其他键取消: ${C_RESET}"
    read -r confirm

    if [[ "$confirm" == "YES" ]]; then
        echo -e "${C_INFO}🚀 正在执行强制推送...${C_RESET}"
        git push --force-with-lease origin "$target_branch" && \
        echo -e "${C_SUCCESS}✅ 强制推送完成！${C_RESET}"
    else
        echo -e "${C_INFO}⛔ 已取消操作${C_RESET}"
    fi
}

push_menu() {
    detect_conflicts && { echo -e "${C_ERROR}存在冲突，请先解决${C_RESET}"; return; }

    local choice=$(printf "普通推送\n强制推送（--force-with-lease）\n智能提交 + 推送\n推送到新分支（备份）\n智能文件结构迁移并推送\n返回主菜单" |
        fzf --prompt="选择推送操作: ")

    local needs_stash=1
    if [[ "$choice" == "智能提交 + 推送" || "$choice" == "智能文件结构迁移并推送" || "$choice" == "返回主菜单" ]]; then
        needs_stash=0
    fi

    local did_stash=1
    if [[ "$needs_stash" -eq 1 ]]; then
        auto_stash && did_stash=0
    fi

    case "$choice" in
        "普通推送") git push ;;
        "强制推送（--force-with-lease）") smart_force_push ;;
        "智能提交 + 推送") smart_commit ;;
        "推送到新分支（备份）") push_new_branch ;;
        "智能文件结构迁移并推送") smart_file_migration ;;
        *) [[ "$did_stash" -eq 0 ]] && auto_pop 0; return ;;
    esac

    [[ "$did_stash" -eq 0 ]] && auto_pop 0
}

# ----------------------------
# 主菜单
# ----------------------------
main_menu() {
    while true; do
        clear
        local status_info=$(show_repo_status)
        local choice=$(printf "🔄 刷新状态\n📥 拉取代码 (Pull)\n🚀 推送选项 (Push)\n🔍 层级文件审计 (History)\n🍒 定向同步 (Pick)\n🌿 切换分支\n📜 交互日志 (Log)\n❌ 退出" | \
            fzf --ansi --layout=reverse --border --margin=1 --header-first \
                --prompt="✨ 操作 > " --header="$status_info") || choice="刷新状态"

        case "$choice" in
            *"刷新"*) continue ;;
            *"拉取"*) git pull ;;
            *"推送"*) push_menu ;; # 调用你之前的 push_menu
            *"层级文件审计"*) file_history_explorer ;;
            *"定向同步"*) sync_specific_files ;; # 调用你之前的同步函数
            *"切换分支"*) switch_branch ;;
            *"交互日志"*) browse_log ;; # 调用你之前的带预览日志
            *"退出"*) exit 0 ;;
        esac

        if [[ "$choice" != "刷新状态" ]]; then
            echo -e "\n${C_INFO}按任意键继续...${C_RESET}"
            read -n 1 -s -r
        fi
    done
}

main_menu