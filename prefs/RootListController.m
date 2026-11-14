// 顾海龙集团分屏 — 设置页（PreferenceLoader）。
// v42：主頁照 FV 設定主頁的順序排（啟用／三屏／ARC／浮窗／其他雜項／
// 操作性功能五項藍色操作列）＋主頁搜索、常用開關、布局預設、配置方案、
// 手勢總覽、高級設置、新手模式；子頁是獨立 plist（浮窗／三屏／ARC／
// 其他＋調度／陰影／橫幅／鍵盤／搜索／桌面圖標／懸浮圖標／ARC 按鈕／
// 兩個排序頁＋手勢自定義／高級設置），由 PreferenceLoader 的預設控制器
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

// v42：刪掉一個 prefs 鍵，立刻落盤（每頁重置用）。
static void GHLSSDeletePrefsKey(const char *key) {
    CFStringRef domain = GHLSSRuntimeCFString("com.guhailong.splitscreen");
    CFStringRef keyRef = GHLSSRuntimeCFString(key);
    if (domain && keyRef) {
        CFPreferencesSetAppValue(keyRef, NULL, domain);
        CFPreferencesAppSynchronize(domain);
    }
    if (domain) CFRelease(domain);
    if (keyRef) CFRelease(keyRef);
}

// v42：卡片頭像／背景圖的固定檔名（設定目錄下，浮窗卡片和設定頁
// 兩邊都讀得到；頭像 GuHaiLongSplitScreen-avatar.jpg，
// 背景 GuHaiLongSplitScreen-cardbg.jpg）。
static NSString *GHLSSCardAvatarPath(void) {
    return [GHLSSPrefsDir() stringByAppendingPathComponent:GHLSSRuntimeString("GuHaiLongSplitScreen-avatar.jpg")];
}

static NSString *GHLSSCardBgPath(void) {
    return [GHLSSPrefsDir() stringByAppendingPathComponent:GHLSSRuntimeString("GuHaiLongSplitScreen-cardbg.jpg")];
}

static NSString *GHLSSLogFilePath(void) {
    return GHLSSRuntimeString("/var/mobile/Library/Logs/GuHaiLongSplitScreen.log");
}

// v42：日誌尾段（預設最後 200 行）、最新在最上面（跟浮窗卡片同一份寫法）。
static NSString *GHLSSLogTailNewestFirst(void) {
    NSString *content = [NSString stringWithContentsOfFile:GHLSSLogFilePath() encoding:NSUTF8StringEncoding error:nil];
    if (!content) return GHLSSRuntimeString("還沒有日誌（檔案不存在或讀不到）。");
    NSArray *lines = [content componentsSeparatedByString:GHLSSRuntimeString("\n")];
    NSMutableArray *last = [NSMutableArray array];
    NSInteger start = (NSInteger)[lines count] - 200;
    if (start < 0) start = 0;
    for (NSInteger i = (NSInteger)[lines count] - 1; i >= start; i--) {
        [last addObject:[lines objectAtIndex:i]];
    }
    return [last componentsJoinedByString:GHLSSRuntimeString("\n")];
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

@interface GuHaiLongSplitScreenRootListController : PSListController
@end

@implementation GuHaiLongSplitScreenRootListController

- (NSArray *)specifiers {
    if (!_specifiers) {
        NSMutableArray *loaded = [self loadSpecifiersFromPlistName:GHLSSRuntimeString("Root") target:self];
        // v42：新手模式——主頁不顯示「高級設置」那一頁（進階項都集中在那頁）；
        // 改了之後退出再進設定頁生效（specifiers 只在進頁時建一次）。
        if (GHLSSPrefsBool("noviceMode", NO)) {
            NSMutableArray *filtered = [NSMutableArray array];
            for (PSSpecifier *spec in loaded) {
                NSString *detail = spec.properties[GHLSSRuntimeString("detail")];
                if (detail && [detail isEqualToString:GHLSSRuntimeString("Advanced")]) continue;
                [filtered addObject:spec];
            }
            _specifiers = filtered;
        } else {
            _specifiers = loaded;
        }
    }
    return _specifiers;
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
    }
    if (domain) CFRelease(domain);
}

// 彈一個提示框（設定頁裡的回饋）。
- (void)ghlssShowAlertWithTitle:(NSString *)title message:(NSString *)message {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title message:message preferredStyle:UIAlertControllerStyleAlert];
    NSString *okTitle = GHLSSRuntimeString("好");
    UIAlertAction *ok = [UIAlertAction actionWithTitle:okTitle style:UIAlertActionStyleDefault handler:nil];
    [alert addAction:ok];
    [self presentViewController:alert animated:YES completion:nil];
}

