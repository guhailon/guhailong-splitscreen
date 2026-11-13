// GuHaiLongSplitScreen v1.0.25 (v25) — 顾海龙集团原创分屏插件（实验版）
//
// 目标：iPhone 11 / iOS 16.5 / Dopamine (rootless)，iphoneos-arm64。
//
// ── v25：5.2 修 v24 的安全模式（macOS 编） ──────────────
// v24（1.0.24）皇上真机实测（2026-11-13 11:09）：点启动器里的计算器，
// 手机直接进安全模式。崩溃日志（SpringBoard-2026-11-13-110826.ips）
// 定死了原因：EXC_BREAKPOINT，崩在 -[BSTransaction begin] 里，
// 后台队列（com.apple.root.default-qos）。FBApplicationProcessLaunch-
// Transaction 是 BSTransaction 的子类，begin 里面断言当前队列必须是
// 主队列（BSDispatchQueueAssert）——v24 把启动放后台队列，begin 一调
// 就触发断言，把 SpringBoard 杀进安全模式。RBS 那些调用在后台队列都
// 成功了，只有 begin 崩。所以 v25 只改一件事：启动放回主线程做
// （和参考实现 FrontBoardAppLauncher 一模一样——它就是在主线程点按
// 回调里拉起进程）。FB 事务本身是异步的：begin 立刻返回、完成走回调，
// 主线程不会被堵（v23 那种 5 秒卡死是同步打开调用造成的，那条路已
// 经删了，不会重演）。先收启动器不变；每一步都记日志，下次再崩直接
// 定位到具体调用。
// v25 还是 5.2：点启动器里的 App，不再全屏打开，而是按 V5_DESIGN.md
// §2.2 把它的 live scene 嵌进一个 FV 风格的悬浮窗（圆角 35、有阴影、
// 离屏幕边缘有距离、44pt 标题栏可拖动、红关闭钮、黄最小化钮、右下角
// 缩放手柄）。先只支持一个悬浮窗；计算器先测（测前先把计算器彻底
// 关掉——目标 App 不能已经在跑）。键盘不做（计算器不用键盘；
// iOS 16.5 上没有干净修法，见 V5_DESIGN.md §3.3）。
// 场景托管的结构与私有接口声明，仿照 FrontBoardAppLauncher
//（作者 khanhduytran0，Apache-2.0，https://github.com/khanhduytran0/
// FrontBoardAppLauncher）的 DecoratedAppSceneView.m、
// AppSceneViewController.m 与 UIKitPrivate+MultitaskSupport.h；
// 代码全部原创，只借结构与接口名（接口名是事实，不是表达）。
// LiveContainer 的窗外形与场景生命周期只学原理（AGPL-3.0，不能抄）。
// 关键约束（v13 的教训）：**这个文件里一个写死的字串都不能有**——
// 不用硬编码的 CoreFoundation 字串常量，也不用 ObjC 字面量字串。
// 所有 NSString/CFString 都在运行时现做
//（CFStringCreateWithCString / stringWithCString:）；普通的 C
// 字串（"..."）没问题；@selector(...) 没问题（selector 不是
// 字串常量）。编译完要验 dylib 里没有 __cfstring 段，也没有通知中心的
// 登记调用。不要用任何已废弃 API（v23 首编的教训：取主窗口的旧 API 在
// iOS 13 起已废弃，Theos 默认 -Werror 会把它当编译错误）。
// 感应带与启动器不看开关：v25 永远建带，只测功能；开关的门以后再加。
// 横屏不处理：只按竖屏算位置。
// v1–v24 的完整历史与诊断见 BUILD_LOG.md。5.2 的完整设计见
// V5_DESIGN.md §2、§4.4、§5.2 与附录 D。开源学习见
// OPEN_SOURCE_RESEARCH_2.md。

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import <stdio.h>
#import <string.h>
#import <stdlib.h>
#import <unistd.h>
#import <signal.h>

#define GHLSS_LOG_PATH "/var/mobile/Library/Logs/GuHaiLongSplitScreen.log"

// 纯 C 写日志（一行）：日志只用来证明延后步骤跑了、窗建了没有、
// 启动走到哪一步了。
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

// ── 私有接口最小声明 ─────────────────────────────────────
// 结构与接口名仿照 FrontBoardAppLauncher 的
// UIKitPrivate+MultitaskSupport.h（作者 khanhduytran0，
// Apache-2.0）。只声明类名与方法名，代码全部原创。
// 注意：audit_token_t 是 32 字节的结构（8 个 uint32_t），这里用
// 自己的同布局类型名，避免去找 bsm 头文件；传参布局完全一致。
typedef struct { uint32_t val[8]; } GHLSSAuditToken;

@interface BSTransaction : NSObject
- (void)begin;
- (void)setCompletionBlock:(dispatch_block_t)block;
@end

@interface FBApplicationProcessLaunchTransaction : BSTransaction
- (instancetype)initWithProcessIdentity:(id)identity executionContextProvider:(id)providerBlock;
@end

@interface FBProcessExecutionContext : NSObject
@end

@interface FBMutableProcessExecutionContext : FBProcessExecutionContext
@property (nonatomic, copy) id identity;
@property (nonatomic, copy) NSDictionary *environment;
@property (nonatomic, assign) long long launchIntent;
@end

@interface FBProcessManager : NSObject
+ (instancetype)sharedInstance;
- (FBProcessExecutionContext *)launchProcessWithContext:(FBMutableProcessExecutionContext *)context;
- (void)registerProcessForAuditToken:(GHLSSAuditToken)token;
@end

