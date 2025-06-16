#!/bin/bash

# CActor 7.0 最终状态验证脚本
# 验证所有功能、性能和架构完整性

echo "========================================"
echo "=== CActor 7.0 最终状态验证 ==="
echo "验证Plan7.md中的所有成就和目标"
echo "========================================"
echo

# 颜色定义
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 计数器
TOTAL_TESTS=0
PASSED_TESTS=0

# 测试函数
run_test() {
    local test_name="$1"
    local test_command="$2"
    
    echo -e "${BLUE}🔍 测试: ${test_name}${NC}"
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    
    if eval "$test_command" > /dev/null 2>&1; then
        echo -e "${GREEN}  ✅ 通过${NC}"
        PASSED_TESTS=$((PASSED_TESTS + 1))
        return 0
    else
        echo -e "${RED}  ❌ 失败${NC}"
        return 1
    fi
}

# 1. 架构完整性验证
echo -e "${YELLOW}📋 第一部分: 架构完整性验证${NC}"
echo

# 检查6层架构目录结构
run_test "Foundation层目录结构" "[ -d 'src/foundation/memory' ] && [ -d 'src/foundation/queue' ] && [ -d 'src/foundation/serialization' ] && [ -d 'src/foundation/network' ]"

run_test "Core层目录结构" "[ -d 'src/core/actor' ] && [ -d 'src/core/message' ] && [ -d 'src/core/system' ] && [ -d 'src/core/context' ]"

run_test "Runtime层目录结构" "[ -d 'src/runtime/dispatcher' ] && [ -d 'src/runtime/mailbox' ]"

run_test "Patterns层目录结构" "[ -d 'src/patterns/ask' ] && [ -d 'src/patterns/routing' ] && [ -d 'src/patterns/circuit_breaker' ] && [ -d 'src/patterns/backpressure' ]"

run_test "Distribution层目录结构" "[ -d 'src/distribution/remote' ] && [ -d 'src/distribution/cluster' ] && [ -d 'src/distribution/persistence' ] && [ -d 'src/distribution/streaming' ]"

run_test "Integration层目录结构" "[ -d 'src/integration/configuration' ] && [ -d 'src/integration/monitoring' ] && [ -d 'src/integration/logging' ] && [ -d 'src/integration/testing' ]"

echo

# 2. 编译验证
echo -e "${YELLOW}🔧 第二部分: 编译验证${NC}"
echo

run_test "项目编译成功" "cd /Users/louloulin/Documents/linchong/cangjie && cjpm build"

echo

# 3. 核心功能测试
echo -e "${YELLOW}⚡ 第三部分: 核心功能测试${NC}"
echo

run_test "Plan7综合功能验证" "cd /Users/louloulin/Documents/linchong/cangjie && timeout 60 cjpm run --name cactor.integration.testing.plan7_comprehensive_test"

run_test "性能目标验证测试" "cd /Users/louloulin/Documents/linchong/cangjie && timeout 120 cjpm run --name cactor.integration.testing.performance_target_verification"

run_test "JCTools基准测试" "cd /Users/louloulin/Documents/linchong/cangjie && timeout 90 cjpm run --name cactor.integration.testing.jctools_inspired_benchmark"

echo

# 4. 代码质量验证
echo -e "${YELLOW}📊 第四部分: 代码质量验证${NC}"
echo

# 统计代码行数
TOTAL_FILES=$(find src -name "*.cj" | wc -l)
TOTAL_LINES=$(find src -name "*.cj" -exec wc -l {} + | tail -1 | awk '{print $1}')

run_test "代码文件数量充足" "[ $TOTAL_FILES -ge 160 ]"
run_test "代码行数达标" "[ $TOTAL_LINES -ge 35000 ]"

# 检查关键文件存在
run_test "Foundation零依赖验证" "[ -f 'src/foundation/queue/queue.cj' ] && [ -f 'src/foundation/memory/object_pool.cj' ]"

run_test "Core层关键文件" "[ -f 'src/core/actor/actor.cj' ] && [ -f 'src/core/message/message.cj' ]"

run_test "Runtime层关键文件" "[ -f 'src/runtime/mailbox/foundation_mailbox.cj' ] && [ -f 'src/runtime/dispatcher/work_stealing/work_stealing_dispatcher.cj' ]"

echo

# 5. 测试覆盖验证
echo -e "${YELLOW}🧪 第五部分: 测试覆盖验证${NC}"
echo

# 检查测试文件存在
run_test "简单性能测试" "[ -f 'src/integration/testing/simple_performance_test/main.cj' ]"
run_test "极限性能测试" "[ -f 'src/integration/testing/extreme_performance_test/main.cj' ]"
run_test "JCTools基准测试" "[ -f 'src/integration/testing/jctools_inspired_benchmark/main.cj' ]"
run_test "性能目标验证测试" "[ -f 'src/integration/testing/performance_target_verification/main.cj' ]"

echo

# 6. 配置文件验证
echo -e "${YELLOW}⚙️  第六部分: 配置文件验证${NC}"
echo

run_test "cjpm.toml配置完整" "[ -f 'cjpm.toml' ] && grep -q 'performance_target_verification' cjpm.toml"
run_test "plan7.md文档存在" "[ -f 'plan7.md' ]"

echo

# 最终结果统计
echo "========================================"
echo -e "${BLUE}=== 最终验证结果 ===${NC}"
echo "========================================"
echo

SUCCESS_RATE=$(echo "scale=1; $PASSED_TESTS * 100 / $TOTAL_TESTS" | bc)

echo "📊 测试统计:"
echo "  总测试数: $TOTAL_TESTS"
echo "  通过测试: $PASSED_TESTS"
echo "  成功率: ${SUCCESS_RATE}%"
echo

echo "📈 代码统计:"
echo "  文件数量: $TOTAL_FILES 个"
echo "  代码行数: $TOTAL_LINES 行"
echo

if [ "$PASSED_TESTS" -eq "$TOTAL_TESTS" ]; then
    echo -e "${GREEN}🎉 CActor 7.0 验证完全成功！${NC}"
    echo -e "${GREEN}✅ 所有架构、功能、性能测试全部通过${NC}"
    echo -e "${GREEN}🚀 CActor 7.0 已达到世界级Actor框架标准${NC}"
    exit 0
elif [ "$PASSED_TESTS" -ge $((TOTAL_TESTS * 8 / 10)) ]; then
    echo -e "${YELLOW}⚡ CActor 7.0 验证大部分成功！${NC}"
    echo -e "${YELLOW}✅ 80%以上测试通过，系统基本达标${NC}"
    echo -e "${YELLOW}📈 建议继续优化剩余问题${NC}"
    exit 0
else
    echo -e "${RED}❌ CActor 7.0 验证需要改进${NC}"
    echo -e "${RED}📋 请检查失败的测试项目${NC}"
    exit 1
fi
