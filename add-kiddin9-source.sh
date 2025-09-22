#!/bin/sh

# dl.openwrt.ai feed (kiddin9) with nikkinikki key

# check env
if [[ ! -x "/bin/opkg" && ! -x "/usr/bin/apk" || ! -x "/sbin/fw4" ]]; then
    echo "only supports OpenWrt build with firewall4!"
    exit 1
fi

# include openwrt_release
. /etc/openwrt_release

# get branch/arch
arch="$DISTRIB_ARCH"
branch=
case "$DISTRIB_RELEASE" in
    *"23.05"*)
        branch="23.05"
        ;;
    *"24.10"*)
        branch="24.10"
        ;;
    "SNAPSHOT")
        branch="SNAPSHOT"
        ;;
    *)
        echo "unsupported release: $DISTRIB_RELEASE"
        exit 1
        ;;
esac

# feed url
repository_url="https://dl.openwrt.ai/releases"
feed_url="$repository_url/$branch/packages/$arch/kiddin9"

# 公钥仍然使用 nikkinikki 的
key_url="https://nikkinikki.pages.dev/key-build.pub"

if [ -x "/bin/opkg" ]; then
    # add key
    echo "add key"
    key_build_pub_file="key-build.pub"
    wget -O "$key_build_pub_file" "$key_url"
    opkg-key add "$key_build_pub_file"
    rm -f "$key_build_pub_file"
    # add feed
    echo "add feed"
    if grep -q kiddin9 /etc/opkg/customfeeds.conf; then
        sed -i '/kiddin9/d' /etc/opkg/customfeeds.conf
    fi
    echo "src/gz kiddin9 $feed_url" >> /etc/opkg/customfeeds.conf
    # update feeds
    echo "update feeds"
    opkg update
elif [ -x "/usr/bin/apk" ]; then
    # add key
    echo "add key"
    wget -O "/etc/apk/keys/dlopenwrt.pem" "$key_url"
    # add feed
    echo "add feed"
    if grep -q kiddin9 /etc/apk/repositories.d/customfeeds.list; then
        sed -i '/kiddin9/d' /etc/apk/repositories.d/customfeeds.list
    fi
    echo "$feed_url/packages.adb" >> /etc/apk/repositories.d/customfeeds.list
    # update feeds
    echo "update feeds"
fi

echo "success"
