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

// v42：寫一個 prefs 數字，立刻落盤。
static void GHLSSWritePrefsDouble(const char *key, double value) {
    CFStringRef domain = GHLSSRuntimeCFString("com.guhailong.splitscreen");
    CFStringRef keyRef = GHLSSRuntimeCFString(key);
    if (domain && keyRef) {
        CFNumberRef n = CFNumberCreate(NULL, kCFNumberDoubleType, &value);
        if (n) {
            CFPreferencesSetAppValue(keyRef, n, domain);
            CFPreferencesAppSynchronize(domain);
            CFRelease(n);
        }
    }
    if (domain) CFRelease(domain);
    if (keyRef) CFRelease(keyRef);
}

// v42：卡片背景圖的固定檔名（設定目錄下，浮窗卡片和設定頁兩邊都讀得到；
// v55：卡片頭像已取消，只剩背景圖）。
static NSString *GHLSSCardBgPath(void) {
    return [GHLSSPrefsDir() stringByAppendingPathComponent:GHLSSRuntimeString("GuHaiLongSplitScreen-cardbg.jpg")];
}

// v53：哆啦A夢鈕自訂圖的固定檔名（跟卡片頭像／背景同一個設定目錄；
// dylib 那邊 GHLSSCustomDoraemonImagePath 寫死同一條路徑）。
static NSString *GHLSSDoraemonIconPath(void) {
    return [GHLSSPrefsDir() stringByAppendingPathComponent:GHLSSRuntimeString("GuHaiLongSplitScreen-doraemon.jpg")];
}

static NSString *GHLSSLogFilePath(void) {
    return GHLSSRuntimeString("/var/mobile/Library/Logs/GuHaiLongSplitScreen.log");
}

// v55：分屏實時狀態快照路徑（dylib 寫、prefs 讀，跟日誌同一目錄）。
static NSString *GHLSSStatusSnapshotPath(void) {
    return GHLSSRuntimeString("/var/mobile/Library/Logs/GuHaiLongSplitScreen-status.txt");
}

// v55：讀實時狀態快照，拼成狀態頁那行字（主窗幾個、小窗幾個、
// 哪個在前面、三屏開了沒）。檔案不存在／格式不對回 nil，
// 顯示「暫無（還沒開過浮窗）」，不要把舊數據當實時顯示。
static NSString *GHLSSReadStatusSnapshotText(void) {
    NSData *data = [NSData dataWithContentsOfFile:GHLSSStatusSnapshotPath()];
    if (!data || [data length] == 0) return nil;
    NSString *content = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    if (!content) return nil;
    NSArray *lines = [content componentsSeparatedByString:GHLSSRuntimeString("\n")];
    if ([lines count] == 0) return nil;
    NSString *magic = [lines objectAtIndex:0];
    if (![magic hasPrefix:GHLSSRuntimeString("GHLSS-STATUS")]) return nil;
    int mainN = -1, peekN = -1, three = 0;
    NSString *front = nil;
    for (NSString *line in lines) {
        if ([line hasPrefix:GHLSSRuntimeString("main=")]) mainN = [[line substringFromIndex:5] intValue];
        else if ([line hasPrefix:GHLSSRuntimeString("peek=")]) peekN = [[line substringFromIndex:5] intValue];
        else if ([line hasPrefix:GHLSSRuntimeString("three=")]) three = [[line substringFromIndex:6] intValue];
        else if ([line hasPrefix:GHLSSRuntimeString("front=")]) front = [line substringFromIndex:6];
    }
    if (mainN < 0 || peekN < 0) return nil;
    NSString *frontText = (front && [front length] > 0) ? front : GHLSSRuntimeString("無");
    NSString *threeText = three ? GHLSSRuntimeString("開") : GHLSSRuntimeString("沒開");
    return [NSString stringWithFormat:GHLSSRuntimeString("主窗 %d 個，小窗 %d 個\n前面：%@\n三屏：%@"), mainN, peekN, frontText, threeText];
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
        return GHLSSRuntimeString("還沒有日誌（檔案不存在或讀不到）。");
    }
    if ([data length] > 262144) {
        data = [data subdataWithRange:NSMakeRange([data length] - 262144, 262144)];
    }
    NSString *content = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    if (!content) content = [NSString stringWithContentsOfFile:GHLSSLogFilePath() encoding:NSUTF8StringEncoding error:nil];
    if (!content) {
        GHLSSLogTailLinesRead = 0;
        return GHLSSRuntimeString("還沒有日誌（檔案不存在或讀不到）。");
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
                snprintf(buf, sizeof(buf), "v55 prefs-table: %s via tableView", t);
                GHLSSPrefsLogLine(buf);
                return tv;
            }
        }
    } @catch (NSException *e) {
        const char *why = [e reason] ? [[e reason] UTF8String] : "?";
        char buf[256];
        snprintf(buf, sizeof(buf), "v55 prefs-table: %s tableView EXCEPTION %s", t, why);
        GHLSSPrefsLogLine(buf);
    }
    @try {
        UIView *view = controller.view;
        if ([view isKindOfClass:[UITableView class]]) {
            char buf[192];
            snprintf(buf, sizeof(buf), "v55 prefs-table: %s via self.view", t);
            GHLSSPrefsLogLine(buf);
            return (UITableView *)view;
        }
        for (UIView *sub in view.subviews) {
            if ([sub isKindOfClass:[UITableView class]]) {
                char buf[192];
                snprintf(buf, sizeof(buf), "v55 prefs-table: %s via subview", t);
                GHLSSPrefsLogLine(buf);
                return (UITableView *)sub;
            }
        }
    } @catch (NSException *e) {
        const char *why = [e reason] ? [[e reason] UTF8String] : "?";
        char buf[256];
        snprintf(buf, sizeof(buf), "v55 prefs-table: %s view scan EXCEPTION %s", t, why);
        GHLSSPrefsLogLine(buf);
    }
    @try {
        id iv = [controller valueForKey:GHLSSRuntimeString("_tableView")];
        if ([iv isKindOfClass:[UITableView class]]) {
            char buf[192];
            snprintf(buf, sizeof(buf), "v55 prefs-table: %s via _tableView", t);
            GHLSSPrefsLogLine(buf);
            return (UITableView *)iv;
        }
    } @catch (NSException *e) {
        const char *why = [e reason] ? [[e reason] UTF8String] : "?";
        char buf[256];
        snprintf(buf, sizeof(buf), "v55 prefs-table: %s _tableView EXCEPTION %s", t, why);
        GHLSSPrefsLogLine(buf);
    }
    char buf[192];
    snprintf(buf, sizeof(buf), "v55 prefs-table: %s none", t);
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
        GHLSSPrefsLogLine("v55 prefs-config tap: no specifier for tap");
        return NO;
    }
    // v52：入口先記一行（section／row／cellType），點了沒反應時日誌看得見
    // 派發走到哪一步——之前這裡靜默回 NO，狀態頁的點按在日誌裡全無痕跡。
    {
        char tapBuf[160];
        snprintf(tapBuf, sizeof(tapBuf), "v55 prefs-config tap: section %ld row %ld cellType %d", (long)indexPath.section, (long)indexPath.row, (int)spec.cellType);
        GHLSSPrefsLogLine(tapBuf);
    }
    if (spec.cellType != PSButtonCell) return NO;
    // v54：action 只走 properties，絕不再碰 spec->action ivar（見上面）。
    NSString *actionName = [spec propertyForKey:GHLSSRuntimeString("action")];
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if (!actionName || [actionName length] == 0) {
        GHLSSPrefsLogLine("v55 prefs-config tap: button without action");
        return YES;
    }
    const char *actionC = [actionName UTF8String];
    SEL action = NSSelectorFromString(actionName);
    id target = spec.target;
    if (!target) target = controller;
    char buf[320];
    snprintf(buf, sizeof(buf), "v55 prefs-config tap: action %s target %s", actionC ? actionC : "?", [NSStringFromClass([target class]) UTF8String]);
    GHLSSPrefsLogLine(buf);
    // v44：action 字串是裸名（沒有冒號），但方法都帶一個參數（PSSpecifier *），
    // 真正的 selector 有冒號（例如 ghlssBackupConfig:）。裸名先試，不回應就補冒號再試。
    // 這也是為什麼框架自己的派發在 v42 也不動——框架也是拿同一個裸名字串轉 SEL，
    // respondsToSelector 永遠回 NO，點按就這樣被靜靜吞掉了。
    if (![target respondsToSelector:action]) {
        GHLSSPrefsLogLine("v55 prefs-config tap: bare name does not respond, trying colon");
        NSString *colonName = [actionName stringByAppendingString:GHLSSRuntimeString(":")];
        SEL colonAction = NSSelectorFromString(colonName);
        if ([target respondsToSelector:colonAction]) {
            action = colonAction;
            GHLSSPrefsLogLine("v55 prefs-config tap: colon selector responds");
        }
    }
    if (![target respondsToSelector:action]) {
        GHLSSPrefsLogLine("v55 prefs-config tap: target does not respond to bare or colon, falling through to super");
        return NO;
    }
    // v44：變數 SEL 不能用 performSelector（-Werror 下 -Warc-performSelector-leaks），
    // 用 v41 就在用的 objc_msgSend 寫法。
    ((void (*)(id, SEL, id))objc_msgSend)(target, action, spec);
    snprintf(buf, sizeof(buf), "v55 prefs-config tap: dispatched %s", [NSStringFromSelector(action) UTF8String]);
    GHLSSPrefsLogLine(buf);
    return YES;
    } @catch (NSException *e) {
        const char *why = [e reason] ? [[e reason] UTF8String] : "?";
        char buf[512];
        snprintf(buf, sizeof(buf), "v55 prefs-config tap EXCEPTION %s", why);
        GHLSSPrefsLogLine(buf);
        @try {
            UIAlertController *alert = [UIAlertController alertControllerWithTitle:GHLSSRuntimeString("點按失敗") message:GHLSSRuntimeString("這個按鈕點下去出錯了（已記進日誌），先回上一頁再試。") preferredStyle:UIAlertControllerStyleAlert];
            [alert addAction:[UIAlertAction actionWithTitle:GHLSSRuntimeString("好") style:UIAlertActionStyleDefault handler:nil]];
            [controller presentViewController:alert animated:YES completion:nil];
        } @catch (NSException *e2) {
            (void)e2;
        }
        return YES;
    }
}

