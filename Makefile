# 顾海龙集团分屏 — GuHaiLongSplitScreen
# 原创 Theos 插件工程。目标机型：iPhone 11 / iOS 16.5 / Dopamine (rootless)。
# 构建：macOS + Xcode + Theos，或 GitHub Actions（macos runner，
# 做法照抄 FrontBoardAppLauncher 的 build.yml）。
# 本地 Linux 构建见 BUILD_LOG.md（需 clang 交叉工具链 + iOS SDK + ldid）。
ARCHS = arm64 arm64e
TARGET := iphone:clang:16.5:15.0
INSTALL_TARGET_PROCESSES = SpringBoard

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = GuHaiLongSplitScreen

GuHaiLongSplitScreen_FILES = Tweak.xm
GuHaiLongSplitScreen_CFLAGS = -fobjc-arc
# v24（5.2）建 scene 要用的私有框架：FBProcessManager / FBSceneManager /
# FBApplicationProcessLaunchTransaction 在 FrontBoard；FBSMutableSceneDefinition /
# FBSMutableSceneParameters / FBSSceneIdentity / FBSSceneClientIdentity /
# FBSSceneSpecification 在 FrontBoardServices；RBSProcessIdentity /
# RBSProcessPredicate / RBSProcessHandle 在 RunningBoardServices；
# BSCornerRadiusConfiguration 在 BaseBoard。直接引用类 + 自己声明接口
#（不走 NSClassFromString 的 PrivClass：本工程 -Werror，找不到方法的
# 警告会直接变成编译错误）。
GuHaiLongSplitScreen_PRIVATE_FRAMEWORKS = FrontBoard FrontBoardServices RunningBoardServices BaseBoard

include $(THEOS_MAKE_PATH)/tweak.mk

SUBPROJECTS += prefs
include $(THEOS_MAKE_PATH)/aggregate.mk
