// 顾海龙集团分屏 — 设置页（PreferenceLoader）。
// v50：主頁順序＝版本頭／搜索／狀態／三屏／ARC／浮窗／其他四大分類／
// 常用開關／布局預設／配置方案／手勢總覽／操作性功能（含檢查更新）／
// 新手模式殿後；子頁是獨立 plist（浮窗／三屏／ARC／其他＋調度／陰影／
// 橫幅／鍵盤／搜索／桌面圖標／懸浮圖標／ARC 按鈕／兩個排序頁＋手勢自定義／
// 狀態頁），由 PreferenceLoader 的預設控制器
// 載入；「選擇應用」是動態頁（GHLSSAppPickerListController，下面），
// 按後台緩存的已安裝 App 清單即時建開關；日誌查看器、三屏組合、卡片頭像／
// 背景圖、搜索、手勢總覽、配置方案、每頁重置也都是動態頁（下面）。
//
// 注意（2026-11-12）：这个文件以前用写死字串和 CFSTR，设置一打开
// 就闪退——和 SpringBoard 那边一样，咱们这套工具链编出来的写死
// 字串是坏的。所以这里一个写死的字串都不能用：名字、路径、键名
// 全在运行时现做（CFStringCreateWithCString / stringWithCString），
// 读写开关直接用 CFPreferences（v13 证实过这条路是通的）。
// 以前还发过一个 Darwin 通知，现在不发了：主插件那边根本不听
// 通知（登记通知会卡住手机），发了也没用。
// v41：備份／導出／導入／恢復／重置是真的做檔案複製（設定目錄裡的
// 固定檔案），不是擺設；重置是刪掉整個設定檔（備份檔不動）。
// v42：卡片頭像／背景圖用 PHPicker 選圖（iOS 14+，不用相冊權限）；
// 方案檔是設定目錄裡 GuHaiLongSplitScreen-profile-<名字>.plist。
#import <Preferences/PSListController.h>
#import <Preferences/PSSpecifier.h>
#import <Preferences/PSTableCell.h>
#import <UIKit/UIKit.h>
#import <PhotosUI/PhotosUI.h>
#import <objc/message.h>
#import "../GHLSSUpdateCheck.h"

// 运行时现做一个 NSString（不用写死字串）。
static NSString *GHLSSRuntimeString(const char *cstr) {
    return [NSString stringWithCString:cstr encoding:NSUTF8StringEncoding];
}

// 运行时现做一个 CFStringRef（不用 CFSTR），用完要 CFRelease。
static CFStringRef GHLSSRuntimeCFString(const char *cstr) {
    return CFStringCreateWithCString(NULL, cstr, kCFStringEncodingUTF8);
}

// 設定檔目錄（設定 App 的 mobile 用戶可寫）。
static NSString *GHLSSPrefsDir(void) {
    return GHLSSRuntimeString("/var/mobile/Library/Preferences");
}

static NSString *GHLSSPrefsFilePath(void) {
    return [GHLSSPrefsDir() stringByAppendingPathComponent:GHLSSRuntimeString("com.guhailong.splitscreen.plist")];
}

static NSString *GHLSSBackupFilePath(void) {
    return [GHLSSPrefsDir() stringByAppendingPathComponent:GHLSSRuntimeString("GuHaiLongSplitScreen-backup.plist")];
}

static NSString *GHLSSExportFilePath(void) {
    return [GHLSSPrefsDir() stringByAppendingPathComponent:GHLSSRuntimeString("GuHaiLongSplitScreen-export.plist")];
}

static NSString *GHLSSAppCacheFilePath(void) {
    return [GHLSSPrefsDir() stringByAppendingPathComponent:GHLSSRuntimeString("GuHaiLongSplitScreen-apps.plist")];
}

// 讀一個 prefs BOOL（沒設就回預設值）。
static BOOL GHLSSPrefsBool(const char *key, BOOL defaultValue) {
    CFStringRef domain = GHLSSRuntimeCFString("com.guhailong.splitscreen");
    CFStringRef keyRef = GHLSSRuntimeCFString(key);
    BOOL out = defaultValue;
    if (domain && keyRef) {
        CFPropertyListRef v = CFPreferencesCopyAppValue(keyRef, domain);
        if (v) {
            if (CFGetTypeID(v) == CFBooleanGetTypeID()) out = CFBooleanGetValue((CFBooleanRef)v);
            CFRelease(v);
        }
    }
    if (domain) CFRelease(domain);
    if (keyRef) CFRelease(keyRef);
    return out;
}

// 讀一個 prefs 字串（沒設就回 NULL，調用處要 free）。
static char *GHLSSPrefsCString(const char *key) {
    CFStringRef domain = GHLSSRuntimeCFString("com.guhailong.splitscreen");
    CFStringRef keyRef = GHLSSRuntimeCFString(key);
    char *out = NULL;
    if (domain && keyRef) {
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

// 寫一個 prefs BOOL，立刻落盤。
static void GHLSSWritePrefsBool(const char *key, BOOL value) {
    CFStringRef domain = GHLSSRuntimeCFString("com.guhailong.splitscreen");
    CFStringRef keyRef = GHLSSRuntimeCFString(key);
    if (domain && keyRef) {
        CFPreferencesSetAppValue(keyRef, value ? kCFBooleanTrue : kCFBooleanFalse, domain);
        CFPreferencesAppSynchronize(domain);
    }
    if (domain) CFRelease(domain);
    if (keyRef) CFRelease(keyRef);
}

// 寫一個 prefs 字串（NULL = 清掉那個鍵），立刻落盤。
static void GHLSSWritePrefsCString(const char *key, const char *value) {
    CFStringRef domain = GHLSSRuntimeCFString("com.guhailong.splitscreen");
    CFStringRef keyRef = GHLSSRuntimeCFString(key);
    if (domain && keyRef) {
        if (value && value[0] != '\0') {
            CFStringRef v = CFStringCreateWithCString(NULL, value, kCFStringEncodingUTF8);
            if (v) {
                CFPreferencesSetAppValue(keyRef, v, domain);
                CFRelease(v);
            }
        } else {
            CFPreferencesSetAppValue(keyRef, NULL, domain);
        }
        CFPreferencesAppSynchronize(domain);
    }
    if (domain) CFRelease(domain);
    if (keyRef) CFRelease(keyRef);
}

// v42：讀一個 prefs 數字（沒設就回預設值；整數／小數都讀）。
static double GHLSSPrefsDouble(const char *key, double defaultValue) {
    CFStringRef domain = GHLSSRuntimeCFString("com.guhailong.splitscreen");
    CFStringRef keyRef = GHLSSRuntimeCFString(key);
    double out = defaultValue;
    if (domain && keyRef) {
        CFPropertyListRef v = CFPreferencesCopyAppValue(keyRef, domain);
        if (v) {
            if (CFGetTypeID(v) == CFNumberGetTypeID()) {
                double d = 0;
                if (CFNumberGetValue((CFNumberRef)v, kCFNumberDoubleType, &d)) out = d;
            }
            CFRelease(v);
        }
    }
    if (domain) CFRelease(domain);
    if (keyRef) CFRelease(keyRef);
    return out;
}

// v42：卡片背景圖的固定檔名（設定目錄下，浮窗卡片和設定頁兩邊都讀得到；
// v55：卡片頭像已取消，只剩背景圖）。
static NSString *GHLSSCardBgPath(void) {
    return [GHLSSPrefsDir() stringByAppendingPathComponent:GHLSSRuntimeString("GuHaiLongSplitScreen-cardbg.jpg")];
}

// 先聲明（下面定義；輪播 helper 要記日誌，先用）。
static void GHLSSPrefsLogLine(const char *line);

// v59：背景圖輪播——最多 6 張槽位檔（cardbg-0..5.jpg）；
// GuHaiLongSplitScreen-cardbg.jpg 仍是「當前那張」（橫幅＋浮窗卡片讀它，
// 不動讀取方）。count／index 存 prefs 字串；沒寫過就遷移：舊版單張在
// 就拷進槽位 0 當 1 張，否則 0 張。輪播開關 cardBgRotate 預設開。
#define GHLSS_CARD_BG_MAX 6
static NSString *GHLSSCardBgSlotPath(int slot) {
    char name[64];
    snprintf(name, sizeof(name), "GuHaiLongSplitScreen-cardbg-%d.jpg", slot);
    return [GHLSSPrefsDir() stringByAppendingPathComponent:GHLSSRuntimeString(name)];
}
static int GHLSSCardBgCountValue(void) {
    char *raw = GHLSSPrefsCString("cardBgCount");
    int n = -1;
    if (raw) { n = atoi(raw); free(raw); }
    if (n < 0) {
        NSFileManager *fm = [NSFileManager defaultManager];
        NSString *legacy = GHLSSCardBgPath();
        if ([fm fileExistsAtPath:legacy]) {
            [fm copyItemAtPath:legacy toPath:GHLSSCardBgSlotPath(0) error:nil];
            n = 1;
        } else {
            n = 0;
        }
        char buf[16];
        snprintf(buf, sizeof(buf), "%d", n);
        GHLSSWritePrefsCString("cardBgCount", buf);
        GHLSSWritePrefsCString("cardBgIndex", "0");
    }
    if (n < 0) n = 0;
    if (n > GHLSS_CARD_BG_MAX) n = GHLSS_CARD_BG_MAX;
    return n;
}
static int GHLSSCardBgIndexValue(void) {
    int n = GHLSSCardBgCountValue();
    if (n <= 0) return 0;
    char *raw = GHLSSPrefsCString("cardBgIndex");
    int idx = 0;
    if (raw) { idx = atoi(raw); free(raw); }
    if (idx < 0) idx = 0;
    if (idx >= n) idx = 0;
    return idx;
}
static void GHLSSCardBgWriteCount(int n) {
    if (n < 0) n = 0;
    if (n > GHLSS_CARD_BG_MAX) n = GHLSS_CARD_BG_MAX;
    char buf[16];
    snprintf(buf, sizeof(buf), "%d", n);
    GHLSSWritePrefsCString("cardBgCount", buf);
}
static void GHLSSCardBgWriteIndex(int idx) {
    char buf[16];
    snprintf(buf, sizeof(buf), "%d", idx);
    GHLSSWritePrefsCString("cardBgIndex", buf);
}
static BOOL GHLSSCardBgRotateEnabled(void) {
    return GHLSSPrefsBool("cardBgRotate", YES);
}
// 把第 idx 張槽位拷成當前圖（橫幅＋浮窗卡片讀它），記一行日誌。
static void GHLSSCardBgSetCurrent(int idx) {
    int n = GHLSSCardBgCountValue();
    if (n <= 0 || idx < 0 || idx >= n) return;
    NSFileManager *fm = [NSFileManager defaultManager];
    NSString *src = GHLSSCardBgSlotPath(idx);
    if (![fm fileExistsAtPath:src]) return;
    [fm removeItemAtPath:GHLSSCardBgPath() error:nil];
    [fm copyItemAtPath:src toPath:GHLSSCardBgPath() error:nil];
    GHLSSCardBgWriteIndex(idx);
    char buf[128];
    snprintf(buf, sizeof(buf), "v59 bg current %d/%d", idx + 1, n);
    GHLSSPrefsLogLine(buf);
}

// v53：哆啦A夢鈕自訂圖的固定檔名（跟卡片頭像／背景同一個設定目錄；
// dylib 那邊 GHLSSCustomDoraemonImagePath 寫死同一條路徑）。
static NSString *GHLSSDoraemonIconPath(void) {
    return [GHLSSPrefsDir() stringByAppendingPathComponent:GHLSSRuntimeString("GuHaiLongSplitScreen-doraemon.jpg")];
}

static NSString *GHLSSLogFilePath(void) {
    return GHLSSRuntimeString("/var/mobile/Library/Logs/GuHaiLongSplitScreen.log");
}


// v42：日誌尾段（預設最後 200 行）、最新在最上面（跟浮窗卡片同一份寫法）。
// v50：讀檔防呆——檔案不存在／讀不到回提示文字；超過 256KB 只取尾段
// （切口可能斷掉一個多字節字，讀不出來就退回整檔讀）；讀到幾行記在
// GHLSSLogTailLinesRead，呼叫方寫日誌用。
static int GHLSSLogTailLinesRead = 0;
static NSString *GHLSSLogTailNewestFirst(void) {
    NSData *data = [NSData dataWithContentsOfFile:GHLSSLogFilePath()];
    if (!data || [data length] == 0) {
        GHLSSLogTailLinesRead = 0;
        return GHLSSRuntimeString("还没有日志（档案不存在或读不到）。");
    }
    if ([data length] > 262144) {
        data = [data subdataWithRange:NSMakeRange([data length] - 262144, 262144)];
    }
    NSString *content = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    if (!content) content = [NSString stringWithContentsOfFile:GHLSSLogFilePath() encoding:NSUTF8StringEncoding error:nil];
    if (!content) {
        GHLSSLogTailLinesRead = 0;
        return GHLSSRuntimeString("还没有日志（档案不存在或读不到）。");
    }
    NSArray *lines = [content componentsSeparatedByString:GHLSSRuntimeString("\n")];
    NSMutableArray *last = [NSMutableArray array];
    NSInteger start = (NSInteger)[lines count] - 200;
    if (start < 0) start = 0;
    for (NSInteger i = (NSInteger)[lines count] - 1; i >= start; i--) {
        [last addObject:[lines objectAtIndex:i]];
    }
    GHLSSLogTailLinesRead = (int)[last count];
    return [last componentsJoinedByString:GHLSSRuntimeString("\n")];
}

// v43：prefs 側寫檔日誌（搜索閃退診斷用，跟 dylib 寫同一份
// 檔案；設定 App 也是 mobile 身份，寫得動；寫不動就靜靜算了，
// 不彈框、不擋路）。
static void GHLSSPrefsLogLine(const char *line) {
    if (!line) return;
    NSString *path = GHLSSLogFilePath();
    NSString *text = [NSString stringWithCString:line encoding:NSUTF8StringEncoding];
    if (!text) return;
    NSString *entry = [text stringByAppendingString:GHLSSRuntimeString("\n")];
    NSData *data = [entry dataUsingEncoding:NSUTF8StringEncoding];
    if (!data) return;
    NSFileHandle *fh = [NSFileHandle fileHandleForWritingAtPath:path];
    if (fh) {
        [fh seekToEndOfFile];
        [fh writeData:data];
        [fh closeFile];
    } else {
        [data writeToFile:path atomically:NO];
    }
}

// v50：安全取表——iOS 16.5 上 PSListController 子類的 self.tableView
// 並不可靠（搜索頁上它拋 unrecognized selector，見 13.log 8610 行；
// 但日誌頁／頭像頁同一寫法又進得去，時好時壞）。以後全檔案一律走
// 這個 helper，絕不直接調 self.tableView。依序試：(1) respondsToSelector
// 再調 tableView；(2) self.view 本身或子視圖裡找 UITableView；
// (3) valueForKey _tableView。哪一路成功記一行日誌；都失敗回 nil，
// 呼叫方自己決定降級（不掛頭、不進編輯模式），不閃退。
static UITableView *GHLSSSafeTableViewForController(PSListController *controller, const char *tag) {
    if (!controller) return nil;
    const char *t = tag ? tag : "?";
    @try {
        if ([controller respondsToSelector:@selector(tableView)]) {
            UITableView *(*msgSend)(id, SEL) = (UITableView *(*)(id, SEL))objc_msgSend;
            UITableView *tv = msgSend(controller, @selector(tableView));
            if ([tv isKindOfClass:[UITableView class]]) {
                char buf[192];
                snprintf(buf, sizeof(buf), "v57 prefs-table: %s via tableView", t);
                GHLSSPrefsLogLine(buf);
                return tv;
            }
        }
    } @catch (NSException *e) {
        const char *why = [e reason] ? [[e reason] UTF8String] : "?";
        char buf[256];
        snprintf(buf, sizeof(buf), "v57 prefs-table: %s tableView EXCEPTION %s", t, why);
        GHLSSPrefsLogLine(buf);
    }
    @try {
        UIView *view = controller.view;
        if ([view isKindOfClass:[UITableView class]]) {
            char buf[192];
            snprintf(buf, sizeof(buf), "v57 prefs-table: %s via self.view", t);
            GHLSSPrefsLogLine(buf);
            return (UITableView *)view;
        }
        for (UIView *sub in view.subviews) {
            if ([sub isKindOfClass:[UITableView class]]) {
                char buf[192];
                snprintf(buf, sizeof(buf), "v57 prefs-table: %s via subview", t);
                GHLSSPrefsLogLine(buf);
                return (UITableView *)sub;
            }
        }
    } @catch (NSException *e) {
        const char *why = [e reason] ? [[e reason] UTF8String] : "?";
        char buf[256];
        snprintf(buf, sizeof(buf), "v57 prefs-table: %s view scan EXCEPTION %s", t, why);
        GHLSSPrefsLogLine(buf);
    }
    @try {
        id iv = [controller valueForKey:GHLSSRuntimeString("_tableView")];
        if ([iv isKindOfClass:[UITableView class]]) {
            char buf[192];
            snprintf(buf, sizeof(buf), "v57 prefs-table: %s via _tableView", t);
            GHLSSPrefsLogLine(buf);
            return (UITableView *)iv;
        }
    } @catch (NSException *e) {
        const char *why = [e reason] ? [[e reason] UTF8String] : "?";
        char buf[256];
        snprintf(buf, sizeof(buf), "v57 prefs-table: %s _tableView EXCEPTION %s", t, why);
        GHLSSPrefsLogLine(buf);
    }
    char buf[192];
    snprintf(buf, sizeof(buf), "v57 prefs-table: %s none", t);
    GHLSSPrefsLogLine(buf);
    return nil;
}

// v50：日誌尾段取 N 行（狀態頁要最後 5 行；查看日志仍是 200 行）。
static NSString *GHLSSLogTailNewestFirstN(int maxLines) {
    if (maxLines <= 0) maxLines = 200;
    NSString *full = GHLSSLogTailNewestFirst();
    if (!full) return GHLSSRuntimeString("");
    NSArray *lines = [full componentsSeparatedByString:GHLSSRuntimeString("\n")];
    if ((int)[lines count] <= maxLines) return full;
    NSRange r = NSMakeRange(0, (NSUInteger)maxLines);
    return [[lines subarrayWithRange:r] componentsJoinedByString:GHLSSRuntimeString("\n")];
}

// v42：圖片居中裁方形（頭像用，512px）＋按最長邊縮放（背景圖用，1024px）。
static UIImage *GHLSSPrefsSquareCropImage(UIImage *image, CGFloat size) {
    if (!image || !image.CGImage) return nil;
    CGFloat w = image.size.width, h = image.size.height;
    CGFloat side = (w < h) ? w : h;
    CGRect crop = CGRectMake((w - side) / 2.0, (h - side) / 2.0, side, side);
    CGImageRef cg = CGImageCreateWithImageInRect(image.CGImage, crop);
    if (!cg) return nil;
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(size, size), YES, 1.0);
    [[UIImage imageWithCGImage:cg] drawInRect:CGRectMake(0, 0, size, size)];
    UIImage *out = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    CGImageRelease(cg);
    return out;
}

static UIImage *GHLSSPrefsResizeImageMax(UIImage *image, CGFloat maxDim) {
    if (!image) return nil;
    CGFloat w = image.size.width, h = image.size.height;
    CGFloat m = (w > h) ? w : h;
    if (m <= maxDim) return image;
    CGFloat s = maxDim / m;
    CGSize ns = CGSizeMake(w * s, h * s);
    UIGraphicsBeginImageContextWithOptions(ns, YES, 1.0);
    [image drawInRect:CGRectMake(0, 0, ns.width, ns.height)];
    UIImage *out = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return out;
}

// v62：每張槽位圖的顏色名（挑選頁下卡標籤「第 X 張 · 色」用；沒記的
// 就只寫「第 X 張」）。key 是 cardBgColor0..5，跟槽位檔一起搬。
static void GHLSSCardBgWriteColor(int slot, const char *color) {
    char key[32];
    snprintf(key, sizeof(key), "cardBgColor%d", slot);
    GHLSSWritePrefsCString(key, color);
}
static char *GHLSSCardBgColorValue(int slot) {
    char key[32];
    snprintf(key, sizeof(key), "cardBgColor%d", slot);
    return GHLSSPrefsCString(key);
}

// v62：把一張圖按顏色特徵分成舊內置（0 粉／1 白／2 綠／3 龍）或 -1
//（用戶圖／認不出）。舊裁圖的特徵（16×16 上算）：粉 pink 0.49、
// 白 pink 0.19／dark 0.16、綠 pink 0.08／white 0.34、龍 dark 0.66。
// 槽位檔是舊圖同尺寸 JPEG 重壓（q0.85），特徵漂得不多，閾值留足餘量。
static int GHLSSCardBgClassifyOldBuiltin(UIImage *img) {
    if (!img || !img.CGImage) return -1;
    size_t W = 16, H = 16;
    unsigned char *buf = (unsigned char *)calloc(W * H * 4, 1);
    if (!buf) return -1;
    CGColorSpaceRef cs = CGColorSpaceCreateDeviceRGB();
    CGContextRef ctx = CGBitmapContextCreate(buf, W, H, 8, W * 4, cs, kCGImageAlphaPremultipliedLast);
    int kind = -1;
    if (ctx) {
        CGContextDrawImage(ctx, CGRectMake(0, 0, W, H), img.CGImage);
        long n = (long)(W * H);
        double pink = 0, white = 0, dark = 0;
        for (long i = 0; i < n; i++) {
            unsigned char r = buf[i*4], g = buf[i*4+1], b = buf[i*4+2];
            unsigned char mn = r < g ? (r < b ? r : b) : (g < b ? g : b);
            unsigned char mx = r > g ? (r > b ? r : b) : (g > b ? g : b);
            if ((int)r - (int)g > 25 && (int)r - (int)b > 10) pink += 1;
            if (mn > 200 && (mx - mn) < 25) white += 1;
            if (mx < 110) dark += 1;
        }
        pink /= n; white /= n; dark /= n;
        if (dark >= 0.50) kind = 3;
        else if (pink >= 0.35) kind = 0;
        else if (pink < 0.10 && white >= 0.20) kind = 2;
        else if (pink >= 0.10 && white < 0.15 && dark < 0.30) kind = 1;
        CGContextRelease(ctx);
    }
    if (cs) CGColorSpaceRelease(cs);
    free(buf);
    return kind;
}

// v62：一次遷移——把槽位裡的舊內置裁圖換成高清版，並把影片三張排到
// 最前面（白第 1 張、粉第 2 張、綠第 3 張），其他用戶圖保持原順序
// 跟在後面；當前圖設回第 1 張。沒找到影片圖就不動順序。只跑一次。
static void GHLSSCardBgMigrateV62(NSBundle *bundle) {
    char *done = GHLSSPrefsCString("cardBgV62Migrated");
    if (done) { free(done); return; }
    int n = GHLSSCardBgCountValue();
    if (n <= 0) { GHLSSWritePrefsCString("cardBgV62Migrated", "1"); return; }
    UIImage *imgs[6];
    int kind[6];
    for (int i = 0; i < n; i++) {
        imgs[i] = [UIImage imageWithContentsOfFile:GHLSSCardBgSlotPath(i)];
        kind[i] = GHLSSCardBgClassifyOldBuiltin(imgs[i]);
    }
    BOOL hasVideo = NO;
    for (int i = 0; i < n; i++) if (kind[i] >= 0 && kind[i] <= 2) hasVideo = YES;
    if (!hasVideo) { GHLSSWritePrefsCString("cardBgV62Migrated", "1"); return; }
    static const char *kRes[4] = {"ghlss-bg-pink", "ghlss-bg-white", "ghlss-bg-green", NULL};
    static const char *kColor[4] = {"粉", "白", "绿", NULL};
    int order[6];
    int m = 0;
    int want[3] = {1, 0, 2};
    for (int w = 0; w < 3; w++) for (int i = 0; i < n; i++) if (kind[i] == want[w]) order[m++] = i;
    for (int i = 0; i < n; i++) if (kind[i] < 0 || kind[i] > 2) order[m++] = i;
    NSFileManager *fm = [NSFileManager defaultManager];
    for (int i = 0; i < n; i++) [fm removeItemAtPath:GHLSSCardBgSlotPath(i) error:nil];
    for (int pos = 0; pos < m; pos++) {
        int src = order[pos];
        UIImage *img = nil;
        const char *color = NULL;
        if (kind[src] >= 0 && kind[src] <= 2) {
            NSString *path = [bundle pathForResource:GHLSSRuntimeString(kRes[kind[src]]) ofType:GHLSSRuntimeString("jpg")];
            img = path ? [UIImage imageWithContentsOfFile:path] : imgs[src];
            color = kColor[kind[src]];
        } else {
            img = imgs[src];
        }
        UIImage *resized = img ? GHLSSPrefsResizeImageMax(img, 1024.0) : nil;
        NSData *data = resized ? UIImageJPEGRepresentation(resized, 0.85) : nil;
        if (data) [data writeToFile:GHLSSCardBgSlotPath(pos) atomically:YES];
        GHLSSCardBgWriteColor(pos, color);
    }
    GHLSSCardBgWriteCount(m);
    GHLSSCardBgSetCurrent(0);
    GHLSSWritePrefsCString("cardBgV62Migrated", "1");
    char buf[64];
    snprintf(buf, sizeof(buf), "v62 bg migrated %d slots", m);
    GHLSSPrefsLogLine(buf);
}

// v42：bundleID 轉 App 名字（固定 5 個先查，找不到再查後台緩存檔；
// 還是找不到就回 bundleID 本身，不空白）。
// （固定表在下面定義，這裡先前向聲明，免得隱式聲明報錯。）
static const char *GHLSSFixedNames[5];
static int GHLSSFixedIndexForBundleID(const char *bid);
static NSString *GHLSSPrefsAppNameForBundleID(const char *bid) {
    if (!bid || bid[0] == '\0') return GHLSSRuntimeString("未知 App");
    int fixed = GHLSSFixedIndexForBundleID(bid);
    if (fixed >= 0) return GHLSSRuntimeString(GHLSSFixedNames[fixed]);
    NSArray *cached = [NSArray arrayWithContentsOfFile:GHLSSAppCacheFilePath()];
    if (cached) {
        for (id item in cached) {
            if (![item isKindOfClass:[NSDictionary class]]) continue;
            NSString *bidStr = item[GHLSSRuntimeString("bundleID")];
            NSString *nameStr = item[GHLSSRuntimeString("name")];
            if (bidStr && strcmp([bidStr UTF8String], bid) == 0) {
                if (nameStr && [nameStr length] > 0) return nameStr;
                return bidStr;
            }
        }
    }
    return [NSString stringWithCString:bid encoding:NSUTF8StringEncoding];
}

// v42：「主|側」格式的配對字串拆成兩個 bundleID（回 NO = 格式不對）。
static BOOL GHLSSPrefsSplitPair(const char *pair, char *a, size_t aSize, char *b, size_t bSize) {
    if (!pair) return NO;
    const char *sep = strchr(pair, '|');
    if (!sep) return NO;
    size_t la = (size_t)(sep - pair);
    size_t lb = strlen(sep + 1);
    if (la == 0 || lb == 0 || la >= aSize || lb >= bSize) return NO;
    memcpy(a, pair, la);
    a[la] = '\0';
    strncpy(b, sep + 1, bSize - 1);
    b[bSize - 1] = '\0';
    return YES;
}

// v42：配置方案檔名（設定目錄下 GuHaiLongSplitScreen-profile-<名字>.plist；
// 名字裡的斜線／冒號換成底線，免得寫出目錄外）。
static NSString *GHLSSProfileFilePathForName(NSString *name) {
    NSMutableString *safe = [NSMutableString stringWithString:name];
    NSArray *bad = [NSArray arrayWithObjects:GHLSSRuntimeString("/"), GHLSSRuntimeString(":"), GHLSSRuntimeString("\\"), nil];
    for (NSString *c in bad) {
        [safe replaceOccurrencesOfString:c withString:GHLSSRuntimeString("_") options:0 range:NSMakeRange(0, [safe length])];
    }
    NSString *fileName = [[GHLSSRuntimeString("GuHaiLongSplitScreen-profile-") stringByAppendingString:safe] stringByAppendingString:GHLSSRuntimeString(".plist")];
    return [GHLSSPrefsDir() stringByAppendingPathComponent:fileName];
}

// v42：列出現有的配置方案名字（最多 5 個，按檔名排）。
static NSArray *GHLSSListProfileNames(void) {
    NSFileManager *fm = [NSFileManager defaultManager];
    NSArray *files = [fm contentsOfDirectoryAtPath:GHLSSPrefsDir() error:nil];
    NSMutableArray *names = [NSMutableArray array];
    NSString *prefix = GHLSSRuntimeString("GuHaiLongSplitScreen-profile-");
    NSString *suffix = GHLSSRuntimeString(".plist");
    if (files) {
        for (NSString *f in files) {
            if (![f hasPrefix:prefix] || ![f hasSuffix:suffix]) continue;
            NSString *name = [f substringWithRange:NSMakeRange([prefix length], [f length] - [prefix length] - [suffix length])];
            if ([name length] > 0) [names addObject:name];
        }
    }
    [names sortUsingSelector:@selector(compare:)];
    if ([names count] > 5) return [names subarrayWithRange:NSMakeRange(0, 5)];
    return names;
}

// 原來的 5 個固定 App（跟主插件 Tweak.xm 裡的表同一份）。
static const char *GHLSSFixedBundleIDs[5] = {
    "com.apple.calculator",
    "com.apple.mobiletimer",
    "com.apple.mobilenotes",
    "com.apple.Preferences",
    "com.apple.mobileslideshow"
};
static const char *GHLSSFixedNames[5] = {
    "计算器",
    "时钟",
    "备忘录",
    "设置",
    "照片"
};
static const char *GHLSSFixedEnabledKeys[5] = {
    "appCalculatorEnabled",
    "appClockEnabled",
    "appNotesEnabled",
    "appSettingsEnabled",
    "appPhotosEnabled"
};

static int GHLSSFixedIndexForBundleID(const char *bid) {
    if (!bid) return -1;
    for (int i = 0; i < 5; i++) {
        if (strcmp(GHLSSFixedBundleIDs[i], bid) == 0) return i;
    }
    return -1;
}

// 某個 bundleID 是不是在啟動器裡（固定 App 讀開關，預設開；
// 自選 App 看 7 個槽位裡有沒有它的 bundleID 且開關開著）。
static BOOL GHLSSAppInLauncher(const char *bid) {
    if (!bid || bid[0] == '\0') return NO;
    int fixed = GHLSSFixedIndexForBundleID(bid);
    if (fixed >= 0) return GHLSSPrefsBool(GHLSSFixedEnabledKeys[fixed], YES);
    for (int s = 1; s <= 7; s++) {
        char slotKey[32];
        char enabledKey[32];
        snprintf(slotKey, sizeof(slotKey), "customApp%dBundleID", s);
        snprintf(enabledKey, sizeof(enabledKey), "customApp%dEnabled", s);
        char *slotBid = GHLSSPrefsCString(slotKey);
        BOOL match = (slotBid && strcmp(slotBid, bid) == 0);
        if (slotBid) free(slotBid);
        if (match) return GHLSSPrefsBool(enabledKey, YES);
    }
    return NO;
}

// 把某個 App 放進／拿出啟動器（跟主插件的 GHLSSSetAppInLauncher 同款
// 邏輯，設定頁這邊重寫一份——設定 bundle 和主插件是兩個進程，
// 調不到主插件的函數）。滿了（7 個自選槽位都佔了）回 NO。
static BOOL GHLSSSetAppInLauncherPrefs(const char *bid, BOOL on) {
    if (!bid || bid[0] == '\0') return NO;
    int fixed = GHLSSFixedIndexForBundleID(bid);
    if (fixed >= 0) {
        GHLSSWritePrefsBool(GHLSSFixedEnabledKeys[fixed], on);
        return YES;
    }
    if (on) {
        for (int s = 1; s <= 7; s++) {
            char slotKey[32];
            char enabledKey[32];
            snprintf(slotKey, sizeof(slotKey), "customApp%dBundleID", s);
            snprintf(enabledKey, sizeof(enabledKey), "customApp%dEnabled", s);
            char *slotBid = GHLSSPrefsCString(slotKey);
            BOOL empty = (!slotBid || slotBid[0] == '\0');
            if (slotBid) free(slotBid);
            if (empty) {
                GHLSSWritePrefsCString(slotKey, bid);
                GHLSSWritePrefsBool(enabledKey, YES);
                return YES;
            }
        }
        return NO;
    }
    for (int s = 1; s <= 7; s++) {
        char slotKey[32];
        char enabledKey[32];
        snprintf(slotKey, sizeof(slotKey), "customApp%dBundleID", s);
        snprintf(enabledKey, sizeof(enabledKey), "customApp%dEnabled", s);
        char *slotBid = GHLSSPrefsCString(slotKey);
        BOOL match = (slotBid && strcmp(slotBid, bid) == 0);
        if (slotBid) free(slotBid);
        if (match) {
            GHLSSWritePrefsCString(slotKey, NULL);
            GHLSSWritePrefsBool(enabledKey, NO);
            return YES;
        }
    }
    return YES;
}

// v47：見下面 GHLSSHandlePlistDetailTap 的定義——定義要用到白名單
// GHLSSPrefsIsKnownPlistName 與 PlistPage 的接口聲明，都在文件後面，
// 這裡先給原型（主頁控制器與 PlistPage 共用同一個 didSelectRow）。
static BOOL GHLSSHandlePlistDetailTap(PSListController *controller, UITableView *tableView, NSIndexPath *indexPath);

// v72：見下面 GHLSSHandleLinkListTap 的定義——LinkList 點按攔截，
// 推我們自己的 GHLSSLinkListController（定義在文件後面，這裡先給原型）。
static BOOL GHLSSHandleLinkListTap(PSListController *controller, UITableView *tableView, NSIndexPath *indexPath);

// v43：手動派發 PSButtonCell 點按——不再賭框架會不會從 action 字串派發。
// 診斷：plist 的 action 字串、程式現拼的 action 字串、方法、target 全部合規，
// 但皇上在 v42 真機測到五個操作行點了完全沒反應；框架內部到底讀
// specifier->action 還是 properties 裡的 action 字串，靜態查不到，
// 所以直接在 didSelectRow 裡讀 action 字串、轉 SEL、在 target（沒有就 self）上跑。
// v54：N 定死——v52 加的 `SEL specAction = spec->action;` 整行刪掉：
// arm64e 上編譯器給這行直接 ivar 讀取生成帶 PAC 認證的載入，plist 載入
// 的按鈕那個值認證不過就 trap（.ips：GHLSSDispatchButtonTap+552 `brk`，
// 呼叫方是狀態頁；19.log:11626 遊戲布局點按後無動作行，死在同一行）。
// action 只走 properties（v43/v44 就是這樣派發，遊戲布局走通過）。
// 注意：@try/@catch 只防 ObjC 例外，PAC trap 是硬體 trap、防不住——
// 真正的修法就是刪掉這行讀取，@try/@catch 只是第二道防線。
// 回傳 YES 表示這一行已經處理了（呼叫方直接 return，不要再走 super，免得重複跑）。
static BOOL GHLSSDispatchButtonTap(PSListController *controller, UITableView *tableView, NSIndexPath *indexPath) {
    if (!controller || !indexPath) return NO;
    @try {
    PSSpecifier *spec = [controller specifierAtIndexPath:indexPath];
    if (!spec) {
        GHLSSPrefsLogLine("v57 prefs-config tap: no specifier for tap");
        return NO;
    }
    // v52：入口先記一行（section／row／cellType），點了沒反應時日誌看得見
    // 派發走到哪一步——之前這裡靜默回 NO，狀態頁的點按在日誌裡全無痕跡。
    {
        char tapBuf[160];
        snprintf(tapBuf, sizeof(tapBuf), "v57 prefs-config tap: section %ld row %ld cellType %d", (long)indexPath.section, (long)indexPath.row, (int)spec.cellType);
        GHLSSPrefsLogLine(tapBuf);
    }
    if (spec.cellType != PSButtonCell) return NO;
    // v54：action 只走 properties，絕不再碰 spec->action ivar（見上面）。
    NSString *actionName = [spec propertyForKey:GHLSSRuntimeString("action")];
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if (!actionName || [actionName length] == 0) {
        GHLSSPrefsLogLine("v57 prefs-config tap: button without action");
        return YES;
    }
    const char *actionC = [actionName UTF8String];
    SEL action = NSSelectorFromString(actionName);
    id target = spec.target;
    if (!target) target = controller;
    char buf[320];
    snprintf(buf, sizeof(buf), "v57 prefs-config tap: action %s target %s", actionC ? actionC : "?", [NSStringFromClass([target class]) UTF8String]);
    GHLSSPrefsLogLine(buf);
    // v44：action 字串是裸名（沒有冒號），但方法都帶一個參數（PSSpecifier *），
    // 真正的 selector 有冒號（例如 ghlssBackupConfig:）。裸名先試，不回應就補冒號再試。
    // 這也是為什麼框架自己的派發在 v42 也不動——框架也是拿同一個裸名字串轉 SEL，
    // respondsToSelector 永遠回 NO，點按就這樣被靜靜吞掉了。
    if (![target respondsToSelector:action]) {
        GHLSSPrefsLogLine("v57 prefs-config tap: bare name does not respond, trying colon");
        NSString *colonName = [actionName stringByAppendingString:GHLSSRuntimeString(":")];
        SEL colonAction = NSSelectorFromString(colonName);
        if ([target respondsToSelector:colonAction]) {
            action = colonAction;
            GHLSSPrefsLogLine("v57 prefs-config tap: colon selector responds");
        }
    }
    if (![target respondsToSelector:action]) {
        GHLSSPrefsLogLine("v57 prefs-config tap: target does not respond to bare or colon, falling through to super");
        return NO;
    }
    // v44：變數 SEL 不能用 performSelector（-Werror 下 -Warc-performSelector-leaks），
    // 用 v41 就在用的 objc_msgSend 寫法。
    ((void (*)(id, SEL, id))objc_msgSend)(target, action, spec);
    snprintf(buf, sizeof(buf), "v57 prefs-config tap: dispatched %s", [NSStringFromSelector(action) UTF8String]);
    GHLSSPrefsLogLine(buf);
    return YES;
    } @catch (NSException *e) {
        const char *why = [e reason] ? [[e reason] UTF8String] : "?";
        char buf[512];
        snprintf(buf, sizeof(buf), "v57 prefs-config tap EXCEPTION %s", why);
        GHLSSPrefsLogLine(buf);
        @try {
            UIAlertController *alert = [UIAlertController alertControllerWithTitle:GHLSSRuntimeString("点按失败") message:GHLSSRuntimeString("这个按钮点下去出错了（已记进日志），先回上一页再试。") preferredStyle:UIAlertControllerStyleAlert];
            [alert addAction:[UIAlertAction actionWithTitle:GHLSSRuntimeString("好") style:UIAlertActionStyleDefault handler:nil]];
            [controller presentViewController:alert animated:YES completion:nil];
        } @catch (NSException *e2) {
            (void)e2;
        }
        return YES;
    }
}

// （輪播頁在文件後面定義，這裡先給完整接口聲明——光是 @class 前向
// 聲明不夠，[GHLSSCardBgCarouselListController class] 會報錯；
// 後面只寫 @implementation，不再重複寫 @interface。）
@interface GHLSSCardBgCarouselListController : PSListController <PHPickerViewControllerDelegate>
@property (nonatomic, strong) UIView *headerView;
@property (nonatomic, strong) UIView *stackView;
@property (nonatomic, strong) NSMutableArray *stackButtons;
@property (nonatomic, assign) BOOL headerInstalled;
@property (nonatomic, strong) UILabel *wallStatusLabel;
@property (nonatomic, strong) UILabel *wallOutputLabel;
@property (nonatomic, strong) UIButton *wallDeleteButton;
@property (nonatomic, strong) NSTimer *wallPickerTimer;
@property (nonatomic, assign) BOOL wallPickerModeAdjust;
@end

@interface GuHaiLongSplitScreenRootListController : PSListController
@property (nonatomic, strong) UIImageView *ghlssBannerView;
@property (nonatomic, strong) UIView *ghlssBannerContainer;
@property (nonatomic, assign) BOOL ghlssBannerInstalled;
@property (nonatomic, strong) NSTimer *ghlssBgTimer;
@end

@implementation GuHaiLongSplitScreenRootListController

// v43：記進了哪一頁（PlistPage 繼承這裡，類名是 GHLSSPlistPageController，
// 具體哪份 plist 由 specifiers 裡的 plistpage entry 行給出）。
- (void)viewDidLoad {
    [super viewDidLoad];
    char buf[160];
    snprintf(buf, sizeof(buf), "v57 prefs-page: %s", [NSStringFromClass([self class]) UTF8String]);
    GHLSSPrefsLogLine(buf);
    // v53：設定主頁頂上直接顯示卡片背景圖橫幅（點圖就換；「卡片背景圖」行＋
    // 進去選圖的子頁已拿掉）。只掛在設定主頁本身（isMemberOfClass），
    // 子頁（GHLSSPlistPageController 繼承這裡）不掛。
    if ([self isMemberOfClass:[GuHaiLongSplitScreenRootListController class]]) {
        @try {
            CGFloat w = [UIScreen mainScreen].bounds.size.width;
            UIView *container = [[UIView alloc] initWithFrame:CGRectMake(0, 0, w, 200)];
            container.backgroundColor = [UIColor whiteColor];
            // v54：圖改滿幅（0,0,w,200）去白邊（v53 是 (0,10,w,180)，上下各 10pt 白邊）。
            UIImageView *iv = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, w, 200)];
            iv.contentMode = UIViewContentModeScaleAspectFill;
            iv.clipsToBounds = YES;
            iv.backgroundColor = [UIColor whiteColor];
            iv.userInteractionEnabled = YES;
            [container addSubview:iv];
            UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(ghlssBannerTapped:)];
            [iv addGestureRecognizer:tap];
            UIButton *restoreBtn = [UIButton buttonWithType:UIButtonTypeSystem];
            restoreBtn.frame = CGRectMake(w - 92, 158, 84, 28);
            [restoreBtn setTitle:GHLSSRuntimeString("恢复默认") forState:UIControlStateNormal];
            restoreBtn.titleLabel.font = [UIFont systemFontOfSize:13];
            restoreBtn.backgroundColor = [[UIColor whiteColor] colorWithAlphaComponent:0.75];
            restoreBtn.layer.cornerRadius = 6.0;
            [restoreBtn addTarget:self action:@selector(ghlssRestoreBannerBg:) forControlEvents:UIControlEventTouchUpInside];
            [container addSubview:restoreBtn];
            self.ghlssBannerView = iv;
            self.ghlssBannerContainer = container;
            [self ghlssRefreshBannerPreview];
        } @catch (NSException *e) {
            GHLSSPrefsLogLine("v57 prefs-banner: viewDidLoad EXCEPTION");
        }
    }
}

