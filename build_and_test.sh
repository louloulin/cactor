#!/bin/bash

# 仓颉Actor系统构建和测试脚本

echo "=== 仓颉Actor系统构建和测试 ==="

# 检查仓颉编译器是否可用
if ! command -v cjc &> /dev/null; then
    echo "错误: 找不到仓颉编译器 (cjc)"
    echo "请确保仓颉工具链已正确安装并添加到PATH中"
    exit 1
fi

echo "仓颉编译器版本:"
cjc --version

# 创建输出目录
mkdir -p build
mkdir -p build/tests

echo ""
echo "=== 编译Actor核心模块 ==="

# 编译Actor核心模块
echo "编译 src/actor.cj..."
if cjc -o build/actor.so src/actor.cj; then
    echo "✓ Actor核心模块编译成功"
else
    echo "✗ Actor核心模块编译失败"
    exit 1
fi

echo ""
echo "=== 编译测试模块 ==="

# 编译简单测试
echo "编译 tests/simple_test.cj..."
if cjc -o build/tests/simple_test tests/simple_test.cj; then
    echo "✓ 简单测试编译成功"
else
    echo "✗ 简单测试编译失败"
    exit 1
fi

echo ""
echo "=== 运行测试 ==="

# 运行简单测试
echo "运行简单测试..."
if ./build/tests/simple_test; then
    echo "✓ 简单测试执行成功"
else
    echo "✗ 简单测试执行失败"
    exit 1
fi

echo ""
echo "=== 构建完成 ==="
echo "所有模块编译成功，测试通过！"
echo ""
echo "生成的文件:"
echo "  - build/actor.so (Actor核心模块)"
echo "  - build/tests/simple_test (简单测试可执行文件)"
echo ""
echo "使用方法:"
echo "  ./build/tests/simple_test  # 运行简单测试"
echo ""
