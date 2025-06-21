#!/bin/bash

# 🚀 GitHub Issue Management System 環境構築

set -e  # エラー時に停止

# 色付きログ関数
log_info() {
    echo -e "\033[1;32m[INFO]\033[0m $1"
}

log_success() {
    echo -e "\033[1;34m[SUCCESS]\033[0m $1"
}

echo "🤖 GitHub Issue Management System 環境構築"
echo "============================================="
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

# STEP 2: multiagentセッション作成（4ペイン：issue-manager + worker1,2,3）
log_info "📺 multiagentセッション作成開始 (4ペイン)..."

# 最初のペイン作成
tmux new-session -d -s multiagent -n "agents"

# 2x2グリッド作成（合計4ペイン）
tmux split-window -h -t "multiagent:0"      # 水平分割（左右）
tmux select-pane -t "multiagent:0.0"
tmux split-window -v                        # 左側を垂直分割
tmux select-pane -t "multiagent:0.2"
tmux split-window -v                        # 右側を垂直分割

# ペインタイトル設定
log_info "ペインタイトル設定中..."
PANE_TITLES=("issue-manager" "worker1" "worker2" "worker3")

for i in {0..3}; do
    tmux select-pane -t "multiagent:0.$i" -T "${PANE_TITLES[$i]}"

    # 作業ディレクトリ設定
    tmux send-keys -t "multiagent:0.$i" "cd $(pwd)" C-m

    # カラープロンプト設定
    if [ $i -eq 0 ]; then
        # issue-manager: 緑色
        tmux send-keys -t "multiagent:0.$i" "export PS1='(\[\033[1;32m\]${PANE_TITLES[$i]}\[\033[0m\]) \[\033[1;32m\]\w\[\033[0m\]\$ '" C-m
    else
        # workers: 青色
        tmux send-keys -t "multiagent:0.$i" "export PS1='(\[\033[1;34m\]${PANE_TITLES[$i]}\[\033[0m\]) \[\033[1;32m\]\w\[\033[0m\]\$ '" C-m
    fi

    # ウェルカムメッセージ
    tmux send-keys -t "multiagent:0.$i" "echo '=== ${PANE_TITLES[$i]} エージェント ==='" C-m
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
echo "  multiagentセッション（4ペイン）:"
echo "    Pane 0: issue-manager (GitHub Issue管理者)"
echo "    Pane 1: worker1       (Issue解決担当者A)"
echo "    Pane 2: worker2       (Issue解決担当者B)"
echo "    Pane 3: worker3       (Issue解決担当者C)"

echo ""
log_success "🎉 GitHub Issue管理システム環境セットアップ完了！"
echo ""
echo "📋 次のステップ:"
echo "  1. 🔗 セッションアタッチ:"
echo "     tmux attach-session -t multiagent   # GitHub Issue管理システム確認"
echo ""
echo "  2. 🤖 Claude Code起動:"
echo "     # Issue Manager起動"
echo "     tmux send-keys -t multiagent:0.0 'claude --dangerously-skip-permissions' C-m"
echo "     # Worker一括起動"
echo "     for i in {1..3}; do tmux send-keys -t multiagent:0.\$i 'claude --dangerously-skip-permissions' C-m; done"
echo ""
echo "  3. 📜 指示書確認:"
echo "     Issue Manager: instructions/issue-manager.md"
echo "     worker1,2,3: instructions/worker.md"
echo "     システム構造: CLAUDE.md"
echo ""
echo "  4. 🎯 システム起動: Issue Managerに「あなたはissue-managerです。指示書に従ってGitHub Issueの監視を開始してください」と入力"
echo ""
echo "  5. 📋 GitHub設定確認:"
echo "     gh auth status  # GitHub CLI認証確認"
echo "     gh repo view     # リポジトリ確認"
