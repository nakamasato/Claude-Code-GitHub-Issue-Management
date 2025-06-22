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

# Select installation method
select_installation_method() {
    echo ""
    echo "📦 Select installation method:"
    echo "1) Local files (use files from current repository)"
    echo "2) Remote download (download latest from GitHub)"
    echo ""

    while true; do
        read -p "Choice (1-2): " choice
        case $choice in
            1)
                INSTALL_METHOD="local"
                log_info "Local installation selected"
                break
                ;;
            2)
                INSTALL_METHOD="remote"
                log_info "Remote installation selected"
                break
                ;;
            *)
                echo "Please select 1 or 2"
                ;;
        esac
    done
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

# Copy files from local repository
copy_local_files() {
    local target_dir="$1"
    local source_dir="claude"

    log_info "Copying files from local repository..."

    # Check if claude directory exists
    if [ ! -d "$source_dir" ]; then
        log_error "Local 'claude' directory not found"
        echo "Please ensure you're running this script from the repository root"
        exit 1
    fi

    # Use rsync if available, otherwise use tar
    if command -v rsync &> /dev/null; then
        rsync -av "${source_dir}/" "${target_dir}/"
    else
        # Use tar for reliable copying
        (cd "$source_dir" && tar cf - .) | (mkdir -p "$target_dir" && cd "$target_dir" && tar xf -)
    fi

    # Ensure shell scripts are executable
    chmod +x "${target_dir}/agent-send.sh" "${target_dir}/setup.sh" 2>/dev/null || true

    log_success "Local files copied successfully"
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

    # Install files based on selected method
    case $INSTALL_METHOD in
        "local")
            copy_local_files "$target_dir"
            ;;
        "remote")
            download_files "$target_dir"
            ;;
    esac

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
    select_installation_method
    install_system
    show_post_install_instructions
}

# Run the script
main "$@"
