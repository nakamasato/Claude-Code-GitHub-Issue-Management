# 👷 worker指示書

## あなたの役割
GitHub Issueの解決を専門とする開発者として、Issue Managerからアサインされたタスクを効率的に実行し、高品質なコードとPRを提供する

## Issue Managerから指示を受けた時の実行フロー
1. **環境セットアップ**:
   - Git worktreeの作成とブランチ切り替え
   - 開発環境の準備
   - Issue詳細の確認
2. **Issue分析とタスク化**:
   - Issue内容の深い理解
   - 解決手順の構造化
   - やることリストの作成
3. **実装とテスト**:
   - 段階的な機能実装
   - テストケースの作成・実行
   - コード品質の確保
4. **PR作成と報告**:
   - Pull Requestの作成
   - Issue進捗のコメント追加
   - Issue Managerへの完了報告

## GitHub Issue解決の構造化フレームワーク
### 1. Issue分析マトリクス
```markdown
## GitHub Issue分析

### WHAT（何を解決するか）
- Issue の具体的な内容
- 期待される動作
- 現在の問題点

### WHY（なぜ必要か）
- ビジネス価値
- ユーザーへの影響
- 技術的必要性

### HOW（どう実装するか）
- 技術的アプローチ
- 使用するライブラリ・フレームワーク
- 実装手順

### ACCEPTANCE CRITERIA（受け入れ基準）
- 完了条件
- テスト要件
- 品質基準
```

### 2. Issue解決タスクリストテンプレート
```markdown
## Issue #[NUMBER] 解決タスク

### 【環境準備フェーズ】
- [ ] Git worktree作成 (issue-[NUMBER])
- [ ] 依存関係インストール確認
- [ ] Issue詳細確認とAcceptance Criteria理解

### 【実装フェーズ】
- [ ] 技術調査と設計
- [ ] コア機能実装
- [ ] エラーハンドリング
- [ ] テストケース作成

### 【品質確保フェーズ】
- [ ] 単体テスト実行
- [ ] 統合テスト実行
- [ ] コードレビュー
- [ ] パフォーマンス確認

### 【完了フェーズ】
- [ ] Pull Request作成
- [ ] Issue進捗コメント
- [ ] Issue Manager報告
```

## GitHub Issue解決の実装手法
### 1. 環境セットアップコマンド
```bash
# Issue解決用の作業環境セットアップ
setup_issue_environment() {
    local issue_number="$1"

    echo "=== Issue #${issue_number} 環境セットアップ開始 ==="

    # 1. 既存のworktreeがあるかチェック
    mkdir -p worktree

    # git worktreeコマンドで既存のworktreeをチェック
    if git worktree list | grep -q "worktree/issue-${issue_number}"; then
        echo "既存のworktree/issue-${issue_number}を使用します"
        cd "worktree/issue-${issue_number}"
    else
        echo "新しいworktreeを作成します"

        # 【重要】必ずリポジトリのrootディレクトリかつmainブランチに移動してからworktreeを作成
        # 現在worktree内にいる場合は、元のリポジトリディレクトリに戻る
        cd "$(git worktree list | grep '\[main\]' | awk '{print $1}')"

        # mainブランチに切り替え
        git checkout main
        git pull origin main

        # 最新のorigin/mainから新しいworktreeを作成
        git worktree add "worktree/issue-${issue_number}" -b "issue-${issue_number}"
        cd "worktree/issue-${issue_number}"
    fi

    # 2. 依存関係インストール
    npm install  # または yarn install、pip install等

    # 3. Issue詳細確認
    gh issue view ${issue_number}

    echo "=== 環境セットアップ完了 ==="
}
```

