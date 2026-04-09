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

# === 全局变量 ===
used_ports_file="/tmp/vps_ports.txt"
> $used_ports_file
nginx_domains=""

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
        redis-cli) redis-cli -v | awk '{print $2}' ;;
        git) git --version | awk '{print $3}' ;;
        php) php -v | head -n 1 | awk '{print $2}' ;;
        java) java -version 2>&1 | awk -F '"' '/version/ {print $2}' ;;
        go) go version | awk '{print $3}' | sed 's/go//' ;;
        *) echo "已安装" ;;
    esac
}

# === 数据采集 ===
echo -e "\n${C_TITLE}    💎 VPS 开发者全能看板 (MAX 生产级高可用版)    ${C_RESET}"

# --- 硬件、网络与系统负载 ---
echo -e "\n${C_CYAN}【零、基础硬件 & 系统负载】${C_RESET}"
echo -e "┌────────────────────────────────────────────────────────────┐"
os_name=$(cat /etc/os-release 2>/dev/null | grep PRETTY_NAME | cut -d '"' -f 2)
cpu_model=$(grep -m 1 "model name" /proc/cpuinfo | cut -d: -f2 | sed 's/^ *//')
cpu_cores=$(nproc)
disk_usage=$(df -h / | awk 'NR==2 {print $3 " / " $2 " ("$5")"}')
up_time=$(uptime -p 2>/dev/null | sed 's/up //')
load_avg=$(cat /proc/loadavg | awk '{print $1", "$2", "$3}')

# 双栈 IP 并发检测 (2秒 超时防卡死)
ipv4=$(curl -s4m2 icanhazip.com 2>/dev/null)
ipv6=$(curl -s6m2 icanhazip.com 2>/dev/null)

printf "│ 系统: %-52s │\n" "${os_name:-未知 Linux}"
printf "│ 核心: %-52s │\n" "${cpu_cores}核 | ${cpu_model:-未知 CPU}"
printf "│ 硬盘: %-22s │ 负载: %-25s │\n" "$disk_usage" "${load_avg}"
printf "│ IPv4: %-52s │\n" "${ipv4:-未分配 / 禁用}"
printf "│ IPv6: %-52s │\n" "${ipv6:-未分配 / 禁用}"
printf "│ 运行: %-52s │\n" "${up_time:-未知}"
echo -e "└────────────────────────────────────────────────────────────┘"

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
items=("nginx" "node" "npm" "pm2" "python3" "docker" "mysql" "redis-cli" "git" "php" "java" "go")
count=0
for app in "${items[@]}"; do
    v=$(get_ver "$app")
    [ "$v" == "---" ] && color=$C_RED || color=$C_GREEN
    display_name="$app"
    [ "$app" == "redis-cli" ] && display_name="redis"
    printf "│ %-12s │ ${color}%-13s${C_RESET} " "$display_name" "$v"
    ((count++))
    if [ $((count % 2)) -eq 0 ]; then echo "│"; fi
done
[ $((count % 2)) -ne 0 ] && echo "│"
echo -e "└──────────────┴───────────────┴──────────────┴───────────────┘"

# --- 端口识别与深度溯源 ---
echo -e "\n${C_PURPLE}【三、网络占用 & 深度进程溯源】${C_RESET}"
echo -e "┌──────────┬────────┬──────────────┬──────────────────────────────────────────┐"
echo -e "│ 协议     │ 端口   │ 占用进程     │ 业务备注 / 域名 / 识别类型               │"
echo -e "├──────────┼────────┼──────────────┼──────────────────────────────────────────┤"

