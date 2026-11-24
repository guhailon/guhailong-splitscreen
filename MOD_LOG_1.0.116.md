# 1.0.116 修改日志 — 键盘进入分屏浮窗内

日期：2026-11-24    作者：MrDu    包：com.guhailong.splitscreen 1.0.116 (rootless arm64)

## 问题
分屏后键盘停在屏幕底部全宽（浮窗外部），需要键盘缩放后进入分屏浮窗内底部。

## 方案
SpringBoard 把浮窗 frame 写入共享 prefs `kbHostedFrame` 并 post
`com.guhailong.splitscreen.keyboardFrameReady`；App 进程里的键盘助手收到后
把键盘窗按「浮窗宽 ÷ 屏宽」等比缩放，左上角对齐浮窗、底边贴浮窗底部；
键盘收起还原。该模式下 SpringBoard 不再上移/放大浮窗。新增开关
`keyboardInWindowEnabled`（默认开），关闭恢复旧行为。

## 修改文件（4 个）

| 文件 | 改动 |
|---|---|
| `Tweak.xm` | 新增开关读取、frame 发布函数；键盘 show 走进浮窗分支、hide 清状态；浮窗拖动/缩放后重发几何 |
| `KeyboardHelper.xm` | 新增 frame 接收通知、键盘窗缩放/还原逻辑；键盘 show/hide 与应用启动挂接 |
| `prefs/Resources/Keyboard.plist` | 新增开关「键盘进入分屏浮窗内」 |
| `control` | 版本号 1.0.115 → 1.0.116 |

## 完整 diff

### Tweak.xm

