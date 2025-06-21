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
# 利用可能なWorkerを見つけてIssueをAssign
assign_issue() {
    local issue_number="$1"
    local issue_title="$2"

    # 利用可能なWorkerを探す
    for worker_num in 1 2 3; do
        if [ ! -f ./tmp/worker-status/worker${worker_num}_busy.txt ]; then
            echo "Issue #${issue_number}を@meにAssign"

            # GitHub上で現在ログインしているユーザーにAssign
            gh issue edit $issue_number --add-assignee @me

            # Worker状況ファイル作成
            echo "Issue #${issue_number}: ${issue_title}" > ./tmp/worker-status/worker${worker_num}_busy.txt

            # Workerに作業指示を送信
            setup_worker_environment $worker_num $issue_number "$issue_title"

            break
        fi
    done
}
```

## Worker環境セットアップ
### 1. Worker初期化処理
```bash
setup_worker_environment() {
    local worker_num="$1"
    local issue_number="$2"
    local issue_title="$3"

    # Workerセッションをクリア
    ./agent-send.sh worker${worker_num} "/clear"
    sleep 2

    # Git環境セットアップ指示
    ./agent-send.sh worker${worker_num} "あなたはworker${worker_num}です。

【GitHub Issue Assignment】
Issue #${issue_number}: ${issue_title}

以下の手順で作業環境をセットアップしてください：

1. Git環境の準備
   \`\`\`bash
   mkdir -p worktree

      # 既存のworktreeがあるかチェック
   if [ -d "worktree/issue-${issue_number}" ]; then
     echo "既存のworktree/issue-${issue_number}を使用します"
     cd worktree/issue-${issue_number}
   else
     echo "新しいworktreeを作成します"

     # 最新のorigin/mainから新しいworktreeを作成
     git checkout main
     git pull origin main
     git worktree add worktree/issue-${issue_number} -b issue-${issue_number}
     cd worktree/issue-${issue_number}
   fi
   \`\`\`

2. Issue詳細確認
   \`\`\`bash
   gh issue view ${issue_number}
   \`\`\`

3. タスクリスト作成
   - Issue内容を分析し、やることリストを作成
   - 実装手順を明確化
   - 必要な技術調査を実施

作業準備が完了したら、Issue解決に向けて実装を開始してください。
進捗や質問があれば随時報告してください。"
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
    # ./agent-send.sh worker${worker_num} "課題について以下の解決策を試してください：[具体的な指示]"
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
        ./agent-send.sh worker${worker_num} "PR #${pr_number}を確認しました。

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

    # Worker状況ファイル削除（作業完了）
    rm -f ./tmp/worker-status/worker${worker_num}_busy.txt

    # Worktreeクリーンアップ（必要に応じて）
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

    for worker_num in 1 2 3; do
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
# Worker負荷確認
check_worker_load() {
    echo "=== Worker負荷状況 ==="
    for worker_num in 1 2 3; do
        if [ -f ./tmp/worker-status/worker${worker_num}_busy.txt ]; then
            echo "Worker${worker_num}: 作業中 - $(cat ./tmp/worker-status/worker${worker_num}_busy.txt)"
        else
            echo "Worker${worker_num}: 利用可能"
        fi
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

# 4. 未割り当てのバグを探したい場合
monitor_issues_with_filter "no:assignee label:bug"

# 5. ヘルプが必要なタスクを探したい場合
monitor_issues_with_filter "no:assignee label:\"help wanted\""

# 6. 新機能開発に集中したい場合
monitor_issues_with_filter "no:assignee label:enhancement"

# 7. ドキュメント関連のタスクを探したい場合
monitor_issues_with_filter "no:assignee label:documentation"

# 8. 初心者向けタスクを探したい場合
monitor_issues_with_filter "no:assignee label:\"good first issue\""

# 9. 質問への回答を探したい場合
monitor_issues_with_filter "no:assignee label:question"

# 10. 今週作成されたIssueのみを確認したい場合
monitor_issues_with_filter "created:>$(date -d '1 week ago' '+%Y-%m-%d')"

# 11. 特定のキーワードを含むIssueを確認したい場合
monitor_issues_with_filter "authentication in:title"
monitor_issues_with_filter "API in:body"

# 12. 複数の条件を組み合わせたい場合
monitor_issues_with_filter "no:assignee label:bug label:\"help wanted\""
```

### 定期的な監視スケジュール例
```bash
# 朝の作業開始時：自分の作業進捗確認（デフォルト）
monitor_issues_with_filter ""

# 作業の合間：新しいヘルプ募集タスクをチェック
monitor_issues_with_filter "no:assignee label:\"help wanted\""

# 午前中：バグ修正に集中
monitor_issues_with_filter "no:assignee label:bug"

# 午後：新機能開発
monitor_issues_with_filter "no:assignee label:enhancement"

# 空き時間：ドキュメント作成や質問回答
monitor_issues_with_filter "no:assignee label:documentation"
monitor_issues_with_filter "no:assignee label:question"

# 初心者歓迎のタスクを探すとき
monitor_issues_with_filter "no:assignee label:\"good first issue\""

# 夕方：自分の作業完了状況を再確認
monitor_issues_with_filter "assignee:@me"
```

## 重要なポイント
- 各Workerが同時に1つのIssueのみ処理するよう厳密管理
- GitHub IssueとPRの状況を常に把握
- Worker環境セットアップの自動化
- 進捗の可視化と適切なフィードバック
- 品質確保のためのローカル確認プロセス
- 継続的なIssue監視と効率的な割り当て
- **フィルタ条件を活用した効率的なIssue管理**
