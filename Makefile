# 顾海龙集团分屏 — GuHaiLongSplitScreen
# 原创 Theos 插件工程。目标机型：iPhone 11 / iOS 16.5 / Dopamine (rootless)。
# 构建：macOS + Xcode + Theos，或 GitHub Actions（macos runner，
# 做法照抄 FrontBoardAppLauncher 的 build.yml）。
# 本地 Linux 构建见 BUILD_LOG.md（需 clang 交叉工具链 + iOS SDK + ldid）。
ARCHS = arm64 arm64e
TARGET := iphone:clang:16.5:15.0
INSTALL_TARGET_PROCESSES = SpringBoard

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = GuHaiLongSplitScreen GHLSSKeyboardHelper

GuHaiLongSplitScreen_FILES = Tweak.xm
GuHaiLongSplitScreen_CFLAGS = -fobjc-arc
# v43.5（1.0.80）：第二個 dylib——鍵盤助手，塞進 App 進程（v43.26 改
# Bundles=(com.tencent.xin, com.tencent.mqq)＋Executables=(WeChat, QQ)，
# 見 GHLSSKeyboardHelper.plist；舊的 Classes=(UIApplication) 會被 ElleKit
# 在進程啟動時只評估一次，類名過濾看時序，微信／QQ 從來沒載進去過。
# %ctor 裡再排掉 SpringBoard／抖音兩個包名／設定 App——過濾器改窄之後
# 這些排除走不到，但留著當防線，以後 Bundles 加 App 也不怕誤進）。
# 只橋接鍵盤通知＋移鍵盤窗，不進 SpringBoard。兩個 dylib 共用同一個 .deb。
# v24（5.2）建 scene 要用的私有框架：FBProcessManager / FBSceneManager /
# FBApplicationProcessLaunchTransaction 在 FrontBoard；FBSMutableSceneDefinition /
# FBSMutableSceneParameters / FBSSceneIdentity / FBSSceneClientIdentity /
# FBSSceneSpecification 在 FrontBoardServices；RBSProcessIdentity /
# RBSProcessPredicate / RBSProcessHandle 在 RunningBoardServices；
# BSCornerRadiusConfiguration 在 BaseBoard。直接引用类 + 自己声明接口
#（不走 NSClassFromString 的 PrivClass：本工程 -Werror，找不到方法的
# 警告会直接变成编译错误）。
GuHaiLongSplitScreen_PRIVATE_FRAMEWORKS = FrontBoard FrontBoardServices RunningBoardServices BaseBoard

GHLSSKeyboardHelper_FILES = KeyboardHelper.xm
GHLSSKeyboardHelper_CFLAGS = -fobjc-arc
GHLSSKeyboardHelper_FRAMEWORKS = UIKit Foundation CoreGraphics

include $(THEOS_MAKE_PATH)/tweak.mk

SUBPROJECTS += prefs
include $(THEOS_MAKE_PATH)/aggregate.mk