@interface GuHaiLongSplitScreenRootListController : PSListController <PHPickerViewControllerDelegate>
@property (nonatomic, strong) UIImageView *ghlssBannerView;
@property (nonatomic, strong) UIView *ghlssBannerContainer;
@property (nonatomic, assign) BOOL ghlssBannerInstalled;
@end

@implementation GuHaiLongSplitScreenRootListController

// v43：記進了哪一頁（PlistPage 繼承這裡，類名是 GHLSSPlistPageController，
// 具體哪份 plist 由 specifiers 裡的 plistpage entry 行給出）。
- (void)viewDidLoad {
    [super viewDidLoad];
    char buf[160];
    snprintf(buf, sizeof(buf), "v55 prefs-page: %s", [NSStringFromClass([self class]) UTF8String]);
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
            [restoreBtn setTitle:GHLSSRuntimeString("恢復默認") forState:UIControlStateNormal];
            restoreBtn.titleLabel.font = [UIFont systemFontOfSize:13];
            restoreBtn.backgroundColor = [[UIColor whiteColor] colorWithAlphaComponent:0.75];
            restoreBtn.layer.cornerRadius = 6.0;
            [restoreBtn addTarget:self action:@selector(ghlssRestoreBannerBg:) forControlEvents:UIControlEventTouchUpInside];
            [container addSubview:restoreBtn];
            self.ghlssBannerView = iv;
            self.ghlssBannerContainer = container;
            [self ghlssRefreshBannerPreview];
        } @catch (NSException *e) {
            GHLSSPrefsLogLine("v55 prefs-banner: viewDidLoad EXCEPTION");
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
            GHLSSPrefsLogLine("v55 prefs-banner: table mismatch, header not mounted");
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
                GHLSSPrefsLogLine("v55 prefs-banner: header mounted");
            } @catch (NSException *e) {
                GHLSSPrefsLogLine("v55 prefs-banner: mount EXCEPTION");
            }
        } else {
            GHLSSPrefsLogLine("v55 prefs-banner: no table, header not mounted");
        }
    }
}

- (void)ghlssRefreshBannerPreview {
    @try {
        UIImage *img = [UIImage imageWithContentsOfFile:GHLSSCardBgPath()];
        self.ghlssBannerView.image = img;
    } @catch (NSException *e) {
        GHLSSPrefsLogLine("v55 prefs-banner: refresh EXCEPTION");
    }
}

- (void)ghlssBannerTapped:(UITapGestureRecognizer *)tap {
    (void)tap;
    PHPickerConfiguration *config = [[PHPickerConfiguration alloc] init];
    config.filter = [PHPickerFilter imagesFilter];
    config.selectionLimit = 1;
    PHPickerViewController *picker = [[PHPickerViewController alloc] initWithConfiguration:config];
    picker.delegate = self;
    [self presentViewController:picker animated:YES completion:nil];
}

- (void)ghlssRestoreBannerBg:(id)sender {
    (void)sender;
    [[NSFileManager defaultManager] removeItemAtPath:GHLSSCardBgPath() error:nil];
    GHLSSWritePrefsBool("cardBgCustom", NO);
    [self ghlssRefreshBannerPreview];
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:GHLSSRuntimeString("已恢復默認白卡") message:GHLSSRuntimeString("浮窗設定卡片回到默認白卡。") preferredStyle:UIAlertControllerStyleAlert];
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
            UIImage *resized = GHLSSPrefsResizeImageMax(picked, 1024.0);
            if (!resized) return;
            NSData *data = UIImageJPEGRepresentation(resized, 0.85);
            BOOL ok = data && [data writeToFile:GHLSSCardBgPath() atomically:YES];
            if (ok) {
                GHLSSWritePrefsBool("cardBgCustom", YES);
                [self ghlssRefreshBannerPreview];
                UIAlertController *alert = [UIAlertController alertControllerWithTitle:GHLSSRuntimeString("背景圖已換好") message:GHLSSRuntimeString("浮窗設定卡片就是這張背景（上面罩半透明白）。") preferredStyle:UIAlertControllerStyleAlert];
                [alert addAction:[UIAlertAction actionWithTitle:GHLSSRuntimeString("好") style:UIAlertActionStyleDefault handler:nil]];
                [self presentViewController:alert animated:YES completion:nil];
            } else {
                UIAlertController *alert = [UIAlertController alertControllerWithTitle:GHLSSRuntimeString("保存背景圖失敗") message:GHLSSRuntimeString("圖片寫不進設定目錄。") preferredStyle:UIAlertControllerStyleAlert];
                [alert addAction:[UIAlertAction actionWithTitle:GHLSSRuntimeString("好") style:UIAlertActionStyleDefault handler:nil]];
                [self presentViewController:alert animated:YES completion:nil];
            }
        });
    }];
}

// v43：按鈕行自己派發（見上面 GHLSSDispatchButtonTap）；其他行走框架。
// v47：plist 名 detail 的連結行先攔下來自己推 PlistPage（見下面
// GHLSSHandlePlistDetailTap），不再走框架預設——框架推的原生頁是空的。
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
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
        } @catch (NSException *e) {
            const char *reason = [e reason] ? [[e reason] UTF8String] : "?";
            char buf[512];
            snprintf(buf, sizeof(buf), "v55 prefs-root specifiers EXCEPTION %s", reason);
            GHLSSPrefsLogLine(buf);
            NSMutableArray *safe = [NSMutableArray array];
            PSSpecifier *group = [PSSpecifier emptyGroupSpecifier];
            [group setProperty:GHLSSRuntimeString("主頁組裝出錯（已記進日誌），先回設定再試。") forKey:GHLSSRuntimeString("footerText")];
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
    GHLSSPrefsLogLine("v55 prefs-update: check started");
    __weak typeof(self) weakSelf = self;
    GHLSSCheckForUpdate(^(NSString *latest, const char *error) {
        typeof(self) strongSelf = weakSelf;
        if (!strongSelf) return;
        if (error || !latest) {
            GHLSSPrefsLogLine("v55 prefs-update: fetch failed");
            [strongSelf ghlssShowAlertWithTitle:GHLSSRuntimeString("檢查失敗") message:GHLSSRuntimeString("檢查失敗，請檢查網絡。")];
            return;
        }
        char buf[192];
        snprintf(buf, sizeof(buf), "v55 prefs-update: latest %s", [latest UTF8String]);
        GHLSSPrefsLogLine(buf);
        int cmp = GHLSSCompareDottedVersions([latest UTF8String], "1.0.55");
        if (cmp <= 0) {
            [strongSelf ghlssShowAlertWithTitle:GHLSSRuntimeString("已經是最新版") message:GHLSSRuntimeString("已經是最新版 1.0.55。")];
        } else {
            NSString *msg = [[GHLSSRuntimeString("有新版 ") stringByAppendingString:latest] stringByAppendingString:GHLSSRuntimeString("，請去 Sileo 更新。")];
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
        snprintf(buf, sizeof(buf), "v55 prefs-set: %s = %s", keyC ? keyC : "?", valC ? valC : "?");
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
            GHLSSPrefsLogLine("v55 prefs-config alert shown");
        } else {
            GHLSSPrefsLogLine("v55 prefs-config alert FAILED: no presenter");
        }
    });
}

