#!/bin/sh
# 交互式安装 luci-theme

BASE_URL="https://dl.openwrt.ai/releases/24.10/packages/aarch64_cortex-a53/kiddin9"

# 检查是否安装了 whiptail
if ! command -v whiptail >/dev/null 2>&1; then
    echo "请先安装 whiptail: opkg update && opkg install whiptail"
    exit 1
fi

echo "[1/3] 获取 luci-theme 列表..."
# 从 Packages 文件里抓取所有 luci-theme 包
THEMES=$(curl -s $BASE_URL/Packages | awk '
  $1=="Package:" && $2 ~ /^luci-theme-/ {print $2}
')

if [ -z "$THEMES" ]; then
    echo "未找到 luci-theme 包"
    exit 1
fi

# 构建 whiptail 菜单参数
MENU_ITEMS=""
for t in $THEMES; do
    MENU_ITEMS="$MENU_ITEMS $t ''"
done

# 弹出菜单选择主题
CHOICE=$(whiptail --title "选择要安装的 luci-theme" --menu "Use UP/DOWN keys to select" 20 70 15 $MENU_ITEMS 3>&1 1>&2 2>&3)

if [ -z "$CHOICE" ]; then
    echo "未选择主题，退出"
    exit 0
fi

echo "[2/3] 获取 $CHOICE 最新版本..."
FILENAME=$(curl -s $BASE_URL/Packages | awk -v pkg="$CHOICE" '
  $1=="Package:" && $2==pkg {found=1}
  found && $1=="Filename:" {print $2; exit}
')

if [ -z "$FILENAME" ]; then
    echo "未找到 $CHOICE 包"
    exit 1
fi

URL="$BASE_URL/$FILENAME"
echo "[3/3] 安装 $CHOICE..."
opkg update
opkg install "$URL"

echo "✅ $CHOICE 安装完成！"
