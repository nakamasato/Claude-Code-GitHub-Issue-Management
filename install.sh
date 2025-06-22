#!/bin/bash

# 🚀 GitHub Issue Management System - Enhanced Installation Script
# Usage: curl -sSL https://raw.githubusercontent.com/nakamasato/Claude-Code-Communication/main/install.sh | bash

set -e

echo "🤖 GitHub Issue Management System - Enhanced Installation"
echo "========================================================"

# Color definitions
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

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."

    # Check if we're in a Git repository
    if ! git rev-parse --git-dir > /dev/null 2>&1; then
        log_error "This directory is not a Git repository"
        echo "Please run this script in a Git repository directory"
        exit 1
    fi

    # Git check
    if ! command -v git &> /dev/null; then
        log_error "Git is not installed"
        exit 1
    fi

    # tmux check
    if ! command -v tmux &> /dev/null; then
        log_error "tmux is not installed"
        echo "macOS: brew install tmux"
        echo "Ubuntu: sudo apt install tmux"
        exit 1
    fi

    # gh CLI check
    if ! command -v gh &> /dev/null; then
        log_warning "GitHub CLI (gh) is not installed"
        echo "Installation guide: https://cli.github.com/"
        read -p "Continue anyway? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi

    # Claude CLI check
    if ! command -v claude &> /dev/null; then
        log_warning "Claude CLI is not installed"
        echo "Installation guide: https://docs.anthropic.com/en/docs/claude-code"
        read -p "Continue anyway? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi

    log_success "Prerequisites check completed"
}

# Set installation method to remote only
set_installation_method() {
    INSTALL_METHOD="remote"
    log_info "Using remote installation (downloading latest from GitHub)"
}

# Download files from GitHub
download_files() {
    local target_dir="$1"
    local base_url="https://raw.githubusercontent.com/nakamasato/Claude-Code-Communication/main/claude"

    log_info "Downloading files from GitHub..."

    mkdir -p "${target_dir}/instructions"

    # File list to download
    local files=(
        "instructions/issue-manager.md"
        "instructions/worker.md"
        "agent-send.sh"
        "setup.sh"
        "local-verification.md"
        "CLAUDE.md"
    )

    for file in "${files[@]}"; do
        log_info "Downloading: $file"
        curl -sSL "${base_url}/${file}" -o "${target_dir}/${file}"

        # Add execute permission for shell scripts
        if [[ $file == *.sh ]]; then
            chmod +x "${target_dir}/${file}"
        fi
    done

    log_success "Files downloaded successfully"
}


# Generate CLAUDE.md with correct paths
generate_claude_md() {
    log_info "Generating CLAUDE.md with correct paths..."

    cat > "CLAUDE.md" << 'EOF'
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
EOF

    log_success "CLAUDE.md generated successfully"
}

# Update .gitignore
update_gitignore() {
    log_info "Updating .gitignore..."

    local gitignore_entries=(
        "# GitHub Issue Management System"
        "worktree/"
        "tmp/"
        "logs/"
        ""
    )

    local gitignore_file=".gitignore"

    # Create .gitignore if it doesn't exist
    touch "$gitignore_file"

    # Check if entries already exist
    local needs_update=false
    for entry in "${gitignore_entries[@]}"; do
        if [ -n "$entry" ] && ! grep -Fxq "$entry" "$gitignore_file"; then
            needs_update=true
            break
        fi
    done

    if [ "$needs_update" = true ]; then
        echo "" >> "$gitignore_file"
        for entry in "${gitignore_entries[@]}"; do
            echo "$entry" >> "$gitignore_file"
        done
        log_success ".gitignore updated"
    else
        log_info ".gitignore already up to date"
    fi
}

# Main installation process
install_system() {
    local target_dir="claude"

    # Check if target directory exists
    if [ -d "$target_dir" ]; then
        log_warning "Directory 'claude' already exists"
        read -p "Overwrite existing installation? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_info "Installation cancelled"
            exit 0
        fi
        rm -rf "$target_dir"
    fi

    # Create target directory
    mkdir -p "$target_dir"

    # Download files from GitHub
    download_files "$target_dir"

    # Generate CLAUDE.md
    generate_claude_md

    # Update .gitignore
    update_gitignore

    log_success "GitHub Issue Management System installed successfully!"
}

# Display post-installation instructions
show_post_install_instructions() {
    echo ""
    echo "🎉 Installation Complete!"
    echo "======================="
    echo ""
    echo "📁 Files installed in: ./claude/"
    echo "📄 Main configuration: ./CLAUDE.md"
    echo ""
    echo "📋 Next steps:"
    echo ""
    echo "1. 🔧 Setup tmux environment:"
    echo "   ./claude/setup.sh"
    echo ""
    echo "2. 🚀 Start Claude Code with:"
    echo "   claude"
    echo ""
    echo "3. 📊 Monitor GitHub Issues:"
    echo "   The issue-manager agent will help you manage GitHub Issues automatically"
    echo ""
    echo "📚 Documentation:"
    echo "   https://github.com/nakamasato/Claude-Code-Communication/blob/main/INSTALLATION.md"
    echo ""
    echo "✨ The system is ready to use!"
}

# Main execution
main() {
    check_prerequisites
    set_installation_method
    install_system
    show_post_install_instructions
}

# Run the script
main "$@"
