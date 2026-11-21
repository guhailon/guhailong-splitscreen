// GHLSSKeyboardHelper — 顧海龍分屏鍵盤助手（v43.5，1.0.80）
// 原創代碼。塞進 App 進程（不是 SpringBoard），只做兩件事：
// (1) 橋接：App 行程收得到 UIKeyboard 通知，SpringBoard 收不到——
//     這裡收到就寫 kbNotifyInfo（"<包名>|<鍵盤高>"）再 notify_post
//     Darwin 通知，SpringBoard 側用 notify_register_dispatch 接，
//     內彈出上移／外彈出關窗／橫屏放大才真正生效。
// (2) 真外置鍵盤（實驗，預設關）：kill switch keyboardExternalEnabled
//     開著＋當方向外彈出＋本 App 正被託管成浮窗時，才把鍵盤窗的
//     frame 移到屏幕底部全寬。只動 frame，不攔按鍵、不碰 first
//     responder、不改鍵盤內部視圖；開關每彈一次鍵盤重讀，關了下次
//     就恢復原樣，不用 respring。
// 安全邊界：%ctor 先排 bundle——SpringBoard、抖音（兩個包名，
// DYYY.plist Filter 原文）、設定 App（kill switch 必須永遠能關）
// 都不進；全屏 App 不動（鍵盤本來就在屏幕底部全寬，移了等於沒移；
// 另有 keyWindow 尺寸比對守衛）。橫屏鍵盤能不能真的出浮窗外，
// 要 Lee 真機測（鍵盤窗在託管 scene 裡怎麼合成，沒真機證實不了）。
// 參考：Konban（nicho1asdev/Konban，MIT）README 寫鍵盤在託管視圖裡
// 看不見但能打字；floatingView 實拍證明外置鍵盤存在，但它是付費
// 閉源、無代碼可抄——這裡是自己從頭寫的做法。
// 注意：本檔禁用 ObjC 字串與裝箱字面量（會產生 __cfstring 段），
// 全部字串走 C 字串＋stringWithCString／CFStringCreateWithCString。

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <CoreFoundation/CoreFoundation.h>
#import <notify.h>
#import <objc/runtime.h>
#import <string.h>
#import <stdio.h>
#import <stdlib.h>

#define GHLSS_KB_DOMAIN "com.guhailong.splitscreen"
#define GHLSS_KB_LOG_PATH "/var/mobile/Library/Logs/GuHaiLongSplitScreen.log"
#define GHLSS_KB_NOTIFY_SHOW "com.guhailong.splitscreen.keyboardWillShow"
#define GHLSS_KB_NOTIFY_HIDE "com.guhailong.splitscreen.keyboardDidHide"
#define GHLSS_KB_INFO_KEY "kbNotifyInfo"

static void GHLSSKBLogLine(const char *line) {
    FILE *f = fopen(GHLSS_KB_LOG_PATH, "a");
    if (f) {
        fputs(line, f);
        fputc('\n', f);
        fclose(f);
    }
}

static BOOL GHLSSKBReadPrefsBool(const char *key, BOOL defaultValue) {
    if (!key) return defaultValue;
    CFStringRef domain = CFStringCreateWithCString(NULL, GHLSS_KB_DOMAIN, kCFStringEncodingUTF8);
    CFStringRef keyRef = CFStringCreateWithCString(NULL, key, kCFStringEncodingUTF8);
    BOOL result = defaultValue;
    if (domain && keyRef) {
        CFPreferencesAppSynchronize(domain);
        CFPropertyListRef v = CFPreferencesCopyAppValue(keyRef, domain);
        if (v) {
            if (CFGetTypeID(v) == CFBooleanGetTypeID()) {
                result = CFBooleanGetValue((CFBooleanRef)v);
            }
            CFRelease(v);
        }
    }
    if (domain) CFRelease(domain);
    if (keyRef) CFRelease(keyRef);
    return result;
}

