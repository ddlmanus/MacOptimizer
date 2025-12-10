#!/bin/bash

# Mac优化大师 - 发布打包脚本
# 
# 功能:
# 1. 编译 Universal Binary (x86_64 + arm64)
# 2. 生成 DMG 安装包
#

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}    Mac优化大师 (MacOptimizer) 发布打包脚本${NC}"
echo -e "${BLUE}    Universal Binary & DMG Generator${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# 配置变量
APP_NAME="Mac优化大师"
EXECUTABLE_NAME="AppUninstaller"
BUNDLE_NAME="${APP_NAME}.app"
BUILD_DIR="build_release"
DMG_NAME="${APP_NAME}_Universal.dmg"
SOURCE_DIR="AppUninstaller"

# 源文件列表
SWIFT_FILES=(
    "${SOURCE_DIR}/Models.swift"
    "${SOURCE_DIR}/AppScanner.swift"
    "${SOURCE_DIR}/ResidualFileScanner.swift"
    "${SOURCE_DIR}/FileRemover.swift"
    "${SOURCE_DIR}/DiskSpaceManager.swift"
    "${SOURCE_DIR}/DiskUsageView.swift"
    "${SOURCE_DIR}/Styles.swift"
    "${SOURCE_DIR}/LargeFileScanner.swift"
    "${SOURCE_DIR}/LargeFileView.swift"
    "${SOURCE_DIR}/TrashView.swift"
    "${SOURCE_DIR}/SystemMonitorService.swift"
    "${SOURCE_DIR}/ProcessService.swift"
    "${SOURCE_DIR}/MonitorView.swift"
    "${SOURCE_DIR}/ContentView.swift"
    "${SOURCE_DIR}/AppDetailView.swift"
    "${SOURCE_DIR}/NavigationSidebar.swift"
    "${SOURCE_DIR}/JunkCleaner.swift"
    "${SOURCE_DIR}/JunkCleanerView.swift"
    "${SOURCE_DIR}/SystemOptimizer.swift"
    "${SOURCE_DIR}/OptimizerView.swift"
    "${SOURCE_DIR}/AppUninstallerApp.swift"
)

# 1. 清理环境
echo -e "${YELLOW}[1/6] 清理构建环境...${NC}"
rm -rf "${BUILD_DIR}"
mkdir -p "${BUILD_DIR}/arm64"
mkdir -p "${BUILD_DIR}/x86_64"
mkdir -p "${BUILD_DIR}/${BUNDLE_NAME}/Contents/MacOS"
mkdir -p "${BUILD_DIR}/${BUNDLE_NAME}/Contents/Resources"

# 2. 编译 ARM64 Version
echo -e "${YELLOW}[2/6] 编译 Apple Silicon (arm64) 版本...${NC}"
swiftc \
    -O -whole-module-optimization \
    -target arm64-apple-macos13.0 \
    -sdk $(xcrun --sdk macosx --show-sdk-path) \
    -parse-as-library \
    -o "${BUILD_DIR}/arm64/${EXECUTABLE_NAME}" \
    "${SWIFT_FILES[@]}"

# 3. 编译 Intel Version
echo -e "${YELLOW}[3/6] 编译 Intel (x86_64) 版本...${NC}"
swiftc \
    -O -whole-module-optimization \
    -target x86_64-apple-macos13.0 \
    -sdk $(xcrun --sdk macosx --show-sdk-path) \
    -parse-as-library \
    -o "${BUILD_DIR}/x86_64/${EXECUTABLE_NAME}" \
    "${SWIFT_FILES[@]}"

# 4. 创建 Universal Binary
echo -e "${YELLOW}[4/6] 合并为通用二进制 (Universal Binary)...${NC}"
lipo -create \
    "${BUILD_DIR}/arm64/${EXECUTABLE_NAME}" \
    "${BUILD_DIR}/x86_64/${EXECUTABLE_NAME}" \
    -output "${BUILD_DIR}/${BUNDLE_NAME}/Contents/MacOS/${EXECUTABLE_NAME}"

# 验证二进制架构
echo "架构验证:"
lipo -info "${BUILD_DIR}/${BUNDLE_NAME}/Contents/MacOS/${EXECUTABLE_NAME}"

# 复制资源文件
cp "${SOURCE_DIR}/Info.plist" "${BUILD_DIR}/${BUNDLE_NAME}/Contents/"
if [ -f "${SOURCE_DIR}/AppIcon.icns" ]; then
    cp "${SOURCE_DIR}/AppIcon.icns" "${BUILD_DIR}/${BUNDLE_NAME}/Contents/Resources/"
fi

# 5. 签名
echo -e "${YELLOW}[5/6] 签名应用包...${NC}"
codesign --force --deep --sign - "${BUILD_DIR}/${BUNDLE_NAME}"

# 6. 打包 DMG
echo -e "${YELLOW}[6/6] 生成 DMG 安装包...${NC}"
DMG_PATH="${BUILD_DIR}/${DMG_NAME}"
rm -f "${DMG_PATH}"

# 创建临时文件夹用于 DMG 内容
DMG_SRC="${BUILD_DIR}/dmg_source"
mkdir -p "${DMG_SRC}"
cp -r "${BUILD_DIR}/${BUNDLE_NAME}" "${DMG_SRC}/"
ln -s /Applications "${DMG_SRC}/Applications"

# 使用 hdiutil 创建 DMG
hdiutil create -volname "${APP_NAME}" \
    -srcfolder "${DMG_SRC}" \
    -ov -format UDZO \
    "${DMG_PATH}"

echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}发布构建完成！${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "应用路径: ${YELLOW}${BUILD_DIR}/${BUNDLE_NAME}${NC}"
echo -e "DMG 包路径: ${YELLOW}${DMG_PATH}${NC}"
echo ""
