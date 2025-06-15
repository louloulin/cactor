#!/bin/bash

# dnsmasq 域名配置自动化脚本
# 用于快速配置本地开发环境的域名解析

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 日志函数
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 检查是否为 macOS
check_macos() {
    if [[ "$OSTYPE" != "darwin"* ]]; then
        log_error "此脚本仅支持 macOS 系统"
        exit 1
    fi
}

# 检查 Homebrew 是否安装
check_homebrew() {
    if ! command -v brew &> /dev/null; then
        log_error "Homebrew 未安装，请先安装 Homebrew"
        echo "安装命令: /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
        exit 1
    fi
}

# 安装 dnsmasq
install_dnsmasq() {
    log_info "检查 dnsmasq 安装状态..."
    
    if brew list dnsmasq &> /dev/null; then
        log_success "dnsmasq 已安装"
    else
        log_info "正在安装 dnsmasq..."
        brew install dnsmasq
        log_success "dnsmasq 安装完成"
    fi
}

# 创建 dnsmasq 配置文件
create_dnsmasq_config() {
    local config_file="/usr/local/etc/dnsmasq.conf"
    
    log_info "创建 dnsmasq 配置文件..."
    
    # 备份现有配置文件
    if [[ -f "$config_file" ]]; then
        sudo cp "$config_file" "$config_file.backup.$(date +%Y%m%d_%H%M%S)"
        log_info "已备份现有配置文件"
    fi
    
    # 创建新的配置文件
    sudo tee "$config_file" > /dev/null <<EOF
# dnsmasq 配置文件 - 自动生成
# 生成时间: $(date)

# 基本设置
port=53
listen-address=127.0.0.1
no-hosts
no-resolv

# 上游 DNS 服务器
server=8.8.8.8
server=8.8.4.4
server=1.1.1.1
server=223.5.5.5

# 缓存设置
cache-size=1000
local-ttl=300

# 日志设置
log-queries
log-facility=/usr/local/var/log/dnsmasq.log

# 本地域名解析
# 开发环境域名
address=/.local/127.0.0.1
address=/.dev/127.0.0.1
address=/.test/127.0.0.1

# Coder 相关域名
address=/coder.local/127.0.0.1
address=/.coder.local/127.0.0.1

# Cangjie 项目域名
address=/cangjie.dev/127.0.0.1
address=/cangjie.local/127.0.0.1
address=/.cangjie.dev/127.0.0.1
address=/.cangjie.local/127.0.0.1

# API 子域名
address=/api.cangjie.dev/127.0.0.1
address=/admin.cangjie.dev/127.0.0.1
address=/docs.cangjie.dev/127.0.0.1
address=/monitor.cangjie.dev/127.0.0.1

# 其他常用开发域名
address=/app.local/127.0.0.1
address=/web.local/127.0.0.1
address=/api.local/127.0.0.1
address=/admin.local/127.0.0.1
EOF
    
    log_success "dnsmasq 配置文件创建完成"
}

# 配置系统 DNS 解析器
setup_system_resolvers() {
    log_info "配置系统 DNS 解析器..."
    
    # 创建解析器目录
    sudo mkdir -p /etc/resolver
    
    # 配置各种域名的解析器
    local domains=("local" "dev" "test")
    
    for domain in "${domains[@]}"; do
        echo "nameserver 127.0.0.1" | sudo tee "/etc/resolver/$domain" > /dev/null
        log_success "已配置 .$domain 域名解析器"
    done
}

# 创建日志目录
setup_logging() {
    log_info "设置日志目录..."
    
    local log_dir="/usr/local/var/log"
    sudo mkdir -p "$log_dir"
    sudo touch "$log_dir/dnsmasq.log"
    sudo chmod 644 "$log_dir/dnsmasq.log"
    
    log_success "日志目录设置完成"
}

# 启动 dnsmasq 服务
start_dnsmasq() {
    log_info "启动 dnsmasq 服务..."
    
    # 停止现有服务（如果正在运行）
    sudo brew services stop dnsmasq 2>/dev/null || true
    
    # 启动服务
    sudo brew services start dnsmasq
    
    # 等待服务启动
    sleep 2
    
    # 检查服务状态
    if brew services list | grep dnsmasq | grep started > /dev/null; then
        log_success "dnsmasq 服务启动成功"
    else
        log_error "dnsmasq 服务启动失败"
        return 1
    fi
}