// v43.18：讀一個 prefs double（沒設就回預設值），外置鍵盤圓角用。
static double GHLSSKBReadPrefsDouble(const char *key, double defaultValue) {
    if (!key) return defaultValue;
    CFStringRef domain = CFStringCreateWithCString(NULL, GHLSS_KB_DOMAIN, kCFStringEncodingUTF8);
    CFStringRef keyRef = CFStringCreateWithCString(NULL, key, kCFStringEncodingUTF8);
    double result = defaultValue;
    if (domain && keyRef) {
        CFPreferencesAppSynchronize(domain);
        CFPropertyListRef v = CFPreferencesCopyAppValue(keyRef, domain);
        if (v) {
            if (CFGetTypeID(v) == CFNumberGetTypeID()) {
                double d = 0;
                if (CFNumberGetValue((CFNumberRef)v, kCFNumberDoubleType, &d)) result = d;
            }
            CFRelease(v);
        }
    }
    if (domain) CFRelease(domain);
    if (keyRef) CFRelease(keyRef);
    return result;
}

static char *GHLSSKBReadPrefsCString(const char *key) {
    if (!key) return NULL;
    CFStringRef domain = CFStringCreateWithCString(NULL, GHLSS_KB_DOMAIN, kCFStringEncodingUTF8);
    CFStringRef keyRef = CFStringCreateWithCString(NULL, key, kCFStringEncodingUTF8);
    char *out = NULL;
    if (domain && keyRef) {
        CFPreferencesAppSynchronize(domain);
        CFPropertyListRef v = CFPreferencesCopyAppValue(keyRef, domain);
        if (v) {
            if (CFGetTypeID(v) == CFStringGetTypeID()) {
                CFIndex len = CFStringGetLength((CFStringRef)v);
                CFIndex maxBytes = CFStringGetMaximumSizeForEncoding(len, kCFStringEncodingUTF8) + 1;
                out = (char *)malloc(maxBytes);
                if (out && !CFStringGetCString((CFStringRef)v, out, maxBytes, kCFStringEncodingUTF8)) {
                    free(out);
                    out = NULL;
                }
            }
            CFRelease(v);
        }
    }
    if (domain) CFRelease(domain);
    if (keyRef) CFRelease(keyRef);
    return out;
}

static void GHLSSKBWritePrefsCString(const char *key, const char *value) {
    if (!key) return;
    CFStringRef domain = CFStringCreateWithCString(NULL, GHLSS_KB_DOMAIN, kCFStringEncodingUTF8);
    CFStringRef keyRef = CFStringCreateWithCString(NULL, key, kCFStringEncodingUTF8);
    if (domain && keyRef) {
        if (value && value[0] != '\0') {
            CFStringRef valRef = CFStringCreateWithCString(NULL, value, kCFStringEncodingUTF8);
            if (valRef) {
                CFPreferencesSetAppValue(keyRef, valRef, domain);
                CFRelease(valRef);
            }
        }
        CFPreferencesAppSynchronize(domain);
    }
    if (domain) CFRelease(domain);
    if (keyRef) CFRelease(keyRef);
}

// v43.18：鍵盤模式合一（跟 SpringBoard 側同一語義）：0＝浮窗內彈出，
// 1＝外彈出。先讀單鍵 keyboardMode；沒有讀分向舊鍵；再讀舊單鍵
// keyboardPopupMode；最後預設豎屏內彈出／橫屏外彈出照舊。
static int GHLSSKBReadKeyboardPopupMode(void) {
    CGRect sb = [UIScreen mainScreen].bounds;
    BOOL landscape = sb.size.width > sb.size.height;
    char *mode = GHLSSKBReadPrefsCString("keyboardMode");
    if (!mode) mode = GHLSSKBReadPrefsCString(landscape ? "keyboardPopupModeLandscape" : "keyboardPopupModePortrait");
    if (!mode) mode = GHLSSKBReadPrefsCString("keyboardPopupMode");
    int m = landscape ? 1 : 0;
    if (mode) {
        m = (strcmp(mode, "outer") == 0) ? 1 : 0;
        free(mode);
    }
    return m;
}

static UIWindow *GHLSSKBFindKeyboardWindow(void) {
    UIApplication *app = [UIApplication sharedApplication];
    if (!app) return nil;
    for (id sc in [app connectedScenes]) {
        if (![sc isKindOfClass:[UIWindowScene class]]) continue;
        for (UIWindow *w in [(UIWindowScene *)sc windows]) {
            const char *cls = class_getName([w class]);
            if (cls && strstr(cls, "Keyboard")) return w;
        }
    }
    return nil;
}

static UIWindow *GHLSSKBKeyWindow(void) {
    UIApplication *app = [UIApplication sharedApplication];
    if (!app) return nil;
    for (id sc in [app connectedScenes]) {
        if (![sc isKindOfClass:[UIWindowScene class]]) continue;
        UIWindow *kw = [(UIWindowScene *)sc keyWindow];
        if (kw) return kw;
    }
    return nil;
}

