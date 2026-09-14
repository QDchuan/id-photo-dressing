#!/usr/bin/env bash
# ============================================================================
# 一键生成「可分享的 skill 压缩包」（不含 runtime/）
# ----------------------------------------------------------------------------
# runtime/ 里是本机部署的虚拟环境和模型（venv 不可移植、体积大），分享时必须排除。
# 对方拿到压缩包后：解压 → 放进自己的 .user_skills 目录 → bash scripts/setup.sh
#
# 用法：bash scripts/package.sh [输出路径]
# 默认输出到 <skill>/../id-photo-dressing-<日期>.zip
# ============================================================================
set -euo pipefail

SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT="${1:-$SKILL_DIR/../id-photo-dressing-$(date +%Y%m%d).zip}"

command -v zip >/dev/null 2>&1 || { echo "[错误] 需要 zip 命令（apt install zip）"; exit 1; }

# 打包内容：SKILL.md + scripts + references（排除 runtime、缓存、临时文件）
cd "$(dirname "$SKILL_DIR")"
mkdir -p "$(dirname "$OUT")"
TARGET_DIR="$(basename "$SKILL_DIR")"

find "$TARGET_DIR" -type d -name runtime -prune -o -type f -print | \
    grep -vE "(/runtime/|__pycache__|\.DS_Store)" | \
    zip -q "$OUT" -@

echo ""
echo "✅ 分享包已生成: $OUT"
echo "-----------------------------------------------------------"
echo " 分享步骤："
echo "  1. 把 $(basename "$OUT") 发给对方"
echo "  2. 对方解压后，将 $TARGET_DIR 放入其 .user_skills 目录"
echo "  3. 对方执行： bash $TARGET_DIR/scripts/setup.sh  （自动初始化环境）"
echo "-----------------------------------------------------------"
