#!/bin/bash

# 🚀 GitHub Issue Management System - 自動インストールスクリプト
# 使用方法: curl -sSL https://raw.githubusercontent.com/nakamasato/Claude-Code-Communication/refactor/github-issue-management-system/install.sh | bash

set -e

echo "🤖 GitHub Issue Management System インストール開始"
echo "=================================================="

# カラー定義
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 前提条件チェック
check_prerequisites() {
    log_info "前提条件をチェック中..."
    
    # Git チェック
    if ! command -v git &> /dev/null; then
        log_error "Gitがインストールされていません"
        exit 1
    fi
    
    # tmux チェック
    if ! command -v tmux &> /dev/null; then
        log_error "tmuxがインストールされていません"
        echo "macOS: brew install tmux"
        echo "Ubuntu: sudo apt install tmux"
        exit 1
    fi
    
    # gh CLI チェック
    if ! command -v gh &> /dev/null; then
        log_warning "GitHub CLI (gh) がインストールされていません"
        echo "インストール方法: https://cli.github.com/"
        read -p "続行しますか？ (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
    
    log_success "前提条件チェック完了"
}

# インストール方式選択
select_installation_method() {
    echo ""
    echo "📦 インストール方式を選択してください:"
    echo "1) モジュラー構成 (推奨) - 専用ディレクトリで独立管理"
    echo "2) CLAUDE.md統合 - 既存設定に追記"
    echo "3) サブディレクトリ独立 - 完全独立運用"
    echo ""
    
    while true; do
        read -p "選択 (1-3): " choice
        case $choice in
            1)
                INSTALL_METHOD="modular"
                log_info "モジュラー構成を選択しました"
                break
                ;;
            2)
                INSTALL_METHOD="integration"
                log_info "CLAUDE.md統合を選択しました"
                break
                ;;
            3)
                INSTALL_METHOD="independent"
                log_info "サブディレクトリ独立を選択しました"
                break
                ;;
            *)
                echo "1-3のいずれかを選択してください"
                ;;
        esac
    done
}

# ファイルダウンロード
download_files() {
    local target_dir="$1"
    local base_url="https://raw.githubusercontent.com/nakamasato/Claude-Code-Communication/refactor/github-issue-management-system"
    
    log_info "必要ファイルをダウンロード中..."
    
    mkdir -p "${target_dir}/instructions"
    
    # ファイルリスト
    local files=(
        "instructions/issue-manager.md"
        "instructions/worker.md"
        "agent-send.sh"
        "setup.sh"
        "local-verification.md"
    )
    
    for file in "${files[@]}"; do
        log_info "ダウンロード: $file"
        curl -sSL "${base_url}/${file}" -o "${target_dir}/${file}"
        
        # 実行権限付与（shファイルの場合）
        if [[ $file == *.sh ]]; then
            chmod +x "${target_dir}/${file}"
        fi
    done
    
    log_success "ファイルダウンロード完了"
}

# モジュラー構成インストール
install_modular() {
    log_info "モジュラー構成でインストール中..."
    
    local target_dir=".claude-issue-manager"
    
    # ディレクトリ作成
    mkdir -p "$target_dir"
    
    # ファイルダウンロード
    download_files "$target_dir"
    
    # CLAUDE-issue.md作成
    cat > "${target_dir}/CLAUDE-issue.md" << 'EOF'
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
    
    # settings.local.json 更新案内
    cat > "${target_dir}/settings-update.json" << 'EOF'
{
  "permissions": {
    "allow": [
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
EOF
    
    log_success "モジュラー構成インストール完了"
    
    echo ""
    echo "📋 次の手順:"
    echo "1. .claude/settings.local.json に以下の権限を追加:"
    echo "   cat ${target_dir}/settings-update.json"
    echo ""
    echo "2. tmux環境セットアップ:"
    echo "   ./${target_dir}/setup.sh"
    echo ""
    echo "3. Claude起動:"
    echo "   claude --file ${target_dir}/CLAUDE-issue.md"
}

# CLAUDE.md統合インストール
install_integration() {
    log_info "CLAUDE.md統合でインストール中..."
    
    # instructionsディレクトリに配置
    download_files "."
    
    # CLAUDE.md統合内容作成
    cat > "claude-issue-integration.md" << 'EOF'

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
EOF
    
    log_success "統合用ファイル準備完了"
    
    echo ""
    echo "📋 次の手順:"
    echo "1. 以下の内容をCLAUDE.mdに追記:"
    echo "   cat claude-issue-integration.md"
    echo ""
    echo "2. settings.local.jsonに権限追加が必要です"
    echo "   詳細は INSTALLATION.md を参照"
}

# 独立インストール
install_independent() {
    log_info "サブディレクトリ独立でインストール中..."
    
    local target_dir="issue-management"
    
    # ディレクトリ作成
    mkdir -p "$target_dir"
    
    # ファイルダウンロード
    download_files "$target_dir"
    
    # 独立用のCLAUDE.md作成
    cp CLAUDE.md "${target_dir}/" 2>/dev/null || cat > "${target_dir}/CLAUDE.md" << 'EOF'
# GitHub Issue Management System

## エージェント構成
- **issue-manager** (multiagent:0.0): GitHub Issue管理者
- **worker1,2,3** (multiagent:0.1-3): Issue解決担当

## あなたの役割
- **issue-manager**: @instructions/issue-manager.md
- **worker1,2,3**: @instructions/worker.md

## メッセージ送信
```bash
./agent-send.sh [相手] "[メッセージ]"
```

## 基本フロー
GitHub Issues → issue-manager → workers → issue-manager → GitHub PRs
EOF
    
    log_success "独立ディレクトリインストール完了"
    
    echo ""
    echo "📋 次の手順:"
    echo "1. issue-managementディレクトリに移動:"
    echo "   cd issue-management"
    echo ""
    echo "2. tmux環境セットアップ:"
    echo "   ./setup.sh"
    echo ""
    echo "3. Claude起動:"
    echo "   claude"
}

# メイン実行
main() {
    check_prerequisites
    select_installation_method
    
    case $INSTALL_METHOD in
        "modular")
            install_modular
            ;;
        "integration")
            install_integration
            ;;
        "independent")
            install_independent
            ;;
    esac
    
    echo ""
    log_success "🎉 GitHub Issue Management System インストール完了！"
    echo ""
    echo "📚 詳細な使用方法:"
    echo "   https://github.com/nakamasato/Claude-Code-Communication/blob/refactor/github-issue-management-system/INSTALLATION.md"
}

# スクリプト実行
main "$@"