// v53：橫幅掛載（viewDidAppear 才碰 table；只掛設定主頁本身）。
// v54：掛載前核對取到的表就是主表（dataSource 是自己才掛），寬度改這時重取。
- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    if (![self isMemberOfClass:[GuHaiLongSplitScreenRootListController class]]) return;
    if (self.ghlssBannerContainer && !self.ghlssBannerInstalled) {
        UITableView *tv = GHLSSSafeTableViewForController(self, "banner");
        if (tv && tv.dataSource && (id)tv.dataSource != (id)self) {
            GHLSSPrefsLogLine("v57 prefs-banner: table mismatch, header not mounted");
            return;
        }
        if (tv) {
            @try {
                CGFloat w = tv.bounds.size.width;
                if (w <= 0) w = [UIScreen mainScreen].bounds.size.width;
                self.ghlssBannerContainer.frame = CGRectMake(0, 0, w, 200);
                self.ghlssBannerView.frame = CGRectMake(0, 0, w, 200);
                for (UIView *sub in self.ghlssBannerContainer.subviews) {
                    if ([sub isKindOfClass:[UIButton class]]) sub.frame = CGRectMake(w - 92, 158, 84, 28);
                }
                tv.tableHeaderView = self.ghlssBannerContainer;
                self.ghlssBannerInstalled = YES;
                GHLSSPrefsLogLine("v57 prefs-banner: header mounted");
            } @catch (NSException *e) {
                GHLSSPrefsLogLine("v57 prefs-banner: mount EXCEPTION");
            }
        } else {
            GHLSSPrefsLogLine("v57 prefs-banner: no table, header not mounted");
        }
    }
    // v59：回來時刷一次橫幅（輪播頁裡換過圖），重開 3 秒輪播計時。
    [self ghlssRefreshBannerPreview];
    [self ghlssRefreshWallpaperRowIcon];
    [self ghlssStartBgTimer];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [self ghlssStopBgTimer];
}

- (void)ghlssRefreshBannerPreview {
    @try {
        UIImage *img = [UIImage imageWithContentsOfFile:GHLSSCardBgPath()];
        self.ghlssBannerView.image = img;
    } @catch (NSException *e) {
        GHLSSPrefsLogLine("v57 prefs-banner: refresh EXCEPTION");
    }
}

// v61：設定首頁「壁紙」行左邊放當前壁紙小預覽（沒有圖就放龍頭圖）；
// 回來時（挑選頁換過圖）重刷那一行，預覽跟著新。找不到行就靜默跳過。
- (void)ghlssRefreshWallpaperRowIcon {
    @try {
        NSArray *specs = [self specifiers];
        PSSpecifier *wall = nil;
        NSInteger wallIndex = -1;
        for (NSInteger i = 0; i < (NSInteger)[specs count]; i++) {
            PSSpecifier *sp = [specs objectAtIndex:i];
            NSString *detail = [sp propertyForKey:GHLSSRuntimeString("detail")];
            if (detail && [detail isEqualToString:GHLSSRuntimeString("GHLSSCardBgCarouselListController")]) { wall = sp; wallIndex = i; break; }
        }
        if (!wall || wallIndex < 0) return;
        UIImage *img = [UIImage imageWithContentsOfFile:GHLSSCardBgPath()];
        if (!img) {
            NSBundle *bundle = [NSBundle bundleForClass:[self class]];
            NSString *dpath = [bundle pathForResource:GHLSSRuntimeString("ghlss-bg-dragon") ofType:GHLSSRuntimeString("jpg")];
            if (dpath) img = [UIImage imageWithContentsOfFile:dpath];
        }
        if (img) {
            UIImage *thumb = GHLSSPrefsSquareCropImage(img, 58.0);
            if (thumb) [wall setProperty:thumb forKey:GHLSSRuntimeString("iconImage")];
        }
        UITableView *tv = GHLSSSafeTableViewForController(self, "wallpapericon");
        if (!tv) return;
        NSInteger section = -1, row = -1;
        for (NSInteger i = 0; i <= wallIndex; i++) {
            PSSpecifier *sp = [specs objectAtIndex:i];
            if (sp.cellType == PSGroupCell) { section++; row = -1; }
            else { row++; }
        }
        if (section < 0 || row < 0) return;
        NSIndexPath *ip = [NSIndexPath indexPathForRow:row inSection:section];
        [tv reloadRowsAtIndexPaths:[NSArray arrayWithObject:ip] withRowAnimation:UITableViewRowAnimationNone];
    } @catch (NSException *e) {
        GHLSSPrefsLogLine("v61 prefs-wallpapericon EXCEPTION");
    }
}

// v59：背景圖輪播計時（設定主頁才跑，離開頁面就停）：兩張以上、
// 輪播開關開著時，每 3 秒換下一張（寫回當前圖＋刷橫幅＋記日誌）。
- (void)ghlssStartBgTimer {
    [self ghlssStopBgTimer];
    if (GHLSSCardBgCountValue() < 2) return;
    NSTimer *t = [NSTimer scheduledTimerWithTimeInterval:3.0 target:self selector:@selector(ghlssBgTimerFired:) userInfo:nil repeats:YES];
    self.ghlssBgTimer = t;
}

- (void)ghlssStopBgTimer {
    [self.ghlssBgTimer invalidate];
    self.ghlssBgTimer = nil;
}

- (void)ghlssBgTimerFired:(NSTimer *)timer {
    (void)timer;
    int n = GHLSSCardBgCountValue();
    if (n < 2 || !GHLSSCardBgRotateEnabled()) return;
    int next = (GHLSSCardBgIndexValue() + 1) % n;
    GHLSSCardBgSetCurrent(next);
    [self ghlssRefreshBannerPreview];
}

- (void)ghlssBannerTapped:(UITapGestureRecognizer *)tap {
    (void)tap;
    // v59：點橫幅進輪播頁選圖（不再直接開相冊單選）。
    GHLSSCardBgCarouselListController *vc = [[GHLSSCardBgCarouselListController alloc] init];
    [self.navigationController pushViewController:vc animated:YES];
}

- (void)ghlssRestoreBannerBg:(id)sender {
    (void)sender;
    NSFileManager *fm = [NSFileManager defaultManager];
    [fm removeItemAtPath:GHLSSCardBgPath() error:nil];
    for (int i = 0; i < GHLSS_CARD_BG_MAX; i++) [fm removeItemAtPath:GHLSSCardBgSlotPath(i) error:nil];
    GHLSSCardBgWriteCount(0);
    GHLSSCardBgWriteIndex(0);
    GHLSSWritePrefsBool("cardBgCustom", NO);
    [self ghlssRefreshBannerPreview];
    [self ghlssStopBgTimer];
    GHLSSPrefsLogLine("v59 bg restored default");
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:GHLSSRuntimeString("已恢复默认白卡") message:GHLSSRuntimeString("浮窗设定卡片回到默认白卡。") preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:GHLSSRuntimeString("好") style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

// v43：按鈕行自己派發（見上面 GHLSSDispatchButtonTap）；其他行走框架。
// v47：plist 名 detail 的連結行先攔下來自己推 PlistPage（見下面
// GHLSSHandlePlistDetailTap），不再走框架預設——框架推的原生頁是空的。
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if (GHLSSHandleLinkListTap(self, tableView, indexPath)) return;
    if (GHLSSHandlePlistDetailTap(self, tableView, indexPath)) return;
    if (GHLSSDispatchButtonTap(self, tableView, indexPath)) return;
    [super tableView:tableView didSelectRowAtIndexPath:indexPath];
}

