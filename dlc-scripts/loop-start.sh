#!/usr/bin/env bash
# loop-start.sh — ループ開始時の初期化スクリプト
# 使用方法: ./ai-dlc/dlc-scripts/loop-start.sh "<目標>" [ループ番号]

set -u

GOAL="${1:-}"
LOOP_NUM="${2:-}"
LOG_FILE="${LOOP_LOG_FILE:-loop-log.md}"
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
DATE=$(date '+%Y-%m-%d')

# ----------------------------------------------------------------
# バリデーション
# ----------------------------------------------------------------
if [[ -z "$GOAL" ]]; then
  echo "❌ エラー: 目標を第1引数で指定してください。"
  echo "   使用方法: $0 \"<目標>\" [ループ番号]"
  exit 1
fi

if [[ -n "$LOOP_NUM" && ! "$LOOP_NUM" =~ ^[0-9]+$ ]]; then
  echo "❌ エラー: ループ番号は整数で指定してください。"
  exit 1
fi

# ----------------------------------------------------------------
# ループ番号の自動採番
# ----------------------------------------------------------------
if [[ -z "$LOOP_NUM" ]]; then
  if [[ -f "$LOG_FILE" ]]; then
    LAST_NUM=$(grep -Eo '^## Loop #[0-9]+' "$LOG_FILE" | tail -1 | sed -E 's/^## Loop #//')
    LOOP_NUM=$(( ${LAST_NUM:-0} + 1 ))
  else
    LOOP_NUM=1
  fi
fi

# ----------------------------------------------------------------
# loop-log.md の初期化（存在しない場合）
# ----------------------------------------------------------------
if [[ ! -f "$LOG_FILE" ]]; then
  cat > "$LOG_FILE" << 'EOF'
# Loop Log

このファイルはAI-DLCループエンジニアリングの実行記録です。
自動生成・追記されます。削除・上書きしないでください。

---
EOF
  echo "📄 $LOG_FILE を新規作成しました。"
fi

# ----------------------------------------------------------------
# ループエントリのヘッダーを追記
# ----------------------------------------------------------------
cat >> "$LOG_FILE" << EOF

## Loop #${LOOP_NUM} — ${DATE}

### 目標
${GOAL}

### 結果
- ステータス: (実行中)
- 開始時刻: ${TIMESTAMP}

### 実施内容
- 変更ファイル:
- 主な変更内容:

### 学び・気づき
-

### 次のループへの引き継ぎ
-
EOF

# ----------------------------------------------------------------
# 環境変数ファイルの出力（Clineが参照できるよう）
# ----------------------------------------------------------------
LOOP_ENV_FILE=".loop-env"
printf -v GOAL_ESCAPED '%q' "$GOAL"
printf -v TIMESTAMP_ESCAPED '%q' "$TIMESTAMP"
printf 'LOOP_NUM=%s\nLOOP_GOAL=%s\nLOOP_STARTED_AT=%s\n' \
  "$LOOP_NUM" "$GOAL_ESCAPED" "$TIMESTAMP_ESCAPED" > "$LOOP_ENV_FILE"

echo "✅ Loop #${LOOP_NUM} を開始しました。"
echo "   目標: ${GOAL}"
echo "   記録: ${LOG_FILE}"