// 備份配置：設定檔複製一份到備份檔。
- (void)ghlssBackupConfig:(PSSpecifier *)specifier {
    (void)specifier;
    GHLSSPrefsLogLine("v55 prefs-config backup entry");
    NSFileManager *fm = [NSFileManager defaultManager];
    NSString *src = GHLSSPrefsFilePath();
    NSString *dst = GHLSSBackupFilePath();
    // v43：先同步一次，確保磁碟上的檔案是最新值，再複製。
    CFStringRef domain = GHLSSRuntimeCFString("com.guhailong.splitscreen");
    if (domain) { CFPreferencesAppSynchronize(domain); CFRelease(domain); }
    if (![fm fileExistsAtPath:src]) {
        GHLSSPrefsLogLine("v55 prefs-config backup: no prefs file");
        [self ghlssShowAlertWithTitle:GHLSSRuntimeString("没有配置文件可备份") message:GHLSSRuntimeString("先改一个设置，配置文件才会生成。")];
        return;
    }
    NSError *err = nil;
    [fm removeItemAtPath:dst error:nil];
    BOOL ok = [fm copyItemAtPath:src toPath:dst error:&err];
    if (ok) {
        char buf[512];
        snprintf(buf, sizeof(buf), "v55 prefs-config backup: copied to %s", [dst UTF8String]);
        GHLSSPrefsLogLine(buf);
    } else {
        char buf[768];
        const char *errC = [[err localizedDescription] UTF8String];
        snprintf(buf, sizeof(buf), "v55 prefs-config backup: copy failed %s -> %s : %s", [src UTF8String], [dst UTF8String], errC ? errC : "?");
        GHLSSPrefsLogLine(buf);
    }
    if (ok) {
        [self ghlssShowAlertWithTitle:GHLSSRuntimeString("已备份配置") message:GHLSSRuntimeString("备份在 GuHaiLongSplitScreen-backup.plist，恢复时读这个文件。")];
    } else {
        [self ghlssShowAlertWithTitle:GHLSSRuntimeString("备份失败") message:GHLSSRuntimeString("复制配置文件时出错。")];
    }
}

