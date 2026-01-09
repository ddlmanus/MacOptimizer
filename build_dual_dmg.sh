#!/bin/bash

# Mac优化大师 4.0.0 - 双架构 DMG 打包脚本
# 构建 Apple Silicon 和 Intel 版本的 DMG

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}    Mac优化大师 v4.0.0 双架构打包脚本${NC}"
echo -e "${BLUE}    Apple Silicon + Intel DMG Generator${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# 定义变量
APP_NAME="Mac优化大师"
EXECUTABLE_NAME="AppUninstaller"
BUNDLE_NAME="${APP_NAME}.app"
BUILD_DIR="build_release"
SOURCE_DIR="AppUninstaller"
VERSION="4.0.1"

# DMG 文件名
DMG_ARM64="${APP_NAME}_v${VERSION}_AppleSilicon.dmg"
DMG_X86_64="${APP_NAME}_v${VERSION}_Intel.dmg"

# 1. 检查源文件
echo -e "${YELLOW}[1/5] 检查源文件...${NC}"
SWIFT_FILES=()
while IFS= read -r -d '' file; do
    SWIFT_FILES+=("$file")
done < <(find "${SOURCE_DIR}" -name "*.swift" -print0)

if [ ${#SWIFT_FILES[@]} -eq 0 ]; then
    echo -e "${RED}错误: 找不到源文件${NC}"
    exit 1
fi
echo -e "${GREEN}✓ 源文件检查通过 (找到 ${#SWIFT_FILES[@]} 个文件)${NC}"
echo ""

# 2. 准备构建目录
echo -e "${YELLOW}[2/5] 准备构建环境...${NC}"
rm -rf "${BUILD_DIR}"
mkdir -p "${BUILD_DIR}/arm64"
mkdir -p "${BUILD_DIR}/x86_64"
echo -e "${GREEN}✓ 构建环境已准备${NC}"
echo ""

# 函数: 构建单架构版本
build_architecture() {
    local ARCH=$1
    local TARGET=$2
    local ARCH_NAME=$3
    
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}构建 ${ARCH_NAME} 版本${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    local APP_DIR="${BUILD_DIR}/${ARCH}/${BUNDLE_NAME}"
    
    # a) 创建 App Bundle 目录
    echo -e "${YELLOW}  准备目录结构...${NC}"
    mkdir -p "${APP_DIR}/Contents/MacOS"
    mkdir -p "${APP_DIR}/Contents/Resources"
    echo -e "${GREEN}  ✓ 目录结构完成${NC}"
    
    # b) 复制资源文件
    echo -e "${YELLOW}  复制资源文件...${NC}"
    cp "${SOURCE_DIR}/Info.plist" "${APP_DIR}/Contents/"
    
    # 复制图标
    if [ -f "${SOURCE_DIR}/AppIcon.icns" ]; then
        cp "${SOURCE_DIR}/AppIcon.icns" "${APP_DIR}/Contents/Resources/"
        echo -e "${GREEN}  ✓ AppIcon.icns 已复制${NC}"
    elif [ -f "${SOURCE_DIR}/Application.icns" ]; then
        cp "${SOURCE_DIR}/Application.icns" "${APP_DIR}/Contents/Resources/AppIcon.icns"
        echo -e "${GREEN}  ✓ Application.icns 已复制为 AppIcon.icns${NC}"
    fi
    
    # 复制 Application.icns (菜单栏图标)
    if [ -f "${SOURCE_DIR}/Application.icns" ]; then
        cp "${SOURCE_DIR}/Application.icns" "${APP_DIR}/Contents/Resources/Application.icns"
        echo -e "${GREEN}  ✓ Application.icns 已复制 (用于菜单栏)${NC}"
    fi
    
    # 复制 PNG 图片
    for png_file in "${SOURCE_DIR}"/*.png; do
        if [ -f "$png_file" ]; then
            cp "$png_file" "${APP_DIR}/Contents/Resources/"
        fi
    done
    PNG_COUNT=$(ls -1 "${SOURCE_DIR}"/*.png 2>/dev/null | wc -l | tr -d ' ')
    if [ "$PNG_COUNT" -gt 0 ]; then
        echo -e "${GREEN}  ✓ 已复制 ${PNG_COUNT} 个 PNG 图片资源${NC}"
    fi
    
    # 复制 JPG 图片
    for jpg_file in "${SOURCE_DIR}"/*.jpg; do
        if [ -f "$jpg_file" ]; then
            cp "$jpg_file" "${APP_DIR}/Contents/Resources/"
        fi
    done
    JPG_COUNT=$(ls -1 "${SOURCE_DIR}"/*.jpg 2>/dev/null | wc -l | tr -d ' ')
    if [ "$JPG_COUNT" -gt 0 ]; then
        echo -e "${GREEN}  ✓ 已复制 ${JPG_COUNT} 个 JPG 图片资源${NC}"
    fi
    
    # 复制音频资源
    for audio_file in "${SOURCE_DIR}"/*.m4a; do
        if [ -f "$audio_file" ]; then
            cp "$audio_file" "${APP_DIR}/Contents/Resources/"
        fi
    done
    AUDIO_COUNT=$(ls -1 "${SOURCE_DIR}"/*.m4a 2>/dev/null | wc -l | tr -d ' ')
    if [ "$AUDIO_COUNT" -gt 0 ]; then
        echo -e "${GREEN}  ✓ 已复制 ${AUDIO_COUNT} 个音频资源${NC}"
    fi
    
    # 复制视频资源
    for video_file in "${SOURCE_DIR}"/*.mp4; do
        if [ -f "$video_file" ]; then
            cp "$video_file" "${APP_DIR}/Contents/Resources/"
        fi
    done
    VIDEO_COUNT=$(ls -1 "${SOURCE_DIR}"/*.mp4 2>/dev/null | wc -l | tr -d ' ')
    if [ "$VIDEO_COUNT" -gt 0 ]; then
        echo -e "${GREEN}  ✓ 已复制 ${VIDEO_COUNT} 个视频资源${NC}"
    fi
    
    # c) 编译
    echo -e "${YELLOW}  编译 ${ARCH_NAME}...${NC}"
    echo -n "    "
    swiftc -O \
        -target ${TARGET} \
        -sdk $(xcrun --sdk macosx --show-sdk-path) \
        -parse-as-library \
        -o "${APP_DIR}/Contents/MacOS/${EXECUTABLE_NAME}" \
        "${SWIFT_FILES[@]}"
    echo -e "${GREEN}OK${NC}"
    
    # d) 签名
    echo -e "${YELLOW}  签名应用...${NC}"
    codesign --force --deep --sign - "${APP_DIR}" > /dev/null 2>&1
    echo -e "${GREEN}  ✓ 签名完成${NC}"
    
    echo -e "${GREEN}✓ ${ARCH_NAME} 应用构建完成${NC}"
    echo ""
}

# 函数: 创建 DMG
create_dmg() {
    local ARCH=$1
    local DMG_FILE=$2
    local ARCH_NAME=$3
    
    echo -e "${YELLOW}打包 ${ARCH_NAME} DMG...${NC}"
    
    local APP_DIR="${BUILD_DIR}/${ARCH}/${BUNDLE_NAME}"
    local DMG_TEMP_DIR="${BUILD_DIR}/${ARCH}/dmg_temp"
    local DMG_PATH="${BUILD_DIR}/${DMG_FILE}"
    
    # 准备 DMG 内容
    rm -rf "${DMG_TEMP_DIR}"
    mkdir -p "${DMG_TEMP_DIR}"
    cp -R "${APP_DIR}" "${DMG_TEMP_DIR}/"
    ln -s /Applications "${DMG_TEMP_DIR}/Applications"
    
    # 复制背景图片
    mkdir -p "${DMG_TEMP_DIR}/.background"
    if [ -f "dmg_background.png" ]; then
        cp "dmg_background.png" "${DMG_TEMP_DIR}/.background/background.png"
        echo -e "${GREEN}  ✓ 背景图片已复制${NC}"
    fi
    
    # 创建临时 DMG
    TEMP_DMG="${BUILD_DIR}/${ARCH}/temp_rw.dmg"
    rm -f "${TEMP_DMG}"
    
    hdiutil create \
        -volname "${APP_NAME}" \
        -srcfolder "${DMG_TEMP_DIR}" \
        -ov -format UDRW \
        "${TEMP_DMG}" > /dev/null
    
    # 挂载并设置布局
    MOUNT_DIR="/Volumes/${APP_NAME}"
    
    # 卸载可能存在的卷
    if [ -d "${MOUNT_DIR}" ]; then
        hdiutil detach "${MOUNT_DIR}" -force > /dev/null 2>&1 || true
    fi
    
    hdiutil attach "${TEMP_DMG}" -nobrowse -mountpoint "${MOUNT_DIR}" > /dev/null
    
    echo -e "  ${YELLOW}设置窗口布局...${NC}"
    osascript <<EOF > /dev/null 2>&1
tell application "Finder"
    tell disk "${APP_NAME}"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set bounds of container window to {200, 150, 860, 550}
        set theViewOptions to the icon view options of container window
        set arrangement of theViewOptions to not arranged
        set icon size of theViewOptions to 100
        set background picture of theViewOptions to file ".background:background.png"
        set position of item "${BUNDLE_NAME}" of container window to {140, 180}
        set position of item "Applications" of container window to {500, 180}
        close
        open
        update without registering applications
        delay 1
        close
    end tell
end tell
EOF
    
    sync
    hdiutil detach "${MOUNT_DIR}" > /dev/null
    
    # 转换为压缩 DMG
    rm -f "${DMG_PATH}"
    hdiutil convert "${TEMP_DMG}" -format UDZO -imagekey zlib-level=9 -o "${DMG_PATH}" > /dev/null
    
    # 清理
    rm -f "${TEMP_DMG}"
    rm -rf "${DMG_TEMP_DIR}"
    
    echo -e "${GREEN}  ✓ DMG 打包完成${NC}"
    echo ""
}

# 3. 构建 Apple Silicon 版本
echo -e "${YELLOW}[3/5] 构建 Apple Silicon (arm64) 版本${NC}"
echo ""
build_architecture "arm64" "arm64-apple-macos13.0" "Apple Silicon (M芯片)"

# 4. 构建 Intel 版本
echo -e "${YELLOW}[4/5] 构建 Intel (x86_64) 版本${NC}"
echo ""
build_architecture "x86_64" "x86_64-apple-macos13.0" "Intel"

# 5. 创建 DMG
echo -e "${YELLOW}[5/5] 打包 DMG 镜像${NC}"
echo ""
echo -e "${BLUE}━━ Apple Silicon DMG ━━${NC}"
create_dmg "arm64" "${DMG_ARM64}" "Apple Silicon"
echo -e "${BLUE}━━ Intel DMG ━━${NC}"
create_dmg "x86_64" "${DMG_X86_64}" "Intel"

# 完成
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}双架构 DMG 打包全部完成！${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "版本: ${YELLOW}v${VERSION}${NC}"
echo ""
echo -e "Apple Silicon (M芯片): ${YELLOW}${BUILD_DIR}/${DMG_ARM64}${NC}"
echo -e "Intel 版本:             ${YELLOW}${BUILD_DIR}/${DMG_X86_64}${NC}"
echo ""
echo -e "${BLUE}文件大小:${NC}"
ls -lh "${BUILD_DIR}"/*.dmg 2>/dev/null || true
echo ""
echo -e "${GREEN}✓ 两个版本均包含拖拽安装界面和 Applications 快捷方式${NC}"
echo ""
