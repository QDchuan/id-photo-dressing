#!/usr/bin/env bash
# ============================================================================
# id-photo-dressing 一键初始化脚本（幂等，可重复执行）
# 完成：前置检查 → clone HivisionIDPhotos → 下载模型 → 建 venv → 装依赖 → 冒烟测试
#
# 用法：bash scripts/setup.sh
# 若 onnxruntime 等大包下载过慢，可先在本机已有 venv 中装好，脚本会自动跳过已满足的依赖。
# ============================================================================
set -euo pipefail

# ---- 路径 ----
SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RUNTIME_DIR="$SKILL_DIR/runtime"
PROJECT_DIR="$RUNTIME_DIR/HivisionIDPhotos"
WEIGHTS_DIR="$PROJECT_DIR/hivision/creator/weights"
VENV_DIR="$RUNTIME_DIR/venv"

C_RESET='\033[0m'; C_BLUE='\033[1;34m'; C_GREEN='\033[1;32m'; C_RED='\033[1;31m'
info()  { echo -e "${C_BLUE}[setup]${C_RESET} $*"; }
ok()    { echo -e "${C_GREEN}[setup]${C_RESET} $*"; }
err()   { echo -e "${C_RED}[setup]${C_RESET} $*"; }

# ---- 模型下载源（HF 官方 space，速度快且权威）----
HF_BASE="https://huggingface.co/spaces/TheEeeeLin/HivisionIDPhotos/resolve/main/hivision/creator/weights"
MODELS=("modnet_photographic_portrait_matting.onnx" "hivision_modnet.onnx")

# ---- 1. 前置工具检查 ----
info "检查前置工具 ..."
for tool in python3 git curl; do
  command -v "$tool" >/dev/null 2>&1 || { err "缺少 $tool，请先安装（如 apt install $tool）"; exit 1; }
done
PY_VERSION=$(python3 -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")')
ok "Python $PY_VERSION 可用"

# ---- 2. 获取 HivisionIDPhotos 项目 ----
info "[1/5] 定位/克隆 HivisionIDPhotos ..."
mkdir -p "$RUNTIME_DIR"
if [ -d "$PROJECT_DIR/hivision" ]; then
  ok "  已存在，跳过 clone"
else
  git clone --depth 1 https://github.com/zifeiyu0721/HivisionIDPhotos.git "$PROJECT_DIR"
  ok "  clone 完成"
fi

# ---- 3. 下载模型权重 ----
info "[2/5] 下载抠图模型权重 ..."
mkdir -p "$WEIGHTS_DIR"
for m in "${MODELS[@]}"; do
  if [ -s "$WEIGHTS_DIR/$m" ]; then
    ok "  已存在 $m，跳过"
  else
    info "  下载 $m ..."
    # HF 官方源，带 5 次重试 + 非空校验
    ok_flag=0
    for attempt in 1 2 3 4 5; do
      if curl -fL --retry 3 --connect-timeout 20 -o "$WEIGHTS_DIR/$m.tmp" "$HF_BASE/$m" 2>/dev/null \
         && [ -s "$WEIGHTS_DIR/$m.tmp" ]; then
        mv "$WEIGHTS_DIR/$m.tmp" "$WEIGHTS_DIR/$m"
        ok "  完成: $m ($(du -h "$WEIGHTS_DIR/$m" | cut -f1))"
        ok_flag=1; break
      fi
      sleep 3
    done
    [ "$ok_flag" -eq 1 ] || { err "  下载失败: $m"; exit 1; }
  fi
done

# ---- 4. 创建虚拟环境（复用系统 opencv/numpy，避免大包）----
info "[3/5] 创建虚拟环境（复用系统 opencv/numpy） ..."
if [ ! -x "$VENV_DIR/bin/python" ]; then
  python3 -m venv --system-site-packages "$VENV_DIR"
  ok "  venv 创建完成"
else
  ok "  venv 已存在，跳过"
fi

# ---- 5. 安装 Python 依赖（多镜像源自动 fallback）----
info "[4/5] 安装 Python 依赖（onnxruntime / mtcnn-runtime 等） ..."
PY="$VENV_DIR/bin/python"
if ! "$PY" -c "import onnxruntime, cv2, numpy" >/dev/null 2>&1; then
  MIRRORS=(
    "https://mirrors.aliyun.com/pypi/simple/"
    "https://pypi.tuna.tsinghua.edu.cn/simple"
    "https://pypi.org/simple"
  )
  deps_ok=0
  for m in "${MIRRORS[@]}"; do
    info "  尝试镜像源: $m"
    if "$VENV_DIR/bin/pip" install --no-input --index-url "$m" \
        onnxruntime "mtcnn-runtime" requests tqdm starlette fastapi uvicorn 2>/tmp/pip_err.log; then
      # mtcnn-runtime 必须 --no-deps 安装，避免误拉 opencv 大包
      "$VENV_DIR/bin/pip" install --no-input --no-deps --index-url "$m" mtcnn-runtime 2>/tmp/pip_err2.log || true
      deps_ok=1; break
    else
      err "  该源失败，换下一个源"
    fi
  done
  [ "$deps_ok" -eq 1 ] || { err "  依赖安装失败（详见 /tmp/pip_err.log）"; exit 1; }
  ok "  依赖安装完成"
else
  ok "  依赖已满足，跳过"
fi

# ---- 6. 冒烟测试：用示例照生成一张证件照 ----
info "[5/5] 冒烟测试：用示例照生成一张证件照 ..."
SMOKE_DIR="$RUNTIME_DIR/smoke_test"
mkdir -p "$SMOKE_DIR"
SAMPLE="$PROJECT_DIR/demo/images/test0.jpg"
if [ ! -f "$SAMPLE" ]; then SAMPLE="$PROJECT_DIR/examples/images/test0.jpg"; fi
if [ -f "$SAMPLE" ]; then
  if HIVISION_DIR="$PROJECT_DIR" "$PY" "$SKILL_DIR/scripts/pipeline.py" "$SAMPLE" "$SMOKE_DIR" --bg 438edb >/tmp/smoke.log 2>&1; then
    ok "  冒烟测试通过 ✅（示例证件照: $SMOKE_DIR）"
  else
    err "  冒烟测试失败（详见 /tmp/smoke.log）"
    exit 1
  fi
else
  warn "  未找到示例图，跳过冒烟测试"
fi

echo ""
echo "==========================================================="
echo " ✅ 环境初始化完成！"
echo "    项目目录: $PROJECT_DIR"
echo "    模型目录: $WEIGHTS_DIR"
echo "    Python:   $VENV_DIR/bin/python"
echo "-----------------------------------------------------------"
echo " 用法示例："
echo "   # 生成一寸蓝底证件照"
echo "   $VENV_DIR/bin/python $SKILL_DIR/scripts/pipeline.py 你的照片.jpg ./out --bg 438edb"
echo "   # 透明图换红底"
echo "   $VENV_DIR/bin/python $SKILL_DIR/scripts/repaint_bg.py 透明.png ./out/red.png d9001b"
echo "   # 一键换正装见 references/dressing.md"
echo "==========================================================="
