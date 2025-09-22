#!/bin/sh
# 一键安装 OpenClash 脚本
# 适用于 OpenWrt 系统

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
# 通过 GitHub API 获取最新版下载链接
LATEST_URL=$(curl -H "Authorization: token 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" https://gh-proxy.com/https://api.github.com/repos/vernesong/OpenClash/releases/latest \
    | grep browser_download_url \
    | grep luci-app-openclash_ \
    | grep _all.ipk \
    | cut -d '"' -f 4)

if [ -z "$LATEST_URL" ]; then
    echo "[!] 获取 OpenClash 下载链接失败，请检查网络！"
    exit 1
fi

echo "[*] 最新版本地址: $LATEST_URL"
echo "[*] 下载中..."
curl -L -o /tmp/openclash.ipk "$LATEST_URL"

echo "[4/4] 安装 OpenClash..."
opkg install /tmp/openclash.ipk

echo "[✔] OpenClash 安装完成！可以在 LuCI 界面中使用了。"
