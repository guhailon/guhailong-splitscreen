// 顾海龙集团分屏 — 设置页（PreferenceLoader）。
// v43.30：主頁順序＝版本頭／激活／常用開關／歌词墙／启动器设置／
// 浮窗设置／其他功能／配置管理（含檢查更新）／狀態；
// 遊戲模式整套已刪（v43.30，皇上 2026-11-22 定）；激活是獨立頁
// （Activation.plist，兩張卡：激活／狀態）。子頁是獨立 plist（浮窗／ARC／其他＋調度／陰影／
// 橫幅／鍵盤／搜索／桌面圖標／懸浮圖標／ARC 按鈕＋手勢自定義／
// 狀態頁），由 PreferenceLoader 的預設控制器
// 載入；「加入 App」是動態頁（GHLSSAppPickerListController，下面），
// 按後台緩存的已安裝 App 清單即時建開關；日誌查看器、卡片頭像、搜索、
// 每頁重置也都是動態頁（下面）。
//
// 注意（2026-11-12）：这个文件以前用写死字串和 CFSTR，设置一打开
// 就闪退——和 SpringBoard 那边一样，咱们这套工具链编出来的写死
// 字串是坏的。所以这里一个写死的字串都不能用：名字、路径、键名
// 全在运行时现做（CFStringCreateWithCString / stringWithCString），
// 读写开关直接用 CFPreferences（v13 证实过这条路是通的）。
// v41：備份／導出／導入／恢復是真的做檔案（設定目錄裡的固定檔案），
// 不是擺設；v43.8 起備份／導出改從 live 設定現取值建檔（重置已刪）。
// v42：卡片頭像／背景圖用 PHPicker 選圖（iOS 14+，不用相冊權限）。
#import <Preferences/PSListController.h>
#import <Preferences/PSSpecifier.h>
#import <Preferences/PSTableCell.h>
#import <UIKit/UIKit.h>
#import <PhotosUI/PhotosUI.h>
#import <WebKit/WebKit.h>
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>
#import <objc/message.h>
#import <notify.h>
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

static NSString *GHLSSBackupFilePath(void) {
    return [GHLSSPrefsDir() stringByAppendingPathComponent:GHLSSRuntimeString("顾海龙分屏备份.plist")];
}