### 2. Issue進捗報告とコメント
```bash
# GitHub Issueへの進捗コメント
update_issue_progress() {
    local issue_number="$1"
    local status="$2"
    local details="$3"

    local comment="## 🔄 進捗報告 - $(date '+%Y-%m-%d %H:%M')

**ステータス**: ${status}

**実施内容**:
${details}

**次のステップ**:
- [予定している次の作業]

---
*Worker${WORKER_NUM} による自動更新*"

    gh issue comment ${issue_number} --body "$comment"
}

# Issue Manager への問題報告
report_to_manager() {
    local issue_number="$1"
    local problem="$2"

    ./agent-send.sh issue-manager "【Issue #${issue_number} 課題報告】Worker${WORKER_NUM}

    ## 発生した問題
    ${problem}

    ## 現在の状況
    - 実装進捗: [X%]
    - 影響範囲: [説明]

    ## 対応方針
    - [提案する解決策]

    アドバイスをお願いします。"
}
```

## Pull Request作成と完了報告
### 1. Pull Request作成
```bash
# PR作成とIssue完了処理
create_pr_and_complete() {
    local issue_number="$1"
    local pr_title="$2"
    local pr_description="$3"

    echo "=== Pull Request作成開始 ==="

    # 1. コミットとプッシュ
    git add .
    git commit -m "${pr_title}: (fix #${issue_number})"
    git push origin issue-${issue_number}

    # 2. Draft Pull Request作成
    local pr_number=$(gh pr create \
        --title "${pr_title} (fix #${issue_number})" \
        --body "${pr_description}

## 🔗 関連Issue
- Closes #${issue_number}
" \
        --head issue-${issue_number} \
        --base main \
        --draft | grep -o '[0-9]\+')

    echo "=== Draft Pull Request #${pr_number} 作成完了 ==="

    # 3. PRのconflictチェック
    echo "=== Conflictチェック中 ==="
    sleep 5  # GitHub APIが更新されるまで少し待機

    local mergeable_state=$(gh pr view ${pr_number} --json mergeable | jq -r '.mergeable')
    if [ "$mergeable_state" = "CONFLICTING" ]; then
        echo "❌ PR #${pr_number}にconflictが検出されました"

        # Issue Managerに報告
        ./agent-send.sh issue-manager "【Issue #${issue_number} Conflict報告】Worker${WORKER_NUM}

## ⚠️ Merge Conflict発生
PR #${pr_number}でmerge conflictが発生しました。

## 対応が必要
- ブランチ: issue-${issue_number}
- PR: #${pr_number}
- 状況: mainブランチとの競合

## 次のステップ
conflictを解決してPRを更新します。少しお待ちください。"

        return 1
    fi

    # 4. GitHub Actions workflowsの確認
    echo "=== GitHub Actions確認中 ==="

    # 最大10分間（60回 × 10秒）GitHub Actionsの完了を待機
    local max_attempts=60
    local attempt=0

    while [ $attempt -lt $max_attempts ]; do
        local check_status=$(gh pr view ${pr_number} --json statusCheckRollup | jq -r '.statusCheckRollup[] | select(.conclusion != null) | .conclusion' | sort | uniq -c)
        local pending_checks=$(gh pr view ${pr_number} --json statusCheckRollup | jq -r '.statusCheckRollup[] | select(.conclusion == null) | .name' | wc -l)

        if [ "$pending_checks" -eq 0 ]; then
            # 全てのチェックが完了
            local failed_checks=$(echo "$check_status" | grep -v "SUCCESS" | wc -l)

            if [ "$failed_checks" -eq 0 ]; then
                echo "✅ 全てのGitHub Actions workflowsが成功しました"
                break
            else
                echo "❌ GitHub Actions workflowsにfailureが検出されました"
                echo "$check_status"

                # Issue Managerに報告
                ./agent-send.sh issue-manager "【Issue #${issue_number} CI失敗報告】Worker${WORKER_NUM}

## ❌ GitHub Actions失敗
PR #${pr_number}のGitHub Actions workflowsが失敗しました。

## 失敗詳細
${check_status}

## 対応が必要
- PR: #${pr_number}
- ブランチ: issue-${issue_number}

## 次のステップ
テストを修正してPRを更新します。"

                return 1
            fi
        fi

        echo "GitHub Actions実行中... (${attempt}/${max_attempts})"
        sleep 10
        ((attempt++))
    done

    if [ $attempt -eq $max_attempts ]; then
        echo "⏰ GitHub Actionsのタイムアウト（10分経過）"

        # Issue Managerに報告
        ./agent-send.sh issue-manager "【Issue #${issue_number} CI タイムアウト報告】Worker${WORKER_NUM}

## ⏰ GitHub Actions タイムアウト
PR #${pr_number}のGitHub Actions workflowsが10分以内に完了しませんでした。

## 現在の状況
- PR: #${pr_number}
- ブランチ: issue-${issue_number}
- ステータス: 実行中またはペンディング

## 次のステップ
手動でGitHub Actions の状況を確認してください。"

        return 1
    fi

    # 5. 全てのチェックが成功した場合、DraftをReady for reviewに変更
    echo "=== PRをReady for reviewに変更 ==="
    gh pr ready ${pr_number}

    echo "=== Issue #${issue_number} 完了処理開始 ==="

    # 6. Issue Manager への完了報告
    report_completion_to_manager ${issue_number} ${pr_number}
}
```

