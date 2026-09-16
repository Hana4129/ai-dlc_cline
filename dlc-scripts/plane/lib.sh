#!/usr/bin/env bash
# lib.sh — Plane API 共通ライブラリ
# 他のスクリプトから source して使用する
#
# 使用方法:
#   source "$(dirname "$0")/lib.sh"
#   plane_load_config        # .plane-config.json を読み込む
#   plane_get_label_id "phase:planning"

set -euo pipefail

# ----------------------------------------------------------------
# 設定読み込み
# ----------------------------------------------------------------
plane_load_config() {
  local config_file="${PLANE_CONFIG_FILE:-}"

  # 設定ファイルの探索順: 環境変数 → カレント → Gitルート
  if [[ -z "$config_file" ]]; then
    if [[ -f ".plane-config.json" ]]; then
      config_file=".plane-config.json"
    else
      local git_root
      git_root=$(git rev-parse --show-toplevel 2>/dev/null || echo "")
      if [[ -n "$git_root" && -f "${git_root}/.plane-config.json" ]]; then
        config_file="${git_root}/.plane-config.json"
      fi
    fi
  fi

  if [[ -z "$config_file" || ! -f "$config_file" ]]; then
    plane_error ".plane-config.json が見つかりません。" \
      "テンプレートからコピーして設定してください:" \
      "  cp ai-dlc/dlc-templates/.plane-config.template.json .plane-config.json"
    return 1
  fi

  # jq で各値を読み込む
  PLANE_BASE_URL=$(jq -r '.plane.baseUrl' "$config_file")
  PLANE_WORKSPACE=$(jq -r '.plane.workspaceSlug' "$config_file")
  PLANE_TOKEN=$(jq -r '.plane.apiToken' "$config_file")
  PLANE_PROJECT_SLUG=$(jq -r '.project.slug' "$config_file")

  PLANE_LABEL_PLANNING=$(jq -r '.labels.phases.planning' "$config_file")
  PLANE_LABEL_IMPLEMENTATION=$(jq -r '.labels.phases.implementation' "$config_file")
  PLANE_LABEL_VERIFICATION=$(jq -r '.labels.phases.verification' "$config_file")
  PLANE_LABEL_REFLECTION=$(jq -r '.labels.phases.reflection' "$config_file")
  PLANE_LABEL_BUG=$(jq -r '.labels.types.bug' "$config_file")
  PLANE_LABEL_FEATURE=$(jq -r '.labels.types.feature' "$config_file")

  PLANE_STATE_DEFAULT=$(jq -r '.issueDefaults.defaultState' "$config_file")
  PLANE_STATE_IN_PROGRESS=$(jq -r '.issueDefaults.inProgressState' "$config_file")
  PLANE_STATE_DONE=$(jq -r '.issueDefaults.doneState' "$config_file")
  PLANE_STATE_BUG=$(jq -r '.issueDefaults.bugState' "$config_file")
  PLANE_DEFAULT_PRIORITY=$(jq -r '.issueDefaults.defaultPriority' "$config_file")

  # バリデーション
  if [[ "$PLANE_TOKEN" == "YOUR_PLANE_API_TOKEN_HERE" || -z "$PLANE_TOKEN" ]]; then
    plane_error "APIトークンが設定されていません。.plane-config.json の plane.apiToken を設定してください。"
    return 1
  fi
  if [[ "$PLANE_PROJECT_SLUG" == "YOUR_PROJECT_SLUG_HERE" || -z "$PLANE_PROJECT_SLUG" ]]; then
    plane_error "プロジェクトスラッグが設定されていません。.plane-config.json の project.slug を設定してください。"
    return 1
  fi

  # プロジェクトIDを取得・キャッシュ
  PLANE_PROJECT_ID=$(plane_get_project_id "$PLANE_PROJECT_SLUG")
  if [[ -z "$PLANE_PROJECT_ID" ]]; then
    plane_error "プロジェクト '${PLANE_PROJECT_SLUG}' が見つかりません。Plane上のプロジェクトスラッグを確認してください。"
    return 1
  fi

  plane_info "設定を読み込みました: ${PLANE_BASE_URL}/${PLANE_WORKSPACE}/${PLANE_PROJECT_SLUG}/"
}

