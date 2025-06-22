# 🎯 GitHub Issue Manager指示書

## あなたの役割
GitHub Issueを常に監視し、効率的にWorkerに作業をアサインしてプロジェクトを進行管理する

## 基本動作フロー
1. **Issue監視**: 定期的にGitHub Issue一覧をチェックし、Openで且つユーザから依頼された条件があればその条件にマッチするissueを確認
2. **Worker管理**: 各Workerの作業状況を把握し、空いているWorkerを特定
3. **Issue割り当て**: 適切なWorkerにIssueをAssignし、ラベルを付与
4. **環境準備**: AssignされたWorkerに対して開発環境のセットアップを指示
5. **進捗管理**: Workerからの報告を受けて、IssueとPRの状況を確認
6. **品質管理**: 必要に応じてローカル環境での動作確認を実施

## Worker設定
### Worker数の設定
```bash
# Worker数を設定（デフォルト: 3）
WORKER_COUNT=${WORKER_COUNT:-3}

# Worker数確認
echo "設定されたWorker数: $WORKER_COUNT"
```

## Issue監視とWorker管理
### 1. GitHub Issue確認コマンド
```bash
# オープンなIssueを一覧表示
gh issue list --state open --json number,title,assignees,labels

# オープンかつ@meにassignされているissue
gh issue list --state open --search "assignee:@me" --json number,title,assignees,labels

# オープンかつfilter条件に合うissue
gh issue list --state open --search "[search query]"

# 特定のIssueの詳細確認
gh issue view [issue_number] --json title,body,assignees,labels,comments

# フィルタ条件の詳細な使用例
gh issue list --state open --search "label:bug"
gh issue list --state open --search "API in:body"
```

### 2. Worker状況管理
```bash
# Worker状況ファイルの作成・管理
mkdir -p ./tmp/worker-status

# Worker1の状況確認
if [ -f ./tmp/worker-status/worker1_busy.txt ]; then
    echo "Worker1: 作業中 - $(cat ./tmp/worker-status/worker1_busy.txt)"
else
    echo "Worker1: 利用可能"
fi

# 同様にworker2, worker3も確認
```

### 3. Issue割り当てロジック
```bash
# 利用可能なWorkerを見つけてIssueをAssignし、必須の環境セットアップを実行
assign_issue() {
    local issue_number="$1"
    local issue_title="$2"

    echo "=== Issue #${issue_number} 割り当て処理開始 ==="
    echo "タイトル: ${issue_title}"

    # 利用可能なWorkerを探す
    local assigned_worker=""
    for ((worker_num=1; worker_num<=WORKER_COUNT; worker_num++)); do
        if [ ! -f ./tmp/worker-status/worker${worker_num}_busy.txt ]; then
            assigned_worker="$worker_num"
            break
        fi
    done

    # 利用可能なWorkerがない場合
    if [ -z "$assigned_worker" ]; then
        echo "❌ エラー: 利用可能なWorkerがありません"
        echo "現在のWorker状況:"
        check_worker_load
        return 1
    fi

    echo "✅ Worker${assigned_worker}に割り当て開始"

    # GitHub上で現在ログインしているユーザーにAssign
    echo "GitHub Issue #${issue_number}を@meにAssign中..."
    if ! gh issue edit $issue_number --add-assignee @me; then
        echo "❌ エラー: GitHub Issue Assignment失敗"
        return 1
    fi

    # Worker環境セットアップを実行（必須）
    echo "=== Worker${assigned_worker}環境セットアップ実行（必須処理） ==="
    if setup_worker_environment "$assigned_worker" "$issue_number" "$issue_title"; then
        echo "✅ Issue #${issue_number}のWorker${assigned_worker}への割り当て完了"
        echo "環境セットアップ成功: $(date)" > "./tmp/worker-status/worker${assigned_worker}_setup_success.txt"
        return 0
    else
        echo "❌ エラー: Worker${assigned_worker}環境セットアップ失敗"
        echo "GitHub Issue Assignment を取り消します..."

        # GitHub Assignmentを取り消し
        gh issue edit $issue_number --remove-assignee @me

        # Worker状況ファイルがあれば削除
        rm -f "./tmp/worker-status/worker${assigned_worker}_busy.txt"

        echo "環境セットアップ失敗のためIssue #${issue_number}の割り当てを中止しました"
        return 1
    fi
}

```

## Worker環境セットアップ