@interface RBSProcessIdentity : NSObject
+ (instancetype)identityForEmbeddedApplicationIdentifier:(NSString *)identifier;
@end

@interface RBSProcessPredicate : NSObject
+ (instancetype)predicateMatchingIdentity:(RBSProcessIdentity *)identity;
@end

@interface RBSProcessHandle : NSObject
@property (nonatomic, copy, readonly) RBSProcessIdentity *identity;
+ (instancetype)handleForPredicate:(RBSProcessPredicate *)predicate error:(NSError **)error;
- (GHLSSAuditToken)auditToken;
- (int)pid;
@end

@interface FBSSceneIdentity : NSObject
+ (instancetype)identityForIdentifier:(NSString *)identifier;
@end

@interface FBSSceneClientIdentity : NSObject
+ (instancetype)identityForProcessIdentity:(RBSProcessIdentity *)identity;
@end

@interface FBSSceneSpecification : NSObject
+ (instancetype)specification;
@end

@interface UIApplicationSceneSpecification : FBSSceneSpecification
@end

@interface FBSMutableSceneDefinition : NSObject
@property (nonatomic, copy) FBSSceneClientIdentity *clientIdentity;
@property (nonatomic, copy) FBSSceneIdentity *identity;
@property (nonatomic, copy) FBSSceneSpecification *specification;
+ (instancetype)definition;
@end

@interface UIApplicationSceneSettings : NSObject
@end

// BSCornerRadiusConfiguration 在 BaseBoard 里，完整声明在下面；
// 这里先前置声明（UIMutableApplicationSceneSettings 的
// cornerRadiusConfiguration 属性要用到它）。
@class BSCornerRadiusConfiguration;

@interface UIMutableApplicationSceneSettings : UIApplicationSceneSettings
@property (nonatomic, assign) BOOL canShowAlerts;
@property (nonatomic, assign) NSInteger interruptionPolicy;
@property (nonatomic, strong) NSString *persistenceIdentifier;
@property (nonatomic, assign) UIEdgeInsets peripheryInsets;
@property (nonatomic, assign) UIEdgeInsets safeAreaInsetsPortrait;
@property (nonatomic, assign) UIDeviceOrientation deviceOrientation;
@property (nonatomic, strong) BSCornerRadiusConfiguration *cornerRadiusConfiguration;
@property (nonatomic, assign, getter=isForeground) BOOL foreground;
@property (nonatomic, assign) CGRect frame;
@property (nonatomic, assign) NSInteger level;
@property (nonatomic, assign) BOOL statusBarDisabled;
@property (nonatomic, assign) NSInteger interfaceOrientation;
@property (nonatomic, strong) id displayConfiguration;
@end

@interface UIApplicationSceneClientSettings : NSObject
@end

@interface UIMutableApplicationSceneClientSettings : UIApplicationSceneClientSettings
@property (nonatomic, assign) UIDeviceOrientation deviceOrientation;
@property (nonatomic, assign) NSInteger interfaceOrientation;
@property (nonatomic, assign) NSInteger statusBarStyle;
@end

@interface FBSSceneParameters : NSObject
@property (nonatomic, copy) UIApplicationSceneSettings *settings;
@property (nonatomic, copy) UIApplicationSceneClientSettings *clientSettings;
@end

@interface FBSMutableSceneParameters : FBSSceneParameters
@property (nonatomic, copy) UIMutableApplicationSceneSettings *settings;
+ (instancetype)parametersForSpecification:(FBSSceneSpecification *)spec;
@end

@interface BSCornerRadiusConfiguration : NSObject
- (instancetype)initWithTopLeft:(CGFloat)topLeft bottomLeft:(CGFloat)bottomLeft bottomRight:(CGFloat)bottomRight topRight:(CGFloat)topRight;
@end

@interface FBScene : NSObject
- (id)uiPresentationManager;
- (void)updateSettingsWithBlock:(void (^)(UIMutableApplicationSceneSettings *settings))block;
@end

@interface FBSceneManager : NSObject
+ (instancetype)sharedInstance;
- (FBScene *)createSceneWithDefinition:(id)definition initialParameters:(id)params;
- (void)destroyScene:(id)arg1 withTransitionContext:(id)arg2;
@end

@interface _UIScenePresentationView : UIView
@end

@interface UIMutableScenePresentationContext : NSObject
@property (nonatomic, assign) NSUInteger appearanceStyle;
@end

@interface _UIScenePresenter : NSObject
@property (nonatomic, assign, readonly) _UIScenePresentationView *presentationView;
@property (nonatomic, assign, readonly) FBScene *scene;
- (void)modifyPresentationContext:(void (^)(UIMutableScenePresentationContext *context))block;
- (void)activate;
- (void)deactivate;
- (void)invalidate;
@end

@interface UIScenePresentationManager : NSObject
- (_UIScenePresenter *)createPresenterWithIdentifier:(NSString *)identifier;
@end

@interface UIScreen (GHLSSScenePrivate)
- (id)displayConfiguration;
@end

// 感应带的视图：自己写的普通 UIView 子类，里面什么方法都没有
//（v18/v21 已证明它在 macOS 编的包里是安全的）。
@interface GHLSSPlainStripView : UIView
@end
@implementation GHLSSPlainStripView
@end

