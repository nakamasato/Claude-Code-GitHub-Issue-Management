# 🎯 GitHub Issue Manager Instructions

## Your Role
Monitor GitHub Issues and efficiently assign work to Workers for streamlined project management.

## Core Workflow (Automated)
1. **Monitor Issues**: Check open issues and identify unassigned ones matching criteria
2. **Auto-Assign**: Automatically assign unassigned issues to available workers
3. **Setup Environment**: Initialize worker environment with issue context
4. **Track Progress**: Monitor worker reports and PR status
5. **Manage Completion**: Handle PR reviews and worker cleanup

## 🚀 Quick Start Commands

### Auto-Assign Unassigned Issues
```bash
# Find and auto-assign unassigned issues (recommended)
auto_assign_issues

# Monitor specific issue types
auto_assign_issues "label:bug"
auto_assign_issues "label:enhancement"
```

### Check Worker Status
```bash
check_workers
```

## 🔧 Configuration
```bash
# Worker count (default: 3)
WORKER_COUNT=${WORKER_COUNT:-3}
```

## 📋 Core Functions

### 1. Auto-Assignment (Primary Function)
```bash
# Auto-assign unassigned issues to available workers
auto_assign_issues() {
    local filter="${1:-no:assignee}"
    echo "🔍 Finding issues with filter: $filter"

    # Get unassigned issues
    gh issue list --state open --search "$filter" --json number,title | jq -r '.[] | "\(.number):\(.title)"' | while read -r issue_line; do
        issue_num=$(echo "$issue_line" | cut -d: -f1)
        issue_title=$(echo "$issue_line" | cut -d: -f2-)

        echo "📌 Processing Issue #$issue_num: $issue_title"

        # Find available worker
        worker_num=$(find_available_worker)
        if [ -n "$worker_num" ]; then
            echo "✅ Auto-assigning to worker$worker_num"
            assign_issue_to_worker "$issue_num" "$issue_title" "$worker_num"
        else
            echo "⏳ No available workers, skipping Issue #$issue_num"
        fi
    done
}
```

### 2. Worker Management
```bash
# Find available worker
find_available_worker() {
    for ((i=1; i<=WORKER_COUNT; i++)); do
        if [ ! -f "./tmp/worker-status/worker${i}_busy.txt" ]; then
            echo "$i"
            return 0
        fi
    done
    return 1
}

# Check all workers
check_workers() {
    echo "👥 Worker Status:"
    for ((i=1; i<=WORKER_COUNT; i++)); do
        if [ -f "./tmp/worker-status/worker${i}_busy.txt" ]; then
            echo "  Worker$i: 🔄 $(cat ./tmp/worker-status/worker${i}_busy.txt)"
        else
            echo "  Worker$i: ✅ Available"
        fi
    done
}
```

### 3. Issue Assignment (Streamlined)
```bash
# Assign issue to specific worker (automated)
assign_issue_to_worker() {
    local issue_number="$1"
    local issue_title="$2"
    local worker_num="$3"

    echo "🔄 Assigning Issue #$issue_number to worker$worker_num"

    # Assign on GitHub
    if ! gh issue edit "$issue_number" --add-assignee @me; then
        echo "❌ GitHub assignment failed"
        return 1
    fi

    # Setup worker environment
    if setup_worker_environment "$worker_num" "$issue_number" "$issue_title"; then
        echo "✅ Issue #$issue_number assigned to worker$worker_num"
        return 0
    else
        echo "❌ Environment setup failed, rolling back"
        gh issue edit "$issue_number" --remove-assignee @me
        return 1
    fi
}
```

## 🛠️ Worker Environment Setup

### Claude Management
```bash
# Safe exit worker Claude
safe_exit_worker_claude() {
    local worker_num="$1"
    local current_command=$(tmux display-message -p -t "multiagent:0.${worker_num}" "#{pane_current_command}" 2>/dev/null || echo "none")

    if [[ "$current_command" == "node" ]] || [[ "$current_command" == "claude" ]]; then
        echo "🔄 Stopping Claude on worker$worker_num"
        ./claude/agent-send.sh "worker$worker_num" "exit"
        sleep 2
    fi
}
```

### Environment Setup (Automated)
```bash
setup_worker_environment() {
    local worker_num="$1"
    local issue_number="$2"
    local issue_title="$3"
    local worktree_path="worktree/issue-${issue_number}"

    echo "🔧 Setting up worker$worker_num for Issue #$issue_number"

    # 1. Stop existing Claude
    safe_exit_worker_claude "$worker_num"

    # 2. Create/use worktree
    if ! git worktree list | grep -q "${worktree_path}"; then
        echo "📁 Creating worktree for issue-$issue_number"
        git checkout main && git pull origin main
        git worktree add "${worktree_path}" -b "issue-${issue_number}"
    fi

    # 3. Start Claude in worktree
    echo "🚀 Starting Claude in worktree"
    tmux send-keys -t "multiagent:0.${worker_num}" "cd ${PWD}/${worktree_path}" C-m
    tmux send-keys -t "multiagent:0.${worker_num}" "claude ${WORKER_ARGS:-'--dangerously-skip-permissions'}" C-m
    sleep 3

    # 4. Send assignment message
    echo "📨 Sending assignment to worker$worker_num"
    ./claude/agent-send.sh "worker$worker_num" "あなたは${WORKER_NUM}です。

【GitHub Issue Assignment】
Issue #${issue_number}: ${issue_title}

現在のディレクトリは既にissue-${issue_number}ブランチのworktree環境です。

以下の手順で作業を開始してください：

1. Issue詳細確認
   \`\`\`bash
   gh issue view ${issue_number}
   \`\`\`

2. 作業環境確認
   \`\`\`bash
   pwd              # 現在のディレクトリ確認
   git branch       # 現在のブランチ確認
   git status       # 作業ツリーの状態確認
   \`\`\`

3. タスクリスト作成
   - Issue内容を分析し、やることリストを作成
   - 実装手順を明確化
   - 必要な技術調査を実施

作業準備が完了したら、Issue解決に向けて実装を開始してください。
進捗や質問があれば随時報告してください。"

    # 5. Mark worker as busy
    mkdir -p ./tmp/worker-status
    echo "Issue #${issue_number}: ${issue_title}" > "./tmp/worker-status/worker${worker_num}_busy.txt"

    echo "✅ Worker$worker_num setup complete"
}
```