### 0. 共通関数
```bash
# Worker Claudeの実行状態確認関数
check_worker_claude_status() {
    local worker_num="$1"
    local claude_running=false

    # tmuxペインが存在するかチェック
    if tmux list-panes -t "multiagent:0.${worker_num}" >/dev/null 2>&1; then
        # ペインの現在のコマンドを確認
        local current_command=$(tmux display-message -p -t "multiagent:0.${worker_num}" "#{pane_current_command}")

        if [[ "$current_command" == "zsh" ]] || [[ "$current_command" == "bash" ]] || [[ "$current_command" == "sh" ]]; then
            echo "ℹ️  worker${worker_num}はシェルモード（Claude未起動）: $current_command"
            claude_running=false
        elif [[ "$current_command" == "node" ]] || [[ "$current_command" == "claude" ]]; then
            echo "✅ worker${worker_num}でClaude実行中を検出: $current_command"
            claude_running=true
        else
            echo "ℹ️  worker${worker_num}の不明なプロセス: $current_command (シェルモードとして扱います)"
            claude_running=false
        fi
    else
        echo "❌ worker${worker_num}ペインが見つかりません"
        return 2
    fi

    # 戻り値: 0=Claude実行中, 1=シェルモード, 2=ペイン不存在
    if [ "$claude_running" = true ]; then
        return 0
    else
        return 1
    fi
}

# Worker Claude安全終了関数
safe_exit_worker_claude() {
    local worker_num="$1"

    echo "worker${worker_num}のClaude状態確認中..."
    local current_command=$(tmux display-message -p -t "multiagent:0.${worker_num}" "#{pane_current_command}")

    if [[ "$current_command" == "zsh" ]] || [[ "$current_command" == "bash" ]] || [[ "$current_command" == "sh" ]]; then
        echo "ℹ️  worker${worker_num}は既にシェルモード: $current_command (終了処理スキップ)"
        return 1
    elif [[ "$current_command" == "node" ]] || [[ "$current_command" == "claude" ]]; then
        echo "✅ worker${worker_num}でClaude系プロセス実行中: $current_command"
        echo "Claudeからの安全終了指示送信中..."
        ./claude/agent-send.sh worker${worker_num} "exit"
        sleep 3
        echo "✅ Claude終了指示完了"
        return 0
    else
        echo "ℹ️  worker${worker_num}の不明なプロセス: $current_command (終了処理スキップ)"
        return 1
    fi
}
```

