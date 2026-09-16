#!/usr/bin/env bash
# task-end.sh — ループ終了時にPlaneチケットを更新するスクリプト
#
# Clineの PostTaskExec フックから呼び出される
#
# 使用方法:
#   ./ai-dlc/dlc-scripts/plane/task-end.sh <issue_sequence_id> <status> [next_phase]
#   ./ai-dlc/dlc-scripts/plane/task-end.sh 42 success
#   ./ai-dlc/dlc-scripts/plane/task-end.sh 42 partial implementation
#
# 引数:
#   issue_sequence_id : PlaneチケットのシーケンスID
#   status            : ループ結果（success|partial|failure）
#   next_phase        : 次のフェーズ（省略時はreflection）

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib.sh"

ISSUE_SEQ="${1:-}"
STATUS="${2:-}"
NEXT_PHASE="${3:-reflection}"
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
LOOP_ENV_FILE=".loop-env"

# ----------------------------------------------------------------
# バリデーション
# ----------------------------------------------------------------
if [[ -z "$ISSUE_SEQ" || -z "$STATUS" ]]; then
  plane_error "引数が不足しています。"
  plane_error "使用方法: $0 <issue_sequence_id> <success|partial|failure> [next_phase]"
  exit 1
fi

case "$STATUS" in
  success)  STATUS_LABEL="✅ 成功" ;;
  partial)  STATUS_LABEL="⚠️ 部分成功" ;;
  failure)  STATUS_LABEL="❌ 失敗" ;;
  *)
    plane_error "ステータスは success / partial / failure のいずれかを指定してください。"
    exit 1
    ;;
esac

# ----------------------------------------------------------------
# 設定読み込み
# ----------------------------------------------------------------
plane_load_config || exit 1

# ----------------------------------------------------------------
# チケットIDの解決（.loop-envがあれば優先使用）
# ----------------------------------------------------------------
ISSUE_ID=""
if [[ -f "$LOOP_ENV_FILE" ]]; then
  # shellcheck disable=SC1090
  source "$LOOP_ENV_FILE" 2>/dev/null || true
  ISSUE_ID="${PLANE_ISSUE_ID:-}"
fi

if [[ -z "$ISSUE_ID" ]]; then
  ISSUE_ID=$(plane_get_issue_id "$ISSUE_SEQ")
fi

if [[ -z "$ISSUE_ID" ]]; then
  plane_error "チケット #${ISSUE_SEQ} が見つかりません。"
  exit 1
fi

plane_info "チケット #${ISSUE_SEQ} の終了処理を開始します..."

# ----------------------------------------------------------------
# ステータスに応じてPlaneを更新
# ----------------------------------------------------------------
case "$STATUS" in
  success)
    # 完了: ステートをDoneに、フェーズをreflectionに
    plane_set_issue_state "$ISSUE_ID" "$PLANE_STATE_DONE"
    plane_set_phase_label "$ISSUE_ID" "reflection"
    ;;
  partial)
    # 部分完了: ステートはIn Progressのまま、次フェーズラベルを設定
    plane_set_phase_label "$ISSUE_ID" "$NEXT_PHASE"
    ;;
  failure)
    # 失敗: ステートをTodoに戻し、planningラベルを設定
    plane_set_issue_state "$ISSUE_ID" "$PLANE_STATE_DEFAULT"
    plane_set_phase_label "$ISSUE_ID" "planning"
    ;;
esac

# ----------------------------------------------------------------
# 終了コメントを追加
# ----------------------------------------------------------------
LOOP_NUM="${LOOP_NUM:-}"
if [[ -z "$LOOP_NUM" && -f "loop-log.md" ]]; then
  LOOP_NUM=$(grep -oP '(?<=## Loop #)\d+' "loop-log.md" | tail -1)
fi

COMMENT="🏁 Loop ${LOOP_NUM:+#${LOOP_NUM} }終了: ${STATUS_LABEL} | フェーズ [${NEXT_PHASE}] | ${TIMESTAMP}"
plane_add_comment "$ISSUE_ID" "$COMMENT"

# ----------------------------------------------------------------
# 完了の場合: loop-log の最新エントリのURLをコメント追記
# ----------------------------------------------------------------
if [[ "$STATUS" == "success" && -f "loop-log.md" ]]; then
  ISSUE_URL="${PLANE_BASE_URL}/${PLANE_WORKSPACE}/projects/${PLANE_PROJECT_SLUG}/issues/${ISSUE_SEQ}/"
  plane_info "チケットURL: ${ISSUE_URL}"
fi

plane_success "チケット #${ISSUE_SEQ} を ${STATUS_LABEL} で更新しました。"
