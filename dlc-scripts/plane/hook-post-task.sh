#!/usr/bin/env bash
# hook-post-task.sh — PostTaskExec フックから呼ばれるラッパー
#
# Clineはタスク完了後にこのスクリプトを呼び出す。
# .loop-env に保存されたチケットIDを使ってPlaneを更新する。

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOOP_ENV_FILE=".loop-env"

# .plane-config.json が存在しない場合はスキップ
if [[ ! -f ".plane-config.json" ]]; then
  exit 0
fi

# stdin のJSONを読み込む
INPUT=$(cat)

# .loop-env からチケットSeqIDを取得
ISSUE_SEQ=""
if [[ -f "$LOOP_ENV_FILE" ]]; then
  ISSUE_SEQ=$(grep -oP '(?<=PLANE_ISSUE_SEQ=)\d+' "$LOOP_ENV_FILE" || echo "")
fi

# .loop-envになければタスク情報から抽出
if [[ -z "$ISSUE_SEQ" ]]; then
  TASK_TITLE=$(echo "$INPUT" | jq -r '.task.title // .title // ""' 2>/dev/null || echo "")
  ISSUE_SEQ=$(echo "$TASK_TITLE" | grep -oP '(?<=#)\d+' | head -1 || echo "")
fi

if [[ -z "$ISSUE_SEQ" ]]; then
  exit 0
fi

# タスクの成否を判定
TASK_STATUS=$(echo "$INPUT" | jq -r '.task.status // .status // "completed"' 2>/dev/null || echo "completed")

case "$TASK_STATUS" in
  completed|done|success) STATUS="success" ;;
  partial|in_progress)    STATUS="partial" ;;
  failed|failure|error)   STATUS="failure" ;;
  *)                      STATUS="success" ;;
esac

# Plane更新（失敗してもループを止めない）
bash "${SCRIPT_DIR}/task-end.sh" "$ISSUE_SEQ" "$STATUS" || {
  echo "⚠️  [plane hook] task-end.sh が失敗しました。ループは継続します。" >&2
}

exit 0