// 備份配置：設定檔複製一份到備份檔。
- (void)ghlssBackupConfig:(PSSpecifier *)specifier {
    (void)specifier;
    NSFileManager *fm = [NSFileManager defaultManager];
    NSString *src = GHLSSPrefsFilePath();
    NSString *dst = GHLSSBackupFilePath();
    if (![fm fileExistsAtPath:src]) {
        [self ghlssShowAlertWithTitle:GHLSSRuntimeString("没有配置文件可备份") message:GHLSSRuntimeString("先改一个设置，配置文件才会生成。")];
        return;
    }
    NSError *err = nil;
    [fm removeItemAtPath:dst error:nil];
    BOOL ok = [fm copyItemAtPath:src toPath:dst error:&err];
    if (ok) {
        [self ghlssShowAlertWithTitle:GHLSSRuntimeString("已备份配置") message:GHLSSRuntimeString("备份在 GuHaiLongSplitScreen-backup.plist，恢复时读这个文件。")];
    } else {
        [self ghlssShowAlertWithTitle:GHLSSRuntimeString("备份失败") message:GHLSSRuntimeString("复制配置文件时出错。")];
    }
}

// 導出配置（非備份配置）：設定檔複製一份到導出檔，導入時讀它。
- (void)ghlssExportConfig:(PSSpecifier *)specifier {
    (void)specifier;
    NSFileManager *fm = [NSFileManager defaultManager];
    NSString *src = GHLSSPrefsFilePath();
    NSString *dst = GHLSSExportFilePath();
    if (![fm fileExistsAtPath:src]) {
        [self ghlssShowAlertWithTitle:GHLSSRuntimeString("没有配置文件可导出") message:GHLSSRuntimeString("先改一个设置，配置文件才会生成。")];
        return;
    }
    [fm removeItemAtPath:dst error:nil];
    NSError *err = nil;
    BOOL ok = [fm copyItemAtPath:src toPath:dst error:&err];
    if (ok) {
        [self ghlssShowAlertWithTitle:GHLSSRuntimeString("已导出配置") message:GHLSSRuntimeString("导出在 GuHaiLongSplitScreen-export.plist，导入时读这个文件。")];
    } else {
        [self ghlssShowAlertWithTitle:GHLSSRuntimeString("导出失败") message:GHLSSRuntimeString("复制配置文件时出错。")];
    }
}

// 從文件中導入配置：讀導出檔，蓋掉現在的設定檔。
- (void)ghlssImportConfig:(PSSpecifier *)specifier {
    (void)specifier;
    NSFileManager *fm = [NSFileManager defaultManager];
    NSString *src = GHLSSExportFilePath();
    NSString *dst = GHLSSPrefsFilePath();
    if (![fm fileExistsAtPath:src]) {
        [self ghlssShowAlertWithTitle:GHLSSRuntimeString("没有找到导出的配置文件") message:GHLSSRuntimeString("先点「导出配置」，再导入。")];
        return;
    }
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
        [self ghlssShowAlertWithTitle:GHLSSRuntimeString("已导入配置") message:GHLSSRuntimeString("配置已恢复，请重新启动 SpringBoard 生效。")];
    } else {
        [self ghlssShowAlertWithTitle:GHLSSRuntimeString("导入失败") message:GHLSSRuntimeString("复制配置文件时出错。")];
    }
}

// 從備份文件恢復配置：讀備份檔，蓋掉現在的設定檔。
- (void)ghlssRestoreConfig:(PSSpecifier *)specifier {
    (void)specifier;
    NSFileManager *fm = [NSFileManager defaultManager];
    NSString *src = GHLSSBackupFilePath();
    NSString *dst = GHLSSPrefsFilePath();
    if (![fm fileExistsAtPath:src]) {
        [self ghlssShowAlertWithTitle:GHLSSRuntimeString("没有找到备份文件") message:GHLSSRuntimeString("先点「备份配置」，再恢复。")];
        return;
    }
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
        [self ghlssShowAlertWithTitle:GHLSSRuntimeString("已从备份恢复配置") message:GHLSSRuntimeString("配置已恢复，请重新启动 SpringBoard 生效。")];
    } else {
        [self ghlssShowAlertWithTitle:GHLSSRuntimeString("恢复失败") message:GHLSSRuntimeString("复制配置文件时出错。")];
    }
}

// 重置為默認配置：刪掉整個設定檔（備份檔不動），全部開關回預設值。
- (void)ghlssResetConfig:(PSSpecifier *)specifier {
    (void)specifier;
    NSFileManager *fm = [NSFileManager defaultManager];
    NSString *dst = GHLSSPrefsFilePath();
    NSError *err = nil;
    BOOL removed = YES;
    if ([fm fileExistsAtPath:dst]) {
        removed = [fm removeItemAtPath:dst error:&err];
    }
    CFStringRef domain = GHLSSRuntimeCFString("com.guhailong.splitscreen");
    if (domain) {
        CFPreferencesAppSynchronize(domain);
        CFRelease(domain);
    }
    [self reloadSpecifiers];
    if (removed) {
        [self ghlssShowAlertWithTitle:GHLSSRuntimeString("已重置为默认配置") message:GHLSSRuntimeString("全部设置已恢复默认（备份文件还在），请重新启动 SpringBoard 生效。")];
    } else {
        [self ghlssShowAlertWithTitle:GHLSSRuntimeString("重置失败") message:GHLSSRuntimeString("删除配置文件时出错。")];
    }
}

