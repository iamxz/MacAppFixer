# MacUnblock - 构建 / 安装 Makefile
#
#   make            # 只构建（产物在 build/MacUnblock.app）
#   make install    # 构建 + 安装到 /Applications + 登记 Finder 扩展
#   make run        # install 之后直接打开应用
#   make status     # 检查扩展登记状态
#   make uninstall  # 把应用移到废纸篓并注销登记
#
# 真正的构建逻辑都在 build.sh 里，这里只做一层薄封装。

APP_NAME     := MacUnblock
BUNDLE_ID    := com.macunblock.app
EXT_BUNDLE_ID := com.macunblock.app.FinderSync
PROJECT_DIR  := $(shell pwd)
BUILD_DIR    := $(PROJECT_DIR)/build
APP_BUNDLE   := $(BUILD_DIR)/$(APP_NAME).app
TARGET_APP   := /Applications/$(APP_NAME).app
EXT_BUNDLE   := $(APP_BUNDLE)/Contents/PlugIns/MacUnblockAppFinderSync.appex
LSREGISTER   := /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister

.DEFAULT_GOAL := build

.PHONY: all build install run guide clean status restart-finder uninstall help

all: build

## 只构建，不安装（产物在 build/）
build:
	@SKIP_INSTALL=1 ./build.sh

## 构建 + 安装到 /Applications + 登记并刷新 Finder 扩展
install:
	@./build.sh
	@echo ""
	@echo "👉 还差一步：打开应用点「引导设置…」按步骤开启扩展"
	@echo "   （拖拽和「选择文件…」不需要扩展，装完即可用）"

## install 之后直接打开应用
run: install
	@open "$(TARGET_APP)"

## 直接弹出「引导设置」面板（走 macunblock:// URL，应用没开也会被拉起来）
guide:
	@open "macunblock://guide" 2>/dev/null || open "$(TARGET_APP)"
	@echo "👉 已请求打开「引导设置」面板"

## 清理构建产物
clean:
	@echo "🧹 清理 $(BUILD_DIR)"
	@rm -rf "$(BUILD_DIR)"
	@echo "✅ 已清理"

## 检查应用与扩展的登记 / 运行状态
status:
	@echo "=== 应用 ==="
	@if [ -d "$(TARGET_APP)" ]; then \
		echo "  已安装: $(TARGET_APP)"; \
		echo "  主类:   $$(/usr/libexec/PlistBuddy -c 'Print :NSExtension:NSExtensionPrincipalClass' "$(TARGET_APP)/Contents/PlugIns/MacUnblockAppFinderSync.appex/Contents/Info.plist" 2>/dev/null || echo '(缺扩展)')"; \
	else \
		echo "  未安装（先执行 make install）"; \
	fi
	@echo "=== LaunchServices 登记 ==="
	@if [ -x "$(LSREGISTER)" ] && "$(LSREGISTER)" -dump 2>/dev/null | grep -q "$(EXT_BUNDLE_ID)"; then \
		echo "  ✅ 扩展已登记: $(EXT_BUNDLE_ID)"; \
	else \
		echo "  ⚠️  未查到扩展登记，执行 make install"; \
	fi
	@echo "=== 应用进程 ==="
	@pgrep -fl "$(APP_NAME).app/Contents/MacOS/$(APP_NAME)" || echo "  未运行"
	@echo "=== 扩展进程（被启用并加载后才会有）==="
	@pgrep -fl "MacUnblockAppFinderSync" || echo "  未加载 —— 需在系统设置中启用扩展后重启 Finder"

## 让 Finder 重新加载扩展（启用/更新扩展后必做）
restart-finder:
	@echo "🔄 重启 Finder..."
	@killall Finder 2>/dev/null || true
	@sleep 1
	@pgrep -fl "MacUnblockAppFinderSync" || echo "  ℹ️  扩展进程仍未出现，请确认已在系统设置中勾选 MacUnblock"

## 卸载：退出应用 → 注销登记 → 移到废纸篓（不用 rm，可恢复）
uninstall:
	@if [ ! -d "$(TARGET_APP)" ]; then \
		echo "ℹ️  $(TARGET_APP) 不存在，无需卸载"; \
		exit 0; \
	fi
	@FOUND_ID=$$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$(TARGET_APP)/Contents/Info.plist" 2>/dev/null || echo ""); \
	if [ "$$FOUND_ID" != "$(BUNDLE_ID)" ]; then \
		echo "⚠️  $(TARGET_APP) 不是 MacUnblock（bundle id: $$FOUND_ID），已中止"; \
		exit 1; \
	fi
	@echo "🚪 退出应用（如在运行）..."
	@osascript -e 'tell application "$(APP_NAME)" to quit' >/dev/null 2>&1 || true
	@pkill -x "$(APP_NAME)" >/dev/null 2>&1 || true
	@sleep 1
	@echo "🧾 注销 LaunchServices / PluginKit 登记..."
	@[ -x "$(LSREGISTER)" ] && "$(LSREGISTER)" -u "$(TARGET_APP)" >/dev/null 2>&1 || true
	@pluginkit -r "$(TARGET_APP)/Contents/PlugIns/MacUnblockAppFinderSync.appex" >/dev/null 2>&1 || true
	@echo "🗑️  移到废纸篓（可在访达里恢复）..."
	@DEST="$$HOME/.Trash/$(APP_NAME)-$$(date +%Y%m%d-%H%M%S).app"; \
	mv "$(TARGET_APP)" "$$DEST" && echo "✅ 已移到: $$DEST"
	@echo "   提示：系统设置 → 通用 → 登录项与扩展 里若仍残留条目，重启 Finder 后会自动消失"

help:
	@echo "MacUnblock Makefile"
	@echo ""
	@echo "  make              只构建（产物在 build/MacUnblock.app）"
	@echo "  make install      构建 + 安装到 /Applications + 登记扩展   ← 常用"
	@echo "  make run          install 后打开应用"
	@echo "  make guide        直接弹出「引导设置」面板"
	@echo "  make status       查看应用 / 扩展登记与运行状态"
	@echo "  make restart-finder  让 Finder 重新加载扩展"
	@echo "  make clean        清理 build/ 产物"
	@echo "  make uninstall    移到废纸篓并注销登记（可恢复）"
