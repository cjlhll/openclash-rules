#!/bin/sh
# OpenWrt ash 兼容版本111 - 命令行选择安装 luci-theme

BASE_URL="https://dl.openwrt.ai/releases/24.10/packages/aarch64_cortex-a53/kiddin9"

echo "[1/3] 获取 luci-theme 列表..."
THEMES=$(curl -s $BASE_URL/Packages | awk '$1=="Package:" && $2 ~ /^luci-theme-/ {print $2}')

if [ -z "$THEMES" ]; then
    echo "未找到 luci-theme 包"
    exit 1
fi

# 输出带编号的列表，写入临时文件
TMPFILE=$(mktemp)
i=1
echo "$THEMES" | while read t; do
    echo "$i) $t"
    echo "$i:$t" >> $TMPFILE
    i=$((i+1))
done

# 用户输入选择编号
echo -n "请输入要安装的主题编号: "
read CHOICE

# 从临时文件中获取对应包名
SELECTED=$(grep "^$CHOICE:" $TMPFILE | cut -d: -f2)
rm $TMPFILE

if [ -z "$SELECTED" ]; then
    echo "无效选择，退出"
    exit 1
fi

echo "[2/3] 获取 $SELECTED 最新版本..."
FILENAME=$(curl -s $BASE_URL/Packages | awk -v pkg="$SELECTED" '
  $1=="Package:" && $2==pkg {found=1}
  found && $1=="Filename:" {print $2; exit}
')

if [ -z "$FILENAME" ]; then
    echo "未找到 $SELECTED 包"
    exit 1
fi

URL="$BASE_URL/$FILENAME"
echo "[3/3] 安装 $SELECTED..."
opkg update
opkg install "$URL"

echo "✅ $SELECTED 安装完成！"