while read -r line; do
    proto=$(echo $line | cut -d'|' -f1)
    port=$(echo $line | cut -d'|' -f2)
    name=$(echo $line | cut -d'|' -f3)
    pid=$(echo $line | cut -d'|' -f4)
    
    echo "$port" >> $used_ports_file
    lower_name=$(echo "$name" | tr 'A-Z' 'a-z')
    
    case "$lower_name" in
        *nginx*) 
            domains=$(grep -lriE "listen.*[: ]$port([ ;]|$)" /etc/nginx/ 2>/dev/null | xargs grep -i "server_name" 2>/dev/null | awk '{for(i=2;i<=NF;i++) print $i}' | sed 's/;//g' | grep -vE "localhost|_|example.com" | sort -u | xargs)
            nginx_domains="$nginx_domains $domains" # 收集域名用于后续证书检测
            info="${C_CYAN}${domains:-默认站点}${C_RESET} ${C_YELLOW}【Nginx站点】${C_RESET}" ;;
        *node*)
            path=$(readlink -f /proc/$pid/cwd 2>/dev/null)
            info="${C_YELLOW}Node.js 服务${C_RESET} 📂:${path:-未知目录}" ;;
        *python*) info="${C_YELLOW}Python 脚本/服务${C_RESET}" ;;
        *docker*|*containerd*) info="${C_CYAN}Docker 容器/守护进程${C_RESET}" ;;
        *mysql*|*mariadb*) info="${C_PURPLE}数据库服务 (MySQL/MariaDB)${C_RESET}" ;;
        *redis*) info="${C_RED}Redis 内存缓存服务${C_RESET}" ;;
        *php-fpm*|*php*) info="${C_PURPLE}PHP 运行环境${C_RESET}" ;;
        *java*) info="${C_YELLOW}Java 应用/微服务${C_RESET}" ;;
        *x-ui*) info="${C_GREEN}X-UI 面板服务${C_RESET}" ;;
        *xray*) info="${C_GREEN}Xray 核心代理服务${C_RESET}" ;;
        *sshd*) info="SSH 远程登录服务" ;;
        *systemd-resolve*) info="${C_WHITE}DNS 系统解析服务${C_RESET}" ;;
        *) info="基础/系统进程" ;;
    esac
    
    echo -e "│ $(printf "%-8s" "$proto") │ $(printf "%-6s" "$port") │ $(printf "%-12s" "${name:0:12}") │ $(printf "%-40s" "$info") │"