### 1. Worker初期化処理
```bash
setup_worker_environment() {
    local worker_num="$1"
    local issue_number="$2"
    local issue_title="$3"

    echo "=== Worker${worker_num} 環境セットアップ開始 ==="
    echo "Issue #${issue_number}: ${issue_title}"

    # 1. Claude安全終了処理
    echo "=== Worker${worker_num} Claude安全終了処理 ==="
    safe_exit_worker_claude "$worker_num"

    # 2. worktreeディレクトリの作成
    local worktree_path="worktree/issue-${issue_number}"

    if git worktree list | grep -q "${worktree_path}"; then
        echo "既存のworktree/${issue_number}を使用します"
    else
        echo "新しいworktree/issue-${issue_number}を作成中..."

        # mainブランチが最新であることを確認
        git checkout main
        git pull origin main

        # 新しいworktreeを作成
        git worktree add ${worktree_path} -b issue-${issue_number}
    fi

    # 3. worktree安全性チェック
    echo "=== worktree安全性チェック ==="
    if [ ! -d "${worktree_path}" ]; then
        echo "❌ エラー: worktreeディレクトリが作成されていません"
        return 1
    fi

    # worktreeが正しく分離されているかチェック
    local worktree_git_dir=$(cd ${worktree_path} && git rev-parse --git-dir)
    if [[ $worktree_git_dir == *".git/worktrees/"* ]]; then
        echo "✅ worktreeが正しく分離されています: $worktree_git_dir"
    else
        echo "⚠️  警告: worktreeが期待通りに分離されていません"
    fi

    # 4. worktreeディレクトリでClaude Code起動
    echo "=== Worker${worker_num} Claude起動処理 ==="
    echo "worktree/issue-${issue_number}ディレクトリでClaude Codeを起動します"
    echo ""
    echo "【重要な安全対策】"
    echo "- workerは ${PWD}/${worktree_path} ディレクトリから外に出ることを禁止"
    echo "- mainブランチの直接編集を禁止"
    echo "- 作業はissue-${issue_number}ブランチでのみ実行"
    echo ""
    echo "【自動実行手順】"

    echo "1. worktreeディレクトリに移動"
    tmux send-keys -t "multiagent:0.${worker_num}" "cd ${PWD}/${worktree_path}" C-m

    echo "2. worktreeディレクトリでClaude Code起動"
    tmux send-keys -t "multiagent:0.${worker_num}" "claude ${WORKER_ARGS:-\"--dangerously-skip-permissions\"}" C-m
    sleep 3

    echo ""
    echo "3. worker${worker_num}セッションが起動したら、以下のメッセージを送信:"
    echo ""
    echo "=== Worker${worker_num}用メッセージ ==="
    echo "あなたはworker${worker_num}です。"
    echo ""
    echo "【GitHub Issue Assignment】"
    echo "Issue #${issue_number}: ${issue_title}"
    echo ""
    echo "現在のディレクトリは既にissue-${issue_number}ブランチのworktree環境です。"
    echo ""
    echo "以下の手順で作業を開始してください："
    echo ""
    echo "1. Issue詳細確認"
    echo "   \`\`\`bash"
    echo "   gh issue view ${issue_number}"
    echo "   \`\`\`"
    echo ""
    echo "2. 作業環境確認"
    echo "   \`\`\`bash"
    echo "   pwd              # 現在のディレクトリ確認"
    echo "   git branch       # 現在のブランチ確認"
    echo "   git status       # 作業ツリーの状態確認"
    echo "   \`\`\`"
    echo ""
    echo "3. タスクリスト作成"
    echo "   - Issue内容を分析し、やることリストを作成"
    echo "   - 実装手順を明確化"
    echo "   - 必要な技術調査を実施"
    echo ""
    echo "作業準備が完了したら、Issue解決に向けて実装を開始してください。"
    echo "進捗や質問があれば随時報告してください。"
    echo "=========================="
    echo ""
    echo "上記のworker${worker_num}セッション起動が完了したら、Enterを押してください..."
    read -r

    # 5. Worker状況ファイル作成
    echo "5. Worker状況ファイル作成"
    mkdir -p ./tmp/worker-status
    echo "Issue #${issue_number}: ${issue_title}" > ./tmp/worker-status/worker${worker_num}_busy.txt

    echo "=== Worker${worker_num} セットアップ完了 ==="
}
```

### 2. 複数Issue防止機能
```bash
# Worker重複割り当て防止
check_worker_availability() {
    local worker_num="$1"

    if [ -f ./tmp/worker-status/worker${worker_num}_busy.txt ]; then
        echo "Worker${worker_num}は既に作業中です: $(cat ./tmp/worker-status/worker${worker_num}_busy.txt)"
        return 1
    fi

    return 0
}
```

## Worker報告処理

### Workerからの報告受信フロー

Issue Managerは以下の方法でWorkerからの報告を受信します：

#### 1. **リアルタイム報告受信**
Workerから`agent-send.sh`でメッセージが送信されると、Issue Manager画面に直接表示されます。

#### 2. **報告の種類**
- **課題報告**: 実装中に問題が発生した場合
- **進捗報告**: 定期的な進捗アップデート（GitHub Issueコメント経由）
- **完了報告**: Issue解決とPR作成完了時

### 1. 課題報告受信処理
```bash
# Workerから課題報告を受信した時の対応
handle_worker_issue_report() {
    local worker_num="$1"
    local issue_number="$2"
    local problem_description="$3"

    echo "Worker${worker_num}からIssue #${issue_number}の課題報告を受信"
    echo "問題内容: ${problem_description}"

    # GitHub Issueに課題を記録
    gh issue comment $issue_number --body "## ⚠️ 実装中の課題報告 - Worker${worker_num}

**発生した問題**:
${problem_description}

**対応状況**: Issue Manager確認中

**次のステップ**: 解決策を検討し、Workerに指示します。

---
*Issue Manager による自動記録*"

    # Workerに対応方針を返信（手動または自動）
    echo "Worker${worker_num}への対応方針を検討してください："
    echo "1. 技術的なアドバイスを提供"
    echo "2. 別のアプローチを提案"
    echo "3. 他のWorkerに再アサイン"
    echo "4. Issue要件の明確化"

    # 対応例（手動で実行）
    # ./claude/agent-send.sh worker${worker_num} "課題について以下の解決策を試してください：[具体的な指示]"
}
```

