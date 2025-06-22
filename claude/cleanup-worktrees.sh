#!/bin/bash

# cleanup-worktrees.sh
# Script to automatically clean up worktrees for closed GitHub issues
#
# Usage:
#   ./claude/cleanup-worktrees.sh [--dry-run] [--help]
#
# Options:
#   --dry-run    Show what would be cleaned up without actually removing anything
#   --help       Show this help message

set -euo pipefail

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default options
DRY_RUN=false
VERBOSE=true
REPO_ROOT=""

# Function to print colored output
print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Function to show usage
show_help() {
    cat << EOF
cleanup-worktrees.sh - Clean up worktrees for closed GitHub issues

USAGE:
    ./claude/cleanup-worktrees.sh [OPTIONS]

OPTIONS:
    --dry-run    Show what would be cleaned up without actually removing anything
    --help       Show this help message

DESCRIPTION:
    This script automatically identifies and removes git worktrees that correspond
    to closed GitHub issues. It scans the worktree/ directory for directories
    following the pattern 'issue-N', checks the status of corresponding GitHub
    issues, and safely removes worktrees for closed issues.

EXAMPLES:
    # Dry run - see what would be cleaned up
    ./claude/cleanup-worktrees.sh --dry-run

    # Actually clean up closed issue worktrees
    ./claude/cleanup-worktrees.sh
EOF
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --help|-h)
            show_help
            exit 0
            ;;
        *)
            print_error "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Function to check if we're in the correct repository root
check_repository_root() {
    # Check if we're in a git repository
    if ! git rev-parse --git-dir &> /dev/null; then
        print_error "This script must be run from within a git repository"
        exit 1
    fi

    # Try to find the repository root
    local repo_root
    repo_root=$(git rev-parse --show-toplevel)

    # If we're in a worktree, get the main repository root
    local git_common_dir
    git_common_dir=$(git rev-parse --git-common-dir)

    # If git-common-dir is not the same as git-dir, we're in a worktree
    if [[ "$git_common_dir" != "$(git rev-parse --git-dir)" ]]; then
        # We're in a worktree, find the main repository root
        repo_root=$(dirname "$git_common_dir")
        print_info "Detected worktree environment, using main repository root: $repo_root"
    fi

    # Check if worktree directory exists relative to repository root
    if [[ ! -d "$repo_root/worktree" ]]; then
        print_warning "No worktree directory found at $repo_root/worktree. Nothing to clean up."
        exit 0
    fi

    # Set global variable for later use
    REPO_ROOT="$repo_root"
}

# Function to check if gh CLI is available and authenticated
check_gh_cli() {
    if ! command -v gh &> /dev/null; then
        print_error "GitHub CLI (gh) is not installed or not in PATH"
        print_error "Please install it from: https://cli.github.com/"
        exit 1
    fi

    # Check if authenticated
    if ! gh auth status &> /dev/null; then
        print_error "GitHub CLI is not authenticated"
        print_error "Please run: gh auth login"
        exit 1
    fi
}

# Function to get issue status from GitHub
get_issue_status() {
    local issue_number="$1"
    local status

    # Try to get issue status, handle errors gracefully
    if status=$(gh issue view "$issue_number" --json state --jq '.state' 2>/dev/null); then
        echo "$status"
    else
        echo "NOT_FOUND"
    fi
}

# Function to extract issue number from worktree directory name
extract_issue_number() {
    local dir_name="$1"
    # Extract number from 'issue-N' pattern
    if [[ $dir_name =~ ^issue-([0-9]+)$ ]]; then
        echo "${BASH_REMATCH[1]}"
    else
        echo ""
    fi
}

