# MacAppFixer - 构建 / 安装 / 发版 Makefile
#
#   make / make build   # 编译 + 组装成 build/MacAppFixer.app（本机架构）
#   make universal      # 通用架构（arm64 + x86_64）组装 .app
#   make test           # 运行单元测试（swift test）
#   make install        # 组装 + 安装到 /Applications
#   make run            # install 之后直接打开应用
#   make status         # 查看安装与运行状态
#   make uninstall      # 移到废纸篓并注销登记（可恢复）
#   make clean          # 清理 .build / build
#   make pkg            # 通用架构编译 + 打成 build/MacAppFixer-<版本>.pkg
#   make dist           # pkg + .app.zip + checksums.txt（CI 发版用）
#   make release        # 发版：VERSION=<x.y.z|patch|minor|major> [MSG="..."] [NOTES="..."]
#
# 构建基于 Swift Package Manager（见 Package.swift）：`swift build` 产出可执行文件，
# 再由 assemble 组装成 .app —— Info.plist / 图标 / 本地化 / entitlements 全部来自 Resources/。

APP_NAME     := MacAppFixer
BUNDLE_ID    := com.macappfixer.app
BUILD_DIR    := $(CURDIR)/build
APP_BUNDLE   := $(BUILD_DIR)/$(APP_NAME).app
TARGET_APP   := /Applications/$(APP_NAME).app
PLIST        := Resources/Info.plist
ICNS         := Resources/$(APP_NAME).icns
ENTITLEMENTS := Resources/$(APP_NAME).entitlements
LSREGISTER   := /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister

