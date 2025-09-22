#!/bin/sh
# 安装 luci-theme-argon 最新版本（OpenWrt ash 兼容）

# GitHub API 获取最新 release
API_URL="https://api.github.com/repos/jerrykuku/luci-theme-argon/releases/latest"

echo "[1/3] 获取 luci-theme-argon 最新 release 信息..."

# 获取 assets 中 browser_download_url 链接
URL=$(curl -s $API_URL | grep "browser_download_url" | grep "luci-theme-argon.*\.ipk\|\.apk" | head -n 1 | cut -d '"' -f 4)

if [ -z "$URL" ]; then
    echo "未找到 luci-theme-argon 最新 ipk 文件"
    exit 1
fi

FILENAME="/tmp/$(basename $URL)"
echo "[2/3] 下载 $URL 到 $FILENAME ..."
curl -L -o "$FILENAME" "$URL"

echo "[3/3] 安装 $FILENAME ..."
opkg update
opkg install "$FILENAME"

echo "✅ luci-theme-argon 安装完成！"
