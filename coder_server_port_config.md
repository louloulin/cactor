# Coder Server 端口配置指南

本指南详细介绍如何在启动 Coder 服务器时指定端口，以及相关的配置选项。

## 基本端口配置

### 1. 使用命令行参数指定端口

```bash
# 指定 HTTP 端口（默认 7080）
coder server --address 0.0.0.0:8080

# 指定访问 URL 和端口
coder server --access-url http://localhost:8080 --address 0.0.0.0:8080

# 指定 HTTPS 端口
coder server --address 0.0.0.0:443 --tls-enable
```

### 2. 常用端口配置示例

```bash
# 开发环境 - 端口 7080（默认）
coder server

# 开发环境 - 自定义端口 8080
coder server --address 0.0.0.0:8080 --access-url http://localhost:8080

# 生产环境 - 端口 80
sudo coder server --address 0.0.0.0:80 --access-url http://your-domain.com

# 生产环境 - HTTPS 端口 443
sudo coder server --address 0.0.0.0:443 --access-url https://your-domain.com --tls-enable

# 本地开发 - 端口 3000
coder server --address 127.0.0.1:3000 --access-url http://localhost:3000
```

## 详细配置选项

### 1. 地址和端口配置

```bash
# --address: 指定监听地址和端口
# 格式：[host]:port

# 监听所有接口的 8080 端口
coder server --address 0.0.0.0:8080

# 仅监听本地回环接口的 7080 端口
coder server --address 127.0.0.1:7080

# 监听特定 IP 地址的端口
coder server --address 192.168.1.100:8080
```

### 2. 访问 URL 配置

```bash
# --access-url: 指定外部访问的 URL
# 这个 URL 会被用于生成链接和重定向

# 本地开发
coder server --access-url http://localhost:8080 --address 0.0.0.0:8080

# 使用自定义域名
coder server --access-url http://coder.local:8080 --address 0.0.0.0:8080

# 生产环境
coder server --access-url https://coder.company.com --address 0.0.0.0:443
```

### 3. TLS/SSL 配置

```bash
# 启用 TLS
coder server --tls-enable --address 0.0.0.0:443

# 指定 TLS 证书文件
coder server --tls-cert-file /path/to/cert.pem --tls-key-file /path/to/key.pem --address 0.0.0.0:443

# 自动获取 Let's Encrypt 证书
coder server --tls-enable --tls-address 0.0.0.0:443 --access-url https://your-domain.com
```

## 环境变量配置

### 1. 使用环境变量设置端口

```bash
# 设置环境变量
export CODER_ADDRESS="0.0.0.0:8080"
export CODER_ACCESS_URL="http://localhost:8080"

# 启动服务器（会自动读取环境变量）
coder server
```

### 2. 常用环境变量

```bash
# 服务器配置
export CODER_ADDRESS="0.0.0.0:8080"              # 监听地址和端口
export CODER_ACCESS_URL="http://localhost:8080"   # 访问 URL
export CODER_TLS_ENABLE="true"                   # 启用 TLS
export CODER_TLS_ADDRESS="0.0.0.0:443"           # TLS 监听地址

# 数据库配置
export CODER_PG_CONNECTION_URL="postgres://user:pass@localhost/coder"

# 认证配置
export CODER_OAUTH2_GITHUB_CLIENT_ID="your-client-id"
export CODER_OAUTH2_GITHUB_CLIENT_SECRET="your-client-secret"

# 启动服务器
coder server
```

## 配置文件方式

### 1. 创建配置文件

```yaml
# ~/.config/coder/coder.yaml
address: "0.0.0.0:8080"
access-url: "http://localhost:8080"
tls-enable: false
verbose: true

# 数据库配置
pg-connection-url: "postgres://coder:password@localhost/coder?sslmode=disable"

# 认证配置
oauth2:
  github:
    client-id: "your-client-id"
    client-secret: "your-client-secret"
    allow-signups: true
```

### 2. 使用配置文件启动

```bash
# 使用默认配置文件位置
coder server

# 指定配置文件
coder server --config /path/to/coder.yaml
```

## 端口冲突解决

### 1. 检查端口占用

```bash
# 检查端口是否被占用
lsof -i :8080
netstat -tulpn | grep :8080

# 查找占用端口的进程
sudo lsof -i :8080
```

### 2. 终止占用端口的进程

```bash
# 终止特定进程
sudo kill -9 <PID>

# 终止所有占用端口的进程
sudo fuser -k 8080/tcp
```

### 3. 选择可用端口

```bash
# 查找可用端口
ss -tuln | grep :8080

# 使用不同端口启动
coder server --address 0.0.0.0:8081 --access-url http://localhost:8081
```

## 防火墙配置

### 1. macOS 防火墙

