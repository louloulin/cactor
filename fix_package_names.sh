#!/bin/bash
# fix_package_names.sh - 批量修复包名脚本

echo "=== 修复CActor 7.0架构包名 ==="

# 修复foundation层包名
echo "修复Foundation层包名..."
find src/foundation -name "*.cj" -type f -exec sed -i.bak 's/package cactor\.memory/package cactor.foundation.memory/g' {} \; 2>/dev/null || true
find src/foundation -name "*.cj" -type f -exec sed -i.bak 's/package cactor\.core\.memory/package cactor.foundation.memory/g' {} \; 2>/dev/null || true
find src/foundation -name "*.cj" -type f -exec sed -i.bak 's/package cactor\.core\.collections/package cactor.foundation.concurrency/g' {} \; 2>/dev/null || true
find src/foundation -name "*.cj" -type f -exec sed -i.bak 's/package cactor\.mailbox\.lockfree/package cactor.foundation.concurrency/g' {} \; 2>/dev/null || true
find src/foundation -name "*.cj" -type f -exec sed -i.bak 's/package cactor\.serialization/package cactor.foundation.serialization/g' {} \; 2>/dev/null || true
find src/foundation -name "*.cj" -type f -exec sed -i.bak 's/package cactor\.network/package cactor.foundation.network/g' {} \; 2>/dev/null || true

# 修复core层包名
echo "修复Core层包名..."
find src/core -name "*.cj" -type f -exec sed -i.bak 's/package cactor\.core\.actor/package cactor.core.actor/g' {} \; 2>/dev/null || true
find src/core -name "*.cj" -type f -exec sed -i.bak 's/package cactor\.core\.message/package cactor.core.message/g' {} \; 2>/dev/null || true
find src/core -name "*.cj" -type f -exec sed -i.bak 's/package cactor\.core\.system/package cactor.core.system/g' {} \; 2>/dev/null || true
find src/core -name "*.cj" -type f -exec sed -i.bak 's/package cactor\.runtime\.system/package cactor.core.system/g' {} \; 2>/dev/null || true
find src/core -name "*.cj" -type f -exec sed -i.bak 's/package cactor\.supervision/package cactor.core.supervision/g' {} \; 2>/dev/null || true
find src/core -name "*.cj" -type f -exec sed -i.bak 's/package cactor\.core\.context/package cactor.core.context/g' {} \; 2>/dev/null || true

# 修复runtime层包名
echo "修复Runtime层包名..."
find src/runtime -name "*.cj" -type f -exec sed -i.bak 's/package cactor\.dispatcher/package cactor.runtime.dispatcher/g' {} \; 2>/dev/null || true
find src/runtime -name "*.cj" -type f -exec sed -i.bak 's/package cactor\.mailbox/package cactor.runtime.mailbox/g' {} \; 2>/dev/null || true

# 修复patterns层包名
echo "修复Patterns层包名..."
find src/patterns -name "*.cj" -type f -exec sed -i.bak 's/package cactor\.pattern\.ask/package cactor.patterns.ask/g' {} \; 2>/dev/null || true
find src/patterns -name "*.cj" -type f -exec sed -i.bak 's/package cactor\.routing/package cactor.patterns.routing/g' {} \; 2>/dev/null || true
find src/patterns -name "*.cj" -type f -exec sed -i.bak 's/package cactor\.circuit_breaker/package cactor.patterns.circuit_breaker/g' {} \; 2>/dev/null || true

# 修复distribution层包名
echo "修复Distribution层包名..."
find src/distribution -name "*.cj" -type f -exec sed -i.bak 's/package cactor\.remote/package cactor.distribution.remote/g' {} \; 2>/dev/null || true
find src/distribution -name "*.cj" -type f -exec sed -i.bak 's/package cactor\.cluster/package cactor.distribution.cluster/g' {} \; 2>/dev/null || true
find src/distribution -name "*.cj" -type f -exec sed -i.bak 's/package cactor\.persistence/package cactor.distribution.persistence/g' {} \; 2>/dev/null || true
find src/distribution -name "*.cj" -type f -exec sed -i.bak 's/package cactor\.stream/package cactor.distribution.streaming/g' {} \; 2>/dev/null || true

# 修复integration层包名
echo "修复Integration层包名..."
find src/integration -name "*.cj" -type f -exec sed -i.bak 's/package cactor\.config/package cactor.integration.configuration/g' {} \; 2>/dev/null || true
find src/integration -name "*.cj" -type f -exec sed -i.bak 's/package cactor\.monitoring/package cactor.integration.monitoring/g' {} \; 2>/dev/null || true
find src/integration -name "*.cj" -type f -exec sed -i.bak 's/package cactor\.logging/package cactor.integration.logging/g' {} \; 2>/dev/null || true
find src/integration -name "*.cj" -type f -exec sed -i.bak 's/package cactor\.debug/package cactor.integration.logging/g' {} \; 2>/dev/null || true
find src/integration -name "*.cj" -type f -exec sed -i.bak 's/package cactor\.tests/package cactor.integration.testing/g' {} \; 2>/dev/null || true

# 清理备份文件
echo "清理备份文件..."
find src -name "*.bak" -type f -delete 2>/dev/null || true

echo "包名修复完成！"
