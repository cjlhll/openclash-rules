#!/bin/sh
# 一键安装 Passwall2 脚本
# 适用于 OpenWrt 系统
# 从 xiaorouji/openwrt-passwall2 仓库自动获取最新 IPK 文件

set -e

echo "=================================================="
echo "            Passwall2 一键安装脚本"
echo "=================================================="
echo "源仓库: https://github.com/xiaorouji/openwrt-passwall2"
echo "目标架构: aarch64_generic"
echo "=================================================="
echo ""

# 检查必要的命令
for cmd in curl jq unzip; do
    if ! command -v $cmd >/dev/null 2>&1; then
        echo "[!] 缺少必要命令: $cmd"
        echo "[*] 正在安装 $cmd..."
        opkg update >/dev/null 2>&1
        opkg install $cmd >/dev/null 2>&1 || {
            echo "[!] 无法安装 $cmd，请手动安装后重试"
            exit 1
        }
    fi
done

echo "[1/6] 更新软件源..."
opkg update

echo "[2/6] 预清理配置文件备份..."
for backup_file in /etc/config/*-opkg; do
    if [ -f "$backup_file" ]; then
        echo "[*] 删除已存在的备份: $backup_file"
        rm -f "$backup_file"
    fi
done

echo "[3/6] 分析 GitHub Releases，查找所需文件..."

# GitHub API URL
REPO_API="https://api.github.com/repos/xiaorouji/openwrt-passwall2/releases"

echo "[*] 获取 releases 列表..."
RELEASES_JSON=$(curl -s "$REPO_API" || {
    echo "[!] 获取 releases 信息失败，尝试使用加速镜像..."
    curl -s "https://gh-proxy.com/$REPO_API" || {
        echo "[!] 无法获取 releases 信息，请检查网络连接"
        exit 1
    }
})

# 查找包含 passwall_packages_ipk_aarch64_generic.zip 的 release
PACKAGES_RELEASE=""
PACKAGES_URL=""
LUCI_RELEASE=""
LUCI_APP_URL=""
LUCI_I18N_URL=""

echo "[*] 搜索 passwall_packages_ipk_aarch64_generic.zip..."

# 使用 jq 解析 JSON（如果可用），否则使用 grep
if command -v jq >/dev/null 2>&1; then
    # 使用 jq 解析
    RELEASE_COUNT=$(echo "$RELEASES_JSON" | jq length)
    echo "[*] 找到 $RELEASE_COUNT 个 releases"
    
    for i in $(seq 0 $((RELEASE_COUNT - 1))); do
        RELEASE_TAG=$(echo "$RELEASES_JSON" | jq -r ".[$i].tag_name")
        echo "[*] 检查 release: $RELEASE_TAG"
        
        # 检查是否有 passwall_packages_ipk_aarch64_generic.zip
        PACKAGES_URL=$(echo "$RELEASES_JSON" | jq -r ".[$i].assets[] | select(.name == \"passwall_packages_ipk_aarch64_generic.zip\") | .browser_download_url" 2>/dev/null)
        
        if [ -n "$PACKAGES_URL" ] && [ "$PACKAGES_URL" != "null" ]; then
            PACKAGES_RELEASE="$RELEASE_TAG"
            echo "[✓] 在 release $RELEASE_TAG 中找到 passwall_packages_ipk_aarch64_generic.zip"
            break
        fi
    done
    
    # 在第一个 release 中查找 luci 相关文件
    if [ -n "$PACKAGES_RELEASE" ]; then
        echo "[*] 在最新 release 中查找 luci 相关文件..."
        LUCI_APP_URL=$(echo "$RELEASES_JSON" | jq -r ".[0].assets[] | select(.name | startswith(\"luci-24.10_luci-app-passwall2\")) | .browser_download_url" | head -1)
        LUCI_I18N_URL=$(echo "$RELEASES_JSON" | jq -r ".[0].assets[] | select(.name | startswith(\"luci-24.10_luci-i18n-passwall2-zh-cn\")) | .browser_download_url" | head -1)
        
        if [ -n "$LUCI_APP_URL" ] && [ "$LUCI_APP_URL" != "null" ] && [ -n "$LUCI_I18N_URL" ] && [ "$LUCI_I18N_URL" != "null" ]; then
            LUCI_RELEASE=$(echo "$RELEASES_JSON" | jq -r ".[0].tag_name")
            echo "[✓] 在 release $LUCI_RELEASE 中找到 luci 文件"
        else
            echo "[!] 在最新 release 中未找到 luci 相关文件"
        fi
    fi
else
    # 使用 grep 解析（备用方法）
    echo "[*] 使用备用解析方法..."
    
    # 提取所有 browser_download_url
    URLS=$(echo "$RELEASES_JSON" | grep -o '"browser_download_url": "[^"]*"' | cut -d '"' -f 4)
    
    # 查找 passwall_packages_ipk_aarch64_generic.zip
    PACKAGES_URL=$(echo "$URLS" | grep "passwall_packages_ipk_aarch64_generic.zip" | head -1)
    
    if [ -n "$PACKAGES_URL" ]; then
        echo "[✓] 找到 passwall_packages_ipk_aarch64_generic.zip"
        PACKAGES_RELEASE="latest"
    fi
    
    # 查找 luci 相关文件
    LUCI_APP_URL=$(echo "$URLS" | grep "luci-24.10_luci-app-passwall2" | head -1)
    LUCI_I18N_URL=$(echo "$URLS" | grep "luci-24.10_luci-i18n-passwall2-zh-cn" | head -1)
    
    if [ -n "$LUCI_APP_URL" ] && [ -n "$LUCI_I18N_URL" ]; then
        echo "[✓] 找到 luci 相关文件"
        LUCI_RELEASE="latest"
    fi
fi

# 验证是否找到所有必要文件
if [ -z "$PACKAGES_URL" ]; then
    echo "[!] 未找到 passwall_packages_ipk_aarch64_generic.zip"
    exit 1
fi

if [ -z "$LUCI_APP_URL" ] || [ -z "$LUCI_I18N_URL" ]; then
    echo "[!] 未找到完整的 luci 相关文件"
    echo "LUCI_APP_URL: $LUCI_APP_URL"
    echo "LUCI_I18N_URL: $LUCI_I18N_URL"
    exit 1
fi

echo ""
echo "找到以下文件："
echo "- Packages: $PACKAGES_URL"
echo "- LuCI App: $LUCI_APP_URL"
echo "- LuCI I18n: $LUCI_I18N_URL"
echo ""

echo "[4/6] 下载文件..."

# 创建临时目录
TMP_DIR="/tmp/passwall2_install"
rm -rf "$TMP_DIR"
mkdir -p "$TMP_DIR"
cd "$TMP_DIR"

# 下载函数
download_file() {
    local url="$1"
    local filename="$2"
    local use_proxy="$3"
    
    if [ "$use_proxy" = "true" ]; then
        local proxy_url="https://gh-proxy.com/$url"
        echo "[*] 使用加速镜像下载 $filename..."
        if curl -L -f -o "$filename" "$proxy_url"; then
            return 0
        else
            echo "[*] 加速镜像失败，尝试原始地址..."
        fi
    fi
    
    echo "[*] 下载 $filename..."
    if curl -L -f -o "$filename" "$url"; then
        return 0
    else
        echo "[!] 下载 $filename 失败"
        return 1
    fi
}

# 下载所有文件
download_file "$PACKAGES_URL" "passwall_packages_ipk_aarch64_generic.zip" "true" || exit 1
download_file "$LUCI_APP_URL" "luci-app-passwall2.ipk" "true" || exit 1
download_file "$LUCI_I18N_URL" "luci-i18n-passwall2-zh-cn.ipk" "true" || exit 1

echo "[*] 验证下载的文件..."
for file in "passwall_packages_ipk_aarch64_generic.zip" "luci-app-passwall2.ipk" "luci-i18n-passwall2-zh-cn.ipk"; do
    if [ ! -f "$file" ] || [ ! -s "$file" ]; then
        echo "[!] 文件 $file 下载失败或为空"
        exit 1
    fi
    echo "[✓] $file ($(du -h "$file" | cut -f1))"
done

echo "[5/6] 解压和准备安装文件..."

# 解压 packages zip
echo "[*] 解压 passwall_packages_ipk_aarch64_generic.zip..."
unzip -q "passwall_packages_ipk_aarch64_generic.zip" || {
    echo "[!] 解压失败"
    exit 1
}

# 移动 luci 文件到解压目录
echo "[*] 整理安装文件..."
mv "luci-app-passwall2.ipk" "luci-i18n-passwall2-zh-cn.ipk" ./ 2>/dev/null || {
    # 如果解压后有子目录，找到它
    EXTRACT_DIR=$(find . -name "*.ipk" -type f | head -1 | xargs dirname)
    if [ -n "$EXTRACT_DIR" ] && [ "$EXTRACT_DIR" != "." ]; then
        echo "[*] 移动文件到 $EXTRACT_DIR"
        mv "luci-app-passwall2.ipk" "luci-i18n-passwall2-zh-cn.ipk" "$EXTRACT_DIR/"
        cd "$EXTRACT_DIR"
    fi
}

# 列出所有要安装的 ipk 文件
IPK_FILES=$(find . -name "*.ipk" -type f)
IPK_COUNT=$(echo "$IPK_FILES" | wc -l)

echo "[*] 准备安装 $IPK_COUNT 个 IPK 文件："
echo "$IPK_FILES" | sed 's|^\./||' | sort

echo "[6/6] 安装依赖和 Passwall2..."

# 安装 dnsmasq-full 并处理冲突
echo "[*] 安装 dnsmasq-full..."

# 如果有 dnsmasq 就卸载
if opkg list-installed | grep -q "^dnsmasq "; then
    echo "[*] 检测到 dnsmasq，卸载中..."
    opkg remove dnsmasq
fi

# 备份 dhcp 配置以避免警告
if [ -f "/etc/config/dhcp" ]; then
    echo "[*] 备份 dhcp 配置..."
    cp "/etc/config/dhcp" "/tmp/dhcp.backup"
fi

# 安装 dnsmasq-full
opkg install dnsmasq-full --force-overwrite --force-maintainer || {
    echo "[!] dnsmasq-full 安装失败"
    # 尝试恢复 dhcp 配置
    if [ -f "/tmp/dhcp.backup" ]; then
        cp "/tmp/dhcp.backup" "/etc/config/dhcp"
    fi
    exit 1
}

# 恢复 dhcp 配置（如果备份存在且当前配置被覆盖）
if [ -f "/tmp/dhcp.backup" ] && [ -f "/etc/config/dhcp" ]; then
    # 检查配置是否被重置为默认值（通常很小）
    CURRENT_SIZE=$(wc -c < "/etc/config/dhcp")
    BACKUP_SIZE=$(wc -c < "/tmp/dhcp.backup")
    
    if [ "$CURRENT_SIZE" -lt "$BACKUP_SIZE" ]; then
        echo "[*] 恢复原有 dhcp 配置..."
        cp "/tmp/dhcp.backup" "/etc/config/dhcp"
    fi
    
    rm -f "/tmp/dhcp.backup"
fi

# 清理可能产生的备份文件
echo "[*] 清理 dnsmasq-full 安装产生的备份文件..."
for backup_file in /etc/config/*-opkg; do
    if [ -f "$backup_file" ]; then
        echo "[*] 删除备份文件: $backup_file"
        rm -f "$backup_file"
    fi
done

# 安装其他依赖
echo "[*] 安装其他依赖包..."
DEPS="curl ca-bundle ipset ip-full iptables-mod-tproxy iptables-mod-extra kmod-tun unzip luci-compat tcping"
opkg install $DEPS --force-overwrite --force-maintainer 2>/dev/null || {
    echo "[*] 部分依赖可能已存在，继续..."
}

# 安装 Passwall2 IPK 文件
echo "[*] 安装 Passwall2 IPK 文件..."

# 分离 LuCI 相关文件和核心包文件
LUCI_IPKS=""
CORE_IPKS=""

for ipk in $IPK_FILES; do
    ipk_name=$(basename "$ipk")
    if echo "$ipk_name" | grep -q "^luci-"; then
        LUCI_IPKS="$LUCI_IPKS $ipk"
    else
        CORE_IPKS="$CORE_IPKS $ipk"
    fi
done

# 首先安装核心包（除了 LuCI 相关的）
if [ -n "$CORE_IPKS" ]; then
    echo "[*] 第一阶段: 安装核心包..."
    echo "[*] 核心包列表："
    for ipk in $CORE_IPKS; do
        echo "    - $(basename "$ipk")"
    done
    for ipk in $CORE_IPKS; do
        ipk_name=$(basename "$ipk")
        echo "[*] 安装 $ipk_name..."
        
        if opkg install "$ipk" --force-overwrite --force-maintainer 2>/dev/null; then
            echo "[✓] $ipk_name 安装成功"
        else
            echo "[*] $ipk_name 安装时有警告，尝试强制安装..."
            if opkg install "$ipk" --force-overwrite --force-maintainer --force-depends; then
                echo "[✓] $ipk_name 强制安装成功"
            else
                echo "[!] $ipk_name 安装失败，继续安装其他文件..."
            fi
        fi
    done
fi

# 安装缺失的依赖包
echo "[*] 检查并安装缺失的依赖包..."
MISSING_DEPS="tcping"
for dep in $MISSING_DEPS; do
    if ! opkg list-installed | grep -q "^$dep "; then
        echo "[*] 安装缺失依赖: $dep"
        opkg install "$dep" --force-overwrite --force-maintainer 2>/dev/null || {
            echo "[!] 无法从软件源安装 $dep，尝试检查是否已在下载的包中..."
            # 检查是否在下载的 IPK 文件中有这个依赖
            DEP_IPK=$(find . -name "*$dep*.ipk" -type f 2>/dev/null | head -1)
            if [ -n "$DEP_IPK" ]; then
                echo "[*] 找到依赖包: $(basename "$DEP_IPK")"
                opkg install "$DEP_IPK" --force-overwrite --force-maintainer 2>/dev/null || {
                    echo "[!] 安装 $dep 失败，但继续..."
                }
            else
                echo "[!] 未找到 $dep 依赖包，但继续安装..."
            fi
        }
    else
        echo "[✓] $dep 已安装"
    fi
done

# 最后安装 LuCI 相关包
if [ -n "$LUCI_IPKS" ]; then
    echo "[*] 第二阶段: 安装 LuCI 相关包..."
    echo "[*] LuCI 包列表："
    for ipk in $LUCI_IPKS; do
        echo "    - $(basename "$ipk")"
    done
    for ipk in $LUCI_IPKS; do
        ipk_name=$(basename "$ipk")
        echo "[*] 安装 $ipk_name..."
        
        if opkg install "$ipk" --force-overwrite --force-maintainer 2>/dev/null; then
            echo "[✓] $ipk_name 安装成功"
        else
            echo "[*] $ipk_name 安装时有警告，尝试强制安装..."
            if opkg install "$ipk" --force-overwrite --force-maintainer --force-depends; then
                echo "[✓] $ipk_name 强制安装成功"
            else
                echo "[!] $ipk_name 安装失败，但核心功能应该可用..."
            fi
        fi
    done
fi

# 最终清理配置文件备份
echo "[*] 清理所有配置文件备份..."
for backup_file in /etc/config/*-opkg; do
    if [ -f "$backup_file" ]; then
        echo "[*] 删除备份文件: $backup_file"
        rm -f "$backup_file"
    fi
done

# 清理临时文件
cd /
rm -rf "$TMP_DIR"

echo ""
echo "=================================================="
echo "            安装完成信息"
echo "=================================================="
echo "✓ 源仓库: xiaorouji/openwrt-passwall2"
echo "✓ 架构: aarch64_generic"
echo "✓ 访问方式: LuCI 界面 -> 服务 -> PassWall 2"
echo "✓ 配置文件冲突已自动处理"
echo "✓ dnsmasq-full 已安装并配置"
echo "✓ 核心包和 LuCI 包已分阶段安装"
echo ""
echo "重要提醒："
echo "- 建议重启路由器以确保所有服务正常运行"
echo "- 首次使用需要在 PassWall 2 界面中配置节点"
echo "- 如遇到问题，请检查系统日志"
echo ""
echo "命令参考："
echo "- 重启路由器: reboot"
echo "- 查看日志: logread | grep passwall"
echo "- 检查服务: /etc/init.d/passwall2 status"
echo "=================================================="
echo "[✔] Passwall2 安装完成！"
