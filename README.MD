instruction:`https://gitee.com/jacklee85/detect_ccpd`

original text:
```
detect_ccpd
介绍
采用YOLO训练一个车牌检测模型

安装教程
Install the ultralytics package from PyPI pip install ultralytics

install openCV pip install opencv-python

数据集
下载数据集 CCPD数据集 可以先选择 ccpd 2020，这个数据集比较小。

数据集转换为YOLO格式 unzip CCPD2020.zip python ccpd2yolo.py --data_path="CCPD2020/ccpd_green"

整理好数据集的格式

images
train
val
test
labels
train
val
test
训练模型 yolo settings tensorboard=True yolo detect train model=yolo11n.pt epochs=300
data=CCPD2020/ccpd_green/ccpd.yaml
batch=100
```



OCR System:`https://github.com/PaddlePaddle/PaddleOCR`