# ----------------------------------------------------------------
# ログ出力
# ----------------------------------------------------------------
plane_info()    { echo "ℹ️  [plane] $*"; }
plane_success() { echo "✅ [plane] $*"; }
plane_warn()    { echo "⚠️  [plane] $*"; }
plane_error()   { echo "❌ [plane] $*" >&2; }

# ----------------------------------------------------------------
# API 共通リクエスト
# ----------------------------------------------------------------
plane_api() {
  local method="$1"
  local endpoint="$2"
  local data="${3:-}"

  local url="${PLANE_BASE_URL}/api/v1${endpoint}"
  local args=(
    -s -f
    -X "$method"
    -H "X-API-Key: ${PLANE_TOKEN}"
    -H "Content-Type: application/json"
  )

  if [[ -n "$data" ]]; then
    args+=(-d "$data")
  fi

  local response
  if ! response=$(curl "${args[@]}" "$url" 2>&1); then
    plane_error "API リクエスト失敗: ${method} ${url}"
    plane_error "レスポンス: ${response}"
    return 1
  fi

  echo "$response"
}

# ----------------------------------------------------------------
# プロジェクトID取得
# ----------------------------------------------------------------
plane_get_project_id() {
  local slug="$1"
  local response
  response=$(plane_api GET "/workspaces/${PLANE_WORKSPACE}/projects/") || return 1
  echo "$response" | jq -r --arg slug "$slug" \
    '.results[] | select(.identifier == $slug or .slug == $slug) | .id' | head -1
}

# ----------------------------------------------------------------
# ラベルID取得（ラベル名 → ID）
# ----------------------------------------------------------------
plane_get_label_id() {
  local label_name="$1"
  local response
  response=$(plane_api GET "/workspaces/${PLANE_WORKSPACE}/projects/${PLANE_PROJECT_ID}/labels/") || return 1
  local label_id
  label_id=$(echo "$response" | jq -r --arg name "$label_name" \
    '.results[] | select(.name == $name) | .id' | head -1)

  if [[ -z "$label_id" ]]; then
    # ラベルが存在しない場合は自動作成
    plane_warn "ラベル '${label_name}' が存在しません。自動作成します..."
    label_id=$(plane_create_label "$label_name")
  fi

  echo "$label_id"
}

# ----------------------------------------------------------------
# ラベル自動作成
# ----------------------------------------------------------------
plane_create_label() {
  local label_name="$1"
  # フェーズラベルの色定義
  local color="#6366f1"
  case "$label_name" in
    phase:planning)       color="#f59e0b" ;;  # 黄
    phase:implementation) color="#3b82f6" ;;  # 青
    phase:verification)   color="#10b981" ;;  # 緑
    phase:reflection)     color="#8b5cf6" ;;  # 紫
    type:bug)             color="#ef4444" ;;  # 赤
    type:feature)         color="#06b6d4" ;;  # シアン
    type:chore)           color="#6b7280" ;;  # グレー
  esac

  local response
  response=$(plane_api POST \
    "/workspaces/${PLANE_WORKSPACE}/projects/${PLANE_PROJECT_ID}/labels/" \
    "{\"name\": \"${label_name}\", \"color\": \"${color}\"}") || return 1
  echo "$response" | jq -r '.id'
}

# ----------------------------------------------------------------
# ステートID取得（ステート名 → ID）
# ----------------------------------------------------------------
plane_get_state_id() {
  local state_name="$1"
  local response
  response=$(plane_api GET "/workspaces/${PLANE_WORKSPACE}/projects/${PLANE_PROJECT_ID}/states/") || return 1
  echo "$response" | jq -r --arg name "$state_name" \
    '.results[] | select(.name == $name) | .id' | head -1
}

# ----------------------------------------------------------------
# チケットID取得（シーケンス番号 → ID）
# ----------------------------------------------------------------
plane_get_issue_id() {
  local sequence_id="$1"
  local response
  response=$(plane_api GET \
    "/workspaces/${PLANE_WORKSPACE}/projects/${PLANE_PROJECT_ID}/issues/?sequence_id=${sequence_id}") || return 1
  echo "$response" | jq -r '.results[0].id // empty'
}

