#!/bin/bash
set -e

warning() { echo -e "\033[31m\033[01m$*\033[0m"; }         # 红色
error() { echo -e "\033[31m\033[01m$*\033[0m" && exit 1; } # 红色
info() { echo -e "\033[32m\033[01m$*\033[0m"; }            # 绿色
hint() { echo -e "\033[33m\033[01m$*\033[0m"; }            # 黄色

cd /opt/gorelay

[ -f info.txt ] || error "可能已经安装过了，如需再次安装，请删除 /opt/gorelay 并重新解压。"

info "==== 离线包版本信息 ===="
cat info.txt

info "==== 正在安装 ===="
rm -f info.txt

export NO_DOWNLOAD=1
bash install.sh rel_nodeclient "$1"
