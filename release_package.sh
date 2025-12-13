#!/bin/bash

# Mac优化大师 - 发布打包脚本 v3.0.0
# 
# 功能:
# 1. 分别编译 Intel (x86_64) 和 Apple Silicon (arm64) 版本
# 2. 生成两个独立的 DMG 安装包
#

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

VERSION="3.0.0"

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}    Mac优化大师 (MacOptimizer) v${VERSION}${NC}"
echo -e "${BLUE}    Intel & Apple Silicon DMG Generator${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# 配置变量
APP_NAME="Mac优化大师"
EXECUTABLE_NAME="AppUninstaller"
BUNDLE_NAME="${APP_NAME}.app"
BUILD_DIR="build_release"
SOURCE_DIR="AppUninstaller"

# 源文件列表 (与 build.sh 保持一致)
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
    "${SOURCE_DIR}/LargeFileDetailsSplitView.swift"
    "${SOURCE_DIR}/TrashView.swift"
    "${SOURCE_DIR}/DeepCleanScanner.swift"
    "${SOURCE_DIR}/DeepCleanView.swift"
    "${SOURCE_DIR}/TrashDetailsSplitView.swift"
    "${SOURCE_DIR}/FileExplorerService.swift"
    "${SOURCE_DIR}/FileExplorerView.swift"
    "${SOURCE_DIR}/SystemMonitorService.swift"
    "${SOURCE_DIR}/ProcessService.swift"
    "${SOURCE_DIR}/PortScannerService.swift"
    "${SOURCE_DIR}/MonitorView.swift"
    "${SOURCE_DIR}/ContentView.swift"
    "${SOURCE_DIR}/AppDetailView.swift"
    "${SOURCE_DIR}/AppUninstallerView.swift"
    "${SOURCE_DIR}/NavigationSidebar.swift"
    "${SOURCE_DIR}/JunkCleaner.swift"
    "${SOURCE_DIR}/JunkCleanerView.swift"
    "${SOURCE_DIR}/SystemOptimizer.swift"
    "${SOURCE_DIR}/MaintenanceView.swift"
    "${SOURCE_DIR}/MalwareScanner.swift"
    "${SOURCE_DIR}/MalwareView.swift"
    "${SOURCE_DIR}/PrivacyScannerService.swift"
    "${SOURCE_DIR}/PrivacyView.swift"
    "${SOURCE_DIR}/SmartCleanerService.swift"
    "${SOURCE_DIR}/CircularActionButton.swift"
    "${SOURCE_DIR}/SmartCleanerView.swift"
    "${SOURCE_DIR}/AppUninstallerApp.swift"
)

# 创建 App Bundle 的函数
create_app_bundle() {
    local ARCH=$1
    local OUTPUT_DIR=$2
    
    mkdir -p "${OUTPUT_DIR}/${BUNDLE_NAME}/Contents/MacOS"
    mkdir -p "${OUTPUT_DIR}/${BUNDLE_NAME}/Contents/Resources"
    
    # 复制二进制文件
    cp "${BUILD_DIR}/${ARCH}/${EXECUTABLE_NAME}" "${OUTPUT_DIR}/${BUNDLE_NAME}/Contents/MacOS/"
    
    # 复制资源文件
    cp "${SOURCE_DIR}/Info.plist" "${OUTPUT_DIR}/${BUNDLE_NAME}/Contents/"
    if [ -f "${SOURCE_DIR}/AppIcon.icns" ]; then
        cp "${SOURCE_DIR}/AppIcon.icns" "${OUTPUT_DIR}/${BUNDLE_NAME}/Contents/Resources/"
    fi
    
    # 签名
    codesign --force --deep --sign - "${OUTPUT_DIR}/${BUNDLE_NAME}"
}

