#!/bin/bash
set -e

warning() { echo -e "\033[31m\033[01m$*\033[0m"; }         # 红色
error() { echo -e "\033[31m\033[01m$*\033[0m" && exit 1; } # 红色
info() { echo -e "\033[32m\033[01m$*\033[0m"; }            # 绿色
hint() { echo -e "\033[33m\033[01m$*\033[0m"; }            # 黄色

DOWNLOAD_HOST="https://api.gorelay.net"
PRODUCT="$1"
PRODUCT_ARGUMENTS="$2"

if [ -z "$PRODUCT" ]; then
    error "输入有误"
fi

if [ -z "$PRODUCT_ARGUMENTS" ]; then
    error "输入有误"
fi

if [ "$PRODUCT_ARGUMENTS" == "update" ]; then
    if [ -z "$BG_UPDATE" ]; then
        BG_UPDATE=1 bash "$0" "$1" "$2" >/dev/null 2>&1 &
        exit
    fi
fi

#### 判断处理器架构

case $(uname -m) in
aarch64 | arm64) ARCH=arm64 ;;
x86_64 | amd64) [[ "$(awk -F ':' '/flags/{print $2; exit}' /proc/cpuinfo)" =~ avx2 ]] && ARCH=amd64v3 || ARCH=amd64 ;;
*) error "cpu not supported" ;;
esac

if grep "Intel Core Processor (Broadwell)" /proc/cpuinfo >/dev/null 2>&1; then
    ARCH=amd64
fi

PRODUCT="$PRODUCT"_linux_"$ARCH"

#### 重复安装

echo_uninstall() {
    echo "systemctl disable --now $1 ; rm -rf /opt/$1 ; rm -f /etc/systemd/system/$1.service"
}

echo_uninstall_to_file() {
    echo "systemctl disable --now $1 ; rm -rf /opt/$1 ; rm -f /etc/systemd/system/$1.service" >"$2"
}

#### 询问用户

if [ -z "$BG_UPDATE" ]; then
    read -p "请输入服务名 [默认 gorelay] : " service_name
    service_name=$(echo "$service_name" | awk '{print$1}')
    if [ -z "$service_name" ]; then
        service_name="gorelay"
    fi
    #
    if [ -f "/etc/systemd/system/${service_name}.service" ]; then
        hint "该服务已经存在，请先运行以下命令卸载："
        echo_uninstall "$service_name"
        exit
    fi
    ##
    read -p "是否优化系统参数 [输入 n 不优化，默认优化] : " youhua
    youhua=$(echo "$youhua" | awk '{print$1}' | tr A-Z a-z)
    if [ "$youhua" != "n" ]; then
        OPTIMIZE=1
    fi
    ##
    read -p "是否安装常用工具 [输入 n 不安装，默认安装] : " azcygj
    azcygj=$(echo "$azcygj" | awk '{print$1}' | tr A-Z a-z)
    if [ "$azcygj" != "n" ]; then
        INSTALL_TOOLS=1
    fi
else
    service_name=$(basename "$PWD")
fi

#### ？

if [ -z "$BG_UPDATE" ]; then
    mkdir -p /etc/systemd/system
    mkdir -p ~/.config
    mkdir -p /opt/"${service_name}"
    cd /opt/"${service_name}"
    #### 安装一些常用工具
    if [ -z "$NYP_DOCKER" ]; then
        if [ -n "$INSTALL_TOOLS" ]; then
            apt-get update
            apt-get install -y wget curl mtr-tiny iftop unzip htop net-tools dnsutils nload psmisc nano
        fi
    fi
fi

#### Download & unzip product (rel_nodeclient)

rm -rf temp_backup
mkdir -p temp_backup

if [ -z "$NO_DOWNLOAD" ]; then
    mv rel_nodeclient temp_backup/ || true
    mv realnya temp_backup/ || true
    curl -fLSsO "$DOWNLOAD_HOST"/download/download.sh
    bash download.sh "$DOWNLOAD_HOST" "$PRODUCT"
fi

if [ -f "rel_nodeclient" ]; then
    rm -rf temp_backup
else
    mv temp_backup/* .
    error "下载失败！"
fi

#### Install

if [ -z "$BG_UPDATE" ]; then
    rm -f start.sh
    echo 'source ./env.sh || true' >>start.sh
    echo './rel_nodeclient' "$PRODUCT_ARGUMENTS" >>start.sh
fi

echo "[Unit]
Description=gorelay
After=network-online.target
Wants=network-online.target systemd-networkd-wait-online.service
[Service]
Type=simple
LimitAS=infinity
LimitRSS=infinity
LimitCORE=infinity
LimitNOFILE=999999
User=root
Restart=always
RestartSec=3
WorkingDirectory=/opt/${service_name}
ExecStart=/bin/bash /opt/${service_name}/start.sh
[Install]
WantedBy=multi-user.target
" >/etc/systemd/system/"${service_name}".service

systemctl daemon-reload
systemctl enable --now "${service_name}"
systemctl restart "${service_name}"

info "安装成功"
info "如需卸载，请运行以下命令："
echo_uninstall "$service_name"

UNINSTALL_FILE="/opt/${service_name}.uninstall.sh"
echo_uninstall_to_file "$service_name" "$UNINSTALL_FILE"
info "或者："
echo "bash $UNINSTALL_FILE"

if [ -n "$BG_UPDATE" ]; then
    # TODO BUG?
    if [ -n "$NYP_DOCKER" ]; then
        kill -9 1
    fi
fi

echo

#### 系统参数优化

if [ -n "$OPTIMIZE" ]; then
    info "正在优化系统参数..."
    echo '
net.core.default_qdisc = fq
net.ipv4.tcp_congestion_control = bbr

net.ipv4.conf.all.rp_filter = 0
net.ipv4.tcp_no_metrics_save = 1
net.ipv4.tcp_ecn = 0
net.ipv4.tcp_frto = 0
net.ipv4.tcp_mtu_probing = 0
net.ipv4.tcp_rfc1337 = 1
net.ipv4.tcp_sack = 1
net.ipv4.tcp_fack = 1
net.ipv4.tcp_window_scaling = 1
net.ipv4.tcp_adv_win_scale = 2
net.ipv4.tcp_moderate_rcvbuf = 1
net.ipv4.tcp_rmem = 4096 65536 16777216
net.ipv4.tcp_wmem = 4096 65536 16777216
net.core.rmem_max = 16777216
net.core.wmem_max = 16777216
net.ipv4.udp_rmem_min = 8192
net.ipv4.udp_wmem_min = 8192
net.ipv4.ip_local_port_range = 1024 65535
net.ipv4.tcp_timestamps = 1
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_max_syn_backlog = 4096
net.core.somaxconn = 4096
net.ipv4.tcp_abort_on_overflow = 1

vm.swappiness = 10
fs.file-max = 6553560
' >/etc/sysctl.conf
    sysctl -p
fi

#### 检查 bbr

info "当前 TCP 阻控算法: " "$(cat /proc/sys/net/ipv4/tcp_congestion_control)"