// 5.1 唯一的自定义处理类：手势与按钮的目标、启动器的主人、
// 5.2 托管悬浮窗的主人。视图全部用苹果的类，不再加自定义视图子类。
@interface GHLSSLauncher : NSObject <UIGestureRecognizerDelegate>
- (void)handleEdgeSwipe:(UIScreenEdgePanGestureRecognizer *)recognizer;
- (void)handleHandleButton:(id)sender;
- (void)handleAppButton:(UIButton *)sender;
- (void)handleCloseButton:(id)sender;
- (void)handleBackgroundTap:(UITapGestureRecognizer *)recognizer;
- (void)showLauncher;
- (void)dismissLauncher;
- (void)buildLauncherWindow;
- (void)launchHostedApp:(const char *)bundleID name:(const char *)name;
- (void)createHostedSceneForBundleID:(const char *)bundleID name:(const char *)name;
- (void)buildHostedWindowForBundleID:(const char *)bundleID name:(const char *)name scene:(FBScene *)scene presenter:(_UIScenePresenter *)presenter sceneID:(NSString *)sceneID pid:(int)pid;
- (void)closeHostedWindow;
- (void)minimizeHostedWindow;
- (void)restoreHostedWindow;
- (void)handleHostedClose:(id)sender;
- (void)handleHostedMinimize:(id)sender;
- (void)handleTitleDrag:(UIPanGestureRecognizer *)recognizer;
- (void)handleResizeDrag:(UIPanGestureRecognizer *)recognizer;
- (void)resizeHostedSceneToContentSize:(CGSize)size;
@end

// 窗与状态要一直留着（静态变量拿着，不会被释放）。
static UIWindow *GHLSSStripWindow = nil;
static UIWindow *GHLSSLauncherWindow = nil;
static GHLSSLauncher *GHLSSLauncherShared = nil;
static BOOL GHLSSLauncherVisible = NO;
// 上一次边缘滑动的时间（CFAbsoluteTime），用来做"滑两次才开"。
static double GHLSSLastSwipeTime = 0;

// 5.2 托管悬浮窗的状态（一个窗，见 V5_DESIGN.md §5.2）。
static UIWindow *GHLSSHostedWindow = nil;
static FBScene *GHLSSHostedScene = nil;
static _UIScenePresenter *GHLSSHostedPresenter = nil;
static UIView *GHLSSHostedContainer = nil;
static UIView *GHLSSHostedTitleBar = nil;
static UILabel *GHLSSHostedTitleLabel = nil;
static UIView *GHLSSHostedContentView = nil;
static UIView *GHLSSHostedResizeHandle = nil;
static NSString *GHLSSHostedSceneID = nil;
static char GHLSSHostedBundleID[128] = {0};
static int GHLSSHostedPid = 0;
static BOOL GHLSSHostedMinimized = NO;
static BOOL GHLSSHostedLaunching = NO;
// 悬浮窗的尺寸：内容区 320x480（竖屏）+ 44pt 标题栏；圆角 35。
#define GHLSS_HOSTED_CONTENT_W 320.0
#define GHLSS_HOSTED_CONTENT_H 480.0
#define GHLSS_HOSTED_TITLE_H 44.0
#define GHLSS_HOSTED_CORNER 35.0

// 取一个可用的 UIWindowScene（iOS 13+ 的窗必须挂 scene 才会显示）：
// 从 connectedScenes 里找第一个 UIWindowScene，没有就返回 nil
//（调用处记日志）。全部是公开 API 的方法调用，不用字串常量。
// 注意：不能用已废弃的取主窗口 API 做退路——它在 iOS 13 起已废弃，Theos
// 默认 -Werror 会把它当编译错误（v23 首编就是这么失败的）。
static UIWindowScene *GHLSSActiveWindowScene(void) {
UIApplication *app = [UIApplication sharedApplication];
if (!app) return nil;
NSSet *scenes = [app connectedScenes];
for (id s in scenes) {
if ([s isKindOfClass:[UIWindowScene class]]) return (UIWindowScene *)s;
}
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
GHLSSLogLine("v25 edge swipe 2nd, opening launcher");
[self showLauncher];
} else {
GHLSSLastSwipeTime = now;
GHLSSLogLine("v25 edge swipe 1st, armed");
}
}

// 金色"分"按钮：点一次就开启动器（备用触发，不用滑两次）。
- (void)handleHandleButton:(id)sender {
GHLSSLogLine("v25 handle button tapped, opening launcher");
[self showLauncher];
}

// 点启动器里的一个 App：v25 不再全屏打开（那条路在 SpringBoard 里
// 是死的：在 SpringBoard 里打开 App 返回 NO，四次全失败，还把主线程
// 堵 5 秒以上、触发看门狗重启）。
// 新流程：先收启动器，再在主线程走 FB 事务建 scene、嵌进悬浮窗。
// FB 事务是异步的：begin 立刻返回，场景创建走回调；主线程不被堵。
- (void)handleAppButton:(UIButton *)sender {
NSInteger idx = sender.tag;
if (idx < 0 || idx >= GHLSS_APP_COUNT) return;
const char *bid = GHLSSAppBundleIDs[idx];
const char *name = GHLSSAppNames[idx];
char buf[256];
snprintf(buf, sizeof(buf), "v25 app tapped %s", bid);
GHLSSLogLine(buf);
// 一个悬浮窗：已经有窗在，就不再开第二个。
if (GHLSSHostedWindow) {
if (GHLSSHostedMinimized && strcmp(GHLSSHostedBundleID, bid) == 0) {
[self restoreHostedWindow];
[self dismissLauncher];
return;
}
if (strcmp(GHLSSHostedBundleID, bid) == 0) {
GHLSSLogLine("v25 window already open");
[self dismissLauncher];
return;
}
snprintf(buf, sizeof(buf), "v25 window busy, ignoring tap %s", bid);
GHLSSLogLine(buf);
return;
}
if (GHLSSHostedLaunching) {
GHLSSLogLine("v25 launch in progress, ignoring tap");
return;
}
// 先收启动器（v23 卡死的教训：收窗是便宜操作，先做；
// 启动是慢操作，后做——但要在主线程做，v24 放后台队列崩了）。
[self dismissLauncher];
[self launchHostedApp:bid name:name];
}