# 创建 DMG 的函数
create_dmg() {
    local ARCH=$1
    local SOURCE_APP=$2
    local OUTPUT_PATH=$3
    
    # 创建临时文件夹
    local DMG_SRC="${BUILD_DIR}/dmg_${ARCH}"
    rm -rf "${DMG_SRC}"
    mkdir -p "${DMG_SRC}"
    
    # 复制 App 和创建 Applications 链接
    cp -r "${SOURCE_APP}" "${DMG_SRC}/"
    ln -s /Applications "${DMG_SRC}/Applications"
    
    # 创建 DMG
    rm -f "${OUTPUT_PATH}"
    hdiutil create -volname "${APP_NAME}" \
        -srcfolder "${DMG_SRC}" \
        -ov -format UDZO \
        "${OUTPUT_PATH}"
    
    # 清理
    rm -rf "${DMG_SRC}"
}

# 1. 清理环境
echo -e "${YELLOW}[1/7] 清理构建环境...${NC}"
rm -rf "${BUILD_DIR}"
mkdir -p "${BUILD_DIR}/arm64"
mkdir -p "${BUILD_DIR}/x86_64"
mkdir -p "${BUILD_DIR}/app_arm64"
mkdir -p "${BUILD_DIR}/app_x86_64"

# 2. 编译 ARM64 (Apple Silicon) 版本
echo -e "${YELLOW}[2/7] 编译 Apple Silicon (arm64) 版本...${NC}"
swiftc \
    -O -whole-module-optimization \
    -target arm64-apple-macos13.0 \
    -sdk $(xcrun --sdk macosx --show-sdk-path) \
    -parse-as-library \
    -o "${BUILD_DIR}/arm64/${EXECUTABLE_NAME}" \
    "${SWIFT_FILES[@]}"
echo -e "${GREEN}✓ Apple Silicon 编译完成${NC}"

# 3. 编译 Intel (x86_64) 版本
echo -e "${YELLOW}[3/7] 编译 Intel (x86_64) 版本...${NC}"
swiftc \
    -O -whole-module-optimization \
    -target x86_64-apple-macos13.0 \
    -sdk $(xcrun --sdk macosx --show-sdk-path) \
    -parse-as-library \
    -o "${BUILD_DIR}/x86_64/${EXECUTABLE_NAME}" \
    "${SWIFT_FILES[@]}"
echo -e "${GREEN}✓ Intel 编译完成${NC}"

# 4. 创建 ARM64 App Bundle
echo -e "${YELLOW}[4/7] 创建 Apple Silicon App Bundle...${NC}"
create_app_bundle "arm64" "${BUILD_DIR}/app_arm64"
echo -e "${GREEN}✓ Apple Silicon App Bundle 创建完成${NC}"

# 5. 创建 Intel App Bundle
echo -e "${YELLOW}[5/7] 创建 Intel App Bundle...${NC}"
create_app_bundle "x86_64" "${BUILD_DIR}/app_x86_64"
echo -e "${GREEN}✓ Intel App Bundle 创建完成${NC}"

# 6. 生成 ARM64 DMG
echo -e "${YELLOW}[6/7] 生成 Apple Silicon DMG...${NC}"
ARM64_DMG="${BUILD_DIR}/${APP_NAME}_v${VERSION}_AppleSilicon.dmg"
create_dmg "arm64" "${BUILD_DIR}/app_arm64/${BUNDLE_NAME}" "${ARM64_DMG}"
echo -e "${GREEN}✓ Apple Silicon DMG 生成完成${NC}"

# 7. 生成 Intel DMG
echo -e "${YELLOW}[7/7] 生成 Intel DMG...${NC}"
INTEL_DMG="${BUILD_DIR}/${APP_NAME}_v${VERSION}_Intel.dmg"
create_dmg "x86_64" "${BUILD_DIR}/app_x86_64/${BUNDLE_NAME}" "${INTEL_DMG}"
echo -e "${GREEN}✓ Intel DMG 生成完成${NC}"

echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}发布构建完成！${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "版本: ${YELLOW}v${VERSION}${NC}"
echo ""
echo -e "生成的 DMG 文件:"
echo -e "  Apple Silicon (M1/M2/M3): ${YELLOW}${ARM64_DMG}${NC}"
echo -e "  Intel (x86_64):           ${YELLOW}${INTEL_DMG}${NC}"
echo ""
echo -e "文件大小:"
ls -lh "${ARM64_DMG}" | awk '{print "  Apple Silicon: " $5}'
ls -lh "${INTEL_DMG}" | awk '{print "  Intel:         " $5}'
echo ""
