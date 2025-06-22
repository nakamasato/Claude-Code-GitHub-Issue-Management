#!/bin/bash

# 🚀 GitHub Issue Management System 環境構築

set -e  # エラー時に停止

# Worker数の設定（デフォルト: 3）
WORKER_COUNT=${1:-3}

# Worker数の妥当性チェック
if ! [[ "$WORKER_COUNT" =~ ^[1-9][0-9]*$ ]] || [ "$WORKER_COUNT" -gt 10 ]; then
    echo "❌ エラー: Worker数は1-10の範囲で指定してください"
    echo "使用方法: $0 [worker数]"
    echo "例: $0 3  # 3つのWorkerを作成（デフォルト）"
    echo "例: $0 5  # 5つのWorkerを作成"
    exit 1
fi

# 色付きログ関数
log_info() {
    echo -e "\033[1;32m[INFO]\033[0m $1"
}

log_success() {
    echo -e "\033[1;34m[SUCCESS]\033[0m $1"
}

echo "🤖 GitHub Issue Management System 環境構築"
echo "============================================="
echo "📊 設定: Worker数 = $WORKER_COUNT"
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
    echo "    Pane $i: worker$i       (Issue解決担当者$(printf '\x$(printf %x $((i+64)))'))"
done

echo ""
log_success "🎉 GitHub Issue管理システム環境セットアップ完了！"
echo ""
echo "📋 次のステップ:"
echo "  1. 🤖 Claude Code起動:"
echo "     # Issue Manager起動"
echo "     tmux send-keys -t multiagent:0.0 'claude --dangerously-skip-permissions' C-m"
echo "     # Worker一括起動"
echo "     for i in {1..$WORKER_COUNT}; do tmux send-keys -t multiagent:0.\$i 'claude --dangerously-skip-permissions' C-m; done"
echo ""
echo "  2. 🔗 セッションアタッチ:"
echo "     tmux attach-session -t multiagent   # GitHub Issue管理システム確認"
echo ""
echo "  3. 📜 指示書確認:"
echo "     Issue Manager: instructions/issue-manager.md"
echo "     worker1-${WORKER_COUNT}: instructions/worker.md"
echo "     システム構造: CLAUDE.md"
echo ""
echo "  4. 🎯 システム起動: Issue Managerに「あなたはissue-managerです。指示書に従ってGitHub Issueの監視を開始してください」と入力"
echo ""
echo "  5. 📋 GitHub設定確認:"
echo "     gh auth status  # GitHub CLI認証確認"
echo "     gh repo view     # リポジトリ確認"
