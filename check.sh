#!/bin/bash
export LANG=zh_CN.UTF-8

# === 颜色定义 ===
C_TITLE='\033[1;44;37m' 
C_CYAN='\033[1;36m'
C_GREEN='\033[1;32m'
C_YELLOW='\033[1;33m'
C_RED='\033[1;31m'
C_PURPLE='\033[1;35m'
C_WHITE='\033[1;37m'
C_RESET='\033[0m'

clear

# === 核心逻辑函数 ===
test_sz() {
    local res=$(ping -c 2 -W 1 $2 2>/dev/null | grep rtt | cut -d"/" -f5)
    echo -ne "${1}:${res:-${C_RED}超时${C_RESET}}${C_GREEN}${res:+ms}${C_RESET}"
}

get_ver() {
    if ! command -v $1 >/dev/null 2>&1; then echo "---"; return; fi
    case $1 in
        nginx) nginx -v 2>&1 | cut -d/ -f2 | awk '{print $1}' ;;
        node) node -v | sed 's/v//' ;;
        npm) npm -v ;;
        pm2) pm2 -v ;;
        python3) python3 -V 2>&1 | awk '{print $2}' ;;
        docker) docker --version | awk '{print $3}' | sed 's/,//' ;;
        mysql|mysqld) mysql --version 2>&1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1 ;;
        *) echo "已安装" ;;
    esac
}

# === 数据采集 ===
echo -e "\n${C_TITLE}   💎 VPS 开发者全能看板 (GitHub 同步版)   ${C_RESET}"

# --- 资源状态 ---
echo -e "\n${C_CYAN}【一、核心资源 & 深圳回程】${C_RESET}"
echo -e "┌────────────────────────────────────────────────────────────┐"
ram_total=$(free -m | awk '/Mem:/ {print $2}')
ram_used=$(free -m | awk '/Mem:/ {print $3}')
ram_pct=$(( ram_used * 100 / ram_total ))
swap_total=$(free -m | awk '/Swap:/ {print $2}')
printf "│ 内存: %-22s │ Swap: %-25s │\n" "${ram_pct}% (${ram_used}MB)" "${swap_total}MB ($([ $swap_total -eq 0 ] && echo -e "${C_RED}未开启${C_RESET}" || echo -e "${C_GREEN}已开启${C_RESET}"))"
echo -ne "│ 深圳延迟: "
echo -ne "$(test_sz "电信" "119.147.15.13")  " 
echo -ne "$(test_sz "联通" "58.250.0.1")  "    
echo -ne "$(test_sz "移动" "211.139.129.222")" 
echo -e "   │"
echo -e "└────────────────────────────────────────────────────────────┘"

# --- 软件清单 ---
echo -e "\n${C_PURPLE}【二、开发者全量环境版本清单】${C_RESET}"
echo -e "┌──────────────┬───────────────┬──────────────┬───────────────┐"
items=("nginx" "node" "npm" "pm2" "python3" "docker" "mysql")
count=0
for app in "${items[@]}"; do
    v=$(get_ver "$app")
    [ "$v" == "---" ] && color=$C_RED || color=$C_GREEN
    printf "│ %-12s │ ${color}%-13s${C_RESET} " "$app" "$v"
    ((count++))
    if [ $((count % 2)) -eq 0 ]; then echo "│"; fi
done
[ $((count % 2)) -ne 0 ] && echo "│"
echo -e "└──────────────┴───────────────┴──────────────┴───────────────┘"

# --- 端口识别 ---
echo -e "\n${C_PURPLE}【三、网络占用 & 进程溯源】${C_RESET}"
echo -e "┌──────────┬────────┬──────────────┬──────────────────────────────────────────┐"
echo -e "│ 协议     │ 端口   │ 占用进程     │ 业务备注 / 域名 / 源码目录               │"
echo -e "├──────────┼────────┼──────────────┼──────────────────────────────────────────┤"

used_ports_file="/tmp/vps_ports.txt"
> $used_ports_file

while read -r line; do
    proto=$(echo $line | cut -d'|' -f1)
    port=$(echo $line | cut -d'|' -f2)
    name=$(echo $line | cut -d'|' -f3)
    pid=$(echo $line | cut -d'|' -f4)
    echo "$port" >> $used_ports_file
    case "$name" in
        nginx) 
            domains=$(grep -lriE "listen.*[: ]$port([ ;]|$)" /etc/nginx/ 2>/dev/null | xargs grep -i "server_name" 2>/dev/null | awk '{for(i=2;i<=NF;i++) print $i}' | sed 's/;//g' | grep -vE "localhost|_|example.com" | sort -u | xargs)
            info="${C_CYAN}${domains:-默认站点}${C_RESET} ${C_YELLOW}【部署网址】${C_RESET}" ;;
        node)
            path=$(readlink -f /proc/$pid/cwd 2>/dev/null)
            info="${C_YELLOW}Node项目${C_RESET} 📂:${path:-未知}" ;;
        sshd) info="SSH 远程登录服务" ;;
        systemd-resolve) info="${C_WHITE}DNS 系统解析服务${C_RESET}" ;;
        *) info="基础/系统进程" ;;
    esac
    echo -e "│ $(printf "%-8s" "$proto") │ $(printf "%-6s" "$port") │ $(printf "%-12s" "$name") │ $(printf "%-40s" "$info") │"
done < <(ss -tunlp | grep LISTEN | awk '{
    split($5,a,":"); port=a[length(a)]; 
    prog=$7; gsub(/"/,"",prog); split(prog,p,",");
    pname=p[1]; sub(/users:\(\(/,"",pname);
    pid=p[2]; sub(/pid=/,"",pid);
    printf "%s|%s|%s|%s\n", $1, port, pname, pid
}' | sort -t'|' -k2 -n | uniq)

echo -e "└──────────┴────────┴──────────────┴──────────────────────────────────────────┘"

echo -e "\n${C_YELLOW}【四、🚀 智能部署建议】${C_RESET}"
echo -e "${C_CYAN}────────────────────────────────────────────────────────────${C_RESET}"
all_ports=$(cat $used_ports_file)
if echo "$all_ports" | grep -qwE "3000|3001"; then
    echo -e "  ● ${C_RED}[端口占用]${C_RESET} 3000/3010 常用端口已被占，新项目请使用 9000+。"
else
    echo -e "  ● ${C_GREEN}[端口充足]${C_RESET} 3000-3010 端口可用。"
fi
echo -e "  ● ${C_WHITE}[无痕说明]${C_RESET} 脚本执行后已自动自毁，不留痕迹。"
echo -e "${C_CYAN}────────────────────────────────────────────────────────────${C_RESET}"

rm -f $used_ports_file
rm -f "$0"