// v43.23：第 2 件——舊備份檔名（改名前備份寫在這裡）；恢復時新檔名找不到
// 就回頭找它，舊備份不斷檔（遷移選了「恢復時雙檔名都找」，不是只改注腳）。
static NSString *GHLSSLegacyBackupFilePath(void) {
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

// v43.28：先聲明（下面定義；激活狀態 helper 要讀字串，先用）。
static char *GHLSSPrefsCString(const char *key);

// v43.28：激活状态文字（读 dylib 写的 activationState 快取；
// authorized 已激活、locked 未激活、checkFailed 名单读不到暂不锁，
// 没值＝还没检查）。
static NSString *GHLSSPrefsActivationStatusText(void) {
    char *state = GHLSSPrefsCString("activationState");
    NSString *out;
    if (state && strcmp(state, "authorized") == 0) {
        out = GHLSSRuntimeString("您的设备已授权");
    } else if (state && strcmp(state, "locked") == 0) {
        out = GHLSSRuntimeString("未授权");
    } else if (state && strcmp(state, "checkFailed") == 0) {
        out = GHLSSRuntimeString("名单读不到，暂不锁（检查网络／名单）");
    } else {
        out = GHLSSRuntimeString("未检查（启动后异步检查）");
    }
    if (state) free(state);
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


// 先聲明（下面定義；輪播 helper 要記日誌，先用）。
static void GHLSSPrefsLogLine(const char *line);
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

// v42：圖片居中裁方形（頭像用，512px）。
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



// v42：bundleID 轉 App 名字（固定 5 個先查，找不到再查後台緩存檔；
// 還是找不到就回 bundleID 本身，不空白）。
// （固定表在下面定義，這裡先前向聲明，免得隱式聲明報錯。）
static const char *GHLSSFixedNames[5];
static int GHLSSFixedIndexForBundleID(const char *bid);


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

// v43.24：第 6 件——自選 App 串列（customAppBundleIDs，逗號分隔 bundleID），
// 開關是 sel-<bundleID>。
static BOOL GHLSSCustomAppListContainsBid(const char *bid) {
    if (!bid || bid[0] == '\0') return NO;
    char *raw = GHLSSPrefsCString("customAppBundleIDs");
    if (!raw) return NO;
    NSString *rawStr = [NSString stringWithCString:raw encoding:NSUTF8StringEncoding];
    free(raw);
    if (!rawStr || [rawStr length] == 0) return NO;
    NSArray *parts = [rawStr componentsSeparatedByString:GHLSSRuntimeString(",")];
    NSString *bidStr = [NSString stringWithCString:bid encoding:NSUTF8StringEncoding];
    return [parts containsObject:bidStr];
}
static void GHLSSSetCustomAppListBid(const char *bid, BOOL on) {
    if (!bid || bid[0] == '\0') return;
    NSMutableArray *ids = [NSMutableArray array];
    char *raw = GHLSSPrefsCString("customAppBundleIDs");
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
    GHLSSWritePrefsCString("customAppBundleIDs", [joined UTF8String]);
}

// 某個 bundleID 是不是在啟動器裡（固定 App 讀開關，預設開；
// 自選 App 看串列裡有沒有它且 sel-<bid> 開關開著）。
static BOOL GHLSSAppInLauncher(const char *bid) {
    if (!bid || bid[0] == '\0') return NO;
    int fixed = GHLSSFixedIndexForBundleID(bid);
    if (fixed >= 0) return GHLSSPrefsBool(GHLSSFixedEnabledKeys[fixed], YES);
    if (!GHLSSCustomAppListContainsBid(bid)) return NO;
    char selKey[160];
    snprintf(selKey, sizeof(selKey), "sel-%s", bid);
    return GHLSSPrefsBool(selKey, YES);
}

// 把某個 App 放進／拿出啟動器（跟主插件的 GHLSSSetAppInLauncher 同款
// 邏輯，設定頁這邊重寫一份——設定 bundle 和主插件是兩個進程，
// 調不到主插件的函數）。沒有數量上限，永遠回 YES。
static BOOL GHLSSSetAppInLauncherPrefs(const char *bid, BOOL on) {
    if (!bid || bid[0] == '\0') return NO;
    int fixed = GHLSSFixedIndexForBundleID(bid);
    if (fixed >= 0) {
        GHLSSWritePrefsBool(GHLSSFixedEnabledKeys[fixed], on);
        return YES;
    }
    GHLSSSetCustomAppListBid(bid, on);
    char selKey[160];
    snprintf(selKey, sizeof(selKey), "sel-%s", bid);
    GHLSSWritePrefsBool(selKey, on);
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

@interface GuHaiLongSplitScreenRootListController : PSListController <UIDocumentPickerDelegate>
@property (nonatomic, strong) WKWebView *ghlssInlineLyricView;
@property (nonatomic, strong) UIView *ghlssBannerContainer;
@property (nonatomic, assign) BOOL ghlssBannerInstalled;
@property (nonatomic, assign) int ghlssDocPickerKind;
@end

// v43.36：首页内嵌歌词墙改成整页 9:16 高——播放器是按整页 9:16 设计的
// （stage 高 = min(100dvh, 100vw*16/9)），480pt 头把它压扁，3D 墙只剩
// 一条、歌单也被挤得点不开。h = 宽 * 16 / 9，封顶屏幕高（皇上 iPhone 11
// 屏宽 430 → 764pt）。viewDidLoad／viewDidAppear 两处共用这一个公式。
static CGFloat GHLSSInlineLyricWallHeight(CGFloat w) {
    CGFloat h = w * 16.0 / 9.0;
    CGFloat maxH = [UIScreen mainScreen].bounds.size.height;
    if (h > maxH) h = maxH;
    return h;
}

@implementation GuHaiLongSplitScreenRootListController

// v43：記進了哪一頁（PlistPage 繼承這裡，類名是 GHLSSPlistPageController，
// 具體哪份 plist 由 specifiers 裡的 plistpage entry 行給出）。
- (void)viewDidLoad {
    [super viewDidLoad];
    char buf[160];
    snprintf(buf, sizeof(buf), "v57 prefs-page: %s", [NSStringFromClass([self class]) UTF8String]);
    GHLSSPrefsLogLine(buf);
    // v43.30：設定主頁頂上直接嵌整个 3D 立体歌词墙播放器（整页 9:16 高的
    // WKWebView 头，跟歌词墙那栏同一份 lyricwall/index.html，不是两套
    // 播放器；触摸进墙里，不再点横幅进详情页）。只挂在設定主頁本身
    //（isMemberOfClass），子頁（GHLSSPlistPageController 繼承這裡）不掛。
    // 主页列表滚动从播放器下面开始拖；主页消失时暂停内嵌播放器（见下面
    // viewWillDisappear），防主页墙与详情页墙同时出声。
    if ([self isMemberOfClass:[GuHaiLongSplitScreenRootListController class]]) {
        // v43.35：单 webview 保证——viewDidLoad 只建一次，防重复建出第二个播放器。
        if (self.ghlssInlineLyricView || self.ghlssBannerContainer) return;
        @try {
            CGFloat w = [UIScreen mainScreen].bounds.size.width;
            CGFloat h = GHLSSInlineLyricWallHeight(w);
            UIView *container = [[UIView alloc] initWithFrame:CGRectMake(0, 0, w, h)];
            // v43.35：底色跟页面 #17112b 一致，有缝也不露黑。
            container.backgroundColor = [UIColor colorWithRed:23.0/255.0 green:17.0/255.0 blue:43.0/255.0 alpha:1.0];
            container.clipsToBounds = YES;
            NSBundle *bundle = [NSBundle bundleForClass:[self class]];
            NSString *htmlPath = [bundle pathForResource:GHLSSRuntimeString("index") ofType:GHLSSRuntimeString("html") inDirectory:GHLSSRuntimeString("lyricwall")];
            WKWebView *wv = nil;
            if (htmlPath) {
                WKWebViewConfiguration *config = [[WKWebViewConfiguration alloc] init];
                wv = [[WKWebView alloc] initWithFrame:CGRectMake(0, 0, w, h) configuration:config];
                wv.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
                // v43.38（1.0.111，捏合缩放锁）：只关内嵌播放器的捏合缩放，手指一捏不再放大、
                // 缩不回去。滚动、点按、滑动手势不动。pinch 手势关掉＋maximumZoomScale 锁 1.0
                // ＋bouncesZoom 关掉，三重保险。
                wv.scrollView.pinchGestureRecognizer.enabled = NO;
                wv.scrollView.maximumZoomScale = 1.0;
                wv.scrollView.bouncesZoom = NO;
                // v43.35：同上，跟页面底色一致。
                wv.backgroundColor = [UIColor colorWithRed:23.0/255.0 green:17.0/255.0 blue:43.0/255.0 alpha:1.0];
                wv.opaque = YES;
                NSURL *fileURL = [NSURL fileURLWithPath:htmlPath];
                NSURL *dirURL = [fileURL URLByDeletingLastPathComponent];
                [wv loadFileURL:fileURL allowingReadAccessToURL:dirURL];
                [container addSubview:wv];
            } else {
                UILabel *lb = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, w, h)];
                lb.text = GHLSSRuntimeString("歌词墙文件没找到，请重装一次插件再试。");
                lb.font = [UIFont systemFontOfSize:15];
                lb.textColor = [UIColor grayColor];
                lb.textAlignment = NSTextAlignmentCenter;
                lb.numberOfLines = 0;
                lb.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
                [container addSubview:lb];
                GHLSSPrefsLogLine("v43.30 prefs-inline-lyricwall html missing");
            }
            self.ghlssInlineLyricView = wv;
            self.ghlssBannerContainer = container;
        } @catch (NSException *e) {
            GHLSSPrefsLogLine("v43.30 prefs-inline-lyricwall viewDidLoad EXCEPTION");
        }
    }
}

// v43.30：内嵌歌词墙挂载（viewDidAppear 才碰 table；只挂設定主頁本身）。
// v54：掛載前核對取到的表就是主表（dataSource 是自己才掛），寬度改這時重取。
- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    if (![self isMemberOfClass:[GuHaiLongSplitScreenRootListController class]]) return;
    if (self.ghlssBannerContainer && !self.ghlssBannerInstalled) {
        UITableView *tv = GHLSSSafeTableViewForController(self, "inline-lyricwall");
        if (tv && tv.dataSource && (id)tv.dataSource != (id)self) {
            GHLSSPrefsLogLine("v43.30 prefs-inline-lyricwall: table mismatch, header not mounted");
            return;
        }
        if (tv) {
            @try {
                CGFloat w = tv.bounds.size.width;
                if (w <= 0) w = [UIScreen mainScreen].bounds.size.width;
                CGFloat h = GHLSSInlineLyricWallHeight(w);
                self.ghlssBannerContainer.frame = CGRectMake(0, 0, w, h);
                if (self.ghlssInlineLyricView) self.ghlssInlineLyricView.frame = CGRectMake(0, 0, w, h);
                tv.tableHeaderView = self.ghlssBannerContainer;
                self.ghlssBannerInstalled = YES;
                GHLSSPrefsLogLine("v43.30 prefs-inline-lyricwall: header mounted");
            } @catch (NSException *e) {
                GHLSSPrefsLogLine("v43.30 prefs-inline-lyricwall: mount EXCEPTION");
            }
        } else {
            GHLSSPrefsLogLine("v43.30 prefs-inline-lyricwall: no table, header not mounted");
        }
    }
}

// v43.30：主页嵌了整个歌词墙（整页 9:16 高的 WKWebView 头）：离开主页时暂停内嵌
// 播放器（停声音＋停渲染），防主页墙与详情页墙同时出声；回来时只恢复
// 渲染，不自动续播（声音等用户再点播放）。
- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    if (![self isMemberOfClass:[GuHaiLongSplitScreenRootListController class]]) return;
    if (self.ghlssInlineLyricView) {
        [self.ghlssInlineLyricView evaluateJavaScript:GHLSSRuntimeString("window.ghlssResumeView && window.ghlssResumeView()") completionHandler:nil];
    }
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    if (![self isMemberOfClass:[GuHaiLongSplitScreenRootListController class]]) return;
    if (self.ghlssInlineLyricView) {
        [self.ghlssInlineLyricView evaluateJavaScript:GHLSSRuntimeString("window.ghlssPausePlayer && window.ghlssPausePlayer()") completionHandler:nil];
    }
}

