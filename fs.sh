#!/bin/bash

# ======================================================
# 脚本名称: Debian 13 搬瓦工终极管理脚本 (KJYCOMP/mus)
# 版本: v6.8 Final (智能在线申请 + 优先级防失联版)
# ======================================================

RED='\033[31m'
GREEN='\033[32m'
YELLOW='\033[33m'
BLUE='\033[34m'
PLAIN='\033[0m'

# 自动绑定快捷指令
[ ! -f "/usr/local/bin/fs" ] && ln -sf "$(realpath "$0")" /usr/local/bin/fs 2>/dev/null

pause() {
    echo -e "\n${YELLOW}------------------------------------------${PLAIN}"
    read -p "操作已完成，按 [Enter] 键返回主菜单..." 
}

# 获取网络信息
get_network_info() {
    NIC=$(ip -4 route ls | grep default | grep -Po '(?<=dev )(\S+)' | head -n1)
    GATEWAY=$(ip -4 route ls | grep default | grep -Po '(?<=via )(\S+)' | head -n1)
}

show_status() {
    get_network_info
    clear
    echo -e "${BLUE}================================================================${PLAIN}"
    echo -e "${BLUE}          WARP 智能调度看板 (KJYCOMP/mus v6.8)          ${PLAIN}"
    echo -e "${BLUE}================================================================${PLAIN}"
    echo -ne "🕒 时间: $(date +'%H:%M:%S')"
    sysctl net.ipv4.tcp_congestion_control | grep -q "bbr" && echo -ne " | 🚀 BBR: ${GREEN}[ON]${PLAIN}" || echo -ne " | 🚀 BBR: ${RED}[OFF]${PLAIN}"
    wg show wg0 2>/dev/null | grep -q "handshake" && echo -e " | 🌐 WARP: ${GREEN}[已握手]${PLAIN}" || echo -e " | 🌐 WARP: ${RED}[未连接]${PLAIN}"
    echo -e "🌐 网卡: ${YELLOW}$NIC${PLAIN} | 网关: ${YELLOW}$GATEWAY${PLAIN}"
    echo -e "${BLUE}================================================================${PLAIN}"
}

# --- 模块 1: 基础建设 ---
init_system() {
    echo -e "${YELLOW}>>> 正在部署基础工具...${PLAIN}"
    apt update && apt install -y wireguard-tools openresolv curl wget iproute2 iptables openssl
    echo "net.core.default_qdisc=fq" > /etc/sysctl.d/99-bbr.conf
    echo "net.ipv4.tcp_congestion_control=bbr" >> /etc/sysctl.d/99-bbr.conf
    sysctl --system
    echo -e "${GREEN}基础优化完成！${PLAIN}"
    pause
}

# --- 模块 2: 智能在线注册 (模拟大佬绕路方案) ---
register_warp() {
    cd /root
    echo -e "${YELLOW}>>> 正在获取 wgcf 主程序...${PLAIN}"
    wget -N https://github.com/ViRb3/wgcf/releases/download/v2.2.22/wgcf_2.2.22_linux_amd64 -O wgcf
    chmod +x wgcf
    
    echo -e "${YELLOW}>>> 注入 Hosts 劫持以绕过 500 错误...${PLAIN}"
    # 强制将 API 指向 Cloudflare 的边缘 IP
    sed -i '/api.cloudflareclient.com/d' /etc/hosts
    echo "162.159.192.1 api.cloudflareclient.com" >> /etc/hosts

    echo -e "${YELLOW}>>> 尝试在线申请身份...${PLAIN}"
    rm -f wgcf-account.toml wgcf-profile.conf
    ./wgcf register --accept-tos
    
    if [ $? -ne 0 ]; then
        echo -e "${RED}在线申请失败！尝试方案 B (备选域名)...${PLAIN}"
        sed -i '/api.cloudflareclient.com/d' /etc/hosts
        echo "162.159.193.1 api.cloudflareclient.com" >> /etc/hosts
        ./wgcf register --accept-tos
    fi

    ./wgcf generate
    sed -i '/api.cloudflareclient.com/d' /etc/hosts

    if [ -f "/root/wgcf-profile.conf" ]; then
        echo -e "${GREEN}在线申请成功！证书已保存。${PLAIN}"
    else
        echo -e "${RED}申请依然失败，可能该 IP 段已被彻底黑掉，请从本地电脑上传证书。${PLAIN}"
    fi
    pause
}