// v42：布局預設——點一下一次換整套設定（各預設改哪些 key，
// Root.plist 的頁腳列出來了）。改完要重新啟動 SpringBoard 才生效
//（浮窗尺寸／任務欄／懸浮球那幾項 2 秒 tick 會自己跟上）。
- (void)ghlssApplyLayoutGame:(PSSpecifier *)specifier {
    (void)specifier;
    GHLSSWritePrefsBool("gameModeEnabled", YES);
    GHLSSWritePrefsBool("arcEnabled", YES);
    GHLSSWritePrefsBool("centerOnOpen", NO);
    GHLSSWritePrefsDouble("cornerRadius", 20);
    GHLSSWritePrefsDouble("safeDistance", 20);
    GHLSSWritePrefsBool("shadowEnabled", YES);
    GHLSSWritePrefsBool("taskbarEnabled", NO);
    GHLSSWritePrefsBool("autoHideDoraemonInFullscreen", YES);
    GHLSSWritePrefsBool("demoModeEnabled", NO);
    GHLSSWritePrefsCString("windowSizePreset", "large");
    [self reloadSpecifiers];
    [self ghlssShowAlertWithTitle:GHLSSRuntimeString("已切到遊戲布局") message:GHLSSRuntimeString("遊戲模式開、ARC 開、固定中心關、圓角 20、安全距離 20、陰影開、任務欄關、全屏藏哆啦A夢鈕開、演示模式關、浮窗大。請重新啟動 SpringBoard 生效。")];
}

- (void)ghlssApplyLayoutWork:(PSSpecifier *)specifier {
    (void)specifier;
    GHLSSWritePrefsBool("gameModeEnabled", NO);
    GHLSSWritePrefsBool("centerOnOpen", YES);
    GHLSSWritePrefsDouble("cornerRadius", 35);
    GHLSSWritePrefsDouble("safeDistance", 50);
    GHLSSWritePrefsBool("taskbarEnabled", YES);
    GHLSSWritePrefsCString("windowSizePreset", "medium");
    GHLSSWritePrefsCString("sideWidthPreset", "medium");
    GHLSSWritePrefsBool("restoreWindowsAfterRespring", YES);
    [self reloadSpecifiers];
    [self ghlssShowAlertWithTitle:GHLSSRuntimeString("已切到工作布局") message:GHLSSRuntimeString("遊戲模式關、固定中心開、圓角 35、安全距離 50、任務欄開、浮窗中、側窗寬中、重啟恢復開。請重新啟動 SpringBoard 生效。")];
}

- (void)ghlssApplyLayoutDefault:(PSSpecifier *)specifier {
    (void)specifier;
    GHLSSWritePrefsBool("gameModeEnabled", NO);
    GHLSSWritePrefsBool("arcEnabled", YES);
    GHLSSWritePrefsBool("centerOnOpen", NO);
    GHLSSWritePrefsDouble("cornerRadius", 35);
    GHLSSWritePrefsDouble("safeDistance", 50);
    GHLSSWritePrefsBool("shadowEnabled", YES);
    GHLSSWritePrefsBool("taskbarEnabled", NO);
    GHLSSWritePrefsBool("autoHideDoraemonInFullscreen", YES);
    GHLSSWritePrefsBool("demoModeEnabled", NO);
    GHLSSWritePrefsCString("windowSizePreset", "medium");
    GHLSSWritePrefsCString("sideWidthPreset", "medium");
    GHLSSWritePrefsBool("restoreWindowsAfterRespring", YES);
    [self reloadSpecifiers];
    [self ghlssShowAlertWithTitle:GHLSSRuntimeString("已切到默認布局") message:GHLSSRuntimeString("全部回到預設值（遊戲模式關、ARC 開、固定中心關、圓角 35、安全距離 50、陰影開、任務欄關、全屏藏哆啦A夢鈕開、演示模式關、浮窗中、側窗寬中、重啟恢復開）。請重新啟動 SpringBoard 生效。")];
}

@end
// 開的那份清單的設定頁版，同一份 key、同一份清單，兩邊同步。
// 清單讀後台緩存檔（主插件啟動 5 秒後在後台列舉、寫檔；設定頁
// 只讀緩存，不列舉、不堵主線程）。固定 5 個永遠在最前面；
// 自選 App 的開關 key 是 sel-<bundleID>，走 GHLSSSetAppInLauncherPrefs
// 的槽位邏輯（7 個自選槽位）。
@interface GHLSSAppPickerListController : PSListController
@end