// v43.35：单 webview 保证——控制器销毁时停掉内嵌播放器并释放 webview，
// 防重建控制器后旧 webview 还在后台出声（双声）。
- (void)dealloc {
    if (self.ghlssInlineLyricView) {
        [self.ghlssInlineLyricView evaluateJavaScript:GHLSSRuntimeString("window.ghlssPausePlayer && window.ghlssPausePlayer()") completionHandler:nil];
        [self.ghlssInlineLyricView removeFromSuperview];
        self.ghlssInlineLyricView = nil;
    }
    self.ghlssBannerContainer = nil;
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
        int cmp = GHLSSCompareDottedVersions([latest UTF8String], "1.0.111");
        if (cmp <= 0) {
            [strongSelf ghlssShowAlertWithTitle:GHLSSRuntimeString("已经是最新版") message:GHLSSRuntimeString("已经是最新版 1.0.111。")];
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
    // v43.28：激活码是文字行，没存过回空字串（回 @(NO) 会在输入框里显示成 0）。
    if ([key isEqualToString:GHLSSRuntimeString("activationCode")]) return GHLSSRuntimeString("");
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
        // v43.29：激活码绝不写日志——key 是 activationCode 时跳过这行
        //（值本身照常写 prefs，检查要读它；只不记日志，码不进日志文件）。
        if (![key isEqualToString:GHLSSRuntimeString("activationCode")]) {
            char buf[256];
            const char *keyC = [key UTF8String];
            const char *valC = [[value description] UTF8String];
            snprintf(buf, sizeof(buf), "v57 prefs-set: %s = %s", keyC ? keyC : "?", valC ? valC : "?");
            GHLSSPrefsLogLine(buf);
        }
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

// v43.8：从 live 的 CFPreferences 现取值建档（备份／导出共用）——
// 设定档 /var/mobile/Library/Preferences/com.guhailong.splitscreen.plist
// 在设定进程里看不到（写入都走 CFPreferencesSetAppValue，档是 cfprefsd
// 管的），旧写法复制档案永远报「没有配置文件可备份」。改成同步后用
// CFPreferencesCopyKeyList 拿全部 key、逐 key 取值组 dict 再写档；
// dict 是空的（0 个 key）才回 NO 且 count=0（没东西可备／可导）。
static BOOL GHLSSWriteLivePrefsToFile(NSString *dst, NSUInteger *outCount, unsigned long long *outBytes) {
    CFStringRef domain = GHLSSRuntimeCFString("com.guhailong.splitscreen");
    if (!domain || !dst) return NO;
    CFPreferencesAppSynchronize(domain);
    CFArrayRef keys = CFPreferencesCopyKeyList(domain, kCFPreferencesCurrentUser, kCFPreferencesAnyHost);
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    if (keys) {
        CFIndex n = CFArrayGetCount(keys);
        for (CFIndex i = 0; i < n; i++) {
            CFStringRef key = (CFStringRef)CFArrayGetValueAtIndex(keys, i);
            if (!key) continue;
            CFPropertyListRef value = CFPreferencesCopyAppValue(key, domain);
            if (value) {
                [dict setObject:(__bridge id)value forKey:(__bridge NSString *)key];
                CFRelease(value);
            }
        }
        CFRelease(keys);
    }
    CFRelease(domain);
    if ([dict count] == 0) return NO;
    [[NSFileManager defaultManager] removeItemAtPath:dst error:nil];
    BOOL ok = [dict writeToFile:dst atomically:YES];
    if (ok) {
        if (outCount) *outCount = [dict count];
        if (outBytes) {
            NSDictionary *attrs = [[NSFileManager defaultManager] attributesOfItemAtPath:dst error:nil];
            *outBytes = attrs ? [attrs fileSize] : 0;
        }
    }
    return ok;
}

// v43.10：備份／導出成功後直接把檔案遞給皇上——分享表帶檔案 URL，
// 當場存到文件／傳出去／隔空投送，不用自己去文件找。分享表關掉後
// 再彈提示寫清完整路徑（兩個 modal 不能疊著彈，分享表先開）。
- (void)ghlssShareConfigFile:(NSString *)path title:(NSString *)title what:(NSString *)what restoreRow:(NSString *)restoreRow {
    NSURL *url = [NSURL fileURLWithPath:path];
    if (!url) {
        [self ghlssShowAlertWithTitle:title message:GHLSSRuntimeString("文件路径不对，分享打不开。")];
        return;
    }
    UIActivityViewController *share = [[UIActivityViewController alloc] initWithActivityItems:[NSArray arrayWithObject:url] applicationActivities:nil];
    __weak typeof(self) weakSelf = self;
    share.completionWithItemsHandler = ^(UIActivityType activityType, BOOL completed, NSArray *returnedItems, NSError *activityError) {
        (void)activityType; (void)completed; (void)returnedItems; (void)activityError;
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;
        char msgBuf[768];
        snprintf(msgBuf, sizeof(msgBuf), "%s在 %s。刚才的分享表可以直接把文件存到文件、发出去或隔空投送，不用自己去文件找。想换配置时，点「%s」挑这个文件就能用。", [what UTF8String], [path UTF8String], [restoreRow UTF8String]);
        [strongSelf ghlssShowAlertWithTitle:title message:GHLSSRuntimeString(msgBuf)];
    };
    @try {
        [self presentViewController:share animated:YES completion:nil];
    } @catch (NSException *e) {
        const char *reason = [e reason] ? [[e reason] UTF8String] : "?";
        char buf[256];
        snprintf(buf, sizeof(buf), "v43.10 prefs-config share EXCEPTION %s", reason);
        GHLSSPrefsLogLine(buf);
        char msgBuf[768];
        snprintf(msgBuf, sizeof(msgBuf), "分享表打不开，文件在 %s，自己去文件找。", [path UTF8String]);
        [self ghlssShowAlertWithTitle:title message:GHLSSRuntimeString(msgBuf)];
    }
}

// 備份配置：live 設定現取值寫一份到備份檔（v43.8）。
- (void)ghlssBackupConfig:(PSSpecifier *)specifier {
    (void)specifier;
    GHLSSPrefsLogLine("v57 prefs-config backup entry");
    NSString *dst = GHLSSBackupFilePath();
    NSUInteger count = 0;
    unsigned long long bytes = 0;
    BOOL ok = GHLSSWriteLivePrefsToFile(dst, &count, &bytes);
    if (count == 0) {
        GHLSSPrefsLogLine("v57 prefs-config backup: no keys in live prefs");
        [self ghlssShowAlertWithTitle:GHLSSRuntimeString("没有配置文件可备份") message:GHLSSRuntimeString("先改一个设置，配置文件才会生成。")];
        return;
    }
    if (ok) {
        char buf[512];
        snprintf(buf, sizeof(buf), "v57 prefs-config backup: wrote %lu keys, %llu bytes to %s", (unsigned long)count, bytes, [dst UTF8String]);
        GHLSSPrefsLogLine(buf);
        // v43.10：成功後直接把檔案遞給皇上（分享表），不用自己去文件找。
        [self ghlssShareConfigFile:dst title:GHLSSRuntimeString("已备份配置") what:GHLSSRuntimeString("备份") restoreRow:GHLSSRuntimeString("从备份恢复")];
    } else {
        GHLSSPrefsLogLine("v57 prefs-config backup: write failed");
        [self ghlssShowAlertWithTitle:GHLSSRuntimeString("备份失败") message:GHLSSRuntimeString("复制配置文件时出错。")];
    }
}


// 導出配置（非備份配置）：live 設定現取值寫一份到導出檔，導入時讀它（v43.8）。
- (void)ghlssExportConfig:(PSSpecifier *)specifier {
    (void)specifier;
    GHLSSPrefsLogLine("v57 prefs-config export entry");
    NSString *dst = GHLSSExportFilePath();
    NSUInteger count = 0;
    unsigned long long bytes = 0;
    BOOL ok = GHLSSWriteLivePrefsToFile(dst, &count, &bytes);
    if (count == 0) {
        GHLSSPrefsLogLine("v57 prefs-config export: no keys in live prefs");
        [self ghlssShowAlertWithTitle:GHLSSRuntimeString("没有配置文件可导出") message:GHLSSRuntimeString("先改一个设置，配置文件才会生成。")];
        return;
    }
    if (ok) {
        char buf[512];
        snprintf(buf, sizeof(buf), "v57 prefs-config export: wrote %lu keys, %llu bytes to %s", (unsigned long)count, bytes, [dst UTF8String]);
        GHLSSPrefsLogLine(buf);
        // v43.10：成功後直接把檔案遞給皇上（分享表），不用自己去文件找。
        [self ghlssShareConfigFile:dst title:GHLSSRuntimeString("已导出配置") what:GHLSSRuntimeString("导出") restoreRow:GHLSSRuntimeString("导入配置文件")];
    } else {
        GHLSSPrefsLogLine("v57 prefs-config export: write failed");
        [self ghlssShowAlertWithTitle:GHLSSRuntimeString("导出失败") message:GHLSSRuntimeString("复制配置文件时出错。")];
    }
}

// v43.10：恢復／導入共用——把字典逐鍵寫進 live prefs（走 CFPreferences，
// cfprefsd 快取才更新；直接換檔看著像沒反應，v43 教訓）。
- (void)ghlssApplyConfigDict:(NSDictionary *)dict sourceDescription:(NSString *)src title:(NSString *)title {
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
    snprintf(buf, sizeof(buf), "v43.10 prefs-config apply: applied %lu keys from %s", (unsigned long)[dict count], [src UTF8String]);
    GHLSSPrefsLogLine(buf);
    [self ghlssShowAlertWithTitle:title message:GHLSSRuntimeString("配置已恢复，请重新启动 SpringBoard 生效。")];
}

// v43.10：文件挑選器——恢復／導入讓皇上自己挑配置文件（想換成別的
// 配置也能用，不只限於原來那一個固定備份檔）。用 initForOpeningContentTypes:
// asCopy:YES（等於舊 Import 模式：系統把挑中的檔拷一份進容器再給我們讀，
// 不用管 security-scoped resource；舊 initWithDocumentTypes:inMode: 在
// iOS 14 起已棄用，-Werror 會直接報錯）。彈不出來就走舊固定路徑
//（見下面兩個 FromFixedPath）。
- (void)ghlssPresentDocPickerForKind:(int)kind {
    self.ghlssDocPickerKind = kind;
    @try {
        UTType *plistType = [UTType typeWithIdentifier:GHLSSRuntimeString("com.apple.property-list")];
        NSArray *types = [NSArray arrayWithObjects:plistType, nil];
        UIDocumentPickerViewController *picker = [[UIDocumentPickerViewController alloc] initForOpeningContentTypes:types asCopy:YES];
        picker.delegate = self;
        [self presentViewController:picker animated:YES completion:nil];
    } @catch (NSException *e) {
        const char *reason = [e reason] ? [[e reason] UTF8String] : "?";
        char buf[256];
        snprintf(buf, sizeof(buf), "v43.10 prefs-config docpicker EXCEPTION %s, fixed-path fallback", reason);
        GHLSSPrefsLogLine(buf);
        if (kind == 0) [self ghlssRestoreConfigFromFixedPath];
        else [self ghlssImportConfigFromFixedPath];
    }
}

- (void)documentPicker:(UIDocumentPickerViewController *)controller didPickDocumentsAtURLs:(NSArray<NSURL *> *)urls {
    (void)controller;
    NSURL *url = ([urls count] > 0) ? [urls objectAtIndex:0] : nil;
    if (!url) {
        GHLSSPrefsLogLine("v43.10 prefs-config docpicker: no url");
        return;
    }
    NSString *path = [url path];
    NSDictionary *dict = [NSDictionary dictionaryWithContentsOfFile:path];
    if (!dict) {
        char buf[512];
        snprintf(buf, sizeof(buf), "v43.10 prefs-config docpicker: unreadable %s", [path UTF8String]);
        GHLSSPrefsLogLine(buf);
        [self ghlssShowAlertWithTitle:GHLSSRuntimeString("导入失败") message:GHLSSRuntimeString("挑的配置文件读不出来（要 .plist 配置文件）。")];
        return;
    }
    BOOL isRestore = (self.ghlssDocPickerKind == 0);
    [self ghlssApplyConfigDict:dict sourceDescription:path title:GHLSSRuntimeString(isRestore ? "已从备份恢复配置" : "已导入配置")];
}

- (void)documentPickerWasCancelled:(UIDocumentPickerViewController *)controller {
    (void)controller;
    GHLSSPrefsLogLine("v43.10 prefs-config docpicker: cancelled");
}

// 從文件中導入配置：先彈文件挑選器，讓皇上自己挑配置文件。
// v43：不再直接換檔案——直接換檔不會動 cfprefsd 的快取，reload 後開關還是舊值，
// 看著就像沒反應。改成讀出字典、逐鍵用 CFPreferencesSetAppValue 寫進去，快取才會更新。
- (void)ghlssImportConfig:(PSSpecifier *)specifier {
    (void)specifier;
    GHLSSPrefsLogLine("v57 prefs-config import entry");
    [self ghlssPresentDocPickerForKind:1];
}

// v43.10：挑選器彈不出來時的 fallback——讀固定導出檔（舊做法）。
- (void)ghlssImportConfigFromFixedPath {
    NSFileManager *fm = [NSFileManager defaultManager];
    NSString *src = GHLSSExportFilePath();
    if (![fm fileExistsAtPath:src]) {
        GHLSSPrefsLogLine("v57 prefs-config import: no export file");
        [self ghlssShowAlertWithTitle:GHLSSRuntimeString("没有找到导出的配置文件") message:GHLSSRuntimeString("先点「导出当前配置」，再导入。")];
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
    [self ghlssApplyConfigDict:dict sourceDescription:src title:GHLSSRuntimeString("已导入配置")];
}

// 從備份文件恢復配置：先彈文件挑選器，讓皇上自己挑配置文件。
// v43：同導入，改走 CFPreferences 逐鍵寫入（見上）。
- (void)ghlssRestoreConfig:(PSSpecifier *)specifier {
    (void)specifier;
    GHLSSPrefsLogLine("v57 prefs-config restore entry");
    [self ghlssPresentDocPickerForKind:0];
}

// v43.10：挑選器彈不出來時的 fallback——讀固定備份檔（舊做法）。
// v43.23：第 2 件——備份檔名改了（顾海龙分屏备份.plist），舊檔名
// （GuHaiLongSplitScreen-backup.plist）的備份恢復時也找得到：新檔沒有
// 就用舊檔，找到舊檔記一行（下次備份會寫成新檔名）。
- (void)ghlssRestoreConfigFromFixedPath {
    NSFileManager *fm = [NSFileManager defaultManager];
    NSString *src = GHLSSBackupFilePath();
    if (![fm fileExistsAtPath:src]) {
        NSString *legacy = GHLSSLegacyBackupFilePath();
        if ([fm fileExistsAtPath:legacy]) {
            GHLSSPrefsLogLine("v43.23 prefs-config restore: using legacy backup filename");
            src = legacy;
        }
    }
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
    [self ghlssApplyConfigDict:dict sourceDescription:src title:GHLSSRuntimeString("已从备份恢复配置")];
}

// v42：布局預設——點一下一次換整套設定（各預設改哪些 key，
// Root.plist 的頁腳列出來了）。改完要重新啟動 SpringBoard 才生效
//（浮窗尺寸／任務欄那幾項 2 秒 tick 會自己跟上）。
// v56：遊戲布局已取消（§141-5）。ghlssApplyLayoutGame 整段刪掉。
// v53：工作／默認布局已刪（皇上 23:29：布局只要遊戲布局就好了）。
@end
// 開的那份清單的設定頁版，同一份 key、同一份清單，兩邊同步。
// 清單讀後台緩存檔（主插件啟動 5 秒後在後台列舉、寫檔；設定頁
// 只讀緩存，不列舉、不堵主線程）。固定 5 個永遠在最前面；
// 自選 App 的開關 key 是 sel-<bundleID>，串列走 customAppBundleIDs（無上限）。
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
            [group setProperty:GHLSSRuntimeString("开的 App 出现在启动器里（数量不限）。清单在后台列举、缓存起来；刚装的 App 可能要等一会儿才出现，缺 App 时点下面「重新扫描」。") forKey:footerKey];
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
    // v43.28：激活码是文字行，没存过回空字串（回 @(NO) 会在输入框里显示成 0）。
    if ([key isEqualToString:GHLSSRuntimeString("activationCode")]) return GHLSSRuntimeString("");
    return @(NO);
}

- (void)setPreferenceValue:(id)value specifier:(PSSpecifier *)specifier {
    NSString *key = specifier.properties[GHLSSRuntimeString("key")];
    if (!key) return;
    BOOL on = [value boolValue];
    NSString *selPrefix = GHLSSRuntimeString("sel-");
    if ([key hasPrefix:selPrefix]) {
        NSString *bidStr = [key substringFromIndex:[selPrefix length]];
        GHLSSSetAppInLauncherPrefs([bidStr UTF8String], on);
        // v43.24：第 6 件——自選 App 無上限，不再彈「已滿」提示。
        char buf[320];
        snprintf(buf, sizeof(buf), "v57 prefs-set: sel %s = %d", [bidStr UTF8String], on ? 1 : 0);
        GHLSSPrefsLogLine(buf);
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


// v60：标题栏整个拿掉，「三屏工具栏排序」页跟着删（没有按钮可排了）。
// GHLSSToolbarSortListController、GHLSSToolbarSortIDs／Names 全删；
// App 排序頁 v43.24 也刪了（三屏取消）。
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

// v43：子頁要跳的 plist 白名單（15 份真實檔案；不在裡面的
// 名字一律不載，免得 loadSpecifiersFromPlistName 拿到壞名字）。
// v50：Advanced 刪了（去重）、Status 新加。
// v43.37：Trigger 新加（1.0.110 觸發設置頁，ARC／邊緣／懸浮條三套）。
static BOOL GHLSSPrefsIsKnownPlistName(const char *name) {
    if (!name || name[0] == '\0') return NO;
    static const char *known[] = {"ARC", "ARCButtons", "Activation", "Banner", "Floating", "FloatingIcon", "GestureCustom", "Info", "Keyboard", "Other", "Root", "Scheduler", "Shadow", "Status", "Trigger", "Window"};
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
    // v43.11：plist 載入的 LinkList 行用 validValues／validTitles，沒有 values 屬性
    //（鍵盤彈出方式那些行就是這麼漏網的——30.log 6 次 no values）。
    //讀不到才改讀 validValues／validTitles，讀到就推我們自己的頁。
    if (!values || [values count] == 0) {
        values = spec.properties[GHLSSRuntimeString("validValues")];
        titles = spec.properties[GHLSSRuntimeString("validTitles")];
    }
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
// 根因（皇上 2026-11-14 19:29 報：系統設定裡點「ARC设置」進去什麼都
// 沒有，主頁本身正常）：Root.plist 裡四個子頁連結行
// （arc 設置 detail=ARC、浮窗設置
// detail=Floating、其他雜項功能 detail=Other、高級設置 detail=Advanced）
// 的 detail 是 plist 名、沒有 action，點按走到框架預設的處理——它 new
// 一個原生的 PSListController 來載那份 plist，但那個原生控制器的 bundle
// 不是我們這個 PreferenceLoader bundle（我們 bundle 裡的 plist 它找不
// 到），specifiers 載出來是空的：頁面推得出來，裡面一行都沒有。類名
// detail 的行不受影響（框架直接 alloc 那個類，類在我們二進制裡，
// specifiers 由類自己載），所以類名 detail 的行都正常，
// 主頁（我們自己的控制器自己載 Root.plist）也正常。PreferenceLoader
// 登記檔裡根控制器就是用類名登記的（isController），也是同一道理。
// 修法：連結行點按時先在這裡攔下來——detail 是白名單裡的 plist 名，就
// 手動推一個 GHLSSPlistPageController：把 plist 名寫進 specifier 的非保留字鍵
// ghlssTargetPlist，再 push。PlistPage 的 specifiers 是在我們自己的
// 子類身上載 plist（bundle 對得上），內容就出來了。detail 是類名、
// 或不在白名單裡的，一律回 NO 交回框架／super，不動它。
// PlistPage 繼承主頁控制器（同一個 didSelectRow），所以子頁裡的嵌套
// plist 連結（浮窗設置裡的陰影／橫幅／鍵盤／調度、其他雜項裡的
// 桌面圖標／懸浮圖標、ARC／高級設置裡的調度／手勢自定義）走同
// 一個攔截，一次全修；類名 detail 的嵌套行（排序頁、加入 App、
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

// v42：任意 plist 頁——搜索結果點進來的頁：按 specifier 上的
// plistName 載入那份 plist。繼承主頁控制器，所以備份／導出／
// 導入／恢復／布局預設那些按鈕動作在這裡也一樣能用。
// （接口聲明在文件前面搜索控制器之前，這裡只寫實作。）
// v43：改讀 ghlssTargetPlist（非保留字 key），先對白名單才載，
// 載入失敗只顯示空白頁、不閃退；進出寫檔日誌。
@implementation GHLSSPlistPageController

- (NSArray *)specifiers {
    if (!_specifiers) {
        NSString *targetPlist = self.specifier.properties[GHLSSRuntimeString("ghlssTargetPlist")];
        if (!targetPlist || [targetPlist length] == 0) {
            // v43.19：重進設定恢復出來的頁，specifier 是新的，ghlssTargetPlist
            // 那個運行期寫進去的鍵沒了；退回讀 detail（行裡本來就寫著 plist 名）。
            targetPlist = self.specifier.properties[GHLSSRuntimeString("detail")];
        }
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
        // v43.18：鍵盤模式下面兩行按模式動態換行——外置只留外置兩行
        //（enlargeOnExternalKeyboard／externalKeyboardCornerRadius），
        // 內置只留內置兩行（enlargeOnKeyboardPortrait／
        // landscapeEnlargeOnKeyboard）。模式變了回這一頁時 viewWillAppear
        // 已清快取重組（v71），讀到的就是新值。
        // v43.23：第 8 件——鍵盤頁只剩圖裡的行（模式＋兩行）：其餘三行
        //（真外置鍵盤（實驗）／橫屏時可拖動外置鍵盤／鍵盤彈出時浮窗自動上移）
        // 已從 Keyboard.plist 拿掉，鍵的值不動（kill switch keyboardExternalEnabled
        // 還留著 ON，helper 還靠它；四個放大／圓角鍵的值／預設也不動）。
        // 這裡的過濾不動——外置只留外置兩行、內置只留內置兩行，頁面就是 3 行。
        if (targetPlist && [targetPlist isEqualToString:GHLSSRuntimeString("Keyboard")]) {
            char *kmode = GHLSSPrefsCString("keyboardMode");
            BOOL outerMode = (kmode && strcmp(kmode, "outer") == 0);
            if (kmode) free(kmode);
            NSMutableArray *kept = [NSMutableArray array];
            for (PSSpecifier *sp in _specifiers) {
                NSString *spKey = sp.properties[GHLSSRuntimeString("key")];
                const char *kc = spKey ? [spKey UTF8String] : NULL;
                if (!kc) { [kept addObject:sp]; continue; }
                BOOL isOuterRow = (strcmp(kc, "enlargeOnExternalKeyboard") == 0) || (strcmp(kc, "externalKeyboardCornerRadius") == 0);
                BOOL isInnerRow = (strcmp(kc, "enlargeOnKeyboardPortrait") == 0) || (strcmp(kc, "landscapeEnlargeOnKeyboard") == 0);
                if (outerMode && isInnerRow) continue;
                if (!outerMode && isOuterRow) continue;
                [kept addObject:sp];
            }
            _specifiers = kept;
        }
        // v43.32：觸發方式下面三套按方式動態換行——ARC 只留 ARC 兩行
        //（arcStartAngle／arcFanAngle），邊緣只留邊緣那套（觸發側／
        // 滑幾次／左／右×豎／橫屏各三根滑桿），懸浮條只留懸浮條兩行
        //（floatingBarY／floatingBarSize）；調試開關和觸發方式行本身
        // 三套通用，一直留著。行和組頭都帶 ghlssTriggerSet 標記
        //（arc／edge／bar），沒標記的都留。模式變了回這一頁時
        // viewWillAppear 已清快取重組（v71），讀到的就是新值。
        if (targetPlist && [targetPlist isEqualToString:GHLSSRuntimeString("Trigger")]) {
            char *tmode = GHLSSPrefsCString("triggerMode");
            const char *want = "edge";
            if (tmode) {
                if (strcmp(tmode, "arc") == 0) want = "arc";
                else if (strcmp(tmode, "bar") == 0) want = "bar";
                free(tmode);
            }
            NSMutableArray *kept = [NSMutableArray array];
            for (PSSpecifier *sp in _specifiers) {
                NSString *setTag = sp.properties[GHLSSRuntimeString("ghlssTriggerSet")];
                if (setTag && strcmp([setTag UTF8String], want) != 0) continue;
                [kept addObject:sp];
            }
            _specifiers = kept;
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
        // v43.11：跟攔截一樣，values／titles 讀不到改讀 validValues／validTitles
        //（plist 行就是這個名字；建出來的選項行照舊只寫 values，寫值路只讀 values）。
        if (!values || [values count] == 0) {
            values = parent ? parent.properties[GHLSSRuntimeString("validValues")] : nil;
            titles = parent ? parent.properties[GHLSSRuntimeString("validTitles")] : nil;
        }
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

// v43.11：LinkList 選項行點按自己寫值——框架原生的 PSListController 不負責給
// PSListItemCell 行寫值（那是 PSListItemsController 的活，我們在 v43.10 繞過了它），
// 所以這頁以前只能看不能改（30.log：點選項 0 行寫值日誌）。取該行 values[0] 調
// [self setPreferenceValue:values[0] specifier:spec]（上面 v72 記日誌＋繼承寫值＋
// 同步），再 pop 回上一頁（原生 LinkList 點選後自動返回；挑選頁 viewDidAppear
// 會 reloadSpecifiers＋按新間隔重開計時器，不用再補）。不是 PSListItemCell 的行
// 或 values 讀不到就走 super。
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    PSSpecifier *spec = [self specifierAtIndexPath:indexPath];
    if (spec && spec.cellType == PSListItemCell) {
        NSArray *values = spec.properties[GHLSSRuntimeString("values")];
        if (values && [values count] > 0) {
            [tableView deselectRowAtIndexPath:indexPath animated:YES];
            [self setPreferenceValue:[values objectAtIndex:0] specifier:spec];
            [self.navigationController popViewControllerAnimated:YES];
            return;
        }
    }
    [super tableView:tableView didSelectRowAtIndexPath:indexPath];
}

@end

// v43.23：第 8 件——讀 kbHelperLoaded-<bid> 標記（97 的 %ctor 寫的 prefs 鍵）：
// helper 載入過哪個 App，這裡列哪個；主 dylib 以前沒有任何代碼讀這個鍵。
// 用 CopyKeyList 列舉 domain 裡 kbHelperLoaded- 開頭的鍵。沒找到回 nil。
static NSString *GHLSSKbHelperMarkersText(void) {
    NSMutableString *marks = [NSMutableString string];
    CFStringRef domain = GHLSSRuntimeCFString("com.guhailong.splitscreen");
    if (domain) {
        CFArrayRef keys = CFPreferencesCopyKeyList(domain, kCFPreferencesCurrentUser, kCFPreferencesAnyHost);
        if (keys) {
            CFIndex n = CFArrayGetCount(keys);
            for (CFIndex i = 0; i < n; i++) {
                CFStringRef kr = (CFStringRef)CFArrayGetValueAtIndex(keys, i);
                if (!kr || CFGetTypeID(kr) != CFStringGetTypeID()) continue;
                char kbuf[192] = {0};
                if (!CFStringGetCString(kr, kbuf, sizeof(kbuf), kCFStringEncodingUTF8)) continue;
                if (strncmp(kbuf, "kbHelperLoaded-", 15) != 0) continue;
                if ([marks length] > 0) [marks appendString:GHLSSRuntimeString("、")];
                [marks appendString:GHLSSRuntimeString(kbuf + 15)];
            }
            CFRelease(keys);
        }
        CFRelease(domain);
    }
    if ([marks length] == 0) return nil;
    return marks;
}

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
                } else if ([k isKindOfClass:[NSString class]] && [k isEqualToString:GHLSSRuntimeString("statusKbHelperMarkers")]) {
                    // v43.23：第 8 件——狀態頁顯示 kbHelperLoaded-<bid> 標記，
                    // 讓 Lee 在手機上看得到微信／QQ 的 helper 到底載入沒有。
                    NSString *marks = GHLSSKbHelperMarkersText();
                    NSString *txt = marks ? [GHLSSRuntimeString("键盘助手已载入：") stringByAppendingString:marks] : GHLSSRuntimeString("键盘助手：未检测到已载入标记（helper 还没进过任何 App）");
                    [spec setProperty:txt forKey:GHLSSRuntimeString("footerText")];
                } else if ([k isKindOfClass:[NSString class]] && [k isEqualToString:GHLSSRuntimeString("statusActivationState")]) {
                    NSString *status = GHLSSPrefsActivationStatusText();
                    NSString *txt = [GHLSSRuntimeString("激活状态：") stringByAppendingString:status];
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
    NSString *diag = [[[GHLSSRuntimeString("顾海龙集团分屏 v1.0.111\n插件开关：") stringByAppendingString:onOff] stringByAppendingString:GHLSSRuntimeString("\n最近日志：\n")] stringByAppendingString:tail];
    // v43.23：第 8 件——診斷信息也帶上 kbHelperLoaded 標記。
    NSString *marks = GHLSSKbHelperMarkersText();
    if (marks) {
        diag = [[diag stringByAppendingString:GHLSSRuntimeString("\n键盘助手已载入：")] stringByAppendingString:marks];
    }
    // v43.28：诊断信息也带上激活状态。
    NSString *activationStatus = GHLSSPrefsActivationStatusText();
    diag = [[diag stringByAppendingString:GHLSSRuntimeString("\n激活状态：")] stringByAppendingString:activationStatus];
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

// v43.30：激活页专用行（图标＋主标题＋副标题／右值，仿电话助手激活页）。
// PreferenceLoader 的 cellClass 键指定本类；读 specifier 的 label／
// subtitle／iconName／valueText 四个属性排版。cellClass 万一不生效，
// 行退回 stock PSButtonCell／PSLinkCell，只剩主标题、点按功能照常；
// 值行要 cellClass 才显示右值（状态页仍有同一状态可看）。
@interface GHLSSActivationRowCell : PSTableCell
@end

@implementation GHLSSActivationRowCell {
    UIImageView *_actIconView;
    UILabel *_actTitleLabel;
    UILabel *_actSubtitleLabel;
    UILabel *_actValueLabel;
    UIImageView *_actChevronView;
}

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier specifier:(PSSpecifier *)specifier {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier specifier:specifier];
    if (self) {
        self.accessoryType = UITableViewCellAccessoryNone;
        _actIconView = [[UIImageView alloc] init];
        _actIconView.contentMode = UIViewContentModeScaleAspectFit;
        _actIconView.tintColor = [UIColor systemBlueColor];
        [self.contentView addSubview:_actIconView];
        _actTitleLabel = [[UILabel alloc] init];
        _actTitleLabel.font = [UIFont systemFontOfSize:16];
        _actTitleLabel.lineBreakMode = NSLineBreakByTruncatingTail;
        [self.contentView addSubview:_actTitleLabel];
        _actSubtitleLabel = [[UILabel alloc] init];
        _actSubtitleLabel.font = [UIFont systemFontOfSize:13];
        _actSubtitleLabel.textColor = [UIColor grayColor];
        _actSubtitleLabel.lineBreakMode = NSLineBreakByTruncatingTail;
        [self.contentView addSubview:_actSubtitleLabel];
        _actValueLabel = [[UILabel alloc] init];
        _actValueLabel.font = [UIFont systemFontOfSize:16];
        _actValueLabel.textColor = [UIColor grayColor];
        _actValueLabel.textAlignment = NSTextAlignmentRight;
        _actValueLabel.lineBreakMode = NSLineBreakByTruncatingTail;
        [self.contentView addSubview:_actValueLabel];
        _actChevronView = [[UIImageView alloc] init];
        _actChevronView.contentMode = UIViewContentModeScaleAspectFit;
        _actChevronView.tintColor = [UIColor grayColor];
        [self.contentView addSubview:_actChevronView];
    }
    return self;
}

- (void)refreshCellContentsWithSpecifier:(PSSpecifier *)specifier {
    [super refreshCellContentsWithSpecifier:specifier];
    self.textLabel.text = nil;
    self.textLabel.hidden = YES;
    self.detailTextLabel.text = nil;
    self.detailTextLabel.hidden = YES;
    NSString *title = specifier.properties[GHLSSRuntimeString("label")];
    _actTitleLabel.text = title;
    NSString *subtitle = specifier.properties[GHLSSRuntimeString("subtitle")];
    _actSubtitleLabel.text = subtitle;
    _actSubtitleLabel.hidden = (!subtitle || [subtitle length] == 0);
    NSString *iconName = specifier.properties[GHLSSRuntimeString("iconName")];
    UIImage *icon = nil;
    if (iconName && [iconName length] > 0) icon = [UIImage systemImageNamed:iconName];
    _actIconView.image = icon;
    _actIconView.hidden = (icon == nil);
    NSString *value = specifier.properties[GHLSSRuntimeString("valueText")];
    _actValueLabel.text = value;
    _actValueLabel.hidden = (!value || [value length] == 0);
    BOOL hasAction = (specifier.properties[GHLSSRuntimeString("action")] != nil);
    if (hasAction) {
        _actChevronView.image = [UIImage systemImageNamed:GHLSSRuntimeString("chevron.right")];
        _actChevronView.hidden = NO;
    } else {
        _actChevronView.image = nil;
        _actChevronView.hidden = YES;
    }
    [self setNeedsLayout];
}

- (void)layoutSubviews {
    [super layoutSubviews];
    CGFloat w = self.contentView.bounds.size.width;
    CGFloat h = self.contentView.bounds.size.height;
    CGFloat textX = _actIconView.hidden ? 15 : 53;
    CGFloat textRight = w - 15;
    if (!_actChevronView.hidden) textRight = w - 40;
    if (!_actIconView.hidden) _actIconView.frame = CGRectMake(15, (h - 28) / 2, 28, 28);
    if (!_actChevronView.hidden) _actChevronView.frame = CGRectMake(w - 25, (h - 14) / 2, 10, 14);
    CGFloat valueW = _actValueLabel.hidden ? 0 : 160;
    if (valueW > 0) _actValueLabel.frame = CGRectMake(textRight - valueW, 0, valueW, h);
    CGFloat titleW = textRight - valueW - (valueW > 0 ? 8 : 0) - textX;
    if (titleW < 0) titleW = 0;
    if (_actSubtitleLabel.hidden) {
        _actTitleLabel.frame = CGRectMake(textX, 0, titleW, h);
    } else {
        _actTitleLabel.frame = CGRectMake(textX, 7, titleW, 22);
        _actSubtitleLabel.frame = CGRectMake(textX, 29, titleW, 18);
    }
}

@end

// v43.30：激活页（两张卡：上卡激活／赞助／管理三行，下卡状态行＋
// 加入群组＋底部「关于 SeaDragon Split」）。旧激活组（输入行＋检查
// 按钮）已由本页代替；状态文字走同一套 GHLSSPrefsActivationStatusText，
// 跟状态页一致。值行在 -specifiers 里现填，viewWillAppear 重载。
// 设备号那行不加（设备号读不出来才整条取消的，不把已删的链加回来）。
@interface GHLSSActivationListController : GuHaiLongSplitScreenRootListController
@end

@implementation GHLSSActivationListController

- (void)viewDidLoad {
    @try {
        [super viewDidLoad];
    } @catch (NSException *e) {
        const char *reason = [e reason] ? [[e reason] UTF8String] : "?";
        char buf[256];
        snprintf(buf, sizeof(buf), "v43.30 prefs-activation viewDidLoad EXCEPTION %s", reason);
        GHLSSPrefsLogLine(buf);
    }
    GHLSSPrefsLogLine("v43.30 prefs-page: Activation");
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self reloadSpecifiers];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    char buf[160];
    snprintf(buf, sizeof(buf), "v43.30 prefs-activation tap: section %ld row %ld", (long)indexPath.section, (long)indexPath.row);
    GHLSSPrefsLogLine(buf);
    if (GHLSSHandlePlistDetailTap(self, tableView, indexPath)) return;
    if (GHLSSDispatchButtonTap(self, tableView, indexPath)) return;
    [super tableView:tableView didSelectRowAtIndexPath:indexPath];
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    (void)tableView;
    (void)indexPath;
    return 56;
}

- (NSArray *)specifiers {
    if (!_specifiers) {
        @try {
            NSMutableArray *loaded = [self loadSpecifiersFromPlistName:GHLSSRuntimeString("Activation") target:self];
            for (PSSpecifier *spec in loaded) {
                NSString *vk = spec.properties[GHLSSRuntimeString("valueKey")];
                if (![vk isKindOfClass:[NSString class]]) continue;
                if ([vk isEqualToString:GHLSSRuntimeString("activationState")]) {
                    [spec setProperty:GHLSSPrefsActivationStatusText() forKey:GHLSSRuntimeString("valueText")];
                } else if ([vk isEqualToString:GHLSSRuntimeString("systemVersion")]) {
                    NSString *ver = [[UIDevice currentDevice] systemVersion];
                    NSString *txt = [GHLSSRuntimeString("iOS ") stringByAppendingString:(ver ? ver : GHLSSRuntimeString("?"))];
                    [spec setProperty:txt forKey:GHLSSRuntimeString("valueText")];
                } else if ([vk isEqualToString:GHLSSRuntimeString("pluginVersion")]) {
                    [spec setProperty:GHLSSRuntimeString("1.0.111") forKey:GHLSSRuntimeString("valueText")];
                }
            }
            _specifiers = loaded;
        } @catch (NSException *e) {
            const char *reason = [e reason] ? [[e reason] UTF8String] : "?";
            char buf[512];
            snprintf(buf, sizeof(buf), "v43.30 prefs-activation specifiers EXCEPTION %s", reason);
            GHLSSPrefsLogLine(buf);
            NSMutableArray *safe = [NSMutableArray array];
            PSSpecifier *group = [PSSpecifier emptyGroupSpecifier];
            [group setProperty:GHLSSRuntimeString("激活页打不开（已记进日志），先回上一页再试。") forKey:GHLSSRuntimeString("footerText")];
            [safe addObject:group];
            _specifiers = safe;
        }
        if (!_specifiers) _specifiers = [NSMutableArray array];
    }
    return _specifiers;
}

// v43：提示框改走最上层 presenter、主队列（同 ghlssShowAlertWithTitle
// 的做法；本页的输入框／操作表不能走那个只带「好」的 helper）。
- (void)ghlssActivationPresent:(UIAlertController *)alert {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIViewController *presenter = self;
        while (presenter.presentedViewController) presenter = presenter.presentedViewController;
        if (!presenter.view.window) {
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
        if (alert.popoverPresentationController) {
            alert.popoverPresentationController.sourceView = self.view;
            alert.popoverPresentationController.sourceRect = CGRectMake(CGRectGetMidX(self.view.bounds), CGRectGetMidY(self.view.bounds), 1, 1);
        }
        if (presenter) {
            [presenter presentViewController:alert animated:YES completion:nil];
        } else {
            GHLSSPrefsLogLine("v43.30 prefs-activation present FAILED: no presenter");
        }
    });
}

// 发 Darwin 通知给 dylib 重抓名单对码，4 秒后重载本页（状态行自己翻成
// 「您的设备已授权」／「未授权」，不用退出重进）。
- (void)ghlssActivationPostRecheck {
    notify_post("com.guhailong.splitscreen.activationRecheck");
    GHLSSPrefsLogLine("v43.30 prefs-activation recheck posted");
    __weak typeof(self) weakSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(4 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        typeof(self) strongSelf = weakSelf;
        if (!strongSelf) return;
        [strongSelf reloadSpecifiers];
    });
}

// 上卡第 1 行：弹输入框输激活码，确认就写 prefs＋发检查（码不记日志）。
- (void)ghlssActivationEnterCode:(PSSpecifier *)specifier {
    (void)specifier;
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:GHLSSRuntimeString("激活正版授权") message:GHLSSRuntimeString("输入激活码来绑定当前的设备。") preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *textField) {
        textField.placeholder = GHLSSRuntimeString("激活码，如 SD-XXXX-XXXX-XXXX");
        textField.autocapitalizationType = UITextAutocapitalizationTypeAllCharacters;
        textField.autocorrectionType = UITextAutocorrectionTypeNo;
    }];
    UIAlertAction *cancel = [UIAlertAction actionWithTitle:GHLSSRuntimeString("取消") style:UIAlertActionStyleCancel handler:nil];
    __weak UIAlertController *weakAlert = alert;
    UIAlertAction *ok = [UIAlertAction actionWithTitle:GHLSSRuntimeString("确认") style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        (void)action;
        UIAlertController *strongAlert = weakAlert;
        NSString *raw = strongAlert ? strongAlert.textFields.firstObject.text : nil;
        NSString *code = [[raw stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] uppercaseString];
        if (!code || [code length] == 0) {
            [self ghlssShowAlertWithTitle:GHLSSRuntimeString("请输入激活码") message:GHLSSRuntimeString("激活码是空的，先输入再确认。")];
            return;
        }
        CFStringRef domain = GHLSSRuntimeCFString("com.guhailong.splitscreen");
        if (domain) {
            CFStringRef cfKey = GHLSSRuntimeCFString("activationCode");
            if (cfKey) {
                CFPreferencesSetAppValue(cfKey, (__bridge CFPropertyListRef)code, domain);
                CFRelease(cfKey);
            }
            CFPreferencesAppSynchronize(domain);
            CFRelease(domain);
        }
        [self ghlssActivationPostRecheck];
        [self ghlssShowAlertWithTitle:GHLSSRuntimeString("已发送检查") message:GHLSSRuntimeString("已发送检查，稍等几秒再看「当前授权状态」，通过了会显示「您的设备已授权」。")];
    }];
    [alert addAction:cancel];
    [alert addAction:ok];
    [self ghlssActivationPresent:alert];
}

