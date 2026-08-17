"""
将 CCPD 数据集转换为 YOLO 检测格式。

用法:
    python ccpd2yolo.py --data_path="datasets/CCPD2020/CCPD2020/ccpd_green"

最终目录结构:
    ccpd_green/
      images/
        train/   (jpg)
        val/     (jpg)
        test/    (jpg)
      labels/
        train/   (txt, 每行: class cx cy w h)
        val/     (txt)
        test/    (txt)
"""
import os
import argparse
import shutil
import cv2


def txt_translate(img_dir, label_dir, dst_img_dir):
    """ 把 jpg 文件名中编码的 bbox 信息转换为 YOLO txt 标签，并把图片移动到 images/ 目录 """
    os.makedirs(label_dir, exist_ok=True)
    os.makedirs(dst_img_dir, exist_ok=True)
    count = 0
    for filename in os.listdir(img_dir):
        if not filename.lower().endswith(".jpg"):
            continue
        list1 = filename.split("-", 3)          # 以 '-' 分割，取第 3 段为 bbox
        subname = list1[2]
        lt, rb = subname.split("_", 1)          # 以 '_' 分割成左上、右下两点
        lx, ly = lt.split("&", 1)
        rx, ry = rb.split("&", 1)
        width = int(rx) - int(lx)
        height = int(ry) - int(ly)              # bbox 宽高（像素）
        cx = float(lx) + width / 2
        cy = float(ly) + height / 2             # bbox 中心点（像素）

        img_path = os.path.join(img_dir, filename)
        img = cv2.imread(img_path)
        if img is None:                         # 删除损坏图片（下载过程可能产生）
            print("删除损坏图片:", img_path)
            os.remove(img_path)
            continue

        # 归一化到 [0,1]
        width = width / img.shape[1]
        height = height / img.shape[0]
        cx = cx / img.shape[1]
        cy = cy / img.shape[0]

        txtname = os.path.splitext(filename)[0]
        txtfile = os.path.join(label_dir, txtname + ".txt")
        with open(txtfile, "w") as f:
            f.write("0 {:.6f} {:.6f} {:.6f} {:.6f}\n".format(cx, cy, width, height))

        # 图片移动到 images/<split>
        shutil.move(img_path, os.path.join(dst_img_dir, filename))
        count += 1
    return count


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="CCPD -> YOLO 格式转换")
    parser.add_argument(
        "--data_path",
        type=str,
        default="datasets/CCPD2020/CCPD2020/ccpd_green",
        help="ccpd_green 数据目录（含 train/val/test 子目录）",
    )
    args = parser.parse_args()
    data_path = args.data_path

    total = 0
    for subdir in ["train", "val", "test"]:
        src = os.path.join(data_path, subdir)
        if not os.path.isdir(src):
            # 兼容已转换过的情况：图片已在 images/<subdir>
            src = os.path.join(data_path, "images", subdir)
        if not os.path.isdir(src):
            print("警告: 找不到目录", src, "，跳过")
            continue
        n = txt_translate(
            src,
            os.path.join(data_path, "labels", subdir),
            os.path.join(data_path, "images", subdir),
        )
        print("{}: 转换 {} 张".format(subdir, n))
        total += n
    print("完成，共转换 {} 张图片".format(total))