@implementation GHLSSAppPickerListController

- (NSArray *)specifiers {
    if (!_specifiers) {
        NSMutableArray *specs = [NSMutableArray array];
        // 說明組。
        PSSpecifier *group = [PSSpecifier emptyGroupSpecifier];
        NSString *footerKey = GHLSSRuntimeString("footerText");
        [group setProperty:GHLSSRuntimeString("开的 App 出现在启动器/ARC 里（最多 12 个，自选 7 个）。清单在后台列举、缓存起来；刚装的 App 可能要等一会儿才出现。") forKey:footerKey];
        [specs addObject:group];
        // 固定 5 個。
        for (int i = 0; i < 5; i++) {
            NSString *name = GHLSSRuntimeString(GHLSSFixedNames[i]);
            PSSpecifier *spec = [PSSpecifier preferenceSpecifierNamed:name target:self set:@selector(setPreferenceValue:specifier:) get:@selector(readPreferenceValue:) detail:nil cell:PSSwitchCell edit:nil];
            [spec setProperty:GHLSSRuntimeString(GHLSSFixedEnabledKeys[i]) forKey:GHLSSRuntimeString("key")];
            [spec setProperty:GHLSSRuntimeString("com.guhailong.splitscreen") forKey:GHLSSRuntimeString("defaults")];
            [spec setProperty:@(YES) forKey:GHLSSRuntimeString("default")];
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
                [specs addObject:spec];
            }
        }
        if (!anyCached) {
            PSSpecifier *emptyGroup = [PSSpecifier emptyGroupSpecifier];
            [emptyGroup setProperty:GHLSSRuntimeString("还没有已安装 App 清单（后台列举中，稍后再开这个页）。") forKey:GHLSSRuntimeString("footerText")];
            [specs addObject:emptyGroup];
        }
        _specifiers = specs;
    }
    return _specifiers;
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
@end

@implementation GHLSSLogViewerListController

- (void)viewDidLoad {
    [super viewDidLoad];
    UITextView *tv = [[UITextView alloc] initWithFrame:CGRectMake(0, 0, [UIScreen mainScreen].bounds.size.width, 420)];
    tv.font = [UIFont systemFontOfSize:11];
    tv.editable = NO;
    tv.backgroundColor = [UIColor colorWithWhite:0.95 alpha:1.0];
    tv.text = GHLSSLogTailNewestFirst();
    self.logView = tv;
    self.tableView.tableHeaderView = tv;
}

- (NSArray *)specifiers {
    if (!_specifiers) {
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
    }
    return _specifiers;
}

