#!/usr/bin/env bash
# install.sh — ai-dlc を既存プロジェクトへ導入するスクリプト
#
# 使用方法:
#   # サブモジュールとして追加（推奨）
#   curl -fsSL https://raw.githubusercontent.com/<org>/ai-dlc/main/dlc-scripts/install.sh | bash
#
#   # またはローカルで直接実行
#   ./ai-dlc/dlc-scripts/install.sh [オプション]
#
# オプション:
#   --no-submodule    サブモジュールを使わず、ファイルをコピーする
#   --branch <name>   使用するブランチを指定（デフォルト: main）
#   --repo <url>      ai-dlc リポジトリのURLを指定

set -euo pipefail

# ----------------------------------------------------------------
# デフォルト設定
# ----------------------------------------------------------------
AI_DLC_REPO="${AI_DLC_REPO:-https://github.com/<org>/ai-dlc.git}"
AI_DLC_BRANCH="${AI_DLC_BRANCH:-main}"
USE_SUBMODULE=true
SUBMODULE_PATH="ai-dlc"
CLINERULES_DIR=".clinerules"
LOCAL_RULES_FILE="${CLINERULES_DIR}/99_local.md"

# ----------------------------------------------------------------
# 引数パース
# ----------------------------------------------------------------
while [[ $# -gt 0 ]]; do
  case "$1" in
    --no-submodule) USE_SUBMODULE=false; shift ;;
    --branch)       AI_DLC_BRANCH="$2"; shift 2 ;;
    --repo)         AI_DLC_REPO="$2"; shift 2 ;;
    *) echo "未知のオプション: $1"; exit 1 ;;
  esac
done

# ----------------------------------------------------------------
# ヘルパー関数
# ----------------------------------------------------------------
info()    { echo "ℹ️  $*"; }
success() { echo "✅ $*"; }
warn()    { echo "⚠️  $*"; }
error()   { echo "❌ $*" >&2; exit 1; }

# ----------------------------------------------------------------
# 前提チェック
# ----------------------------------------------------------------
if ! git rev-parse --git-dir > /dev/null 2>&1; then
  error "Gitリポジトリではありません。プロジェクトルートで実行してください。"
fi

# ----------------------------------------------------------------
# サブモジュールとして追加
# ----------------------------------------------------------------
install_as_submodule() {
  if [[ -d "$SUBMODULE_PATH" ]]; then
    warn "${SUBMODULE_PATH}/ は既に存在します。スキップします。"
    warn "更新する場合は: git submodule update --remote ${SUBMODULE_PATH}"
    return
  fi

  info "ai-dlc をサブモジュールとして追加します..."
  git submodule add --branch "$AI_DLC_BRANCH" "$AI_DLC_REPO" "$SUBMODULE_PATH"
  git submodule update --init --recursive
  success "サブモジュールを追加しました: ${SUBMODULE_PATH}/"

  # .gitmodulesをコミット推奨メッセージ
  info "以下のコマンドでコミットしてください:"
  echo "  git add .gitmodules ${SUBMODULE_PATH}"
  echo "  git commit -m \"chore: add ai-dlc as submodule\""
}

# ----------------------------------------------------------------
# コピーとして追加（--no-submodule）
# ----------------------------------------------------------------
install_as_copy() {
  info "ai-dlc を一時的にクローンしてコピーします..."
  TMP_DIR=$(mktemp -d)
  trap "rm -rf $TMP_DIR" EXIT

  git clone --depth 1 --branch "$AI_DLC_BRANCH" "$AI_DLC_REPO" "$TMP_DIR/ai-dlc"

  # .clinerules/base/ にコピー
  BASE_DIR="${CLINERULES_DIR}/base"
  mkdir -p "$BASE_DIR"
  cp -r "$TMP_DIR/ai-dlc/.clinerules/." "$BASE_DIR/"
  success "ルールファイルを ${BASE_DIR}/ にコピーしました。"

  # scripts をコピー
  cp -r "$TMP_DIR/ai-dlc/dlc-scripts" "./ai-dlc-dlc-scripts"
  success "スクリプトを ./ai-dlc-dlc-scripts/ にコピーしました。"

  warn "コピー方式では ai-dlc の更新が自動反映されません。"
  warn "定期的に install.sh を再実行して更新してください。"
}

