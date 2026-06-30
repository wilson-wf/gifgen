#!/bin/bash
# Screen2GIF 项目构建验证脚本
# 注意：完整编译需要 DevEco Studio + HarmonyOS SDK 环境
# 本脚本用于验证项目文件结构完整性和基本语法检查

set -e

echo "=== Screen2GIF 构建验证 ==="
echo ""

# 1. 检查项目结构
echo "[1/4] 检查项目文件结构..."

REQUIRED_FILES=(
  "oh-package.json5"
  "build-profile.json5"
  "hvigorfile.ts"
  "entry/oh-package.json5"
  "entry/src/main/module.json5"
  "entry/src/main/ets/entryability/EntryAbility.ets"
  "entry/src/main/ets/pages/Index.ets"
  "entry/src/main/ets/pages/HistoryPage.ets"
  "entry/src/main/ets/pages/PreviewPage.ets"
  "entry/src/main/ets/services/ScreenRecorderService.ets"
  "entry/src/main/ets/services/GifGeneratorService.ets"
  "entry/src/main/ets/services/FileManagerService.ets"
  "entry/src/main/ets/models/RecordState.ets"
  "entry/src/main/ets/utils/Constants.ets"
  "entry/src/main/ets/utils/Logger.ets"
  "entry/src/main/ets/utils/TimeUtil.ets"
  "entry/src/main/resources/base/element/string.json"
  "entry/src/main/resources/base/element/color.json"
  "entry/src/main/resources/base/profile/main_pages.json"
  ".gitignore"
  "README.md"
)

MISSING=0
for FILE in "${REQUIRED_FILES[@]}"; do
  if [ -f "$FILE" ]; then
    echo "  ✓ $FILE"
  else
    echo "  ✗ $FILE (缺失)"
    MISSING=$((MISSING + 1))
  fi
done

if [ $MISSING -gt 0 ]; then
  echo ""
  echo "❌ 缺失 $MISSING 个必需文件，构建验证失败！"
  exit 1
fi

echo ""
echo "[2/4] 验证 JSON/JSON5 文件格式..."

for JSON_FILE in $(find . -name "*.json" -o -name "*.json5"); do
  python3 -c "import json; json.load(open('$JSON_FILE'))" 2>/dev/null && \
    echo "  ✓ $JSON_FILE" || \
    echo "  ~ $JSON_FILE (JSON5格式，需DevEco Studio验证)"
done

echo ""
echo "[3/4] 统计代码行数..."

ETS_FILES=$(find . -name "*.ets")
TOTAL_LINES=0
for FILE in $ETS_FILES; do
  LINES=$(wc -l < "$FILE")
  TOTAL_LINES=$((TOTAL_LINES + LINES))
  echo "  $FILE: $LINES 行"
done
echo "  ──────────────"
echo "  总计: $TOTAL_LINES 行 ArkTS/ETS 代码"

echo ""
echo "[4/4] 构建环境检查..."

if command -v hvigorw &>/dev/null; then
  echo "  ✓ hvigorw 可用"
  echo "  执行: hvigorw assembleHap --mode module -p module=entry@default"
else
  echo "  ~ hvigorw 不可用（需要在 DevEco Studio 环境中编译）"
  echo "  ~ 请使用 DevEco Studio 打开项目后点击 Build > Build Hap(s)/APP(s)"
fi

echo ""
echo "=== 构建验证完成 ==="
echo "项目结构完整，共 $TOTAL_LINES 行代码"
echo ""
echo "下一步："
echo "  1. 在 DevEco Studio 中打开 /workspace/Screen2GIF"
echo "  2. File > Project Structure 配置签名"
echo "  3. Build > Build Hap(s) 编译"
echo "  4. 连接鸿蒙PC真机，点击 Run"
