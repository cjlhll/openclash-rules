#!/bin/sh
# 一键安装 OpenClash 脚本
# 适用于 OpenWrt 系统
# 从 vernesong/OpenClash 官方仓库获取最新 Pre-release IPK 文件

set -e

echo "=================================================="
echo "            OpenClash 一键安装脚本"
echo "=================================================="
echo "源仓库: https://github.com/vernesong/OpenClash"
echo "版本类型: Pre-release 优先，Release 备选"
echo "目标: luci-app-openclash*.ipk"
echo "=================================================="
echo ""

echo "[1/4] 更新软件源..."
opkg update

echo "[2/4] 安装依赖包..."

# 预先清理可能存在的配置文件备份
echo "[*] 预清理配置文件备份..."
for backup_file in /etc/config/*-opkg; do
    if [ -f "$backup_file" ]; then
        echo "[*] 删除已存在的备份: $backup_file"
        rm -f "$backup_file"
    fi
done

# 安装必要依赖
echo "[*] 安装 OpenClash 依赖包..."

# OpenClash 必需依赖
DEPS="bash iptables dnsmasq-full curl ca-bundle ipset ip-full iptables-mod-tproxy iptables-mod-extra ruby ruby-yaml kmod-tun kmod-inet-diag unzip"

# 处理 dnsmasq/dnsmasq-full 冲突
if opkg list-installed | grep -q "^dnsmasq-full "; then
    echo "[*] 检测到 dnsmasq-full 已安装，跳过 dnsmasq 处理..."
else
    if opkg list-installed | grep -q "^dnsmasq "; then
        echo "[*] 替换 dnsmasq 为 dnsmasq-full..."
        opkg remove dnsmasq
    else
        echo "[*] 未检测到 dnsmasq，将安装 dnsmasq-full..."
    fi
fi

# 安装依赖（不强制覆盖）
opkg install $DEPS || {
    echo "[!] 部分依赖安装失败，继续安装 OpenClash..."
}

echo "[3/4] 获取最新 OpenClash Pre-release ipk..."

# 从 vernesong/OpenClash 官方仓库获取最新 Pre-release 版本
echo "[*] 从 vernesong/OpenClash 官方仓库获取最新 Pre-release 版本..."

# 检查必要的命令
if ! command -v jq >/dev/null 2>&1; then
    echo "[*] 安装 jq 用于 JSON 解析..."
    opkg install jq >/dev/null 2>&1 || {
        echo "[!] 无法安装 jq，将使用备用解析方法"
        USE_JQ=false
    }
else
    USE_JQ=true
fi

# 获取所有 releases（包括 pre-release）
REPO_API="https://api.github.com/repos/vernesong/OpenClash/releases"
echo "[*] 获取 releases 列表..."

RELEASES_JSON=$(curl -s "$REPO_API" || {
    echo "[!] 获取 releases 信息失败，尝试使用加速镜像..."
    curl -s "https://gh-proxy.com/$REPO_API" || {
        echo "[!] 无法获取 releases 信息，请检查网络连接"
        exit 1
    }
})

LATEST_URL=""
LATEST_VERSION=""

# 添加调试信息
echo "[*] 调试信息: 检查获取到的数据..."
TOTAL_RELEASES=$(echo "$RELEASES_JSON" | jq '. | length' 2>/dev/null || echo "unknown")
echo "[*] 总共找到 $TOTAL_RELEASES 个 releases"

if [ "$USE_JQ" = "true" ]; then
    # 使用 jq 解析 JSON
    echo "[*] 搜索最新的 Pre-release 版本..."
    
    # 查找第一个 prerelease: true 的版本
    PRERELEASE_COUNT=$(echo "$RELEASES_JSON" | jq '[.[] | select(.prerelease == true)] | length' 2>/dev/null || echo "0")
    echo "[*] 找到 $PRERELEASE_COUNT 个 Pre-release 版本"
    
    if [ "$PRERELEASE_COUNT" -gt 0 ]; then
        # 获取最新的 Pre-release 信息
        LATEST_PRERELEASE=$(echo "$RELEASES_JSON" | jq '[.[] | select(.prerelease == true)][0]')
        LATEST_VERSION=$(echo "$LATEST_PRERELEASE" | jq -r '.tag_name')
        
        echo "[*] 找到最新 Pre-release 版本: $LATEST_VERSION"
        
        # 显示该版本的所有 assets
        echo "[*] 该版本包含的文件:"
        echo "$LATEST_PRERELEASE" | jq -r '.assets[].name' | sed 's/^/  - /'
        
        # 查找以 luci-app-openclash 开头的 ipk 文件
        LATEST_URL=$(echo "$LATEST_PRERELEASE" | jq -r '.assets[] | select(.name | startswith("luci-app-openclash") and endswith(".ipk")) | .browser_download_url' | head -1)
        
        if [ -n "$LATEST_URL" ] && [ "$LATEST_URL" != "null" ]; then
            IPK_FILENAME=$(echo "$LATEST_PRERELEASE" | jq -r '.assets[] | select(.name | startswith("luci-app-openclash") and endswith(".ipk")) | .name' | head -1)
            echo "[✓] 找到 IPK 文件: $IPK_FILENAME"
        fi
    else
        echo "[!] 未找到 Pre-release 版本，将搜索最新的 Release 版本..."
        
        # 如果没有 Pre-release，搜索最新的正式版本
        LATEST_RELEASE=$(echo "$RELEASES_JSON" | jq '.[0]')
        LATEST_VERSION=$(echo "$LATEST_RELEASE" | jq -r '.tag_name')
        
        echo "[*] 找到最新 Release 版本: $LATEST_VERSION"
        echo "[*] 该版本包含的文件:"
        echo "$LATEST_RELEASE" | jq -r '.assets[].name' | sed 's/^/  - /'
        
        LATEST_URL=$(echo "$LATEST_RELEASE" | jq -r '.assets[] | select(.name | startswith("luci-app-openclash") and endswith(".ipk")) | .browser_download_url' | head -1)
        
        if [ -n "$LATEST_URL" ] && [ "$LATEST_URL" != "null" ]; then
            IPK_FILENAME=$(echo "$LATEST_RELEASE" | jq -r '.assets[] | select(.name | startswith("luci-app-openclash") and endswith(".ipk")) | .name' | head -1)
            echo "[✓] 找到 IPK 文件: $IPK_FILENAME"
        fi
    fi
else
    # 使用 grep 解析（备用方法）
    echo "[*] 使用备用解析方法搜索..."
    
    # 先尝试查找 prerelease: true 的条目
    echo "[*] 搜索 Pre-release 版本..."
    PRERELEASE_URLS=$(echo "$RELEASES_JSON" | grep -B 5 -A 20 '"prerelease": true' | grep -o '"browser_download_url": "[^"]*luci-app-openclash[^"]*\.ipk"' | cut -d '"' -f 4 | head -1)
    
    if [ -n "$PRERELEASE_URLS" ]; then
        LATEST_URL="$PRERELEASE_URLS"
        LATEST_VERSION="latest-prerelease"
        echo "[✓] 找到 Pre-release IPK 文件"
    else
        echo "[*] 未找到 Pre-release，搜索任意版本的 IPK 文件..."
        # 搜索任意版本的 luci-app-openclash IPK 文件
        ANY_VERSION_URL=$(echo "$RELEASES_JSON" | grep -o '"browser_download_url": "[^"]*luci-app-openclash[^"]*\.ipk"' | cut -d '"' -f 4 | head -1)
        
        if [ -n "$ANY_VERSION_URL" ]; then
            LATEST_URL="$ANY_VERSION_URL"
            LATEST_VERSION="latest-available"
            echo "[✓] 找到 IPK 文件（任意版本）"
        fi
    fi
fi

if [ -z "$LATEST_URL" ]; then
    echo ""
    echo "[!] 获取 OpenClash IPK 下载链接失败"
    echo ""
    echo "调试信息："
    echo "- API 响应大小: $(echo "$RELEASES_JSON" | wc -c) 字符"
    echo "- 使用 jq: $USE_JQ"
    echo ""
    echo "可能的原因："
    echo "1. 网络连接问题"
    echo "2. GitHub API 限制"
    echo "3. 仓库结构变化"
    echo "4. IPK 文件命名格式变化"
    echo ""
    echo "建议："
    echo "1. 检查网络连接: curl -I https://api.github.com"
    echo "2. 手动查看: https://github.com/vernesong/OpenClash/releases"
    echo "3. 稍后重试脚本"
    exit 1
fi

# 检查 URL 是否已经包含镜像前缀，避免重复添加
if echo "$LATEST_URL" | grep -q "gh-proxy.com"; then
    echo "[*] 检测到已包含镜像地址: $LATEST_URL"
    DOWNLOAD_URL="$LATEST_URL"
    # 提取原始 GitHub 地址作为备用
    ORIGINAL_URL=$(echo "$LATEST_URL" | sed 's|https://gh-proxy.com/||')
else
    echo "[*] 原始地址: $LATEST_URL"
    # 使用 GitHub 加速镜像提高下载速度
    DOWNLOAD_URL="https://gh-proxy.com/$LATEST_URL"
    ORIGINAL_URL="$LATEST_URL"
    echo "[*] 加速地址: $DOWNLOAD_URL"
fi

echo "[*] 下载中..."

# 首先尝试使用主要下载地址
if ! curl -L -f -o /tmp/openclash.ipk "$DOWNLOAD_URL"; then
    echo "[*] 主要下载失败，尝试备用地址..."
    # 如果主要地址失败，尝试备用地址
    if ! curl -L -f -o /tmp/openclash.ipk "$ORIGINAL_URL"; then
        echo "[!] 下载失败，请检查网络连接或稍后重试"
        exit 1
    fi
fi

# 验证下载的文件
if [ ! -f "/tmp/openclash.ipk" ] || [ ! -s "/tmp/openclash.ipk" ]; then
    echo "[!] 下载的文件无效"
    exit 1
fi

echo "[*] 下载完成，文件大小: $(du -h /tmp/openclash.ipk | cut -f1)"

echo "[4/4] 安装 OpenClash..."

# 检查是否已经安装了 OpenClash
if opkg list-installed | grep -q "luci-app-openclash"; then
    echo "[*] 检测到已安装的 OpenClash，正在卸载..."
    opkg remove luci-app-openclash --force-removal-of-dependent-packages 2>/dev/null || {
        echo "[!] 卸载失败，尝试强制移除..."
        opkg remove luci-app-openclash --force-depends 2>/dev/null || {
            echo "[!] 无法卸载现有版本，继续安装可能会失败"
        }
    }
fi

# 安装 OpenClash
echo "[*] 安装 OpenClash..."

# 检查文件
if [ ! -f "/tmp/openclash.ipk" ] || [ ! -s "/tmp/openclash.ipk" ]; then
    echo "[!] IPK 文件无效或不存在"
    exit 1
fi

echo "[*] IPK 文件大小: $(du -h /tmp/openclash.ipk | cut -f1)"

# 检查是否已经安装
if opkg list-installed | grep -q "luci-app-openclash"; then
    echo "[*] 检测到已安装的 OpenClash，正在卸载..."
    opkg remove luci-app-openclash --force-removal-of-dependent-packages
fi

# 标准安装（不覆盖系统组件）
echo "[*] 开始标准安装..."
if opkg install /tmp/openclash.ipk; then
    echo "[✓] OpenClash 安装成功"
else
    echo "[!] OpenClash 安装失败"
    echo ""
    echo "可能原因："
    echo "1. 依赖包缺失"
    echo "2. 系统空间不足"  
    echo "3. 权限问题"
    echo ""
    echo "建议手动安装: opkg install /tmp/openclash.ipk --force-maintainer"
    exit 1
fi

# 清理配置文件备份
echo "[*] 清理临时文件..."
for backup_file in /etc/config/*-opkg; do
    if [ -f "$backup_file" ]; then
        rm -f "$backup_file"
    fi
done

# 清理临时文件
rm -f /tmp/openclash.ipk

echo "[✔] OpenClash 安装完成！"
echo ""
echo "=================================================="
echo "            安装完成信息"
echo "=================================================="
echo "✓ 下载源: vernesong/OpenClash 官方仓库"
echo "✓ 版本: $LATEST_VERSION"
echo "✓ 访问方式: LuCI 界面 -> 服务 -> OpenClash"
echo "✓ 安装方式: 标准安装（未覆盖系统组件）"
echo ""
echo "重要提醒："
echo "- 首次使用需要在 OpenClash 界面中下载内核文件"
echo "- 建议重启路由器以确保所有服务正常运行"
echo "- 源仓库: https://github.com/vernesong/OpenClash"
echo "- 加速镜像: https://gh-proxy.com/"
echo "=================================================="
