#!/bin/bash

# ======================================================
# 脚本名称: Debian 13 搬瓦工终极管理脚本 (KJYCOMP/mus)
# 版本: v6.6 Final Priority (优先级防失联版)
# ======================================================

RED='\033[31m'
GREEN='\033[32m'
YELLOW='\033[33m'
BLUE='\033[34m'
PLAIN='\033[0m'

# 自动绑定快捷指令 fs
if [ ! -f "/usr/local/bin/fs" ]; then
    ln -sf "$(realpath "$0")" /usr/local/bin/fs 2>/dev/null || true
fi

pause() {
    echo -e "\n${YELLOW}------------------------------------------${PLAIN}"
    read -p "操作已完成，按 [Enter] 键返回主菜单..." 
}

# 动态获取物理网卡和网关
get_network_info() {
    NIC=$(ip -4 route ls | grep default | grep -Po '(?<=dev )(\S+)' | head -n1)
    GATEWAY=$(ip -4 route ls | grep default | grep -Po '(?<=via )(\S+)' | head -n1)
}

show_status() {
    get_network_info
    clear
    echo -e "${BLUE}================================================================${PLAIN}"
    echo -e "${BLUE}          WARP & 系统流量调度看板 (KJYCOMP/mus v6.6)          ${PLAIN}"
    echo -e "${BLUE}================================================================${PLAIN}"
    echo -ne "🕒 时间: $(date +'%H:%M:%S')"
    sysctl net.ipv4.tcp_congestion_control | grep -q "bbr" && echo -ne " | 🚀 BBR: ${GREEN}[ON]${PLAIN}" || echo -ne " | 🚀 BBR: ${RED}[OFF]${PLAIN}"
    ip rule show | grep -q "priority 10" && echo -e " | 🛡️ 入站: ${GREEN}[优先级保护]${PLAIN}" || echo -e " | 🛡️ 入站: ${RED}[未保护]${PLAIN}"
    echo -e "🌐 网卡: ${YELLOW}$NIC${PLAIN} | 网关: ${YELLOW}$GATEWAY${PLAIN}"
    echo -e "${BLUE}================================================================${PLAIN}"
}

# --- 模块 1: 基础建设 ---
init_system() {
    echo -e "${YELLOW}>>> 正在部署基础优化...${PLAIN}"
    apt update && apt install -y wireguard-tools openresolv curl wget iproute2 nload iptables
    echo "net.core.default_qdisc=fq" > /etc/sysctl.d/99-bbr.conf
    echo "net.ipv4.tcp_congestion_control=bbr" >> /etc/sysctl.d/99-bbr.conf
    sysctl --system
    timedatectl set-timezone Asia/Shanghai
    echo -e "${GREEN}优化完成！${PLAIN}"
    pause
}

# --- 模块 2: 获取身份 ---
register_warp() {
    cd /root
    wget -O wgcf https://github.com/ViRb3/wgcf/releases/download/v2.2.22/wgcf_2.2.22_linux_amd64
    chmod +x wgcf
    echo -e "${YELLOW}尝试注册 (如报 500 请忽略，脚本将尝试继续)...${PLAIN}"
    ./wgcf register --accept-tos && ./wgcf generate
    [ -f "/root/wgcf-profile.conf" ] && echo -e "${GREEN}证书生成成功！${PLAIN}" || echo -e "${RED}证书不存在，请手动注入。${PLAIN}"
    pause
}

# --- 模块 3: 【核心】开启全局模式 ---
start_global_mode() {
    get_network_info
    CONF="/root/wgcf-profile.conf"
    if [ ! -f "$CONF" ]; then echo -e "${RED}错误：请先执行选项 2 或手动注入证书！${PLAIN}"; pause; return; fi

    echo -e "${YELLOW}>>> 正在应用优先级路由策略...${PLAIN}"
    
    # 强制修改配置，禁用自动路由防止冲突
    sed -i '/Table = off/d' "$CONF"
    sed -i '/\[Interface\]/a Table = off' "$CONF"
    cp "$CONF" /etc/wireguard/wg0.conf

    # 启动网卡
    wg-quick down wg0 2>/dev/null || true
    wg-quick up wg0

    # 1. 设置优先级 10：锁定 SSH (端口 22) 走原路直连
    iptables -t mangle -F
    iptables -t mangle -A PREROUTING -i $NIC -p tcp --dport 22 -j CONNMARK --set-mark 0x66
    iptables -t mangle -A OUTPUT -p tcp --sport 22 -j CONNMARK --restore-mark
    
    ip rule del fwmark 0x66 table 100 2>/dev/null || true
    ip route flush table 100 2>/dev/null || true
    ip rule add fwmark 0x66 table 100 priority 10
    ip route add default via $GATEWAY dev $NIC table 100

    # 2. 设置优先级 100：将其余流量全部赶进 WARP
    ip rule del table 200 2>/dev/null || true
    ip route flush table 200 2>/dev/null || true
    
    # IPv4 路由
    ip -4 route add default dev wg0 table 200
    ip -4 rule add from 0.0.0.0/0 table 200 priority 100
    
    # IPv6 路由
    ip -6 route add default dev wg0 table 200
    ip -6 rule add from ::/0 table 200 priority 100

    echo -e "${GREEN}全局模式已开启！SSH 使用优先级 10 保护。${PLAIN}"
    pause
}

# --- 模块 4: 关闭全局模式 ---
stop_global_mode() {
    echo -e "${YELLOW}>>> 正在恢复原生网络...${PLAIN}"
    wg-quick down wg0 2>/dev/null || true
    iptables -t mangle -F
    ip rule del priority 10 2>/dev/null || true
    ip rule del priority 100 2>/dev/null || true
    ip route flush table 100 2>/dev/null || true
    ip route flush table 200 2>/dev/null || true
    echo -e "${GREEN}全局模式已关闭。${PLAIN}"
    pause
}

# --- 模块 9: 彻底卸载 ---
uninstall_all() {
    stop_global_mode
    rm -f /root/wgcf /root/wgcf-account.toml /root/wgcf-profile.conf /usr/local/bin/fs
    echo -e "${GREEN}卸载完成，再见！${PLAIN}"
    exit 0
}

# --- 主菜单 ---
while true; do
    show_status
    echo -e " 1. 一键系统优化 (BBR/时区)"
    echo -e " 2. 注册 WARP 账号 (生成证书)"
    echo -e " 3. 【开启】全局模式 (优先级防失联)"
    echo -e " 4. 【关闭】全局模式"
    echo -e " 7. 实时流量监控 (nload)"
    echo -e " 8. 检测当前网络 IP"
    echo -e " 9. 一键卸载环境"
    echo -e " 0. 退出脚本"
    echo -e "${BLUE}================================================================${PLAIN}"
    read -p "请输入选项 [0-9]: " choice
    case $choice in
        1) init_system ;;
        2) register_warp ;;
        3) start_global_mode ;;
        4) stop_global_mode ;;
        7) nload ;;
        8) 
            echo -e "${YELLOW}正在查询 IPv4...${PLAIN}"
            echo -e "IPv4: $(curl -s4 --connect-timeout 5 ip.p3terx.com || echo '无法连接')"
            echo -e "${YELLOW}正在查询 IPv6...${PLAIN}"
            echo -e "IPv6: $(curl -s6 --connect-timeout 5 ip.p3terx.com || echo '无法连接')"
            pause ;;
        9) uninstall_all ;;
        0) exit 0 ;;
        *) echo "无效选项"; sleep 1 ;;
    esac
done