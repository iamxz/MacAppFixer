#!/bin/bash
#
# build.sh - 在命令行直接编译 MacUnblock 应用
# 不需要打开 Xcode，直接运行此脚本即可
#
set -e

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="${PROJECT_DIR}/build"
APP_BUNDLE="${BUILD_DIR}/MacUnblock.app"
EXT_BUNDLE="${APP_BUNDLE}/Contents/PlugIns/MacUnblockAppFinderSync.appex"

echo "🏗️  开始构建 MacUnblock..."
echo "   项目目录: ${PROJECT_DIR}"
echo "   输出目录: ${BUILD_DIR}"
echo ""

# 获取 SDK 路径
SDK_PATH="$(xcrun --show-sdk-path)"

# 获取架构
ARCH=$(uname -m)
echo "   架构: ${ARCH}"
echo "   SDK: ${SDK_PATH}"
echo ""

# 清理旧构建
rm -rf "${BUILD_DIR}"
mkdir -p "${BUILD_DIR}"

# === 构建 Finder Sync Extension (MH_BUNDLE) ===
echo "📦 构建 Finder Sync Extension..."

mkdir -p "${EXT_BUNDLE}/Contents/MacOS"

# Finder Sync Extension is a loadable bundle (MH_BUNDLE)
# Use -emit-library with -Xlinker -bundle to produce a loadable bundle
xcrun swiftc \
    -target "${ARCH}-apple-macos12" \
    -sdk "${SDK_PATH}" \
    -parse-as-library \
    -module-name MacUnblockSync \
    -emit-library \
    -Xlinker -bundle \
    -o "${EXT_BUNDLE}/Contents/MacOS/MacUnblockAppFinderSync" \
    "${PROJECT_DIR}/MacUnblockAppFinderSync/SyncDelegate.swift" \
    -framework FinderSync \
    -framework AppKit \
    -framework Foundation \
    -F "${SDK_PATH}/System/Library/Frameworks" \
    -Xlinker -rpath -Xlinker @executable_path/../Frameworks \
    -Xlinker -rpath -Xlinker @executable_path/../../../../Frameworks

# 复制 Info.plist
cp "${PROJECT_DIR}/MacUnblockAppFinderSync/Info.plist" "${EXT_BUNDLE}/Contents/Info.plist"

# 设置 bundle 标识
/usr/libexec/PlistBuddy -c "Set :CFBundleExecutable MacUnblockAppFinderSync" "${EXT_BUNDLE}/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier com.macunblock.app.FinderSync" "${EXT_BUNDLE}/Contents/Info.plist"

echo "✅ Finder Sync Extension 构建完成"
echo ""

# === 构建主应用 ===
echo "📦 构建主应用 MacUnblock..."

mkdir -p "${APP_BUNDLE}/Contents/MacOS"

xcrun swiftc \
    -target "${ARCH}-apple-macos12" \
    -sdk "${SDK_PATH}" \
    -parse-as-library \
    -module-name MacUnblock \
    -emit-executable \
    -o "${APP_BUNDLE}/Contents/MacOS/MacUnblock" \
    "${PROJECT_DIR}/MacUnblockApp/AppDelegate.swift" \
    "${PROJECT_DIR}/MacUnblockApp/NSViewExtension.swift" \
    -framework AppKit \
    -framework Foundation \
    -framework ServiceManagement \
    -F "${SDK_PATH}/System/Library/Frameworks" \
    -Xlinker -rpath -Xlinker @executable_path/../Frameworks

# 复制 Info.plist
cp "${PROJECT_DIR}/MacUnblockApp/Info.plist" "${APP_BUNDLE}/Contents/Info.plist"

# 修正 Info.plist 中的可执行文件名
/usr/libexec/PlistBuddy -c "Set :CFBundleExecutable MacUnblock" "${APP_BUNDLE}/Contents/Info.plist"

echo "✅ 主应用构建完成"
echo ""

# === 签名 ===
echo "🔐 签名..."

# 签名扩展（带沙箱 entitlements）
codesign -f -s - \
    --entitlements "${PROJECT_DIR}/MacUnblockAppFinderSync/MacUnblockAppFinderSync.entitlements" \
    "${EXT_BUNDLE}"

# 签名主应用（带 entitlements）
codesign -f -s - \
    --entitlements "${PROJECT_DIR}/MacUnblockApp/MacUnblock.entitlements" \
    "${APP_BUNDLE}"

echo "✅ 签名完成"
echo ""

# === 注册 Finder Sync Extension ===
echo "📋 注册 Finder Sync Extension..."
/usr/bin/pluginkit -a "${EXT_BUNDLE}" 2>/dev/null || true

echo ""
echo "🎉 构建成功！"
echo "   应用路径: ${APP_BUNDLE}"
echo ""
echo "下一步："
echo "  1. 打开应用: open \"${APP_BUNDLE}\""
echo "  2. 在应用中点击「启用 Finder 扩展」"
echo "  3. 在系统设置中允许扩展运行"
echo "  4. 在 Finder 中右键 .app 文件即可看到「解除安装限制」选项"