// 導出配置（非備份配置）：設定檔複製一份到導出檔，導入時讀它。
- (void)ghlssExportConfig:(PSSpecifier *)specifier {
    (void)specifier;
    GHLSSPrefsLogLine("v55 prefs-config export entry");
    NSFileManager *fm = [NSFileManager defaultManager];
    NSString *src = GHLSSPrefsFilePath();
    NSString *dst = GHLSSExportFilePath();
    // v43：先同步一次，確保磁碟上的檔案是最新值，再複製。
    CFStringRef domain = GHLSSRuntimeCFString("com.guhailong.splitscreen");
    if (domain) { CFPreferencesAppSynchronize(domain); CFRelease(domain); }
    if (![fm fileExistsAtPath:src]) {
        GHLSSPrefsLogLine("v55 prefs-config export: no prefs file");
        [self ghlssShowAlertWithTitle:GHLSSRuntimeString("没有配置文件可导出") message:GHLSSRuntimeString("先改一个设置，配置文件才会生成。")];
        return;
    }
    [fm removeItemAtPath:dst error:nil];
    NSError *err = nil;
    BOOL ok = [fm copyItemAtPath:src toPath:dst error:&err];
    if (ok) {
        char buf[512];
        snprintf(buf, sizeof(buf), "v55 prefs-config export: copied to %s", [dst UTF8String]);
        GHLSSPrefsLogLine(buf);
    } else {
        char buf[768];
        const char *errC = [[err localizedDescription] UTF8String];
        snprintf(buf, sizeof(buf), "v55 prefs-config export: copy failed %s -> %s : %s", [src UTF8String], [dst UTF8String], errC ? errC : "?");
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
    GHLSSPrefsLogLine("v55 prefs-config import entry");
    NSFileManager *fm = [NSFileManager defaultManager];
    NSString *src = GHLSSExportFilePath();
    if (![fm fileExistsAtPath:src]) {
        GHLSSPrefsLogLine("v55 prefs-config import: no export file");
        [self ghlssShowAlertWithTitle:GHLSSRuntimeString("没有找到导出的配置文件") message:GHLSSRuntimeString("先点「导出配置」，再导入。")];
        return;
    }
    NSDictionary *dict = [NSDictionary dictionaryWithContentsOfFile:src];
    if (!dict) {
        char buf[512];
        snprintf(buf, sizeof(buf), "v55 prefs-config import: export file unreadable %s", [src UTF8String]);
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
    snprintf(buf, sizeof(buf), "v55 prefs-config import: applied %lu keys from %s", (unsigned long)[dict count], [src UTF8String]);
    GHLSSPrefsLogLine(buf);
    [self ghlssShowAlertWithTitle:GHLSSRuntimeString("已导入配置") message:GHLSSRuntimeString("配置已恢复，请重新启动 SpringBoard 生效。")];
}

// 從備份文件恢復配置：讀備份檔，蓋掉現在的設定檔。
// v43：同導入，改走 CFPreferences 逐鍵寫入（見上）。
- (void)ghlssRestoreConfig:(PSSpecifier *)specifier {
    (void)specifier;
    GHLSSPrefsLogLine("v55 prefs-config restore entry");
    NSFileManager *fm = [NSFileManager defaultManager];
    NSString *src = GHLSSBackupFilePath();
    if (![fm fileExistsAtPath:src]) {
        GHLSSPrefsLogLine("v55 prefs-config restore: no backup file");
        [self ghlssShowAlertWithTitle:GHLSSRuntimeString("没有找到备份文件") message:GHLSSRuntimeString("先点「备份配置」，再恢复。")];
        return;
    }
    NSDictionary *dict = [NSDictionary dictionaryWithContentsOfFile:src];
    if (!dict) {
        char buf[512];
        snprintf(buf, sizeof(buf), "v55 prefs-config restore: backup file unreadable %s", [src UTF8String]);
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
    snprintf(buf, sizeof(buf), "v55 prefs-config restore: applied %lu keys from %s", (unsigned long)[dict count], [src UTF8String]);
    GHLSSPrefsLogLine(buf);
    [self ghlssShowAlertWithTitle:GHLSSRuntimeString("已从备份恢复配置") message:GHLSSRuntimeString("配置已恢复，请重新启动 SpringBoard 生效。")];
}

// 重置為默認配置：刪掉整個設定檔（備份檔不動），全部開關回預設值。
// v43：舊寫法只刪檔案——cfprefsd 快取裡的值還在，reload 後開關還是舊值，
// 看著就像沒反應。改成先用 CFPreferencesCopyKeyList 逐鍵清掉（快取才會空），
// 再刪檔案。
- (void)ghlssResetConfig:(PSSpecifier *)specifier {
    (void)specifier;
    GHLSSPrefsLogLine("v55 prefs-config reset entry");
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
    snprintf(buf, sizeof(buf), "v55 prefs-config reset: cleared %ld keys, file %s removed %d", (long)clearedCount, [dst UTF8String], removed ? 1 : 0);
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
- (void)ghlssApplyLayoutGame:(PSSpecifier *)specifier {
    (void)specifier;
    GHLSSPrefsLogLine("v55 prefs-layout: game applied");
    GHLSSWritePrefsBool("gameModeEnabled", YES);
    GHLSSWritePrefsBool("centerOnOpen", NO);
    GHLSSWritePrefsDouble("cornerRadius", 20);
    GHLSSWritePrefsDouble("safeDistance", 20);
    GHLSSWritePrefsBool("shadowEnabled", YES);
    GHLSSWritePrefsBool("taskbarEnabled", NO);
    GHLSSWritePrefsCString("windowSizePreset", "large");
    [self reloadSpecifiers];
    [self ghlssShowAlertWithTitle:GHLSSRuntimeString("已切到遊戲布局") message:GHLSSRuntimeString("遊戲模式開、ARC 開、固定中心關、圓角 20、安全距離 20、陰影開、任務欄關、浮窗大。請重新啟動 SpringBoard 生效。")];
}

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

@interface GHLSSAppPickerListController : PSListController
@end

@implementation GHLSSAppPickerListController

// v43：記進了哪一頁。
- (void)viewDidLoad {
    @try {
        [super viewDidLoad];
    } @catch (NSException *e) {
        const char *reason = [e reason] ? [[e reason] UTF8String] : "?";
        char buf[256];
        snprintf(buf, sizeof(buf), "v55 prefs-apppicker viewDidLoad EXCEPTION %s", reason);
        GHLSSPrefsLogLine(buf);
    }
    GHLSSPrefsLogLine("v55 prefs-page: AppPicker");
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
            [group setProperty:GHLSSRuntimeString("开的 App 出现在启动器/ARC 里（最多 12 个，自选 7 个）。清单在后台列举、缓存起来；刚装的 App 可能要等一会儿才出现，缺 App 時點下面「重新掃描」。") forKey:footerKey];
            [specs addObject:group];
            // v50：重新掃描（清單是後台列舉的緩存，舊了會缺 App；點一下請
            // dylib 2 秒內重建緩存，下次開這頁就看到新的）。
            PSSpecifier *rescan = [PSSpecifier preferenceSpecifierNamed:GHLSSRuntimeString("重新掃描") target:self set:nil get:nil detail:nil cell:PSButtonCell edit:nil];
            [rescan setProperty:GHLSSRuntimeString("ghlssRescanApps") forKey:GHLSSRuntimeString("action")];
            [specs addObject:rescan];
            // 固定 5 個。
            for (int i = 0; i < 5; i++) {
                NSString *name = GHLSSRuntimeString(GHLSSFixedNames[i]);
                PSSpecifier *spec = [PSSpecifier preferenceSpecifierNamed:name target:self set:@selector(setPreferenceValue:specifier:) get:@selector(readPreferenceValue:) detail:nil cell:PSSwitchCell edit:nil];
                [spec setProperty:GHLSSRuntimeString(GHLSSFixedEnabledKeys[i]) forKey:GHLSSRuntimeString("key")];
                [spec setProperty:GHLSSRuntimeString("com.guhailong.splitscreen") forKey:GHLSSRuntimeString("defaults")];
                [spec setProperty:@(YES) forKey:GHLSSRuntimeString("default")];
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
            snprintf(buf, sizeof(buf), "v55 prefs-apppicker specifiers EXCEPTION %s", reason);
            GHLSSPrefsLogLine(buf);
            NSMutableArray *safe = [NSMutableArray array];
            PSSpecifier *group = [PSSpecifier emptyGroupSpecifier];
            [group setProperty:GHLSSRuntimeString("選擇器頁組裝出錯（已記進日誌），先回上一頁再試。") forKey:GHLSSRuntimeString("footerText")];
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
    GHLSSPrefsLogLine("v55 prefs-apppicker rescan requested");
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:GHLSSRuntimeString("正在重新掃描") message:GHLSSRuntimeString("已請後台重新列舉已安裝 App，稍後再開這一頁就看到新的清單。") preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:GHLSSRuntimeString("好") style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (id)readPreferenceValue:(PSSpecifier *)specifier {
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
    NSString *key = specifier.properties[GHLSSRuntimeString("key")];
    if (!key) return;
    BOOL on = [value boolValue];
    NSString *selPrefix = GHLSSRuntimeString("sel-");
    if ([key hasPrefix:selPrefix]) {
        NSString *bidStr = [key substringFromIndex:[selPrefix length]];
        BOOL ok = GHLSSSetAppInLauncherPrefs([bidStr UTF8String], on);
        // v43：記自選 App 加／減（槽位滿了也會記，開關彈回關的原因就有了）。
        char buf[320];
        snprintf(buf, sizeof(buf), "v55 prefs-set: sel %s = %d ok %d", [bidStr UTF8String], on ? 1 : 0, ok ? 1 : 0);
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
    snprintf(buf, sizeof(buf), "v55 prefs-set: %s = %s", keyC ? keyC : "?", valC ? valC : "?");
    GHLSSPrefsLogLine(buf);
}

@end

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
    [super viewDidLoad];
    GHLSSPrefsLogLine("v55 prefs-page: AppSort");
    self.navigationItem.rightBarButtonItem = self.editButtonItem;
    // 現在的順序：順序表裡的先按表裡的順序，沒在表裡的接在後面。
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
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    // v54：拖曳手柄沒出現過（19.log prefs-sort 全文 0 行）——兩層都開編輯：
    // 控制器層 self.editing（框架認）＋表格層 setEditing，並記一行驗證
    //（editing 是不是真開了、幾行），下次日誌看得見手柄到底有沒有出來。
    @try {
        [self setEditing:YES animated:NO];
    } @catch (NSException *e) {
        GHLSSPrefsLogLine("v55 prefs-sort: self setEditing EXCEPTION");
    }
    UITableView *tv = GHLSSSafeTableViewForController(self, "sort");
    if (tv) {
        @try {
            [tv reloadData];
            [tv setEditing:YES animated:NO];
            char buf[192];
            snprintf(buf, sizeof(buf), "v55 prefs-sort: editing=%d rows=%ld", (int)tv.editing, (long)[tv numberOfRowsInSection:0]);
            GHLSSPrefsLogLine(buf);
        } @catch (NSException *e) {
            GHLSSPrefsLogLine("v55 prefs-sort: setEditing EXCEPTION");
        }
    }
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
                [specs addObject:spec];
            }
            _specifiers = specs;
    
        } @catch (NSException *e) {
            const char *reason = [e reason] ? [[e reason] UTF8String] : "?";
            char buf[512];
            snprintf(buf, sizeof(buf), "v55 prefs-appsort specifiers EXCEPTION %s", reason);
            GHLSSPrefsLogLine(buf);
            NSMutableArray *safe = [NSMutableArray array];
            PSSpecifier *group = [PSSpecifier emptyGroupSpecifier];
            [group setProperty:GHLSSRuntimeString("排序頁組裝出錯（已記進日誌），先回上一頁再試。") forKey:GHLSSRuntimeString("footerText")];
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
    snprintf(buf, sizeof(buf), "v55 prefs-sort: app order moved %s %ld -> %ld", [bid UTF8String], (long)from, (long)to);
    GHLSSPrefsLogLine(buf);
}

@end

// v46：「三屏工具欄排序」——拖動換浮窗控制條四顆鈕的左右順序
// （關閉／最小化／釘選／縮放）。順序存 prefs 鍵
// toolbarOrder（逗號分隔）；預設 close,minimize,pin,scale。
// v47：「透」拿掉，舊順序表裡殘留的 "opacity" 讀進來直接過濾掉
// （只認下面四個識別字，不會崩、不會出幽靈行）。
// 前兩顆排左邊，後兩顆排右邊；窄側窗只放得下關閉／最小化／縮放。
// 新開的窗照新順序；活動窗 2 秒內跟著重排（tick 裡調
// GHLSSRelayoutActiveTitleBar）。
static const char *GHLSSToolbarSortIDs[4] = {
    "close", "minimize", "pin", "scale"
};
static const char *GHLSSToolbarSortNames[4] = {
    "关闭", "最小化", "钉选", "缩放"
};

@interface GHLSSToolbarSortListController : PSListController
@property (nonatomic, strong) NSMutableArray *orderedIDs;
@end

@implementation GHLSSToolbarSortListController

- (void)viewDidLoad {
    [super viewDidLoad];
    GHLSSPrefsLogLine("v55 prefs-page: ToolbarSort");
    self.navigationItem.rightBarButtonItem = self.editButtonItem;
    // 現在的順序：順序表裡的先按表裡的順序，缺的按預設補回來。
    NSMutableArray *ordered = [NSMutableArray array];
    char *raw = GHLSSPrefsCString("toolbarOrder");
    if (raw) {
        NSString *rawStr = [NSString stringWithCString:raw encoding:NSUTF8StringEncoding];
        free(raw);
        if (rawStr && [rawStr length] > 0) {
            NSArray *parts = [rawStr componentsSeparatedByString:GHLSSRuntimeString(",")];
            for (NSString *tid in parts) {
                for (int i = 0; i < 4; i++) {
                    NSString *known = [NSString stringWithCString:GHLSSToolbarSortIDs[i] encoding:NSUTF8StringEncoding];
                    if ([tid isEqualToString:known] && ![ordered containsObject:tid]) [ordered addObject:tid];
                }
            }
        }
    }
    for (int i = 0; i < 4; i++) {
        NSString *known = [NSString stringWithCString:GHLSSToolbarSortIDs[i] encoding:NSUTF8StringEncoding];
        if (![ordered containsObject:known]) [ordered addObject:known];
    }
    self.orderedIDs = ordered;
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    // v54：拖曳手柄沒出現過（19.log prefs-sort 全文 0 行）——兩層都開編輯：
    // 控制器層 self.editing（框架認）＋表格層 setEditing，並記一行驗證
    //（editing 是不是真開了、幾行），下次日誌看得見手柄到底有沒有出來。
    @try {
        [self setEditing:YES animated:NO];
    } @catch (NSException *e) {
        GHLSSPrefsLogLine("v55 prefs-sort: self setEditing EXCEPTION");
    }
    UITableView *tv = GHLSSSafeTableViewForController(self, "sort");
    if (tv) {
        @try {
            [tv reloadData];
            [tv setEditing:YES animated:NO];
            char buf[192];
            snprintf(buf, sizeof(buf), "v55 prefs-sort: editing=%d rows=%ld", (int)tv.editing, (long)[tv numberOfRowsInSection:0]);
            GHLSSPrefsLogLine(buf);
        } @catch (NSException *e) {
            GHLSSPrefsLogLine("v55 prefs-sort: setEditing EXCEPTION");
        }
    }
}

- (NSArray *)specifiers {
    if (!_specifiers) {
        @try {
            NSMutableArray *specs = [NSMutableArray array];
            PSSpecifier *group = [PSSpecifier emptyGroupSpecifier];
            [group setProperty:GHLSSRuntimeString("四颗钮：关闭、最小化、钉选、缩放，都是毛玻璃圆钮、白符号。拖右边的手柄换顺序，松手立刻存；前两颗排左边，后两颗排右边；窄侧窗只放得下关闭／最小化／缩放。新开的窗照新顺序，活动窗 2 秒内跟着重排。") forKey:GHLSSRuntimeString("footerText")];
            [specs addObject:group];
            for (NSString *tid in self.orderedIDs) {
                NSString *name = tid;
                for (int i = 0; i < 4; i++) {
                    NSString *known = [NSString stringWithCString:GHLSSToolbarSortIDs[i] encoding:NSUTF8StringEncoding];
                    if ([tid isEqualToString:known]) { name = GHLSSRuntimeString(GHLSSToolbarSortNames[i]); break; }
                }
                PSSpecifier *spec = [PSSpecifier preferenceSpecifierNamed:name target:self set:nil get:nil detail:nil cell:PSStaticTextCell edit:nil];
                [specs addObject:spec];
            }
            _specifiers = specs;
    
        } @catch (NSException *e) {
            const char *reason = [e reason] ? [[e reason] UTF8String] : "?";
            char buf[512];
            snprintf(buf, sizeof(buf), "v55 prefs-toolbarsort specifiers EXCEPTION %s", reason);
            GHLSSPrefsLogLine(buf);
            NSMutableArray *safe = [NSMutableArray array];
            PSSpecifier *group = [PSSpecifier emptyGroupSpecifier];
            [group setProperty:GHLSSRuntimeString("排序頁組裝出錯（已記進日誌），先回上一頁再試。") forKey:GHLSSRuntimeString("footerText")];
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
    if (from < 0 || to < 0 || from >= (NSInteger)[self.orderedIDs count] || to >= (NSInteger)[self.orderedIDs count]) return;
    if (from == to) return;
    NSString *tid = [self.orderedIDs objectAtIndex:from];
    [self.orderedIDs removeObjectAtIndex:from];
    [self.orderedIDs insertObject:tid atIndex:to];
    NSString *joined = [self.orderedIDs componentsJoinedByString:GHLSSRuntimeString(",")];
    GHLSSWritePrefsCString("toolbarOrder", [joined UTF8String]);
    char buf[256];
    snprintf(buf, sizeof(buf), "v55 prefs-sort: toolbar order moved %s %ld -> %ld", [tid UTF8String], (long)from, (long)to);
    GHLSSPrefsLogLine(buf);
}

@end

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
        snprintf(buf, sizeof(buf), "v55 prefs-log: super viewDidLoad EXCEPTION %s", why);
        GHLSSPrefsLogLine(buf);
    }
    GHLSSPrefsLogLine("v55 prefs-page: LogViewer");
    @try {
        UITextView *tv = [[UITextView alloc] initWithFrame:CGRectMake(0, 0, [UIScreen mainScreen].bounds.size.width, 420)];
        tv.font = [UIFont systemFontOfSize:11];
        tv.editable = NO;
        tv.backgroundColor = [UIColor colorWithWhite:0.95 alpha:1.0];
        tv.text = GHLSSLogTailNewestFirst();
        self.logView = tv;
        char buf[128];
        snprintf(buf, sizeof(buf), "v55 prefs-log: read %d lines", GHLSSLogTailLinesRead);
        GHLSSPrefsLogLine(buf);
    } @catch (NSException *e) {
        const char *why = [e reason] ? [[e reason] UTF8String] : "?";
        char buf[256];
        snprintf(buf, sizeof(buf), "v55 prefs-log: build text view EXCEPTION %s", why);
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
        snprintf(buf, sizeof(buf), "v55 prefs-log: super viewDidAppear EXCEPTION %s", why);
        GHLSSPrefsLogLine(buf);
    }
    if (self.logView && !self.headerInstalled) {
        UITableView *tv = GHLSSSafeTableViewForController(self, "log");
        if (tv) {
            @try {
                tv.tableHeaderView = self.logView;
                self.headerInstalled = YES;
                GHLSSPrefsLogLine("v55 prefs-log: header mounted");
            } @catch (NSException *e) {
                const char *why = [e reason] ? [[e reason] UTF8String] : "?";
                char buf[256];
                snprintf(buf, sizeof(buf), "v55 prefs-log: mount EXCEPTION %s", why);
                GHLSSPrefsLogLine(buf);
            }
        } else {
            GHLSSPrefsLogLine("v55 prefs-log: no table, header not mounted");
        }
    }
}

- (NSArray *)specifiers {
    if (!_specifiers) {
        @try {
            NSMutableArray *specs = [NSMutableArray array];
            PSSpecifier *group = [PSSpecifier emptyGroupSpecifier];
            [group setProperty:GHLSSRuntimeString("最新的在最上面（預設最後 200 行）；清空是把檔案截斷，新的日誌會繼續寫進來。") forKey:GHLSSRuntimeString("footerText")];
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
            snprintf(buf, sizeof(buf), "v55 prefs-log: specifiers EXCEPTION %s", why);
            GHLSSPrefsLogLine(buf);
            NSMutableArray *safe = [NSMutableArray array];
            PSSpecifier *group = [PSSpecifier emptyGroupSpecifier];
            [group setProperty:GHLSSRuntimeString("日誌頁組裝出錯（已記進日誌），先回上一頁再試。") forKey:GHLSSRuntimeString("footerText")];
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
        GHLSSPrefsLogLine("v55 prefs-log: refresh EXCEPTION");
    }
}

- (void)ghlssLogClear:(PSSpecifier *)specifier {
    (void)specifier;
    NSError *err = nil;
    BOOL ok = [[NSData data] writeToFile:GHLSSLogFilePath() options:NSDataWritingAtomic error:&err];
    if (ok) {
        if (self.logView) self.logView.text = GHLSSLogTailNewestFirst();
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:GHLSSRuntimeString("日誌已清空") message:GHLSSRuntimeString("日誌檔案已截斷，新的日誌會繼續寫進來。") preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:GHLSSRuntimeString("好") style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:alert animated:YES completion:nil];
    } else {
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:GHLSSRuntimeString("清空失敗") message:GHLSSRuntimeString("日誌檔案寫不動（權限問題），請用 Filza 手動清。") preferredStyle:UIAlertControllerStyleAlert];
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
        snprintf(buf, sizeof(buf), "v55 prefs-pairlist viewDidLoad EXCEPTION %s", reason);
        GHLSSPrefsLogLine(buf);
    }
    GHLSSPrefsLogLine("v55 prefs-page: PairList");
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
            [group setProperty:GHLSSRuntimeString("點一對就成對開（主 App 浮窗 + 另一個側窗），2 秒內開，不用 respring；最多存 3 對。") forKey:GHLSSRuntimeString("footerText")];
            [specs addObject:group];
            char *lastPair = GHLSSPrefsCString("lastThreeScreenPair");
            if (lastPair) {
                char a[128], b[128];
                if (GHLSSPrefsSplitPair(lastPair, a, sizeof(a), b, sizeof(b))) {
                    NSString *nameA = GHLSSPrefsAppNameForBundleID(a);
                    NSString *nameB = GHLSSPrefsAppNameForBundleID(b);
                    NSString *label = [[GHLSSRuntimeString("上次組合：") stringByAppendingString:nameA] stringByAppendingString:[[GHLSSRuntimeString(" + ") stringByAppendingString:nameB] stringByAppendingString:GHLSSRuntimeString("（點一下成對開）")]];
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
                [emptyGroup setProperty:GHLSSRuntimeString("還沒有上次的三屏組合（開一次三屏就有了）。") forKey:GHLSSRuntimeString("footerText")];
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
                    NSString *label = [[[[GHLSSRuntimeString("組合 ") stringByAppendingString:[NSString stringWithFormat:GHLSSRuntimeString("%d"), s]] stringByAppendingString:GHLSSRuntimeString("：")] stringByAppendingString:nameA] stringByAppendingString:[[GHLSSRuntimeString(" + ") stringByAppendingString:nameB] stringByAppendingString:GHLSSRuntimeString("（點一下成對開）")]];
                    PSSpecifier *spec = [PSSpecifier preferenceSpecifierNamed:label target:self set:nil get:nil detail:nil cell:PSButtonCell edit:nil];
                    [spec setProperty:GHLSSRuntimeString("ghlssOpenPair") forKey:GHLSSRuntimeString("action")];
                    char pairBuf[256];
                    snprintf(pairBuf, sizeof(pairBuf), "%s|%s", a, b);
                    [spec setProperty:[NSString stringWithCString:pairBuf encoding:NSUTF8StringEncoding] forKey:GHLSSRuntimeString("pairValue")];
                    [specs addObject:spec];
                    NSString *delLabel = [GHLSSRuntimeString("刪除組合 ") stringByAppendingString:[NSString stringWithFormat:GHLSSRuntimeString("%d"), s]];
                    PSSpecifier *del = [PSSpecifier preferenceSpecifierNamed:delLabel target:self set:nil get:nil detail:nil cell:PSButtonCell edit:nil];
                    [del setProperty:GHLSSRuntimeString("ghlssDeletePair") forKey:GHLSSRuntimeString("action")];
                    [del setProperty:@(s) forKey:GHLSSRuntimeString("pairSlot")];
                    [specs addObject:del];
                }
                free(pair);
            }
            PSSpecifier *save = [PSSpecifier preferenceSpecifierNamed:GHLSSRuntimeString("存目前這對（上次開過的組合）") target:self set:nil get:nil detail:nil cell:PSButtonCell edit:nil];
            [save setProperty:GHLSSRuntimeString("ghlssSaveCurrentPair") forKey:GHLSSRuntimeString("action")];
            [specs addObject:save];
            PSSpecifier *note = [PSSpecifier emptyGroupSpecifier];
            [note setProperty:GHLSSRuntimeString("設定 App 看不到現在開著的窗，這裡存的是上次開過的三屏組合；要存現在這對，請在浮窗設定卡片裡點「存目前這對」。") forKey:GHLSSRuntimeString("footerText")];
            [specs addObject:note];
            _specifiers = specs;
    
        } @catch (NSException *e) {
            const char *reason = [e reason] ? [[e reason] UTF8String] : "?";
            char buf[512];
            snprintf(buf, sizeof(buf), "v55 prefs-pairlist specifiers EXCEPTION %s", reason);
            GHLSSPrefsLogLine(buf);
            NSMutableArray *safe = [NSMutableArray array];
            PSSpecifier *group = [PSSpecifier emptyGroupSpecifier];
            [group setProperty:GHLSSRuntimeString("三屏組合頁組裝出錯（已記進日誌），先回上一頁再試。") forKey:GHLSSRuntimeString("footerText")];
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
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:GHLSSRuntimeString("已通知主插件") message:GHLSSRuntimeString("2 秒內成對開（主 App 浮窗 + 另一個側窗），不用 respring。") preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:GHLSSRuntimeString("好") style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)ghlssSaveCurrentPair:(PSSpecifier *)specifier {
    (void)specifier;
    char *lastPair = GHLSSPrefsCString("lastThreeScreenPair");
    if (!lastPair) {
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:GHLSSRuntimeString("沒有上次的組合") message:GHLSSRuntimeString("先開一次三屏，再來存。") preferredStyle:UIAlertControllerStyleAlert];
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
    NSString *msg = [[GHLSSRuntimeString("已存成組合 ") stringByAppendingString:[NSString stringWithFormat:GHLSSRuntimeString("%d"), slot]] stringByAppendingString:GHLSSRuntimeString("。")];
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:GHLSSRuntimeString("已存目前這對") message:msg preferredStyle:UIAlertControllerStyleAlert];
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
        snprintf(buf, sizeof(buf), "v55 prefs-doraemonicon: super viewDidLoad EXCEPTION %s", why);
        GHLSSPrefsLogLine(buf);
    }
    GHLSSPrefsLogLine("v55 prefs-page: DoraemonIcon");
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
        snprintf(buf, sizeof(buf), "v55 prefs-doraemonicon: viewDidLoad EXCEPTION %s", why);
        GHLSSPrefsLogLine(buf);
    }
}

- (void)viewDidAppear:(BOOL)animated {
    @try {
        [super viewDidAppear:animated];
    } @catch (NSException *e) {
        GHLSSPrefsLogLine("v55 prefs-doraemonicon: super viewDidAppear EXCEPTION");
    }
    if (self.headerView && !self.headerInstalled) {
        UITableView *tv = GHLSSSafeTableViewForController(self, "doraemonicon");
        if (tv) {
            @try {
                tv.tableHeaderView = self.headerView;
                self.headerInstalled = YES;
                GHLSSPrefsLogLine("v55 prefs-doraemonicon: header mounted");
            } @catch (NSException *e) {
                const char *why = [e reason] ? [[e reason] UTF8String] : "?";
                char buf[256];
                snprintf(buf, sizeof(buf), "v55 prefs-doraemonicon: mount EXCEPTION %s", why);
                GHLSSPrefsLogLine(buf);
            }
        } else {
            GHLSSPrefsLogLine("v55 prefs-doraemonicon: no table, header not mounted");
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
        GHLSSPrefsLogLine("v55 prefs-doraemonicon: refresh EXCEPTION");
    }
}

- (NSArray *)specifiers {
    if (!_specifiers) {
        NSMutableArray *specs = [NSMutableArray array];
        PSSpecifier *group = [PSSpecifier emptyGroupSpecifier];
        [group setProperty:GHLSSRuntimeString("上面那張圓圖是現在的悬浮图标；從相冊選一張、居中裁成方形存起來，哆啦A夢鈕 2 秒內就換成它。") forKey:GHLSSRuntimeString("footerText")];
        [specs addObject:group];
        PSSpecifier *pick = [PSSpecifier preferenceSpecifierNamed:GHLSSRuntimeString("從相冊選圖（換鈕圖片）") target:self set:nil get:nil detail:nil cell:PSButtonCell edit:nil];
        [pick setProperty:GHLSSRuntimeString("ghlssPickDoraemonIcon") forKey:GHLSSRuntimeString("action")];
        [specs addObject:pick];
        PSSpecifier *restore = [PSSpecifier preferenceSpecifierNamed:GHLSSRuntimeString("恢復默認哆啦A夢圖") target:self set:nil get:nil detail:nil cell:PSButtonCell edit:nil];
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
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:GHLSSRuntimeString("已恢復默認哆啦A夢圖") message:GHLSSRuntimeString("哆啦A夢鈕回到默認圖。") preferredStyle:UIAlertControllerStyleAlert];
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
                UIAlertController *alert = [UIAlertController alertControllerWithTitle:GHLSSRuntimeString("鈕圖片已換好") message:GHLSSRuntimeString("哆啦A夢鈕 2 秒內就換成這張。") preferredStyle:UIAlertControllerStyleAlert];
                [alert addAction:[UIAlertAction actionWithTitle:GHLSSRuntimeString("好") style:UIAlertActionStyleDefault handler:nil]];
                [self presentViewController:alert animated:YES completion:nil];
            } else {
                UIAlertController *alert = [UIAlertController alertControllerWithTitle:GHLSSRuntimeString("保存鈕圖片失敗") message:GHLSSRuntimeString("圖片寫不進設定目錄。") preferredStyle:UIAlertControllerStyleAlert];
                [alert addAction:[UIAlertAction actionWithTitle:GHLSSRuntimeString("好") style:UIAlertActionStyleDefault handler:nil]];
                [self presentViewController:alert animated:YES completion:nil];
            }
        });
    }];
}

