// GuHaiLongSplitScreen v1.0.23 (v23) — 顾海龙集团原创分屏插件（实验版）
//
// 目标：iPhone 11 / iOS 16.5 / Dopamine (rootless)，iphoneos-arm64。
//
// ── v23：修 v22 的窗没显示出来的问题（macOS 编） ───────────
// v22（1.0.22，macOS 编）皇上真机实测（2026-11-13 10:03–10:05）：
// 装得上、不黑屏，日志 9–13 行全齐（`v22 handle button added` 也在），
// 但金色"分"按钮看不见，右边缘滑两次启动器也打不开——感应带的窗
// 在代码里建了，却从来没显示到屏幕上，也没收到触摸。v21/v22 的带子
// 都是透明的，窗本身从来没被肉眼确认过，"分"按钮是第一个看得见的
// 东西。最可能的两个原因：(a) 窗是用 initWithFrame 建的，没挂
// windowScene（iOS 13+ 没挂 scene 的窗可能不显示）；(b) 带子的视图
// 是 plain init（零 frame），只靠 view controller 去调尺寸。
// v23 只改这三件事（其余照抄 v22）：
//   1) 建窗前先从 connectedScenes 取一个 UIWindowScene（没有就用
//      key window 的 windowScene），显式挂到窗上，再 hidden = NO，
//      并记日志 `v23 window scene found` / `v23 window scene nil`；
//   2) 带子的视图用 initWithFrame 给显式 frame；
//   3) 把手做大做显眼：感应带 24pt 宽，按钮 24x64、14pt 粗体、
//      金底黑边，竖直居中放右边缘。
// 另外建窗后记诊断日志：窗的 frame、hidden、scene 有没有，带子与
// 按钮的 frame 各是多少——下次真机一看日志就知道窗到底上没上屏。
// 5.1 的其余部分不变：感应带上挂 UIScreenEdgePanGestureRecognizer
// （右边缘，2 秒内滑两次才开启动器），侧边小窗启动器（右边缘
// 220pt 宽、暗色半透明，列 5 个系统 App，图标用 UIImage 的私有方法
// 取；点 App 全屏打开，点窗外或"关闭"收起）。启动器的窗也一样显式
// 挂 scene（不然启动器也可能看不见）。手势与按钮的目标是唯一的一
// 个自定义类 GHLSSLauncher，视图全部用苹果的类（UIWindow、
// UIViewController、UIView、UIButton、UIImageView、UILabel）。
// 关键约束（v13 的教训）：**这个文件里一个写死的字串都不能有**——
// 不用硬编码的 CoreFoundation 字串常量，也不用 ObjC 字面量字串。
// 所有 NSString/CFString 都在运行时现做
//（CFStringCreateWithCString / stringWithCString:）；普通的 C
// 字串（"..."）没问题；@selector(...) 没问题（selector 不是
// 字串常量）。编译完要验 dylib 里没有 __cfstring 段，
// AddObserver 是 0。
// 感应带与启动器不看开关：v23 永远建带，只测功能；开关的门以后再加。
// 横屏不处理：只按竖屏算位置。
// v1–v21 的完整历史与诊断见 BUILD_LOG.md。5.1 的完整设计见
// V5_DESIGN.md §5.1。开源学习的完整报告见
// OPEN_SOURCE_RESEARCH_2.md。

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <objc/message.h>
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

// 5.1 启动器里的 5 个系统 App（bundle ID 与显示名，都是普通 C 字串）。
static const char *GHLSSAppBundleIDs[5] = {
"com.apple.calculator",
"com.apple.mobiletimer",
"com.apple.mobilenotes",
"com.apple.Preferences",
"com.apple.mobileslideshow"
};
static const char *GHLSSAppNames[5] = {
"计算器",
"时钟",
"备忘录",
"设置",
"照片"
};
#define GHLSS_APP_COUNT 5