# ----------------------------------------------------------------
# チケットにラベルを追加
# ----------------------------------------------------------------
plane_add_label_to_issue() {
  local issue_id="$1"
  local label_name="$2"

  local label_id
  label_id=$(plane_get_label_id "$label_name") || return 1

  # 現在のラベル一覧を取得してマージ
  local current_labels
  current_labels=$(plane_api GET \
    "/workspaces/${PLANE_WORKSPACE}/projects/${PLANE_PROJECT_ID}/issues/${issue_id}/") \
    | jq -r '[.label_ids[]] | @json')

  # 新しいラベルIDを追加（重複除外）
  local new_labels
  new_labels=$(echo "$current_labels" | jq --arg id "$label_id" \
    '. + [$id] | unique')

  plane_api PATCH \
    "/workspaces/${PLANE_WORKSPACE}/projects/${PLANE_PROJECT_ID}/issues/${issue_id}/" \
    "{\"label_ids\": ${new_labels}}" > /dev/null

  plane_success "ラベル '${label_name}' を追加しました (issue: ${issue_id})"
}

# ----------------------------------------------------------------
# チケットのラベルをフェーズラベルのみ入れ替え
# ----------------------------------------------------------------
plane_set_phase_label() {
  local issue_id="$1"
  local phase="$2"   # planning | implementation | verification | reflection

  local new_label_name
  case "$phase" in
    planning)       new_label_name="$PLANE_LABEL_PLANNING" ;;
    implementation) new_label_name="$PLANE_LABEL_IMPLEMENTATION" ;;
    verification)   new_label_name="$PLANE_LABEL_VERIFICATION" ;;
    reflection)     new_label_name="$PLANE_LABEL_REFLECTION" ;;
    *)
      plane_error "不明なフェーズ: ${phase}"
      return 1
      ;;
  esac

  local new_label_id
  new_label_id=$(plane_get_label_id "$new_label_name") || return 1

  # 全フェーズラベルIDを取得
  local phase_label_ids=()
  for pname in "$PLANE_LABEL_PLANNING" "$PLANE_LABEL_IMPLEMENTATION" \
               "$PLANE_LABEL_VERIFICATION" "$PLANE_LABEL_REFLECTION"; do
    local pid
    pid=$(plane_get_label_id "$pname" 2>/dev/null || echo "")
    [[ -n "$pid" ]] && phase_label_ids+=("$pid")
  done

  # 現在のラベルからフェーズラベルを除外し、新しいフェーズラベルを追加
  local current_issue
  current_issue=$(plane_api GET \
    "/workspaces/${PLANE_WORKSPACE}/projects/${PLANE_PROJECT_ID}/issues/${issue_id}/")
  local current_labels
  current_labels=$(echo "$current_issue" | jq '[.label_ids[]]')

  local filtered_labels="$current_labels"
  for pid in "${phase_label_ids[@]}"; do
    filtered_labels=$(echo "$filtered_labels" | jq --arg id "$pid" '[.[] | select(. != $id)]')
  done

  local new_labels
  new_labels=$(echo "$filtered_labels" | jq --arg id "$new_label_id" '. + [$id] | unique')

  plane_api PATCH \
    "/workspaces/${PLANE_WORKSPACE}/projects/${PLANE_PROJECT_ID}/issues/${issue_id}/" \
    "{\"label_ids\": ${new_labels}}" > /dev/null

  plane_success "フェーズラベルを '${new_label_name}' に更新しました (issue: ${issue_id})"
}

# ----------------------------------------------------------------
# チケットのステートを更新
# ----------------------------------------------------------------
plane_set_issue_state() {
  local issue_id="$1"
  local state_name="$2"

  local state_id
  state_id=$(plane_get_state_id "$state_name") || return 1

  if [[ -z "$state_id" ]]; then
    plane_warn "ステート '${state_name}' が見つかりません。スキップします。"
    return 0
  fi

  plane_api PATCH \
    "/workspaces/${PLANE_WORKSPACE}/projects/${PLANE_PROJECT_ID}/issues/${issue_id}/" \
    "{\"state\": \"${state_id}\"}" > /dev/null

  plane_success "ステートを '${state_name}' に更新しました (issue: ${issue_id})"
}

# ----------------------------------------------------------------
# チケットにコメントを追加
# ----------------------------------------------------------------
plane_add_comment() {
  local issue_id="$1"
  local comment="$2"

  plane_api POST \
    "/workspaces/${PLANE_WORKSPACE}/projects/${PLANE_PROJECT_ID}/issues/${issue_id}/comments/" \
    "{\"comment_html\": \"<p>${comment}</p>\"}" > /dev/null

  plane_success "コメントを追加しました (issue: ${issue_id})"
}