@end

// （GHLSSPlistPageController 在文件後面定義，這裡先給完整接口聲明——
// 光是 @class 前向聲明不夠，[GHLSSPlistPageController class] 會報錯。）
@interface GHLSSPlistPageController : GuHaiLongSplitScreenRootListController
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
        snprintf(buf, sizeof(buf), "v55 prefs-nav REJECTED unknown plist detail %s", detailC ? detailC : "?");
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
    snprintf(buf, sizeof(buf), "v55 prefs-nav push plist %s", detailC ? detailC : "?");
    GHLSSPrefsLogLine(buf);
    return YES;
}

// v42：手勢總覽——一頁列出全部手勢跟目前的設定值（只讀，
// 改去調度設置／手勢自定義那頁）。
static NSString *GHLSSGestureActionName(const char *value) {
    if (!value) return GHLSSRuntimeString("未設定");
    if (strcmp(value, "pin") == 0) return GHLSSRuntimeString("釘選置頂");
    if (strcmp(value, "dock") == 0) return GHLSSRuntimeString("收起貼邊");
    if (strcmp(value, "close") == 0) return GHLSSRuntimeString("關掉");
    if (strcmp(value, "cycle") == 0) return GHLSSRuntimeString("輪切主窗");
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
        snprintf(buf, sizeof(buf), "v55 prefs-gestures viewDidLoad EXCEPTION %s", reason);
        GHLSSPrefsLogLine(buf);
    }
    GHLSSPrefsLogLine("v55 prefs-page: Gestures");
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
        snprintf(buf, sizeof(buf), "v55 prefs-gestures viewWillAppear EXCEPTION %s", reason);
        GHLSSPrefsLogLine(buf);
    }
}