PKG_VERSION  := $(shell /usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' $(PLIST) 2>/dev/null)
PKG_ROOT     := $(BUILD_DIR)/pkgroot
PKG_OUT      := $(BUILD_DIR)/$(APP_NAME)-$(PKG_VERSION).pkg
ZIP_OUT      := $(BUILD_DIR)/$(APP_NAME)-$(PKG_VERSION).app.zip
UNIVERSAL    := --arch arm64 --arch x86_64
# 透传给 swift build / swift test 的附加参数。
# 例：在无法执行 sandbox-exec 的受限环境（部分 CI / 容器 / 沙箱内）：
#   make build SWIFT_FLAGS=--disable-sandbox
SWIFT_FLAGS  ?=

.DEFAULT_GOAL := build

.PHONY: all build app test universal assemble install run clean status uninstall pkg dist verify-version release help

all: build

## 编译 + 组装成本机架构的 .app（产物在 build/MacAppFixer.app）
build: app

## 编译 + 组装 .app（ARCHS 留空 = 本机架构）
app:
	@$(MAKE) assemble ARCHS=

## 通用架构（arm64 + x86_64）的 .app
universal:
	@$(MAKE) assemble ARCHS="$(UNIVERSAL)"

## 运行单元测试
test:
	@swift test $(SWIFT_FLAGS)

## 组装 .app：swift build 产物 + Resources/ 里的 plist / 图标 / 本地化 / entitlements
assemble:
	swift build $(SWIFT_FLAGS) -c release $(ARCHS)
	rm -rf "$(APP_BUNDLE)"
	mkdir -p "$(APP_BUNDLE)/Contents/MacOS"
	mkdir -p "$(APP_BUNDLE)/Contents/Resources"
	cp "$$(swift build $(SWIFT_FLAGS) -c release $(ARCHS) --show-bin-path)/$(APP_NAME)" "$(APP_BUNDLE)/Contents/MacOS/$(APP_NAME)"
	cp "$(PLIST)" "$(APP_BUNDLE)/Contents/Info.plist"
	cp "$(ICNS)" "$(APP_BUNDLE)/Contents/Resources/$(APP_NAME).icns"
	for lproj in Resources/*.lproj; do \
		[ -d "$$lproj" ] || continue; \
		ditto "$$lproj" "$(APP_BUNDLE)/Contents/Resources/$$(basename $$lproj)"; \
	done
	for qr in screenshots/wechat.jpg screenshots/alipay.jpg; do \
		[ -f "$$qr" ] && cp "$$qr" "$(APP_BUNDLE)/Contents/Resources/$$(basename $$qr)" || true; \
	done
	codesign --force --sign - --entitlements "$(ENTITLEMENTS)" "$(APP_BUNDLE)"
	codesign --verify --deep --strict "$(APP_BUNDLE)" && echo "✅ 签名校验通过"
	@echo "Built $(APP_BUNDLE)"

## 组装 + 安装到 /Applications
install: app
	@echo "📥 安装到 $(TARGET_APP)..."
	@if [ -d "$(TARGET_APP)" ]; then \
		OLD_ID=$$(/usr/libexec/PlistBuddy -c "Print :CFBundleIdentifier" "$(TARGET_APP)/Contents/Info.plist" 2>/dev/null || echo ""); \
		if [ "$$OLD_ID" = "$(BUNDLE_ID)" ]; then \
			osascript -e 'tell application "$(APP_NAME)" to quit' >/dev/null 2>&1 || true; \
			pkill -x "$(APP_NAME)" >/dev/null 2>&1 || true; \
			sleep 1; \
			echo "   替换旧版本：$(TARGET_APP)"; \
			rm -rf "$(TARGET_APP)"; \
		else \
			echo "⚠️  $(TARGET_APP) 已存在且不是本应用，已中止"; exit 1; \
		fi; \
	fi
	@ditto "$(APP_BUNDLE)" "$(TARGET_APP)"
	@[ -x "$(LSREGISTER)" ] && "$(LSREGISTER)" -u "$(APP_BUNDLE)" >/dev/null 2>&1 || true
	@[ -x "$(LSREGISTER)" ] && "$(LSREGISTER)" -f "$(TARGET_APP)" >/dev/null 2>&1 || true
	@echo "✅ 已安装: $(TARGET_APP)"

## install 之后直接打开应用
run: install
	@open "$(TARGET_APP)"

## 清理构建产物
clean:
	@echo "🧹 清理 .build / $(BUILD_DIR)"
	@rm -rf .build "$(BUILD_DIR)"
	@echo "✅ 已清理"

## 查看安装 / 运行状态
status:
	@echo "=== 应用 ==="
	@if [ -d "$(TARGET_APP)" ]; then \
		echo "  已安装: $(TARGET_APP)"; \
		echo "  Bundle ID: $$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$(TARGET_APP)/Contents/Info.plist" 2>/dev/null || echo '?')"; \
		echo "  版本: $$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$(TARGET_APP)/Contents/Info.plist" 2>/dev/null || echo '?')"; \
	else \
		echo "  未安装（先执行 make install）"; \
	fi
	@echo "=== 应用进程 ==="
	@pgrep -fl "$(APP_NAME).app/Contents/MacOS/$(APP_NAME)" || echo "  未运行"

## 卸载：退出应用 → 注销登记 → 移到废纸篓（不用 rm，可恢复）
uninstall:
	@if [ ! -d "$(TARGET_APP)" ]; then \
		echo "ℹ️  $(TARGET_APP) 不存在，无需卸载"; \
		exit 0; \
	fi
	@FOUND_ID=$$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$(TARGET_APP)/Contents/Info.plist" 2>/dev/null || echo ""); \
	if [ "$$FOUND_ID" != "$(BUNDLE_ID)" ]; then \
		echo "⚠️  $(TARGET_APP) 不是 MacAppFixer（bundle id: $$FOUND_ID），已中止"; \
		exit 1; \
	fi
	@echo "🚪 退出应用（如在运行）..."
	@osascript -e 'tell application "$(APP_NAME)" to quit' >/dev/null 2>&1 || true
	@pkill -x "$(APP_NAME)" >/dev/null 2>&1 || true
	@sleep 1
	@echo "🧾 注销 LaunchServices 登记..."
	@[ -x "$(LSREGISTER)" ] && "$(LSREGISTER)" -u "$(TARGET_APP)" >/dev/null 2>&1 || true
	@echo "🗑️  移到废纸篓（可在访达里恢复）..."
	@DEST="$$HOME/.Trash/$(APP_NAME)-$$(date +%Y%m%d-%H%M%S).app"; \
	mv "$(TARGET_APP)" "$$DEST" && echo "✅ 已移到: $$DEST"

## 通用架构编译 + 打成 .pkg 安装包（双击装到 /Applications/MacAppFixer.app）
pkg:
	test -n "$(PKG_VERSION)"
	@$(MAKE) assemble ARCHS="$(UNIVERSAL)"
	@rm -rf "$(PKG_ROOT)"
	@mkdir -p "$(PKG_ROOT)/Applications"
	@ditto "$(APP_BUNDLE)" "$(PKG_ROOT)/Applications/$(APP_NAME).app"
	pkgbuild --root "$(PKG_ROOT)" \
	         --identifier "$(BUNDLE_ID)" \
	         --version "$(PKG_VERSION)" \
	         --install-location / \
	         "$(PKG_OUT)"
	@echo "Built $(PKG_OUT)"

## 发版产物：.pkg + .app.zip + checksums.txt
dist: pkg
	@ditto -c -k --keepParent "$(APP_BUNDLE)" "$(ZIP_OUT)"
	@shasum -a 256 "$(PKG_OUT)" "$(ZIP_OUT)" > "$(BUILD_DIR)/checksums.txt"
	@echo "Built $(ZIP_OUT) and $(BUILD_DIR)/checksums.txt"

## 校验 Info.plist 版本号与 tag 一致（CI 发版前调用）：make verify-version TAG=v1.0.0
verify-version:
	test -n "$(TAG)"
	@[ "$(PKG_VERSION)" = "$(patsubst v%,%,$(TAG))" ] || (echo "version mismatch: Info.plist $(PKG_VERSION) vs TAG $(TAG)" >&2; exit 1)
	@echo "version ok: $(PKG_VERSION) == $(TAG)"

## 发版：make release VERSION=<x.y.z|patch|minor|major> [MSG="提交信息"] [NOTES="更新说明" | NOTES_FILE=<路径>]
release:
	@NOTES='$(NOTES)' NOTES_FILE='$(NOTES_FILE)' scripts/release.sh '$(VERSION)' '$(MSG)'

help:
	@echo "MacAppFixer Makefile（Swift Package Manager）"
	@echo ""
	@echo "  make / make build  编译 + 组装 .app（产物在 build/MacAppFixer.app）"
	@echo "  make universal     通用架构（arm64 + x86_64）的 .app"
	@echo "  make test          运行单元测试"
	@echo "  make install       组装 + 安装到 /Applications   ← 常用"
	@echo "  make run           install 后打开应用"
	@echo "  make status        查看安装 / 运行状态"
	@echo "  make clean         清理 .build / build"
	@echo "  make uninstall     移到废纸篓并注销登记（可恢复）"
	@echo "  make pkg           通用架构编译 + 打成 .pkg 安装包"
	@echo "  make dist          pkg + .app.zip + checksums.txt（CI 发版用）"
	@echo "  make release       VERSION=<x.y.z|patch|minor|major> 发版"
	@echo ""
	@echo "功能：拖拽安装包到窗口，或点「选择文件…」；两种方式都不需要任何系统扩展。"
