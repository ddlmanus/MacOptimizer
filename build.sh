#!/bin/bash

# 应用卸载器 - 构建脚本
# 使用命令行工具编译 SwiftUI macOS 应用

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}    Mac优化大师 (MacOptimizer) 构建脚本${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# 设置变量
APP_NAME="Mac优化大师"
BUNDLE_NAME="${APP_NAME}.app"
BUILD_DIR="build"
SOURCE_DIR="AppUninstaller"

# 检查源文件
echo -e "${YELLOW}[1/5] 检查源文件...${NC}"
SWIFT_FILES=(
    "${SOURCE_DIR}/Models.swift"
    "${SOURCE_DIR}/LocalizationManager.swift"
    "${SOURCE_DIR}/ConcurrentScanner.swift"
    "${SOURCE_DIR}/ScanServiceManager.swift"
    "${SOURCE_DIR}/AppScanner.swift"
    "${SOURCE_DIR}/ResidualFileScanner.swift"
    "${SOURCE_DIR}/FileRemover.swift"
    "${SOURCE_DIR}/DiskSpaceManager.swift"
    "${SOURCE_DIR}/DiskUsageView.swift"
    "${SOURCE_DIR}/Styles.swift"
    "${SOURCE_DIR}/LargeFileScanner.swift"
    "${SOURCE_DIR}/LargeFileView.swift"
    "${SOURCE_DIR}/TrashView.swift"
    "${SOURCE_DIR}/DeepCleanScanner.swift"
    "${SOURCE_DIR}/DeepCleanView.swift"
    "${SOURCE_DIR}/FileExplorerService.swift"
    "${SOURCE_DIR}/FileExplorerView.swift"
    "${SOURCE_DIR}/SystemMonitorService.swift"
    "${SOURCE_DIR}/ProcessService.swift"
    "${SOURCE_DIR}/PortScannerService.swift"
    "${SOURCE_DIR}/MonitorView.swift"
    "${SOURCE_DIR}/ContentView.swift"
    "${SOURCE_DIR}/AppDetailView.swift"
    "${SOURCE_DIR}/NavigationSidebar.swift"
    "${SOURCE_DIR}/JunkCleaner.swift"
    "${SOURCE_DIR}/JunkCleanerView.swift"
    "${SOURCE_DIR}/SystemOptimizer.swift"
    "${SOURCE_DIR}/OptimizerView.swift"
    "${SOURCE_DIR}/MalwareScanner.swift"
    "${SOURCE_DIR}/MalwareView.swift"
    "${SOURCE_DIR}/PrivacyScannerService.swift"
    "${SOURCE_DIR}/PrivacyView.swift"
    "${SOURCE_DIR}/SmartCleanerService.swift"
    "${SOURCE_DIR}/CircularActionButton.swift"
    "${SOURCE_DIR}/SmartCleanerView.swift"
    "${SOURCE_DIR}/AppUninstallerApp.swift"
)

for file in "${SWIFT_FILES[@]}"; do
    if [ ! -f "$file" ]; then
        echo -e "${RED}错误: 找不到源文件 $file${NC}"
        exit 1
    fi
done
echo -e "${GREEN}✓ 所有源文件存在${NC}"

# 设置变量
APP_NAME="Mac优化大师"
EXECUTABLE_NAME="AppUninstaller"
BUNDLE_NAME="${APP_NAME}.app"
BUILD_DIR="build"
SOURCE_DIR="AppUninstaller"

# 清理旧构建
echo -e "${YELLOW}[2/5] 准备构建目录...${NC}"
rm -rf "${BUILD_DIR}"
mkdir -p "${BUILD_DIR}/${BUNDLE_NAME}/Contents/MacOS"
mkdir -p "${BUILD_DIR}/${BUNDLE_NAME}/Contents/Resources"
echo -e "${GREEN}✓ 构建目录已创建${NC}"

# 复制 Info.plist
echo -e "${YELLOW}[3/5] 复制配置文件...${NC}"
cp "${SOURCE_DIR}/Info.plist" "${BUILD_DIR}/${BUNDLE_NAME}/Contents/"

# 复制图标文件
if [ -f "${SOURCE_DIR}/AppIcon.icns" ]; then
    cp "${SOURCE_DIR}/AppIcon.icns" "${BUILD_DIR}/${BUNDLE_NAME}/Contents/Resources/"
    echo -e "${GREEN}✓ Info.plist 和 AppIcon.icns 已复制${NC}"
else
    echo -e "${GREEN}✓ Info.plist 已复制 (无图标文件)${NC}"
fi

# 编译
echo -e "${YELLOW}[4/5] 编译 Swift 源代码...${NC}"
swiftc \
    -O \
    -whole-module-optimization \
    -target x86_64-apple-macos13.0 \
    -sdk $(xcrun --sdk macosx --show-sdk-path) \
    -parse-as-library \
    -o "${BUILD_DIR}/${BUNDLE_NAME}/Contents/MacOS/${EXECUTABLE_NAME}" \
    "${SWIFT_FILES[@]}"

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ 编译成功${NC}"
else
    echo -e "${RED}✗ 编译失败${NC}"
    exit 1
fi

# 签名 (Ad-hoc)
echo -e "${YELLOW}[5/5] 签名应用...${NC}"
codesign --force --deep --sign - "${BUILD_DIR}/${BUNDLE_NAME}"
echo -e "${GREEN}✓ 签名完成${NC}"

echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}构建完成！${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "应用位置: ${YELLOW}${BUILD_DIR}/${BUNDLE_NAME}${NC}"
echo ""
echo -e "运行命令: ${YELLOW}open ${BUILD_DIR}/${BUNDLE_NAME}${NC}"
echo ""
