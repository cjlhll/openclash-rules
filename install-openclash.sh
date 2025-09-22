#!/bin/sh
# 一键安装 OpenClash 脚本
# 适用于 OpenWrt 系统
# 从 cjlhll/openclash-rules 仓库获取 IPK 文件

set -e

echo "[1/4] 更新软件源..."
opkg update

echo "[2/4] 安装依赖包..."

PKGS="bash iptables dnsmasq-full curl ca-bundle ipset ip-full iptables-mod-tproxy iptables-mod-extra ruby ruby-yaml kmod-tun kmod-inet-diag unzip luci-compat luci luci-base"

# 如果有 dnsmasq 就卸载
if opkg list-installed | grep -q "^dnsmasq "; then
    echo "[*] 检测到 dnsmasq，卸载中..."
    opkg remove dnsmasq
fi

opkg install $PKGS --force-overwrite

echo "[3/4] 获取最新 OpenClash ipk..."

# 从 cjlhll/openclash-rules 仓库获取最新版下载链接
# 该仓库将 IPK 文件重命名为 luci-app-openclash.ipk（去掉版本号）
echo "[*] 从 cjlhll/openclash-rules 仓库获取最新版本..."

LATEST_URL=$(curl -s "https://api.github.com/repos/cjlhll/openclash-rules/releases/latest" \
    | grep browser_download_url \
    | grep "luci-app-openclash.ipk" \
    | cut -d '"' -f 4)

if [ -z "$LATEST_URL" ]; then
    echo "[!] 获取 OpenClash 下载链接失败，尝试备用方法..."
    
    # 备用方法：获取最新 release 的所有 assets
    RELEASE_INFO=$(curl -s "https://api.github.com/repos/cjlhll/openclash-rules/releases/latest")
    LATEST_URL=$(echo "$RELEASE_INFO" | grep -o '"browser_download_url": "[^"]*luci-app-openclash\.ipk"' | cut -d '"' -f 4)
    
    if [ -z "$LATEST_URL" ]; then
        echo "[!] 获取下载链接失败，请检查："
        echo "    1. 网络连接是否正常"
        echo "    2. cjlhll/openclash-rules 仓库是否有最新的 release"
        echo "    3. release 中是否包含 luci-app-openclash.ipk 文件"
        exit 1
    fi
fi

echo "[*] 最新版本地址: $LATEST_URL"
echo "[*] 下载中..."

# 下载文件，添加更多错误处理
if ! curl -L -f -o /tmp/openclash.ipk "https://gh-proxy.com/$LATEST_URL"; then
    echo "[!] 下载失败，请检查网络连接或稍后重试"
    exit 1
fi

# 验证下载的文件
if [ ! -f "/tmp/openclash.ipk" ] || [ ! -s "/tmp/openclash.ipk" ]; then
    echo "[!] 下载的文件无效"
    exit 1
fi

echo "[*] 下载完成，文件大小: $(du -h /tmp/openclash.ipk | cut -f1)"

echo "[4/4] 安装 OpenClash..."

# 使用 --force-confold 参数避免配置文件冲突
# --force-confold: 保留现有配置文件，不创建备份
# --force-overwrite: 强制覆盖已存在的文件
if ! opkg install /tmp/openclash.ipk --force-confold --force-confold; then
    echo "[!] 安装失败，可能的原因："
    echo "    1. IPK 文件损坏"
    echo "    2. 依赖包未正确安装"
    echo "    3. 系统空间不足"
    exit 1
fi

# 清理临时文件
rm -f /tmp/openclash.ipk

echo "[✔] OpenClash 安装完成！"
echo "[*] 请在 LuCI 界面中访问 服务 -> OpenClash 来配置使用。"
echo "[*] 源仓库: https://github.com/cjlhll/openclash-rules"
