# dnsmasq 本地 DNS 服务配置指南

## 概述

dnsmasq 是一个轻量级的 DNS 转发器和 DHCP 服务器，非常适合在本地开发环境中使用。它可以帮助您设置自定义域名解析，避免频繁修改 hosts 文件。

## 安装 dnsmasq

### 使用 Homebrew 安装

```bash
# 安装 dnsmasq
brew install dnsmasq

# 查看安装信息
brew info dnsmasq
```

## 基本配置

### 1. 创建配置文件

```bash
# 复制默认配置文件
sudo cp /usr/local/etc/dnsmasq.conf.example /usr/local/etc/dnsmasq.conf

# 或者创建新的配置文件
sudo touch /usr/local/etc/dnsmasq.conf
```

### 2. 编辑配置文件

```bash
sudo nano /usr/local/etc/dnsmasq.conf
```

添加以下基本配置：

```conf
# 监听端口
port=53

# 监听地址（仅本地）
listen-address=127.0.0.1

# 不读取 /etc/hosts 文件
no-hosts

# 不读取 /etc/resolv.conf
no-resolv

# 上游 DNS 服务器
server=8.8.8.8
server=8.8.4.4
server=1.1.1.1

# 本地域名解析
address=/.local/127.0.0.1
address=/.dev/127.0.0.1
address=/.test/127.0.0.1

# 缓存大小
cache-size=1000

# 日志查询
log-queries

# 日志文件
log-facility=/usr/local/var/log/dnsmasq.log
```

## 针对 Coder 项目的配置

### 为 Coder 服务器配置域名

```conf
# Coder 相关域名
address=/coder.local/127.0.0.1
address=/cangjie.dev/127.0.0.1
address=/cangjie.local/127.0.0.1

# 通配符域名支持
address=/.coder.local/127.0.0.1
address=/.cangjie.dev/127.0.0.1
```

### 配置端口映射

```conf
# 为不同端口配置子域名
address=/api.cangjie.dev/127.0.0.1
address=/admin.cangjie.dev/127.0.0.1
address=/docs.cangjie.dev/127.0.0.1
```

## 系统配置

### 1. 配置系统 DNS 解析器

```bash
# 创建解析器目录
sudo mkdir -p /etc/resolver

# 为 .local 域名配置解析器
echo "nameserver 127.0.0.1" | sudo tee /etc/resolver/local

# 为 .dev 域名配置解析器
echo "nameserver 127.0.0.1" | sudo tee /etc/resolver/dev

# 为 .test 域名配置解析器
echo "nameserver 127.0.0.1" | sudo tee /etc/resolver/test
```

### 2. 启动 dnsmasq 服务

```bash
# 启动服务
sudo brew services start dnsmasq

# 设置开机自启
sudo brew services enable dnsmasq

# 检查服务状态
brew services list | grep dnsmasq
```

### 3. 手动启动（用于调试）

```bash
# 前台运行（用于调试）
sudo dnsmasq --no-daemon --log-queries

# 后台运行
sudo dnsmasq

# 停止服务
sudo killall dnsmasq
```

## 验证配置

### 1. 测试 DNS 解析

```bash
# 测试本地域名解析
nslookup coder.local
nslookup cangjie.dev

# 使用 dig 命令测试
dig @127.0.0.1 coder.local
dig @127.0.0.1 cangjie.dev

# 测试通配符域名
ping test.coder.local
ping api.cangjie.dev
```

### 2. 检查 dnsmasq 日志

```bash
# 查看日志文件
tail -f /usr/local/var/log/dnsmasq.log

# 或者使用系统日志
log show --predicate 'process == "dnsmasq"' --info
```

## 与 Coder 服务器集成

### 1. 启动 Coder 服务器使用自定义域名

```bash
# 使用 coder.local 域名
coder server --access-url http://coder.local:8080 --address 0.0.0.0:8080

# 使用 cangjie.dev 域名
coder server --access-url http://cangjie.dev:8080 --address 0.0.0.0:8080

# HTTPS 配置
coder server --access-url https://coder.local:8443 --address 0.0.0.0:8443 --tls-enable
```

### 2. 环境变量配置

```bash
# 设置环境变量
export CODER_ACCESS_URL="http://coder.local:8080"
export CODER_ADDRESS="0.0.0.0:8080"

# 启动服务器
coder server
```

## 高级配置

### 1. 配置多个上游 DNS

```conf
# 不同域名使用不同的上游 DNS
server=/company.com/192.168.1.1
server=/internal.local/10.0.0.1
server=8.8.8.8  # 默认上游 DNS
```

### 2. 配置 DNS 缓存

```conf
# 设置缓存大小
cache-size=10000

# 设置 TTL
local-ttl=300

# 禁用负缓存
no-negcache
```

### 3. 配置 DHCP（可选）

```conf
# DHCP 范围
dhcp-range=192.168.1.100,192.168.1.200,12h

# 静态 IP 分配
dhcp-host=aa:bb:cc:dd:ee:ff,192.168.1.50,coder-dev
```

## 故障排除

### 1. 常见问题

```bash
# 检查端口占用
sudo lsof -i :53

# 检查配置文件语法
dnsmasq --test

# 重启服务
sudo brew services restart dnsmasq

# 清除 DNS 缓存
sudo dscacheutil -flushcache
sudo killall -HUP mDNSResponder
```

### 2. 权限问题

```bash
# 确保 dnsmasq 有权限绑定端口 53
sudo setcap 'cap_net_bind_service=+ep' /usr/local/bin/dnsmasq

# 或者使用非特权端口
port=5353
```

### 3. 日志调试

```bash
# 启用详细日志
log-queries
log-dhcp

# 查看实时日志
tail -f /usr/local/var/log/dnsmasq.log
```

## 性能优化

### 1. 缓存优化

```conf
# 增加缓存大小
cache-size=10000

# 预加载常用域名
address=/github.com/140.82.112.3
address=/google.com/172.217.164.110
```

### 2. 网络优化

```conf
# 并发查询数量
dns-forward-max=1000

# 超时设置
server-timeout=5
```

## 安全考虑

### 1. 访问控制

```conf
# 仅允许本地访问
listen-address=127.0.0.1

# 禁止某些查询
bogus-nxdomain=64.94.110.11
```

### 2. 日志管理

```conf
# 限制日志大小
log-facility=/usr/local/var/log/dnsmasq.log

# 定期轮转日志
# 可以使用 logrotate 或类似工具
```

## 卸载和清理

```bash
# 停止服务
sudo brew services stop dnsmasq

# 卸载 dnsmasq
brew uninstall dnsmasq

# 清理配置文件
sudo rm -rf /usr/local/etc/dnsmasq.conf
sudo rm -rf /etc/resolver/local
sudo rm -rf /etc/resolver/dev
sudo rm -rf /etc/resolver/test

# 清理日志
sudo rm -rf /usr/local/var/log/dnsmasq.log
```

## 总结

dnsmasq 为本地开发提供了强大而灵活的 DNS 解决方案。通过合理配置，您可以：

- 使用自定义域名访问本地服务
- 避免频繁修改 hosts 文件
- 提供通配符域名支持
- 缓存 DNS 查询以提高性能
- 支持多种开发环境需求

配置完成后，您就可以使用 `http://coder.local:8080` 或 `http://cangjie.dev:8080` 等友好的域名来访问您的 Coder 服务器了。