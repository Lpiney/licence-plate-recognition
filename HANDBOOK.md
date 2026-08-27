# 车牌识别项目 · 完整操作手册

> 从环境搭建到最终系统的**全流程操作指南**，配合 `PROGRESS.md`（进度记录）使用。
> 本手册面向实际操作，所有命令均可直接复制。

---

## 📖 目录

1. [项目简介](#1-项目简介)
2. [硬件与环境](#2-硬件与环境)
3. [目录结构](#3-目录结构)
4. [环境搭建（一次性）](#4-环境搭建一次性)
5. [数据集准备（已完成）](#5-数据集准备已完成)
6. [模型训练](#6-模型训练)
7. [评估与调优](#7-评估与调优)
8. [检测推理](#8-检测推理)
9. [OCR 车牌识别（下一阶段）](#9-ocr-车牌识别下一阶段)
10. [常见问题 FAQ](#10-常见问题-faq)
11. [命令速查表](#11-命令速查表)

---

## 1. 项目简介

- **目标**：车牌检测（YOLO）+ 车牌识别（OCR）两阶段系统
  - 阶段 1（检测）：找到"车牌在哪" → YOLO11 目标检测
  - 阶段 2（识别）：读出"车牌号是什么" → PaddleOCR
- **参考项目**：[detect_ccpd](https://gitee.com/jacklee85/detect_ccpd)
- **数据集**：CCPD2020（绿牌/新能源车，train 5769 / val 1001 / test 5006 张）
- **训练框架**：Ultralytics YOLO11n（PyTorch 2.13.0 + CUDA 12.6）

---

## 2. 硬件与环境

| 项目 | 配置 | 用途 |
|---|---|---|
| 训练机 | i7-12700H + **RTX 3070 Laptop 8GB** + 16GB 内存 | 主力训练（CUDA） |
| 备用机 | MacBook M2 16GB | MPS 跑小模型验证/部署 |
| conda 环境 | `lpr`（Python 3.10.20） | 项目专用环境 |

**已验证**（`diag.py` 输出）：
- ✅ PyTorch 2.13.0+cu126（CUDA 版）
- ✅ CUDA 可用，识别到 RTX 3070 Laptop GPU，显存 8192 MB
- ✅ GPU 矩阵运算正常
- ✅ yolo11n 模型加载正常

**可训练模型范围**（8GB 显存）：

| 模型 | 参数量 | 可行性 |
|---|---|---|
| yolo11n | 2.6M | ✅ 推荐（本项目选用） |
| yolo11s | 9.4M | ✅ 可以（batch 建议 ≤32） |
| yolo11m | 20.1M | ⚠️ 勉强（batch 8 + 降 imgsz） |
| yolo11l / yolo11x | 25M+ | ❌ 超显存 |

---

## 3. 目录结构

```
<项目根目录>\
├── README.MD              # 项目说明（参考来源）
├── PROGRESS.md            # 进度记录（AI 助手维护）
├── HANDBOOK.md            # 本手册
├── ccpd2yolo.py           # CCPD → YOLO 格式转换脚本
├── download.ps1           # aria2 断点续传下载脚本
├── train.py               # 🔧 训练脚本（主入口）
├── diag.py                # 🔧 环境诊断脚本
├── test.py                # 空文件（预留：推理脚本）
├── datasets/
│   └── CCPD2020/
│       ├── CCPD2020.zip   # 原始压缩包（907MB）
│       └── CCPD2020/
│           └── ccpd_green/
│               ├── ccpd.yaml        # 数据集配置
│               ├── images/train|val|test/   # 图片
│               └── labels/train|val|test/   # YOLO 标签
├── weights/
│   └── yolo11n.pt         # 预训练权重
├── tools/aria2/           # aria2 便携版
└── runs/                  # (训练后生成) 训练输出
```

---

## 4. 环境搭建（一次性）

> ✅ 你的 `lpr` 环境已搭建完成，本节仅存档备查。

```powershell
# 1. 创建环境
conda create -n lpr python=3.10 -y

# 2. 激活
conda activate lpr

# 3. 安装依赖
pip install ultralytics opencv-python

# 4. 验证
python -c "import ultralytics, cv2; print(ultralytics.__version__, cv2.__version__)"
```

**💡 conda 激活的正确姿势**（重要）：
- ❌ 错误：`C:\...\conda.BAT activate lpr` —— 在 PowerShell 里**无效**（.BAT 在子进程运行，环境不传回）
- ✅ 正确：先执行一次 `<conda路径>\Scripts\conda.exe init powershell`，**关掉终端重开**，之后就能直接 `conda activate lpr`（提示符从 `(base)` 变成 `(lpr)`）
- ✅ 或者不激活，用 `conda run -n lpr python xxx.py`

---

## 5. 数据集准备（已完成）

### 5.1 下载（download.ps1）
```powershell
.\download.ps1 -Url "https://github.com/detectRecog/CCPD/archive/refs/heads/master.zip" -Proxy $null
```
> 特性：aria2 16 线程 + 断点续传 + 无限重试，中断后重跑脚本自动续传。

### 5.2 格式转换（ccpd2yolo.py）
CCPD 文件名内嵌标注信息，例如：
```
025-95_113-154&383_386&473-386&473_177&454_154&383_363&402-0_0_22_27_27_33_16-37-15.jpg
     │         └──────┬──────┘
     │         第3段: 左上&右下 bbox 坐标
     └ 段位说明: 面积/纵横比-bbox-四角点-车牌字符-亮度
```
转换脚本解析第 3 段坐标 → 归一化 → 生成 YOLO txt 标签：
```
# labels/train/025-....txt
0 0.5123 0.4567 0.1234 0.0456   # class cx cy w h (归一化)
```

### 5.3 数据集配置（ccpd.yaml）
```yaml
path: D:/Github/licence-plate-recognition/datasets/CCPD2020/CCPD2020/ccpd_green
train: images/train
val: images/val
test: images/test
nc: 1            # 1 个类别
names: ['plate'] # 类别名: 车牌
```

---

## 6. 模型训练

### 6.1 训练脚本（train.py）

```powershell
# 已激活 lpr 环境时（推荐）:
python <项目根目录>\train.py

# 未激活时:
<conda路径>\Library\bin\conda.BAT run --no-capture-output -n lpr python <项目根目录>\train.py
```

> 脚本已内置路径自动定位（基于 `__file__`），**从任何目录运行都能找到数据**。
> ⚠️ 务必用 `--no-capture-output`，否则 `conda run` 会缓冲输出，看起来像卡死。

### 6.2 参数详解

| 参数 | 当前值 | 全量值 | 说明 |
|---|---|---|---|
| `epochs` | 10 | **300** | 训练轮数（验证改全量时改这里） |
| `batch` | 64 | 64 | 每批图片数；OOM 就降到 32 |
| `imgsz` | 640 | 640 | 输入分辨率，越高越准但越慢 |
| `device` | 0 | 0 | GPU 编号（0 = RTX 3070） |
| `workers` | 8 | 8 | 数据加载线程数 |
| `project` | runs | runs | 输出根目录 |
| `name` | plate | plate | 本次训练名 → `runs/plate/` |

### 6.3 训练过程输出解读

```
      Epoch    GPU_mem   box_loss   cls_loss   dfl_loss  Instances   Size
       1/10      3.2G      1.152      1.089      1.152          2    640
```
- **GPU_mem**：显存占用，>7G 危险
- **box_loss**：检测框损失，应从 ~1.1 持续下降
- 每轮结束显示耗时，如 `1/10 0.05 hours`，×300 即全量预估时间

### 6.4 中断后续训（resume）

```python
# train.py 里改为:
model.train(resume=True)  # 自动找到上次中断的训练
# 或命令行:
yolo detect train resume=True
```

### 6.5 实时监控（训练时必看）

训练要跑几小时，实时监控能帮你随时掌握进度。**两种方案搭配用**：

#### 方案 A：TensorBoard（推荐，看训练曲线）

1. **训练前安装一次**：
   ```powershell
   python -m pip install tensorboard
   ```
2. **开两个终端**：
   - 终端 1：跑训练 `python <项目根目录>\train.py`
   - 终端 2：启动 TensorBoard：
     ```powershell
     tensorboard --logdir <项目根目录>\runs
     ```
3. **浏览器打开**：`http://localhost:6006`

能实时看到：box_loss / cls_loss / dfl_loss 曲线、学习率、mAP、precision、recall。
> 判断标准：loss 持续下降 = 健康；**曲线变平** = 可能到瓶颈；**loss 上升** = 过拟合前兆。

#### 方案 B：GPU 状态监控（看显存/温度）

```powershell
nvidia-smi -l 2
```
每 2 秒刷新一次（Ctrl+C 退出）。精简版（只看关键指标）：
```powershell
nvidia-smi -l 2 --query-gpu=utilization.gpu,memory.used,temperature.gpu --format=csv
```
> 训练时正常：利用率 80-100%，显存 3-7GB，温度 <85°C。显存 >7GB 有爆显存风险。

### 6.6 全量训练操作步骤

1. 用记事本/VSCode 打开 `train.py`
2. 把 `epochs=10` 改为 `epochs=300`
3. 保存，重新运行第 6.1 节命令
4. 训练约 1.5-3 小时（yolo11n），期间可正常用电脑但别开大程序

---

## 7. 评估与调优

### 7.1 训练结果文件（runs/plate/）

| 文件 | 内容 |
|---|---|
| `weights/best.pt` | 验证集最优权重（**部署用这个**） |
| `weights/last.pt` | 最后一轮权重（续训用） |
| `results.png` | 训练曲线总览 |
| `confusion_matrix.png` | 混淆矩阵 |
| `val_batch*.jpg` | 验证集预测可视化 |
| `args.yaml` | 本次训练全部参数 |

### 7.2 指标含义

| 指标 | 含义 | 好模型标准 |
|---|---|---|
| mAP50 | IoU=0.5 时的平均精度 | >0.95（单类检测容易达标） |
| mAP50-95 | 多 IoU 阈值平均 | >0.85 |
| Precision | 检出框中真车的比例 | >0.95 |
| Recall | 真车牌被检出的比例 | >0.95 |

### 7.3 调优方向

| 问题 | 手段 |
|---|---|
| 欠拟合（loss 高、mAP 低） | 加 epochs、换大模型（s/m）、加大 imgsz |
| 过拟合（val 指标差、train 好） | 早停、数据增强、减小模型 |
| 漏检 | 降 `conf` 阈值、数据增强 |
| 误检 | 升 `conf` 阈值 |

---

### 7.4 怎么看训练结果图（results.png + 预测图）

**训练曲线 `results.png`**（10 个子图，上行=训练集，下行=验证集）：

| 图 | 看什么 | 好标准 |
|---|---|---|
| 6 个 loss 图（box/cls/dfl） | 是否**持续下降** | 平滑线一路向下 |
| precision | 检出准确率 | 稳定高位 |
| recall | 检出率 | 稳定高位 |
| mAP50 / mAP50-95 | 综合精度 | 越高越好，**最后还在涨 = 值得继续训** |

读图要点：
- 🔵 实线 = 每 epoch 实际值（波动正常）；🟠 虚线 smooth = 趋势
- 初期（epoch 1-2）波动大是**正常适应**，看后段趋势
- **最右下角 `mAP50-95`：若仍在上升，表明还有潜力，应加 epochs**

**预测效果图 `val_batch0_pred.jpg`**（验证集预测可视化）：
- 蓝框 + `plate 置信度` 标签 = 检测结果
- 置信度 0.9 以上算精准；0.7 左右说明场景较难（暗/模糊），已能框住

---

## 8. 检测推理

> 当前未实现，训练完成后补全。预期脚本 `test.py` 用法：

```python
from ultralytics import YOLO

model = YOLO("runs/plate/weights/best.pt")  # 用训练好的权重

# 单张图片
model.predict("test.jpg", conf=0.25, save=True)

# 视频
model.predict("video.mp4", conf=0.25, save=True)

# 摄像头实时
model.predict(source=0, conf=0.25, show=True)
```

---

## 9. OCR 车牌识别（下一阶段）

### 9.1 方案对比

| 方案 | 优点 | 缺点 |
|---|---|---|
| A. PaddleOCR 通用模型 | 开箱即用 | 对车牌字符（特殊字体）精度一般 |
| B. 车牌专用识别模型 | 精度高 | 需要额外训练/找模型 |
| C. PaddleOCR 微调 | 兼顾两者 | 需要车牌字符标注数据 |

### 9.2 推荐路线

1. 用 YOLO 检测框裁剪车牌 → `plate_crops/`
2. 安装 PaddleOCR：
   ```powershell
   pip install paddlepaddle paddleocr
   ```
3. 对裁剪图做 OCR → 输出车牌号
4. （进阶）用 CCPD 文件名的字符段标注微调模型

---

## 10. 常见问题 FAQ

### Q1: OSError: [WinError 1455] 页面文件太小
**原因**：物理内存被占满，PyTorch 框架加载失败。
**解决**：重启电脑；训练时关闭浏览器/Steam/KOOK/壁纸引擎；还不行就调大虚拟内存（控制面板 → 系统 → 高级系统设置 → 性能 → 虚拟内存 → 自定义，设 16-32GB）。

### Q2: 提示符一直是 (base)，conda activate 没反应
**原因**：用 `conda.BAT activate` 在 PowerShell 里无效。
**解决**：执行 `conda init powershell` 后重启终端；或用 `conda run -n lpr python xxx.py` 免激活。

### Q3: 找不到 yolo 命令 / No module named ultralytics.__main__
**原因**：`yolo` 是 CLI 入口；`python -m ultralytics` 不存在。
**解决**：激活环境后用 `yolo ...`，或直接 `python train.py`。

### Q4: conda run 跑训练没输出/像卡死
**原因**：`conda run` 默认缓冲输出。
**解决**：加 `--no-capture-output`。

### Q5: 长命令粘贴报 SyntaxError
**原因**：PowerShell 粘贴长命令时被换行截断。
**解决**：所有逻辑写入脚本文件（train.py / diag.py），只运行短命令。

### Q6: SSL: CERTIFICATE_VERIFY_FAILED（GitHub 下载失败）
**原因**：网络/证书问题，ultralytics 想联网下载权重。
**解决**：本地已有 `weights/yolo11n.pt` 时不影响（训练指定本地文件即可）；必要时挂代理。

### Q7: CUDA out of memory
**解决**：`train.py` 里 `batch=64` 降到 `32` 或 `16`；关掉其他占显存的程序。

---

## 11. 命令速查表

| 用途 | 命令 |
|---|---|
| 激活环境 | `conda activate lpr` |
| 环境诊断 | `python <项目根目录>\diag.py` |
| 训练（激活后） | `python <项目根目录>\train.py` |
| 训练（免激活） | `<conda路径>\Library\bin\conda.BAT run --no-capture-output -n lpr python <项目根目录>\train.py` |
| 初始化 conda 到 PowerShell | `<conda路径>\Scripts\conda.exe init powershell`（需重启终端） |
| 查看训练结果 | `dir <项目根目录>\runs\plate` |
| 查看 GPU 状态 | `nvidia-smi` |

---

*手册由 AI 助手维护，随项目进展持续更新。*
