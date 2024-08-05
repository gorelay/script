#!/bin/bash
set -e

warning() { echo -e "\033[31m\033[01m$*\033[0m"; }         # 红色
error() { echo -e "\033[31m\033[01m$*\033[0m" && exit 1; } # 红色
info() { echo -e "\033[32m\033[01m$*\033[0m"; }            # 绿色
hint() { echo -e "\033[33m\033[01m$*\033[0m"; }            # 黄色

#### install dependency

install_zip() {
    apt-get update
    apt-get install -y zip
}

command -v zip >/dev/null 2>&1 || install_zip

#### Download & unzip product

ARCH="$1"

rm -rf offlinepkg
mkdir -p offlinepkg
pushd offlinepkg

info "正在下载" "$ARCH"
bash <(curl -fLSs https://api.gorelay.net/download/download.sh) api.gorelay.net rel_nodeclient_$ARCH

info "正在下载安装脚本"
curl -fLSsO https://bash.gorelay.net/install.sh
curl -fLSso offline.sh https://bash.gorelay.net/install-offline.sh

echo "架构" "$ARCH" >>info.txt
# TODO 获取版本信息

info "正在打包离线包" "$ARCH"
zip -r offline.zip ./*
popd

mv offlinepkg/offline.zip .
rm -rf offlinepkg

info "打包完成，离线包输出在 offline.zip"