// v25：启动必须在主线程做——v24 把它放后台队列，BSTransaction 的 begin
// 在里面断言当前队列是主队列（BSDispatchQueueAssert），直接把 SpringBoard
// 杀进安全模式（.ips：EXC_BREAKPOINT，-[BSTransaction begin]，后台队列）。
// 参考实现 FrontBoardAppLauncher 就是在主线程点按回调里做这一模一样的
// 调用。FB 事务本身是异步的：begin 立刻返回、完成走回调，主线程不会被堵
//（v23 那种 5 秒卡死是同步打开调用造成的，那条路已经删了，不会重演）。
// 每一步都记日志，下次再崩直接定位到具体调用。
- (void)launchHostedApp:(const char *)bundleID name:(const char *)name {
char *bidCopy = strdup(bundleID);
char *nameCopy = strdup(name);
if (!bidCopy || !nameCopy) {
if (bidCopy) free(bidCopy);
if (nameCopy) free(nameCopy);
GHLSSLogLine("v25 launch failed no memory");
return;
}
GHLSSHostedLaunching = YES;
char buf[256];
snprintf(buf, sizeof(buf), "v25 launch start %s", bundleID);
GHLSSLogLine(buf);
@try {
NSString *bidStr = [NSString stringWithCString:bidCopy encoding:NSUTF8StringEncoding];
if (!bidStr) {
GHLSSLogLine("v25 launch failed bad bundle id");
GHLSSHostedLaunching = NO;
free(bidCopy);
free(nameCopy);
return;
}
RBSProcessIdentity *identity = [RBSProcessIdentity identityForEmbeddedApplicationIdentifier:bidStr];
if (!identity) {
GHLSSLogLine("v25 launch failed no identity");
GHLSSHostedLaunching = NO;
free(bidCopy);
free(nameCopy);
return;
}
GHLSSLogLine("v25 identity ok");
// 先看 App 是不是已经在跑（单场景 App 已有全屏版时，再建
// 第二个 scene 可能只剩白窗——测前要先把目标 App 彻底关掉）。
RBSProcessPredicate *predicate = [RBSProcessPredicate predicateMatchingIdentity:identity];
RBSProcessHandle *handle = [RBSProcessHandle handleForPredicate:predicate error:nil];
int pid = handle ? [handle pid] : 0;
if (pid > 0) {
char pbuf[128];
snprintf(pbuf, sizeof(pbuf), "v25 app already running pid=%d", pid);
GHLSSLogLine(pbuf);
// 已经在跑：不走事务，直接去建 scene（和参考实现同一做法）。
dispatch_async(dispatch_get_main_queue(), ^{
[self createHostedSceneForBundleID:bidCopy name:nameCopy];
free(bidCopy);
free(nameCopy);
});
return;
}
GHLSSLogLine("v25 handle pid=0");
FBProcessManager *manager = [FBProcessManager sharedInstance];
if (!manager) {
GHLSSLogLine("v25 manager failed nil");
GHLSSHostedLaunching = NO;
free(bidCopy);
free(nameCopy);
return;
}
GHLSSLogLine("v25 manager ok");
FBApplicationProcessLaunchTransaction *transaction = [[FBApplicationProcessLaunchTransaction alloc] initWithProcessIdentity:identity executionContextProvider:^id(void) {
GHLSSLogLine("v25 launch provider called");
FBMutableProcessExecutionContext *context = [FBMutableProcessExecutionContext new];
context.identity = identity;
context.environment = [NSDictionary dictionary];
context.launchIntent = 4;
return [manager launchProcessWithContext:context];
}];
if (!transaction) {
GHLSSLogLine("v25 transaction failed nil");
GHLSSHostedLaunching = NO;
free(bidCopy);
free(nameCopy);
return;
}
GHLSSLogLine("v25 transaction created");
[transaction setCompletionBlock:^{
// 事务完成可能跑在任意队列——场景创建回主线程做。
dispatch_async(dispatch_get_main_queue(), ^{
[self createHostedSceneForBundleID:bidCopy name:nameCopy];
free(bidCopy);
free(nameCopy);
});
}];
[transaction begin];
GHLSSLogLine("v25 begin called");
GHLSSLogLine("v25 launch transaction begun");
} @catch (NSException *e) {
(void)e;
GHLSSLogLine("v25 launch failed exception");
GHLSSHostedLaunching = NO;
free(bidCopy);
free(nameCopy);
}
}

