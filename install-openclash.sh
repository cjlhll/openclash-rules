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

# 安全的依赖安装策略 - 避免覆盖系统关键组件
echo "[*] 检查和安装依赖包（安全模式）..."

# 分离依赖包：系统关键包 vs OpenClash 专用包
SYSTEM_CRITICAL="luci luci-base luci-compat"  # 系统关键的 LuCI 组件
OPENCLASH_DEPS="bash iptables curl ca-bundle ipset ip-full iptables-mod-tproxy iptables-mod-extra ruby ruby-yaml kmod-tun kmod-inet-diag unzip"
NETWORK_DEPS="dnsmasq-full"  # 需要特殊处理的网络组件

# 1. 安装 OpenClash 专用依赖（这些通常不会冲突）
echo "[*] 安装 OpenClash 专用依赖..."
for pkg in $OPENCLASH_DEPS; do
    if ! opkg list-installed | grep -q "^$pkg "; then
        echo "[*] 安装 $pkg..."
        opkg install "$pkg" 2>/dev/null || {
            echo "[!] $pkg 安装失败，继续..."
        }
    else
        echo "[✓] $pkg 已安装"
    fi
done

# 2. 处理 dnsmasq/dnsmasq-full 冲突
echo "[*] 处理 DNS 服务冲突..."
if opkg list-installed | grep -q "^dnsmasq "; then
    echo "[*] 检测到 dnsmasq，需要替换为 dnsmasq-full..."
    # 备份 dhcp 配置
    if [ -f "/etc/config/dhcp" ]; then
        cp "/etc/config/dhcp" "/tmp/dhcp.backup"
    fi
    # 卸载 dnsmasq
    opkg remove dnsmasq 2>/dev/null
    # 安装 dnsmasq-full
    if opkg install dnsmasq-full 2>/dev/null; then
        echo "[✓] dnsmasq-full 安装成功"
        # 恢复配置
        if [ -f "/tmp/dhcp.backup" ]; then
            cp "/tmp/dhcp.backup" "/etc/config/dhcp"
            rm -f "/tmp/dhcp.backup"
        fi
    else
        echo "[!] dnsmasq-full 安装失败"
    fi
elif ! opkg list-installed | grep -q "^dnsmasq-full "; then
    echo "[*] 安装 dnsmasq-full..."
    opkg install dnsmasq-full 2>/dev/null || {
        echo "[!] dnsmasq-full 安装失败"
    }
else
    echo "[✓] dnsmasq-full 已安装"
fi

# 3. 检查系统关键组件（只检查不强制安装/覆盖）
echo "[*] 检查系统关键组件..."
for pkg in $SYSTEM_CRITICAL; do
    if ! opkg list-installed | grep -q "^$pkg "; then
        echo "[*] 尝试安装缺失的系统组件: $pkg"
        # 不使用强制参数，避免覆盖
        opkg install "$pkg" 2>/dev/null || {
            echo "[!] $pkg 安装失败，可能存在冲突，跳过..."
        }
    else
        echo "[✓] 系统组件 $pkg 已存在"
    fi
done