# ----------------------------------------------------------------
# .clinerules/ のセットアップ
# ----------------------------------------------------------------
setup_clinerules() {
  mkdir -p "$CLINERULES_DIR"

  # ローカルルールファイルがなければテンプレートから生成
  if [[ ! -f "$LOCAL_RULES_FILE" ]]; then
    TEMPLATE_SRC=""
    if [[ -f "${SUBMODULE_PATH}/dlc-templates/99_local.template.md" ]]; then
      TEMPLATE_SRC="${SUBMODULE_PATH}/dlc-templates/99_local.template.md"
    elif [[ -f "${CLINERULES_DIR}/base/../../../${SUBMODULE_PATH}/dlc-templates/99_local.template.md" ]]; then
      TEMPLATE_SRC="${SUBMODULE_PATH}/dlc-templates/99_local.template.md"
    fi

    if [[ -n "$TEMPLATE_SRC" && -f "$TEMPLATE_SRC" ]]; then
      cp "$TEMPLATE_SRC" "$LOCAL_RULES_FILE"
      success "プロジェクト固有ルールテンプレートを作成しました: ${LOCAL_RULES_FILE}"
    else
      cat > "$LOCAL_RULES_FILE" << 'EOF'
# 99_local.md — プロジェクト固有ルール
#
# このファイルはai-dlcの汎用ルール（00〜05）を上書き・追記するためのファイルです。
# チームの規約に合わせて編集してください。

## プロジェクト情報

- プロジェクト名: <プロジェクト名>
- 主な技術スタック: <言語・FW・主要ライブラリ>
- テスト実行コマンド: `<コマンド>`
- ビルドコマンド: `<コマンド>`

## プロジェクト固有の制約

- <プロジェクト固有の制約をここに追加>

## プロジェクト固有のコーディング規約

- <規約をここに追加>
EOF
      success "プロジェクト固有ルールファイルを作成しました: ${LOCAL_RULES_FILE}"
    fi
  else
    warn "${LOCAL_RULES_FILE} は既に存在します。スキップします。"
  fi
}

# ----------------------------------------------------------------
# loop-log.md の初期化
# ----------------------------------------------------------------
setup_loop_log() {
  if [[ ! -f "loop-log.md" ]]; then
    cat > "loop-log.md" << 'EOF'
# Loop Log

このファイルはAI-DLCループエンジニアリングの実行記録です。
自動生成・追記されます。削除・上書きしないでください。

---
EOF
    success "loop-log.md を初期化しました。"

    # .gitignoreに追加しない（チーム共有するため）
    info "loop-log.md はチームで共有するためgitignoreに追加しません。"
  else
    warn "loop-log.md は既に存在します。スキップします。"
  fi
}

# ----------------------------------------------------------------
# メイン処理
# ----------------------------------------------------------------
echo ""
echo "🚀 ai-dlc インストールを開始します"
echo "   リポジトリ: ${AI_DLC_REPO}"
echo "   ブランチ:   ${AI_DLC_BRANCH}"
echo "   方式:       $([ "$USE_SUBMODULE" = true ] && echo 'サブモジュール' || echo 'コピー')"
echo ""

if [[ "$USE_SUBMODULE" = true ]]; then
  install_as_submodule
else
  install_as_copy
fi

setup_clinerules
setup_loop_log

echo ""
success "ai-dlc のセットアップが完了しました！"
echo ""
echo "次のステップ:"
echo "  1. ${LOCAL_RULES_FILE} をプロジェクトに合わせて編集する"
echo "  2. ループを開始する:"
echo "     ./${SUBMODULE_PATH}/dlc-scripts/loop-start.sh \"<目標>\""
echo ""