static UIWindow *GHLSSKBDragTarget = nil;

@interface GHLSSKeyboardHelper : NSObject
+ (instancetype)shared;
- (void)handleKeyboardWillShow:(NSNotification *)note;
- (void)handleKeyboardWillHide:(NSNotification *)note;
- (void)handleKeyboardDrag:(UIPanGestureRecognizer *)recognizer;
@end

@implementation GHLSSKeyboardHelper

+ (instancetype)shared {
    static GHLSSKeyboardHelper *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[GHLSSKeyboardHelper alloc] init];
    });
    return instance;
}

- (void)handleKeyboardWillShow:(NSNotification *)note {
    char bid[128] = {0};
    NSString *bidStr = [[NSBundle mainBundle] bundleIdentifier];
    if (bidStr) {
        [bidStr getCString:bid maxLength:sizeof(bid) encoding:NSUTF8StringEncoding];
    }
    NSDictionary *info = note.userInfo;
    NSValue *frameValue = info ? [info objectForKey:UIKeyboardFrameEndUserInfoKey] : nil;
    CGFloat kbHeight = 0;
    if (frameValue) {
        CGRect kf = [frameValue CGRectValue];
        kbHeight = kf.size.height;
    }
    // (1) 橋接：不管 kill switch 開不開，都把這次鍵盤事件告訴 SpringBoard。
    char infoBuf[256];
    snprintf(infoBuf, sizeof(infoBuf), "%s|%d", bid, (int)kbHeight);
    GHLSSKBWritePrefsCString(GHLSS_KB_INFO_KEY, infoBuf);
    notify_post(GHLSS_KB_NOTIFY_SHOW);
    {
        char buf[256];
        snprintf(buf, sizeof(buf), "v43.5 kb-helper notify show %s %d", bid, (int)kbHeight);
        GHLSSKBLogLine(buf);
    }
    // (2) 真外置：三道門——kill switch、當方向外彈出、本 App 正被託管。
    if (!GHLSSKBReadPrefsBool("keyboardExternalEnabled", NO)) return;
    if (GHLSSKBReadKeyboardPopupMode() != 1) return;
    CGRect screenBounds = [UIScreen mainScreen].bounds;
    UIWindow *keyWindow = GHLSSKBKeyWindow();
    if (!keyWindow) return;
    CGSize winSize = keyWindow.bounds.size;
    if (winSize.width == screenBounds.size.width && winSize.height == screenBounds.size.height) return;
    UIWindow *kbWindow = GHLSSKBFindKeyboardWindow();
    if (!kbWindow) {
        GHLSSKBLogLine("v43.5 kb-helper no keyboard window");
        return;
    }
    CGRect oldFrame = kbWindow.frame;
    CGFloat newH = kbHeight > 0 ? kbHeight : oldFrame.size.height;
    CGRect newFrame = CGRectMake(0, screenBounds.size.height - newH, screenBounds.size.width, newH);
    kbWindow.frame = newFrame;
    {
        char buf[256];
        snprintf(buf, sizeof(buf), "v43.5 kb-helper keyboard moved %dx%d@%d,%d -> %dx%d@%d,%d",
            (int)oldFrame.size.width, (int)oldFrame.size.height, (int)oldFrame.origin.x, (int)oldFrame.origin.y,
            (int)newFrame.size.width, (int)newFrame.size.height, (int)newFrame.origin.x, (int)newFrame.origin.y);
        GHLSSKBLogLine(buf);
    }
    // v43.18：外置鍵盤圓角——每次 show 都重套一次（系統可能重置）。
    // 0 就是不設；跑到這裡時殺開關開著且模式是外置（上面三道門已過）。
    double kbRadius = GHLSSKBReadPrefsDouble("externalKeyboardCornerRadius", 30.0);
    if (kbRadius > 0) {
        kbWindow.layer.cornerRadius = (CGFloat)kbRadius;
        kbWindow.layer.masksToBounds = YES;
        char rbuf[128];
        snprintf(rbuf, sizeof(rbuf), "v43.18 kb-helper keyboard corner radius %d", (int)kbRadius);
        GHLSSKBLogLine(rbuf);
    }
    // 橫屏拖外置鍵盤：只在橫屏＋開關開著時掛手勢（鍵盤窗還活著就一直掛著，
    // 手勢裡每次都重讀開關，關了就不動）。
    BOOL landscape = screenBounds.size.width > screenBounds.size.height;
    if (landscape && GHLSSKBReadPrefsBool("landscapeMoveExternalKeyboard", NO)) {
        if (kbWindow != GHLSSKBDragTarget) {
            GHLSSKBDragTarget = kbWindow;
            UIPanGestureRecognizer *drag = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handleKeyboardDrag:)];
            drag.cancelsTouchesInView = NO;
            [kbWindow addGestureRecognizer:drag];
            GHLSSKBLogLine("v43.5 kb-helper drag attached");
        }
    }
}

