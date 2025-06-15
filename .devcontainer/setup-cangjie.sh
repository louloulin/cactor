#!/bin/bash

# 仓颉语言开发环境安装脚本
# Cangjie Language Development Environment Setup Script

set -e

echo "🚀 开始配置仓颉语言开发环境..."
echo "🚀 Setting up Cangjie Language Development Environment..."

# 更新系统包
echo "📦 更新系统包..."
sudo apt-get update
sudo apt-get install -y \
    build-essential \
    curl \
    wget \
    git \
    vim \
    nano \
    unzip \
    ca-certificates \
    gnupg \
    lsb-release \
    software-properties-common \
    cmake \
    clang \
    llvm \
    libc6-dev \
    libssl-dev \
    pkg-config

# 创建仓颉SDK目录
echo "📁 创建仓颉SDK目录..."
sudo mkdir -p /opt/cangjie
sudo chown -R vscode:vscode /opt/cangjie

# 下载并安装仓颉语言SDK (模拟安装，实际需要从官方渠道获取)
echo "⬇️ 准备仓颉语言SDK安装..."
echo "注意：由于仓颉语言SDK需要从官方渠道获取，请手动下载并放置到容器中"
echo "官方下载地址：https://cangjie-lang.cn/download"

# 创建模拟的仓颉编译器目录结构
mkdir -p /opt/cangjie/compiler/{bin,lib,modules,runtime,third_party,tools}
mkdir -p /opt/cangjie/compiler/runtime/lib/linux_x86_64_llvm
mkdir -p /opt/cangjie/compiler/lib/linux_x86_64_llvm
mkdir -p /opt/cangjie/compiler/tools/{bin,lib}

# 创建CJPM目录
mkdir -p /home/vscode/.cjpm/bin

# 创建仓颉编译器占位符脚本
cat > /opt/cangjie/compiler/bin/cjc << 'EOF'
#!/bin/bash
echo "仓颉编译器 (cjc) - 请安装完整的仓颉SDK"
echo "Cangjie Compiler (cjc) - Please install the complete Cangjie SDK"
echo "下载地址 / Download: https://cangjie-lang.cn/download"
EOF

chmod +x /opt/cangjie/compiler/bin/cjc

# 创建CJPM包管理器占位符脚本
cat > /home/vscode/.cjpm/bin/cjpm << 'EOF'
#!/bin/bash
echo "仓颉包管理器 (cjpm) - 请安装完整的仓颉SDK"
echo "Cangjie Package Manager (cjpm) - Please install the complete Cangjie SDK"
echo "下载地址 / Download: https://cangjie-lang.cn/download"
EOF

chmod +x /home/vscode/.cjpm/bin/cjpm

# 设置权限
chown -R vscode:vscode /home/vscode/.cjpm

# 创建仓颉项目模板
echo "📝 创建仓颉项目模板..."
cat > /workspace/hello_cangjie.cj << 'EOF'
// 仓颉语言 Hello World 示例
// Cangjie Language Hello World Example

import std.io.*

main(): Unit {
    println("Hello, Cangjie! 你好，仓颉！")
    println("欢迎使用仓颉语言Actor框架开发环境")
    println("Welcome to Cangjie Language Actor Framework Development Environment")
}
EOF

# 创建HTTP服务器示例
cat > /workspace/http_server_example.cj << 'EOF'
// 仓颉语言HTTP服务器示例
// Cangjie Language HTTP Server Example

import net.http.*
import std.io.*

func start_server(): Unit {
    println("启动仓颉HTTP服务器...")
    println("Starting Cangjie HTTP Server...")
    
    let server = ServerBuilder()
        .addr("0.0.0.0")
        .port(8080)
        .build()
    
    server.distributor.register("/hello", { http_context =>
        http_context.responseBuilder.body("Hello from Cangjie Actor Framework! 🚀")
    })
    
    server.distributor.register("/", { http_context =>
        let html = """
        <!DOCTYPE html>
        <html>
        <head>
            <title>仓颉语言Actor框架</title>
            <meta charset="UTF-8">
        </head>
        <body>
            <h1>🚀 仓颉语言Actor框架开发环境</h1>
            <h2>🎯 Cangjie Language Actor Framework</h2>
            <p>欢迎使用仓颉语言开发高性能Actor系统！</p>
            <p>Welcome to develop high-performance Actor systems with Cangjie!</p>
            <ul>
                <li><a href="/hello">Hello API</a></li>
                <li><a href="https://cangjie-lang.cn/docs">仓颉文档</a></li>
                <li><a href="https://cangjie-lang.cn/download">下载SDK</a></li>
            </ul>
        </body>
        </html>
        """
        http_context.responseBuilder
            .header("Content-Type", "text/html; charset=utf-8")
            .body(html)
    })
    
    println("服务器运行在 http://localhost:8080")
    println("Server running at http://localhost:8080")
    server.serve()
}

