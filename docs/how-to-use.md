# AI-DLC 使い方ガイド

## 目次

1. [AI-DLC とは](#ai-dlc-とは)
2. [導入手順](#導入手順)
3. [ループの回し方](#ループの回し方)
4. [Plane連携](#plane連携)
5. [ルールのカスタマイズ](#ルールのカスタマイズ)
6. [ファイル構成リファレンス](#ファイル構成リファレンス)
7. [トラブルシューティング](#トラブルシューティング)

---

## AI-DLC とは

**AI-DLC（AI-Driven Loop Cycle）** は、Cline（AIエージェント）を使って
「計画 → 実装 → 検証 → 振り返り」のループを自律的に回すエンジニアリング手法です。

```
計画 ──→ 実装 ──→ 検証
  ↑                  │
  └──── 振り返り ←───┘
```

各ループは小さく完結し、記録が蓄積されることでチーム全体の知識になります。

---

## 導入手順

### ステップ 1: ai-dlc をサブモジュールとして追加

```bash
# プロジェクトルートで実行
git submodule add https://github.com/<org>/ai-dlc.git ai-dlc
git submodule update --init --recursive
```

または install.sh を使う場合：

```bash
curl -fsSL https://raw.githubusercontent.com/<org>/ai-dlc/main/dlc-scripts/install.sh | bash
```

### ステップ 2: プロジェクト固有ルールを設定

```bash
# テンプレートをコピー
cp ai-dlc/dlc-templates/99_local.template.md .clinerules/99_local.md
```

`.clinerules/99_local.md` を開いて以下を埋める：

- プロジェクト名・技術スタック
- ビルド・テストコマンド
- プロジェクト固有の制約・コーディング規約

### ステップ 3: .clinerules/ の構成を確認

Cline が読む `.clinerules/` ディレクトリは以下の構成になっている必要があります：

```
.clinerules/
├── 00_meta.md           ← ai-dlc/dlc-scripts/install.sh が自動リンクまたはコピー
├── 01_planning.md
├── 02_implementation.md
├── 03_verification.md
├── 04_reflection.md
├── 05_constraints.md
├── 06_plane.md
└── 99_local.md          ← あなたが編集するファイル
```

**サブモジュール方式**の場合、汎用ルールは `ai-dlc/.clinerules/` にあります。
Clineに認識させるため、プロジェクト側の `.clinerules/` にシンボリックリンクまたはコピーを配置してください。

```bash
# シンボリックリンクで参照する例（Linux/macOS）
for f in ai-dlc/.clinerules/0*.md; do
  ln -sf "../../${f}" ".clinerules/$(basename $f)"
done
```

### ステップ 4: コミット

```bash
git add .gitmodules ai-dlc .clinerules/ loop-log.md
git commit -m "chore: add ai-dlc loop engineering setup"
```

### ステップ 5: チームメンバーへの共有

README にサブモジュールの初期化手順を追記してください：

```bash
git clone <repo> --recurse-submodules
# または既存のクローンの場合
git submodule update --init --recursive
```

---

## ループの回し方

### 基本的な流れ

#### 1. ループを開始する

```bash
./ai-dlc/dlc-scripts/loop-start.sh "UserエンティティにアバターURL項目を追加する"
```

このコマンドは `loop-log.md` に新しいエントリを作成します。

#### 2. Cline に指示を出す

Cline のチャットで目標を伝えます。
ルールファイルが読み込まれているので、Cline は自動的に4フェーズを実行します。

```
「UserエンティティにアバターURL項目を追加してください。」
```

Cline は以下の順で動きます：

```
## Loop #N 開始
- 目標: UserエンティティにアバターURL項目を追加する
- フェーズ: 計画

### 計画
- [ ] ステップ1: ...
...

## フェーズ移行: 計画 → 実装
...

## フェーズ移行: 実装 → 検証
...

## フェーズ移行: 検証 → 振り返り
...
```

#### 3. ループを終了する

```bash
./ai-dlc/dlc-scripts/loop-end.sh success \
  "小さいタスクに分解することで迷いなく実装できた" \
  "次はフロントエンドのアバター表示を実装する"
```

### ループのステータス

| ステータス | 意味 |
|---|---|
| `success` | 完了基準をすべて達成した |
| `partial` | 一部達成・残課題あり |
| `failure` | 目標未達成・次ループで再挑戦 |

---

## Plane連携

### セットアップ

```bash
# 1. Plane設定ファイルを作成
cp ai-dlc/dlc-templates/.plane-config.template.json .plane-config.json

# 2. .plane-config.json を編集
#    - plane.apiToken: PlaneのAPIトークン
#    - project.slug: PlaneのプロジェクトURL上のスラッグ
vi .plane-config.json

# 3. .gitignore に追加（トークンを含むため必須）
echo ".plane-config.json" >> .gitignore

# 4. フックを配置（Kiro の場合）
mkdir -p .kiro/hooks
cp ai-dlc/dlc-hooks/plane-task-sync.kiro.json .kiro/hooks/plane-task-sync.json
```

### 動作フロー

```
Clineにタスク指示「#42 ○○を実装して」
         ↓
PreTaskExec フック
→ task-start.sh 42 implementation
→ Planeチケット#42: ステート「In Progress」+ ラベル「phase:implementation」

         ↓ バグ発見 ↓

→ bug-report.sh "バグ名" "説明" high 42
→ 新規バグチケット#XX を自動起票
→ 親チケット#42 にコメント追記

         ↓

PostTaskExec フック
→ task-end.sh 42 success
→ Planeチケット#42: ステート「Done」+ ラベル「phase:reflection」
```

### バグ手動起票

```bash
./ai-dlc/dlc-scripts/plane/bug-report.sh \
  "ユーザー削除後もセッションが残存する" \
  "1. ユーザーを削除 2. 同セッションでAPI呼び出し → 期待:401 / 実際:200" \
  "high" \
  "42"
```

### フェーズラベル一覧

| ラベル | フェーズ |
|---|---|
| `phase:planning` | 計画中 |
| `phase:implementation` | 実装中 |
| `phase:verification` | 検証中 |
| `phase:reflection` | 振り返り中 |
| `type:bug` | バグチケット |

---

## ルールのカスタマイズ

### 上書きの仕組み

Cline はディレクトリ内のMarkdownをファイル名順に読みます。
`99_local.md` が最後に読まれるため、汎用ルールを上書きできます。

```
00_meta.md          ← 最初に読まれる（汎用）
01_planning.md
...
06_plane.md
99_local.md         ← 最後に読まれる（プロジェクト固有・上書き有効）
```

### よくあるカスタマイズ例

**ビルドコマンドの指定:**

```markdown
## ビルド・テストコマンド
\`\`\`bash
npm run build
npm run test -- --run
\`\`\`
```

**追加の制約:**

```markdown
## プロジェクト固有の制約
- `src/lib/payment/` は変更前にリードエンジニアに確認する
- マイグレーションファイルは手動編集禁止
```

---

## ファイル構成リファレンス

| ファイル | 役割 | 編集者 |
|---|---|---|
| `.clinerules/00_meta.md` | ループ制御の原則・フェーズ遷移 | ai-dlc（触らない） |
| `.clinerules/01_planning.md` | 計画フェーズのルール | ai-dlc（触らない） |
| `.clinerules/02_implementation.md` | 実装フェーズのルール | ai-dlc（触らない） |
| `.clinerules/03_verification.md` | 検証フェーズのルール | ai-dlc（触らない） |
| `.clinerules/04_reflection.md` | 振り返りフェーズのルール | ai-dlc（触らない） |
| `.clinerules/05_constraints.md` | 絶対的な制約 | ai-dlc（触らない） |
| `.clinerules/06_plane.md` | Plane連携ルール | ai-dlc（触らない） |
| `.clinerules/99_local.md` | プロジェクト固有ルール（上書き） | **チームが編集** |
| `.plane-config.json` | Plane接続設定（gitignore） | **各自が設定** |
| `loop-log.md` | ループ実行記録 | 自動生成（削除しない） |
| `ai-dlc/` | ai-dlcサブモジュール | ai-dlc側で管理 |

---

## トラブルシューティング

### Clineがルールを読んでくれない

- `.clinerules/` がプロジェクトルートにあるか確認する
- ファイルが `.md` 拡張子であるか確認する
- Clineの設定でカスタムルールディレクトリが有効になっているか確認する

### loop-log.md が更新されない

- `loop-start.sh` を先に実行したか確認する
- スクリプトに実行権限があるか確認する:
  ```bash
  chmod +x ai-dlc/dlc-scripts/*.sh ai-dlc/dlc-scripts/plane/*.sh
  ```

### Plane連携が動かない

```bash
# 設定の確認
source ./ai-dlc/dlc-scripts/plane/lib.sh
plane_load_config && echo "設定OK"
```

- `.plane-config.json` がプロジェクトルートにあるか確認する
- `apiToken` と `project.slug` が正しく設定されているか確認する
- `jq` がインストールされているか確認する: `jq --version`

### サブモジュールが空になっている

```bash
git submodule update --init --recursive
```

### ai-dlc を最新版に更新したい

```bash
cd ai-dlc
git pull origin main
cd ..
git add ai-dlc
git commit -m "chore: update ai-dlc to latest"
```
