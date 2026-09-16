#!/usr/bin/env bash
# bug-report.sh — バグ発見時にPlaneへ新規チケットを自動起票するスクリプト
#
# Clineがバグを検出した際に呼び出される（06_plane.md のルールに従う）
#
# 使用方法:
#   ./ai-dlc/dlc-scripts/plane/bug-report.sh "<タイトル>" "<説明>" [priority] [parent_issue_seq]
#
# 引数:
#   title            : バグチケットのタイトル（必須）
#   description      : バグの説明・再現手順（必須）
#   priority         : 優先度（urgent|high|medium|low|none）デフォルト: medium
#   parent_issue_seq : 発見元チケットのシーケンスID（省略可）
#
# 出力:
#   作成されたチケットのシーケンスIDとURLを標準出力に出力する

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib.sh"

TITLE="${1:-}"
DESCRIPTION="${2:-}"
PRIORITY="${3:-medium}"
PARENT_SEQ="${4:-}"
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
LOOP_ENV_FILE=".loop-env"

# ----------------------------------------------------------------
# バリデーション
# ----------------------------------------------------------------
if [[ -z "$TITLE" || -z "$DESCRIPTION" ]]; then
  plane_error "タイトルと説明は必須です。"
  plane_error "使用方法: $0 \"<タイトル>\" \"<説明>\" [priority] [parent_issue_seq]"
  exit 1
fi

case "$PRIORITY" in
  urgent|high|medium|low|none) ;;
  *)
    plane_warn "不明な優先度 '${PRIORITY}'。'medium' を使用します。"
    PRIORITY="medium"
    ;;
esac

# ----------------------------------------------------------------
# 設定読み込み
# ----------------------------------------------------------------
plane_load_config || exit 1

# ----------------------------------------------------------------
# ループ情報の取得
# ----------------------------------------------------------------
LOOP_NUM=""
CURRENT_PHASE="unknown"
PARENT_ISSUE_ID=""

if [[ -f "$LOOP_ENV_FILE" ]]; then
  # shellcheck disable=SC1090
  source "$LOOP_ENV_FILE" 2>/dev/null || true
  LOOP_NUM="${LOOP_NUM:-}"
  CURRENT_PHASE="${PLANE_CURRENT_PHASE:-unknown}"
fi

if [[ -z "$LOOP_NUM" && -f "loop-log.md" ]]; then
  LOOP_NUM=$(grep -oP '(?<=## Loop #)\d+' "loop-log.md" | tail -1)
fi

# 発見元チケットIDの解決
if [[ -n "$PARENT_SEQ" ]]; then
  PARENT_ISSUE_ID=$(plane_get_issue_id "$PARENT_SEQ" || echo "")
elif [[ -n "${PLANE_ISSUE_ID:-}" ]]; then
  PARENT_ISSUE_ID="$PLANE_ISSUE_ID"
  PARENT_SEQ="${PLANE_ISSUE_SEQ:-}"
fi

# ----------------------------------------------------------------
# バグラベルIDの取得
# ----------------------------------------------------------------
BUG_LABEL_ID=$(plane_get_label_id "$PLANE_LABEL_BUG") || exit 1

# フェーズラベルIDの取得（発見時のフェーズを記録）
PHASE_LABEL_ID=""
case "$CURRENT_PHASE" in
  planning)       PHASE_LABEL_ID=$(plane_get_label_id "$PLANE_LABEL_PLANNING" 2>/dev/null || echo "") ;;
  implementation) PHASE_LABEL_ID=$(plane_get_label_id "$PLANE_LABEL_IMPLEMENTATION" 2>/dev/null || echo "") ;;
  verification)   PHASE_LABEL_ID=$(plane_get_label_id "$PLANE_LABEL_VERIFICATION" 2>/dev/null || echo "") ;;
  reflection)     PHASE_LABEL_ID=$(plane_get_label_id "$PLANE_LABEL_REFLECTION" 2>/dev/null || echo "") ;;
esac

# ラベルID配列の構築
LABEL_IDS="[\"${BUG_LABEL_ID}\""
if [[ -n "$PHASE_LABEL_ID" ]]; then
  LABEL_IDS="${LABEL_IDS}, \"${PHASE_LABEL_ID}\""