# 测试域名解析
test_dns_resolution() {
    log_info "测试域名解析..."
    
    local test_domains=(
        "coder.local"
        "cangjie.dev"
        "api.cangjie.dev"
        "test.local"
    )
    
    for domain in "${test_domains[@]}"; do
        if nslookup "$domain" 127.0.0.1 > /dev/null 2>&1; then
            log_success "✓ $domain 解析正常"
        else
            log_warning "✗ $domain 解析失败"
        fi
    done
}

# 显示使用说明
show_usage_info() {
    echo
    log_info "=== dnsmasq 域名配置完成 ==="
    echo
    echo "现在您可以使用以下域名访问本地服务："
    echo
    echo "  Coder 服务器:"
    echo "    http://coder.local:8080"
    echo "    http://cangjie.dev:8080"
    echo
    echo "  API 服务:"
    echo "    http://api.cangjie.dev:3000"
    echo "    http://admin.cangjie.dev:3001"
    echo
    echo "  启动 Coder 服务器示例:"
    echo "    coder server --access-url http://coder.local:8080 --address 0.0.0.0:8080"
    echo
    echo "  常用命令:"
    echo "    查看服务状态: brew services list | grep dnsmasq"
    echo "    重启服务:     sudo brew services restart dnsmasq"
    echo "    查看日志:     tail -f /usr/local/var/log/dnsmasq.log"
    echo "    测试解析:     nslookup coder.local"
    echo
}

# 添加自定义域名函数
add_custom_domain() {
    local domain="$1"
    local ip="${2:-127.0.0.1}"
    
    if [[ -z "$domain" ]]; then
        log_error "请提供域名"
        return 1
    fi
    
    log_info "添加自定义域名: $domain -> $ip"
    
    # 添加到 dnsmasq 配置
    echo "address=/$domain/$ip" | sudo tee -a /usr/local/etc/dnsmasq.conf > /dev/null
    
    # 重启服务
    sudo brew services restart dnsmasq
    
    log_success "域名 $domain 添加完成"
}

# 移除自定义域名函数
remove_custom_domain() {
    local domain="$1"
    
    if [[ -z "$domain" ]]; then
        log_error "请提供要移除的域名"
        return 1
    fi
    
    log_info "移除域名: $domain"
    
    # 从配置文件中移除
    sudo sed -i '' "/address=\/$domain\//d" /usr/local/etc/dnsmasq.conf
    
    # 重启服务
    sudo brew services restart dnsmasq
    
    log_success "域名 $domain 移除完成"
}

# 显示帮助信息
show_help() {
    echo "dnsmasq 域名配置脚本"
    echo
    echo "用法:"
    echo "  $0 [选项]"
    echo
    echo "选项:"
    echo "  install           安装并配置 dnsmasq"
    echo "  start             启动 dnsmasq 服务"
    echo "  stop              停止 dnsmasq 服务"
    echo "  restart           重启 dnsmasq 服务"
    echo "  status            查看服务状态"
    echo "  test              测试域名解析"
    echo "  logs              查看日志"
    echo "  add <domain> [ip] 添加自定义域名"
    echo "  remove <domain>   移除自定义域名"
    echo "  help              显示此帮助信息"
    echo
    echo "示例:"
    echo "  $0 install                    # 完整安装配置"
    echo "  $0 add myapp.local            # 添加域名指向 127.0.0.1"
    echo "  $0 add api.myapp.dev 10.0.0.1 # 添加域名指向指定 IP"
    echo "  $0 remove myapp.local         # 移除域名"
}

# 主函数
main() {
    local action="${1:-install}"
    
    case "$action" in
        "install")
            check_macos
            check_homebrew
            install_dnsmasq
            create_dnsmasq_config
            setup_system_resolvers
            setup_logging
            start_dnsmasq
            test_dns_resolution
            show_usage_info
            ;;
        "start")
            start_dnsmasq
            ;;
        "stop")
            sudo brew services stop dnsmasq
            log_success "dnsmasq 服务已停止"
            ;;
        "restart")
            sudo brew services restart dnsmasq
            log_success "dnsmasq 服务已重启"
            ;;
        "status")
            brew services list | grep dnsmasq
            ;;
        "test")
            test_dns_resolution
            ;;
        "logs")
            tail -f /usr/local/var/log/dnsmasq.log
            ;;
        "add")
            add_custom_domain "$2" "$3"
            ;;
        "remove")
            remove_custom_domain "$2"
            ;;
        "help")
            show_help
            ;;
        *)
            log_error "未知选项: $action"
            show_help
            exit 1
            ;;
    esac
}

# 执行主函数
main "$@"