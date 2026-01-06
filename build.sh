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

# 复制 PNG 图片资源
for png_file in "${SOURCE_DIR}"/*.png; do
    if [ -f "$png_file" ]; then
        cp "$png_file" "${BUILD_DIR}/${BUNDLE_NAME}/Contents/Resources/"
    fi
done
PNG_COUNT=$(ls -1 "${SOURCE_DIR}"/*.png 2>/dev/null | wc -l | tr -d ' ')
if [ "$PNG_COUNT" -gt 0 ]; then
    echo -e "${GREEN}✓ 已复制 ${PNG_COUNT} 个 PNG 图片资源${NC}"
fi

# 复制 JPG 图片资源
for jpg_file in "${SOURCE_DIR}"/*.jpg; do
    if [ -f "$jpg_file" ]; then
        cp "$jpg_file" "${BUILD_DIR}/${BUNDLE_NAME}/Contents/Resources/"
    fi
done
JPG_COUNT=$(ls -1 "${SOURCE_DIR}"/*.jpg 2>/dev/null | wc -l | tr -d ' ')
if [ "$JPG_COUNT" -gt 0 ]; then
    echo -e "${GREEN}✓ 已复制 ${JPG_COUNT} 个 JPG 图片资源${NC}"
fi

# 复制音频资源 (m4a)
for audio_file in "${SOURCE_DIR}"/*.m4a; do
    if [ -f "$audio_file" ]; then
        cp "$audio_file" "${BUILD_DIR}/${BUNDLE_NAME}/Contents/Resources/"
    fi
done
AUDIO_COUNT=$(ls -1 "${SOURCE_DIR}"/*.m4a 2>/dev/null | wc -l | tr -d ' ')
if [ "$AUDIO_COUNT" -gt 0 ]; then
    echo -e "${GREEN}✓ 已复制 ${AUDIO_COUNT} 个音频资源${NC}"
fi

# 复制视频资源 (mp4)
for video_file in "${SOURCE_DIR}"/*.mp4; do
    if [ -f "$video_file" ]; then
        cp "$video_file" "${BUILD_DIR}/${BUNDLE_NAME}/Contents/Resources/"
    fi
done
VIDEO_COUNT=$(ls -1 "${SOURCE_DIR}"/*.mp4 2>/dev/null | wc -l | tr -d ' ')
if [ "$VIDEO_COUNT" -gt 0 ]; then
    echo -e "${GREEN}✓ 已复制 ${VIDEO_COUNT} 个视频资源${NC}"
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

# 7. 打包 DMG (带有背景图片和 Applications 快捷方式)
echo -e "${YELLOW}[6/7] 打包 DMG 安装镜像...${NC}"
DMG_PATH="${BUILD_DIR}/${DMG_NAME}"
if [ -f "${DMG_PATH}" ]; then
    rm "${DMG_PATH}"
fi

# 创建临时目录用于 DMG 内容
DMG_TEMP_DIR="${BUILD_DIR}/dmg_temp"
rm -rf "${DMG_TEMP_DIR}"
mkdir -p "${DMG_TEMP_DIR}"

# 复制应用到临时目录
cp -R "${BUILD_DIR}/${BUNDLE_NAME}" "${DMG_TEMP_DIR}/"

# 创建 Applications 文件夹的符号链接
ln -s /Applications "${DMG_TEMP_DIR}/Applications"

# 创建隐藏的背景图片目录
mkdir -p "${DMG_TEMP_DIR}/.background"
if [ -f "dmg_background.png" ]; then
    cp "dmg_background.png" "${DMG_TEMP_DIR}/.background/background.png"
    echo -e "${GREEN}✓ 背景图片已复制${NC}"
fi

# 创建临时的读写 DMG
TEMP_DMG="${BUILD_DIR}/temp_rw.dmg"
if [ -f "${TEMP_DMG}" ]; then
    rm "${TEMP_DMG}"
fi

hdiutil create \
    -volname "${APP_NAME}" \
    -srcfolder "${DMG_TEMP_DIR}" \
    -ov -format UDRW \
    "${TEMP_DMG}" > /dev/null

# 挂载 DMG 并设置窗口布局
MOUNT_DIR="/Volumes/${APP_NAME}"

# 先卸载可能已存在的同名卷
if [ -d "${MOUNT_DIR}" ]; then
    hdiutil detach "${MOUNT_DIR}" -force > /dev/null 2>&1 || true
fi

# 挂载 DMG
hdiutil attach "${TEMP_DMG}" -nobrowse -mountpoint "${MOUNT_DIR}" > /dev/null

# 使用 AppleScript 设置 Finder 窗口布局
echo -e "  - 设置窗口布局..."
osascript << EOF
tell application "Finder"
    tell disk "${APP_NAME}"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        -- 窗口大小: 660x400
        set bounds of container window to {200, 150, 860, 550}
        set theViewOptions to the icon view options of container window
        set arrangement of theViewOptions to not arranged
        set icon size of theViewOptions to 100
        set background picture of theViewOptions to file ".background:background.png"
        
        -- 设置图标位置 (垂直居中在窗口中央)
        -- 窗口高度400，图标100，所以垂直位置约 (400-100-30)/2 = 135 (考虑标题栏和文字)
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

# 确保写入完成
sync

# 卸载 DMG
hdiutil detach "${MOUNT_DIR}" > /dev/null

# 转换为只读压缩格式
hdiutil convert "${TEMP_DMG}" -format UDZO -imagekey zlib-level=9 -o "${DMG_PATH}" > /dev/null

# 清理临时文件
rm -f "${TEMP_DMG}"
rm -rf "${DMG_TEMP_DIR}"

echo -e "${GREEN}✓ DMG 打包完成 (带拖拽安装界面)${NC}"

echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}构建 & 打包全部完成！${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "应用包: ${YELLOW}${BUILD_DIR}/${BUNDLE_NAME}${NC}"
echo -e "DMG文件: ${YELLOW}${DMG_PATH}${NC}"
echo -e "  └─ ${GREEN}✓ 包含拖拽安装界面和 Applications 快捷方式${NC}"
echo ""
