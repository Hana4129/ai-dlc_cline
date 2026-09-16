#!/usr/bin/env bash
# task-start.sh — ループ開始時にPlaneチケットを更新するスクリプト
#
# Clineの PreTaskExec フックから呼び出される
#
# 使用方法:
#   ./ai-dlc/dlc-scripts/plane/task-start.sh <issue_sequence_id> <phase>
#   ./ai-dlc/dlc-scripts/plane/task-start.sh 42 planning
#
# 引数:
#   issue_sequence_id : PlaneチケットのシーケンスID（URLに表示される番号）
#   phase             : 開始フェーズ（planning|implementation|verification|reflection）

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib.sh"

ISSUE_SEQ="${1:-}"
PHASE="${2:-planning}"
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
LOOP_ENV_FILE=".loop-env"

# ----------------------------------------------------------------
# バリデーション
# ----------------------------------------------------------------
if [[ -z "$ISSUE_SEQ" ]]; then
  plane_error "チケットIDを第1引数で指定してください。"
  plane_error "使用方法: $0 <issue_sequence_id> [phase]"
  exit 1
fi

# ----------------------------------------------------------------
# 設定読み込み
# ----------------------------------------------------------------
plane_load_config || exit 1

# ----------------------------------------------------------------
# チケットIDの解決
# ----------------------------------------------------------------
ISSUE_ID=$(plane_get_issue_id "$ISSUE_SEQ")
if [[ -z "$ISSUE_ID" ]]; then
  plane_error "チケット #${ISSUE_SEQ} が見つかりません。"
  exit 1
fi

plane_info "チケット #${ISSUE_SEQ} の処理を開始します..."

# ----------------------------------------------------------------
# ステートを「In Progress」に更新
# ----------------------------------------------------------------
plane_set_issue_state "$ISSUE_ID" "$PLANE_STATE_IN_PROGRESS"

# ----------------------------------------------------------------
# フェーズラベルを設定
# ----------------------------------------------------------------
plane_set_phase_label "$ISSUE_ID" "$PHASE"

# ----------------------------------------------------------------
# 開始コメントを追加
# ----------------------------------------------------------------
# ループ番号の取得（loop-log.md から）
LOOP_NUM=""
if [[ -f ".loop-env" ]]; then
  # shellcheck disable=SC1090
  source ".loop-env" 2>/dev/null || true
fi
if [[ -z "${LOOP_NUM:-}" && -f "loop-log.md" ]]; then
  LOOP_NUM=$(grep -oP '(?<=## Loop #)\d+' "loop-log.md" | tail -1)
fi

COMMENT="🚀 Loop ${LOOP_NUM:+#${LOOP_NUM} }開始: フェーズ [${PHASE}] | ${TIMESTAMP}"
plane_add_comment "$ISSUE_ID" "$COMMENT"

# ----------------------------------------------------------------
# .loop-env にチケット情報を追記
# ----------------------------------------------------------------
if [[ -f "$LOOP_ENV_FILE" ]]; then
  echo "PLANE_ISSUE_SEQ=${ISSUE_SEQ}" >> "$LOOP_ENV_FILE"
  echo "PLANE_ISSUE_ID=${ISSUE_ID}" >> "$LOOP_ENV_FILE"
  echo "PLANE_CURRENT_PHASE=${PHASE}" >> "$LOOP_ENV_FILE"
fi

plane_success "チケット #${ISSUE_SEQ} をフェーズ [${PHASE}] で開始しました。"
echo "   URL: ${PLANE_BASE_URL}/${PLANE_WORKSPACE}/projects/${PLANE_PROJECT_SLUG}/issues/${ISSUE_SEQ}/"