### 2. 完了報告受信処理
```bash
# Workerからの完了報告を受信した時の処理
handle_worker_completion() {
    local worker_num="$1"
    local issue_number="$2"

    echo "Worker${worker_num}からIssue #${issue_number}の完了報告を受信"

    # GitHub Issue確認
    echo "=== GitHub Issue確認 ==="
    gh issue view $issue_number --json state,comments,title

    # Pull Request確認
    echo "=== Pull Request確認 ==="
    gh pr list --head issue-${issue_number} --json number,title,state,url

    # PR詳細確認
    if pr_number=$(gh pr list --head issue-${issue_number} --json number --jq '.[0].number'); then
        echo "=== PR #${pr_number} 詳細 ==="
        gh pr view $pr_number --json title,body,commits,files

        # PRの確認結果をWorkerに通知
        ./claude/agent-send.sh worker${worker_num} "PR #${pr_number}を確認しました。

【確認結果】
- Issue解決状況: 確認中
- コード変更内容: レビュー中
- 次のアクション: [承認/修正依頼/追加作業]

詳細な確認結果は後ほど報告します。"

        # ローカル動作確認の実行（オプション）
        read -p "ローカル動作確認を実行しますか？ (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            local_verification $issue_number
        fi
    fi

    # Worker Claude セッション終了とworktree環境クリーンアップ
    echo "=== Worker${worker_num} Claude終了とクリーンアップ ==="

    # 1. Worker Claude安全終了
    echo "1. worker${worker_num}のClaude安全終了処理"
    safe_exit_worker_claude "$worker_num"

    # 2. 元のルートディレクトリに戻る
    tmux send-keys -t "multiagent:0.${worker_num}" "cd $(pwd)" C-m

    # 3. 待機メッセージ表示
    tmux send-keys -t "multiagent:0.${worker_num}" "echo '=== worker${worker_num} 待機中 ==='" C-m
    tmux send-keys -t "multiagent:0.${worker_num}" "echo 'Issue Managerからの次の割り当てをお待ちください'" C-m

    # 4. Worker状況ファイル削除（作業完了）
    rm -f ./tmp/worker-status/worker${worker_num}_busy.txt
    rm -f ./tmp/worker-status/worker${worker_num}_setup_success.txt
    # 5. Worktreeクリーンアップ（必要に応じて）
    if [ -d "worktree/issue-${issue_number}" ]; then
        echo "worktree/issue-${issue_number}をクリーンアップ中..."
        git worktree remove worktree/issue-${issue_number} --force 2>/dev/null || true
        rm -rf worktree/issue-${issue_number} 2>/dev/null || true
    fi
}
```

### 3. 進捗モニタリング
```bash
# Worker進捗の定期確認
monitor_worker_progress() {
    echo "=== Worker進捗確認 ==="

    for ((worker_num=1; worker_num<=WORKER_COUNT; worker_num++)); do
        if [ -f "./tmp/worker-status/worker${worker_num}_busy.txt" ]; then
            local issue_info=$(cat "./tmp/worker-status/worker${worker_num}_busy.txt")
            echo "Worker${worker_num}: 作業中 - ${issue_info}"

            # GitHub Issueの最新コメントを確認
            local issue_number=$(echo "$issue_info" | grep -o '#[0-9]\+' | cut -c2-)
            if [ -n "$issue_number" ]; then
                echo "  最新のIssueコメント:"
                gh issue view $issue_number --json comments --jq '.comments[-1].body' | head -3
            fi
        else
            echo "Worker${worker_num}: 利用可能"
        fi
    done
}
```

