<!-- skip:true -->
# 🔍 ローカル動作確認チェックリスト

このファイルでは、Pull Request作成後のローカル動作確認で実施するチェック項目を定義します。
Issue Managerがlocal_verification関数を実行する際に、このファイルの内容に基づいて確認を行います。

## 基本チェック項目

<markdownでチェックリストを作成することでlocal verificationが実行されるようになります>

## 環境セットアップ手順

### 1. 開発環境準備
```bash
# ブランチに移動（Issue Managerが自動実行）
mkdir -p worktree
git worktree add worktree/issue-{issue_number} -b issue-{issue_number}
cd worktree/issue-{issue_number}

# 依存関係インストール
npm install
# または yarn install
# または pip install -r requirements.txt
```

### 2. サーバー起動
```bash
# 開発サーバー起動
npm run dev
# または npm start
# または yarn dev
# または python manage.py runserver
# または python app.py

# バックグラウンド起動の場合
npm run dev &
SERVER_PID=$!
```

### 3. アクセス方法
```bash
# ブラウザを開く（macOS）
open http://localhost:3000

# ブラウザを開く（Linux）
xdg-open http://localhost:3000

# 手動でブラウザを開く
# http://localhost:3000
# http://localhost:8000
# http://localhost:5000
```

### 4. 確認完了後のクリーンアップ
```bash
# サーバー停止
kill $SERVER_PID
# または Ctrl+C

# テスト用データのクリーンアップ（必要に応じて）
npm run db:reset
```

## 確認手順メモ

### 確認環境
- ブラウザ: Chrome, Firefox, Safari
- デバイス: PC, タブレット, スマートフォン
- OS: macOS, Windows, Linux

### 確認すべきURL・画面
- トップページ: http://localhost:3000/
- [その他のページを追記してください]

### テスト用データ
- テストユーザー: [テストアカウント情報]
- テストデータ: [必要なデータセット]

## 注意事項

### Local Verification実行条件
- ✅ このファイルが存在する
- ✅ 第一行目が `<!-- skip:true -->` でない

### Local Verificationをスキップする方法
```markdown
<!-- skip:true -->
```
ファイルの第一行目に上記コメントを追加すると、local verificationがスキップされます。

### その他の注意事項
- チェック項目はプロジェクトの特性に応じてカスタマイズしてください
- 新機能追加時は、関連するチェック項目を追加してください
- local verificationを一時的に無効にしたい場合は `<!-- skip:true -->` を使用
- 完全に無効にしたい場合はファイルを削除してください

---

**使用方法**:
1. プロジェクトに応じてチェック項目をカスタマイズ
2. Issue Manager が PR 作成後に自動でローカル確認を実施
3. 確認結果を GitHub Issue にコメントとして記録
