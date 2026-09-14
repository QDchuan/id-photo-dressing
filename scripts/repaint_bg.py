#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
透明证件照换底色工具：输入 RGBA 透明 PNG，输出指定底色证件照。

用法：python repaint_bg.py <透明png> <输出.png> [bg_hex]
默认 bg_hex = d9001b（红底）。常用：438edb(蓝) / ffffff(白) / d9001b(红)
"""
import os
import sys

# ---- 内联 gradio stub（同 pipeline.py，避免美颜插件导入失败）----
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
        sys.modules["gradio"] = types.SimpleNamespace(
            Blocks=_B, Markdown=_C, Image=_C, Slider=_C,
            Row=_C, Button=_C, Textbox=_C, Column=_C,
        )

HERE = os.path.dirname(os.path.abspath(__file__))
SKILL_DIR = os.path.dirname(HERE)


def _resolve_hivision_dir():
    env = os.environ.get("HIVISION_DIR", "")
    if env and os.path.isdir(os.path.join(env, "hivision")):
        return os.path.abspath(env)
    default = os.path.join(SKILL_DIR, "runtime", "HivisionIDPhotos")
    if os.path.isdir(os.path.join(default, "hivision")):
        return os.path.abspath(default)
    raise RuntimeError("未找到 HivisionIDPhotos，请先运行 scripts/setup.sh")


def main():
    if len(sys.argv) < 3:
        sys.exit("用法: python repaint_bg.py <透明png> <输出.png> [bg_hex]")
    input_path, output_path = sys.argv[1], sys.argv[2]
    bg = sys.argv[3] if len(sys.argv) > 3 else "d9001b"

    sys.path.insert(0, _resolve_hivision_dir())
    import cv2
    import numpy as np
    from hivision.utils import add_background, save_image_dpi_to_bytes

    img = cv2.imread(input_path, cv2.IMREAD_UNCHANGED)
    if img is None:
        sys.exit(f"[错误] 无法读取: {input_path}")
    if img.shape[2] != 4:
        sys.exit("[错误] 输入需为 RGBA 透明 PNG")

    color_bgr = (int(bg[4:6], 16), int(bg[2:4], 16), int(bg[0:2], 16))
    out = add_background(img, bgr=color_bgr, mode="pure_color").astype(np.uint8)
    out = cv2.cvtColor(out, cv2.COLOR_RGBA2BGR)
    os.makedirs(os.path.dirname(os.path.abspath(output_path)), exist_ok=True)
    save_image_dpi_to_bytes(out, output_path, dpi=300)
    print(f"[OK] {output_path}")


if __name__ == "__main__":
    main()
