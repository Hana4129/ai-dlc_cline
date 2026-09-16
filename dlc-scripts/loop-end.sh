#!/usr/bin/env bash
# loop-end.sh — ループ終了時の記録更新スクリプト
# 使用方法: ./ai-dlc/dlc-scripts/loop-end.sh <ステータス> "<学び>" "<次の引き継ぎ>"
#   ステータス: success | partial | failure

set -euo pipefail

STATUS="${1:-}"
LEARNING="${2:-}"
NEXT_ACTION="${3:-}"
LOG_FILE="${LOOP_LOG_FILE:-loop-log.md}"
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
LOOP_ENV_FILE=".loop-env"

# ----------------------------------------------------------------
# バリデーション
# ----------------------------------------------------------------
if [[ -z "$STATUS" ]]; then
  echo "❌ エラー: ステータスを第1引数で指定してください。"
  echo "   使用方法: $0 <success|partial|failure> \"<学び>\" \"<次の引き継ぎ>\""
  exit 1
fi

case "$STATUS" in
  success)  STATUS_LABEL="✅ 成功" ;;
  partial)  STATUS_LABEL="⚠️ 部分成功" ;;
  failure)  STATUS_LABEL="❌ 失敗" ;;
  *)
    echo "❌ エラー: ステータスは success / partial / failure のいずれかを指定してください。"
    exit 1
    ;;
esac

# ----------------------------------------------------------------
# loop-log.md の存在確認
# ----------------------------------------------------------------
if [[ ! -f "$LOG_FILE" ]]; then
  echo "❌ エラー: $LOG_FILE が見つかりません。loop-start.sh を先に実行してください。"
  exit 1
fi

# ----------------------------------------------------------------
# ループ番号の取得
# ----------------------------------------------------------------
LOOP_NUM=""
if [[ -f "$LOOP_ENV_FILE" ]]; then
  # shellcheck disable=SC1090
  source "$LOOP_ENV_FILE"
fi

if [[ -z "$LOOP_NUM" ]]; then
  LOOP_NUM=$(grep -oP '(?<=## Loop #)\d+' "$LOG_FILE" | tail -1)
fi

# ----------------------------------------------------------------
# loop-log.md の「実行中」エントリを更新
# ----------------------------------------------------------------
# sedでステータス行を置換
if [[ "$(uname)" == "Darwin" ]]; then
  # macOS
  sed -i '' "s/- ステータス: (実行中)/- ステータス: ${STATUS_LABEL}/" "$LOG_FILE"
  sed -i '' "s/- 開始時刻: .*/- 開始時刻: $(grep '開始時刻' "$LOG_FILE" | tail -1 | grep -oP '(?<=開始時刻: ).+')\n- 終了時刻: ${TIMESTAMP}/" "$LOG_FILE"
else
  # Linux / WSL
  sed -i "s/- ステータス: (実行中)/- ステータス: ${STATUS_LABEL}/" "$LOG_FILE"
fi

# 学び・引き継ぎを追記（最後のエントリの該当セクションに）
if [[ -n "$LEARNING" ]]; then
  python3 - "$LOG_FILE" "$LOOP_NUM" "$LEARNING" "$NEXT_ACTION" "$TIMESTAMP" << 'PYEOF'
import sys, re

log_file   = sys.argv[1]
loop_num   = sys.argv[2]
learning   = sys.argv[3]
next_action= sys.argv[4]
timestamp  = sys.argv[5]

with open(log_file, 'r', encoding='utf-8') as f:
    content = f.read()

# 対象ループのブロックを特定して更新
pattern = rf'(## Loop #{loop_num}.*?### 学び・気づき\n)-\n(.*?### 次のループへの引き継ぎ\n)-\n'

replacement = (
    rf'\g<1>- {learning}\n'
    rf'\2- {next_action}\n'
)

new_content = re.sub(pattern, replacement, content, flags=re.DOTALL)

# 終了時刻を追記
new_content = new_content.replace(
    '- 開始時刻:',
    f'- 終了時刻: {timestamp}\n- 開始時刻:'
, 1)

with open(log_file, 'w', encoding='utf-8') as f:
    f.write(new_content)

print("loop-log.md を更新しました。")
PYEOF
fi

# ----------------------------------------------------------------
# .loop-env クリーンアップ
# ----------------------------------------------------------------
if [[ -f "$LOOP_ENV_FILE" ]]; then
  rm "$LOOP_ENV_FILE"
fi

echo "✅ Loop #${LOOP_NUM} を終了しました。"
echo "   ステータス: ${STATUS_LABEL}"
echo "   記録: ${LOG_FILE}"
