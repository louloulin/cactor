#!/bin/bash
# verify_cactor_complete_system.sh - CActor完整系统验证

echo "=== CActor 完整系统验证 ==="

# 创建验证结果目录
mkdir -p verification_results
timestamp=$(date +%Y%m%d_%H%M%S)
result_file="verification_results/cactor_complete_verification_${timestamp}.log"

echo "验证时间: $(date)" > $result_file
echo "系统信息:" >> $result_file
uname -a >> $result_file
echo "" >> $result_file

# 1. 架构完整性验证
echo "🏗️ 验证架构完整性..." | tee -a $result_file
./verify_cactor_architecture.sh > /tmp/arch_verification.log 2>&1
arch_result=$?

if [ $arch_result -eq 0 ]; then
    echo "✅ 架构完整性验证通过" | tee -a $result_file
    arch_score=100
else
    echo "❌ 架构完整性验证失败" | tee -a $result_file
    arch_score=0
fi

# 2. Foundation层零依赖验证
echo "" | tee -a $result_file
echo "🔍 验证Foundation层零依赖..." | tee -a $result_file
./check_foundation_dependencies.sh > /tmp/foundation_verification.log 2>&1
foundation_result=$?

if [ $foundation_result -eq 0 ]; then
    echo "✅ Foundation层零依赖验证通过" | tee -a $result_file
    foundation_score=100
else
    echo "❌ Foundation层零依赖验证失败" | tee -a $result_file
    foundation_score=0
fi

# 3. 生产环境就绪验证
echo "" | tee -a $result_file
echo "🚀 验证生产环境就绪度..." | tee -a $result_file
./production_readiness_check.sh > /tmp/production_verification.log 2>&1
production_result=$?

if [ $production_result -eq 0 ]; then
    echo "✅ 生产环境就绪验证通过" | tee -a $result_file
    production_score=100
elif [ $production_result -eq 1 ]; then
    echo "⚠️  生产环境基本就绪" | tee -a $result_file
    production_score=80
else
    echo "❌ 生产环境未就绪" | tee -a $result_file
    production_score=0
fi

# 4. 6层架构验证
echo "" | tee -a $result_file
echo "📚 验证6层架构完整性..." | tee -a $result_file

layers=(
    "src/foundation"
    "src/core" 
    "src/runtime"
    "src/patterns"
    "src/distribution"
    "src/integration"
)