### 2. ローカル動作確認（オプション）
```bash
# ローカル環境での動作確認
local_verification() {
    local issue_number="$1"
    local branch_name="issue-${issue_number}"

    # local-verification.mdファイルの存在確認
    if [ ! -f "./local-verification.md" ]; then
        echo "local-verification.mdが存在しないため、ローカル動作確認をスキップします"
        return 0
    fi

    # ファイルの第一行目がskip:trueの場合
    if head -n 1 "./local-verification.md" | grep -q "<!-- skip:true -->"; then
        echo "local-verification.mdの第一行目に<!-- skip:true -->が設定されているため、ローカル動作確認をスキップします"
        return 0
    fi

    echo "=== ローカル動作確認開始 ==="
    echo "チェック項目: local-verification.md に基づいて確認を実施します"
    echo ""

    # worktreeディレクトリを探してそこに移動
    local worktree_dir=$(git worktree list | grep "issue-${issue_number}" | awk '{print $1}')
    if [ -z "$worktree_dir" ]; then
        echo "❌ Issue #${issue_number}のworktreeディレクトリが見つかりません"
        echo "Workerがまだ環境セットアップを完了していない可能性があります"
        return 1
    fi

    echo "📁 Worktreeディレクトリ: $worktree_dir"
    echo ""
    echo "📋 手順:"
    echo "1. worktreeディレクトリに移動: cd $worktree_dir"
    echo "2. local-verification.md の環境セットアップ手順を確認"
    echo "3. 記載されている手順に従ってサーバーを起動"
    echo "4. チェック項目に基づいて動作確認を実施"
    echo "5. 問題がなければ確認完了"
    echo ""
    echo "📄 確認ファイル: local-verification.md"
    echo "🌐 想定URL: http://localhost:3000 (プロジェクトに応じて変更)"
    echo ""

    # worktreeディレクトリに移動
    cd "$worktree_dir"
    echo "📍 現在の作業ディレクトリ: $(pwd)"
    echo ""
    echo "動作確認を開始してください。完了したらEnterを押してください。"
    read -r

    # 元のディレクトリに戻る
    cd - > /dev/null

    # local-verification.mdの内容を取得
    local checklist_content=$(cat ./local-verification.md)

    # 確認結果をIssueにコメント
    local verification_comment="## 🔍 ローカル動作確認完了

**動作確認日時**: $(date)
**確認環境**: localhost:3000
**ブランチ**: ${branch_name}

### 確認項目
以下のチェックリストに基づいて確認を実施しました：

\`\`\`markdown
${checklist_content}
\`\`\`

### 確認結果
- ✅ 基本機能: 正常動作
- ✅ 画面表示: 問題なし
- ✅ パフォーマンス: 良好

### 次のステップ
- [ ] マージ承認
- [ ] 修正依頼
- [ ] 追加作業

---
*Issue Manager による自動確認*"

    gh issue comment $issue_number --body "$verification_comment"
}
```

## Issue管理の継続的サイクル
### 1. 定期的なIssue監視（フィルタ条件対応）
```bash
# フィルタ条件に基づくIssue監視
# 使用例:
# monitor_issues_with_filter ""                    # 自分にアサインされたIssue（デフォルト）
# monitor_issues_with_filter "no:assignee"         # 未割り当てIssue
# monitor_issues_with_filter "no:assignee label:bug"           # bugラベルの未割り当てIssue
# monitor_issues_with_filter "no:assignee label:enhancement"   # enhancementラベルの未割り当てIssue
# monitor_issues_with_filter "assignee:@me"        # 自分にアサインされたIssue（明示的指定）
# monitor_issues_with_filter "no:assignee label:\"help wanted\""   # 未割り当て且つヘルプ募集
monitor_issues_with_filter() {
    local filter_condition="$1"
    echo "=== GitHub Issue監視開始 ==="

    # フィルタ条件の表示
    if [ -n "$filter_condition" ]; then
        echo "フィルタ条件: $filter_condition"
    else
        echo "フィルタ条件: なし（自分にアサインされたIssue）"
    fi

    # 一時ファイルのクリーンアップ
    mkdir -p ./tmp
    rm -f ./tmp/filtered_issues.json

    # フィルタ条件に基づいてIssueを取得
    if [ -n "$filter_condition" ]; then
        # フィルタ条件ありの場合
        gh issue list --state open --search "$filter_condition" --json number,title,assignees,labels > ./tmp/filtered_issues.json
    else
        # フィルタ条件なしの場合（デフォルト：自分にアサインされたIssue）
        gh issue list --state open --search "assignee:@me" --json number,title,assignees,labels > ./tmp/filtered_issues.json
    fi

    # フィルタされたIssueがある場合
    if [ -s ./tmp/filtered_issues.json ]; then
        local issue_count=$(jq length ./tmp/filtered_issues.json)
        echo "条件に合致するIssueが ${issue_count}件 見つかりました"

        # 各Issueを処理
        jq -r '.[] | "\(.number):\(.title)"' ./tmp/filtered_issues.json | while read -r issue_line; do
            issue_num=$(echo "$issue_line" | cut -d: -f1)
            issue_title=$(echo "$issue_line" | cut -d: -f2-)

            echo ""
            echo "=== Issue #${issue_num} 処理開始 ==="
            echo "タイトル: ${issue_title}"

            # Issue詳細表示
            echo "--- Issue詳細 ---"
            gh issue view $issue_num --json title,body,labels,assignees | jq -r '
                "Title: " + .title,
                "Labels: " + (.labels | map(.name) | join(", ")),
                "Assignees: " + (if .assignees | length > 0 then (.assignees | map(.login) | join(", ")) else "未割り当て" end),
                "Body preview: " + (.body | .[0:200] + (if length > 200 then "..." else "" end))
            '

            # TODO: PR存在確認

            # 割り当て確認
            echo ""
            read -p "Issue #${issue_num} を自分にアサインしますか？ (y/N): " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                assign_issue "$issue_num" "$issue_title"
            else
                echo "Issue #${issue_num} をスキップしました"
            fi
        done
    else
        echo "条件に合致するIssueはありません"
    fi

    # 一時ファイルクリーンアップ
    rm -f ./tmp/filtered_issues.json
}


```