- (NSArray *)specifiers {
    if (!_specifiers) {
        @try {
            NSMutableArray *loaded = [self loadSpecifiersFromPlistName:GHLSSRuntimeString("Root") target:self];
            // v52：新手模式整個取消，不再過濾。
            _specifiers = loaded;
            [self ghlssRefreshWallpaperRowIcon];
        } @catch (NSException *e) {
            const char *reason = [e reason] ? [[e reason] UTF8String] : "?";
            char buf[512];
            snprintf(buf, sizeof(buf), "v57 prefs-root specifiers EXCEPTION %s", reason);
            GHLSSPrefsLogLine(buf);
            NSMutableArray *safe = [NSMutableArray array];
            PSSpecifier *group = [PSSpecifier emptyGroupSpecifier];
            [group setProperty:GHLSSRuntimeString("主页组装出错（已记进日志），先回设定再试。") forKey:GHLSSRuntimeString("footerText")];
            [safe addObject:group];
            _specifiers = safe;
        }
        if (!_specifiers) _specifiers = [NSMutableArray array];
    }
    return _specifiers;
}

// v50：主頁「檢查更新」——抓 live /Packages 比對已裝版本（跟浮窗設定卡片
// 共用 GHLSSUpdateCheck.h 同一份抓取邏輯；已裝版本就是跑著的代碼本身）。
- (void)ghlssCheckForUpdate:(PSSpecifier *)specifier {
    (void)specifier;
    GHLSSPrefsLogLine("v57 prefs-update: check started");
    __weak typeof(self) weakSelf = self;
    GHLSSCheckForUpdate(^(NSString *latest, const char *error) {
        typeof(self) strongSelf = weakSelf;
        if (!strongSelf) return;
        if (error || !latest) {
            GHLSSPrefsLogLine("v57 prefs-update: fetch failed");
            [strongSelf ghlssShowAlertWithTitle:GHLSSRuntimeString("检查失败") message:GHLSSRuntimeString("检查失败，请检查网络。")];
            return;
        }
        char buf[192];
        snprintf(buf, sizeof(buf), "v57 prefs-update: latest %s", [latest UTF8String]);
        GHLSSPrefsLogLine(buf);
        int cmp = GHLSSCompareDottedVersions([latest UTF8String], "1.0.75");
        if (cmp <= 0) {
            [strongSelf ghlssShowAlertWithTitle:GHLSSRuntimeString("已经是最新版") message:GHLSSRuntimeString("已经是最新版 1.0.75。")];
        } else {
            NSString *msg = [[GHLSSRuntimeString("有新版 ") stringByAppendingString:latest] stringByAppendingString:GHLSSRuntimeString("，请去 Sileo 更新。")];
            [strongSelf ghlssShowAlertWithTitle:GHLSSRuntimeString("有新版") message:msg];
        }
    });
}

- (id)readPreferenceValue:(PSSpecifier *)specifier {
    CFStringRef domain = GHLSSRuntimeCFString("com.guhailong.splitscreen");
    NSString *keyName = GHLSSRuntimeString("key");
    NSString *key = specifier.properties[keyName];
    CFPropertyListRef v = NULL;
    if (key) {
        CFStringRef cfKey = (__bridge CFStringRef)key;
        v = CFPreferencesCopyAppValue(cfKey, domain);
    }
    if (domain) CFRelease(domain);
    if (v) {
        id value = (__bridge_transfer id)v;
        return value;
    }
    // v41：沒存過就回 plist 裡寫的 default（以前回 NO，滑桿的預設值
    // 在設定頁會顯示成 0）。
    NSString *defaultName = GHLSSRuntimeString("default");
    id def = specifier.properties[defaultName];
    if (def) return def;
    return @(NO);
}

- (void)setPreferenceValue:(id)value specifier:(PSSpecifier *)specifier {
    CFStringRef domain = GHLSSRuntimeCFString("com.guhailong.splitscreen");
    NSString *keyName = GHLSSRuntimeString("key");
    NSString *key = specifier.properties[keyName];
    if (key) {
        CFStringRef cfKey = (__bridge CFStringRef)key;
        CFPreferencesSetAppValue(cfKey, (__bridge CFPropertyListRef)value, domain);
        CFPreferencesAppSynchronize(domain);
        // v43：記開關／滑桿／分段改了什麼值（只記用戶改動，不記讀取；
        // readPreferenceValue 每行渲染都跑，記了會刷爆日誌）。
        char buf[256];
        const char *keyC = [key UTF8String];
        const char *valC = [[value description] UTF8String];
        snprintf(buf, sizeof(buf), "v57 prefs-set: %s = %s", keyC ? keyC : "?", valC ? valC : "?");
        GHLSSPrefsLogLine(buf);
    }
    if (domain) CFRelease(domain);
}

// 彈一個提示框（設定頁裡的回饋）。
- (void)ghlssShowAlertWithTitle:(NSString *)title message:(NSString *)message {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title message:message preferredStyle:UIAlertControllerStyleAlert];
    NSString *okTitle = GHLSSRuntimeString("好");
    UIAlertAction *ok = [UIAlertAction actionWithTitle:okTitle style:UIAlertActionStyleDefault handler:nil];
    [alert addAction:ok];
    // v43：提示框改走最上層 presenter、主隊列；彈不出來要寫日誌，不要靜默
    // （presentViewController 失敗是靜默的，看著就像點了沒反應）。
    dispatch_async(dispatch_get_main_queue(), ^{
        UIViewController *presenter = self;
        while (presenter.presentedViewController) presenter = presenter.presentedViewController;
        if (!presenter.view.window) {
            // v43：self 不在視窗裡時，改找前景 scene 的 key window
            //（不用已棄用的 UIApplication.keyWindow / windows）。
            UIWindow *keyWindow = nil;
            for (UIScene *s in [[UIApplication sharedApplication] connectedScenes]) {
                if (![s isKindOfClass:[UIWindowScene class]]) continue;
                UIWindowScene *ws = (UIWindowScene *)s;
                if (ws.activationState != UISceneActivationStateForegroundActive) continue;
                for (UIWindow *w in ws.windows) {
                    if (w.isKeyWindow) { keyWindow = w; break; }
                }
                if (keyWindow) break;
            }
            if (keyWindow && keyWindow.rootViewController) {
                presenter = keyWindow.rootViewController;
                while (presenter.presentedViewController) presenter = presenter.presentedViewController;
            }
        }
        if (presenter) {
            [presenter presentViewController:alert animated:YES completion:nil];
            GHLSSPrefsLogLine("v57 prefs-config alert shown");
        } else {
            GHLSSPrefsLogLine("v57 prefs-config alert FAILED: no presenter");
        }
    });
}

// 備份配置：設定檔複製一份到備份檔。
- (void)ghlssBackupConfig:(PSSpecifier *)specifier {
    (void)specifier;
    GHLSSPrefsLogLine("v57 prefs-config backup entry");
    NSFileManager *fm = [NSFileManager defaultManager];
    NSString *src = GHLSSPrefsFilePath();
    NSString *dst = GHLSSBackupFilePath();
    // v43：先同步一次，確保磁碟上的檔案是最新值，再複製。
    CFStringRef domain = GHLSSRuntimeCFString("com.guhailong.splitscreen");
    if (domain) { CFPreferencesAppSynchronize(domain); CFRelease(domain); }
    if (![fm fileExistsAtPath:src]) {
        GHLSSPrefsLogLine("v57 prefs-config backup: no prefs file");
        [self ghlssShowAlertWithTitle:GHLSSRuntimeString("没有配置文件可备份") message:GHLSSRuntimeString("先改一个设置，配置文件才会生成。")];
        return;
    }
    NSError *err = nil;
    [fm removeItemAtPath:dst error:nil];
    BOOL ok = [fm copyItemAtPath:src toPath:dst error:&err];
    if (ok) {
        char buf[512];
        snprintf(buf, sizeof(buf), "v57 prefs-config backup: copied to %s", [dst UTF8String]);
        GHLSSPrefsLogLine(buf);
    } else {
        char buf[768];
        const char *errC = [[err localizedDescription] UTF8String];
        snprintf(buf, sizeof(buf), "v57 prefs-config backup: copy failed %s -> %s : %s", [src UTF8String], [dst UTF8String], errC ? errC : "?");
        GHLSSPrefsLogLine(buf);
    }
    if (ok) {
        [self ghlssShowAlertWithTitle:GHLSSRuntimeString("已备份配置") message:GHLSSRuntimeString("备份在 GuHaiLongSplitScreen-backup.plist，恢复时读这个文件。")];
    } else {
        [self ghlssShowAlertWithTitle:GHLSSRuntimeString("备份失败") message:GHLSSRuntimeString("复制配置文件时出错。")];
    }
}

// v63：清除已記的遊戲浮窗位置——刪掉全部 gameWinPos_ 開頭的設定鍵
//（每款遊戲記浮窗位置的記錄），方便重設。檔案裡刪鍵再寫回，再逐鍵從
// CFPreferences 刪一次（快取才會更新——v43 導入的教訓：直接換檔不動
// cfprefsd 快取，開關看著像沒反應）。刪完彈提示。
- (void)ghlssClearGameWindowPositions:(PSSpecifier *)specifier {
    (void)specifier;
    GHLSSPrefsLogLine("v68 prefs-config clear game window positions entry");
    NSString *prefix = GHLSSRuntimeString("gameWinPos_");
    CFStringRef domain = GHLSSRuntimeCFString("com.guhailong.splitscreen");
    if (domain) { CFPreferencesAppSynchronize(domain); CFRelease(domain); }
    NSString *path = GHLSSPrefsFilePath();
    NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithContentsOfFile:path];
    NSMutableArray *toDelete = [NSMutableArray array];
    if (dict) {
        for (NSString *key in dict) {
            if ([key hasPrefix:prefix]) [toDelete addObject:key];
        }
    }
    int removed = (int)[toDelete count];
    if (removed > 0) {
        for (NSString *key in toDelete) [dict removeObjectForKey:key];
        [dict writeToFile:path atomically:YES];
        CFStringRef domain2 = GHLSSRuntimeCFString("com.guhailong.splitscreen");
        if (domain2) {
            for (NSString *key in toDelete) {
                CFPreferencesSetAppValue((__bridge CFStringRef)key, NULL, domain2);
            }
            CFPreferencesAppSynchronize(domain2);
            CFRelease(domain2);
        }
        char buf[128];
        snprintf(buf, sizeof(buf), "v68 prefs-config clear game window positions: removed %d keys", removed);
        GHLSSPrefsLogLine(buf);
        [self ghlssShowAlertWithTitle:GHLSSRuntimeString("已清除") message:GHLSSRuntimeString("已记的游戏浮窗位置都清掉了，下次进游戏浮窗回到预设位置。")];
    } else {
        GHLSSPrefsLogLine("v68 prefs-config clear game window positions: none saved");
        [self ghlssShowAlertWithTitle:GHLSSRuntimeString("没有已记的位置") message:GHLSSRuntimeString("还没有记过任何游戏浮窗位置，不用清。")];
    }
}

// 導出配置（非備份配置）：設定檔複製一份到導出檔，導入時讀它。
- (void)ghlssExportConfig:(PSSpecifier *)specifier {
    (void)specifier;
    GHLSSPrefsLogLine("v57 prefs-config export entry");
    NSFileManager *fm = [NSFileManager defaultManager];
    NSString *src = GHLSSPrefsFilePath();
    NSString *dst = GHLSSExportFilePath();
    // v43：先同步一次，確保磁碟上的檔案是最新值，再複製。
    CFStringRef domain = GHLSSRuntimeCFString("com.guhailong.splitscreen");
    if (domain) { CFPreferencesAppSynchronize(domain); CFRelease(domain); }
    if (![fm fileExistsAtPath:src]) {
        GHLSSPrefsLogLine("v57 prefs-config export: no prefs file");
        [self ghlssShowAlertWithTitle:GHLSSRuntimeString("没有配置文件可导出") message:GHLSSRuntimeString("先改一个设置，配置文件才会生成。")];
        return;
    }
    [fm removeItemAtPath:dst error:nil];
    NSError *err = nil;
    BOOL ok = [fm copyItemAtPath:src toPath:dst error:&err];
    if (ok) {
        char buf[512];
        snprintf(buf, sizeof(buf), "v57 prefs-config export: copied to %s", [dst UTF8String]);
        GHLSSPrefsLogLine(buf);
    } else {
        char buf[768];
        const char *errC = [[err localizedDescription] UTF8String];
        snprintf(buf, sizeof(buf), "v57 prefs-config export: copy failed %s -> %s : %s", [src UTF8String], [dst UTF8String], errC ? errC : "?");
        GHLSSPrefsLogLine(buf);
    }
    if (ok) {
        [self ghlssShowAlertWithTitle:GHLSSRuntimeString("已导出配置") message:GHLSSRuntimeString("导出在 GuHaiLongSplitScreen-export.plist，导入时读这个文件。")];
    } else {
        [self ghlssShowAlertWithTitle:GHLSSRuntimeString("导出失败") message:GHLSSRuntimeString("复制配置文件时出错。")];
    }
}

// 從文件中導入配置：讀導出檔，蓋掉現在的設定檔。
// v43：不再直接換檔案——直接換檔不會動 cfprefsd 的快取，reload 後開關還是舊值，
// 看著就像沒反應。改成讀出字典、逐鍵用 CFPreferencesSetAppValue 寫進去，快取才會更新。
- (void)ghlssImportConfig:(PSSpecifier *)specifier {
    (void)specifier;
    GHLSSPrefsLogLine("v57 prefs-config import entry");
    NSFileManager *fm = [NSFileManager defaultManager];
    NSString *src = GHLSSExportFilePath();
    if (![fm fileExistsAtPath:src]) {
        GHLSSPrefsLogLine("v57 prefs-config import: no export file");
        [self ghlssShowAlertWithTitle:GHLSSRuntimeString("没有找到导出的配置文件") message:GHLSSRuntimeString("先点「导出配置」，再导入。")];
        return;
    }
    NSDictionary *dict = [NSDictionary dictionaryWithContentsOfFile:src];
    if (!dict) {
        char buf[512];
        snprintf(buf, sizeof(buf), "v57 prefs-config import: export file unreadable %s", [src UTF8String]);
        GHLSSPrefsLogLine(buf);
        [self ghlssShowAlertWithTitle:GHLSSRuntimeString("导入失败") message:GHLSSRuntimeString("导出的配置文件读不出来。")];
        return;
    }
    CFStringRef domain = GHLSSRuntimeCFString("com.guhailong.splitscreen");
    if (domain) {
        for (NSString *key in dict) {
            CFPreferencesSetAppValue((__bridge CFStringRef)key, (__bridge CFPropertyListRef)[dict objectForKey:key], domain);
        }
        CFPreferencesAppSynchronize(domain);
        CFRelease(domain);
    }
    [self reloadSpecifiers];
    char buf[512];
    snprintf(buf, sizeof(buf), "v57 prefs-config import: applied %lu keys from %s", (unsigned long)[dict count], [src UTF8String]);
    GHLSSPrefsLogLine(buf);
    [self ghlssShowAlertWithTitle:GHLSSRuntimeString("已导入配置") message:GHLSSRuntimeString("配置已恢复，请重新启动 SpringBoard 生效。")];
}

// 從備份文件恢復配置：讀備份檔，蓋掉現在的設定檔。
// v43：同導入，改走 CFPreferences 逐鍵寫入（見上）。
- (void)ghlssRestoreConfig:(PSSpecifier *)specifier {
    (void)specifier;
    GHLSSPrefsLogLine("v57 prefs-config restore entry");
    NSFileManager *fm = [NSFileManager defaultManager];
    NSString *src = GHLSSBackupFilePath();
    if (![fm fileExistsAtPath:src]) {
        GHLSSPrefsLogLine("v57 prefs-config restore: no backup file");
        [self ghlssShowAlertWithTitle:GHLSSRuntimeString("没有找到备份文件") message:GHLSSRuntimeString("先点「备份配置」，再恢复。")];
        return;
    }
    NSDictionary *dict = [NSDictionary dictionaryWithContentsOfFile:src];
    if (!dict) {
        char buf[512];
        snprintf(buf, sizeof(buf), "v57 prefs-config restore: backup file unreadable %s", [src UTF8String]);
        GHLSSPrefsLogLine(buf);
        [self ghlssShowAlertWithTitle:GHLSSRuntimeString("恢复失败") message:GHLSSRuntimeString("备份文件读不出来。")];
        return;
    }
    CFStringRef domain = GHLSSRuntimeCFString("com.guhailong.splitscreen");
    if (domain) {
        for (NSString *key in dict) {
            CFPreferencesSetAppValue((__bridge CFStringRef)key, (__bridge CFPropertyListRef)[dict objectForKey:key], domain);
        }
        CFPreferencesAppSynchronize(domain);
        CFRelease(domain);
    }
    [self reloadSpecifiers];
    char buf[512];
    snprintf(buf, sizeof(buf), "v57 prefs-config restore: applied %lu keys from %s", (unsigned long)[dict count], [src UTF8String]);
    GHLSSPrefsLogLine(buf);
    [self ghlssShowAlertWithTitle:GHLSSRuntimeString("已从备份恢复配置") message:GHLSSRuntimeString("配置已恢复，请重新启动 SpringBoard 生效。")];
}

// 重置為默認配置：刪掉整個設定檔（備份檔不動），全部開關回預設值。
// v43：舊寫法只刪檔案——cfprefsd 快取裡的值還在，reload 後開關還是舊值，
// 看著就像沒反應。改成先用 CFPreferencesCopyKeyList 逐鍵清掉（快取才會空），
// 再刪檔案。
- (void)ghlssResetConfig:(PSSpecifier *)specifier {
    (void)specifier;
    GHLSSPrefsLogLine("v57 prefs-config reset entry");
    NSFileManager *fm = [NSFileManager defaultManager];
    NSString *dst = GHLSSPrefsFilePath();
    CFIndex clearedCount = 0;
    CFStringRef domain = GHLSSRuntimeCFString("com.guhailong.splitscreen");
    if (domain) {
        CFArrayRef keys = CFPreferencesCopyKeyList(domain, kCFPreferencesCurrentUser, kCFPreferencesAnyHost);
        if (keys) {
            clearedCount = CFArrayGetCount(keys);
            for (CFIndex i = 0; i < clearedCount; i++) {
                CFStringRef k = (CFStringRef)CFArrayGetValueAtIndex(keys, i);
                CFPreferencesSetAppValue(k, NULL, domain);
            }
            CFRelease(keys);
        }
        CFPreferencesAppSynchronize(domain);
        CFRelease(domain);
    }
    NSError *err = nil;
    BOOL removed = YES;
    if ([fm fileExistsAtPath:dst]) {
        removed = [fm removeItemAtPath:dst error:&err];
    }
    [self reloadSpecifiers];
    char buf[320];
    snprintf(buf, sizeof(buf), "v57 prefs-config reset: cleared %ld keys, file %s removed %d", (long)clearedCount, [dst UTF8String], removed ? 1 : 0);
    GHLSSPrefsLogLine(buf);
    if (removed) {
        [self ghlssShowAlertWithTitle:GHLSSRuntimeString("已重置为默认配置") message:GHLSSRuntimeString("全部设置已恢复默认（备份文件还在），请重新启动 SpringBoard 生效。")];
    } else {
        [self ghlssShowAlertWithTitle:GHLSSRuntimeString("重置失败") message:GHLSSRuntimeString("删除配置文件时出错。")];
    }
}

// v42：布局預設——點一下一次換整套設定（各預設改哪些 key，
// Root.plist 的頁腳列出來了）。改完要重新啟動 SpringBoard 才生效
//（浮窗尺寸／任務欄那幾項 2 秒 tick 會自己跟上）。
// v56：遊戲布局已取消（§141-5；留遊戲模式）。ghlssApplyLayoutGame 整段刪掉。
// v53：工作／默認布局已刪（皇上 23:29：布局只要遊戲布局就好了）。
@end
// 開的那份清單的設定頁版，同一份 key、同一份清單，兩邊同步。
// 清單讀後台緩存檔（主插件啟動 5 秒後在後台列舉、寫檔；設定頁
// 只讀緩存，不列舉、不堵主線程）。固定 5 個永遠在最前面；
// 自選 App 的開關 key 是 sel-<bundleID>，走 GHLSSSetAppInLauncherPrefs
// 的槽位邏輯（7 個自選槽位）。
// v55：選 App 頁每行掛 App 圖標（UIImage 取 App 圖標的私有方法，走運行時拿；
// 拿不到就回 nil、行只顯示名字，不擋列表、不閃退）。圖標按 bundleID 快取，
// 開頁只取一次（清單上百個也不卡）。
@interface UIImage (GHLSSAppIconLookup)
+ (UIImage *)_applicationIconImageForBundleIdentifier:(NSString *)bundleIdentifier format:(int)format scale:(CGFloat)scale;
@end
static NSMutableDictionary *GHLSSAppIconCache = nil;
static UIImage *GHLSSAppIconForBundleID(NSString *bid) {
    if (!bid || [bid length] == 0) return nil;
    if (!GHLSSAppIconCache) GHLSSAppIconCache = [NSMutableDictionary dictionary];
    UIImage *cached = GHLSSAppIconCache[bid];
    if (cached) return cached;
    UIImage *icon = nil;
    @try {
        icon = [UIImage _applicationIconImageForBundleIdentifier:bid format:0 scale:[UIScreen mainScreen].scale];
        if (!icon) icon = [UIImage _applicationIconImageForBundleIdentifier:bid format:2 scale:[UIScreen mainScreen].scale];
    } @catch (NSException *e) {
        icon = nil;
    }
    if (icon) {
        if ([GHLSSAppIconCache count] > 300) [GHLSSAppIconCache removeAllObjects];
        GHLSSAppIconCache[bid] = icon;
    }
    return icon;
}

// v56：遊戲 App 清單（gameAppBundleIDs，逗號分隔 bundleID；遊戲模式自動觸發認這份清單）。
static BOOL GHLSSGameAppContainsBid(const char *bid) {
    if (!bid || bid[0] == '\0') return NO;
    char *raw = GHLSSPrefsCString("gameAppBundleIDs");
    if (!raw) return NO;
    NSString *rawStr = [NSString stringWithCString:raw encoding:NSUTF8StringEncoding];
    free(raw);
    if (!rawStr || [rawStr length] == 0) return NO;
    NSArray *parts = [rawStr componentsSeparatedByString:GHLSSRuntimeString(",")];
    NSString *bidStr = [NSString stringWithCString:bid encoding:NSUTF8StringEncoding];
    return [parts containsObject:bidStr];
}
static void GHLSSSetGameAppBid(const char *bid, BOOL on) {
    if (!bid || bid[0] == '\0') return;
    NSMutableArray *ids = [NSMutableArray array];
    char *raw = GHLSSPrefsCString("gameAppBundleIDs");
    if (raw) {
        NSString *rawStr = [NSString stringWithCString:raw encoding:NSUTF8StringEncoding];
        free(raw);
        if (rawStr && [rawStr length] > 0) {
            NSArray *parts = [rawStr componentsSeparatedByString:GHLSSRuntimeString(",")];
            for (NSString *p in parts) if ([p length] > 0 && ![ids containsObject:p]) [ids addObject:p];
        }
    }
    NSString *bidStr = [NSString stringWithCString:bid encoding:NSUTF8StringEncoding];
    [ids removeObject:bidStr];
    if (on) [ids addObject:bidStr];
    NSString *joined = [ids componentsJoinedByString:GHLSSRuntimeString(",")];
    GHLSSWritePrefsCString("gameAppBundleIDs", [joined UTF8String]);
}

@interface GHLSSAppPickerListController : PSListController
@end

@implementation GHLSSAppPickerListController

// v56：是不是遊戲 App 選擇（Root.plist「選擇遊戲 App」連結行帶
// ghlssPickerMode=game；沒帶就是啟動器選擇）。每次現讀 specifier，
// 不用 ivar——super viewDidLoad 會先載 specifiers，ivar 晚了就讀不到。
- (BOOL)ghlssIsGamePicker {
    NSString *mode = self.specifier ? self.specifier.properties[GHLSSRuntimeString("ghlssPickerMode")] : nil;
    return (mode && [mode isEqualToString:GHLSSRuntimeString("game")]);
}

// v43：記進了哪一頁。
- (void)viewDidLoad {
    @try {
        [super viewDidLoad];
    } @catch (NSException *e) {
        const char *reason = [e reason] ? [[e reason] UTF8String] : "?";
        char buf[256];
        snprintf(buf, sizeof(buf), "v57 prefs-apppicker viewDidLoad EXCEPTION %s", reason);
        GHLSSPrefsLogLine(buf);
    }
    GHLSSPrefsLogLine("v57 prefs-page: AppPicker");
}

// v50：按鈕行自己派發（GHLSSDispatchButtonTap；框架自己的派發對裸方法名
// 不補冒號，點了沒反應——見 v42.1/v42.2；「重新掃描」按鈕靠這個才動）。
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if (GHLSSDispatchButtonTap(self, tableView, indexPath)) return;
    [super tableView:tableView didSelectRowAtIndexPath:indexPath];
}

