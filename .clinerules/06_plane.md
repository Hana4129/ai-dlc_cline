# 06_plane.md — Plane タスク管理連携ルール

このルールは Plane（プロジェクト管理ツール）との連携方法を定義します。
`.plane-config.json` が存在するプロジェクトでのみ有効です。

---

## フェーズラベルの運用ルール

各ループのフェーズ移行時に、対応するラベルをPlaneチケットに設定する。

| フェーズ | ラベル | 意味 |
|---|---|---|
| 計画 | `phase:planning` | タスク分解・完了基準の定義中 |
| 実装 | `phase:implementation` | コーディング・変更作業中 |
| 検証 | `phase:verification` | ビルド・テスト・完了基準の照合中 |
| 振り返り | `phase:reflection` | loop-log記録・次ループ計画中 |

### フェーズ移行時の操作

フェーズを移行するときは、必ず以下のスクリプトを実行する：

```bash
# 例: 計画フェーズを開始する
./ai-dlc/scripts/plane/task-start.sh <issue_seq> planning

# 例: 実装フェーズに移行する
./ai-dlc/scripts/plane/task-start.sh <issue_seq> implementation
```

ループ終了時：

```bash
# 成功で終了
./ai-dlc/scripts/plane/task-end.sh <issue_seq> success

# 部分完了（次フェーズを指定）
./ai-dlc/scripts/plane/task-end.sh <issue_seq> partial implementation

# 失敗（計画フェーズに戻る）
./ai-dlc/scripts/plane/task-end.sh <issue_seq> failure
```

---

## バグ検出時の起票ルール

### バグとみなす条件

以下のいずれかに該当する場合、バグチケットを起票する：

- テスト実行中にテストが失敗し、その原因が**既存コードのデグレード**である
- ビルド中に**既存機能の破壊**が確認された
- 実装中に**仕様外の挙動**を発見した（実装しているタスクとは別の問題）
- コードレビュー中に**潜在的なセキュリティ問題**を発見した

### バグとみなさない条件（起票しない）

- 今ループで実装中の機能がまだ動いていない（それは未完成であり、バグではない）
- 設定ミス・環境依存の問題（まず設定を直す）
- テストコード自体の誤り

### バグ起票の手順

バグを発見したら、**実装を止めて**以下を実行する：

```bash
./ai-dlc/scripts/plane/bug-report.sh \
  "<バグのタイトル>" \
  "<再現手順と期待値・実際の挙動>" \
  "<優先度: urgent|high|medium|low>" \
  "<発見元チケットのSeqID（省略可）>"
```

**例：**

```bash
./ai-dlc/scripts/plane/bug-report.sh \
  "ユーザー削除後もセッションが残存する" \
  "1. ユーザーを削除する 2. 同じセッションでAPIを呼ぶ → 期待: 401 / 実際: 200" \
  "high" \
  "42"
```

### バグ起票後の対応

起票後は**現在のループを継続する**。バグ修正は別ループで行う。
ただし以下の場合は現在のループを中断してユーザーに報告する：

- バグが現在のタスクの完了を**物理的にブロック**する
- **セキュリティ上の重大な問題**（認証バイパス、データ漏洩等）

### 優先度の目安

| 優先度 | 基準 |
|---|---|
| `urgent` | 本番障害・セキュリティ脆弱性 |
| `high` | 主要機能が動作しない |
| `medium` | 一部機能に影響するが回避策がある |
| `low` | 軽微な表示崩れ・使い勝手の問題 |

---

## `.plane-config.json` が存在しない場合

`.plane-config.json` がプロジェクトルートに存在しない場合、
Plane連携のスクリプト実行はスキップしてよい。
その場合もloop-log.mdへの記録は通常通り行う。

---

## Plane連携の確認方法

設定が正しいか確認するには：

```bash
# 設定読み込みテスト
source ./ai-dlc/scripts/plane/lib.sh
plane_load_config && echo "設定OK"
```
