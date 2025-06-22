#!/bin/bash

# 🚀 GitHub Issue Management System 環境構築

set -e  # エラー時に停止

# ヘルプオプション処理
if [[ "$1" == "--help" || "$1" == "-h" ]]; then
    echo "🤖 GitHub Issue Management System Environment Setup"
    echo "============================================="
    echo ""
    echo "Usage:"
    echo "  $0 [worker_count]"
    echo ""
    echo "Arguments:"
    echo "  worker_count    Number of Workers to create (1-10, default: 3)"
    echo ""
    echo "Environment Variables:"
    echo "  ISSUE_MANAGER_ARGS    Claude arguments for Issue Manager (default: --dangerously-skip-permissions)"
    echo "  WORKER_ARGS           Claude arguments for Workers (default: --dangerously-skip-permissions)"
    echo ""
    echo "Examples:"
    echo "  $0                                                        # Create 3 Workers with default settings"
    echo "  $0 5                                                      # Create 5 Workers"
    echo "  ISSUE_MANAGER_ARGS='' WORKER_ARGS='' $0                   # Run without Claude arguments"
    echo "  ISSUE_MANAGER_ARGS='--model claude-3-5-sonnet-20241022' \\"
    echo "  WORKER_ARGS='--model claude-3-5-sonnet-20241022' $0       # Specify a particular model"
    echo ""
    exit 0
fi

# Worker count setting (default: 3)
WORKER_COUNT=${1:-3}

# Claude arguments setting (obtained from environment variables, default maintains existing behavior)
ISSUE_MANAGER_ARGS=${ISSUE_MANAGER_ARGS:-"--dangerously-skip-permissions"}
WORKER_ARGS=${WORKER_ARGS:-"--dangerously-skip-permissions"}

# Export environment variables (make available within tmux session)
export ISSUE_MANAGER_ARGS
export WORKER_ARGS

# Worker count validity check
if ! [[ "$WORKER_COUNT" =~ ^[1-9][0-9]*$ ]] || [ "$WORKER_COUNT" -gt 10 ]; then
    echo "❌ Error: Worker count must be specified in the range 1-10"
    echo "Usage: $0 [worker_count]"
    echo "Example: $0 3  # Create 3 Workers (default)"
    echo "Example: $0 5  # Create 5 Workers"
    echo "Help: $0 --help"
    exit 1
fi

# Colored log functions
log_info() {
    echo -e "\033[1;32m[INFO]\033[0m $1"
}

log_success() {
    echo -e "\033[1;34m[SUCCESS]\033[0m $1"
}

echo "🤖 GitHub Issue Management System 環境構築"
echo "============================================="
echo "📊 設定: Worker数 = $WORKER_COUNT"
echo "🔧 Claude引数設定:"
echo "   Issue Manager: ${ISSUE_MANAGER_ARGS:-"(引数なし)"}"
echo "   Workers: ${WORKER_ARGS:-"(引数なし)"}"
echo ""

# STEP 1: 既存セッションクリーンアップ
log_info "🧹 既存セッションクリーンアップ開始..."

tmux kill-session -t multiagent 2>/dev/null && log_info "multiagentセッション削除完了" || log_info "multiagentセッションは存在しませんでした"

# 完了ファイルクリア
mkdir -p ./tmp/worker-status
rm -f ./tmp/worker*_done.txt 2>/dev/null && log_info "既存の完了ファイルをクリア" || log_info "完了ファイルは存在しませんでした"
rm -f ./tmp/worker-status/worker*_busy.txt 2>/dev/null && log_info "既存のWorker状況ファイルをクリア" || log_info "Worker状況ファイルは存在しませんでした"

# .gitignoreにworktreeエントリを追加
log_info ".gitignoreにworktreeエントリを追加中..."
if [ ! -f ".gitignore" ]; then
    touch .gitignore
    log_info ".gitignoreファイルを作成しました"
fi

if ! grep -q "^worktree/$" .gitignore; then
    echo "worktree/" >> .gitignore
    log_info ".gitignoreにworktree/を追加しました"
else
    log_info ".gitignoreに既にworktree/が存在します"
fi

# worktreeディレクトリの準備
mkdir -p worktree
log_info "worktreeディレクトリを作成しました"

log_success "✅ クリーンアップ完了"
echo ""

# STEP 2: multiagentセッション作成（動的ペイン数：issue-manager + workers）
TOTAL_PANES=$((WORKER_COUNT + 1))
log_info "📺 multiagentセッション作成開始 (${TOTAL_PANES}ペイン: issue-manager + ${WORKER_COUNT}workers)..."

# 最初のペイン作成
tmux new-session -d -s multiagent -n "agents"

# 動的なペイン分割（ワーカー数に応じて）
if [ "$WORKER_COUNT" -eq 1 ]; then
    # 1 worker: 左右分割
    tmux split-window -h -t "multiagent:0"
elif [ "$WORKER_COUNT" -eq 2 ]; then
    # 2 workers: 上下分割後、右側を左右分割
    tmux split-window -h -t "multiagent:0"
    tmux select-pane -t "multiagent:0.1"
    tmux split-window -v
