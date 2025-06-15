#!/bin/bash
# production_readiness_check.sh - CActor 7.0 生产环境就绪检查

echo "=== CActor 7.0 生产环境就绪检查 ==="

# 1. 架构完整性检查
echo "🏗️ 检查架构完整性..."
./verify_cactor_architecture.sh > /tmp/arch_check.log 2>&1
arch_score=$(tail -1 /tmp/arch_check.log | grep -o '[0-9]\+%' | grep -o '[0-9]\+' | head -1)
arch_score=${arch_score:-0}

if [ "$arch_score" -ge 90 ]; then
    echo "✅ 架构完整性: ${arch_score}% (优秀)"
    arch_ready=1
elif [ "$arch_score" -ge 80 ]; then
    echo "⚠️  架构完整性: ${arch_score}% (良好，建议优化)"
    arch_ready=1
else
    echo "❌ 架构完整性: ${arch_score}% (需要改进)"
    arch_ready=0
fi

# 2. Foundation层零依赖验证
echo ""
echo "🔍 验证Foundation层零依赖..."
./check_foundation_dependencies.sh > /tmp/foundation_check.log 2>&1
if grep -q "Foundation层依赖检查通过" /tmp/foundation_check.log; then
    echo "✅ Foundation层零依赖验证通过"
    foundation_ready=1
else
    echo "❌ Foundation层依赖验证失败"
    foundation_ready=0
fi

# 3. 代码质量检查
echo ""
echo "📊 检查代码质量..."

# 检查代码行数和结构
foundation_lines=$(find src/foundation -name "*.cj" -exec wc -l {} \; 2>/dev/null | awk '{sum += $1} END {print sum}')
core_lines=$(find src/core -name "*.cj" -exec wc -l {} \; 2>/dev/null | awk '{sum += $1} END {print sum}')
runtime_lines=$(find src/runtime -name "*.cj" -exec wc -l {} \; 2>/dev/null | awk '{sum += $1} END {print sum}')
total_lines=$((${foundation_lines:-0} + ${core_lines:-0} + ${runtime_lines:-0}))

echo "代码规模: $total_lines 行"
if [ $total_lines -gt 5000 ]; then
    echo "✅ 代码规模充足 ($total_lines 行)"
    code_size_ready=1
else
    echo "⚠️  代码规模较小 ($total_lines 行)"
    code_size_ready=0
fi

# 检查关键组件
key_components=(
    "src/foundation/queue/queue.cj"
    "src/foundation/queue/lockfree_queue.cj"
    "src/foundation/serialization/serialization_manager.cj"
    "src/foundation/network/transport.cj"
    "src/foundation/memory/object_pool/object_pool.cj"
    "src/core/message/message.cj"
    "src/core/message/message_serializer.cj"
    "src/core/actor/actor.cj"
    "src/runtime/mailbox/foundation_mailbox.cj"
)

missing_components=0
for component in "${key_components[@]}"; do
    if [ ! -f "$component" ]; then
        echo "❌ 缺少关键组件: $component"
        missing_components=$((missing_components + 1))
    fi
done

if [ $missing_components -eq 0 ]; then
    echo "✅ 所有关键组件完整"
    components_ready=1
else
    echo "❌ 缺少 $missing_components 个关键组件"
    components_ready=0
fi

# 4. 测试覆盖率检查
echo ""
echo "🧪 检查测试覆盖率..."

test_files=(
    "test/cactor_functionality_test.cj"
    "test/cactor_performance_test.cj"
    "test/cactor_integration_test.cj"
    "test/runtime_foundation_integration_test.cj"
)

existing_tests=0
for test_file in "${test_files[@]}"; do
    if [ -f "$test_file" ]; then
        existing_tests=$((existing_tests + 1))
    fi
done

