#!/bin/bash
# check_foundation_dependencies.sh - Foundation层依赖检查脚本

echo "=== CActor Foundation层依赖检查 ==="

# 检查Foundation层是否存在
if [ ! -d "src/foundation" ]; then
    echo "❌ Foundation层目录不存在"
    exit 1
fi

# 初始化检查结果
DEPENDENCY_VIOLATIONS=0

echo "检查Foundation层各模块的依赖关系..."

# 检查foundation.memory
echo "📁 检查 foundation.memory..."
if grep -r "import cactor\.core\." src/foundation/memory/ 2>/dev/null; then
    echo "❌ foundation.memory 不应该依赖 core 层"
    DEPENDENCY_VIOLATIONS=$((DEPENDENCY_VIOLATIONS + 1))
fi

if grep -r "import cactor\.runtime\." src/foundation/memory/ 2>/dev/null; then
    echo "❌ foundation.memory 不应该依赖 runtime 层"
    DEPENDENCY_VIOLATIONS=$((DEPENDENCY_VIOLATIONS + 1))
fi

# 检查foundation.concurrency (或queue)
echo "📁 检查 foundation.concurrency..."
if [ -d "src/foundation/concurrency" ]; then
    if grep -r "import cactor\.core\." src/foundation/concurrency/ 2>/dev/null; then
        echo "❌ foundation.concurrency 不应该依赖 core 层"
        echo "   发现的违规导入:"
        grep -r "import cactor\.core\." src/foundation/concurrency/ 2>/dev/null | sed 's/^/   /'
        DEPENDENCY_VIOLATIONS=$((DEPENDENCY_VIOLATIONS + 1))
    fi

    if grep -r "import cactor\.runtime\." src/foundation/concurrency/ 2>/dev/null; then
        echo "❌ foundation.concurrency 不应该依赖 runtime 层"
        DEPENDENCY_VIOLATIONS=$((DEPENDENCY_VIOLATIONS + 1))
    fi
fi

# 检查foundation.queue (重构后)
if [ -d "src/foundation/queue" ]; then
    echo "📁 检查 foundation.queue..."
    if grep -r "import cactor\.core\." src/foundation/queue/ 2>/dev/null; then
        echo "❌ foundation.queue 不应该依赖 core 层"
        DEPENDENCY_VIOLATIONS=$((DEPENDENCY_VIOLATIONS + 1))
    fi

    if grep -r "import cactor\.runtime\." src/foundation/queue/ 2>/dev/null; then
        echo "❌ foundation.queue 不应该依赖 runtime 层"
        DEPENDENCY_VIOLATIONS=$((DEPENDENCY_VIOLATIONS + 1))
    fi
fi

# 检查foundation.serialization
echo "📁 检查 foundation.serialization..."
if grep -r "import cactor\.core\." src/foundation/serialization/ 2>/dev/null; then
    echo "❌ foundation.serialization 不应该依赖 core 层"
    echo "   发现的违规导入:"
    grep -r "import cactor\.core\." src/foundation/serialization/ 2>/dev/null | sed 's/^/   /'
    DEPENDENCY_VIOLATIONS=$((DEPENDENCY_VIOLATIONS + 1))
fi

if grep -r "import cactor\.runtime\." src/foundation/serialization/ 2>/dev/null; then
    echo "❌ foundation.serialization 不应该依赖 runtime 层"
    DEPENDENCY_VIOLATIONS=$((DEPENDENCY_VIOLATIONS + 1))
fi

# 检查foundation.network
echo "📁 检查 foundation.network..."
if grep -r "import cactor\.core\." src/foundation/network/ 2>/dev/null; then
    echo "❌ foundation.network 不应该依赖 core 层"
    echo "   发现的违规导入:"
    grep -r "import cactor\.core\." src/foundation/network/ 2>/dev/null | sed 's/^/   /'
    DEPENDENCY_VIOLATIONS=$((DEPENDENCY_VIOLATIONS + 1))
fi

if grep -r "import cactor\.runtime\." src/foundation/network/ 2>/dev/null; then
    echo "❌ foundation.network 不应该依赖 runtime 层"
    DEPENDENCY_VIOLATIONS=$((DEPENDENCY_VIOLATIONS + 1))
fi

# 检查是否有业务概念
echo "📋 检查Foundation层是否包含业务概念..."

# 检查是否有Mailbox概念
if grep -r "Mailbox" src/foundation/ 2>/dev/null; then
    echo "⚠️  Foundation层包含Mailbox概念，应该移至Runtime层"
    echo "   发现的位置:"
    grep -r "Mailbox" src/foundation/ 2>/dev/null | sed 's/^/   /'
fi

# 检查是否有Message概念
if grep -r "Message" src/foundation/ 2>/dev/null; then
    echo "⚠️  Foundation层包含Message概念，应该移至Core层"
    echo "   发现的位置:"
    grep -r "Message" src/foundation/ 2>/dev/null | sed 's/^/   /'
fi

# 检查是否有Envelope概念
if grep -r "Envelope" src/foundation/ 2>/dev/null; then
    echo "⚠️  Foundation层包含Envelope概念，应该移至Core层"
    echo "   发现的位置:"
    grep -r "Envelope" src/foundation/ 2>/dev/null | sed 's/^/   /'
fi

# 检查是否有Actor概念
if grep -r "Actor" src/foundation/ 2>/dev/null; then
    echo "⚠️  Foundation层包含Actor概念，应该移至Core层"
    echo "   发现的位置:"
    grep -r "Actor" src/foundation/ 2>/dev/null | sed 's/^/   /'
fi

# 总结检查结果
echo ""
echo "=== 检查结果总结 ==="

if [ $DEPENDENCY_VIOLATIONS -eq 0 ]; then
    echo "✅ Foundation层依赖检查通过！"
    echo "✅ Foundation层实现了零依赖架构"
else
    echo "❌ 发现 $DEPENDENCY_VIOLATIONS 个依赖违规问题"
    echo "❌ Foundation层需要重构以实现零依赖"
    echo ""
    echo "🔧 修复建议:"
    echo "1. 移除Foundation层对Core层的所有导入"
    echo "2. 将Mailbox概念移至Runtime层"
    echo "3. 将Message/Envelope概念移至Core层"
    echo "4. 重构Foundation层为纯基础设施组件"
    echo ""
    echo "📖 详细修复计划请参考: Foundation.md"
fi

echo ""
echo "Foundation层依赖检查完成！"

# 返回适当的退出码
exit $DEPENDENCY_VIOLATIONS
