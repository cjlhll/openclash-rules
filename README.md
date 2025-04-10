### 安装[OpenWrt-mihomo](https://github.com/morytyann/OpenWrt-mihomo)脚本

### release安装方式
```shell
curl -s -L https://github.boki.moe/https://github.com/nikkinikki-org/OpenWrt-nikki/raw/refs/heads/main/install.sh | ash
```
### feed源方式
```
curl -s -L https://gh-proxy.com/github.com/nikkinikki-org/OpenWrt-nikki/raw/refs/heads/main/feed.sh | ash

opkg install nikki
opkg install luci-app-nikki
opkg install luci-i18n-nikki-zh-cn
```


### 安装passwall
```
opkg update
opkg install openssh-sftp-server kmod-nft-socket kmod-nft-tproxy haproxy
把passwall 安装文件和所有依赖 文件放到tmp/pw目录
执行opkg install *.ipk
```