# --- 模块 3: 开启全局模式 (带端口探测) ---
start_global_mode() {
    get_network_info
    CONF="/root/wgcf-profile.conf"
    if [ ! -f "$CONF" ]; then echo -e "${RED}错误：证书不存在！请先执行选项 2。${PLAIN}"; pause; return; fi

    echo -e "${YELLOW}>>> 配置策略路由保护 SSH...${PLAIN}"
    sed -i '/Table = off/d' "$CONF"
    sed -i '/\[Interface\]/a Table = off' "$CONF"
    cp "$CONF" /etc/wireguard/wg0.conf

    # 锁定 SSH 直连 (Priority 10)
    iptables -t mangle -F
    iptables -t mangle -A PREROUTING -i $NIC -p tcp --dport 22 -j CONNMARK --set-mark 0x66
    iptables -t mangle -A OUTPUT -p tcp --sport 22 -j CONNMARK --restore-mark
    ip rule del priority 10 2>/dev/null || true
    ip route flush table 100 2>/dev/null || true
    ip rule add fwmark 0x66 table 100 priority 10
    ip route add default via $GATEWAY dev $NIC table 100

    # 尝试多端口握手
    for port in 2408 500 4500 1701; do
        echo -e "${YELLOW}正在尝试端口 $port 建立隧道...${PLAIN}"
        sed -i "s/Endpoint = .*/Endpoint = 162.159.193.10:$port/" /etc/guard/wg0.conf 2>/dev/null || \
        sed -i "s/Endpoint = .*/Endpoint = 162.159.193.10:$port/" /etc/wireguard/wg0.conf
        
        wg-quick down wg0 2>/dev/null || true
        wg-quick up wg0 2>/dev/null
        
        sleep 3
        if wg show wg0 | grep -q "latest handshake"; then
            echo -e "${GREEN}端口 $port 握手成功！${PLAIN}"
            # 开启全局路由 (Priority 100)
            ip rule del priority 100 2>/dev/null || true
            ip -4 route add default dev wg0 table 200 2>/dev/null || true
            ip -4 rule add from 0.0.0.0/0 table 200 priority 100
            echo -e "${GREEN}全局模式已完全激活！${PLAIN}"
            pause && return
        fi
    done

    echo -e "${RED}所有端口握手失败，正在回滚...${PLAIN}"
    wg-quick down wg0 2>/dev/null
    pause
}

# --- 模块 4: 关闭全局模式 ---
stop_global_mode() {
    echo -e "${YELLOW}>>> 恢复原生网络...${PLAIN}"
    wg-quick down wg0 2>/dev/null || true
    iptables -t mangle -F
    ip rule del priority 10 2>/dev/null || true
    ip rule del priority 100 2>/dev/null || true
    echo -e "${GREEN}已恢复原生 IP。${PLAIN}"
    pause
}

# --- 主菜单 ---
while true; do
    show_status
    echo -e " 1. 一键环境优化"
    echo -e " 2. 在线申请身份 (Hosts 劫持版)"
    echo -e " 3. 【开启】全局模式 (多端口盲测)"
    echo -e " 4. 【关闭】全局模式"
    echo -e " 8. 检测当前网络 IP"
    echo -e " 9. 一键卸载清理"
    echo -e " 0. 退出"
    echo -e "${BLUE}================================================================${PLAIN}"
    read -p "请输入选项 [0-9]: " choice
    case $choice in
        1) init_system ;;
        2) register_warp ;;
        3) start_global_mode ;;
        4) stop_global_mode ;;
        8) 
            echo -e "IPv4: $(curl -s4m 5 ip.p3terx.com || echo '无法连接')"
            echo -e "IPv6: $(curl -s6m 5 ip.p3terx.com || echo '无法连接')"
            pause ;;
        9) stop_global_mode; rm -rf /root/wgcf* /usr/local/bin/fs; exit 0 ;;
        0) exit 0 ;;
        *) echo "无效选项"; sleep 1 ;;
    esac
done