- (void)ghlssLogRefresh:(PSSpecifier *)specifier {
    (void)specifier;
    if (self.logView) self.logView.text = GHLSSLogTailNewestFirst();
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

- (NSArray *)specifiers {
    if (!_specifiers) {
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

// v42：卡片頭像設置——相冊選圖（PHPicker，不用相冊權限）、
// 居中裁方形 512、存設定目錄固定檔名、寫 cardAvatarCustom 鍵；
// 恢復默認刪檔＋清鍵，浮窗卡片下次開就回默認龍頭。
@interface GHLSSCardAvatarListController : PSListController <PHPickerViewControllerDelegate>
@property (nonatomic, strong) UIImageView *previewView;
@end

@implementation GHLSSCardAvatarListController

- (void)viewDidLoad {
    [super viewDidLoad];
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
    self.tableView.tableHeaderView = container;
    [self ghlssRefreshAvatarPreview];
}

- (void)ghlssRefreshAvatarPreview {
    UIImage *img = [UIImage imageWithContentsOfFile:GHLSSCardAvatarPath()];
    if (!img) {
        NSBundle *bundle = [NSBundle bundleForClass:[self class]];
        NSString *path = [bundle pathForResource:GHLSSRuntimeString("icon") ofType:GHLSSRuntimeString("png")];
        if (path) img = [UIImage imageWithContentsOfFile:path];
    }
    self.previewView.image = img;
}

- (NSArray *)specifiers {
    if (!_specifiers) {
        NSMutableArray *specs = [NSMutableArray array];
        PSSpecifier *group = [PSSpecifier emptyGroupSpecifier];
        [group setProperty:GHLSSRuntimeString("點頭像上面那張圖是現在的卡片頭像；從相冊選一張、居中裁成方形存起來，浮窗設定卡片頂上就換成它。") forKey:GHLSSRuntimeString("footerText")];
        [specs addObject:group];
        PSSpecifier *pick = [PSSpecifier preferenceSpecifierNamed:GHLSSRuntimeString("從相冊選圖（換頭像）") target:self set:nil get:nil detail:nil cell:PSButtonCell edit:nil];
        [pick setProperty:GHLSSRuntimeString("ghlssPickAvatar") forKey:GHLSSRuntimeString("action")];
        [specs addObject:pick];
        PSSpecifier *restore = [PSSpecifier preferenceSpecifierNamed:GHLSSRuntimeString("恢復默認龍頭") target:self set:nil get:nil detail:nil cell:PSButtonCell edit:nil];
        [restore setProperty:GHLSSRuntimeString("ghlssRestoreAvatar") forKey:GHLSSRuntimeString("action")];
        [specs addObject:restore];
        _specifiers = specs;
    }
    return _specifiers;
}

- (void)ghlssPickAvatar:(PSSpecifier *)specifier {
    (void)specifier;
    PHPickerConfiguration *config = [[PHPickerConfiguration alloc] init];
    config.filter = [PHPickerFilter imagesFilter];
    config.selectionLimit = 1;
    PHPickerViewController *picker = [[PHPickerViewController alloc] initWithConfiguration:config];
    picker.delegate = self;
    [self presentViewController:picker animated:YES completion:nil];
}

- (void)ghlssRestoreAvatar:(PSSpecifier *)specifier {
    (void)specifier;
    [[NSFileManager defaultManager] removeItemAtPath:GHLSSCardAvatarPath() error:nil];
    GHLSSWritePrefsBool("cardAvatarCustom", NO);
    [self ghlssRefreshAvatarPreview];
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:GHLSSRuntimeString("已恢復默認龍頭") message:GHLSSRuntimeString("浮窗設定卡片頂上回到默認龍頭圖。") preferredStyle:UIAlertControllerStyleAlert];
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
            BOOL ok = data && [data writeToFile:GHLSSCardAvatarPath() atomically:YES];
            if (ok) {
                GHLSSWritePrefsBool("cardAvatarCustom", YES);
                [self ghlssRefreshAvatarPreview];
                UIAlertController *alert = [UIAlertController alertControllerWithTitle:GHLSSRuntimeString("頭像已換好") message:GHLSSRuntimeString("浮窗設定卡片頂上就是這張。") preferredStyle:UIAlertControllerStyleAlert];
                [alert addAction:[UIAlertAction actionWithTitle:GHLSSRuntimeString("好") style:UIAlertActionStyleDefault handler:nil]];
                [self presentViewController:alert animated:YES completion:nil];
            } else {
                UIAlertController *alert = [UIAlertController alertControllerWithTitle:GHLSSRuntimeString("保存頭像失敗") message:GHLSSRuntimeString("圖片寫不進設定目錄。") preferredStyle:UIAlertControllerStyleAlert];
                [alert addAction:[UIAlertAction actionWithTitle:GHLSSRuntimeString("好") style:UIAlertActionStyleDefault handler:nil]];
                [self presentViewController:alert animated:YES completion:nil];
            }
        });
    }];
}

@end

// v42：卡片背景圖——相冊選圖（PHPicker）、最長邊縮到 1024、
// 存設定目錄固定檔名、寫 cardBgCustom 鍵；恢復默認刪檔＋清鍵，
// 卡片回到默認白卡（背景圖上面罩半透明白，字才看得清）。
@interface GHLSSCardBgListController : PSListController <PHPickerViewControllerDelegate>
@property (nonatomic, strong) UIImageView *previewView;
@end

@implementation GHLSSCardBgListController

- (void)viewDidLoad {
    [super viewDidLoad];
    CGFloat w = [UIScreen mainScreen].bounds.size.width;
    UIView *container = [[UIView alloc] initWithFrame:CGRectMake(0, 0, w, 200)];
    container.backgroundColor = [UIColor whiteColor];
    UIImageView *iv = [[UIImageView alloc] initWithFrame:CGRectMake(0, 10, w, 180)];
    iv.contentMode = UIViewContentModeScaleAspectFill;
    iv.clipsToBounds = YES;
    iv.backgroundColor = [UIColor whiteColor];
    [container addSubview:iv];
    self.previewView = iv;
    self.tableView.tableHeaderView = container;
    [self ghlssRefreshBgPreview];
}

- (void)ghlssRefreshBgPreview {
    UIImage *img = [UIImage imageWithContentsOfFile:GHLSSCardBgPath()];
    self.previewView.image = img;
}