- (NSArray *)specifiers {
    if (!_specifiers) {
        @try {
            NSMutableArray *specs = [NSMutableArray array];
            PSSpecifier *intro = [PSSpecifier emptyGroupSpecifier];
            [intro setProperty:GHLSSRuntimeString("全部手勢跟目前的設定值（只讀；改去調度設置／手勢自定義那頁）。") forKey:GHLSSRuntimeString("footerText")];
            [specs addObject:intro];
            // 邊緣滑動。
            {
                int count = (int)GHLSSPrefsDouble("edgeSwipeCount", 2);
                char *side = GHLSSPrefsCString("edgeSwipeSide");
                const char *sideStr = side ? side : "right";
                if (sideStr[0] == '\0') sideStr = "right";
                BOOL direct = GHLSSPrefsBool("edgeSwipeOpensThreeScreen", NO);
                char buf[256];
                snprintf(buf, sizeof(buf), "從%s邊滑 %d 次，%s", (strcmp(sideStr, "left") == 0) ? "左" : "右", count, direct ? "直接開三屏（上次組合）" : "開 ARC");
                if (side) free(side);
                PSSpecifier *g = [PSSpecifier emptyGroupSpecifier];
                [g setProperty:GHLSSRuntimeString("邊緣滑動") forKey:GHLSSRuntimeString("label")];
                [g setProperty:[NSString stringWithCString:buf encoding:NSUTF8StringEncoding] forKey:GHLSSRuntimeString("footerText")];
                [specs addObject:g];
            }
            // 哆啦A夢鈕。
            {
                double lp = GHLSSPrefsDouble("longPressDuration", 0.5);
                BOOL dbl = GHLSSPrefsBool("doraemonDoubleTapEnabled", YES);
                char buf[256];
                snprintf(buf, sizeof(buf), "單擊開 ARC；%s；長按 %.1f 秒關全部浮窗；直接拖鈕改高度。", dbl ? "雙擊輪切主窗" : "雙擊輪切已關", lp);
                PSSpecifier *g = [PSSpecifier emptyGroupSpecifier];
                [g setProperty:GHLSSRuntimeString("哆啦A夢鈕") forKey:GHLSSRuntimeString("label")];
                [g setProperty:[NSString stringWithCString:buf encoding:NSUTF8StringEncoding] forKey:GHLSSRuntimeString("footerText")];
                [specs addObject:g];
            }
            // 浮窗手勢（自定義四項）。
            {
                char *t = GHLSSPrefsCString("gestureTripleTap");
                char *v = GHLSSPrefsCString("gestureSwipeV");
                char *h = GHLSSPrefsCString("gestureSwipeH");
                char *f = GHLSSPrefsCString("gestureTwoFingerTap");
                NSMutableString *line = [NSMutableString stringWithString:GHLSSRuntimeString("三擊浮窗：")];
                [line appendString:GHLSSGestureActionName(t ? t : "pin")];
                [line appendString:GHLSSRuntimeString("；上下滑：")];
                [line appendString:GHLSSGestureActionName(v ? v : "dock")];
                [line appendString:GHLSSRuntimeString("；左右滑：")];
                [line appendString:GHLSSGestureActionName(h ? h : "close")];
                [line appendString:GHLSSRuntimeString("；雙指點：")];
                [line appendString:GHLSSGestureActionName(f ? f : "maximize")];
                if (t) free(t);
                if (v) free(v);
                if (h) free(h);
                if (f) free(f);
                PSSpecifier *g = [PSSpecifier emptyGroupSpecifier];
                [g setProperty:GHLSSRuntimeString("浮窗手勢（頂上 24pt 手柄，綁在手柄上、不是內容區）") forKey:GHLSSRuntimeString("label")];
                [g setProperty:line forKey:GHLSSRuntimeString("footerText")];
                [specs addObject:g];
            }
            // 拖窗／分隔線／點窗外。
            {
                BOOL drag = GHLSSPrefsBool("windowDragEnabled", YES);
                BOOL sideGest = GHLSSPrefsBool("sideWindowGestures", YES);
                BOOL tapOut = GHLSSPrefsBool("tapOutsideEnabled", YES);
                char *tapAction = GHLSSPrefsCString("tapOutsideAction");
                const char *tapStr = (tapAction && strcmp(tapAction, "close") == 0) ? "關掉浮窗" : "收起貼邊";
                if (tapAction) free(tapAction);
                char buf[320];
                snprintf(buf, sizeof(buf), "拖窗：%s；分隔線拖動：%s（拖到頂放大、拖到邊吸住留 8pt，放手才吸）；點窗外：%s（%s）。", drag ? "開" : "關", sideGest ? "開" : "關", tapOut ? "開" : "關", tapStr);
                PSSpecifier *g = [PSSpecifier emptyGroupSpecifier];
                [g setProperty:GHLSSRuntimeString("拖窗／分隔線／點窗外") forKey:GHLSSRuntimeString("label")];
                [g setProperty:[NSString stringWithCString:buf encoding:NSUTF8StringEncoding] forKey:GHLSSRuntimeString("footerText")];
                [specs addObject:g];
            }
            // v53：懸浮球已整個拿掉（狀態頁球區塊刪除）。
            _specifiers = specs;
    
        } @catch (NSException *e) {
            const char *reason = [e reason] ? [[e reason] UTF8String] : "?";
            char buf[512];
            snprintf(buf, sizeof(buf), "v55 prefs-gestures specifiers EXCEPTION %s", reason);
            GHLSSPrefsLogLine(buf);
            NSMutableArray *safe = [NSMutableArray array];
            PSSpecifier *group = [PSSpecifier emptyGroupSpecifier];
            [group setProperty:GHLSSRuntimeString("手勢總覽頁組裝出錯（已記進日誌），先回上一頁再試。") forKey:GHLSSRuntimeString("footerText")];
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
        snprintf(buf, sizeof(buf), "v55 prefs-profiles viewDidLoad EXCEPTION %s", reason);
        GHLSSPrefsLogLine(buf);
    }
    GHLSSPrefsLogLine("v55 prefs-page: Profiles");
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
            [group setProperty:GHLSSRuntimeString("存幾套配置，點一下整套切換（跟備份／導出是兩回事：備份是單檔，方案是多套並存）。套用後要重新啟動 SpringBoard 生效。") forKey:GHLSSRuntimeString("footerText")];
            [specs addObject:group];
            PSSpecifier *save = [PSSpecifier preferenceSpecifierNamed:GHLSSRuntimeString("把目前配置存成方案…") target:self set:nil get:nil detail:nil cell:PSButtonCell edit:nil];
            [save setProperty:GHLSSRuntimeString("ghlssSaveProfile") forKey:GHLSSRuntimeString("action")];
            [specs addObject:save];
            NSArray *names = GHLSSListProfileNames();
            if ([names count] == 0) {
                PSSpecifier *emptyGroup = [PSSpecifier emptyGroupSpecifier];
                [emptyGroup setProperty:GHLSSRuntimeString("還沒有方案（先點上面存一個，例如「日常」「遊戲」）。") forKey:GHLSSRuntimeString("footerText")];
                [specs addObject:emptyGroup];
            }
            for (NSString *name in names) {
                NSString *applyLabel = [[GHLSSRuntimeString("套用方案：") stringByAppendingString:name] stringByAppendingString:GHLSSRuntimeString("（點一下整套切換）")];
                PSSpecifier *apply = [PSSpecifier preferenceSpecifierNamed:applyLabel target:self set:nil get:nil detail:nil cell:PSButtonCell edit:nil];
                [apply setProperty:GHLSSRuntimeString("ghlssApplyProfile") forKey:GHLSSRuntimeString("action")];
                [apply setProperty:name forKey:GHLSSRuntimeString("profileName")];
                [specs addObject:apply];
                NSString *delLabel = [GHLSSRuntimeString("刪除方案：") stringByAppendingString:name];
                PSSpecifier *del = [PSSpecifier preferenceSpecifierNamed:delLabel target:self set:nil get:nil detail:nil cell:PSButtonCell edit:nil];
                [del setProperty:GHLSSRuntimeString("ghlssDeleteProfile") forKey:GHLSSRuntimeString("action")];
                [del setProperty:name forKey:GHLSSRuntimeString("profileName")];
                [specs addObject:del];
            }
            _specifiers = specs;
    
        } @catch (NSException *e) {
            const char *reason = [e reason] ? [[e reason] UTF8String] : "?";
            char buf[512];
            snprintf(buf, sizeof(buf), "v55 prefs-profiles specifiers EXCEPTION %s", reason);
            GHLSSPrefsLogLine(buf);
            NSMutableArray *safe = [NSMutableArray array];
            PSSpecifier *group = [PSSpecifier emptyGroupSpecifier];
            [group setProperty:GHLSSRuntimeString("配置方案頁組裝出錯（已記進日誌），先回上一頁再試。") forKey:GHLSSRuntimeString("footerText")];
            [safe addObject:group];
            _specifiers = safe;
        }
        if (!_specifiers) _specifiers = [NSMutableArray array];
    }
    return _specifiers;
}

