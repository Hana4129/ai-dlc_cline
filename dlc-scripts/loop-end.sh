#!/usr/bin/env bash
# loop-end.sh — ループ終了時の記録更新スクリプト
# 使用方法: ./ai-dlc/dlc-scripts/loop-end.sh <ステータス> "<学び>" "<次の引き継ぎ>"
#   ステータス: success | partial | failure

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/loop-env.sh"

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
  LOOP_NUM=$(loop_env_get LOOP_NUM "$LOOP_ENV_FILE")
fi

if [[ -z "$LOOP_NUM" ]]; then
  LOOP_NUM=$(grep -Eo '^## Loop #[0-9]+' "$LOG_FILE" | tail -1 | sed -E 's/^## Loop #//')
fi

if [[ ! "$LOOP_NUM" =~ ^[0-9]+$ ]]; then
  echo "❌ エラー: 対象のループ番号を特定できません。"
  exit 1
fi

run_python() {
  if command -v python3 >/dev/null 2>&1; then
    python3 "$@"
  elif command -v python >/dev/null 2>&1; then
    python "$@"
  elif command -v py >/dev/null 2>&1; then
    py -3 "$@"
  else
    echo "❌ エラー: Python 3 が必要です（python3, python, または py -3）。" >&2
    return 127
  fi
}

run_python - "$LOG_FILE" "$LOOP_NUM" "$STATUS_LABEL" "$LEARNING" "$NEXT_ACTION" "$TIMESTAMP" << 'PYEOF'
import sys, re

log_file   = sys.argv[1]
loop_num   = sys.argv[2]
status     = sys.argv[3]
learning   = sys.argv[4]
next_action= sys.argv[5]
timestamp  = sys.argv[6]

with open(log_file, 'r', encoding='utf-8') as f:
    content = f.read()

header_pattern = re.compile(rf'(?m)^## Loop #{re.escape(loop_num)}(?=\s|$)')
header_match = header_pattern.search(content)
if not header_match:
    raise SystemExit(f'Loop #{loop_num} が見つかりません。')

block_start = header_match.start()
next_loop = re.search(r'(?m)^## Loop #[0-9]+\b', content[header_match.end():])
block_end = header_match.end() + next_loop.start() if next_loop else len(content)
block = content[block_start:block_end]

block, status_count = re.subn(
    r'(?m)^- ステータス: \(実行中\)$',
    lambda _: f'- ステータス: {status}',
    block,
    count=1,
)
if status_count != 1:
    raise SystemExit(f'Loop #{loop_num} は実行中ではありません。')

block = re.sub(r'(?m)^- 終了時刻: .*\n?', '', block)
block, start_count = re.subn(
    r'(?m)^(- 開始時刻: .*)$',
    lambda match: f'{match.group(1)}\n- 終了時刻: {timestamp}',
    block,
    count=1,
)
if start_count != 1:
    raise SystemExit(f'Loop #{loop_num} の開始時刻が見つかりません。')

def replace_section(text, heading, value, next_heading=None):
    end = rf'(?=^{re.escape(next_heading)}\n)' if next_heading else r'(?=\Z)'
    pattern = re.compile(rf'(?ms)^(?P<header>{re.escape(heading)}\n).*?{end}')
    lines = value.splitlines()
    body = '-\n' if not lines else '- ' + lines[0] + ''.join(f'\n  {line}' for line in lines[1:]) + '\n'
    updated, count = pattern.subn(lambda match: match.group('header') + body + '\n', text, count=1)
    if count != 1:
        raise SystemExit(f'{heading} セクションが見つかりません。')
    return updated

block = replace_section(block, '### 学び・気づき', learning, '### 次のループへの引き継ぎ')
block = replace_section(block, '### 次のループへの引き継ぎ', next_action)
content = content[:block_start] + block + content[block_end:]

with open(log_file, 'w', encoding='utf-8', newline='') as f:
    f.write(content)

print("loop-log.md を更新しました。")
PYEOF

# ----------------------------------------------------------------
# .loop-env クリーンアップ
# ----------------------------------------------------------------
if [[ -f "$LOOP_ENV_FILE" ]]; then
  rm "$LOOP_ENV_FILE"
fi

echo "✅ Loop #${LOOP_NUM} を終了しました。"
echo "   ステータス: ${STATUS_LABEL}"
echo "   記録: ${LOG_FILE}"
