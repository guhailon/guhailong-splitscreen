// v50：檢查更新共用 helper（設定頁主頁「檢查更新」按鈕 + 浮窗設定卡片
// 「檢查更新」按鈕共用同一份寫法，不要複製兩套抓取邏輯）。
// prefs bundle 與 dylib 在不同進程跑、不能共用程式碼，所以做成 static
// 函數放在共用標頭裡：同一份來源，各自編一份，邏輯只有一份。
// 抓 live /Packages，找 com.guhailong.splitscreen 的 Version；
// 完成時在主隊列回調：latestVersion 有值＝抓到的版本；error 有值＝失敗原因。
// 注意：零字面量規則——這裡不用 ObjC 字串字面量，全部用 stringWithCString 現拼。
// 兩個呼叫端各自負責彈框顯示結果（prefs 用 ghlssShowAlertWithTitle、
// 卡片用 showSettingsCardAlert），這裡只抓取＋比對，不彈框、不寫日誌。

#import <Foundation/Foundation.h>

// 逐段比數字（1.0.50 vs 1.0.9 → 50 > 9 才對，不能只比字串）。
static inline int GHLSSCompareDottedVersions(const char *a, const char *b) {
    if (!a) a = "";
    if (!b) b = "";
    const char *pa = a;
    const char *pb = b;
    while (*pa || *pb) {
        long na = 0, nb = 0;
        while (*pa && *pa != '.') {
            if (*pa >= '0' && *pa <= '9') na = na * 10 + (*pa - '0');
            pa++;
        }
        while (*pb && *pb != '.') {
            if (*pb >= '0' && *pb <= '9') nb = nb * 10 + (*pb - '0');
            pb++;
        }
        if (na < nb) return -1;
        if (na > nb) return 1;
        if (*pa == '.') pa++;
        if (*pb == '.') pb++;
    }
    return 0;
}

static inline void GHLSSCheckForUpdate(void (^completion)(NSString *latestVersion, const char *error)) {
    NSString *urlString = [NSString stringWithCString:"https://guhailong-repo.pages.dev/Packages" encoding:NSUTF8StringEncoding];
    NSURL *url = [NSURL URLWithString:urlString];
    if (!url) {
        if (completion) completion(nil, "bad url");
        return;
    }
    NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithURL:url completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        (void)response;
        NSString *latest = nil;
        const char *err = NULL;
        if (error || !data) {
            err = "network";
        } else {
            NSString *text = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
            if (!text) {
                err = "decode";
            } else {
                NSString *pkgNeedle = [NSString stringWithCString:"Package: com.guhailong.splitscreen" encoding:NSUTF8StringEncoding];
                NSRange pkgRange = [text rangeOfString:pkgNeedle];
                if (pkgRange.location == NSNotFound) {
                    err = "not found";
                } else {
                    NSString *verNeedle = [NSString stringWithCString:"Version: " encoding:NSUTF8StringEncoding];
                    NSRange searchRange = NSMakeRange(pkgRange.location, [text length] - pkgRange.location);
                    NSRange verRange = [text rangeOfString:verNeedle options:0 range:searchRange];
                    if (verRange.location == NSNotFound) {
                        err = "no version";
                    } else {
                        NSUInteger start = verRange.location + verRange.length;
                        NSRange rest = NSMakeRange(start, [text length] - start);
                        NSRange nl = [text rangeOfString:[NSString stringWithCString:"\n" encoding:NSUTF8StringEncoding] options:0 range:rest];
                        NSUInteger end = (nl.location == NSNotFound) ? [text length] : nl.location;
                        NSString *ver = [text substringWithRange:NSMakeRange(start, end - start)];
                        ver = [ver stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
                        if ([ver length] == 0) err = "empty version";
                        else latest = ver;
                    }
                }
            }
        }
        NSString *found = latest;
        const char *foundErr = err;
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completion) completion(found, foundErr);
        });
    }];
    [task resume];
}
