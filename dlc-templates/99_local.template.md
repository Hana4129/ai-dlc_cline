# 99_local.md — プロジェクト固有ルール

<!--
このファイルは ai-dlc の汎用ルール（00_meta 〜 05_constraints）を
上書き・追記するためのプロジェクト固有ルールファイルです。

- このファイルは .clinerules/99_local.md として配置してください
- 汎用ルールと競合する記述は、このファイルの内容が優先されます
- チームで合意した内容のみ記述してください
-->

---

## プロジェクト情報

- **プロジェクト名**: <!-- 例: my-awesome-app -->
- **技術スタック**: <!-- 例: TypeScript, Next.js 14, PostgreSQL -->
- **リポジトリ**: <!-- 例: https://github.com/org/repo -->

---

## ビルド・テストコマンド

<!-- 03_verification.md のフォールバックコマンドを上書きします -->

```bash
# ビルド
# 例: npm run build

# テスト（単体）
# 例: npm run test -- --run

# テスト（E2E）
# 例: npm run test:e2e

# リント
# 例: npm run lint
```

---

## ループの設定

<!-- 00_meta.md の設定を上書きします -->

### ループの粒度
<!-- 1ループで扱う作業量の目安 -->
<!-- 例: PRとして出せる最小単位（1機能・1バグ修正） -->

### ユーザー確認が必要な追加条件
<!-- 汎用ルール以外にユーザー確認が必要なケース -->
<!-- 例: -->
<!-- - DBスキーマ変更を伴う場合 -->
<!-- - 外部APIの呼び出しを新規追加する場合 -->

---

## コーディング規約

<!-- 02_implementation.md の規約を上書き・追記します -->

### 命名規則
<!-- 例: -->
<!-- - 変数・関数: camelCase -->
<!-- - クラス・型: PascalCase -->
<!-- - 定数: UPPER_SNAKE_CASE -->
<!-- - ファイル: kebab-case.ts -->

### ディレクトリ構成の規則
<!-- 例: -->
<!-- - コンポーネント: src/components/<カテゴリ>/<ComponentName>/index.tsx -->
<!-- - API ルート: src/app/api/<リソース>/route.ts -->
<!-- - テスト: <対象ファイルと同ディレクトリ>/<name>.test.ts -->

### インポート順序
<!-- 例: -->
<!-- 1. Node.js 標準モジュール -->
<!-- 2. 外部ライブラリ -->
<!-- 3. 内部モジュール（絶対パス） -->
<!-- 4. 相対パス -->

---

## テスト方針

<!-- 03_verification.md を上書き・追記します -->

### テストを必須とするケース
<!-- 例: -->
<!-- - ビジネスロジックを含む関数 -->
<!-- - バグ修正（再現テストを書いてから修正） -->

### テストを省略できるケース
<!-- 例: -->
<!-- - 純粋なUIコンポーネント（Storybookで確認） -->
<!-- - 設定ファイルの変更 -->

---

## プロジェクト固有の制約

<!-- 05_constraints.md に追加する制約 -->

<!-- 例: -->
<!-- - src/lib/auth/ は変更前に必ずセキュリティレビューを受ける -->
<!-- - prisma/migrations/ は自動生成以外の手動編集禁止 -->
<!-- - 環境変数は必ず .env.example にも追記する -->

---

## 保護ファイル・ディレクトリ

<!-- 05_constraints.md の保護対象に追加 -->

<!-- 例: -->
<!-- - prisma/migrations/  （マイグレーションは自動生成のみ） -->
<!-- - public/             （静的アセットはデザイナーが管理） -->

---

## よく使うコマンド・スニペット

<!-- Clineへのヒントとして記載 -->

<!-- 例: -->
<!-- ### 新しいDBマイグレーションを作成する -->
<!-- ```bash -->
<!-- npx prisma migrate dev --name <migration_name> -->
<!-- ``` -->

<!-- ### 型チェックのみ実行 -->
<!-- ```bash -->
<!-- npx tsc --noEmit -->
<!-- ``` -->

---

## Plane タスク管理連携

<!--
.plane-config.json をプロジェクトルートに配置することで有効になります。
テンプレート: cp ai-dlc/dlc-templates/.plane-config.template.json .plane-config.json
.plane-config.json は機密情報（APIトークン）を含むため .gitignore に追加してください。
-->

### セットアップ状態

- [ ] `.plane-config.json` を配置済み
- [ ] `plane.apiToken` を設定済み
- [ ] `project.slug` を設定済み（Plane上のプロジェクトスラッグ）
- [ ] `.kiro/hooks/plane-task-sync.json` を配置済み
- [ ] Plane上に以下のラベルを作成済み:
  - `phase:planning`
  - `phase:implementation`
  - `phase:verification`
  - `phase:reflection`
  - `type:bug`
  - `type:feature`
  - `type:chore`

### このプロジェクトのPlane情報

- **ワークスペース**: `hanaprojjcts`
- **プロジェクトスラッグ**: <!-- 例: my-project -->
- **プロジェクトURL**: `http://localhost/hanaprojjcts/<project-slug>/`

### チケットタイトルの命名規則

Clineがチケットを自動識別するために、タスク指示に `#<SeqID>` を含めてください。

```
# 良い例（ClineがPlaneチケット#42を自動更新する）
「#42 ユーザー認証にリフレッシュトークンを追加してください」

# 悪い例（チケットIDがないためPlane連携がスキップされる）
「ユーザー認証にリフレッシュトークンを追加してください」
```

### バグ起票時のデフォルト設定

<!-- 06_plane.md のバグ優先度の目安をプロジェクトに合わせて上書きできます -->

```bash
# バグ手動起票の例
./ai-dlc/dlc-scripts/plane/bug-report.sh \
  "<バグタイトル>" \
  "<再現手順>" \
  "medium" \
  "<発見元チケットSeqID>"
```
