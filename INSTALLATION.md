# 📦 GitHub Issue管理システム - 他リポジトリへの導入ガイド

既存のリポジトリにGitHub Issue管理システムを導入する際のガイドです。

## 🎯 導入方式の選択

### 方式1: モジュラー構成（推奨）
既存のCLAUDE.mdと競合せず、独立したディレクトリで管理

### 方式2: CLAUDE.md統合
既存のCLAUDE.mdに追記して統合

### 方式3: サブディレクトリ完全独立
完全に独立したサブディレクトリで運用

---

## 🚀 方式1: モジュラー構成（推奨）

### 手順1: 必要ファイルをコピー
```bash
# ターゲットリポジトリに移動
cd /path/to/your-repo

# Issue管理専用ディレクトリを作成
mkdir -p .claude-issue-manager/instructions

# 必要なファイルをコピー
curl -O https://raw.githubusercontent.com/nakamasato/Claude-Code-Communication/refactor/github-issue-management-system/.claude-issue-manager/instructions/issue-manager.md
curl -O https://raw.githubusercontent.com/nakamasato/Claude-Code-Communication/refactor/github-issue-management-system/.claude-issue-manager/instructions/worker.md
curl -O https://raw.githubusercontent.com/nakamasato/Claude-Code-Communication/refactor/github-issue-management-system/.claude-issue-manager/agent-send.sh
curl -O https://raw.githubusercontent.com/nakamasato/Claude-Code-Communication/refactor/github-issue-management-system/.claude-issue-manager/setup.sh
curl -O https://raw.githubusercontent.com/nakamasato/Claude-Code-Communication/refactor/github-issue-management-system/.claude-issue-manager/local-verification.md
```

### 手順2: CLAUDE-issue.md作成
```bash
cat > .claude-issue-manager/CLAUDE-issue.md << 'EOF'
# GitHub Issue Management System

## エージェント構成
- **issue-manager** (multiagent:0.0): GitHub Issue管理者
- **worker1,2,3** (multiagent:0.1-3): Issue解決担当

## あなたの役割
- **issue-manager**: @.claude-issue-manager/instructions/issue-manager.md
- **worker1,2,3**: @.claude-issue-manager/instructions/worker.md

## メッセージ送信
```bash
./.claude-issue-manager/agent-send.sh [相手] "[メッセージ]"
```

## 基本フロー
GitHub Issues → issue-manager → workers → issue-manager → GitHub PRs
EOF
```

### 手順3: settings.local.json更新
```bash
# 既存の設定ファイルに権限を追加
# .claude/settings.local.json の "allow" 配列に以下を追加：
{
  "permissions": {
    "allow": [
      # 既存の権限...
      "Bash(./.claude-issue-manager/agent-send.sh:*)",
      "Bash(gh:*)",
      "Bash(git:*)",
      "Bash(npm:*)",
      "Bash(yarn:*)",
      "Bash(pip:*)",
      "Bash(open:*)",
      "Bash(xdg-open:*)",
      "Bash(kill:*)",
      "Bash(sleep:*)",
      "Bash(cd:*)",
      "Bash(pwd:*)",
      "Bash(basename:*)",
      "Bash(head:*)",
      "Bash(grep:*)",
      "Bash(cat:*)",
      "Bash(rm:*)"
    ]
  }
}
```

### 手順4: 環境セットアップ
```bash
# 実行権限付与
chmod +x .claude-issue-manager/agent-send.sh
chmod +x .claude-issue-manager/setup.sh

# tmux環境セットアップ
./.claude-issue-manager/setup.sh
```

### 手順5: Claude起動
```bash
# Issue Manager起動
claude --file .claude-issue-manager/CLAUDE-issue.md

# 別ターミナルで
tmux attach-session -t multiagent
```

---

## 🔄 方式2: CLAUDE.md統合

### 既存のCLAUDE.mdに追記
```markdown
# 既存のプロジェクト設定
[既存の内容]

---

# GitHub Issue Management System

## エージェント構成（Issue管理用）
- **issue-manager** (multiagent:0.0): GitHub Issue管理者
- **worker1,2,3** (multiagent:0.1-3): Issue解決担当

## Issue管理モード切り替え
```bash
# Issue管理モードに切り替える場合
./agent-send.sh issue-manager "あなたはissue-managerです。指示書に従ってGitHub Issueの監視を開始してください"
```

## 関連ファイル
- Issue Manager: @instructions/issue-manager.md
- Workers: @instructions/worker.md
```

---

## 📁 方式3: サブディレクトリ完全独立

### ディレクトリ構成
```
your-repo/
├── CLAUDE.md (既存)
├── issue-management/
│   ├── CLAUDE.md
│   ├── README.md
│   ├── agent-send.sh
│   ├── setup.sh
│   ├── local-verification.md
│   └── instructions/
│       ├── issue-manager.md
│       └── worker.md
└── .claude/
    └── settings.local.json
```

### 使用方法
```bash
# Issue管理専用ディレクトリに移動
cd issue-management

# Claude起動
claude

# 環境セットアップ
./setup.sh
```

---

## 🛠️ カスタマイズ

### local-verification.mdのカスタマイズ
```bash
# プロジェクト固有の確認項目を追加
vim .claude-issue-manager/local-verification.md

# 確認を無効にする場合
echo "<!-- skip:true -->" | cat - .claude-issue-manager/local-verification.md > temp && mv temp .claude-issue-manager/local-verification.md
```

### agent-send.shのパス調整
方式1の場合、agent-send.sh内のパスを調整：
```bash
# .claude-issue-manager/agent-send.sh を編集
# logs/ → .claude-issue-manager/logs/
# ./tmp/ → .claude-issue-manager/tmp/
```

---

## 🔧 トラブルシューティング

### tmuxセッションの競合
```bash
# 既存セッションの確認
tmux ls

# 競合回避のためセッション名変更
# setup.sh の multiagent を project-multiagent に変更
```

### Claude設定ファイルの競合
```bash
# プロジェクト固有の設定ディレクトリ使用
export CLAUDE_CONFIG_DIR=.claude-issue-manager
```

### worktreeディレクトリの管理
Claude Codeのセキュリティ制限により、worktreeは子ディレクトリに作成されます：
```bash
# 自動生成されるパス例
worktree/issue-123
worktree/issue-456
```

worktreeディレクトリは自動的に.gitignoreに追加され、作業完了後に削除されます。

---

## 📋 導入チェックリスト

- [ ] 必要ファイルをコピー
- [ ] CLAUDE-issue.md または既存CLAUDE.md更新
- [ ] settings.local.json権限追加
- [ ] 実行権限付与
- [ ] local-verification.mdカスタマイズ
- [ ] tmux環境セットアップ
- [ ] Claude起動テスト
- [ ] GitHub CLI認証確認
- [ ] テストIssue作成・処理確認

---

## 🚀 使用開始

```bash
# 1. Issue Manager起動
claude --file .claude-issue-manager/CLAUDE-issue.md

# 2. tmux確認
tmux attach-session -t multiagent

# 3. GitHub Issue作成
gh issue create --title "Test Issue" --body "Testing the system"

# 4. Issue Manager指示
# Issue Manager画面で
あなたはissue-managerです。指示書に従ってGitHub Issueの監視を開始してください。
```