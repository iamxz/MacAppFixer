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
    -module-name MacUnblockAppFinderSync \
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
# 主类必须带 Swift 模块前缀，且与上面的 -module-name 一致，否则扩展无法加载
/usr/libexec/PlistBuddy -c "Set :NSExtension:NSExtensionPrincipalClass MacUnblockAppFinderSync.SyncDelegate" "${EXT_BUNDLE}/Contents/Info.plist"

echo "✅ Finder Sync Extension 构建完成"
echo ""

# === 构建主应用 ===
echo "📦 构建主应用 MacUnblock..."

mkdir -p "${APP_BUNDLE}/Contents/MacOS"

xcrun swiftc \
    -target "${ARCH}-apple-macos12" \
    -sdk "${SDK_PATH}" \
    -module-name MacUnblock \
    -emit-executable \
    -o "${APP_BUNDLE}/Contents/MacOS/MacUnblock" \
    "${PROJECT_DIR}/MacUnblockApp/main.swift" \
    "${PROJECT_DIR}/MacUnblockApp/AppDelegate.swift" \
    "${PROJECT_DIR}/MacUnblockApp/SetupGuide.swift" \
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

# 复制应用图标（.icns）
mkdir -p "${APP_BUNDLE}/Contents/Resources"
cp "${PROJECT_DIR}/MacUnblockApp/AppIcon.icns" "${APP_BUNDLE}/Contents/Resources/AppIcon.icns"
/usr/libexec/PlistBuddy -c "Add :CFBundleIconFile string AppIcon" "${APP_BUNDLE}/Contents/Info.plist" 2>/dev/null \
    || /usr/libexec/PlistBuddy -c "Set :CFBundleIconFile AppIcon" "${APP_BUNDLE}/Contents/Info.plist"

echo "✅ 主应用构建完成"
echo ""

# === 签名 ===
echo "🔐 签名..."

# 签名扩展（必须保持 App Sandbox）
# 注意：沙箱进程无法写 com.apple.quarantine，扩展只负责把请求转发给主应用
codesign -f -s - \
    --force-library-entitlements \
    --entitlements "${PROJECT_DIR}/MacUnblockAppFinderSync/MacUnblockAppFinderSync.entitlements" \
    "${EXT_BUNDLE}"

# 签名主应用（不带沙箱，否则无法移除隔离属性）
codesign -f -s - \
    --entitlements "${PROJECT_DIR}/MacUnblockApp/MacUnblock.entitlements" \
    "${APP_BUNDLE}"

codesign --verify --deep --strict "${APP_BUNDLE}" && echo "✅ 签名校验通过"
echo ""

# === 安装到 /Applications ===
# Finder 扩展只有在系统能发现应用时才会被登记，放到「应用程序」目录最稳妥
TARGET_APP="/Applications/MacUnblock.app"
LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"

if [ "${SKIP_INSTALL}" = "1" ]; then
    echo "⏭️  已跳过安装（SKIP_INSTALL=1），产物位于 ${APP_BUNDLE}"

    # 只登记 build/ 里这一份
    [ -x "${LSREGISTER}" ] && "${LSREGISTER}" -f "${APP_BUNDLE}" >/dev/null 2>&1 || true
    /usr/bin/pluginkit -a "${EXT_BUNDLE}" 2>/dev/null || true
else
    echo "📥 安装到 ${TARGET_APP}..."

    if [ -d "${TARGET_APP}" ]; then
        OLD_ID=$(/usr/libexec/PlistBuddy -c "Print :CFBundleIdentifier" "${TARGET_APP}/Contents/Info.plist" 2>/dev/null || echo "")
        if [ "${OLD_ID}" = "com.macunblock.app" ]; then
            osascript -e 'tell application "MacUnblock" to quit' >/dev/null 2>&1 || true
            pkill -x MacUnblock >/dev/null 2>&1 || true
            sleep 1
            echo "   替换旧版本：${TARGET_APP}"
            rm -rf "${TARGET_APP}"
        else
            echo "⚠️  ${TARGET_APP} 已存在且不是本应用，跳过安装"
        fi
    fi

    ditto "${APP_BUNDLE}" "${TARGET_APP}"

    # 关键：同一 bundle id 只能登记一份。
    # build/ 与 /Applications/ 两份同时被 LaunchServices 认识时，扩展解析会变得不确定，
    # Finder 有可能挑中构建目录里那份而拒绝加载，因此这里把构建目录那份注销掉。
    [ -x "${LSREGISTER}" ] && "${LSREGISTER}" -u "${APP_BUNDLE}" >/dev/null 2>&1 || true

    # 让系统重新扫描应用与扩展
    if [ -x "${LSREGISTER}" ]; then
        "${LSREGISTER}" -f "${TARGET_APP}" >/dev/null 2>&1 || true
        "${LSREGISTER}" -f "${TARGET_APP}/Contents/PlugIns/MacUnblockAppFinderSync.appex" >/dev/null 2>&1 || true
    fi
    /usr/bin/pluginkit -a "${TARGET_APP}/Contents/PlugIns/MacUnblockAppFinderSync.appex" 2>/dev/null || true

    echo "✅ 已安装: ${TARGET_APP}"
fi

echo ""
echo "🎉 构建完成！"
echo ""
echo "下一步："
echo "  1. 打开应用: open \"${TARGET_APP}\""
echo "  2. 拖拽 / 点击「选择文件」按钮解除限制"
echo "  3. Finder 右键菜单需要在「系统设置 → 通用 → 登录项与扩展 → 文件提供程序/Finder 扩展」中开启 MacUnblock"

