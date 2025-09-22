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

# 检测 opkg 版本并使用合适的参数
echo "[*] 检测 opkg 支持的参数..."

# 检查是否支持新式参数格式
if opkg --help 2>&1 | grep -q "\-\-force-maintainer"; then
    echo "[*] 使用新版本 opkg 参数..."
    FORCE_ARGS="--force-maintainer --force-overwrite --force-depends"
elif opkg --help 2>&1 | grep -q "force-maintainer"; then
    echo "[*] 使用兼容版本 opkg 参数..."
    FORCE_ARGS="--force-maintainer --force-overwrite"
else
    echo "[*] 使用基础 opkg 参数..."
    FORCE_ARGS="--force-overwrite"
fi

echo "[*] 安装参数: $FORCE_ARGS"

# 安装 OpenClash
if ! opkg install /tmp/openclash.ipk $FORCE_ARGS; then
    echo "[!] 安装失败，尝试不使用强制参数..."
    # 如果强制参数失败，尝试基本安装
    if ! opkg install /tmp/openclash.ipk; then
        echo "[!] 安装失败，可能的原因："
        echo "    1. IPK 文件损坏"
        echo "    2. 依赖包未正确安装"
        echo "    3. 系统空间不足"
        echo "    4. 配置文件冲突（请手动处理 /etc/config/ 目录下的 -opkg 备份文件）"
        exit 1
    else
        echo "[*] 基本安装成功，但可能存在配置文件备份"
    fi
else
    echo "[*] 安装成功！"
fi

# 清理可能产生的配置文件备份
echo "[*] 清理配置文件备份..."
for backup_file in /etc/config/*-opkg; do
    if [ -f "$backup_file" ]; then
        echo "[*] 发现备份文件: $backup_file"
        rm -f "$backup_file"
        echo "[*] 已删除备份文件: $backup_file"
    fi
done

# 清理临时文件
rm -f /tmp/openclash.ipk

echo "[✔] OpenClash 安装完成！"
echo ""
echo "=================================================="
echo "            安装完成信息"
echo "=================================================="
echo "✓ 下载源: cjlhll/openclash-rules 仓库"
echo "✓ 访问方式: LuCI 界面 -> 服务 -> OpenClash"
echo "✓ 配置文件冲突已自动处理"
echo "✓ 加速镜像: https://gh-proxy.com/"
echo ""
echo "重要提醒："
echo "- 首次使用需要在 OpenClash 界面中下载内核文件"
echo "- 建议重启路由器以确保所有服务正常运行"
echo "- 源仓库: https://github.com/cjlhll/openclash-rules"
echo "=================================================="
