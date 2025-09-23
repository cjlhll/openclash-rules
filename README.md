### 安装[OpenWrt-nikki](https://github.com/morytyann/OpenWrt-mihomo)脚本

### release安装方式
```shell
curl -s -L https://gh-proxy.com/https://github.com/nikkinikki-org/OpenWrt-nikki/raw/refs/heads/main/install.sh | ash
```
### feed源方式
```
wget -O - https://gh-proxy.com/https://github.com/nikkinikki-org/OpenWrt-nikki/raw/refs/heads/main/feed.sh | ash

opkg install luci-i18n-nikki-zh-cn
```

### ⭐️安装必要插件
```
opkg install luci-app-wol luci-i18n-base-zh-cn luci-i18n-package-manager-zh-cn
```

### 一键安装openclash的脚本
```
wget -O - https://gh-proxy.com/https://raw.githubusercontent.com/cjlhll/openclash-rules/main/install-openclash.sh | sh
```
### 一键安装passwall2的脚本
```
wget -O - https://gh-proxy.com/https://raw.githubusercontent.com/cjlhll/openclash-rules/main/install-passwall2.sh | sh
```
### 一键安装kiddin9源里的主题
```
curl -sSL https://raw.githubusercontent.com/cjlhll/openclash-rules/main/install-theme.sh -o /tmp/install-theme.sh && sh /tmp/install-theme.sh
```
### 一键安装luci-theme-design主题
```
wget -O - https://gh-proxy.com/https://raw.githubusercontent.com/cjlhll/openclash-rules/main/install-luci-theme-design.sh | sh
```

### 安装passwall
```
opkg update
opkg install openssh-sftp-server kmod-nft-socket kmod-nft-tproxy haproxy
把passwall 安装文件和所有依赖 文件放到tmp/pw目录
执行opkg install *.ipk
```