// 在主线程建 scene + presenter（V5_DESIGN.md §2.2 第 2–5 步）。
// 每一步都记日志、包 @try/@catch：任何一步失败只记日志，
// 绝不拖垮 SpringBoard。
- (void)createHostedSceneForBundleID:(const char *)bundleID name:(const char *)name {
@try {
char buf[256];
snprintf(buf, sizeof(buf), "v25 scene start %s", bundleID);
GHLSSLogLine(buf);
NSString *bidStr = [NSString stringWithCString:bundleID encoding:NSUTF8StringEncoding];
if (!bidStr) {
GHLSSLogLine("v25 scene failed no bid");
return;
}
RBSProcessIdentity *identity = [RBSProcessIdentity identityForEmbeddedApplicationIdentifier:bidStr];
RBSProcessPredicate *predicate = [RBSProcessPredicate predicateMatchingIdentity:identity];
RBSProcessHandle *handle = [RBSProcessHandle handleForPredicate:predicate error:nil];
int pid = handle ? [handle pid] : 0;
if (pid <= 0) {
GHLSSLogLine("v25 scene failed no process");
return;
}
snprintf(buf, sizeof(buf), "v25 process launched pid=%d", pid);
GHLSSLogLine(buf);
FBProcessManager *manager = [FBProcessManager sharedInstance];
[manager registerProcessForAuditToken:[handle auditToken]];
// 每次建窗都用新的 sceneID 与 persistenceIdentifier
//（复用会出“关窗后重开崩”的问题，见 V5_DESIGN.md §2.5 第 4 条）。
NSString *uuidStr = [[NSUUID UUID] UUIDString];
NSString *fmt = [NSString stringWithCString:"sceneID:%s-%s" encoding:NSUTF8StringEncoding];
NSString *sceneID = [NSString stringWithFormat:fmt, bundleID, [uuidStr UTF8String]];
FBSMutableSceneDefinition *definition = [FBSMutableSceneDefinition definition];
definition.identity = [FBSSceneIdentity identityForIdentifier:sceneID];
definition.clientIdentity = [FBSSceneClientIdentity identityForProcessIdentity:[handle identity]];
definition.specification = [UIApplicationSceneSpecification specification];
FBSMutableSceneParameters *parameters = [FBSMutableSceneParameters parametersForSpecification:definition.specification];
UIMutableApplicationSceneSettings *settings = [UIMutableApplicationSceneSettings new];
settings.canShowAlerts = YES;
settings.cornerRadiusConfiguration = [[BSCornerRadiusConfiguration alloc] initWithTopLeft:GHLSS_HOSTED_CORNER bottomLeft:GHLSS_HOSTED_CORNER bottomRight:GHLSS_HOSTED_CORNER topRight:GHLSS_HOSTED_CORNER];
settings.displayConfiguration = [[UIScreen mainScreen] displayConfiguration];
settings.foreground = YES;
settings.deviceOrientation = UIDeviceOrientationPortrait;
settings.interfaceOrientation = UIInterfaceOrientationPortrait;
settings.frame = CGRectMake(0, 0, GHLSS_HOSTED_CONTENT_W, GHLSS_HOSTED_CONTENT_H);
settings.level = 1;
settings.persistenceIdentifier = uuidStr;
settings.peripheryInsets = UIEdgeInsetsZero;
settings.safeAreaInsetsPortrait = UIEdgeInsetsZero;
settings.statusBarDisabled = YES;
parameters.settings = settings;
UIMutableApplicationSceneClientSettings *clientSettings = [UIMutableApplicationSceneClientSettings new];
clientSettings.interfaceOrientation = UIInterfaceOrientationPortrait;
clientSettings.statusBarStyle = 0;
parameters.clientSettings = clientSettings;
FBScene *scene = [[FBSceneManager sharedInstance] createSceneWithDefinition:definition initialParameters:parameters];
if (!scene) {
GHLSSLogLine("v25 scene failed nil scene");
return;
}
GHLSSLogLine("v25 scene created");
id presenterManager = [scene uiPresentationManager];
if (!presenterManager) {
GHLSSLogLine("v25 presenter failed no manager");
return;
}
_UIScenePresenter *presenter = [presenterManager createPresenterWithIdentifier:sceneID];
if (!presenter) {
GHLSSLogLine("v25 presenter failed nil");
return;
}
[presenter modifyPresentationContext:^(UIMutableScenePresentationContext *context) {
context.appearanceStyle = 2;
}];
[presenter activate];
if (!presenter.presentationView) {
GHLSSLogLine("v25 presenter failed no view");
return;
}
GHLSSLogLine("v25 presenter ready");
[self buildHostedWindowForBundleID:bundleID name:name scene:scene presenter:presenter sceneID:sceneID pid:pid];
} @catch (NSException *e) {
(void)e;
GHLSSLogLine("v25 scene failed exception");
} @finally {
GHLSSHostedLaunching = NO;
}
}