- (void)handleKeyboardWillHide:(NSNotification *)note {
    (void)note;
    char bid[128] = {0};
    NSString *bidStr = [[NSBundle mainBundle] bundleIdentifier];
    if (bidStr) {
        [bidStr getCString:bid maxLength:sizeof(bid) encoding:NSUTF8StringEncoding];
    }
    char infoBuf[192];
    snprintf(infoBuf, sizeof(infoBuf), "%s|0", bid);
    GHLSSKBWritePrefsCString(GHLSS_KB_INFO_KEY, infoBuf);
    notify_post(GHLSS_KB_NOTIFY_HIDE);
    {
        char buf[192];
        snprintf(buf, sizeof(buf), "v43.5 kb-helper notify hide %s", bid);
        GHLSSKBLogLine(buf);
    }
}

- (void)handleKeyboardDrag:(UIPanGestureRecognizer *)recognizer {
    UIWindow *kbWindow = (UIWindow *)recognizer.view;
    if (!kbWindow) return;
    if (!GHLSSKBReadPrefsBool("keyboardExternalEnabled", NO)) return;
    if (GHLSSKBReadKeyboardPopupMode() != 1) return;
    if (!GHLSSKBReadPrefsBool("landscapeMoveExternalKeyboard", NO)) return;
    CGRect screenBounds = [UIScreen mainScreen].bounds;
    if (screenBounds.size.width <= screenBounds.size.height) return;
    CGPoint t = [recognizer translationInView:kbWindow];
    [recognizer setTranslation:CGPointZero inView:kbWindow];
    CGRect f = kbWindow.frame;
    CGFloat nx = f.origin.x + t.x;
    CGFloat ny = f.origin.y + t.y;
    if (nx < 0) nx = 0;
    if (nx > screenBounds.size.width - f.size.width) nx = screenBounds.size.width - f.size.width;
    if (ny < 0) ny = 0;
    if (ny > screenBounds.size.height - f.size.height) ny = screenBounds.size.height - f.size.height;
    kbWindow.frame = CGRectMake(nx, ny, f.size.width, f.size.height);
    if (recognizer.state == UIGestureRecognizerStateEnded) {
        char buf[128];
        snprintf(buf, sizeof(buf), "v43.5 kb-helper keyboard dragged to %d,%d", (int)nx, (int)ny);
        GHLSSKBLogLine(buf);
    }
}

@end

%ctor {
    // 排 bundle：SpringBoard（主 dylib 的地盤）、抖音兩個包名
    // （DYYY.plist Filter 原文，分工：抖音歸主聊天）、設定 App
    // （kill switch 必須永遠關得掉）。其他 UIKit App 都進。
    NSString *bidStr = [[NSBundle mainBundle] bundleIdentifier];
    char bid[128] = {0};
    if (bidStr) {
        [bidStr getCString:bid maxLength:sizeof(bid) encoding:NSUTF8StringEncoding];
    }
    static const char *excluded[] = {"com.apple.springboard", "com.ss.iphone.ugc.Aweme", "com.ss.iphone.ugc.aweme.lite", "com.apple.Preferences"};
    size_t n = sizeof(excluded) / sizeof(excluded[0]);
    for (size_t i = 0; i < n; i++) {
        if (strcmp(bid, excluded[i]) == 0) return;
    }
    GHLSSKeyboardHelper *helper = [GHLSSKeyboardHelper shared];
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    [nc addObserver:helper selector:@selector(handleKeyboardWillShow:) name:UIKeyboardWillShowNotification object:nil];
    [nc addObserver:helper selector:@selector(handleKeyboardWillHide:) name:UIKeyboardWillHideNotification object:nil];
}