- (NSArray *)specifiers {
    if (!_specifiers) {
        @try {
            NSMutableArray *specs = [NSMutableArray array];
            // 說明組。
            PSSpecifier *group = [PSSpecifier emptyGroupSpecifier];
            NSString *footerKey = GHLSSRuntimeString("footerText");
            // v56：遊戲模式復用同一頁——頁腳改說遊戲清單，開關只管遊戲清單。
            if ([self ghlssIsGamePicker]) {
                [group setProperty:GHLSSRuntimeString("选哪些 App 算游戏：进这些 App 自动开游戏模式（浮窗变淡、缩边、防误触；出来自动恢复）。开关只管游戏清单，不影响启动器。") forKey:footerKey];
            } else {
                [group setProperty:GHLSSRuntimeString("开的 App 出现在启动器/ARC 里（最多 12 个，自选 7 个）。清单在后台列举、缓存起来；刚装的 App 可能要等一会儿才出现，缺 App 时点下面「重新扫描」。") forKey:footerKey];
            }
            [specs addObject:group];
            // v50：重新掃描（清單是後台列舉的緩存，舊了會缺 App；點一下請
            // dylib 2 秒內重建緩存，下次開這頁就看到新的）。
            PSSpecifier *rescan = [PSSpecifier preferenceSpecifierNamed:GHLSSRuntimeString("重新扫描") target:self set:nil get:nil detail:nil cell:PSButtonCell edit:nil];
            [rescan setProperty:GHLSSRuntimeString("ghlssRescanApps") forKey:GHLSSRuntimeString("action")];
            [specs addObject:rescan];
            // 固定 5 個。
            for (int i = 0; i < 5; i++) {
                NSString *name = GHLSSRuntimeString(GHLSSFixedNames[i]);
                PSSpecifier *spec = [PSSpecifier preferenceSpecifierNamed:name target:self set:@selector(setPreferenceValue:specifier:) get:@selector(readPreferenceValue:) detail:nil cell:PSSwitchCell edit:nil];
                [spec setProperty:GHLSSRuntimeString(GHLSSFixedEnabledKeys[i]) forKey:GHLSSRuntimeString("key")];
                [spec setProperty:GHLSSRuntimeString("com.guhailong.splitscreen") forKey:GHLSSRuntimeString("defaults")];
                [spec setProperty:@(YES) forKey:GHLSSRuntimeString("default")];
                // v56：遊戲模式下固定行也按 bundleID 認遊戲清單（key 不走啟動器開關）。
                if ([self ghlssIsGamePicker]) [spec setProperty:GHLSSRuntimeString(GHLSSFixedBundleIDs[i]) forKey:GHLSSRuntimeString("ghlssGameBid")];
                UIImage *fixedIcon = GHLSSAppIconForBundleID(GHLSSRuntimeString(GHLSSFixedBundleIDs[i]));
                if (fixedIcon) [spec setProperty:fixedIcon forKey:GHLSSRuntimeString("iconImage")];
                [specs addObject:spec];
            }
            // 緩存的已安裝 App（跳過固定 5 個，按名字排過了）。
            NSArray *cached = [NSArray arrayWithContentsOfFile:GHLSSAppCacheFilePath()];
            BOOL anyCached = NO;
            if (cached) {
                for (id item in cached) {
                    if (![item isKindOfClass:[NSDictionary class]]) continue;
                    NSString *bidStr = item[GHLSSRuntimeString("bundleID")];
                    NSString *nameStr = item[GHLSSRuntimeString("name")];
                    if (!bidStr || [bidStr length] == 0) continue;
                    const char *bid = [bidStr UTF8String];
                    if (GHLSSFixedIndexForBundleID(bid) >= 0) continue;
                    anyCached = YES;
                    NSString *label = (nameStr && [nameStr length] > 0) ? nameStr : bidStr;
                    PSSpecifier *spec = [PSSpecifier preferenceSpecifierNamed:label target:self set:@selector(setPreferenceValue:specifier:) get:@selector(readPreferenceValue:) detail:nil cell:PSSwitchCell edit:nil];
                    NSString *selKey = [GHLSSRuntimeString("sel-") stringByAppendingString:bidStr];
                    [spec setProperty:selKey forKey:GHLSSRuntimeString("key")];
                    [spec setProperty:GHLSSRuntimeString("com.guhailong.splitscreen") forKey:GHLSSRuntimeString("defaults")];
                    [spec setProperty:@(NO) forKey:GHLSSRuntimeString("default")];
                    UIImage *cachedIcon = GHLSSAppIconForBundleID(bidStr);
                    if (cachedIcon) [spec setProperty:cachedIcon forKey:GHLSSRuntimeString("iconImage")];
                    [specs addObject:spec];
                }
            }
            if (!anyCached) {
                PSSpecifier *emptyGroup = [PSSpecifier emptyGroupSpecifier];
                [emptyGroup setProperty:GHLSSRuntimeString("还没有已安装 App 清单（后台列举中，稍后再开这个页）。") forKey:GHLSSRuntimeString("footerText")];
                [specs addObject:emptyGroup];
            }
            _specifiers = specs;
    
        } @catch (NSException *e) {
            const char *reason = [e reason] ? [[e reason] UTF8String] : "?";
            char buf[512];
            snprintf(buf, sizeof(buf), "v57 prefs-apppicker specifiers EXCEPTION %s", reason);
            GHLSSPrefsLogLine(buf);
            NSMutableArray *safe = [NSMutableArray array];
            PSSpecifier *group = [PSSpecifier emptyGroupSpecifier];
            [group setProperty:GHLSSRuntimeString("选择器页组装出错（已记进日志），先回上一页再试。") forKey:GHLSSRuntimeString("footerText")];
            [safe addObject:group];
            _specifiers = safe;
        }
        if (!_specifiers) _specifiers = [NSMutableArray array];
    }
    return _specifiers;
}

- (void)ghlssRescanApps:(PSSpecifier *)specifier {
    (void)specifier;
    GHLSSWritePrefsBool("rescanAppsRequested", YES);
    GHLSSPrefsLogLine("v57 prefs-apppicker rescan requested");
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:GHLSSRuntimeString("正在重新扫描") message:GHLSSRuntimeString("已请后台重新列举已安装 App，稍后再开这一页就看到新的清单。") preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:GHLSSRuntimeString("好") style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (id)readPreferenceValue:(PSSpecifier *)specifier {
    // v56：遊戲模式——開關讀遊戲清單（ghlssGameBid 固定行／sel- 自選行），不讀啟動器開關。
    if ([self ghlssIsGamePicker]) {
        NSString *bidStr = specifier.properties[GHLSSRuntimeString("ghlssGameBid")];
        if (!bidStr) {
            NSString *key = specifier.properties[GHLSSRuntimeString("key")];
            NSString *selPrefix = GHLSSRuntimeString("sel-");
            if (key && [key hasPrefix:selPrefix]) bidStr = [key substringFromIndex:[selPrefix length]];
        }
        if (!bidStr) return @(NO);
        return @(GHLSSGameAppContainsBid([bidStr UTF8String]));
    }
    NSString *key = specifier.properties[GHLSSRuntimeString("key")];
    if (!key) return @(NO);
    NSString *selPrefix = GHLSSRuntimeString("sel-");
    if ([key hasPrefix:selPrefix]) {
        NSString *bidStr = [key substringFromIndex:[selPrefix length]];
        return @(GHLSSAppInLauncher([bidStr UTF8String]));
    }
    // 固定 App：讀 prefs，沒設回 plist 的 default（開）。
    CFStringRef domain = GHLSSRuntimeCFString("com.guhailong.splitscreen");
    CFPropertyListRef v = NULL;
    if (domain) {
        CFStringRef cfKey = (__bridge CFStringRef)key;
        v = CFPreferencesCopyAppValue(cfKey, domain);
        CFRelease(domain);
    }
    if (v) {
        id value = (__bridge_transfer id)v;
        return value;
    }
    NSString *defaultName = GHLSSRuntimeString("default");
    id def = specifier.properties[defaultName];
    if (def) return def;
    return @(NO);
}

- (void)setPreferenceValue:(id)value specifier:(PSSpecifier *)specifier {
    // v56：遊戲模式——開關寫遊戲清單（沒有 7 個上限，不彈自選已滿提示）。
    if ([self ghlssIsGamePicker]) {
        BOOL on = [value boolValue];
        NSString *bidStr = specifier.properties[GHLSSRuntimeString("ghlssGameBid")];
        if (!bidStr) {
            NSString *key = specifier.properties[GHLSSRuntimeString("key")];
            NSString *selPrefix = GHLSSRuntimeString("sel-");
            if (key && [key hasPrefix:selPrefix]) bidStr = [key substringFromIndex:[selPrefix length]];
        }
        if (!bidStr) return;
        GHLSSSetGameAppBid([bidStr UTF8String], on);
        char buf[320];
        snprintf(buf, sizeof(buf), "v57 prefs-set: game app %s = %d", [bidStr UTF8String], on ? 1 : 0);
        GHLSSPrefsLogLine(buf);
        [self reloadSpecifiers];
        return;
    }
    NSString *key = specifier.properties[GHLSSRuntimeString("key")];
    if (!key) return;
    BOOL on = [value boolValue];
    NSString *selPrefix = GHLSSRuntimeString("sel-");
    if ([key hasPrefix:selPrefix]) {
        NSString *bidStr = [key substringFromIndex:[selPrefix length]];
        BOOL ok = GHLSSSetAppInLauncherPrefs([bidStr UTF8String], on);
        // v43：記自選 App 加／減（槽位滿了也會記，開關彈回關的原因就有了）。
        char buf[320];
        snprintf(buf, sizeof(buf), "v57 prefs-set: sel %s = %d ok %d", [bidStr UTF8String], on ? 1 : 0, ok ? 1 : 0);
        GHLSSPrefsLogLine(buf);
        if (!ok && on) {
            // 自選槽位滿了（7 個）：開關彈回關，告訴用戶。
            UIAlertController *alert = [UIAlertController alertControllerWithTitle:GHLSSRuntimeString("自选 App 已满") message:GHLSSRuntimeString("最多加 7 个自选 App，先关掉一个再加。") preferredStyle:UIAlertControllerStyleAlert];
            UIAlertAction *okAction = [UIAlertAction actionWithTitle:GHLSSRuntimeString("好") style:UIAlertActionStyleDefault handler:nil];
            [alert addAction:okAction];
            [self presentViewController:alert animated:YES completion:nil];
        }
        [self reloadSpecifiers];
        return;
    }
    // 固定 App：直接寫開關。
    CFStringRef domain = GHLSSRuntimeCFString("com.guhailong.splitscreen");
    if (domain) {
        CFStringRef cfKey = (__bridge CFStringRef)key;
        CFPreferencesSetAppValue(cfKey, (__bridge CFPropertyListRef)value, domain);
        CFPreferencesAppSynchronize(domain);
        CFRelease(domain);
    }
    // v43：記固定 App 開關改了什麼值。
    char buf[256];
    const char *keyC = [key UTF8String];
    const char *valC = [[value description] UTF8String];
    snprintf(buf, sizeof(buf), "v57 prefs-set: %s = %s", keyC ? keyC : "?", valC ? valC : "?");
    GHLSSPrefsLogLine(buf);
}

@end

// v58（§151-1）：排序頁灰字——只設 textLabel 沒用，PSStaticTextCell
// 看得見的那個 label 不是 textLabel；掃 cell 整棵子 view，所有 UILabel
// 都染 labelColor；再把 cellEnabled 開了（PSStaticTextCell 預設不可選
// 會灰，手勢總覽同款寫法）；手柄保持。
static void GHLSSSortCellFixUp(UITableViewCell *cell) {
    if (!cell) return;
    @try {
        UIColor *c = [UIColor labelColor];
        cell.textLabel.textColor = c;
        cell.detailTextLabel.textColor = c;
        NSMutableArray *stack = [NSMutableArray arrayWithObject:(UIView *)cell];
        while ([stack count] > 0) {
            UIView *v = [stack lastObject];
            [stack removeLastObject];
            if ([v isKindOfClass:[UILabel class]]) ((UILabel *)v).textColor = c;
            for (UIView *sub in v.subviews) [stack addObject:sub];
        }
        if ([cell isKindOfClass:[PSTableCell class]]) ((PSTableCell *)cell).cellEnabled = YES;
        cell.showsReorderControl = YES;
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
    } @catch (NSException *e) {
    }
}

// ── v46 排序頁 ──
// 兩個排序頁都是動態頁（行數看啟動器裡有幾個 App／工具欄固定 4 顆鈕），
// 表格常駐編輯模式：進頁就能拖右邊的手柄換順序，鬆手立刻存 prefs。
// PSListController 的表格只有一個 section（一個 PSGroupCell + 若干行），
// moveRowAtIndexPath 的 row 下標直接對到 orderedBids／orderedIDs 的下標。

// v46：「三屏 App 排序」——拖動換 ARC「全部 App」那段的順序
// （置頂／最近兩段不動：置頂按釘的時間、最近按用的時間）。
// 順序存 prefs 鍵 threeScreenAppOrder（逗號分隔的 bundleID）；
// 沒在表裡的 App（新加的）排最後、照原來槽位順序。dylib 那邊
// 建 ARC 時按這張表排（Tweak.xm 的 GHLSSSortBidsByAppOrder）。
@interface GHLSSAppSortListController : PSListController
@property (nonatomic, strong) NSMutableArray *orderedBids;
@end

@implementation GHLSSAppSortListController

- (void)viewDidLoad {
    // v56（§141-2 真 bug 修法）：先組順序、設 ivar，再調 super——
    // super viewDidLoad 會先載 specifiers，那時 orderedBids 還是 nil
    // 就組出 0 行且快取住，viewDidAppear reload 只重載空快取。
    NSMutableArray *ordered = [NSMutableArray array];
    char *raw = GHLSSPrefsCString("threeScreenAppOrder");
    if (raw) {
        NSString *rawStr = [NSString stringWithCString:raw encoding:NSUTF8StringEncoding];
        free(raw);
        if (rawStr && [rawStr length] > 0) {
            NSArray *parts = [rawStr componentsSeparatedByString:GHLSSRuntimeString(",")];
            for (NSString *bid in parts) {
                if ([bid length] > 0 && GHLSSAppInLauncher([bid UTF8String]) && ![ordered containsObject:bid]) [ordered addObject:bid];
            }
        }
    }
    // 預設順序：固定 5 個照槽位，再加自選槽 1–7 照槽位。
    for (int i = 0; i < 5; i++) {
        NSString *bid = [NSString stringWithCString:GHLSSFixedBundleIDs[i] encoding:NSUTF8StringEncoding];
        if (GHLSSAppInLauncher(GHLSSFixedBundleIDs[i]) && ![ordered containsObject:bid]) [ordered addObject:bid];
    }
    for (int sl = 1; sl <= 7; sl++) {
        char slotKey[32];
        snprintf(slotKey, sizeof(slotKey), "customApp%dBundleID", sl);
        char *slotBid = GHLSSPrefsCString(slotKey);
        if (slotBid && slotBid[0] != '\0') {
            NSString *bid = [NSString stringWithCString:slotBid encoding:NSUTF8StringEncoding];
            if (GHLSSAppInLauncher(slotBid) && ![ordered containsObject:bid]) [ordered addObject:bid];
        }
        if (slotBid) free(slotBid);
    }
    self.orderedBids = ordered;
    [super viewDidLoad];
    GHLSSPrefsLogLine("v57 prefs-page: AppSort");
    self.navigationItem.rightBarButtonItem = self.editButtonItem;
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    // v54：拖曳手柄沒出現過（19.log prefs-sort 全文 0 行）——兩層都開編輯：
    // 控制器層 self.editing（框架認）＋表格層 setEditing，並記一行驗證
    //（editing 是不是真開了、幾行），下次日誌看得見手柄到底有沒有出來。
    @try {
        [self setEditing:YES animated:NO];
    } @catch (NSException *e) {
        GHLSSPrefsLogLine("v57 prefs-sort: self setEditing EXCEPTION");
    }
    UITableView *tv = GHLSSSafeTableViewForController(self, "sort");
    if (tv) {
        @try {
            [tv reloadData];
            [tv setEditing:YES animated:NO];
            BOOL row0Reorder = NO;
            @try {
                UITableViewCell *row0 = [tv cellForRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:0]];
                if (row0) row0Reorder = row0.showsReorderControl;
            } @catch (NSException *e) {
            }
            char buf[256];
            snprintf(buf, sizeof(buf), "v58 prefs-sort: editing=%d rows=%ld row0Reorder=%d", (int)tv.editing, (long)[tv numberOfRowsInSection:0], (int)row0Reorder);
            GHLSSPrefsLogLine(buf);
        } @catch (NSException *e) {
            GHLSSPrefsLogLine("v57 prefs-sort: setEditing EXCEPTION");
        }
    }
}


// v57（§144-3 真根因）：行是 PSStaticTextCell，天生灰字不可選；且從沒
// 在 cell 上設 showsReorderControl——table view 不會自動設，預設 NO，
// 手柄從來沒出現過。兩個 override 強制補上（cellForRow 調 super 後改；
// willDisplayCell 再套一次，防 PSTableCell 的 setEditing 重設；調 super
// 前用 instancesRespondToSelector 守著）。
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = nil;
    if ([[self superclass] instancesRespondToSelector:@selector(tableView:cellForRowAtIndexPath:)]) {
        cell = [super tableView:tableView cellForRowAtIndexPath:indexPath];
    }
    if (!cell) return cell;
    GHLSSSortCellFixUp(cell);
    return cell;
}

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath {
    if ([[self superclass] instancesRespondToSelector:@selector(tableView:willDisplayCell:forRowAtIndexPath:)]) {
        [super tableView:tableView willDisplayCell:cell forRowAtIndexPath:indexPath];
    }
    GHLSSSortCellFixUp(cell);
}

- (NSArray *)specifiers {
    if (!_specifiers) {
        @try {
            NSMutableArray *specs = [NSMutableArray array];
            PSSpecifier *group = [PSSpecifier emptyGroupSpecifier];
            NSString *footerKey = GHLSSRuntimeString("footerText");
            if ([self.orderedBids count] == 0) {
                [group setProperty:GHLSSRuntimeString("启动器里还没有 App，先去「选择应用」加几个再来排。") forKey:footerKey];
            } else {
                [group setProperty:GHLSSRuntimeString("拖右边的手柄换顺序，松手立刻存；下次开 ARC，「全部 App」那段就按这个顺序排（置顶／最近两段不动；新加的 App 排最后）。") forKey:footerKey];
            }
            [specs addObject:group];
            for (NSString *bid in self.orderedBids) {
                NSString *name = GHLSSPrefsAppNameForBundleID([bid UTF8String]);
                PSSpecifier *spec = [PSSpecifier preferenceSpecifierNamed:name target:self set:nil get:nil detail:nil cell:PSStaticTextCell edit:nil];
                // v57（§144-3）：行上掛 App 圖標（AppPicker 同款寫法），一眼認得出是哪個 App。
                UIImage *icon = GHLSSAppIconForBundleID(bid);
                if (icon) [spec setProperty:icon forKey:GHLSSRuntimeString("iconImage")];
                [specs addObject:spec];
            }
            _specifiers = specs;
    
        } @catch (NSException *e) {
            const char *reason = [e reason] ? [[e reason] UTF8String] : "?";
            char buf[512];
            snprintf(buf, sizeof(buf), "v57 prefs-appsort specifiers EXCEPTION %s", reason);
            GHLSSPrefsLogLine(buf);
            NSMutableArray *safe = [NSMutableArray array];
            PSSpecifier *group = [PSSpecifier emptyGroupSpecifier];
            [group setProperty:GHLSSRuntimeString("排序页组装出错（已记进日志），先回上一页再试。") forKey:GHLSSRuntimeString("footerText")];
            [safe addObject:group];
            _specifiers = safe;
        }
        if (!_specifiers) _specifiers = [NSMutableArray array];
    }
    return _specifiers;
}

- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath {
    (void)tableView;
    (void)indexPath;
    return YES;
}

- (UITableViewCellEditingStyle)tableView:(UITableView *)tableView editingStyleForRowAtIndexPath:(NSIndexPath *)indexPath {
    (void)tableView;
    (void)indexPath;
    return UITableViewCellEditingStyleNone;
}

- (BOOL)tableView:(UITableView *)tableView shouldIndentWhileEditingRowAtIndexPath:(NSIndexPath *)indexPath {
    (void)tableView;
    (void)indexPath;
    return NO;
}

- (void)tableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)fromIndexPath toIndexPath:(NSIndexPath *)toIndexPath {
    (void)tableView;
    NSInteger from = fromIndexPath.row;
    NSInteger to = toIndexPath.row;
    if (from < 0 || to < 0 || from >= (NSInteger)[self.orderedBids count] || to >= (NSInteger)[self.orderedBids count]) return;
    if (from == to) return;
    NSString *bid = [self.orderedBids objectAtIndex:from];
    [self.orderedBids removeObjectAtIndex:from];
    [self.orderedBids insertObject:bid atIndex:to];
    NSString *joined = [self.orderedBids componentsJoinedByString:GHLSSRuntimeString(",")];
    GHLSSWritePrefsCString("threeScreenAppOrder", [joined UTF8String]);
    char buf[256];
    snprintf(buf, sizeof(buf), "v57 prefs-sort: app order moved %s %ld -> %ld", [bid UTF8String], (long)from, (long)to);
    GHLSSPrefsLogLine(buf);
}

@end

// v60：标题栏整个拿掉，「三屏工具栏排序」页跟着删（没有按钮可排了）。
// GHLSSToolbarSortListController、GHLSSToolbarSortIDs／Names 全删；
// App 排序页（GHLSSAppSortListController）不动。
// ── v42 動態頁 ──
// 下面 9 個控制器都是 prefs bundle 裡的自訂類（prefs bundle 不受
// dylib「禁自訂 ObjC 類」那條限；主插件 Tweak.xm 裡還是只能用
// Apple 類＋GHLSSLauncher 一個自訂類）。

// v42：「查看日誌」——設定 App 裡直接看分屏日誌：最新在最上面
//（讀尾段，預設最後 200 行）、能刷新、能清空（檔案截斷；寫不動就
// 誠實報失敗，不假裝能清）、能分享（系統分享表單）。
@interface GHLSSLogViewerListController : PSListController
@property (nonatomic, strong) UITextView *logView;
@property (nonatomic, assign) BOOL headerInstalled;
@end

@implementation GHLSSLogViewerListController

// v43：按鈕行自己派發（GHLSSDispatchButtonTap）；其他行走框架。
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if (GHLSSDispatchButtonTap(self, tableView, indexPath)) return;
    [super tableView:tableView didSelectRowAtIndexPath:indexPath];
}

// v50：重做——viewDidLoad 只建 UITextView（讀檔防呆在
// GHLSSLogTailNewestFirst 裡），不再碰 table；掛載移到 viewDidAppear
//（只掛一次，安全取表＋try/catch），掛不上就只記日誌、頁面照常可用
//（三個按鈕＋分享都還在）。
- (void)viewDidLoad {
    @try {
        [super viewDidLoad];
    } @catch (NSException *e) {
        const char *why = [e reason] ? [[e reason] UTF8String] : "?";
        char buf[256];
        snprintf(buf, sizeof(buf), "v57 prefs-log: super viewDidLoad EXCEPTION %s", why);
        GHLSSPrefsLogLine(buf);
    }
    GHLSSPrefsLogLine("v57 prefs-page: LogViewer");
    @try {
        UITextView *tv = [[UITextView alloc] initWithFrame:CGRectMake(0, 0, [UIScreen mainScreen].bounds.size.width, 420)];
        tv.font = [UIFont systemFontOfSize:11];
        tv.editable = NO;
        tv.backgroundColor = [UIColor colorWithWhite:0.95 alpha:1.0];
        tv.text = GHLSSLogTailNewestFirst();
        self.logView = tv;
        char buf[128];
        snprintf(buf, sizeof(buf), "v57 prefs-log: read %d lines", GHLSSLogTailLinesRead);
        GHLSSPrefsLogLine(buf);
    } @catch (NSException *e) {
        const char *why = [e reason] ? [[e reason] UTF8String] : "?";
        char buf[256];
        snprintf(buf, sizeof(buf), "v57 prefs-log: build text view EXCEPTION %s", why);
        GHLSSPrefsLogLine(buf);
        self.logView = nil;
    }
}

- (void)viewDidAppear:(BOOL)animated {
    @try {
        [super viewDidAppear:animated];
    } @catch (NSException *e) {
        const char *why = [e reason] ? [[e reason] UTF8String] : "?";
        char buf[256];
        snprintf(buf, sizeof(buf), "v57 prefs-log: super viewDidAppear EXCEPTION %s", why);
        GHLSSPrefsLogLine(buf);
    }
    if (self.logView && !self.headerInstalled) {
        UITableView *tv = GHLSSSafeTableViewForController(self, "log");
        if (tv) {
            @try {
                tv.tableHeaderView = self.logView;
                self.headerInstalled = YES;
                GHLSSPrefsLogLine("v57 prefs-log: header mounted");
            } @catch (NSException *e) {
                const char *why = [e reason] ? [[e reason] UTF8String] : "?";
                char buf[256];
                snprintf(buf, sizeof(buf), "v57 prefs-log: mount EXCEPTION %s", why);
                GHLSSPrefsLogLine(buf);
            }
        } else {
            GHLSSPrefsLogLine("v57 prefs-log: no table, header not mounted");
        }
    }
}

