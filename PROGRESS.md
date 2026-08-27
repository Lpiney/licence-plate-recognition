# 车牌识别项目 · 进度记录

> 本文档由 AI 助手同步维护，记录项目进度、操作步骤与问题排查。
> 最后更新：2026-08-26

---

## 一、项目概览

- **目标**：车牌检测（YOLO）+ 车牌识别（OCR）完整系统
- **参考项目**：[detect_ccpd](https://gitee.com/jacklee85/detect_ccpd)（YOLO 车牌检测）
- **OCR 方案**：[PaddleOCR](https://github.com/PaddlePaddle/PaddleOCR)
- **数据集**：CCPD2020（绿牌/新能源车，约 1.2 万张）
- **代码仓库**：`D:\Github\licence-plate-recognition`

---

## 二、硬件配置

| 部件 | 型号 | 说明 |
|---|---|---|
| CPU | i7-12700H | 14 核 20 线程 |
| 内存 | 16 GB | 训练时建议关掉浏览器/Steam 等 |
| GPU | **RTX 3070 Laptop (8GB)** | CUDA 12.7 ✅ 主力训练机 |
| 驱动 | 566.07 | 支持 CUDA 12.7 |
| 备用机 | MacBook M2 16GB | 可用 MPS 跑小模型（慢 3-4 倍），适合验证/部署 |

### 可用模型范围（8GB 显存）

| 模型 | 参数量 | 结论 |
|---|---|---|
| yolo11n | 2.6M | ✅ 推荐（用户选定） |
| yolo11s | 9.4M | ✅ 可以 |
| yolo11m | 20.1M | ⚠️ 勉强 |
| yolo11l / x | 25M+ | ❌ 超显存 |

---

## 三、完整流程（5 阶段 14 步）

```
阶段一 数据准备     阶段二 训练评估     阶段三 检测推理     阶段四 OCR 识别     阶段五 系统集成
  1.环境 ✅          5.训练 ⏳           9.推理脚本         11.裁剪车牌         14.检测+识别串联
  2.下载 ✅          6.指标评估          10.阈值调优         12.PaddleOCR/专用模型
  3.格式转换 ✅      7.调参迭代                               13.输出车牌号
  4.划分+配置 ✅     8.定稿 best.pt
```

| 阶段 | 步骤 | 状态 |
|---|---|---|
| 一、数据准备 | 1. 环境搭建（conda lpr: Python 3.10.20 + ultralytics 8.4.120 + cv2 4.10.0） | ✅ |
| | 2. 数据集下载（CCPD2020.zip 907MB，aria2 断点续传） | ✅ |
| | 3. 格式转换（`ccpd2yolo.py`：文件名 → YOLO 标签） | ✅ |
| | 4. 划分数据集（train 5769 / val 1001 / test 5006）+ `ccpd.yaml` | ✅ |
| 二、训练评估 | 5. 模型训练（yolo11n，10 epochs 验证） | ✅ 完成 |
| | 6. mAP50 / mAP50-95 / P / R 评估（mAP50=0.994, mAP50-95=0.849） | ✅ 完成 |
| | 7. 调参迭代 / 全量训练（改 epochs=300） | ⏳ **当前** |
| | 8. 确定 best.pt | ⬜ |
| 三、检测推理 | 9. 推理脚本（图片/视频/摄像头 → 车牌框） | ⬜ |
| | 10. conf / iou 阈值调优 | ⬜ |
| 四、OCR 识别 | 11. 裁剪车牌区域 | ⬜ |
| | 12. PaddleOCR 或车牌专用识别模型 | ⬜ |
| | 13. 输出车牌号（如 皖A·D12345） | ⬜ |
| 五、系统集成 | 14. 检测+识别 pipeline（可选：摄像头/API/界面） | ⬜ |

---

## 四、问题排查记录

### 🐛 问题 8：为什么每次跑都内存溢出（根因总结）（✅ 已提供一键方案）
- **根因**：Windows 下训练失败/中断会留下**孤儿 python 进程**（最多攒 31 个），吃光内存显存 → 下次训练启动失败 → 更多残留 → 恶性循环
- **补充**：Windows DataLoader（workers）每个子进程复制一份 CUDA 环境，占显存翻倍
- **一劳永逸**：`start_train.ps1` 一键脚本 = 自动清理残留 + 启动训练，以后只跑这一个
- **状态**：✅ 已解决（脚本已创建）

### 🐛 问题 7：训练卡死在数据加载（workers 太多）（✅ 已解决）
- **现象**：训练进程启动后 CPU 停止增长（卡死），GPU 显存被占满 7.7GB，TensorBoard 显示 no dashboards
- **原因**：Windows 上 `workers=8` 的 DataLoader 用 spawn 模式，**每个 worker 都初始化 CUDA 占显存**，spawn 出 20+ 个 worker 把 8GB 显存吃光后主进程卡死
- **解决**：杀掉全部进程 → 显存恢复 674MB；`train.py` 的 `workers` 改为 **2**（还卡就改 0）
- **自查命令**：`nvidia-smi` 看显存占用；训练卡死时 `Get-Process python* | Stop-Process -Force`
- **状态**：✅ 已解决

### 🐛 问题 6：残留 python 进程吃光内存（✅ 已解决）
- **现象**：再次报 `WinError 1455`，这次加载 `nvperf_host.dll` 失败
- **原因**：之前多次失败的训练尝试留下 **31 个 python 僵尸进程**，物理内存仅剩 0.7 GB
- **解决**：清掉全部残留进程 → 可用内存恢复到 10 GB
- **自查命令**：
  ```powershell
  Get-Process python* | Stop-Process -Force   # 清残留（训练前可先跑）
  ```
- **状态**：✅ 已解决

### 🐛 问题 1：OSError: [WinError 1455] 页面文件太小
- **现象**：加载 `torch_python.dll` 失败
- **原因**：物理内存被桌面程序占满，PyTorch 框架加载需要数 GB 内存
- **解决**：重启电脑 + 训练时关闭浏览器/Steam/KOOK/壁纸引擎
- **状态**：✅ 已解决

### 🐛 问题 2：`yolo` 命令找不到
- **现象**：`无法将"yolo"项识别为 cmdlet...`
- **原因**：PowerShell 里用 `conda.BAT activate lpr` 激活**无效**（.BAT 在子进程运行，环境不传回终端），提示符一直停留在 `(base)`
- **正确做法**：不用激活，直接用 `conda run -n lpr ...`
- **状态**：✅ 已解决

### 🐛 问题 3：`python -m ultralytics` 报错
- **现象**：`No module named ultralytics.__main__`
- **原因**：ultralytics 没有 `__main__` 入口，不能这样调用
- **正确做法**：`conda run -n lpr python train.py`（或 `yolo` 命令 / `python -c` API）
- **状态**：✅ 已解决

### 🐛 问题 4：train.py 卡死（✅ 已定位解决）
- **现象**：`conda run` 跑 `train.py` 后无输出，进程 CPU 停止增长，GPU 利用率 2%
- **原因**：① `conda run` 默认缓冲输出导致看不到进度（假卡死）；② 部分加载环节确实较慢
- **对策**：加 `--no-capture-output` 实时看输出；`diag.py` 诊断确认 CUDA/模型正常
- **结果**：`diag.py` 全部通过（PyTorch 2.13.0+cu126 / CUDA True / RTX 3070 8192MB / GPU 运算 OK / 模型加载 OK）
- **状态**：✅ 已解决，`train.py` 已改为路径自动定位，可直接训练

### 🐛 问题 5：长命令粘贴被截断
- **现象**：`SyntaxError: '(' was never closed`，命令断在 `print('cuda可用:',` 处
- **原因**：PowerShell 粘贴超长含中文/引号命令时被换行截断
- **对策**：不再让用户复制长命令，改为**写脚本文件**（`diag.py` / `train.py`），用户只跑短命令
- **状态**：✅ 已规避（后续所有命令都走脚本文件）

---

## 五、常用命令速查

### 一键训练（推荐：自动清理残留 + 启动）
```powershell
powershell -ExecutionPolicy Bypass -File D:\Github\licence-plate-recognition\start_train.ps1
```

### 快速诊断（推荐：先跑这个）
```powershell
# 已激活 lpr 环境时:
cd D:\Github\licence-plate-recognition
python diag.py
# 未激活时:
C:\Users\Bruce\miniconda3\Library\bin\conda.BAT run --no-capture-output -n lpr python D:\Github\licence-plate-recognition\diag.py
```
> 检查项：PyTorch 版本 / CUDA 可用性 / 显卡名 / 显存 / GPU 运算测试 / 模型加载

### 修复 conda 激活（可选，一劳永逸）
```powershell
C:\Users\Bruce\miniconda3\Scripts\conda.exe init powershell
# 然后关闭终端重开，即可使用 conda activate lpr
```

### 训练脚本参数（train.py 内可改）
| 参数 | 当前值 | 说明 |
|---|---|---|
| epochs | 10 | 验证用；全量训练改 300 |
| batch | 64 | OOM 则降到 32 |
| imgsz | 640 | 输入尺寸 |
| device | 0 | RTX 3070 |
| workers | 8 | 数据加载线程 |

---

## 六、项目文档

| 文件 | 内容 |
|---|---|
| `HANDBOOK.md` | 📘 **完整操作手册**：环境/数据/训练/推理/OCR/FAQ/命令速查 |
| `PROGRESS.md` | 📊 进度记录（本文件） |
| `README.MD` | 项目说明与参考来源 |

---

## 七、训练结果（10 epochs 验证完成 ✅）

**训练时间**：2026-08-27 9:20 → 9:46（约 26 分钟，10 epochs）
**输出目录**：`runs/plate-3/`

| 指标（epoch 10） | 数值 |
|---|---|
| **mAP50** | **0.9937** |
| **mAP50-95** | **0.849** |
| Precision | 0.993 |
| Recall | 0.983 |
| train box_loss | 0.745 → 0.491（持续下降 ✅）|
| val box_loss | 0.733 → 0.606（健康 ✅）|
| 单 epoch 耗时 | ~154 秒（2.6 分钟）|

**结论**：
- ✅ 全流程验证通过（数据 → 训练 → 评估 → best.pt 输出）
- ✅ mAP50 已超 99%，mAP50-95 仍在上升趋势（**未过拟合**，可继续训练）
- ⏱️ 全量 300 epochs 预计约 **13 小时**（可挂机过夜）
- 📊 可视化：`runs/plate-3/val_batch0_pred.jpg`（预测图）、`results.png`（曲线）

**下一步**：
1. ▶️ 全量训练：`train.py` 改 `epochs=300`，用 `start_train.ps1` 启动
2. 训练完成后评估最终指标 → 写推理脚本（test.py）→ OCR 集成

---

*由 AI 助手持续维护，每次操作后更新。*