```bash
# 允许 Coder 通过防火墙
sudo /usr/libexec/ApplicationFirewall/socketfilterfw --add /usr/local/bin/coder
sudo /usr/libexec/ApplicationFirewall/socketfilterfw --unblock /usr/local/bin/coder
```

### 2. Linux 防火墙（ufw）

```bash
# 允许特定端口
sudo ufw allow 8080/tcp
sudo ufw allow 443/tcp

# 允许来自特定 IP 的访问
sudo ufw allow from 192.168.1.0/24 to any port 8080
```

## 反向代理配置

### 1. Nginx 反向代理

```nginx
server {
    listen 80;
    server_name coder.local;
    
    location / {
        proxy_pass http://127.0.0.1:7080;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        
        # WebSocket 支持
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        
        # 超时设置
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }
}
```

### 2. Apache 反向代理

```apache
<VirtualHost *:80>
    ServerName coder.local
    
    ProxyPreserveHost On
    ProxyRequests Off
    
    ProxyPass / http://127.0.0.1:7080/
    ProxyPassReverse / http://127.0.0.1:7080/
    
    # WebSocket 支持
    RewriteEngine on
    RewriteCond %{HTTP:Upgrade} websocket [NC]
    RewriteCond %{HTTP:Connection} upgrade [NC]
    RewriteRule ^/?(.*) "ws://127.0.0.1:7080/$1" [P,L]
</VirtualHost>
```

## Docker 容器端口映射

### 1. Docker 运行配置

```bash
# 映射端口 8080 到容器内的 7080
docker run -d \
  --name coder-server \
  -p 8080:7080 \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v ~/.config/coder:/home/coder/.config/coder \
  coder/coder:latest server --address 0.0.0.0:7080

# 映射多个端口
docker run -d \
  --name coder-server \
  -p 8080:7080 \
  -p 8443:443 \
  -v /var/run/docker.sock:/var/run/docker.sock \
  coder/coder:latest server --address 0.0.0.0:7080
```

### 2. Docker Compose 配置

```yaml
version: '3.8'

services:
  coder:
    image: coder/coder:latest
    container_name: coder-server
    ports:
      - "8080:7080"  # HTTP
      - "8443:443"   # HTTPS
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - ~/.config/coder:/home/coder/.config/coder
      - coder_data:/home/coder
    environment:
      - CODER_ADDRESS=0.0.0.0:7080
      - CODER_ACCESS_URL=http://localhost:8080
    command: server
    restart: unless-stopped

volumes:
  coder_data:
```

## 常见问题和解决方案

### 1. 端口权限问题

```bash
# 使用 1024 以下的端口需要 root 权限
sudo coder server --address 0.0.0.0:80

# 或者使用 setcap 给予权限
sudo setcap 'cap_net_bind_service=+ep' /usr/local/bin/coder
coder server --address 0.0.0.0:80
```

### 2. 访问 URL 不匹配

```bash
# 确保 access-url 与实际访问地址匹配
coder server --address 0.0.0.0:8080 --access-url http://localhost:8080

# 如果使用域名，确保 DNS 解析正确
coder server --address 0.0.0.0:8080 --access-url http://coder.local:8080
```

### 3. WebSocket 连接问题

```bash
# 确保防火墙允许 WebSocket 连接
# 检查反向代理配置是否支持 WebSocket
# 验证 access-url 配置是否正确
```

## 生产环境最佳实践

### 1. 安全配置

```bash
# 使用 HTTPS
coder server --tls-enable --address 0.0.0.0:443 --access-url https://coder.company.com

# 限制访问 IP
coder server --address 192.168.1.100:443 --access-url https://coder.company.com

# 使用强密码和 OAuth
export CODER_OAUTH2_GITHUB_CLIENT_ID="your-client-id"
export CODER_OAUTH2_GITHUB_CLIENT_SECRET="your-client-secret"
```

### 2. 性能优化

```bash
# 增加并发连接数
export CODER_MAX_TOKEN_LIFETIME="24h"
export CODER_SESSION_DURATION="24h"

# 配置数据库连接池
export CODER_PG_CONNECTION_URL="postgres://user:pass@localhost/coder?pool_max_conns=20"
```

### 3. 监控和日志

```bash
# 启用详细日志
coder server --verbose --log-human

# 配置日志文件
coder server --log-file /var/log/coder/coder.log

# 启用指标收集
coder server --prometheus-enable --prometheus-address 0.0.0.0:2112
```

## 总结

选择合适的端口配置方法：

- **开发环境**：使用默认端口 7080 或自定义端口
- **生产环境**：使用标准端口 80/443 配合 TLS
- **容器化部署**：使用端口映射和环境变量
- **多实例部署**：使用不同端口避免冲突

确保配置正确的访问 URL 和防火墙规则，以保证服务的可访问性和安全性。