- (NSArray *)specifiers {
    if (!_specifiers) {
        @try {
            NSMutableArray *specs = [NSMutableArray array];
            PSSpecifier *group = [PSSpecifier emptyGroupSpecifier];
            [group setProperty:GHLSSRuntimeString("最新的在最上面（预设最后 200 行）；清空是把档案截断，新的日志会继续写进来。") forKey:GHLSSRuntimeString("footerText")];
            [specs addObject:group];
            NSArray *buttons = [NSArray arrayWithObjects:GHLSSRuntimeString("刷新"), GHLSSRuntimeString("清空"), GHLSSRuntimeString("分享"), nil];
            NSArray *actions = [NSArray arrayWithObjects:GHLSSRuntimeString("ghlssLogRefresh"), GHLSSRuntimeString("ghlssLogClear"), GHLSSRuntimeString("ghlssLogShare"), nil];
            for (NSUInteger i = 0; i < [buttons count]; i++) {
                PSSpecifier *spec = [PSSpecifier preferenceSpecifierNamed:[buttons objectAtIndex:i] target:self set:nil get:nil detail:nil cell:PSButtonCell edit:nil];
                [spec setProperty:[actions objectAtIndex:i] forKey:GHLSSRuntimeString("action")];
                [specs addObject:spec];
            }
            _specifiers = specs;
        } @catch (NSException *e) {
            const char *why = [e reason] ? [[e reason] UTF8String] : "?";
            char buf[256];
            snprintf(buf, sizeof(buf), "v57 prefs-log: specifiers EXCEPTION %s", why);
            GHLSSPrefsLogLine(buf);
            NSMutableArray *safe = [NSMutableArray array];
            PSSpecifier *group = [PSSpecifier emptyGroupSpecifier];
            [group setProperty:GHLSSRuntimeString("日志页组装出错（已记进日志），先回上一页再试。") forKey:GHLSSRuntimeString("footerText")];
            [safe addObject:group];
            _specifiers = safe;
        }
    }
    return _specifiers;
}

- (void)ghlssLogRefresh:(PSSpecifier *)specifier {
    (void)specifier;
    @try {
        if (self.logView) self.logView.text = GHLSSLogTailNewestFirst();
    } @catch (NSException *e) {
        GHLSSPrefsLogLine("v57 prefs-log: refresh EXCEPTION");
    }
}

- (void)ghlssLogClear:(PSSpecifier *)specifier {
    (void)specifier;
    NSError *err = nil;
    BOOL ok = [[NSData data] writeToFile:GHLSSLogFilePath() options:NSDataWritingAtomic error:&err];
    if (ok) {
        if (self.logView) self.logView.text = GHLSSLogTailNewestFirst();
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:GHLSSRuntimeString("日志已清空") message:GHLSSRuntimeString("日志档案已截断，新的日志会继续写进来。") preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:GHLSSRuntimeString("好") style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:alert animated:YES completion:nil];
    } else {
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:GHLSSRuntimeString("清空失败") message:GHLSSRuntimeString("日志档案写不动（权限问题），请用 Filza 手动清。") preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:GHLSSRuntimeString("好") style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:alert animated:YES completion:nil];
    }
}

- (void)ghlssLogShare:(PSSpecifier *)specifier {
    (void)specifier;
    NSURL *url = [NSURL fileURLWithPath:GHLSSLogFilePath()];
    if (!url) return;
    UIActivityViewController *share = [[UIActivityViewController alloc] initWithActivityItems:[NSArray arrayWithObject:url] applicationActivities:nil];
    [self presentViewController:share animated:YES completion:nil];
}

@end

// v42：「三屏組合」——上次組合（顯示 App 名字，點一下成對開）＋
// 最多 3 對常用組合（存目前這對、點一對切過去、能刪一對）。
// 設定 App 看不到現在開著的窗：成對開是寫 openThreeScreenPair 鍵，
// 主插件 2 秒 tick 讀到就開；「存目前這對」存的是上次開過的那對
//（要存現在這對，請在浮窗設定卡片裡點）。
@interface GHLSSPairListController : PSListController
@end

@implementation GHLSSPairListController

// v43：記進了哪一頁。
- (void)viewDidLoad {
    @try {
        [super viewDidLoad];
    } @catch (NSException *e) {
        const char *reason = [e reason] ? [[e reason] UTF8String] : "?";
        char buf[256];
        snprintf(buf, sizeof(buf), "v57 prefs-pairlist viewDidLoad EXCEPTION %s", reason);
        GHLSSPrefsLogLine(buf);
    }
    GHLSSPrefsLogLine("v57 prefs-page: PairList");
}

// v43：按鈕行自己派發（GHLSSDispatchButtonTap）；其他行走框架。
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if (GHLSSDispatchButtonTap(self, tableView, indexPath)) return;
    [super tableView:tableView didSelectRowAtIndexPath:indexPath];
}

- (NSArray *)specifiers {
    if (!_specifiers) {
        @try {
            NSMutableArray *specs = [NSMutableArray array];
            PSSpecifier *group = [PSSpecifier emptyGroupSpecifier];
            [group setProperty:GHLSSRuntimeString("点一对就成对开（主 App 浮窗 + 另一个侧窗），2 秒内开，不用 respring；最多存 3 对。") forKey:GHLSSRuntimeString("footerText")];
            [specs addObject:group];
            char *lastPair = GHLSSPrefsCString("lastThreeScreenPair");
            if (lastPair) {
                char a[128], b[128];
                if (GHLSSPrefsSplitPair(lastPair, a, sizeof(a), b, sizeof(b))) {
                    NSString *nameA = GHLSSPrefsAppNameForBundleID(a);
                    NSString *nameB = GHLSSPrefsAppNameForBundleID(b);
                    NSString *label = [[GHLSSRuntimeString("上次组合：") stringByAppendingString:nameA] stringByAppendingString:[[GHLSSRuntimeString(" + ") stringByAppendingString:nameB] stringByAppendingString:GHLSSRuntimeString("（点一下成对开）")]];
                    PSSpecifier *spec = [PSSpecifier preferenceSpecifierNamed:label target:self set:nil get:nil detail:nil cell:PSButtonCell edit:nil];
                    [spec setProperty:GHLSSRuntimeString("ghlssOpenPair") forKey:GHLSSRuntimeString("action")];
                    char pairBuf[256];
                    snprintf(pairBuf, sizeof(pairBuf), "%s|%s", a, b);
                    [spec setProperty:[NSString stringWithCString:pairBuf encoding:NSUTF8StringEncoding] forKey:GHLSSRuntimeString("pairValue")];
                    [specs addObject:spec];
                }
                free(lastPair);
            } else {
                PSSpecifier *emptyGroup = [PSSpecifier emptyGroupSpecifier];
                [emptyGroup setProperty:GHLSSRuntimeString("还没有上次的三屏组合（开一次三屏就有了）。") forKey:GHLSSRuntimeString("footerText")];
                [specs addObject:emptyGroup];
            }
            for (int s = 1; s <= 3; s++) {
                char key[32];
                snprintf(key, sizeof(key), "threeScreenPair%d", s);
                char *pair = GHLSSPrefsCString(key);
                if (!pair) continue;
                char a[128], b[128];
                if (GHLSSPrefsSplitPair(pair, a, sizeof(a), b, sizeof(b))) {
                    NSString *nameA = GHLSSPrefsAppNameForBundleID(a);
                    NSString *nameB = GHLSSPrefsAppNameForBundleID(b);
                    NSString *label = [[[[GHLSSRuntimeString("组合 ") stringByAppendingString:[NSString stringWithFormat:GHLSSRuntimeString("%d"), s]] stringByAppendingString:GHLSSRuntimeString("：")] stringByAppendingString:nameA] stringByAppendingString:[[GHLSSRuntimeString(" + ") stringByAppendingString:nameB] stringByAppendingString:GHLSSRuntimeString("（点一下成对开）")]];
                    PSSpecifier *spec = [PSSpecifier preferenceSpecifierNamed:label target:self set:nil get:nil detail:nil cell:PSButtonCell edit:nil];
                    [spec setProperty:GHLSSRuntimeString("ghlssOpenPair") forKey:GHLSSRuntimeString("action")];
                    char pairBuf[256];
                    snprintf(pairBuf, sizeof(pairBuf), "%s|%s", a, b);
                    [spec setProperty:[NSString stringWithCString:pairBuf encoding:NSUTF8StringEncoding] forKey:GHLSSRuntimeString("pairValue")];
                    [specs addObject:spec];
                    NSString *delLabel = [GHLSSRuntimeString("删除组合 ") stringByAppendingString:[NSString stringWithFormat:GHLSSRuntimeString("%d"), s]];
                    PSSpecifier *del = [PSSpecifier preferenceSpecifierNamed:delLabel target:self set:nil get:nil detail:nil cell:PSButtonCell edit:nil];
                    [del setProperty:GHLSSRuntimeString("ghlssDeletePair") forKey:GHLSSRuntimeString("action")];
                    [del setProperty:@(s) forKey:GHLSSRuntimeString("pairSlot")];
                    [specs addObject:del];
                }
                free(pair);
            }
            PSSpecifier *save = [PSSpecifier preferenceSpecifierNamed:GHLSSRuntimeString("存目前这对（上次开过的组合）") target:self set:nil get:nil detail:nil cell:PSButtonCell edit:nil];
            [save setProperty:GHLSSRuntimeString("ghlssSaveCurrentPair") forKey:GHLSSRuntimeString("action")];
            [specs addObject:save];
            PSSpecifier *note = [PSSpecifier emptyGroupSpecifier];
            [note setProperty:GHLSSRuntimeString("设定 App 看不到现在开著的窗，这里存的是上次开过的三屏组合；要存现在这对，请在浮窗设定卡片里点「存目前这对」。") forKey:GHLSSRuntimeString("footerText")];
            [specs addObject:note];
            _specifiers = specs;
    
        } @catch (NSException *e) {
            const char *reason = [e reason] ? [[e reason] UTF8String] : "?";
            char buf[512];
            snprintf(buf, sizeof(buf), "v57 prefs-pairlist specifiers EXCEPTION %s", reason);
            GHLSSPrefsLogLine(buf);
            NSMutableArray *safe = [NSMutableArray array];
            PSSpecifier *group = [PSSpecifier emptyGroupSpecifier];
            [group setProperty:GHLSSRuntimeString("三屏组合页组装出错（已记进日志），先回上一页再试。") forKey:GHLSSRuntimeString("footerText")];
            [safe addObject:group];
            _specifiers = safe;
        }
        if (!_specifiers) _specifiers = [NSMutableArray array];
    }
    return _specifiers;
}

- (void)ghlssOpenPair:(PSSpecifier *)specifier {
    NSString *pair = specifier.properties[GHLSSRuntimeString("pairValue")];
    if (!pair || [pair length] == 0) return;
    GHLSSWritePrefsCString("openThreeScreenPair", [pair UTF8String]);
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:GHLSSRuntimeString("已通知主插件") message:GHLSSRuntimeString("2 秒内成对开（主 App 浮窗 + 另一个侧窗），不用 respring。") preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:GHLSSRuntimeString("好") style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)ghlssSaveCurrentPair:(PSSpecifier *)specifier {
    (void)specifier;
    char *lastPair = GHLSSPrefsCString("lastThreeScreenPair");
    if (!lastPair) {
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:GHLSSRuntimeString("没有上次的组合") message:GHLSSRuntimeString("先开一次三屏，再来存。") preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:GHLSSRuntimeString("好") style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:alert animated:YES completion:nil];
        return;
    }
    int slot = 0;
    for (int s = 1; s <= 3; s++) {
        char key[32];
        snprintf(key, sizeof(key), "threeScreenPair%d", s);
        char *existing = GHLSSPrefsCString(key);
        BOOL empty = (!existing || existing[0] == '\0');
        if (existing) free(existing);
        if (empty) { slot = s; break; }
    }
    if (slot == 0) slot = 3;
    char key[32];
    snprintf(key, sizeof(key), "threeScreenPair%d", slot);
    GHLSSWritePrefsCString(key, lastPair);
    free(lastPair);
    [self reloadSpecifiers];
    NSString *msg = [[GHLSSRuntimeString("已存成组合 ") stringByAppendingString:[NSString stringWithFormat:GHLSSRuntimeString("%d"), slot]] stringByAppendingString:GHLSSRuntimeString("。")];
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:GHLSSRuntimeString("已存目前这对") message:msg preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:GHLSSRuntimeString("好") style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)ghlssDeletePair:(PSSpecifier *)specifier {
    NSNumber *slotNum = specifier.properties[GHLSSRuntimeString("pairSlot")];
    int slot = slotNum ? [slotNum intValue] : 0;
    if (slot < 1 || slot > 3) return;
    char key[32];
    snprintf(key, sizeof(key), "threeScreenPair%d", slot);
    GHLSSWritePrefsCString(key, "");
    [self reloadSpecifiers];
}

@end


// v53：悬浮图标——相冊選圖（PHPicker）、居中裁方形 512、
// 存設定目錄固定檔名、寫 doraemonIconCustom 鍵；恢復默認刪檔＋清鍵，
// 哆啦A夢鈕 2 秒內回默認圖（dylib tick 重讀）。照卡片頭像控制器樣式。
@interface GHLSSDoraemonIconListController : PSListController <PHPickerViewControllerDelegate>
@property (nonatomic, strong) UIImageView *previewView;
@property (nonatomic, strong) UIView *headerView;
@property (nonatomic, assign) BOOL headerInstalled;
@end

@implementation GHLSSDoraemonIconListController

// v43：按鈕行自己派發（GHLSSDispatchButtonTap）；其他行走框架。
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if (GHLSSDispatchButtonTap(self, tableView, indexPath)) return;
    [super tableView:tableView didSelectRowAtIndexPath:indexPath];
}

// v50：掛載移到 viewDidAppear（安全取表＋try/catch）；viewDidLoad 只建
// 預覽區，不再碰 table。
- (void)viewDidLoad {
    @try {
        [super viewDidLoad];
    } @catch (NSException *e) {
        const char *why = [e reason] ? [[e reason] UTF8String] : "?";
        char buf[256];
        snprintf(buf, sizeof(buf), "v57 prefs-doraemonicon: super viewDidLoad EXCEPTION %s", why);
        GHLSSPrefsLogLine(buf);
    }
    GHLSSPrefsLogLine("v57 prefs-page: DoraemonIcon");
    @try {
        CGFloat w = [UIScreen mainScreen].bounds.size.width;
        UIView *container = [[UIView alloc] initWithFrame:CGRectMake(0, 0, w, 160)];
        container.backgroundColor = [UIColor whiteColor];
        UIImageView *iv = [[UIImageView alloc] initWithFrame:CGRectMake((w - 120) / 2.0, 20, 120, 120)];
        iv.layer.cornerRadius = 60.0;
        iv.layer.masksToBounds = YES;
        iv.layer.borderWidth = 2.0;
        iv.layer.borderColor = [UIColor colorWithRed:0.83 green:0.68 blue:0.21 alpha:1.0].CGColor;
        iv.contentMode = UIViewContentModeScaleAspectFill;
        [container addSubview:iv];
        self.previewView = iv;
        self.headerView = container;
        [self ghlssRefreshDoraemonPreview];
    } @catch (NSException *e) {
        const char *why = [e reason] ? [[e reason] UTF8String] : "?";
        char buf[256];
        snprintf(buf, sizeof(buf), "v57 prefs-doraemonicon: viewDidLoad EXCEPTION %s", why);
        GHLSSPrefsLogLine(buf);
    }
}

- (void)viewDidAppear:(BOOL)animated {
    @try {
        [super viewDidAppear:animated];
    } @catch (NSException *e) {
        GHLSSPrefsLogLine("v57 prefs-doraemonicon: super viewDidAppear EXCEPTION");
    }
    if (self.headerView && !self.headerInstalled) {
        UITableView *tv = GHLSSSafeTableViewForController(self, "doraemonicon");
        if (tv) {
            @try {
                tv.tableHeaderView = self.headerView;
                self.headerInstalled = YES;
                GHLSSPrefsLogLine("v57 prefs-doraemonicon: header mounted");
            } @catch (NSException *e) {
                const char *why = [e reason] ? [[e reason] UTF8String] : "?";
                char buf[256];
                snprintf(buf, sizeof(buf), "v57 prefs-doraemonicon: mount EXCEPTION %s", why);
                GHLSSPrefsLogLine(buf);
            }
        } else {
            GHLSSPrefsLogLine("v57 prefs-doraemonicon: no table, header not mounted");
        }
    }
}

- (void)ghlssRefreshDoraemonPreview {
    @try {
        UIImage *img = [UIImage imageWithContentsOfFile:GHLSSDoraemonIconPath()];
        if (!img) {
            NSBundle *bundle = [NSBundle bundleForClass:[self class]];
            NSString *path = [bundle pathForResource:GHLSSRuntimeString("doraemon-button") ofType:GHLSSRuntimeString("png")];
            if (path) img = [UIImage imageWithContentsOfFile:path];
        }
        self.previewView.image = img;
    } @catch (NSException *e) {
        GHLSSPrefsLogLine("v57 prefs-doraemonicon: refresh EXCEPTION");
    }
}

- (NSArray *)specifiers {
    if (!_specifiers) {
        NSMutableArray *specs = [NSMutableArray array];
        PSSpecifier *group = [PSSpecifier emptyGroupSpecifier];
        [group setProperty:GHLSSRuntimeString("上面那张圆图是现在的悬浮图标；从相册选一张、居中裁成方形存起来，哆啦A梦钮 2 秒内就换成它。") forKey:GHLSSRuntimeString("footerText")];
        [specs addObject:group];
        PSSpecifier *pick = [PSSpecifier preferenceSpecifierNamed:GHLSSRuntimeString("从相册选图（换钮图片）") target:self set:nil get:nil detail:nil cell:PSButtonCell edit:nil];
        [pick setProperty:GHLSSRuntimeString("ghlssPickDoraemonIcon") forKey:GHLSSRuntimeString("action")];
        [specs addObject:pick];
        PSSpecifier *restore = [PSSpecifier preferenceSpecifierNamed:GHLSSRuntimeString("恢复默认哆啦A梦图") target:self set:nil get:nil detail:nil cell:PSButtonCell edit:nil];
        [restore setProperty:GHLSSRuntimeString("ghlssRestoreDoraemonIcon") forKey:GHLSSRuntimeString("action")];
        [specs addObject:restore];
        _specifiers = specs;
    }
    return _specifiers;
}

- (void)ghlssPickDoraemonIcon:(PSSpecifier *)specifier {
    (void)specifier;
    PHPickerConfiguration *config = [[PHPickerConfiguration alloc] init];
    config.filter = [PHPickerFilter imagesFilter];
    config.selectionLimit = 1;
    PHPickerViewController *picker = [[PHPickerViewController alloc] initWithConfiguration:config];
    picker.delegate = self;
    [self presentViewController:picker animated:YES completion:nil];
}

- (void)ghlssRestoreDoraemonIcon:(PSSpecifier *)specifier {
    (void)specifier;
    [[NSFileManager defaultManager] removeItemAtPath:GHLSSDoraemonIconPath() error:nil];
    GHLSSWritePrefsBool("doraemonIconCustom", NO);
    [self ghlssRefreshDoraemonPreview];
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:GHLSSRuntimeString("已恢复默认哆啦A梦图") message:GHLSSRuntimeString("哆啦A梦钮回到默认图。") preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:GHLSSRuntimeString("好") style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)picker:(PHPickerViewController *)picker didFinishPicking:(NSArray<PHPickerResult *> *)results {
    [picker dismissViewControllerAnimated:YES completion:nil];
    if (!results || [results count] == 0) return;
    NSItemProvider *provider = [results objectAtIndex:0].itemProvider;
    if (!provider) return;
    [provider loadObjectOfClass:[UIImage class] completionHandler:^(id object, NSError *error) {
        (void)error;
        if (![object isKindOfClass:[UIImage class]]) return;
        UIImage *picked = (UIImage *)object;
        dispatch_async(dispatch_get_main_queue(), ^{
            UIImage *square = GHLSSPrefsSquareCropImage(picked, 512.0);
            if (!square) return;
            NSData *data = UIImageJPEGRepresentation(square, 0.85);
            BOOL ok = data && [data writeToFile:GHLSSDoraemonIconPath() atomically:YES];
            if (ok) {
                GHLSSWritePrefsBool("doraemonIconCustom", YES);
                [self ghlssRefreshDoraemonPreview];
                UIAlertController *alert = [UIAlertController alertControllerWithTitle:GHLSSRuntimeString("钮图片已换好") message:GHLSSRuntimeString("哆啦A梦钮 2 秒内就换成这张。") preferredStyle:UIAlertControllerStyleAlert];
                [alert addAction:[UIAlertAction actionWithTitle:GHLSSRuntimeString("好") style:UIAlertActionStyleDefault handler:nil]];
                [self presentViewController:alert animated:YES completion:nil];
            } else {
                UIAlertController *alert = [UIAlertController alertControllerWithTitle:GHLSSRuntimeString("保存钮图片失败") message:GHLSSRuntimeString("图片写不进设定目录。") preferredStyle:UIAlertControllerStyleAlert];
                [alert addAction:[UIAlertAction actionWithTitle:GHLSSRuntimeString("好") style:UIAlertActionStyleDefault handler:nil]];
                [self presentViewController:alert animated:YES completion:nil];
            }
        });
    }];
}

@end

// v59：背景圖輪播頁——設定主頁橫幅點進來。做法學 CarPlayMaker 影片
// （多張卡片扇形堆疊、選中的在前＋高亮邊框、兩張以上 3 秒自動換、
// 內置幾張點一下直接用），代碼與圖片全部自己寫／用自己的圖：
// 內置只用 prefs bundle 裡的龍頭 ghlss-bg-dragon.jpg 和哆啦A夢
// doraemon-button@3x.png，影片裡的動漫圖不用。槽位檔 cardbg-0..5.jpg
// ＋count／index 鍵（見上面 GHLSSCardBgSlotPath 一組 helper）；當前圖
// 仍寫回 cardbg.jpg，橫幅＋浮窗卡片不用改讀取方。計時器在設定主頁
// （root 控制器）跑，這頁只管選圖。
// v61：壁紙挑選頁重做——照 CarPlayMaker 影片的挑選頁結構來排
// （頁頭＋01 選擇照片＋大橫卡扇形疊＋狀態行＋藍色更換圖片鈕＋內置壁紙
// 縮圖列），只學版式不抄名字／圖標／底欄／分辨率那排。內置五張：
// 粉／白／綠三張動漫圖是皇上 2026-11-15 19:22 定的正式版內置（從皇上
// 發來的 CarPlayMaker 影片錄屏裡裁出，皇上說正式版先用著；綠那張只有
// 63×48，放大全圖會糊，只適合當縮圖看），另加龍頭圖＋哆啦A夢圖。
// v62：挑選頁細節再照影片改（無龍頭頁頭／01、粉紅選中邊、標籤改到底卡
// 帶顏色字、無暫停鈕、灰調整、紅圓刪除），影片三張排前面（白第 1 張）；
// 三張動漫圖換真高清（白 1920×1080 彼岸桌面、粉 1100×827 哲風預覽、
// 綠＝初音穿出電腦屏幕 1920×1080 彼岸桌面），另加紅裙白髮少女（哲風
// 4K）當第六張內置。舊槽位一次遷移：認出舊內置就換高清＋重排。
// 槽位檔 cardbg-0..5.jpg＋count／index 鍵不動；計時器這頁自己跑（root
// 主頁的計時器離開主頁就停，這頁進來才開始，出去就停）。
@implementation GHLSSCardBgCarouselListController

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if (GHLSSDispatchButtonTap(self, tableView, indexPath)) return;
    [super tableView:tableView didSelectRowAtIndexPath:indexPath];
}

- (void)viewDidLoad {
    @try {
        [super viewDidLoad];
    } @catch (NSException *e) {
        GHLSSPrefsLogLine("v61 prefs-bgcarousel: super viewDidLoad EXCEPTION");
    }
    GHLSSPrefsLogLine("v61 prefs-page: CardBgCarousel");
    self.title = GHLSSRuntimeString("壁纸");
    @try {
        [self ghlssBuildWallpaperPage];
    } @catch (NSException *e) {
        GHLSSPrefsLogLine("v61 prefs-bgcarousel: build EXCEPTION");
    }
}

