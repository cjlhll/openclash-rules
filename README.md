<img width="1269" height="946" alt="image" src="https://github.com/user-attachments/assets/bfd513d4-4aca-4280-9de5-ee14204bf171" />### 安装[OpenWrt-nikki](https://github.com/morytyann/OpenWrt-mihomo)脚本

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
sh -c "$(curl -fsSL https://gh-proxy.com/https://raw.githubusercontent.com/cjlhll/openclash-rules/main/install-openclash.sh)"
```

### 安装passwall
```
opkg update
opkg install openssh-sftp-server kmod-nft-socket kmod-nft-tproxy haproxy
把passwall 安装文件和所有依赖 文件放到tmp/pw目录
执行opkg install *.ipk
```
