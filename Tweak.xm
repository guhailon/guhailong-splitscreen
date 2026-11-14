// GuHaiLongSplitScreen v1.0.42 (v42) — 顾海龙集团原创分屏插件（实验版）
//
// ── v42：30 項（皇上 2026-11-14 13:22–13:32 五次批准：三次「全做」＋
// 浮窗設定卡片＋卡片頭像/背景可換＋最後五項 1/4/6/7/8） ──
// A. 查看日誌（其他雜項功能）：設定 App 裡直接看分屏日誌（最新在上、
// 預設最後 200 行、刷新、清空、分享；自訂控制器 GHLSSLogViewerListController，
// 跟主聊天抖音 1.0.6 的「顧海龍日誌」是兩回事）。
// B. 三屏設置加 6 項：側窗寬度預設（窄 25%/中 30%/寬 40%）、記住上次
// 三屏組合（重開）、三屏組合子頁（最多 3 對）、分隔線粗細+顏色、邊緣
// 滑動直接開三屏、側窗圓角/陰影跟浮窗分開調。
// C. 另外 8 項：浮窗大小預設（小/中/大）、浮窗置頂鎖定、貼邊吸附（左右
// 吸住留 8pt、拖到頂放大）、重啟後自動恢復浮窗、全屏時哆啦A夢鈕自動藏
// （探針：狀態列隱藏啟發式）、鍵盤彈出時浮窗自動上移（探針：通知可能
// 不到 SpringBoard）、底部任務欄、浮窗透明度（每窗 0.5–1.0）。
// D. 設置改版 8 項：主頁搜索框（靜態索引對照表，非全文搜索）、常用開關
// 放主頁、每開關一句說明（豎屏固定中心 vs 記住位置互斥）、布局預設
// （遊戲/工作/默認）、配置方案（多套並存）、新手/專家模式（新手藏
// 「高級設置」一頁）、每頁單獨重置、手勢總覽頁。
// E. 浮窗設定卡片（概念圖已獲皇上 13:27「不錯」）：ARC 裡「設置」入口
// 開一張浮在當前 App 上的白卡（金邊、龍頭+版本 v1.0.42、右上 X、
// 點外面收起、層級低於鎖屏），五段同系統設定頁；子頁能在卡片裡做的
// 就做，做不到的跳回系統設定、頁腳寫明。系統設定五頁全部保留當備用。
// F. 卡片頭像/背景可換：頭像點一下換（相冊選圖、居中裁方形、存設定目錄
// 固定檔名；長按或設定行恢復默認龍頭）、卡片背景圖（設定行選圖、
// 半透明白遮罩保可讀性、可恢復默認白卡）；picker 在系統設定頁做
// （PHPicker，不用相冊權限），卡片只讀存好的圖；卡片點頭像是探針。
// G. 最後五項：1 手勢自定義（調度設置子頁：三擊窗/窗上下滑/窗左右滑/
// 雙指點窗 → 釘選/收起貼邊/關掉/輪切/放大；綁在窗頂細條上，不誤觸
// App 內容）、4 懸浮球觸發（小球點開 ARC、可拖任意位置、預設關）、
// 6 低電量自動收窗（開關+閾值 10–30% 預設 20% 預設開；低於閾值收成
// peek + 橫幅）、7 智能配對推薦（ARC 裡「常跟 XX 一起開：YY」，
// 配對記錄存 prefs 上限 5 對）、8 演示模式（ARC+設定主頁同一份鍵；
// 開了藏哆啦A夢鈕/peek/任務欄/橫幅/ARC，角落留半透明小點點一下退出）。
// 全部新 key 進 plist + 運行時拼字串讀 prefs；日誌前綴 v42；
// 詳見 BUILD_LOG §115（逐項誠實狀態 + 30 項真機測試清單）。
// 目標：iPhone 11 / iOS 16.5 / Dopamine (rootless)，iphoneos-arm64。
//
// 目标：iPhone 11 / iOS 16.5 / Dopamine (rootless)，iphoneos-arm64。
//
// ── v41：修哆啦A夢鈕拖動 + FV 式切換/設定重構/ARC/三屏（macOS 编） ──
// 皇上 2026-11-14 12:28 報 v40 真機測 5 項、12:30 批准做 v41，12:29 糾正：
// 不要白色相框做法，要王者榮耀那樣顯示（三屏：主 App 占大半屏幕 +
// 窄豎屏側窗貼邊，兩邊都活著）。12:32 又發兩張 FV 實機截圖當顯示樣板：
// 圖 1：主屏右邊緣上下疊著 3 張收起的浮窗（只露出一截內容，活的），
// 哆啦A夢鈕貼在右邊緣、疊在最下面那張卡上；圖 2：一個大浮窗（微信聊
// 天列表）浮在主屏之上，大圓角，App 內容從頂到底貼邊填滿整個窗——
// 白的是 App 自己的內容，不是裝圖標的白框；哆啦A夢鈕貼在右邊緣中間；
// 右上角還露出一張收起小卡的一角。所以 v41 的收起改成「peek」：窗不藏
// 起來改放小卡，改成縮到邊緣、露出一截活內容（點那截叫回來）；白色啟
// 動器面板拿掉，改 ARC 式（下面第 5 项）。
// 第 1 项：哆啦A夢鈕拖不動（v40 bug，根因在代碼裡定死）：拖動手勢
// handleDoraemonButtonDrag 寫了，但共用的手勢代理
// gestureRecognizer:shouldReceiveTouch: 對「touch.view 是 UIButton」
// 一律回 NO，而鈕上的 pan 與 long-press 兩個手勢都掛在這個代理上——
// 手指碰到鈕，兩個手勢根本收不到觸摸，鈕動不了（長按關全部也一樣死）。
// 這個代理本來是 v38 為細條/控制條點按寫的（點在紅 X、黃最小化、±
// 上時手勢不認、按鈕自己處理）。修法：shouldReceiveTouch 先判——
// 手勢掛在哆啦A夢鈕上（recognizer.view == GHLSSDoraemonButton）就回
// YES；其他手勢碰到 UIButton 才回 NO。拖動只沿右邊緣上下（Y，夾在
// 100 到 h-100），拖完記住 Y（prefs 鍵 doraemonButtonY，運行時現拼），
// 下次啟動恢復到那個高度。長按 0.5 秒關全部也因此活過來（pan 與
// long-press 同時識別本來就回 YES；long-press 內建 allowableMovement
// 約 10pt，拖動了它就不認）。另加雙擊鈕輪流切窗（第 2 项）：點按改成
// 單擊手勢（single-tap），雙擊手勢認出來時單擊不觸發（require
// GestureRecognizerToFail），點按不再走 TouchUpInside——單擊開 ARC，
// 雙擊輪切主窗。
// 第 2 项：浮窗切換像 FV 影片 49：窗有前後順序——最前可見的是主浮窗，
// 其次副浮窗、再副副浮窗，其餘收成貼邊 peek。順序存在靜態陣列
// GHLSSFrontOrder（最近帶到最前的在前），帶到最前/恢復/建新窗時更新。
// 點 peek 把那個窗升為主窗（恢復 + 推前景）；雙擊哆啦A夢鈕按順序輪切
// 主窗；ARC 裡開著的 App 帶標記點，點一下升為主窗。日誌「v41 window
// promoted to main」/「v41 window cycled main」。
// 第 3 项：設定頁改成 FV 真實結構（皇上 2026-11-12 發的 FV 設定截圖）：
// 主頁 = 啟用開關 + 四個子頁連結（浮窗設置 / 三屏設置 / ARC設置 /
// 其他設置），子頁是標準 iOS 設定子頁（各一個 plist + 各一個
// PSListController 子類，都在 prefs bundle 裡，不進 SpringBoard 的
// dylib）。浮窗設置：陰影開關、圓角滑桿（預設 35）、安全距離滑桿
// （沿用 safeDistance，預設 50）、點窗外開關 + 動作（沿用舊鍵）、
// 豎屏開窗固定中心開關、鍵盤設置頁、通知橫幅開關、調度窗口設置連結
// （第 4 项）。三屏設置：選 App（沿用 5 個 app*Enabled 鍵）、排序
// （目前順序固定，拖動排序下一版）、關三屏同時關側邊小窗開關
// （預設關，按 FV 截圖）、小窗左右位置（沿用 windowPosition）。
// ARC設置：開 ARC、ARC 顯示位置跟小窗位置走。其他設置：備份/導出/
// 導入/恢復/重置（備份與恢復是真的複製設定檔；導出/導入走固定檔案；
// 重置清掉全部已知鍵；見 BUILD_LOG §113）。**白色相框拿掉**：v40 的
// 白底圓角啟動器面板刪掉，改成 FV ARC 式（第 5 项）。三屏 = 王者榮耀
// 式（影片 95）：主 App 占大半屏幕 + 窄豎屏側窗貼邊，兩邊都活著，
// 中間一條可拖分隔線（調側窗寬度；主窗不自動縮——底下那個 App 本來就
// 是全屏在跑，見 §113）。
// 第 4 项：調度窗口設置（浮窗設置裡的子頁）：邊緣滑動開 ARC——滑幾次
// （1 或 2，預設 2）、滑哪邊（左/右，預設跟小窗位置走）；浮窗拖動手勢
// 開關（預設開）；側邊小窗手勢開關（管分隔線拖動，預設開）；哆啦A夢
// 雙擊輪切開關（預設開）；長按多久關全部（滑桿 0.3–1.0 秒，預設 0.5）。
// 第 5 项：ARC 圓形啟動器（影片 95 最後幾秒）：暗背景 + 一列圓形 App
// 圖標直接浮在上面（沒有白框面板），下面一顆 X 關掉；點圖標開那個 App
// 的浮窗（已開著的升為主窗）；開著的 App 圖標右上角有標記點（主窗金
// 色、其他白色）。觸發：點哆啦A夢鈕（單擊）或邊緣滑動（按調度設定）。
// 只有測過的 5 個 App。
// 不做：拖動排序（設定頁順序固定，下一版）；鍵盤自動上移（開關先存著，
// 頁腳寫明待真機驗證，見 §113）；橫屏三屏（本版先做直屏側窗，橫屏
// 支持仍在真分屏那一步）；任務欄快照、關閉彈性動畫（點綴）。
//
// ── v40：多窗 5.3 + 贴边小卡 + 拖到右緣收起 + 點窗外事件 + 安全距離（macOS 编） ──
// 皇上 2026-11-14 11:05 批准想法、11:32「接下来就是你的想法」。
// v39 真机测「改的非常好」（哆啦A夢圖、計算機/設置位置、關屏黑窗三處
// 都修好了）；11:34–11:38 又報三個跟進問題，全進 v40：
// 第 1 项：多窗（5.3，V5_DESIGN.md §5.3 + BUILD_LOG §104 的影片）：
// 一次開多個浮窗（最多 5 個，v35 每 App 快取的底子）；點啟動器裡的
// App：已開著的帶到最前、收著的從小卡恢復、沒開的在新窗打開，別的窗
// 不動；「window busy」那條擋切換的邏輯刪掉（最小化後點別的 App
// 也能開，不再被擋）。新窗錯位放（每多一個看得見的窗錯開 44pt，
// 橫豎交錯、夾在屏幕裡），不直接蓋在舊窗正上方。點窗頂細條/控制條
// 把窗帶到最前（層級：宿主窗基礎 Alert - 2、帶到最前 Alert - 1.75、
// 貼邊小卡 Alert - 1.5、啟動器 Alert - 1、鎖屏 2000）。
// 第 2 项：貼邊小卡（最小化改成看得見的停靠）：黃最小化不再只是藏窗，
// 窗藏起來、右邊緣留一張 68x76 的小卡（App 圖標 + App 名），一張張
// 豎著排、上下居中；點卡恢復窗（帶到最前、推前景）。卡右上角一顆
// 小 X，點 X 徹底關掉（窗藏起來、卡收掉、scene 留著不銷毀，下次從
// 啟動器重開直接復用）。控制條裡的紅 X 留著當備用。scene 永遠不
// 銷毀（v35 規則），關窗/最小化都只藏窗 + 推後台。
// 第 3 项：拖到右邊緣貼邊收起（主關閉路徑，像影片一樣）：影片裡的浮窗
// 根本沒有標題列、沒有 X 鈕，是拖到右邊緣收成小卡的。拖著浮窗往右邊
// 緣拖、放手時窗中心進了右緣 60pt 內，就收成一張貼邊小卡（跟最小化
// 一樣，scene 活著）；沒拖到那麼邊、放手就停在原地（但窗不能半截
// 出屏，放手夾回全可見）。拖動的夾制也放寬（右邊 maxX 放到屏寬 - 20，
// 才拖得到收起門檻）。
// 第 4 项：拖動修（皇上 11:34：v39 浮窗拖不動）：拖動是靠窗頂細條，
// 但細條只有 16pt、太透明（只有一顆 56x5 的小 pill），找不到地方抓。
// 細條加寬到 24pt（GHLSS_HOSTED_STRIP_H，建窗與 resize 都用這個常量，
// 一起改），pill 改 72x6、alpha 0.7、垂直置中，更好找；細條保持透明
//（App 內容透出來）。控制條 36pt 不動、滑桿條 y=36 不動。手勢改成
// 動「手勢所屬的窗」（recognizer.view 所在的 window），不是只動
// GHLSSHostedWindow 這個單一靜態（多窗時拖 B 窗會動到 A 窗）；拖動、
// 縮放、滑桿、控制條點按都先切活動量到手勢所屬的窗再做事。
// 第 5 项：點窗外事件 + 安全距離（皇上 11:38 發 floatingView 設定頁
// 截圖「可以搞這樣子」）：設定頁加三項（同一個 prefs domain）：
// ①「點窗外事件」開關（預設開）；②「點窗外動作」二選一（關閉浮窗 /
// 側邊，預設側邊）；③「與劉海方向安全距離」滑桿（0–100，預設 50）。
// 開關開著、且有浮窗看得見時，浮窗後面出一層陰影背景（overlay
// window，Alert - 4.5，在主屏之上、感應帶/哆啦A夢鈕之下、浮窗之下——
// 點浮窗本身、點哆啦A夢鈕、滑感應帶都不受影響）；點陰影背景時，按
// 設定把最上面/主浮窗關掉或移到側邊貼成小卡。開關關掉時不出陰影、
// 點窗外不做事。安全距離：拖窗時窗頂離劉海（屏幕頂緣）不到這個值
// 就自動回彈（夾住位置，讓窗頂至少離頂緣這個距離；舊 minY=100 是
// 夾中心，頂緣能出屏——v40 改成夾窗頂）。設定值讀法跟現有開關一樣
//（CFPreferencesCopyAppValue，用時現讀 + CFPreferencesAppSynchronize
// 同步，不用通知中心——那個被禁；零字面量規則不動）。
// 第 6 项：记位置/大小（皇上 11:55 糾正「全加」）：每个 App 单独记住
// 最后一次的窗口位置（中心）与尺寸（宽高）+ 缩放 scale，存 CFPreferences
//（同一个 domain，键 "geo<App>X/Y/W/H/Scale"，runtime 现拼，零字面量
// 规则不动）。下次开同一 App 时恢复到上次的位置和大小；没有存过的用
// 现有默认（+ 新窗错位）。恢复后夹在屏幕内（左右留 8pt、顶留安全距离、
// 底留 8pt），并遵守安全距离。拖动结束、缩放改变、收起/关窗、调尺寸
// 结束时保存。日誌「v40 geometry restored/saved」。
// 第 7 项：一键关全部浮窗（皇上 11:55 糾正「全加」）：长按哆啦A夢鈕
//（约 0.5 秒）关掉全部已开的浮窗 + 已收起的小卡（每个窗走现有的关闭
// 路径：hide + background scene，不在 session 内 destroy scene，
// 遵守 v35 规则；小卡清除）。长按松手不触发启动器（长按旗标 suppress
// TouchUpInside，拖动钮时也清掉——长按后拖出按钮外的兜底）；短按
//（无拖动、无长按）仍是开启动器。日誌「v40 close all windows」。
// 第 8 项：窗上显示 App 名（皇上 11:55 糾正「全加」）：24pt 顶部拖动条
// 中央加一个小字 App 名（12pt，置于拖动条内，不遮挡内容，触摸仍归
// 拖动条的拖动手势，不影响拖动；白字 + 黑色阴影，浅色内容上也看得见）。
// 控制条里的 App 名保留；Dock 小卡上本来就有 App 名，不用改。细条里的
// pill 从垂直置中改成贴条底（72x6 不变，y=17），给名字让位。
// 第 9 项：拖动角落调整大小（皇上 11:55 糾正「全加」）：窗口右下角一顆
// 可拖的角落手柄（36x36 触摸区——比说的 24 稍大，好抓；带一个看得见
// 的白色角落括号「⌟」标记，0.8 alpha，原来 60x60 透明窗 + 0.2 alpha
// 淡菱形太难找）。拖动即改窗口 frame，并走现有的
// GHLSSApplyScaleToHostedWindow 缩放逻辑重算内容（松手时调 scene 的
// frame，跟原来一样）；限制最小 200x300、最大不超过屏幕，保持圆角
// 35 与 anchorPoint (0,0) 的 v39 修正。调整结束保存大小（第 6 项）。
// 日誌记 resize（scene resized + geometry saved）。
// 不做：三屏、ARC 菜單、鍵盤/mediaserverd 辅助 dylib（5.4 / 5.3 之後
// 才評估）；任務欄快照（我們沒有任務欄）、關閉彈性動畫（點綴）。
//
// ── v39：哆啦A夢鈕读图路径 + sublayerTransform 左上锚点 + 解锁推前景（macOS 编） ──
// 皇上 2026-11-14 11:02 批准做 v39（v38 真机测：撞崩修法有效——已在跑
// 的设置再打开不进安全模式；剩下三个显示问题，日志 GuHaiLongSplitScreen-9.log
// 定死，见 BUILD_LOG §107–§108）。三件事：
// 第 1 项：哆啦A夢鈕还是金色「分」——读图路径写死 /Library/...，
// Dopamine 是 rootless，实际在 /var/jb/Library/...，bundleWithPath
// 拿到 nil、图读不到、退回金色「分」（日志只有 image missing，没有
// image loaded）。修法：先试 /var/jb/Library/...，再试 /Library/...。
// 第 2 项：计算器/设置位置往右下偏——sublayerTransform 是繞內容區
// layer 的 anchorPoint 縮，預設 (0.5,0.5) 是中心，不是左上；
// scale<1.0 的 App（計算機 0.77、設置 0.845）偏了中心×(1−scale)，
// scale=1.0 的 App 沒事（日志数字全对、窗没被改过，见 §108）。
// 修法：建 contentView 時把 anchorPoint=(0,0)、position=(0,0)
//（frame 仍是 (0,0,winW,winH)），一次改，建窗、resize、滑桿的
// sublayerTransform 全都繞左上縮；GHLSSApplyScaleToHostedWindow 裡
// 兩個分支各重申一次錨點（防萬一）。scene frame、scale 數值不動；
// presenterView/layerHostView 自己的錨點本來就是 (0,0)，不動。
// 第 3 项：浮窗开着、关屏、再进去是黑的——解锁 handler 只把窗显示
// 回来、不推 foreground，恢复路径又只在最小化时跑，scene 一直在
// 後台（日志：unlock 後沒有 foreground push）。修法：解锁分支顯示
// 窗之後，順手推 foreground=YES + backgrounded=NO（跟
// restoreHostedWindow 裡 v30 的做法一樣，包 @try/@catch；解鎖時
// 鎖屏已不在，不影響密碼）。
//
// ── v38：托管已在跑 App 的已有主 scene + 无标题栏大窗 + 哆啦A夢鈕（macOS 编） ──
// 皇上 2026-11-13 22:26 批准做 v38。三件事，崩溃修第一：
// 第 1 项：已在跑的 App 撞固定 ID 崩（v36 日志定死：设置已在跑、
// 再建 scene 就在 createSceneWithDefinition 里撞 registerHost
// fromRemnant 断言进安全模式）。修法按 KonbanXV（作者 Hoangdus，
// MIT，https://github.com/Hoangdus/KonbanXV——只仿它的结构与做法，
// 代码全部原创；註明写进这里与查表函数的注释）：建 scene 之前先
// 查现有 scene——新增纯 C helper GHLSSExistingMainSceneForBundleID：
// FBSceneManager sharedInstance → object_getIvar 读 _workspace →
// object_getIvar 读 _allScenesByID（NSDictionary）→ 找 identifier
// 等于固定 sceneID `sceneID:<bundleID>-default` 或含 bundleID 的
// 那一项，返回 FBScene（找不到返回 nil）。每一步都判 nil，任何一步
// 失败就走老路（createScene），不崩、不拦。找到现有 scene 就走新
// 路：不调 registerProcessForAuditToken（进程已在跑、SpringBoard
// 早就管着它）、不调 createSceneWithDefinition、不建 presenter——
// 用 _UISceneLayerHostContainerView（initWithScene:debugDescription:
// + _setPresentationContext:，context 是 UIScenePresentationContext
// 的 _initWithDefaultValues）建一个 layer host view，把它当
// presenterView 用，嵌进内容区；scene 照常存 GHLSSHostedScene，
// 前景/后台生命周期照常走（显示时 foreground=YES + backgrounded=
// NO，最小化/关窗/锁屏时 foreground=NO + backgrounded=YES）；
// **这个 scene 永远不调 destroyScene**（它是 App 自己的主 scene，
// 销毁会杀掉 App 的界面；复用守卫判旧时也分叉：layer-host 的项只
// 清缓存引用、不销毁）。frame **不要改**（它是 App 的全屏主 scene，
// frame 就是屏幕尺寸；缩放只靠 view 的 transform / sublayerTransform，
// 不动 scene 的 frame——反向耦合的 frame 更新只对新建 scene 用）。
// 安全区 insets **不要动**（主 scene 的 insets 是 App 正常显示用
// 的）。presenter 为空的处理：缓存里加一个平行数组
// GHLSSCacheLayerHostViews[5]（和 presenter 数组平行）+ 活动量
// GHLSSHostedLayerHostView；复用守卫改成「presenter 与 view 活着
// **或** layer host view 活着」才复用；buildHostedWindow 的嵌入
// 分叉（有 presenter 走老路，有 layer host view 走新路）；resize/
// 滑杆的 helper 分叉（有 presenter 走 GHLSSApplyScaleToHostedWindow
// 的老路，有 layer host view 只改 view 的 bounds + sublayerTransform，
// **不推 scene frame**）；GHLSSDestroyCachedEntryAtIndex 分叉
//（layer-host 的项只清引用、不 deactivate/invalidate presenter、
// 不 destroyScene）。**不要**用 _UIScenePresenter 挂现有 scene——
// FBAL 的 presenter 是从新建 scene 的 uiPresentationManager 建的，
// 没有现成例子证明它能挂一个已有主 scene；KonbanXV 的 layer host
// 是唯一有代码可循的做法。未验证点（真机前先想好）：layer host 在
// SpringBoard 主屏（非 Today 页）是否显示——KonbanXV 只在 Today 页
// 用过，机制上它就是个显示 scene 图层的 UIView，嵌进哪个 view 层
// 级都一样，但没在主屏证实过；_workspace / _allScenesByID 的 ivar
// 名在 iOS 16.5 上是否就是 KonbanXV 用的那两个（对不上就走老路，
// 有 nil 守卫，不崩）；已有主 scene 的 foreground=YES 推送会不会
// 把 App 的全屏版也顶出来（主 scene 本来就在前台跑着，推 foreground
// 应该是空操作，但没证实——真机要看点开浮窗后，主屏的 App 有没有
// 被顶到前台）。
// 第 2 项：无标题栏大窗（皇上 2026-11-13 22:12 的外观反馈：我们的
// v37 装了、能用、没问题，但长得不如 floatingView——对方的窗又大
// 又长、约 85% 宽、80% 高、圆角、没有标题栏，内容从顶到底贴边填
// 满）。改：① 44pt 标题栏**拿掉**，内容区就是整个窗（App 内容从
// 顶到底贴边填满，圆角 35、阴影不变）；② 默认窗改大：一般 App 内
// 容 350x757（85% 宽，757 是按屏高宽比算的——350/414×896≈757，
// 和屏幕同宽高比，这样已有主 scene（414x896）按宽缩放正好贴边填
// 满、不切不留边；新建 scene 的 App 则按 350x757 重排版）；计算器
// 内容仍是 320x693（窗 320x693，之前 320x737 是含 44pt 标题栏的
// 总高，内容几何不变、scale 仍是 0.77）。③ 标题栏的活儿另找位置：
// 窗顶上加一条 16pt 的透明细条（中间一颗 56x5 的白点小 pill，
// 半透明——唯一的常驻装饰），点它展开/收起 36pt 的控制条（半透明
// 黑底，里面红 X、黄最小化、App 名、± 缩放钮，和旧标题栏一样的
// 布局，只是默认藏着）；细条和控制条都能拖动窗（手势和原来一样，
// 位置夹在屏幕里）；控制条收起来时缩放滑杆条也跟着收起来（± 在
// 控制条里，控制条藏着时滑杆条也够不着）。缩放滑杆条仍在内容区
// 顶上（y=36，控制条下面），默认藏着。
// 第 3 项：哆啦A夢鈕（皇上 2026-11-13 22:17 要金色「分」按钮改
// 成可爱型哆啦A夢图；22:19 不要 2D 扁平图标，要动漫那种、3D；
// 22:22 发了搜索截图，要百度百科那只大笑的哆啦A夢（张大嘴笑、
// 眼睛笑成弯弯的、双手合在肚子前面）；22:23 皇上确认「对」）。
// 改：金色「分」24x64 按钮**拿掉**，换成一颗 56pt 的圆哆啦A夢鈕
//（大笑 3D 版，图已备好：prefs/Resources/doraemon-button.png/
// @2x/@3x，56/112/168px，裁到脸）。24pt 的感应带放不下 56pt 的
// 圆钮（圆钮一半会伸出窗外、点不到），所以哆啦A夢鈕单独一个
// 56x56 的小窗（右边缘、竖直居中、层级 Alert - 4，和感应带同级），
// 感应带仍是 24pt 全高（只留右边缘滑动手势）。图从 prefs bundle
// 里读（NSBundle bundleWithPath: + pathForResource:ofType:，
// 路径用运行时现做的字串——零 ObjC 字面量字串规则不变；@3x 由系统按屏
// 幕 scale 自动挑）；读不到就退回金色圆钮 + 「分」字（不空白、
// 不崩）。层级、主线程启动、锁屏回调、固定 sceneID、永不销毁，
// 其余什么都不动。
//
// ── v37：反向耦合缩放（所有 App）+ 标题栏缩放滑杆 + 安全区规则；
//        已在跑的 App 撞固定 ID 崩——修法太大，留给 v38（macOS 编） ──
// v36 真机日志（GuHaiLongSplitScreen-8.log，v36 段 183 行）：计算器
// 贴边修好了（窗 320x736、scale 77%、presenterView frame 0,0 320x692、
// contentState 到 2）；切计算器→时钟→备忘录都正常；切到设置时进安全
// 模式两次，都是同一个签名——`app already running pid=3666` → 建
// scene → `sceneID sceneID:com.apple.Preferences-default` → 下一行就
// 是 `deferred setup ran`（SpringBoard 重启）。设置是皇上之前自己打
// 开过、一直在后台跑的，所以 createScene 时它的进程已有同 ID 的主
// scene，固定 ID 一撞就触发 registerHost fromRemnant 断言（和 v32/
// v34 的销毁后重建是同一个断言、不同触发点）。计算器/时钟/备忘录/
// 照片都是新进程所以没事。v35 段对比：设置第一次开是新进程、建
// scene 成功，之后 12 次都是 reusing cached scene、0 崩——v35 的
// never-destroy 修好了「销毁→重建」崩，但 v36 暴露了「已在跑 +
// 同 ID」这个新触发点。
// 所以 v37 的第 4 项（最高优先级）：已在跑的 App 不要 createScene，
// 改托管它已有的主 scene（KonbanXV 的做法，MIT：_workspace →
// _allScenesByID 找现有 scene，用 _UISceneLayerHostContainerView 挂；
// 找不到才 createScene）。但这条路在 SpringBoard 主屏（非 Today 页）
// 是否同样工作，未验证；且要加第二条嵌 view 的路 + presenter 为空
// 的处理，和第 1 项（反向耦合改同一处 frame/缩放代码）互相影响。
// 判断：v37 先做原定的三项（下面），第 4 项写成 v38 的具体设计
//（见 BUILD_LOG §99 末尾：查表函数、layer-host 嵌法、presenter 为
// 空的处理、不销毁已有 scene 的规则、回退 createScene、验证计划），
// 不猜一个不稳的做法赶 v37。
// 第 1 项：反向耦合缩放（仿照 FrontBoardAppLauncher，作者
// khanhduytran0，Apache-2.0，https://github.com/khanhduytran0/
// FrontBoardAppLauncher——只仿它的结构与做法，代码全部原创）：每
// 个窗一个 scaleRatio（默认 1.0；计算器默认 0.77，窗仍是 320x737）；
// scene frame = 内容尺寸 ÷ scale（App 在这个尺寸里排版）；内容区
// 的 layer 加 sublayerTransform = CATransform3DMakeScale(scale,
// scale, 1)（显示时缩回窗尺寸）。一除一乘，任意窗尺寸、任意 App
// 都填满内容区、贴边。v36 的计算器特判全删掉（只按宽缩放的 helper、
// 建窗的计算器分支、缩放手柄的比例锁、resize 的计算器分支），只剩
// 每 App 的默认 scaleRatio 不同。frame 更新防抖 0.05 秒（FBAL 的
// resizeWindowWithFrame 做法）；presentationView 的 bounds = frame
// 尺寸、anchorPoint (0,0)、position (0,0)（FBAL 的做法，左上对齐）。
// 第 2 项：标题栏缩放滑杆 0.5–2.0（步进 0.01，FBAL + LiveContainer
// 原则）：标题栏右边加一个 26x26 的「±」圆钮（和红 X、黄最小化一样
// 大），点一下在内容区顶上展开一条 36pt 的滑杆条（半透明黑底，里
// 面一条 UISlider + 百分比），再点收起来。拖滑杆改 scaleRatio，走
// 同一条反向耦合路径（立即改 transform、0.05 秒防抖改 frame），记
// 日志「v37 scale changed to X%」。滑杆条默认藏着，不挡正常使用；
// 缩放能裁掉计算器顶上约 370pt 的黑空区（放大就裁掉，v36 的遗留）。
// 第 3 项：设置顶上切掉——按 LiveContainer 的安全区规则（AGPL，
// 只借原则、代码原创）：我们的初始 settings 本来就 peripheryInsets
// = 0、safeAreaInsetsPortrait = 0（窗口模式规则，已对上），所以初
// 始 settings 不动；只在 frame 更新时（resize、滑杆）顺带把两个
// insets 重设为 0（LC 就是把安全区 block 附在 frame 更新里的）。
// 若切掉只是滚动位置，这改就是空操作；若是 frame 更新后 insets 被
// 重置，这改就修了它。仍需真机验证（滚动到顶看个人资料卡）。
// 层级、主线程启动、锁屏回调、固定 sceneID、永不销毁，其余什么都不动。
//
// ── v36：计算器窗改高、按宽缩放贴边；内容贴边填满、不被切掉（macOS 编） ──
// v35 真机（2026-11-13 20:39）：皇上「我觉得这些都不够整齐，没有
// 对方好，我觉得可以做成第三幅图片样子」。三张截图：① 我们的 v35
// 计算器——全键盘出来了（显示 556,913,316，全部 5 排都在），但黑内
// 容左右两边各有一条约 50pt 的白色边（53% 缩放的图层只有约 219 宽，
// 居中放在 320 宽的窗里，两边露白——露的是内容区的白色底）；② 我
// 们的 v35 设置——列表画出来了，但顶上第一项在内容区顶上被切掉一
// 半；③ 对方 floatingView——一个又高又大的浮窗（几乎满屏高、约
// 85% 屏宽、圆角），Sileo 精选页把窗填得满满的、贴边，没有白边、
// 没有被切掉、没有标题栏。v35 的防崩修法已证实有效（皇上能打开计
// 算器和设置两个浮窗、没进安全模式；v34 切到设置崩了两次）。
// 所以 v36 只改窗的「整齐」：① 计算器窗改高、按宽缩放——内容区
// 改成 320x693（屏高×320/屏宽，运行时算，不写死）、s = 内容宽/
// 图层宽 ≈ 320/414 ≈ 0.77（只按宽算，不再取宽高最小值），图层
// 414x896 按 0.77 缩后正好是 320x693，填满内容区、左右零白边、
// 按键约 62pt；窗总高 693+44=737，896 高的屏上居中放得下（上下
// 各留约 80pt）。缩放手柄拖计算器窗时按比例锁高（内容高 = 宽×
// 屏高/屏宽），不然缩放后的图层上下会被切。② 内容贴边填满：
// 内容区底色由白改黑（万一哪有缝，露黑不露白）；建窗时记
// presenterView 的实际 frame（x,y WxH），日志能证明它贴边放对
// 了。③ 设置顶上切掉的判定（从源码 + 截图）：非计算器 App 的
// presenterView 就是 frame = 内容区 bounds（0,0,320,480），没
// 有任何偏移、没有裁——我们的几何不可能切掉顶部；最可能就是列
// 表被滚过（皇上测试时滑过，或缓存的 scene 留着滚动位置），其
// 次才是 App 在零 safe-area 下的内部顶 inset。判定方法：把设置
// 列表拉到最顶，看个人资料卡出不出现——出来就是滚动位置，没出
// 来就是 inset 问题，v37 再试顶 safe-area。④ 默认窗尺寸不动：
// 非计算器 App 已经贴边填满（源码 + 截图都证实），加高默认窗不
// 修任何毛病、只会多盖屏幕；计算器改高是它的固定全屏排版逼的，
// 不是设计偏好。层级、主线程启动、锁屏回调、固定 sceneID、永不
// 销毁，其余什么都不动。
//
// ── v35：会话内永不销毁 scene + 计算器缩放到窗里（macOS 编） ──
// v34 真机（2026-11-13 20:01）：皇上「都还在，感觉非常OK，就是计算
// 机画面有点没对准」——计算器画出来了、切换没问题、没进安全模式、状
// 态也留住了（截图里 556,913,3… 是按过的数字）。但日志
//（GuHaiLongSplitScreen-7.log，v34 段 555 行）定死 v34 还是崩两次，
// 两次都是切到设置（com.apple.Preferences）：设置只建过一次、被切走
// 时销毁过（切设置→照片），再建就崩在 createSceneWithDefinition 里
//（日志在 sceneID 后直接跳到 deferred setup ran，即 SpringBoard 重
// 启；和 v32 的 .ips 定死的 registerHost 撞残留是同一个点）；第二
// 次更是在重启之后又崩——设置进程 pid=2521 在重启后还活着，所以残
// 留不在 SpringBoard 里、在设置进程自己身上，重启清不掉它。计算器、
// 时钟、备忘录、照片都被销毁重建过多次，全成功——只有设置再建会崩，
// 是设置特有的（它的进程在 host 销毁后还留着客户端的 scene）。结论：
// v34「切走才销毁、ID 不同不撞」的判断错了——设置证明销毁 + 再建
// 同一固定 ID 就是会崩，不管新 ID 是哪个 App 的。所以 v35 只改一处
// 原则：**一个 SpringBoard 会话里永远不销毁 scene**——关窗（X）和
// 切走都只藏窗 + 推后台，每个 App 留一个 scene + presenter + 窗
//（最多 5 个，启动器的 5 个 App），切回来直接复用；只在进程死了的
// 时候（复用守卫判旧：pid 对不上或 presenter/view 没了）才销毁那
// 个旧 scene 再建——死进程留不住客户端残留，建的应该是干净的。
// 实现选型（i）：每 App 一个窗、缓存在平行静态数组里（强引用，ARC
// 安全），一次只显示一个；活动窗仍用原来那套静态量，所有现成路径
//（关窗、最小化、恢复、锁屏回调、重试、拖动、缩放）原样不动，只改
// 切换路径（藏旧窗 → 存缓存 → 清活动量 → 核对 → 开新 App）与复用
// 守卫（查缓存不查活动量）。没选（ii）单窗换 presentationView：
// 换 view 要拆 presenter 的 view 再嵌回去，presenter 可能停掉、
// scene 可能挂起，且各 App 的窗尺寸/缩放状态会互相串，不如每 App
// 一个窗干净。重试块不改：它只推 foreground=YES（对已在前景的
// scene 是空操作），切走 1.5 秒内重试打到新 scene 上也无害。
// 计算器对不准（20:01 截图）：窗 320 宽、计算器按全屏 414 宽排版、
// 1:1 显示，右边和底下被切掉；日志 15 次 presentationView 全是
// w=320 h=480。v35 只改：① 计算器的 scene frame 改成屏幕尺寸
//（运行时读 UIScreen，不写死 414/896）——frame 决定远端图层大小，
// 这样计算器的整张 414x896 画面都在图层里，不会被 scene frame 先
// 切掉一刀；② presentationView 按比例缩放到窗里（s = min(内容宽/
// 图层宽，内容高/图层高)，只缩不放大；只对计算器——别的 App 按
// scene frame 排版，s=1，不动）；触摸由 transform 自动映射；
// safe-area insets 本来就是零，不用除以 transform。缩放手柄松手
// 时重算一次缩放（resizeHostedSceneToContentSize 里计算器分支：
// frame 保持屏幕尺寸，只改缩放）。别的 App 的窗尺寸、frame、缩放
// 全不动。层级、主线程启动、锁屏回调、固定 sceneID，其余什么都不动。
//
// ── v34：留着固定 sceneID，关窗改藏窗不销毁（macOS 编） ──
// v33 真机实测（2026-11-13 17:08）：开计算器就是黑屏，没进安全
// 模式——崩是没崩，但主 App 画不出来，比 v32 还糟。元凶定死是新
// UUID sceneID：这次测的只是全新打开计算器，没走切换逻辑；v33
// 相对 v32 对全新打开唯一的区别就是 sceneID 从固定改成每次新
// UUID。历史对得上：v25–v27（新 UUID）计算器黑；v28（固定 ID，
// 高层级）黑（层级问题）；v29–v32（固定 ID，低层级）计算器能画；
// v33（新 UUID，低层级）又黑了。结论：已在跑着的单 scene App
//（计算器）要画出来，需要固定 sceneID `sceneID:<bundleID>-default`
//（即 App 自己的默认 scene ID）；全新 UUID 的 scene 它认不出来、
// 不往里画。v28「sceneID 假说已死」是错的——当时是层级问题盖住
// 了 sceneID 的作用；两个条件（固定 ID + 低层级）都要，缺一不可。
// v33 的「固定 ID 不是画画的必要条件」也是错的，一并纠正。
// 但固定 ID 的残留撞 ID 崩是真的（.ips 定死：EXC_BREAKPOINT，
// FBWorkspace registerHost:...fromRemnant: 里断言；同一固定 ID
// 关窗重开 5 次都好、第 6、7 次崩）。v34 的修法不靠新 ID，靠改
// 关窗的生命周期：① 关窗（X）不再销毁 scene——只藏窗、推后台、
// 记最小化，scene 留着；重开同一个 App 直接复用旧 scene（推前
// 景、显示窗），不再建新 scene，同一 ID 一个 SpringBoard 会话里
// 只建一次，残留撞不到。② 切走别的 App 时才真正销毁（新方法
// destroyHostedScene，旧关窗体；新 App 的固定 ID 不同，不撞）。
// ③ createHostedScene 入口加复用守卫：已有同 App 的 scene 且
// presenter/view 还活着、进程还是同一个 pid，就直接复用、不建新
// scene；scene 旧了（进程换了或 presenter 没了）就先销毁再建。
// 残留风险：A→B→A 切回来时，A 的 scene 在第一次切走时已销毁，
// 重建同一固定 ID——v32 的崩要攒 ~6 次同 ID 关窗重开才触发，单
// 次切回远不到阈值，但反复来回切可能攒够；若真机再现，v35 再做
// 每 App 留一个 scene、会话内永不销毁。单窗切换（v33 的）原样
// 保留；层级、主线程启动、重试、锁屏回调，其余什么都不动。
// v35 纠正：上面 ②「切走才销毁、ID 不同不撞」也是错的——v34 日志
// 定死，切设置→照片再切回设置就崩（设置进程在 host 销毁后还留着
// 客户端 scene）；所以 v35 会话内永不销毁（见 v35 节）。
//
// ── v33：5.2 单窗切换 + 每次新 sceneID（macOS 编） ──
// 皇上 2026-11-13 16:31：v32 锁屏密码修好了（「可以了，非常OK」）。
// 但新问题：App 没办法来回切换——开着计算器，点启动器里的时钟没
// 反应，必须先把计算器悬浮窗关掉（X）再点。5.2 只准开一个窗，点别
// 的 App 时直接忽略（window busy）。皇上 16:33 确认是不同 App 之
// 间切。v33 只改：点别的 App 时，先关当前窗（走现有关窗路径，销毁
// scene、停 presenter、进程留着），核对状态清干净了，再开新 App
// 的悬浮窗（单窗切换）；最小化着的窗也一样关了再开。同一个 App 再
// 点不变（恢复/已开着）。同一天皇上又报：悬浮窗开着时点启动器里的
// App，SpringBoard 会进安全模式——日志（GuHaiLongSplitScreen-6.log）
// 定死：2 次崩全是计算器关窗重开，崩在 createSceneWithDefinition 里，
// 同一固定 sceneID、同一 pid，前面 5 次关窗重开都好、第 6、7 次崩；
// 第 2 次崩很可能是第 1 次崩留下的半注册 scene 撞的。v28 说固定 ID
// 复用安全的判断错了（destroyScene 不是完全同步/干净的）。v33 顺
// 便改：sceneID 改每次新 UUID（LiveContainer 的做法；我们保留
// bundleID 在前面、UUID 在后面，日志一眼看出是哪个 App），
// persistenceIdentifier 仍与 sceneID 相同；关窗仍按存着的 sceneID
// 销毁。固定 ID 不是画画的必要条件：v28 换固定 ID 时计算器还是黑
// 的，是 v29 降层级才让它画出来。UUID 用纯 C 的 uuid_generate /
// uuid_unparse，不用 NSUUID 类、不碰字串常量。层级、主线程启动、
// 重试、其余什么都不动。
//
// ── v32：锁屏时把悬浮窗也临时藏起来（macOS 编） ──
// v31 真机实测（2026-11-13 16:00）：密码还是按不动——等 30 秒左右
// 密码就开始按不了了，键盘看得见（跟 15:21 的截图一样），按了没
// 反应。锁屏时把 scene 推回后台不够，foreground-scene 理论被证伪。
// 下一方向（V31_RESEARCH.md 写的）：锁屏时我们的窗/presenter 可能
// 还抓着触摸。v32 只改一个变量：在 v31 的锁屏回调里，锁了除了推
// 后台化，还把悬浮窗临时藏起来（hidden=YES）；开了再显示回来——
// 只藏"开着"的窗，最小化着的窗本来就藏着，不碰它；没窗时什么都不
// 做。感应带和启动器不动（只藏悬浮窗）。开了不自动推前景（等用户
// 点恢复，恢复路径会推）。
//
// ── v31：修锁屏密码按不动——最小化与锁屏时把 scene 推回后台（macOS 编） ──
// v29 把所有窗层级降到锁屏之下，只修好了第一次锁屏；v30 上源后皇上
// 15:21 复现：锁屏密码键盘看得见（数字键全在），但按了没反应，6 个
// 圆圈一个都没填——不是窗盖住键盘，是按了没被系统处理。首要怀疑：
// hosted scene 从没被后台化（只推过 foreground=YES，从没推过 NO），
// 锁屏时它还占着前景，干扰锁屏触摸。v31 只改三处：① 最小化时把
// scene 推回后台（foreground=NO + backgrounded=YES）；② 锁屏信号用
// libnotify 的 notify_register_dispatch（纯 C API，传 C 字串，不是被
// 禁的 CFNotificationCenterAddObserver，不碰 CFString），锁了且有
// hosted scene 就把它推回后台，开了只记日志、不自动推前景；③ 恢复
// 时 v30 的 foreground 推送里补 backgrounded=NO。backgrounded 属性
// 由 KonbanXV（MIT）的 dehost 先例证实存在，另加 respondsToSelector
// 兜底；presenter 不动（只在关窗销毁时才 deactivate）。层级、sceneID、
// 主线程启动、重试、其余什么都不动。
//
// ── v30：5.2 修恢复后黑窗——恢复时再推一遍 foreground（macOS 编） ──
// v29 真机实测（2026-11-13 15:12–15:14）：锁屏修好了——开悬浮窗锁
// 屏，再开屏密码能输；计算器也能画了（截图为证：数字键全画出来了）。
// 但新 bug：最小化悬浮窗 → 锁屏 → 解锁 → 再点同一个 App 恢复窗，
// 内容是黑的（截图为证：标题栏和按钮都在，内容区全黑）；点 X 关窗
// 再打开就正常（新 scene、建窗时推了 foreground）。原因是锁屏把
// scene 的 foreground 状态弄丢了，恢复时只取消 hidden、没再推
// foreground，scene 就一直黑着。v30 只改一个变量：restoreHostedWindow
// 里，取消 hidden 之后，用建窗时同一个已证明能用的
// updateSettingsWithBlock: 把 foreground=YES 再推一遍，并记一行
// 日志（foreground pushed on restore）；单独包 @try/@catch，出错
// 只记日志。锁屏层级（v29 的 Alert - 4/-3/-2/-1）、sceneID（v28 的
// 固定格式）、其余什么都不动。
//
// ── v29：修锁屏密码输不进去——所有窗层级降到锁屏之下（macOS 编） ──
// 皇上 2026-11-13 14:51 复现并确认：锁屏再开屏，锁屏密码输不进去，
// 只能关机。原因在代码里看得一清二楚：我们所有窗的层级都在锁屏之上
// ——悬浮窗 UIWindowLevelAlert + 2.0（2002）、启动器最高 + 3.0
// （2003）、感应带就是 Alert（2000），而锁屏约在 Alert=2000。
// 手机一锁屏，我们的窗还盖在锁屏上面，密码键盘点不到。
// v29 只改一个变量：所有 windowLevel 整体下移 4，相对顺序不变——
// 感应带 Alert - 4（1996）、启动器基准 Alert - 3（1997）、悬浮窗
// Alert - 2（1998）、有悬浮窗时启动器 Alert - 1（1999）。全部在
// 锁屏（2000）之下，仍在状态栏（1000）与 App（0）之上，平时用不
// 受影响。sceneID 仍是 v28 的固定格式，其余什么都不动。
//
// ── v28：5.2 修计算器还是黑——sceneID 改固定格式（macOS 编） ──
// 计算器的诊断到此定死了（2026-11-13 14:16–14:27）：v26 的 foreground
// 显式推修好了 4/5 个 App 的黑窗（设置、时钟、照片、备忘录全能在悬浮
// 窗里画出来，截图为证）；只有计算器还是黑的。已排除的：时机（等 10
// 秒还是黑，不是连得慢）；全新启动 vs 已在跑（新启动和已在跑都黑，
// 别的 App 画出来之前和之后都黑）；**第一个进程被「毒化」也排除了**——
// 皇上 14:27 重新越狱（全部进程全新、新 SpringBoard），计算器在悬浮
// 窗里还是黑的。所以是计算器这个 App 本身不吃我们现在的 scene 设置。
// v27 是诊断版（1.5 秒 + 4 秒重试、无条件记日志、记 presenterView），
// 重试修不了计算器（10 秒等待已证明不是时机问题）。
// v28 只改一个变量：sceneID 从每次新 UUID，改成参考项目
// FrontBoardAppLauncher 的固定格式 `sceneID:<bundleID>-default`
//（persistenceIdentifier 也用同一个固定值），和参考项目完全一样。
// 关窗时 scene 本来就会销毁，所以固定 ID 重用是安全的（参考项目就
// 是这么做的）。如果 v28 计算器画出来了，就是 sceneID 的问题；如果
// 还是黑，下一步走 KonbanXV 的路——宿主 App 已有的主 scene。
// v34 纠正：固定 ID 重用并不安全——v32 日志 + .ips 定死，多次关窗
// 重开后 createScene 在 registerHost 断言崩（残留撞 ID）；但固定
// ID 是计算器画画的必要条件（v33 新 UUID 黑屏定死），所以 v34
// 不换 ID，改关窗生命周期：关窗藏窗不销毁，重开复用（见
// closeHostedWindow），同一 ID 一个会话只建一次。
//
// ── v27：5.2 修 v26 的重试没留日志 + 计算器还是黑（macOS 编） ──
// v26（1.0.26）皇上真机实测（2026-11-13 14:16–14:17）：foreground
// 显式推，修好了 4/5 个 App 的黑窗——设置、时钟、照片、备忘录全
// 能在悬浮窗里画出来（截图为证：设置 > 通用、世界时钟都显示了）。
// 只有计算器还是黑的，3 次全黑（全新启动 pid=5642 + 已在跑重开
// 两次，别的 App 画出来之前和之后都黑）——所以是计算器自己的问题，
// 不是启动时机、不是顺序、不是全新还是已在跑。日志
//（GuHaiLongSplitScreen-4.log）20 次 contentState 全是 1、一次
// 都不是 2，连能画出来的 App 也是 1——contentState 不能当画没画
// 的信号（继续记，但不拿它当通过标准）。1.5 秒的 foreground 重试
// 在整份日志里一次都没出现：要么皇上每次都在 1.5 秒内关窗/最小化
// 了（守卫条件直接 return、没留日志），要么重试块根本没跑。
// 所以 v27 只改两处：① 1.5 秒重试之外再加 4 秒重试一次，两次
// 重试的块一跑就先无条件记一行 retry check（窗关了也记，
// contentState=0、minimized=0），再按老条件决定推不推；推了记
// retry / retry2。② presenter activate 之后，记 presenterView
// 的尺寸（w/h）与有没有 layer，排除 view 本身没尺寸、没嵌进去的
// 可能。其余与 v26 相同：sceneID 还是每次新 UUID（一个变量一个
// 变量地改）。
//
// ── v26：5.2 修 v25 的黑窗（macOS 编） ──────────────
// v25（1.0.25）皇上真机实测（2026-11-13 11:50）：悬浮窗出来了（圆角、
// 标题栏「计算器」、红 X、黄最小化、金色「分」按钮），没进安全模式、
// 没卡住、手机没重启——v24 的崩修好了。但窗里的内容全黑，计算器的
// 界面画不出来，没法用。日志（GuHaiLongSplitScreen-3.log）证明整条
// 链全走通了两遍：identity ok → handle pid=0 → manager ok →
// transaction created → provider called → begin called → transaction
// begun → scene start → process launched pid=5254 → scene created →
// presenter ready → window shown；关窗后重开（进程已在跑 pid=5254）
// 也一样走到 window shown、也一样黑——所以不是启动时机问题。
// scene、presenter、窗都在，就是计算器进程没往 scene 里画东西。
// 首要怀疑：建完 scene 后，从没把 foreground 显式推给客户端。
// 证据是 KonbanXV（MIT，同样在 SpringBoard 里托管 App 的 scene）：
// 它建完 scene 就调 [sceneSettings setForeground:YES] 再
// [scene updateSettings:sceneSettings withTransitionContext:nil]，
// 注释写着 "This is important for the view to be interactable."，
// 还记 scene.contentState（0 没就绪、1 准备中、2 就绪）。我们只在
// 建 scene 的参数里写了 foreground=YES，从没事后推过。所以 v26
// 只改这一处：presenter activate 之后，记一次 contentState，再用
// 已经证明能用的 updateSettingsWithBlock: 把 foreground=YES 推一
// 遍、再记一次 contentState；窗出来 1.5 秒后再推一遍（重试，只在窗
// 还在、没最小化、contentState 还不是 2 时推）。sceneID 还是每次
// 新 UUID（一个变量一个变量地改）。
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
#import <notify.h>
#import <AudioToolbox/AudioServices.h>

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

// 5.1 启动器里的 App（bundle ID 与显示名，都是普通 C 字串）。
// v41：上限提到 12 個——前 5 個是測過的固定 App（計算器、時鐘、備忘錄、
// 設置、照片），後 7 個是自選槽位（customApp1–7，bundle ID 存在 prefs
// 裡，啟動時從 prefs 讀進來；見 GHLSSLoadCustomApps）。啟動器/ARC 最多
// 同時開 12 個窗（每 App 一個 scene 緩存，v35 規則不變）。微信就是
// 「任何 App」裡的一個，不用單獨加——用戶在 ARC 的「＋」或設定頁選
// 它，就進一個自選槽位。
#define GHLSS_APP_COUNT 12
#define GHLSS_CUSTOM_APP_COUNT 7
static char GHLSSAppBundleIDs[GHLSS_APP_COUNT][128] = {
"com.apple.calculator",
"com.apple.mobiletimer",
"com.apple.mobilenotes",
"com.apple.Preferences",
"com.apple.mobileslideshow"
};
static char GHLSSAppNames[GHLSS_APP_COUNT][128] = {
"计算器",
"时钟",
"备忘录",
"设置",
"照片"
};
static const char *GHLSSAppEnabledKeys[GHLSS_APP_COUNT] = {
"appCalculatorEnabled",
"appClockEnabled",
"appNotesEnabled",
"appSettingsEnabled",
"appPhotosEnabled",
"customApp1Enabled",
"customApp2Enabled",
"customApp3Enabled",
"customApp4Enabled",
"customApp5Enabled",
"customApp6Enabled",
"customApp7Enabled"
};
// v41：自選槽位的 bundle ID 鍵（customAppNBundleID，存在同一個 prefs
// domain；開關是上面對應的 customAppNEnabled）。
static const char *GHLSSCustomBundleIDKeys[GHLSS_CUSTOM_APP_COUNT] = {
"customApp1BundleID",
"customApp2BundleID",
"customApp3BundleID",
"customApp4BundleID",
"customApp5BundleID",
"customApp6BundleID",
"customApp7BundleID"
};
// v40：记位置/大小的键前缀——一个 App 一个前缀，键 = "geo" + 前缀 +
// 字段（例："geoCalculatorX"、"geoCalculatorScale"）。字段：X、Y（窗中心）、
// W、H（窗尺寸）、Scale（缩放）。存在同一个 prefs domain。
static const char *GHLSSGeoAppKeys[GHLSS_APP_COUNT] = {
"Calculator",
"Clock",
"Notes",
"Settings",
"Photos"
};

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
// v31：backgrounded 由 KonbanXV（MIT）的 dehost 先例证实存在
//（iOS 15–16 的 FBSMutableSceneSettings）；只用 setter，另加
// respondsToSelector 兜底。
@property (nonatomic, assign) BOOL backgrounded;
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
@property (nonatomic, readonly) NSUInteger contentState;
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

// v38：托管已有主 scene 用的 layer host（KonbanXV，MIT，只仿结构、
// 代码原创）。_UISceneLayerHostContainerView 是显示 scene 图层的
// UIView（不是 _UIScenePresenter——FBAL 的 presenter 是从新建 scene
// 的 uiPresentationManager 建的，没有现成例子证明它能挂一个已有主
// scene；KonbanXV 的 layer host 是唯一有代码可循的做法）。
// context 用 UIScenePresentationContext 的 _initWithDefaultValues。
@interface UIScenePresentationContext : NSObject
- (instancetype)_initWithDefaultValues;
@end

@interface _UISceneLayerHostContainerView : UIView
- (instancetype)initWithScene:(FBScene *)scene debugDescription:(NSString *)debugDescription;
- (void)_setPresentationContext:(UIScenePresentationContext *)context;
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
// v42：它同时是浮窗設定卡片的 UITableView 資料源/代理（卡片的表
// 格、開關、滑桿、分段控制都走它，不另加自訂類）。
@interface GHLSSLauncher : NSObject <UIGestureRecognizerDelegate, UITableViewDataSource, UITableViewDelegate>
- (void)handleEdgeSwipe:(UIScreenEdgePanGestureRecognizer *)recognizer;
- (void)handleDoraemonButtonDrag:(UIPanGestureRecognizer *)recognizer;
- (void)handleDoraemonButtonLongPress:(UILongPressGestureRecognizer *)recognizer;
- (void)handleAppButton:(UIButton *)sender;
- (void)handleCloseButton:(id)sender;
- (void)handleBackgroundTap:(UITapGestureRecognizer *)recognizer;
- (void)showLauncher;
- (void)dismissLauncher;
- (void)buildLauncherWindow;
- (void)launchHostedApp:(const char *)bundleID name:(const char *)name;
- (void)createHostedSceneForBundleID:(const char *)bundleID name:(const char *)name;
- (void)buildHostedWindowForBundleID:(const char *)bundleID name:(const char *)name scene:(FBScene *)scene presenter:(_UIScenePresenter *)presenter layerHostView:(UIView *)layerHostView sceneID:(NSString *)sceneID pid:(int)pid;
- (void)closeHostedWindow;
- (void)minimizeHostedWindow;
- (void)restoreHostedWindow;
- (void)handleHostedClose:(id)sender;
- (void)handleHostedMinimize:(id)sender;
- (void)handleScaleButton:(id)sender;
- (void)handleScaleSlider:(UISlider *)sender;
- (void)handleScaleSliderEnded:(UISlider *)sender;
- (void)handleTitleDrag:(UIPanGestureRecognizer *)recognizer;
- (void)handleTopStripTap:(UITapGestureRecognizer *)recognizer;
- (void)handleResizeDrag:(UIPanGestureRecognizer *)recognizer;
- (void)resizeHostedSceneToContentSize:(CGSize)size;
// v41：贴边 peek 的点按（恢复窗）与小 X（彻底关掉）、阴影背景的点按。
- (void)handleDockPeekTap:(UIButton *)sender;
- (void)handleDockPeekClose:(UIButton *)sender;
- (void)handleDimOverlayTap:(UITapGestureRecognizer *)recognizer;
// v41：哆啦A夢鈕單擊（開 ARC）/雙擊（輪切主窗）、升主窗、輪切主窗。
- (void)handleDoraemonButtonSingleTap:(UITapGestureRecognizer *)recognizer;
- (void)handleDoraemonButtonDoubleTap:(UITapGestureRecognizer *)recognizer;
- (void)promoteWindowToMainIndex:(int)idx;
- (void)cycleMainWindow;
// v41：三屏分隔線拖動、ARC 的「＋」選 App、選 App 頁的開關與完成。
- (void)handleSideDividerDrag:(UIPanGestureRecognizer *)recognizer;
- (void)handleARCPickerButton:(id)sender;
- (void)showAppPicker;
- (void)dismissAppPicker;
- (void)handleAppPickerToggle:(UISwitch *)sender;
- (void)handleAppPickerDone:(id)sender;
// v41：ARC 內容重建（搜索/三段/遊戲模式/常用三開）、搜索結果點按、
// 圖標長按置頂、遊戲模式開關、常用三開、通知橫幅、全屏打開探針、
// 截圖錄屏隱藏 ARC。
- (void)rebuildARCContent;
- (CGFloat)addARCSectionLabel:(const char *)title fromY:(CGFloat)y iconSize:(CGFloat)size;
- (CGFloat)addARCIconsForBids:(NSArray *)bids fromY:(CGFloat)y iconSize:(CGFloat)size tagBase:(NSInteger)tagBase action:(SEL)action isSearchResult:(BOOL)isSearchResult;
- (void)handleARCSearchDone:(UITextField *)textField;
- (UIButton *)arcIconButtonForIndex:(int)idx atY:(CGFloat)y size:(CGFloat)size;
- (UIButton *)arcIconButtonForBundleID:(const char *)bid name:(const char *)name tag:(NSInteger)tag action:(SEL)action atY:(CGFloat)y size:(CGFloat)size isSearchResult:(BOOL)isSearchResult;
- (void)handleARCSearchChanged:(UITextField *)textField;
- (void)handleARCSearchResultButton:(UIButton *)sender;
- (void)handleARCIconLongPress:(UILongPressGestureRecognizer *)recognizer;
- (void)handleGameModeSwitch:(UISwitch *)sender;
- (void)launchTrio;
- (void)launchTrioStep;
- (void)showNotificationBannerForName:(const char *)name;
- (void)showNotificationBannerWithText:(const char *)text;
- (void)openAppFullscreen:(const char *)bundleID;
- (void)handleScreenCaptureChanged:(NSNotification *)note;
// v42：控制條新鈕（釘選/透明度）+ 尺寸預設 + 手勢自定義（綁細條）。
- (void)handlePinButton:(UIButton *)sender;
- (void)handleOpacityButton:(UIButton *)sender;
- (void)handleOpacitySlider:(UISlider *)sender;
- (void)handleOpacitySliderEnded:(UISlider *)sender;
- (void)handleSizePresetButton:(UIButton *)sender;
- (void)handleGestureTripleTap:(UITapGestureRecognizer *)recognizer;
- (void)handleGestureSwipeVertical:(UISwipeGestureRecognizer *)recognizer;
- (void)handleGestureSwipeHorizontal:(UISwipeGestureRecognizer *)recognizer;
- (void)handleGestureTwoFingerTap:(UITapGestureRecognizer *)recognizer;
- (void)performGestureAction:(const char *)action;
- (void)resizeActiveWindowToFrame:(CGRect)frame;
// v42：懸浮球、演示模式小點、底部任務欄、ARC 設置入口與演示開關、
// 智能配對、鍵盤上移、設定卡片（見下面卡片段）。
- (void)handleFloatBallTap:(UITapGestureRecognizer *)recognizer;
- (void)handleFloatBallDrag:(UIPanGestureRecognizer *)recognizer;
- (void)handleDemoDotTap:(UITapGestureRecognizer *)recognizer;
- (void)handleTaskbarButton:(UIButton *)sender;
- (void)handleARCSettingsButton:(id)sender;
- (void)handleARCPairButton:(UIButton *)sender;
- (void)handleDemoModeSwitch:(UISwitch *)sender;
- (void)openPairWithBundleIDs:(const char *)mainBid mainName:(const char *)mainName sideBid:(const char *)sideBid sideName:(const char *)sideName;
- (void)openThreeScreenFromEdge;
- (void)checkPendingPairOpen;
- (void)handleKeyboardWillShow:(NSNotification *)note;
- (void)handleKeyboardWillHide:(NSNotification *)note;
// v42：浮窗設定卡片（ARC 裡「設置」開；白卡+金邊+龍頭+版本；
// 點外面/X 收起；五段同系統設定頁；表格走 GHLSSLauncher 自己當
// 資料源/代理；頭像點一下試 PHPicker（探針），失敗退回設定頁指引）。
- (void)showSettingsCard;
- (void)dismissSettingsCard;
- (void)rebuildSettingsCard;
- (void)handleSettingsCardBackgroundTap:(UITapGestureRecognizer *)recognizer;
- (void)handleSettingsCardClose:(id)sender;
- (void)handleSettingsCardAvatarTap:(UITapGestureRecognizer *)recognizer;
- (void)handleSettingsCardSwitch:(UISwitch *)sender;
- (void)handleSettingsCardSlider:(UISlider *)sender;
- (void)handleSettingsCardSliderEnded:(UISlider *)sender;
- (void)handleSettingsCardSegmented:(UISegmentedControl *)sender;
- (void)handleSettingsCardPairButtonForAction:(int)action;
- (void)handleSettingsCardLogRefresh:(id)sender;
- (void)handleSettingsCardLogClear:(id)sender;
- (void)handleSettingsCardLogShare:(id)sender;
- (void)showSettingsCardAlert:(const char *)title message:(const char *)message;
- (void)refreshSettingsCardLogView;
- (void)handleSettingsCardActionRow:(int)row;
- (void)picker:(id)picker didFinishPicking:(NSArray *)results;
@end

// 窗与状态要一直留着（静态变量拿着，不会被释放）。
static UIWindow *GHLSSStripWindow = nil;
static UIWindow *GHLSSLauncherWindow = nil;
static UIScrollView *GHLSSLauncherScrollView = nil; // v41：ARC 的滾動內容區（搜索/三段/常用三開/遊戲模式都在裡面重建）。
static UITextField *GHLSSLauncherSearchField = nil; // v41：ARC 頂上的搜索框。
static char GHLSSAppPickerBids[256][128]; // v41：選 App 頁每一行的 bundleID（開關 tag = 行號）。
static int GHLSSAppPickerCount = 0;
static BOOL GHLSSDividerDragDisabled = NO; // v41：這次分隔線拖動被調度設定關掉了（Began 時讀一次）。
static UIScreenEdgePanGestureRecognizer *GHLSSLauncherEdgePan = nil; // v40：感应带上的右/左边缘滑动手势（跟小窗位置设定走，见 GHLSSUpdateStripPosition）。
static GHLSSLauncher *GHLSSLauncherShared = nil;
static BOOL GHLSSLauncherVisible = NO;
// 上一次边缘滑动的时间（CFAbsoluteTime），用来做"滑两次才开"。
static double GHLSSLastSwipeTime = 0;

// 5.2 托管悬浮窗的状态（一个窗，见 V5_DESIGN.md §5.2）。
static UIWindow *GHLSSHostedWindow = nil;
static FBScene *GHLSSHostedScene = nil;
static _UIScenePresenter *GHLSSHostedPresenter = nil;
// v38：托管已有主 scene 的 layer host view（没有 presenter 时用它；
// 见文件头 v38 节第 1 项）。presenter 与 layerHostView 有且只有一个
// 非空——presenter!=nil 走新建 scene 的老路，layerHostView!=nil 走
// 托管已有主 scene 的新路。
static UIView *GHLSSHostedLayerHostView = nil;
// v38：窗顶上的 16pt 透明细条（拖动窗 + 点它展开/收起控制条，见
// 文件头 v38 节第 2 项）。它是 container 的子视图，跟着窗走。
static UIView *GHLSSHostedTopStrip = nil;
// v38：哆啦A夢鈕单独的小窗（56x56，右边缘、竖直居中，见文件头
// v38 节第 3 项）。感应带仍是 24pt 全高，只留右边缘滑动手势。
static UIWindow *GHLSSDoraemonButtonWindow = nil;
static UIButton *GHLSSDoraemonButton = nil;
static UIView *GHLSSHostedContainer = nil;
static UIView *GHLSSHostedTitleBar = nil;
static UILabel *GHLSSHostedTitleLabel = nil;
static UIView *GHLSSHostedContentView = nil;
static UIView *GHLSSHostedResizeHandle = nil;
static UIView *GHLSSHostedSideDivider = nil; // v41：三屏側窗內緣的分隔線（16pt，拖動調側窗寬度；只在側窗時存在）。
static BOOL GHLSSHostedIsSideDock = NO; // v41：活動窗是不是三屏側窗。
static BOOL GHLSSForceThreeScreenOnce = NO; // v41：ARC 打開方式選「三屏」時，下一次開窗強制走側窗（一次性的，用完清掉）。
static NSString *GHLSSHostedSceneID = nil;
static char GHLSSHostedBundleID[128] = {0};
static int GHLSSHostedPid = 0;
static BOOL GHLSSHostedMinimized = NO;
static BOOL GHLSSHostedLaunching = NO;

// v38：每窗一个 scaleRatio（反向耦合缩放，见文件头 v38 节）。
// 活动窗的 scale 存在这里；切走时存缓存、切回来时读缓存。
// 计算器默认 0.77（窗 320x737），别的 App 默认 1.0。
static CGFloat GHLSSHostedScaleRatio = 1.0;
// 标题栏的缩放按钮（±）与滑杆条（UISlider + 百分比），见 buildHostedWindow。
static UIButton *GHLSSHostedScaleButton = nil;
static UIView *GHLSSHostedScaleSliderBar = nil;
static UISlider *GHLSSHostedScaleSlider = nil;
static UILabel *GHLSSHostedScaleLabel = nil;
// v38：frame 更新防抖的令牌（FBAL 的 resizeWindowWithFrame 做法）。
// 每次调缩放就 +1、0.05 秒后只跑最新的一次。
static int GHLSSScaleDebounceToken = 0;

// v32：锁屏时临时藏窗——悬浮窗是不是被锁屏藏起来的（不是被最小化）。
// 只在"开着"时锁屏才设 YES；解锁时只有它是 YES 才把窗重新显示出来。
// 最小化着的窗本来就藏着，解锁时不碰它（等用户点恢复）。
static BOOL GHLSSHostedHiddenByLock = NO;

// v35：每 App 一个悬浮窗的缓存——一个 SpringBoard 会话里永远不销毁
// scene（见文件头 v35 节）。关窗（X）与切走都只藏窗 + 推后台，不
// 销毁；切回来直接复用缓存里的 scene + presenter + 窗。
// v40：一次可以显示多个窗（5.3 多窗）。活动窗仍用原来那套静态量
//（GHLSSHostedWindow 等），是「最近互动的窗」；所有现成路径（关窗、
// 最小化、恢复、锁屏回调、重试、拖动、缩放）都先把活动量切到「手势
// 所属的窗」再做事（GHLSSSetActiveToWindow），原样不动；新窗创建时
// 不再藏旧窗，旧窗留在原地、层级降回基础。
// 平行静态数组（强引用，ARC 安全）：不用 struct 存对象指针（ARC 不
// 准 struct 里放强引用对象，__unsafe_unretained 又怕对象被系统释放
// 后成野指针——SpringBoard 里野指针就是安全模式）；数组是静态量，
// 可以强引用，缓存里的对象在会话里一直活着。sceneID 也放数组里
//（NSString*，强引用），bundleID 放 char 数组（和原来一样）。
static UIWindow *GHLSSCacheWindows[GHLSS_APP_COUNT];
static FBScene *GHLSSCacheScenes[GHLSS_APP_COUNT];
static _UIScenePresenter *GHLSSCachePresenters[GHLSS_APP_COUNT];
// v38：layer host view 与顶条的缓存（和 presenter 数组平行；
// layer-host 的项 presenter 是 nil，presenter 的项 layerHostView
// 是 nil——复用守卫与销毁函数靠这个分叉）。
static UIView *GHLSSCacheLayerHostViews[GHLSS_APP_COUNT];
static UIView *GHLSSCacheTopStrips[GHLSS_APP_COUNT];
// v41：貼邊 peek 的點按層與小 X（收起時蓋在宿主窗上：點整截恢復窗，
// 點 X 徹底關掉；恢復/關窗時藏起來，不另建小卡窗——peek 就是宿主窗
// 本身縮到邊緣）。三屏側窗旗標 + 分隔線視圖（與其他平行數組同做法）。
static UIButton *GHLSSPeekTapOverlays[GHLSS_APP_COUNT];
static UIButton *GHLSSPeekCloseButtons[GHLSS_APP_COUNT];
static BOOL GHLSSCacheIsSideDock[GHLSS_APP_COUNT];
static UIView *GHLSSCacheSideDividers[GHLSS_APP_COUNT];
// v41：ARC 的搜索字串（UITextField 的即時篩選；空字串 = 顯示三段）、
// 搜索結果的 bundleID（tag 1000+ 的按鈕對應這裡的第幾筆）、常用三開
// 的待開清單（一次最多 3 個，順序開，中間等上一個建完）。
static NSString *GHLSSARCSearchText = nil;
static char GHLSSARCSearchResults[64][128];
static int GHLSSARCSearchResultCount = 0;
static char GHLSSPendingTrio[3][128];
static int GHLSSPendingTrioCount = 0;
static int GHLSSPendingTrioNext = 0;
static int GHLSSPendingTrioRetries = 0;
// v41：選 App 頁的窗（ARC 裡「＋」開的已安裝 App 清單；層級 Alert - 1）。
static UIWindow *GHLSSAppPickerWindow = nil;
// v41：通知橫幅的窗（新窗建好時短暫顯示「已打開 <App>」，自動藏）。
static UIWindow *GHLSSNotificationBannerWindow = nil;
static UIWindow *GHLSSDimOverlayWindow; // v40：点窗外事件的阴影背景窗（Alert - 4.5，主屏之上、感应带/哆啦A夢鈕之下、宿主窗之下；开关开着、且有浮窗看得见时显示）
static BOOL GHLSSDragDockLeft = NO; // v40：这次拖动贴边收起往哪边（Began 时读一次位置设定，拖动中不变——每动一下都读 prefs 太费）。
static CGFloat GHLSSDragSafeDistance = 50.0; // v40：这次拖动的安全距离（Began 时读一次，同上）。
static BOOL GHLSSDragDisabled = NO; // v41：這次拖動被調度設定關掉了（Began 時讀一次浮窗拖動手勢開關）。
static BOOL GHLSSDoraemonLongPressed = NO; // v40：哆啦A夢鈕刚被长按过（长按关全部窗；点按处理里看到它就 suppress 启动器、清掉；拖动钮时也清掉——长按后拖出按钮外、TouchUpInside 不触发时的兜底）。
static UIView *GHLSSCacheContainers[GHLSS_APP_COUNT];
static UIView *GHLSSCacheTitleBars[GHLSS_APP_COUNT];
static UILabel *GHLSSCacheTitleLabels[GHLSS_APP_COUNT];
static UIView *GHLSSCacheContentViews[GHLSS_APP_COUNT];
static UIView *GHLSSCacheResizeHandles[GHLSS_APP_COUNT];
static NSString *GHLSSCacheSceneIDs[GHLSS_APP_COUNT];
static char GHLSSCacheBundleIDs[GHLSS_APP_COUNT][128];
static int GHLSSCachePids[GHLSS_APP_COUNT];
static BOOL GHLSSCacheMinimized[GHLSS_APP_COUNT];
static BOOL GHLSSCacheHiddenByLock[GHLSS_APP_COUNT];
// v38：每 App 的 scaleRatio + 缩放 UI（和上面那套平行数组同一做法）。
static CGFloat GHLSSCacheScaleRatios[GHLSS_APP_COUNT];
static UIButton *GHLSSCacheScaleButtons[GHLSS_APP_COUNT];
static UIView *GHLSSCacheScaleSliderBars[GHLSS_APP_COUNT];
static UISlider *GHLSSCacheScaleSliders[GHLSS_APP_COUNT];
static UILabel *GHLSSCacheScaleLabels[GHLSS_APP_COUNT];
// v42：每 App 的透明度滑桿條（跟縮放條同一做法）+ 釘選鈕（控制條裡）。
static UIView *GHLSSCacheOpacitySliderBars[GHLSS_APP_COUNT];
static UISlider *GHLSSCacheOpacitySliders[GHLSS_APP_COUNT];
static UILabel *GHLSSCacheOpacityLabels[GHLSS_APP_COUNT];
static UIButton *GHLSSCachePinButtons[GHLSS_APP_COUNT];
static UIButton *GHLSSCacheOpacityButtons[GHLSS_APP_COUNT];
// v42：演示模式藏起來的 peek（解演示時只恢復這些，不碰本來就藏的）。
static BOOL GHLSSCacheHiddenByDemo[GHLSS_APP_COUNT];
// v42：底部任務欄、懸浮球、演示模式小點、設定卡片（見下面宣告）。
static UIWindow *GHLSSSettingsTaskbarWindow = nil;
static UIWindow *GHLSSFloatBallWindow = nil;
static UIButton *GHLSSFloatBallButton = nil;
static UIWindow *GHLSSDemoDotWindow = nil;
static BOOL GHLSSDemoModeApplied = NO;
static BOOL GHLSSLowBatteryDocked = NO;
static int GHLSSPeriodicTickCount = 0;
static BOOL GHLSSKeyboardShifted = NO;
static CGRect GHLSSKeyboardSavedFrame = {{0, 0}, {0, 0}};
// v42：配對記錄用——上一個開著的窗的 bundleID（開新窗時記配對用）。
static char GHLSSPairPrevBid[128] = {0};
// v42：設定卡片的窗/表/頁/頭像/背景（卡片只讀存好的圖，見下面）。
static UIWindow *GHLSSSettingsCardWindow = nil;
static UITableView *GHLSSSettingsCardTable = nil;
static UITextView *GHLSSSettingsCardLogView = nil;
static UIView *GHLSSSettingsCardLogToolbar = nil;
static int GHLSSSettingsCardPage = 0;
static UIImageView *GHLSSSettingsCardAvatarView = nil;
static UIImageView *GHLSSSettingsCardBgView = nil;
static UIView *GHLSSSettingsCardOverlayView = nil;
// v42：設定卡片的表格資料（每頁重建；行結構見 rebuildSettingsCard）。
typedef struct {
int type;
char key[64];
char title[64];
char subtitle[160];
char values[96];
int page;
int action;
double minValue;
double maxValue;
double defaultValue;
} GHLSSCardRow;
static GHLSSCardRow GHLSSSettingsCardRows[40];
static int GHLSSSettingsCardRowCount = 0;
// v42：ARC 配對推薦行暫存（主/配 App 的 bundleID，點了成對開）。
static char GHLSSARCPairMain[128] = {0};
static char GHLSSARCPairOther[128] = {0};
// v42：側窗分隔線當次厚度（建窗時讀設定記下，拖動時用同一份）。
static CGFloat GHLSSHostedSideDividerThickness = 16.0;
// v42：透明度滑桿條的活動量（跟縮放條同一做法）。
static UIView *GHLSSHostedOpacitySliderBar = nil;
static UISlider *GHLSSHostedOpacitySlider = nil;
static UILabel *GHLSSHostedOpacityLabel = nil;
static UIButton *GHLSSHostedPinButton = nil;
static UIButton *GHLSSHostedOpacityButton = nil;
// 当前活动的是缓存里的第几个 App（-1 = 没有活动窗）。
static int GHLSSActiveAppIndex = -1;

// v38：默认 scaleRatio（下面定义；GHLSSLoadCacheToActive 要用，先声明）。
static CGFloat GHLSSDefaultScaleRatioForBundleID(const char *bundleID);
// v41：先声明（下面定义；GHLSSBringWindowToFront 要用，先声明）。
static BOOL GHLSSReadGameModeEnabled(void);
// v41：先声明（下面定义；GHLSSIsEdgeSwipeLeft 等讀值 helper 要用，先声明）。
static BOOL GHLSSIsWindowPositionLeft(void);
// v42：先声明（下面定义；%ctor 与各处要用，先声明）。
static void GHLSSApplyDemoMode(void);
static void GHLSSUpdateTaskbar(void);
static void GHLSSUpdateDoraemonVisibilityForFullscreen(void);
static void GHLSSCheckLowBattery(void);
static void GHLSSSchedulePeriodicTick(void);
static void GHLSSSaveRestoreList(void);
static void GHLSSRecordPair(const char *bidA, const char *bidB);
static BOOL GHLSSIsWindowPinned(const char *bundleID);
static NSArray *GHLSSReadIDList(const char *key);
static void GHLSSWriteIDList(const char *key, NSArray *ids);
static BOOL GHLSSListContainsBid(NSArray *ids, const char *bundleID);
static UIImage *GHLSSLoadCardAvatarImage(void);
static UIImage *GHLSSLoadCardBgImage(void);
static NSString *GHLSSCardImagePath(BOOL isAvatar);

// bundleID → 启动器下标（0–4），找不到返回 -1。
static int GHLSSAppIndexForBundleID(const char *bundleID) {
if (!bundleID) return -1;
for (int i = 0; i < GHLSS_APP_COUNT; i++) {
if (strcmp(GHLSSAppBundleIDs[i], bundleID) == 0) return i;
}
return -1;
}

// 把活动量存进缓存（切走 / 新窗建成后调；调用前活动量必须是那个 App 的）。
static void GHLSSSaveActiveToCache(void) {
if (GHLSSActiveAppIndex < 0 || GHLSSActiveAppIndex >= GHLSS_APP_COUNT) return;
int i = GHLSSActiveAppIndex;
GHLSSCacheWindows[i] = GHLSSHostedWindow;
GHLSSCacheScenes[i] = GHLSSHostedScene;
GHLSSCachePresenters[i] = GHLSSHostedPresenter;
GHLSSCacheLayerHostViews[i] = GHLSSHostedLayerHostView;
GHLSSCacheTopStrips[i] = GHLSSHostedTopStrip;
GHLSSCacheContainers[i] = GHLSSHostedContainer;
GHLSSCacheTitleBars[i] = GHLSSHostedTitleBar;
GHLSSCacheTitleLabels[i] = GHLSSHostedTitleLabel;
GHLSSCacheContentViews[i] = GHLSSHostedContentView;
GHLSSCacheResizeHandles[i] = GHLSSHostedResizeHandle;
GHLSSCacheSideDividers[i] = GHLSSHostedSideDivider;
GHLSSCacheIsSideDock[i] = GHLSSHostedIsSideDock;
GHLSSCacheSceneIDs[i] = GHLSSHostedSceneID;
strncpy(GHLSSCacheBundleIDs[i], GHLSSHostedBundleID, sizeof(GHLSSCacheBundleIDs[i]) - 1);
GHLSSCacheBundleIDs[i][sizeof(GHLSSCacheBundleIDs[i]) - 1] = '\0';
GHLSSCachePids[i] = GHLSSHostedPid;
GHLSSCacheMinimized[i] = GHLSSHostedMinimized;
GHLSSCacheHiddenByLock[i] = GHLSSHostedHiddenByLock;
GHLSSCacheScaleRatios[i] = GHLSSHostedScaleRatio;
GHLSSCacheScaleButtons[i] = GHLSSHostedScaleButton;
GHLSSCacheScaleSliderBars[i] = GHLSSHostedScaleSliderBar;
GHLSSCacheScaleSliders[i] = GHLSSHostedScaleSlider;
GHLSSCacheScaleLabels[i] = GHLSSHostedScaleLabel;
// v42：透明度滑桿條 + 釘選鈕跟著同一份緩存走。
GHLSSCacheOpacitySliderBars[i] = GHLSSHostedOpacitySliderBar;
GHLSSCacheOpacitySliders[i] = GHLSSHostedOpacitySlider;
GHLSSCacheOpacityLabels[i] = GHLSSHostedOpacityLabel;
GHLSSCachePinButtons[i] = GHLSSHostedPinButton;
GHLSSCacheOpacityButtons[i] = GHLSSHostedOpacityButton;
}

// 把缓存第 idx 项装回活动量（切回来复用时调）。
static void GHLSSLoadCacheToActive(int idx) {
if (idx < 0 || idx >= GHLSS_APP_COUNT) return;
GHLSSHostedWindow = GHLSSCacheWindows[idx];
GHLSSHostedScene = GHLSSCacheScenes[idx];
GHLSSHostedPresenter = GHLSSCachePresenters[idx];
GHLSSHostedLayerHostView = GHLSSCacheLayerHostViews[idx];
GHLSSHostedTopStrip = GHLSSCacheTopStrips[idx];
GHLSSHostedContainer = GHLSSCacheContainers[idx];
GHLSSHostedTitleBar = GHLSSCacheTitleBars[idx];
GHLSSHostedTitleLabel = GHLSSCacheTitleLabels[idx];
GHLSSHostedContentView = GHLSSCacheContentViews[idx];
GHLSSHostedResizeHandle = GHLSSCacheResizeHandles[idx];
GHLSSHostedSideDivider = GHLSSCacheSideDividers[idx];
GHLSSHostedIsSideDock = GHLSSCacheIsSideDock[idx];
GHLSSHostedSceneID = GHLSSCacheSceneIDs[idx];
strncpy(GHLSSHostedBundleID, GHLSSCacheBundleIDs[idx], sizeof(GHLSSHostedBundleID) - 1);
GHLSSHostedBundleID[sizeof(GHLSSHostedBundleID) - 1] = '\0';
GHLSSHostedPid = GHLSSCachePids[idx];
GHLSSHostedMinimized = GHLSSCacheMinimized[idx];
GHLSSHostedHiddenByLock = GHLSSCacheHiddenByLock[idx];
GHLSSHostedScaleRatio = GHLSSCacheScaleRatios[idx];
if (GHLSSHostedScaleRatio <= 0) GHLSSHostedScaleRatio = GHLSSDefaultScaleRatioForBundleID(GHLSSCacheBundleIDs[idx]);
GHLSSHostedScaleButton = GHLSSCacheScaleButtons[idx];
GHLSSHostedScaleSliderBar = GHLSSCacheScaleSliderBars[idx];
GHLSSHostedScaleSlider = GHLSSCacheScaleSliders[idx];
GHLSSHostedScaleLabel = GHLSSCacheScaleLabels[idx];
// v42：透明度滑桿條 + 釘選鈕跟著同一份緩存走。
GHLSSHostedOpacitySliderBar = GHLSSCacheOpacitySliderBars[idx];
GHLSSHostedOpacitySlider = GHLSSCacheOpacitySliders[idx];
GHLSSHostedOpacityLabel = GHLSSCacheOpacityLabels[idx];
GHLSSHostedPinButton = GHLSSCachePinButtons[idx];
GHLSSHostedOpacityButton = GHLSSCacheOpacityButtons[idx];
GHLSSActiveAppIndex = idx;
}

// 清活动量（切走时存完缓存后调；缓存里的指针不受影响）。
static void GHLSSClearActive(void) {
GHLSSHostedWindow = nil;
GHLSSHostedScene = nil;
GHLSSHostedPresenter = nil;
GHLSSHostedLayerHostView = nil;
GHLSSHostedTopStrip = nil;
GHLSSHostedContainer = nil;
GHLSSHostedTitleBar = nil;
GHLSSHostedTitleLabel = nil;
GHLSSHostedContentView = nil;
GHLSSHostedResizeHandle = nil;
GHLSSHostedSideDivider = nil;
GHLSSHostedIsSideDock = NO;
GHLSSHostedSceneID = nil;
GHLSSHostedBundleID[0] = '\0';
GHLSSHostedPid = 0;
GHLSSHostedMinimized = NO;
GHLSSHostedHiddenByLock = NO;
GHLSSHostedScaleRatio = 1.0;
GHLSSHostedScaleButton = nil;
GHLSSHostedScaleSliderBar = nil;
GHLSSHostedScaleSlider = nil;
GHLSSHostedScaleLabel = nil;
// v42：透明度滑桿條 + 釘選鈕一起清。
GHLSSHostedOpacitySliderBar = nil;
GHLSSHostedOpacitySlider = nil;
GHLSSHostedOpacityLabel = nil;
GHLSSHostedPinButton = nil;
GHLSSHostedOpacityButton = nil;
GHLSSActiveAppIndex = -1;
}

// v35：销毁缓存里第 idx 项的 scene + presenter。只在复用守卫判旧时
// 调（进程死了：pid 对不上或 presenter/view 没了）。死进程留不住
// 客户端残留，销毁后重建同一固定 ID 应该是干净的。切走与关窗永远
// 不调这里（只藏窗）。若那项正好是活动窗，也顺手清活动量。
// v38：layer-host 的项分叉——它的 scene 是 App 自己的主 scene，
// **永远不调 destroyScene**（销毁会杀掉 App 的界面），也没有
// presenter 可 deactivate/invalidate；只清缓存引用（窗藏起来、
// 指针全清），App 自己留着跑。复用守卫判旧时才调这里（进程换了
// 或 view 没了，旧主 scene 已死，清引用是安全的）。
// v41 前向声明：貼邊 peek 收掉（定义在后面工具函数区；销毁缓存项时也要
// 收掉对应的 peek，不然死进程的舊窗會一直貼在邊緣）。
static void GHLSSHideDockPeekForIndex(int idx);

static void GHLSSDestroyCachedEntryAtIndex(int idx) {
if (idx < 0 || idx >= GHLSS_APP_COUNT) return;
if (!GHLSSCacheScenes[idx] && !GHLSSCacheWindows[idx]) return;
if (GHLSSCacheWindows[idx]) GHLSSCacheWindows[idx].hidden = YES;
// v38：layer-host 的项（有 layerHostView、没有 presenter）只清引用。
if (GHLSSCacheLayerHostViews[idx] && !GHLSSCachePresenters[idx]) {
GHLSSLogLine("v43 layer host entry cleared (scene kept)");
} else {
@try {
if (GHLSSCacheSceneIDs[idx]) {
char dbuf[256];
snprintf(dbuf, sizeof(dbuf), "v43 destroying scene %s", [GHLSSCacheSceneIDs[idx] UTF8String]);
GHLSSLogLine(dbuf);
[[FBSceneManager sharedInstance] destroyScene:GHLSSCacheSceneIDs[idx] withTransitionContext:nil];
}
if (GHLSSCachePresenters[idx]) {
[GHLSSCachePresenters[idx] deactivate];
[GHLSSCachePresenters[idx] invalidate];
}
} @catch (NSException *e) {
(void)e;
GHLSSLogLine("v43 destroy failed");
}
}
GHLSSCacheWindows[idx] = nil;
GHLSSCacheScenes[idx] = nil;
GHLSSCachePresenters[idx] = nil;
GHLSSCacheLayerHostViews[idx] = nil;
GHLSSCacheTopStrips[idx] = nil;
GHLSSCacheContainers[idx] = nil;
GHLSSCacheTitleBars[idx] = nil;
GHLSSCacheTitleLabels[idx] = nil;
GHLSSCacheContentViews[idx] = nil;
GHLSSCacheResizeHandles[idx] = nil;
GHLSSCacheSideDividers[idx] = nil;
GHLSSCacheIsSideDock[idx] = NO;
GHLSSPeekTapOverlays[idx] = nil;
GHLSSPeekCloseButtons[idx] = nil;
GHLSSCacheSceneIDs[idx] = nil;
GHLSSCacheBundleIDs[idx][0] = '\0';
GHLSSCachePids[idx] = 0;
GHLSSCacheMinimized[idx] = NO;
GHLSSCacheHiddenByLock[idx] = NO;
GHLSSCacheScaleRatios[idx] = 1.0;
GHLSSCacheScaleButtons[idx] = nil;
GHLSSCacheScaleSliderBars[idx] = nil;
GHLSSCacheScaleSliders[idx] = nil;
GHLSSCacheScaleLabels[idx] = nil;
// v42：透明度滑桿條 + 釘選鈕 + 演示藏旗標一起清。
GHLSSCacheOpacitySliderBars[idx] = nil;
GHLSSCacheOpacitySliders[idx] = nil;
GHLSSCacheOpacityLabels[idx] = nil;
GHLSSCachePinButtons[idx] = nil;
GHLSSCacheOpacityButtons[idx] = nil;
GHLSSCacheHiddenByDemo[idx] = NO;
// v41：销毁缓存项时收掉对应的貼邊 peek（死进程的舊窗不能留着）。
GHLSSHideDockPeekForIndex(idx);
if (idx == GHLSSActiveAppIndex) {
GHLSSClearActive();
}
GHLSSLogLine("v43 scene destroyed");
}

// v31：把 hosted scene 推回后台（foreground=NO + backgrounded=YES）。
// 最小化、关窗与锁屏三处共用。只推 settings，不动 presenter（只在
// 销毁 scene 时才 deactivate；临时后台化就 deactivate 很可能拆掉
// presentationView）。
// 单独包 @try/@catch，出错只记一行日志。logLine 是调用处传进来的
// 日志行（最小化与锁屏各记各的）。
static void GHLSSBackgroundHostedScene(const char *logLine) {
if (!GHLSSHostedScene) return;
@try {
[GHLSSHostedScene updateSettingsWithBlock:^(UIMutableApplicationSceneSettings *settings) {
settings.foreground = NO;
if ([settings respondsToSelector:@selector(setBackgrounded:)]) {
settings.backgrounded = YES;
}
}];
GHLSSLogLine(logLine);
} @catch (NSException *e) {
(void)e;
GHLSSLogLine("v43 scene background failed");
}
}

// v38：悬浮窗的尺寸——没有标题栏了，内容区就是整个窗；圆角 35。
// 一般 App 内容 350x757（85% 宽，757 是按屏高宽比算的：350/414×
// 896≈757，和屏幕同宽高比——已有主 scene（414x896）按宽缩放正好
// 贴边填满；新建 scene 的 App 按 350x757 重排版）。计算器内容仍
// 是 320x693（窗 320x693，之前 320x737 是含 44pt 标题栏的总高，
// 内容几何不变、scale 仍是 0.77），宽用下面的 CALC_W。控制条
// 36pt（默认藏着）、顶条 24pt（透明细条；v40 从 16 加宽到 24——皇上
// 11:34：v39 的 16pt 细条太细、太透明，找不到地方抓；建窗与 resize 都用
// 这个常量，会自动一起改；pill 72x6、alpha 0.7、垂直置中，细条保持透明——
// App 内容透出来；控制条 36pt 不动、滑杆条 y=36 不动）。
#define GHLSS_HOSTED_CONTENT_W 350.0
#define GHLSS_HOSTED_CONTENT_H 757.0
#define GHLSS_HOSTED_CALC_W 320.0
#define GHLSS_HOSTED_CONTROL_H 36.0
#define GHLSS_HOSTED_STRIP_H 24.0
// v41：圓角改走設定（cornerRadius，預設 35；上面三處已改讀設定）。

// v40：多窗层级（锁屏 2000 之下）：宿主窗基础 Alert - 2（1998）、
// 带到最前 Alert - 1.75（1998.25）、贴边小卡 Alert - 1.5（1998.5）、
// 阴影背景 Alert - 4.5（1995.5，在主屏之上、感应带/哆啦A夢鈕 1996 之下、
// 宿主窗之下——点浮窗本身、点哆啦A夢鈕、滑感应带都不受影响）。
#define GHLSS_HOSTED_BASE_LEVEL (UIWindowLevelAlert - 2.0)
#define GHLSS_HOSTED_FRONT_LEVEL (UIWindowLevelAlert - 1.75)
#define GHLSS_DOCK_LEVEL (UIWindowLevelAlert - 1.5)
#define GHLSS_DIM_OVERLAY_LEVEL (UIWindowLevelAlert - 4.5)
// v41：遊戲模式的層級——開著時浮窗釘在鎖屏之下允許的最高層級
//（Alert - 0.5，底窗；主窗 Alert - 0.25），蓋過啟動器（1999）與其他
// App；鎖屏（2000）仍在上面，密碼不受影響。
#define GHLSS_GAME_BASE_LEVEL (UIWindowLevelAlert - 0.5)
#define GHLSS_GAME_FRONT_LEVEL (UIWindowLevelAlert - 0.25)
// v41：貼邊 peek 的尺寸（圖 1 的樣子：縮到邊緣、露出一截活內容）。
// 寬 112、高 216，上下疊著排，間距 8。
#define GHLSS_DOCK_PEEK_W 112.0
#define GHLSS_DOCK_PEEK_H 216.0
#define GHLSS_DOCK_PEEK_GAP 8.0
// v41：貼邊 peek 的尺寸在上面（GHLSS_DOCK_PEEK_W/H/GAP）；v40 的
// 68x76 小卡窗已刪（peek 就是宿主窗本身縮到邊緣，不另建卡窗）。
// v40：新窗错位放的步进（每多一个看得见的窗错开 44pt，横竖交错、夹在屏幕里）。
#define GHLSS_NEW_WINDOW_OFFSET 44.0
// v40：拖到右邊緣贴边收起的门槛——放手时窗中心进了右缘 60pt 内才收。
#define GHLSS_DOCK_DRAG_THRESHOLD 60.0

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

// v38：一个 App 的默认 scaleRatio（反向耦合缩放，见文件头 v38 节）。
// 计算器默认 320/屏宽 ≈ 0.77（窗 320x737 的那个缩放，v36 证实过）；
// 别的 App 默认 1.0（scene frame 就是内容尺寸，不缩放）。屏幕尺寸
// 运行时读，不写死 414/896。
static CGFloat GHLSSDefaultScaleRatioForBundleID(const char *bundleID) {
if (bundleID && strcmp(bundleID, "com.apple.calculator") == 0) {
CGSize screenSize = [UIScreen mainScreen].bounds.size;
if (screenSize.width > 0) {
return GHLSS_HOSTED_CALC_W / screenSize.width;
}
}
return 1.0;
}

// v38：scene frame 尺寸 = 内容尺寸 ÷ scale（反向耦合的一半：App 在
// 这个尺寸里排版；另一半是内容区 layer 的 sublayerTransform 缩回）。
// scale<=0 当 1.0 用。计算器：内容 320x693 ÷ 0.77 ≈ 414x896（屏
// 幕尺寸，和 v36 一样）；别的 App：320x480 ÷ 1.0 = 320x480。
static CGSize GHLSSSceneFrameSizeForContentSizeAndScale(CGSize contentSize, CGFloat scale) {
if (scale <= 0) scale = 1.0;
return CGSizeMake(contentSize.width / scale, contentSize.height / scale);
}

// v36：一个 App 的悬浮窗内容区尺寸——计算器拿 (320, 屏高×320/屏宽)
//（按宽缩放 s=320/屏宽≈0.77 时，图层高 896×s≈693，正好放进内容区，
// 左右零白边、按键约 62pt；窗总高 693+44=737，896 高的屏上居中放得
// 下，上下各留约 80pt；运行时算，不写死 414/896）。别的 App 拿
// 320x480（它们按 scene frame 排版，内容区就是 scene frame，已经
// 贴边填满，不用改）。
static CGSize GHLSSHostedContentSizeForBundleID(const char *bundleID) {
if (bundleID && strcmp(bundleID, "com.apple.calculator") == 0) {
CGSize screenSize = [UIScreen mainScreen].bounds.size;
if (screenSize.width > 0) {
return CGSizeMake(GHLSS_HOSTED_CALC_W, screenSize.height * (GHLSS_HOSTED_CALC_W / screenSize.width));
}
}
return CGSizeMake(GHLSS_HOSTED_CONTENT_W, GHLSS_HOSTED_CONTENT_H);
}

// v38：一个 App 的 scene frame 尺寸（默认 scale 下）——计算器拿屏幕
// 尺寸（内容 320x693 ÷ 0.77 ≈ 414x896），别的 App 拿 320x480 内
// 容尺寸。建 scene 时用（初始 settings.frame）。
static CGSize GHLSSSceneFrameSizeForBundleID(const char *bundleID) {
CGSize contentSize = GHLSSHostedContentSizeForBundleID(bundleID);
CGFloat scale = GHLSSDefaultScaleRatioForBundleID(bundleID);
return GHLSSSceneFrameSizeForContentSizeAndScale(contentSize, scale);
}

// v38：找一个 App 已有的主 scene（KonbanXV，MIT，只仿结构、代码
// 原创）。FBSceneManager sharedInstance → object_getIvar 读
// _workspace → object_getIvar 读 _allScenesByID（NSDictionary）→
// 找 identifier 等于固定 sceneID `sceneID:<bundleID>-default` 或含
// bundleID 的那一项，返回 FBScene。找不到返回 nil。每一步都判 nil，
// 任何一步失败就返回 nil（调用处走老路 createScene，不崩、不拦）。
// ivar 名用 class_getInstanceVariable 拿（不用 MSHookIvar 宏——我们
// 不用 Logos hook，改用 <objc/runtime.h> 的 object_getIvar，已在用）。
static FBScene *GHLSSExistingMainSceneForBundleID(const char *bundleID) {
if (!bundleID) return nil;
FBSceneManager *manager = [FBSceneManager sharedInstance];
if (!manager) return nil;
Ivar workspaceIvar = class_getInstanceVariable([FBSceneManager class], "_workspace");
if (!workspaceIvar) return nil;
id workspace = object_getIvar(manager, workspaceIvar);
if (!workspace) return nil;
Ivar scenesIvar = class_getInstanceVariable(object_getClass(workspace), "_allScenesByID");
if (!scenesIvar) return nil;
id scenesDict = object_getIvar(workspace, scenesIvar);
if (!scenesDict || ![scenesDict isKindOfClass:[NSDictionary class]]) return nil;
char idbuf[256];
snprintf(idbuf, sizeof(idbuf), "sceneID:%s-default", bundleID);
NSString *fixedID = [NSString stringWithCString:idbuf encoding:NSUTF8StringEncoding];
NSString *bidStr = [NSString stringWithCString:bundleID encoding:NSUTF8StringEncoding];
if (!fixedID || !bidStr) return nil;
NSDictionary *scenes = (NSDictionary *)scenesDict;
for (id key in [scenes allKeys]) {
if (![key isKindOfClass:[NSString class]]) continue;
NSString *keyStr = (NSString *)key;
if ([keyStr isEqualToString:fixedID] || [keyStr rangeOfString:bidStr].location != NSNotFound) {
id scene = [scenes objectForKey:key];
if (scene && [scene isKindOfClass:[FBScene class]]) return (FBScene *)scene;
}
}
return nil;
}

// v38：layer-host 路的显示 scale（见文件头 v38 节第 1 项）。已有主
// scene 的 frame 是全屏尺寸（运行时读屏幕，不写死 414/896），不能
// 改；要贴边填满，显示 scale = 内容宽 ÷ 屏宽，再乘以用户缩放相对
// 默认的倍数（scaleRatio ÷ 默认 scaleRatio）。一般 App：内容 350
// ÷ 屏宽 414 ≈ 0.845，scaleRatio 默认 1.0，显示 0.845（贴边）；
// 计算器：内容 320 ÷ 414 ≈ 0.77，scaleRatio 默认 0.77，显示 0.77
//（贴边，和 v36/v38 一样）。滑杆把 scaleRatio 拖到 1.5，显示就
// 是 0.845×1.5（放大、裁掉边缘）；拖到 0.5，显示就是 0.845×0.5
//（缩小、留黑边）。和新建 scene 的路（scene frame = 内容 ÷ scale，
// 显示永远是内容尺寸）不一样——layer-host 的 scene frame 改不了，
// 只能靠显示 scale 缩放。
static CGFloat GHLSSLayerHostDisplayScaleForContentSizeAndBundleID(CGSize contentSize, const char *bundleID) {
CGSize screenSize = [UIScreen mainScreen].bounds.size;
if (screenSize.width <= 0 || contentSize.width <= 0) return 1.0;
CGFloat fitScale = contentSize.width / screenSize.width;
CGFloat defaultScale = GHLSSDefaultScaleRatioForBundleID(bundleID);
if (defaultScale <= 0) defaultScale = 1.0;
CGFloat ratio = GHLSSHostedScaleRatio;
if (ratio < 0.5) ratio = 0.5;
if (ratio > 2.0) ratio = 2.0;
return fitScale * (ratio / defaultScale);
}

// v38：反向耦合缩放（仿照 FrontBoardAppLauncher 的做法，见文件头
// v38 节——只仿结构，代码原创）：scene frame = 内容尺寸 ÷ scale，
// 内容区 layer 的 sublayerTransform = CATransform3DMakeScale(scale,
// scale, 1) 把图层缩回窗尺寸。一除一乘，任意 App、任意窗尺寸都填
// 满内容区、贴边；不再有计算器特判。presentationView 的 bounds =
// frame 尺寸、anchorPoint (0,0)、position (0,0)（FBAL 的左上对齐
// 做法）。注意：sublayerTransform 是繞內容區 layer 的 anchorPoint
// 縮，不是繞左上——v38 只設了 presenterView/layerHostView 的錨點，
// 沒設內容區 layer 的錨點（預設中心），scale<1.0 的 App 往右下偏
// 了（見 BUILD_LOG §108）；v39 在建 contentView 時把錨點改 (0,0)。
// pushFrame=YES 时，0.05 秒防抖后把新 frame 推给 scene（FBAL 的
// resizeWindowWithFrame 做法）；建窗时 pushFrame=NO（初始 settings
// 里已经是这个 frame，不用再推一次）。frame 更新时顺带把两个安全
// 区 insets 重设为 0（第 3 项：LiveContainer 窗口模式规则，frame 更
// 新时附带安全区 block）。立即改 bounds + transform（视觉立即跟
// 手），frame 只防抖推一次。触摸由 transform 自动映射。
static void GHLSSApplyScaleToHostedWindow(BOOL pushFrame) {
if (!GHLSSHostedContentView || !GHLSSHostedScene) return;
// v38：layer-host 路（没有 presenter，有 layerHostView）——只改
// view 的 bounds + sublayerTransform，**不推 scene frame**（已有主
// scene 的 frame 就是屏幕尺寸，不能改）。显示 scale 用
// GHLSSLayerHostDisplayScaleForContentSize（内容宽 ÷ 屏宽 × 用户
// 缩放相对默认的倍数）。layer host view 的 bounds = 屏幕尺寸
//（scene 的 frame 尺寸），anchorPoint (0,0)、position (0,0)。
if (GHLSSHostedLayerHostView && !GHLSSHostedPresenter) {
CGSize contentSize = GHLSSHostedContentView.bounds.size;
if (contentSize.width <= 0 || contentSize.height <= 0) return;
CGSize screenSize = [UIScreen mainScreen].bounds.size;
if (screenSize.width <= 0 || screenSize.height <= 0) return;
CGFloat displayScale = GHLSSLayerHostDisplayScaleForContentSizeAndBundleID(contentSize, GHLSSHostedBundleID);
UIView *layerHostView = GHLSSHostedLayerHostView;
layerHostView.bounds = CGRectMake(0, 0, screenSize.width, screenSize.height);
layerHostView.layer.anchorPoint = CGPointMake(0, 0);
layerHostView.layer.position = CGPointMake(0, 0);
// v39：錨點重申為左上（建窗時已設，這裡防萬一被 layout 改回中心）。
GHLSSHostedContentView.layer.anchorPoint = CGPointMake(0, 0);
GHLSSHostedContentView.layer.position = CGPointMake(0, 0);
GHLSSHostedContentView.layer.sublayerTransform = CATransform3DMakeScale(displayScale, displayScale, 1.0);
char buf[128];
snprintf(buf, sizeof(buf), "v43 layer host scaled %d%%", (int)(displayScale * 100.0));
GHLSSLogLine(buf);
// pushFrame 对 layer-host 没有意义（scene frame 不能推），直接返回。
return;
}
if (!GHLSSHostedPresenter || !GHLSSHostedPresenter.presentationView) return;
CGFloat scale = GHLSSHostedScaleRatio;
if (scale < 0.5) scale = 0.5;
if (scale > 2.0) scale = 2.0;
GHLSSHostedScaleRatio = scale;
CGSize contentSize = GHLSSHostedContentView.bounds.size;
if (contentSize.width <= 0 || contentSize.height <= 0) return;
CGSize frameSize = GHLSSSceneFrameSizeForContentSizeAndScale(contentSize, scale);
UIView *presenterView = GHLSSHostedPresenter.presentationView;
presenterView.bounds = CGRectMake(0, 0, frameSize.width, frameSize.height);
presenterView.layer.anchorPoint = CGPointMake(0, 0);
presenterView.layer.position = CGPointMake(0, 0);
// v39：錨點重申為左上（建窗時已設，這裡防萬一被 layout 改回中心）。
GHLSSHostedContentView.layer.anchorPoint = CGPointMake(0, 0);
GHLSSHostedContentView.layer.position = CGPointMake(0, 0);
GHLSSHostedContentView.layer.sublayerTransform = CATransform3DMakeScale(scale, scale, 1.0);
char buf[128];
snprintf(buf, sizeof(buf), "v43 scene scaled %d%%", (int)(scale * 100.0));
GHLSSLogLine(buf);
if (!pushFrame) return;
int token = ++GHLSSScaleDebounceToken;
dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.05 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
if (token != GHLSSScaleDebounceToken) return;
if (!GHLSSHostedScene || !GHLSSHostedContentView) return;
CGSize curContentSize = GHLSSHostedContentView.bounds.size;
CGFloat curScale = GHLSSHostedScaleRatio;
if (curScale <= 0) curScale = 1.0;
CGSize curFrameSize = GHLSSSceneFrameSizeForContentSizeAndScale(curContentSize, curScale);
@try {
[GHLSSHostedScene updateSettingsWithBlock:^(UIMutableApplicationSceneSettings *settings) {
settings.frame = CGRectMake(0, 0, curFrameSize.width, curFrameSize.height);
settings.interfaceOrientation = UIInterfaceOrientationPortrait;
settings.deviceOrientation = UIDeviceOrientationPortrait;
settings.peripheryInsets = UIEdgeInsetsZero;
settings.safeAreaInsetsPortrait = UIEdgeInsetsZero;
}];
char fbuf[128];
snprintf(fbuf, sizeof(fbuf), "v43 scene frame updated %dx%d scale %d%%", (int)curFrameSize.width, (int)curFrameSize.height, (int)(curScale * 100.0));
GHLSSLogLine(fbuf);
} @catch (NSException *e) {
(void)e;
GHLSSLogLine("v43 scene frame update failed");
}
});
}

// ── v40：多窗 + 贴边小卡 + 点窗外事件 + 安全距离 的工具函数 ──

// v40：读一个 prefs BOOL（没有就回默认值）。CFPreferencesAppSynchronize
// 先同步（设置页改完立刻生效，不用等）；零字面量规则：key 与 domain
// 都用 CFStringCreateWithCString 现做；不用通知中心（那个被禁）。
static BOOL GHLSSReadPrefsBool(const char *key, BOOL defaultValue) {
if (!key) return defaultValue;
CFStringRef domain = CFStringCreateWithCString(NULL, "com.guhailong.splitscreen", kCFStringEncodingUTF8);
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

// v40：读一个 prefs 数字（没有/不是数字就回默认值；滑杆存的是 NSNumber）。
static double GHLSSReadPrefsDouble(const char *key, double defaultValue) {
if (!key) return defaultValue;
CFStringRef domain = CFStringCreateWithCString(NULL, "com.guhailong.splitscreen", kCFStringEncodingUTF8);
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

// v40：读一个 prefs 字串（返回 malloc 的 C 字串，调用处 free；
// 没有/不是字串就返回 NULL）。
static char *GHLSSReadPrefsCString(const char *key) {
if (!key) return NULL;
CFStringRef domain = CFStringCreateWithCString(NULL, "com.guhailong.splitscreen", kCFStringEncodingUTF8);
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

// v40：刘海安全距离（prefs 里的 safeDistance，0–100，默认 50；
// 超出范围就夹到 0–100）。
static CGFloat GHLSSReadSafeDistance(void) {
double v = GHLSSReadPrefsDouble("safeDistance", 50.0);
if (v < 0) v = 0;
if (v > 100) v = 100;
return (CGFloat)v;
}

// ── v41：新設定鍵的讀法（全部走上面三個現成 helper；鍵名都是普通
// C 字串，運行時現做，零字面量規則不動） ──
// 浮窗設置：陰影開關（預設開）、圓角滑桿（0–50，預設 35）、豎屏開窗
// 固定中心（預設關——開了新窗一律居中開，不恢復記住的位置；關了才
// 恢復上次位置，保住 v40 第 6 項）、通知橫幅（預設開）。
static BOOL GHLSSReadShadowEnabled(void) {
return GHLSSReadPrefsBool("shadowEnabled", YES);
}
static CGFloat GHLSSReadCornerRadius(void) {
double v = GHLSSReadPrefsDouble("cornerRadius", 35.0);
if (v < 0) v = 0;
if (v > 50) v = 50;
return (CGFloat)v;
}
static BOOL GHLSSReadCenterOnOpen(void) {
return GHLSSReadPrefsBool("centerOnOpen", NO);
}
static BOOL GHLSSReadNotificationBanner(void) {
return GHLSSReadPrefsBool("notificationBanner", YES);
}
// 調度窗口設置：邊緣滑幾次開 ARC（1 或 2，預設 2）、滑哪邊（沒設就跟
// 小窗顯示位置走）、浮窗拖動手勢開關（預設開）、側邊小窗手勢開關
// （管三屏分隔線拖動，預設開）、哆啦A夢雙擊輪切開關（預設開）、
// 長按多久關全部（0.3–1.0 秒，預設 0.5）。
static int GHLSSReadEdgeSwipeCount(void) {
double v = GHLSSReadPrefsDouble("edgeSwipeCount", 2.0);
return (v <= 1.0) ? 1 : 2;
}
static BOOL GHLSSIsEdgeSwipeLeft(void) {
char *side = GHLSSReadPrefsCString("edgeSwipeSide");
BOOL isLeft = NO;
if (side) {
isLeft = (strcmp(side, "left") == 0);
free(side);
} else {
isLeft = GHLSSIsWindowPositionLeft();
}
return isLeft;
}
static BOOL GHLSSReadWindowDragEnabled(void) {
return GHLSSReadPrefsBool("windowDragEnabled", YES);
}
static BOOL GHLSSReadSideWindowGestures(void) {
return GHLSSReadPrefsBool("sideWindowGestures", YES);
}
static BOOL GHLSSReadDoraemonDoubleTapEnabled(void) {
return GHLSSReadPrefsBool("doraemonDoubleTapEnabled", YES);
}
static double GHLSSReadLongPressDuration(void) {
double v = GHLSSReadPrefsDouble("longPressDuration", 0.5);
if (v < 0.3) v = 0.3;
if (v > 1.0) v = 1.0;
return v;
}
// v41：哆啦A夢鈕上次拖到的中心高度（沒設 = -1，%ctor 用居中）。
static double GHLSSReadDoraemonButtonY(void) {
return GHLSSReadPrefsDouble("doraemonButtonY", -1.0);
}
// ── v42：新設定鍵的讀法（全部走上面三個現成 helper） ──
// B1 側窗寬度預設（narrow 25% / medium 30% / wide 40%，預設 medium）。
static CGFloat GHLSSReadSideWidthFraction(void) {
char *v = GHLSSReadPrefsCString("sideWidthPreset");
CGFloat f = 0.30;
if (v) {
if (strcmp(v, "narrow") == 0) f = 0.25;
else if (strcmp(v, "wide") == 0) f = 0.40;
free(v);
}
return f;
}
// B4 分隔線粗細（8/16/24，預設 16）與顏色（gold/gray/clear，預設 gold）。
static CGFloat GHLSSReadSideDividerThickness(void) {
double v = GHLSSReadPrefsDouble("sideDividerThickness", 16.0);
if (v < 8) v = 8;
if (v > 24) v = 24;
return (CGFloat)v;
}
static int GHLSSReadSideDividerColor(void) {
char *v = GHLSSReadPrefsCString("sideDividerColor");
int c = 0;
if (v) {
if (strcmp(v, "gray") == 0) c = 1;
else if (strcmp(v, "clear") == 0) c = 2;
free(v);
}
return c;
}
// B5 邊緣滑動直接開三屏（預設關）。
static BOOL GHLSSReadEdgeSwipeOpensThreeScreen(void) {
return GHLSSReadPrefsBool("edgeSwipeOpensThreeScreen", NO);
}
// B6 側窗圓角（0–50，預設 35）/陰影開關（預設開）/透明度（0–1，預設 0.5）/半徑（0–30，預設 10）。
static CGFloat GHLSSReadSideCornerRadius(void) {
double v = GHLSSReadPrefsDouble("sideCornerRadius", 35.0);
if (v < 0) v = 0;
if (v > 50) v = 50;
return (CGFloat)v;
}
static BOOL GHLSSReadSideShadowEnabled(void) {
return GHLSSReadPrefsBool("sideShadowEnabled", YES);
}
static CGFloat GHLSSReadSideShadowOpacity(void) {
double v = GHLSSReadPrefsDouble("sideShadowOpacity", 0.5);
if (v < 0) v = 0;
if (v > 1) v = 1;
return (CGFloat)v;
}
static CGFloat GHLSSReadSideShadowRadius(void) {
double v = GHLSSReadPrefsDouble("sideShadowRadius", 10.0);
if (v < 0) v = 0;
if (v > 30) v = 30;
return (CGFloat)v;
}
// C1 浮窗大小預設（small 280x600 / medium 350x757 / large 414x800，預設 medium；
// 計算器在 medium 時仍用自己的 320x693，見 buildHostedWindow）。
static int GHLSSReadWindowSizePreset(void) {
char *v = GHLSSReadPrefsCString("windowSizePreset");
int p = 1;
if (v) {
if (strcmp(v, "small") == 0) p = 0;
else if (strcmp(v, "large") == 0) p = 2;
free(v);
}
return p;
}
// C2 某 App 的窗是不是釘選（pinnedWindowIDs 清單裡有它就算；
// 釘住的窗層級提到遊戲最前、別的窗蓋不住）。
static BOOL GHLSSIsWindowPinned(const char *bundleID) {
if (!bundleID || bundleID[0] == '\0') return NO;
return GHLSSListContainsBid(GHLSSReadIDList("pinnedWindowIDs"), bundleID);
}
// C4 重啟後自動恢復浮窗（預設開；scene 撐不過重啟，恢復是重建 scene 重新開 App）。
static BOOL GHLSSReadRestoreWindowsAfterRespring(void) {
return GHLSSReadPrefsBool("restoreWindowsAfterRespring", YES);
}
// C5 全屏時哆啦A夢鈕自動藏（預設開；探針：狀態列隱藏啟發式，見 §115）。
static BOOL GHLSSReadAutoHideDoraemonInFullscreen(void) {
return GHLSSReadPrefsBool("autoHideDoraemonInFullscreen", YES);
}
// C6 鍵盤彈出時浮窗自動上移（Keyboard.plist 的 keyboardAvoidEnabled，預設開；
// 探針：通知可能到不了 SpringBoard，見 §115）。
static BOOL GHLSSReadKeyboardAvoidEnabled(void) {
return GHLSSReadPrefsBool("keyboardAvoidEnabled", YES);
}
// C7 底部任務欄（預設關；開了要 respring 才建欄）。
static BOOL GHLSSReadTaskbarEnabled(void) {
return GHLSSReadPrefsBool("taskbarEnabled", NO);
}
// C8 浮窗透明度：全域預設（0.5–1.0，預設 1.0）與每窗值（winOpacity_<bid>，
// 沒設就走全域；調的是窗的 alpha）。
static CGFloat GHLSSReadWindowOpacityGlobal(void) {
double v = GHLSSReadPrefsDouble("windowOpacityGlobal", 1.0);
if (v < 0.5) v = 0.5;
if (v > 1.0) v = 1.0;
return (CGFloat)v;
}
static CGFloat GHLSSReadWindowOpacityForBundleID(const char *bundleID) {
if (!bundleID || bundleID[0] == '\0') return GHLSSReadWindowOpacityGlobal();
char key[192];
snprintf(key, sizeof(key), "winOpacity_%s", bundleID);
double v = GHLSSReadPrefsDouble(key, -1.0);
if (v < 0) return GHLSSReadWindowOpacityGlobal();
if (v < 0.5) v = 0.5;
if (v > 1.0) v = 1.0;
return (CGFloat)v;
}
// G4 懸浮球（預設關）與球的位置（沒設 = -1，%ctor 用右緣 70% 高）。
static BOOL GHLSSReadFloatBallEnabled(void) {
return GHLSSReadPrefsBool("floatBallEnabled", NO);
}
static double GHLSSReadFloatBallX(void) {
return GHLSSReadPrefsDouble("floatBallX", -1.0);
}
static double GHLSSReadFloatBallY(void) {
return GHLSSReadPrefsDouble("floatBallY", -1.0);
}
// G6 低電量自動收窗（預設開）與閾值（10–30%，預設 20%）。
static BOOL GHLSSReadLowBatteryAutoDock(void) {
return GHLSSReadPrefsBool("lowBatteryAutoDock", YES);
}
static double GHLSSReadLowBatteryThreshold(void) {
double v = GHLSSReadPrefsDouble("lowBatteryThreshold", 20.0);
if (v < 10) v = 10;
if (v > 30) v = 30;
return v;
}
// G8 演示模式（預設關；ARC 與設定主頁同一份鍵）。
static BOOL GHLSSReadDemoModeEnabled(void) {
return GHLSSReadPrefsBool("demoModeEnabled", NO);
}
// F 卡片頭像/背景是不是自訂（檔案在設定目錄固定檔名，見下面）。
static BOOL GHLSSReadCardAvatarCustom(void) {
return GHLSSReadPrefsBool("cardAvatarCustom", NO);
}
static BOOL GHLSSReadCardBgCustom(void) {
return GHLSSReadPrefsBool("cardBgCustom", NO);
}
// 三屏設置：三屏模式開關（預設關）、關三屏同時關側邊小窗（預設關，
// 按 FV 截圖）；ARC 設置：開 ARC（預設開）。
static BOOL GHLSSReadThreeScreenEnabled(void) {
return GHLSSReadPrefsBool("threeScreenEnabled", NO);
}
static BOOL GHLSSReadCloseThreeScreenAlsoClosesSide(void) {
return GHLSSReadPrefsBool("closeThreeScreenAlsoClosesSide", NO);
}
static BOOL GHLSSReadARCEnabled(void) {
return GHLSSReadPrefsBool("arcEnabled", YES);
}
// v41：ARC 打開方式（arcOpenMode，字串：fullscreen / floating /
// threescreen，預設 floating；橫屏下強制 floating）、ARC 圖標大小
// （arcIconSize 40–72，預設 56）、ARC 與邊緣距離（arcEdgeDistance
// 0–60，預設 20）、ARC 列在左/右（arcColumnSide，沒設就跟小窗位置）、
// 顯示已開綠點（arcShowOpenDots，預設開）、顯示 App 名（arcShowNames，
// 預設開）、截圖錄屏隱藏 ARC（arcHideOnScreenshot，預設開）、震動反饋
// （arcHaptics，預設開）、觸控音效（arcTouchSound，預設開）。
static int GHLSSReadARCMenuOpenMode(void) {
char *mode = GHLSSReadPrefsCString("arcOpenMode");
int m = 1;
if (mode) {
if (strcmp(mode, "fullscreen") == 0) m = 0;
else if (strcmp(mode, "threescreen") == 0) m = 2;
free(mode);
}
return m;
}
static CGFloat GHLSSReadARCIconSize(void) {
double v = GHLSSReadPrefsDouble("arcIconSize", 56.0);
if (v < 40) v = 40;
if (v > 72) v = 72;
return (CGFloat)v;
}
static CGFloat GHLSSReadARCEdgeDistance(void) {
double v = GHLSSReadPrefsDouble("arcEdgeDistance", 20.0);
if (v < 0) v = 0;
if (v > 60) v = 60;
return (CGFloat)v;
}
static BOOL GHLSSIsARCColumnLeft(void) {
char *side = GHLSSReadPrefsCString("arcColumnSide");
BOOL isLeft = NO;
if (side) {
isLeft = (strcmp(side, "left") == 0);
free(side);
} else {
isLeft = GHLSSIsWindowPositionLeft();
}
return isLeft;
}
static BOOL GHLSSReadARCShowOpenDots(void) {
return GHLSSReadPrefsBool("arcShowOpenDots", YES);
}
static BOOL GHLSSReadARCShowNames(void) {
return GHLSSReadPrefsBool("arcShowNames", YES);
}
static BOOL GHLSSReadARCHideOnScreenshot(void) {
return GHLSSReadPrefsBool("arcHideOnScreenshot", YES);
}
static BOOL GHLSSReadARCHaptics(void) {
return GHLSSReadPrefsBool("arcHaptics", YES);
}
static BOOL GHLSSReadARCTouchSound(void) {
return GHLSSReadPrefsBool("arcTouchSound", YES);
}
// v41：陰影細項（透明度 0–1 預設 0.5、半徑 0–30 預設 12）、通知橫幅
// 顯示時長（1–3 秒，預設 1.5）、搜索開關與上限（arcSearchEnabled 預設
// 開、searchResultLimit 5–20 預設 12、searchShowsNotInLauncher 預設開）、
// 哆啦A夢鈕大小（44–72 預設 56）、左右邊（doraemonSide，沒設就跟小窗
// 位置）、顯示開關（doraemonVisible 預設開）。鍵盤/相機/桌面圖標三個
// 開關只存偏好（見 BUILD_LOG §113：鍵盤在浮窗內的表現、相機授權、
// 主屏圖標都不是這個開關能直接改的，誠實記為待真機驗證/未實作）。
static CGFloat GHLSSReadShadowOpacity(void) {
double v = GHLSSReadPrefsDouble("shadowOpacity", 0.5);
if (v < 0) v = 0;
if (v > 1) v = 1;
return (CGFloat)v;
}
static CGFloat GHLSSReadShadowRadius(void) {
double v = GHLSSReadPrefsDouble("shadowRadius", 12.0);
if (v < 0) v = 0;
if (v > 30) v = 30;
return (CGFloat)v;
}
static double GHLSSReadBannerDuration(void) {
double v = GHLSSReadPrefsDouble("bannerDuration", 1.5);
if (v < 1.0) v = 1.0;
if (v > 3.0) v = 3.0;
return v;
}
static BOOL GHLSSReadARCSearchEnabled(void) {
return GHLSSReadPrefsBool("arcSearchEnabled", YES);
}
static int GHLSSReadSearchResultLimit(void) {
double v = GHLSSReadPrefsDouble("searchResultLimit", 12.0);
if (v < 5) v = 5;
if (v > 20) v = 20;
return (int)v;
}
static BOOL GHLSSReadSearchShowsNotInLauncher(void) {
return GHLSSReadPrefsBool("searchShowsNotInLauncher", YES);
}
static CGFloat GHLSSReadDoraemonIconSize(void) {
double v = GHLSSReadPrefsDouble("doraemonIconSize", 56.0);
if (v < 44) v = 44;
if (v > 72) v = 72;
return (CGFloat)v;
}
static BOOL GHLSSIsDoraemonSideLeft(void) {
char *side = GHLSSReadPrefsCString("doraemonSide");
BOOL isLeft = NO;
if (side) {
isLeft = (strcmp(side, "left") == 0);
free(side);
} else {
isLeft = GHLSSIsWindowPositionLeft();
}
return isLeft;
}
static BOOL GHLSSReadDoraemonVisible(void) {
return GHLSSReadPrefsBool("doraemonVisible", YES);
}
// v41：keyboardAvoidEnabled / cameraPermissionEnabled /
// desktopIconEnabled 三個鍵只存偏好（設定頁讀寫），主插件裡沒有
// 地方用它們——這裡不寫讀值 helper，免得 -Wunused-function
// 報錯；鍵照樣在 plist 裡，設定頁照常讀寫。

// v40：写一个 prefs 数字（CFPreferencesSetAppValue + 同步，立刻落盘；
// 零字面量规则：key 与 domain 都用 CFStringCreateWithCString 现做）。
static void GHLSSWritePrefsDouble(const char *key, double value) {
if (!key) return;
CFStringRef domain = CFStringCreateWithCString(NULL, "com.guhailong.splitscreen", kCFStringEncodingUTF8);
CFStringRef keyRef = CFStringCreateWithCString(NULL, key, kCFStringEncodingUTF8);
if (domain && keyRef) {
CFNumberRef num = CFNumberCreate(NULL, kCFNumberDoubleType, &value);
if (num) {
CFPreferencesSetAppValue(keyRef, num, domain);
CFRelease(num);
}
CFPreferencesAppSynchronize(domain);
}
if (domain) CFRelease(domain);
if (keyRef) CFRelease(keyRef);
}

// v40：记位置/大小的键——"geo" + App 前缀 + 字段（例："geoCalculatorX"、
// "geoCalculatorScale"）。字段：X、Y（窗中心）、W、H（窗尺寸）、Scale（缩放）。
// v41：前 5 個固定 App 用上面那張前綴表；自選槽位（idx>=5）用
// "geoCustom<槽號>" 當前綴（例："geoCustom5X"），不依賴 bundle ID，
// 換了 App 也認得回來。
static void GHLSSGeoKeyForIndex(int idx, const char *field, char *buf, size_t bufSize) {
if (idx < 0 || idx >= GHLSS_APP_COUNT || !field || !buf || bufSize == 0) {
if (buf && bufSize > 0) buf[0] = '\0';
return;
}
if (idx < 5) {
snprintf(buf, bufSize, "geo%s%s", GHLSSGeoAppKeys[idx], field);
} else {
snprintf(buf, bufSize, "geoCustom%d%s", idx - 5, field);
}
}

// v40：把第 idx 个 App 的窗口位置/大小/缩放存进 prefs（拖动结束、
// 缩放改变、收起/关窗、调尺寸结束时调）。存的是窗中心 (x,y) + 窗尺寸
// (w,h) + scale；没有窗就不存。活动窗的 scale 用活动量（缓存里的
// scaleRatio 可能还没同步滑杆的最新值）。
static void GHLSSSaveGeometryForIndex(int idx) {
if (idx < 0 || idx >= GHLSS_APP_COUNT) return;
// v41：豎屏固定中心開著時不記位置（FV 的意思：開了這個開關，轉屏或
// 拖全屏後都不記錄位置、固定為屏幕中心；跟 v40「記住位置大小」是反的）。
if (GHLSSReadCenterOnOpen()) {
GHLSSLogLine("v43 geometry not saved, center on open");
return;
}
UIWindow *w = GHLSSCacheWindows[idx];
if (!w) return;
char key[64];
CGPoint c = w.center;
CGSize s = w.bounds.size;
CGFloat scale = GHLSSCacheScaleRatios[idx];
if (idx == GHLSSActiveAppIndex && GHLSSHostedScaleRatio > 0) scale = GHLSSHostedScaleRatio;
if (scale <= 0) scale = 1.0;
GHLSSGeoKeyForIndex(idx, "X", key, sizeof(key));
GHLSSWritePrefsDouble(key, (double)c.x);
GHLSSGeoKeyForIndex(idx, "Y", key, sizeof(key));
GHLSSWritePrefsDouble(key, (double)c.y);
GHLSSGeoKeyForIndex(idx, "W", key, sizeof(key));
GHLSSWritePrefsDouble(key, (double)s.width);
GHLSSGeoKeyForIndex(idx, "H", key, sizeof(key));
GHLSSWritePrefsDouble(key, (double)s.height);
GHLSSGeoKeyForIndex(idx, "Scale", key, sizeof(key));
GHLSSWritePrefsDouble(key, (double)scale);
char buf[128];
snprintf(buf, sizeof(buf), "v43 geometry saved %s %dx%d scale %d%%", GHLSSCacheBundleIDs[idx], (int)s.width, (int)s.height, (int)(scale * 100.0));
GHLSSLogLine(buf);
}

// v40：读第 idx 个 App 存过的位置/大小/缩放（有存过就回 YES，输出
// 中心/尺寸/缩放；没存过、或尺寸不合法就回 NO，走默认+错位）。
// W、H 没存过时读到 0（默认 0），尺寸下限 200x300（调尺寸的下限），
// 小于它就是没存过。中心没存过时读到 0，恢复处会夹到屏幕内。
static BOOL GHLSSRestoreGeometryForIndex(int idx, CGFloat *outCX, CGFloat *outCY, CGFloat *outW, CGFloat *outH, CGFloat *outScale) {
if (idx < 0 || idx >= GHLSS_APP_COUNT) return NO;
char key[64];
double w = 0, h = 0;
GHLSSGeoKeyForIndex(idx, "W", key, sizeof(key));
w = GHLSSReadPrefsDouble(key, 0);
GHLSSGeoKeyForIndex(idx, "H", key, sizeof(key));
h = GHLSSReadPrefsDouble(key, 0);
if (w < 200.0 || h < 300.0) return NO;
double cx = 0, cy = 0, scale = 1.0;
GHLSSGeoKeyForIndex(idx, "X", key, sizeof(key));
cx = GHLSSReadPrefsDouble(key, 0);
GHLSSGeoKeyForIndex(idx, "Y", key, sizeof(key));
cy = GHLSSReadPrefsDouble(key, 0);
GHLSSGeoKeyForIndex(idx, "Scale", key, sizeof(key));
scale = GHLSSReadPrefsDouble(key, 1.0);
if (scale < 0.5) scale = 0.5;
if (scale > 2.0) scale = 2.0;
if (outCX) *outCX = (CGFloat)cx;
if (outCY) *outCY = (CGFloat)cy;
if (outW) *outW = (CGFloat)w;
if (outH) *outH = (CGFloat)h;
if (outScale) *outScale = (CGFloat)scale;
return YES;
}

// v40：点窗外事件开关（prefs 里的 tapOutsideEnabled，默认开）。
static BOOL GHLSSReadTapOutsideEnabled(void) {
return GHLSSReadPrefsBool("tapOutsideEnabled", YES);
}

// v40：这个 App 在设定页里开着没有（默认开；键不存在就回 YES）。
static BOOL GHLSSIsAppEnabled(int idx) {
if (idx < 0 || idx >= GHLSS_APP_COUNT) return NO;
return GHLSSReadPrefsBool(GHLSSAppEnabledKeys[idx], YES);
}

// ── v41：寫 prefs（BOOL / 字串） ──
// 字串傳 NULL 或空字串 = 清掉那個鍵（CFPreferencesSetAppValue 傳 NULL
// 就是刪除）。立刻落盤。
static void GHLSSWritePrefsBool(const char *key, BOOL value) {
if (!key) return;
CFStringRef domain = CFStringCreateWithCString(NULL, "com.guhailong.splitscreen", kCFStringEncodingUTF8);
CFStringRef keyRef = CFStringCreateWithCString(NULL, key, kCFStringEncodingUTF8);
if (domain && keyRef) {
CFPreferencesSetAppValue(keyRef, value ? kCFBooleanTrue : kCFBooleanFalse, domain);
CFPreferencesAppSynchronize(domain);
}
if (domain) CFRelease(domain);
if (keyRef) CFRelease(keyRef);
}
static void GHLSSWritePrefsCString(const char *key, const char *value) {
if (!key) return;
CFStringRef domain = CFStringCreateWithCString(NULL, "com.guhailong.splitscreen", kCFStringEncodingUTF8);
CFStringRef keyRef = CFStringCreateWithCString(NULL, key, kCFStringEncodingUTF8);
if (domain && keyRef) {
if (value && value[0] != '\0') {
CFStringRef valRef = CFStringCreateWithCString(NULL, value, kCFStringEncodingUTF8);
if (valRef) {
CFPreferencesSetAppValue(keyRef, valRef, domain);
CFRelease(valRef);
}
} else {
CFPreferencesSetAppValue(keyRef, NULL, domain);
}
CFPreferencesAppSynchronize(domain);
}
if (domain) CFRelease(domain);
if (keyRef) CFRelease(keyRef);
}

// ── v41：已安裝 App 清單（ARC 的「＋」與設定頁選擇器共用） ──
// 緩存檔：/var/mobile/Library/Preferences/GuHaiLongSplitScreen-apps.plist，
// 內容是 NSArray<NSDictionary{bundleID, name}>。列舉在後台做（見下面
// GHLSSRefreshInstalledAppListInBackground），讀緩存只讀檔、很快，
// 主線程讀沒問題。緩存不存在/空時，選擇器只列 5 個固定 App。
// 完全不用 LSApplicationWorkspace（禁區——同步調用會堵主線程 ≥5 秒），
// 只用 NSFileManager + plist 讀檔。
static NSString *GHLSSAppListCachePath(void) {
return [NSString stringWithCString:"/var/mobile/Library/Preferences/GuHaiLongSplitScreen-apps.plist" encoding:NSUTF8StringEncoding];
}
static NSArray *GHLSSCachedInstalledAppList(void) {
NSString *path = GHLSSAppListCachePath();
if (!path) return nil;
NSArray *list = [NSArray arrayWithContentsOfFile:path];
if (![list isKindOfClass:[NSArray class]]) return nil;
return list;
}
// 從緩存檔查一個 bundle ID 的顯示名（回傳 malloc 的 C 字串，調用處 free；
// 查不到回 NULL）。
static char *GHLSSCachedAppNameForBundleID(const char *bundleID) {
if (!bundleID || bundleID[0] == '\0') return NULL;
NSArray *list = GHLSSCachedInstalledAppList();
if (!list) return NULL;
NSString *bidKey = [NSString stringWithCString:"bundleID" encoding:NSUTF8StringEncoding];
NSString *nameKey = [NSString stringWithCString:"name" encoding:NSUTF8StringEncoding];
NSString *bidStr = [NSString stringWithCString:bundleID encoding:NSUTF8StringEncoding];
for (id item in list) {
if (![item isKindOfClass:[NSDictionary class]]) continue;
NSString *itemBid = [(NSDictionary *)item objectForKey:bidKey];
if (itemBid && [itemBid isEqualToString:bidStr]) {
NSString *name = [(NSDictionary *)item objectForKey:nameKey];
if (name && [name length] > 0) {
const char *utf8 = [name UTF8String];
if (!utf8) return NULL;
char *out = (char *)malloc(strlen(utf8) + 1);
if (!out) return NULL;
strcpy(out, utf8);
return out;
}
return NULL;
}
}
return NULL;
}
// 把自選槽位（5–11）從 prefs 讀進 GHLSSAppBundleIDs/GHLSSAppNames。
// 槽位有 bundle ID 就填進去，名字從緩存檔查（查不到就用 bundle ID 最後一段）；
// 槽位空就清掉。啟動時調一次，ARC 打開與選完 App 後也調（立刻生效）。
static void GHLSSLoadCustomApps(void) {
for (int s = 0; s < GHLSS_CUSTOM_APP_COUNT; s++) {
int idx = 5 + s;
char *bid = GHLSSReadPrefsCString(GHLSSCustomBundleIDKeys[s]);
if (bid && bid[0] != '\0') {
strncpy(GHLSSAppBundleIDs[idx], bid, sizeof(GHLSSAppBundleIDs[idx]) - 1);
GHLSSAppBundleIDs[idx][sizeof(GHLSSAppBundleIDs[idx]) - 1] = '\0';
char *name = GHLSSCachedAppNameForBundleID(bid);
if (name && name[0] != '\0') {
strncpy(GHLSSAppNames[idx], name, sizeof(GHLSSAppNames[idx]) - 1);
GHLSSAppNames[idx][sizeof(GHLSSAppNames[idx]) - 1] = '\0';
free(name);
} else {
const char *lastDot = strrchr(bid, '.');
const char *shortName = lastDot ? lastDot + 1 : bid;
strncpy(GHLSSAppNames[idx], shortName, sizeof(GHLSSAppNames[idx]) - 1);
GHLSSAppNames[idx][sizeof(GHLSSAppNames[idx]) - 1] = '\0';
}
free(bid);
} else {
GHLSSAppBundleIDs[idx][0] = '\0';
GHLSSAppNames[idx][0] = '\0';
if (bid) free(bid);
}
}
}
// 這個 bundle ID 現在在不在啟動器裡（固定槽看 app*Enabled，自選槽看
// customAppNEnabled；空槽不算）。
static BOOL GHLSSIsAppInLauncher(const char *bundleID) {
if (!bundleID || bundleID[0] == '\0') return NO;
int idx = GHLSSAppIndexForBundleID(bundleID);
if (idx < 0) return NO;
return GHLSSIsAppEnabled(idx);
}
// 把一個 App 加進/移出啟動器（ARC 的「＋」與設定頁選擇器共用同一份鍵，
// 兩邊改了都同步）。固定 App 只改它的開關；自選 App：開時找第一個空槽位
// 寫 bundle ID + 開關開，關時清掉那個槽位；沒空槽位就回 NO（上限 12 個）。
static BOOL GHLSSSetAppInLauncher(const char *bundleID, BOOL inLauncher) {
if (!bundleID || bundleID[0] == '\0') return NO;
int idx = GHLSSAppIndexForBundleID(bundleID);
char buf[256];
if (idx >= 0 && idx < 5) {
GHLSSWritePrefsBool(GHLSSAppEnabledKeys[idx], inLauncher);
snprintf(buf, sizeof(buf), "v43 app selector %s %s", bundleID, inLauncher ? "on" : "off");
GHLSSLogLine(buf);
return YES;
}
if (idx >= 5) {
if (inLauncher) {
GHLSSWritePrefsBool(GHLSSAppEnabledKeys[idx], YES);
} else {
GHLSSWritePrefsCString(GHLSSCustomBundleIDKeys[idx - 5], NULL);
GHLSSWritePrefsBool(GHLSSAppEnabledKeys[idx], NO);
GHLSSLoadCustomApps();
}
snprintf(buf, sizeof(buf), "v43 app selector %s %s", bundleID, inLauncher ? "on" : "off");
GHLSSLogLine(buf);
return YES;
}
if (!inLauncher) return YES;
for (int s = 0; s < GHLSS_CUSTOM_APP_COUNT; s++) {
char *existing = GHLSSReadPrefsCString(GHLSSCustomBundleIDKeys[s]);
BOOL empty = (!existing || existing[0] == '\0');
if (existing) free(existing);
if (empty) {
GHLSSWritePrefsCString(GHLSSCustomBundleIDKeys[s], bundleID);
GHLSSWritePrefsBool(GHLSSAppEnabledKeys[5 + s], YES);
GHLSSLoadCustomApps();
snprintf(buf, sizeof(buf), "v43 app selector %s on slot %d", bundleID, s + 1);
GHLSSLogLine(buf);
return YES;
}
}
GHLSSLogLine("v43 app selector full");
return NO;
}
// v41：取一個 bundleID 的顯示名（啟動器槽位優先，其次緩存清單，
// 都沒有就用 bundle ID 最後一段）。輸出寫進 out（呼叫處備好 buffer）。
static void GHLSSAppNameForBundleID(const char *bundleID, char *out, size_t outSize) {
if (!bundleID || !out || outSize == 0) return;
out[0] = '\0';
int idx = GHLSSAppIndexForBundleID(bundleID);
if (idx >= 0 && GHLSSAppNames[idx][0] != '\0') {
strncpy(out, GHLSSAppNames[idx], outSize - 1);
out[outSize - 1] = '\0';
return;
}
char *cached = GHLSSCachedAppNameForBundleID(bundleID);
if (cached) {
strncpy(out, cached, outSize - 1);
out[outSize - 1] = '\0';
free(cached);
return;
}
const char *lastDot = strrchr(bundleID, '.');
const char *shortName = lastDot ? lastDot + 1 : bundleID;
strncpy(out, shortName, outSize - 1);
out[outSize - 1] = '\0';
}
// 後台列舉已安裝 App（絕不在主線程做——讀幾十個 Info.plist + 掃兩個目錄
// 要時間，主線程做會卡住 SpringBoard）。讀 /Applications（系統 App）與
// /var/mobile/Containers/Bundle/Application（商店 App，UUID 目錄裡才是
// .app）下面每個 .app 的 Info.plist，取 CFBundleIdentifier +
// CFBundleDisplayName（沒有就用 CFBundleName，再沒有就用目錄名），去重、
// 按名字排好，寫進緩存檔。跑在 global queue 上；寫完記一行日誌。
// 若目錄讀不到（權限），緩存就是空的，選擇器只列 5 個固定 App，不崩。
static void GHLSSRefreshInstalledAppListInBackground(void) {
dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
@try {
NSMutableArray *apps = [NSMutableArray array];
NSMutableSet *seenBids = [NSMutableSet set];
NSFileManager *fm = [NSFileManager defaultManager];
NSString *appsDir = [NSString stringWithCString:"/Applications" encoding:NSUTF8StringEncoding];
NSString *containersDir = [NSString stringWithCString:"/var/mobile/Containers/Bundle/Application" encoding:NSUTF8StringEncoding];
NSString *appSuffix = [NSString stringWithCString:".app" encoding:NSUTF8StringEncoding];
NSString *infoName = [NSString stringWithCString:"Info.plist" encoding:NSUTF8StringEncoding];
NSString *bidKey = [NSString stringWithCString:"CFBundleIdentifier" encoding:NSUTF8StringEncoding];
NSString *displayKey = [NSString stringWithCString:"CFBundleDisplayName" encoding:NSUTF8StringEncoding];
NSString *nameKey2 = [NSString stringWithCString:"CFBundleName" encoding:NSUTF8StringEncoding];
NSString *cacheBidKey = [NSString stringWithCString:"bundleID" encoding:NSUTF8StringEncoding];
NSString *cacheNameKey = [NSString stringWithCString:"name" encoding:NSUTF8StringEncoding];
NSArray *dirs = [NSArray arrayWithObjects:appsDir, containersDir, nil];
for (NSString *dir in dirs) {
NSArray *entries = [fm contentsOfDirectoryAtPath:dir error:nil];
if (!entries) continue;
for (NSString *entry in entries) {
NSString *entryPath = [dir stringByAppendingPathComponent:entry];
BOOL isDir = NO;
if (![fm fileExistsAtPath:entryPath isDirectory:&isDir] || !isDir) continue;
NSString *appPath = nil;
if ([entry hasSuffix:appSuffix]) {
appPath = entryPath;
} else {
NSArray *inner = [fm contentsOfDirectoryAtPath:entryPath error:nil];
for (NSString *innerEntry in inner) {
if ([innerEntry hasSuffix:appSuffix]) {
appPath = [entryPath stringByAppendingPathComponent:innerEntry];
break;
}
}
}
if (!appPath) continue;
NSString *infoPath = [appPath stringByAppendingPathComponent:infoName];
NSDictionary *info = [NSDictionary dictionaryWithContentsOfFile:infoPath];
if (!info) continue;
NSString *bid = [info objectForKey:bidKey];
if (!bid || [bid length] == 0) continue;
if ([seenBids containsObject:bid]) continue;
NSString *name = [info objectForKey:displayKey];
if (!name || [name length] == 0) name = [info objectForKey:nameKey2];
if (!name || [name length] == 0) name = [appPath lastPathComponent];
[seenBids addObject:bid];
NSDictionary *item = [NSDictionary dictionaryWithObjectsAndKeys:bid, cacheBidKey, name, cacheNameKey, nil];
[apps addObject:item];
}
}
[apps sortUsingComparator:^NSComparisonResult(id a, id b) {
NSString *na = [(NSDictionary *)a objectForKey:cacheNameKey];
NSString *nb = [(NSDictionary *)b objectForKey:cacheNameKey];
if (!na) return NSOrderedAscending;
if (!nb) return NSOrderedDescending;
return [na localizedCaseInsensitiveCompare:nb];
}];
NSString *cachePath = GHLSSAppListCachePath();
if (cachePath) [apps writeToFile:cachePath atomically:YES];
char buf[128];
snprintf(buf, sizeof(buf), "v43 installed apps cached %lu", (unsigned long)[apps count]);
GHLSSLogLine(buf);
} @catch (NSException *e) {
(void)e;
GHLSSLogLine("v43 installed apps scan failed");
}
});
}

// v40：小窗显示位置是不是左侧（prefs 里的 windowPosition，
// "left" 或 "right"，默认 "right"；不是 "left" 就当右側）。
static BOOL GHLSSIsWindowPositionLeft(void) {
char *pos = GHLSSReadPrefsCString("windowPosition");
BOOL isLeft = (pos && strcmp(pos, "left") == 0);
if (pos) free(pos);
return isLeft;
}

// v41：貼邊 peek 的 x（右：屏寬 - peek 寬 - 邊距；左：邊距）。重排
// 與收起都用它，跟位置設定走。
static CGFloat GHLSSDockPeekX(void) {
CGRect screenBounds = [UIScreen mainScreen].bounds;
if (GHLSSIsWindowPositionLeft()) return 2.0;
return screenBounds.size.width - GHLSS_DOCK_PEEK_W - 2.0;
}

// v40：感应带跟小窗位置设定走（左/右）。%ctor 建带时调一次（初始位置）；
// showLauncher 也调（设定改了，下次开启动器时带子就跟到对的边；
// 哆啦A夢鈕一直在右邊，永遠能開啟動器）。带子 24pt 宽、全高；
// 边缘滑动手势的 edges 也一起改（右緣滑 / 左緣滑）。
// v41：感應帶跟調度設定走（edgeSwipeSide；沒設就跟小窗位置設定）。
static void GHLSSUpdateStripPosition(void) {
if (!GHLSSStripWindow) return;
CGRect screenBounds = [UIScreen mainScreen].bounds;
CGFloat stripWidth = 24.0;
if (GHLSSIsEdgeSwipeLeft()) {
GHLSSStripWindow.frame = CGRectMake(0, 0, stripWidth, screenBounds.size.height);
if (GHLSSLauncherEdgePan) GHLSSLauncherEdgePan.edges = UIRectEdgeLeft;
} else {
GHLSSStripWindow.frame = CGRectMake(screenBounds.size.width - stripWidth, 0, stripWidth, screenBounds.size.height);
if (GHLSSLauncherEdgePan) GHLSSLauncherEdgePan.edges = UIRectEdgeRight;
}
}

// v40：把活动量切到指定窗（手势/小卡/启动器点按时调——多窗时每个手势
// 都先调它，再做事；已经是活动窗就直接回；窗不在缓存里也直接回）。
static void GHLSSSetActiveToWindow(UIWindow *window) {
if (!window || window == GHLSSHostedWindow) return;
for (int i = 0; i < GHLSS_APP_COUNT; i++) {
if (GHLSSCacheWindows[i] == window) {
GHLSSLoadCacheToActive(i);
return;
}
}
}

// v40：给一个 view 找它所在的窗（控制条按钮、滑杆、细条手势的
// recognizer.view 都是窗里的子视图，沿 superview 一路往上找 UIWindow）。
static UIWindow *GHLSSWindowForView(UIView *view) {
UIView *v = view;
while (v) {
if ([v isKindOfClass:[UIWindow class]]) return (UIWindow *)v;
v = v.superview;
}
return nil;
}

// v40：现在看得见的悬浮窗有几个（新窗错位放、阴影背景显示时用）。
static int GHLSSVisibleHostedWindowCount(void) {
int n = 0;
for (int i = 0; i < GHLSS_APP_COUNT; i++) {
if (GHLSSCacheWindows[i] && !GHLSSCacheWindows[i].hidden && !GHLSSCacheMinimized[i]) n++;
}
return n;
}

// v40：缓存里有没有悬浮窗（启动器层级用：有窗就升到 Alert - 1，
// 在悬浮窗之上；没窗就降回 Alert - 3，让主屏点按正常穿过）。
static BOOL GHLSSAnyCachedHostedWindow(void) {
for (int i = 0; i < GHLSS_APP_COUNT; i++) {
if (GHLSSCacheWindows[i]) return YES;
}
return NO;
}

// v40：缓存第 idx 项还活不活（复用守卫同款判定：进程还是同一个 pid，
// 且 presenter 的 view 或 layer host view 还在）。死进程的项不能恢复，
// 要走 launchHostedApp 让复用守卫销毁重建。
static BOOL GHLSSCachedEntryIsAlive(int idx) {
if (idx < 0 || idx >= GHLSS_APP_COUNT) return NO;
if (!GHLSSCacheWindows[idx] || !GHLSSCacheScenes[idx]) return NO;
if (!((GHLSSCachePresenters[idx] && GHLSSCachePresenters[idx].presentationView) || GHLSSCacheLayerHostViews[idx])) return NO;
const char *bid = GHLSSCacheBundleIDs[idx];
if (!bid || bid[0] == '\0') return NO;
NSString *bidStr = [NSString stringWithCString:bid encoding:NSUTF8StringEncoding];
if (!bidStr) return NO;
RBSProcessIdentity *identity = [RBSProcessIdentity identityForEmbeddedApplicationIdentifier:bidStr];
if (!identity) return NO;
RBSProcessPredicate *predicate = [RBSProcessPredicate predicateMatchingIdentity:identity];
RBSProcessHandle *handle = [RBSProcessHandle handleForPredicate:predicate error:nil];
int pid = handle ? [handle pid] : 0;
return (pid > 0 && pid == GHLSSCachePids[idx]);
}

// v40：把缓存第 idx 项的 scene 推回后台（锁屏时全窗循环用；和
// GHLSSBackgroundHostedScene 同款，只是不动活动量）。
static void GHLSSBackgroundCachedSceneAtIndex(int idx, const char *logLine) {
if (idx < 0 || idx >= GHLSS_APP_COUNT) return;
FBScene *scene = GHLSSCacheScenes[idx];
if (!scene) return;
@try {
[scene updateSettingsWithBlock:^(UIMutableApplicationSceneSettings *settings) {
settings.foreground = NO;
if ([settings respondsToSelector:@selector(setBackgrounded:)]) {
settings.backgrounded = YES;
}
}];
GHLSSLogLine(logLine);
} @catch (NSException *e) {
(void)e;
GHLSSLogLine("v43 scene background failed");
}
}

// v40：把缓存第 idx 项的 scene 推回前景（解锁时全窗循环用；
// v39 的解锁推前景只管活动窗一个，v40 扩展到全部开着的窗）。
static void GHLSSPushForegroundCachedSceneAtIndex(int idx, const char *logLine) {
if (idx < 0 || idx >= GHLSS_APP_COUNT) return;
FBScene *scene = GHLSSCacheScenes[idx];
if (!scene) return;
@try {
[scene updateSettingsWithBlock:^(UIMutableApplicationSceneSettings *settings) {
settings.foreground = YES;
if ([settings respondsToSelector:@selector(setBackgrounded:)]) {
settings.backgrounded = NO;
}
}];
GHLSSLogLine(logLine);
} @catch (NSException *e) {
(void)e;
GHLSSLogLine("v43 foreground push failed");
}
}

// v41：浮窗前後順序（主/副/副副）：最近帶到最前的在前。帶到最前/恢復/
// 建新窗時更新；雙擊哆啦A夢輪切、ARC 升主窗都按這張表走。
static int GHLSSFrontOrder[GHLSS_APP_COUNT] = {0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11};
static int GHLSSAppIndexForWindow(UIWindow *window) {
if (!window) return -1;
for (int i = 0; i < GHLSS_APP_COUNT; i++) {
if (GHLSSCacheWindows[i] == window) return i;
}
return -1;
}
static void GHLSSMarkWindowFront(int idx) {
if (idx < 0 || idx >= GHLSS_APP_COUNT) return;
int pos = -1;
for (int i = 0; i < GHLSS_APP_COUNT; i++) {
if (GHLSSFrontOrder[i] == idx) { pos = i; break; }
}
if (pos < 0) return;
for (int i = pos; i > 0; i--) GHLSSFrontOrder[i] = GHLSSFrontOrder[i - 1];
GHLSSFrontOrder[0] = idx;
}

// v40：把指定窗带到最前——别的宿主窗回基础层级（Alert - 2），这个窗
// 升到最前层级（Alert - 1.75）。启动器（Alert - 1）与锁屏（2000）
// 仍在它之上；贴边小卡（Alert - 1.5）也在它之上（卡要一直看得见）。
static void GHLSSBringWindowToFront(UIWindow *window) {
if (!window) return;
// v41：遊戲模式開著時，帶到最前的窗升到遊戲層級（Alert - 0.25），
// 別的窗回遊戲底層級（Alert - 0.5）；關著時走原來的 1998.25 / 1998。
BOOL gameMode = GHLSSReadGameModeEnabled();
for (int i = 0; i < GHLSS_APP_COUNT; i++) {
if (GHLSSCacheWindows[i] && GHLSSCacheWindows[i] != window) {
GHLSSCacheWindows[i].windowLevel = gameMode ? GHLSS_GAME_BASE_LEVEL : GHLSS_HOSTED_BASE_LEVEL;
}
}
window.windowLevel = gameMode ? GHLSS_GAME_FRONT_LEVEL : GHLSS_HOSTED_FRONT_LEVEL;
// v42：釘選的窗提到最上層（遊戲最前層級，比帶到最前的窗還高、
// 別的窗蓋不住；收起的 peek 不提——peek 本來就在邊緣層級）。
for (int i = 0; i < GHLSS_APP_COUNT; i++) {
if (GHLSSCacheWindows[i] && GHLSSCacheWindows[i] != window && !GHLSSCacheMinimized[i] && !GHLSSCacheWindows[i].hidden && GHLSSCacheBundleIDs[i][0] != '\0' && GHLSSIsWindowPinned(GHLSSCacheBundleIDs[i])) {
GHLSSCacheWindows[i].windowLevel = GHLSS_GAME_FRONT_LEVEL;
}
}
GHLSSSetActiveToWindow(window);
GHLSSMarkWindowFront(GHLSSAppIndexForWindow(window));
GHLSSLogLine("v43 window brought to front");
}

// v41：貼邊 peek 重新排布——收著的窗縮到邊緣、上下疊著排（圖 1 的樣子：
// 右邊緣上下疊著收起的浮窗，只露出一截活內容）。peek 就是宿主窗本身
//（112x216），不是另外的小卡窗。有 peek 增減時調（最小化、恢復、
// 關窗、從 peek 關掉）。順序按前後順序表（主窗在最上面）。
static void GHLSSLayoutDockPeeks(void) {
CGRect screenBounds = [UIScreen mainScreen].bounds;
int docked[GHLSS_APP_COUNT];
int n = 0;
for (int k = 0; k < GHLSS_APP_COUNT; k++) {
int i = GHLSSFrontOrder[k];
if (GHLSSCacheWindows[i] && GHLSSCacheMinimized[i]) {
docked[n++] = i;
}
}
if (n == 0) return;
CGFloat totalH = n * GHLSS_DOCK_PEEK_H + (n - 1) * GHLSS_DOCK_PEEK_GAP;
CGFloat startY = (screenBounds.size.height - totalH) / 2.0;
CGFloat x = GHLSSDockPeekX(); // v41：跟小窗位置設定走（右緣 / 左緣）。
for (int k = 0; k < n; k++) {
CGFloat y = startY + k * (GHLSS_DOCK_PEEK_H + GHLSS_DOCK_PEEK_GAP);
GHLSSCacheWindows[docked[k]].frame = CGRectMake(x, y, GHLSS_DOCK_PEEK_W, GHLSS_DOCK_PEEK_H);
}
}

// v41：把第 idx 個窗收成貼邊 peek——窗本身縮到邊緣（112x216，露出一截
// 活內容，上下疊著排；圖 1 的樣子），不是另外建小卡窗。窗上蓋一層透明
// 點按層（點整截恢復窗）+ 右上角一顆小 X（徹底關掉）。scene 活著
// （只縮窗 + 推後台，不銷毀；v35 規則）。收起前的位置/大小由
// minimizeHostedWindow 在縮窗之前存過（GHLSSSaveGeometryForIndex）。
static void GHLSSShowDockPeekForIndex(int idx) {
if (idx < 0 || idx >= GHLSS_APP_COUNT) return;
UIWindow *w = GHLSSCacheWindows[idx];
if (!w || !GHLSSCacheContainers[idx]) return;
GHLSSCacheMinimized[idx] = YES;
w.windowLevel = GHLSS_DOCK_LEVEL;
UIView *container = GHLSSCacheContainers[idx];
if (!GHLSSPeekTapOverlays[idx]) {
UIButton *tapOverlay = [UIButton buttonWithType:UIButtonTypeCustom];
tapOverlay.tag = idx;
[tapOverlay addTarget:GHLSSLauncherShared action:@selector(handleDockPeekTap:) forControlEvents:UIControlEventTouchUpInside];
[container addSubview:tapOverlay];
GHLSSPeekTapOverlays[idx] = tapOverlay;
UIButton *closeBtn = [UIButton buttonWithType:UIButtonTypeCustom];
closeBtn.backgroundColor = [UIColor colorWithRed:1.0 green:0.23 blue:0.19 alpha:1.0];
closeBtn.layer.cornerRadius = 10.0;
[closeBtn setTitle:[NSString stringWithCString:"x" encoding:NSUTF8StringEncoding] forState:UIControlStateNormal];
[closeBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
closeBtn.titleLabel.font = [UIFont boldSystemFontOfSize:11];
closeBtn.tag = idx;
[closeBtn addTarget:GHLSSLauncherShared action:@selector(handleDockPeekClose:) forControlEvents:UIControlEventTouchUpInside];
[container addSubview:closeBtn];
GHLSSPeekCloseButtons[idx] = closeBtn;
}
GHLSSPeekTapOverlays[idx].frame = CGRectMake(0, 0, GHLSS_DOCK_PEEK_W, GHLSS_DOCK_PEEK_H);
GHLSSPeekTapOverlays[idx].hidden = NO;
GHLSSPeekCloseButtons[idx].frame = CGRectMake(GHLSS_DOCK_PEEK_W - 22, 2, 20, 20);
GHLSSPeekCloseButtons[idx].hidden = NO;
GHLSSLayoutDockPeeks();
char buf[128];
snprintf(buf, sizeof(buf), "v43 window docked to peek %s", GHLSSCacheBundleIDs[idx]);
GHLSSLogLine(buf);
}

// v41：收掉第 idx 個 App 的貼邊 peek（恢復/關窗時調）：點按層與小 X
// 藏起來（不刪，下次收起再用），再重排剩下的 peek。窗的尺寸由恢復處
// 從存過的位置/大小還原（見 restoreHostedWindow）。
static void GHLSSHideDockPeekForIndex(int idx) {
if (idx < 0 || idx >= GHLSS_APP_COUNT) return;
GHLSSCacheMinimized[idx] = NO;
if (GHLSSPeekTapOverlays[idx]) GHLSSPeekTapOverlays[idx].hidden = YES;
if (GHLSSPeekCloseButtons[idx]) GHLSSPeekCloseButtons[idx].hidden = YES;
GHLSSLayoutDockPeeks();
}

// v40：阴影背景（点窗外事件）的显示/隐藏——开关开着、且至少有一个
// 看得见的悬浮窗时显示；否则藏起来。层级 Alert - 4.5（1995.5）：
// 在主屏之上、感应带/哆啦A夢鈕（1996）之下、悬浮窗（1998）之下——
// 点浮窗本身不受影响（浮窗在 overlay 之上），点哆啦A夢鈕/感应带
// 也不受影响（它们在 overlay 之上），只有点浮窗外的空白才落到
// overlay 上。启动器（1997/1999）在 overlay 之上，打开时不受影响。
// 浮窗可见性有变时调（建窗、最小化、恢复、关窗、锁屏回调）。
static void GHLSSUpdateDimOverlay(void) {
BOOL shouldShow = NO;
if (GHLSSReadTapOutsideEnabled()) {
for (int i = 0; i < GHLSS_APP_COUNT; i++) {
if (GHLSSCacheWindows[i] && !GHLSSCacheWindows[i].hidden && !GHLSSCacheMinimized[i]) {
shouldShow = YES;
break;
}
}
}
if (!shouldShow) {
if (GHLSSDimOverlayWindow) GHLSSDimOverlayWindow.hidden = YES;
return;
}
if (!GHLSSLauncherShared) return;
if (!GHLSSDimOverlayWindow) {
CGRect screenBounds = [UIScreen mainScreen].bounds;
GHLSSDimOverlayWindow = [[UIWindow alloc] initWithFrame:screenBounds];
GHLSSDimOverlayWindow.windowLevel = GHLSS_DIM_OVERLAY_LEVEL;
GHLSSDimOverlayWindow.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.45];
UIWindowScene *overlayScene = GHLSSActiveWindowScene();
if (overlayScene) GHLSSDimOverlayWindow.windowScene = overlayScene;
UIViewController *overlayVC = [[UIViewController alloc] init];
UIView *overlayView = [[UIView alloc] initWithFrame:screenBounds];
overlayView.backgroundColor = [UIColor clearColor];
UITapGestureRecognizer *overlayTap = [[UITapGestureRecognizer alloc] initWithTarget:GHLSSLauncherShared action:@selector(handleDimOverlayTap:)];
[overlayView addGestureRecognizer:overlayTap];
overlayVC.view = overlayView;
GHLSSDimOverlayWindow.rootViewController = overlayVC;
GHLSSLogLine("v43 dim overlay created");
}
GHLSSDimOverlayWindow.hidden = NO;
}

// ── v41：置頂 / 最近 / 遊戲模式 ──
// 置頂與最近都存在 prefs 裡一個逗號分隔的字串鍵（pinnedAppIDs、
// recentAppIDs），讀寫走上面現成的字串 helper；順序就是字串裡的順序。
static NSArray *GHLSSReadIDList(const char *key) {
char *raw = GHLSSReadPrefsCString(key);
if (!raw) return [NSArray array];
NSString *rawStr = [NSString stringWithCString:raw encoding:NSUTF8StringEncoding];
free(raw);
if (!rawStr || [rawStr length] == 0) return [NSArray array];
NSString *sep = [NSString stringWithCString:"," encoding:NSUTF8StringEncoding];
return [rawStr componentsSeparatedByString:sep];
}
static void GHLSSWriteIDList(const char *key, NSArray *ids) {
NSString *sep = [NSString stringWithCString:"," encoding:NSUTF8StringEncoding];
NSString *joined = [ids componentsJoinedByString:sep];
const char *utf8 = joined ? [joined UTF8String] : "";
GHLSSWritePrefsCString(key, utf8 ? utf8 : "");
}
static BOOL GHLSSListContainsBid(NSArray *ids, const char *bundleID) {
if (!bundleID) return NO;
NSString *bidStr = [NSString stringWithCString:bundleID encoding:NSUTF8StringEncoding];
for (id item in ids) {
if ([item isKindOfClass:[NSString class]] && [(NSString *)item isEqualToString:bidStr]) return YES;
}
return NO;
}
static BOOL GHLSSIsAppPinned(const char *bundleID) {
return GHLSSListContainsBid(GHLSSReadIDList("pinnedAppIDs"), bundleID);
}
static void GHLSSSetAppPinned(const char *bundleID, BOOL pinned) {
if (!bundleID || bundleID[0] == '\0') return;
NSMutableArray *ids = [NSMutableArray arrayWithArray:GHLSSReadIDList("pinnedAppIDs")];
NSString *bidStr = [NSString stringWithCString:bundleID encoding:NSUTF8StringEncoding];
[ids removeObject:bidStr];
if (pinned) [ids insertObject:bidStr atIndex:0];
GHLSSWriteIDList("pinnedAppIDs", ids);
char buf[256];
snprintf(buf, sizeof(buf), "v43 app %s %s", bundleID, pinned ? "pinned" : "unpinned");
GHLSSLogLine(buf);
}
// 最近開過的浮窗 App（上限 5 個，最近的在前；開窗時調）。
static void GHLSSPushRecentApp(const char *bundleID) {
if (!bundleID || bundleID[0] == '\0') return;
NSMutableArray *ids = [NSMutableArray arrayWithArray:GHLSSReadIDList("recentAppIDs")];
NSString *bidStr = [NSString stringWithCString:bundleID encoding:NSUTF8StringEncoding];
[ids removeObject:bidStr];
[ids insertObject:bidStr atIndex:0];
while ([ids count] > 5) [ids removeLastObject];
GHLSSWriteIDList("recentAppIDs", ids);
}
// 遊戲模式開關（prefs 鍵 gameModeEnabled，ARC 裡的開關與設定頁同一份鍵）。
static BOOL GHLSSReadGameModeEnabled(void) {
return GHLSSReadPrefsBool("gameModeEnabled", NO);
}
// 遊戲模式開關切換時重算全部可見窗的層級（開：釘在鎖屏之下最高層級；
// 關：回基礎/最前層級）。帶到最前時 GHLSSBringWindowToFront 已經按
// 遊戲模式算過，這裡只負責開關當下那一下。
static void GHLSSApplyGameModeLevels(void) {
BOOL gameMode = GHLSSReadGameModeEnabled();
for (int i = 0; i < GHLSS_APP_COUNT; i++) {
if (!GHLSSCacheWindows[i] || GHLSSCacheWindows[i].hidden || GHLSSCacheMinimized[i]) continue;
if (gameMode) {
GHLSSCacheWindows[i].windowLevel = (i == GHLSSActiveAppIndex) ? GHLSS_GAME_FRONT_LEVEL : GHLSS_GAME_BASE_LEVEL;
} else {
GHLSSCacheWindows[i].windowLevel = (i == GHLSSActiveAppIndex) ? GHLSS_HOSTED_FRONT_LEVEL : GHLSS_HOSTED_BASE_LEVEL;
}
}
char buf[64];
snprintf(buf, sizeof(buf), "v43 game mode %s", gameMode ? "on" : "off");
GHLSSLogLine(buf);
}

// ── v42 輔助函數（配對／恢復清單／演示模式／任務欄／懸浮球／
// 低電量／卡片圖片／定時 tick；全部在 %ctor 延後塊之前定義，
// 供 %ctor 與各方法調用） ──

// v42：卡片頭像/背景圖的固定檔名（設定目錄，設定 App 與 SpringBoard
// 都是 mobile 身份，兩邊都讀寫得到；key 走同一份 CFPreferences）。
static NSString *GHLSSCardImagePath(BOOL isAvatar) {
NSString *dir = [NSString stringWithCString:"/var/mobile/Library/Preferences" encoding:NSUTF8StringEncoding];
NSString *name = [NSString stringWithCString:(isAvatar ? "GuHaiLongSplitScreen-avatar.jpg" : "GuHaiLongSplitScreen-cardbg.jpg") encoding:NSUTF8StringEncoding];
return [dir stringByAppendingPathComponent:name];
}
// v42：讀卡片頭像（自訂開著且檔案在才回圖，不然回 nil → 用預設龍頭）。
static UIImage *GHLSSLoadCardAvatarImage(void) {
if (!GHLSSReadCardAvatarCustom()) return nil;
NSString *path = GHLSSCardImagePath(YES);
if (!path) return nil;
return [UIImage imageWithContentsOfFile:path];
}
// v42：讀卡片背景圖（自訂開著且檔案在才回圖，不然回 nil → 默認白卡）。
static UIImage *GHLSSLoadCardBgImage(void) {
if (!GHLSSReadCardBgCustom()) return nil;
NSString *path = GHLSSCardImagePath(NO);
if (!path) return nil;
return [UIImage imageWithContentsOfFile:path];
}
// v42：讀哆啦A夢圖（%ctor 裡鈕的同一套路徑：先 /var/jb 再 /Library；
// 懸浮球用同一份圖；讀不到回 nil → 呼叫處退回金色「分」）。
static UIImage *GHLSSLoadDoraemonImage(void) {
UIImage *image = nil;
@try {
NSString *resName = [NSString stringWithCString:"doraemon-button" encoding:NSUTF8StringEncoding];
NSString *resType = [NSString stringWithCString:"png" encoding:NSUTF8StringEncoding];
NSString *imagePath = nil;
NSString *bundlePath = [NSString stringWithCString:"/var/jb/Library/PreferenceBundles/GuHaiLongSplitScreenPrefs.bundle" encoding:NSUTF8StringEncoding];
NSBundle *prefsBundle = bundlePath ? [NSBundle bundleWithPath:bundlePath] : nil;
if (prefsBundle && resName && resType) imagePath = [prefsBundle pathForResource:resName ofType:resType];
if (!imagePath) {
NSString *bundlePath2 = [NSString stringWithCString:"/Library/PreferenceBundles/GuHaiLongSplitScreenPrefs.bundle" encoding:NSUTF8StringEncoding];
NSBundle *prefsBundle2 = bundlePath2 ? [NSBundle bundleWithPath:bundlePath2] : nil;
if (prefsBundle2 && resName && resType) imagePath = [prefsBundle2 pathForResource:resName ofType:resType];
}
if (imagePath) image = [UIImage imageWithContentsOfFile:imagePath];
if (image && image.CGImage) {
CGFloat screenScale = [UIScreen mainScreen].scale;
if (screenScale > 0) image = [UIImage imageWithCGImage:image.CGImage scale:screenScale orientation:image.imageOrientation];
}
} @catch (NSException *e) {
(void)e;
image = nil;
}
return image;
}
// v42：讀龍頭圖（設定卡片頂上的預設頭像；prefs bundle 裡的 icon.png，
// 同一套 /var/jb 優先路徑；讀不到回 nil → 呼叫處用金色圓底+「龍」字）。
static UIImage *GHLSSLoadDragonIconImage(void) {
UIImage *image = nil;
@try {
NSString *resName = [NSString stringWithCString:"icon" encoding:NSUTF8StringEncoding];
NSString *resType = [NSString stringWithCString:"png" encoding:NSUTF8StringEncoding];
NSString *imagePath = nil;
NSString *bundlePath = [NSString stringWithCString:"/var/jb/Library/PreferenceBundles/GuHaiLongSplitScreenPrefs.bundle" encoding:NSUTF8StringEncoding];
NSBundle *prefsBundle = bundlePath ? [NSBundle bundleWithPath:bundlePath] : nil;
if (prefsBundle && resName && resType) imagePath = [prefsBundle pathForResource:resName ofType:resType];
if (!imagePath) {
NSString *bundlePath2 = [NSString stringWithCString:"/Library/PreferenceBundles/GuHaiLongSplitScreenPrefs.bundle" encoding:NSUTF8StringEncoding];
NSBundle *prefsBundle2 = bundlePath2 ? [NSBundle bundleWithPath:bundlePath2] : nil;
if (prefsBundle2 && resName && resType) imagePath = [prefsBundle2 pathForResource:resName ofType:resType];
}
if (imagePath) image = [UIImage imageWithContentsOfFile:imagePath];
if (image && image.CGImage) {
CGFloat screenScale = [UIScreen mainScreen].scale;
if (screenScale > 0) image = [UIImage imageWithCGImage:image.CGImage scale:screenScale orientation:image.imageOrientation];
}
} @catch (NSException *e) {
(void)e;
image = nil;
}
return image;
}
// v42：把「a|b」拆成兩份（回 YES 才拆開；a/b 緩衝區由呼叫處給）。
static BOOL GHLSSSplitPairString(const char *pair, char *outA, size_t sizeA, char *outB, size_t sizeB) {
if (!pair || !pair[0] || !outA || !outB) return NO;
const char *bar = strchr(pair, '|');
if (!bar) return NO;
size_t lenA = (size_t)(bar - pair);
size_t lenB = strlen(bar + 1);
if (lenA == 0 || lenB == 0 || lenA >= sizeA || lenB >= sizeB) return NO;
memcpy(outA, pair, lenA);
outA[lenA] = '\0';
strncpy(outB, bar + 1, sizeB - 1);
outB[sizeB - 1] = '\0';
return YES;
}
// v42：記一對配對（無序：先按字典序排好再存，(A,B)==(B,A)；
// 最近的在前，上限 5 對；存 prefs 鍵 recentPairs，逗號分隔）。
static void GHLSSRecordPair(const char *bidA, const char *bidB) {
if (!bidA || !bidB || !bidA[0] || !bidB[0] || strcmp(bidA, bidB) == 0) return;
const char *first = bidA;
const char *second = bidB;
if (strcmp(bidA, bidB) > 0) { first = bidB; second = bidA; }
char pair[256];
snprintf(pair, sizeof(pair), "%s|%s", first, second);
NSMutableArray *ids = [NSMutableArray arrayWithArray:GHLSSReadIDList("recentPairs")];
NSString *pairStr = [NSString stringWithCString:pair encoding:NSUTF8StringEncoding];
[ids removeObject:pairStr];
[ids insertObject:pairStr atIndex:0];
while ([ids count] > 5) [ids removeLastObject];
GHLSSWriteIDList("recentPairs", ids);
char buf[300];
snprintf(buf, sizeof(buf), "v43 pair recorded %s", pair);
GHLSSLogLine(buf);
}
// v42：找某 App 的配對（recentPairs 裡含它的那一對，另一邊是誰；
// 找到回 malloc 的字串，呼叫處 free；找不到回 NULL）。
static char *GHLSSPairPartnerForBundleID(const char *bundleID) {
if (!bundleID || !bundleID[0]) return NULL;
NSArray *pairs = GHLSSReadIDList("recentPairs");
for (id item in pairs) {
if (![item isKindOfClass:[NSString class]]) continue;
const char *pair = [(NSString *)item UTF8String];
if (!pair) continue;
char a[128], b[128];
if (!GHLSSSplitPairString(pair, a, sizeof(a), b, sizeof(b))) continue;
if (strcmp(a, bundleID) == 0) return strdup(b);
if (strcmp(b, bundleID) == 0) return strdup(a);
}
return NULL;
}
// v42：存上次的三屏組合（主 App|側窗 App；三屏設置頁「重新打開」與
// 三屏組合子頁都讀它）。
static void GHLSSSaveLastThreeScreenPair(const char *mainBid, const char *sideBid) {
if (!mainBid || !sideBid || !mainBid[0] || !sideBid[0]) return;
char pair[256];
snprintf(pair, sizeof(pair), "%s|%s", mainBid, sideBid);
GHLSSWritePrefsCString("lastThreeScreenPair", pair);
char buf[300];
snprintf(buf, sizeof(buf), "v43 last three screen pair %s", pair);
GHLSSLogLine(buf);
}
// v42：存重啟後要恢復的浮窗清單（看得見的窗：浮窗本身 + 貼邊 peek；
// X 關掉的窗 hidden=YES，不算；開/關/收/恢復時都重存一次）。
static void GHLSSSaveRestoreList(void) {
NSMutableArray *ids = [NSMutableArray array];
for (int i = 0; i < GHLSS_APP_COUNT; i++) {
if (GHLSSCacheWindows[i] && !GHLSSCacheWindows[i].hidden && GHLSSCacheBundleIDs[i][0] != '\0') {
NSString *bidStr = [NSString stringWithCString:GHLSSCacheBundleIDs[i] encoding:NSUTF8StringEncoding];
if (bidStr) [ids addObject:bidStr];
}
}
GHLSSWriteIDList("restoreWindows", ids);
}
// v42：演示模式開關切換時把各層藏/顯示回來（哆啦A夢鈕、懸浮球、
// 任務欄、橫幅、ARC、設定卡片、貼邊 peek；看得見的浮窗本身不動——
// 演示就是要拍浮窗裡的 App）。開關在設定 App 改也一樣：2 秒定時
// 輪詢會再調這裡，不用通知。
static void GHLSSApplyDemoMode(void) {
BOOL on = GHLSSReadDemoModeEnabled();
if (on == GHLSSDemoModeApplied) return;
GHLSSDemoModeApplied = on;
if (on) {
if (GHLSSDoraemonButtonWindow) GHLSSDoraemonButtonWindow.hidden = YES;
if (GHLSSFloatBallWindow) GHLSSFloatBallWindow.hidden = YES;
if (GHLSSSettingsTaskbarWindow) GHLSSSettingsTaskbarWindow.hidden = YES;
if (GHLSSNotificationBannerWindow) GHLSSNotificationBannerWindow.hidden = YES;
if (GHLSSSettingsCardWindow) GHLSSSettingsCardWindow.hidden = YES;
if (GHLSSLauncherShared && GHLSSLauncherVisible) [GHLSSLauncherShared dismissLauncher];
for (int i = 0; i < GHLSS_APP_COUNT; i++) {
if (GHLSSCacheWindows[i] && GHLSSCacheMinimized[i] && !GHLSSCacheWindows[i].hidden) {
GHLSSCacheWindows[i].hidden = YES;
GHLSSCacheHiddenByDemo[i] = YES;
}
}
if (!GHLSSDemoDotWindow) {
CGRect screenBounds = [UIScreen mainScreen].bounds;
GHLSSDemoDotWindow = [[UIWindow alloc] initWithFrame:CGRectMake(8, screenBounds.size.height - 26, 14, 14)];
GHLSSDemoDotWindow.windowLevel = UIWindowLevelAlert - 1.25;
GHLSSDemoDotWindow.backgroundColor = [UIColor clearColor];
UIWindowScene *dotScene = GHLSSActiveWindowScene();
if (dotScene) GHLSSDemoDotWindow.windowScene = dotScene;
UIViewController *vc = [[UIViewController alloc] init];
UIView *root = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 14, 14)];
root.backgroundColor = [UIColor clearColor];
vc.view = root;
UIButton *dot = [UIButton buttonWithType:UIButtonTypeCustom];
dot.frame = CGRectMake(0, 0, 14, 14);
dot.backgroundColor = [[UIColor whiteColor] colorWithAlphaComponent:0.35];
dot.layer.cornerRadius = 7.0;
dot.layer.borderWidth = 1.0;
dot.layer.borderColor = [[UIColor blackColor] colorWithAlphaComponent:0.3].CGColor;
UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:GHLSSLauncherShared action:@selector(handleDemoDotTap:)];
[dot addGestureRecognizer:tap];
[root addSubview:dot];
GHLSSDemoDotWindow.rootViewController = vc;
}
GHLSSDemoDotWindow.hidden = NO;
GHLSSLogLine("v43 demo mode on");
} else {
GHLSSDemoDotWindow.hidden = YES;
for (int i = 0; i < GHLSS_APP_COUNT; i++) {
if (GHLSSCacheHiddenByDemo[i] && GHLSSCacheWindows[i]) {
GHLSSCacheWindows[i].hidden = NO;
GHLSSCacheHiddenByDemo[i] = NO;
}
}
// 設定卡片不自動叫回來（用戶從 ARC 再開）；哆啦A夢鈕/懸浮球/
// 任務欄交給下面兩個函數按設定與全屏狀態恢復（2 秒內收斂）。
GHLSSLogLine("v43 demo mode off");
}
GHLSSUpdateDoraemonVisibilityForFullscreen();
GHLSSUpdateTaskbar();
}
// v42：全屏偵測（探針：狀態列隱藏啟發式——全屏遊戲/影片會藏狀態列；
// 一般 App 不藏；可能誤判，見 §115）。全屏時藏哆啦A夢鈕+懸浮球，
// 退出全屏再顯示回來（尊重 doraemonVisible / floatBallEnabled /
// 演示模式：演示開著時這裡不碰，由演示模式管）。
static void GHLSSUpdateDoraemonVisibilityForFullscreen(void) {
if (GHLSSDemoModeApplied) return;
if (!GHLSSReadAutoHideDoraemonInFullscreen()) {
if (GHLSSDoraemonButtonWindow) GHLSSDoraemonButtonWindow.hidden = !GHLSSReadDoraemonVisible();
if (GHLSSFloatBallWindow) GHLSSFloatBallWindow.hidden = !GHLSSReadFloatBallEnabled();
return;
}
BOOL fullscreen = NO;
@try {
// isStatusBarHidden（UIApplication）在 iOS 13 已棄用、-Werror 會攔；
// 改走 windowScene.statusBarManager.isStatusBarHidden（沒棄用）。
UIWindowScene *scene = GHLSSActiveWindowScene();
if (scene && scene.statusBarManager) {
fullscreen = scene.statusBarManager.isStatusBarHidden;
}
} @catch (NSException *e) {
(void)e;
fullscreen = NO;
}
if (GHLSSDoraemonButtonWindow) GHLSSDoraemonButtonWindow.hidden = fullscreen ? YES : !GHLSSReadDoraemonVisible();
if (GHLSSFloatBallWindow) GHLSSFloatBallWindow.hidden = fullscreen ? YES : !GHLSSReadFloatBallEnabled();
}
// v42：低電量自動收窗（UIDevice batteryLevel；batteryMonitoringEnabled
// 在 %ctor 開）。低於閾值：看得見的浮窗全收成貼邊小卡 + 橫幅提示；
// 回到閾值+5% 以上才重新武裝（遲滯，免得在閾值邊緣反覆收放）。
static void GHLSSCheckLowBattery(void) {
if (!GHLSSReadLowBatteryAutoDock()) {
GHLSSLowBatteryDocked = NO;
return;
}
CGFloat level = -1.0;
@try {
level = [UIDevice currentDevice].batteryLevel;
} @catch (NSException *e) {
(void)e;
level = -1.0;
}
if (level < 0) return;
double pct = (double)level * 100.0;
double threshold = GHLSSReadLowBatteryThreshold();
if (pct < threshold && !GHLSSLowBatteryDocked) {
GHLSSLowBatteryDocked = YES;
int docked = 0;
for (int i = 0; i < GHLSS_APP_COUNT; i++) {
if (GHLSSCacheWindows[i] && !GHLSSCacheWindows[i].hidden && !GHLSSCacheMinimized[i]) {
GHLSSLoadCacheToActive(i);
if (GHLSSLauncherShared) [GHLSSLauncherShared minimizeHostedWindow];
docked++;
}
}
char buf[192];
snprintf(buf, sizeof(buf), "v43 low battery %d%% docked %d windows", (int)pct, docked);
GHLSSLogLine(buf);
if (GHLSSLauncherShared && docked > 0) {
char msg[192];
snprintf(msg, sizeof(msg), "電量低於 %d%%，浮窗已收成貼邊小卡", (int)threshold);
[GHLSSLauncherShared showNotificationBannerWithText:msg];
}
} else if (pct >= threshold + 5.0) {
GHLSSLowBatteryDocked = NO;
}
}
// v42：底部任務欄（開了要 respring 才建欄；內容每次重建：開著的窗
// 的圖標 + 綠點，點一下切到那個窗；演示模式/沒窗時藏起來）。
static void GHLSSBuildTaskbarIfNeeded(void) {
if (GHLSSSettingsTaskbarWindow) return;
CGRect screenBounds = [UIScreen mainScreen].bounds;
GHLSSSettingsTaskbarWindow = [[UIWindow alloc] initWithFrame:CGRectMake(0, screenBounds.size.height - 60, screenBounds.size.width, 52)];
GHLSSSettingsTaskbarWindow.windowLevel = GHLSS_DOCK_LEVEL;
GHLSSSettingsTaskbarWindow.backgroundColor = [UIColor clearColor];
UIWindowScene *taskScene = GHLSSActiveWindowScene();
if (taskScene) GHLSSSettingsTaskbarWindow.windowScene = taskScene;
UIViewController *vc = [[UIViewController alloc] init];
UIView *root = [[UIView alloc] initWithFrame:CGRectMake(0, 0, screenBounds.size.width, 52)];
root.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.85];
root.layer.cornerRadius = 16.0;
root.tag = 55;
vc.view = root;
GHLSSSettingsTaskbarWindow.rootViewController = vc;
GHLSSSettingsTaskbarWindow.hidden = YES;
GHLSSLogLine("v43 taskbar built");
}
static void GHLSSUpdateTaskbar(void) {
if (!GHLSSSettingsTaskbarWindow) return;
if (!GHLSSReadTaskbarEnabled() || GHLSSDemoModeApplied) {
GHLSSSettingsTaskbarWindow.hidden = YES;
return;
}
UIView *root = GHLSSSettingsTaskbarWindow.rootViewController.view;
for (UIView *sub in [root.subviews copy]) [sub removeFromSuperview];
int count = 0;
for (int i = 0; i < GHLSS_APP_COUNT; i++) {
if (!GHLSSCacheWindows[i]) continue;
const char *bid = GHLSSCacheBundleIDs[i];
if (!bid || bid[0] == '\0') continue;
CGFloat x = 8.0 + count * 44.0;
UIButton *btn = [UIButton buttonWithType:UIButtonTypeCustom];
btn.frame = CGRectMake(x, 8, 36, 36);
btn.tag = i;
UIImage *icon = GHLSSAppIcon(bid);
if (icon) {
[btn setImage:icon forState:UIControlStateNormal];
} else {
btn.backgroundColor = [UIColor grayColor];
}
btn.imageView.layer.cornerRadius = 8.0;
btn.imageView.layer.masksToBounds = YES;
[btn addTarget:GHLSSLauncherShared action:@selector(handleTaskbarButton:) forControlEvents:UIControlEventTouchUpInside];
[root addSubview:btn];
BOOL isOpen = !GHLSSCacheWindows[i].hidden && !GHLSSCacheMinimized[i];
BOOL isMain = (i == GHLSSActiveAppIndex);
if (isOpen || GHLSSCacheMinimized[i]) {
UIView *dot = [[UIView alloc] initWithFrame:CGRectMake(x + 26, 8, 10, 10)];
dot.backgroundColor = isMain ? [UIColor colorWithRed:0.83 green:0.68 blue:0.21 alpha:1.0] : [UIColor colorWithRed:0.2 green:0.8 blue:0.2 alpha:1.0];
dot.layer.cornerRadius = 5.0;
dot.layer.borderWidth = 1.0;
dot.layer.borderColor = [UIColor whiteColor].CGColor;
[root addSubview:dot];
}
count++;
}
GHLSSSettingsTaskbarWindow.hidden = (count == 0);
}
// v42：懸浮球（預設關；開了要 respring 才建球）。小圓球 44pt，點一下
// 開 ARC（跟哆啦A夢鈕同一條路）；拖到哪放手記到哪（floatBallX/Y）。
static void GHLSSBuildFloatBallIfNeeded(void) {
if (GHLSSFloatBallWindow) return;
CGRect screenBounds = [UIScreen mainScreen].bounds;
CGFloat ballSize = 44.0;
double savedX = GHLSSReadFloatBallX();
double savedY = GHLSSReadFloatBallY();
CGFloat cx = (savedX >= 0) ? (CGFloat)savedX : (screenBounds.size.width - ballSize / 2.0);
CGFloat cy = (savedY >= 0) ? (CGFloat)savedY : (screenBounds.size.height * 0.7);
if (cx < ballSize / 2.0) cx = ballSize / 2.0;
if (cx > screenBounds.size.width - ballSize / 2.0) cx = screenBounds.size.width - ballSize / 2.0;
if (cy < 100.0) cy = 100.0;
if (cy > screenBounds.size.height - 100.0) cy = screenBounds.size.height - 100.0;
GHLSSFloatBallWindow = [[UIWindow alloc] initWithFrame:CGRectMake(cx - ballSize / 2.0, cy - ballSize / 2.0, ballSize, ballSize)];
GHLSSFloatBallWindow.windowLevel = UIWindowLevelAlert - 1.25;
GHLSSFloatBallWindow.backgroundColor = [UIColor clearColor];
UIWindowScene *ballScene = GHLSSActiveWindowScene();
if (ballScene) GHLSSFloatBallWindow.windowScene = ballScene;
UIViewController *vc = [[UIViewController alloc] init];
UIView *root = [[UIView alloc] initWithFrame:CGRectMake(0, 0, ballSize, ballSize)];
root.backgroundColor = [UIColor clearColor];
vc.view = root;
UIButton *ball = [UIButton buttonWithType:UIButtonTypeCustom];
ball.frame = CGRectMake(0, 0, ballSize, ballSize);
ball.layer.cornerRadius = ballSize / 2.0;
ball.layer.masksToBounds = YES;
UIImage *ballImage = GHLSSLoadDoraemonImage();
if (ballImage && ballImage.CGImage) {
[ball setImage:ballImage forState:UIControlStateNormal];
GHLSSLogLine("v43 float ball image loaded");
} else {
ball.backgroundColor = [UIColor colorWithRed:0.83 green:0.68 blue:0.21 alpha:1.0];
ball.layer.borderWidth = 2.0;
ball.layer.borderColor = [UIColor blackColor].CGColor;
[ball setTitle:[NSString stringWithCString:"分" encoding:NSUTF8StringEncoding] forState:UIControlStateNormal];
[ball setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
ball.titleLabel.font = [UIFont boldSystemFontOfSize:14];
GHLSSLogLine("v43 float ball image missing, fallback to gold");
}
UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:GHLSSLauncherShared action:@selector(handleFloatBallTap:)];
tap.delegate = GHLSSLauncherShared;
[ball addGestureRecognizer:tap];
UIPanGestureRecognizer *drag = [[UIPanGestureRecognizer alloc] initWithTarget:GHLSSLauncherShared action:@selector(handleFloatBallDrag:)];
drag.minimumNumberOfTouches = 1;
drag.maximumNumberOfTouches = 1;
drag.delegate = GHLSSLauncherShared;
[ball addGestureRecognizer:drag];
[root addSubview:ball];
GHLSSFloatBallButton = ball;
GHLSSFloatBallWindow.rootViewController = vc;
GHLSSFloatBallWindow.hidden = !GHLSSReadFloatBallEnabled();
GHLSSLogLine("v43 float ball built");
}
// v42：設定卡片表格加一行（C 函數，rebuildSettingsCard 用；
// values 是分段控制的選項值，用 | 分隔；type 見 rebuildSettingsCard）。
static void GHLSSCardAddRow(int type, const char *key, const char *title, const char *subtitle, int page, int action, double minV, double maxV, double defV, const char *values) {
if (GHLSSSettingsCardRowCount >= 40) return;
GHLSSCardRow *r = &GHLSSSettingsCardRows[GHLSSSettingsCardRowCount++];
r->type = type;
r->page = page;
r->action = action;
r->minValue = minV;
r->maxValue = maxV;
r->defaultValue = defV;
if (key) { strncpy(r->key, key, sizeof(r->key) - 1); r->key[sizeof(r->key) - 1] = '\0'; } else r->key[0] = '\0';
if (title) { strncpy(r->title, title, sizeof(r->title) - 1); r->title[sizeof(r->title) - 1] = '\0'; } else r->title[0] = '\0';
if (subtitle) { strncpy(r->subtitle, subtitle, sizeof(r->subtitle) - 1); r->subtitle[sizeof(r->subtitle) - 1] = '\0'; } else r->subtitle[0] = '\0';
if (values) { strncpy(r->values, values, sizeof(r->values) - 1); r->values[sizeof(r->values) - 1] = '\0'; } else r->values[0] = '\0';
}
// v42：圖片居中裁成方形再縮到指定邊長（卡片頭像用，512；
// 設定頁那邊也有一份同款，兩個進程調不到彼此的函數）。
static UIImage *GHLSSSquareCropImage(UIImage *image, CGFloat size) {
if (!image || !image.CGImage || size <= 0) return nil;
CGSize src = image.size;
if (src.width <= 0 || src.height <= 0) return nil;
CGFloat side = (src.width < src.height) ? src.width : src.height;
CGRect crop = CGRectMake((src.width - side) / 2.0, (src.height - side) / 2.0, side, side);
CGImageRef cropped = CGImageCreateWithImageInRect(image.CGImage, crop);
if (!cropped) return nil;
UIImage *croppedImage = [UIImage imageWithCGImage:cropped scale:1.0 orientation:image.imageOrientation];
CGImageRelease(cropped);
if (!croppedImage) return nil;
UIGraphicsBeginImageContextWithOptions(CGSizeMake(size, size), NO, 1.0);
[croppedImage drawInRect:CGRectMake(0, 0, size, size)];
UIImage *out = UIGraphicsGetImageFromCurrentImageContext();
UIGraphicsEndImageContext();
return out;
}
// v42：2 秒定時輪詢（設定 App 改開關不發通知給 SpringBoard，
// dylib 不聽通知——每 2 秒自己讀一次 prefs 補狀態：演示模式、
// 全屏藏鈕、任務欄；每 60 秒查一次電量；設定頁寫的開三屏組合請求
// 也在這裡接（key openThreeScreenPair，見 checkPendingPairOpen）。
static void GHLSSSchedulePeriodicTick(void) {
dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
GHLSSApplyDemoMode();
GHLSSUpdateDoraemonVisibilityForFullscreen();
// v42：任務欄/懸浮球開了就建（2 秒內生效，不用 respring）。
if (GHLSSReadTaskbarEnabled()) GHLSSBuildTaskbarIfNeeded();
if (GHLSSReadFloatBallEnabled()) GHLSSBuildFloatBallIfNeeded();
GHLSSUpdateTaskbar();
GHLSSPeriodicTickCount++;
if (GHLSSPeriodicTickCount % 30 == 0) GHLSSCheckLowBattery();
if (GHLSSLauncherShared) [GHLSSLauncherShared checkPendingPairOpen];
GHLSSSchedulePeriodicTick();
});
}

@implementation GHLSSLauncher

// 允许我们的手势与系统手势同时识别（不抢系统手势）。
- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer {
return YES;
}

// v38：点按手势不接按钮上的触摸——控制条的点按（收起控制条）与
// 细条的点按（展开/收起控制条）都挂在这个代理上；点在红 X、黄
// 最小化、± 按钮上时，手势不认，按钮自己处理。点在控制条中间
//（标题处，UILabel 默认不接手势）才认，收起控制条。点在细条的
// 小 pill 上（普通 UIView）也认，展开/收起控制条。边缘滑动手势
// 的触摸在感应带上（不是按钮），不受影响。
// v41 修：哆啦A夢鈕自己的手勢（拖動 pan、長按、單擊、雙擊）掛在鈕上，
// 觸摸的 view 就是鈕本身（UIButton）——按上面那條一律回 NO，鈕的手勢
// 永遠收不到觸摸（v40 拖不動、長按關全部也死的根因）。所以先判：
// 手勢掛在哆啦A夢鈕上就回 YES；其他手勢碰到 UIButton 才回 NO。
- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldReceiveTouch:(UITouch *)touch {
if (gestureRecognizer.view == GHLSSDoraemonButton) return YES;
if ([touch.view isKindOfClass:[UIButton class]]) return NO;
return YES;
}

// v41：右邊緣滑動開 ARC（調度窗口設置：滑幾次、滑哪邊）。滑 1 次開
// （edgeSwipeCount=1）或 2 秒內滑兩次才開（=2，預設，防誤觸）；
// 第一次只記日誌。滑哪邊跟調度設定走（沒設就跟小窗顯示位置）。
- (void)handleEdgeSwipe:(UIScreenEdgePanGestureRecognizer *)recognizer {
if (recognizer.state != UIGestureRecognizerStateEnded) return;
// v42：邊緣滑動直接開三屏（開關開著時，邊緣滑動不再開 ARC、改開三屏；
// 次數/邊照調度設定走——下面那套計數邏輯不動，只換終點）。
if (GHLSSReadEdgeSwipeOpensThreeScreen()) {
if (GHLSSReadEdgeSwipeCount() <= 1) {
GHLSSLogLine("v43 edge swipe 1x, opening three screen");
[self openThreeScreenFromEdge];
return;
}
double now = CFAbsoluteTimeGetCurrent();
if (now - GHLSSLastSwipeTime < 2.0) {
GHLSSLastSwipeTime = 0;
GHLSSLogLine("v43 edge swipe 2nd, opening three screen");
[self openThreeScreenFromEdge];
} else {
GHLSSLastSwipeTime = now;
GHLSSLogLine("v43 edge swipe 1st, armed");
}
return;
}
// v41：ARC 總開關關了，邊緣滑動不再叫出 ARC（只剩浮窗和三屏路）。
if (!GHLSSReadARCEnabled()) {
GHLSSLogLine("v43 edge swipe ignored, arc disabled");
return;
}
if (GHLSSReadEdgeSwipeCount() <= 1) {
GHLSSLogLine("v43 edge swipe 1x, opening ARC");
[self showLauncher];
return;
}
double now = CFAbsoluteTimeGetCurrent();
if (now - GHLSSLastSwipeTime < 2.0) {
GHLSSLastSwipeTime = 0;
GHLSSLogLine("v43 edge swipe 2nd, opening ARC");
[self showLauncher];
} else {
GHLSSLastSwipeTime = now;
GHLSSLogLine("v43 edge swipe 1st, armed");
}
}

// v41：哆啦A夢鈕單擊——開 ARC（代替原來的 TouchUpInside：單擊手勢要
// 等雙擊失敗才認，雙擊時不誤開 ARC）。剛被長按過（關全部窗）——這次
// 單擊不開 ARC（長按鬆手不觸發）；旗標清掉，下次單擊恢復正常。
- (void)handleDoraemonButtonSingleTap:(UITapGestureRecognizer *)recognizer {
(void)recognizer;
if (GHLSSDoraemonLongPressed) {
GHLSSDoraemonLongPressed = NO;
GHLSSLogLine("v43 handle button tap suppressed after long press");
return;
}
// v41：ARC 總開關關了，哆啦A夢點按不再叫出 ARC（只剩浮窗和三屏路）。
if (!GHLSSReadARCEnabled()) {
GHLSSLogLine("v43 doraemon tap ignored, arc disabled");
return;
}
GHLSSLogLine("v43 handle button tapped, opening ARC");
[self showLauncher];
}
// v41：哆啦A夢鈕雙擊——輪切主窗（按順序表找下一個看得見的窗升為主窗）。
- (void)handleDoraemonButtonDoubleTap:(UITapGestureRecognizer *)recognizer {
(void)recognizer;
GHLSSLogLine("v43 doraemon double tapped");
[self cycleMainWindow];
}
// v41：把第 idx 個窗升為主窗（ARC 點已開的 App / 點 peek / 雙擊輪切）。
// 收著的從 peek 恢復（帶到最前、推前景）；看得見的帶到最前 + 推前景；
// 進程死了就走正常開窗流程（復用守衛銷毀重建）。
- (void)promoteWindowToMainIndex:(int)idx {
if (idx < 0 || idx >= GHLSS_APP_COUNT) return;
if (!GHLSSCacheWindows[idx]) return;
if (GHLSSCacheMinimized[idx]) {
if (GHLSSCachedEntryIsAlive(idx)) {
GHLSSLoadCacheToActive(idx);
[self restoreHostedWindow];
} else {
GHLSSLogLine("v43 promote entry stale, relaunching");
const char *bid = GHLSSCacheBundleIDs[idx];
if (bid && bid[0] != '\0') {
[self launchHostedApp:bid name:GHLSSAppNames[idx]];
}
}
return;
}
GHLSSLoadCacheToActive(idx);
GHLSSBringWindowToFront(GHLSSHostedWindow);
@try {
if (GHLSSHostedScene) {
[GHLSSHostedScene updateSettingsWithBlock:^(UIMutableApplicationSceneSettings *settings) {
settings.foreground = YES;
if ([settings respondsToSelector:@selector(setBackgrounded:)]) {
settings.backgrounded = NO;
}
}];
}
} @catch (NSException *e) {
(void)e;
GHLSSLogLine("v43 foreground push on promote failed");
}
char buf[256];
snprintf(buf, sizeof(buf), "v43 window promoted to main %s", GHLSSCacheBundleIDs[idx]);
GHLSSLogLine(buf);
}
// v41：雙擊哆啦A夢輪切主窗——按順序表找下一個看得見的窗升為主窗。
// 雙擊開關關了就不切；少於 2 個可見窗也沒得切。
- (void)cycleMainWindow {
if (!GHLSSReadDoraemonDoubleTapEnabled()) {
GHLSSLogLine("v43 window cycle disabled");
return;
}
int visible[GHLSS_APP_COUNT];
int n = 0;
for (int k = 0; k < GHLSS_APP_COUNT; k++) {
int idx = GHLSSFrontOrder[k];
if (GHLSSCacheWindows[idx] && !GHLSSCacheWindows[idx].hidden && !GHLSSCacheMinimized[idx]) visible[n++] = idx;
}
if (n <= 1) {
GHLSSLogLine("v43 window cycle nothing to cycle");
return;
}
int current = GHLSSActiveAppIndex;
int pos = -1;
for (int i = 0; i < n; i++) {
if (visible[i] == current) { pos = i; break; }
}
int next = visible[(pos + 1) % n];
[self promoteWindowToMainIndex:next];
char buf[256];
snprintf(buf, sizeof(buf), "v43 window cycled main %s", GHLSSCacheBundleIDs[next]);
GHLSSLogLine(buf);
}

// v40：长按哆啦A夢鈕——一键关掉全部已开的浮窗 +
// 已收起的 peek（第 7 项）。每个窗走现有的关闭路径（hide +
// background scene，不在 session 内 destroy scene，遵守 v35 规则；
// peek 清除）。关一个不影响别的——这里是全部关掉（用户主动长按）。
// 只在 Began 时做一次（长按中途状态变 Changed 不重复关）。
// 旗标不在 Ended/Cancelled 里清——触摸抬起时手势先变 Ended、按钮的
// 单击手势后到，先清会让 ARC 误开；旗标由 handleDoraemonButtonSingleTap
//（点按）与 handleDoraemonButtonDrag（拖动）清。
- (void)handleDoraemonButtonLongPress:(UILongPressGestureRecognizer *)recognizer {
if (recognizer.state != UIGestureRecognizerStateBegan) return;
GHLSSDoraemonLongPressed = YES;
GHLSSLogLine("v43 close all windows");
for (int i = 0; i < GHLSS_APP_COUNT; i++) {
if (GHLSSCacheWindows[i]) {
GHLSSLoadCacheToActive(i);
[self closeHostedWindow];
}
}
GHLSSUpdateDimOverlay();
}

// v40：拖哆啦A夢鈕沿右邊緣上下移動（皇上 11:50：鈕改可移動式，這樣比較
// 清楚）。x 固定在右邊緣不動（鈕的窗寬 56，中心 x = 屏寬 - 28），y 跟著
// 手指走、夾在 100 到 h-100（別頂到劉海、別掉出底邊）；放手就停在放下
// 的高度，不用吸附。鈕的大小（56pt）、樣子不變，鈕留在右邊緣（啟動器
// 是右側滑出的，移到左邊緣不在 v40 範圍）。
// 點按跟拖動分開：UIPanGestureRecognizer 有內建位移門檻（約 10pt），
// 手指沒怎麼動、快速抬起時 pan 不認、TouchUpInside 照舊開啟動器；
// 拖動了 pan 認出來（cancelsTouchesInView 預設 YES，會取消鈕的點按
// 追蹤），才算移動鈕的位置。
- (void)handleDoraemonButtonDrag:(UIPanGestureRecognizer *)recognizer {
if (!GHLSSDoraemonButtonWindow) return;
// v40：拖动钮时清掉长按旗标——长按后拖出按钮外、TouchUpInside 不触发
// 时的兜底（不然旗标一直留着，下次点按会被误 suppress）。
GHLSSDoraemonLongPressed = NO;
CGPoint point = [recognizer translationInView:GHLSSDoraemonButtonWindow];
[recognizer setTranslation:CGPointZero inView:GHLSSDoraemonButtonWindow];
CGRect screenBounds = [UIScreen mainScreen].bounds;
CGFloat doraemonW = GHLSSDoraemonButtonWindow.frame.size.width;
CGFloat fixedX = GHLSSIsDoraemonSideLeft() ? 0 : (screenBounds.size.width - doraemonW);
CGFloat minY = 100.0;
CGFloat maxY = screenBounds.size.height - 100.0;
CGPoint center = GHLSSDoraemonButtonWindow.center;
CGFloat newY = center.y + point.y;
if (newY < minY) newY = minY;
if (newY > maxY) newY = maxY;
// x 固定在設定那邊的邊緣（鈕的窗寬 doraemonW，中心 x = 邊緣 + 寬/2）。
GHLSSDoraemonButtonWindow.center = CGPointMake(fixedX + doraemonW / 2.0, newY);
if (recognizer.state == UIGestureRecognizerStateEnded) {
// v41：拖完記住 Y（prefs 鍵 doraemonButtonY），下次啟動恢復到這個高度。
GHLSSWritePrefsDouble("doraemonButtonY", (double)newY);
char buf[128];
snprintf(buf, sizeof(buf), "v43 doraemon button moved to y=%f", (double)newY);
GHLSSLogLine(buf);
}
}

// v41：點貼邊 peek——把這個 App 的窗叫回來升為主窗（恢復：帶到最前、
// 推前景）。peek 上 tag 是 App 下標；進程死了就走正常開窗流程
//（promoteWindowToMainIndex 裡面分叉處理）。
- (void)handleDockPeekTap:(UIButton *)sender {
NSInteger idx = sender.tag;
if (idx < 0 || idx >= GHLSS_APP_COUNT) return;
if (!GHLSSCacheWindows[idx]) return;
GHLSSLogLine("v43 docked peek tapped");
[self promoteWindowToMainIndex:(int)idx];
}

// v41：點貼邊 peek 右上角的小 X——徹底關掉這個窗（不再回來）。
// 窗藏起來、peek 收掉、scene 留著不銷毀（v35 規則）；別的窗不受影響。
// 下次從啟動器重開這個 App，直接復用緩存裡的 scene。
- (void)handleDockPeekClose:(UIButton *)sender {
NSInteger idx = sender.tag;
if (idx < 0 || idx >= GHLSS_APP_COUNT) return;
if (!GHLSSCacheWindows[idx]) return;
GHLSSLogLine("v43 docked peek closed");
GHLSSLoadCacheToActive((int)idx);
[self closeHostedWindow];
}

// v40：点阴影背景——按设定把最上面/主浮窗关掉或移到侧边贴成小卡。
// 主浮窗 = 活动窗（最近互动的，就是最上面那个）；活动窗不可见就
// 找第一个看得见的缓存窗。开着「側邊」就贴边成小卡，选「關閉」就关掉。
- (void)handleDimOverlayTap:(UITapGestureRecognizer *)recognizer {
(void)recognizer;
int idx = GHLSSActiveAppIndex;
if (idx < 0 || idx >= GHLSS_APP_COUNT || !GHLSSCacheWindows[idx] || GHLSSCacheWindows[idx].hidden || GHLSSCacheMinimized[idx]) {
idx = -1;
for (int i = 0; i < GHLSS_APP_COUNT; i++) {
if (GHLSSCacheWindows[i] && !GHLSSCacheWindows[i].hidden && !GHLSSCacheMinimized[i]) {
idx = i;
break;
}
}
}
if (idx < 0) {
GHLSSUpdateDimOverlay();
return;
}
GHLSSLoadCacheToActive(idx);
char *action = GHLSSReadPrefsCString("tapOutsideAction");
int isSide = !(action && strcmp(action, "close") == 0);
if (action) free(action);
if (isSide) {
GHLSSLogLine("v43 tap outside docked");
[self minimizeHostedWindow];
} else {
GHLSSLogLine("v43 tap outside closed");
[self closeHostedWindow];
}
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
snprintf(buf, sizeof(buf), "v43 app tapped %s", bid);
GHLSSLogLine(buf);
// v41：點選回饋（ARC 設置：震動/音效開關，預設都開）+ 最近使用記錄
//（點過就算，置頂/最近/常用三開都用這份記錄）。
if (GHLSSReadARCHaptics()) {
@try {
UIImpactFeedbackGenerator *haptic = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
[haptic impactOccurred];
} @catch (NSException *e) {
(void)e;
}
}
if (GHLSSReadARCTouchSound()) {
AudioServicesPlaySystemSound(1104);
}
GHLSSPushRecentApp(bid);
// v40：多窗（5.3）——「window busy」删掉，点启动器里的 App 不再被挡：
// ① 点的 App 已开着（窗看得见）→ 带到最前（层级升到 Alert - 1.75，
// 活动量切到它）；② 点的 App 收着（最小化/贴边小卡）→ 从小卡恢复
//（带到最前、推前景）；③ 没开的 → 在新窗打开，别的窗不动（不藏旧窗）。
// ④ 缓存里的项死了（进程死了）→ 走正常开窗流程，复用守卫会销毁
// 旧项重建（见 createHostedScene；销毁时连贴边小卡一起收掉）。
// scene 永遠不銷毀（v35 规则）：关窗/最小化都只藏窗 + 推后台，
// 切回来直接复用缓存里的旧 scene。
UIWindow *cachedWindow = GHLSSCacheWindows[idx];
if (cachedWindow && !GHLSSCacheMinimized[idx] && !cachedWindow.hidden) {
// 已开着：带到最前。
GHLSSLogLine("v43 window already open, bringing to front");
[self dismissLauncher];
GHLSSBringWindowToFront(cachedWindow);
GHLSSUpdateDimOverlay();
return;
}
if (cachedWindow && GHLSSCacheMinimized[idx]) {
// 收着：从小卡恢复（先确认进程还活着；死了就走正常开窗流程，
// 复用守卫会销毁旧项重建）。
if (GHLSSCachedEntryIsAlive(idx)) {
GHLSSLogLine("v43 window minimized, restoring from dock");
GHLSSLoadCacheToActive(idx);
[self restoreHostedWindow];
[self dismissLauncher];
return;
}
GHLSSLogLine("v43 docked entry stale, relaunching");
}
if (GHLSSHostedLaunching) {
GHLSSLogLine("v43 launch in progress, ignoring tap");
return;
}
// v41：ARC 打開方式（預設浮窗）：全屏打開走 SB 啟動探針（失敗退回浮窗）、
// 三屏走側窗（一次性的旗標，launchHostedApp 裡舊側窗先收成 peek）、
// 橫屏下強制浮窗（FV 的注意文字：橫屏狀態下 arc 上應用操作都是以浮窗
// 模式顯示）。
CGRect screenBounds = [UIScreen mainScreen].bounds;
BOOL isLandscape = screenBounds.size.width > screenBounds.size.height;
int openMode = GHLSSReadARCMenuOpenMode();
if (isLandscape && openMode != 1) {
GHLSSLogLine("v43 landscape forces floating");
openMode = 1;
}
// 先收启动器（v23 卡死的教训：收窗是便宜操作，先做；
// 启动是慢操作，后做——但要在主线程做，v24 放后台队列崩了）。
[self dismissLauncher];
if (openMode == 0) {
[self openAppFullscreen:bid];
return;
}
if (openMode == 2) {
GHLSSForceThreeScreenOnce = YES;
}
[self launchHostedApp:bid name:name];
}

// v41：ARC 打開方式「全屏打開」的探針——用 SpringBoard 自己的
// SBApplicationController 把 App 叫到前台全屏（tweak 在 SpringBoard
// 進程裡，調它自己的類是常規做法；LSApplicationWorkspace 從
// SpringBoard 調會堵主線程 ≥5 秒，已禁用，不走那條路）。類名/方法都
// 用運行時現做的字串找，找不到或調失敗就退回浮窗（不崩、不卡）。
// 橫屏下不走這裡（handleAppButton 已強制浮窗）。真機行為見 BUILD_LOG
// §113（探針，需皇上真機驗證）。
- (void)openAppFullscreen:(const char *)bundleID {
if (!bundleID || bundleID[0] == '\0') return;
BOOL opened = NO;
@try {
NSString *controllerName = [NSString stringWithCString:"SBApplicationController" encoding:NSUTF8StringEncoding];
Class controllerClass = NSClassFromString(controllerName);
if (controllerClass && [controllerClass respondsToSelector:@selector(sharedInstance)]) {
id controller = [controllerClass sharedInstance];
NSString *bidStr = [NSString stringWithCString:bundleID encoding:NSUTF8StringEncoding];
SEL appSel = NSSelectorFromString([NSString stringWithCString:"applicationWithBundleIdentifier:" encoding:NSUTF8StringEncoding]);
if (controller && [controller respondsToSelector:appSel]) {
id app = ((id (*)(id, SEL, id))objc_msgSend)(controller, appSel, bidStr);
if (app) {
SEL launchSel = NSSelectorFromString([NSString stringWithCString:"launchWithCompletion:" encoding:NSUTF8StringEncoding]);
if ([app respondsToSelector:launchSel]) {
((void (*)(id, SEL, id))objc_msgSend)(app, launchSel, nil);
opened = YES;
} else {
SEL activateSel = NSSelectorFromString([NSString stringWithCString:"activateWithCompletion:" encoding:NSUTF8StringEncoding]);
if ([app respondsToSelector:activateSel]) {
((void (*)(id, SEL, id))objc_msgSend)(app, activateSel, nil);
opened = YES;
}
}
}
}
}
} @catch (NSException *e) {
(void)e;
opened = NO;
}
if (opened) {
char buf[256];
snprintf(buf, sizeof(buf), "v43 fullscreen open %s", bundleID);
GHLSSLogLine(buf);
} else {
GHLSSLogLine("v43 fullscreen open unavailable, falling back to floating");
int fidx = GHLSSAppIndexForBundleID(bundleID);
const char *fname = (fidx >= 0) ? GHLSSAppNames[fidx] : bundleID;
[self launchHostedApp:bundleID name:fname];
}
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
GHLSSLogLine("v43 launch failed no memory");
GHLSSForceThreeScreenOnce = NO;
return;
}
GHLSSHostedLaunching = YES;
// v42：記下開窗前正在看的 App（開新窗時配對用；沒活動窗就清空）。
if (GHLSSActiveAppIndex >= 0 && GHLSSActiveAppIndex < GHLSS_APP_COUNT && GHLSSCacheBundleIDs[GHLSSActiveAppIndex][0] != '\0') {
strncpy(GHLSSPairPrevBid, GHLSSCacheBundleIDs[GHLSSActiveAppIndex], sizeof(GHLSSPairPrevBid) - 1);
GHLSSPairPrevBid[sizeof(GHLSSPairPrevBid) - 1] = '\0';
} else {
GHLSSPairPrevBid[0] = '\0';
}
char buf[256];
snprintf(buf, sizeof(buf), "v43 launch start %s", bundleID);
GHLSSLogLine(buf);
// v41：最近使用記錄（開窗就算用過一次）+ 三屏替換：三屏模式下一次
// 只能有一個側窗，舊側窗先收成 peek（scene 留著）。
GHLSSPushRecentApp(bundleID);
if (GHLSSReadThreeScreenEnabled() || GHLSSForceThreeScreenOnce) {
for (int i = 0; i < GHLSS_APP_COUNT; i++) {
if (GHLSSCacheIsSideDock[i] && GHLSSCacheWindows[i] && !GHLSSCacheWindows[i].hidden && !GHLSSCacheMinimized[i]) {
GHLSSLoadCacheToActive(i);
[self minimizeHostedWindow];
}
}
}
@try {
NSString *bidStr = [NSString stringWithCString:bidCopy encoding:NSUTF8StringEncoding];
if (!bidStr) {
GHLSSLogLine("v43 launch failed bad bundle id");
GHLSSForceThreeScreenOnce = NO;
GHLSSHostedLaunching = NO;
free(bidCopy);
free(nameCopy);
return;
}
RBSProcessIdentity *identity = [RBSProcessIdentity identityForEmbeddedApplicationIdentifier:bidStr];
if (!identity) {
GHLSSLogLine("v43 launch failed no identity");
GHLSSForceThreeScreenOnce = NO;
GHLSSHostedLaunching = NO;
free(bidCopy);
free(nameCopy);
return;
}
GHLSSLogLine("v43 identity ok");
// 先看 App 是不是已经在跑（单场景 App 已有全屏版时，再建
// 第二个 scene 可能只剩白窗——测前要先把目标 App 彻底关掉）。
RBSProcessPredicate *predicate = [RBSProcessPredicate predicateMatchingIdentity:identity];
RBSProcessHandle *handle = [RBSProcessHandle handleForPredicate:predicate error:nil];
int pid = handle ? [handle pid] : 0;
if (pid > 0) {
char pbuf[128];
snprintf(pbuf, sizeof(pbuf), "v43 app already running pid=%d", pid);
GHLSSLogLine(pbuf);
// 已经在跑：不走事务，直接去建 scene（和参考实现同一做法）。
dispatch_async(dispatch_get_main_queue(), ^{
[self createHostedSceneForBundleID:bidCopy name:nameCopy];
free(bidCopy);
free(nameCopy);
});
return;
}
GHLSSLogLine("v43 handle pid=0");
FBProcessManager *manager = [FBProcessManager sharedInstance];
if (!manager) {
GHLSSLogLine("v43 manager failed nil");
GHLSSForceThreeScreenOnce = NO;
GHLSSHostedLaunching = NO;
free(bidCopy);
free(nameCopy);
return;
}
GHLSSLogLine("v43 manager ok");
FBApplicationProcessLaunchTransaction *transaction = [[FBApplicationProcessLaunchTransaction alloc] initWithProcessIdentity:identity executionContextProvider:^id(void) {
GHLSSLogLine("v43 launch provider called");
FBMutableProcessExecutionContext *context = [FBMutableProcessExecutionContext new];
context.identity = identity;
context.environment = [NSDictionary dictionary];
context.launchIntent = 4;
return [manager launchProcessWithContext:context];
}];
if (!transaction) {
GHLSSLogLine("v43 transaction failed nil");
GHLSSForceThreeScreenOnce = NO;
GHLSSHostedLaunching = NO;
free(bidCopy);
free(nameCopy);
return;
}
GHLSSLogLine("v43 transaction created");
[transaction setCompletionBlock:^{
// 事务完成可能跑在任意队列——场景创建回主线程做。
dispatch_async(dispatch_get_main_queue(), ^{
[self createHostedSceneForBundleID:bidCopy name:nameCopy];
free(bidCopy);
free(nameCopy);
});
}];
[transaction begin];
GHLSSLogLine("v43 begin called");
GHLSSLogLine("v43 launch transaction begun");
} @catch (NSException *e) {
(void)e;
GHLSSLogLine("v43 launch failed exception");
GHLSSForceThreeScreenOnce = NO;
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
snprintf(buf, sizeof(buf), "v43 scene start %s", bundleID);
GHLSSLogLine(buf);
NSString *bidStr = [NSString stringWithCString:bundleID encoding:NSUTF8StringEncoding];
if (!bidStr) {
GHLSSLogLine("v43 scene failed no bid");
GHLSSForceThreeScreenOnce = NO;
return;
}
RBSProcessIdentity *identity = [RBSProcessIdentity identityForEmbeddedApplicationIdentifier:bidStr];
RBSProcessPredicate *predicate = [RBSProcessPredicate predicateMatchingIdentity:identity];
RBSProcessHandle *handle = [RBSProcessHandle handleForPredicate:predicate error:nil];
int pid = handle ? [handle pid] : 0;
if (pid <= 0) {
GHLSSLogLine("v43 scene failed no process");
GHLSSForceThreeScreenOnce = NO;
return;
}
snprintf(buf, sizeof(buf), "v43 process launched pid=%d", pid);
GHLSSLogLine(buf);
// v35 复用守卫：缓存里已有这个 App 的 scene（关窗或切走时没销毁）
// 且进程还是同一个 pid、presenter 与它的 view 还活着——直接复用，
// 不建新 scene。固定 ID 一个会话里只建一次，残留撞不到。scene 旧
// 了（进程换了或 presenter/view 没了）就先销毁缓存里那一项再建
//（掉下去之前先清掉旧 scene，见下面；只调销毁缓存那一项，不碰
// 活动量）。查缓存不查活动量：切走后活动量是空的，旧 scene 只在
// 缓存里。
int cacheIdx = GHLSSAppIndexForBundleID(bundleID);
if (cacheIdx >= 0 && GHLSSCacheScenes[cacheIdx]) {
// v38：复用守卫分叉——presenter 的项看 presenter 与 view 活着，
// layer-host 的项（presenter 是 nil）看 layerHostView 活着；
// 只要一边活着就复用，不建新 scene。
if (pid == GHLSSCachePids[cacheIdx] && ((GHLSSCachePresenters[cacheIdx] && GHLSSCachePresenters[cacheIdx].presentationView) || GHLSSCacheLayerHostViews[cacheIdx])) {
if (GHLSSCacheSceneIDs[cacheIdx]) {
char rbuf[256];
snprintf(rbuf, sizeof(rbuf), "v43 reusing cached scene %s", [GHLSSCacheSceneIDs[cacheIdx] UTF8String]);
GHLSSLogLine(rbuf);
} else {
GHLSSLogLine("v43 reusing cached scene");
}
GHLSSLoadCacheToActive(cacheIdx);
// v41：三屏一次性的旗標在這裡清掉（復用舊 scene 不重建窗，
// 側窗轉換下一版再做；這次先以普通浮窗打開，不讓旗標漏到下一次開窗）。
if (GHLSSForceThreeScreenOnce) {
GHLSSForceThreeScreenOnce = NO;
GHLSSLogLine("v43 three screen request on cached window, opened as floating");
}
if (GHLSSHostedMinimized) {
[self restoreHostedWindow];
} else if (GHLSSHostedWindow) {
GHLSSHostedWindow.hidden = NO;
// v40：复用的窗已开着——带到最前（别的窗回基础层级，这个窗升到
// 最前层级、活动量切到它），再推前景。
GHLSSBringWindowToFront(GHLSSHostedWindow);
@try {
[GHLSSHostedScene updateSettingsWithBlock:^(UIMutableApplicationSceneSettings *settings) {
settings.foreground = YES;
if ([settings respondsToSelector:@selector(setBackgrounded:)]) {
settings.backgrounded = NO;
}
}];
GHLSSLogLine("v43 foreground pushed on reuse");
} @catch (NSException *e) {
(void)e;
GHLSSLogLine("v43 foreground push on reuse failed");
}
}
return;
}
GHLSSLogLine("v43 stored scene stale, destroying");
GHLSSDestroyCachedEntryAtIndex(cacheIdx);
}
// v35：sceneID 仍是固定格式 `sceneID:<bundleID>-default`（v28 的
// 格式）——v33 的每次新 UUID 让计算器黑屏：已在跑着的单 scene App
// 只往自己默认 ID 的 scene 里画，全新 UUID 的 scene 它认不出来、
// 不往里画（§84 定死）。固定 ID + 低层级（v29）两个条件都要，缺
// 一不可。残留撞 ID 的崩不靠新 ID 修，靠会话内永不销毁（见文件头
// v35 节：关窗与切走都只藏窗，复用缓存里的旧 scene；同一 ID 一个
// 会话只建一次）。persistenceIdentifier 仍与 sceneID 相同（下面那
// 行本来就是 settings.persistenceIdentifier = sceneID）。主线程启
// 动、foreground 推送、1.5 秒 + 4 秒重试，其余什么都不动。
NSString *fmt = [NSString stringWithCString:"sceneID:%s-default" encoding:NSUTF8StringEncoding];
NSString *sceneID = [NSString stringWithFormat:fmt, bundleID];
// v38：已在跑的 App，先查它已有的主 scene（KonbanXV 的路，见文件
// 头 v38 节第 1 项）。找到就走新路（托管已有主 scene，不 createScene、
// 不撞固定 ID）；找不到、或新路任何一步失败，就走老路（下面
// registerProcessForAuditToken + createScene），不崩、不拦、不跳过。
FBScene *existingScene = GHLSSExistingMainSceneForBundleID(bundleID);
BOOL hostedExisting = NO;
if (existingScene) {
char ebuf[256];
snprintf(ebuf, sizeof(ebuf), "v43 hosting existing scene %s", bundleID);
GHLSSLogLine(ebuf);
@try {
Class layerHostClass = objc_getClass("_UISceneLayerHostContainerView");
UIView *layerHostView = nil;
if (layerHostClass) {
layerHostView = [[layerHostClass alloc] initWithScene:existingScene debugDescription:nil];
}
if (layerHostView) {
Class contextClass = objc_getClass("UIScenePresentationContext");
if (contextClass) {
id context = [[contextClass alloc] _initWithDefaultValues];
if (context) [(_UISceneLayerHostContainerView *)layerHostView _setPresentationContext:context];
}
// 已有主 scene 不推 frame、不动 insets（见文件头 v38 节第 1 项）；
// 只推 foreground（建窗时同一个已证明能用的做法），让它在浮窗里画。
@try {
[existingScene updateSettingsWithBlock:^(UIMutableApplicationSceneSettings *settings) {
settings.foreground = YES;
if ([settings respondsToSelector:@selector(setBackgrounded:)]) {
settings.backgrounded = NO;
}
}];
GHLSSLogLine("v43 foreground pushed on existing scene");
} @catch (NSException *e) {
(void)e;
GHLSSLogLine("v43 foreground push on existing scene failed");
}
GHLSSLogLine("v43 layer host ready");
[self buildHostedWindowForBundleID:bundleID name:name scene:existingScene presenter:nil layerHostView:layerHostView sceneID:sceneID pid:pid];
hostedExisting = YES;
} else {
GHLSSLogLine("v43 layer host view nil, creating new");
}
} @catch (NSException *e) {
(void)e;
GHLSSLogLine("v43 layer host failed, creating new");
}
}
if (hostedExisting) return;
GHLSSLogLine("v43 no existing scene, creating new");
FBProcessManager *manager = [FBProcessManager sharedInstance];
[manager registerProcessForAuditToken:[handle auditToken]];
GHLSSLogLine("v43 creating new scene");
char idbuf[256];
snprintf(idbuf, sizeof(idbuf), "v43 sceneID %s", [sceneID UTF8String]);
GHLSSLogLine(idbuf);
FBSMutableSceneDefinition *definition = [FBSMutableSceneDefinition definition];
definition.identity = [FBSSceneIdentity identityForIdentifier:sceneID];
definition.clientIdentity = [FBSSceneClientIdentity identityForProcessIdentity:[handle identity]];
definition.specification = [UIApplicationSceneSpecification specification];
FBSMutableSceneParameters *parameters = [FBSMutableSceneParameters parametersForSpecification:definition.specification];
UIMutableApplicationSceneSettings *settings = [UIMutableApplicationSceneSettings new];
settings.canShowAlerts = YES;
settings.cornerRadiusConfiguration = [[BSCornerRadiusConfiguration alloc] initWithTopLeft:GHLSSReadCornerRadius() bottomLeft:GHLSSReadCornerRadius() bottomRight:GHLSSReadCornerRadius() topRight:GHLSSReadCornerRadius()];
settings.displayConfiguration = [[UIScreen mainScreen] displayConfiguration];
settings.foreground = YES;
settings.deviceOrientation = UIDeviceOrientationPortrait;
settings.interfaceOrientation = UIInterfaceOrientationPortrait;
// v38：frame = 内容尺寸 ÷ 默认 scale（反向耦合，见
// GHLSSSceneFrameSizeForBundleID）：计算器 320x693 ÷ 0.77 ≈ 414x896
//（屏幕尺寸，它的远端图层得是整张全屏画面），别的 App 320x480 ÷
// 1.0 = 320x480。presentationView 的尺寸就是 frame 的尺寸（日志里那行
// presentationView w=... 会印证：计算器应是 414x896）。
CGSize sceneFrameSize = GHLSSSceneFrameSizeForBundleID(bundleID);
settings.frame = CGRectMake(0, 0, sceneFrameSize.width, sceneFrameSize.height);
settings.level = 1;
settings.persistenceIdentifier = sceneID;
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
GHLSSLogLine("v43 scene failed nil scene");
return;
}
GHLSSLogLine("v43 scene created");
id presenterManager = [scene uiPresentationManager];
if (!presenterManager) {
GHLSSLogLine("v43 presenter failed no manager");
return;
}
_UIScenePresenter *presenter = [presenterManager createPresenterWithIdentifier:sceneID];
if (!presenter) {
GHLSSLogLine("v43 presenter failed nil");
return;
}
[presenter modifyPresentationContext:^(UIMutableScenePresentationContext *context) {
context.appearanceStyle = 2;
}];
[presenter activate];
if (!presenter.presentationView) {
GHLSSLogLine("v43 presenter failed no view");
return;
}
// v28：记 presenterView 的尺寸与有没有 layer——计算器在 v26 还是黑的
//（别的 App 都能画出来），要先排除 view 本身没尺寸、没嵌进去的可能。
// 只记日志，不改任何行为；同样包 @try/@catch，出错只记日志。
@try {
char pbuf[128];
UIView *pv = presenter.presentationView;
snprintf(pbuf, sizeof(pbuf), "v43 presentationView w=%d h=%d layer=%d", (int)pv.bounds.size.width, (int)pv.bounds.size.height, pv.layer ? 1 : 0);
GHLSSLogLine(pbuf);
} @catch (NSException *e) {
(void)e;
GHLSSLogLine("v43 presentationView failed");
}
// v28：scene 建好了、presenter 也 activate 了，但 v25 的窗是黑的——
// 计算器进程没往 scene 里画。KonbanXV 的做法是建完 scene 就把
// foreground 显式推给客户端（"important for the view to be
// interactable"）。先记 contentState（0 没就绪、1 准备中、2 就绪），
// 再用已经证明能用的 updateSettingsWithBlock: 把 foreground=YES 推
// 一遍、再记一次 contentState。推 foreground 绝不能拖垮建窗：
// 单独包 @try/@catch，出错只记日志、继续建窗。
@try {
char cbuf[128];
snprintf(cbuf, sizeof(cbuf), "v43 scene contentState=%lu", (unsigned long)[scene contentState]);
GHLSSLogLine(cbuf);
} @catch (NSException *e) {
(void)e;
GHLSSLogLine("v43 scene contentState failed");
}
@try {
[scene updateSettingsWithBlock:^(UIMutableApplicationSceneSettings *settings) {
settings.foreground = YES;
}];
char fbuf[128];
snprintf(fbuf, sizeof(fbuf), "v43 foreground pushed contentState=%lu", (unsigned long)[scene contentState]);
GHLSSLogLine(fbuf);
} @catch (NSException *e) {
(void)e;
GHLSSLogLine("v43 foreground push failed");
}
GHLSSLogLine("v43 presenter ready");
[self buildHostedWindowForBundleID:bundleID name:name scene:scene presenter:presenter layerHostView:nil sceneID:sceneID pid:pid];
} @catch (NSException *e) {
(void)e;
GHLSSLogLine("v43 scene failed exception");
} @finally {
GHLSSHostedLaunching = NO;
}
}

// 建 FV 风格的悬浮窗（V5_DESIGN.md §4.4 + 附录 D）：
// 圆角 35、有阴影、离屏幕边缘有距离、44pt 标题栏（可拖动）、
// 红关闭钮、黄最小化钮、右下角缩放手柄。内容区嵌 presenter 的 view。
- (void)buildHostedWindowForBundleID:(const char *)bundleID name:(const char *)name scene:(FBScene *)scene presenter:(_UIScenePresenter *)presenter layerHostView:(UIView *)layerHostView sceneID:(NSString *)sceneID pid:(int)pid {
@try {
CGRect screenBounds = [UIScreen mainScreen].bounds;
// v38：窗尺寸按 App 定——计算器拿 320x693（内容就是窗，没有标题栏
// 了；之前 320x737 是含 44pt 标题栏的总高，内容几何不变），别的
// App 拿 350x757（85% 宽、和屏幕同宽高比）。见
// GHLSSHostedContentSizeForBundleID。
CGSize hostedContentSize = GHLSSHostedContentSizeForBundleID(bundleID);
CGFloat winW = hostedContentSize.width;
CGFloat winH = hostedContentSize.height;
// v42：浮窗大小預設（小 280x600 / 中 350x757 / 大 414x800；中 + 計算器
// 仍用自己的 320x693；有存過的位置/大小或側窗時，後面會蓋掉這裡）。
int sizePreset = GHLSSReadWindowSizePreset();
if (sizePreset == 0) {
winW = 280.0;
winH = 600.0;
hostedContentSize = CGSizeMake(winW, winH);
} else if (sizePreset == 2) {
winW = 414.0;
winH = 800.0;
hostedContentSize = CGSizeMake(winW, winH);
}
// v38：新窗的 scaleRatio 用这个 App 的默认值（计算器 0.77，别的 1.0）。
GHLSSHostedScaleRatio = GHLSSDefaultScaleRatioForBundleID(bundleID);
GHLSSHostedIsSideDock = NO;
GHLSSHostedSideDivider = nil;
CGRect winFrame = CGRectMake((screenBounds.size.width - winW) / 2.0, (screenBounds.size.height - winH) / 2.0, winW, winH);
// v40：恢复上次的位置/大小/缩放（有存过的才恢复；没有就走默认+错位）。
// 存的是窗中心 + 窗尺寸 + scale；恢复后夹在屏幕内（左右留 8pt、
// 顶留安全距离、底留 8pt），缩放夹在 0.5–2.0。内容按恢复后的尺寸嵌
//（hostedContentSize 改成恢复的窗尺寸，反向耦合按它算，内容贴边
// 填满、不错位；建窗后再调一次 resizeHostedSceneToContentSize，把
// scene frame 也推到恢复的尺寸，见下面 window shown 后）。
BOOL geometryRestored = NO;
CGFloat restoredW = 0, restoredH = 0;
{
int geoIdx = GHLSSAppIndexForBundleID(bundleID);
CGFloat geoCX, geoCY, geoW, geoH, geoScale;
// v41：豎屏固定中心開著時不恢復存過的位置（開了這個開關，開窗固定
// 為屏幕中心；跟 v40「記住位置大小」是反的）。
if (geoIdx >= 0 && !GHLSSReadCenterOnOpen() && GHLSSRestoreGeometryForIndex(geoIdx, &geoCX, &geoCY, &geoW, &geoH, &geoScale)) {
CGFloat safeDistance = GHLSSReadSafeDistance();
CGFloat minCX = geoW / 2.0 + 8.0;
CGFloat maxCX = screenBounds.size.width - geoW / 2.0 - 8.0;
CGFloat minCY = safeDistance + geoH / 2.0;
CGFloat maxCY = screenBounds.size.height - geoH / 2.0 - 8.0;
if (geoCX < minCX) geoCX = minCX;
if (geoCX > maxCX) geoCX = maxCX;
if (geoCY < minCY) geoCY = minCY;
if (geoCY > maxCY) geoCY = maxCY;
winW = geoW;
winH = geoH;
hostedContentSize = CGSizeMake(geoW, geoH);
GHLSSHostedScaleRatio = geoScale;
winFrame = CGRectMake(geoCX - geoW / 2.0, geoCY - geoH / 2.0, geoW, geoH);
geometryRestored = YES;
restoredW = geoW;
restoredH = geoH;
GHLSSLogLine("v43 geometry restored");
}
}
if (!geometryRestored) {
// v40：新窗错位放——每多一个看得见的窗错开 44pt（横竖交错），不直接
// 盖在旧窗正上方；夹在屏幕里（左右留 8pt、顶留安全距离、底留 8pt）。
int visibleCount = GHLSSVisibleHostedWindowCount();
if (visibleCount > 0) {
CGFloat step = GHLSS_NEW_WINDOW_OFFSET;
CGFloat dx = step * visibleCount;
CGFloat dy = step * visibleCount;
CGFloat minX = 8.0;
CGFloat maxX = screenBounds.size.width - winW - 8.0;
CGFloat minY = GHLSSReadSafeDistance();
CGFloat maxY = screenBounds.size.height - winH - 8.0;
CGFloat nx = winFrame.origin.x + dx;
CGFloat ny = winFrame.origin.y + dy;
if (nx > maxX) nx = maxX;
if (nx < minX) nx = minX;
if (ny > maxY) ny = maxY;
if (ny < minY) ny = minY;
winFrame = CGRectMake(nx, ny, winW, winH);
}
}
// v41：三屏側窗（開關開著、或 ARC 打開方式選「三屏」這一次）：
// 窄豎屏貼邊（寬 30% 屏寬，全高減安全距離），App 在窄 scene 裡按
// 豎屏重排版（scene frame = 側窗尺寸，scale 1.0）；已在跑的 App
// 托管現有主 scene，窄 scene 推不過去（見 BUILD_LOG §113），內容
// 按寬縮放、頂對齊，下方留黑。主窗不自動縮（底下那個 App 本來就是
// 全屏在跑）。建窗末尾的 resize 推送到側窗尺寸（restoredW/H 改寫），
// 所以側窗的 scene frame 是對的。
BOOL sideDock = GHLSSReadThreeScreenEnabled() || GHLSSForceThreeScreenOnce;
GHLSSForceThreeScreenOnce = NO;
if (sideDock) {
CGFloat safeDistance = GHLSSReadSafeDistance();
// v42：側窗寬度走預設（窄 25% / 中 30% / 寬 40%，預設中）。
CGFloat sideW = screenBounds.size.width * GHLSSReadSideWidthFraction();
CGFloat sideH = screenBounds.size.height - safeDistance * 2.0;
BOOL dockLeft = GHLSSIsWindowPositionLeft();
CGFloat sideX = dockLeft ? 0 : (screenBounds.size.width - sideW);
winW = sideW;
winH = sideH;
hostedContentSize = CGSizeMake(sideW, sideH);
GHLSSHostedScaleRatio = 1.0;
winFrame = CGRectMake(sideX, safeDistance, sideW, sideH);
GHLSSHostedIsSideDock = YES;
geometryRestored = YES;
restoredW = sideW;
restoredH = sideH;
GHLSSLogLine("v43 three screen side dock");
}
if (strcmp(bundleID, "com.apple.calculator") == 0) {
char wbuf[160];
CGFloat calcScale = hostedContentSize.width / GHLSSSceneFrameSizeForBundleID(bundleID).width;
snprintf(wbuf, sizeof(wbuf), "v43 calculator window %dx%d scale %d%%", (int)winW, (int)winH, (int)(calcScale * 100.0));
GHLSSLogLine(wbuf);
}
GHLSSHostedWindow = [[UIWindow alloc] initWithFrame:winFrame];
// v29：层级降到 Alert 之下——锁屏约在 Alert（2000），锁屏必须盖住我们的窗，密码键盘才能点到（2026-11-13 锁屏密码输不进去的 bug）。
// v40：基础层级用常量 Alert - 2（1998）；新窗建好后带到最前
//（Alert - 1.75，见下面 window shown 后）。
GHLSSHostedWindow.windowLevel = GHLSS_HOSTED_BASE_LEVEL;
GHLSSHostedWindow.backgroundColor = [UIColor clearColor];
UIWindowScene *hostedScene = GHLSSActiveWindowScene();
if (hostedScene) {
GHLSSHostedWindow.windowScene = hostedScene;
} else {
GHLSSLogLine("v43 hosted scene nil");
}
// 窗的阴影与圆角（画在窗的 layer 上；内容容器自己裁圆角）。
// v41：圆角、阴影开关/透明度/半径都走设定（浮窗设置 → 浮窗阴影设置）。
// v42：側窗圓角/陰影跟浮窗分開調（側窗走 side*，浮窗走原來的）。
GHLSSHostedWindow.layer.shadowColor = [UIColor blackColor].CGColor;
if (GHLSSHostedIsSideDock) {
GHLSSHostedWindow.layer.cornerRadius = GHLSSReadSideCornerRadius();
GHLSSHostedWindow.layer.shadowOpacity = GHLSSReadSideShadowEnabled() ? GHLSSReadSideShadowOpacity() : 0.0;
GHLSSHostedWindow.layer.shadowRadius = GHLSSReadSideShadowRadius();
} else {
GHLSSHostedWindow.layer.cornerRadius = GHLSSReadCornerRadius();
GHLSSHostedWindow.layer.shadowOpacity = GHLSSReadShadowEnabled() ? GHLSSReadShadowOpacity() : 0.0;
GHLSSHostedWindow.layer.shadowRadius = GHLSSReadShadowRadius();
}
GHLSSHostedWindow.layer.shadowOffset = CGSizeMake(0, 6);
UIViewController *vc = [[UIViewController alloc] init];
// 内容容器：圆角 35、裁掉超出部分、细边框。v36：底色由白改黑——万一
// 哪有缝，露黑不露白（v35 计算器两侧的白边就是内容区的白色底）。
UIView *container = [[UIView alloc] initWithFrame:CGRectMake(0, 0, winW, winH)];
container.backgroundColor = [UIColor blackColor];
// v42：側窗圓角跟浮窗分開（側窗走 sideCornerRadius）。
container.layer.cornerRadius = GHLSSHostedIsSideDock ? GHLSSReadSideCornerRadius() : GHLSSReadCornerRadius();
container.layer.masksToBounds = YES;
container.layer.borderWidth = 1.0;
container.layer.borderColor = [UIColor colorWithWhite:0.8 alpha:1.0].CGColor;
vc.view = container;
GHLSSHostedContainer = container;
// v38：内容区就是整个窗（没有标题栏了，App 内容从顶到底贴边填满）。
// v36：底色由白改黑（同容器）。
UIView *contentView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, winW, winH)];
contentView.backgroundColor = [UIColor blackColor];
// v39：contentView layer 的 anchorPoint 改 (0,0)、position (0,0)
//（frame 仍是 (0,0,winW,winH)）。sublayerTransform 是繞 layer 的
// anchorPoint 縮——預設 (0.5,0.5) 是中心，scale<1.0 的 App（計算機
// 0.77、設置 0.845）會往右下偏中心×(1−scale)，見 BUILD_LOG §108；
// 改成左上錨點後，建窗、resize、滑桿的 sublayerTransform 全都繞左上縮。
contentView.layer.anchorPoint = CGPointMake(0, 0);
contentView.layer.position = CGPointMake(0, 0);
[container addSubview:contentView];
GHLSSHostedContentView = contentView;
// v38：嵌 view 分叉——有 presenter 走新建 scene 的老路（反向耦合），
// 有 layerHostView 走托管已有主 scene 的新路（bounds = 屏幕尺寸，
// 显示 scale 用 GHLSSLayerHostDisplayScaleForContentSizeAndBundleID，
// 不推 scene frame）。presenter 与 layerHostView 有且只有一个非空。
if (presenter && presenter.presentationView) {
UIView *presenterView = presenter.presentationView;
// v38：反向耦合（所有 App 都一样，不再有计算器特判）——
// presentationView 的 bounds = scene frame 尺寸（内容尺寸 ÷ scale），
// anchorPoint (0,0)、position (0,0)（FBAL 的左上对齐做法）；内容区
// layer 的 sublayerTransform 缩回窗尺寸。autoresizing 关掉，尺寸由
// 缩放管（resize 与滑杆时重算，见 GHLSSApplyScaleToHostedWindow）。
CGSize frameSize = GHLSSSceneFrameSizeForContentSizeAndScale(hostedContentSize, GHLSSHostedScaleRatio);
presenterView.autoresizingMask = UIViewAutoresizingNone;
presenterView.bounds = CGRectMake(0, 0, frameSize.width, frameSize.height);
presenterView.layer.anchorPoint = CGPointMake(0, 0);
presenterView.layer.position = CGPointMake(0, 0);
[contentView insertSubview:presenterView atIndex:0];
contentView.layer.sublayerTransform = CATransform3DMakeScale(GHLSSHostedScaleRatio, GHLSSHostedScaleRatio, 1.0);
{
char sbuf[128];
snprintf(sbuf, sizeof(sbuf), "v43 scene scaled %d%%", (int)(GHLSSHostedScaleRatio * 100.0));
GHLSSLogLine(sbuf);
}
} else if (layerHostView) {
CGSize screenSize = [UIScreen mainScreen].bounds.size;
layerHostView.autoresizingMask = UIViewAutoresizingNone;
layerHostView.bounds = CGRectMake(0, 0, screenSize.width, screenSize.height);
layerHostView.layer.anchorPoint = CGPointMake(0, 0);
layerHostView.layer.position = CGPointMake(0, 0);
[contentView insertSubview:layerHostView atIndex:0];
CGFloat displayScale = GHLSSLayerHostDisplayScaleForContentSizeAndBundleID(hostedContentSize, bundleID);
contentView.layer.sublayerTransform = CATransform3DMakeScale(displayScale, displayScale, 1.0);
{
char sbuf[128];
snprintf(sbuf, sizeof(sbuf), "v43 layer host scaled %d%%", (int)(displayScale * 100.0));
GHLSSLogLine(sbuf);
}
} else {
GHLSSLogLine("v43 window failed no view to embed");
return;
}
// v38：记实际嵌进去的 view 的 frame——注意：frame 现在是图层的
// 尺寸（未缩放），显示尺寸 = frame × scale（sublayerTransform 缩
// 回）。新建 scene 的计算器应是 0,0 414x896（图层尺寸）+ scene
// scaled 77%（显示 320x693）；新建 scene 的非计算器 App 应是
// 0,0 350x757 + scaled 100%；layer-host 的 App 应是 0,0 414x896
//（屏幕尺寸）+ layer host scaled 85%（一般 App，显示 350x757）
// 或 77%（计算器，显示 320x693）。
@try {
UIView *embeddedView = (presenter && presenter.presentationView) ? presenter.presentationView : layerHostView;
CGRect pvFrame = embeddedView.frame;
char fbuf[160];
snprintf(fbuf, sizeof(fbuf), "v43 hosted view frame %d,%d %dx%d", (int)pvFrame.origin.x, (int)pvFrame.origin.y, (int)pvFrame.size.width, (int)pvFrame.size.height);
GHLSSLogLine(fbuf);
} @catch (NSException *e) {
(void)e;
GHLSSLogLine("v43 hosted view frame failed");
}
// v38：缩放滑杆条（默认藏着）——点控制条的 ± 钮展开，盖在内容区顶
// 上（控制条下面，y=36；半透明黑底，不改窗尺寸、不推内容区）。
// 里面一条 UISlider（0.5–2.0，步进 0.01）+ 右边一个百分比。拖滑杆
// 改 scaleRatio，走同一条反向耦合路径。滑杆条是 container 的子视图
//（在内容区之上），跟着窗一起缓存、一起藏/显示。
// v42：滑桿條加高到 72pt，第二行放浮窗大小預設（小/中/大三顆鈕，
// 點一下窗就變那個尺寸，走 resize 路；窄窗（<240pt）不放這行）。
UIView *scaleBar = [[UIView alloc] initWithFrame:CGRectMake(0, GHLSS_HOSTED_CONTROL_H, winW, 72)];
scaleBar.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.85];
scaleBar.hidden = YES;
[container addSubview:scaleBar];
GHLSSHostedScaleSliderBar = scaleBar;
UISlider *scaleSlider = [[UISlider alloc] initWithFrame:CGRectMake(10, 3, winW - 70, 30)];
scaleSlider.minimumValue = 0.5;
scaleSlider.maximumValue = 2.0;
scaleSlider.value = GHLSSHostedScaleRatio;
scaleSlider.minimumTrackTintColor = [UIColor colorWithRed:0.83 green:0.68 blue:0.21 alpha:1.0];
[scaleSlider addTarget:self action:@selector(handleScaleSlider:) forControlEvents:UIControlEventValueChanged];
// v40：滑杆松手时存一次位置/大小/缩放（ValueChanged 拖动中一直在触发，
// 每动一下都写 prefs 太费；松手（TouchUpInside/Outside）才存一次）。
[scaleSlider addTarget:self action:@selector(handleScaleSliderEnded:) forControlEvents:UIControlEventTouchUpInside | UIControlEventTouchUpOutside];
[scaleBar addSubview:scaleSlider];
GHLSSHostedScaleSlider = scaleSlider;
UILabel *scaleLabel = [[UILabel alloc] initWithFrame:CGRectMake(winW - 56, 3, 46, 30)];
{
char pbuf[32];
snprintf(pbuf, sizeof(pbuf), "%d%%", (int)(GHLSSHostedScaleRatio * 100.0));
scaleLabel.text = [NSString stringWithCString:pbuf encoding:NSUTF8StringEncoding];
}
scaleLabel.textColor = [UIColor whiteColor];
scaleLabel.font = [UIFont boldSystemFontOfSize:14];
scaleLabel.textAlignment = NSTextAlignmentCenter;
[scaleBar addSubview:scaleLabel];
GHLSSHostedScaleLabel = scaleLabel;
if (winW >= 240.0) {
UILabel *sizeTitle = [[UILabel alloc] initWithFrame:CGRectMake(10, 39, 40, 28)];
sizeTitle.text = [NSString stringWithCString:"尺寸" encoding:NSUTF8StringEncoding];
sizeTitle.textColor = [[UIColor whiteColor] colorWithAlphaComponent:0.8];
sizeTitle.font = [UIFont systemFontOfSize:13];
[scaleBar addSubview:sizeTitle];
const char *sizeNames[3] = {"小", "中", "大"};
int currentPreset = GHLSSReadWindowSizePreset();
for (int sp = 0; sp < 3; sp++) {
UIButton *sizeBtn = [UIButton buttonWithType:UIButtonTypeCustom];
sizeBtn.frame = CGRectMake(winW - 140 + sp * 44, 39, 40, 28);
sizeBtn.tag = 100 + sp;
sizeBtn.backgroundColor = [UIColor colorWithRed:0.25 green:0.25 blue:0.25 alpha:1.0];
sizeBtn.layer.cornerRadius = 8.0;
sizeBtn.layer.borderWidth = (sp == currentPreset) ? 2.0 : 1.0;
sizeBtn.layer.borderColor = (sp == currentPreset) ? [UIColor colorWithRed:0.83 green:0.68 blue:0.21 alpha:1.0].CGColor : [[UIColor whiteColor] colorWithAlphaComponent:0.3].CGColor;
[sizeBtn setTitle:[NSString stringWithCString:sizeNames[sp] encoding:NSUTF8StringEncoding] forState:UIControlStateNormal];
[sizeBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
sizeBtn.titleLabel.font = [UIFont boldSystemFontOfSize:13];
[sizeBtn addTarget:self action:@selector(handleSizePresetButton:) forControlEvents:UIControlEventTouchUpInside];
[scaleBar addSubview:sizeBtn];
}
}
// v42：透明度滑桿條（預設藏著）——點控制條的「透」鈕展開，
// 在縮放條下面（y=108，36pt）；滑桿 0.5–1.0，調窗的 alpha，
// 每窗單獨存（winOpacity_<bid>），松手才存。
UIView *opacityBar = [[UIView alloc] initWithFrame:CGRectMake(0, GHLSS_HOSTED_CONTROL_H + 72, winW, 36)];
opacityBar.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.85];
opacityBar.hidden = YES;
[container addSubview:opacityBar];
GHLSSHostedOpacitySliderBar = opacityBar;
UISlider *opacitySlider = [[UISlider alloc] initWithFrame:CGRectMake(10, 3, winW - 70, 30)];
opacitySlider.minimumValue = 0.5;
opacitySlider.maximumValue = 1.0;
opacitySlider.value = GHLSSReadWindowOpacityForBundleID(bundleID);
opacitySlider.minimumTrackTintColor = [UIColor colorWithRed:0.83 green:0.68 blue:0.21 alpha:1.0];
[opacitySlider addTarget:self action:@selector(handleOpacitySlider:) forControlEvents:UIControlEventValueChanged];
[opacitySlider addTarget:self action:@selector(handleOpacitySliderEnded:) forControlEvents:UIControlEventTouchUpInside | UIControlEventTouchUpOutside];
[opacityBar addSubview:opacitySlider];
GHLSSHostedOpacitySlider = opacitySlider;
UILabel *opacityLabel = [[UILabel alloc] initWithFrame:CGRectMake(winW - 56, 3, 46, 30)];
{
char pbuf[32];
snprintf(pbuf, sizeof(pbuf), "%d%%", (int)(GHLSSReadWindowOpacityForBundleID(bundleID) * 100.0));
opacityLabel.text = [NSString stringWithCString:pbuf encoding:NSUTF8StringEncoding];
}
opacityLabel.textColor = [UIColor whiteColor];
opacityLabel.font = [UIFont boldSystemFontOfSize:14];
opacityLabel.textAlignment = NSTextAlignmentCenter;
[opacityBar addSubview:opacityLabel];
GHLSSHostedOpacityLabel = opacityLabel;
// v38：窗顶上的 24pt 透明细条（拖动窗 + 点它展开/收起控制条，
// 唯一的常驻装饰——App 名（12pt，置中）+ 一颗 72x6 的白点小 pill，
// alpha 0.7、贴条底）。
// v40 从 16pt 加宽到 24pt（皇上 11:34：v39 的 16pt 细条太细、太透明，
// 找不到地方抓；细条保持透明——App 内容透出来）。细条在
// 内容区之上、控制条之下（控制条展开时会盖住它）。点细条的手势
// 要等拖动失败才认（拖动时不触发点按）。
// v40：细条中央加 App 名（12pt，白字 + 黑色阴影，浅色内容上也看得见；
// UILabel 默认不收触摸，点按/拖动仍归细条的手势，不影响拖动）。
// pill 从垂直置中改成贴条底（72x6 不变，y=17），给名字让位；名字
// 与 pill 都跟窗宽走（名字横向拉伸、pill 左右留空、水平置中），
// 窗调尺寸后不跑偏。
UIView *topStrip = [[UIView alloc] initWithFrame:CGRectMake(0, 0, winW, GHLSS_HOSTED_STRIP_H)];
topStrip.backgroundColor = [UIColor clearColor];
[container addSubview:topStrip];
GHLSSHostedTopStrip = topStrip;
UILabel *stripNameLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, winW, 15)];
stripNameLabel.text = [NSString stringWithCString:name encoding:NSUTF8StringEncoding];
stripNameLabel.textColor = [[UIColor whiteColor] colorWithAlphaComponent:0.85];
stripNameLabel.font = [UIFont systemFontOfSize:12];
stripNameLabel.textAlignment = NSTextAlignmentCenter;
stripNameLabel.shadowColor = [UIColor blackColor];
stripNameLabel.shadowOffset = CGSizeMake(0, 1);
stripNameLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
[topStrip addSubview:stripNameLabel];
UIView *pill = [[UIView alloc] initWithFrame:CGRectMake((winW - 72) / 2.0, 17, 72, 6)];
pill.backgroundColor = [[UIColor whiteColor] colorWithAlphaComponent:0.7];
pill.layer.cornerRadius = 3.0;
pill.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;
[topStrip addSubview:pill];
UIPanGestureRecognizer *stripDrag = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handleTitleDrag:)];
stripDrag.minimumNumberOfTouches = 1;
stripDrag.maximumNumberOfTouches = 1;
[topStrip addGestureRecognizer:stripDrag];
UITapGestureRecognizer *stripTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleTopStripTap:)];
stripTap.delegate = self;
[stripTap requireGestureRecognizerToFail:stripDrag];
[topStrip addGestureRecognizer:stripTap];
// v42：手勢自定義（綁在窗頂細條上，不綁內容區——App 自己的滑動/
// 點按不會誤觸；動作走設定 gestureTripleTap/gestureSwipeV/
// gestureSwipeH/gestureTwoFingerTap；單擊展開控制條要等三擊失敗
// 才認，免得三擊時控制條先跳一下）。
UITapGestureRecognizer *tripleTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleGestureTripleTap:)];
tripleTap.numberOfTapsRequired = 3;
tripleTap.delegate = self;
tripleTap.cancelsTouchesInView = NO;
[topStrip addGestureRecognizer:tripleTap];
[stripTap requireGestureRecognizerToFail:tripleTap];
UISwipeGestureRecognizer *swipeV = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(handleGestureSwipeVertical:)];
swipeV.direction = UISwipeGestureRecognizerDirectionUp | UISwipeGestureRecognizerDirectionDown;
swipeV.delegate = self;
swipeV.cancelsTouchesInView = NO;
[topStrip addGestureRecognizer:swipeV];
UISwipeGestureRecognizer *swipeH = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(handleGestureSwipeHorizontal:)];
swipeH.direction = UISwipeGestureRecognizerDirectionLeft | UISwipeGestureRecognizerDirectionRight;
swipeH.delegate = self;
swipeH.cancelsTouchesInView = NO;
[topStrip addGestureRecognizer:swipeH];
UITapGestureRecognizer *twoFingerTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleGestureTwoFingerTap:)];
twoFingerTap.numberOfTouchesRequired = 2;
twoFingerTap.delegate = self;
twoFingerTap.cancelsTouchesInView = NO;
[topStrip addGestureRecognizer:twoFingerTap];
// v38：控制条（36pt，半透明黑底，默认藏着）——旧标题栏的活儿都搬
// 到这里：红 X、黄最小化、App 名、± 缩放钮。控制条在细条之上
//（展开时盖住细条），自己也能拖动窗；点控制条中间（标题处）收起
// 它（点在按钮上不触发——手势代理把按钮的触摸挡掉）。
UIView *titleBar = [[UIView alloc] initWithFrame:CGRectMake(0, 0, winW, GHLSS_HOSTED_CONTROL_H)];
titleBar.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.85];
titleBar.hidden = YES;
[container addSubview:titleBar];
GHLSSHostedTitleBar = titleBar;
UIPanGestureRecognizer *barDrag = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handleTitleDrag:)];
barDrag.minimumNumberOfTouches = 1;
barDrag.maximumNumberOfTouches = 1;
[titleBar addGestureRecognizer:barDrag];
UITapGestureRecognizer *barTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleTopStripTap:)];
barTap.delegate = self;
[barTap requireGestureRecognizerToFail:barDrag];
[titleBar addGestureRecognizer:barTap];
// 关闭钮（红圆，左）。
UIButton *closeBtn = [UIButton buttonWithType:UIButtonTypeCustom];
closeBtn.frame = CGRectMake(10, 5, 26, 26);
closeBtn.backgroundColor = [UIColor colorWithRed:1.0 green:0.23 blue:0.19 alpha:1.0];
closeBtn.layer.cornerRadius = 13.0;
[closeBtn setTitle:[NSString stringWithCString:"x" encoding:NSUTF8StringEncoding] forState:UIControlStateNormal];
[closeBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
closeBtn.titleLabel.font = [UIFont boldSystemFontOfSize:14];
[closeBtn addTarget:self action:@selector(handleHostedClose:) forControlEvents:UIControlEventTouchUpInside];
[titleBar addSubview:closeBtn];
// 最小化钮（黄圆，左二）：只藏窗、不销毁 scene（v40：贴边小卡——
// 窗藏起来、右边缘留一张看得见的小卡，点卡恢复窗；见 minimizeHostedWindow）。
UIButton *minBtn = [UIButton buttonWithType:UIButtonTypeCustom];
minBtn.frame = CGRectMake(44, 5, 26, 26);
minBtn.backgroundColor = [UIColor colorWithRed:1.0 green:0.76 blue:0.03 alpha:1.0];
minBtn.layer.cornerRadius = 13.0;
[minBtn setTitle:[NSString stringWithCString:"-" encoding:NSUTF8StringEncoding] forState:UIControlStateNormal];
[minBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
minBtn.titleLabel.font = [UIFont boldSystemFontOfSize:14];
[minBtn addTarget:self action:@selector(handleHostedMinimize:) forControlEvents:UIControlEventTouchUpInside];
[titleBar addSubview:minBtn];
// 标题：App 名，居中（v42：給「透」「釘」兩顆鈕讓位，標題只到 winW-112；
// 窄側窗本來就放不下標題，跟以前一樣不顯示）。
UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(78, 0, winW - 190, GHLSS_HOSTED_CONTROL_H)];
titleLabel.text = [NSString stringWithCString:name encoding:NSUTF8StringEncoding];
titleLabel.textColor = [UIColor whiteColor];
titleLabel.font = [UIFont boldSystemFontOfSize:16];
titleLabel.textAlignment = NSTextAlignmentCenter;
[titleBar addSubview:titleLabel];
GHLSSHostedTitleLabel = titleLabel;
// v38：缩放按钮（±，26x26 圆钮，控制条右边，和红 X、黄最小化一样
// 大）——点一下展开/收起内容区顶上的缩放滑杆条。标题写在 winW-36，
// 标题 label 只到 winW-78，不重叠。
UIButton *scaleBtn = [UIButton buttonWithType:UIButtonTypeCustom];
scaleBtn.frame = CGRectMake(winW - 36, 5, 26, 26);
scaleBtn.backgroundColor = [UIColor colorWithRed:0.15 green:0.15 blue:0.15 alpha:1.0];
scaleBtn.layer.cornerRadius = 13.0;
scaleBtn.layer.borderWidth = 1.0;
scaleBtn.layer.borderColor = [UIColor colorWithRed:0.83 green:0.68 blue:0.21 alpha:1.0].CGColor;
[scaleBtn setTitle:[NSString stringWithCString:"±" encoding:NSUTF8StringEncoding] forState:UIControlStateNormal];
[scaleBtn setTitleColor:[UIColor colorWithRed:0.83 green:0.68 blue:0.21 alpha:1.0] forState:UIControlStateNormal];
scaleBtn.titleLabel.font = [UIFont boldSystemFontOfSize:14];
[scaleBtn addTarget:self action:@selector(handleScaleButton:) forControlEvents:UIControlEventTouchUpInside];
[titleBar addSubview:scaleBtn];
GHLSSHostedScaleButton = scaleBtn;
// v42：釘選鈕（「釘」，winW-70）+ 透明度鈕（「透」，winW-104）；
// 窄側窗（<200pt）不放這兩顆（放不下，控制條只留紅 X/黃最小化/±）。
// 釘住的窗金底、層級提到最上層（見 GHLSSBringWindowToFront）。
if (winW >= 200.0) {
UIButton *pinBtn = [UIButton buttonWithType:UIButtonTypeCustom];
pinBtn.frame = CGRectMake(winW - 70, 5, 26, 26);
pinBtn.backgroundColor = GHLSSIsWindowPinned(bundleID) ? [UIColor colorWithRed:0.83 green:0.68 blue:0.21 alpha:1.0] : [UIColor colorWithRed:0.15 green:0.15 blue:0.15 alpha:1.0];
pinBtn.layer.cornerRadius = 13.0;
pinBtn.layer.borderWidth = 1.0;
pinBtn.layer.borderColor = [UIColor colorWithRed:0.83 green:0.68 blue:0.21 alpha:1.0].CGColor;
[pinBtn setTitle:[NSString stringWithCString:"釘" encoding:NSUTF8StringEncoding] forState:UIControlStateNormal];
[pinBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
pinBtn.titleLabel.font = [UIFont boldSystemFontOfSize:14];
[pinBtn addTarget:self action:@selector(handlePinButton:) forControlEvents:UIControlEventTouchUpInside];
[titleBar addSubview:pinBtn];
GHLSSHostedPinButton = pinBtn;
UIButton *opacityBtn = [UIButton buttonWithType:UIButtonTypeCustom];
opacityBtn.frame = CGRectMake(winW - 104, 5, 26, 26);
opacityBtn.backgroundColor = [UIColor colorWithRed:0.15 green:0.15 blue:0.15 alpha:1.0];
opacityBtn.layer.cornerRadius = 13.0;
opacityBtn.layer.borderWidth = 1.0;
opacityBtn.layer.borderColor = [UIColor colorWithRed:0.83 green:0.68 blue:0.21 alpha:1.0].CGColor;
[opacityBtn setTitle:[NSString stringWithCString:"透" encoding:NSUTF8StringEncoding] forState:UIControlStateNormal];
[opacityBtn setTitleColor:[UIColor colorWithRed:0.83 green:0.68 blue:0.21 alpha:1.0] forState:UIControlStateNormal];
opacityBtn.titleLabel.font = [UIFont boldSystemFontOfSize:14];
[opacityBtn addTarget:self action:@selector(handleOpacityButton:) forControlEvents:UIControlEventTouchUpInside];
[titleBar addSubview:opacityBtn];
GHLSSHostedOpacityButton = opacityBtn;
} else {
GHLSSHostedPinButton = nil;
GHLSSHostedOpacityButton = nil;
}
// v40：右下角缩放手柄（36x36 触摸区——比说的 24 稍大，好抓；
// 带一个看得见的白色角落括号「⌟」标记，0.8 alpha。原来 60x60 透明窗
// + 0.2 alpha 淡菱形太难找，皇上 11:55 要一个看得见的手柄）。
// 拖动即改窗口 frame，松手时调 scene 的 frame（跟原来一样）；
// 限制最小 200x300、最大不超过屏幕（见 handleResizeDrag），
// 保持圆角 35 与 anchorPoint (0,0) 的 v39 修正（只改 frame，
// 不动圆角与锚点）。手柄跟着窗走（FlexibleLeftMargin|FlexibleTopMargin，
// 一直在右下角）。
UIView *resizeHandle = [[UIView alloc] initWithFrame:CGRectMake(winW - 36, winH - 36, 36, 36)];
resizeHandle.backgroundColor = [UIColor clearColor];
resizeHandle.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleTopMargin;
// 角落括号「⌟」：竖条（右边缘）+ 横条（底边缘），白 0.8 alpha。
UIView *bracketV = [[UIView alloc] initWithFrame:CGRectMake(31, 17, 3, 17)];
bracketV.backgroundColor = [[UIColor whiteColor] colorWithAlphaComponent:0.8];
bracketV.layer.cornerRadius = 1.5;
[resizeHandle addSubview:bracketV];
UIView *bracketH = [[UIView alloc] initWithFrame:CGRectMake(17, 31, 17, 3)];
bracketH.backgroundColor = [[UIColor whiteColor] colorWithAlphaComponent:0.8];
bracketH.layer.cornerRadius = 1.5;
[resizeHandle addSubview:bracketH];
UIPanGestureRecognizer *resizeGesture = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handleResizeDrag:)];
resizeGesture.minimumNumberOfTouches = 1;
resizeGesture.maximumNumberOfTouches = 1;
[resizeHandle addGestureRecognizer:resizeGesture];
[container addSubview:resizeHandle];
GHLSSHostedResizeHandle = resizeHandle;
// v41：三屏分隔線（側窗內緣，拖動調側窗寬度；側邊小窗手勢
// 開關關了就不建）。分隔線是 container 的子視圖（在內容區之上），
// 位置跟側窗左右邊走（右側窗：內緣在左；左側窗：內緣在右）。
// v42：粗細（8/16/24，預設 16）+ 顏色（金色/灰色/透明，預設金色）
// 走設定；透明時中間那顆抓手也一起透明（線本身還能拖）。
if (GHLSSHostedIsSideDock && GHLSSReadSideWindowGestures()) {
BOOL dockLeft = GHLSSIsWindowPositionLeft();
CGFloat divThickness = GHLSSReadSideDividerThickness();
GHLSSHostedSideDividerThickness = divThickness;
int divColor = GHLSSReadSideDividerColor();
CGFloat divX = dockLeft ? (winW - divThickness) : 0;
UIView *divider = [[UIView alloc] initWithFrame:CGRectMake(divX, 0, divThickness, winH)];
if (divColor == 0) {
divider.backgroundColor = [UIColor colorWithRed:0.83 green:0.68 blue:0.21 alpha:0.8];
} else if (divColor == 1) {
divider.backgroundColor = [[UIColor whiteColor] colorWithAlphaComponent:0.25];
} else {
divider.backgroundColor = [UIColor clearColor];
}
UIView *divPill = [[UIView alloc] initWithFrame:CGRectMake((divThickness - 4.0) / 2.0, winH / 2.0 - 20, 4, 40)];
if (divColor == 0) {
divPill.backgroundColor = [UIColor colorWithRed:0.83 green:0.68 blue:0.21 alpha:1.0];
} else if (divColor == 1) {
divPill.backgroundColor = [[UIColor whiteColor] colorWithAlphaComponent:0.7];
} else {
divPill.backgroundColor = [UIColor clearColor];
}
divPill.layer.cornerRadius = 2.0;
[divider addSubview:divPill];
UIPanGestureRecognizer *divDrag = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handleSideDividerDrag:)];
divDrag.delegate = self;
[divider addGestureRecognizer:divDrag];
[container addSubview:divider];
GHLSSHostedSideDivider = divider;
}
GHLSSHostedWindow.rootViewController = vc;
GHLSSHostedWindow.hidden = NO;
GHLSSHostedScene = scene;
GHLSSHostedPresenter = presenter;
GHLSSHostedLayerHostView = layerHostView;
GHLSSHostedSceneID = sceneID;
strncpy(GHLSSHostedBundleID, bundleID, sizeof(GHLSSHostedBundleID) - 1);
GHLSSHostedBundleID[sizeof(GHLSSHostedBundleID) - 1] = '\0';
GHLSSHostedPid = pid;
GHLSSHostedMinimized = NO;
// v35：新窗也进缓存（这个 App 的第一份），活动下标指到它；以后切
// 走再切回来，直接复用这一份，不再建新 scene。
int newCacheIdx = GHLSSAppIndexForBundleID(bundleID);
if (newCacheIdx >= 0) {
GHLSSActiveAppIndex = newCacheIdx;
GHLSSSaveActiveToCache();
}
GHLSSLogLine("v43 window shown");
// v42：浮窗透明度（每窗 winOpacity_<bid>，沒設走全域；調窗的 alpha）。
GHLSSHostedWindow.alpha = GHLSSReadWindowOpacityForBundleID(bundleID);
// v40：新窗带到最前（别的窗回基础层级，这个窗升到最前层级、活动量
// 切到它），再更新阴影背景（开关开着、且有浮窗看得见时显示）。
GHLSSBringWindowToFront(GHLSSHostedWindow);
GHLSSUpdateDimOverlay();
// v42：配對記錄（開新窗時前面已有別的窗看得見：記一對；側窗的話
// 還存成上次的三屏組合）+ 重啟恢復清單 + 任務欄。
if (GHLSSPairPrevBid[0] != '\0' && strcmp(GHLSSPairPrevBid, bundleID) != 0) {
GHLSSRecordPair(GHLSSPairPrevBid, bundleID);
if (GHLSSHostedIsSideDock) GHLSSSaveLastThreeScreenPair(GHLSSPairPrevBid, bundleID);
}
GHLSSSaveRestoreList();
GHLSSUpdateTaskbar();
// v41：新窗建好時短暫顯示通知橫幅（浮窗設置 → 通知橫幅設置；
// 開關關了不顯示，時長走設定，預設 1.5 秒）。
[self showNotificationBannerForName:name];
// v40：恢复了上次的位置/大小——建窗时内容已按恢复的尺寸嵌，再调一次
// resizeHostedSceneToContentSize，把 scene frame 也推到恢复的尺寸
//（跟拖角落调尺寸松手时同一条路；只在恢复时调一次）。
if (geometryRestored) {
[self resizeHostedSceneToContentSize:CGSizeMake(restoredW, restoredH)];
}
// v28：1.5 秒重试 + 4 秒再重试一次。v26 的 1.5 秒重试在真机日志里
// 一次都没出现——不知道是重试块根本没跑，还是窗在 1.5 秒内就被
// 关/最小化了、守卫条件直接 return 没留日志。所以两次重试的块一跑
// 就先无条件记一行 retry check（窗关了也记：scene 是 nil 时
// contentState 记 0），再按老条件决定推不推；推了记 retry /
// retry2。再包一层 @try/@catch，重试绝不能拖垮 SpringBoard。
// v40：重试块抓当前窗的 scene/window（多窗时活动量会切到别的窗，
// 老写法读活动量会推错窗）；缓存里的 scene 换了（销毁重建）就跳过。
FBScene *retryScene = scene;
UIWindow *retryWindow = GHLSSHostedWindow;
int retryIdx = newCacheIdx;
dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
char cbuf[160];
snprintf(cbuf, sizeof(cbuf), "v43 foreground retry check contentState=%lu minimized=%d", (unsigned long)(retryScene ? [retryScene contentState] : 0), (retryIdx >= 0 && GHLSSCacheMinimized[retryIdx]) ? 1 : 0);
GHLSSLogLine(cbuf);
if (!retryScene || !retryWindow || (retryIdx >= 0 && GHLSSCacheMinimized[retryIdx])) return;
if (retryIdx >= 0 && GHLSSCacheScenes[retryIdx] != retryScene) return;
@try {
if ([retryScene contentState] != 2) {
[retryScene updateSettingsWithBlock:^(UIMutableApplicationSceneSettings *settings) {
settings.foreground = YES;
}];
char rbuf[128];
snprintf(rbuf, sizeof(rbuf), "v43 foreground retry contentState=%lu", (unsigned long)[retryScene contentState]);
GHLSSLogLine(rbuf);
}
} @catch (NSException *e) {
(void)e;
GHLSSLogLine("v43 foreground retry failed");
}
});
dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(4.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
char cbuf[160];
snprintf(cbuf, sizeof(cbuf), "v43 foreground retry2 check contentState=%lu minimized=%d", (unsigned long)(retryScene ? [retryScene contentState] : 0), (retryIdx >= 0 && GHLSSCacheMinimized[retryIdx]) ? 1 : 0);
GHLSSLogLine(cbuf);
if (!retryScene || !retryWindow || (retryIdx >= 0 && GHLSSCacheMinimized[retryIdx])) return;
if (retryIdx >= 0 && GHLSSCacheScenes[retryIdx] != retryScene) return;
@try {
if ([retryScene contentState] != 2) {
[retryScene updateSettingsWithBlock:^(UIMutableApplicationSceneSettings *settings) {
settings.foreground = YES;
}];
char rbuf[128];
snprintf(rbuf, sizeof(rbuf), "v43 foreground retry2 contentState=%lu", (unsigned long)[retryScene contentState]);
GHLSSLogLine(rbuf);
}
} @catch (NSException *e) {
(void)e;
GHLSSLogLine("v43 foreground retry2 failed");
}
});
} @catch (NSException *e) {
(void)e;
GHLSSLogLine("v43 window failed exception");
}
}

// v35 关窗（X）：藏窗、不销毁 scene——只藏窗、推后台、记最小化。
// scene 留着，重开同一个 App 直接复用（见 createHostedScene 的
// 复用守卫），不再建新 scene；固定 ID 一个 SpringBoard 会话里只
// 建一次，残留撞不到。切走别的 App 时也一样（只藏窗、存缓存，见
// handleAppButton 的切换路径）；真正销毁只在复用守卫判旧时（进程
// 死了，见 GHLSSDestroyCachedEntryAtIndex）。关窗后窗的状态与最小
// 化一样（hidden=YES、minimized=YES、scene 后台化），重开走同一条
// 恢复路（restoreHostedWindow 推前景）；锁屏回调也一样处理（最小
// 化着的窗锁屏不藏、解锁不弹，等用户点恢复）。
// 进程留着不杀（V5_DESIGN.md §2.2 第 19 步的精神：关窗不杀进程）。
// v40：关窗只影响这个窗（别的窗不动），贴边小卡也收掉（彻底关掉，
// 不再回来——卡没了、窗藏着，下次从启动器重开直接复用缓存里的 scene）。
- (void)closeHostedWindow {
if (!GHLSSHostedWindow) return;
int idx = GHLSSActiveAppIndex;
BOOL wasSideDock = GHLSSHostedIsSideDock;
GHLSSHostedWindow.hidden = YES;
GHLSSHostedMinimized = YES;
GHLSSLogLine("v43 window closed (scene kept)");
GHLSSBackgroundHostedScene("v43 scene backgrounded on close");
if (idx >= 0 && idx < GHLSS_APP_COUNT) {
GHLSSHideDockPeekForIndex(idx);
GHLSSSaveActiveToCache();
// v40：关窗时存一次位置/大小/缩放（第 6 项）——下次开同一 App
// 恢复到这次的位置和大小。
GHLSSSaveGeometryForIndex(idx);
}
if (GHLSSHostedSideDivider) GHLSSHostedSideDivider.hidden = YES;
GHLSSHostedIsSideDock = NO;
// v41：關三屏同時關側邊小窗（預設關）：關的是側窗、開關開著時，
// 同場的其他可見浮窗也一起關掉（三屏會話結束）；關著時只關這個窗。
if (wasSideDock && GHLSSReadCloseThreeScreenAlsoClosesSide()) {
GHLSSLogLine("v43 three screen close also closes side windows");
for (int i = 0; i < GHLSS_APP_COUNT; i++) {
if (i == idx) continue;
if (GHLSSCacheWindows[i] && !GHLSSCacheWindows[i].hidden && !GHLSSCacheMinimized[i]) {
GHLSSLoadCacheToActive(i);
[self closeHostedWindow];
}
}
}
GHLSSUpdateDimOverlay();
// v42：重啟恢復清單 + 任務欄跟著關窗更新。
GHLSSSaveRestoreList();
GHLSSUpdateTaskbar();
}

// v35：destroyHostedScene 已删——会话内永不销毁 scene（见文件头 v35
// 节）。唯一剩下的销毁在 GHLSSDestroyCachedEntryAtIndex（只在复用
// 守卫判旧、进程死了时调）。切走与关窗只藏窗（见 handleAppButton
// 的切换路径与 closeHostedWindow）。启动器层级不用这里复位：
// showLauncher 每次按活动窗有没有定层级（有窗 Alert - 1、没窗
// Alert - 3），销毁只发生在没有活动窗的旧 scene 上。

- (void)minimizeHostedWindow {
if (!GHLSSHostedWindow || GHLSSHostedMinimized) return;
int idx = GHLSSActiveAppIndex;
GHLSSHostedMinimized = YES;
GHLSSLogLine("v43 window minimized");
// v31：藏窗后把 scene 推回后台（foreground=NO + backgrounded=YES）。
// 锁屏时系统不会替我们的 scene 推后台，scene 一直占着前景，很可能
// 干扰锁屏密码的触摸；最小化时先后台化，锁屏时再后台化一次也无妨。
GHLSSBackgroundHostedScene("v43 scene backgrounded on minimize");
// v41：最小化改成貼邊 peek（圖 1 的樣子）：窗本身縮到邊緣（112x216，
// 露出一截活內容，上下疊著排），點那截恢復窗；scene 活著（只縮窗 +
// 推後台，不銷毀）。收起前的位置/大小先存（縮窗之後再存會存成
// peek 的尺寸），側窗旗標清掉（收起後再叫回來是普通浮窗）。
if (idx >= 0 && idx < GHLSS_APP_COUNT) {
GHLSSSaveGeometryForIndex(idx);
GHLSSSaveActiveToCache();
GHLSSHostedIsSideDock = NO;
GHLSSShowDockPeekForIndex(idx);
}
GHLSSUpdateDimOverlay();
// v42：重啟恢復清單 + 任務欄跟著收起更新。
GHLSSSaveRestoreList();
GHLSSUpdateTaskbar();
}

- (void)restoreHostedWindow {
if (!GHLSSHostedWindow || !GHLSSHostedMinimized) return;
int idx = GHLSSActiveAppIndex;
// v41：從 peek 恢復——先把窗的尺寸從存過的位置/大小還原（收起時縮
// 成了 112x216；存的是窗中心 + 尺寸 + scale），再把容器/內容區的
// 尺寸也還原（系統可能在縮窗時改了容器尺寸），點按層與小 X 藏起來，
// 分隔線藏起來（恢復後是普通浮窗，不是側窗）。
if (idx >= 0 && idx < GHLSS_APP_COUNT) {
GHLSSHideDockPeekForIndex(idx);
CGFloat geoCX, geoCY, geoW, geoH, geoScale;
if (GHLSSRestoreGeometryForIndex(idx, &geoCX, &geoCY, &geoW, &geoH, &geoScale)) {
CGRect screenBounds = [UIScreen mainScreen].bounds;
CGFloat minCX = geoW / 2.0 + 8.0;
CGFloat maxCX = screenBounds.size.width - geoW / 2.0 - 8.0;
CGFloat minCY = GHLSSReadSafeDistance() + geoH / 2.0;
CGFloat maxCY = screenBounds.size.height - geoH / 2.0 - 8.0;
if (geoCX < minCX) geoCX = minCX;
if (geoCX > maxCX) geoCX = maxCX;
if (geoCY < minCY) geoCY = minCY;
if (geoCY > maxCY) geoCY = maxCY;
GHLSSHostedWindow.frame = CGRectMake(geoCX - geoW / 2.0, geoCY - geoH / 2.0, geoW, geoH);
if (GHLSSHostedContainer) GHLSSHostedContainer.frame = CGRectMake(0, 0, geoW, geoH);
if (GHLSSHostedContentView) GHLSSHostedContentView.frame = CGRectMake(0, 0, geoW, geoH);
if (GHLSSHostedTopStrip) GHLSSHostedTopStrip.frame = CGRectMake(0, 0, geoW, GHLSS_HOSTED_STRIP_H);
if (GHLSSHostedTitleBar) GHLSSHostedTitleBar.frame = CGRectMake(0, 0, geoW, GHLSS_HOSTED_CONTROL_H);
GHLSSHostedScaleRatio = geoScale;
GHLSSApplyScaleToHostedWindow(NO);
}
if (GHLSSHostedSideDivider) GHLSSHostedSideDivider.hidden = YES;
GHLSSHostedIsSideDock = NO;
}
GHLSSHostedWindow.hidden = NO;
GHLSSHostedMinimized = NO;
GHLSSBringWindowToFront(GHLSSHostedWindow);
GHLSSLogLine("v43 window restored from peek");
// v30：最小化后锁屏再解锁、恢复窗时内容是黑的——锁屏把 scene 的
// foreground 状态弄丢了，只取消 hidden 不够；恢复时也要把
// foreground=YES 再推一遍（建窗时同一个已证明能用的做法），
// 单独包 @try/@catch，出错只记日志、继续恢复。
@try {
if (GHLSSHostedScene) {
[GHLSSHostedScene updateSettingsWithBlock:^(UIMutableApplicationSceneSettings *settings) {
settings.foreground = YES;
// v31：把 backgrounded 也推回 NO（最小化/锁屏时推过 YES），
// 和 foreground 一起恢复；setter 不存在就跳过，不崩。
if ([settings respondsToSelector:@selector(setBackgrounded:)]) {
settings.backgrounded = NO;
}
}];
char fbuf[128];
snprintf(fbuf, sizeof(fbuf), "v43 foreground pushed on restore contentState=%lu", (unsigned long)[GHLSSHostedScene contentState]);
GHLSSLogLine(fbuf);
}
} @catch (NSException *e) {
(void)e;
GHLSSLogLine("v43 foreground push on restore failed");
}
// v40：恢复完把状态存回缓存、更新阴影背景（窗又看得见了）。
if (idx >= 0 && idx < GHLSS_APP_COUNT) {
GHLSSSaveActiveToCache();
}
GHLSSUpdateDimOverlay();
// v42：重啟恢復清單 + 任務欄跟著恢復更新。
GHLSSSaveRestoreList();
GHLSSUpdateTaskbar();
}

- (void)handleHostedClose:(id)sender {
GHLSSLogLine("v43 hosted close tapped");
// v40：多窗——控制条按钮是哪个窗的，就关哪个窗（先切活动量到
// 按钮所在的窗，再关；不切的话关的是活动窗，可能是别的窗）。
if ([sender isKindOfClass:[UIView class]]) {
GHLSSSetActiveToWindow(GHLSSWindowForView((UIView *)sender));
}
[self closeHostedWindow];
}

- (void)handleHostedMinimize:(id)sender {
GHLSSLogLine("v43 hosted minimize tapped");
if ([sender isKindOfClass:[UIView class]]) {
GHLSSSetActiveToWindow(GHLSSWindowForView((UIView *)sender));
}
[self minimizeHostedWindow];
}

// v38：点标题栏的 ± 钮——展开/收起缩放滑杆条（默认藏着）。
- (void)handleScaleButton:(id)sender {
// v40：多窗——先切活动量到按钮所在的窗（滑杆条是活动窗的）。
if ([sender isKindOfClass:[UIView class]]) {
GHLSSSetActiveToWindow(GHLSSWindowForView((UIView *)sender));
}
if (!GHLSSHostedScaleSliderBar) return;
GHLSSHostedScaleSliderBar.hidden = !GHLSSHostedScaleSliderBar.hidden;
// 展开时把滑杆值同步到当前 scale（切回来复用时滑杆还是旧值，
// 展开才同步一次，不用每次恢复都调）。
if (!GHLSSHostedScaleSliderBar.hidden && GHLSSHostedScaleSlider) {
GHLSSHostedScaleSlider.value = GHLSSHostedScaleRatio;
}
GHLSSLogLine("v43 scale bar toggled");
}

// v38：拖缩放滑杆——0.5–2.0，步进 0.01（UISlider 没有步进，handler
// 里四舍五入到 0.01：(int)(v*100+0.5)/100，不用 math.h）。改
// scaleRatio，走同一条反向耦合路径（立即改 transform、0.05 秒防抖
// 改 frame），百分比同步到滑杆条右边的 label，缓存里的 scaleRatio
// 也立即同步（不然切走再切回来会读回旧值）。
- (void)handleScaleSlider:(UISlider *)sender {
if (!sender) return;
// v40：多窗——先切活动量到滑杆所在的窗（scaleRatio 是活动窗的）。
GHLSSSetActiveToWindow(GHLSSWindowForView(sender));
CGFloat v = sender.value;
v = (CGFloat)((int)(v * 100.0 + 0.5)) / 100.0;
if (v < 0.5) v = 0.5;
if (v > 2.0) v = 2.0;
sender.value = v;
GHLSSHostedScaleRatio = v;
if (GHLSSHostedScaleLabel) {
char pbuf[32];
snprintf(pbuf, sizeof(pbuf), "%d%%", (int)(v * 100.0));
GHLSSHostedScaleLabel.text = [NSString stringWithCString:pbuf encoding:NSUTF8StringEncoding];
}
if (GHLSSActiveAppIndex >= 0 && GHLSSActiveAppIndex < GHLSS_APP_COUNT) {
GHLSSCacheScaleRatios[GHLSSActiveAppIndex] = v;
}
char buf[128];
snprintf(buf, sizeof(buf), "v43 scale changed to %d%%", (int)(v * 100.0));
GHLSSLogLine(buf);
GHLSSApplyScaleToHostedWindow(YES);
}

// v40：滑杆松手（拖动结束）——存一次位置/大小/缩放（第 6 项）。
// ValueChanged 拖动中一直在触发，每动一下都写 prefs 太费；
// 松手才存一次（TouchUpInside/Outside）。
- (void)handleScaleSliderEnded:(UISlider *)sender {
(void)sender;
if (GHLSSActiveAppIndex >= 0 && GHLSSActiveAppIndex < GHLSS_APP_COUNT) {
GHLSSSaveGeometryForIndex(GHLSSActiveAppIndex);
}
}

// 拖标题栏移动窗口（参考实现的 moveWindow 做法：取位移、
// 加到中心点上、位移清零；位置夹在屏幕里，不让窗丢出去）。
// v40：多窗——拖哪个窗就动哪个窗（recognizer.view 所在的 window，
// 不是只动 GHLSSHostedWindow 这个单一静态，不然拖 B 窗会动到 A 窗）；
// 细条 24pt（皇上 11:34：v39 的 16pt 细条太细、太透明，找不到地方抓）。
// 拖到右邊緣贴边收起（主关掉路徑，像影片一樣）：放手时窗中心进了右缘
// 60pt 内，窗收成一张贴边小卡（跟最小化一样，scene 活着）；没拖到
// 那么边、放手就停在原地（但窗不能半截出屏，放手夹回全可见）。
// 安全距离（设定页，默认 50）：拖窗时窗顶离刘海（屏幕顶缘）不到这个
// 值就自动回弹（夹住位置，让窗顶至少离顶缘这个距离；旧 minY=100 是
// 夹中心，顶缘能出屏——v40 改成夹窗顶）。
- (void)handleTitleDrag:(UIPanGestureRecognizer *)recognizer {
UIWindow *dragWindow = GHLSSWindowForView(recognizer.view);
if (!dragWindow) dragWindow = GHLSSHostedWindow;
if (!dragWindow) return;
GHLSSSetActiveToWindow(dragWindow);
// v41：收起的 peek 窗不拖（點整截是恢復，拖動沒有意義；peek 上的
// 點按層本來就擋住了細條，這裡是兜底）。
int dragIdx = GHLSSAppIndexForWindow(dragWindow);
if (dragIdx >= 0 && dragIdx < GHLSS_APP_COUNT && GHLSSCacheMinimized[dragIdx]) return;
// v40：拖动一开始读一次设定（贴边收起往哪边、安全距离），拖动中
// 不变——每动一下都读 prefs 太费（CFPreferencesAppSynchronize）。
if (recognizer.state == UIGestureRecognizerStateBegan) {
// v41：浮窗拖動手勢開關（調度窗口設置，預設開）——關了這次拖動
// 不動（Began 讀一次，之後的事件看旗標，不每動一下讀 prefs）。
GHLSSDragDisabled = !GHLSSReadWindowDragEnabled();
if (GHLSSDragDisabled) {
GHLSSLogLine("v43 window drag disabled");
return;
}
GHLSSDragDockLeft = GHLSSIsWindowPositionLeft();
GHLSSDragSafeDistance = GHLSSReadSafeDistance();
GHLSSLogLine("v43 window dragged");
}
if (GHLSSDragDisabled) return;
BOOL dockLeft = GHLSSDragDockLeft;
CGFloat safeDistance = GHLSSDragSafeDistance;
CGPoint point = [recognizer translationInView:dragWindow];
[recognizer setTranslation:CGPointZero inView:dragWindow];
CGPoint center = dragWindow.center;
CGRect screenBounds = [UIScreen mainScreen].bounds;
CGFloat winW = dragWindow.bounds.size.width;
CGFloat winH = dragWindow.bounds.size.height;
// 横向：贴边那侧放寬到 20（才拖得到贴边收起的门槛——中心进那侧缘
// 60pt 内），另一侧还是 80。右側：minX 80、maxX 屏宽 - 20；
// 左側：minX 20、maxX 屏宽 - 80。
CGFloat minX = dockLeft ? 20.0 : 80.0;
CGFloat maxX = dockLeft ? (screenBounds.size.width - 80.0) : (screenBounds.size.width - 20.0);
// 纵向：窗顶离顶缘至少安全距离（设定页 safeDistance，默认 50），
// 中心 = 安全距离 + 窗高/2；底边夹在屏高 - 100（中心）。
CGFloat minY = safeDistance + winH / 2.0;
CGFloat maxY = screenBounds.size.height - 100.0;
CGFloat newX = center.x + point.x;
CGFloat newY = center.y + point.y;
if (newX < minX) newX = minX;
if (newX > maxX) newX = maxX;
if (newY < minY) newY = minY;
if (newY > maxY) newY = maxY;
dragWindow.center = CGPointMake(newX, newY);
if (recognizer.state == UIGestureRecognizerStateEnded) {
// 放手：窗中心进了贴边那侧的缘 60pt 内——贴边收起（主关掉路徑，
// 像影片一樣）。右側：中心进右缘 60pt 内；左側：中心进左缘 60pt 内。
BOOL shouldDock = dockLeft ? (newX <= GHLSS_DOCK_DRAG_THRESHOLD) : (screenBounds.size.width - newX <= GHLSS_DOCK_DRAG_THRESHOLD);
if (shouldDock) {
GHLSSLogLine("v43 window docked by drag");
[self minimizeHostedWindow];
return;
}
// v42：貼邊吸附（放手才吸，不拖著就跳）：拖到頂部（窗頂離頂緣不到
// 安全距離+24pt）放大到全屏尺寸；拖到左右邊緣（窗邊離屏邊不到 24pt）
// 吸住對齊（留 8pt）。側窗不放大（側窗本來就貼邊全高）。
if (!GHLSSHostedIsSideDock && (newY - winH / 2.0) <= safeDistance + 24.0) {
CGRect fullFrame = CGRectMake(8.0, safeDistance, screenBounds.size.width - 16.0, screenBounds.size.height - safeDistance - 8.0);
GHLSSLogLine("v43 window snapped to fullscreen");
[self resizeActiveWindowToFrame:fullFrame];
return;
}
if (newX - winW / 2.0 <= 24.0) newX = winW / 2.0 + 8.0;
else if (screenBounds.size.width - (newX + winW / 2.0) <= 24.0) newX = screenBounds.size.width - winW / 2.0 - 8.0;
// 没拖到那么边：放手停在原地，但窗不能半截出屏——夹回全可见
//（左右留 8pt、顶留安全距离、底留 8pt）。
CGFloat minCX = winW / 2.0 + 8.0;
CGFloat maxCX = screenBounds.size.width - winW / 2.0 - 8.0;
CGFloat minCY = safeDistance + winH / 2.0;
CGFloat maxCY = screenBounds.size.height - winH / 2.0 - 8.0;
CGFloat snapX = newX, snapY = newY;
if (snapX < minCX) snapX = minCX;
if (snapX > maxCX) snapX = maxCX;
if (snapY < minCY) snapY = minCY;
if (snapY > maxCY) snapY = maxCY;
dragWindow.center = CGPointMake(snapX, snapY);
// v40：拖动结束存一次位置/大小/缩放（第 6 项）——下次开同一 App
// 恢复到这次的位置和大小（贴边收起时 minimizeHostedWindow 里已存）。
if (GHLSSActiveAppIndex >= 0 && GHLSSActiveAppIndex < GHLSS_APP_COUNT) {
GHLSSSaveGeometryForIndex(GHLSSActiveAppIndex);
}
}
}

// v38：点窗顶上的细条（或控制条中间）——展开/收起控制条。控制条
// 收起来时，缩放滑杆条也跟着收起来（± 在控制条里，控制条藏着时
// 滑杆条也够不着）；控制条展开时，滑杆条保持原来的状态（展开时
// 才由 ± 控制）。
// v40：多窗——点哪个窗的细条/控制条，就切活动量到那个窗、把它带到
// 最前（层级升到最前），再展开/收起它的控制条。
- (void)handleTopStripTap:(UITapGestureRecognizer *)recognizer {
UIWindow *tapWindow = GHLSSWindowForView(recognizer.view);
if (tapWindow) {
GHLSSSetActiveToWindow(tapWindow);
GHLSSBringWindowToFront(tapWindow);
}
if (!GHLSSHostedTitleBar) return;
GHLSSHostedTitleBar.hidden = !GHLSSHostedTitleBar.hidden;
if (GHLSSHostedTitleBar.hidden && GHLSSHostedScaleSliderBar) {
GHLSSHostedScaleSliderBar.hidden = YES;
}
// v42：控制條收起來時，透明度滑桿條也跟著收起來。
if (GHLSSHostedTitleBar.hidden && GHLSSHostedOpacitySliderBar) {
GHLSSHostedOpacitySliderBar.hidden = YES;
}
GHLSSLogLine("v43 control bar toggled");
}

// ── v42 新方法（窗控制／手勢／懸浮球／演示／任務欄／配對／鍵盤） ──

// v42：把活動窗改到指定 frame（尺寸預設、放大、手勢「放大」共用）：
// 窗 + 容器/內容區/細條/控制條/滑桿條/手柄都跟著改，scene frame 重推，
// 位置/大小存一次（下次開同一 App 恢復）。側窗旗標清掉（放大後是普通浮窗）。
- (void)resizeActiveWindowToFrame:(CGRect)frame {
if (!GHLSSHostedWindow || !GHLSSHostedContainer || !GHLSSHostedContentView) return;
CGRect screenBounds = [UIScreen mainScreen].bounds;
CGFloat newW = frame.size.width;
CGFloat newH = frame.size.height;
if (newW < 200.0) newW = 200.0;
if (newW > screenBounds.size.width - 16.0) newW = screenBounds.size.width - 16.0;
if (newH < 300.0) newH = 300.0;
if (newH > screenBounds.size.height - 120.0) newH = screenBounds.size.height - 120.0;
CGFloat newX = frame.origin.x;
CGFloat newY = frame.origin.y;
if (newX < 8.0) newX = 8.0;
if (newY < GHLSSReadSafeDistance()) newY = GHLSSReadSafeDistance();
if (newX + newW > screenBounds.size.width - 8.0) newX = screenBounds.size.width - 8.0 - newW;
if (newY + newH > screenBounds.size.height - 8.0) newY = screenBounds.size.height - 8.0 - newH;
GHLSSHostedWindow.frame = CGRectMake(newX, newY, newW, newH);
if (GHLSSHostedContainer) GHLSSHostedContainer.frame = CGRectMake(0, 0, newW, newH);
if (GHLSSHostedContentView) GHLSSHostedContentView.frame = CGRectMake(0, 0, newW, newH);
if (GHLSSHostedTopStrip) GHLSSHostedTopStrip.frame = CGRectMake(0, 0, newW, GHLSS_HOSTED_STRIP_H);
if (GHLSSHostedTitleBar) GHLSSHostedTitleBar.frame = CGRectMake(0, 0, newW, GHLSS_HOSTED_CONTROL_H);
if (GHLSSHostedTitleLabel) GHLSSHostedTitleLabel.frame = CGRectMake(78, 0, newW - 190, GHLSS_HOSTED_CONTROL_H);
if (GHLSSHostedScaleButton) GHLSSHostedScaleButton.frame = CGRectMake(newW - 36, 5, 26, 26);
if (GHLSSHostedPinButton) GHLSSHostedPinButton.frame = CGRectMake(newW - 70, 5, 26, 26);
if (GHLSSHostedOpacityButton) GHLSSHostedOpacityButton.frame = CGRectMake(newW - 104, 5, 26, 26);
if (GHLSSHostedScaleSliderBar) {
GHLSSHostedScaleSliderBar.frame = CGRectMake(0, GHLSS_HOSTED_CONTROL_H, newW, 72);
for (UIView *sub in GHLSSHostedScaleSliderBar.subviews) {
if ([sub isKindOfClass:[UIButton class]] && sub.tag >= 100 && sub.tag <= 102) {
int sp = (int)sub.tag - 100;
sub.frame = CGRectMake(newW - 140 + sp * 44, 39, 40, 28);
}
}
}
if (GHLSSHostedScaleSlider) GHLSSHostedScaleSlider.frame = CGRectMake(10, 3, newW - 70, 30);
if (GHLSSHostedScaleLabel) GHLSSHostedScaleLabel.frame = CGRectMake(newW - 56, 3, 46, 30);
if (GHLSSHostedOpacitySliderBar) GHLSSHostedOpacitySliderBar.frame = CGRectMake(0, GHLSS_HOSTED_CONTROL_H + 72, newW, 36);
if (GHLSSHostedOpacitySlider) GHLSSHostedOpacitySlider.frame = CGRectMake(10, 3, newW - 70, 30);
if (GHLSSHostedOpacityLabel) GHLSSHostedOpacityLabel.frame = CGRectMake(newW - 56, 3, 46, 30);
if (GHLSSHostedResizeHandle) GHLSSHostedResizeHandle.frame = CGRectMake(newW - 36, newH - 36, 36, 36);
if (GHLSSHostedSideDivider) GHLSSHostedSideDivider.hidden = YES;
GHLSSHostedIsSideDock = NO;
[self resizeHostedSceneToContentSize:CGSizeMake(newW, newH)];
if (GHLSSActiveAppIndex >= 0 && GHLSSActiveAppIndex < GHLSS_APP_COUNT) {
GHLSSSaveGeometryForIndex(GHLSSActiveAppIndex);
}
char buf[128];
snprintf(buf, sizeof(buf), "v43 window resized to %dx%d", (int)newW, (int)newH);
GHLSSLogLine(buf);
}

// v42：手勢動作分派（手勢自定義與釘選鈕共用）：pin 釘選/取消、
// dock 收起貼邊、close 關掉、cycle 輪切主窗、maximize 放大到全屏尺寸。
- (void)performGestureAction:(const char *)action {
if (!action || !GHLSSHostedWindow) return;
if (strcmp(action, "pin") == 0) {
if (GHLSSHostedBundleID[0] == '\0') return;
BOOL pinned = GHLSSIsWindowPinned(GHLSSHostedBundleID);
NSMutableArray *ids = [NSMutableArray arrayWithArray:GHLSSReadIDList("pinnedWindowIDs")];
NSString *bidStr = [NSString stringWithCString:GHLSSHostedBundleID encoding:NSUTF8StringEncoding];
[ids removeObject:bidStr];
if (!pinned) [ids insertObject:bidStr atIndex:0];
GHLSSWriteIDList("pinnedWindowIDs", ids);
if (GHLSSHostedPinButton) {
GHLSSHostedPinButton.backgroundColor = !pinned ? [UIColor colorWithRed:0.83 green:0.68 blue:0.21 alpha:1.0] : [UIColor colorWithRed:0.15 green:0.15 blue:0.15 alpha:1.0];
}
GHLSSBringWindowToFront(GHLSSHostedWindow);
char buf[256];
snprintf(buf, sizeof(buf), "v43 window %s %s", GHLSSHostedBundleID, !pinned ? "pinned" : "unpinned");
GHLSSLogLine(buf);
} else if (strcmp(action, "dock") == 0) {
[self minimizeHostedWindow];
} else if (strcmp(action, "close") == 0) {
[self closeHostedWindow];
} else if (strcmp(action, "cycle") == 0) {
[self cycleMainWindow];
} else if (strcmp(action, "maximize") == 0) {
CGRect screenBounds = [UIScreen mainScreen].bounds;
CGFloat safeDistance = GHLSSReadSafeDistance();
[self resizeActiveWindowToFrame:CGRectMake(8.0, safeDistance, screenBounds.size.width - 16.0, screenBounds.size.height - safeDistance - 8.0)];
}
}

// v42：控制條「釘」鈕——先切活動量到按鈕所在的窗，再釘選/取消。
- (void)handlePinButton:(UIButton *)sender {
if ([sender isKindOfClass:[UIView class]]) {
GHLSSSetActiveToWindow(GHLSSWindowForView((UIView *)sender));
}
[self performGestureAction:"pin"];
}

// v42：控制條「透」鈕——展開/收起透明度滑桿條。
- (void)handleOpacityButton:(UIButton *)sender {
if ([sender isKindOfClass:[UIView class]]) {
GHLSSSetActiveToWindow(GHLSSWindowForView((UIView *)sender));
}
if (!GHLSSHostedOpacitySliderBar) return;
GHLSSHostedOpacitySliderBar.hidden = !GHLSSHostedOpacitySliderBar.hidden;
if (!GHLSSHostedOpacitySliderBar.hidden && GHLSSHostedOpacitySlider) {
GHLSSHostedOpacitySlider.value = GHLSSReadWindowOpacityForBundleID(GHLSSHostedBundleID);
}
GHLSSLogLine("v43 opacity bar toggled");
}

// v42：透明度滑桿——拖動即改窗的 alpha；松手才存每窗值。
- (void)handleOpacitySlider:(UISlider *)sender {
if (!GHLSSHostedWindow) return;
GHLSSHostedWindow.alpha = sender.value;
if (GHLSSHostedOpacityLabel) {
char pbuf[32];
snprintf(pbuf, sizeof(pbuf), "%d%%", (int)(sender.value * 100.0));
GHLSSHostedOpacityLabel.text = [NSString stringWithCString:pbuf encoding:NSUTF8StringEncoding];
}
}
- (void)handleOpacitySliderEnded:(UISlider *)sender {
if (GHLSSHostedBundleID[0] == '\0') return;
char key[192];
snprintf(key, sizeof(key), "winOpacity_%s", GHLSSHostedBundleID);
GHLSSWritePrefsDouble(key, (double)sender.value);
GHLSSLogLine("v43 window opacity saved");
}

// v42：尺寸預設鈕（小/中/大，tag 100/101/102）——窗立刻變那個尺寸
//（保持窗中心不動），同時寫回預設（下次開窗也用這個尺寸）。
- (void)handleSizePresetButton:(UIButton *)sender {
int preset = (int)sender.tag - 100;
if (preset < 0 || preset > 2 || !GHLSSHostedWindow) return;
GHLSSWritePrefsCString("windowSizePreset", preset == 0 ? "small" : (preset == 2 ? "large" : "medium"));
CGSize size;
if (preset == 0) size = CGSizeMake(280, 600);
else if (preset == 2) size = CGSizeMake(414, 800);
else size = CGSizeMake(350, 757);
CGRect frame = GHLSSHostedWindow.frame;
CGFloat cx = frame.origin.x + frame.size.width / 2.0;
CGFloat cy = frame.origin.y + frame.size.height / 2.0;
[self resizeActiveWindowToFrame:CGRectMake(cx - size.width / 2.0, cy - size.height / 2.0, size.width, size.height)];
if (GHLSSHostedScaleSliderBar) {
for (UIView *sub in GHLSSHostedScaleSliderBar.subviews) {
if ([sub isKindOfClass:[UIButton class]] && sub.tag >= 100 && sub.tag <= 102) {
BOOL current = ((int)sub.tag - 100 == preset);
sub.layer.borderWidth = current ? 2.0 : 1.0;
sub.layer.borderColor = current ? [UIColor colorWithRed:0.83 green:0.68 blue:0.21 alpha:1.0].CGColor : [[UIColor whiteColor] colorWithAlphaComponent:0.3].CGColor;
}
}
}
char buf[64];
snprintf(buf, sizeof(buf), "v43 window size preset %d", preset);
GHLSSLogLine(buf);
}

// v42：手勢自定義（細條上的手勢；動作走設定，沒設回預設：
// 三擊=釘選、上下滑=收起貼邊、左右滑=關掉、雙指點=放大）。
- (void)handleGestureTripleTap:(UITapGestureRecognizer *)recognizer {
UIWindow *w = GHLSSWindowForView(recognizer.view);
if (w) GHLSSSetActiveToWindow(w);
char *action = GHLSSReadPrefsCString("gestureTripleTap");
const char *a = action ? action : "pin";
[self performGestureAction:a];
if (action) free(action);
GHLSSLogLine("v43 gesture triple tap");
}
- (void)handleGestureSwipeVertical:(UISwipeGestureRecognizer *)recognizer {
UIWindow *w = GHLSSWindowForView(recognizer.view);
if (w) GHLSSSetActiveToWindow(w);
char *action = GHLSSReadPrefsCString("gestureSwipeV");
const char *a = action ? action : "dock";
[self performGestureAction:a];
if (action) free(action);
GHLSSLogLine("v43 gesture swipe vertical");
}
- (void)handleGestureSwipeHorizontal:(UISwipeGestureRecognizer *)recognizer {
UIWindow *w = GHLSSWindowForView(recognizer.view);
if (w) GHLSSSetActiveToWindow(w);
char *action = GHLSSReadPrefsCString("gestureSwipeH");
const char *a = action ? action : "close";
[self performGestureAction:a];
if (action) free(action);
GHLSSLogLine("v43 gesture swipe horizontal");
}
- (void)handleGestureTwoFingerTap:(UITapGestureRecognizer *)recognizer {
UIWindow *w = GHLSSWindowForView(recognizer.view);
if (w) GHLSSSetActiveToWindow(w);
char *action = GHLSSReadPrefsCString("gestureTwoFingerTap");
const char *a = action ? action : "maximize";
[self performGestureAction:a];
if (action) free(action);
GHLSSLogLine("v43 gesture two finger tap");
}

// v42：懸浮球點一下——開 ARC（跟哆啦A夢鈕同一條路，ARC 關了就不開）。
- (void)handleFloatBallTap:(UITapGestureRecognizer *)recognizer {
(void)recognizer;
if (!GHLSSReadARCEnabled()) {
GHLSSLogLine("v43 float ball tap ignored, arc disabled");
return;
}
GHLSSLogLine("v43 float ball tapped, opening ARC");
[self showLauncher];
}
// v42：懸浮球拖動——拖到屏幕任何位置，放手記住位置（floatBallX/Y）。
- (void)handleFloatBallDrag:(UIPanGestureRecognizer *)recognizer {
if (!GHLSSFloatBallWindow) return;
CGPoint point = [recognizer translationInView:GHLSSFloatBallWindow];
[recognizer setTranslation:CGPointZero inView:GHLSSFloatBallWindow];
CGPoint center = GHLSSFloatBallWindow.center;
CGRect screenBounds = [UIScreen mainScreen].bounds;
CGFloat newX = center.x + point.x;
CGFloat newY = center.y + point.y;
if (newX < 22.0) newX = 22.0;
if (newX > screenBounds.size.width - 22.0) newX = screenBounds.size.width - 22.0;
if (newY < 60.0) newY = 60.0;
if (newY > screenBounds.size.height - 60.0) newY = screenBounds.size.height - 60.0;
GHLSSFloatBallWindow.center = CGPointMake(newX, newY);
if (recognizer.state == UIGestureRecognizerStateEnded) {
GHLSSWritePrefsDouble("floatBallX", (double)newX);
GHLSSWritePrefsDouble("floatBallY", (double)newY);
GHLSSLogLine("v43 float ball position saved");
}
}

// v42：演示模式小點——點一下退出演示模式（設定 App 裡的開關不受影響）。
- (void)handleDemoDotTap:(UITapGestureRecognizer *)recognizer {
(void)recognizer;
GHLSSWritePrefsBool("demoModeEnabled", NO);
GHLSSLogLine("v43 demo mode exited via dot");
GHLSSApplyDemoMode();
}

// v42：底部任務欄點圖標——切到那個窗（收著的從 peek 恢復）。
- (void)handleTaskbarButton:(UIButton *)sender {
NSInteger idx = sender.tag;
if (idx < 0 || idx >= GHLSS_APP_COUNT) return;
if (!GHLSSCacheWindows[idx]) return;
[self promoteWindowToMainIndex:(int)idx];
GHLSSUpdateTaskbar();
}

// v42：ARC 裡的「設置」——收起 ARC，開浮窗設定卡片。
- (void)handleARCSettingsButton:(id)sender {
(void)sender;
[self dismissLauncher];
[self showSettingsCard];
}

// v42：ARC 配對推薦行——成對開（主 App 浮窗 + 另一個側窗）。
- (void)handleARCPairButton:(UIButton *)sender {
(void)sender;
if (GHLSSARCPairMain[0] == '\0' || GHLSSARCPairOther[0] == '\0') return;
char mainName[128], otherName[128];
GHLSSAppNameForBundleID(GHLSSARCPairMain, mainName, sizeof(mainName));
GHLSSAppNameForBundleID(GHLSSARCPairOther, otherName, sizeof(otherName));
[self dismissLauncher];
[self openPairWithBundleIDs:GHLSSARCPairMain mainName:mainName sideBid:GHLSSARCPairOther sideName:otherName];
}

// v42：ARC 裡的演示模式開關——寫同一份鍵，立刻藏/顯示回來。
// 開了會把 ARC 一起藏掉，只剩角落小點（點小點退出）。
- (void)handleDemoModeSwitch:(UISwitch *)sender {
GHLSSWritePrefsBool("demoModeEnabled", sender.on);
GHLSSLogLine(sender.on ? "v43 demo mode on from ARC" : "v43 demo mode off from ARC");
GHLSSApplyDemoMode();
}

// v42：成對開窗（主 App 浮窗 + 側窗 App）：主 App 已開著就升為主窗，
// 沒開就開浮窗；側窗 App 1.5 秒後開側窗（錯開兩次啟動事務）。
- (void)openPairWithBundleIDs:(const char *)mainBid mainName:(const char *)mainName sideBid:(const char *)sideBid sideName:(const char *)sideName {
if (!mainBid || !sideBid || !mainBid[0] || !sideBid[0]) return;
char buf[300];
snprintf(buf, sizeof(buf), "v43 opening pair %s + %s", mainBid, sideBid);
GHLSSLogLine(buf);
int mainIdx = GHLSSAppIndexForBundleID(mainBid);
if (mainIdx >= 0 && GHLSSCacheWindows[mainIdx] && !GHLSSCacheWindows[mainIdx].hidden) {
[self promoteWindowToMainIndex:mainIdx];
} else if (mainIdx >= 0 && GHLSSCacheWindows[mainIdx] && GHLSSCacheMinimized[mainIdx]) {
GHLSSLoadCacheToActive(mainIdx);
[self restoreHostedWindow];
} else {
[self launchHostedApp:mainBid name:mainName];
}
char *sideBidCopy = strdup(sideBid);
char *sideNameCopy = strdup(sideName);
if (!sideBidCopy || !sideNameCopy) {
if (sideBidCopy) free(sideBidCopy);
if (sideNameCopy) free(sideNameCopy);
return;
}
dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1500 * NSEC_PER_MSEC)), dispatch_get_main_queue(), ^{
GHLSSForceThreeScreenOnce = YES;
[self launchHostedApp:sideBidCopy name:sideNameCopy];
free(sideBidCopy);
free(sideNameCopy);
});
}

// v42：邊緣滑動直接開三屏（開關開著時）：有上次的組合就重開那一對，
// 沒有就用最近開的 App 開側窗（再沒有就開計算器側窗）。
- (void)openThreeScreenFromEdge {
char *lastPair = GHLSSReadPrefsCString("lastThreeScreenPair");
if (lastPair) {
char a[128], b[128];
if (GHLSSSplitPairString(lastPair, a, sizeof(a), b, sizeof(b))) {
char nameA[128], nameB[128];
GHLSSAppNameForBundleID(a, nameA, sizeof(nameA));
GHLSSAppNameForBundleID(b, nameB, sizeof(nameB));
GHLSSLogLine("v43 edge swipe opening last three screen pair");
free(lastPair);
[self openPairWithBundleIDs:a mainName:nameA sideBid:b sideName:nameB];
return;
}
free(lastPair);
}
NSArray *recent = GHLSSReadIDList("recentAppIDs");
char bidBuf[128] = {0};
const char *bid = NULL;
if ([recent count] > 0 && [[recent objectAtIndex:0] isKindOfClass:[NSString class]]) {
const char *r = [[recent objectAtIndex:0] UTF8String];
if (r) { strncpy(bidBuf, r, sizeof(bidBuf) - 1); bid = bidBuf; }
}
if (!bid) bid = "com.apple.calculator";
char name[128];
GHLSSAppNameForBundleID(bid, name, sizeof(name));
GHLSSLogLine("v43 edge swipe opening recent app as side window");
GHLSSForceThreeScreenOnce = YES;
[self launchHostedApp:bid name:name];
}

// v42：設定頁寫的開三屏組合請求（key openThreeScreenPair，
// 三屏組合子頁/上次組合點了寫；2 秒定時輪詢在這裡接，開完清掉）。
- (void)checkPendingPairOpen {
char *pair = GHLSSReadPrefsCString("openThreeScreenPair");
if (!pair || pair[0] == '\0') {
if (pair) free(pair);
return;
}
char a[128], b[128];
if (!GHLSSSplitPairString(pair, a, sizeof(a), b, sizeof(b))) {
GHLSSWritePrefsCString("openThreeScreenPair", "");
free(pair);
return;
}
GHLSSWritePrefsCString("openThreeScreenPair", "");
free(pair);
char nameA[128], nameB[128];
GHLSSAppNameForBundleID(a, nameA, sizeof(nameA));
GHLSSAppNameForBundleID(b, nameB, sizeof(nameB));
char buf[300];
snprintf(buf, sizeof(buf), "v43 opening pair from settings %s + %s", a, b);
GHLSSLogLine(buf);
[self openPairWithBundleIDs:a mainName:nameA sideBid:b sideName:nameB];
}

// v42：鍵盤彈出時浮窗自動上移（探針：鍵盤通知是 App 進程發的，
// SpringBoard 這邊可能收不到——收到了才上移，收不到就不動，見 §115）。
// 上移只動活動窗（鍵盤擋住它的底才移，移多少看鍵盤高度），收起回原位。
- (void)handleKeyboardWillShow:(NSNotification *)note {
if (!GHLSSReadKeyboardAvoidEnabled()) return;
if (!GHLSSHostedWindow || GHLSSHostedMinimized || GHLSSKeyboardShifted) return;
NSDictionary *info = note.userInfo;
NSValue *frameValue = info ? [info objectForKey:UIKeyboardFrameEndUserInfoKey] : nil;
if (!frameValue) return;
CGRect kbFrame = [frameValue CGRectValue];
CGFloat kbHeight = kbFrame.size.height;
if (kbHeight <= 0) return;
CGRect screenBounds = [UIScreen mainScreen].bounds;
CGRect winFrame = GHLSSHostedWindow.frame;
CGFloat winBottom = winFrame.origin.y + winFrame.size.height;
CGFloat kbTop = screenBounds.size.height - kbHeight;
if (winBottom <= kbTop) return;
GHLSSKeyboardSavedFrame = winFrame;
CGFloat shift = winBottom - kbTop;
CGFloat newY = winFrame.origin.y - shift;
CGFloat minY = GHLSSReadSafeDistance();
if (newY < minY) newY = minY;
GHLSSHostedWindow.frame = CGRectMake(winFrame.origin.x, newY, winFrame.size.width, winFrame.size.height);
GHLSSKeyboardShifted = YES;
char buf[128];
snprintf(buf, sizeof(buf), "v43 window shifted up for keyboard %dpt", (int)shift);
GHLSSLogLine(buf);
}
- (void)handleKeyboardWillHide:(NSNotification *)note {
(void)note;
if (!GHLSSKeyboardShifted || !GHLSSHostedWindow) return;
GHLSSHostedWindow.frame = GHLSSKeyboardSavedFrame;
GHLSSKeyboardShifted = NO;
GHLSSLogLine("v43 window restored after keyboard hide");
}

// v42：任意文字的通知橫幅（低電量收窗提示用；跟 showNotificationBannerForName
// 共用同一個橫幅窗；演示模式開著時橫幅不顯示、計時到了也不會把它叫回來）。
- (void)showNotificationBannerWithText:(const char *)text {
if (!GHLSSReadNotificationBanner()) return;
if (!text) text = "";
CGRect screenBounds = [UIScreen mainScreen].bounds;
CGFloat w = screenBounds.size.width - 64.0;
CGFloat h = 44.0;
if (!GHLSSNotificationBannerWindow) {
GHLSSNotificationBannerWindow = [[UIWindow alloc] initWithFrame:CGRectMake(32, GHLSSReadSafeDistance() + 8, w, h)];
GHLSSNotificationBannerWindow.windowLevel = UIWindowLevelAlert - 0.25;
GHLSSNotificationBannerWindow.backgroundColor = [UIColor clearColor];
UIWindowScene *bannerScene = GHLSSActiveWindowScene();
if (bannerScene) GHLSSNotificationBannerWindow.windowScene = bannerScene;
UIViewController *vc = [[UIViewController alloc] init];
UIView *pill = [[UIView alloc] initWithFrame:CGRectMake(0, 0, w, h)];
pill.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.85];
pill.layer.cornerRadius = 22.0;
vc.view = pill;
UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(12, 0, w - 24, h)];
label.tag = 99;
label.textColor = [UIColor whiteColor];
label.font = [UIFont systemFontOfSize:15];
label.textAlignment = NSTextAlignmentCenter;
[pill addSubview:label];
GHLSSNotificationBannerWindow.rootViewController = vc;
}
GHLSSNotificationBannerWindow.frame = CGRectMake(32, GHLSSReadSafeDistance() + 8, w, h);
UILabel *label = (UILabel *)[GHLSSNotificationBannerWindow.rootViewController.view viewWithTag:99];
if (label) label.text = [NSString stringWithCString:text encoding:NSUTF8StringEncoding];
GHLSSNotificationBannerWindow.hidden = NO;
double duration = GHLSSReadBannerDuration();
dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(duration * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
if (!GHLSSDemoModeApplied) GHLSSNotificationBannerWindow.hidden = YES;
});
char buf[256];
snprintf(buf, sizeof(buf), "v43 notification banner text %s", text);
GHLSSLogLine(buf);
}

// ── v42 浮窗設定卡片（ARC 裡「設置」開） ──
// 概念圖已獲皇上「不錯」：主屏變暗，白色大圓角卡片浮在中間、金邊、
// 頂上圓形龍頭 logo（金環）+ 標題「顾海龙分屏」+ 版本 v1.0.42、右上角 X；
// 下面五段同系統設定頁；點一項在卡片裡切到那一頁；點外面/X 收起、
// 關掉直接回到原來的 App；層級 Alert-1（1999，鎖屏之下）。
// 表格走 GHLSSLauncher 自己當資料源/代理（dylib 裡唯一自訂類）；
// 開關/滑桿/分段控制都讀寫同一份 CFPreferences key（系統設定頁同步）；
// 頭像/背景圖只讀設定目錄存好的檔案；做不到的子頁（頭像/背景選圖、
// 手勢總覽、高級設置）跳回系統設定、頁腳寫明。
// 行定義（GHLSSCardRow）：0 開關、1 滑桿、2 連結、3 操作、4 分段控制、
// 5 資訊行、6 配對行、7 返回行。

- (void)showSettingsCard {
if (GHLSSSettingsCardWindow && !GHLSSSettingsCardWindow.hidden) return;
CGRect screenBounds = [UIScreen mainScreen].bounds;
if (!GHLSSSettingsCardWindow) {
GHLSSSettingsCardWindow = [[UIWindow alloc] initWithFrame:screenBounds];
GHLSSSettingsCardWindow.windowLevel = UIWindowLevelAlert - 1.0;
GHLSSSettingsCardWindow.backgroundColor = [UIColor clearColor];
UIWindowScene *cardScene = GHLSSActiveWindowScene();
if (cardScene) GHLSSSettingsCardWindow.windowScene = cardScene;
UIViewController *vc = [[UIViewController alloc] init];
UIView *root = [[UIView alloc] initWithFrame:screenBounds];
root.backgroundColor = [UIColor clearColor];
vc.view = root;
UIView *bg = [[UIView alloc] initWithFrame:screenBounds];
bg.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.55];
UITapGestureRecognizer *bgTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleSettingsCardBackgroundTap:)];
[bg addGestureRecognizer:bgTap];
[root addSubview:bg];
CGFloat cardW = screenBounds.size.width - 48.0;
CGFloat cardH = screenBounds.size.height - 240.0;
UIView *card = [[UIView alloc] initWithFrame:CGRectMake(24, 110, cardW, cardH)];
card.backgroundColor = [UIColor whiteColor];
card.layer.cornerRadius = 24.0;
card.layer.borderWidth = 2.0;
card.layer.borderColor = [UIColor colorWithRed:0.83 green:0.68 blue:0.21 alpha:1.0].CGColor;
card.layer.masksToBounds = YES;
[root addSubview:card];
UIImageView *bgView = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, cardW, cardH)];
bgView.contentMode = UIViewContentModeScaleAspectFill;
bgView.clipsToBounds = YES;
[card addSubview:bgView];
GHLSSSettingsCardBgView = bgView;
UIView *overlay = [[UIView alloc] initWithFrame:CGRectMake(0, 0, cardW, cardH)];
overlay.backgroundColor = [[UIColor whiteColor] colorWithAlphaComponent:0.72];
[card addSubview:overlay];
GHLSSSettingsCardOverlayView = overlay;
UIView *header = [[UIView alloc] initWithFrame:CGRectMake(0, 0, cardW, 76)];
header.backgroundColor = [[UIColor whiteColor] colorWithAlphaComponent:0.9];
[card addSubview:header];
UIImageView *avatar = [[UIImageView alloc] initWithFrame:CGRectMake(16, 10, 56, 56)];
avatar.layer.cornerRadius = 28.0;
avatar.layer.masksToBounds = YES;
avatar.layer.borderWidth = 2.0;
avatar.layer.borderColor = [UIColor colorWithRed:0.83 green:0.68 blue:0.21 alpha:1.0].CGColor;
avatar.userInteractionEnabled = YES;
UITapGestureRecognizer *avatarTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleSettingsCardAvatarTap:)];
[avatar addGestureRecognizer:avatarTap];
[header addSubview:avatar];
GHLSSSettingsCardAvatarView = avatar;
UILabel *title = [[UILabel alloc] initWithFrame:CGRectMake(84, 14, cardW - 140, 28)];
title.text = [NSString stringWithCString:"顾海龙分屏" encoding:NSUTF8StringEncoding];
title.font = [UIFont boldSystemFontOfSize:20];
title.textColor = [UIColor blackColor];
[header addSubview:title];
UILabel *version = [[UILabel alloc] initWithFrame:CGRectMake(84, 42, cardW - 140, 20)];
version.text = [NSString stringWithCString:"v1.0.42" encoding:NSUTF8StringEncoding];
version.font = [UIFont systemFontOfSize:13];
version.textColor = [UIColor grayColor];
[header addSubview:version];
UIButton *xBtn = [UIButton buttonWithType:UIButtonTypeCustom];
xBtn.frame = CGRectMake(cardW - 48, 14, 36, 36);
[xBtn setTitle:[NSString stringWithCString:"×" encoding:NSUTF8StringEncoding] forState:UIControlStateNormal];
[xBtn setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
xBtn.titleLabel.font = [UIFont systemFontOfSize:28];
[xBtn addTarget:self action:@selector(handleSettingsCardClose:) forControlEvents:UIControlEventTouchUpInside];
[header addSubview:xBtn];
UITableView *table = [[UITableView alloc] initWithFrame:CGRectMake(0, 76, cardW, cardH - 76) style:UITableViewStylePlain];
table.backgroundColor = [UIColor clearColor];
table.dataSource = self;
table.delegate = self;
[card addSubview:table];
GHLSSSettingsCardTable = table;
UIView *logToolbar = [[UIView alloc] initWithFrame:CGRectMake(0, 76, cardW, 44)];
logToolbar.backgroundColor = [UIColor clearColor];
logToolbar.hidden = YES;
[card addSubview:logToolbar];
GHLSSSettingsCardLogToolbar = logToolbar;
const char *logTitles[3] = {"刷新", "清空", "分享"};
SEL logActions[3] = {@selector(handleSettingsCardLogRefresh:), @selector(handleSettingsCardLogClear:), @selector(handleSettingsCardLogShare:)};
for (int i = 0; i < 3; i++) {
UIButton *b = [UIButton buttonWithType:UIButtonTypeSystem];
b.frame = CGRectMake(16 + i * ((cardW - 32) / 3.0), 6, (cardW - 32) / 3.0 - 8, 32);
[b setTitle:[NSString stringWithCString:logTitles[i] encoding:NSUTF8StringEncoding] forState:UIControlStateNormal];
b.titleLabel.font = [UIFont boldSystemFontOfSize:15];
[b addTarget:self action:logActions[i] forControlEvents:UIControlEventTouchUpInside];
[logToolbar addSubview:b];
}
UITextView *logView = [[UITextView alloc] initWithFrame:CGRectMake(8, 76 + 44, cardW - 16, cardH - 76 - 44 - 8)];
logView.backgroundColor = [UIColor colorWithWhite:0.95 alpha:1.0];
logView.font = [UIFont systemFontOfSize:11];
logView.editable = NO;
logView.hidden = YES;
[card addSubview:logView];
GHLSSSettingsCardLogView = logView;
GHLSSSettingsCardWindow.rootViewController = vc;
}
GHLSSSettingsCardPage = 0;
[self rebuildSettingsCard];
GHLSSSettingsCardWindow.hidden = NO;
GHLSSLogLine("v43 settings card opened");
}

- (void)dismissSettingsCard {
if (!GHLSSSettingsCardWindow) return;
GHLSSSettingsCardWindow.hidden = YES;
GHLSSLogLine("v43 settings card dismissed");
}

- (void)handleSettingsCardBackgroundTap:(UITapGestureRecognizer *)recognizer {
(void)recognizer;
[self dismissSettingsCard];
}

- (void)handleSettingsCardClose:(id)sender {
(void)sender;
[self dismissSettingsCard];
}

// v42：卡片裡的提示框（從卡片的 rootViewController 彈）。
- (void)showSettingsCardAlert:(const char *)title message:(const char *)message {
UIViewController *vc = GHLSSSettingsCardWindow ? GHLSSSettingsCardWindow.rootViewController : nil;
if (!vc) return;
UIAlertController *alert = [UIAlertController alertControllerWithTitle:[NSString stringWithCString:title encoding:NSUTF8StringEncoding] message:[NSString stringWithCString:message encoding:NSUTF8StringEncoding] preferredStyle:UIAlertControllerStyleAlert];
UIAlertAction *ok = [UIAlertAction actionWithTitle:[NSString stringWithCString:"好" encoding:NSUTF8StringEncoding] style:UIAlertActionStyleDefault handler:nil];
[alert addAction:ok];
[vc presentViewController:alert animated:YES completion:nil];
}

// v42：卡片表格重建（每頁的行；背景圖/遮罩/頭像按存好的檔案刷新；
// 日誌頁（5）不用表格，改顯示文字區）。
- (void)rebuildSettingsCard {
if (!GHLSSSettingsCardTable) return;
UIImage *bgImage = GHLSSLoadCardBgImage();
if (GHLSSSettingsCardBgView) GHLSSSettingsCardBgView.image = bgImage;
if (GHLSSSettingsCardOverlayView) GHLSSSettingsCardOverlayView.hidden = (bgImage == nil);
UIImage *avatarImage = GHLSSLoadCardAvatarImage();
if (!avatarImage) avatarImage = GHLSSLoadDragonIconImage();
if (GHLSSSettingsCardAvatarView) GHLSSSettingsCardAvatarView.image = avatarImage;
BOOL isLogPage = (GHLSSSettingsCardPage == 5);
if (GHLSSSettingsCardTable) GHLSSSettingsCardTable.hidden = isLogPage;
if (GHLSSSettingsCardLogView) GHLSSSettingsCardLogView.hidden = !isLogPage;
if (GHLSSSettingsCardLogToolbar) GHLSSSettingsCardLogToolbar.hidden = !isLogPage;
if (isLogPage) {
[self refreshSettingsCardLogView];
return;
}
GHLSSSettingsCardRowCount = 0;
if (GHLSSSettingsCardPage != 0) {
GHLSSCardAddRow(7, "", "< 返回", "", 0, 0, 0, 0, 0, "");
}
if (GHLSSSettingsCardPage == 0) {
GHLSSCardAddRow(0, "enabled", "啟用分屏", "", 0, 0, 0, 0, 0, "");
GHLSSCardAddRow(0, "demoModeEnabled", "演示模式", "開了藏哆啦A夢鈕/貼邊小卡/任務欄/橫幅，角落留小點退出", 0, 0, 0, 0, 0, "");
GHLSSCardAddRow(2, "", "三屏設置", "", 1, 0, 0, 0, 0, "");
GHLSSCardAddRow(2, "", "ARC設置", "", 2, 0, 0, 0, 0, "");
GHLSSCardAddRow(2, "", "浮窗設置", "", 3, 0, 0, 0, 0, "");
GHLSSCardAddRow(2, "", "其他雜項功能", "", 4, 0, 0, 0, 0, "");
GHLSSCardAddRow(5, "", "操作性功能", "", 0, 0, 0, 0, 0, "");
GHLSSCardAddRow(3, "", "備份配置", "", 0, 0, 0, 0, 0, "");
GHLSSCardAddRow(3, "", "導出配置", "", 0, 1, 0, 0, 0, "");
GHLSSCardAddRow(3, "", "從文件中導入配置", "", 0, 2, 0, 0, 0, "");
GHLSSCardAddRow(3, "", "從備份文件恢復配置", "", 0, 3, 0, 0, 0, "");
GHLSSCardAddRow(3, "", "重置為默認配置", "", 0, 4, 0, 0, 0, "");
GHLSSCardAddRow(5, "", "搜尋、配置方案、手勢總覽在系統設定主頁；子頁做不到的會寫明去系統設定哪一頁。", "", 0, 0, 0, 0, 0, "");
} else if (GHLSSSettingsCardPage == 1) {
GHLSSCardAddRow(0, "threeScreenEnabled", "三屏模式", "開著新窗默認走三屏側窗", 0, 0, 0, 0, 0, "");
GHLSSCardAddRow(3, "", "選擇應用", "開選 App 頁（跟 ARC 裡「＋」同一份）", 0, 10, 0, 0, 0, "");
GHLSSCardAddRow(4, "sideWidthPreset", "側窗寬度預設", "開側窗時的寬度；拖分隔線後以拖的為準", 0, 0, 0, 0, 1, "narrow|medium|wide");
GHLSSCardAddRow(4, "sideDividerThickness", "分隔線粗細", "", 0, 0, 0, 0, 1, "8|16|24");
GHLSSCardAddRow(4, "sideDividerColor", "分隔線顏色", "", 0, 0, 0, 0, 0, "gold|gray|clear");
GHLSSCardAddRow(0, "edgeSwipeOpensThreeScreen", "邊緣滑動直接開三屏", "開著邊緣滑動開三屏（上次組合），不再開 ARC", 0, 0, 0, 0, 0, "");
GHLSSCardAddRow(1, "sideCornerRadius", "側窗圓角", "", 0, 0, 0, 50, 35, "");
GHLSSCardAddRow(0, "sideShadowEnabled", "側窗陰影", "", 0, 0, 0, 0, 1, "");
GHLSSCardAddRow(1, "sideShadowOpacity", "側窗陰影透明度", "", 0, 0, 0, 1, 0.5, "");
GHLSSCardAddRow(1, "sideShadowRadius", "側窗陰影模糊半徑", "", 0, 0, 0, 30, 10, "");
GHLSSCardAddRow(0, "closeThreeScreenAlsoClosesSide", "關三屏同時關側邊小窗", "", 0, 0, 0, 0, 0, "");
char lastTitle[300];
char *lastPair = GHLSSReadPrefsCString("lastThreeScreenPair");
if (lastPair) {
char a[128], b[128];
if (GHLSSSplitPairString(lastPair, a, sizeof(a), b, sizeof(b))) {
char nameA[128], nameB[128];
GHLSSAppNameForBundleID(a, nameA, sizeof(nameA));
GHLSSAppNameForBundleID(b, nameB, sizeof(nameB));
snprintf(lastTitle, sizeof(lastTitle), "重新打開上次的三屏組合：%s + %s", nameA, nameB);
GHLSSCardAddRow(6, "", lastTitle, "點一下成對開", 0, 0, 0, 0, 0, "");
} else {
GHLSSCardAddRow(5, "", "還沒有上次的三屏組合", "", 0, 0, 0, 0, 0, "");
}
free(lastPair);
} else {
GHLSSCardAddRow(5, "", "還沒有上次的三屏組合", "", 0, 0, 0, 0, 0, "");
}
GHLSSCardAddRow(2, "", "三屏組合", "最多存 3 對常用組合", 6, 0, 0, 0, 0, "");
} else if (GHLSSSettingsCardPage == 2) {
GHLSSCardAddRow(0, "arcEnabled", "arc總開關", "", 0, 0, 0, 0, 1, "");
GHLSSCardAddRow(4, "arcOpenMode", "arc菜單 App 打開方式", "", 0, 0, 0, 0, 1, "fullscreen|floating|threescreen");
GHLSSCardAddRow(0, "gameModeEnabled", "遊戲模式", "浮窗釘在鎖屏之下最高層級", 0, 0, 0, 0, 0, "");
GHLSSCardAddRow(1, "arcEdgeDistance", "arc 與屏幕邊緣距離", "", 0, 0, 0, 60, 20, "");
GHLSSCardAddRow(0, "arcHideOnScreenshot", "截圖、錄屏時，隱藏 Arc", "錄屏開始藏；截圖藏不了（通知在截圖之後才到）", 0, 0, 0, 0, 1, "");
GHLSSCardAddRow(0, "arcHaptics", "arc震動反饋", "", 0, 0, 0, 0, 1, "");
GHLSSCardAddRow(0, "arcTouchSound", "arc觸控音效", "", 0, 0, 0, 0, 1, "");
GHLSSCardAddRow(0, "demoModeEnabled", "演示模式", "開了藏哆啦A夢鈕/貼邊小卡/任務欄/橫幅/ARC", 0, 0, 0, 0, 0, "");
GHLSSCardAddRow(5, "", "注意：橫屏狀態下 arc 上應用操作都是以浮窗模式顯示！", "", 0, 0, 0, 0, 0, "");
} else if (GHLSSSettingsCardPage == 3) {
GHLSSCardAddRow(1, "cornerRadius", "浮窗圓角", "", 0, 0, 0, 50, 35, "");
GHLSSCardAddRow(1, "safeDistance", "與劉海方向安全距離", "", 0, 0, 0, 100, 50, "");
GHLSSCardAddRow(0, "centerOnOpen", "豎屏浮窗打開固定屏中心", "開了不記住位置、固定居中；跟「記住位置」互斥", 0, 0, 0, 0, 0, "");
GHLSSCardAddRow(4, "windowSizePreset", "浮窗大小預設", "新窗的尺寸；控制條 ± 展開後也能點", 0, 0, 0, 0, 1, "small|medium|large");
GHLSSCardAddRow(0, "taskbarEnabled", "底部任務欄", "開了 2 秒內建欄；開著的窗都在上面，點一下切窗", 0, 0, 0, 0, 0, "");
GHLSSCardAddRow(1, "windowOpacityGlobal", "浮窗透明度", "新窗預設；每窗在控制條「透」鈕裡單獨調", 0, 0, 0.5, 1, 1, "");
GHLSSCardAddRow(0, "shadowEnabled", "浮窗陰影", "", 0, 0, 0, 0, 1, "");
GHLSSCardAddRow(0, "tapOutsideEnabled", "點擊浮窗外部事件", "", 0, 0, 0, 0, 1, "");
GHLSSCardAddRow(0, "keyboardAvoidEnabled", "鍵盤彈出時浮窗自動上移", "探針：通知可能到不了 SpringBoard", 0, 0, 0, 0, 1, "");
GHLSSCardAddRow(0, "lowBatteryAutoDock", "低電量自動收窗", "低於閾值收成貼邊小卡 + 橫幅", 0, 0, 0, 0, 1, "");
GHLSSCardAddRow(1, "lowBatteryThreshold", "電量閾值（%）", "", 0, 0, 10, 30, 20, "");
} else if (GHLSSSettingsCardPage == 4) {
GHLSSCardAddRow(0, "cameraPermissionEnabled", "開啟相機權限", "只存偏好，修不好相機本身", 0, 0, 0, 0, 1, "");
GHLSSCardAddRow(2, "", "查看日誌", "在卡片裡直接看分屏日誌", 5, 0, 0, 0, 0, "");
GHLSSCardAddRow(3, "", "卡片頭像設置", "去系統設定裡換（相冊選圖）", 0, 11, 0, 0, 0, "");
GHLSSCardAddRow(3, "", "卡片背景圖", "去系統設定裡換（相冊選圖）", 0, 12, 0, 0, 0, "");
GHLSSCardAddRow(0, "floatBallEnabled", "懸浮球", "開了 2 秒內建球；點一下開 ARC", 0, 0, 0, 0, 0, "");
GHLSSCardAddRow(0, "autoHideDoraemonInFullscreen", "全屏時哆啦A夢鈕自動藏", "探針：狀態列隱藏啟發式", 0, 0, 0, 0, 1, "");
GHLSSCardAddRow(3, "", "手勢總覽", "去系統設定主頁看", 0, 13, 0, 0, 0, "");
GHLSSCardAddRow(3, "", "高級設置", "去系統設定主頁看", 0, 14, 0, 0, 0, "");
GHLSSCardAddRow(5, "", "新手模式、配置方案、布局預設在系統設定主頁。", "", 0, 0, 0, 0, 0, "");
} else if (GHLSSSettingsCardPage == 6) {
char *lastPair = GHLSSReadPrefsCString("lastThreeScreenPair");
if (lastPair) {
char a[128], b[128];
if (GHLSSSplitPairString(lastPair, a, sizeof(a), b, sizeof(b))) {
char nameA[128], nameB[128];
GHLSSAppNameForBundleID(a, nameA, sizeof(nameA));
GHLSSAppNameForBundleID(b, nameB, sizeof(nameB));
char title[300];
snprintf(title, sizeof(title), "上次組合：%s + %s", nameA, nameB);
GHLSSCardAddRow(6, "", title, "點一下成對開", 0, 0, 0, 0, 0, "");
}
free(lastPair);
}
for (int s = 1; s <= 3; s++) {
char key[32];
snprintf(key, sizeof(key), "threeScreenPair%d", s);
char *pair = GHLSSReadPrefsCString(key);
if (pair) {
char a[128], b[128];
if (GHLSSSplitPairString(pair, a, sizeof(a), b, sizeof(b))) {
char nameA[128], nameB[128];
GHLSSAppNameForBundleID(a, nameA, sizeof(nameA));
GHLSSAppNameForBundleID(b, nameB, sizeof(nameB));
char title[300];
snprintf(title, sizeof(title), "組合 %d：%s + %s", s, nameA, nameB);
GHLSSCardAddRow(6, "", title, "點一下成對開", 0, s, 0, 0, 0, "");
char delTitle[64];
snprintf(delTitle, sizeof(delTitle), "刪除組合 %d", s);
GHLSSCardAddRow(3, "", delTitle, "", 0, 15 + s, 0, 0, 0, "");
}
free(pair);
}
}
GHLSSCardAddRow(3, "", "存目前這對", "現在一個浮窗 + 一個側窗時，存成常用組合", 0, 15, 0, 0, 0, "");
GHLSSCardAddRow(5, "", "點一對就成對開（主 App 浮窗 + 另一個側窗）；最多存 3 對。", "", 0, 0, 0, 0, 0, "");
}
[GHLSSSettingsCardTable reloadData];
}

// v42：卡片表格資料源/代理（行高：滑桿/分段 72，其他 52）。
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
(void)tableView;
return 1;
}
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
(void)tableView;
(void)section;
return GHLSSSettingsCardRowCount;
}
- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
(void)tableView;
if (indexPath.row < 0 || indexPath.row >= GHLSSSettingsCardRowCount) return 52.0;
GHLSSCardRow *r = &GHLSSSettingsCardRows[indexPath.row];
if (r->type == 1 || r->type == 4) return 72.0;
return 52.0;
}
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
(void)tableView;
GHLSSCardRow *r = &GHLSSSettingsCardRows[indexPath.row];
UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:nil];
cell.backgroundColor = [UIColor clearColor];
cell.textLabel.text = [NSString stringWithCString:r->title encoding:NSUTF8StringEncoding];
cell.textLabel.font = [UIFont systemFontOfSize:16];
cell.textLabel.numberOfLines = 2;
cell.detailTextLabel.text = [NSString stringWithCString:r->subtitle encoding:NSUTF8StringEncoding];
cell.detailTextLabel.font = [UIFont systemFontOfSize:12];
cell.detailTextLabel.textColor = [UIColor grayColor];
cell.detailTextLabel.numberOfLines = 2;
cell.selectionStyle = UITableViewCellSelectionStyleDefault;
CGFloat cardW = [UIScreen mainScreen].bounds.size.width - 48.0;
if (r->type == 0) {
UISwitch *sw = [[UISwitch alloc] init];
sw.tag = indexPath.row;
sw.on = GHLSSReadPrefsBool(r->key, r->defaultValue > 0.5);
[sw addTarget:self action:@selector(handleSettingsCardSwitch:) forControlEvents:UIControlEventValueChanged];
cell.accessoryView = sw;
} else if (r->type == 1) {
double v = GHLSSReadPrefsDouble(r->key, r->defaultValue);
char vbuf[32];
if (r->maxValue <= 1.0 && r->minValue >= 0.0) snprintf(vbuf, sizeof(vbuf), "%.2f", v);
else snprintf(vbuf, sizeof(vbuf), "%.0f", v);
cell.detailTextLabel.text = [NSString stringWithCString:vbuf encoding:NSUTF8StringEncoding];
UISlider *sl = [[UISlider alloc] initWithFrame:CGRectMake(16, 38, cardW - 80, 30)];
sl.tag = indexPath.row;
sl.minimumValue = (float)r->minValue;
sl.maximumValue = (float)r->maxValue;
sl.value = (float)v;
sl.minimumTrackTintColor = [UIColor colorWithRed:0.83 green:0.68 blue:0.21 alpha:1.0];
[sl addTarget:self action:@selector(handleSettingsCardSlider:) forControlEvents:UIControlEventValueChanged];
[sl addTarget:self action:@selector(handleSettingsCardSliderEnded:) forControlEvents:UIControlEventTouchUpInside | UIControlEventTouchUpOutside];
[cell.contentView addSubview:sl];
UILabel *valLabel = [[UILabel alloc] initWithFrame:CGRectMake(cardW - 60, 38, 44, 30)];
valLabel.tag = 201;
valLabel.text = [NSString stringWithCString:vbuf encoding:NSUTF8StringEncoding];
valLabel.font = [UIFont boldSystemFontOfSize:14];
valLabel.textAlignment = NSTextAlignmentCenter;
[cell.contentView addSubview:valLabel];
} else if (r->type == 2 || r->type == 6) {
cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
} else if (r->type == 3) {
cell.textLabel.textColor = [UIColor colorWithRed:0.0 green:0.48 blue:1.0 alpha:1.0];
} else if (r->type == 4) {
NSString *vals = [NSString stringWithCString:r->values encoding:NSUTF8StringEncoding];
NSString *sep = [NSString stringWithCString:"|" encoding:NSUTF8StringEncoding];
NSArray *parts = [vals componentsSeparatedByString:sep];
UISegmentedControl *seg = [[UISegmentedControl alloc] initWithFrame:CGRectMake(16, 38, cardW - 32, 30)];
seg.tag = indexPath.row;
NSInteger selected = (NSInteger)r->defaultValue;
for (NSInteger i = 0; i < (NSInteger)[parts count] && i < 3; i++) {
NSString *part = [parts objectAtIndex:i];
const char *titleC = [part UTF8String];
if (strcmp(r->key, "sideWidthPreset") == 0) {
if (strcmp(titleC, "narrow") == 0) titleC = "窄";
else if (strcmp(titleC, "medium") == 0) titleC = "中";
else if (strcmp(titleC, "wide") == 0) titleC = "寬";
} else if (strcmp(r->key, "sideDividerColor") == 0) {
if (strcmp(titleC, "gold") == 0) titleC = "金色";
else if (strcmp(titleC, "gray") == 0) titleC = "灰色";
else if (strcmp(titleC, "clear") == 0) titleC = "透明";
} else if (strcmp(r->key, "arcOpenMode") == 0) {
if (strcmp(titleC, "fullscreen") == 0) titleC = "全屏";
else if (strcmp(titleC, "floating") == 0) titleC = "浮窗";
else if (strcmp(titleC, "threescreen") == 0) titleC = "三屏";
} else if (strcmp(r->key, "windowSizePreset") == 0) {
if (strcmp(titleC, "small") == 0) titleC = "小";
else if (strcmp(titleC, "medium") == 0) titleC = "中";
else if (strcmp(titleC, "large") == 0) titleC = "大";
}
[seg insertSegmentWithTitle:[NSString stringWithCString:titleC encoding:NSUTF8StringEncoding] atIndex:i animated:NO];
}
if (strcmp(r->key, "sideDividerThickness") == 0) {
double cur = GHLSSReadPrefsDouble(r->key, r->defaultValue);
for (NSInteger i = 0; i < (NSInteger)[parts count] && i < 3; i++) {
if (fabs([[parts objectAtIndex:i] doubleValue] - cur) < 0.5) { selected = i; break; }
}
} else if (strcmp(r->key, "sideWidthPreset") == 0) {
char *cur = GHLSSReadPrefsCString(r->key);
const char *curStr = cur ? cur : "medium";
const char *vals2[3] = {"narrow", "medium", "wide"};
for (int i = 0; i < 3; i++) { if (strcmp(vals2[i], curStr) == 0) { selected = i; break; } }
if (cur) free(cur);
} else if (strcmp(r->key, "sideDividerColor") == 0) {
char *cur = GHLSSReadPrefsCString(r->key);
const char *curStr = cur ? cur : "gold";
const char *vals2[3] = {"gold", "gray", "clear"};
for (int i = 0; i < 3; i++) { if (strcmp(vals2[i], curStr) == 0) { selected = i; break; } }
if (cur) free(cur);
} else if (strcmp(r->key, "arcOpenMode") == 0) {
char *cur = GHLSSReadPrefsCString(r->key);
const char *curStr = cur ? cur : "floating";
const char *vals2[3] = {"fullscreen", "floating", "threescreen"};
for (int i = 0; i < 3; i++) { if (strcmp(vals2[i], curStr) == 0) { selected = i; break; } }
if (cur) free(cur);
} else if (strcmp(r->key, "windowSizePreset") == 0) {
char *cur = GHLSSReadPrefsCString(r->key);
const char *curStr = cur ? cur : "medium";
const char *vals2[3] = {"small", "medium", "large"};
for (int i = 0; i < 3; i++) { if (strcmp(vals2[i], curStr) == 0) { selected = i; break; } }
if (cur) free(cur);
}
if (selected < 0) selected = 0;
if (selected >= (NSInteger)[parts count]) selected = (NSInteger)[parts count] - 1;
seg.selectedSegmentIndex = selected;
[seg addTarget:self action:@selector(handleSettingsCardSegmented:) forControlEvents:UIControlEventValueChanged];
[cell.contentView addSubview:seg];
} else if (r->type == 5) {
cell.textLabel.font = [UIFont systemFontOfSize:13];
cell.textLabel.textColor = [UIColor grayColor];
cell.detailTextLabel.text = [NSString string];
cell.selectionStyle = UITableViewCellSelectionStyleNone;
} else if (r->type == 7) {
cell.textLabel.textColor = [UIColor colorWithRed:0.0 green:0.48 blue:1.0 alpha:1.0];
}
return cell;
}
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
(void)tableView;
if (indexPath.row < 0 || indexPath.row >= GHLSSSettingsCardRowCount) return;
GHLSSCardRow *r = &GHLSSSettingsCardRows[indexPath.row];
[tableView deselectRowAtIndexPath:indexPath animated:YES];
if (r->type == 2) {
GHLSSSettingsCardPage = r->page;
[self rebuildSettingsCard];
} else if (r->type == 7) {
GHLSSSettingsCardPage = 0;
[self rebuildSettingsCard];
} else if (r->type == 3) {
[self handleSettingsCardActionRow:(int)indexPath.row];
} else if (r->type == 6) {
[self handleSettingsCardPairButtonForAction:r->action];
}
}

// v42：卡片裡的開關——寫同一份 key（系統設定頁同步）；
// 演示模式立刻藏/顯示回來；任務欄/懸浮球開了 2 秒內建好。
- (void)handleSettingsCardSwitch:(UISwitch *)sender {
int row = (int)sender.tag;
if (row < 0 || row >= GHLSSSettingsCardRowCount) return;
GHLSSCardRow *r = &GHLSSSettingsCardRows[row];
GHLSSWritePrefsBool(r->key, sender.on);
if (strcmp(r->key, "demoModeEnabled") == 0) {
GHLSSApplyDemoMode();
} else if (strcmp(r->key, "taskbarEnabled") == 0 && sender.on) {
GHLSSBuildTaskbarIfNeeded();
GHLSSUpdateTaskbar();
} else if (strcmp(r->key, "floatBallEnabled") == 0 && sender.on) {
GHLSSBuildFloatBallIfNeeded();
}
char buf[128];
snprintf(buf, sizeof(buf), "v43 card switch %s %d", r->key, sender.on ? 1 : 0);
GHLSSLogLine(buf);
}
// v42：卡片裡的滑桿——拖動即改顯示值，松手才寫 prefs。
- (void)handleSettingsCardSlider:(UISlider *)sender {
int row = (int)sender.tag;
if (row < 0 || row >= GHLSSSettingsCardRowCount) return;
GHLSSCardRow *r = &GHLSSSettingsCardRows[row];
NSIndexPath *path = [NSIndexPath indexPathForRow:row inSection:0];
UITableViewCell *cell = [GHLSSSettingsCardTable cellForRowAtIndexPath:path];
char vbuf[32];
if (r->maxValue <= 1.0 && r->minValue >= 0.0) snprintf(vbuf, sizeof(vbuf), "%.2f", (double)sender.value);
else snprintf(vbuf, sizeof(vbuf), "%.0f", (double)sender.value);
if (cell) {
cell.detailTextLabel.text = [NSString stringWithCString:vbuf encoding:NSUTF8StringEncoding];
UILabel *valLabel = (UILabel *)[cell.contentView viewWithTag:201];
if (valLabel) valLabel.text = [NSString stringWithCString:vbuf encoding:NSUTF8StringEncoding];
}
}
- (void)handleSettingsCardSliderEnded:(UISlider *)sender {
int row = (int)sender.tag;
if (row < 0 || row >= GHLSSSettingsCardRowCount) return;
GHLSSCardRow *r = &GHLSSSettingsCardRows[row];
GHLSSWritePrefsDouble(r->key, (double)sender.value);
char buf[128];
snprintf(buf, sizeof(buf), "v43 card slider %s %.2f", r->key, (double)sender.value);
GHLSSLogLine(buf);
}
// v42：卡片裡的分段控制——值寫回 prefs（分隔線粗細是數字，其餘是字串）。
- (void)handleSettingsCardSegmented:(UISegmentedControl *)sender {
int row = (int)sender.tag;
if (row < 0 || row >= GHLSSSettingsCardRowCount) return;
GHLSSCardRow *r = &GHLSSSettingsCardRows[row];
NSString *vals = [NSString stringWithCString:r->values encoding:NSUTF8StringEncoding];
NSString *sep = [NSString stringWithCString:"|" encoding:NSUTF8StringEncoding];
NSArray *parts = [vals componentsSeparatedByString:sep];
NSInteger idx = sender.selectedSegmentIndex;
if (idx < 0 || idx >= (NSInteger)[parts count]) return;
NSString *value = [parts objectAtIndex:idx];
if (strcmp(r->key, "sideDividerThickness") == 0) {
GHLSSWritePrefsDouble(r->key, [value doubleValue]);
} else {
GHLSSWritePrefsCString(r->key, [value UTF8String]);
}
char buf[128];
snprintf(buf, sizeof(buf), "v43 card segmented %s %s", r->key, [value UTF8String]);
GHLSSLogLine(buf);
}
// v42：卡片裡的操作行（備份/導出/導入/恢復/重置/選 App/去設定頁/存組合/刪組合）。
- (void)handleSettingsCardActionRow:(int)row {
if (row < 0 || row >= GHLSSSettingsCardRowCount) return;
GHLSSCardRow *r = &GHLSSSettingsCardRows[row];
int action = r->action;
NSFileManager *fm = [NSFileManager defaultManager];
NSString *prefsDir = [NSString stringWithCString:"/var/mobile/Library/Preferences" encoding:NSUTF8StringEncoding];
NSString *prefsFile = [prefsDir stringByAppendingPathComponent:[NSString stringWithCString:"com.guhailong.splitscreen.plist" encoding:NSUTF8StringEncoding]];
NSString *backupFile = [prefsDir stringByAppendingPathComponent:[NSString stringWithCString:"GuHaiLongSplitScreen-backup.plist" encoding:NSUTF8StringEncoding]];
NSString *exportFile = [prefsDir stringByAppendingPathComponent:[NSString stringWithCString:"GuHaiLongSplitScreen-export.plist" encoding:NSUTF8StringEncoding]];
if (action == 0) {
if (![fm fileExistsAtPath:prefsFile]) {
[self showSettingsCardAlert:"沒有配置文件可備份" message:"先改一個設置，配置文件才會生成。"];
return;
}
[fm removeItemAtPath:backupFile error:nil];
NSError *err = nil;
BOOL ok = [fm copyItemAtPath:prefsFile toPath:backupFile error:&err];
[self showSettingsCardAlert:(ok ? "已備份配置" : "備份失敗") message:(ok ? "備份在 GuHaiLongSplitScreen-backup.plist，恢復時讀這個文件。" : "複製配置文件時出錯。")];
} else if (action == 1) {
if (![fm fileExistsAtPath:prefsFile]) {
[self showSettingsCardAlert:"沒有配置文件可導出" message:"先改一個設置，配置文件才會生成。"];
return;
}
[fm removeItemAtPath:exportFile error:nil];
NSError *err = nil;
BOOL ok = [fm copyItemAtPath:prefsFile toPath:exportFile error:&err];
[self showSettingsCardAlert:(ok ? "已導出配置" : "導出失敗") message:(ok ? "導出在 GuHaiLongSplitScreen-export.plist，導入時讀這個文件。" : "複製配置文件時出錯。")];
} else if (action == 2) {
if (![fm fileExistsAtPath:exportFile]) {
[self showSettingsCardAlert:"沒有找到導出的配置文件" message:"先點「導出配置」，再導入。"];
return;
}
[fm removeItemAtPath:prefsFile error:nil];
NSError *err = nil;
BOOL ok = [fm copyItemAtPath:exportFile toPath:prefsFile error:&err];
if (ok) {
CFStringRef domain = CFStringCreateWithCString(NULL, "com.guhailong.splitscreen", kCFStringEncodingUTF8);
if (domain) { CFPreferencesAppSynchronize(domain); CFRelease(domain); }
[self rebuildSettingsCard];
}
[self showSettingsCardAlert:(ok ? "已導入配置" : "導入失敗") message:(ok ? "配置已恢復，請重新啟動 SpringBoard 生效。" : "複製配置文件時出錯。")];
} else if (action == 3) {
if (![fm fileExistsAtPath:backupFile]) {
[self showSettingsCardAlert:"沒有找到備份文件" message:"先點「備份配置」，再恢復。"];
return;
}
[fm removeItemAtPath:prefsFile error:nil];
NSError *err = nil;
BOOL ok = [fm copyItemAtPath:backupFile toPath:prefsFile error:&err];
if (ok) {
CFStringRef domain = CFStringCreateWithCString(NULL, "com.guhailong.splitscreen", kCFStringEncodingUTF8);
if (domain) { CFPreferencesAppSynchronize(domain); CFRelease(domain); }
[self rebuildSettingsCard];
}
[self showSettingsCardAlert:(ok ? "已從備份恢復配置" : "恢復失敗") message:(ok ? "配置已恢復，請重新啟動 SpringBoard 生效。" : "複製配置文件時出錯。")];
} else if (action == 4) {
NSError *err = nil;
BOOL removed = YES;
if ([fm fileExistsAtPath:prefsFile]) removed = [fm removeItemAtPath:prefsFile error:&err];
CFStringRef domain = CFStringCreateWithCString(NULL, "com.guhailong.splitscreen", kCFStringEncodingUTF8);
if (domain) { CFPreferencesAppSynchronize(domain); CFRelease(domain); }
[self rebuildSettingsCard];
[self showSettingsCardAlert:(removed ? "已重置為默認配置" : "重置失敗") message:(removed ? "全部設置已恢復默認（備份文件還在），請重新啟動 SpringBoard 生效。" : "刪除配置文件時出錯。")];
} else if (action == 10) {
[self dismissSettingsCard];
[self showAppPicker];
} else if (action == 11) {
[self showSettingsCardAlert:"卡片頭像在系統設定裡換" message:"系統設定 → 其他雜項功能 → 懸浮圖標設置 → 卡片頭像設置（相冊選圖、居中裁方形；長按或點恢復回默認龍頭）。"];
} else if (action == 12) {
[self showSettingsCardAlert:"卡片背景圖在系統設定裡換" message:"系統設定 → 其他雜項功能 → 卡片背景圖（相冊選圖，上面罩半透明白，字才看得清；可恢復默認白卡）。"];
} else if (action == 13) {
[self showSettingsCardAlert:"手勢總覽在系統設定主頁" message:"系統設定 → 顧海龍分屏 → 手勢總覽（一頁列出全部手勢跟目前的設定值）。"];
} else if (action == 14) {
[self showSettingsCardAlert:"高級設置在系統設定主頁" message:"系統設定 → 顧海龍分屏 → 高級設置（調度、手勢自定義、三屏組合、配置方案、日誌查看器都在裡面；新手模式下主頁不顯示這一頁）。"];
} else if (action == 15) {
const char *mainBid = NULL;
const char *sideBid = NULL;
char mainBuf[128] = {0};
char sideBuf[128] = {0};
if (GHLSSActiveAppIndex >= 0 && GHLSSActiveAppIndex < GHLSS_APP_COUNT && GHLSSCacheBundleIDs[GHLSSActiveAppIndex][0] != '\0' && GHLSSCacheWindows[GHLSSActiveAppIndex] && !GHLSSCacheWindows[GHLSSActiveAppIndex].hidden) {
strncpy(mainBuf, GHLSSCacheBundleIDs[GHLSSActiveAppIndex], sizeof(mainBuf) - 1);
mainBid = mainBuf;
}
for (int i = 0; i < GHLSS_APP_COUNT; i++) {
if (GHLSSCacheIsSideDock[i] && GHLSSCacheWindows[i] && !GHLSSCacheWindows[i].hidden && GHLSSCacheBundleIDs[i][0] != '\0') {
strncpy(sideBuf, GHLSSCacheBundleIDs[i], sizeof(sideBuf) - 1);
sideBid = sideBuf;
break;
}
}
if (!mainBid || !sideBid || strcmp(mainBid, sideBid) == 0) {
[self showSettingsCardAlert:"現在沒有一對三屏" message:"要一個浮窗 + 一個側窗同時開著，才能存成常用組合。"];
return;
}
int slot = 0;
for (int s = 1; s <= 3; s++) {
char key[32];
snprintf(key, sizeof(key), "threeScreenPair%d", s);
char *existing = GHLSSReadPrefsCString(key);
BOOL empty = (!existing || existing[0] == '\0');
if (existing) free(existing);
if (empty) { slot = s; break; }
}
if (slot == 0) slot = 3;
char key[32];
snprintf(key, sizeof(key), "threeScreenPair%d", slot);
char pair[256];
snprintf(pair, sizeof(pair), "%s|%s", mainBid, sideBid);
GHLSSWritePrefsCString(key, pair);
GHLSSSaveLastThreeScreenPair(mainBid, sideBid);
[self rebuildSettingsCard];
char msg[256];
snprintf(msg, sizeof(msg), "已存成組合 %d（%s + %s）。", slot, mainBid, sideBid);
[self showSettingsCardAlert:"已存目前這對" message:msg];
} else if (action >= 16 && action <= 18) {
int slot = action - 15;
char key[32];
snprintf(key, sizeof(key), "threeScreenPair%d", slot);
GHLSSWritePrefsCString(key, "");
[self rebuildSettingsCard];
char msg[64];
snprintf(msg, sizeof(msg), "組合 %d 已刪除。", slot);
[self showSettingsCardAlert:"已刪除" message:msg];
}
}
// v42：卡片裡的配對行（action 0 = 上次組合，1–3 = 存的組合）——
// 收起卡片、成對開（主 App 浮窗 + 另一個側窗）。
- (void)handleSettingsCardPairButtonForAction:(int)action {
char pair[256] = {0};
if (action == 0) {
char *lastPair = GHLSSReadPrefsCString("lastThreeScreenPair");
if (!lastPair) return;
strncpy(pair, lastPair, sizeof(pair) - 1);
free(lastPair);
} else if (action >= 1 && action <= 3) {
char key[32];
snprintf(key, sizeof(key), "threeScreenPair%d", action);
char *saved = GHLSSReadPrefsCString(key);
if (!saved) return;
strncpy(pair, saved, sizeof(pair) - 1);
free(saved);
} else {
return;
}
char a[128], b[128];
if (!GHLSSSplitPairString(pair, a, sizeof(a), b, sizeof(b))) return;
char nameA[128], nameB[128];
GHLSSAppNameForBundleID(a, nameA, sizeof(nameA));
GHLSSAppNameForBundleID(b, nameB, sizeof(nameB));
[self dismissSettingsCard];
[self openPairWithBundleIDs:a mainName:nameA sideBid:b sideName:nameB];
}
// v42：卡片頂上的頭像點一下——試著在卡片上直接換圖（PHPicker，
// 不用相冊權限；SpringBoard 上彈 picker 是探針，失敗就退回設定頁指引）。
- (void)handleSettingsCardAvatarTap:(UITapGestureRecognizer *)recognizer {
(void)recognizer;
@try {
Class pickerClass = objc_getClass("PHPickerViewController");
Class configClass = objc_getClass("PHPickerConfiguration");
Class filterClass = objc_getClass("PHPickerFilter");
if (!pickerClass || !configClass || !filterClass) {
[self showSettingsCardAlert:"換頭像請去系統設定" message:"系統設定 → 其他雜項功能 → 懸浮圖標設置 → 卡片頭像設置。"];
return;
}
id config = [[configClass alloc] init];
// filterClass 是運行時拿的 Class，編譯器不認 imagesFilter；
// 用 performSelector 調（-Werror 下直接調會報 no known class method）。
id filter = [filterClass performSelector:@selector(imagesFilter)];
[config setValue:filter forKey:[NSString stringWithCString:"filter" encoding:NSUTF8StringEncoding]];
[config setValue:[NSNumber numberWithInt:1] forKey:[NSString stringWithCString:"selectionLimit" encoding:NSUTF8StringEncoding]];
id picker = [[pickerClass alloc] initWithConfiguration:config];
[picker performSelector:@selector(setDelegate:) withObject:self];
UIViewController *vc = GHLSSSettingsCardWindow.rootViewController;
[vc presentViewController:picker animated:YES completion:nil];
GHLSSLogLine("v43 card avatar picker presented");
} @catch (NSException *e) {
(void)e;
[self showSettingsCardAlert:"換頭像請去系統設定" message:"卡片上直接換圖失敗（SpringBoard 上彈相冊是探針），請去系統設定 → 其他雜項功能 → 懸浮圖標設置 → 卡片頭像設置。"];
GHLSSLogLine("v43 card avatar picker failed");
}
}
// v42：PHPicker 回調（卡片頭像；delegate 不走 protocol 宣告——
// 運行時按 respondsToSelector 調，不用鏈 PhotosUI）。
// 選到的圖居中裁方形 512、存設定目錄固定檔名、寫鍵、重建卡片。
- (void)picker:(id)picker didFinishPicking:(NSArray *)results {
[picker dismissViewControllerAnimated:YES completion:nil];
if (!results || [results count] == 0) return;
id result = [results objectAtIndex:0];
id provider = [result itemProvider];
if (!provider) return;
[provider loadObjectOfClass:[UIImage class] completionHandler:^(id object, NSError *error) {
(void)error;
if (![object isKindOfClass:[UIImage class]]) return;
UIImage *picked = (UIImage *)object;
dispatch_async(dispatch_get_main_queue(), ^{
UIImage *square = GHLSSSquareCropImage(picked, 512.0);
if (!square) return;
NSString *path = GHLSSCardImagePath(YES);
NSData *data = UIImageJPEGRepresentation(square, 0.85);
BOOL ok = data && [data writeToFile:path atomically:YES];
if (ok) {
GHLSSWritePrefsBool("cardAvatarCustom", YES);
[self rebuildSettingsCard];
GHLSSLogLine("v43 card avatar picked from card");
} else {
[self showSettingsCardAlert:"保存頭像失敗" message:"圖片寫不進設定目錄，請去系統設定裡換。"];
}
});
}];
}
// v42：卡片日誌頁——讀尾段（預設最後 200 行）、最新在最上面。
- (void)refreshSettingsCardLogView {
NSString *logPath = [NSString stringWithCString:GHLSS_LOG_PATH encoding:NSUTF8StringEncoding];
NSString *content = [NSString stringWithContentsOfFile:logPath encoding:NSUTF8StringEncoding error:nil];
if (!content) content = [NSString stringWithCString:"還沒有日誌（檔案不存在或讀不到）。" encoding:NSUTF8StringEncoding];
NSString *sep = [NSString stringWithCString:"\n" encoding:NSUTF8StringEncoding];
NSArray *lines = [content componentsSeparatedByString:sep];
NSMutableArray *last = [NSMutableArray array];
NSInteger start = (NSInteger)[lines count] - 200;
if (start < 0) start = 0;
for (NSInteger i = (NSInteger)[lines count] - 1; i >= start; i--) {
[last addObject:[lines objectAtIndex:i]];
}
NSString *shown = [last componentsJoinedByString:sep];
if (GHLSSSettingsCardLogView) GHLSSSettingsCardLogView.text = shown;
}
- (void)handleSettingsCardLogRefresh:(id)sender {
(void)sender;
[self refreshSettingsCardLogView];
GHLSSLogLine("v43 card log refreshed");
}
- (void)handleSettingsCardLogClear:(id)sender {
(void)sender;
NSString *logPath = [NSString stringWithCString:GHLSS_LOG_PATH encoding:NSUTF8StringEncoding];
NSError *err = nil;
BOOL ok = [[NSData data] writeToFile:logPath options:NSDataWritingAtomic error:&err];
if (ok) {
[self refreshSettingsCardLogView];
[self showSettingsCardAlert:"日誌已清空" message:"日誌檔案已截斷，新的日誌會繼續寫進來。"];
} else {
[self showSettingsCardAlert:"清空失敗" message:"日誌檔案寫不動（權限問題），請用 Filza 手動清。"];
}
GHLSSLogLine(ok ? "v43 card log cleared" : "v43 card log clear failed");
}
- (void)handleSettingsCardLogShare:(id)sender {
(void)sender;
NSString *logPath = [NSString stringWithCString:GHLSS_LOG_PATH encoding:NSUTF8StringEncoding];
NSURL *url = [NSURL fileURLWithPath:logPath];
if (!url) return;
UIActivityViewController *share = [[UIActivityViewController alloc] initWithActivityItems:[NSArray arrayWithObject:url] applicationActivities:nil];
UIViewController *vc = GHLSSSettingsCardWindow.rootViewController;
[vc presentViewController:share animated:YES completion:nil];
}

// 拖右下角手柄改窗大小：拖动时只改窗与视图（live）；
// 松手时才调 scene 的 frame（V5_DESIGN.md §2.2：改尺寸防抖，
// 拖动时不要每次移动都调一次）。
- (void)handleResizeDrag:(UIPanGestureRecognizer *)recognizer {
// v40：多窗——先切活动量到缩放手柄所在的窗（不切的话改的是活动窗，
// 可能是别的窗的尺寸）。
UIWindow *resizeWindow = GHLSSWindowForView(recognizer.view);
if (resizeWindow) {
GHLSSSetActiveToWindow(resizeWindow);
}
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
// v38：没有标题栏了，内容区就是整个窗——拖动时只改窗与视图（live）；
// 松手时才调 scene 的 frame（V5_DESIGN.md §2.2：改尺寸防抖，
// 拖动时不要每次移动都调一次）。控制条 36pt、细条 16pt、滑杆条
// 在控制条下面（y=36），都跟着窗宽走。
GHLSSHostedWindow.frame = CGRectMake(frame.origin.x, frame.origin.y, newW, newH);
GHLSSHostedContainer.frame = CGRectMake(0, 0, newW, newH);
GHLSSHostedTitleBar.frame = CGRectMake(0, 0, newW, GHLSS_HOSTED_CONTROL_H);
GHLSSHostedTitleLabel.frame = CGRectMake(78, 0, newW - 156, GHLSS_HOSTED_CONTROL_H);
if (GHLSSHostedTopStrip) GHLSSHostedTopStrip.frame = CGRectMake(0, 0, newW, GHLSS_HOSTED_STRIP_H);
GHLSSHostedContentView.frame = CGRectMake(0, 0, newW, newH);
// v38：缩放按钮与滑杆条跟着窗宽走（按钮在控制条右边，滑杆条在控制条下面）。
if (GHLSSHostedScaleButton) GHLSSHostedScaleButton.frame = CGRectMake(newW - 36, 5, 26, 26);
if (GHLSSHostedScaleSliderBar) GHLSSHostedScaleSliderBar.frame = CGRectMake(0, GHLSS_HOSTED_CONTROL_H, newW, 36);
if (GHLSSHostedScaleSlider) GHLSSHostedScaleSlider.frame = CGRectMake(10, 3, newW - 70, 30);
if (GHLSSHostedScaleLabel) GHLSSHostedScaleLabel.frame = CGRectMake(newW - 56, 3, 46, 30);
if (recognizer.state == UIGestureRecognizerStateEnded) {
char rbuf[128];
snprintf(rbuf, sizeof(rbuf), "v43 window resized to %dx%d", (int)newW, (int)newH);
GHLSSLogLine(rbuf);
[self resizeHostedSceneToContentSize:CGSizeMake(newW, newH)];
// v40：调尺寸结束存一次位置/大小/缩放（第 6 项）——下次开同一 App
// 恢复到这次的位置和大小。
if (GHLSSActiveAppIndex >= 0 && GHLSSActiveAppIndex < GHLSS_APP_COUNT) {
GHLSSSaveGeometryForIndex(GHLSSActiveAppIndex);
}
}
}

// 松手后把新内容尺寸告诉 scene（只在松手时调一次）。
- (void)resizeHostedSceneToContentSize:(CGSize)size {
if (!GHLSSHostedScene) return;
@try {
// v38：反向耦合（所有 App 都一样）——内容区已经是新尺寸了（
// handleResizeDrag 里改过），直接调同一条缩放路径：立即改
// presenterView 的 bounds + sublayerTransform，0.05 秒防抖后推
// 新 frame（= 新内容尺寸 ÷ scale）+ 重设安全区 insets（第 3 项）。
char buf[128];
snprintf(buf, sizeof(buf), "v43 scene resized %d,%d", (int)size.width, (int)size.height);
GHLSSLogLine(buf);
GHLSSApplyScaleToHostedWindow(YES);
} @catch (NSException *e) {
(void)e;
GHLSSLogLine("v43 scene resize failed");
}
}

- (void)handleCloseButton:(id)sender {
GHLSSLogLine("v43 close button tapped");
[self dismissLauncher];
}

- (void)handleBackgroundTap:(UITapGestureRecognizer *)recognizer {
GHLSSLogLine("v43 background tapped, dismissing launcher");
[self dismissLauncher];
}

- (void)showLauncher {
if (!GHLSSReadARCEnabled()) {
GHLSSLogLine("v43 launcher ignored, arc disabled");
return;
}
if (GHLSSLauncherVisible) {
GHLSSLogLine("v43 launcher already open");
return;
}
// v40：每次打开都重建（设定页的 App 开关、左右位置可能改了，重建
// 才能立刻生效；窗很轻（几个视图），重建不贵）。旧窗先放掉。
GHLSSLauncherWindow = nil;
[self buildLauncherWindow];
// v40：感应带跟小窗位置设定走（设定改了，下次开启动器时带子就跟到
// 对的边；哆啦A夢鈕一直在右邊，永遠能開啟動器）。
GHLSSUpdateStripPosition();
// 有悬浮窗在时，启动器要升到它上面（不然会被盖住一半）。v29：相对顺序不变，但最高只到 Alert - 1（锁屏之下）。
// v40：多窗——缓存里有任何悬浮窗（不只活动窗）就升到 Alert - 1。
if (GHLSSAnyCachedHostedWindow()) {
GHLSSLauncherWindow.windowLevel = UIWindowLevelAlert - 1.0;
} else {
GHLSSLauncherWindow.windowLevel = UIWindowLevelAlert - 3.0;
}
GHLSSLauncherWindow.hidden = NO;
GHLSSLauncherVisible = YES;
GHLSSLogLine("v43 launcher opened");
// v41：叫出 ARC 時給一下震動（ARC 設置的震動反饋開關，預設開）。
if (GHLSSReadARCHaptics()) {
@try {
UIImpactFeedbackGenerator *haptic = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
[haptic impactOccurred];
} @catch (NSException *e) {
(void)e;
}
}
}

- (void)dismissLauncher {
if (!GHLSSLauncherVisible) return;
GHLSSLauncherWindow.hidden = YES;
GHLSSLauncherVisible = NO;
GHLSSLogLine("v43 launcher dismissed");
}

// 建启动器窗（第一次打开时才建）：全屏透明窗 + 右侧 220pt 暗色面板。
// 面板与背景点按区是平级的两个子视图：点面板不会触发收起，
// 点面板以外（透明区）才收起。
// v41：ARC 圓形啟動器（取代 v40 的白底面板——皇上 12:29：不要白色相框，
// 要像 video 95 結尾那樣：圖標直接浮在變暗的當前 App 上）。全屏暗背景
//（黑 0.55，點背景收起）+ 頂上搜索框 + 右側一列圓形 App 圖標
//（分段：置頂／最近／全部 App）+ 常用三開 + 遊戲模式開關 + 「＋」
// 選 App + 下面 X 關掉。開著的 App 帶綠點（主窗金色），點一下升為主窗。
// 內容由 rebuildARCContent 重建（打開、搜索、置頂、選完 App 後都調）。
- (void)buildLauncherWindow {
CGRect screenBounds = [UIScreen mainScreen].bounds;
GHLSSLauncherWindow = [[UIWindow alloc] initWithFrame:screenBounds];
// v29：基准层级 Alert - 3（锁屏之下；有悬浮窗时见 showLauncher，会升到 Alert - 1）。
GHLSSLauncherWindow.windowLevel = UIWindowLevelAlert - 3.0;
GHLSSLauncherWindow.backgroundColor = [UIColor clearColor];
UIWindowScene *launcherScene = GHLSSActiveWindowScene();
if (launcherScene) {
GHLSSLauncherWindow.windowScene = launcherScene;
GHLSSLogLine("v43 launcher scene found");
} else {
GHLSSLogLine("v43 launcher scene nil");
}
UIViewController *launcherVC = [[UIViewController alloc] init];
UIView *rootView = [[UIView alloc] initWithFrame:screenBounds];
rootView.backgroundColor = [UIColor clearColor];
launcherVC.view = rootView;
// 暗背景（點它收起啟動器）。
UIView *bgView = [[UIView alloc] initWithFrame:screenBounds];
bgView.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.55];
UITapGestureRecognizer *bgTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleBackgroundTap:)];
[bgView addGestureRecognizer:bgTap];
[rootView addSubview:bgView];
// 搜索框（頂上；打字即篩已安裝 App，篩緩存清單，不重新列舉）。
// 點搜索框會彈出系統鍵盤（SpringBoard 上也能彈），按完成收起。
CGFloat scrollY = 24.0;
GHLSSLauncherSearchField = nil;
if (GHLSSReadARCSearchEnabled()) {
UITextField *searchField = [[UITextField alloc] initWithFrame:CGRectMake(16, 60, screenBounds.size.width - 32, 36)];
searchField.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.5];
searchField.layer.cornerRadius = 10.0;
searchField.textColor = [UIColor whiteColor];
searchField.font = [UIFont systemFontOfSize:15];
searchField.placeholder = [NSString stringWithCString:"搜索 App" encoding:NSUTF8StringEncoding];
searchField.clearButtonMode = UITextFieldViewModeWhileEditing;
searchField.returnKeyType = UIReturnKeyDone;
searchField.autocorrectionType = UITextAutocorrectionTypeNo;
[searchField addTarget:self action:@selector(handleARCSearchChanged:) forControlEvents:UIControlEventEditingChanged];
[searchField addTarget:self action:@selector(handleARCSearchDone:) forControlEvents:UIControlEventEditingDidEndOnExit];
[rootView addSubview:searchField];
GHLSSLauncherSearchField = searchField;
scrollY = 108.0;
}
GHLSSARCSearchText = [NSString string];
UIScrollView *scroll = [[UIScrollView alloc] initWithFrame:CGRectMake(0, scrollY, screenBounds.size.width, screenBounds.size.height - scrollY)];
scroll.backgroundColor = [UIColor clearColor];
[rootView addSubview:scroll];
GHLSSLauncherScrollView = scroll;
GHLSSLauncherWindow.rootViewController = launcherVC;
[self rebuildARCContent];
GHLSSLogLine("v43 launcher built");
}

// v41：ARC 內容重建（每次打開、搜索字變了、置頂變了、選完 App 後都調）：
// 沒有搜索字：常用三開 + 遊戲模式 + 三段（置頂／最近／全部 App，
// 像 App 資料庫那樣分段）+ 「＋」選 App + X 關掉；有搜索字：只顯示
// 篩過的已安裝 App（篩緩存清單，不重新列舉）。
- (void)rebuildARCContent {
if (!GHLSSLauncherScrollView) return;
for (UIView *sub in [GHLSSLauncherScrollView.subviews copy]) [sub removeFromSuperview];
CGRect screenBounds = [UIScreen mainScreen].bounds;
CGFloat screenW = screenBounds.size.width;
CGFloat iconSize = GHLSSReadARCIconSize();
CGFloat edgeDistance = GHLSSReadARCEdgeDistance();
BOOL columnLeft = GHLSSIsARCColumnLeft();
CGFloat colRight = columnLeft ? (edgeDistance + iconSize) : (screenW - edgeDistance);
CGFloat y = 8.0;
NSString *query = GHLSSARCSearchText;
BOOL searching = (query && [query length] > 0);
if (searching) {
// 搜索：篩緩存清單（名字或 bundleID 含關鍵字，不分大小寫），
// 上限走設定（searchResultLimit，預設 12）；沒加入啟動器的也列
// 出來（searchShowsNotInLauncher 開著時），點了先加入再打開。
y = [self addARCSectionLabel:"搜索結果" fromY:y iconSize:iconSize];
NSArray *installed = GHLSSCachedInstalledAppList();
NSMutableArray *matched = [NSMutableArray array];
NSString *bidKey = [NSString stringWithCString:"bundleID" encoding:NSUTF8StringEncoding];
NSString *nameKey = [NSString stringWithCString:"name" encoding:NSUTF8StringEncoding];
int limit = GHLSSReadSearchResultLimit();
for (id item in installed) {
if (![item isKindOfClass:[NSDictionary class]]) continue;
NSString *itemBid = [(NSDictionary *)item objectForKey:bidKey];
NSString *itemName = [(NSDictionary *)item objectForKey:nameKey];
if (!itemBid) continue;
BOOL hit = ([itemBid rangeOfString:query options:NSCaseInsensitiveSearch].location != NSNotFound);
if (!hit && itemName) hit = ([itemName rangeOfString:query options:NSCaseInsensitiveSearch].location != NSNotFound);
if (!hit) continue;
if (!GHLSSReadSearchShowsNotInLauncher() && !GHLSSIsAppInLauncher([itemBid UTF8String])) continue;
[matched addObject:itemBid];
if ((int)[matched count] >= limit) break;
}
GHLSSARCSearchResultCount = (int)[matched count];
y = [self addARCIconsForBids:matched fromY:y iconSize:iconSize tagBase:1000 action:@selector(handleARCSearchResultButton:) isSearchResult:YES];
if ([matched count] == 0) {
UILabel *empty = [[UILabel alloc] initWithFrame:CGRectMake(colRight - 200, y, 200, 20)];
empty.text = [NSString stringWithCString:"沒有找到" encoding:NSUTF8StringEncoding];
empty.textColor = [[UIColor whiteColor] colorWithAlphaComponent:0.7];
empty.font = [UIFont systemFontOfSize:13];
empty.textAlignment = NSTextAlignmentRight;
[GHLSSLauncherScrollView addSubview:empty];
y += 24.0;
}
} else {
// 常用三開：置頂的前三個（不夠就用最近的補，再不夠用啟動器順序補）。
UIButton *trioBtn = [UIButton buttonWithType:UIButtonTypeCustom];
trioBtn.frame = CGRectMake(colRight - 120, y, 120, 36);
trioBtn.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.5];
trioBtn.layer.cornerRadius = 18.0;
trioBtn.layer.borderWidth = 1.0;
trioBtn.layer.borderColor = [[UIColor whiteColor] colorWithAlphaComponent:0.3].CGColor;
[trioBtn setTitle:[NSString stringWithCString:"常用三開" encoding:NSUTF8StringEncoding] forState:UIControlStateNormal];
[trioBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
trioBtn.titleLabel.font = [UIFont boldSystemFontOfSize:15];
[trioBtn addTarget:self action:@selector(launchTrio) forControlEvents:UIControlEventTouchUpInside];
[GHLSSLauncherScrollView addSubview:trioBtn];
y += 40.0;
// v42：智能配對推薦（最近成對使用的記錄：常跟目前在看/最近開的 App
// 一起開的另一個 App；沒有記錄就不顯示這行；點一下成對開——
// 主 App 浮窗 + 另一個側窗或第二個浮窗）。
const char *pairContextBid = NULL;
if (GHLSSActiveAppIndex >= 0 && GHLSSActiveAppIndex < GHLSS_APP_COUNT && GHLSSCacheBundleIDs[GHLSSActiveAppIndex][0] != '\0') pairContextBid = GHLSSCacheBundleIDs[GHLSSActiveAppIndex];
if (!pairContextBid) {
NSArray *recentApps = GHLSSReadIDList("recentAppIDs");
if ([recentApps count] > 0 && [[recentApps objectAtIndex:0] isKindOfClass:[NSString class]]) {
pairContextBid = [[recentApps objectAtIndex:0] UTF8String];
}
}
if (pairContextBid) {
char *partner = GHLSSPairPartnerForBundleID(pairContextBid);
if (partner) {
char pairMainBid[128], pairOtherBid[128];
strncpy(pairMainBid, pairContextBid, sizeof(pairMainBid) - 1);
pairMainBid[sizeof(pairMainBid) - 1] = '\0';
strncpy(pairOtherBid, partner, sizeof(pairOtherBid) - 1);
pairOtherBid[sizeof(pairOtherBid) - 1] = '\0';
free(partner);
char mainName[128], otherName[128];
GHLSSAppNameForBundleID(pairMainBid, mainName, sizeof(mainName));
GHLSSAppNameForBundleID(pairOtherBid, otherName, sizeof(otherName));
strncpy(GHLSSARCPairMain, pairMainBid, sizeof(GHLSSARCPairMain) - 1);
GHLSSARCPairMain[sizeof(GHLSSARCPairMain) - 1] = '\0';
strncpy(GHLSSARCPairOther, pairOtherBid, sizeof(GHLSSARCPairOther) - 1);
GHLSSARCPairOther[sizeof(GHLSSARCPairOther) - 1] = '\0';
UIButton *pairBtn = [UIButton buttonWithType:UIButtonTypeCustom];
pairBtn.frame = CGRectMake(16, y, screenW - 32, 36);
pairBtn.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.5];
pairBtn.layer.cornerRadius = 18.0;
pairBtn.layer.borderWidth = 1.0;
pairBtn.layer.borderColor = [[UIColor colorWithRed:0.83 green:0.68 blue:0.21 alpha:0.6] CGColor];
char pairTitle[280];
snprintf(pairTitle, sizeof(pairTitle), "常跟 %s 一起開：%s", mainName, otherName);
[pairBtn setTitle:[NSString stringWithCString:pairTitle encoding:NSUTF8StringEncoding] forState:UIControlStateNormal];
[pairBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
pairBtn.titleLabel.font = [UIFont boldSystemFontOfSize:14];
[pairBtn addTarget:self action:@selector(handleARCPairButton:) forControlEvents:UIControlEventTouchUpInside];
[GHLSSLauncherScrollView addSubview:pairBtn];
y += 44.0;
GHLSSLogLine("v43 arc pair suggestion shown");
}
}
// 遊戲模式：浮窗釘在最上層（鎖屏之下允許的最高層級），再點關掉。
// 完整遊戲模式＋橫屏支援仍排在真分屏之後，這開關是第一步（見 §113）。
UILabel *gameLabel = [[UILabel alloc] initWithFrame:CGRectMake(colRight - 51 - 90, y + 5, 86, 20)];
gameLabel.text = [NSString stringWithCString:"遊戲模式" encoding:NSUTF8StringEncoding];
gameLabel.textColor = [UIColor whiteColor];
gameLabel.font = [UIFont systemFontOfSize:13];
gameLabel.textAlignment = NSTextAlignmentRight;
[GHLSSLauncherScrollView addSubview:gameLabel];
UISwitch *gameSwitch = [[UISwitch alloc] init];
gameSwitch.frame = CGRectMake(colRight - 51, y, 51, 31);
gameSwitch.on = GHLSSReadGameModeEnabled();
[gameSwitch addTarget:self action:@selector(handleGameModeSwitch:) forControlEvents:UIControlEventValueChanged];
[GHLSSLauncherScrollView addSubview:gameSwitch];
y += 39.0;
// v42：演示模式（ARC 與設定主頁同一份鍵 demoModeEnabled；開了藏
// 哆啦A夢鈕/貼邊小卡/任務欄/橫幅/ARC，角落留半透明小點點一下退出）。
UILabel *demoLabel = [[UILabel alloc] initWithFrame:CGRectMake(colRight - 51 - 90, y + 5, 86, 20)];
demoLabel.text = [NSString stringWithCString:"演示模式" encoding:NSUTF8StringEncoding];
demoLabel.textColor = [UIColor whiteColor];
demoLabel.font = [UIFont systemFontOfSize:13];
demoLabel.textAlignment = NSTextAlignmentRight;
[GHLSSLauncherScrollView addSubview:demoLabel];
UISwitch *demoSwitch = [[UISwitch alloc] init];
demoSwitch.frame = CGRectMake(colRight - 51, y, 51, 31);
demoSwitch.on = GHLSSReadDemoModeEnabled();
[demoSwitch addTarget:self action:@selector(handleDemoModeSwitch:) forControlEvents:UIControlEventValueChanged];
[GHLSSLauncherScrollView addSubview:demoSwitch];
y += 39.0;
// 三段：置頂 / 最近 / 全部（只顯示啟動器裡開著的 App；置頂的不在
// 最近裡重複，最近的不在全部裡重複）。
NSArray *pinned = GHLSSReadIDList("pinnedAppIDs");
NSArray *recent = GHLSSReadIDList("recentAppIDs");
NSMutableArray *pinnedInLauncher = [NSMutableArray array];
NSMutableArray *recentInLauncher = [NSMutableArray array];
NSMutableArray *allRest = [NSMutableArray array];
for (id item in pinned) {
if (![item isKindOfClass:[NSString class]]) continue;
const char *bid = [(NSString *)item UTF8String];
int idx = bid ? GHLSSAppIndexForBundleID(bid) : -1;
if (idx >= 0 && GHLSSIsAppEnabled(idx)) [pinnedInLauncher addObject:item];
}
for (id item in recent) {
if (![item isKindOfClass:[NSString class]]) continue;
const char *bid = [(NSString *)item UTF8String];
int idx = bid ? GHLSSAppIndexForBundleID(bid) : -1;
if (idx >= 0 && GHLSSIsAppEnabled(idx) && ![pinnedInLauncher containsObject:item]) [recentInLauncher addObject:item];
}
for (int i = 0; i < GHLSS_APP_COUNT; i++) {
if (GHLSSAppBundleIDs[i][0] == '\0' || !GHLSSIsAppEnabled(i)) continue;
NSString *bidStr = [NSString stringWithCString:GHLSSAppBundleIDs[i] encoding:NSUTF8StringEncoding];
if ([pinnedInLauncher containsObject:bidStr]) continue;
if ([recentInLauncher containsObject:bidStr]) continue;
[allRest addObject:bidStr];
}
if ([pinnedInLauncher count] > 0) {
y = [self addARCSectionLabel:"置頂" fromY:y iconSize:iconSize];
y = [self addARCIconsForBids:pinnedInLauncher fromY:y iconSize:iconSize tagBase:0 action:@selector(handleAppButton:) isSearchResult:NO];
}
if ([recentInLauncher count] > 0) {
y = [self addARCSectionLabel:"最近" fromY:y iconSize:iconSize];
y = [self addARCIconsForBids:recentInLauncher fromY:y iconSize:iconSize tagBase:0 action:@selector(handleAppButton:) isSearchResult:NO];
}
if ([allRest count] > 0) {
y = [self addARCSectionLabel:"全部 App" fromY:y iconSize:iconSize];
y = [self addARCIconsForBids:allRest fromY:y iconSize:iconSize tagBase:0 action:@selector(handleAppButton:) isSearchResult:NO];
}
}
// 「＋」加入 App（ARC 裡面選）與 X 關掉。
UIButton *plusBtn = [UIButton buttonWithType:UIButtonTypeCustom];
plusBtn.frame = CGRectMake(columnLeft ? edgeDistance : (screenW - edgeDistance - iconSize), y, iconSize, iconSize);
plusBtn.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.5];
plusBtn.layer.cornerRadius = iconSize * 0.5;
plusBtn.layer.borderWidth = 1.0;
plusBtn.layer.borderColor = [[UIColor whiteColor] colorWithAlphaComponent:0.4].CGColor;
[plusBtn setTitle:[NSString stringWithCString:"+" encoding:NSUTF8StringEncoding] forState:UIControlStateNormal];
[plusBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
plusBtn.titleLabel.font = [UIFont systemFontOfSize:28];
[plusBtn addTarget:self action:@selector(handleARCPickerButton:) forControlEvents:UIControlEventTouchUpInside];
[GHLSSLauncherScrollView addSubview:plusBtn];
if (GHLSSReadARCShowNames()) {
UILabel *plusLabel = [[UILabel alloc] initWithFrame:CGRectMake(plusBtn.frame.origin.x - 8, y + iconSize + 2, iconSize + 16, 14)];
plusLabel.text = [NSString stringWithCString:"加入 App" encoding:NSUTF8StringEncoding];
plusLabel.textColor = [UIColor whiteColor];
plusLabel.font = [UIFont systemFontOfSize:10];
plusLabel.textAlignment = NSTextAlignmentCenter;
[GHLSSLauncherScrollView addSubview:plusLabel];
}
y += iconSize + 22.0;
// v42：ARC 裡的「設置」入口（固定一項，點了開浮窗設定卡片；
// 哆啦A夢鈕長按保持關全部不變，不搶）。
UIButton *settingsBtn = [UIButton buttonWithType:UIButtonTypeCustom];
settingsBtn.frame = CGRectMake(columnLeft ? edgeDistance : (screenW - edgeDistance - iconSize), y, iconSize, iconSize);
settingsBtn.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.5];
settingsBtn.layer.cornerRadius = iconSize * 0.5;
settingsBtn.layer.borderWidth = 1.0;
settingsBtn.layer.borderColor = [[UIColor colorWithRed:0.83 green:0.68 blue:0.21 alpha:0.8] CGColor];
[settingsBtn setTitle:[NSString stringWithCString:"設置" encoding:NSUTF8StringEncoding] forState:UIControlStateNormal];
[settingsBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
settingsBtn.titleLabel.font = [UIFont boldSystemFontOfSize:13];
[settingsBtn addTarget:self action:@selector(handleARCSettingsButton:) forControlEvents:UIControlEventTouchUpInside];
[GHLSSLauncherScrollView addSubview:settingsBtn];
if (GHLSSReadARCShowNames()) {
UILabel *settingsLabel = [[UILabel alloc] initWithFrame:CGRectMake(settingsBtn.frame.origin.x - 8, y + iconSize + 2, iconSize + 16, 14)];
settingsLabel.text = [NSString stringWithCString:"設定卡片" encoding:NSUTF8StringEncoding];
settingsLabel.textColor = [UIColor whiteColor];
settingsLabel.font = [UIFont systemFontOfSize:10];
settingsLabel.textAlignment = NSTextAlignmentCenter;
[GHLSSLauncherScrollView addSubview:settingsLabel];
}
y += iconSize + 22.0;
UIButton *xBtn = [UIButton buttonWithType:UIButtonTypeCustom];
xBtn.frame = CGRectMake(columnLeft ? edgeDistance : (screenW - edgeDistance - iconSize), y, iconSize, iconSize);
xBtn.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.5];
xBtn.layer.cornerRadius = iconSize * 0.5;
xBtn.layer.borderWidth = 1.0;
xBtn.layer.borderColor = [[UIColor whiteColor] colorWithAlphaComponent:0.4].CGColor;
[xBtn setTitle:[NSString stringWithCString:"×" encoding:NSUTF8StringEncoding] forState:UIControlStateNormal];
[xBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
xBtn.titleLabel.font = [UIFont systemFontOfSize:28];
[xBtn addTarget:self action:@selector(handleCloseButton:) forControlEvents:UIControlEventTouchUpInside];
[GHLSSLauncherScrollView addSubview:xBtn];
if (GHLSSReadARCShowNames()) {
UILabel *xLabel = [[UILabel alloc] initWithFrame:CGRectMake(xBtn.frame.origin.x - 8, y + iconSize + 2, iconSize + 16, 14)];
xLabel.text = [NSString stringWithCString:"關閉" encoding:NSUTF8StringEncoding];
xLabel.textColor = [UIColor whiteColor];
xLabel.font = [UIFont systemFontOfSize:10];
xLabel.textAlignment = NSTextAlignmentCenter;
[GHLSSLauncherScrollView addSubview:xLabel];
}
y += iconSize + 22.0;
GHLSSLauncherScrollView.contentSize = CGSizeMake(screenW, y + 8);
}

// v41：ARC 裡一段的標題（置頂／最近／全部 App／搜索結果），
// 跟圖標列同一側對齊。
- (CGFloat)addARCSectionLabel:(const char *)title fromY:(CGFloat)y iconSize:(CGFloat)size {
CGFloat screenW = [UIScreen mainScreen].bounds.size.width;
CGFloat edgeDistance = GHLSSReadARCEdgeDistance();
BOOL columnLeft = GHLSSIsARCColumnLeft();
CGFloat colX = columnLeft ? edgeDistance : (screenW - edgeDistance - size);
UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(colX - 8, y, size + 16, 18)];
label.text = [NSString stringWithCString:title encoding:NSUTF8StringEncoding];
label.textColor = [[UIColor whiteColor] colorWithAlphaComponent:0.9];
label.font = [UIFont boldSystemFontOfSize:13];
label.textAlignment = columnLeft ? NSTextAlignmentLeft : NSTextAlignmentRight;
[GHLSSLauncherScrollView addSubview:label];
return y + 22.0;
}

// v41：ARC 裡一列圖標（bids 是 bundleID 字串的陣列；搜索結果用
// tagBase 1000 + 第幾筆，點了走 handleARCSearchResultButton:；
// 啟動器裡的 App 用槽位下標當 tag，點了走 handleAppButton:）。
- (CGFloat)addARCIconsForBids:(NSArray *)bids fromY:(CGFloat)y iconSize:(CGFloat)size tagBase:(NSInteger)tagBase action:(SEL)action isSearchResult:(BOOL)isSearchResult {
if (!bids || [bids count] == 0) return y;
CGFloat pitch = size + 22.0;
for (NSInteger k = 0; k < (NSInteger)[bids count]; k++) {
id item = [bids objectAtIndex:k];
if (![item isKindOfClass:[NSString class]]) continue;
const char *bid = [(NSString *)item UTF8String];
if (!bid || bid[0] == '\0') continue;
char name[128];
GHLSSAppNameForBundleID(bid, name, sizeof(name));
NSInteger tag;
if (isSearchResult) {
tag = tagBase + k;
if (tag >= 1000 + 64) continue;
strncpy(GHLSSARCSearchResults[tag - 1000], bid, sizeof(GHLSSARCSearchResults[0]) - 1);
GHLSSARCSearchResults[tag - 1000][sizeof(GHLSSARCSearchResults[0]) - 1] = '\0';
} else {
tag = GHLSSAppIndexForBundleID(bid);
if (tag < 0) continue;
}
UIButton *btn = [self arcIconButtonForBundleID:bid name:name tag:tag action:action atY:y size:size isSearchResult:isSearchResult];
[GHLSSLauncherScrollView addSubview:btn];
y += pitch;
}
return y;
}

// v41：ARC 裡一顆圓形 App 圖標（icon + 名 + 狀態點）：開著的 App 帶
// 綠點（主窗金色），點一下升為主窗；搜索結果裡還沒加入啟動器的帶
// 小「＋」；置頂的帶 ★；長按圖標置頂/取消置頂（只在啟動器段裡）。
- (UIButton *)arcIconButtonForBundleID:(const char *)bid name:(const char *)name tag:(NSInteger)tag action:(SEL)action atY:(CGFloat)y size:(CGFloat)size isSearchResult:(BOOL)isSearchResult {
CGFloat screenW = [UIScreen mainScreen].bounds.size.width;
CGFloat edgeDistance = GHLSSReadARCEdgeDistance();
BOOL columnLeft = GHLSSIsARCColumnLeft();
CGFloat colX = columnLeft ? edgeDistance : (screenW - edgeDistance - size);
UIButton *btn = [UIButton buttonWithType:UIButtonTypeCustom];
btn.frame = CGRectMake(colX, y, size, size);
btn.tag = tag;
[btn addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
UIImage *icon = GHLSSAppIcon(bid);
UIImageView *iconView = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, size, size)];
if (icon) {
iconView.image = icon;
} else {
iconView.backgroundColor = [UIColor grayColor];
}
iconView.layer.cornerRadius = size * 0.22;
iconView.layer.masksToBounds = YES;
[btn addSubview:iconView];
int slotIdx = (bid) ? GHLSSAppIndexForBundleID(bid) : -1;
BOOL inLauncher = (slotIdx >= 0 && GHLSSIsAppEnabled(slotIdx));
BOOL isOpen = (slotIdx >= 0 && GHLSSCacheWindows[slotIdx] && !GHLSSCacheWindows[slotIdx].hidden);
if (GHLSSReadARCShowOpenDots() && isOpen) {
UIView *dot = [[UIView alloc] initWithFrame:CGRectMake(size - 12, 0, 12, 12)];
BOOL isMain = (slotIdx == GHLSSActiveAppIndex);
dot.backgroundColor = isMain ? [UIColor colorWithRed:0.83 green:0.68 blue:0.21 alpha:1.0] : [UIColor colorWithRed:0.2 green:0.8 blue:0.2 alpha:1.0];
dot.layer.cornerRadius = 6.0;
dot.layer.borderWidth = 1.5;
dot.layer.borderColor = [UIColor whiteColor].CGColor;
[btn addSubview:dot];
} else if (isSearchResult && !inLauncher) {
UILabel *plus = [[UILabel alloc] initWithFrame:CGRectMake(size - 16, -4, 18, 18)];
plus.text = [NSString stringWithCString:"+" encoding:NSUTF8StringEncoding];
plus.textColor = [UIColor whiteColor];
plus.backgroundColor = [UIColor colorWithRed:0.2 green:0.8 blue:0.2 alpha:1.0];
plus.layer.cornerRadius = 9.0;
plus.layer.masksToBounds = YES;
plus.font = [UIFont boldSystemFontOfSize:12];
plus.textAlignment = NSTextAlignmentCenter;
[btn addSubview:plus];
}
if (!isSearchResult && GHLSSIsAppPinned(bid)) {
UILabel *pin = [[UILabel alloc] initWithFrame:CGRectMake(-4, -4, 16, 16)];
pin.text = [NSString stringWithCString:"★" encoding:NSUTF8StringEncoding];
pin.textColor = [UIColor colorWithRed:1.0 green:0.85 blue:0.0 alpha:1.0];
pin.font = [UIFont boldSystemFontOfSize:12];
[btn addSubview:pin];
}
if (GHLSSReadARCShowNames() && name && name[0] != '\0') {
UILabel *nameLabel = [[UILabel alloc] initWithFrame:CGRectMake(-8, size + 2, size + 16, 14)];
nameLabel.text = [NSString stringWithCString:name encoding:NSUTF8StringEncoding];
nameLabel.textColor = [UIColor whiteColor];
nameLabel.font = [UIFont systemFontOfSize:10];
nameLabel.textAlignment = NSTextAlignmentCenter;
[btn addSubview:nameLabel];
}
if (!isSearchResult) {
UILongPressGestureRecognizer *lp = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(handleARCIconLongPress:)];
lp.minimumPressDuration = 0.5;
[btn addGestureRecognizer:lp];
}
return btn;
}

// v41：啟動器段的圖標（槽位下標當 tag，點了走 handleAppButton:）。
- (UIButton *)arcIconButtonForIndex:(int)idx atY:(CGFloat)y size:(CGFloat)size {
return [self arcIconButtonForBundleID:GHLSSAppBundleIDs[idx] name:GHLSSAppNames[idx] tag:idx action:@selector(handleAppButton:) atY:y size:size isSearchResult:NO];
}

// v41：搜索框打字——即時篩（改字串、重建內容；篩緩存清單，
// 不重新列舉）。
- (void)handleARCSearchChanged:(UITextField *)textField {
NSString *text = textField.text;
GHLSSARCSearchText = text ? [text copy] : [NSString string];
[self rebuildARCContent];
}

// v41：搜索框按完成——收起鍵盤。
- (void)handleARCSearchDone:(UITextField *)textField {
[textField resignFirstResponder];
}

// v41：點搜索結果——還沒加入啟動器的先加入（沒空槽位就記日誌、
// 不開），再走 handleAppButton 同一條路（已開著升主窗、收著恢復、
// 沒開的開新窗）。
- (void)handleARCSearchResultButton:(UIButton *)sender {
NSInteger resultIdx = sender.tag - 1000;
if (resultIdx < 0 || resultIdx >= GHLSSARCSearchResultCount) return;
const char *bid = GHLSSARCSearchResults[resultIdx];
char name[128];
GHLSSAppNameForBundleID(bid, name, sizeof(name));
int slotIdx = GHLSSAppIndexForBundleID(bid);
if (slotIdx < 0 || !GHLSSIsAppEnabled(slotIdx)) {
if (!GHLSSSetAppInLauncher(bid, YES)) {
GHLSSLogLine("v43 search result add failed, launcher full");
return;
}
GHLSSLogLine("v43 search result added to launcher");
slotIdx = GHLSSAppIndexForBundleID(bid);
}
if (slotIdx < 0) return;
sender.tag = slotIdx;
[self handleAppButton:sender];
}

// v41：長按 ARC 圖標——置頂/取消置頂（置頂的固定在最上面一段，
// 存 prefs 鍵 pinnedAppIDs；震動一下回饋；重建內容即時生效）。
- (void)handleARCIconLongPress:(UILongPressGestureRecognizer *)recognizer {
if (recognizer.state != UIGestureRecognizerStateBegan) return;
UIButton *btn = (UIButton *)recognizer.view;
if (!btn) return;
NSInteger idx = btn.tag;
if (idx < 0 || idx >= GHLSS_APP_COUNT) return;
const char *bid = GHLSSAppBundleIDs[idx];
BOOL pinned = !GHLSSIsAppPinned(bid);
GHLSSSetAppPinned(bid, pinned);
if (GHLSSReadARCHaptics()) {
@try {
UIImpactFeedbackGenerator *haptic = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
[haptic impactOccurred];
} @catch (NSException *e) {
(void)e;
}
}
[self rebuildARCContent];
}

// v41：遊戲模式開關（ARC 裡 + 設定頁同一份鍵 gameModeEnabled）：
// 開著時浮窗釘在鎖屏之下允許的最高層級（Alert - 0.5，底窗；
// 主窗 Alert - 0.25），蓋過啟動器與其他 App；關掉回 1998/1998.25。
// 完整遊戲模式＋橫屏支援仍排在真分屏之後，這開關是第一步。
- (void)handleGameModeSwitch:(UISwitch *)sender {
GHLSSWritePrefsBool("gameModeEnabled", sender.on);
GHLSSApplyGameModeLevels();
if (GHLSSReadARCHaptics()) {
@try {
UIImpactFeedbackGenerator *haptic = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
[haptic impactOccurred];
} @catch (NSException *e) {
(void)e;
}
}
}

// v41：常用三開——置頂的前三個（不夠就用最近的補，再不夠用啟動器
// 順序補），一次最多三個，順序開（中間等上一個建完，見 launchTrioStep）。
- (void)launchTrio {
GHLSSPendingTrioCount = 0;
GHLSSPendingTrioNext = 0;
GHLSSPendingTrioRetries = 0;
NSArray *pinned = GHLSSReadIDList("pinnedAppIDs");
NSArray *recent = GHLSSReadIDList("recentAppIDs");
NSMutableArray *chosen = [NSMutableArray array];
for (id item in pinned) {
if ([chosen count] >= 3) break;
if (![item isKindOfClass:[NSString class]]) continue;
const char *bid = [(NSString *)item UTF8String];
int idx = bid ? GHLSSAppIndexForBundleID(bid) : -1;
if (idx >= 0 && GHLSSIsAppEnabled(idx) && ![chosen containsObject:item]) [chosen addObject:item];
}
for (id item in recent) {
if ([chosen count] >= 3) break;
if (![item isKindOfClass:[NSString class]]) continue;
const char *bid = [(NSString *)item UTF8String];
int idx = bid ? GHLSSAppIndexForBundleID(bid) : -1;
if (idx >= 0 && GHLSSIsAppEnabled(idx) && ![chosen containsObject:item]) [chosen addObject:item];
}
for (int i = 0; i < GHLSS_APP_COUNT && [chosen count] < 3; i++) {
if (GHLSSAppBundleIDs[i][0] == '\0' || !GHLSSIsAppEnabled(i)) continue;
NSString *bidStr = [NSString stringWithCString:GHLSSAppBundleIDs[i] encoding:NSUTF8StringEncoding];
if (![chosen containsObject:bidStr]) [chosen addObject:bidStr];
}
for (id item in chosen) {
const char *bid = [(NSString *)item UTF8String];
strncpy(GHLSSPendingTrio[GHLSSPendingTrioCount], bid, sizeof(GHLSSPendingTrio[0]) - 1);
GHLSSPendingTrio[GHLSSPendingTrioCount][sizeof(GHLSSPendingTrio[0]) - 1] = '\0';
GHLSSPendingTrioCount++;
}
if (GHLSSPendingTrioCount == 0) {
GHLSSLogLine("v43 trio nothing to open");
return;
}
char buf[256];
snprintf(buf, sizeof(buf), "v43 trio launch %d apps", GHLSSPendingTrioCount);
GHLSSLogLine(buf);
[self dismissLauncher];
[self launchTrioStep];
}

// v41：常用三開的下一步——上一個還在建（GHLSSHostedLaunching），
// 0.8 秒後再試（最多 12 次，超了跳過這一個）；建完了 1.0 秒後開下一個。
- (void)launchTrioStep {
if (GHLSSPendingTrioNext >= GHLSSPendingTrioCount) {
GHLSSLogLine("v43 trio done");
return;
}
if (GHLSSHostedLaunching) {
if (GHLSSPendingTrioRetries >= 12) {
GHLSSLogLine("v43 trio launch timed out, skipping one");
GHLSSPendingTrioNext++;
GHLSSPendingTrioRetries = 0;
} else {
GHLSSPendingTrioRetries++;
}
dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.8 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
[self launchTrioStep];
});
return;
}
GHLSSPendingTrioRetries = 0;
const char *bid = GHLSSPendingTrio[GHLSSPendingTrioNext];
char name[128];
GHLSSAppNameForBundleID(bid, name, sizeof(name));
int idx = GHLSSAppIndexForBundleID(bid);
if (idx >= 0 && GHLSSCacheWindows[idx] && !GHLSSCacheMinimized[idx] && !GHLSSCacheWindows[idx].hidden) {
GHLSSLogLine("v43 trio app already open, skipping");
} else {
[self launchHostedApp:bid name:name];
}
GHLSSPendingTrioNext++;
dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
[self launchTrioStep];
});
}

// v41：通知橫幅——新窗建好時短暫顯示「已打開 <App>」（浮窗設置 →
// 通知橫幅設置；開關關了不顯示，時長走設定，預設 1.5 秒自動藏）。
// v42：原來的「已打開 X」橫幅改走共用的文字版（同一個橫幅窗）。
- (void)showNotificationBannerForName:(const char *)name {
if (!name) name = "";
char text[192];
snprintf(text, sizeof(text), "已打開 %s", name);
[self showNotificationBannerWithText:text];
char buf[192];
snprintf(buf, sizeof(buf), "v43 notification banner %s", name);
GHLSSLogLine(buf);
}

// v41：截圖/錄屏狀態變了（ARC 設置的截圖錄屏隱藏 ARC，預設開）：
// 錄屏開始時把 ARC 藏起來，錄完不自動叫回來。截圖的通知在截圖完成
// 後才發，藏了也來不及進那一張——截圖隱藏做不到（見 BUILD_LOG
// §113），只做到錄屏隱藏。哆啦A夢鈕不藏（FV 的 ARC 鈕也一樣在圖裡）。
- (void)handleScreenCaptureChanged:(NSNotification *)note {
(void)note;
BOOL captured = [UIScreen mainScreen].isCaptured;
char buf[64];
snprintf(buf, sizeof(buf), "v43 screen capture changed %d", captured ? 1 : 0);
GHLSSLogLine(buf);
if (captured && GHLSSReadARCHideOnScreenshot() && GHLSSLauncherVisible) {
[self dismissLauncher];
GHLSSLogLine("v43 arc hidden for screen capture");
}
}

// v41：拖三屏分隔線——調側窗寬度（100..屏寬×0.5；右側窗往左拖變寬、
// 左側窗往右拖變寬）。拖動時只改窗與視圖（live）；松手時才調 scene
// 的 frame（跟右下角手柄同一條路）+ 存一次位置/大小。
- (void)handleSideDividerDrag:(UIPanGestureRecognizer *)recognizer {
UIWindow *divWindow = GHLSSWindowForView(recognizer.view);
if (!divWindow) divWindow = GHLSSHostedWindow;
if (!divWindow) return;
GHLSSSetActiveToWindow(divWindow);
if (!GHLSSHostedIsSideDock) return;
if (recognizer.state == UIGestureRecognizerStateBegan) {
GHLSSDividerDragDisabled = !GHLSSReadSideWindowGestures();
if (GHLSSDividerDragDisabled) {
GHLSSLogLine("v43 divider drag disabled");
return;
}
GHLSSLogLine("v43 divider dragged");
}
if (GHLSSDividerDragDisabled) return;
CGPoint point = [recognizer translationInView:divWindow];
[recognizer setTranslation:CGPointZero inView:divWindow];
CGRect screenBounds = [UIScreen mainScreen].bounds;
CGRect frame = divWindow.frame;
BOOL dockLeft = GHLSSIsWindowPositionLeft();
CGFloat newW = frame.size.width + (dockLeft ? point.x : -point.x);
if (newW < 100.0) newW = 100.0;
if (newW > screenBounds.size.width * 0.5) newW = screenBounds.size.width * 0.5;
CGFloat newX = dockLeft ? 0 : (screenBounds.size.width - newW);
CGFloat newH = frame.size.height;
divWindow.frame = CGRectMake(newX, frame.origin.y, newW, newH);
if (GHLSSHostedContainer) GHLSSHostedContainer.frame = CGRectMake(0, 0, newW, newH);
if (GHLSSHostedContentView) GHLSSHostedContentView.frame = CGRectMake(0, 0, newW, newH);
if (GHLSSHostedTopStrip) GHLSSHostedTopStrip.frame = CGRectMake(0, 0, newW, GHLSS_HOSTED_STRIP_H);
if (GHLSSHostedTitleBar) GHLSSHostedTitleBar.frame = CGRectMake(0, 0, newW, GHLSS_HOSTED_CONTROL_H);
if (GHLSSHostedTitleLabel) GHLSSHostedTitleLabel.frame = CGRectMake(78, 0, newW - 190, GHLSS_HOSTED_CONTROL_H);
if (GHLSSHostedScaleButton) GHLSSHostedScaleButton.frame = CGRectMake(newW - 36, 5, 26, 26);
// v42：縮放條 72pt（含尺寸行）+ 透明度條跟著側窗寬度走；
// 釘選鈕（窄窗本來就沒有，這裡只在有鈕時移位）。
if (GHLSSHostedScaleSliderBar) GHLSSHostedScaleSliderBar.frame = CGRectMake(0, GHLSS_HOSTED_CONTROL_H, newW, 72);
if (GHLSSHostedScaleSlider) GHLSSHostedScaleSlider.frame = CGRectMake(10, 3, newW - 70, 30);
if (GHLSSHostedScaleLabel) GHLSSHostedScaleLabel.frame = CGRectMake(newW - 56, 3, 46, 30);
if (GHLSSHostedOpacitySliderBar) GHLSSHostedOpacitySliderBar.frame = CGRectMake(0, GHLSS_HOSTED_CONTROL_H + 72, newW, 36);
if (GHLSSHostedOpacitySlider) GHLSSHostedOpacitySlider.frame = CGRectMake(10, 3, newW - 70, 30);
if (GHLSSHostedOpacityLabel) GHLSSHostedOpacityLabel.frame = CGRectMake(newW - 56, 3, 46, 30);
if (GHLSSHostedPinButton) GHLSSHostedPinButton.frame = CGRectMake(newW - 70, 5, 26, 26);
if (GHLSSHostedSideDivider) {
CGFloat divThickness = GHLSSHostedSideDividerThickness;
CGFloat divX = dockLeft ? (newW - divThickness) : 0;
GHLSSHostedSideDivider.frame = CGRectMake(divX, 0, divThickness, newH);
}
if (recognizer.state == UIGestureRecognizerStateEnded) {
char rbuf[128];
snprintf(rbuf, sizeof(rbuf), "v43 divider resized side window to %dx%d", (int)newW, (int)newH);
GHLSSLogLine(rbuf);
[self resizeHostedSceneToContentSize:CGSizeMake(newW, newH)];
if (GHLSSActiveAppIndex >= 0 && GHLSSActiveAppIndex < GHLSS_APP_COUNT) {
GHLSSSaveGeometryForIndex(GHLSSActiveAppIndex);
}
}
}

// v41：ARC 裡的「＋」——開選 App 頁（已安裝 App 清單，當場勾選）。
- (void)handleARCPickerButton:(id)sender {
(void)sender;
[self showAppPicker];
}

// v41：選 App 頁（ARC 裡「＋」開的已安裝 App 清單；跟設定頁三屏設置
// 裡的選擇器同一份鍵、同一份清單，兩邊改了都同步）。每次打開都重建
// 清單（緩存可能更新了；開關狀態即時讀 prefs）。列舉在後台做、結果
// 寫緩存檔，這裡只讀緩存（見 GHLSSRefreshInstalledAppListInBackground）。
- (void)showAppPicker {
if (GHLSSAppPickerWindow && !GHLSSAppPickerWindow.hidden) {
GHLSSLogLine("v43 app picker already open");
return;
}
CGRect screenBounds = [UIScreen mainScreen].bounds;
if (!GHLSSAppPickerWindow) {
GHLSSAppPickerWindow = [[UIWindow alloc] initWithFrame:screenBounds];
GHLSSAppPickerWindow.windowLevel = UIWindowLevelAlert - 1.0;
GHLSSAppPickerWindow.backgroundColor = [UIColor clearColor];
UIWindowScene *pickerScene = GHLSSActiveWindowScene();
if (pickerScene) GHLSSAppPickerWindow.windowScene = pickerScene;
UIViewController *vc = [[UIViewController alloc] init];
UIView *root = [[UIView alloc] initWithFrame:screenBounds];
root.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.85];
vc.view = root;
UILabel *title = [[UILabel alloc] initWithFrame:CGRectMake(16, 44, screenBounds.size.width - 32, 30)];
title.text = [NSString stringWithCString:"選擇應用" encoding:NSUTF8StringEncoding];
title.textColor = [UIColor whiteColor];
title.font = [UIFont boldSystemFontOfSize:20];
[root addSubview:title];
UILabel *sub = [[UILabel alloc] initWithFrame:CGRectMake(16, 76, screenBounds.size.width - 32, 20)];
sub.text = [NSString stringWithCString:"開了就出現在啟動器裡（最多 12 個）" encoding:NSUTF8StringEncoding];
sub.textColor = [[UIColor whiteColor] colorWithAlphaComponent:0.7];
sub.font = [UIFont systemFontOfSize:13];
[root addSubview:sub];
UIScrollView *scroll = [[UIScrollView alloc] initWithFrame:CGRectMake(0, 104, screenBounds.size.width, screenBounds.size.height - 104 - 60)];
scroll.tag = 77;
[root addSubview:scroll];
UIButton *done = [UIButton buttonWithType:UIButtonTypeSystem];
done.frame = CGRectMake(0, screenBounds.size.height - 56, screenBounds.size.width, 44);
[done setTitle:[NSString stringWithCString:"完成" encoding:NSUTF8StringEncoding] forState:UIControlStateNormal];
[done setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
done.titleLabel.font = [UIFont boldSystemFontOfSize:17];
[done addTarget:self action:@selector(handleAppPickerDone:) forControlEvents:UIControlEventTouchUpInside];
[root addSubview:done];
GHLSSAppPickerWindow.rootViewController = vc;
}
UIScrollView *scroll = (UIScrollView *)[GHLSSAppPickerWindow.rootViewController.view viewWithTag:77];
for (UIView *sub in [scroll.subviews copy]) [sub removeFromSuperview];
NSArray *installed = GHLSSCachedInstalledAppList();
NSString *bidKey = [NSString stringWithCString:"bundleID" encoding:NSUTF8StringEncoding];
NSString *nameKey = [NSString stringWithCString:"name" encoding:NSUTF8StringEncoding];
CGFloat y = 0;
CGFloat rowH = 52.0;
GHLSSAppPickerCount = 0;
if (!installed || [installed count] == 0) {
UILabel *empty = [[UILabel alloc] initWithFrame:CGRectMake(16, 8, screenBounds.size.width - 32, 40)];
empty.text = [NSString stringWithCString:"還沒有已安裝 App 清單（後台列舉中，稍後再開）" encoding:NSUTF8StringEncoding];
empty.textColor = [[UIColor whiteColor] colorWithAlphaComponent:0.7];
empty.font = [UIFont systemFontOfSize:13];
empty.numberOfLines = 2;
[scroll addSubview:empty];
y = 48.0;
} else {
for (id item in installed) {
if (GHLSSAppPickerCount >= 256) break;
if (![item isKindOfClass:[NSDictionary class]]) continue;
NSString *itemBid = [(NSDictionary *)item objectForKey:bidKey];
NSString *itemName = [(NSDictionary *)item objectForKey:nameKey];
if (!itemBid || [itemBid length] == 0) continue;
const char *bid = [itemBid UTF8String];
strncpy(GHLSSAppPickerBids[GHLSSAppPickerCount], bid, sizeof(GHLSSAppPickerBids[0]) - 1);
GHLSSAppPickerBids[GHLSSAppPickerCount][sizeof(GHLSSAppPickerBids[0]) - 1] = '\0';
UIImage *icon = GHLSSAppIcon(bid);
UIImageView *iconView = [[UIImageView alloc] initWithFrame:CGRectMake(16, y + 8, 36, 36)];
if (icon) {
iconView.image = icon;
} else {
iconView.backgroundColor = [UIColor grayColor];
}
iconView.layer.cornerRadius = 8.0;
iconView.layer.masksToBounds = YES;
[scroll addSubview:iconView];
UILabel *nameLabel = [[UILabel alloc] initWithFrame:CGRectMake(60, y, screenBounds.size.width - 60 - 70, rowH)];
nameLabel.text = itemName ? itemName : itemBid;
nameLabel.textColor = [UIColor whiteColor];
nameLabel.font = [UIFont systemFontOfSize:15];
[scroll addSubview:nameLabel];
UISwitch *sw = [[UISwitch alloc] init];
sw.frame = CGRectMake(screenBounds.size.width - 16 - 51, y + 10, 51, 31);
sw.on = GHLSSIsAppInLauncher(bid);
sw.tag = GHLSSAppPickerCount;
[sw addTarget:self action:@selector(handleAppPickerToggle:) forControlEvents:UIControlEventValueChanged];
[scroll addSubview:sw];
y += rowH;
GHLSSAppPickerCount++;
}
}
scroll.contentSize = CGSizeMake(screenBounds.size.width, y);
GHLSSAppPickerWindow.hidden = NO;
char buf[128];
snprintf(buf, sizeof(buf), "v43 app picker opened %d apps", GHLSSAppPickerCount);
GHLSSLogLine(buf);
}

// v41：選 App 頁關掉（ARC 內容重建，剛勾的立刻生效）。
- (void)dismissAppPicker {
if (GHLSSAppPickerWindow) GHLSSAppPickerWindow.hidden = YES;
[self rebuildARCContent];
GHLSSLogLine("v43 app picker closed");
}

// v41：選 App 頁的完成鈕。
- (void)handleAppPickerDone:(id)sender {
(void)sender;
[self dismissAppPicker];
}

// v41：選 App 頁的開關——當場勾選，立刻生效、存 CFPreferences；
// 滿了（12 個槽位用完）開關彈回關。關掉的 App 如果正開著窗，
// 窗留著（只從啟動器拿掉，下次打不開而已）。
- (void)handleAppPickerToggle:(UISwitch *)sender {
NSInteger row = sender.tag;
if (row < 0 || row >= GHLSSAppPickerCount) return;
const char *bid = GHLSSAppPickerBids[row];
BOOL on = sender.on;
if (!GHLSSSetAppInLauncher(bid, on)) {
sender.on = NO;
GHLSSLogLine("v43 app picker full, switch reverted");
return;
}
[self rebuildARCContent];
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
// 3) 感应带上挂右边缘滑动手势；哆啦A夢鈕单独一个 56x56 的小窗
//    （右边缘、竖直居中，图从 prefs bundle 里读）。
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
snprintf(buf, sizeof(buf), "v43 deferred setup ran, switch=%s", state);
GHLSSLogLine("v43 deferred setup ran");
GHLSSLogLine(buf);
// v41：自選 App 槽位從 prefs 讀進來（ARC 第一次打開就看得到）；
// 已安裝 App 清單在後台列舉、寫緩存檔（不堵主線程），設定頁/ARC 只讀緩存。
GHLSSLoadCustomApps();
GHLSSRefreshInstalledAppListInBackground();
// 右边缘感应带：24pt 宽、全高、透明，层级在 SpringBoard 内容之上。
// v23 的修法：窗显式挂 windowScene（没挂 scene 的窗可能不显示，
// v22 的教训）；带子的视图给显式 frame（不用 plain init 的零 frame）。
CGRect screenBounds = [UIScreen mainScreen].bounds;
CGFloat stripWidth = 24.0;
CGRect stripFrame = CGRectMake(screenBounds.size.width - stripWidth, 0, stripWidth, screenBounds.size.height);
GHLSSStripWindow = [[UIWindow alloc] initWithFrame:stripFrame];
// v29：层级降到 Alert - 4——锁屏之下，但仍在状态栏（1000）与 App（0）之上，平时用不受影响。
GHLSSStripWindow.windowLevel = UIWindowLevelAlert - 4.0;
GHLSSStripWindow.backgroundColor = [UIColor clearColor];
UIWindowScene *stripScene = GHLSSActiveWindowScene();
if (stripScene) {
GHLSSStripWindow.windowScene = stripScene;
GHLSSLogLine("v43 window scene found");
} else {
GHLSSLogLine("v43 window scene nil");
}
UIViewController *stripVC = [[UIViewController alloc] init];
GHLSSPlainStripView *stripView = [[GHLSSPlainStripView alloc] initWithFrame:CGRectMake(0, 0, stripWidth, screenBounds.size.height)];
stripView.backgroundColor = [UIColor clearColor];
stripVC.view = stripView;
GHLSSStripWindow.rootViewController = stripVC;
GHLSSStripWindow.hidden = NO;
GHLSSLogLine("v43 edge strip built");
// 诊断日志：窗与带子到底是什么状态（真机一看就知道上没上屏）。
char dbuf[256];
CGRect wf = GHLSSStripWindow.frame;
snprintf(dbuf, sizeof(dbuf), "v43 window frame=%d,%d,%d,%d hidden=%d scene=%s", (int)wf.origin.x, (int)wf.origin.y, (int)wf.size.width, (int)wf.size.height, GHLSSStripWindow.hidden ? 1 : 0, GHLSSStripWindow.windowScene ? "ok" : "nil");
GHLSSLogLine(dbuf);
CGRect sf = stripView.frame;
snprintf(dbuf, sizeof(dbuf), "v43 strip frame=%d,%d,%d,%d", (int)sf.origin.x, (int)sf.origin.y, (int)sf.size.width, (int)sf.size.height);
GHLSSLogLine(dbuf);
// 5.1 的处理器（唯一的自定义处理类）。
GHLSSLauncherShared = [[GHLSSLauncher alloc] init];
// 右边缘滑动手势（挂在感应带上）。
UIScreenEdgePanGestureRecognizer *edgePan = [[UIScreenEdgePanGestureRecognizer alloc] initWithTarget:GHLSSLauncherShared action:@selector(handleEdgeSwipe:)];
edgePan.edges = UIRectEdgeRight;
edgePan.delegate = GHLSSLauncherShared;
[stripView addGestureRecognizer:edgePan];
GHLSSLauncherEdgePan = edgePan;
GHLSSLogLine("v43 edge gesture added");
// v40：感应带跟小窗位置设定走（初始位置按设定放；设定改了，下次开
// 启动器时 showLauncher 会再调 GHLSSUpdateStripPosition 跟到对的边）。
GHLSSUpdateStripPosition();
// v38：哆啦A夢鈕（皇上要金色「分」按钮改成可爱型哆啦A夢图，3D 大笑
// 版）。24pt 的感应带放不下 56pt 的圆钮（圆钮一半会伸出窗外、点
// 不到），所以哆啦A夢鈕单独一个小窗（右边缘、竖直居中、图从 prefs
// bundle 里读；读不到就退回金色圆钮 + 「分」字（不空白、不崩）。
// v41：大小走設定（doraemonIconSize，44–72，預設 56）；左右邊走設定
// （doraemonSide，沒設跟小窗位置）；高度從 prefs 恢復（上次拖到的
// 位置，沒拖過就居中）；層級 Alert - 1.25（1998.75，貼邊 peek 之上、
// ARC 之下——圖 1 裡鈕疊在最下面那張 peek 卡上）。
CGFloat doraemonSize = GHLSSReadDoraemonIconSize();
CGFloat doraemonX = GHLSSIsDoraemonSideLeft() ? 0 : (screenBounds.size.width - doraemonSize);
double savedDoraemonY = GHLSSReadDoraemonButtonY();
CGFloat doraemonCenterY = (savedDoraemonY >= 0) ? (CGFloat)savedDoraemonY : (screenBounds.size.height / 2.0);
if (doraemonCenterY < 100.0) doraemonCenterY = 100.0;
if (doraemonCenterY > screenBounds.size.height - 100.0) doraemonCenterY = screenBounds.size.height - 100.0;
CGRect doraemonFrame = CGRectMake(doraemonX, doraemonCenterY - doraemonSize / 2.0, doraemonSize, doraemonSize);
GHLSSDoraemonButtonWindow = [[UIWindow alloc] initWithFrame:doraemonFrame];
GHLSSDoraemonButtonWindow.windowLevel = UIWindowLevelAlert - 1.25;
GHLSSDoraemonButtonWindow.backgroundColor = [UIColor clearColor];
UIWindowScene *doraemonScene = GHLSSActiveWindowScene();
if (doraemonScene) {
GHLSSDoraemonButtonWindow.windowScene = doraemonScene;
} else {
GHLSSLogLine("v43 doraemon scene nil");
}
UIViewController *doraemonVC = [[UIViewController alloc] init];
UIView *doraemonRoot = [[UIView alloc] initWithFrame:CGRectMake(0, 0, doraemonSize, doraemonSize)];
doraemonRoot.backgroundColor = [UIColor clearColor];
doraemonVC.view = doraemonRoot;
GHLSSDoraemonButtonWindow.rootViewController = doraemonVC;
UIButton *doraemonButton = [UIButton buttonWithType:UIButtonTypeCustom];
doraemonButton.frame = CGRectMake(0, 0, doraemonSize, doraemonSize);
doraemonButton.layer.cornerRadius = doraemonSize / 2.0;
doraemonButton.layer.masksToBounds = YES;
UIImage *doraemonImage = nil;
@try {
NSString *resName = [NSString stringWithCString:"doraemon-button" encoding:NSUTF8StringEncoding];
NSString *resType = [NSString stringWithCString:"png" encoding:NSUTF8StringEncoding];
NSString *imagePath = nil;
// v39：先试 rootless 的 /var/jb/...（v38 只写 /Library/...，
// Dopamine 上 bundleWithPath 拿到 nil、图读不到、退回金色「分」）；
// 读不到再试 rootful 的 /Library/...，两个都试。
NSString *bundlePath = [NSString stringWithCString:"/var/jb/Library/PreferenceBundles/GuHaiLongSplitScreenPrefs.bundle" encoding:NSUTF8StringEncoding];
NSBundle *prefsBundle = bundlePath ? [NSBundle bundleWithPath:bundlePath] : nil;
if (prefsBundle && resName && resType) imagePath = [prefsBundle pathForResource:resName ofType:resType];
if (!imagePath) {
NSString *bundlePath2 = [NSString stringWithCString:"/Library/PreferenceBundles/GuHaiLongSplitScreenPrefs.bundle" encoding:NSUTF8StringEncoding];
NSBundle *prefsBundle2 = bundlePath2 ? [NSBundle bundleWithPath:bundlePath2] : nil;
if (prefsBundle2 && resName && resType) imagePath = [prefsBundle2 pathForResource:resName ofType:resType];
}
if (imagePath) doraemonImage = [UIImage imageWithContentsOfFile:imagePath];
} @catch (NSException *e) {
(void)e;
doraemonImage = nil;
}
if (doraemonImage && doraemonImage.CGImage) {
// imageWithContentsOfFile 读 @3x 文件时 scale 是 1.0（168pt，太大）；
// 按屏幕 scale 重包一层（168px ÷ 3 = 56pt），正好填满圆钮。
CGFloat screenScale = [UIScreen mainScreen].scale;
if (screenScale > 0) {
doraemonImage = [UIImage imageWithCGImage:doraemonImage.CGImage scale:screenScale orientation:doraemonImage.imageOrientation];
}
[doraemonButton setImage:doraemonImage forState:UIControlStateNormal];
GHLSSLogLine("v43 doraemon image loaded");
} else {
// 退回金色圆钮 + 「分」字（图读不到时不空白、不崩）。
doraemonButton.backgroundColor = [UIColor colorWithRed:0.83 green:0.68 blue:0.21 alpha:1.0];
doraemonButton.layer.borderWidth = 2.0;
doraemonButton.layer.borderColor = [UIColor blackColor].CGColor;
[doraemonButton setTitle:[NSString stringWithCString:"分" encoding:NSUTF8StringEncoding] forState:UIControlStateNormal];
[doraemonButton setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
doraemonButton.titleLabel.font = [UIFont boldSystemFontOfSize:14];
GHLSSLogLine("v43 doraemon image missing, fallback to gold");
}
// v41：單擊開 ARC、雙擊輪切主窗（代替原來的 TouchUpInside：單擊手勢
// 要等雙擊失敗才認，雙擊時不誤開 ARC；見 handleDoraemonButtonSingleTap /
// handleDoraemonButtonDoubleTap）。點按跟拖動分開：pan 有內建位移門檻
// （約 10pt），手指沒怎麼動、快速抬起時 pan 不認、單擊照舊開 ARC；
// 拖動了 pan 認出來（cancelsTouchesInView 預設 YES，會取消鈕的點按
// 追蹤），才算移動鈕的位置。
UITapGestureRecognizer *doraemonSingleTap = [[UITapGestureRecognizer alloc] initWithTarget:GHLSSLauncherShared action:@selector(handleDoraemonButtonSingleTap:)];
doraemonSingleTap.numberOfTapsRequired = 1;
doraemonSingleTap.delegate = GHLSSLauncherShared;
UITapGestureRecognizer *doraemonDoubleTap = [[UITapGestureRecognizer alloc] initWithTarget:GHLSSLauncherShared action:@selector(handleDoraemonButtonDoubleTap:)];
doraemonDoubleTap.numberOfTapsRequired = 2;
doraemonDoubleTap.delegate = GHLSSLauncherShared;
[doraemonSingleTap requireGestureRecognizerToFail:doraemonDoubleTap];
[doraemonButton addGestureRecognizer:doraemonSingleTap];
[doraemonButton addGestureRecognizer:doraemonDoubleTap];
UIPanGestureRecognizer *doraemonDrag = [[UIPanGestureRecognizer alloc] initWithTarget:GHLSSLauncherShared action:@selector(handleDoraemonButtonDrag:)];
doraemonDrag.minimumNumberOfTouches = 1;
doraemonDrag.maximumNumberOfTouches = 1;
doraemonDrag.delegate = GHLSSLauncherShared;
[doraemonButton addGestureRecognizer:doraemonDrag];
// v40：一键关全部浮窗（皇上 11:55 糾正「全加」）——长按哆啦A夢鈕
// 关掉全部已开的浮窗 + 已收起的 peek。长按与点按/拖动
// 分开：长按要手指基本不动（UILongPressGestureRecognizer 内建
// allowableMovement 约 10pt，拖动了它就不认）；短按（无拖动、无长按）
// 仍是开启动器；长按松手不触发启动器（长按旗标 suppress
// 单击，见 handleDoraemonButtonSingleTap）。
// v41：長按時間走調度設定（longPressDuration，0.3–1.0 秒，預設 0.5）。
UILongPressGestureRecognizer *doraemonLongPress = [[UILongPressGestureRecognizer alloc] initWithTarget:GHLSSLauncherShared action:@selector(handleDoraemonButtonLongPress:)];
doraemonLongPress.minimumPressDuration = GHLSSReadLongPressDuration();
doraemonLongPress.delegate = GHLSSLauncherShared;
[doraemonButton addGestureRecognizer:doraemonLongPress];
[doraemonRoot addSubview:doraemonButton];
GHLSSDoraemonButton = doraemonButton;
// v41：顯示走設定（doraemonVisible，預設開；關了鈕不顯示，ARC 只能邊緣滑動叫出）。
GHLSSDoraemonButtonWindow.hidden = !GHLSSReadDoraemonVisible();
GHLSSLogLine("v43 doraemon button added");
CGRect bf = doraemonButton.frame;
snprintf(dbuf, sizeof(dbuf), "v43 doraemon button frame=%d,%d,%d,%d", (int)bf.origin.x, (int)bf.origin.y, (int)bf.size.width, (int)bf.size.height);
GHLSSLogLine(dbuf);
// v41：錄屏開始時藏 ARC（NSNotificationCenter，不是被禁的
// CFNotificationCenterAddObserver；截圖藏不了——通知在截圖完成後才發，
// 見 §113）。
[[NSNotificationCenter defaultCenter] addObserver:GHLSSLauncherShared selector:@selector(handleScreenCaptureChanged:) name:UIScreenCapturedDidChangeNotification object:nil];
GHLSSLogLine("v43 screen capture observer added");
// v32：锁屏信号——libnotify 的 notify_register_dispatch（<notify.h>，
// 纯 C API，传 C 字串）。这不是被禁的 CFNotificationCenterAddObserver，
// 不碰 CFString，回调跑在主队列。v31 的做法（锁了且有 hosted scene
// 就把它推回后台）不够——皇上 16:00 复现：等 30 秒左右密码就按不
// 了了，键盘看得见、按了没反应；foreground-scene 理论被证伪。
// v32 只加一个变量：锁屏时把悬浮窗也临时藏起来（窗/presenter 锁屏
// 时可能还抓着触摸），解锁时再显示回来——只藏"开着"的窗，最小化
// 着的窗本来就藏着，不碰它；没窗时什么都不做。v39：解锁时也把
// foreground 推回去（v38 只显示窗、不推前景，恢复路径又只在最小化
// 时跑，锁屏藏窗的窗解锁后一直黑——见 BUILD_LOG §108；解锁时锁屏
// 已不在，推前景不影响密码）。v40：锁屏/解锁管全部窗（v39 只管活动
// 窗一个）——循环缓存数组，每窗都藏/显示、每窗的 scene 都推后台/
// 推前景；贴边小卡锁屏时不藏。handler 保持极小，只调后台化函数 +
// 藏窗/显示/推前景 + 记日志。
int lockToken = 0;
int lockNotifyResult = notify_register_dispatch("com.apple.springboard.lockstate", &lockToken, dispatch_get_main_queue(), ^(int token) {
uint64_t lockState = 0;
notify_get_state(token, &lockState);
if (lockState == 1) {
// v40：锁屏管全部窗（v39 只管活动窗一个）——每个缓存窗的 scene 都
// 推回后台；看得见的窗都藏起来（记 HiddenByLock，解锁时再显示回来）；
// 最小化着的窗本来就藏着，不碰它（解锁时它也不能自己弹出来，
// 等用户点恢复/点小卡）。贴边小卡锁屏时不藏（卡在右边缘、
// 不挡锁屏密码；解锁后还在，用户直接点卡恢复）。
BOOL anyScene = NO;
for (int i = 0; i < GHLSS_APP_COUNT; i++) {
if (GHLSSCacheScenes[i]) {
anyScene = YES;
GHLSSBackgroundCachedSceneAtIndex(i, "v43 scene backgrounded on lock");
}
if (GHLSSCacheWindows[i] && !GHLSSCacheMinimized[i] && !GHLSSCacheWindows[i].hidden) {
GHLSSCacheWindows[i].hidden = YES;
GHLSSCacheHiddenByLock[i] = YES;
if (i == GHLSSActiveAppIndex) GHLSSHostedHiddenByLock = YES;
char hbuf[128];
snprintf(hbuf, sizeof(hbuf), "v43 hosted window hidden on lock %s", GHLSSCacheBundleIDs[i]);
GHLSSLogLine(hbuf);
} else if (GHLSSCacheWindows[i]) {
GHLSSLogLine("v43 lock, window already minimized");
}
}
if (!anyScene) {
GHLSSLogLine("v43 lock state locked, no hosted scene");
}
GHLSSUpdateDimOverlay();
} else {
// v40：解锁管全部窗——锁屏时藏起来的窗都显示回来，每个都推前景
//（v39 只管活动窗一个；v38 只显示窗、不推前景，恢复路径又只在
// 最小化时跑，锁屏藏窗的窗解锁后一直黑——见 BUILD_LOG §108）。
// 最小化着的窗（HiddenByLock 是 NO）不碰，等用户点恢复/点小卡。
BOOL anyRestored = NO;
for (int i = 0; i < GHLSS_APP_COUNT; i++) {
if (GHLSSCacheHiddenByLock[i] && GHLSSCacheWindows[i]) {
GHLSSCacheWindows[i].hidden = NO;
GHLSSCacheHiddenByLock[i] = NO;
if (i == GHLSSActiveAppIndex) GHLSSHostedHiddenByLock = NO;
anyRestored = YES;
char hbuf[128];
snprintf(hbuf, sizeof(hbuf), "v43 hosted window shown on unlock %s", GHLSSCacheBundleIDs[i]);
GHLSSLogLine(hbuf);
char fbuf[160];
snprintf(fbuf, sizeof(fbuf), "v43 foreground pushed on unlock %s", GHLSSCacheBundleIDs[i]);
GHLSSPushForegroundCachedSceneAtIndex(i, fbuf);
}
}
if (!anyRestored) {
GHLSSLogLine("v43 lock state unlocked");
}
GHLSSUpdateDimOverlay();
}
});
if (lockNotifyResult == 0) {
GHLSSLogLine("v43 lockstate notify registered");
} else {
GHLSSLogLine("v43 lockstate notify register failed");
}
// v42：鍵盤監聽（NSNotificationCenter，不是被禁的
// CFNotificationCenterAddObserver；探針：鍵盤通知由 App 行程發，
// 可能到不了 SpringBoard——邏輯已寫好，收到了就上移、收起回原位）。
[[NSNotificationCenter defaultCenter] addObserver:GHLSSLauncherShared selector:@selector(handleKeyboardWillShow:) name:UIKeyboardWillShowNotification object:nil];
[[NSNotificationCenter defaultCenter] addObserver:GHLSSLauncherShared selector:@selector(handleKeyboardWillHide:) name:UIKeyboardWillHideNotification object:nil];
GHLSSLogLine("v43 keyboard observers added");
// v42：電量監控開（低電量自動收窗讀 batteryLevel 用）。
[[UIDevice currentDevice] setBatteryMonitoringEnabled:YES];
GHLSSLogLine("v43 battery monitoring enabled");
// v42：懸浮球、底部任務欄——開關開著就建（2 秒 tick 也會補建，
// 所以設定改了不用 respring）。
if (GHLSSReadFloatBallEnabled()) GHLSSBuildFloatBallIfNeeded();
if (GHLSSReadTaskbarEnabled()) GHLSSBuildTaskbarIfNeeded();
// v42：重啟後自動恢復浮窗（開關預設開）——scene 撐不過重啟，
// 恢復是重建 scene 重新開 App，不是接續舊 scene；
// 讀 restoreWindows 清單（"bundleID|x,y,w,h"），隔 0.6 秒一個輪流開
//（位置存在清單裡，開窗時 buildHostedWindow 會照恢復幾何放；
// 現在只開浮窗，不恢復 peek——peek 是收起態，重開意義不大）。
if (GHLSSReadRestoreWindowsAfterRespring()) {
NSArray *restoreList = GHLSSReadIDList("restoreWindows");
NSInteger restoreCount = (NSInteger)[restoreList count];
if (restoreCount > 0) {
char rbuf[128];
snprintf(rbuf, sizeof(rbuf), "v43 restore after respring %d windows", (int)restoreCount);
GHLSSLogLine(rbuf);
for (NSInteger ri = 0; ri < restoreCount; ri++) {
NSString *entry = [restoreList objectAtIndex:ri];
NSString *sep = [NSString stringWithCString:"|" encoding:NSUTF8StringEncoding];
NSArray *parts = [entry componentsSeparatedByString:sep];
if ([parts count] < 2) continue;
NSString *bid = [parts objectAtIndex:0];
double delay = 0.6 * (double)(ri + 1);
dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
char nameBuf[128];
GHLSSAppNameForBundleID([bid UTF8String], nameBuf, sizeof(nameBuf));
char nbuf[192];
snprintf(nbuf, sizeof(nbuf), "v43 restore launch %s", [bid UTF8String]);
GHLSSLogLine(nbuf);
[GHLSSLauncherShared launchHostedApp:[bid UTF8String] name:nameBuf];
});
}
}
}
// v42：2 秒定時 tick（演示模式/全屏藏鈕/任務欄/懸浮球/電量/配對）——
// 設定改了 2 秒內生效，不用 respring。
GHLSSSchedulePeriodicTick();
GHLSSLogLine("v43 periodic tick scheduled");
});
}