- (void)viewDidAppear:(BOOL)animated {
    @try {
        [super viewDidAppear:animated];
    } @catch (NSException *e) {
        GHLSSPrefsLogLine("v61 prefs-bgcarousel: super viewDidAppear EXCEPTION");
    }
    if (self.headerView && !self.headerInstalled) {
        UITableView *tv = GHLSSSafeTableViewForController(self, "bgcarousel");
        if (tv) {
            @try {
                tv.tableHeaderView = self.headerView;
                tv.backgroundColor = [UIColor whiteColor];
                self.headerInstalled = YES;
                GHLSSPrefsLogLine("v61 prefs-bgcarousel: header mounted");
            } @catch (NSException *e) {
                GHLSSPrefsLogLine("v61 prefs-bgcarousel: mount EXCEPTION");
            }
        } else {
            GHLSSPrefsLogLine("v61 prefs-bgcarousel: no table, header not mounted");
        }
    }
    [self ghlssRebuildCardStack];
    [self ghlssStartPickerTimer];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [self ghlssStopPickerTimer];
}

// v62：挑選頁整頁自定視圖（不再是普通設定列表的樣子），按 iPhone 11
// 邏輯寬 414 排：標題 22＋說明 40＋卡片區 300＋狀態行 40＋操作行 56＋
// 內置區 118，總高 606。卡片接近滿寬（屏寬減 32，16:10 橫向）。
// v62：頁頭龍頭＋01 徽章拿掉（影片那頁只有「選擇照片」＋說明）。
// 進頁先跑一次 v62 槽位遷移（舊內置換高清、影片三張排前面、白第 1 張）。
- (void)ghlssBuildWallpaperPage {
    @try {
        GHLSSCardBgMigrateV62([NSBundle bundleForClass:[self class]]);
    } @catch (NSException *e) {
        GHLSSPrefsLogLine("v62 prefs-bgcarousel: migrate EXCEPTION");
    }
    CGFloat w = [UIScreen mainScreen].bounds.size.width;
    if (w <= 0) w = 414.0;
    UIView *container = [[UIView alloc] initWithFrame:CGRectMake(0, 0, w, 606)];
    container.backgroundColor = [UIColor whiteColor];

    // 選擇照片＋說明。
    UILabel *secLb = [[UILabel alloc] initWithFrame:CGRectMake(16, 16, w - 32, 22)];
    secLb.text = GHLSSRuntimeString("选择照片");
    secLb.font = [UIFont boldSystemFontOfSize:16];
    secLb.textColor = [UIColor blackColor];
    [container addSubview:secLb];
    UILabel *helpLb = [[UILabel alloc] initWithFrame:CGRectMake(16, 44, w - 32, 40)];
    helpLb.text = GHLSSRuntimeString("点一张卡片选中它，再选图或调整；一次能选多张，按顺序填进空卡（满了就从当前卡往后替换）；有两张以上时 3 秒自动换一张。");
    helpLb.font = [UIFont systemFontOfSize:12];
    helpLb.textColor = [UIColor colorWithWhite:0.45 alpha:1.0];
    helpLb.numberOfLines = 0;
    [container addSubview:helpLb];

    // 大橫卡扇形區（卡片由 ghlssRebuildCardStack 動態填）。
    UIView *stack = [[UIView alloc] initWithFrame:CGRectMake(0, 92, w, 300)];
    stack.backgroundColor = [UIColor clearColor];
    [container addSubview:stack];
    self.stackView = stack;
    self.stackButtons = [NSMutableArray array];

    // 狀態行：綠勾「已選 X/6 張」＋右側輸出尺寸。v62：暫停鈕拿掉
    //（影片那頁沒有），輪播開關移到下面設定列的「自動輪播」行。
    UILabel *checkLb = [[UILabel alloc] initWithFrame:CGRectMake(16, 402, 20, 30)];
    checkLb.text = GHLSSRuntimeString("✓");
    checkLb.font = [UIFont boldSystemFontOfSize:16];
    checkLb.textColor = [UIColor colorWithRed:0.2 green:0.7 blue:0.25 alpha:1.0];
    checkLb.textAlignment = NSTextAlignmentCenter;
    [container addSubview:checkLb];
    UILabel *countLb = [[UILabel alloc] initWithFrame:CGRectMake(40, 402, 120, 30)];
    countLb.font = [UIFont systemFontOfSize:14];
    countLb.textColor = [UIColor blackColor];
    [container addSubview:countLb];
    self.wallStatusLabel = countLb;
    UILabel *outLb = [[UILabel alloc] initWithFrame:CGRectMake(w - 160, 402, 144, 30)];
    outLb.font = [UIFont systemFontOfSize:13];
    outLb.textColor = [UIColor colorWithWhite:0.45 alpha:1.0];
    outLb.textAlignment = NSTextAlignmentRight;
    [container addSubview:outLb];
    self.wallOutputLabel = outLb;

    // 操作行：藍色大鈕「更換圖片」＋「調整」＋紅色刪除。
    UIButton *replaceBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    replaceBtn.frame = CGRectMake(16, 440, w - 164, 48);
    replaceBtn.backgroundColor = [UIColor colorWithRed:0.0 green:0.48 blue:1.0 alpha:1.0];
    replaceBtn.layer.cornerRadius = 12.0;
    replaceBtn.titleLabel.font = [UIFont boldSystemFontOfSize:16];
    [replaceBtn setTitle:GHLSSRuntimeString("🖼 更换图片") forState:UIControlStateNormal];
    [replaceBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [replaceBtn addTarget:self action:@selector(ghlssReplaceWallpaperImages:) forControlEvents:UIControlEventTouchUpInside];
    [container addSubview:replaceBtn];
    UIButton *adjustBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    adjustBtn.frame = CGRectMake(w - 140, 440, 64, 48);
    adjustBtn.backgroundColor = [UIColor colorWithWhite:0.93 alpha:1.0];
    adjustBtn.layer.cornerRadius = 12.0;
    adjustBtn.titleLabel.font = [UIFont systemFontOfSize:15];
    [adjustBtn setTitle:GHLSSRuntimeString("调整") forState:UIControlStateNormal];
    [adjustBtn setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
    [adjustBtn addTarget:self action:@selector(ghlssAdjustCurrentWallpaper:) forControlEvents:UIControlEventTouchUpInside];
    [container addSubview:adjustBtn];
    UIButton *deleteBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    deleteBtn.frame = CGRectMake(w - 64, 440, 48, 48);
    deleteBtn.backgroundColor = [UIColor colorWithRed:1.0 green:0.23 blue:0.19 alpha:1.0];
    deleteBtn.layer.cornerRadius = 24.0;
    UIImage *trashImg = [UIImage systemImageNamed:GHLSSRuntimeString("trash")];
    if (trashImg) [deleteBtn setImage:[trashImg imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate] forState:UIControlStateNormal];
    deleteBtn.tintColor = [UIColor whiteColor];
    [deleteBtn addTarget:self action:@selector(ghlssDeleteCurrentWallpaper:) forControlEvents:UIControlEventTouchUpInside];
    [container addSubview:deleteBtn];
    self.wallDeleteButton = deleteBtn;

    // 內置壁紙區：標題＋橫排小縮圖（點一張直接用）。
    UILabel *builtinTitle = [[UILabel alloc] initWithFrame:CGRectMake(16, 504, 120, 20)];
    builtinTitle.text = GHLSSRuntimeString("内置壁纸");
    builtinTitle.font = [UIFont boldSystemFontOfSize:15];
    builtinTitle.textColor = [UIColor blackColor];
    [container addSubview:builtinTitle];
    UILabel *builtinHint = [[UILabel alloc] initWithFrame:CGRectMake(w - 140, 504, 124, 20)];
    builtinHint.text = GHLSSRuntimeString("点一张直接用");
    builtinHint.font = [UIFont systemFontOfSize:12];
    builtinHint.textColor = [UIColor colorWithWhite:0.45 alpha:1.0];
    builtinHint.textAlignment = NSTextAlignmentRight;
    [container addSubview:builtinHint];
    UIScrollView *thumbScroll = [[UIScrollView alloc] initWithFrame:CGRectMake(0, 530, w, 76)];
    thumbScroll.showsHorizontalScrollIndicator = NO;
    thumbScroll.backgroundColor = [UIColor clearColor];
    thumbScroll.contentSize = CGSizeMake(16 + 6 * 110 + 5 * 10 + 16, 76);
    for (int i = 0; i < 6; i++) {
        NSString *res = nil, *type = nil;
        if (![self ghlssWallBuiltinForTag:i resource:&res type:&type]) continue;
        NSBundle *bundle = [NSBundle bundleForClass:[self class]];
        NSString *path = [bundle pathForResource:res ofType:type];
        UIImage *img = path ? [UIImage imageWithContentsOfFile:path] : nil;
        UIButton *th = [UIButton buttonWithType:UIButtonTypeCustom];
        th.frame = CGRectMake(16 + i * 120, 5, 110, 66);
        th.layer.cornerRadius = 10.0;
        th.clipsToBounds = YES;
        th.layer.borderWidth = 1.0;
        th.layer.borderColor = [[UIColor colorWithWhite:0.88 alpha:1.0] CGColor];
        if (img) [th setBackgroundImage:img forState:UIControlStateNormal];
        else th.backgroundColor = [UIColor colorWithWhite:0.92 alpha:1.0];
        th.tag = 2000 + i;
        [th addTarget:self action:@selector(ghlssBuiltinThumbTapped:) forControlEvents:UIControlEventTouchUpInside];
        [thumbScroll addSubview:th];
    }
    [container addSubview:thumbScroll];

    self.headerView = container;
}

// 內置圖對照（tag 0..5：粉／白／綠三張動漫圖＋龍頭＋哆啦A夢＋紅裙）。
- (BOOL)ghlssWallBuiltinForTag:(int)tag resource:(NSString **)outRes type:(NSString **)outType {
    const char *res = NULL;
    const char *type = "jpg";
    if (tag == 0) res = "ghlss-bg-pink";
    else if (tag == 1) res = "ghlss-bg-white";
    else if (tag == 2) res = "ghlss-bg-green";
    else if (tag == 3) res = "ghlss-bg-dragon";
    else if (tag == 4) { res = "doraemon-button@3x"; type = "png"; }
    else if (tag == 5) res = "ghlss-bg-reddress";
    else return NO;
    if (outRes) *outRes = GHLSSRuntimeString(res);
    if (outType) *outType = GHLSSRuntimeString(type);
    return YES;
}

- (void)ghlssBuiltinThumbTapped:(UIButton *)sender {
    int tag = (int)sender.tag - 2000;
    NSString *res = nil, *type = nil;
    if (![self ghlssWallBuiltinForTag:tag resource:&res type:&type]) return;
    const char *tagC = [res UTF8String];
    [self ghlssAddBuiltinBgWithResource:res ofType:type tag:tagC];
}

// v61：挑選頁自己的 3 秒輪播計時（進頁開始、離頁就停；開關跟主頁橫幅
// 共用 cardBgRotate，暫停鈕能停／繼續）。
- (void)ghlssStartPickerTimer {
    [self ghlssStopPickerTimer];
    if (GHLSSCardBgCountValue() < 2) return;
    if (!GHLSSCardBgRotateEnabled()) return;
    NSTimer *t = [NSTimer scheduledTimerWithTimeInterval:3.0 target:self selector:@selector(ghlssPickerTimerFired:) userInfo:nil repeats:YES];
    self.wallPickerTimer = t;
}

- (void)ghlssStopPickerTimer {
    [self.wallPickerTimer invalidate];
    self.wallPickerTimer = nil;
}

- (void)ghlssPickerTimerFired:(NSTimer *)timer {
    (void)timer;
    int n = GHLSSCardBgCountValue();
    if (n < 2 || !GHLSSCardBgRotateEnabled()) return;
    int next = (GHLSSCardBgIndexValue() + 1) % n;
    GHLSSCardBgSetCurrent(next);
    [self ghlssRebuildCardStack];
}

// 狀態行：已選張數、當前圖真實尺寸、刪除鈕可用與否。
- (void)ghlssRefreshWallpaperStatus {
    int n = GHLSSCardBgCountValue();
    int cur = GHLSSCardBgIndexValue();
    if (self.wallStatusLabel) {
        char buf[64];
        snprintf(buf, sizeof(buf), "已选 %d/6 张", n);
        self.wallStatusLabel.text = GHLSSRuntimeString(buf);
    }
    if (self.wallOutputLabel) {
        if (n > 0) {
            UIImage *img = [UIImage imageWithContentsOfFile:GHLSSCardBgSlotPath(cur)];
            if (img) {
                char buf[64];
                snprintf(buf, sizeof(buf), "输出 %d × %d", (int)img.size.width, (int)img.size.height);
                self.wallOutputLabel.text = GHLSSRuntimeString(buf);
            } else {
                self.wallOutputLabel.text = GHLSSRuntimeString("输出 —");
            }
        } else {
            self.wallOutputLabel.text = GHLSSRuntimeString("尚未选图");
        }
    }
    if (self.wallDeleteButton) {
        self.wallDeleteButton.enabled = (n > 0);
        self.wallDeleteButton.alpha = (n > 0) ? 1.0 : 0.4;
    }
}

// 大橫卡扇形疊：卡片接近滿寬（屏寬減 32，16:10），只顯示已填的卡；
// 當前那張在最前、擺正、深色邊＋陰影；前一張左上斜著露、後一張右下
// 斜著露；兩張時只露一張在後；零張時一張灰卡＋提示。點卡選中它。
- (void)ghlssRebuildCardStack {
    if (!self.stackView) return;
    @try {
        for (UIView *v in self.stackButtons) [v removeFromSuperview];
        [self.stackButtons removeAllObjects];
        int n = GHLSSCardBgCountValue();
        int cur = GHLSSCardBgIndexValue();
        CGFloat w = self.stackView.bounds.size.width;
        if (w <= 0) w = [UIScreen mainScreen].bounds.size.width;
        CGFloat cardW = w - 32.0, cardH = cardW * 10.0 / 16.0;
        CGFloat cx = w / 2.0, cy = 150.0;
        if (n <= 0) {
            UIView *ph = [[UIView alloc] initWithFrame:CGRectMake(16, cy - cardH / 2.0, cardW, cardH)];
            ph.backgroundColor = [UIColor colorWithWhite:0.92 alpha:1.0];
            ph.layer.cornerRadius = 14.0;
            UILabel *lb = [[UILabel alloc] initWithFrame:CGRectMake(0, cardH / 2.0 - 12, cardW, 24)];
            lb.text = GHLSSRuntimeString("还没有壁纸，点「更换图片」加入");
            lb.font = [UIFont systemFontOfSize:15];
            lb.textColor = [UIColor grayColor];
            lb.textAlignment = NSTextAlignmentCenter;
            [ph addSubview:lb];
            UIButton *tap = [UIButton buttonWithType:UIButtonTypeCustom];
            tap.frame = ph.bounds;
            [tap addTarget:self action:@selector(ghlssReplaceWallpaperImages:) forControlEvents:UIControlEventTouchUpInside];
            [ph addSubview:tap];
            [self.stackView addSubview:ph];
            [self.stackButtons addObject:ph];
        } else {
            int prev = (cur - 1 + n) % n;
            int next = (cur + 1) % n;
            if (n == 2) {
                [self ghlssAddFanCardForSlot:next center:CGPointMake(cx + 16.0, cy + 18.0) angle:-0.10 front:NO label:YES cardW:cardW cardH:cardH];
            } else if (n > 2) {
                [self ghlssAddFanCardForSlot:prev center:CGPointMake(cx - 16.0, cy - 18.0) angle:0.12 front:NO label:NO cardW:cardW cardH:cardH];
                [self ghlssAddFanCardForSlot:next center:CGPointMake(cx + 16.0, cy + 18.0) angle:-0.10 front:NO label:YES cardW:cardW cardH:cardH];
            }
            [self ghlssAddFanCardForSlot:cur center:CGPointMake(cx, cy) angle:0.0 front:YES label:NO cardW:cardW cardH:cardH];
        }
    } @catch (NSException *e) {
        GHLSSPrefsLogLine("v61 prefs-bgcarousel: rebuild EXCEPTION");
    }
    [self ghlssRefreshWallpaperStatus];
}

// 一張扇形卡：容器（圓角＋前卡粉紅邊＋陰影）＋滿幅圖＋透明點按層；
// v62：標籤改貼在下面那張卡左下角（影片那樣），格式「第 X 張 · 色」
//（顏色名是槽位遷移／點內置時記的，沒記的只寫「第 X 張」）。
- (void)ghlssAddFanCardForSlot:(int)slot center:(CGPoint)center angle:(CGFloat)angle front:(BOOL)front label:(BOOL)showLabel cardW:(CGFloat)cardW cardH:(CGFloat)cardH {
    UIImage *img = [UIImage imageWithContentsOfFile:GHLSSCardBgSlotPath(slot)];
    UIView *card = [[UIView alloc] init];
    card.bounds = CGRectMake(0, 0, cardW, cardH);
    card.center = center;
    card.layer.cornerRadius = 14.0;
    if (front) {
        card.layer.borderWidth = 3.0;
        card.layer.borderColor = [UIColor colorWithRed:1.0 green:0.176 blue:0.471 alpha:1.0].CGColor;
        card.layer.shadowColor = [UIColor blackColor].CGColor;
        card.layer.shadowOpacity = 0.4;
        card.layer.shadowOffset = CGSizeMake(0, 4);
        card.layer.shadowRadius = 10.0;
    } else {
        card.layer.borderWidth = 1.0;
        card.layer.borderColor = [[UIColor whiteColor] colorWithAlphaComponent:0.8].CGColor;
    }
    UIImageView *iv = [[UIImageView alloc] initWithFrame:card.bounds];
    iv.contentMode = UIViewContentModeScaleAspectFill;
    iv.clipsToBounds = YES;
    iv.layer.cornerRadius = 14.0;
    iv.image = img;
    iv.backgroundColor = [UIColor colorWithWhite:0.92 alpha:1.0];
    [card addSubview:iv];
    if (showLabel) {
        char *color = GHLSSCardBgColorValue(slot);
        NSString *labelText = nil;
        if (color && color[0] != '\0') {
            char buf[64];
            snprintf(buf, sizeof(buf), "第 %d 张 · %s", slot + 1, color);
            labelText = GHLSSRuntimeString(buf);
        } else {
            char buf[64];
            snprintf(buf, sizeof(buf), "第 %d 张", slot + 1);
            labelText = GHLSSRuntimeString(buf);
        }
        if (color) free(color);
        UILabel *lb = [[UILabel alloc] initWithFrame:CGRectMake(12, cardH - 32, 120, 22)];
        lb.text = labelText;
        lb.font = [UIFont systemFontOfSize:12];
        lb.textColor = [UIColor whiteColor];
        lb.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.55];
        lb.textAlignment = NSTextAlignmentCenter;
        lb.layer.cornerRadius = 5.0;
        lb.clipsToBounds = YES;
        [card addSubview:lb];
    }
    UIButton *tap = [UIButton buttonWithType:UIButtonTypeCustom];
    tap.frame = card.bounds;
    tap.tag = 1000 + slot;
    [tap addTarget:self action:@selector(ghlssCardTapped:) forControlEvents:UIControlEventTouchUpInside];
    [card addSubview:tap];
    card.transform = CGAffineTransformMakeRotation(angle);
    [self.stackView addSubview:card];
    [self.stackButtons addObject:card];
}

- (void)ghlssCardTapped:(UIButton *)sender {
    int slot = (int)sender.tag - 1000;
    int n = GHLSSCardBgCountValue();
    if (slot < 0 || slot >= GHLSS_CARD_BG_MAX) return;
    if (slot < n) {
        GHLSSCardBgSetCurrent(slot);
        [self ghlssRebuildCardStack];
    } else {
        self.wallPickerModeAdjust = NO;
        [self ghlssPickCardBgImages:nil];
    }
}

// v62：這頁的設定列只剩一組說明＋一個輪播開關——上面整頁都是自定視圖。
// 輪播開關從狀態行移到這裡（影片那頁沒有暫停鈕；開關寫 cardBgRotate，
// 計時器每次觸發都讀它，開關即時生效）。
- (NSArray *)specifiers {
    if (!_specifiers) {
        NSMutableArray *specs = [NSMutableArray array];
        PSSpecifier *group = [PSSpecifier emptyGroupSpecifier];
        [group setProperty:GHLSSRuntimeString("点卡片换当前背景；有两张以上时每 3 秒自动换一张。内置壁纸点一张直接用。") forKey:GHLSSRuntimeString("footerText")];
        [specs addObject:group];
        PSSpecifier *rot = [PSSpecifier preferenceSpecifierNamed:GHLSSRuntimeString("自动轮播（3 秒换一张）") target:self set:@selector(setPreferenceValue:specifier:) get:@selector(readPreferenceValue:) detail:nil cell:PSSwitchCell edit:nil];
        [rot setProperty:GHLSSRuntimeString("cardBgRotate") forKey:GHLSSRuntimeString("key")];
        [rot setProperty:GHLSSRuntimeString("com.guhailong.splitscreen") forKey:GHLSSRuntimeString("defaults")];
        [rot setProperty:@(YES) forKey:GHLSSRuntimeString("default")];
        [specs addObject:rot];
        _specifiers = specs;
    }
    return _specifiers;
}

// v62：輪播開關撥動時立刻停／起計時器（不然關了再開要重進頁才生效）。
- (void)setPreferenceValue:(id)value specifier:(PSSpecifier *)specifier {
    CFStringRef domain = GHLSSRuntimeCFString("com.guhailong.splitscreen");
    NSString *keyName = GHLSSRuntimeString("key");
    NSString *key = specifier.properties[keyName];
    if (key) {
        CFStringRef cfKey = (__bridge CFStringRef)key;
        CFPreferencesSetAppValue(cfKey, (__bridge CFPropertyListRef)value, domain);
        CFPreferencesAppSynchronize(domain);
    }
    if (domain) CFRelease(domain);
    if (key && [key isEqualToString:GHLSSRuntimeString("cardBgRotate")]) {
        BOOL on = [value boolValue];
        if (on) [self ghlssStartPickerTimer];
        else [self ghlssStopPickerTimer];
        char buf[64];
        snprintf(buf, sizeof(buf), "v62 bg rotate %s", on ? "on" : "off");
        GHLSSPrefsLogLine(buf);
    }
}

// 藍色大鈕：相冊多選，按順序填進空卡（跟 v59 同一套寫法）。
- (void)ghlssReplaceWallpaperImages:(UIButton *)sender {
    (void)sender;
    self.wallPickerModeAdjust = NO;
    [self ghlssPickCardBgImages:nil];
}

// 「調整」：相冊單選，只換掉當前那張。
- (void)ghlssAdjustCurrentWallpaper:(UIButton *)sender {
    (void)sender;
    if (GHLSSCardBgCountValue() <= 0) return;
    self.wallPickerModeAdjust = YES;
    PHPickerConfiguration *config = [[PHPickerConfiguration alloc] init];
    config.filter = [PHPickerFilter imagesFilter];
    config.selectionLimit = 1;
    PHPickerViewController *picker = [[PHPickerViewController alloc] initWithConfiguration:config];
    picker.delegate = self;
    [self presentViewController:picker animated:YES completion:nil];
}

// 紅色刪除：刪當前卡，後面的槽位往前補，不留洞。
- (void)ghlssDeleteCurrentWallpaper:(UIButton *)sender {
    (void)sender;
    int n = GHLSSCardBgCountValue();
    if (n <= 0) return;
    int cur = GHLSSCardBgIndexValue();
    NSFileManager *fm = [NSFileManager defaultManager];
    [fm removeItemAtPath:GHLSSCardBgSlotPath(cur) error:nil];
    for (int i = cur + 1; i < n; i++) {
        NSString *from = GHLSSCardBgSlotPath(i);
        NSString *to = GHLSSCardBgSlotPath(i - 1);
        if ([fm fileExistsAtPath:from]) {
            [fm removeItemAtPath:to error:nil];
            [fm moveItemAtPath:from toPath:to error:nil];
        }
    }
    [fm removeItemAtPath:GHLSSCardBgSlotPath(n - 1) error:nil];
    // v62：顏色名跟著槽位往前補（刪掉的槽位顏色清掉）。
    for (int i = cur; i < n - 1; i++) {
        char *c = GHLSSCardBgColorValue(i + 1);
        GHLSSCardBgWriteColor(i, c);
        if (c) free(c);
    }
    GHLSSCardBgWriteColor(n - 1, NULL);
    int left = n - 1;
    GHLSSCardBgWriteCount(left);
    if (left > 0) {
        int idx = cur < left ? cur : left - 1;
        GHLSSCardBgSetCurrent(idx);
    } else {
        [fm removeItemAtPath:GHLSSCardBgPath() error:nil];
        GHLSSCardBgWriteIndex(0);
        GHLSSWritePrefsBool("cardBgCustom", NO);
    }
    [self ghlssStopPickerTimer];
    [self ghlssRebuildCardStack];
    [self ghlssStartPickerTimer];
    char buf[64];
    snprintf(buf, sizeof(buf), "v61 bg deleted, %d left", left);
    GHLSSPrefsLogLine(buf);
}

- (void)ghlssPickCardBgImages:(PSSpecifier *)specifier {
    (void)specifier;
    PHPickerConfiguration *config = [[PHPickerConfiguration alloc] init];
    config.filter = [PHPickerFilter imagesFilter];
    config.selectionLimit = GHLSS_CARD_BG_MAX;
    PHPickerViewController *picker = [[PHPickerViewController alloc] initWithConfiguration:config];
    picker.delegate = self;
    [self presentViewController:picker animated:YES completion:nil];
}

// 多選回來：調整模式只換當前那張；否則成功讀到的圖按順序寫進槽位
// 0..k-1（中間失敗的不留洞），多出來的舊槽位清掉；第 1 張當當前圖。
- (void)picker:(PHPickerViewController *)picker didFinishPicking:(NSArray<PHPickerResult *> *)results {
    [picker dismissViewControllerAnimated:YES completion:nil];
    if (!results || [results count] == 0) return;
    NSInteger total = [results count];
    if (total > GHLSS_CARD_BG_MAX) total = GHLSS_CARD_BG_MAX;
    NSMutableArray *images = [NSMutableArray array];
    for (NSInteger i = 0; i < total; i++) [images addObject:[NSNull null]];
    dispatch_group_t group = dispatch_group_create();
    for (NSInteger i = 0; i < total; i++) {
        NSItemProvider *provider = [[results objectAtIndex:i] itemProvider];
        if (!provider) continue;
        dispatch_group_enter(group);
        [provider loadObjectOfClass:[UIImage class] completionHandler:^(id object, NSError *error) {
            (void)error;
            if ([object isKindOfClass:[UIImage class]]) {
                @synchronized (images) {
                    [images replaceObjectAtIndex:i withObject:object];
                }
            }
            dispatch_group_leave(group);
        }];
    }
    dispatch_group_notify(group, dispatch_get_main_queue(), ^{
        if (self.wallPickerModeAdjust) {
            self.wallPickerModeAdjust = NO;
            UIImage *first = nil;
            for (id obj in images) {
                if ([obj isKindOfClass:[UIImage class]]) { first = (UIImage *)obj; break; }
            }
            if (first) {
                UIImage *resized = GHLSSPrefsResizeImageMax(first, 1024.0);
                NSData *data = resized ? UIImageJPEGRepresentation(resized, 0.85) : nil;
                if (data) {
                    int cur = GHLSSCardBgIndexValue();
                    if ([data writeToFile:GHLSSCardBgSlotPath(cur) atomically:YES]) {
                        GHLSSCardBgWriteColor(cur, NULL);
                        GHLSSCardBgSetCurrent(cur);
                        GHLSSWritePrefsBool("cardBgCustom", YES);
                    }
                }
            }
            [self ghlssRebuildCardStack];
            char buf[64];
            snprintf(buf, sizeof(buf), "v61 bg adjusted slot %d", GHLSSCardBgIndexValue());
            GHLSSPrefsLogLine(buf);
            return;
        }
        NSMutableArray *good = [NSMutableArray array];
        for (id obj in images) {
            if (![obj isKindOfClass:[UIImage class]]) continue;
            UIImage *resized = GHLSSPrefsResizeImageMax((UIImage *)obj, 1024.0);
            if (resized) [good addObject:resized];
        }
        NSFileManager *fm = [NSFileManager defaultManager];
        int saved = 0;
        for (UIImage *img in good) {
            NSData *data = UIImageJPEGRepresentation(img, 0.85);
            if (!data) continue;
            if ([data writeToFile:GHLSSCardBgSlotPath(saved) atomically:YES]) saved++;
        }
        for (int i = saved; i < GHLSS_CARD_BG_MAX; i++) [fm removeItemAtPath:GHLSSCardBgSlotPath(i) error:nil];
        // v62：相冊選進來的是用戶圖，顏色名全清（標籤只寫「第 X 張」）。
        for (int i = 0; i < GHLSS_CARD_BG_MAX; i++) GHLSSCardBgWriteColor(i, NULL);
        GHLSSCardBgWriteCount(saved);
        GHLSSCardBgWriteIndex(0);
        if (saved > 0) {
            GHLSSCardBgSetCurrent(0);
            GHLSSWritePrefsBool("cardBgCustom", YES);
        }
        [self ghlssRebuildCardStack];
        char buf[128];
        snprintf(buf, sizeof(buf), "v59 bg picked %d", saved);
        GHLSSPrefsLogLine(buf);
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:GHLSSRuntimeString("背景图已换好") message:GHLSSRuntimeString("点卡片可以换当前那张；两张以上每 3 秒自动换。") preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:GHLSSRuntimeString("好") style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:alert animated:YES completion:nil];
    });
}

