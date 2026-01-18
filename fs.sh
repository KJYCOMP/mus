#!/bin/bash

# ======================================================
# 脚本名称: Debian 13 搬瓦工终极优化与全流量保护脚本
# 版本: v6.2 Final Pro (GitHub 存档版)
# 特性: BBR+FQ | 50M限速 | 全入站防失联 | 随机SOCKS5 | SSH直连
# ======================================================

set -e 

# 颜色定义
RED='\033[31m'
GREEN='\033[32m'
YELLOW='\033[33m'
BLUE='\033[34m'
CYAN='\033[0;36m'
PLAIN='\033[0m'

# 自动获取底层核心网络参数
NIC=$(ip route get 8.8.8.8 | grep -oP 'dev \K\S+')
GATEWAY=$(ip route show dev $NIC | grep default | awk '{print $3}')

# --- [看板] 实时读取系统状态 ---
show_status() {
    clear
    echo -e "${BLUE}================================================================${PLAIN}"
    echo -e "${BLUE}          WARP & 系统流量调度看板 (全保护终极版)          ${PLAIN}"
    echo -e "${BLUE}================================================================${PLAIN}"
    echo -ne "🕒 时间: $(date +'%H:%M:%S')"
    sysctl net.ipv4.tcp_congestion_control | grep -q "bbr" && echo -ne " | 🚀 BBR: ${GREEN}[ON]${PLAIN}" || echo -ne " | 🚀 BBR: ${RED}[OFF]${PLAIN}"
    tc qdisc show dev $NIC | grep -q "htb" && echo -ne " | 🛡️ 限速: ${GREEN}[50M]${PLAIN}" || echo -ne " | 🛡️ 限速: ${RED}[OFF]${PLAIN}"
    ip rule show | grep -q "0x66" && echo -e " | 🛡️ 入站: ${GREEN}[安全直连]${PLAIN}" || echo -e " | 🛡️ 入站: ${RED}[未保护]${PLAIN}"
    echo -e "${BLUE}================================================================${PLAIN}"
}

# --- [模块 1] 基础建设 ---
init_system() {
    echo -e "${YELLOW}>>> 正在部署基础优化 (BBR/50M限速/上海时间)...${PLAIN}"
    apt update && apt install -y wireguard-tools openresolv curl wget systemd-timesyncd iproute2 nload iptables net-tools
    
    # 开启 BBR
    echo "net.core.default_qdisc=fq" > /etc/sysctl.d/99-bbr.conf
    echo "net.ipv4.tcp_congestion_control=bbr" >> /etc/sysctl.d/99-bbr.conf
    sysctl --system
    
    # 应用 50M 黄金限速 (HTB)
    tc qdisc del dev $NIC root 2>/dev/null || true
    tc qdisc add dev $NIC root handle 1: htb default 11
    tc class add dev $NIC parent 1: classid 1:11 htb rate 50mbit ceil 55mbit
    
    # 时区同步
    timedatectl set-timezone Asia/Shanghai
    echo -e "${GREEN}基础建设完成！系统已进入最优运行状态。${PLAIN}"
    sleep 2
}

# --- [模块 2] 身份准备 ---
register_warp() {
    echo -e "${YELLOW}>>> 正在注册/同步 WARP 账户证书...${PLAIN}"
    if [ ! -f "wgcf" ]; then
        curl -fsSL git.io/wgcf.sh | bash
    fi
    ./wgcf register --accept-tos && ./wgcf generate
    echo -e "${GREEN}证书已生成 (wgcf-profile.conf)。${PLAIN}"; sleep 2
}

# --- [模块 3] 全局网卡模式 (带动态保护) ---
start_global_mode() {
    echo -e "${YELLOW}>>> 启动全局模式并激活“全入站流量保护”...${PLAIN}"
    if [ ! -f "wgcf-profile.conf" ]; then
        echo -e "${RED}错误：请先执行选项 2 获取证书！${PLAIN}"; sleep 2; return
    fi

    # 1. 配置文件处理 (Table = off 是关键)
    sed -i '/Table = off/d' wgcf-profile.conf
    sed -i '/\[Interface\]/a Table = off' wgcf-profile.conf
    cp wgcf-profile.conf /etc/wireguard/wg0.conf

    # 2. 启动隧道
    wg-quick up wg0 2>/dev/null || true

    # 3. 核心升华：CONNMARK 流量分流保护 (实现入站直连回包)
    iptables -t mangle -F 2>/dev/null || true
    ip rule del fwmark 0x66 table 100 2>/dev/null || true
    
    # 核心逻辑：凡是从物理网卡进来的连接，回包必须原路返回
    iptables -t mangle -A PREROUTING -i $NIC -j CONNMARK --set-mark 0x66
    iptables -t mangle -A OUTPUT -j CONNMARK --restore-mark
    ip rule add fwmark 0x66 table 100
    ip route add default via $GATEWAY dev $NIC table 100 2>/dev/null || true
    
    echo -e "${GREEN}全局模式启动！SSH、面板及节点入站已强制直连，主动出站流量走 WARP。${PLAIN}"
    sleep 2
}

