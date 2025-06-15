#!/bin/bash
# fix_imports.sh - 修复所有导入路径

echo "=== 修复CActor 7.0架构导入路径 ==="

# 修复foundation层导入
echo "修复Foundation层导入..."
find src/foundation -name "*.cj" -type f -exec sed -i.bak 's/import cactor\.memory\./import cactor.foundation.memory./g' {} \; 2>/dev/null || true
find src/foundation -name "*.cj" -type f -exec sed -i.bak 's/import cactor\.core\.memory\./import cactor.foundation.memory./g' {} \; 2>/dev/null || true
find src/foundation -name "*.cj" -type f -exec sed -i.bak 's/import cactor\.core\.collections\./import cactor.foundation.concurrency./g' {} \; 2>/dev/null || true
find src/foundation -name "*.cj" -type f -exec sed -i.bak 's/import cactor\.mailbox\.lockfree\./import cactor.foundation.concurrency./g' {} \; 2>/dev/null || true
find src/foundation -name "*.cj" -type f -exec sed -i.bak 's/import cactor\.serialization\./import cactor.foundation.serialization./g' {} \; 2>/dev/null || true
find src/foundation -name "*.cj" -type f -exec sed -i.bak 's/import cactor\.network\./import cactor.foundation.network./g' {} \; 2>/dev/null || true

# 修复core层导入
echo "修复Core层导入..."
find src/core -name "*.cj" -type f -exec sed -i.bak 's/import cactor\.core\.memory\./import cactor.foundation.memory./g' {} \; 2>/dev/null || true
find src/core -name "*.cj" -type f -exec sed -i.bak 's/import cactor\.runtime\.system\./import cactor.core.system./g' {} \; 2>/dev/null || true
find src/core -name "*.cj" -type f -exec sed -i.bak 's/import cactor\.supervision\./import cactor.core.supervision./g' {} \; 2>/dev/null || true

# 修复runtime层导入
echo "修复Runtime层导入..."
find src/runtime -name "*.cj" -type f -exec sed -i.bak 's/import cactor\.mailbox\./import cactor.runtime.mailbox./g' {} \; 2>/dev/null || true
find src/runtime -name "*.cj" -type f -exec sed -i.bak 's/import cactor\.dispatcher\./import cactor.runtime.dispatcher./g' {} \; 2>/dev/null || true
find src/runtime -name "*.cj" -type f -exec sed -i.bak 's/import cactor\.core\.mailbox\./import cactor.runtime.mailbox./g' {} \; 2>/dev/null || true

# 修复patterns层导入
echo "修复Patterns层导入..."
find src/patterns -name "*.cj" -type f -exec sed -i.bak 's/import cactor\.pattern\./import cactor.patterns./g' {} \; 2>/dev/null || true
find src/patterns -name "*.cj" -type f -exec sed -i.bak 's/import cactor\.routing\./import cactor.patterns.routing./g' {} \; 2>/dev/null || true
find src/patterns -name "*.cj" -type f -exec sed -i.bak 's/import cactor\.circuit_breaker\./import cactor.patterns.circuit_breaker./g' {} \; 2>/dev/null || true

# 修复distribution层导入
echo "修复Distribution层导入..."
find src/distribution -name "*.cj" -type f -exec sed -i.bak 's/import cactor\.remote\./import cactor.distribution.remote./g' {} \; 2>/dev/null || true
find src/distribution -name "*.cj" -type f -exec sed -i.bak 's/import cactor\.cluster\./import cactor.distribution.cluster./g' {} \; 2>/dev/null || true
find src/distribution -name "*.cj" -type f -exec sed -i.bak 's/import cactor\.persistence\./import cactor.distribution.persistence./g' {} \; 2>/dev/null || true
find src/distribution -name "*.cj" -type f -exec sed -i.bak 's/import cactor\.stream\./import cactor.distribution.streaming./g' {} \; 2>/dev/null || true

# 修复integration层导入
echo "修复Integration层导入..."
find src/integration -name "*.cj" -type f -exec sed -i.bak 's/import cactor\.config\./import cactor.integration.configuration./g' {} \; 2>/dev/null || true
find src/integration -name "*.cj" -type f -exec sed -i.bak 's/import cactor\.monitoring\./import cactor.integration.monitoring./g' {} \; 2>/dev/null || true
find src/integration -name "*.cj" -type f -exec sed -i.bak 's/import cactor\.logging\./import cactor.integration.logging./g' {} \; 2>/dev/null || true
find src/integration -name "*.cj" -type f -exec sed -i.bak 's/import cactor\.debug\./import cactor.integration.logging./g' {} \; 2>/dev/null || true
find src/integration -name "*.cj" -type f -exec sed -i.bak 's/import cactor\.tests\./import cactor.integration.testing./g' {} \; 2>/dev/null || true

# 修复跨层导入
echo "修复跨层导入..."
find src -name "*.cj" -type f -exec sed -i.bak 's/import cactor\.memory\./import cactor.foundation.memory./g' {} \; 2>/dev/null || true
find src -name "*.cj" -type f -exec sed -i.bak 's/import cactor\.serialization\./import cactor.foundation.serialization./g' {} \; 2>/dev/null || true
find src -name "*.cj" -type f -exec sed -i.bak 's/import cactor\.network\./import cactor.foundation.network./g' {} \; 2>/dev/null || true

# 清理备份文件
echo "清理备份文件..."
find src -name "*.bak" -type f -delete 2>/dev/null || true

echo "导入路径修复完成！"
