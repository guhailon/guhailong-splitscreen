// 顾海龙集团分屏 — 设置页（PreferenceLoader）。
// v41：主頁照 FV 設定主頁的順序排（啟用／三屏／ARC／浮窗／其他雜項／
// 操作性功能五項藍色操作列）；子頁是獨立 plist（浮窗／三屏／ARC／
// 其他＋調度／陰影／橫幅／鍵盤／搜索／桌面圖標／懸浮圖標／ARC 按鈕／
// 兩個排序頁），由 PreferenceLoader 的預設控制器載入；「選擇應用」
// 是動態頁（GHLSSAppPickerListController，下面），按後台緩存的已安裝
// App 清單即時建開關。
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
#import <Preferences/PSListController.h>
#import <Preferences/PSSpecifier.h>
#import <UIKit/UIKit.h>

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
        _specifiers = [self loadSpecifiersFromPlistName:GHLSSRuntimeString("Root") target:self];
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

@end

// v41：「選擇應用」動態頁——三屏設置裡的選擇器，也是 ARC「＋」
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
