"""
车牌检测训练脚本 (YOLO11n + CCPD2020 绿牌数据集)

用法:
    conda run -n lpr python train.py

说明:
    - 默认跑 10 epochs 验证全流程 (验证显存占用和单 epoch 耗时)
    - 验证没问题后, 把 epochs 改成 300 即可全量训练
    - 训练结果输出到 runs/detect/train*/ 目录
"""
from pathlib import Path

from ultralytics import YOLO

# 基于脚本所在目录自动定位路径 (从任何目录运行都能找到文件)
BASE_DIR = Path(__file__).resolve().parent


def main():
    # 预训练权重 (已下载到 weights/ 目录, 不会重新下载)
    model = YOLO(str(BASE_DIR / "weights" / "yolo11n.pt"))

    # 训练参数
    model.train(
        data=str(BASE_DIR / "datasets" / "CCPD2020" / "CCPD2020" / "ccpd_green" / "ccpd.yaml"),  # 数据集配置
        epochs=10,      # 验证阶段先跑 10 epochs; 全量训练改为 300
        batch=64,       # yolo11n 小模型, 8GB 显存无压力; 若 OOM 降到 32
        imgsz=640,      # 输入图片尺寸
        device=0,       # 0 = 第一张 NVIDIA 显卡 (RTX 3070)
        workers=2,      # Windows 上开太多 worker 会卡死/爆显存; 若仍卡则改 0
        project=str(BASE_DIR / "runs"),  # 输出目录
        name="plate",   # 本次训练名 -> runs/plate/
    )


if __name__ == "__main__":
    main()