# Function to safely remove a worktree
remove_worktree() {
    local worktree_path="$1"
    local issue_number="$2"

    print_info "Removing worktree: $worktree_path"

    if [[ "$DRY_RUN" == "true" ]]; then
        print_warning "[DRY RUN] Would remove worktree: $worktree_path"
        return 0
    fi

    # Try to remove the worktree using git worktree remove
    if git worktree remove "$worktree_path" --force 2>/dev/null; then
        print_success "Successfully removed worktree: $worktree_path"
    else
        print_warning "git worktree remove failed, trying manual cleanup..."

        # Fallback: manual cleanup
        if rm -rf "$worktree_path" 2>/dev/null; then
            print_success "Manually cleaned up directory: $worktree_path"
        else
            print_error "Failed to remove $worktree_path"
            return 1
        fi
    fi

    return 0
}

# Main function
main() {
    local total_worktrees=0
    local removed_worktrees=0
    local errors=0

    print_info "Starting worktree cleanup process..."

    if [[ "$DRY_RUN" == "true" ]]; then
        print_warning "DRY RUN MODE - No actual changes will be made"
    fi

    echo

    # Check prerequisites
    check_repository_root
    check_gh_cli

    # Get list of all worktrees from git
    print_info "Scanning for existing worktrees..."

    # Get worktrees that match the worktree/issue-N pattern
    local worktree_dirs=()

    # Use git worktree list to find issue-related worktrees
    while IFS= read -r line; do
        # Extract path from git worktree list output
        local worktree_path=$(echo "$line" | awk '{print $1}')

        # Check if this is an issue worktree in our worktree directory
        if [[ $worktree_path == */worktree/issue-* ]]; then
            local dir_name=$(basename "$worktree_path")
            worktree_dirs+=("$dir_name:$worktree_path")
        fi
    done < <(git worktree list)

    if [[ ${#worktree_dirs[@]} -eq 0 ]]; then
        print_success "No issue worktrees found to clean up"
        exit 0
    fi

    print_info "Found ${#worktree_dirs[@]} issue worktree(s) to check"
    echo

    # Process each worktree directory
    for entry in "${worktree_dirs[@]}"; do
        local dir_name="${entry%%:*}"
        local worktree_path="${entry##*:}"

        total_worktrees=$((total_worktrees + 1))

        print_info "Checking $dir_name..."

        # Extract issue number
        local issue_number
        issue_number=$(extract_issue_number "$dir_name")

        if [[ -z "$issue_number" ]]; then
            print_warning "Skipping $dir_name - not a valid issue worktree name"
            continue
        fi

        # Check issue status
        print_info "Checking GitHub issue #$issue_number status..."
        local issue_status
        issue_status=$(get_issue_status "$issue_number")

        case "$issue_status" in
            "CLOSED")
                print_info "Issue #$issue_number is CLOSED - marking for removal"
                if remove_worktree "$worktree_path" "$issue_number"; then
                    removed_worktrees=$((removed_worktrees + 1))
                else
                    errors=$((errors + 1))
                fi
                ;;
            "OPEN")
                print_success "Issue #$issue_number is still OPEN - keeping worktree"
                ;;
            "NOT_FOUND")
                print_warning "Issue #$issue_number not found on GitHub - keeping worktree"
                print_warning "  Consider manual review: the issue may have been deleted or moved"
                ;;
            *)
                print_warning "Unknown status '$issue_status' for issue #$issue_number - keeping worktree"
                print_warning "  This may indicate a GitHub API issue or network problem"
                ;;
        esac

        echo
    done

    # Summary
    echo "================== CLEANUP SUMMARY =================="
    print_info "Total worktrees checked: $total_worktrees"

    if [[ "$DRY_RUN" == "true" ]]; then
        print_warning "Worktrees that would be removed: $removed_worktrees"
    else
        print_success "Worktrees successfully removed: $removed_worktrees"
    fi

    if [[ $errors -gt 0 ]]; then
        print_error "Errors encountered: $errors"
    fi

    local kept_worktrees=$((total_worktrees - removed_worktrees - errors))
    print_info "Worktrees kept (open issues): $kept_worktrees"

    if [[ "$DRY_RUN" == "true" && $removed_worktrees -gt 0 ]]; then
        echo
        print_info "To actually perform the cleanup, run:"
        print_info "./claude/cleanup-worktrees.sh"
    fi

    echo "====================================================="
}

# Run main function
main "$@"
