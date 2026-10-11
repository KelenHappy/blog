#!/usr/bin/env bash
#
# updateHugoTheme.sh — 更新 Blowfish 主題（git submodule: themes/blowfish）
#
# 用法:
#   ./updateHugoTheme.sh            # 更新到最新的 release tag（例如 v3.9.0）
#   ./updateHugoTheme.sh v3.8.0     # 更新 / 切換到指定的 tag
#
# 步驟:
#   1. 確認 submodule 已初始化
#   2. 從上游抓取最新 tags
#   3. checkout 目標 tag（預設為最新版）
#   4. 顯示主題要求的 Hugo 最低/最高版本，並檢查 CI (.github/workflows/hugo.yml) 是否相容
#   5. 顯示建議的 git 指令（不會自動 commit / push）
#
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
THEME_PATH="themes/blowfish"
THEME_DIR="$ROOT/$THEME_PATH"
WORKFLOW="$ROOT/.github/workflows/hugo.yml"

cd "$ROOT"

# 1. 初始化 submodule（第一次 clone 時需要）
if [ ! -e "$THEME_DIR/.git" ]; then
  echo "==> 初始化 submodule $THEME_PATH"
  git submodule update --init "$THEME_PATH"
fi

if [ -n "$(git -C "$THEME_DIR" status --porcelain)" ]; then
  echo "錯誤: $THEME_PATH 內有未提交的修改，請先處理後再更新。" >&2
  exit 1
fi

OLD_VERSION="$(git -C "$THEME_DIR" describe --tags 2>/dev/null || git -C "$THEME_DIR" rev-parse --short HEAD)"
OLD_COMMIT="$(git -C "$THEME_DIR" rev-parse HEAD)"

# 2. 抓取上游 tags
echo "==> 抓取 Blowfish 最新版本資訊..."
git -C "$THEME_DIR" fetch --tags --force origin

# 3. 決定目標版本
TARGET="${1:-$(git -C "$THEME_DIR" tag -l 'v*' --sort=-v:refname | head -n1)}"
if ! git -C "$THEME_DIR" rev-parse -q --verify "refs/tags/$TARGET" >/dev/null; then
  echo "錯誤: 找不到 tag '$TARGET'" >&2
  exit 1
fi

echo "    目前版本: $OLD_VERSION"
echo "    目標版本: $TARGET"

if [ "$(git -C "$THEME_DIR" rev-parse "$TARGET^{commit}")" = "$OLD_COMMIT" ]; then
  echo "==> 已經是 $TARGET，不需要更新。"
  exit 0
fi

git -C "$THEME_DIR" checkout -q "$TARGET"
echo "==> 已切換到 $TARGET"

# 4. 檢查 Hugo 版本相容性
version_le() { [ "$(printf '%s\n%s\n' "$1" "$2" | sort -V | head -n1)" = "$1" ]; }

MIN_HUGO="$(sed -n '/\[module.hugoVersion\]/,/^\[/ s/^ *min *= *"\(.*\)"/\1/p' "$THEME_DIR/config.toml")"
MAX_HUGO="$(sed -n '/\[module.hugoVersion\]/,/^\[/ s/^ *max *= *"\(.*\)"/\1/p' "$THEME_DIR/config.toml")"
CI_HUGO="$(sed -n 's/^ *HUGO_VERSION: *\([0-9.]*\).*/\1/p' "$WORKFLOW" | head -n1)"

echo "==> 主題要求 Hugo: ${MIN_HUGO:-?} ~ ${MAX_HUGO:-?}（extended）"
echo "    CI 使用 Hugo:   ${CI_HUGO:-?}"
if [ -n "$CI_HUGO" ] && [ -n "$MIN_HUGO" ] && [ -n "$MAX_HUGO" ]; then
  if version_le "$MIN_HUGO" "$CI_HUGO" && version_le "$CI_HUGO" "$MAX_HUGO"; then
    echo "    ✓ CI 版本相容"
  else
    echo "    ⚠ CI 的 HUGO_VERSION ($CI_HUGO) 不在範圍內，請修改 $WORKFLOW"
  fi
fi

# 5. 提示後續 git 操作
echo
echo "==> 更新完成: $OLD_VERSION -> $TARGET"
echo "    請確認後自行提交:"
echo "      git add $THEME_PATH"
echo "      git commit -m \"chore(theme): update blowfish $OLD_VERSION -> $TARGET\""
echo "      git push"