// 取 App 图标：UIImage 的私有方法
// _applicationIconImageForBundleIdentifier:format:scale:
// 用运行时查找（objc_getClass + objc_msgSend），不链接私有框架。
// 方法不存在或取不到就返回 nil（调用处用灰色方块代替，不崩）。
static UIImage *GHLSSAppIcon(const char *bundleID) {
NSString *bid = [NSString stringWithCString:bundleID encoding:NSUTF8StringEncoding];
if (!bid) return nil;
Class UIImageClass = objc_getClass("UIImage");
if (!UIImageClass) return nil;
SEL sel = sel_registerName("_applicationIconImageForBundleIdentifier:format:scale:");
if (!sel) return nil;
if (![UIImageClass respondsToSelector:sel]) return nil;
@try {
CGFloat scale = [UIScreen mainScreen].scale;
UIImage *icon = ((UIImage *(*)(id, SEL, id, long, double))objc_msgSend)(UIImageClass, sel, bid, 0, (double)scale);
return icon;
} @catch (NSException *e) {
(void)e;
return nil;
}
}

// 全屏打开一个 App：LSApplicationWorkspace 的
// openApplicationWithBundleID:，同样用运行时查找。返回 YES/NO。
static BOOL GHLSSOpenApp(const char *bundleID) {
NSString *bid = [NSString stringWithCString:bundleID encoding:NSUTF8StringEncoding];
if (!bid) return NO;
Class workspaceClass = objc_getClass("LSApplicationWorkspace");
if (!workspaceClass) return NO;
SEL defaultSel = sel_registerName("defaultWorkspace");
if (![workspaceClass respondsToSelector:defaultSel]) return NO;
id workspace = ((id(*)(id, SEL))objc_msgSend)(workspaceClass, defaultSel);
if (!workspace) return NO;
SEL openSel = sel_registerName("openApplicationWithBundleID:");
if (![workspace respondsToSelector:openSel]) return NO;
BOOL ok = ((BOOL(*)(id, SEL, id))objc_msgSend)(workspace, openSel, bid);
return ok;
}

// 感应带的视图：自己写的普通 UIView 子类，里面什么方法都没有
//（v18/v21 已证明它在 macOS 编的包里是安全的）。
@interface GHLSSPlainStripView : UIView
@end
@implementation GHLSSPlainStripView
@end

// 5.1 唯一的自定义处理类：手势与按钮的目标、启动器的主人。
// 视图全部用苹果的类，不再加自定义视图子类。
@interface GHLSSLauncher : NSObject <UIGestureRecognizerDelegate>
- (void)handleEdgeSwipe:(UIScreenEdgePanGestureRecognizer *)recognizer;
- (void)handleHandleButton:(id)sender;
- (void)handleAppButton:(UIButton *)sender;
- (void)handleCloseButton:(id)sender;
- (void)handleBackgroundTap:(UITapGestureRecognizer *)recognizer;
- (void)showLauncher;
- (void)dismissLauncher;
- (void)buildLauncherWindow;
@end

// 窗与状态要一直留着（静态变量拿着，不会被释放）。
static UIWindow *GHLSSStripWindow = nil;
static UIWindow *GHLSSLauncherWindow = nil;
static GHLSSLauncher *GHLSSLauncherShared = nil;
static BOOL GHLSSLauncherVisible = NO;
// 上一次边缘滑动的时间（CFAbsoluteTime），用来做"滑两次才开"。
static double GHLSSLastSwipeTime = 0;

// 取一个可用的 UIWindowScene（iOS 13+ 的窗必须挂 scene 才会显示）：
// 先从 connectedScenes 里找第一个 UIWindowScene，没有就退到
// key window 的 windowScene，再没有就返回 nil（调用处记日志）。
// 全部是公开 API 的方法调用，不用字串常量。
static UIWindowScene *GHLSSActiveWindowScene(void) {
UIApplication *app = [UIApplication sharedApplication];
if (!app) return nil;
NSSet *scenes = [app connectedScenes];
for (id s in scenes) {
if ([s isKindOfClass:[UIWindowScene class]]) return (UIWindowScene *)s;
}
UIWindow *key = [app keyWindow];
if (key) return key.windowScene;
return nil;
}

@implementation GHLSSLauncher

// 允许我们的手势与系统手势同时识别（不抢系统手势）。
- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer {
return YES;
}

