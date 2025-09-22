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
OPENCLASH_URL="https://github.com/vernesong/OpenClash/releases/latest/download/luci-app-openclash_all.ipk"
echo "[*] 下载中: $OPENCLASH_URL"
curl -L -o /tmp/openclash.ipk "$OPENCLASH_URL"

echo "[4/4] 安装 OpenClash..."
opkg install /tmp/openclash.ipk

echo "[✔] OpenClash 安装完成！可以在 LuCI 界面中使用了。"