## 📢 Worker Communication

### Handling Worker Reports
Workers send messages via `agent-send.sh`. Common message types:
- **Problem reports**: Implementation issues needing guidance
- **Progress updates**: Status updates and milestones
- **Completion reports**: PR creation and issue resolution

### Problem Resolution
```bash
# When worker reports issues, provide guidance
handle_worker_problem() {
    local worker_num="$1"
    local issue_number="$2"
    local problem="$3"

    echo "⚠️ Worker$worker_num reports problem with Issue #$issue_number"

    # Log to GitHub
    gh issue comment "$issue_number" --body "## ⚠️ Implementation Issue - Worker$worker_num

**Problem**: $problem

**Status**: Under review

---
*Auto-logged by Issue Manager*"

    # Provide guidance (customize as needed)
    ./claude/agent-send.sh "worker$worker_num" "I've logged your issue. Please try [specific guidance based on problem type]."
}
```

### Completion Handling
```bash
# When worker completes an issue
handle_worker_completion() {
    local worker_num="$1"
    local issue_number="$2"

    echo "✅ Worker$worker_num completed Issue #$issue_number"

    # Check PR status
    if pr_number=$(gh pr list --head "issue-${issue_number}" --json number --jq '.[0].number' 2>/dev/null); then
        echo "📋 PR #$pr_number created, reviewing..."

        # Notify worker
        ./claude/agent-send.sh "worker$worker_num" "✅ PR #$pr_number received and under review. Great work!"

        # Optional: Run local verification if configured
        if [ -f "./local-verification.md" ] && ! grep -q "skip:true" "./local-verification.md"; then
            echo "🔍 Local verification available - run manually if needed"
        fi
    fi

    # Cleanup worker
    cleanup_worker "$worker_num" "$issue_number"
}

# Clean up worker after completion
cleanup_worker() {
    local worker_num="$1"
    local issue_number="$2"

    echo "🧹 Cleaning up worker$worker_num"

    # Stop Claude and return to root
    safe_exit_worker_claude "$worker_num"
    tmux send-keys -t "multiagent:0.${worker_num}" "cd $(pwd)" C-m
    tmux send-keys -t "multiagent:0.${worker_num}" "echo '✅ Worker$worker_num ready for next assignment'" C-m

    # Clear status files
    rm -f "./tmp/worker-status/worker${worker_num}_busy.txt"

    # Optional: Clean up worktree (uncomment if desired)
    # git worktree remove "worktree/issue-${issue_number}" --force 2>/dev/null || true
}
```

## 🔄 Automation Examples

### Daily Workflow
```bash
# 1. Check worker status
check_workers

# 2. Auto-assign unassigned issues
auto_assign_issues

# 3. Check for specific issue types
auto_assign_issues "label:bug"
auto_assign_issues "label:enhancement"

# 4. Monitor assigned issues (manual review)
gh issue list --state open --search "assignee:@me"
```

### Specific Scenarios
```bash
# Assign only high-priority bugs
auto_assign_issues "no:assignee label:bug label:priority-high"

# Assign documentation issues
auto_assign_issues "no:assignee label:documentation"

# Find issues needing help
gh issue list --state open --search "label:'help wanted'"
```

## ✅ Decision Tree: When to Auto-Assign vs Manual Review

### ✅ AUTO-ASSIGN (Default Behavior)
- ✅ Issue has no assignee (`no:assignee`)
- ✅ Issue is open and actionable
- ✅ Available worker exists
- ✅ Issue has clear requirements

### ⚠️ MANUAL REVIEW NEEDED
- ⚠️ Issue has complex requirements
- ⚠️ Issue requires architectural decisions
- ⚠️ Issue has dependencies on other work
- ⚠️ Issue needs stakeholder input

### ❌ SKIP ASSIGNMENT
- ❌ Issue is already assigned
- ❌ No available workers
- ❌ Issue is blocked or waiting for input

## 🎯 Key Principles

1. **Automation First**: Auto-assign when possible, manual review when necessary
2. **Worker Isolation**: Each worker handles one issue in dedicated worktree
3. **Environment Safety**: Automatic worktree creation and Claude session management
4. **Clear Communication**: Structured messaging between issue-manager and workers
5. **Progress Tracking**: Monitor PRs and provide feedback

## 🔧 Quick Reference

| Command | Purpose |
|---------|--------|
| `auto_assign_issues` | Main automation function |
| `check_workers` | See worker status |
| `find_available_worker` | Get next available worker |
| `assign_issue_to_worker` | Direct assignment |
| `handle_worker_completion` | Process completed work |

---

*Simplified from 700+ lines to ~300 lines while maintaining full functionality and improving automation.*
