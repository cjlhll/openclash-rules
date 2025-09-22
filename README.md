### 安装[OpenWrt-nikki](https://github.com/morytyann/OpenWrt-mihomo)脚本

### release安装方式
```shell
curl -s -L https://github.boki.moe/https://github.com/nikkinikki-org/OpenWrt-nikki/raw/refs/heads/main/install.sh | ash
```
### feed源方式
```
wget -O - https://gh-proxy.com/https://github.com/nikkinikki-org/OpenWrt-nikki/raw/refs/heads/main/feed.sh | ash

opkg install luci-i18n-nikki-zh-cn
```

### 一键安装openclash的脚本
```
wget -O - https://gh-proxy.com/https://raw.githubusercontent.com/cjlhll/openclash-rules/main/install-openclash.sh | sh
```
### 一键安装luci-theme-design的脚本
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
