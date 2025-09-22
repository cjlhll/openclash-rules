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

# 专门针对 OpenWrt 系统的 opkg 安装
echo "[*] 使用 OpenWrt 专用参数安装..."

# 根据您提供的 opkg 帮助信息，使用正确的参数
# --force-maintainer: 覆盖预存在的配置文件
# --force-overwrite: 覆盖来自其他包的文件
# --force-depends: 忽略依赖失败进行安装/移除

echo "[*] 尝试使用完整强制参数安装..."
if opkg install /tmp/openclash.ipk --force-maintainer --force-overwrite --force-depends 2>/dev/null; then
    echo "[✓] 安装成功（使用完整强制参数）"
else
    echo "[*] 完整强制参数失败，尝试基础强制参数..."
    if opkg install /tmp/openclash.ipk --force-overwrite 2>/dev/null; then
        echo "[✓] 安装成功（使用基础强制参数）"
    else
        echo "[*] 强制参数失败，尝试标准安装..."
        if opkg install /tmp/openclash.ipk; then
            echo "[✓] 安装成功（标准安装）"
            echo "[!] 注意：可能会创建配置文件备份"
        else
            echo "[!] 所有安装方式都失败了"
            echo ""
            echo "可能的原因："
            echo "1. IPK 文件损坏 - 请重新下载"
            echo "2. 依赖包缺失 - 请运行 'opkg update' 后重试"
            echo "3. 系统空间不足 - 请检查存储空间"
            echo "4. 权限问题 - 请确保以 root 身份运行"
            echo "5. 已安装冲突版本 - 请先卸载：opkg remove luci-app-openclash"
            echo ""
            echo "调试信息："
            echo "文件大小: $(ls -lh /tmp/openclash.ipk 2>/dev/null || echo '文件不存在')"
            echo "可用空间: $(df -h /tmp | tail -1)"
            echo "当前用户: $(whoami)"
            exit 1
        fi
    fi
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
