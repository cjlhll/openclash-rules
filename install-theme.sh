#!/bin/sh
# 纯命令行选择安装 luci-theme

BASE_URL="https://dl.openwrt.ai/releases/24.10/packages/aarch64_cortex-a53/kiddin9"

echo "[1/3] 获取 luci-theme 列表..."
THEMES=$(curl -s $BASE_URL/Packages | awk '$1=="Package:" && $2 ~ /^luci-theme-/ {print $2}')

if [ -z "$THEMES" ]; then
    echo "未找到 luci-theme 包"
    exit 1
fi

# 转换为数组
i=1
declare -a THEME_ARRAY
for t in $THEMES; do
    echo "$i) $t"
    THEME_ARRAY[$i]=$t
    i=$((i+1))
done

# 用户输入选择编号
echo -n "请输入要安装的主题编号: "
read CHOICE

SELECTED=${THEME_ARRAY[$CHOICE]}

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
