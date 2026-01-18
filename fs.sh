#!/bin/bash

# ======================================================
# 脚本名称: Debian 13 搬瓦工终极管理脚本 (KJYCOMP/mus)
# 版本: v6.5 Final Pro (含一键卸载功能)
# ======================================================

# 颜色定义
RED='\033[31m'
GREEN='\033[32m'
YELLOW='\033[33m'
BLUE='\033[34m'
PLAIN='\033[0m'

# 自动绑定快捷指令 fs
if [ ! -f "/usr/local/bin/fs" ]; then
    ln -sf "$(realpath "$0")" /usr/local/bin/fs 2>/dev/null || true
fi

# 暂停函数
pause() {
    echo -e "\n${YELLOW}------------------------------------------${PLAIN}"
    read -p "操作已完成，按 [Enter] 键返回主菜单..." 
}

# 获取网卡参数
NIC=$(ip route get 8.8.8.8 | grep -oP 'dev \K\S+')
GATEWAY=$(ip route show dev $NIC | grep default | awk '{print $3}')

# --- [模块 9] 彻底卸载脚本与环境 ---
uninstall_all() {
    echo -e "${RED}>>> 警告：即将清理所有配置并移除快捷指令...${PLAIN}"
    read -p "确定要卸载吗？(y/n): " confirm
    if [ "$confirm" != "y" ]; then return; fi

    # 1. 关闭网卡
    wg-quick down wg0 2>/dev/null || true
    
    # 2. 清理策略路由和防火墙
    iptables -t mangle -F
    ip rule del fwmark 0x66 table 100 2>/dev/null || true
    
    # 3. 移除限速
    tc qdisc del dev $NIC root 2>/dev/null || true
    
    # 4. 删除配置文件和程序
    rm -rf /etc/wireguard/wg0.conf
    rm -f /root/wgcf /root/wgcf-account.toml /root/wgcf-profile.conf
    
    # 5. 移除全局快捷键
    rm -f /usr/local/bin/fs
    
    echo -e "${GREEN}卸载完成！所有网络规则已恢复默认。${PLAIN}"
    echo -e "${YELLOW}脚本文件本身依然在 /root/fs.sh，你可以手动执行 rm -f fs.sh 彻底删除。${PLAIN}"
    exit 0
}

# --- [看板] ---
show_status() {
    clear
    echo -e "${BLUE}================================================================${PLAIN}"
    echo -e "${BLUE}          WARP & 系统流量调度看板 (KJYCOMP/mus v6.5)          ${PLAIN}"
    echo -e "${BLUE}================================================================${PLAIN}"
    echo -ne "🕒 时间: $(date +'%H:%M:%S')"
    sysctl net.ipv4.tcp_congestion_control | grep -q "bbr" && echo -ne " | 🚀 BBR: ${GREEN}[ON]${PLAIN}" || echo -ne " | 🚀 BBR: ${RED}[OFF]${PLAIN}"
    tc qdisc show dev $NIC | grep -q "htb" && echo -ne " | 🛡️ 限速: ${GREEN}[50M]${PLAIN}" || echo -ne " | 🛡️ 限速: ${RED}[OFF]${PLAIN}"
    ip rule show | grep -q "0x66" && echo -e " | 🛡️ 入站: ${GREEN}[安全直连]${PLAIN}" || echo -e " | 🛡️ 入站: ${RED}[未保护]${PLAIN}"
    echo -e "${BLUE}================================================================${PLAIN}"
}

# 基础建设 (模块1)
init_system() {
    echo -e "${YELLOW}>>> 正在部署基础优化...${PLAIN}"
    apt update && apt install -y wireguard-tools openresolv curl wget iproute2 nload iptables
    echo "net.core.default_qdisc=fq" > /etc/sysctl.d/99-bbr.conf
    echo "net.ipv4.tcp_congestion_control=bbr" >> /etc/sysctl.d/99-bbr.conf
    sysctl --system
    tc qdisc del dev $NIC root 2>/dev/null || true
    tc qdisc add dev $NIC root handle 1: htb default 11
    tc class add dev $NIC parent 1: classid 1:11 htb rate 50mbit ceil 55mbit
    timedatectl set-timezone Asia/Shanghai
    echo -e "${GREEN}基础建设完成！${PLAIN}"
    pause
}

# 注册证书 (模块2)
register_warp() {
    cd /root
    wget -O wgcf https://github.com/ViRb3/wgcf/releases/download/v2.2.22/wgcf_2.2.22_linux_amd64
    chmod +x wgcf
    ./wgcf register --accept-tos && ./wgcf generate
    [ -f "/root/wgcf-profile.conf" ] && echo -e "${GREEN}成功！${PLAIN}" || echo -e "${RED}失败！${PLAIN}"
    pause
}

# 开启全局 (模块3)
start_global_mode() {
    CONF="/root/wgcf-profile.conf"
    if [ ! -f "$CONF" ]; then echo -e "${RED}未找到证书！${PLAIN}"; pause; return; fi
    sed -i '/Table = off/d' "$CONF"
    sed -i '/\[Interface\]/a Table = off' "$CONF"
    cp "$CONF" /etc/wireguard/wg0.conf
    wg-quick down wg0 2>/dev/null || true
    wg-quick up wg0
    iptables -t mangle -F
    ip rule del fwmark 0x66 table 100 2>/dev/null || true
    iptables -t mangle -A PREROUTING -i $NIC -j CONNMARK --set-mark 0x66
    iptables -t mangle -A OUTPUT -j CONNMARK --restore-mark
    ip rule add fwmark 0x66 table 100
    ip route add default via $GATEWAY dev $NIC table 100 2>/dev/null || true
    echo -e "${GREEN}已启动！${PLAIN}"
    pause
}

# --- 主循环菜单 ---
while true; do
    show_status
    echo -e " 1. 一键优化 (BBR/限速/时区)"
    echo -e " 2. 注册并生成 WARP 证书"
    echo -e " 3. 【开启】全局模式 (含防失联)"
    echo -e " 4. 【关闭】全局模式"
    echo -e " 5. 释放带宽 (1G) / 6. 恢复限速 (50M)"
    echo -e " 7. 实时流量监控 (nload)"
    echo -e " 8. 检测当前网络 IP"
    echo -e " 9. 一键卸载环境并清理脚本"
    echo -e " 0. 退出脚本"
    echo -e "${BLUE}================================================================${PLAIN}"
    read -p "请输入选项 [0-9]: " choice
    case $choice in
        1) init_system ;;
        2) register_warp ;;
        3) start_global_mode ;;
        4) 
            wg-quick down wg0 2>/dev/null || true
            iptables -t mangle -F
            ip rule del fwmark 0x66 table 100 2>/dev/null || true
            echo -e "${GREEN}已关闭。${PLAIN}"; pause ;;
        5) tc qdisc del dev $NIC root 2>/dev/null || true; echo -e "${GREEN}带宽已释放${PLAIN}"; pause ;;
        6) init_system ;;
        7) nload ;;
        8) echo -e "IPv4: $(curl -s4 ip.p3terx.com || echo '失败')"; echo -e "IPv6: $(curl -s6 ip.p3terx.com || echo '失败')"; pause ;;
        9) uninstall_all ;;
        0) exit 0 ;;
        *) echo "无效选项"; sleep 1 ;;
    esac
done