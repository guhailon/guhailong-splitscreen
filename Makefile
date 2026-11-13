# 顾海龙集团分屏 — GuHaiLongSplitScreen
# 原创 Theos 插件工程。目标机型：iPhone 11 / iOS 16.5 / Dopamine (rootless)。
# 构建：macOS + Xcode + Theos，或 GitHub Actions (macos runner + waruhachi/theos-action)。
# 本地 Linux 构建见 BUILD_LOG.md（需 clang 交叉工具链 + iOS SDK + ldid）。
ARCHS = arm64 arm64e
TARGET := iphone:clang:16.5:15.0
INSTALL_TARGET_PROCESSES = SpringBoard

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = GuHaiLongSplitScreen

GuHaiLongSplitScreen_FILES = Tweak.xm
GuHaiLongSplitScreen_CFLAGS = -fobjc-arc
# v4 不再链接 MobileGestalt：MGGetBoolAnswer hook 已删，不再调用它。

include $(THEOS_MAKE_PATH)/tweak.mk

SUBPROJECTS += prefs
include $(THEOS_MAKE_PATH)/aggregate.mk
