#!/bin/bash

# Mac优化大师 - 双版本 DMG 打包脚本
# 
# 功能:
# 1. 编译 Apple Silicon (arm64) 版本，生成 DMG
# 2. 编译 Intel (x86_64) 版本，生成 DMG
#

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}    Mac优化大师 (MacOptimizer) 双版本打包脚本${NC}"
echo -e "${BLUE}    Apple Silicon + Intel DMG Generator${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# 配置变量
APP_NAME="Mac优化大师"
EXECUTABLE_NAME="AppUninstaller"
BUNDLE_NAME="${APP_NAME}.app"
BUILD_DIR="build_release"
SOURCE_DIR="AppUninstaller"

# DMG 文件名
DMG_ARM64="${APP_NAME}_AppleSilicon.dmg"
DMG_X86_64="${APP_NAME}_Intel.dmg"

# 源文件列表
SWIFT_FILES=(
    "${SOURCE_DIR}/Models.swift"
    "${SOURCE_DIR}/LocalizationManager.swift"
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
    "${SOURCE_DIR}/SmartCleanerView.swift"
    "${SOURCE_DIR}/AppUninstallerApp.swift"
)

# 创建单架构 DMG 的函数
create_dmg() {
    local ARCH=$1
    local TARGET=$2
    local DMG_FILE=$3
    local ARCH_NAME=$4

    echo -e "${YELLOW}编译 ${ARCH_NAME} 版本...${NC}"
    
    # 创建 App Bundle 目录
    local APP_DIR="${BUILD_DIR}/${ARCH}/${BUNDLE_NAME}"
    mkdir -p "${APP_DIR}/Contents/MacOS"
    mkdir -p "${APP_DIR}/Contents/Resources"
    
    # 编译
    swiftc \
        -O -whole-module-optimization \
        -target ${TARGET} \
        -sdk $(xcrun --sdk macosx --show-sdk-path) \
        -parse-as-library \
        -o "${APP_DIR}/Contents/MacOS/${EXECUTABLE_NAME}" \
        "${SWIFT_FILES[@]}"
    
    echo -e "${GREEN}✓ ${ARCH_NAME} 编译成功${NC}"
    
    # 复制资源文件
    cp "${SOURCE_DIR}/Info.plist" "${APP_DIR}/Contents/"
    if [ -f "${SOURCE_DIR}/AppIcon.icns" ]; then
        cp "${SOURCE_DIR}/AppIcon.icns" "${APP_DIR}/Contents/Resources/"
    fi
    
    # 签名
    echo -e "${YELLOW}签名 ${ARCH_NAME} 应用...${NC}"
    codesign --force --deep --sign - "${APP_DIR}"
    echo -e "${GREEN}✓ ${ARCH_NAME} 签名完成${NC}"
    
    # 创建 DMG
    echo -e "${YELLOW}创建 ${ARCH_NAME} DMG...${NC}"
    local DMG_SRC="${BUILD_DIR}/${ARCH}/dmg_source"
    mkdir -p "${DMG_SRC}"
    cp -r "${APP_DIR}" "${DMG_SRC}/"
    ln -sf /Applications "${DMG_SRC}/Applications"
    
    rm -f "${BUILD_DIR}/${DMG_FILE}"
    hdiutil create -volname "${APP_NAME}" \
        -srcfolder "${DMG_SRC}" \
        -ov -format UDZO \
        "${BUILD_DIR}/${DMG_FILE}"
    
    echo -e "${GREEN}✓ ${ARCH_NAME} DMG 创建成功: ${BUILD_DIR}/${DMG_FILE}${NC}"
    echo ""
}

# 1. 清理环境
echo -e "${YELLOW}[1/4] 清理构建环境...${NC}"
rm -rf "${BUILD_DIR}"
mkdir -p "${BUILD_DIR}/arm64"
mkdir -p "${BUILD_DIR}/x86_64"
echo -e "${GREEN}✓ 构建环境已清理${NC}"
echo ""

# 2. 构建 Apple Silicon (arm64) 版本
echo -e "${BLUE}[2/4] 构建 Apple Silicon (arm64) 版本${NC}"
create_dmg "arm64" "arm64-apple-macos13.0" "${DMG_ARM64}" "Apple Silicon (M芯片)"

# 3. 构建 Intel (x86_64) 版本
echo -e "${BLUE}[3/4] 构建 Intel (x86_64) 版本${NC}"
create_dmg "x86_64" "x86_64-apple-macos13.0" "${DMG_X86_64}" "Intel"

# 4. 完成
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}双版本 DMG 打包完成！${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "Apple Silicon (M芯片) 版本: ${YELLOW}${BUILD_DIR}/${DMG_ARM64}${NC}"
echo -e "Intel 版本:                 ${YELLOW}${BUILD_DIR}/${DMG_X86_64}${NC}"
echo ""
echo -e "${BLUE}文件大小:${NC}"
ls -lh "${BUILD_DIR}"/*.dmg
echo ""
