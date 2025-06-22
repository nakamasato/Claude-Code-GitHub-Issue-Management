#!/bin/bash

# 🚀 Agent間メッセージ送信スクリプト

# エージェント→tmuxターゲット マッピング
get_agent_target() {
    case "$1" in
        "issue-manager") echo "multiagent:0.0" ;;
        worker[0-9]|worker[1-9][0-9])
            # workerN形式の場合、Nを抽出してpane番号を計算
            local worker_num="${1#worker}"
            echo "multiagent:0.$worker_num"
            ;;
        *) echo "" ;;
    esac
}

show_usage() {
    cat << EOF
🤖 Agent間メッセージ送信

使用方法:
  $0 [エージェント名] [メッセージ]
  $0 --list

利用可能エージェント:
  issue-manager - GitHub Issue管理者
  worker1-N     - Issue解決担当者 (Nは設定されたworker数まで)

使用例:
  $0 issue-manager "GitHub Issue確認をお願いします"
  $0 worker1 "Issue #123をアサインしました"
  $0 worker5 "Issue解決完了しました"
EOF
}

# エージェント一覧表示
show_agents() {
    echo "📋 利用可能なエージェント:"
    echo "=========================="
    echo "  issue-manager → multiagent:0.0  (GitHub Issue管理者)"

    # tmuxセッションから実際のpane数を取得して表示
    if tmux has-session -t multiagent 2>/dev/null; then
        local pane_count=$(tmux list-panes -t multiagent:0 -F "#{pane_index}" | wc -l)
        local worker_count=$((pane_count - 1))

        for ((i=1; i<=worker_count; i++)); do
            printf "  worker%-7s → multiagent:0.%-2s (Issue解決担当者#%s)\n" "$i" "$i" "$i"
        done
    else
        echo "  (multiagentセッションが見つかりません - setup.shを実行してください)"
    fi
}

# ログ記録
log_send() {
    local agent="$1"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    mkdir -p logs
    echo "[$timestamp] $agent: SENT - \"$message\"" >> logs/send_log.txt
}

# メッセージ送信
send_message() {
    local target="$1"
    local message="$2"

    echo "📤 送信中: $target ← '$message'"

    # Claude Codeのプロンプトを一度クリア
    tmux send-keys -t "$target" C-c
    sleep 0.3

    # メッセージ送信
    tmux send-keys -t "$target" "$message"
    sleep 0.1

    # エンター押下
    tmux send-keys -t "$target" C-m
    sleep 0.5
}

# ターゲット存在確認
check_target() {
    local target="$1"
    local session_name="${target%%:*}"

    if ! tmux has-session -t "$session_name" 2>/dev/null; then
        echo "❌ セッション '$session_name' が見つかりません"
        return 1
    fi

    return 0
}

# メイン処理
main() {
    if [[ $# -eq 0 ]]; then
        show_usage
        exit 1
    fi

    # --listオプション
    if [[ "$1" == "--list" ]]; then
        show_agents
        exit 0
    fi

    if [[ $# -lt 2 ]]; then
        show_usage
        exit 1
    fi

    local agent_name="$1"
    local message="$2"

    # エージェントターゲット取得
    local target
    target=$(get_agent_target "$agent_name")

    if [[ -z "$target" ]]; then
        echo "❌ エラー: 不明なエージェント '$agent_name'"
        echo "利用可能エージェント: $0 --list"
        exit 1
    fi

    # ターゲット確認
    if ! check_target "$target"; then
        exit 1
    fi

    # メッセージ送信
    send_message "$target" "$message"

    # ログ記録
    log_send "$agent_name" "$message"

    echo "✅ 送信完了: $agent_name に '$message'"

    return 0
}

main "$@"
