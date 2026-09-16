#!/usr/bin/env bash
# hook-pre-task.sh — PreTaskExec フックから呼ばれるラッパー
#
# Clineは stdin にタスク情報をJSONで渡す。
# タイトルに "#<数字>" が含まれる場合にPlaneチケットを更新する。

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# .plane-config.json が存在しない場合はスキップ（エラーなし）
if [[ ! -f ".plane-config.json" ]]; then
  exit 0
fi

# stdin のJSONを読み込む
INPUT=$(cat)

# jq でタスクタイトルを抽出
TASK_TITLE=$(echo "$INPUT" | jq -r '.task.title // .title // ""' 2>/dev/null || echo "")

if [[ -z "$TASK_TITLE" ]]; then
  exit 0
fi

# タイトルからチケットSeqIDを抽出: "[#42]" or "#42"
ISSUE_SEQ=$(echo "$TASK_TITLE" | grep -oP '(?<=#)\d+' | head -1 || echo "")

if [[ -z "$ISSUE_SEQ" ]]; then
  # チケットIDがない場合はスキップ
  exit 0
fi

# フェーズの判定
PHASE="planning"
if echo "$TASK_TITLE" | grep -qiP '実装|implement'; then
  PHASE="implementation"
elif echo "$TASK_TITLE" | grep -qiP '検証|verify|test'; then
  PHASE="verification"
elif echo "$TASK_TITLE" | grep -qiP '振り返り|reflect'; then
  PHASE="reflection"
fi

# Plane更新（失敗してもループを止めない）
bash "${SCRIPT_DIR}/task-start.sh" "$ISSUE_SEQ" "$PHASE" || {
  echo "⚠️  [plane hook] task-start.sh が失敗しました。ループは継続します。" >&2
}

exit 0