// 上卡第 2 行：没有在线购买页，去 Telegram 频道找 Lee 要码。
- (void)ghlssActivationSponsor:(PSSpecifier *)specifier {
    (void)specifier;
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:GHLSSRuntimeString("赞助购买授权") message:GHLSSRuntimeString("没有在线购买页，去 Telegram 频道找 Lee 要激活码。") preferredStyle:UIAlertControllerStyleAlert];
    UIAlertAction *cancel = [UIAlertAction actionWithTitle:GHLSSRuntimeString("取消") style:UIAlertActionStyleCancel handler:nil];
    UIAlertAction *open = [UIAlertAction actionWithTitle:GHLSSRuntimeString("打开频道") style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        (void)action;
        [self ghlssActivationOpenTelegramChannel];
    }];
    [alert addAction:cancel];
    [alert addAction:open];
    [self ghlssActivationPresent:alert];
}

// v71 同款：设置页进程里 openURL 不可靠，先顺手试 tg:// 深链，
// 不管成不成都复制 https 邀请链接＋弹「已复制」，保证链接一定到手。
- (void)ghlssActivationOpenTelegramChannel {
    NSURL *tgURL = [NSURL URLWithString:GHLSSRuntimeString("tg://join?invite=UaeIYedetWtiZGQ1")];
    if (tgURL) {
        [[UIApplication sharedApplication] openURL:tgURL options:[NSDictionary dictionary] completionHandler:^(BOOL success) {
            (void)success;
            dispatch_async(dispatch_get_main_queue(), ^{
                GHLSSPrefsLogLine("v43.30 prefs-activation telegram tg attempted");
            });
        }];
    }
    [UIPasteboard generalPasteboard].string = GHLSSRuntimeString("https://t.me/+UaeIYedetWtiZGQ1");
    GHLSSPrefsLogLine("v43.30 prefs-activation telegram copied");
    [self ghlssShowAlertWithTitle:GHLSSRuntimeString("已复制") message:GHLSSRuntimeString("Telegram 频道链接已复制到剪贴板，去 Telegram 贴上进群找 Lee 要码。")];
}