```diff
--- a/Tweak.xm
+++ b/Tweak.xm
@@ -2324,6 +2324,12 @@
 static BOOL GHLSSReadKeyboardAvoidEnabled(void) {
 return GHLSSReadPrefsBool("keyboardAvoidEnabled", YES);
 }
+// v70.1（1.0.116）：键盘进浮窗——默认开。开了以后键盘不再跑到屏幕底部，
+// 由 App 进程里的键盘助手把键盘窗缩放并对齐到浮窗内底部；SpringBoard 这边
+// 不再上移/放大浮窗（否则窗口位置变了，键盘就对不齐）。关掉恢复旧行为。
+static BOOL GHLSSReadKeyboardInWindowEnabled(void) {
+return GHLSSReadPrefsBool("keyboardInWindowEnabled", YES);
+}
 // v43.33（1.0.108，路線 A 探針）：鍵盤圖層樹探針開關（Keyboard.plist 的
 // kbProbeEnabled，預設開；關了鍵盤彈出時不打圖層樹。只記日誌，不改行為）。
 static BOOL GHLSSReadKbProbeEnabled(void) {
@@ -2997,6 +3003,27 @@
 }
 if (domain) CFRelease(domain);
 if (keyRef) CFRelease(keyRef);
+}
+
+// v70.1（1.0.116）：键盘进浮窗——把当前活动浮窗的屏幕 frame 写进共享
+// prefs，再 post 一个 Darwin 通知给 App 进程的键盘助手。助手收到后把键盘窗
+// 缩放并对齐到这个框里。用 prefs 传四个数，是因为 Darwin 通知没有 payload
+//（跟 kbNotifyInfo 同一套写法）。没有活动窗就清空，助手收到空值会还原键盘。
+static BOOL GHLSSKeyboardInWindowActive = NO;
+static void GHLSSPublishHostedFrameForKeyboard(void) {
+if (!GHLSSHostedWindow || GHLSSHostedWindow.hidden || GHLSSHostedMinimized) {
+GHLSSWritePrefsCString("kbHostedFrame", "");
+notify_post("com.guhailong.splitscreen.keyboardFrameReady");
+return;
+}
+CGRect f = GHLSSHostedWindow.frame;
+char buf[128];
+snprintf(buf, sizeof(buf), "%.1f|%.1f|%.1f|%.1f", (double)f.origin.x, (double)f.origin.y, (double)f.size.width, (double)f.size.height);
+GHLSSWritePrefsCString("kbHostedFrame", buf);
+notify_post("com.guhailong.splitscreen.keyboardFrameReady");
+char lbuf[160];
+snprintf(lbuf, sizeof(lbuf), "v70.1 kb frame published %d,%d %dx%d", (int)f.origin.x, (int)f.origin.y, (int)f.size.width, (int)f.size.height);
+GHLSSLogLine(lbuf);
 }
 
 // v43.18：這個 prefs 鍵有沒有存過值（BOOL 鍵用 CString 讀不到，用這個判）。
@@ -7621,6 +7648,8 @@
 if (GHLSSHostedScaleLabel) GHLSSHostedScaleLabel.frame = CGRectMake(newW - 56, 3, 46, 30);
 if (GHLSSHostedResizeHandle) GHLSSHostedResizeHandle.frame = CGRectMake(newW - 36, newH - 36, 36, 36);
 [self resizeHostedSceneToContentSize:CGSizeMake(newW, newH)];
+// v70.1：键盘进浮窗时，浮窗拖动/缩放后立刻重发几何，键盘跟着贴底。
+if (GHLSSKeyboardInWindowActive) GHLSSPublishHostedFrameForKeyboard();
 if (GHLSSActiveAppIndex >= 0 && GHLSSActiveAppIndex < GHLSSAppCount) {
 GHLSSSaveGeometryForIndex(GHLSSActiveAppIndex);
 }
@@ -7927,6 +7956,14 @@
 if (!GHLSSHostedWindow || GHLSSHostedMinimized) return;
 if (bid && bid[0] != '\0' && strcmp(bid, GHLSSHostedBundleID) != 0) return;
 if (kbHeight <= 0) return;
+// v70.1（1.0.116）：鍵盤進浮窗——把浮窗 frame 發給 App 進程的鍵盤助手，
+// 由助手把鍵盤窗搬進浮窗。這條路不再上移／放大浮窗（移動了就對不齊）。
+if (GHLSSReadKeyboardInWindowEnabled()) {
+GHLSSKeyboardInWindowActive = YES;
+GHLSSPublishHostedFrameForKeyboard();
+GHLSSLogLine("v70.1 keyboard show -> inside window");
+return;
+}
 // v43.33（1.0.108，路線 A 探針）：鍵盤彈出時打一遍當前 presentation 的
 // 圖層樹（只記日誌，2 秒節流；開關 kbProbeEnabled 預設開）。
 if (GHLSSReadKbProbeEnabled()) GHLSSKbProbeDumpOnKeyboardShow(kbHeight, bid);
@@ -8000,6 +8037,11 @@
 GHLSSLogLine("v43.5 window restored after keyboard hide (enlarge)");
 }
 - (void)ghlssHandleKeyboardHideBundleID:(const char *)bid {
+// v70.1：進浮窗模式的 hide 只清狀態（鍵盤窗還原由 App 進程助手自己做）。
+if (GHLSSKeyboardInWindowActive) {
+GHLSSKeyboardInWindowActive = NO;
+GHLSSLogLine("v70.1 keyboard hide -> inside window off");
+}
 // v43.10：最小化守衛（跟 show 路對稱）——鍵盤彈起上移後窗被收成小卡，
 // shift 旗標還在；收起時不能把滿窗框推到小卡窗上（內容還停在小卡縮放，
 // 其餘全黑，半黑）。直接清旗標走人，不要動窗框。
```

### KeyboardHelper.xm

