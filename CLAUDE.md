# GitHub Issue Management System

## Agent Configuration
- **issue-manager** (multiagent:0.0): GitHub Issue Manager
- **worker1-N** (multiagent:0.1-N): Issue Resolution Workers (N specified in setup.sh, default 3)

## Your Role
- **issue-manager**: @claude/instructions/issue-manager.md
- **worker1-N**: @claude/instructions/worker.md

## Message Sending
```bash
./claude/agent-send.sh [recipient] "[message]"
```

## Basic Flow
GitHub Issues → issue-manager → workers → issue-manager → GitHub PRs

## Worker Safe Environment Flow
1. **issue-manager**: Create worktree directory
2. **issue-manager**: Instruct worker to start Claude in worktree directory
3. **worker**: Safely execute work in isolated worktree environment
4. **worker**: No risk of main branch contamination