// 建 FV 风格的悬浮窗（V5_DESIGN.md §4.4 + 附录 D）：
// 圆角 35、有阴影、离屏幕边缘有距离、44pt 标题栏（可拖动）、
// 红关闭钮、黄最小化钮、右下角缩放手柄。内容区嵌 presenter 的 view。
- (void)buildHostedWindowForBundleID:(const char *)bundleID name:(const char *)name scene:(FBScene *)scene presenter:(_UIScenePresenter *)presenter sceneID:(NSString *)sceneID pid:(int)pid {
@try {
CGRect screenBounds = [UIScreen mainScreen].bounds;
CGFloat winW = GHLSS_HOSTED_CONTENT_W;
CGFloat winH = GHLSS_HOSTED_CONTENT_H + GHLSS_HOSTED_TITLE_H;
CGRect winFrame = CGRectMake((screenBounds.size.width - winW) / 2.0, (screenBounds.size.height - winH) / 2.0, winW, winH);
GHLSSHostedWindow = [[UIWindow alloc] initWithFrame:winFrame];
GHLSSHostedWindow.windowLevel = UIWindowLevelAlert + 2.0;
GHLSSHostedWindow.backgroundColor = [UIColor clearColor];
UIWindowScene *hostedScene = GHLSSActiveWindowScene();
if (hostedScene) {
GHLSSHostedWindow.windowScene = hostedScene;
} else {
GHLSSLogLine("v25 hosted scene nil");
}
// 窗的阴影与圆角（画在窗的 layer 上；内容容器自己裁圆角）。
GHLSSHostedWindow.layer.cornerRadius = GHLSS_HOSTED_CORNER;
GHLSSHostedWindow.layer.shadowColor = [UIColor blackColor].CGColor;
GHLSSHostedWindow.layer.shadowOpacity = 0.5;
GHLSSHostedWindow.layer.shadowRadius = 12.0;
GHLSSHostedWindow.layer.shadowOffset = CGSizeMake(0, 6);
UIViewController *vc = [[UIViewController alloc] init];
// 内容容器：圆角 35、裁掉超出部分、细边框。
UIView *container = [[UIView alloc] initWithFrame:CGRectMake(0, 0, winW, winH)];
container.backgroundColor = [UIColor whiteColor];
container.layer.cornerRadius = GHLSS_HOSTED_CORNER;
container.layer.masksToBounds = YES;
container.layer.borderWidth = 1.0;
container.layer.borderColor = [UIColor colorWithWhite:0.8 alpha:1.0].CGColor;
vc.view = container;
GHLSSHostedContainer = container;
// 标题栏（44pt，深色，可拖动）。
UIView *titleBar = [[UIView alloc] initWithFrame:CGRectMake(0, 0, winW, GHLSS_HOSTED_TITLE_H)];
titleBar.backgroundColor = [UIColor colorWithRed:0.15 green:0.15 blue:0.15 alpha:1.0];
[container addSubview:titleBar];
GHLSSHostedTitleBar = titleBar;
UIPanGestureRecognizer *dragGesture = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handleTitleDrag:)];
dragGesture.minimumNumberOfTouches = 1;
dragGesture.maximumNumberOfTouches = 1;
[titleBar addGestureRecognizer:dragGesture];
// 关闭钮（红圆，左）。
UIButton *closeBtn = [UIButton buttonWithType:UIButtonTypeCustom];
closeBtn.frame = CGRectMake(10, 9, 26, 26);
closeBtn.backgroundColor = [UIColor colorWithRed:1.0 green:0.23 blue:0.19 alpha:1.0];
closeBtn.layer.cornerRadius = 13.0;
[closeBtn setTitle:[NSString stringWithCString:"x" encoding:NSUTF8StringEncoding] forState:UIControlStateNormal];
[closeBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
closeBtn.titleLabel.font = [UIFont boldSystemFontOfSize:14];
[closeBtn addTarget:self action:@selector(handleHostedClose:) forControlEvents:UIControlEventTouchUpInside];
[titleBar addSubview:closeBtn];
// 最小化钮（黄圆，左二）：只藏窗、不销毁 scene（5.3 再做贴边）。
UIButton *minBtn = [UIButton buttonWithType:UIButtonTypeCustom];
minBtn.frame = CGRectMake(44, 9, 26, 26);
minBtn.backgroundColor = [UIColor colorWithRed:1.0 green:0.76 blue:0.03 alpha:1.0];
minBtn.layer.cornerRadius = 13.0;
[minBtn setTitle:[NSString stringWithCString:"-" encoding:NSUTF8StringEncoding] forState:UIControlStateNormal];
[minBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
minBtn.titleLabel.font = [UIFont boldSystemFontOfSize:14];
[minBtn addTarget:self action:@selector(handleHostedMinimize:) forControlEvents:UIControlEventTouchUpInside];
[titleBar addSubview:minBtn];
// 标题：App 名，居中。
UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(78, 0, winW - 156, GHLSS_HOSTED_TITLE_H)];
titleLabel.text = [NSString stringWithCString:name encoding:NSUTF8StringEncoding];
titleLabel.textColor = [UIColor whiteColor];
titleLabel.font = [UIFont boldSystemFontOfSize:16];
titleLabel.textAlignment = NSTextAlignmentCenter;
[titleBar addSubview:titleLabel];
GHLSSHostedTitleLabel = titleLabel;
// 内容区：presenter 的 view 嵌在这里（标题栏之下）。
UIView *contentView = [[UIView alloc] initWithFrame:CGRectMake(0, GHLSS_HOSTED_TITLE_H, winW, GHLSS_HOSTED_CONTENT_H)];
contentView.backgroundColor = [UIColor whiteColor];
[container addSubview:contentView];
GHLSSHostedContentView = contentView;
UIView *presenterView = presenter.presentationView;
presenterView.frame = contentView.bounds;
presenterView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
[contentView insertSubview:presenterView atIndex:0];
// 右下角缩放手柄（60x60，斜纹小方块）。
UIView *resizeHandle = [[UIView alloc] initWithFrame:CGRectMake(winW - 60, winH - 60, 60, 60)];
resizeHandle.backgroundColor = [UIColor clearColor];
resizeHandle.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleTopMargin;
UIView *grip = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 60 / 1.4142, 60 / 1.4142)];
grip.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.2];
grip.center = CGPointMake(60, 60);
grip.transform = CGAffineTransformMakeRotation(3.14159265 / 4.0);
[resizeHandle addSubview:grip];
UIPanGestureRecognizer *resizeGesture = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handleResizeDrag:)];
resizeGesture.minimumNumberOfTouches = 1;
resizeGesture.maximumNumberOfTouches = 1;
[resizeHandle addGestureRecognizer:resizeGesture];
[container addSubview:resizeHandle];
GHLSSHostedResizeHandle = resizeHandle;
GHLSSHostedWindow.rootViewController = vc;
GHLSSHostedWindow.hidden = NO;
GHLSSHostedScene = scene;
GHLSSHostedPresenter = presenter;
GHLSSHostedSceneID = sceneID;
strncpy(GHLSSHostedBundleID, bundleID, sizeof(GHLSSHostedBundleID) - 1);
GHLSSHostedBundleID[sizeof(GHLSSHostedBundleID) - 1] = '\0';
GHLSSHostedPid = pid;
GHLSSHostedMinimized = NO;
GHLSSLogLine("v25 window shown");
} @catch (NSException *e) {
(void)e;
GHLSSLogLine("v25 window failed exception");
}
}