fi
LABEL_IDS="${LABEL_IDS}]"

# ----------------------------------------------------------------
# ステートIDの取得
# ----------------------------------------------------------------
BUG_STATE_ID=$(plane_get_state_id "$PLANE_STATE_BUG" || echo "")

# ----------------------------------------------------------------
# チケット説明の構築
# ----------------------------------------------------------------
FULL_DESCRIPTION="${DESCRIPTION}

---
**発見情報**
- 発見ループ: Loop ${LOOP_NUM:+#${LOOP_NUM}}
- 発見フェーズ: ${CURRENT_PHASE}
- 発見日時: ${TIMESTAMP}"

if [[ -n "$PARENT_SEQ" ]]; then
  FULL_DESCRIPTION="${FULL_DESCRIPTION}
- 発見元チケット: #${PARENT_SEQ}"
fi

# JSON エスケープ
ESCAPED_TITLE=$(echo "$TITLE" | python3 -c "import sys,json; print(json.dumps(sys.stdin.read().strip()))" | tr -d '"')
ESCAPED_DESC=$(echo "$FULL_DESCRIPTION" | python3 -c "import sys,json; print(json.dumps(sys.stdin.read().strip()))")

# ----------------------------------------------------------------
# チケット作成
# ----------------------------------------------------------------
plane_info "バグチケットを作成します: ${TITLE}"

REQUEST_BODY="{
  \"name\": \"[Bug] ${ESCAPED_TITLE}\",
  \"description_html\": \"<p>${ESCAPED_DESC}</p>\",
  \"priority\": \"${PRIORITY}\",
  \"label_ids\": ${LABEL_IDS}"

if [[ -n "$BUG_STATE_ID" ]]; then
  REQUEST_BODY="${REQUEST_BODY}, \"state\": \"${BUG_STATE_ID}\""
fi

if [[ -n "$PARENT_ISSUE_ID" ]]; then
  REQUEST_BODY="${REQUEST_BODY}, \"parent\": \"${PARENT_ISSUE_ID}\""
fi

REQUEST_BODY="${REQUEST_BODY}}"

RESPONSE=$(plane_api POST \
  "/workspaces/${PLANE_WORKSPACE}/projects/${PLANE_PROJECT_ID}/issues/" \
  "$REQUEST_BODY")

NEW_ISSUE_SEQ=$(echo "$RESPONSE" | jq -r '.sequence_id')
NEW_ISSUE_ID=$(echo "$RESPONSE" | jq -r '.id')

if [[ -z "$NEW_ISSUE_SEQ" || "$NEW_ISSUE_SEQ" == "null" ]]; then
  plane_error "チケット作成に失敗しました。"
  plane_error "レスポンス: ${RESPONSE}"
  exit 1
fi

# ----------------------------------------------------------------
# 発見元チケットにコメントを追記
# ----------------------------------------------------------------
if [[ -n "$PARENT_ISSUE_ID" ]]; then
  COMMENT="🐛 バグを検出しました → チケット #${NEW_ISSUE_SEQ} を起票しました (フェーズ: ${CURRENT_PHASE})"
  plane_add_comment "$PARENT_ISSUE_ID" "$COMMENT" || true
fi

# ----------------------------------------------------------------
# 結果出力
# ----------------------------------------------------------------
ISSUE_URL="${PLANE_BASE_URL}/${PLANE_WORKSPACE}/projects/${PLANE_PROJECT_SLUG}/issues/${NEW_ISSUE_SEQ}/"

plane_success "バグチケットを作成しました: #${NEW_ISSUE_SEQ}"
echo "   タイトル:  [Bug] ${TITLE}"
echo "   優先度:    ${PRIORITY}"
echo "   URL:       ${ISSUE_URL}"

# 後続スクリプトが参照できるよう標準出力にも出力
echo "PLANE_NEW_BUG_SEQ=${NEW_ISSUE_SEQ}"
echo "PLANE_NEW_BUG_ID=${NEW_ISSUE_ID}"
echo "PLANE_NEW_BUG_URL=${ISSUE_URL}"
