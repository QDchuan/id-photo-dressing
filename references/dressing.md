# 换正装策略（证件照的一键换装前置步骤）

「一键换正装」是把便装/生活照在生成证件照前替换为正式西装等服装。
本 skill 的 `pipeline.py` 只负责「抠图→换底→尺寸→排版」，**不内置换装模型**。
换装这一步按运行环境选择策略：

## 策略选择

| 运行环境 | 推荐做法 | 说明 |
| --- | --- | --- |
| 无 GPU（CPU only，内存小） | 用 AI 图像编辑能力做换装 | 把「人物照」作为参考图，指令模型把上衣换成深色正装西装+白衬衫，**强调保持人脸/发型/五官/构图不变** |
| 有 GPU（显存 ≥ 16GB） | 部署开源换装模型 IDM-VTON | 效果最专业，完全本地闭环 |

## 无 GPU：AI 图像编辑换装

这是默认路径（绝大多数 AI Agent 运行环境无 GPU）。步骤：

1. 获取用户人像照片（或一张示例人像）。
2. 把该照片作为参考图，调用图像编辑工具，prompt 形如：
   「将人物上半身的便装替换为合体的深蓝色正装西装外套，内搭白色衬衫，领型挺括、肩线合身，商务正式风格；**严格保持人物面部、五官、妆容、发型、发色完全不变**，姿态、构图、光影保持不变。」
3. 输出换装后的照片 → 交给 `pipeline.py` 生成证件照。

> 提示：保持原图宽高比；换装后用「证件照管线」自动抠图换底，背景杂乱没关系。

## 有 GPU：IDM-VTON

- 仓库：`https://github.com/yisol/IDM-VTON`（官方协议 **CC BY-NC-SA 4.0，非商用**）
- 部署：
  ```bash
  git clone https://github.com/yisol/IDM-VTON.git && cd IDM-VTON
  conda env create -f environment.yaml && conda activate idm
  # 下载人体解析权重（densepose/humanparsing/openpose，约 10GB）到 ckpt/
  python gradio_demo/app.py   # 上传「人像照 + 正装服装图」→ 输出换装照
  ```
- 整合：把 IDM-VTON 输出的换装照交给 `pipeline.py` 出证件照。
- 备选换装模型：OOTDiffusion、FASHN VTON v1.5、OpenTryOn。

## 关键提示

- **人物一致性**是证件照换装的核心：无论用哪种方式，都必须保留原人物面部/发型，只替换服装。
- 证件照建议准备「深色西装/白衬衫」的正式服装，与人物正面身位一致，效果最佳。
- 换装是**可选**前置步骤：如果用户已有正装照片，可直接跳过换装，直接用 `pipeline.py`。
