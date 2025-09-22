#!/bin/sh
# 一键安装 luci-theme-design 最新版

set -e

BASE_URL="https://dl.openwrt.ai/releases/24.10/packages/aarch64_cortex-a53/kiddin9"
PKG="luci-theme-design"

echo "[1/3] 获取最新 $PKG 版本信息..."
FILENAME=$(curl -s $BASE_URL/Packages | awk -v pkg="$PKG" '
  $1=="Package:" && $2==pkg {found=1}
  found && $1=="Filename:" {print $2; exit}
')

if [ -z "$FILENAME" ]; then
  echo "未找到 $PKG 包，请检查架构或源地址！"
  exit 1
fi

URL="$BASE_URL/$FILENAME"
echo "[2/3] 已找到最新版本: $URL"

echo "[3/3] 开始安装..."
opkg update
opkg install "$URL"

echo "✅ $PKG 安装完成！"
