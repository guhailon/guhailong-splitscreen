// GuHaiLongSplitScreen v1.0.21 (v21) — 顾海龙集团原创分屏插件（实验版）
//
// 目标：iPhone 11 / iOS 16.5 / Dopamine (rootless)，iphoneos-arm64。
//
// ── v21：v18 的代码，在 macOS 上编 ───────────────────────────
// v18（1.0.18，Linux 工具链编的）皇上真机实测失败（2026-11-12
// 约 23:53）：装完黑屏。v18 的 GHLSSPlainStripView 是一个空的
// 视图子类，里面一个方法都没有，不接 touch、不挂手势，还是黑屏。
// v20（1.0.20，v18 代码只编 arm64）也失败（2026-11-13 约 08:29）：
// 装完不黑屏，但日志里没有 v20 的行——只编 arm64 的包注不进
// arm64e 的 SpringBoard，等于没加载，是假通过。
// 开源项目调研（BUILD_LOG.md 第 39 节）发现：FrontBoardAppLauncher
// （Apache-2.0）和 KonbanXV（MIT）的自定义类带手势、带 target，
// 在生产环境里正常工作；而且所有能用的开源项目都是用苹果自己
// 的 clang 在 macOS 上编的，没有一个用 Linux 交叉工具链。
// v21 就是证明：代码和 v18 一模一样（同一个空视图子类、同一
// 个延后步骤、同一扇窗），只改在 macOS（GitHub Actions）上编，
// 用苹果的 clang，通用 arm64 + arm64e。版本号和日志里的 v18
// 改成 v21，除此之外一个字都没动。
// —— v21 不黑屏 + 日志里有 `v21 edge strip built`：凶手就是
//    Linux 工具链；往后全部在 macOS 上编，自定义类、手势、
//    CFSTR 可能全都恢复正常；
// —— v21 也黑屏：问题不在工具链，是自定义类在 iOS 16.5 /
//    Dopamine 的 SpringBoard 里本身就有问题，要换做法。
// 关键约束（v13 的教训）：**这个文件里一个写死的字串都不能有**——
// 不用 CFSTR，也不用 @"..."（ObjC 字串字面量也是 CFSTR）。窗、
// 视图全用运行时创建的对象，不碰任何字串常量。编译完要验
// dylib 里没有 __cfstring 段，也没有手势识别器和 touch 方法。
// 感应带不看开关：v21 永远建带，只测类本身；开关的门以后再加。
// 横屏不处理：只按竖屏算位置。
// v1–v20 的完整历史与诊断见 BUILD_LOG.md。5.1 的完整设计见 V5_DESIGN.md §5.1。

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <stdio.h>

#define GHLSS_LOG_PATH "/var/mobile/Library/Logs/GuHaiLongSplitScreen.log"

// 纯 C 写日志（一行）：日志只用来证明延后步骤跑了、窗建了没有。
static void GHLSSLogLine(const char *line) {
FILE *f = fopen(GHLSS_LOG_PATH, "a");
if (f) {
fputs(line, f);
fputc('\n', f);
fclose(f);
}
}

// 感应带的视图：自己写的普通 UIView 子类，里面什么方法都没有，
// 不接 touch、不挂手势，只测“自己写的类”本身是不是凶手。
@interface GHLSSPlainStripView : UIView
@end
@implementation GHLSSPlainStripView
@end

// 感应带窗要一直留着（静态变量拿着，不会被释放）。
static UIWindow *GHLSSStripWindow = nil;

%ctor {
// v21 的 %ctor 和 v10b/v11/v12/v13/v14/v15/v16/v17/v18/v19/v20 一模一样，只做一行纯 C 调用：
// 5 秒后在主队列跑一个 block。不登记通知、不写日志、不读文件、
// 不调 NSLog、不建窗、不 hook。
dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5 * NSEC_PER_SEC)),
dispatch_get_main_queue(), ^{
// 延后步骤（启动完成 5 秒后，主队列）：
// 1) 读开关（运行时现做的字串，和 v13 一样），写日志；
// 2) 建右边缘感应带（12pt 宽透明窗），带子是自己写的普通视图，
//    不接 touch、不挂手势，写日志。
// 不登记通知、不建 scene、不 hook。
CFStringRef domain = CFStringCreateWithCString(NULL, "com.guhailong.splitscreen", kCFStringEncodingUTF8);
CFStringRef key = CFStringCreateWithCString(NULL, "enabled", kCFStringEncodingUTF8);
CFPropertyListRef v = CFPreferencesCopyAppValue(key, domain);
const char *state = "none(default OFF)";
if (v) {
if (CFGetTypeID(v) == CFBooleanGetTypeID()) {
state = CFBooleanGetValue((CFBooleanRef)v) ? "ON" : "OFF";
} else {
state = "not-a-bool";
}
CFRelease(v);
}
if (domain) CFRelease(domain);
if (key) CFRelease(key);
char buf[128];
snprintf(buf, sizeof(buf), "v21 deferred setup ran, switch=%s", state);
GHLSSLogLine("v21 deferred setup ran");
GHLSSLogLine(buf);
// 右边缘感应带：12pt 宽、全高、透明，层级在 SpringBoard 内容之上。
CGRect screenBounds = [UIScreen mainScreen].bounds;
CGFloat stripWidth = 12.0;
CGRect stripFrame = CGRectMake(screenBounds.size.width - stripWidth, 0, stripWidth, screenBounds.size.height);
GHLSSStripWindow = [[UIWindow alloc] initWithFrame:stripFrame];
GHLSSStripWindow.windowLevel = UIWindowLevelAlert;
GHLSSStripWindow.backgroundColor = [UIColor clearColor];
UIViewController *stripVC = [[UIViewController alloc] init];
GHLSSPlainStripView *stripView = [[GHLSSPlainStripView alloc] init];
stripView.backgroundColor = [UIColor clearColor];
stripVC.view = stripView;
GHLSSStripWindow.rootViewController = stripVC;
GHLSSStripWindow.hidden = NO;
GHLSSLogLine("v21 edge strip built");
});
}