- (void)ghlssSaveProfile:(PSSpecifier *)specifier {
    (void)specifier;
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:GHLSSRuntimeString("存成方案") message:GHLSSRuntimeString("給這套配置起個名字（例如：日常、遊戲）。") preferredStyle:UIAlertControllerStyleAlert];
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
            UIAlertController *noFile = [UIAlertController alertControllerWithTitle:GHLSSRuntimeString("沒有配置文件可存") message:GHLSSRuntimeString("先改一個設置，配置文件才會生成。") preferredStyle:UIAlertControllerStyleAlert];
            [noFile addAction:[UIAlertAction actionWithTitle:GHLSSRuntimeString("好") style:UIAlertActionStyleDefault handler:nil]];
            [self presentViewController:noFile animated:YES completion:nil];
            return;
        }
        NSArray *existing = GHLSSListProfileNames();
        if ([existing count] >= 5 && ![existing containsObject:name]) {
            UIAlertController *full = [UIAlertController alertControllerWithTitle:GHLSSRuntimeString("方案已滿") message:GHLSSRuntimeString("最多存 5 套方案，先刪一個再存。") preferredStyle:UIAlertControllerStyleAlert];
            [full addAction:[UIAlertAction actionWithTitle:GHLSSRuntimeString("好") style:UIAlertActionStyleDefault handler:nil]];
            [self presentViewController:full animated:YES completion:nil];
            return;
        }
        [fm removeItemAtPath:dst error:nil];
        NSError *err = nil;
        BOOL ok = [fm copyItemAtPath:src toPath:dst error:&err];
        [self reloadSpecifiers];
        NSString *title = ok ? GHLSSRuntimeString("已存成方案") : GHLSSRuntimeString("保存失敗");
        NSString *msg = ok ? [[GHLSSRuntimeString("方案「") stringByAppendingString:name] stringByAppendingString:GHLSSRuntimeString("」已存好，點它就整套切換。")] : GHLSSRuntimeString("複製配置文件時出錯。");
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
    NSString *msg = ok ? [[GHLSSRuntimeString("方案「") stringByAppendingString:name] stringByAppendingString:GHLSSRuntimeString("」已套用，請重新啟動 SpringBoard 生效。")] : GHLSSRuntimeString("複製配置文件時出錯。");
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:ok ? GHLSSRuntimeString("已套用方案") : GHLSSRuntimeString("套用失敗") message:msg preferredStyle:UIAlertControllerStyleAlert];
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
        snprintf(buf, sizeof(buf), "v55 prefs-search plistpage entry plist %s", cname ? cname : "(nil)");
        GHLSSPrefsLogLine(buf);
        if (targetPlist && [targetPlist length] > 0 && GHLSSPrefsIsKnownPlistName(cname)) {
            @try {
                _specifiers = [self loadSpecifiersFromPlistName:targetPlist target:self];
            } @catch (NSException *e) {
                char ebuf[512];
                snprintf(ebuf, sizeof(ebuf), "v55 prefs-search plistpage EXCEPTION %s %s", [[e name] UTF8String], [[e reason] UTF8String]);
                GHLSSPrefsLogLine(ebuf);
                NSMutableArray *safe = [NSMutableArray array];
                PSSpecifier *group = [PSSpecifier emptyGroupSpecifier];
                [group setProperty:GHLSSRuntimeString("這一頁打不開（已記進日誌），先回上一頁再試。") forKey:GHLSSRuntimeString("footerText")];
                [safe addObject:group];
                _specifiers = safe;
            }
            if (!_specifiers) _specifiers = [NSMutableArray array];
        } else {
            GHLSSPrefsLogLine("v55 prefs-search plistpage REJECTED unknown plist");
            NSMutableArray *safe = [NSMutableArray array];
            PSSpecifier *group = [PSSpecifier emptyGroupSpecifier];
            [group setProperty:GHLSSRuntimeString("這一頁打不開（已記進日誌），先回上一頁再試。") forKey:GHLSSRuntimeString("footerText")];
            [safe addObject:group];
            _specifiers = safe;
        }
        char buf2[128];
        snprintf(buf2, sizeof(buf2), "v55 prefs-search plistpage exit count %lu", (unsigned long)[_specifiers count]);
        GHLSSPrefsLogLine(buf2);
    }
    return _specifiers;
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
        snprintf(buf, sizeof(buf), "v55 prefs-status viewDidLoad EXCEPTION %s", reason);
        GHLSSPrefsLogLine(buf);
    }
    GHLSSPrefsLogLine("v55 prefs-page: Status");
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
    snprintf(buf, sizeof(buf), "v55 prefs-status tap: section %ld row %ld", (long)indexPath.section, (long)indexPath.row);
    GHLSSPrefsLogLine(buf);
    if (GHLSSHandlePlistDetailTap(self, tableView, indexPath)) return;
    if (GHLSSDispatchButtonTap(self, tableView, indexPath)) return;
    [super tableView:tableView didSelectRowAtIndexPath:indexPath];
}