# --- [模块 4] 局部代理模式 (自定义端口) ---
start_proxy_mode() {
    echo -e "${YELLOW}>>> SOCKS5 代理配置定制化...${PLAIN}"
    if [ ! -f "wgcf-profile.conf" ]; then
        echo -e "${RED}错误：请先执行选项 2 获取证书！${PLAIN}"; sleep 2; return
    fi

    read -p "请输入 SOCKS5 端口 [1024-65535] (回车则随机生成): " USER_PORT
    if [ -z "$USER_PORT" ]; then
        while :; do
            USER_PORT=$(shuf -i 20000-60000 -n 1)
            netstat -tunlp | grep -q ":$USER_PORT " || break
        done
        echo -e "${GREEN}已为你随机生成端口: $USER_PORT${PLAIN}"
    fi

    echo -e "---------------------------------------------------"
    echo -e "${BLUE}配置指引：请在 3X-UI 面板添加以下出站 (Outbound)${PLAIN}"
    echo -e "  - 协议: ${YELLOW}SOCKS5 / WireGuard${PLAIN}"
    echo -e "  - 端口: ${GREEN}$USER_PORT${PLAIN}"
    echo -e "  - 证书路径: ${CYAN}$(pwd)/wgcf-profile.conf${PLAIN}"
    echo -e "---------------------------------------------------"
    echo -e "${BLUE}特性：此模式下节点入站天然直连，无需额外路由配置。${PLAIN}"
    sleep 5
}

# --- 主循环菜单 ---
while true; do
    show_status
    echo -e " ${YELLOW}[第一步] 系统优化 (Infrastructure)${PLAIN}"
    echo -e "  1. 一键全家桶 (BBR+50M限速+时区优化)"
    echo -e ""
    echo -e " ${YELLOW}[第二步] 获取身份 (Identity)${PLAIN}"
    echo -e "  2. 注册 WARP 账户生成证书 (必备基石)"
    echo -e ""
    echo -e " ${YELLOW}[第三步] 部署全局 (Global Interface)${PLAIN}"
    echo -e "  3. 【开启】系统全局网卡 (支持 SSH/面板/节点直连保护)"
    echo -e "  4. 【关闭】系统全局网卡"
    echo -e ""
    echo -e " ${YELLOW}[第四步] 部署局部 (Proxy Mode)${PLAIN}"
    echo -e "  5. 自定义 SOCKS5 端口 / 联动 3X-UI 指引"
    echo -e ""
    echo -e " ${YELLOW}[第五步] 运维工具 (Maintenance)${PLAIN}"
    echo -e "  6. 释放带宽 (1G) / 7. 恢复 50M 限速"
    echo -e "  8. 实时流量监控 (nload) / 9. 检测连通性"
    echo -e "  0. 退出脚本"
    echo -e "${BLUE}================================================================${PLAIN}"
    read -p "请输入选项 [0-9]: " choice
    case $choice in
        1) init_system ;;
        2) register_warp ;;
        3) start_global_mode ;;
        4) wg-quick down wg0 2>/dev/null || true; iptables -t mangle -F; ip rule del fwmark 0x66 table 100 2>/dev/null || true; echo -e "${YELLOW}已关闭全局并清理保护规则${PLAIN}"; sleep 2 ;;
        5) start_proxy_mode ;;
        6) tc qdisc del dev $NIC root 2>/dev/null; echo -e "${GREEN}限速已解除，恢复 1G 满血带宽${PLAIN}"; sleep 2 ;;
        7) init_system ;;
        8) nload ;;
        9) echo -e "IPv4: $(curl -s4 ip.p3terx.com || echo 'Failed') | IPv6: $(curl -s6 ip.p3terx.com || echo 'Failed')"; sleep 5 ;;
        0) exit 0 ;;
    esac
done