// 上卡第 3 行：清除已保存的激活码、重新检查。
- (void)ghlssActivationManage:(PSSpecifier *)specifier {
    (void)specifier;
    UIAlertController *sheet = [UIAlertController alertControllerWithTitle:GHLSSRuntimeString("管理配置授权") message:GHLSSRuntimeString("重置配置，授权找回等操作。") preferredStyle:UIAlertControllerStyleActionSheet];
    UIAlertAction *clear = [UIAlertAction actionWithTitle:GHLSSRuntimeString("清除已保存的激活码") style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action) {
        (void)action;
        CFStringRef domain = GHLSSRuntimeCFString("com.guhailong.splitscreen");
        if (domain) {
            CFStringRef cfKey = GHLSSRuntimeCFString("activationCode");
            if (cfKey) {
                CFPreferencesSetAppValue(cfKey, NULL, domain);
                CFRelease(cfKey);
            }
            CFPreferencesAppSynchronize(domain);
            CFRelease(domain);
        }
        [self ghlssActivationPostRecheck];
        [self ghlssShowAlertWithTitle:GHLSSRuntimeString("已清除") message:GHLSSRuntimeString("已保存的激活码已清除，状态回到未授权。")];
    }];
    UIAlertAction *recheck = [UIAlertAction actionWithTitle:GHLSSRuntimeString("重新检查激活码") style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        (void)action;
        [self ghlssActivationPostRecheck];
        [self ghlssShowAlertWithTitle:GHLSSRuntimeString("已发送检查") message:GHLSSRuntimeString("已发送检查，稍等几秒再看「当前授权状态」。")];
    }];
    UIAlertAction *cancel = [UIAlertAction actionWithTitle:GHLSSRuntimeString("取消") style:UIAlertActionStyleCancel handler:nil];
    [sheet addAction:clear];
    [sheet addAction:recheck];
    [sheet addAction:cancel];
    [self ghlssActivationPresent:sheet];
}

