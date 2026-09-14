---
name: id-photo-dressing
description: 证件照生成与「一键换正装」技能。把普通/便装人像照变成合规标准证件照（抠图、换红/蓝/白底、标准一寸/二寸尺寸、六寸排版照可冲印），并支持先给人物一键换正装（便装→深色西装）再出证件照。AI 触发后应主动引导用户：优先推送可勾选的交互卡片（一键换底红/白/蓝 + 是否换正装 + 确认按钮），用户确认后引导其上传照片，再执行并直接把图片返给用户。当用户需要制作证件照、登记照、免冠照、求职/考试/签证照片，或要求「证件照换正装/换西装/换底色/换背景/排六寸照」时使用；也适用于把随手拍/生活照转成标准证件照的场景。首次使用前需运行 scripts/setup.sh 初始化环境。
---
# 证件照 + 一键换正装

## 用户引导流程（AI 与用户交互时必须遵守）

AI 触发本 skill 后，**不要直接让用户跑命令，也不要拿到一句话就闷头处理**。按以下四步主动引导用户：

### 1️⃣ 推送交互卡片（自动引导，体验最优）
用户提出证件照需求后，**自动推送一张可勾选的交互卡片**（环境支持飞书 lark-im 时）：
- **卡片模板**：`references/idphoto-card.json`（Card 2.0）
- **卡片内容**：
  - **一键换底**（**单选**）：蓝色（默认）/ 红色 / 白色（select_static 下拉）
  - **是否换正装**：深色西装+白衬衫（默认勾选）
  - **确认按钮**（点确认即提交选择）
- **发送**：用 lark-im 发送 `--msg-type interactive`，内容为模板 JSON。
- **读选择**：从回调 `action.form_value` 读 `bg`（blue/red/white 单选）与 `suit`（是否换正装）；回调不可达时请用户把选择用文字发来。卡片回调需在飞书开放平台配置（见 `references/onboarding.md`）。
- 环境不支持卡片时，退化为文字选项列表（见 `references/onboarding.md`）。

### 2️⃣ 引导用户发照片
确认选择后，提示用户上传**正面、单人、光线均匀**的人像照（避免多人/侧脸/逆光）。

### 3️⃣ 执行并返还图片
- 环境未初始化 → 先跑 `scripts/setup.sh`（幂等）。
- 勾选换正装 → 先换装（见 `references/dressing.md`），再跑 `pipeline.py`。
- 生成后**直接把图片返还给用户**（优先拼一张「效果一览」大图：原图→换装→证件照→排版照）。

### 4️⃣ 迭代确认
展示后主动问：「要不要换底色／换尺寸／换西装样式／出排版照？」按需重跑，直到满意。

> 详细话术与场景决策见 `references/onboarding.md`。

## 快速开始（首次使用必须初始化）

本 skill 依赖 HivisionIDPhotos 开源项目 + 抠图模型 + Python 依赖，**首次使用先运行初始化脚本**（幂等，可重复执行）：

```bash
bash <skill>/scripts/setup.sh
```

脚本会自动完成：clone 开源项目 → 下载模型 → 建虚拟环境 → 装依赖 → 冒烟测试。就绪后 `pipeline.py` 会自动定位 `<skill>/runtime/HivisionIDPhotos`，无需手动配置。

## 工作流决策树

```
用户请求
  ├─ 推送交互卡片（换底多选 + 换正装勾选）→ 用户确认
  ├─ 提示发照片
  ├─ 已有正装照片/未勾换装 → 直接生成证件照（pipeline.py）
  └─ 勾选换正装 → 先换装（references/dressing.md）→ 再生成证件照
```

## 任务：生成证件照

```bash
python scripts/pipeline.py <输入照片> <输出目录> [选项]
```

常用选项：

| 选项 | 说明 | 示例 |
| --- | --- | --- |
| `--bg` | 底色 hex | `438edb`蓝 / `d9001b`红 / `ffffff`白 |
| `--width --height` | 尺寸 px | 一寸 `295 413`、二寸 `413 579` |
| `--no-layout` | 不生成六寸排版照 | — |
| `--repo` | 指定 HivisionIDPhotos 路径 | 默认自动定位 |

输出 3 个产物：标准证件照（300DPI）+ 高清透明图 + 六寸排版照（2×5 可直接冲印）。

```bash
# 一寸蓝底
python scripts/pipeline.py 照片.jpg out/ --bg 438edb
# 二寸白底
python scripts/pipeline.py 照片.jpg out/ --bg ffffff --width 413 --height 579
```

## 任务：透明图换底色

对已有的透明证件照换红/蓝/白底：

```bash
python scripts/repaint_bg.py <透明png> <输出.png> d9001b   # 红底
```

## 任务：一键换正装（可选前置步骤）

- **默认路径（无 GPU）**：用 AI 图像编辑能力，把人像照作为参考图，指令「把便装换成深色西装+白衬衫，保持脸/发型不变」。
- **有 GPU 路径**：部署 IDM-VTON 后换装。
- 详细策略见 `references/dressing.md`，务必遵守「人物面部/发型一致性」核心要求。
- 换装后照片再交给 `pipeline.py` 出证件照。

## 分享给他人

- 分享时**不要**带 `runtime/` 目录（内含本机 venv，不可移植），只分享 `SKILL.md + scripts/ + references/`。
- 对方拿到后放进自己的 `.user_skills` 目录，再执行一次 `bash scripts/setup.sh` 即可完成初始化。
- 可用 `scripts/package.sh` 一键生成不含 runtime 的分享压缩包。

## 注意

- 依赖 `onnxruntime` / `mtcnn-runtime` / `opencv`，由 `setup.sh` 自动安装（复用系统 opencv/numpy）。
- 抠图模型需联网下载一次（各约 25MB），之后离线运行。
- 证件照需单人正面照；多人或侧脸会被人脸检测拒绝。
