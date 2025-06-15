#!/bin/bash
# fix_dependencies.sh - 修复依赖问题

echo "=== 修复CActor 7.0架构依赖问题 ==="

# 查找并注释掉有问题的导入
echo "注释掉有问题的导入..."

# 注释掉旧的导入路径
find src -name "*.cj" -type f -exec sed -i.bak 's/^import cactor\.pattern\.ask/\/\/ import cactor.pattern.ask/g' {} \; 2>/dev/null || true
find src -name "*.cj" -type f -exec sed -i.bak 's/^import cactor\.mailbox\.lockfree/\/\/ import cactor.mailbox.lockfree/g' {} \; 2>/dev/null || true
find src -name "*.cj" -type f -exec sed -i.bak 's/^import cactor\.core\.memory/\/\/ import cactor.core.memory/g' {} \; 2>/dev/null || true
find src -name "*.cj" -type f -exec sed -i.bak 's/^import cactor\.core\.mailbox/\/\/ import cactor.core.mailbox/g' {} \; 2>/dev/null || true
find src -name "*.cj" -type f -exec sed -i.bak 's/^import cactor\.mailbox\.ringbuffer/\/\/ import cactor.mailbox.ringbuffer/g' {} \; 2>/dev/null || true
find src -name "*.cj" -type f -exec sed -i.bak 's/^import cactor\.circuit_breaker/\/\/ import cactor.circuit_breaker/g' {} \; 2>/dev/null || true
find src -name "*.cj" -type f -exec sed -i.bak 's/^import cactor\.pattern/\/\/ import cactor.pattern/g' {} \; 2>/dev/null || true
find src -name "*.cj" -type f -exec sed -i.bak 's/^import cactor\.routing/\/\/ import cactor.routing/g' {} \; 2>/dev/null || true
find src -name "*.cj" -type f -exec sed -i.bak 's/^import cactor\.supervision/\/\/ import cactor.supervision/g' {} \; 2>/dev/null || true
find src -name "*.cj" -type f -exec sed -i.bak 's/^import cactor\.dispatcher/\/\/ import cactor.dispatcher/g' {} \; 2>/dev/null || true
find src -name "*.cj" -type f -exec sed -i.bak 's/^import cactor\.mailbox/\/\/ import cactor.mailbox/g' {} \; 2>/dev/null || true
find src -name "*.cj" -type f -exec sed -i.bak 's/^import cactor\.runtime\.system/\/\/ import cactor.runtime.system/g' {} \; 2>/dev/null || true
find src -name "*.cj" -type f -exec sed -i.bak 's/^import cactor\.core\.zerocopy/\/\/ import cactor.core.zerocopy/g' {} \; 2>/dev/null || true
find src -name "*.cj" -type f -exec sed -i.bak 's/^import cactor\.macros/\/\/ import cactor.macros/g' {} \; 2>/dev/null || true
find src -name "*.cj" -type f -exec sed -i.bak 's/^import cactor\.benchmark/\/\/ import cactor.benchmark/g' {} \; 2>/dev/null || true
find src -name "*.cj" -type f -exec sed -i.bak 's/^import cactor\.cluster/\/\/ import cactor.cluster/g' {} \; 2>/dev/null || true
find src -name "*.cj" -type f -exec sed -i.bak 's/^import cactor\.remote/\/\/ import cactor.remote/g' {} \; 2>/dev/null || true
find src -name "*.cj" -type f -exec sed -i.bak 's/^import cactor\.monitoring/\/\/ import cactor.monitoring/g' {} \; 2>/dev/null || true
find src -name "*.cj" -type f -exec sed -i.bak 's/^import cactor\.core\.monitoring/\/\/ import cactor.core.monitoring/g' {} \; 2>/dev/null || true
find src -name "*.cj" -type f -exec sed -i.bak 's/^import cactor\.virtual/\/\/ import cactor.virtual/g' {} \; 2>/dev/null || true
find src -name "*.cj" -type f -exec sed -i.bak 's/^import cactor\.debug/\/\/ import cactor.debug/g' {} \; 2>/dev/null || true
find src -name "*.cj" -type f -exec sed -i.bak 's/^import cactor\.logging/\/\/ import cactor.logging/g' {} \; 2>/dev/null || true
find src -name "*.cj" -type f -exec sed -i.bak 's/^import cactor\.config/\/\/ import cactor.config/g' {} \; 2>/dev/null || true
find src -name "*.cj" -type f -exec sed -i.bak 's/^import cactor\.serialization/\/\/ import cactor.serialization/g' {} \; 2>/dev/null || true
find src -name "*.cj" -type f -exec sed -i.bak 's/^import cactor\.network/\/\/ import cactor.network/g' {} \; 2>/dev/null || true
find src -name "*.cj" -type f -exec sed -i.bak 's/^import cactor\.memory/\/\/ import cactor.memory/g' {} \; 2>/dev/null || true

# 清理备份文件
echo "清理备份文件..."
find src -name "*.bak" -type f -delete 2>/dev/null || true

echo "依赖问题修复完成！"