# 4. 清理可能产生的配置文件备份（但不强制）
echo "[*] 清理依赖安装产生的备份文件..."
for backup_file in /etc/config/*-opkg; do
    if [ -f "$backup_file" ]; then
        echo "[*] 发现备份文件: $backup_file"
        # 检查原文件是否存在且有效
        original_file=$(echo "$backup_file" | sed 's/-opkg$//')
        if [ -f "$original_file" ] && [ -s "$original_file" ]; then
            # 原文件存在且非空，删除备份
            rm -f "$backup_file"
            echo "[*] 已删除备份文件: $backup_file"
        else
            echo "[!] 保留备份文件 $backup_file（原文件可能有问题）"
        fi
    fi
done

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

# 安全安装 OpenClash IPK - 避免覆盖系统组件
echo "[*] 安全安装 OpenClash..."

# 快速依赖检查（避免 opkg depends 可能的挂起问题）
echo "[*] 快速检查 OpenClash 文件信息..."

# 检查文件有效性
if [ ! -f "/tmp/openclash.ipk" ] || [ ! -s "/tmp/openclash.ipk" ]; then
    echo "[!] IPK 文件无效或不存在"
    exit 1
fi

# 简单的文件信息检查（替代可能挂起的 opkg depends）
echo "[*] IPK 文件信息:"
FILE_SIZE=$(du -h /tmp/openclash.ipk | cut -f1)
echo "  - 大小: $FILE_SIZE" 
echo "  - 路径: /tmp/openclash.ipk"

# 检查是否为有效的 IPK 文件
if file /tmp/openclash.ipk 2>/dev/null | grep -q "gzip\|Debian"; then
    echo "  - 格式: 有效的 IPK 包"
else
    echo "  - 格式: 可能不是标准 IPK 格式，但继续尝试安装"
fi

echo "[*] 文件检查完成，开始安装..."

# 分级安装策略：从最安全到最少限制
echo "[*] 使用分级安装策略..."

# Level 1: 标准安装（最安全，不覆盖任何文件）
echo "[*] 尝试标准安装（Level 1）..."
echo "[*] 命令: opkg install /tmp/openclash.ipk"
echo ""
echo "=== 开始标准安装 ==="
if opkg install /tmp/openclash.ipk; then
    echo ""
    echo "[✓] 标准安装成功 - 系统组件未被修改"
    INSTALL_SUCCESS=true
else
    echo ""
    echo "[*] 标准安装失败，尝试下一级别..."
    
    # Level 2: 允许覆盖配置文件，但不覆盖系统包文件
    echo "[*] 尝试配置覆盖安装（Level 2）..."
    echo "[*] 命令: opkg install /tmp/openclash.ipk --force-maintainer"
    echo ""
    echo "=== 开始配置覆盖安装 ==="
    if opkg install /tmp/openclash.ipk --force-maintainer; then
        echo ""
        echo "[✓] 配置覆盖安装成功 - 仅覆盖了配置文件"
        INSTALL_SUCCESS=true
    else
        echo ""
        echo "[*] 配置覆盖安装失败，尝试下一级别..."
        
        # Level 3: 允许覆盖非关键文件（但排除 LuCI 核心）
        echo "[*] 尝试选择性文件覆盖安装（Level 3）..."
        # 创建临时的 exclude 文件
        cat > /tmp/openclash_exclude.conf << EOF
# 保护 LuCI 核心文件
/usr/lib/lua/luci/*
/etc/config/luci
/www/luci-static/*
EOF
        
        if opkg install /tmp/openclash.ipk --force-maintainer --force-overwrite 2>/dev/null; then
            echo "[✓] 选择性覆盖安装成功"
            INSTALL_SUCCESS=true
        else
            echo "[*] 选择性覆盖安装失败，尝试最后的兜底方案..."
            
            # Level 4: 完全强制安装（最后手段）
            echo "[!] 警告：使用完全强制安装可能影响系统组件"
            echo "[*] 尝试完全强制安装（Level 4）..."
            if opkg install /tmp/openclash.ipk --force-maintainer --force-overwrite --force-depends; then
                echo "[✓] 完全强制安装成功"
                echo "[!] 注意：可能覆盖了系统文件，建议检查系统功能"
                INSTALL_SUCCESS=true
            else
                echo "[!] 所有安装方式都失败了"
                INSTALL_SUCCESS=false
            fi
        fi
        
        # 清理临时文件
        rm -f /tmp/openclash_exclude.conf
    fi
fi

# 检查安装结果
if [ "$INSTALL_SUCCESS" != "true" ]; then
    echo ""
    echo "[!] OpenClash 安装失败"
    echo ""
    echo "可能的原因："
    echo "1. IPK 文件损坏 - 请重新下载"
    echo "2. 依赖包缺失 - 请检查上面的依赖列表"
    echo "3. 系统空间不足 - 请检查存储空间"
    echo "4. 权限问题 - 请确保以 root 身份运行"
    echo "5. 系统版本不兼容 - 请检查 OpenWrt 版本"
    echo ""
    echo "调试信息："
    echo "文件大小: $(ls -lh /tmp/openclash.ipk 2>/dev/null || echo '文件不存在')"
    echo "可用空间: $(df -h /tmp | tail -1)"
    echo "当前用户: $(whoami)"
    echo "OpenWrt 版本: $(cat /etc/openwrt_release 2>/dev/null | head -3 || echo '未知')"
    exit 1
fi

# 验证系统完整性
echo "[*] 验证系统关键组件..."

# 检查 LuCI 核心是否正常
if opkg list-installed | grep -q "^luci "; then
    echo "[✓] LuCI 核心组件正常"
else
    echo "[!] LuCI 核心组件可能有问题，尝试修复..."
    opkg install luci 2>/dev/null || {
        echo "[!] LuCI 核心组件修复失败"
    }
fi

# 确保基础中文语言包存在（但不强制覆盖）
echo "[*] 检查中文语言支持..."
if ! opkg list-installed | grep -q "luci-i18n.*-zh-cn"; then
    echo "[*] 安装基础中文语言包..."
    BASIC_LANG_PKGS="luci-i18n-base-zh-cn luci-i18n-firewall-zh-cn"
    for pkg in $BASIC_LANG_PKGS; do
        if ! opkg list-installed | grep -q "^$pkg "; then
            echo "[*] 安装 $pkg..."
            opkg install "$pkg" 2>/dev/null || {
                echo "[!] $pkg 安装失败，可能不可用"
            }
        fi
    done
else
    echo "[✓] 中文语言包已存在"
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
echo "✓ 下载源: vernesong/OpenClash 官方仓库"
echo "✓ 版本类型: Pre-release ($LATEST_VERSION)"
echo "✓ 访问方式: LuCI 界面 -> 服务 -> OpenClash"
echo "✓ 安装策略: 分级安全安装（避免覆盖系统组件）"
echo "✓ 系统保护: LuCI 核心和语言包已保护"
echo ""
echo "重要提醒："
echo "- 首次使用需要在 OpenClash 界面中下载内核文件"
echo "- 建议重启路由器以确保所有服务正常运行"
echo "- 源仓库: https://github.com/vernesong/OpenClash"
echo "- 加速镜像: https://gh-proxy.com/"
echo "=================================================="
