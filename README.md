### 安装[OpenWrt-mihomo](https://github.com/morytyann/OpenWrt-mihomo)脚本

### release安装方式
```shell
curl -s -L https://github.boki.moe/https://github.com/nikkinikki-org/OpenWrt-nikki/raw/refs/heads/main/install.sh | ash
```
### feed源方式
```
curl -s -L https://gh-proxy.com/github.com/nikkinikki-org/OpenWrt-nikki/raw/refs/heads/main/feed.sh | ash
```


### 安装passwall
```
opkg update
opkg install openssh-sftp-server
opkg install kmod-nft-socket kmod-nft-tproxy
把passwall ipk文件放到tmp/pw目录
直行opkg install *.ipk  会自动安装依赖。注意安装sing-box或者xray。不然订阅时候会提示找不到可使用二进制
```
