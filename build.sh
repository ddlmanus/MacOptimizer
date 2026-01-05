#!/bin/bash

# 应用卸载器 - 构建脚本
# 构建 Universal Binary (Intel + Apple Silicon) 并打包 DMG

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}    Mac优化大师 (MacOptimizer) 构建脚本${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# 1. 定义变量
APP_NAME="Mac优化大师"
EXECUTABLE_NAME="AppUninstaller"
BUNDLE_NAME="${APP_NAME}.app"
BUILD_DIR="build"
SOURCE_DIR="AppUninstaller"
DMG_NAME="${APP_NAME}.dmg"

# 2. 检查源文件
# 2. 检查源文件
echo -e "${YELLOW}[1/7] 检查源文件...${NC}"
# Use find to recursively get all .swift files
SWIFT_FILES=()
while IFS= read -r -d '' file; do
    SWIFT_FILES+=("$file")
done < <(find "${SOURCE_DIR}" -name "*.swift" -print0)

if [ ${#SWIFT_FILES[@]} -eq 0 ]; then
    echo -e "${RED}错误: 找不到源文件${NC}"
    exit 1
fi
echo -e "${GREEN}✓ 源文件检查通过 (找到 ${#SWIFT_FILES[@]} 个文件)${NC}"

# 3. 准备构建目录
echo -e "${YELLOW}[2/7] 准备构建目录...${NC}"
rm -rf "${BUILD_DIR}"
mkdir -p "${BUILD_DIR}/${BUNDLE_NAME}/Contents/MacOS"
mkdir -p "${BUILD_DIR}/${BUNDLE_NAME}/Contents/Resources"
echo -e "${GREEN}✓ 目录准备完成${NC}"

# 4. 复制资源
echo -e "${YELLOW}[3/7] 复制资源文件...${NC}"
cp "${SOURCE_DIR}/Info.plist" "${BUILD_DIR}/${BUNDLE_NAME}/Contents/"
if [ -f "${SOURCE_DIR}/AppIcon.icns" ]; then
    cp "${SOURCE_DIR}/AppIcon.icns" "${BUILD_DIR}/${BUNDLE_NAME}/Contents/Resources/"
    echo -e "${GREEN}✓ AppIcon.icns 已复制${NC}"
elif [ -f "${SOURCE_DIR}/Application.icns" ]; then
    # Use Application.icns as the main AppIcon if AppIcon.icns is missing
    cp "${SOURCE_DIR}/Application.icns" "${BUILD_DIR}/${BUNDLE_NAME}/Contents/Resources/AppIcon.icns"
    echo -e "${GREEN}✓ Application.icns 已复制为 AppIcon.icns${NC}"
else
    echo -e "${YELLOW}⚠ 警告: 未找到图标文件 (AppIcon.icns 或 Application.icns)${NC}"
fi

# Also ensure Application.icns is available for the status bar item
if [ -f "${SOURCE_DIR}/Application.icns" ]; then
    # Avoid overwriting if it was just copied above? No, cp -n or just copy again is fine/safer.
    cp "${SOURCE_DIR}/Application.icns" "${BUILD_DIR}/${BUNDLE_NAME}/Contents/Resources/Application.icns"
    echo -e "${GREEN}✓ Application.icns 已复制 (用于菜单栏)${NC}"
fi

# 5. 编译 (Apple Silicon)
echo -e "${YELLOW}[4/7] 正在编译 (Apple Silicon)...${NC}"

echo -n "  - 编译 arm64... "
swiftc -O \
    -target arm64-apple-macos13.0 \
    -sdk $(xcrun --sdk macosx --show-sdk-path) \
    -parse-as-library \
    -o "${BUILD_DIR}/${BUNDLE_NAME}/Contents/MacOS/${EXECUTABLE_NAME}" \
    "${SWIFT_FILES[@]}"
echo -e "${GREEN}OK${NC}"

# 6. 签名
echo -e "${YELLOW}[5/7] 签名应用...${NC}"
codesign --force --deep --sign - "${BUILD_DIR}/${BUNDLE_NAME}"
echo -e "${GREEN}✓ 签名完成${NC}"

# 7. 打包 DMG
echo -e "${YELLOW}[6/7] 打包 DMG 显示镜像...${NC}"
DMG_PATH="${BUILD_DIR}/${DMG_NAME}"
if [ -f "${DMG_PATH}" ]; then
    rm "${DMG_PATH}"
fi

hdiutil create \
    -volname "${APP_NAME}" \
    -srcfolder "${BUILD_DIR}/${BUNDLE_NAME}" \
    -ov -format UDZO \
    "${DMG_PATH}" > /dev/null

echo -e "${GREEN}✓ DMG 打包完成${NC}"

echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}构建 & 打包全部完成！${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "应用包: ${YELLOW}${BUILD_DIR}/${BUNDLE_NAME}${NC}"
echo -e "DMG文件: ${YELLOW}${DMG_PATH}${NC}"
echo ""