test_coverage=$((existing_tests * 100 / ${#test_files[@]}))
echo "测试覆盖率: $test_coverage% ($existing_tests/${#test_files[@]} 测试套件)"

if [ $test_coverage -ge 75 ]; then
    echo "✅ 测试覆盖率充足"
    test_ready=1
else
    echo "⚠️  测试覆盖率不足"
    test_ready=0
fi

# 5. 性能基准检查
echo ""
echo "⚡ 检查性能基准..."

# 检查是否有性能测试
if [ -f "test/cactor_performance_test.cj" ]; then
    echo "✅ 性能测试套件存在"
    perf_test_ready=1
else
    echo "❌ 缺少性能测试套件"
    perf_test_ready=0
fi

# 检查高性能组件
high_perf_components=(
    "src/foundation/queue/lockfree_queue.cj"
    "src/runtime/mailbox/foundation_mailbox.cj"
)

high_perf_ready=1
for component in "${high_perf_components[@]}"; do
    if [ ! -f "$component" ]; then
        echo "❌ 缺少高性能组件: $component"
        high_perf_ready=0
    fi
done

if [ $high_perf_ready -eq 1 ]; then
    echo "✅ 高性能组件完整"
fi

# 6. 文档完整性检查
echo ""
echo "📚 检查文档完整性..."

doc_files=(
    "README.md"
    "plan7.md"
    "Foundation.md"
    "Foundation_Achievement_Report.md"
)

existing_docs=0
for doc_file in "${doc_files[@]}"; do
    if [ -f "$doc_file" ]; then
        existing_docs=$((existing_docs + 1))
    fi
done

doc_coverage=$((existing_docs * 100 / ${#doc_files[@]}))
echo "文档覆盖率: $doc_coverage% ($existing_docs/${#doc_files[@]} 文档)"

if [ $doc_coverage -ge 75 ]; then
    echo "✅ 文档覆盖率充足"
    doc_ready=1
else
    echo "⚠️  文档覆盖率不足"
    doc_ready=0
fi

# 7. 安全性检查
echo ""
echo "🔒 检查安全性..."

# 检查是否有明显的安全问题
security_issues=0

# 检查是否有硬编码的敏感信息
if grep -r "password\|secret\|key" src/ 2>/dev/null | grep -v "// " | grep -v "/\*" | wc -l | grep -q "^0$"; then
    echo "✅ 无明显硬编码敏感信息"
else
    echo "⚠️  发现可能的硬编码敏感信息"
    security_issues=$((security_issues + 1))
fi

# 检查是否有不安全的网络配置
if grep -r "0\.0\.0\.0\|127\.0\.0\.1" src/ 2>/dev/null | wc -l | awk '{if($1 <= 5) print "safe"; else print "unsafe"}' | grep -q "safe"; then
    echo "✅ 网络配置安全"
else
    echo "⚠️  网络配置可能存在安全风险"
    security_issues=$((security_issues + 1))
fi

if [ $security_issues -eq 0 ]; then
    echo "✅ 安全性检查通过"
    security_ready=1
else
    echo "⚠️  发现 $security_issues 个安全问题"
    security_ready=0
fi

# 8. 生成就绪报告
echo ""
echo "📋 生产环境就绪报告"
echo "=================================="

# 计算总体就绪分数
total_checks=7
ready_checks=0

[ $arch_ready -eq 1 ] && ready_checks=$((ready_checks + 1))
[ $foundation_ready -eq 1 ] && ready_checks=$((ready_checks + 1))
[ $code_size_ready -eq 1 ] && ready_checks=$((ready_checks + 1))
[ $components_ready -eq 1 ] && ready_checks=$((ready_checks + 1))
[ $test_ready -eq 1 ] && ready_checks=$((ready_checks + 1))
[ $perf_test_ready -eq 1 ] && ready_checks=$((ready_checks + 1))
[ $doc_ready -eq 1 ] && ready_checks=$((ready_checks + 1))

readiness_score=$((ready_checks * 100 / total_checks))

echo "架构完整性: $([ $arch_ready -eq 1 ] && echo "✅ 就绪" || echo "❌ 未就绪")"
echo "Foundation零依赖: $([ $foundation_ready -eq 1 ] && echo "✅ 就绪" || echo "❌ 未就绪")"
echo "代码质量: $([ $code_size_ready -eq 1 ] && echo "✅ 就绪" || echo "❌ 未就绪")"
echo "关键组件: $([ $components_ready -eq 1 ] && echo "✅ 就绪" || echo "❌ 未就绪")"
echo "测试覆盖: $([ $test_ready -eq 1 ] && echo "✅ 就绪" || echo "❌ 未就绪")"
echo "性能测试: $([ $perf_test_ready -eq 1 ] && echo "✅ 就绪" || echo "❌ 未就绪")"
echo "文档完整: $([ $doc_ready -eq 1 ] && echo "✅ 就绪" || echo "❌ 未就绪")"
echo "安全性: $([ $security_ready -eq 1 ] && echo "✅ 就绪" || echo "⚠️  需注意")"

echo ""
echo "🎯 生产环境就绪度: $readiness_score% ($ready_checks/$total_checks)"

if [ $readiness_score -ge 85 ]; then
    echo "🎉 生产环境就绪！CActor 7.0 可以部署到生产环境！"
    exit 0
elif [ $readiness_score -ge 70 ]; then
    echo "⚠️  基本就绪，建议解决剩余问题后部署"
    exit 1
else
    echo "❌ 未就绪，需要解决关键问题后再部署"
    exit 2
fi
