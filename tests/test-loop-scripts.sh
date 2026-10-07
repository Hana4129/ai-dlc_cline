#!/usr/bin/env bash

set -euo pipefail

AI_DLC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

printf 'LOOP_NUM=1\nLOOP_NUM=2\n' > "$TMP_DIR/loop-env"
[[ "$(bash -c 'source "$1"; loop_env_get LOOP_NUM "$2"' _ "$AI_DLC_DIR/dlc-scripts/loop-env.sh" "$TMP_DIR/loop-env")" == "2" ]]

mkdir -p "$TMP_DIR/install/ai-dlc/dlc-scripts" "$TMP_DIR/install/.clinerules"
cp "$AI_DLC_DIR/dlc-scripts/install.sh" "$TMP_DIR/install/ai-dlc/dlc-scripts/"
cp -R "$AI_DLC_DIR/.clinerules" "$TMP_DIR/install/ai-dlc/"
cp -R "$AI_DLC_DIR/dlc-templates" "$TMP_DIR/install/ai-dlc/"
printf 'project-specific\n' > "$TMP_DIR/install/.clinerules/99_local.md"
git -C "$TMP_DIR/install" init -q
(cd "$TMP_DIR/install" && bash ai-dlc/dlc-scripts/install.sh >/dev/null)

for rule in 00_meta.md 01_planning.md 02_implementation.md 03_verification.md 04_reflection.md 05_constraints.md 06_plane.md; do
  [[ -f "$TMP_DIR/install/.clinerules/$rule" ]]
done
[[ "$(<"$TMP_DIR/install/.clinerules/99_local.md")" == "project-specific" ]]

mkdir -p "$TMP_DIR/loops"
(
  cd "$TMP_DIR/loops"
  bash "$AI_DLC_DIR/dlc-scripts/loop-start.sh" 'first goal with spaces'
  bash "$AI_DLC_DIR/dlc-scripts/loop-end.sh" success 'first learning' 'first next step'
  bash "$AI_DLC_DIR/dlc-scripts/loop-start.sh" '$(touch should-not-exist) second goal'
  bash "$AI_DLC_DIR/dlc-scripts/loop-end.sh" failure 'second learning' 'second next step'
  bash "$AI_DLC_DIR/dlc-scripts/loop-start.sh" 'third goal'
  bash "$AI_DLC_DIR/dlc-scripts/loop-end.sh" partial '' ''

  [[ ! -e should-not-exist ]]
  [[ ! -e .loop-env ]]
  grep -Fq -- '- ステータス: ✅ 成功' <(sed -n '/^## Loop #1 /,/^## Loop #2 /p' loop-log.md)
  grep -Fq -- '- first learning' <(sed -n '/^### 学び・気づき/,/^### 次のループへの引き継ぎ/p' loop-log.md | head -2)
  grep -Fq -- '- ステータス: ❌ 失敗' <(sed -n '/^## Loop #2 /,$p' loop-log.md)
  grep -Fq -- '- second next step' <(sed -n '/^## Loop #2 /,$p' loop-log.md)
  grep -Fq -- '- ステータス: ⚠️ 部分成功' <(sed -n '/^## Loop #3 /,$p' loop-log.md)
  grep -Fq -- '- 終了時刻:' <(sed -n '/^## Loop #3 /,$p' loop-log.md)
  [[ "$(grep -c '^- 終了時刻:' loop-log.md)" -eq 3 ]]
  [[ "$(sed -n '/^## Loop #1 /,/^## Loop #2 /p' loop-log.md | grep -c '^- 終了時刻:')" -eq 1 ]]
  [[ "$(sed -n '/^## Loop #2 /,/^## Loop #3 /p' loop-log.md | grep -c '^- 終了時刻:')" -eq 1 ]]
  [[ "$(sed -n '/^## Loop #3 /,$p' loop-log.md | grep -c '^- 終了時刻:')" -eq 1 ]]
)

printf 'AI-DLC loop script tests passed.\n'