```diff
--- a/KeyboardHelper.xm
+++ b/KeyboardHelper.xm
@@ -43,6 +43,11 @@
 #define GHLSS_KB_NOTIFY_SHOW "com.guhailong.splitscreen.keyboardWillShow"
 #define GHLSS_KB_NOTIFY_HIDE "com.guhailong.splitscreen.keyboardDidHide"
 #define GHLSS_KB_INFO_KEY "kbNotifyInfo"
+// v70.1（1.0.116）：SpringBoard 把当前浮窗 frame 写进 kbHostedFrame 再 post
+// 这个通知；助手收到后把键盘窗缩放并对齐到浮窗内底部。
+#define GHLSS_KB_FRAME_KEY "kbHostedFrame"
+#define GHLSS_KB_FRAME_NOTIFY "com.guhailong.splitscreen.keyboardFrameReady"
+#define GHLSS_KB_INWIN_KEY "keyboardInWindowEnabled"
 
 static void GHLSSKBLogLine(const char *line) {
     FILE *f = fopen(GHLSS_KB_LOG_PATH, "a");
@@ -254,6 +259,89 @@
 
 static UIWindow *GHLSSKBDragTarget = nil;
 
+// ── v70.1：键盘进浮窗 ──
+// 键盘窗在 App 进程里，frame 是屏幕坐标；SpringBoard 把浮窗 frame 写进
+// kbHostedFrame。App 的内容在浮窗里是按「浮窗宽 / 屏宽」等比缩过的，
+// App 自己也按系统键盘高度把输入框上移了。所以键盘要跟内容用同一个
+// 缩放比（横向＝浮窗宽/屏宽，纵向＝浮窗高/屏高中的较小者，避免变形过度），
+// 再把键盘左上角放到浮窗里输入框下方的位置——底边贴浮窗底边。
+// 只用 transform＋position，不改键盘内部 view、不拦按键、不碰 first responder。
+static CGFloat GHLSSKBLastHeight = 0;
+static BOOL GHLSSKBInWindowApplied = NO;
+static CGRect GHLSSKBInWindowSavedBounds = {{0, 0}, {0, 0}};
+static CGPoint GHLSSKBInWindowSavedAnchor = {0, 0};
+static CGAffineTransform GHLSSKBInWindowSavedTransform;
+static CGPoint GHLSSKBInWindowSavedPosition = {0, 0};
+
+static void GHLSSKBRestoreKeyboardWindow(void) {
+if (!GHLSSKBInWindowApplied) return;
+GHLSSKBInWindowApplied = NO;
+UIWindow *kbWindow = GHLSSKBFindKeyboardWindow();
+if (!kbWindow) return;
+kbWindow.layer.anchorPoint = GHLSSKBInWindowSavedAnchor;
+kbWindow.bounds = GHLSSKBInWindowSavedBounds;
+kbWindow.transform = GHLSSKBInWindowSavedTransform;
+kbWindow.layer.position = GHLSSKBInWindowSavedPosition;
+GHLSSKBLogLine("v70.1 kb-helper in-window restored");
+}
+
+static void GHLSSKBApplyKeyboardInWindow(void) {
+if (!GHLSSKBReadPrefsBool(GHLSS_KB_INWIN_KEY, YES)) {
+GHLSSKBRestoreKeyboardWindow();
+return;
+}
+char *frameStr = GHLSSKBReadPrefsCString(GHLSS_KB_FRAME_KEY);
+if (!frameStr || frameStr[0] == '\0') {
+// 没浮窗（关了/最小化）→ 还原键盘到系统原位。
+if (frameStr) free(frameStr);
+GHLSSKBRestoreKeyboardWindow();
+return;
+}
+CGRect winFrame = CGRectZero;
+if (sscanf(frameStr, "%lf|%lf|%lf|%lf",
+           &winFrame.origin.x, &winFrame.origin.y,
+           &winFrame.size.width, &winFrame.size.height) != 4 || winFrame.size.width <= 0) {
+free(frameStr);
+GHLSSKBRestoreKeyboardWindow();
+return;
+}
+free(frameStr);
+UIWindow *kbWindow = GHLSSKBFindKeyboardWindow();
+if (!kbWindow) {
+GHLSSKBLogLine("v70.1 kb-helper no keyboard window for in-window");
+return;
+}
+CGRect screenBounds = [UIScreen mainScreen].bounds;
+if (screenBounds.size.width <= 0 || screenBounds.size.height <= 0) return;
+CGFloat scaleX = winFrame.size.width / screenBounds.size.width;
+if (scaleX <= 0.05 || scaleX > 1.5) return;
+CGFloat kbHeight = GHLSSKBLastHeight > 0 ? GHLSSKBLastHeight : kbWindow.bounds.size.height;
+// 内容在浮窗里等比缩放（浮窗宽/屏宽），键盘也用同一个比例；键盘的
+// 视觉高度＝kbHeight×scaleX，顶边落在「浮窗底边 - 键盘视觉高度」，
+// 正好接住按同比例缩过的输入框，底部贴浮窗底边。
+CGFloat targetH = kbHeight * scaleX;
+if (targetH > winFrame.size.height) targetH = winFrame.size.height;
+CGFloat targetY = winFrame.origin.y + winFrame.size.height - targetH;
+if (!GHLSSKBInWindowApplied) {
+GHLSSKBInWindowSavedBounds = kbWindow.bounds;
+GHLSSKBInWindowSavedAnchor = kbWindow.layer.anchorPoint;
+GHLSSKBInWindowSavedTransform = kbWindow.transform;
+GHLSSKBInWindowSavedPosition = kbWindow.layer.position;
+GHLSSKBInWindowApplied = YES;
+}
+// 左上锚点：缩放围绕左上角展开，layer.position 直接就是屏幕坐标左上角。
+kbWindow.layer.anchorPoint = CGPointMake(0, 0);
+kbWindow.bounds = CGRectMake(0, 0, screenBounds.size.width, kbHeight);
+kbWindow.transform = CGAffineTransformMakeScale(scaleX, scaleX);
+kbWindow.layer.position = CGPointMake(winFrame.origin.x, targetY);
+char buf[256];
+snprintf(buf, sizeof(buf), "v70.1 kb-helper in-window %d,%d %dx%d scale %d kb %d -> %d,%d %dx%d",
+    (int)winFrame.origin.x, (int)winFrame.origin.y, (int)winFrame.size.width, (int)winFrame.size.height,
+    (int)(scaleX * 100.0), (int)kbHeight, (int)winFrame.origin.x, (int)targetY,
+    (int)(screenBounds.size.width * scaleX), (int)targetH);
+GHLSSKBLogLine(buf);
+}
+
 @interface GHLSSKeyboardHelper : NSObject
 + (instancetype)shared;
 - (void)handleKeyboardWillShow:(NSNotification *)note;
@@ -290,7 +378,11 @@
     char infoBuf[256];
     snprintf(infoBuf, sizeof(infoBuf), "%s|%d", bid, (int)kbHeight);
     GHLSSKBWritePrefsCString(GHLSS_KB_INFO_KEY, infoBuf);
+    GHLSSKBLastHeight = kbHeight;
     notify_post(GHLSS_KB_NOTIFY_SHOW);
+    // v70.1：SpringBoard 收到 show 會把浮窗 frame 寫好再 post frameReady；
+    // 这里先直接試一次（prefs 可能已是上一帧位置），收到 frameReady 再對齊一次。
+    GHLSSKBApplyKeyboardInWindow();
     {
         char buf[256];
         snprintf(buf, sizeof(buf), "v43.5 kb-helper notify show %s %d", bid, (int)kbHeight);
@@ -304,6 +396,8 @@
     // 主窗口全屏≠全屏看影片；玩遊戲全屏時鍵盤本來就該在屏底全寬，不另擋。
     if (!GHLSSKBReadPrefsBool("keyboardExternalEnabled", NO)) return;
     if (GHLSSKBReadKeyboardPopupMode() != 1) return;
+    // v70.1：進浮窗模式優先——键盘已经搬进浮窗了，旧的外置全宽分支不再执行。
+    if (GHLSSKBReadPrefsBool(GHLSS_KB_INWIN_KEY, YES)) return;
     CGRect screenBounds = [UIScreen mainScreen].bounds;
     UIWindow *keyWindow = GHLSSKBKeyWindow();
     if (!keyWindow) return;
@@ -358,6 +452,9 @@
 
 - (void)handleKeyboardWillHide:(NSNotification *)note {
     (void)note;
+    // v70.1：键盘收起先把窗还原到系统原位，再通知 SpringBoard。
+    GHLSSKBRestoreKeyboardWindow();
+    GHLSSKBLastHeight = 0;
     char bid[128] = {0};
     NSString *bidStr = [[NSBundle mainBundle] bundleIdentifier];
     if (bidStr) {
@@ -434,6 +531,13 @@
     [nc addObserver:helper selector:@selector(handleKeyboardWillHide:) name:UIKeyboardWillHideNotification object:nil];
     // v43.26：第二次標記——App 啟動完成時再發一次（見 handleAppDidFinishLaunching:）。
     [nc addObserver:helper selector:@selector(handleAppDidFinishLaunching:) name:UIApplicationDidFinishLaunchingNotification object:nil];
+    // v70.1：SpringBoard 写好浮窗 frame 后 post 这个通知，收到就重新对齐键盘。
+    int frameToken = 0;
+    notify_register_dispatch(GHLSS_KB_FRAME_NOTIFY, &frameToken, dispatch_get_main_queue(), ^(int token) {
+        (void)token;
+        GHLSSKBApplyKeyboardInWindow();
+        GHLSSKBLogLine("v70.1 kb-helper frameReady applied");
+    });
     // v43.26：%ctor 標記三件套（見 GHLSSKBReportLoaded）：prefs 鍵 best-effort、
     // TMPDIR 標記檔＋os_log、Darwin 通知（名字帶 bid）給 SpringBoard 寫共用
     // prefs。bid 為空整組跳過，不寫 kbHelperLoaded- 無用鍵（41.log 遺留）。
```

