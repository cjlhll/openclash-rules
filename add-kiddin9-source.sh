#!/bin/sh
# 脚本：添加供 dl.openwrt.ai 源，并安装 luci-theme-design，处理签名或关闭签名验证

set -e

FEED_NAME="kiddin9"
ARCH="aarch64_cortex-a53"    # 可根据你的设备架构改
OPENWRT_VER="24.10"          # 你当前 OpenWrt 版本
BASE_URL="https://dl.openwrt.ai/releases/$OPENWRT_VER/packages/$ARCH/$FEED_NAME"
FEED_LINE="src/gz $FEED_NAME $BASE_URL"

# 公钥文件 URL（如果有的话；你需要确认 dl.openwrt.ai 是否有提供公钥）
PUBKEY_URL="$BASE_URL/pubkey-build.pub"
PUBKEY_FILE="/tmp/pubkey-$FEED_NAME.pub"

# 路径配置
DISTFEEDS_CONF="/etc/opkg/distfeeds.conf"
CUSTOMFEEDS_CONF="/etc/opkg/customfeeds.conf"
OPKG_CONF="/etc/opkg.conf"

echo "=== 添加 $FEED_NAME 源 ==="

# 添加 feed 到 customfeeds
if grep -q "$FEED_LINE" "$CUSTOMFEEDS_CONF"; then
  echo "Feed 已存在： $FEED_LINE"
else
  echo "Adding feed line to $CUSTOMFEEDS_CONF"
  echo "$FEED_LINE" >> "$CUSTOMFEEDS_CONF"
fi

# 尝试下载公钥并添加
echo "=== 尝试获取公钥： $PUBKEY_URL"
if wget -q -O "$PUBKEY_FILE" "$PUBKEY_URL"; then
  echo "公钥下载成功，添加到 opkg-key"
  opkg-key add "$PUBKEY_FILE" || {
    echo "opkg-key add 失败"
  }
  rm -f "$PUBKEY_FILE"
else
  echo "无法下载公钥，可能源不支持签名或没有公钥"
  echo "关闭签名验证"
  # 在 opkg.conf 中设置不校验签名
  # 检查是否已有该选项
  grep -q "^option check_signature 0" "$OPKG_CONF" || {
    echo "option check_signature 0" >> "$OPKG_CONF"
  }
fi

# 更新
echo "=== 更新 feed 列表 ==="
opkg update

# 安装包
echo "=== 安装 luci-theme-design ==="
opkg install luci-theme-design

echo "=== 完成 ==="