- (NSArray *)specifiers {
    if (!_specifiers) {
        @try {
            NSMutableArray *loaded = [self loadSpecifiersFromPlistName:GHLSSRuntimeString("Status") target:self];
            for (PSSpecifier *spec in loaded) {
                NSString *k = spec.properties[GHLSSRuntimeString("key")];
                if ([k isKindOfClass:[NSString class]] && [k isEqualToString:GHLSSRuntimeString("statusEnabledState")]) {
                    BOOL on = GHLSSPrefsBool("enabled", NO);
                    NSString *txt = on ? GHLSSRuntimeString("啟用分屏開關：開（這是系統設定裡的開關狀態，不是即時載入狀態）") : GHLSSRuntimeString("啟用分屏開關：關（這是系統設定裡的開關狀態，不是即時載入狀態）");
                    [spec setProperty:txt forKey:GHLSSRuntimeString("footerText")];
                } else if ([k isKindOfClass:[NSString class]] && [k isEqualToString:GHLSSRuntimeString("statusLogTail")]) {
                    NSString *tail = GHLSSLogTailNewestFirstN(5);
                    if (!tail || [tail length] == 0) tail = GHLSSRuntimeString("還沒有日誌。");
                    [spec setProperty:tail forKey:GHLSSRuntimeString("footerText")];
                } else if ([k isKindOfClass:[NSString class]] && [k isEqualToString:GHLSSRuntimeString("statusLiveState")]) {
                    NSString *live = GHLSSReadStatusSnapshotText();
                    if (!live) live = GHLSSRuntimeString("暫無（還沒開過浮窗）。");
                    [spec setProperty:live forKey:GHLSSRuntimeString("footerText")];
                }
            }
            _specifiers = loaded;
        } @catch (NSException *e) {
            const char *reason = [e reason] ? [[e reason] UTF8String] : "?";
            char buf[512];
            snprintf(buf, sizeof(buf), "v55 prefs-status specifiers EXCEPTION %s", reason);
            GHLSSPrefsLogLine(buf);
            NSMutableArray *safe = [NSMutableArray array];
            PSSpecifier *group = [PSSpecifier emptyGroupSpecifier];
            [group setProperty:GHLSSRuntimeString("狀態頁組裝出錯（已記進日誌），先回上一頁再試。") forKey:GHLSSRuntimeString("footerText")];
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
    NSString *onOff = on ? GHLSSRuntimeString("開") : GHLSSRuntimeString("關");
    NSString *diag = [[[GHLSSRuntimeString("顧海龍集團分屏 v1.0.55\n插件開關：") stringByAppendingString:onOff] stringByAppendingString:GHLSSRuntimeString("\n最近日誌：\n")] stringByAppendingString:tail];
    [UIPasteboard generalPasteboard].string = diag;
    GHLSSPrefsLogLine("v55 prefs-status diagnostics copied");
    [self ghlssShowAlertWithTitle:GHLSSRuntimeString("已複製") message:GHLSSRuntimeString("診斷信息已複製到剪貼板。")];
}

- (void)ghlssCopyQQ:(PSSpecifier *)specifier {
    (void)specifier;
    [UIPasteboard generalPasteboard].string = GHLSSRuntimeString("2309103548");
    GHLSSPrefsLogLine("v55 prefs-status QQ copied");
    [self ghlssShowAlertWithTitle:GHLSSRuntimeString("已複製") message:GHLSSRuntimeString("QQ 2309103548 已複製到剪貼板。")];
}

- (void)ghlssCopyQQGroup:(PSSpecifier *)specifier {
    (void)specifier;
    [UIPasteboard generalPasteboard].string = GHLSSRuntimeString("1130823454");
    GHLSSPrefsLogLine("v55 prefs-status QQ group copied");
    [self ghlssShowAlertWithTitle:GHLSSRuntimeString("已複製") message:GHLSSRuntimeString("QQ交流群 1130823454 已複製到剪貼板。")];
}

- (void)ghlssOpenRepoSource:(PSSpecifier *)specifier {
    (void)specifier;
    // v54：皇上 01:20 定——改成點一下複製源地址，不再打開（打不開也閃退過，
    // 複製最穩；閃退靠派發修法，不靠這一改）。
    [UIPasteboard generalPasteboard].string = GHLSSRuntimeString("https://guhailong-repo.pages.dev");
    GHLSSPrefsLogLine("v55 prefs-status repo copied");
    [self ghlssShowAlertWithTitle:GHLSSRuntimeString("已複製") message:GHLSSRuntimeString("越獄源地址已複製到剪貼板，去 Sileo／Zebra 貼上加入。")];
}

@end