main(): Unit {
    let fut: Future<Unit> = spawn {
        start_server()
    }
    fut.get()
}
EOF

# 创建构建脚本
cat > /workspace/build_examples.sh << 'EOF'
#!/bin/bash

echo "🔨 构建仓颉示例程序..."
echo "🔨 Building Cangjie example programs..."

# 检查仓颉编译器是否可用
if command -v cjc &> /dev/null; then
    echo "✅ 找到仓颉编译器"
    
    # 编译Hello World
    echo "编译 hello_cangjie.cj..."
    cjc --output hello_cangjie hello_cangjie.cj
    
    # 编译HTTP服务器
    echo "编译 http_server_example.cj..."
    cjc --output http_server http_server_example.cj
    
    echo "✅ 编译完成！"
    echo "运行示例："
    echo "  ./hello_cangjie"
    echo "  ./http_server"
else
    echo "❌ 未找到仓颉编译器 (cjc)"
    echo "请从官方网站下载并安装仓颉SDK：https://cangjie-lang.cn/download"
fi
EOF

chmod +x /workspace/build_examples.sh

# 创建开发环境说明文件
cat > /workspace/CANGJIE_SETUP.md << 'EOF'
# 仓颉语言开发环境配置说明

## 🎯 环境概述

本开发容器已预配置仓颉语言开发环境，包含：

- Ubuntu 22.04 基础环境
- 构建工具链 (GCC, Clang, LLVM, CMake)
- 仓颉SDK目录结构 (`/opt/cangjie`)
- 环境变量配置
- VS Code扩展支持

## 📦 完成仓颉SDK安装

由于仓颉语言SDK需要从官方渠道获取，请按以下步骤完成安装：

1. 访问官方下载页面：https://cangjie-lang.cn/download
2. 下载适合Linux的仓颉SDK包
3. 解压到容器的 `/opt/cangjie` 目录
4. 确保编译器可执行：`chmod +x /opt/cangjie/compiler/bin/*`

## 🚀 快速开始

```bash
# 验证安装
cjc --version
cjpm --version

# 编译示例程序
./build_examples.sh

# 运行Hello World
./hello_cangjie

# 启动HTTP服务器
./http_server
```

## 🔧 环境变量

已配置的环境变量：
- `CANGJIE_HOME`: `/opt/cangjie/compiler`
- `CANGJIE_SDK_HOME`: `/opt/cangjie`
- `PATH`: 包含仓颉编译器和工具路径
- `LD_LIBRARY_PATH`: 包含仓颉运行时库路径

## 📚 学习资源

- [仓颉官方文档](https://cangjie-lang.cn/docs)
- [开发指南](https://cangjie-lang.cn/docs)
- [API参考](https://cangjie-lang.cn/docs)
- [语言规约](https://cangjie-lang.cn/docs)

## 🛠 项目结构

```
/workspace/
├── src/                    # 仓颉Actor框架源码
├── examples/              # 示例代码
├── tests/                 # 测试代码
├── cjpm.toml             # 仓颉项目配置
├── hello_cangjie.cj      # Hello World示例
├── http_server_example.cj # HTTP服务器示例
└── build_examples.sh     # 构建脚本
```

## 🔍 故障排除

如果遇到问题，请检查：
1. 仓颉SDK是否正确安装到 `/opt/cangjie`
2. 环境变量是否正确设置
3. 编译器是否有执行权限
4. 依赖库是否完整
EOF

echo "✅ 仓颉语言开发环境配置完成！"
echo "✅ Cangjie Language Development Environment setup completed!"
echo ""
echo "📖 请查看 CANGJIE_SETUP.md 了解如何完成SDK安装"
echo "📖 Please check CANGJIE_SETUP.md for SDK installation instructions"
echo ""
echo "🚀 开始您的仓颉语言Actor框架开发之旅！"
echo "🚀 Start your Cangjie Language Actor Framework development journey!"