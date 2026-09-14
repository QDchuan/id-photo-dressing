#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
证件照生成管线（抠图 → 换标准底色 → 标准尺寸 → 六寸排版照）。

依赖 HivisionIDPhotos 开源项目（由 scripts/setup.sh 部署到 <skill>/runtime/ 下）。
用法：
    python pipeline.py <输入照片> <输出目录> [--bg 438edb] [--width 295] [--height 413] [--no-layout]

常用底色：438edb(蓝) / d9001b(红) / ffffff(白)
常用尺寸：一寸 295x413，二寸 413x579
"""
import os
import sys
import argparse

# ---- 内联 gradio stub：HivisionIDPhotos 的美颜插件在模块级构建 gradio demo，
# ---- 主流程用不到；未安装 gradio 时注入最小替身即可跳过。
if "gradio" not in sys.modules:
    try:
        import gradio  # noqa: F401
    except ImportError:
        import types
        class _C:
            def __init__(self, *a, **k): pass
            def __enter__(self): return self
            def __exit__(self, *a, **k): pass
            def click(self, *a, **k): return self
            def __call__(self, *a, **k): return self
        class _B(_C):
            def launch(self, *a, **k): return None
            def queue(self, *a, **k): return self
        sys.modules["gradio"] = types.SimpleNamespace(
            Blocks=_B, Markdown=_C, Image=_C, Slider=_C,
            Row=_C, Button=_C, Textbox=_C, Column=_C,
        )

HERE = os.path.dirname(os.path.abspath(__file__))
SKILL_DIR = os.path.dirname(HERE)


def _resolve_hivision_dir(repo_arg=None):
    """定位 HivisionIDPhotos 目录：优先命令行参数，其次环境变量，再其次 skill runtime。"""
    candidates = []
    if repo_arg:
        candidates.append(repo_arg)
    candidates += [
        os.environ.get("HIVISION_DIR", ""),
        os.path.join(SKILL_DIR, "runtime", "HivisionIDPhotos"),
    ]
    for c in candidates:
        if c and os.path.isdir(os.path.join(c, "hivision")):
            return os.path.abspath(c)
    raise RuntimeError(
        "未找到 HivisionIDPhotos 项目。请先运行 scripts/setup.sh，或用 --repo 指定路径。"
    )


def main():
    ap = argparse.ArgumentParser(description="证件照生成管线")
    ap.add_argument("input", help="输入照片路径")
    ap.add_argument("out_dir", help="输出目录")
    ap.add_argument("--repo", default=None, help="HivisionIDPhotos 仓库路径（默认自动定位）")
    ap.add_argument("--bg", default="438edb", help="底色 hex，如 438edb/ffffff/d9001b")
    ap.add_argument("--width", type=int, default=295, help="证件照宽 px（一寸 295）")
    ap.add_argument("--height", type=int, default=413, help="证件照高 px（一寸 413）")
    ap.add_argument("--matting_model", default="hivision_modnet", help="抠图模型")
    ap.add_argument("--no-layout", action="store_true", help="不生成六寸排版照")
    args = ap.parse_args()

    hivision_dir = _resolve_hivision_dir(args.repo)
    sys.path.insert(0, hivision_dir)

    import cv2
    import numpy as np
    from hivision import IDCreator
    from hivision.creator.choose_handler import choose_handler
    from hivision.creator.layout_calculator import generate_layout_array, generate_layout_image
    from hivision.utils import add_background, save_image_dpi_to_bytes
    from hivision.error import FaceError

    os.makedirs(args.out_dir, exist_ok=True)
    creator = IDCreator()
    choose_handler(creator, args.matting_model, "mtcnn")
    base = os.path.splitext(os.path.basename(args.input))[0]

    img = cv2.imread(args.input, cv2.IMREAD_UNCHANGED)
    if img is None:
        sys.exit(f"[错误] 无法读取图片: {args.input}")

    # 1) 抠图 + 按规格对齐人脸 → 透明标准照（RGBA）
    try:
        result = creator(img, size=(args.height, args.width), face_alignment=True)
    except FaceError as e:
        sys.exit(f"[错误] 人脸检测失败（需单人正面照）: {e}")
    except Exception:
        result = creator(img, size=(args.height, args.width), face_alignment=False)

    # 2) 合成标准底色 → 标准证件照（3 通道 BGR）
    color_bgr = (int(args.bg[4:6], 16), int(args.bg[2:4], 16), int(args.bg[0:2], 16))
    std_rgba = add_background(result.standard, bgr=color_bgr, mode="pure_color").astype(np.uint8)
    std_bgr = cv2.cvtColor(std_rgba, cv2.COLOR_RGBA2BGR)

    std_path = os.path.join(args.out_dir, f"{base}_标准证件照_{args.width}x{args.height}.png")
    save_image_dpi_to_bytes(std_bgr, std_path, dpi=300)
    print(f"[OK] 标准证件照: {std_path}")

    # 高清透明图
    hd_path = os.path.join(args.out_dir, f"{base}_高清透明.png")
    save_image_dpi_to_bytes(cv2.cvtColor(result.hd, cv2.COLOR_RGBA2BGRA), hd_path, dpi=300)
    print(f"[OK] 高清透明图: {hd_path}")

    # 3) 六寸排版照（2×5 可直接冲印）
    if not args.no_layout:
        arr, rot = generate_layout_array(input_height=args.height, input_width=args.width)
        layout_img = generate_layout_image(std_bgr, arr, rot, height=args.height, width=args.width)
        layout_path = os.path.join(args.out_dir, f"{base}_六寸排版照.png")
        save_image_dpi_to_bytes(layout_img, layout_path, dpi=300)
        print(f"[OK] 六寸排版照: {layout_path}")


if __name__ == "__main__":
    main()
