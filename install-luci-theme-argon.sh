#!/bin/sh

# 脚本：自动下载并安装最新版 luci-theme-argon
# 作者：AI助手
# 适用：OpenWrt 系统

set -e  # 遇错即停

echo "🔍 正在获取最新发布页..."

# 获取重定向后的最新发布页真实 URL（GitHub latest 会 302 重定向）
LATEST_URL=$(curl -sSL -o /dev/null -w "%{url_effective}" "https://github.com/jerrykuku/luci-theme-argon/releases/latest")

if [ -z "$LATEST_URL" ]; then
    echo "❌ 无法获取最新发布页，请检查网络或 GitHub 访问权限。"
    exit 1
fi

echo "📌 最新发布页: $LATEST_URL"

# 提取该页面中所有 luci-theme-argon*.ipk 的下载链接
IPK_URL=$(curl -s "$LATEST_URL" | grep -o 'href="[^"]*luci-theme-argon[^"]*\.ipk"' | head -1 | sed 's/href="//; s/"$//')

if [ -z "$IPK_URL" ]; then
    echo "❌ 未找到 luci-theme-argon*.ipk 文件。"
    exit 1
fi

# 补全完整下载链接（GitHub 的 href 是相对路径）
FULL_URL="https://github.com$IPK_URL"

echo "📥 下载地址: $FULL_URL"

FILENAME=$(basename "$FULL_URL")

echo "⏳ 正在下载 $FILENAME ..."

curl -L -o "/tmp/$FILENAME" "$FULL_URL"

if [ ! -f "/tmp/$FILENAME" ]; then
    echo "❌ 下载失败。"
    exit 1
fi

echo "✅ 下载完成。"

echo "📦 正在安装..."

opkg install "/tmp/$FILENAME"

if [ $? -eq 0 ]; then
    echo "🎉 luci-theme-argon 安装成功！"
    echo "💡 建议重启 LuCI 或浏览器清除缓存以应用新主题。"
else
    echo "❌ 安装失败，请检查依赖或手动安装。"
    exit 1
fi

# 可选：清理安装包
echo "🧹 清理临时文件..."
rm -f "/tmp/$FILENAME"

echo "✅ 脚本执行完毕。"