// 关窗：销毁 scene、停 presenter；进程留着不杀
//（V5_DESIGN.md §2.2 第 19 步：关窗只销毁 scene、不杀进程）。
- (void)closeHostedWindow {
if (!GHLSSHostedWindow) return;
@try {
if (GHLSSHostedSceneID) {
[[FBSceneManager sharedInstance] destroyScene:GHLSSHostedSceneID withTransitionContext:nil];
}
if (GHLSSHostedPresenter) {
[GHLSSHostedPresenter deactivate];
[GHLSSHostedPresenter invalidate];
}
} @catch (NSException *e) {
(void)e;
GHLSSLogLine("v25 close failed");
}
GHLSSHostedWindow.hidden = YES;
GHLSSHostedWindow = nil;
GHLSSHostedScene = nil;
GHLSSHostedPresenter = nil;
GHLSSHostedContainer = nil;
GHLSSHostedTitleBar = nil;
GHLSSHostedTitleLabel = nil;
GHLSSHostedContentView = nil;
GHLSSHostedResizeHandle = nil;
GHLSSHostedSceneID = nil;
GHLSSHostedBundleID[0] = '\0';
GHLSSHostedPid = 0;
GHLSSHostedMinimized = NO;
if (GHLSSLauncherWindow) {
GHLSSLauncherWindow.windowLevel = UIWindowLevelAlert + 1.0;
}
GHLSSLogLine("v25 window closed");
}

- (void)minimizeHostedWindow {
if (!GHLSSHostedWindow || GHLSSHostedMinimized) return;
GHLSSHostedWindow.hidden = YES;
GHLSSHostedMinimized = YES;
GHLSSLogLine("v25 window minimized");
}

- (void)restoreHostedWindow {
if (!GHLSSHostedWindow || !GHLSSHostedMinimized) return;
GHLSSHostedWindow.hidden = NO;
GHLSSHostedMinimized = NO;
GHLSSLogLine("v25 window restored");
}

- (void)handleHostedClose:(id)sender {
GHLSSLogLine("v25 hosted close tapped");
[self closeHostedWindow];
}

- (void)handleHostedMinimize:(id)sender {
GHLSSLogLine("v25 hosted minimize tapped");
[self minimizeHostedWindow];
}

// 拖标题栏移动窗口（参考实现的 moveWindow 做法：取位移、
// 加到中心点上、位移清零；位置夹在屏幕里，不让窗丢出去）。
- (void)handleTitleDrag:(UIPanGestureRecognizer *)recognizer {
if (!GHLSSHostedWindow) return;
CGPoint point = [recognizer translationInView:GHLSSHostedWindow];
[recognizer setTranslation:CGPointZero inView:GHLSSHostedWindow];
CGPoint center = GHLSSHostedWindow.center;
CGRect screenBounds = [UIScreen mainScreen].bounds;
CGFloat minX = 80.0;
CGFloat maxX = screenBounds.size.width - 80.0;
CGFloat minY = 100.0;
CGFloat maxY = screenBounds.size.height - 100.0;
CGFloat newX = center.x + point.x;
CGFloat newY = center.y + point.y;
if (newX < minX) newX = minX;
if (newX > maxX) newX = maxX;
if (newY < minY) newY = minY;
if (newY > maxY) newY = maxY;
GHLSSHostedWindow.center = CGPointMake(newX, newY);
}

// 拖右下角手柄改窗大小：拖动时只改窗与视图（live）；
// 松手时才调 scene 的 frame（V5_DESIGN.md §2.2：改尺寸防抖，
// 拖动时不要每次移动都调一次）。
- (void)handleResizeDrag:(UIPanGestureRecognizer *)recognizer {
if (!GHLSSHostedWindow || !GHLSSHostedContainer || !GHLSSHostedContentView) return;
CGPoint point = [recognizer translationInView:GHLSSHostedContainer];
[recognizer setTranslation:CGPointZero inView:GHLSSHostedContainer];
CGRect screenBounds = [UIScreen mainScreen].bounds;
CGRect frame = GHLSSHostedWindow.frame;
CGFloat newW = frame.size.width + point.x;
CGFloat newH = frame.size.height + point.y;
if (newW < 200.0) newW = 200.0;
if (newW > screenBounds.size.width - 16.0) newW = screenBounds.size.width - 16.0;
if (newH < 300.0) newH = 300.0;
if (newH > screenBounds.size.height - 120.0) newH = screenBounds.size.height - 120.0;
GHLSSHostedWindow.frame = CGRectMake(frame.origin.x, frame.origin.y, newW, newH);
GHLSSHostedContainer.frame = CGRectMake(0, 0, newW, newH);
GHLSSHostedTitleBar.frame = CGRectMake(0, 0, newW, GHLSS_HOSTED_TITLE_H);
GHLSSHostedTitleLabel.frame = CGRectMake(78, 0, newW - 156, GHLSS_HOSTED_TITLE_H);
GHLSSHostedContentView.frame = CGRectMake(0, GHLSS_HOSTED_TITLE_H, newW, newH - GHLSS_HOSTED_TITLE_H);
if (recognizer.state == UIGestureRecognizerStateEnded) {
[self resizeHostedSceneToContentSize:CGSizeMake(newW, newH - GHLSS_HOSTED_TITLE_H)];
}
}