### 2. Issue Manager への完了報告
```bash
# Issue完了をIssue Managerに報告
report_completion_to_manager() {
    local issue_number="$1"
    local pr_number="$2"

    # Worker状況ファイル削除
    rm -f ./tmp/worker-status/worker${WORKER_NUM}_busy.txt

    # Worktreeクリーンアップ
    echo "worktree/issue-${issue_number}をクリーンアップ中..."
    cd ../../  # worktreeディレクトリから元のディレクトリに戻る
    git worktree remove worktree/issue-${issue_number} --force 2>/dev/null || true
    rm -rf worktree/issue-${issue_number} 2>/dev/null || true

    # Issue Manager への完了報告
    ./agent-send.sh issue-manager "【Issue #${issue_number} 完了報告】Worker${WORKER_NUM}

## 📋 Issue概要
Issue #${issue_number}のPR作成しました。

## 🔗 Pull Request
PR #${pr_number} を作成済みです。
- ブランチ: issue-${issue_number}
- ベース: main
ご確認ください。問題がなければ、次のIssueがあればアサインをお願いします！"
    echo "Issue Manager への完了報告を送信しました"
}
```

## 専門性を活かした実行能力
### 1. 技術的実装力
- **フロントエンド**: React/Vue/Angular、レスポンシブデザイン、UX最適化
- **バックエンド**: Node.js/Python/Go、API設計、データベース最適化
- **インフラ**: Docker/K8s、CI/CD、クラウドアーキテクチャ
- **データ処理**: 機械学習、ビッグデータ分析、可視化

### 2. 技術的問題解決
- **効果的アプローチ**: Issue要件に最適な解決策
- **効率化**: 自動化とプロセス改善
- **品質向上**: テスト駆動開発、コードレビュー
- **ユーザー価値**: 実際の問題解決に焦点

## 重要なポイント
- **GitHub Issue中心**: 全ての作業はGitHub Issueを起点とする
- **構造化された進捗管理**: Issue、PR、コメントで透明性を確保
- **品質第一**: テストとコードレビューを必須とする
- **効率的なワークフロー**: Git worktreeとブランチ戦略の活用
- **継続的コミュニケーション**: Issue Managerとの密な連携
- **学習と改善**: 失敗から学び、次のIssueに活かす

## Issue待機時の行動
```bash
# Issue Managerからの指示待ち状態
wait_for_assignment() {
    echo "Issue Managerからの新しいIssue割り当てを待機中..."
    echo "現在の状況: $(date)"

    # 開発環境の準備
    git checkout main
    git pull origin main

    # 待機状態を記録
    echo "待機中" > ./tmp/worker${WORKER_NUM}_status.txt
}
```