// 右边缘滑动：2 秒内滑两次才开启动器（防误触）；第一次只记日志。
- (void)handleEdgeSwipe:(UIScreenEdgePanGestureRecognizer *)recognizer {
if (recognizer.state != UIGestureRecognizerStateEnded) return;
double now = CFAbsoluteTimeGetCurrent();
if (now - GHLSSLastSwipeTime < 2.0) {
GHLSSLastSwipeTime = 0;
GHLSSLogLine("v23 edge swipe 2nd, opening launcher");
[self showLauncher];
} else {
GHLSSLastSwipeTime = now;
GHLSSLogLine("v23 edge swipe 1st, armed");
}
}

// 金色"分"按钮：点一次就开启动器（备用触发，不用滑两次）。
- (void)handleHandleButton:(id)sender {
GHLSSLogLine("v23 handle button tapped, opening launcher");
[self showLauncher];
}

// 点启动器里的一个 App：全屏打开它，再收起启动器。
- (void)handleAppButton:(UIButton *)sender {
NSInteger idx = sender.tag;
if (idx < 0 || idx >= GHLSS_APP_COUNT) return;
const char *bid = GHLSSAppBundleIDs[idx];
char buf[192];
snprintf(buf, sizeof(buf), "v23 app tapped %s", bid);
GHLSSLogLine(buf);
BOOL ok = GHLSSOpenApp(bid);
snprintf(buf, sizeof(buf), "v23 open app %s ok=%d", bid, ok ? 1 : 0);
GHLSSLogLine(buf);
[self dismissLauncher];
}

- (void)handleCloseButton:(id)sender {
GHLSSLogLine("v23 close button tapped");
[self dismissLauncher];
}

- (void)handleBackgroundTap:(UITapGestureRecognizer *)recognizer {
GHLSSLogLine("v23 background tapped, dismissing launcher");
[self dismissLauncher];
}

- (void)showLauncher {
if (GHLSSLauncherVisible) {
GHLSSLogLine("v23 launcher already open");
return;
}
if (!GHLSSLauncherWindow) {
[self buildLauncherWindow];
}
GHLSSLauncherWindow.hidden = NO;
GHLSSLauncherVisible = YES;
GHLSSLogLine("v23 launcher opened");
}

- (void)dismissLauncher {
if (!GHLSSLauncherVisible) return;
GHLSSLauncherWindow.hidden = YES;
GHLSSLauncherVisible = NO;
GHLSSLogLine("v23 launcher dismissed");
}