// 下卡：加入官方群组——QQ 群号复制、Telegram 频道。
- (void)ghlssActivationJoinGroup:(PSSpecifier *)specifier {
    (void)specifier;
    UIAlertController *sheet = [UIAlertController alertControllerWithTitle:GHLSSRuntimeString("加入官方群组") message:GHLSSRuntimeString("选择加入官方交流群") preferredStyle:UIAlertControllerStyleActionSheet];
    UIAlertAction *qq = [UIAlertAction actionWithTitle:GHLSSRuntimeString("QQ 群 1130823454") style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        (void)action;
        [UIPasteboard generalPasteboard].string = GHLSSRuntimeString("1130823454");
        GHLSSPrefsLogLine("v43.30 prefs-activation QQ group copied");
        [self ghlssShowAlertWithTitle:GHLSSRuntimeString("已复制") message:GHLSSRuntimeString("QQ交流群 1130823454 已复制到剪贴板，去 QQ 搜索群号加入。")];
    }];
    UIAlertAction *tg = [UIAlertAction actionWithTitle:GHLSSRuntimeString("Telegram 频道") style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        (void)action;
        [self ghlssActivationOpenTelegramChannel];
    }];
    UIAlertAction *cancel = [UIAlertAction actionWithTitle:GHLSSRuntimeString("取消") style:UIAlertActionStyleCancel handler:nil];
    [sheet addAction:qq];
    [sheet addAction:tg];
    [sheet addAction:cancel];
    [self ghlssActivationPresent:sheet];
}

@end
