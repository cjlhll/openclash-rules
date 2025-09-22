#!/bin/sh
# 安装 luci-theme-argon 最新版本（OpenWrt ash 兼容）
# 支持 ipk 和 apk 文件

API_URL="https://api.github.com/repos/jerrykuku/luci-theme-argon/releases/latest"

echo "[1/3] 获取 luci-theme-argon 最新 release 信息..."

# 获取 assets 中 browser_download_url，兼容 ipk 和 apk
URL=$(curl -s $API_URL | grep "browser_download_url" | grep "luci-theme-argon" | head -n 1 | cut -d '"' -f 4)

if [ -z "$URL" ]; then
    echo "未找到 luci-theme-argon 最新文件"
    exit 1
fi

FILENAME="/tmp/$(basename $URL)"
echo "[2/3] 下载 $URL 到 $FILENAME ..."
curl -L -o "$FILENAME" "$URL"

# 根据文件后缀判断安装方式
EXT="${FILENAME##*.}"

echo "[3/3] 安装 $FILENAME ..."
if [ "$EXT" = "ipk" ]; then
    opkg update
    opkg install "$FILENAME"
    echo "✅ luci-theme-argon ipk 安装完成！"
elif [ "$EXT" = "apk" ]; then
    echo "⚠️ 下载的是 APK 文件，OpenWrt 无法安装，只保存在 $FILENAME"
else
    echo "⚠️ 未知文件类型: $EXT，保存在 $FILENAME"
fi
