"""
环境诊断脚本：检查 PyTorch / CUDA / 模型加载是否正常。
用法:
    conda run --no-capture-output -n lpr python diag.py
    或 (已激活 lpr 环境时):
    python diag.py
"""
import torch

print("=" * 50)
print("1. PyTorch 版本:", torch.__version__)
print("2. CUDA 是否可用:", torch.cuda.is_available())
if torch.cuda.is_available():
    print("3. 显卡名称:", torch.cuda.get_device_name(0))
    print("4. 显存总量: {:.0f} MB".format(torch.cuda.get_device_properties(0).total_memory / 1024 / 1024))
    # 实际跑一个 GPU 运算测试
    a = torch.rand(1000, 1000, device="cuda")
    b = (a @ a).sum().item()
    print("5. GPU 矩阵运算测试: OK (结果 {:.2f})".format(b))
else:
    print("3. 警告: CUDA 不可用! 训练将走 CPU, 会非常慢")
    raise SystemExit("CUDA 不可用, 请检查驱动/安装的 PyTorch 版本")

print("-" * 50)
print("6. 加载 ultralytics ...")
from ultralytics import YOLO

m = YOLO("weights/yolo11n.pt")
print("7. yolo11n 模型加载: OK")
print("=" * 50)
print("全部检查通过, 可以开始训练!")