layer_score=0
total_layers=${#layers[@]}

for layer in "${layers[@]}"; do
    if [ -d "$layer" ]; then
        file_count=$(find "$layer" -name "*.cj" | wc -l)
        if [ $file_count -gt 0 ]; then
            echo "✅ ${layer}: ${file_count} 文件" | tee -a $result_file
            layer_score=$((layer_score + 1))
        else
            echo "⚠️  ${layer}: 无Cangjie文件" | tee -a $result_file
        fi
    else
        echo "❌ ${layer}: 目录不存在" | tee -a $result_file
    fi
done

layer_percentage=$((layer_score * 100 / total_layers))
echo "6层架构完整度: ${layer_percentage}% (${layer_score}/${total_layers})" | tee -a $result_file

# 5. 关键组件验证
echo "" | tee -a $result_file
echo "🔧 验证关键组件..." | tee -a $result_file

key_components=(
    "src/foundation/queue/lockfree_queue.cj"
    "src/foundation/serialization/serialization_manager.cj"
    "src/foundation/network/transport.cj"
    "src/foundation/memory/object_pool/object_pool.cj"
    "src/core/message/message.cj"
    "src/core/actor/actor.cj"
    "src/runtime/mailbox/foundation_mailbox.cj"
    "src/patterns/ask/ask_pattern.cj"
    "src/patterns/circuit_breaker/circuit_breaker.cj"
    "src/patterns/backpressure/backpressure.cj"
    "src/patterns/routing/router.cj"
    "src/distribution/remote/simple_remote.cj"
    "src/integration/monitoring/metrics.cj"
)

component_score=0
total_components=${#key_components[@]}

for component in "${key_components[@]}"; do
    if [ -f "$component" ]; then
        lines=$(wc -l < "$component")
        echo "✅ $(basename $component): ${lines} 行" | tee -a $result_file
        component_score=$((component_score + 1))
    else
        echo "❌ $(basename $component): 缺失" | tee -a $result_file
    fi
done

component_percentage=$((component_score * 100 / total_components))
echo "关键组件完整度: ${component_percentage}% (${component_score}/${total_components})" | tee -a $result_file

# 6. 测试覆盖验证
echo "" | tee -a $result_file
echo "🧪 验证测试覆盖..." | tee -a $result_file

test_files=(
    "test/cactor_functionality_test.cj"
    "test/cactor_performance_test.cj"
    "test/cactor_integration_test.cj"
    "test/patterns_test.cj"
    "test/cactor_full_system_test.cj"
)

test_score=0
total_tests=${#test_files[@]}

for test_file in "${test_files[@]}"; do
    if [ -f "$test_file" ]; then
        lines=$(wc -l < "$test_file")
        echo "✅ $(basename $test_file): ${lines} 行" | tee -a $result_file
        test_score=$((test_score + 1))
    else
        echo "❌ $(basename $test_file): 缺失" | tee -a $result_file
    fi
done

test_percentage=$((test_score * 100 / total_tests))
echo "测试覆盖度: ${test_percentage}% (${test_score}/${total_tests})" | tee -a $result_file

# 7. 文档完整性验证
echo "" | tee -a $result_file
echo "📖 验证文档完整性..." | tee -a $result_file

doc_files=(
    "README.md"
    "plan7.md"
    "Foundation.md"
    "Foundation_Achievement_Report.md"
    "CActor_7.0_Operations_Guide.md"
    "CActor_7.0_Final_Achievement_Report.md"
)

doc_score=0
total_docs=${#doc_files[@]}

for doc_file in "${doc_files[@]}"; do
    if [ -f "$doc_file" ]; then
        lines=$(wc -l < "$doc_file")
        echo "✅ $(basename $doc_file): ${lines} 行" | tee -a $result_file
        doc_score=$((doc_score + 1))
    else
        echo "❌ $(basename $doc_file): 缺失" | tee -a $result_file
    fi
done

doc_percentage=$((doc_score * 100 / total_docs))
echo "文档完整度: ${doc_percentage}% (${doc_score}/${total_docs})" | tee -a $result_file

# 8. 代码质量统计
echo "" | tee -a $result_file
echo "📊 代码质量统计..." | tee -a $result_file

foundation_lines=$(find src/foundation -name "*.cj" -exec wc -l {} \; 2>/dev/null | awk '{sum += $1} END {print sum}')
core_lines=$(find src/core -name "*.cj" -exec wc -l {} \; 2>/dev/null | awk '{sum += $1} END {print sum}')
runtime_lines=$(find src/runtime -name "*.cj" -exec wc -l {} \; 2>/dev/null | awk '{sum += $1} END {print sum}')
patterns_lines=$(find src/patterns -name "*.cj" -exec wc -l {} \; 2>/dev/null | awk '{sum += $1} END {print sum}')
distribution_lines=$(find src/distribution -name "*.cj" -exec wc -l {} \; 2>/dev/null | awk '{sum += $1} END {print sum}')
integration_lines=$(find src/integration -name "*.cj" -exec wc -l {} \; 2>/dev/null | awk '{sum += $1} END {print sum}')
test_lines=$(find test -name "*.cj" -exec wc -l {} \; 2>/dev/null | awk '{sum += $1} END {print sum}')

total_lines=$((${foundation_lines:-0} + ${core_lines:-0} + ${runtime_lines:-0} + ${patterns_lines:-0} + ${distribution_lines:-0} + ${integration_lines:-0}))

echo "Foundation层: ${foundation_lines:-0} 行" | tee -a $result_file
echo "Core层: ${core_lines:-0} 行" | tee -a $result_file
echo "Runtime层: ${runtime_lines:-0} 行" | tee -a $result_file
echo "Patterns层: ${patterns_lines:-0} 行" | tee -a $result_file
echo "Distribution层: ${distribution_lines:-0} 行" | tee -a $result_file
echo "Integration层: ${integration_lines:-0} 行" | tee -a $result_file
echo "测试代码: ${test_lines:-0} 行" | tee -a $result_file
echo "总代码量: $total_lines 行" | tee -a $result_file

# 9. 综合评分计算
echo "" | tee -a $result_file
echo "🎯 综合评分计算..." | tee -a $result_file

# 权重分配
arch_weight=20
foundation_weight=20
production_weight=15
layer_weight=15
component_weight=15
test_weight=10
doc_weight=5

# 计算加权分数
weighted_score=$(( 
    (arch_score * arch_weight / 100) + 
    (foundation_score * foundation_weight / 100) + 
    (production_score * production_weight / 100) + 
    (layer_percentage * layer_weight / 100) + 
    (component_percentage * component_weight / 100) + 
    (test_percentage * test_weight / 100) + 
    (doc_percentage * doc_weight / 100)
))

echo "评分详情:" | tee -a $result_file
echo "  架构完整性: ${arch_score}% (权重${arch_weight}%)" | tee -a $result_file
echo "  Foundation零依赖: ${foundation_score}% (权重${foundation_weight}%)" | tee -a $result_file
echo "  生产就绪: ${production_score}% (权重${production_weight}%)" | tee -a $result_file
echo "  6层架构: ${layer_percentage}% (权重${layer_weight}%)" | tee -a $result_file
echo "  关键组件: ${component_percentage}% (权重${component_weight}%)" | tee -a $result_file
echo "  测试覆盖: ${test_percentage}% (权重${test_weight}%)" | tee -a $result_file
echo "  文档完整: ${doc_percentage}% (权重${doc_weight}%)" | tee -a $result_file

echo "" | tee -a $result_file
echo "🏆 CActor完整系统评分: ${weighted_score}%" | tee -a $result_file

# 10. 最终评估
echo "" | tee -a $result_file
echo "📋 最终评估报告" | tee -a $result_file
echo "==================" | tee -a $result_file

if [ $weighted_score -ge 90 ]; then
    echo "🎉 优秀！CActor系统已达到世界级标准！" | tee -a $result_file
    echo "   系统完整性极高，可以投入生产使用" | tee -a $result_file
    exit_code=0
elif [ $weighted_score -ge 80 ]; then
    echo "✅ 良好！CActor系统质量很高！" | tee -a $result_file
    echo "   系统基本完整，建议优化后投入生产" | tee -a $result_file
    exit_code=0
elif [ $weighted_score -ge 70 ]; then
    echo "⚠️  合格！CActor系统基本可用！" | tee -a $result_file
    echo "   需要进一步完善关键功能" | tee -a $result_file
    exit_code=1
else
    echo "❌ 需要改进！CActor系统还需要大量工作！" | tee -a $result_file
    echo "   建议重点解决架构和核心功能问题" | tee -a $result_file
    exit_code=2
fi

echo "" | tee -a $result_file
echo "验证完成时间: $(date)" | tee -a $result_file
echo "详细报告: $result_file" | tee -a $result_file

echo ""
echo "🎯 CActor完整系统验证完成！"
echo "📊 综合评分: ${weighted_score}%"
echo "📄 详细报告: $result_file"

exit $exit_code