done < <(ss -tunlp | grep LISTEN | awk '{
    split($5,a,":"); port=a[length(a)]; 
    prog=$7; gsub(/"/,"",prog); split(prog,p,",");
    pname=p[1]; sub(/users:\(\(/,"",pname);
    pid=p[2]; sub(/pid=/,"",pid);
    printf "%s|%s|%s|%s\n", $1, port, pname, pid
}' | sort -t'|' -k2 -n | uniq)

echo -e "└──────────┴────────┴──────────────┴──────────────────────────────────────────┘"

# --- 业务级容器/PM2穿透 ---
echo -e "\n${C_CYAN}【四、高可用业务 & 容器穿透监控】${C_RESET}"
echo -e "┌────────────────────────────────────────────────────────────┐"
has_biz=0

# PM2 透视 (利用 Python 安全解析 JSON)
if command -v pm2 >/dev/null 2>&1 && command -v python3 >/dev/null 2>&1; then
    pm2_json=$(pm2 jlist 2>/dev/null)
    if [[ "$pm2_json" == *"["* ]]; then
        has_biz=1
        echo "$pm2_json" | python3 -c '
import json,sys
try:
    data = json.load(sys.stdin)
    if not data: print("│ [PM2] 暂无运行中的项目"+" "*36+"│")
    for x in data:
        name = x.get("name", "Unknown")[:15]
        status = x.get("pm2_env", {}).get("status", "Unknown")
        mem = x.get("monit", {}).get("memory", 0) / 1024 / 1024
        color_status = "\033[1;32monline\033[0m " if status == "online" else f"\033[1;31m{status}\033[0m"
        print(f"│ [PM2] {name:<15} │ 状态: {color_status} │ 内存: {mem:>6.1f} MB  │")
except Exception:
    pass'
    fi
fi

# Docker 透视
if command -v docker >/dev/null 2>&1; then
    docker_status=$(docker ps --format "│ [Docker] {{.Names}} │ 状态: {{.Status}} │" 2>/dev/null)
    if [ ! -z "$docker_status" ]; then
        has_biz=1
        echo "$docker_status" | while read -r line; do
            printf "%-69s│\n" "$line"
        done
    fi
fi

[ $has_biz -eq 0 ] && echo "│ 暂未检测到 PM2 托管项目或 Docker 运行容器。               │"
echo -e "└────────────────────────────────────────────────────────────┘"

# --- 生产级高可用防御与部署建议 ---
echo -e "\n${C_YELLOW}【五、🚀 生产级高可用防御与部署建议】${C_RESET}"
echo -e "${C_CYAN}────────────────────────────────────────────────────────────${C_RESET}"
adv_idx=1
all_ports=$(cat $used_ports_file)

# 1. 负载预警 (修复了 Bash 判断语法)
load_1m=$(echo "$load_avg" | cut -d, -f1)
is_high_load=$(awk -v l="$load_1m" -v c="$cpu_cores" 'BEGIN{if(l>c) print 1; else print 0}')
if [ "$is_high_load" -eq 1 ]; then
    echo -e "  $((adv_idx++)). ${C_RED}[负载报警]${C_RESET} 当前 1分钟平均负载($load_1m) 已超过 CPU 核心数($cpu_cores)！请检查业务进程或考虑扩容机器配置。"
fi

# 2. SSL 证书巡检
if [ ! -z "$nginx_domains" ]; then
    unique_domains=$(echo "$nginx_domains" | tr ' ' '\n' | sort -u | xargs)
    for domain in $unique_domains; do
        exp_date=$(timeout 2 openssl s_client -servername "$domain" -connect 127.0.0.1:443 </dev/null 2>/dev/null | openssl x509 -noout -enddate 2>/dev/null | cut -d= -f2)
        if [ ! -z "$exp_date" ]; then
            exp_epoch=$(date -d "$exp_date" +%s 2>/dev/null)
            now_epoch=$(date +%s)
            days_left=$(( (exp_epoch - now_epoch) / 86400 ))
            if [ $days_left -le 15 ] && [ $days_left -gt 0 ]; then
                echo -e "  $((adv_idx++)). ${C_RED}[安全预警]${C_RESET} 域名 ${domain} 的 SSL 证书仅剩 ${C_RED}${days_left}天${C_RESET} 过期，请及时续签！"
            elif [ $days_left -le 0 ]; then
                echo -e "  $((adv_idx++)). ${C_RED}[紧急预警]${C_RESET} 域名 ${domain} 的 SSL 证书 ${C_RED}已过期${C_RESET}，HTTPS 访问可能已中断！"
            else
                echo -e "  $((adv_idx++)). ${C_GREEN}[安全正常]${C_RESET} 域名 ${domain} 证书正常，剩余 ${days_left} 天。"
            fi
        fi
    done
fi

# 3. 防火墙防坑预警
if command -v ufw >/dev/null 2>&1; then
    if ufw status 2>/dev/null | grep -q "active"; then
        for p in 3000 3001 80 443; do
            if echo "$all_ports" | grep -qw "$p"; then
                if ! ufw status 2>/dev/null | grep -qw "$p"; then
                    echo -e "  $((adv_idx++)). ${C_RED}[网络阻断]${C_RESET} 端口 $p 正在运行，但未在 UFW 防火墙放行，外部将无法访问 (需执行 ufw allow $p)！"
                fi
            fi
        done
    fi
fi

# 4. 僵尸大文件排雷
large_files=$(find /var/log /root -maxdepth 3 -type f -size +500M -exec ls -lh {} + 2>/dev/null | head -n 1)
if [ ! -z "$large_files" ]; then
    big_file_name=$(echo "$large_files" | awk '{print $9}')
    big_file_size=$(echo "$large_files" | awk '{print $5}')
    echo -e "  $((adv_idx++)). ${C_YELLOW}[磁盘空间预警]${C_RESET} 发现超大文件: ${big_file_name} (${big_file_size})，若为无用日志建议清理以防数据库宕机。"
fi

# 5. 常规资源建议
if echo "$all_ports" | grep -qwE "3000|3001"; then
    echo -e "  $((adv_idx++)). ${C_YELLOW}[端口分配]${C_RESET} 3000/3001 已占用，请使用 3002 及以上端口部署新服务。"
fi

# 6. 动态业务隔离建议
biz_name="Node.js 相关业务"
if command -v pm2 >/dev/null 2>&1; then
    pm2_first_app=$(pm2 jlist 2>/dev/null | grep -o '"name":"[^"]*' | head -1 | cut -d'"' -f4)
    [ ! -z "$pm2_first_app" ] && biz_name="${pm2_first_app} 项目"
fi
echo -e "  $((adv_idx++)). ${C_WHITE}[权限隔离]${C_RESET} 鉴于当前正在运行 ${biz_name}，强烈建议分离前端与后端的用户运行组，切忌全部使用 root 权限强跑进程。"

echo -e "${C_CYAN}────────────────────────────────────────────────────────────${C_RESET}"
echo -e "${C_GREEN}>>> 扫描全部结束！本脚本已自动执行“阅后即焚”清理。 <<<\n${C_RESET}"

# === 阅后即焚逻辑 ===
rm -f $used_ports_file
rm -f "$0"