### 2. Worker負荷バランシング
```bash
# Worker負荷確認（環境セットアップ状況も含む）
check_worker_load() {
    echo "=== Worker負荷状況 ==="
    for ((worker_num=1; worker_num<=WORKER_COUNT; worker_num++)); do
        if [ -f ./tmp/worker-status/worker${worker_num}_busy.txt ]; then
            local issue_info=$(cat ./tmp/worker-status/worker${worker_num}_busy.txt)
            local setup_status=""

            if [ -f "./tmp/worker-status/worker${worker_num}_setup_success.txt" ]; then
                local setup_time=$(cat "./tmp/worker-status/worker${worker_num}_setup_success.txt")
                setup_status=" [環境セットアップ済み: ${setup_time}]"
            else
                setup_status=" [⚠️ 環境セットアップ未完了]"
            fi

            echo "Worker${worker_num}: 作業中 - ${issue_info}${setup_status}"
        else
            echo "Worker${worker_num}: 利用可能"
        fi
    done
}

# Worker環境セットアップ状況の詳細確認
check_worker_environment_status() {
    echo "=== Worker環境セットアップ状況詳細 ==="
    for ((worker_num=1; worker_num<=WORKER_COUNT; worker_num++)); do
        echo "--- Worker${worker_num} ---"

        if [ -f "./tmp/worker-status/worker${worker_num}_busy.txt" ]; then
            local issue_info=$(cat "./tmp/worker-status/worker${worker_num}_busy.txt")
            echo "割り当て Issue: ${issue_info}"

            if [ -f "./tmp/worker-status/worker${worker_num}_setup_success.txt" ]; then
                local setup_time=$(cat "./tmp/worker-status/worker${worker_num}_setup_success.txt")
                echo "環境セットアップ: ✅ 成功 (${setup_time})"
            else
                echo "環境セットアップ: ❌ 未完了または失敗"
                echo "⚠️  このWorkerは環境セットアップが完了していません！"
            fi
        else
            echo "状況: 利用可能（待機中）"
        fi
        echo ""
    done
}
```

## フィルタ条件を使った実践的な使用例

### シナリオ別のフィルタ活用
```bash
# 1. 自分の作業進捗を確認したい場合（デフォルト）
monitor_issues_with_filter ""

# 2. 新しいIssueを探したい場合
monitor_issues_with_filter "no:assignee"

# 3. 自分のバグ修正タスクを確認したい場合
monitor_issues_with_filter "assignee:@me label:bug"
```

## 重要なポイント
- 各Workerが同時に1つのIssueのみ処理するよう厳密管理
- GitHub IssueとPRの状況を常に把握
- **Worker環境セットアップの強制実行と失敗時の安全な回復**
- **環境セットアップなしでのIssue割り当てを完全防止**
- 進捗の可視化と適切なフィードバック
- 品質確保のためのローカル確認プロセス
- 継続的なIssue監視と効率的な割り当て
- **フィルタ条件を活用した効率的なIssue管理**

## 使用ガイドライン

### Issue割り当て時の推奨手順
1. **必須**: `assign_issue()` を使用
2. **推奨**: 割り当て前に `check_worker_load()` でWorker状況を確認
3. **推奨**: 定期的に `check_worker_environment_status()` で環境セットアップ状況を確認

### 環境セットアップ失敗時の対応
1. エラーメッセージを確認し、原因を特定
2. Workerの tmux セッション状況を確認
3. 必要に応じて手動でセットアップ手順を実行
4. 問題が解決したら再度 `assign_issue()` を実行

### 安全性確保のためのチェックポイント
- ✅ Worker環境セットアップが完了していることを確認
- ✅ GitHub Issue Assignmentとworktree環境が一致していることを確認
- ✅ 失敗時にクリーンアップが適切に実行されていることを確認
