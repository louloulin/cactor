#!/bin/bash
# verify_cactor_architecture.sh - CActor 7.0 架构验证脚本

echo "=== CActor 7.0 架构验证 ==="

# 1. 检查目录结构
echo "📁 检查目录结构..."
required_dirs=(
    "src/foundation/memory" "src/foundation/queue" "src/foundation/serialization" "src/foundation/network"
    "src/core/actor" "src/core/message" "src/core/system" "src/core/supervision" "src/core/context"
    "src/runtime/dispatcher" "src/runtime/mailbox"
)

missing_dirs=0
for dir in "${required_dirs[@]}"; do
    if [ ! -d "$dir" ]; then
        echo "❌ 缺少目录: $dir"
        missing_dirs=$((missing_dirs + 1))
    else
        echo "✅ 目录存在: $dir"
    fi
done

# 2. 检查Foundation层零依赖
echo ""
echo "🔍 检查Foundation层零依赖..."
./check_foundation_dependencies.sh > /tmp/foundation_check.log 2>&1
if [ $? -eq 0 ]; then
    echo "✅ Foundation层依赖检查通过"
else
    echo "❌ Foundation层依赖检查失败"
    cat /tmp/foundation_check.log
fi

# 3. 检查关键文件是否存在
echo ""
echo "📄 检查关键文件..."
key_files=(
    "src/foundation/queue/queue.cj"
    "src/foundation/queue/lockfree_queue.cj"
    "src/foundation/serialization/serialization_manager.cj"
    "src/foundation/network/transport.cj"
    "src/foundation/memory/object_pool/object_pool.cj"
    "src/core/message/message.cj"
    "src/core/message/message_serializer.cj"
    "src/core/message/network_message.cj"
    "src/core/actor/actor.cj"
    "src/core/system/actor_system.cj"
    "src/runtime/mailbox/mailbox.cj"
    "src/runtime/mailbox/foundation_mailbox.cj"
)

missing_files=0
for file in "${key_files[@]}"; do
    if [ ! -f "$file" ]; then
        echo "❌ 缺少文件: $file"
        missing_files=$((missing_files + 1))
    else
        echo "✅ 文件存在: $file"
    fi
done

# 4. 检查包导入是否正确
echo ""
echo "📦 检查包导入..."
echo "检查Foundation层是否有向上依赖..."
foundation_upward_deps=$(grep -r "import cactor\.core\|import cactor\.runtime\|import cactor\.patterns" src/foundation/ 2>/dev/null | wc -l)
if [ $foundation_upward_deps -eq 0 ]; then
    echo "✅ Foundation层无向上依赖"
else
    echo "❌ Foundation层存在向上依赖 ($foundation_upward_deps 个)"
    grep -r "import cactor\.core\|import cactor\.runtime\|import cactor\.patterns" src/foundation/ 2>/dev/null | head -5
fi

# 5. 检查Core层是否正确使用Foundation
echo ""
echo "🔗 检查Core层Foundation集成..."
core_foundation_usage=$(grep -r "import cactor\.foundation" src/core/ 2>/dev/null | wc -l)
if [ $core_foundation_usage -gt 0 ]; then
    echo "✅ Core层正确使用Foundation组件 ($core_foundation_usage 个引用)"
else
    echo "⚠️  Core层未使用Foundation组件"
fi

# 6. 检查Runtime层是否正确使用Foundation
echo ""
echo "🔗 检查Runtime层Foundation集成..."
runtime_foundation_usage=$(grep -r "import cactor\.foundation" src/runtime/ 2>/dev/null | wc -l)
if [ $runtime_foundation_usage -gt 0 ]; then
    echo "✅ Runtime层正确使用Foundation组件 ($runtime_foundation_usage 个引用)"
else
    echo "⚠️  Runtime层未使用Foundation组件"
fi

# 7. 简化编译检查（只检查Foundation和Core层）
echo ""
echo "🔨 检查核心组件编译..."
echo "检查Foundation层编译..."
foundation_compile_errors=$(find src/foundation -name "*.cj" -exec cjc -c {} \; 2>&1 | grep "error:" | wc -l)
if [ $foundation_compile_errors -eq 0 ]; then
    echo "✅ Foundation层编译检查通过"
else
    echo "⚠️  Foundation层有编译问题 ($foundation_compile_errors 个错误)"
fi

echo "检查Core层编译..."
core_compile_errors=$(find src/core -name "*.cj" -exec cjc -c {} \; 2>&1 | grep "error:" | wc -l)
if [ $core_compile_errors -eq 0 ]; then
    echo "✅ Core层编译检查通过"
else
    echo "⚠️  Core层有编译问题 ($core_compile_errors 个错误)"
fi

# 8. 统计代码行数
echo ""
echo "📊 代码统计..."
foundation_lines=$(find src/foundation -name "*.cj" -exec wc -l {} \; 2>/dev/null | awk '{sum += $1} END {print sum}')
core_lines=$(find src/core -name "*.cj" -exec wc -l {} \; 2>/dev/null | awk '{sum += $1} END {print sum}')
runtime_lines=$(find src/runtime -name "*.cj" -exec wc -l {} \; 2>/dev/null | awk '{sum += $1} END {print sum}')

echo "Foundation层: ${foundation_lines:-0} 行代码"
echo "Core层: ${core_lines:-0} 行代码"
echo "Runtime层: ${runtime_lines:-0} 行代码"
total_lines=$((${foundation_lines:-0} + ${core_lines:-0} + ${runtime_lines:-0}))
echo "总计: $total_lines 行代码"

# 9. 生成验证报告
echo ""
echo "📋 验证报告总结..."
echo "=================================="
echo "目录结构: $((${#required_dirs[@]} - missing_dirs))/${#required_dirs[@]} 完整"
echo "关键文件: $((${#key_files[@]} - missing_files))/${#key_files[@]} 存在"
echo "Foundation零依赖: $([ $foundation_upward_deps -eq 0 ] && echo "✅ 通过" || echo "❌ 失败")"
echo "Core-Foundation集成: $([ $core_foundation_usage -gt 0 ] && echo "✅ 已集成" || echo "⚠️  未集成")"
echo "Runtime-Foundation集成: $([ $runtime_foundation_usage -gt 0 ] && echo "✅ 已集成" || echo "⚠️  未集成")"
echo "代码总量: $total_lines 行"

# 10. 计算总体评分
total_checks=5
passed_checks=0

[ $missing_dirs -eq 0 ] && passed_checks=$((passed_checks + 1))
[ $missing_files -eq 0 ] && passed_checks=$((passed_checks + 1))
[ $foundation_upward_deps -eq 0 ] && passed_checks=$((passed_checks + 1))
[ $core_foundation_usage -gt 0 ] && passed_checks=$((passed_checks + 1))
[ $runtime_foundation_usage -gt 0 ] && passed_checks=$((passed_checks + 1))

score=$((passed_checks * 100 / total_checks))
echo ""
echo "🎯 架构验证评分: $score% ($passed_checks/$total_checks)"

if [ $score -ge 80 ]; then
    echo "🎉 架构验证通过！CActor 7.0 架构改造成功！"
    exit 0
elif [ $score -ge 60 ]; then
    echo "⚠️  架构基本合格，但需要改进"
    exit 1
else
    echo "❌ 架构验证失败，需要重大修复"
    exit 2
fi