### control

```diff
--- a/control
+++ b/control
@@ -1,5 +1,5 @@
 Package: com.guhailong.splitscreen
 Name: SeaDragon Split（顾海龙分屏）
-Version: 1.0.115
+Version: 1.0.116
 Architecture: iphoneos-arm64
 Description: 顾海龙集团原创分屏插件。详见源内说明页。
```

### Keyboard.plist

```diff
--- a/Keyboard.plist
+++ b/Keyboard.plist
@@ -13,6 +13,28 @@
 			<string>1.0.80 起：键盘弹出／收起由 App 行程内的键盘助手桥接给 SpringBoard，下面各行才真正生效。外置模式下，键盘由键盘助手移到屏幕底部全宽。</string>
 			<key>label</key>
 			<string>浮窗键盘设置</string>
+		</dict>
+		<dict>
+			<key>cell</key>
+			<string>PSGroupCell</string>
+			<key>footerText</key>
+			<string>1.0.116 新增：开启后键盘直接缩放并贴进分屏浮窗底部，不再出现在屏幕底部的外面。关闭则恢复旧行为（键盘全屏外置／浮窗上移）。</string>
+			<key>label</key>
+			<string>键盘进浮窗</string>
+		</dict>
+		<dict>
+			<key>PostNotification</key>
+			<string>com.guhailong.splitscreen.prefschanged</string>
+			<key>cell</key>
+			<string>PSSwitchCell</string>
+			<key>default</key>
+			<true/>
+			<key>defaults</key>
+			<string>com.guhailong.splitscreen</string>
+			<key>key</key>
+			<string>keyboardInWindowEnabled</string>
+			<key>label</key>
+			<string>键盘进入分屏浮窗内</string>
 		</dict>
 		<dict>
 			<key>cell</key>
```

## 验证
- 三个二进制（主插件 / 键盘助手 / 设置页）arm64+arm64e 编译链接通过
- `com.guhailong.splitscreen_1.0.116_iphoneos-arm64.deb` 结构、control、路径校验通过
- 设备端日志：`/var/mobile/Library/Logs/GuHaiLongSplitScreen.log`，标记 `v70.1`
