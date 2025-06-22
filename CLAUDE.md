# GitHub Issue Management System

## エージェント構成
- **issue-manager** (multiagent:0.0): GitHub Issue管理者
- **worker1-N** (multiagent:0.1-N): Issue解決担当（Nはsetup.shで指定、デフォルト3）

## あなたの役割
- **issue-manager**: @claude/instructions/issue-manager.md
- **worker1-N**: @claude/instructions/worker.md

## メッセージ送信
```bash
./claude/agent-send.sh [相手] "[メッセージ]"
```

## 基本フロー
GitHub Issues → issue-manager → workers → issue-manager → GitHub PRs

## Worker安全環境フロー
1. **issue-manager**: worktreeディレクトリ作成
2. **issue-manager**: worktreeディレクトリでworker用Claude起動指示
3. **worker**: 分離されたworktree環境で安全に作業実行
4. **worker**: mainブランチ汚染のリスクなし