// 內置圖加進第一個空槽位（滿了就換掉當前那張），當場設成當前圖。
- (void)ghlssAddBuiltinBgWithResource:(NSString *)resource ofType:(NSString *)type tag:(const char *)tag {
    NSBundle *bundle = [NSBundle bundleForClass:[self class]];
    NSString *path = [bundle pathForResource:resource ofType:type];
    UIImage *img = path ? [UIImage imageWithContentsOfFile:path] : nil;
    if (!img) {
        GHLSSPrefsLogLine("v59 bg builtin missing");
        return;
    }
    UIImage *resized = GHLSSPrefsResizeImageMax(img, 1024.0);
    NSData *data = resized ? UIImageJPEGRepresentation(resized, 0.85) : nil;
    if (!data) return;
    int n = GHLSSCardBgCountValue();
    int slot = (n < GHLSS_CARD_BG_MAX) ? n : GHLSSCardBgIndexValue();
    if (![data writeToFile:GHLSSCardBgSlotPath(slot) atomically:YES]) return;
    if (n < GHLSS_CARD_BG_MAX) GHLSSCardBgWriteCount(n + 1);
    // v62：內置圖的顏色名跟著槽位記（下卡標籤用）；龍頭／哆啦A夢沒顏色名。
    const char *color = NULL;
    if (tag) {
        if (strcmp(tag, "ghlss-bg-pink") == 0) color = "粉";
        else if (strcmp(tag, "ghlss-bg-white") == 0) color = "白";
        else if (strcmp(tag, "ghlss-bg-green") == 0) color = "绿";
        else if (strcmp(tag, "ghlss-bg-reddress") == 0) color = "红";
    }
    GHLSSCardBgWriteColor(slot, color);
    GHLSSCardBgSetCurrent(slot);
    GHLSSWritePrefsBool("cardBgCustom", YES);
    [self ghlssRebuildCardStack];
    char buf[128];
    snprintf(buf, sizeof(buf), "v59 bg builtin %s slot %d", tag ? tag : "?", slot);
    GHLSSPrefsLogLine(buf);
}

@end

// （GHLSSPlistPageController 在文件後面定義，這裡先給完整接口聲明——
// 光是 @class 前向聲明不夠，[GHLSSPlistPageController class] 會報錯。）
@interface GHLSSPlistPageController : GuHaiLongSplitScreenRootListController
@end

// v72：LinkList 子清單控制器（見下面 GHLSSHandleLinkListTap）——
// 框架原生的 PSListItemsController 在鍵盤頁上只顯示一個選項（子清單幾乎空白，
// plist 本身是對的、父頁也載了 7 項，框架子清單的生成／快取／渲染在這裡
// 黑盒修不了；同 v47 的做法：點按攔下來、推我們自己的控制器）。
// 它從點按那行的 specifier 現場讀 values／titles 建單選行，不走框架快取；
// 選項寫值走繼承的 setPreferenceValue（CFPreferences＋同步），並記
// v72 prefs-linklist 日誌，下次日誌能證明寫入。
@interface GHLSSLinkListController : GuHaiLongSplitScreenRootListController
@end

// v43：子頁要跳的 plist 白名單（14 份真實檔案；不在裡面的
// 名字一律不載，免得 loadSpecifiersFromPlistName 拿到壞名字）。
// v50：Advanced 刪了（去重）、Status 新加。
static BOOL GHLSSPrefsIsKnownPlistName(const char *name) {
    if (!name || name[0] == '\0') return NO;
    static const char *known[] = {"ARC", "ARCButtons", "Banner", "Floating", "FloatingIcon", "GestureCustom", "Info", "Keyboard", "Other", "Root", "Scheduler", "Shadow", "Status", "ThreeScreen", "Window"};
    size_t n = sizeof(known) / sizeof(known[0]);
    for (size_t i = 0; i < n; i++) {
        if (strcmp(name, known[i]) == 0) return YES;
    }
    return NO;
}


// v72：攔截 PSLinkListCell 的點按，自己推 GHLSSLinkListController。
// 根因（皇上 2026-11-17 14:11 報：鍵盤子清單只顯示內弹出，頁面幾乎空白）：
// plist 本身是對的（Keyboard[4] validTitles 浮窗内弹出／外弹出、
// validValues inner／outer，出貨包裡也在），父頁也載了 7 項（24.log 證明，
// 舊快取假說已推翻）——剩下就是框架原生的 PSListItemsController 自己
// 生成／快取／渲染子清單時出的問題，在這裡黑盒修不了；同 v47 修
// detail 連結行的做法（框架原生控制器載不到我們 bundle 的東西就空白），
// 點按先攔下來、推我們自己的控制器：子清單從點按那行的 specifier
// 現場讀 values／titles 建行，不走框架快取，兩個選項一定都在；
// 選項寫值走繼承的 setPreferenceValue，並記 v72 prefs-linklist 日誌。
// 沒有 values（或空）就回 NO 交回框架，不推空白頁。
// 回傳 YES 表示這一行已經處理了（呼叫方直接 return，不要再走 super）。
static BOOL GHLSSHandleLinkListTap(PSListController *controller, UITableView *tableView, NSIndexPath *indexPath) {
    if (!controller || !indexPath) return NO;
    PSSpecifier *spec = [controller specifierAtIndexPath:indexPath];
    if (!spec) return NO;
    if (spec.cellType != PSLinkListCell) return NO;
    NSArray *values = spec.properties[GHLSSRuntimeString("values")];
    NSArray *titles = spec.properties[GHLSSRuntimeString("titles")];
    if (!values || [values count] == 0) {
        GHLSSPrefsLogLine("v72 prefs-linklist no values, framework fallback");
        return NO;
    }
    (void)titles;
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    GHLSSLinkListController *page = [[GHLSSLinkListController alloc] init];
    page.specifier = spec;
    page.parentController = controller;
    page.rootController = controller.rootController;
    [controller pushController:page];
    NSString *key = spec.properties[GHLSSRuntimeString("key")];
    const char *keyC = key ? [key UTF8String] : "?";
    char buf[256];
    snprintf(buf, sizeof(buf), "v72 prefs-linklist push %s options %lu", keyC, (unsigned long)[values count]);
    GHLSSPrefsLogLine(buf);
    return YES;
}

// v47：攔截 plist 名 detail 的連結行，自己手動推 PlistPage。
// 根因（皇上 2026-11-14 19:29 報：系統設定裡點「三屏设置」進去什麼都
// 沒有，「ARC设置」也一樣，主頁本身正常）：Root.plist 裡五個子頁連結行
// （三屏設置 detail=ThreeScreen、arc 設置 detail=ARC、浮窗設置
// detail=Floating、其他雜項功能 detail=Other、高級設置 detail=Advanced）
// 的 detail 是 plist 名、沒有 action，點按走到框架預設的處理——它 new
// 一個原生的 PSListController 來載那份 plist，但那個原生控制器的 bundle
// 不是我們這個 PreferenceLoader bundle（我們 bundle 裡的 plist 它找不
// 到），specifiers 載出來是空的：頁面推得出來，裡面一行都沒有。類名
// detail 的行不受影響（框架直接 alloc 那個類，類在我們二進制裡，
// specifiers 由類自己載），所以配置方案／手勢總覽都正常，
// 主頁（我們自己的控制器自己載 Root.plist）也正常。PreferenceLoader
// 登記檔裡根控制器就是用類名登記的（isController），也是同一道理。
// 修法：連結行點按時先在這裡攔下來——detail 是白名單裡的 plist 名，就
// 手動推一個 GHLSSPlistPageController：把 plist 名寫進 specifier 的非保留字鍵
// ghlssTargetPlist，再 push。PlistPage 的 specifiers 是在我們自己的
// 子類身上載 plist（bundle 對得上），內容就出來了。detail 是類名、
// 或不在白名單裡的，一律回 NO 交回框架／super，不動它。
// PlistPage 繼承主頁控制器（同一個 didSelectRow），所以子頁裡的嵌套
// plist 連結（浮窗設置裡的陰影／橫幅／鍵盤／調度、其他雜項裡的
// 桌面圖標／懸浮圖標、三屏／ARC／高級設置裡的調度／手勢自定義）走同
// 一個攔截，一次全修；類名 detail 的嵌套行（排序頁、選擇應用、
// 日誌／頭像／背景）繼續走框架，本來就正常。
// 回傳 YES 表示這一行已經處理了（呼叫方直接 return，不要再走 super）。
static BOOL GHLSSHandlePlistDetailTap(PSListController *controller, UITableView *tableView, NSIndexPath *indexPath) {
    if (!controller || !indexPath) return NO;
    PSSpecifier *spec = [controller specifierAtIndexPath:indexPath];
    if (!spec) return NO;
    if (spec.cellType != PSLinkCell) return NO;
    NSString *detail = spec.properties[GHLSSRuntimeString("detail")];
    if (!detail || [detail length] == 0) return NO;
    const char *detailC = [detail UTF8String];
    // 類名 detail——框架直接 alloc 那個類，本來就正常，不攔。
    if (NSClassFromString(detail) != Nil) return NO;
    if (!GHLSSPrefsIsKnownPlistName(detailC)) {
        char buf[256];
        snprintf(buf, sizeof(buf), "v57 prefs-nav REJECTED unknown plist detail %s", detailC ? detailC : "?");
        GHLSSPrefsLogLine(buf);
        return NO;
    }
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    [spec setProperty:detail forKey:GHLSSRuntimeString("ghlssTargetPlist")];
    GHLSSPlistPageController *page = [[GHLSSPlistPageController alloc] init];
    page.specifier = spec;
    page.parentController = controller;
    page.rootController = controller.rootController;
    [controller pushController:page];
    char buf[256];
    snprintf(buf, sizeof(buf), "v57 prefs-nav push plist %s", detailC ? detailC : "?");
    GHLSSPrefsLogLine(buf);
    return YES;
}

// v42：手勢總覽——一頁列出全部手勢跟目前的設定值（只讀，
// 改去調度設置／手勢自定義那頁）。
static NSString *GHLSSGestureActionName(const char *value) {
    if (!value) return GHLSSRuntimeString("未设定");
    if (strcmp(value, "pin") == 0) return GHLSSRuntimeString("钉选置顶");
    if (strcmp(value, "dock") == 0) return GHLSSRuntimeString("收起贴边");
    if (strcmp(value, "close") == 0) return GHLSSRuntimeString("关掉");
    if (strcmp(value, "cycle") == 0) return GHLSSRuntimeString("轮切主窗");
    if (strcmp(value, "maximize") == 0) return GHLSSRuntimeString("放大全屏");
    return [NSString stringWithCString:value encoding:NSUTF8StringEncoding];
}

@interface GHLSSGesturesListController : PSListController
@end

@implementation GHLSSGesturesListController

// v43：記進了哪一頁。
- (void)viewDidLoad {
    @try {
        [super viewDidLoad];
    } @catch (NSException *e) {
        const char *reason = [e reason] ? [[e reason] UTF8String] : "?";
        char buf[256];
        snprintf(buf, sizeof(buf), "v57 prefs-gestures viewDidLoad EXCEPTION %s", reason);
        GHLSSPrefsLogLine(buf);
    }
    GHLSSPrefsLogLine("v57 prefs-page: Gestures");
}

// v54：總覽是只讀快取頁——回來看見的必須是新值（在 Scheduler／GestureCustom
// 改完回來，舊值會 stale）。每次出現都清快取重組。
- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    @try {
        _specifiers = nil;
        [self reloadSpecifiers];
    } @catch (NSException *e) {
        const char *reason = [e reason] ? [[e reason] UTF8String] : "?";
        char buf[256];
        snprintf(buf, sizeof(buf), "v57 prefs-gestures viewWillAppear EXCEPTION %s", reason);
        GHLSSPrefsLogLine(buf);
    }
}

// v56：總覽每行點按跳到對應可改的設定頁（§141-6；plist 名 detail 走同一攔截）。
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if (GHLSSHandlePlistDetailTap(self, tableView, indexPath)) return;
    [super tableView:tableView didSelectRowAtIndexPath:indexPath];
}

// v57（§144-5）：跳轉行在 1.0.56 點不動——didSelectRow 攔截本身沒錯，但
// 框架的 willSelectRowAtIndexPath 可能先把行判成不可選（detail 是 plist
// 名 string，不是 detailControllerClass），didSelectRow 根本收不到。
// 這裡先攔 willSelect：PSLinkCell＋白名單 plist detail 就放行（並記一行），
// 其餘守著調 super。另加 cell fix-up：強制黑字＋cellEnabled＝YES＋chevron，
// 行不再灰白。
- (NSIndexPath *)tableView:(UITableView *)tableView willSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    PSSpecifier *spec = [self specifierAtIndexPath:indexPath];
    if (spec && spec.cellType == PSLinkCell) {
        NSString *detail = spec.properties[GHLSSRuntimeString("detail")];
        if (detail && [detail length] > 0 && NSClassFromString(detail) == Nil) {
            const char *detailC = [detail UTF8String];
            if (GHLSSPrefsIsKnownPlistName(detailC)) {
                GHLSSPrefsLogLine("v57 prefs-nav willSelect allow");
                return indexPath;
            }
        }
    }
    if ([[self superclass] instancesRespondToSelector:@selector(tableView:willSelectRowAtIndexPath:)]) {
        return [super tableView:tableView willSelectRowAtIndexPath:indexPath];
    }
    return indexPath;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = nil;
    if ([[self superclass] instancesRespondToSelector:@selector(tableView:cellForRowAtIndexPath:)]) {
        cell = [super tableView:tableView cellForRowAtIndexPath:indexPath];
    }
    if (!cell) return cell;
    @try {
        cell.textLabel.textColor = [UIColor labelColor];
        if ([cell isKindOfClass:[PSTableCell class]]) {
            ((PSTableCell *)cell).cellEnabled = YES;
        }
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    } @catch (NSException *e) {
    }
    return cell;
}

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath {
    if ([[self superclass] instancesRespondToSelector:@selector(tableView:willDisplayCell:forRowAtIndexPath:)]) {
        [super tableView:tableView willDisplayCell:cell forRowAtIndexPath:indexPath];
    }
    @try {
        cell.textLabel.textColor = [UIColor labelColor];
        if ([cell isKindOfClass:[PSTableCell class]]) {
            ((PSTableCell *)cell).cellEnabled = YES;
        }
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    } @catch (NSException *e) {
    }
}

- (NSArray *)specifiers {
    if (!_specifiers) {
        @try {
            NSMutableArray *specs = [NSMutableArray array];
            PSSpecifier *intro = [PSSpecifier emptyGroupSpecifier];
            [intro setProperty:GHLSSRuntimeString("全部手势跟目前的设定值。点下面一行去改（边缘滑动／哆啦A梦钮／手势绑定／拖窗与点窗外）。") forKey:GHLSSRuntimeString("footerText")];
            [specs addObject:intro];
            // 邊緣滑動。
            {
                int count = (int)GHLSSPrefsDouble("edgeSwipeCount", 2);
                char *side = GHLSSPrefsCString("edgeSwipeSide");
                const char *sideStr = side ? side : "right";
                if (sideStr[0] == '\0') sideStr = "right";
                BOOL direct = GHLSSPrefsBool("edgeSwipeOpensThreeScreen", NO);
                char buf[256];
                snprintf(buf, sizeof(buf), "从%s边滑 %d 次，%s", (strcmp(sideStr, "left") == 0) ? "左" : "右", count, direct ? "直接开三屏（上次组合）" : "开 ARC");
                if (side) free(side);
                PSSpecifier *g = [PSSpecifier emptyGroupSpecifier];
                [g setProperty:GHLSSRuntimeString("边缘滑动") forKey:GHLSSRuntimeString("label")];
                [g setProperty:[NSString stringWithCString:buf encoding:NSUTF8StringEncoding] forKey:GHLSSRuntimeString("footerText")];
                [specs addObject:g];
                // v56：總覽每行點按跳到可改的設定頁（§141-6：總覽本身不改成可編輯頁）。
                PSSpecifier *edgeRow = [PSSpecifier preferenceSpecifierNamed:GHLSSRuntimeString("改边缘滑动") target:self set:nil get:nil detail:nil cell:PSLinkCell edit:nil];
                [edgeRow setProperty:GHLSSRuntimeString("Scheduler") forKey:GHLSSRuntimeString("detail")];
                [specs addObject:edgeRow];
            }
            // 哆啦A夢鈕。
            {
                double lp = GHLSSPrefsDouble("longPressDuration", 0.5);
                BOOL dbl = GHLSSPrefsBool("doraemonDoubleTapEnabled", YES);
                char buf[256];
                snprintf(buf, sizeof(buf), "单击开 ARC；%s；长按 %.1f 秒关全部浮窗；直接拖钮改高度。", dbl ? "双击轮切主窗" : "双击轮切已关", lp);
                PSSpecifier *g = [PSSpecifier emptyGroupSpecifier];
                [g setProperty:GHLSSRuntimeString("哆啦A梦钮") forKey:GHLSSRuntimeString("label")];
                [g setProperty:[NSString stringWithCString:buf encoding:NSUTF8StringEncoding] forKey:GHLSSRuntimeString("footerText")];
                [specs addObject:g];
                PSSpecifier *doraRow = [PSSpecifier preferenceSpecifierNamed:GHLSSRuntimeString("改哆啦A梦钮") target:self set:nil get:nil detail:nil cell:PSLinkCell edit:nil];
                [doraRow setProperty:GHLSSRuntimeString("FloatingIcon") forKey:GHLSSRuntimeString("detail")];
                [specs addObject:doraRow];
            }
            // 浮窗手勢（自定義四項）。
            {
                char *t = GHLSSPrefsCString("gestureTripleTap");
                char *v = GHLSSPrefsCString("gestureSwipeV");
                char *h = GHLSSPrefsCString("gestureSwipeH");
                char *f = GHLSSPrefsCString("gestureTwoFingerTap");
                NSMutableString *line = [NSMutableString stringWithString:GHLSSRuntimeString("三击浮窗：")];
                [line appendString:GHLSSGestureActionName(t ? t : "pin")];
                [line appendString:GHLSSRuntimeString("；上下滑：")];
                [line appendString:GHLSSGestureActionName(v ? v : "dock")];
                [line appendString:GHLSSRuntimeString("；左右滑：")];
                [line appendString:GHLSSGestureActionName(h ? h : "close")];
                [line appendString:GHLSSRuntimeString("；双指点：")];
                [line appendString:GHLSSGestureActionName(f ? f : "maximize")];
                if (t) free(t);
                if (v) free(v);
                if (h) free(h);
                if (f) free(f);
                PSSpecifier *g = [PSSpecifier emptyGroupSpecifier];
                [g setProperty:GHLSSRuntimeString("浮窗手势（顶上 24pt 手柄，绑在手柄上、不是内容区）") forKey:GHLSSRuntimeString("label")];
                [g setProperty:line forKey:GHLSSRuntimeString("footerText")];
                [specs addObject:g];
                PSSpecifier *gestRow = [PSSpecifier preferenceSpecifierNamed:GHLSSRuntimeString("改手势绑定") target:self set:nil get:nil detail:nil cell:PSLinkCell edit:nil];
                [gestRow setProperty:GHLSSRuntimeString("GestureCustom") forKey:GHLSSRuntimeString("detail")];
                [specs addObject:gestRow];
            }
            // 拖窗／分隔線／點窗外。
            {
                BOOL drag = GHLSSPrefsBool("windowDragEnabled", YES);
                BOOL sideGest = GHLSSPrefsBool("sideWindowGestures", YES);
                BOOL tapOut = GHLSSPrefsBool("tapOutsideEnabled", YES);
                char *tapAction = GHLSSPrefsCString("tapOutsideAction");
                const char *tapStr = (tapAction && strcmp(tapAction, "close") == 0) ? "关掉浮窗" : "收起贴边";
                if (tapAction) free(tapAction);
                char buf[320];
                snprintf(buf, sizeof(buf), "拖窗：%s；分隔线拖动：%s（拖到顶放大、拖到边吸住留 8pt，放手才吸）；点窗外：%s（%s）。", drag ? "开" : "关", sideGest ? "开" : "关", tapOut ? "开" : "关", tapStr);
                PSSpecifier *g = [PSSpecifier emptyGroupSpecifier];
                [g setProperty:GHLSSRuntimeString("拖窗／分隔线／点窗外") forKey:GHLSSRuntimeString("label")];
                [g setProperty:[NSString stringWithCString:buf encoding:NSUTF8StringEncoding] forKey:GHLSSRuntimeString("footerText")];
                [specs addObject:g];
                PSSpecifier *dragRow = [PSSpecifier preferenceSpecifierNamed:GHLSSRuntimeString("改拖窗与点窗外") target:self set:nil get:nil detail:nil cell:PSLinkCell edit:nil];
                [dragRow setProperty:GHLSSRuntimeString("Window") forKey:GHLSSRuntimeString("detail")];
                [specs addObject:dragRow];
            }
            // v53：懸浮球已整個拿掉（狀態頁球區塊刪除）。
            _specifiers = specs;
    
        } @catch (NSException *e) {
            const char *reason = [e reason] ? [[e reason] UTF8String] : "?";
            char buf[512];
            snprintf(buf, sizeof(buf), "v57 prefs-gestures specifiers EXCEPTION %s", reason);
            GHLSSPrefsLogLine(buf);
            NSMutableArray *safe = [NSMutableArray array];
            PSSpecifier *group = [PSSpecifier emptyGroupSpecifier];
            [group setProperty:GHLSSRuntimeString("手势总览页组装出错（已记进日志），先回上一页再试。") forKey:GHLSSRuntimeString("footerText")];
            [safe addObject:group];
            _specifiers = safe;
        }
        if (!_specifiers) _specifiers = [NSMutableArray array];
    }
    return _specifiers;
}