elif [ "$WORKER_COUNT" -eq 3 ]; then
    # 3 workers: 2x2グリッド
    tmux split-window -h -t "multiagent:0"
    tmux select-pane -t "multiagent:0.0"
    tmux split-window -v
    tmux select-pane -t "multiagent:0.2"
    tmux split-window -v
else
    # 4+ workers: 左右分割後、両側を縦分割
    tmux split-window -h -t "multiagent:0"

    # 左側を縦分割（issue-manager + 最初のworker）
    tmux select-pane -t "multiagent:0.0"
    tmux split-window -v

    # 右側を縦分割（残りのworkers）
    tmux select-pane -t "multiagent:0.2"
    for ((i=3; i<=WORKER_COUNT; i++)); do
        tmux split-window -v
    done
fi

# ペインタイトル設定
log_info "ペインタイトル設定中..."

# issue-manager
tmux select-pane -t "multiagent:0.0" -T "issue-manager"

# workers
for ((i=1; i<=WORKER_COUNT; i++)); do
    tmux select-pane -t "multiagent:0.$i" -T "worker$i"
done

# 各ペインの初期設定
for ((i=0; i<=WORKER_COUNT; i++)); do
    # 作業ディレクトリ設定
    tmux send-keys -t "multiagent:0.$i" "cd $(pwd)" C-m

    # Claude引数環境変数を各ペインに設定
    tmux send-keys -t "multiagent:0.$i" "export ISSUE_MANAGER_ARGS='${ISSUE_MANAGER_ARGS}'" C-m
    tmux send-keys -t "multiagent:0.$i" "export WORKER_ARGS='${WORKER_ARGS}'" C-m

    # ペインタイトル取得
    if [ $i -eq 0 ]; then
        PANE_TITLE="issue-manager"
        # issue-manager: 緑色
        tmux send-keys -t "multiagent:0.$i" "export PS1='(\[\033[1;32m\]${PANE_TITLE}\[\033[0m\]) \[\033[1;32m\]\w\[\033[0m\]\$ '" C-m
    else
        PANE_TITLE="worker$i"
        # workers: 青色
        tmux send-keys -t "multiagent:0.$i" "export PS1='(\[\033[1;34m\]${PANE_TITLE}\[\033[0m\]) \[\033[1;32m\]\w\[\033[0m\]\$ '" C-m
    fi

    # ウェルカムメッセージ
    tmux send-keys -t "multiagent:0.$i" "echo '=== ${PANE_TITLE} エージェント ==='" C-m
done

# Claude Code起動（issue-managerのみ）
log_info "🤖 issue-manager用Claude Code起動中..."
tmux send-keys -t "multiagent:0.0" "claude ${ISSUE_MANAGER_ARGS}" C-m

# workers用の待機メッセージ
for ((i=1; i<=WORKER_COUNT; i++)); do
    tmux send-keys -t "multiagent:0.$i" "echo '=== worker$i 待機中 ==='" C-m
    tmux send-keys -t "multiagent:0.$i" "echo 'Issue Managerからの割り当てをお待ちください'" C-m
    tmux send-keys -t "multiagent:0.$i" "echo 'Claudeは割り当て時に自動起動されます'" C-m
done

# Claude起動の待機時間
sleep 3

log_success "✅ issue-manager用Claude Codeの起動完了"
log_success "✅ multiagentセッション作成完了"
echo ""

# STEP 3: 環境確認・表示
log_info "🔍 環境確認中..."

echo ""
echo "📊 セットアップ結果:"
echo "==================="

# tmuxセッション確認
echo "📺 Tmux Sessions:"
tmux list-sessions
echo ""

# ペイン構成表示
echo "📋 ペイン構成:"
echo "  multiagentセッション（${TOTAL_PANES}ペイン）:"
echo "    Pane 0: issue-manager (GitHub Issue管理者)"
for ((i=1; i<=WORKER_COUNT; i++)); do
    echo "    Pane $i: worker$i       (Issue解決担当者#$i)"
done

echo ""
log_success "🎉 GitHub Issue管理システム環境セットアップ完了！"
echo ""
echo "📋 次のステップ:"
echo "  1. 🔗 セッションアタッチ:"
echo "     tmux attach-session -t multiagent   # GitHub Issue管理システム確認"
echo "     ※ Claude Codeはissue-managerペインでのみ起動済みです"
echo "     ※ worker用Claudeは、Issue割り当て時に自動起動されます"
echo ""
echo "  2. 📜 指示書確認:"
echo "     Issue Manager: instructions/issue-manager.md"
echo "     worker1-${WORKER_COUNT}: instructions/worker.md"
echo "     システム構造: CLAUDE.md"
echo ""
echo "  3. 🎯 システム起動: Issue Managerに以下のメッセージを入力:"
echo "     「あなたはissue-managerです。指示書に従ってGitHub Issueの監視を開始してください」"
echo ""
echo "  4. 📋 GitHub設定確認:"
echo "     gh auth status  # GitHub CLI認証確認"
echo "     gh repo view     # リポジトリ確認"
