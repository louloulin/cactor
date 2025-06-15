#!/bin/bash

# 简单域名配置脚本
# 使用 hosts 文件快速配置本地域名解析

set -e

# 颜色定义
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=== 简单域名配置工具 ===${NC}"
echo

# 备份 hosts 文件
echo -e "${YELLOW}1. 备份 hosts 文件...${NC}"
sudo cp /etc/hosts /etc/hosts.backup.$(date +%Y%m%d_%H%M%S)
echo -e "${GREEN}✓ hosts 文件已备份${NC}"

# 添加域名到 hosts 文件
echo -e "${YELLOW}2. 添加本地域名...${NC}"

# 检查是否已存在配置
if grep -q "# === 本地开发域名 ===" /etc/hosts; then
    echo -e "${YELLOW}域名配置已存在，跳过添加${NC}"
else
    # 添加域名配置
    sudo tee -a /etc/hosts > /dev/null <<EOF

# === 本地开发域名 ===
# Coder 服务器
127.0.0.1    coder.local
127.0.0.1    cangjie.dev
127.0.0.1    cangjie.local

# API 服务
127.0.0.1    api.cangjie.dev
127.0.0.1    admin.cangjie.dev
127.0.0.1    docs.cangjie.dev
127.0.0.1    monitor.cangjie.dev

# 通用开发域名
127.0.0.1    app.local
127.0.0.1    web.local
127.0.0.1    api.local
127.0.0.1    admin.local
127.0.0.1    test.local
EOF
    echo -e "${GREEN}✓ 域名配置已添加${NC}"
fi

# 刷新 DNS 缓存
echo -e "${YELLOW}3. 刷新 DNS 缓存...${NC}"
sudo dscacheutil -flushcache
sudo killall -HUP mDNSResponder 2>/dev/null || true
echo -e "${GREEN}✓ DNS 缓存已刷新${NC}"

# 测试域名解析
echo -e "${YELLOW}4. 测试域名解析...${NC}"
test_domains=("coder.local" "cangjie.dev" "api.cangjie.dev")

for domain in "${test_domains[@]}"; do
    if ping -c 1 "$domain" > /dev/null 2>&1; then
        echo -e "${GREEN}✓ $domain 解析正常${NC}"
    else
        echo -e "${YELLOW}⚠ $domain 解析可能需要等待${NC}"
    fi
done

echo
echo -e "${GREEN}=== 配置完成 ===${NC}"
echo
echo "现在您可以使用以下域名："
echo
echo "  Coder 服务器:"
echo "    http://coder.local:8080"
echo "    http://cangjie.dev:8080"
echo
echo "  启动命令示例:"
echo "    coder server --access-url http://coder.local:8080 --address 0.0.0.0:8080"
echo
echo "  如需移除配置，请编辑 /etc/hosts 文件删除相关行"
echo