@end

// v42：配置方案——存幾套配置（日常／遊戲／自訂名），點一下整套切換；
// 跟備份／導出是兩回事（備份是單檔，方案是多套並存）。方案檔是
// 設定目錄裡 GuHaiLongSplitScreen-profile-<名字>.plist，最多 5 個。
@interface GHLSSProfilesListController : PSListController
@end

@implementation GHLSSProfilesListController

// v43：記進了哪一頁。
- (void)viewDidLoad {
    @try {
        [super viewDidLoad];
    } @catch (NSException *e) {
        const char *reason = [e reason] ? [[e reason] UTF8String] : "?";
        char buf[256];
        snprintf(buf, sizeof(buf), "v57 prefs-profiles viewDidLoad EXCEPTION %s", reason);
        GHLSSPrefsLogLine(buf);
    }
    GHLSSPrefsLogLine("v57 prefs-page: Profiles");
}

// v43：按鈕行自己派發（GHLSSDispatchButtonTap）；其他行走框架。
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if (GHLSSDispatchButtonTap(self, tableView, indexPath)) return;
    [super tableView:tableView didSelectRowAtIndexPath:indexPath];
}

- (NSArray *)specifiers {
    if (!_specifiers) {
        @try {
            NSMutableArray *specs = [NSMutableArray array];
            PSSpecifier *group = [PSSpecifier emptyGroupSpecifier];
            [group setProperty:GHLSSRuntimeString("存几套配置，点一下整套切换（跟备份／导出是两回事：备份是单档，方案是多套并存）。套用后要重新启动 SpringBoard 生效。") forKey:GHLSSRuntimeString("footerText")];
            [specs addObject:group];
            PSSpecifier *save = [PSSpecifier preferenceSpecifierNamed:GHLSSRuntimeString("把目前配置存成方案…") target:self set:nil get:nil detail:nil cell:PSButtonCell edit:nil];
            [save setProperty:GHLSSRuntimeString("ghlssSaveProfile") forKey:GHLSSRuntimeString("action")];
            [specs addObject:save];
            NSArray *names = GHLSSListProfileNames();
            if ([names count] == 0) {
                PSSpecifier *emptyGroup = [PSSpecifier emptyGroupSpecifier];
                [emptyGroup setProperty:GHLSSRuntimeString("还没有方案（先点上面存一个，例如「日常」「游戏」）。") forKey:GHLSSRuntimeString("footerText")];
                [specs addObject:emptyGroup];
            }
            for (NSString *name in names) {
                NSString *applyLabel = [[GHLSSRuntimeString("套用方案：") stringByAppendingString:name] stringByAppendingString:GHLSSRuntimeString("（点一下整套切换）")];
                PSSpecifier *apply = [PSSpecifier preferenceSpecifierNamed:applyLabel target:self set:nil get:nil detail:nil cell:PSButtonCell edit:nil];
                [apply setProperty:GHLSSRuntimeString("ghlssApplyProfile") forKey:GHLSSRuntimeString("action")];
                [apply setProperty:name forKey:GHLSSRuntimeString("profileName")];
                [specs addObject:apply];
                NSString *delLabel = [GHLSSRuntimeString("删除方案：") stringByAppendingString:name];
                PSSpecifier *del = [PSSpecifier preferenceSpecifierNamed:delLabel target:self set:nil get:nil detail:nil cell:PSButtonCell edit:nil];
                [del setProperty:GHLSSRuntimeString("ghlssDeleteProfile") forKey:GHLSSRuntimeString("action")];
                [del setProperty:name forKey:GHLSSRuntimeString("profileName")];
                [specs addObject:del];
            }
            _specifiers = specs;
    
        } @catch (NSException *e) {
            const char *reason = [e reason] ? [[e reason] UTF8String] : "?";
            char buf[512];
            snprintf(buf, sizeof(buf), "v57 prefs-profiles specifiers EXCEPTION %s", reason);
            GHLSSPrefsLogLine(buf);
            NSMutableArray *safe = [NSMutableArray array];
            PSSpecifier *group = [PSSpecifier emptyGroupSpecifier];
            [group setProperty:GHLSSRuntimeString("配置方案页组装出错（已记进日志），先回上一页再试。") forKey:GHLSSRuntimeString("footerText")];
            [safe addObject:group];
            _specifiers = safe;
        }
        if (!_specifiers) _specifiers = [NSMutableArray array];
    }
    return _specifiers;
}

- (void)ghlssSaveProfile:(PSSpecifier *)specifier {
    (void)specifier;
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:GHLSSRuntimeString("存成方案") message:GHLSSRuntimeString("给这套配置起个名字（例如：日常、游戏）。") preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *textField) {
        textField.placeholder = GHLSSRuntimeString("方案名字");
    }];
    UIAlertAction *save = [UIAlertAction actionWithTitle:GHLSSRuntimeString("保存") style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        (void)action;
        NSString *name = alert.textFields.firstObject.text;
        if (!name) name = GHLSSRuntimeString("");
        name = [name stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
        if ([name length] == 0) return;
        NSFileManager *fm = [NSFileManager defaultManager];
        NSString *src = GHLSSPrefsFilePath();
        NSString *dst = GHLSSProfileFilePathForName(name);
        if (![fm fileExistsAtPath:src]) {
            UIAlertController *noFile = [UIAlertController alertControllerWithTitle:GHLSSRuntimeString("没有配置文件可存") message:GHLSSRuntimeString("先改一个设置，配置文件才会生成。") preferredStyle:UIAlertControllerStyleAlert];
            [noFile addAction:[UIAlertAction actionWithTitle:GHLSSRuntimeString("好") style:UIAlertActionStyleDefault handler:nil]];
            [self presentViewController:noFile animated:YES completion:nil];
            return;
        }
        NSArray *existing = GHLSSListProfileNames();
        if ([existing count] >= 5 && ![existing containsObject:name]) {
            UIAlertController *full = [UIAlertController alertControllerWithTitle:GHLSSRuntimeString("方案已满") message:GHLSSRuntimeString("最多存 5 套方案，先删一个再存。") preferredStyle:UIAlertControllerStyleAlert];
            [full addAction:[UIAlertAction actionWithTitle:GHLSSRuntimeString("好") style:UIAlertActionStyleDefault handler:nil]];
            [self presentViewController:full animated:YES completion:nil];
            return;
        }
        [fm removeItemAtPath:dst error:nil];
        NSError *err = nil;
        BOOL ok = [fm copyItemAtPath:src toPath:dst error:&err];
        [self reloadSpecifiers];
        NSString *title = ok ? GHLSSRuntimeString("已存成方案") : GHLSSRuntimeString("保存失败");
        NSString *msg = ok ? [[GHLSSRuntimeString("方案「") stringByAppendingString:name] stringByAppendingString:GHLSSRuntimeString("」已存好，点它就整套切换。")] : GHLSSRuntimeString("复制配置文件时出错。");
        UIAlertController *done = [UIAlertController alertControllerWithTitle:title message:msg preferredStyle:UIAlertControllerStyleAlert];
        [done addAction:[UIAlertAction actionWithTitle:GHLSSRuntimeString("好") style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:done animated:YES completion:nil];
    }];
    [alert addAction:save];
    [alert addAction:[UIAlertAction actionWithTitle:GHLSSRuntimeString("取消") style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)ghlssApplyProfile:(PSSpecifier *)specifier {
    NSString *name = specifier.properties[GHLSSRuntimeString("profileName")];
    if (!name) return;
    NSFileManager *fm = [NSFileManager defaultManager];
    NSString *src = GHLSSProfileFilePathForName(name);
    NSString *dst = GHLSSPrefsFilePath();
    if (![fm fileExistsAtPath:src]) return;
    [fm removeItemAtPath:dst error:nil];
    NSError *err = nil;
    BOOL ok = [fm copyItemAtPath:src toPath:dst error:&err];
    if (ok) {
        CFStringRef domain = GHLSSRuntimeCFString("com.guhailong.splitscreen");
        if (domain) {
            CFPreferencesAppSynchronize(domain);
            CFRelease(domain);
        }
        [self reloadSpecifiers];
    }
    NSString *msg = ok ? [[GHLSSRuntimeString("方案「") stringByAppendingString:name] stringByAppendingString:GHLSSRuntimeString("」已套用，请重新启动 SpringBoard 生效。")] : GHLSSRuntimeString("复制配置文件时出错。");
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:ok ? GHLSSRuntimeString("已套用方案") : GHLSSRuntimeString("套用失败") message:msg preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:GHLSSRuntimeString("好") style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)ghlssDeleteProfile:(PSSpecifier *)specifier {
    NSString *name = specifier.properties[GHLSSRuntimeString("profileName")];
    if (!name) return;
    [[NSFileManager defaultManager] removeItemAtPath:GHLSSProfileFilePathForName(name) error:nil];
    [self reloadSpecifiers];
}

@end

// v42：任意 plist 頁——搜索結果點進來的頁：按 specifier 上的
// plistName 載入那份 plist。繼承主頁控制器，所以備份／導出／
// 導入／恢復／重置／布局預設那些按鈕動作在這裡也一樣能用。
// （接口聲明在文件前面搜索控制器之前，這裡只寫實作。）
// v43：改讀 ghlssTargetPlist（非保留字 key），先對白名單才載，
// 載入失敗只顯示空白頁、不閃退；進出寫檔日誌。
@implementation GHLSSPlistPageController

- (NSArray *)specifiers {
    if (!_specifiers) {
        NSString *targetPlist = self.specifier.properties[GHLSSRuntimeString("ghlssTargetPlist")];
        const char *cname = targetPlist ? [targetPlist UTF8String] : NULL;
        char buf[256];
        snprintf(buf, sizeof(buf), "v57 prefs-search plistpage entry plist %s", cname ? cname : "(nil)");
        GHLSSPrefsLogLine(buf);
        if (targetPlist && [targetPlist length] > 0 && GHLSSPrefsIsKnownPlistName(cname)) {
            @try {
                _specifiers = [self loadSpecifiersFromPlistName:targetPlist target:self];
            } @catch (NSException *e) {
                char ebuf[512];
                snprintf(ebuf, sizeof(ebuf), "v57 prefs-search plistpage EXCEPTION %s %s", [[e name] UTF8String], [[e reason] UTF8String]);
                GHLSSPrefsLogLine(ebuf);
                NSMutableArray *safe = [NSMutableArray array];
                PSSpecifier *group = [PSSpecifier emptyGroupSpecifier];
                [group setProperty:GHLSSRuntimeString("这一页打不开（已记进日志），先回上一页再试。") forKey:GHLSSRuntimeString("footerText")];
                [safe addObject:group];
                _specifiers = safe;
            }
            if (!_specifiers) _specifiers = [NSMutableArray array];
        } else {
            GHLSSPrefsLogLine("v57 prefs-search plistpage REJECTED unknown plist");
            NSMutableArray *safe = [NSMutableArray array];
            PSSpecifier *group = [PSSpecifier emptyGroupSpecifier];
            [group setProperty:GHLSSRuntimeString("这一页打不开（已记进日志），先回上一页再试。") forKey:GHLSSRuntimeString("footerText")];
            [safe addObject:group];
            _specifiers = safe;
        }
        char buf2[128];
        snprintf(buf2, sizeof(buf2), "v57 prefs-search plistpage exit count %lu", (unsigned long)[_specifiers count]);
        GHLSSPrefsLogLine(buf2);
        // v71：頁面載入時記一行 plist 名＋item 數量——下次日誌直接證明
        // 載的是新版還是舊版（1.0.70 兩行看不到，靠這行定位）。
        {
            char pbuf[256];
            snprintf(pbuf, sizeof(pbuf), "v71 prefs-page %s items %lu", cname ? cname : "(nil)", (unsigned long)[_specifiers count]);
            GHLSSPrefsLogLine(pbuf);
        }
    }
    return _specifiers;
}

// v71：子頁每次出現都清快取重組（學手勢總覽頁 v54——只讀快取頁回來看見的
// 必須是新值，舊 specifiers 會 stale；1.0.70 的新行在手機上看不到，
// 每頁快取就是頭號嫌疑）。
- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    @try {
        _specifiers = nil;
        [self reloadSpecifiers];
    } @catch (NSException *e) {
        const char *reason = [e reason] ? [[e reason] UTF8String] : "?";
        char buf[256];
        snprintf(buf, sizeof(buf), "v71 prefs-plistpage viewWillAppear EXCEPTION %s", reason);
        GHLSSPrefsLogLine(buf);
    }
}

@end

@implementation GHLSSLinkListController

// v72：LinkList 子清單——從點按那行（self.specifier）的 values／titles 現場建單選行。
// 每個選項一行 PSListItemCell（單選圓點行），values 只有那一個值；
// 當前值由繼承的 readPreferenceValue 讀（沒存過回 plist 的 default），框架照它打勾。
- (NSArray *)specifiers {
    if (!_specifiers) {
        PSSpecifier *parent = self.specifier;
        NSArray *values = parent ? parent.properties[GHLSSRuntimeString("values")] : nil;
        NSArray *titles = parent ? parent.properties[GHLSSRuntimeString("titles")] : nil;
        NSString *key = parent ? parent.properties[GHLSSRuntimeString("key")] : nil;
        NSString *defaults = parent ? parent.properties[GHLSSRuntimeString("defaults")] : nil;
        id def = parent ? parent.properties[GHLSSRuntimeString("default")] : nil;
        NSMutableArray *specs = [NSMutableArray array];
        if (values && [values count] > 0 && key) {
            for (NSUInteger i = 0; i < [values count]; i++) {
                id value = [values objectAtIndex:i];
                NSString *title = nil;
                if (titles && i < [titles count]) title = [titles objectAtIndex:i];
                if (!title) title = [value description];
                PSSpecifier *spec = [PSSpecifier preferenceSpecifierNamed:title target:self set:@selector(setPreferenceValue:specifier:) get:@selector(readPreferenceValue:) detail:nil cell:PSListItemCell edit:nil];
                [spec setProperty:[NSArray arrayWithObject:value] forKey:GHLSSRuntimeString("values")];
                [spec setProperty:key forKey:GHLSSRuntimeString("key")];
                if (defaults) [spec setProperty:defaults forKey:GHLSSRuntimeString("defaults")];
                if (def) [spec setProperty:def forKey:GHLSSRuntimeString("default")];
                [specs addObject:spec];
            }
            const char *keyC = [key UTF8String];
            char buf[256];
            snprintf(buf, sizeof(buf), "v72 prefs-linklist %s options %lu", keyC ? keyC : "?", (unsigned long)[values count]);
            GHLSSPrefsLogLine(buf);
        } else {
            // values 讀不到——不推空白頁，顯示一行說明（下次日誌能看到）。
            PSSpecifier *group = [PSSpecifier emptyGroupSpecifier];
            [group setProperty:GHLSSRuntimeString("选项读不到，先回上一页再试。") forKey:GHLSSRuntimeString("footerText")];
            [specs addObject:group];
            GHLSSPrefsLogLine("v72 prefs-linklist no values at build");
        }
        _specifiers = specs;
    }
    return _specifiers;
}

// v72：子頁每次出現都清快取重組（跟 PlistPage 同做法——只讀快取頁回來看見的
// 必須是新值，選中的勾才跟得上）。
- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    @try {
        _specifiers = nil;
        [self reloadSpecifiers];
    } @catch (NSException *e) {
        const char *reason = [e reason] ? [[e reason] UTF8String] : "?";
        char buf[256];
        snprintf(buf, sizeof(buf), "v72 prefs-linklist viewWillAppear EXCEPTION %s", reason);
        GHLSSPrefsLogLine(buf);
    }
}

// v72：LinkList 選項寫值記一行（框架原生的 PSListItemsController 寫值走它
// 自己的控制器，繞過我們有記日誌的 setPreferenceValue——這就是 24.log 裡
// exitAnimation／launcherStyle／keyboardPopupMode 一行 prefs-set 都沒有的原因）。
// 這裡先記 v72 prefs-linklist，再調繼承的 setPreferenceValue 真正寫入
//（CFPreferencesSetAppValue＋AppSynchronize，跟開關／滑桿同一條路）。
- (void)setPreferenceValue:(id)value specifier:(PSSpecifier *)specifier {
    NSString *key = specifier.properties[GHLSSRuntimeString("key")];
    const char *keyC = key ? [key UTF8String] : "?";
    const char *valC = value ? [[value description] UTF8String] : "?";
    char buf[256];
    snprintf(buf, sizeof(buf), "v72 prefs-linklist %s = %s", keyC, valC);
    GHLSSPrefsLogLine(buf);
    [super setPreferenceValue:value specifier:specifier];
}

@end

// v50：狀態頁——版本、插件開關狀態（開關值，不是即時載入狀態）、日誌最後
// 5 行、查看完整日誌、複製診斷信息、聯繫與源（QQ／QQ群／越獄源）。
// 繼承主頁控制器，所以按鈕派發（冒號 SEL）與提示框都是現成的。
@interface GHLSSStatusListController : GuHaiLongSplitScreenRootListController
@end

@implementation GHLSSStatusListController

- (void)viewDidLoad {
    @try {
        [super viewDidLoad];
    } @catch (NSException *e) {
        const char *reason = [e reason] ? [[e reason] UTF8String] : "?";
        char buf[256];
        snprintf(buf, sizeof(buf), "v57 prefs-status viewDidLoad EXCEPTION %s", reason);
        GHLSSPrefsLogLine(buf);
    }
    GHLSSPrefsLogLine("v57 prefs-page: Status");
}

// v55：狀態頁每次開頁重讀快照（實時狀態跟著浮窗走；不加定時器）。
- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self reloadSpecifiers];
}

// v52：狀態頁自己接點按，不再只靠繼承主頁的 didSelectRow——
// 15.log 證明點「源」／QQ／QQ群在日誌裡全無痕跡（派發沒跑、handler
// 沒跑、連入口日誌都沒有）；自己接，入口先記一行，派發走同一套
// GHLSSDispatchButtonTap（它現在也會讀 spec.action 兜底），其他行走 super。
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    char buf[160];
    snprintf(buf, sizeof(buf), "v57 prefs-status tap: section %ld row %ld", (long)indexPath.section, (long)indexPath.row);
    GHLSSPrefsLogLine(buf);
    if (GHLSSHandlePlistDetailTap(self, tableView, indexPath)) return;
    if (GHLSSDispatchButtonTap(self, tableView, indexPath)) return;
    [super tableView:tableView didSelectRowAtIndexPath:indexPath];
}

- (NSArray *)specifiers {
    if (!_specifiers) {
        @try {
            NSMutableArray *loaded = [self loadSpecifiersFromPlistName:GHLSSRuntimeString("Status") target:self];
            // v57（§144-1）：插件開關顯示行加回來，只填這一行的值（1.0.55 寫法）；
            // 最近日誌 tail、實時狀態組仍是刪掉的，不恢復。
            for (PSSpecifier *spec in loaded) {
                NSString *k = spec.properties[GHLSSRuntimeString("key")];
                if ([k isKindOfClass:[NSString class]] && [k isEqualToString:GHLSSRuntimeString("statusEnabledState")]) {
                    BOOL on = GHLSSPrefsBool("enabled", NO);
                    NSString *txt = on ? GHLSSRuntimeString("启用分屏开关：开（这是系统设定里的开关状态，不是即时载入状态）") : GHLSSRuntimeString("启用分屏开关：关（这是系统设定里的开关状态，不是即时载入状态）");
                    [spec setProperty:txt forKey:GHLSSRuntimeString("footerText")];
                }
            }
            _specifiers = loaded;
        } @catch (NSException *e) {
            const char *reason = [e reason] ? [[e reason] UTF8String] : "?";
            char buf[512];
            snprintf(buf, sizeof(buf), "v57 prefs-status specifiers EXCEPTION %s", reason);
            GHLSSPrefsLogLine(buf);
            NSMutableArray *safe = [NSMutableArray array];
            PSSpecifier *group = [PSSpecifier emptyGroupSpecifier];
            [group setProperty:GHLSSRuntimeString("状态页组装出错（已记进日志），先回上一页再试。") forKey:GHLSSRuntimeString("footerText")];
            [safe addObject:group];
            _specifiers = safe;
        }
        if (!_specifiers) _specifiers = [NSMutableArray array];
    }
    return _specifiers;
}

- (void)ghlssCopyDiagnostics:(PSSpecifier *)specifier {
    (void)specifier;
    BOOL on = GHLSSPrefsBool("enabled", NO);
    NSString *tail = GHLSSLogTailNewestFirstN(5);
    if (!tail) tail = GHLSSRuntimeString("");
    NSString *onOff = on ? GHLSSRuntimeString("开") : GHLSSRuntimeString("关");
    NSString *diag = [[[GHLSSRuntimeString("顾海龙集团分屏 v1.0.75\n插件开关：") stringByAppendingString:onOff] stringByAppendingString:GHLSSRuntimeString("\n最近日志：\n")] stringByAppendingString:tail];
    [UIPasteboard generalPasteboard].string = diag;
    GHLSSPrefsLogLine("v57 prefs-status diagnostics copied");
    [self ghlssShowAlertWithTitle:GHLSSRuntimeString("已复制") message:GHLSSRuntimeString("诊断信息已复制到剪贴板。")];
}

- (void)ghlssCopyQQ:(PSSpecifier *)specifier {
    (void)specifier;
    [UIPasteboard generalPasteboard].string = GHLSSRuntimeString("2309103548");
    GHLSSPrefsLogLine("v57 prefs-status QQ copied");
    [self ghlssShowAlertWithTitle:GHLSSRuntimeString("已复制") message:GHLSSRuntimeString("QQ 2309103548 已复制到剪贴板。")];
}

- (void)ghlssCopyQQGroup:(PSSpecifier *)specifier {
    (void)specifier;
    [UIPasteboard generalPasteboard].string = GHLSSRuntimeString("1130823454");
    GHLSSPrefsLogLine("v57 prefs-status QQ group copied");
    [self ghlssShowAlertWithTitle:GHLSSRuntimeString("已复制") message:GHLSSRuntimeString("QQ交流群 1130823454 已复制到剪贴板。")];
}

- (void)ghlssOpenRepoSource:(PSSpecifier *)specifier {
    (void)specifier;
    // v54：皇上 01:20 定——改成點一下複製源地址，不再打開（打不開也閃退過，
    // 複製最穩；閃退靠派發修法，不靠這一改）。
    [UIPasteboard generalPasteboard].string = GHLSSRuntimeString("https://guhailong-repo.pages.dev");
    GHLSSPrefsLogLine("v57 prefs-status repo copied");
    [self ghlssShowAlertWithTitle:GHLSSRuntimeString("已复制") message:GHLSSRuntimeString("越狱源地址已复制到剪贴板，去 Sileo／Zebra 贴上加入。")];
}

- (void)ghlssOpenTelegramGroup:(PSSpecifier *)specifier {
    (void)specifier;
    // v71：Telegram 行改成複製為主——23.log 證明點按每次都派發、openURL
    // 每次都回 success（34 次全是 opened），手機上卻什麼都沒跳出來；
    // 設定頁進程裡 openURL 就是不可見的失敗（v54 越獄源行「打不開也閃退過」
    // 同一類問題）。做法：先順手試 tg:// 深鏈（能打開最好，純添頭），
    // 不管成不成都複製 https 邀請連結＋彈「已複製」，保證一定有可見回饋、
    // 連結一定到手。注意：openURL: 已廢棄（-Werror 會報錯），用
    // openURL:options:completionHandler:（異步，結果在回調裡回來）。
    NSURL *tgURL = [NSURL URLWithString:GHLSSRuntimeString("tg://join?invite=UaeIYedetWtiZGQ1")];
    if (tgURL) {
        [[UIApplication sharedApplication] openURL:tgURL options:[NSDictionary dictionary] completionHandler:^(BOOL success) {
            (void)success;
            dispatch_async(dispatch_get_main_queue(), ^{
                GHLSSPrefsLogLine("v71 prefs-status telegram tg attempted");
            });
        }];
    }
    [UIPasteboard generalPasteboard].string = GHLSSRuntimeString("https://t.me/+UaeIYedetWtiZGQ1");
    GHLSSPrefsLogLine("v71 prefs-status telegram copied");
    [self ghlssShowAlertWithTitle:GHLSSRuntimeString("已复制") message:GHLSSRuntimeString("Telegram 群链接已复制到剪贴板，去 Telegram 贴上进群。")];
}

@end