// 松手后把新内容尺寸告诉 scene（只在松手时调一次）。
- (void)resizeHostedSceneToContentSize:(CGSize)size {
if (!GHLSSHostedScene) return;
@try {
[GHLSSHostedScene updateSettingsWithBlock:^(UIMutableApplicationSceneSettings *settings) {
settings.frame = CGRectMake(0, 0, size.width, size.height);
settings.interfaceOrientation = UIInterfaceOrientationPortrait;
settings.deviceOrientation = UIDeviceOrientationPortrait;
}];
char buf[128];
snprintf(buf, sizeof(buf), "v25 scene resized %d,%d", (int)size.width, (int)size.height);
GHLSSLogLine(buf);
} @catch (NSException *e) {
(void)e;
GHLSSLogLine("v25 scene resize failed");
}
}

- (void)handleCloseButton:(id)sender {
GHLSSLogLine("v25 close button tapped");
[self dismissLauncher];
}

- (void)handleBackgroundTap:(UITapGestureRecognizer *)recognizer {
GHLSSLogLine("v25 background tapped, dismissing launcher");
[self dismissLauncher];
}

- (void)showLauncher {
if (GHLSSLauncherVisible) {
GHLSSLogLine("v25 launcher already open");
return;
}
if (!GHLSSLauncherWindow) {
[self buildLauncherWindow];
}
// 有悬浮窗在时，启动器要升到它上面（不然会被盖住一半）。
if (GHLSSHostedWindow) {
GHLSSLauncherWindow.windowLevel = UIWindowLevelAlert + 3.0;
} else {
GHLSSLauncherWindow.windowLevel = UIWindowLevelAlert + 1.0;
}
GHLSSLauncherWindow.hidden = NO;
GHLSSLauncherVisible = YES;
GHLSSLogLine("v25 launcher opened");
}

- (void)dismissLauncher {
if (!GHLSSLauncherVisible) return;
GHLSSLauncherWindow.hidden = YES;
GHLSSLauncherVisible = NO;
GHLSSLogLine("v25 launcher dismissed");
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
GHLSSLogLine("v25 launcher scene found");
} else {
GHLSSLogLine("v25 launcher scene nil");
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
// 5 个 App 行：图标 + 名字，点一行在悬浮窗里打开那个 App。
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
snprintf(ibuf, sizeof(ibuf), "v25 icon nil for %s", GHLSSAppBundleIDs[i]);
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
GHLSSLogLine("v25 launcher built");
}

@end

%ctor {
// v25 的 %ctor 和 v21/v22/v23/v24 一模一样，只做一行纯 C 调用：
// 5 秒后在主队列跑一个 block。不登记通知、不写日志、不读文件、
// 不调系统日志、不建窗、不 hook。
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
snprintf(buf, sizeof(buf), "v25 deferred setup ran, switch=%s", state);
GHLSSLogLine("v25 deferred setup ran");
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
GHLSSLogLine("v25 window scene found");
} else {
GHLSSLogLine("v25 window scene nil");
}
UIViewController *stripVC = [[UIViewController alloc] init];
GHLSSPlainStripView *stripView = [[GHLSSPlainStripView alloc] initWithFrame:CGRectMake(0, 0, stripWidth, screenBounds.size.height)];
stripView.backgroundColor = [UIColor clearColor];
stripVC.view = stripView;
GHLSSStripWindow.rootViewController = stripVC;
GHLSSStripWindow.hidden = NO;
GHLSSLogLine("v25 edge strip built");
// 诊断日志：窗与带子到底是什么状态（真机一看就知道上没上屏）。
char dbuf[256];
CGRect wf = GHLSSStripWindow.frame;
snprintf(dbuf, sizeof(dbuf), "v25 window frame=%d,%d,%d,%d hidden=%d scene=%s", (int)wf.origin.x, (int)wf.origin.y, (int)wf.size.width, (int)wf.size.height, GHLSSStripWindow.hidden ? 1 : 0, GHLSSStripWindow.windowScene ? "ok" : "nil");
GHLSSLogLine(dbuf);
CGRect sf = stripView.frame;
snprintf(dbuf, sizeof(dbuf), "v25 strip frame=%d,%d,%d,%d", (int)sf.origin.x, (int)sf.origin.y, (int)sf.size.width, (int)sf.size.height);
GHLSSLogLine(dbuf);
// 5.1 的处理器（唯一的自定义处理类）。
GHLSSLauncherShared = [[GHLSSLauncher alloc] init];
// 右边缘滑动手势（挂在感应带上）。
UIScreenEdgePanGestureRecognizer *edgePan = [[UIScreenEdgePanGestureRecognizer alloc] initWithTarget:GHLSSLauncherShared action:@selector(handleEdgeSwipe:)];
edgePan.edges = UIRectEdgeRight;
edgePan.delegate = GHLSSLauncherShared;
[stripView addGestureRecognizer:edgePan];
GHLSSLogLine("v25 edge gesture added");
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
GHLSSLogLine("v25 handle button added");
CGRect bf = handleButton.frame;
snprintf(dbuf, sizeof(dbuf), "v25 button frame=%d,%d,%d,%d", (int)bf.origin.x, (int)bf.origin.y, (int)bf.size.width, (int)bf.size.height);
GHLSSLogLine(dbuf);
});
}
