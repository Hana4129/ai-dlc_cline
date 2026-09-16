# ai-dlc — AI-Driven Loop Cycle エンジニアリング

Cline を使った **ループエンジニアリング**のための汎用ルールセット・スクリプト集です。
各プロジェクトにサブモジュールとして取り込んで使用します。

---

## 概要

AI-DLC は「計画 → 実装 → 検証 → 振り返り」の1サイクル（ループ）を
Cline（AIエージェント）が自律的に回すためのフレームワークです。

```
計画 ──→ 実装 ──→ 検証
  ↑                  │
  └──── 振り返り ←───┘
```

- **汎用ルール**: どのプロジェクトでも使える `.clinerules/` ファイル群
- **ループスクリプト**: 開始・終了の記録を自動化する Shell スクリプト
- **テンプレート**: プロジェクト固有設定・ループログのひな型
- **Plane連携**: タスク開始・終了時にPlaneチケットを自動更新

---

## リポジトリ構成

```
ai-dlc/
├── .clinerules/             # Clineが読む汎用ルールファイル群
│   ├── 00_meta.md           # ループ制御の原則・フェーズ遷移・エスカレーション
│   ├── 01_planning.md       # 計画フェーズ（タスク分解・完了基準定義）
│   ├── 02_implementation.md # 実装フェーズ（最小変更・品質ルール）
│   ├── 03_verification.md   # 検証フェーズ（ビルド・テスト・完了基準照合）
│   ├── 04_reflection.md     # 振り返りフェーズ（loop-log.md への記録）
│   ├── 05_constraints.md    # 制約・境界条件（セキュリティ・本番保護）
│   └── 06_plane.md          # Plane連携ルール（バグ起票・フェーズラベル）
├── dlc-scripts/
│   ├── install.sh           # プロジェクトへの導入スクリプト
│   ├── loop-start.sh        # ループ開始・loop-log.md エントリ作成
│   ├── loop-end.sh          # ループ終了・loop-log.md 更新
│   └── plane/
│       ├── lib.sh           # Plane API共通ライブラリ
│       ├── task-start.sh    # チケット開始更新
│       ├── task-end.sh      # チケット終了更新
│       ├── bug-report.sh    # バグ自動起票
│       ├── hook-pre-task.sh # PreTaskExecフックラッパー
│       └── hook-post-task.sh# PostTaskExecフックラッパー
├── dlc-templates/
│   ├── 99_local.template.md         # プロジェクト固有ルールのテンプレート
│   ├── loop-log.template.md         # loop-log.md のテンプレート
│   ├── .plane-config.template.json  # Plane設定ファイルのひな型
│   └── .plane-config.example.json   # Plane設定ファイルのサンプル
├── dlc-hooks/
│   ├── plane-task-sync.json         # 汎用フック定義
│   └── plane-task-sync.kiro.json    # Kiro/.kiro/hooks/ 用フック定義
└── docs/
    └── how-to-use.md        # 詳細な使い方ガイド
```

---

## クイックスタート

### 1. サブモジュールとして追加

```bash
git submodule add https://github.com/Hana4129/ai-dlc_cline.git ai-dlc
git submodule update --init --recursive
```

### 2. プロジェクトにセットアップ

```bash
# .clinerules/ と loop-log.md を初期化
bash ai-dlc/dlc-scripts/install.sh
```

### 3. プロジェクト固有ルールを編集

```bash
# テンプレートから生成される 99_local.md を編集
vi .clinerules/99_local.md
```

最低限これだけ埋めてください：

```markdown
## ビルド・テストコマンド
\`\`\`bash
npm run build
npm run test -- --run
\`\`\`
```

### 4. ループを開始する

```bash
bash ai-dlc/dlc-scripts/loop-start.sh "認証機能にリフレッシュトークンを追加する"
```

### 5. Cline に指示を出す

Cline のチャットで目標を伝えるだけ。
ルールファイルが自動的にフェーズを制御します。

### 6. ループを終了する

```bash
bash ai-dlc/dlc-scripts/loop-end.sh success \
  "リフレッシュトークンのローテーション実装は思ったより複雑だった" \
  "次はフロントエンド側のトークン更新処理を実装する"
```

---

## Plane 連携のセットアップ

```bash
# 1. 設定ファイルを作成
cp ai-dlc/dlc-templates/.plane-config.template.json .plane-config.json
# → .plane-config.json を編集（apiToken, project.slug を設定）
echo ".plane-config.json" >> .gitignore

# 2. フックを配置（Kiro の場合）
mkdir -p .kiro/hooks
cp ai-dlc/dlc-hooks/plane-task-sync.kiro.json .kiro/hooks/plane-task-sync.json
```

タスク指示に `#<SeqID>` を含めると自動でチケットが更新されます：

```
「#42 ユーザー認証にリフレッシュトークンを追加してください」
```

---

## プロジェクト側のディレクトリ構成

```
my-project/
├── ai-dlc/                  # このリポジトリ（サブモジュール）
├── .clinerules/
│   ├── 00_meta.md           # ai-dlc/.clinerules/ からリンク or コピー
│   ├── 01_planning.md
│   ├── 02_implementation.md
│   ├── 03_verification.md
│   ├── 04_reflection.md
│   ├── 05_constraints.md
│   ├── 06_plane.md
│   └── 99_local.md          # プロジェクト固有ルール（チームが管理）
├── .kiro/hooks/
│   └── plane-task-sync.json # Plane連携フック
├── .plane-config.json       # Plane設定（gitignore済み）
├── loop-log.md              # ループ実行記録（自動追記・削除禁止）
└── ...
```

---

## ルールの上書き方法

`99_local.md` は汎用ルールの後に読まれるため、プロジェクト固有の設定で上書きできます。

```markdown
# 99_local.md — プロジェクト固有ルール

## ビルド・テストコマンド
\`\`\`bash
pnpm build && pnpm test --run
\`\`\`

## プロジェクト固有の制約
- `src/lib/billing/` は変更前にリードに確認する
```

汎用ルール（`00`〜`06`）は **直接編集しない**でください。
`ai-dlc` の更新で上書きされます。

---

## ai-dlc の更新

```bash
cd ai-dlc && git pull origin main && cd ..
git add ai-dlc
git commit -m "chore: update ai-dlc"
```

---

## チームへの展開

新メンバーがリポジトリをクローンしたあと：

```bash
git clone <repo> --recurse-submodules
# または既存のクローンの場合
git submodule update --init --recursive
```

これで `ai-dlc/` サブモジュールが取得されます。

---

## 詳細ドキュメント

→ [docs/how-to-use.md](docs/how-to-use.md)