- (NSArray *)specifiers {
    if (!_specifiers) {
        NSMutableArray *specs = [NSMutableArray array];
        PSSpecifier *group = [PSSpecifier emptyGroupSpecifier];
        [group setProperty:GHLSSRuntimeString("上面那張是現在的卡片背景（空白 = 默認白卡）；從相冊選一張存起來，卡片上就用它，上面罩一層半透明白、字才看得清。") forKey:GHLSSRuntimeString("footerText")];
        [specs addObject:group];
        PSSpecifier *pick = [PSSpecifier preferenceSpecifierNamed:GHLSSRuntimeString("從相冊選圖（換背景圖）") target:self set:nil get:nil detail:nil cell:PSButtonCell edit:nil];
        [pick setProperty:GHLSSRuntimeString("ghlssPickBg") forKey:GHLSSRuntimeString("action")];
        [specs addObject:pick];
        PSSpecifier *restore = [PSSpecifier preferenceSpecifierNamed:GHLSSRuntimeString("恢復默認白卡") target:self set:nil get:nil detail:nil cell:PSButtonCell edit:nil];
        [restore setProperty:GHLSSRuntimeString("ghlssRestoreBg") forKey:GHLSSRuntimeString("action")];
        [specs addObject:restore];
        _specifiers = specs;
    }
    return _specifiers;
}

- (void)ghlssPickBg:(PSSpecifier *)specifier {
    (void)specifier;
    PHPickerConfiguration *config = [[PHPickerConfiguration alloc] init];
    config.filter = [PHPickerFilter imagesFilter];
    config.selectionLimit = 1;
    PHPickerViewController *picker = [[PHPickerViewController alloc] initWithConfiguration:config];
    picker.delegate = self;
    [self presentViewController:picker animated:YES completion:nil];
}