// 建启动器窗（第一次打开时才建）：全屏透明窗 + 右侧 220pt 暗色面板。
// 面板与背景点按区是平级的两个子视图：点面板不会触发收起，
// 点面板以外（透明区）才收起。
- (void)buildLauncherWindow {
CGRect screenBounds = [UIScreen mainScreen].bounds;
CGFloat panelWidth = 220.0;
GHLSSLauncherWindow = [[UIWindow alloc] initWithFrame:screenBounds];
GHLSSLauncherWindow.windowLevel = UIWindowLevelAlert + 1.0;
GHLSSLauncherWindow.backgroundColor = [UIColor clearColor];
// 启动器的窗也显式挂 scene（v22 的教训：没挂 scene 的窗可能不显示）。
UIWindowScene *launcherScene = GHLSSActiveWindowScene();
if (launcherScene) {
GHLSSLauncherWindow.windowScene = launcherScene;
GHLSSLogLine("v23 launcher scene found");
} else {
GHLSSLogLine("v23 launcher scene nil");
}
UIViewController *launcherVC = [[UIViewController alloc] init];
UIView *rootView = [[UIView alloc] initWithFrame:screenBounds];
rootView.backgroundColor = [UIColor clearColor];
launcherVC.view = rootView;
// 背景点按区（全屏透明）：点它收起启动器。
UIView *bgView = [[UIView alloc] initWithFrame:screenBounds];
bgView.backgroundColor = [UIColor clearColor];
UITapGestureRecognizer *bgTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleBackgroundTap:)];
[bgView addGestureRecognizer:bgTap];
[rootView addSubview:bgView];
// 右侧面板（220pt 宽，全高，暗色半透明）。
CGRect panelFrame = CGRectMake(screenBounds.size.width - panelWidth, 0, panelWidth, screenBounds.size.height);
UIView *panel = [[UIView alloc] initWithFrame:panelFrame];
panel.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.85];
[rootView addSubview:panel];
// 标题。
UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(12, 20, 150, 30)];
titleLabel.text = [NSString stringWithCString:"分屏" encoding:NSUTF8StringEncoding];
titleLabel.textColor = [UIColor whiteColor];
titleLabel.font = [UIFont boldSystemFontOfSize:17];
[panel addSubview:titleLabel];
// 5 个 App 行：图标 + 名字，点一行全屏打开那个 App。
for (NSInteger i = 0; i < GHLSS_APP_COUNT; i++) {
UIButton *appButton = [UIButton buttonWithType:UIButtonTypeCustom];
appButton.frame = CGRectMake(0, 64 + i * 64, panelWidth, 60);
appButton.tag = i;
[appButton addTarget:self action:@selector(handleAppButton:) forControlEvents:UIControlEventTouchUpInside];
UIImageView *iconView = [[UIImageView alloc] initWithFrame:CGRectMake(12, 8, 44, 44)];
UIImage *icon = GHLSSAppIcon(GHLSSAppBundleIDs[i]);
if (icon) {
iconView.image = icon;
} else {
iconView.backgroundColor = [UIColor grayColor];
char ibuf[192];
snprintf(ibuf, sizeof(ibuf), "v23 icon nil for %s", GHLSSAppBundleIDs[i]);
GHLSSLogLine(ibuf);
}
iconView.layer.cornerRadius = 10.0;
iconView.layer.masksToBounds = YES;
[appButton addSubview:iconView];
UILabel *nameLabel = [[UILabel alloc] initWithFrame:CGRectMake(64, 0, 144, 60)];
nameLabel.text = [NSString stringWithCString:GHLSSAppNames[i] encoding:NSUTF8StringEncoding];
nameLabel.textColor = [UIColor whiteColor];
nameLabel.font = [UIFont systemFontOfSize:16];
[appButton addSubview:nameLabel];
[panel addSubview:appButton];
}
// 关闭按钮（面板底部）。
UIButton *closeButton = [UIButton buttonWithType:UIButtonTypeSystem];
closeButton.frame = CGRectMake(0, screenBounds.size.height - 60, panelWidth, 44);
[closeButton setTitle:[NSString stringWithCString:"关闭" encoding:NSUTF8StringEncoding] forState:UIControlStateNormal];
[closeButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
closeButton.titleLabel.font = [UIFont systemFontOfSize:16];
[closeButton addTarget:self action:@selector(handleCloseButton:) forControlEvents:UIControlEventTouchUpInside];
[panel addSubview:closeButton];
GHLSSLauncherWindow.rootViewController = launcherVC;
GHLSSLogLine("v23 launcher built");
}

@end

