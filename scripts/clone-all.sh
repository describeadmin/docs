#!/usr/bin/env bash
#
# 把 repos.yml 中登记的全部仓库检出到本仓库的同级目录。
#
# 存在的意义：本项目采用「按模块细分多仓」拓扑，跨仓改动（尤其是 SPI 变更）很常见。
# 没有这个脚本，开发者与 AI Agent 都拿不到完整上下文，多仓会直接侵蚀
# 「AI 能独立理解项目」这个核心目标（见 develop_plan.md 3.1.1）。
#
# 用法：
#   ./scripts/clone-all.sh              处理全部 status: active 的仓库
#   ./scripts/clone-all.sh core         只处理 group: core
#   ./scripts/clone-all.sh --all        含 status: planned（尚未创建的会跳过并提示）
#   ./scripts/clone-all.sh --list       只列出，不执行
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
WORKSPACE_DIR="$(cd "$ROOT_DIR/.." && pwd)"
REPOS_FILE="$ROOT_DIR/repos.yml"

[[ -f "$REPOS_FILE" ]] || { echo "找不到 $REPOS_FILE" >&2; exit 1; }

ORG="$(sed -n 's/^org:[[:space:]]*//p' "$REPOS_FILE" | head -1)"
HOST="$(sed -n 's/^host:[[:space:]]*//p' "$REPOS_FILE" | head -1)"
SELF="$(basename "$ROOT_DIR")"

INCLUDE_PLANNED=0
LIST_ONLY=0
GROUP_FILTER=""

for arg in "$@"; do
  case "$arg" in
    --all)   INCLUDE_PLANNED=1 ;;
    --list)  LIST_ONLY=1 ;;
    --help|-h) sed -n '2,16p' "$0"; exit 0 ;;
    *)       GROUP_FILTER="$arg" ;;
  esac
done

# 极简 YAML 解析：只认 repos: 下的 "- name:" / "group:" / "status:" 三个字段。
# 刻意不引入 yq —— 这个脚本必须在任何一台刚装好 git 的机器上直接可跑。
parse_repos() {
  awk '
    /^repos:/ { in_repos=1; next }
    !in_repos { next }
    /^[[:space:]]*-[[:space:]]*name:[[:space:]]*/ {
      if (name != "") print name "\t" group "\t" status
      name=$0; sub(/^[[:space:]]*-[[:space:]]*name:[[:space:]]*/, "", name)
      group=""; status=""
      next
    }
    /^[[:space:]]+group:[[:space:]]*/ { g=$0; sub(/^[[:space:]]+group:[[:space:]]*/,"",g); group=g; next }
    /^[[:space:]]+status:[[:space:]]*/ { s=$0; sub(/^[[:space:]]+status:[[:space:]]*/,"",s); status=s; next }
    END { if (name != "") print name "\t" group "\t" status }
  ' "$REPOS_FILE"
}

echo "组织    : $ORG@$HOST"
echo "工作区  : $WORKSPACE_DIR"
[[ -n "$GROUP_FILTER" ]] && echo "分组过滤: $GROUP_FILTER"
echo

ok=0; skipped=0; missing=0

while IFS=$'\t' read -r name group status; do
  [[ -z "$name" ]] && continue
  [[ "$name" == "$SELF" ]] && continue
  [[ -n "$GROUP_FILTER" && "$group" != "$GROUP_FILTER" ]] && continue
  if [[ "$status" != "active" && $INCLUDE_PLANNED -eq 0 ]]; then
    skipped=$((skipped+1)); continue
  fi

  target="$WORKSPACE_DIR/$name"
  url="https://$HOST/$ORG/$name.git"

  if [[ $LIST_ONLY -eq 1 ]]; then
    printf "  %-40s %-8s %s\n" "$name" "$group" "$status"
    continue
  fi

  if [[ -d "$target/.git" ]]; then
    echo "▸ $name  已存在，拉取更新"
    git -C "$target" fetch --prune --quiet && echo "  ✔ fetch 完成" || echo "  ⚠ fetch 失败（可能未配置远端）"
    ok=$((ok+1))
  else
    echo "▸ $name  克隆中"
    if git clone --quiet "$url" "$target" 2>/dev/null; then
      echo "  ✔ 完成"
      ok=$((ok+1))
    else
      echo "  ⚠ 克隆失败（仓库尚未创建？）: $url"
      missing=$((missing+1))
    fi
  fi
done < <(parse_repos)

if [[ $LIST_ONLY -eq 0 ]]; then
  echo
  echo "完成：成功 $ok，跳过 $skipped（非 active，用 --all 包含），失败 $missing"
fi