- (void)ghlssRestoreBg:(PSSpecifier *)specifier {
    (void)specifier;
    [[NSFileManager defaultManager] removeItemAtPath:GHLSSCardBgPath() error:nil];
    GHLSSWritePrefsBool("cardBgCustom", NO);
    [self ghlssRefreshBgPreview];
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
                [self ghlssRefreshBgPreview];
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

@end

// v42：設定搜索——主頁頂上的搜索框，點進來是這一頁：打字即篩
// 全部設定項（標題 + 副標題），點結果跳到那一頁（只跳頁，不跳到
// 那一行）。索引是靜態對照表，不是全文搜索——plist 裡沒寫的說明
// 文字搜不到。
// （GHLSSPlistPageController 在文件後面定義，這裡先給完整接口聲明——
// 光是 @class 前向聲明不夠，[GHLSSPlistPageController class] 會報錯。）
@interface GHLSSPlistPageController : GuHaiLongSplitScreenRootListController
@end
typedef struct {
    const char *title;
    const char *subtitle;
    const char *plist;
} GHLSSSearchEntry;

static const GHLSSSearchEntry GHLSSSearchIndex[] = {
    {"啟用分屏", "主頁開關", "Root"},
    {"ARC總開關", "主頁開關", "Root"},
    {"遊戲模式", "主頁開關", "Root"},
    {"演示模式", "主頁開關", "Root"},
    {"安全距離", "主頁開關", "Root"},
    {"搜索設置", "搜尋全部設定項", "Root"},
    {"配置方案", "日常 遊戲 自訂名", "Root"},
    {"手勢總覽", "全部手勢跟目前設定值", "Root"},
    {"高級設置", "調度 手勢自定義 方案 日誌", "Root"},
    {"新手模式", "只顯示常用開關", "Root"},
    {"遊戲布局", "一次換整套設定", "Root"},
    {"工作布局", "一次換整套設定", "Root"},
    {"默認布局", "一次換整套設定", "Root"},
    {"備份配置", "操作性功能", "Root"},
    {"導出配置", "操作性功能", "Root"},
    {"從文件中導入配置", "操作性功能", "Root"},
    {"從備份文件恢復配置", "操作性功能", "Root"},
    {"重置為默認配置", "操作性功能", "Root"},
    {"三屏模式", "新窗默認走三屏側窗", "ThreeScreen"},
    {"選擇應用", "ARC 里點加或這里加", "ThreeScreen"},
    {"側窗寬度預設", "窄中寬", "ThreeScreen"},
    {"分隔線粗細", "8 16 24pt", "ThreeScreen"},
    {"分隔線顏色", "金色 灰色 透明", "ThreeScreen"},
    {"邊緣滑動直接開三屏", "不再開 ARC", "ThreeScreen"},
    {"側窗圓角", "跟浮窗分開調", "ThreeScreen"},
    {"側窗陰影", "跟浮窗分開調", "ThreeScreen"},
    {"三屏組合", "上次 常用 3 對", "ThreeScreen"},
    {"關三屏同時關側邊小窗", "三屏設置", "ThreeScreen"},
    {"三屏小窗顯示位置", "左 右", "ThreeScreen"},
    {"arc總開關", "ARC", "ARC"},
    {"截圖錄屏隱藏 Arc", "錄屏藏 截圖藏不了", "ARC"},
    {"arc震動反饋", "ARC", "ARC"},
    {"arc觸控音效", "ARC", "ARC"},
    {"arc菜單 app打開方式", "全屏 浮窗 三屏", "ARC"},
    {"arc 與屏幕邊緣距離", "ARC", "ARC"},
    {"手勢區域設置", "調度", "ARC"},
    {"浮窗大小預設", "小中大", "Floating"},
    {"底部任務欄", "開著的窗都在上面", "Floating"},
    {"浮窗透明度", "每窗在控制條調", "Floating"},
    {"浮窗圓角", "浮窗設置", "Floating"},
    {"與劉海方向安全距離", "浮窗設置", "Floating"},
    {"豎屏浮窗打開固定屏中心", "跟記住位置互斥", "Floating"},
    {"浮窗陰影設置", "浮窗設置", "Floating"},
    {"通知橫幅設置", "浮窗設置", "Floating"},
    {"浮窗鍵盤設置", "鍵盤彈出上移", "Floating"},
    {"調度窗口設置", "手勢 長按", "Floating"},
    {"點擊浮窗外部事件", "浮窗設置", "Floating"},
    {"查看日誌", "分屏日誌最新在上", "Other"},
    {"卡片頭像設置", "相冊選圖", "Other"},
    {"卡片背景圖", "相冊選圖", "Other"},
    {"懸浮球", "點一下開 ARC", "Other"},
    {"全屏時哆啦A夢鈕自動藏", "探針", "Other"},
    {"開啟相機權限", "只存偏好", "Other"},
    {"邊緣滑動幾次開 ARC", "一次 兩次", "Scheduler"},
    {"邊緣滑動從哪邊", "左 右", "Scheduler"},
    {"手勢自定義", "三擊 滑動 雙指", "Scheduler"},
    {"浮窗拖動", "調度", "Scheduler"},
    {"側邊小窗手勢", "調度", "Scheduler"},
    {"哆啦A夢双击轮切", "調度", "Scheduler"},
    {"長按多久關全部浮窗", "0.3 1.0 秒", "Scheduler"},
    {"三擊浮窗", "釘選 收起 關掉 輪切 放大", "GestureCustom"},
    {"浮窗上下滑", "手勢自定義", "GestureCustom"},
    {"浮窗左右滑", "手勢自定義", "GestureCustom"},
    {"雙指點浮窗", "手勢自定義", "GestureCustom"},
    {"哆啦A夢鈕大小", "44 72", "FloatingIcon"},
    {"哆啦A夢鈕在哪邊", "左 右", "FloatingIcon"},
    {"顯示哆啦A夢鈕", "懸浮圖標", "FloatingIcon"},
    {"浮窗陰影", "陰影設置", "Shadow"},
    {"通知橫幅", "橫幅設置", "Banner"},
    {"ARC 搜索", "搜索界面設置", "Search"},
    {"桌面圖標", "桌面圖標設置", "DesktopIcons"},
    {"ARC 圖標大小", "ARC 按鈕設置", "ARCButtons"},
};
static const int GHLSSSearchIndexCount = (int)(sizeof(GHLSSSearchIndex) / sizeof(GHLSSSearchIndex[0]));

@interface GHLSSSettingsSearchController : PSListController <UISearchBarDelegate>
@property (nonatomic, strong) UISearchBar *searchBar;
@property (nonatomic, strong) NSString *query;
@end

@implementation GHLSSSettingsSearchController

- (void)viewDidLoad {
    [super viewDidLoad];
    UISearchBar *bar = [[UISearchBar alloc] initWithFrame:CGRectMake(0, 0, [UIScreen mainScreen].bounds.size.width, 44)];
    bar.placeholder = GHLSSRuntimeString("搜尋設定（標題 + 副標題）");
    bar.delegate = self;
    self.searchBar = bar;
    self.query = GHLSSRuntimeString("");
    self.tableView.tableHeaderView = bar;
}

- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText {
    (void)searchBar;
    self.query = searchText ? searchText : GHLSSRuntimeString("");
    [self reloadSpecifiers];
}

- (NSArray *)specifiers {
    if (!_specifiers) {
        NSMutableArray *specs = [NSMutableArray array];
        PSSpecifier *group = [PSSpecifier emptyGroupSpecifier];
        [group setProperty:GHLSSRuntimeString("打字篩全部設定項（標題 + 副標題），點結果跳到那一頁（只跳頁，不跳到那一行）；索引是靜態對照表，不是全文搜索——plist 裡沒寫的說明文字搜不到。") forKey:GHLSSRuntimeString("footerText")];
        [specs addObject:group];
        NSString *q = self.query;
        for (int i = 0; i < GHLSSSearchIndexCount; i++) {
            NSString *title = GHLSSRuntimeString(GHLSSSearchIndex[i].title);
            NSString *subtitle = GHLSSRuntimeString(GHLSSSearchIndex[i].subtitle);
            if (q && [q length] > 0) {
                BOOL inTitle = ([title rangeOfString:q options:NSCaseInsensitiveSearch].location != NSNotFound);
                BOOL inSubtitle = ([subtitle rangeOfString:q options:NSCaseInsensitiveSearch].location != NSNotFound);
                if (!inTitle && !inSubtitle) continue;
            }
            PSSpecifier *spec = [PSSpecifier preferenceSpecifierNamed:title target:self set:nil get:nil detail:[GHLSSPlistPageController class] cell:PSLinkCell edit:nil];
            [spec setProperty:GHLSSRuntimeString(GHLSSSearchIndex[i].plist) forKey:GHLSSRuntimeString("plistName")];
            [specs addObject:spec];
        }
        if ([specs count] == 1) {
            PSSpecifier *emptyGroup = [PSSpecifier emptyGroupSpecifier];
            [emptyGroup setProperty:GHLSSRuntimeString("沒有符合的設定項，換個關鍵字試試。") forKey:GHLSSRuntimeString("footerText")];
            [specs addObject:emptyGroup];
        }
        _specifiers = specs;
    }
    return _specifiers;
}

@end

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

- (NSArray *)specifiers {
    if (!_specifiers) {
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
        // 懸浮球。
        {
            BOOL ball = GHLSSPrefsBool("floatBallEnabled", NO);
            PSSpecifier *g = [PSSpecifier emptyGroupSpecifier];
            [g setProperty:GHLSSRuntimeString("懸浮球") forKey:GHLSSRuntimeString("label")];
            [g setProperty:ball ? GHLSSRuntimeString("開著：點一下開 ARC，拖到哪就記住哪。") : GHLSSRuntimeString("關著（預設關，哆啦A夢鈕仍是默認觸發）。") forKey:GHLSSRuntimeString("footerText")];
            [specs addObject:g];
        }
        _specifiers = specs;
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

- (NSArray *)specifiers {
    if (!_specifiers) {
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

// v42：每頁重置——plist 裡的重置行（PSLinkCell，detail 是這個類，
// pageKeys 是那一頁的 key 清單）點進來是這一頁；點按鈕只刪那一頁
// 的 key，不動別頁。
@interface GHLSSPageResetController : PSListController
@end

@implementation GHLSSPageResetController

- (NSArray *)specifiers {
    if (!_specifiers) {
        NSMutableArray *specs = [NSMutableArray array];
        NSArray *keys = self.specifier.properties[GHLSSRuntimeString("pageKeys")];
        NSUInteger count = keys ? [keys count] : 0;
        PSSpecifier *group = [PSSpecifier emptyGroupSpecifier];
        NSString *footer = [[GHLSSRuntimeString("只重置這一頁的 ") stringByAppendingString:[NSString stringWithFormat:GHLSSRuntimeString("%lu"), (unsigned long)count]] stringByAppendingString:GHLSSRuntimeString(" 個設置，不動別頁；重置後要重新啟動 SpringBoard 才生效。")];
        [group setProperty:footer forKey:GHLSSRuntimeString("footerText")];
        [specs addObject:group];
        PSSpecifier *reset = [PSSpecifier preferenceSpecifierNamed:GHLSSRuntimeString("重置本頁為默認") target:self set:nil get:nil detail:nil cell:PSButtonCell edit:nil];
        [reset setProperty:GHLSSRuntimeString("ghlssResetThisPage") forKey:GHLSSRuntimeString("action")];
        [specs addObject:reset];
        _specifiers = specs;
    }
    return _specifiers;
}

- (void)ghlssResetThisPage:(PSSpecifier *)specifier {
    (void)specifier;
    NSArray *keys = self.specifier.properties[GHLSSRuntimeString("pageKeys")];
    if (keys) {
        for (NSString *k in keys) {
            if (![k isKindOfClass:[NSString class]]) continue;
            GHLSSDeletePrefsKey([k UTF8String]);
        }
    }
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:GHLSSRuntimeString("已重置本頁為默認") message:GHLSSRuntimeString("這一頁的設置已恢復預設值（別頁不動），請重新啟動 SpringBoard 生效。") preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:GHLSSRuntimeString("好") style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

@end

// v42：任意 plist 頁——搜索結果點進來的頁：按 specifier 上的
// plistName 載入那份 plist。繼承主頁控制器，所以備份／導出／
// 導入／恢復／重置／布局預設那些按鈕動作在這裡也一樣能用。
// （接口聲明在文件前面搜索控制器之前，這裡只寫實作。）
@implementation GHLSSPlistPageController

- (NSArray *)specifiers {
    if (!_specifiers) {
        NSString *plistName = self.specifier.properties[GHLSSRuntimeString("plistName")];
        if (plistName && [plistName length] > 0) {
            _specifiers = [self loadSpecifiersFromPlistName:plistName target:self];
        } else {
            _specifiers = [NSMutableArray array];
        }
    }
    return _specifiers;
}

@end