%ctor {
// v23 的 %ctor 和 v21 一模一样，只做一行纯 C 调用：
// 5 秒后在主队列跑一个 block。不登记通知、不写日志、不读文件、
// 不调 NSLog、不建窗、不 hook。
dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5 * NSEC_PER_SEC)),
dispatch_get_main_queue(), ^{
// 延后步骤（启动完成 5 秒后，主队列）：
// 1) 读开关（运行时现做的字串，和 v13 一样），写日志；
// 2) 建右边缘感应带（24pt 宽透明窗），带子是自己写的普通视图，
//    写日志；
// 3) 感应带上挂右边缘滑动手势 + 金色"分"按钮（5.1 新增）。
// 不登记通知、不建 FBScene、不 hook。
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
snprintf(buf, sizeof(buf), "v23 deferred setup ran, switch=%s", state);
GHLSSLogLine("v23 deferred setup ran");
GHLSSLogLine(buf);
// 右边缘感应带：24pt 宽、全高、透明，层级在 SpringBoard 内容之上。
// v23 的修法：窗显式挂 windowScene（没挂 scene 的窗可能不显示，
// v22 的教训）；带子的视图给显式 frame（不用 plain init 的零 frame）。
CGRect screenBounds = [UIScreen mainScreen].bounds;
CGFloat stripWidth = 24.0;
CGRect stripFrame = CGRectMake(screenBounds.size.width - stripWidth, 0, stripWidth, screenBounds.size.height);
GHLSSStripWindow = [[UIWindow alloc] initWithFrame:stripFrame];
GHLSSStripWindow.windowLevel = UIWindowLevelAlert;
GHLSSStripWindow.backgroundColor = [UIColor clearColor];
UIWindowScene *stripScene = GHLSSActiveWindowScene();
if (stripScene) {
GHLSSStripWindow.windowScene = stripScene;
GHLSSLogLine("v23 window scene found");
} else {
GHLSSLogLine("v23 window scene nil");
}
UIViewController *stripVC = [[UIViewController alloc] init];
GHLSSPlainStripView *stripView = [[GHLSSPlainStripView alloc] initWithFrame:CGRectMake(0, 0, stripWidth, screenBounds.size.height)];
stripView.backgroundColor = [UIColor clearColor];
stripVC.view = stripView;
GHLSSStripWindow.rootViewController = stripVC;
GHLSSStripWindow.hidden = NO;
GHLSSLogLine("v23 edge strip built");
// 诊断日志：窗与带子到底是什么状态（真机一看就知道上没上屏）。
char dbuf[256];
CGRect wf = GHLSSStripWindow.frame;
snprintf(dbuf, sizeof(dbuf), "v23 window frame=%d,%d,%d,%d hidden=%d scene=%s", (int)wf.origin.x, (int)wf.origin.y, (int)wf.size.width, (int)wf.size.height, GHLSSStripWindow.hidden ? 1 : 0, GHLSSStripWindow.windowScene ? "ok" : "nil");
GHLSSLogLine(dbuf);
CGRect sf = stripView.frame;
snprintf(dbuf, sizeof(dbuf), "v23 strip frame=%d,%d,%d,%d", (int)sf.origin.x, (int)sf.origin.y, (int)sf.size.width, (int)sf.size.height);
GHLSSLogLine(dbuf);
// 5.1 的处理器（唯一的自定义处理类）。
GHLSSLauncherShared = [[GHLSSLauncher alloc] init];
// 右边缘滑动手势（挂在感应带上）。
UIScreenEdgePanGestureRecognizer *edgePan = [[UIScreenEdgePanGestureRecognizer alloc] initWithTarget:GHLSSLauncherShared action:@selector(handleEdgeSwipe:)];
edgePan.edges = UIRectEdgeRight;
edgePan.delegate = GHLSSLauncherShared;
[stripView addGestureRecognizer:edgePan];
GHLSSLogLine("v23 edge gesture added");
// 金色"分"按钮（感应带上的可见把手，备用触发）。
// v23 做大做显眼：24 宽 x 64 高、14pt 粗体、金底黑边（v22 的 12x48
// 太小，就算显示了也难看见）。
UIButton *handleButton = [UIButton buttonWithType:UIButtonTypeCustom];
CGFloat handleHeight = 64.0;
handleButton.frame = CGRectMake(0, (screenBounds.size.height - handleHeight) / 2.0, stripWidth, handleHeight);
handleButton.backgroundColor = [UIColor colorWithRed:0.83 green:0.68 blue:0.21 alpha:1.0];
handleButton.layer.borderWidth = 2.0;
handleButton.layer.borderColor = [UIColor blackColor].CGColor;
[handleButton setTitle:[NSString stringWithCString:"分" encoding:NSUTF8StringEncoding] forState:UIControlStateNormal];
[handleButton setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
handleButton.titleLabel.font = [UIFont boldSystemFontOfSize:14];
[handleButton addTarget:GHLSSLauncherShared action:@selector(handleHandleButton:) forControlEvents:UIControlEventTouchUpInside];
[stripView addSubview:handleButton];
GHLSSLogLine("v23 handle button added");
CGRect bf = handleButton.frame;
snprintf(dbuf, sizeof(dbuf), "v23 button frame=%d,%d,%d,%d", (int)bf.origin.x, (int)bf.origin.y, (int)bf.size.width, (int)bf.size.height);
GHLSSLogLine(dbuf);
});
}
