// GuHaiLongSplitScreen v1.0.38 (v38) — 顾海龙集团原创分屏插件（实验版）
//
// 目标：iPhone 11 / iOS 16.5 / Dopamine (rootless)，iphoneos-arm64。
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
- (void)buildHostedWindowForBundleID:(const char *)bundleID name:(const char *)name scene:(FBScene *)scene presenter:(_UIScenePresenter *)presenter layerHostView:(UIView *)layerHostView sceneID:(NSString *)sceneID pid:(int)pid;
- (void)closeHostedWindow;
- (void)minimizeHostedWindow;
- (void)restoreHostedWindow;
- (void)handleHostedClose:(id)sender;
- (void)handleHostedMinimize:(id)sender;
- (void)handleScaleButton:(id)sender;
- (void)handleScaleSlider:(UISlider *)sender;
- (void)handleTitleDrag:(UIPanGestureRecognizer *)recognizer;
- (void)handleTopStripTap:(UITapGestureRecognizer *)recognizer;
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
// 销毁；切回来直接复用缓存里的 scene + presenter + 窗。一次只显示
// 一个窗：活动窗仍用原来那套静态量（GHLSSHostedWindow 等），所有现
// 成路径（关窗、最小化、恢复、锁屏回调、重试、拖动、缩放）都只认活
// 动量，原样不动；切换时把活动量存进缓存、再清活动量。
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
// 当前活动的是缓存里的第几个 App（-1 = 没有活动窗）。
static int GHLSSActiveAppIndex = -1;

// v38：默认 scaleRatio（下面定义；GHLSSLoadCacheToActive 要用，先声明）。
static CGFloat GHLSSDefaultScaleRatioForBundleID(const char *bundleID);

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
static void GHLSSDestroyCachedEntryAtIndex(int idx) {
if (idx < 0 || idx >= GHLSS_APP_COUNT) return;
if (!GHLSSCacheScenes[idx] && !GHLSSCacheWindows[idx]) return;
if (GHLSSCacheWindows[idx]) GHLSSCacheWindows[idx].hidden = YES;
// v38：layer-host 的项（有 layerHostView、没有 presenter）只清引用。
if (GHLSSCacheLayerHostViews[idx] && !GHLSSCachePresenters[idx]) {
GHLSSLogLine("v38 layer host entry cleared (scene kept)");
} else {
@try {
if (GHLSSCacheSceneIDs[idx]) {
char dbuf[256];
snprintf(dbuf, sizeof(dbuf), "v38 destroying scene %s", [GHLSSCacheSceneIDs[idx] UTF8String]);
GHLSSLogLine(dbuf);
[[FBSceneManager sharedInstance] destroyScene:GHLSSCacheSceneIDs[idx] withTransitionContext:nil];
}
if (GHLSSCachePresenters[idx]) {
[GHLSSCachePresenters[idx] deactivate];
[GHLSSCachePresenters[idx] invalidate];
}
} @catch (NSException *e) {
(void)e;
GHLSSLogLine("v38 destroy failed");
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
if (idx == GHLSSActiveAppIndex) {
GHLSSClearActive();
}
GHLSSLogLine("v38 scene destroyed");
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
GHLSSLogLine("v38 scene background failed");
}
}

// v38：悬浮窗的尺寸——没有标题栏了，内容区就是整个窗；圆角 35。
// 一般 App 内容 350x757（85% 宽，757 是按屏高宽比算的：350/414×
// 896≈757，和屏幕同宽高比——已有主 scene（414x896）按宽缩放正好
// 贴边填满；新建 scene 的 App 按 350x757 重排版）。计算器内容仍
// 是 320x693（窗 320x693，之前 320x737 是含 44pt 标题栏的总高，
// 内容几何不变、scale 仍是 0.77），宽用下面的 CALC_W。控制条
// 36pt（默认藏着）、顶条 16pt（透明细条）。
#define GHLSS_HOSTED_CONTENT_W 350.0
#define GHLSS_HOSTED_CONTENT_H 757.0
#define GHLSS_HOSTED_CALC_W 320.0
#define GHLSS_HOSTED_CONTROL_H 36.0
#define GHLSS_HOSTED_STRIP_H 16.0
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
// 做法），这样 sublayerTransform 从左上缩，不会居中漂移。
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
GHLSSHostedContentView.layer.sublayerTransform = CATransform3DMakeScale(displayScale, displayScale, 1.0);
char buf[128];
snprintf(buf, sizeof(buf), "v38 layer host scaled %d%%", (int)(displayScale * 100.0));
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
GHLSSHostedContentView.layer.sublayerTransform = CATransform3DMakeScale(scale, scale, 1.0);
char buf[128];
snprintf(buf, sizeof(buf), "v38 scene scaled %d%%", (int)(scale * 100.0));
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
snprintf(fbuf, sizeof(fbuf), "v38 scene frame updated %dx%d scale %d%%", (int)curFrameSize.width, (int)curFrameSize.height, (int)(curScale * 100.0));
GHLSSLogLine(fbuf);
} @catch (NSException *e) {
(void)e;
GHLSSLogLine("v38 scene frame update failed");
}
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
- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldReceiveTouch:(UITouch *)touch {
if ([touch.view isKindOfClass:[UIButton class]]) return NO;
return YES;
}

// 右边缘滑动：2 秒内滑两次才开启动器（防误触）；第一次只记日志。
- (void)handleEdgeSwipe:(UIScreenEdgePanGestureRecognizer *)recognizer {
if (recognizer.state != UIGestureRecognizerStateEnded) return;
double now = CFAbsoluteTimeGetCurrent();
if (now - GHLSSLastSwipeTime < 2.0) {
GHLSSLastSwipeTime = 0;
GHLSSLogLine("v38 edge swipe 2nd, opening launcher");
[self showLauncher];
} else {
GHLSSLastSwipeTime = now;
GHLSSLogLine("v38 edge swipe 1st, armed");
}
}

// 哆啦A夢鈕：点一次就开启动器（备用触发，不用滑两次）。
- (void)handleHandleButton:(id)sender {
GHLSSLogLine("v38 handle button tapped, opening launcher");
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
snprintf(buf, sizeof(buf), "v38 app tapped %s", bid);
GHLSSLogLine(buf);
// 一个悬浮窗：已经有窗在，同 App 就恢复/已开着；不同 App 就先关
// 当前窗再开新 App（v34 单窗切换）。
if (GHLSSHostedWindow) {
if (GHLSSHostedMinimized && strcmp(GHLSSHostedBundleID, bid) == 0) {
[self restoreHostedWindow];
[self dismissLauncher];
return;
}
if (strcmp(GHLSSHostedBundleID, bid) == 0) {
GHLSSLogLine("v38 window already open");
[self dismissLauncher];
return;
}
// v35：点的是别的 App——旧窗只藏起来、不销毁（closeHostedWindow：
// 藏窗 + 推后台 + 记最小化，和 X 关窗同一条路），再把活动量存进
// 缓存、清活动量，然后开新 App 的悬浮窗（5.2 单窗切换）。最小化
// 着的窗也一样（反正藏着）。一个 SpringBoard 会话里 scene 永远不
// 销毁：切回来直接复用缓存里的旧 scene（见 createHostedScene 的
// 复用守卫），不再建新 scene，残留撞不到。存完缓存先核对活动量清
// 干净了（窗/scene/presenter 全 nil、bundleID 清空、没最小化、
// 没被锁屏藏着、没在启动中），不清干净就不开新窗，免得新 scene
// 建在旧状态上。同一个 App 重开不走这里（关窗藏窗不销毁，直接
// 复用，见 closeHostedWindow）。
snprintf(buf, sizeof(buf), "v38 switching from %s to %s", GHLSSHostedBundleID, bid);
GHLSSLogLine(buf);
GHLSSLogLine("v38 window hidden on switch");
[self closeHostedWindow];
GHLSSSaveActiveToCache();
GHLSSClearActive();
if (GHLSSHostedWindow || GHLSSHostedScene || GHLSSHostedPresenter || GHLSSHostedBundleID[0] != '\0' || GHLSSHostedMinimized || GHLSSHostedHiddenByLock || GHLSSHostedLaunching) {
GHLSSLogLine("v38 switch state not cleared, aborting launch");
return;
}
GHLSSLogLine("v38 old window hidden, launching new app");
// 不 return，掉下去走正常开窗流程（先收启动器、再主线程启动）。
}
if (GHLSSHostedLaunching) {
GHLSSLogLine("v38 launch in progress, ignoring tap");
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
GHLSSLogLine("v38 launch failed no memory");
return;
}
GHLSSHostedLaunching = YES;
char buf[256];
snprintf(buf, sizeof(buf), "v38 launch start %s", bundleID);
GHLSSLogLine(buf);
@try {
NSString *bidStr = [NSString stringWithCString:bidCopy encoding:NSUTF8StringEncoding];
if (!bidStr) {
GHLSSLogLine("v38 launch failed bad bundle id");
GHLSSHostedLaunching = NO;
free(bidCopy);
free(nameCopy);
return;
}
RBSProcessIdentity *identity = [RBSProcessIdentity identityForEmbeddedApplicationIdentifier:bidStr];
if (!identity) {
GHLSSLogLine("v38 launch failed no identity");
GHLSSHostedLaunching = NO;
free(bidCopy);
free(nameCopy);
return;
}
GHLSSLogLine("v38 identity ok");
// 先看 App 是不是已经在跑（单场景 App 已有全屏版时，再建
// 第二个 scene 可能只剩白窗——测前要先把目标 App 彻底关掉）。
RBSProcessPredicate *predicate = [RBSProcessPredicate predicateMatchingIdentity:identity];
RBSProcessHandle *handle = [RBSProcessHandle handleForPredicate:predicate error:nil];
int pid = handle ? [handle pid] : 0;
if (pid > 0) {
char pbuf[128];
snprintf(pbuf, sizeof(pbuf), "v38 app already running pid=%d", pid);
GHLSSLogLine(pbuf);
// 已经在跑：不走事务，直接去建 scene（和参考实现同一做法）。
dispatch_async(dispatch_get_main_queue(), ^{
[self createHostedSceneForBundleID:bidCopy name:nameCopy];
free(bidCopy);
free(nameCopy);
});
return;
}
GHLSSLogLine("v38 handle pid=0");
FBProcessManager *manager = [FBProcessManager sharedInstance];
if (!manager) {
GHLSSLogLine("v38 manager failed nil");
GHLSSHostedLaunching = NO;
free(bidCopy);
free(nameCopy);
return;
}
GHLSSLogLine("v38 manager ok");
FBApplicationProcessLaunchTransaction *transaction = [[FBApplicationProcessLaunchTransaction alloc] initWithProcessIdentity:identity executionContextProvider:^id(void) {
GHLSSLogLine("v38 launch provider called");
FBMutableProcessExecutionContext *context = [FBMutableProcessExecutionContext new];
context.identity = identity;
context.environment = [NSDictionary dictionary];
context.launchIntent = 4;
return [manager launchProcessWithContext:context];
}];
if (!transaction) {
GHLSSLogLine("v38 transaction failed nil");
GHLSSHostedLaunching = NO;
free(bidCopy);
free(nameCopy);
return;
}
GHLSSLogLine("v38 transaction created");
[transaction setCompletionBlock:^{
// 事务完成可能跑在任意队列——场景创建回主线程做。
dispatch_async(dispatch_get_main_queue(), ^{
[self createHostedSceneForBundleID:bidCopy name:nameCopy];
free(bidCopy);
free(nameCopy);
});
}];
[transaction begin];
GHLSSLogLine("v38 begin called");
GHLSSLogLine("v38 launch transaction begun");
} @catch (NSException *e) {
(void)e;
GHLSSLogLine("v38 launch failed exception");
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
snprintf(buf, sizeof(buf), "v38 scene start %s", bundleID);
GHLSSLogLine(buf);
NSString *bidStr = [NSString stringWithCString:bundleID encoding:NSUTF8StringEncoding];
if (!bidStr) {
GHLSSLogLine("v38 scene failed no bid");
return;
}
RBSProcessIdentity *identity = [RBSProcessIdentity identityForEmbeddedApplicationIdentifier:bidStr];
RBSProcessPredicate *predicate = [RBSProcessPredicate predicateMatchingIdentity:identity];
RBSProcessHandle *handle = [RBSProcessHandle handleForPredicate:predicate error:nil];
int pid = handle ? [handle pid] : 0;
if (pid <= 0) {
GHLSSLogLine("v38 scene failed no process");
return;
}
snprintf(buf, sizeof(buf), "v38 process launched pid=%d", pid);
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
snprintf(rbuf, sizeof(rbuf), "v38 reusing cached scene %s", [GHLSSCacheSceneIDs[cacheIdx] UTF8String]);
GHLSSLogLine(rbuf);
} else {
GHLSSLogLine("v38 reusing cached scene");
}
GHLSSLoadCacheToActive(cacheIdx);
if (GHLSSHostedMinimized) {
[self restoreHostedWindow];
} else if (GHLSSHostedWindow) {
GHLSSHostedWindow.hidden = NO;
@try {
[GHLSSHostedScene updateSettingsWithBlock:^(UIMutableApplicationSceneSettings *settings) {
settings.foreground = YES;
if ([settings respondsToSelector:@selector(setBackgrounded:)]) {
settings.backgrounded = NO;
}
}];
GHLSSLogLine("v38 foreground pushed on reuse");
} @catch (NSException *e) {
(void)e;
GHLSSLogLine("v38 foreground push on reuse failed");
}
}
return;
}
GHLSSLogLine("v38 stored scene stale, destroying");
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
snprintf(ebuf, sizeof(ebuf), "v38 hosting existing scene %s", bundleID);
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
GHLSSLogLine("v38 foreground pushed on existing scene");
} @catch (NSException *e) {
(void)e;
GHLSSLogLine("v38 foreground push on existing scene failed");
}
GHLSSLogLine("v38 layer host ready");
[self buildHostedWindowForBundleID:bundleID name:name scene:existingScene presenter:nil layerHostView:layerHostView sceneID:sceneID pid:pid];
hostedExisting = YES;
} else {
GHLSSLogLine("v38 layer host view nil, creating new");
}
} @catch (NSException *e) {
(void)e;
GHLSSLogLine("v38 layer host failed, creating new");
}
}
if (hostedExisting) return;
GHLSSLogLine("v38 no existing scene, creating new");
FBProcessManager *manager = [FBProcessManager sharedInstance];
[manager registerProcessForAuditToken:[handle auditToken]];
GHLSSLogLine("v38 creating new scene");
char idbuf[256];
snprintf(idbuf, sizeof(idbuf), "v38 sceneID %s", [sceneID UTF8String]);
GHLSSLogLine(idbuf);
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
GHLSSLogLine("v38 scene failed nil scene");
return;
}
GHLSSLogLine("v38 scene created");
id presenterManager = [scene uiPresentationManager];
if (!presenterManager) {
GHLSSLogLine("v38 presenter failed no manager");
return;
}
_UIScenePresenter *presenter = [presenterManager createPresenterWithIdentifier:sceneID];
if (!presenter) {
GHLSSLogLine("v38 presenter failed nil");
return;
}
[presenter modifyPresentationContext:^(UIMutableScenePresentationContext *context) {
context.appearanceStyle = 2;
}];
[presenter activate];
if (!presenter.presentationView) {
GHLSSLogLine("v38 presenter failed no view");
return;
}
// v28：记 presenterView 的尺寸与有没有 layer——计算器在 v26 还是黑的
//（别的 App 都能画出来），要先排除 view 本身没尺寸、没嵌进去的可能。
// 只记日志，不改任何行为；同样包 @try/@catch，出错只记日志。
@try {
char pbuf[128];
UIView *pv = presenter.presentationView;
snprintf(pbuf, sizeof(pbuf), "v38 presentationView w=%d h=%d layer=%d", (int)pv.bounds.size.width, (int)pv.bounds.size.height, pv.layer ? 1 : 0);
GHLSSLogLine(pbuf);
} @catch (NSException *e) {
(void)e;
GHLSSLogLine("v38 presentationView failed");
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
snprintf(cbuf, sizeof(cbuf), "v38 scene contentState=%lu", (unsigned long)[scene contentState]);
GHLSSLogLine(cbuf);
} @catch (NSException *e) {
(void)e;
GHLSSLogLine("v38 scene contentState failed");
}
@try {
[scene updateSettingsWithBlock:^(UIMutableApplicationSceneSettings *settings) {
settings.foreground = YES;
}];
char fbuf[128];
snprintf(fbuf, sizeof(fbuf), "v38 foreground pushed contentState=%lu", (unsigned long)[scene contentState]);
GHLSSLogLine(fbuf);
} @catch (NSException *e) {
(void)e;
GHLSSLogLine("v38 foreground push failed");
}
GHLSSLogLine("v38 presenter ready");
[self buildHostedWindowForBundleID:bundleID name:name scene:scene presenter:presenter layerHostView:nil sceneID:sceneID pid:pid];
} @catch (NSException *e) {
(void)e;
GHLSSLogLine("v38 scene failed exception");
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
// v38：新窗的 scaleRatio 用这个 App 的默认值（计算器 0.77，别的 1.0）。
GHLSSHostedScaleRatio = GHLSSDefaultScaleRatioForBundleID(bundleID);
CGRect winFrame = CGRectMake((screenBounds.size.width - winW) / 2.0, (screenBounds.size.height - winH) / 2.0, winW, winH);
if (strcmp(bundleID, "com.apple.calculator") == 0) {
char wbuf[160];
CGFloat calcScale = hostedContentSize.width / GHLSSSceneFrameSizeForBundleID(bundleID).width;
snprintf(wbuf, sizeof(wbuf), "v38 calculator window %dx%d scale %d%%", (int)winW, (int)winH, (int)(calcScale * 100.0));
GHLSSLogLine(wbuf);
}
GHLSSHostedWindow = [[UIWindow alloc] initWithFrame:winFrame];
// v29：层级降到 Alert 之下——锁屏约在 Alert（2000），锁屏必须盖住我们的窗，密码键盘才能点到（2026-11-13 锁屏密码输不进去的 bug）。
GHLSSHostedWindow.windowLevel = UIWindowLevelAlert - 2.0;
GHLSSHostedWindow.backgroundColor = [UIColor clearColor];
UIWindowScene *hostedScene = GHLSSActiveWindowScene();
if (hostedScene) {
GHLSSHostedWindow.windowScene = hostedScene;
} else {
GHLSSLogLine("v38 hosted scene nil");
}
// 窗的阴影与圆角（画在窗的 layer 上；内容容器自己裁圆角）。
GHLSSHostedWindow.layer.cornerRadius = GHLSS_HOSTED_CORNER;
GHLSSHostedWindow.layer.shadowColor = [UIColor blackColor].CGColor;
GHLSSHostedWindow.layer.shadowOpacity = 0.5;
GHLSSHostedWindow.layer.shadowRadius = 12.0;
GHLSSHostedWindow.layer.shadowOffset = CGSizeMake(0, 6);
UIViewController *vc = [[UIViewController alloc] init];
// 内容容器：圆角 35、裁掉超出部分、细边框。v36：底色由白改黑——万一
// 哪有缝，露黑不露白（v35 计算器两侧的白边就是内容区的白色底）。
UIView *container = [[UIView alloc] initWithFrame:CGRectMake(0, 0, winW, winH)];
container.backgroundColor = [UIColor blackColor];
container.layer.cornerRadius = GHLSS_HOSTED_CORNER;
container.layer.masksToBounds = YES;
container.layer.borderWidth = 1.0;
container.layer.borderColor = [UIColor colorWithWhite:0.8 alpha:1.0].CGColor;
vc.view = container;
GHLSSHostedContainer = container;
// v38：内容区就是整个窗（没有标题栏了，App 内容从顶到底贴边填满）。
// v36：底色由白改黑（同容器）。
UIView *contentView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, winW, winH)];
contentView.backgroundColor = [UIColor blackColor];
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
snprintf(sbuf, sizeof(sbuf), "v38 scene scaled %d%%", (int)(GHLSSHostedScaleRatio * 100.0));
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
snprintf(sbuf, sizeof(sbuf), "v38 layer host scaled %d%%", (int)(displayScale * 100.0));
GHLSSLogLine(sbuf);
}
} else {
GHLSSLogLine("v38 window failed no view to embed");
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
snprintf(fbuf, sizeof(fbuf), "v38 hosted view frame %d,%d %dx%d", (int)pvFrame.origin.x, (int)pvFrame.origin.y, (int)pvFrame.size.width, (int)pvFrame.size.height);
GHLSSLogLine(fbuf);
} @catch (NSException *e) {
(void)e;
GHLSSLogLine("v38 hosted view frame failed");
}
// v38：缩放滑杆条（默认藏着）——点控制条的 ± 钮展开，盖在内容区顶
// 上 36pt（控制条下面，y=36；半透明黑底，不改窗尺寸、不推内容区）。
// 里面一条 UISlider（0.5–2.0，步进 0.01）+ 右边一个百分比。拖滑杆
// 改 scaleRatio，走同一条反向耦合路径。滑杆条是 container 的子视图
//（在内容区之上），跟着窗一起缓存、一起藏/显示。
UIView *scaleBar = [[UIView alloc] initWithFrame:CGRectMake(0, GHLSS_HOSTED_CONTROL_H, winW, 36)];
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
// v38：窗顶上的 16pt 透明细条（拖动窗 + 点它展开/收起控制条，
// 唯一的常驻装饰——中间一颗 56x5 的白点小 pill，半透明）。细条在
// 内容区之上、控制条之下（控制条展开时会盖住它）。点细条的手势
// 要等拖动失败才认（拖动时不触发点按）。
UIView *topStrip = [[UIView alloc] initWithFrame:CGRectMake(0, 0, winW, GHLSS_HOSTED_STRIP_H)];
topStrip.backgroundColor = [UIColor clearColor];
[container addSubview:topStrip];
GHLSSHostedTopStrip = topStrip;
UIView *pill = [[UIView alloc] initWithFrame:CGRectMake((winW - 56) / 2.0, 5, 56, 5)];
pill.backgroundColor = [[UIColor whiteColor] colorWithAlphaComponent:0.5];
pill.layer.cornerRadius = 2.5;
[topStrip addSubview:pill];
UIPanGestureRecognizer *stripDrag = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handleTitleDrag:)];
stripDrag.minimumNumberOfTouches = 1;
stripDrag.maximumNumberOfTouches = 1;
[topStrip addGestureRecognizer:stripDrag];
UITapGestureRecognizer *stripTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleTopStripTap:)];
stripTap.delegate = self;
[stripTap requireGestureRecognizerToFail:stripDrag];
[topStrip addGestureRecognizer:stripTap];
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
// 最小化钮（黄圆，左二）：只藏窗、不销毁 scene（5.3 再做贴边）。
UIButton *minBtn = [UIButton buttonWithType:UIButtonTypeCustom];
minBtn.frame = CGRectMake(44, 5, 26, 26);
minBtn.backgroundColor = [UIColor colorWithRed:1.0 green:0.76 blue:0.03 alpha:1.0];
minBtn.layer.cornerRadius = 13.0;
[minBtn setTitle:[NSString stringWithCString:"-" encoding:NSUTF8StringEncoding] forState:UIControlStateNormal];
[minBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
minBtn.titleLabel.font = [UIFont boldSystemFontOfSize:14];
[minBtn addTarget:self action:@selector(handleHostedMinimize:) forControlEvents:UIControlEventTouchUpInside];
[titleBar addSubview:minBtn];
// 标题：App 名，居中。
UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(78, 0, winW - 156, GHLSS_HOSTED_CONTROL_H)];
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
GHLSSLogLine("v38 window shown");
// v28：1.5 秒重试 + 4 秒再重试一次。v26 的 1.5 秒重试在真机日志里
// 一次都没出现——不知道是重试块根本没跑，还是窗在 1.5 秒内就被
// 关/最小化了、守卫条件直接 return 没留日志。所以两次重试的块一跑
// 就先无条件记一行 retry check（窗关了也记：scene 是 nil 时
// contentState 记 0），再按老条件决定推不推；推了记 retry /
// retry2。再包一层 @try/@catch，重试绝不能拖垮 SpringBoard。
dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
char cbuf[160];
snprintf(cbuf, sizeof(cbuf), "v38 foreground retry check contentState=%lu minimized=%d", (unsigned long)(GHLSSHostedScene ? [GHLSSHostedScene contentState] : 0), GHLSSHostedMinimized ? 1 : 0);
GHLSSLogLine(cbuf);
if (!GHLSSHostedScene || !GHLSSHostedWindow || GHLSSHostedMinimized) return;
@try {
if ([GHLSSHostedScene contentState] != 2) {
[GHLSSHostedScene updateSettingsWithBlock:^(UIMutableApplicationSceneSettings *settings) {
settings.foreground = YES;
}];
char rbuf[128];
snprintf(rbuf, sizeof(rbuf), "v38 foreground retry contentState=%lu", (unsigned long)[GHLSSHostedScene contentState]);
GHLSSLogLine(rbuf);
}
} @catch (NSException *e) {
(void)e;
GHLSSLogLine("v38 foreground retry failed");
}
});
dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(4.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
char cbuf[160];
snprintf(cbuf, sizeof(cbuf), "v38 foreground retry2 check contentState=%lu minimized=%d", (unsigned long)(GHLSSHostedScene ? [GHLSSHostedScene contentState] : 0), GHLSSHostedMinimized ? 1 : 0);
GHLSSLogLine(cbuf);
if (!GHLSSHostedScene || !GHLSSHostedWindow || GHLSSHostedMinimized) return;
@try {
if ([GHLSSHostedScene contentState] != 2) {
[GHLSSHostedScene updateSettingsWithBlock:^(UIMutableApplicationSceneSettings *settings) {
settings.foreground = YES;
}];
char rbuf[128];
snprintf(rbuf, sizeof(rbuf), "v38 foreground retry2 contentState=%lu", (unsigned long)[GHLSSHostedScene contentState]);
GHLSSLogLine(rbuf);
}
} @catch (NSException *e) {
(void)e;
GHLSSLogLine("v38 foreground retry2 failed");
}
});
} @catch (NSException *e) {
(void)e;
GHLSSLogLine("v38 window failed exception");
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
- (void)closeHostedWindow {
if (!GHLSSHostedWindow) return;
GHLSSHostedWindow.hidden = YES;
GHLSSHostedMinimized = YES;
GHLSSLogLine("v38 window closed (scene kept)");
GHLSSBackgroundHostedScene("v38 scene backgrounded on close");
}

// v35：destroyHostedScene 已删——会话内永不销毁 scene（见文件头 v35
// 节）。唯一剩下的销毁在 GHLSSDestroyCachedEntryAtIndex（只在复用
// 守卫判旧、进程死了时调）。切走与关窗只藏窗（见 handleAppButton
// 的切换路径与 closeHostedWindow）。启动器层级不用这里复位：
// showLauncher 每次按活动窗有没有定层级（有窗 Alert - 1、没窗
// Alert - 3），销毁只发生在没有活动窗的旧 scene 上。

- (void)minimizeHostedWindow {
if (!GHLSSHostedWindow || GHLSSHostedMinimized) return;
GHLSSHostedWindow.hidden = YES;
GHLSSHostedMinimized = YES;
GHLSSLogLine("v38 window minimized");
// v31：藏窗后把 scene 推回后台（foreground=NO + backgrounded=YES）。
// 锁屏时系统不会替我们的 scene 推后台，scene 一直占着前景，很可能
// 干扰锁屏密码的触摸；最小化时先后台化，锁屏时再后台化一次也无妨。
GHLSSBackgroundHostedScene("v38 scene backgrounded on minimize");
}

- (void)restoreHostedWindow {
if (!GHLSSHostedWindow || !GHLSSHostedMinimized) return;
GHLSSHostedWindow.hidden = NO;
GHLSSHostedMinimized = NO;
GHLSSLogLine("v38 window restored");
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
snprintf(fbuf, sizeof(fbuf), "v38 foreground pushed on restore contentState=%lu", (unsigned long)[GHLSSHostedScene contentState]);
GHLSSLogLine(fbuf);
}
} @catch (NSException *e) {
(void)e;
GHLSSLogLine("v38 foreground push on restore failed");
}
}

- (void)handleHostedClose:(id)sender {
GHLSSLogLine("v38 hosted close tapped");
[self closeHostedWindow];
}

- (void)handleHostedMinimize:(id)sender {
GHLSSLogLine("v38 hosted minimize tapped");
[self minimizeHostedWindow];
}

// v38：点标题栏的 ± 钮——展开/收起缩放滑杆条（默认藏着）。
- (void)handleScaleButton:(id)sender {
if (!GHLSSHostedScaleSliderBar) return;
GHLSSHostedScaleSliderBar.hidden = !GHLSSHostedScaleSliderBar.hidden;
// 展开时把滑杆值同步到当前 scale（切回来复用时滑杆还是旧值，
// 展开才同步一次，不用每次恢复都调）。
if (!GHLSSHostedScaleSliderBar.hidden && GHLSSHostedScaleSlider) {
GHLSSHostedScaleSlider.value = GHLSSHostedScaleRatio;
}
GHLSSLogLine("v38 scale bar toggled");
}

// v38：拖缩放滑杆——0.5–2.0，步进 0.01（UISlider 没有步进，handler
// 里四舍五入到 0.01：(int)(v*100+0.5)/100，不用 math.h）。改
// scaleRatio，走同一条反向耦合路径（立即改 transform、0.05 秒防抖
// 改 frame），百分比同步到滑杆条右边的 label，缓存里的 scaleRatio
// 也立即同步（不然切走再切回来会读回旧值）。
- (void)handleScaleSlider:(UISlider *)sender {
if (!sender) return;
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
snprintf(buf, sizeof(buf), "v38 scale changed to %d%%", (int)(v * 100.0));
GHLSSLogLine(buf);
GHLSSApplyScaleToHostedWindow(YES);
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

// v38：点窗顶上的细条（或控制条中间）——展开/收起控制条。控制条
// 收起来时，缩放滑杆条也跟着收起来（± 在控制条里，控制条藏着时
// 滑杆条也够不着）；控制条展开时，滑杆条保持原来的状态（展开时
// 才由 ± 控制）。
- (void)handleTopStripTap:(UITapGestureRecognizer *)recognizer {
if (!GHLSSHostedTitleBar) return;
GHLSSHostedTitleBar.hidden = !GHLSSHostedTitleBar.hidden;
if (GHLSSHostedTitleBar.hidden && GHLSSHostedScaleSliderBar) {
GHLSSHostedScaleSliderBar.hidden = YES;
}
GHLSSLogLine("v38 control bar toggled");
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
[self resizeHostedSceneToContentSize:CGSizeMake(newW, newH)];
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
snprintf(buf, sizeof(buf), "v38 scene resized %d,%d", (int)size.width, (int)size.height);
GHLSSLogLine(buf);
GHLSSApplyScaleToHostedWindow(YES);
} @catch (NSException *e) {
(void)e;
GHLSSLogLine("v38 scene resize failed");
}
}

- (void)handleCloseButton:(id)sender {
GHLSSLogLine("v38 close button tapped");
[self dismissLauncher];
}

- (void)handleBackgroundTap:(UITapGestureRecognizer *)recognizer {
GHLSSLogLine("v38 background tapped, dismissing launcher");
[self dismissLauncher];
}

- (void)showLauncher {
if (GHLSSLauncherVisible) {
GHLSSLogLine("v38 launcher already open");
return;
}
if (!GHLSSLauncherWindow) {
[self buildLauncherWindow];
}
// 有悬浮窗在时，启动器要升到它上面（不然会被盖住一半）。v29：相对顺序不变，但最高只到 Alert - 1（锁屏之下）。
if (GHLSSHostedWindow) {
GHLSSLauncherWindow.windowLevel = UIWindowLevelAlert - 1.0;
} else {
GHLSSLauncherWindow.windowLevel = UIWindowLevelAlert - 3.0;
}
GHLSSLauncherWindow.hidden = NO;
GHLSSLauncherVisible = YES;
GHLSSLogLine("v38 launcher opened");
}

- (void)dismissLauncher {
if (!GHLSSLauncherVisible) return;
GHLSSLauncherWindow.hidden = YES;
GHLSSLauncherVisible = NO;
GHLSSLogLine("v38 launcher dismissed");
}

// 建启动器窗（第一次打开时才建）：全屏透明窗 + 右侧 220pt 暗色面板。
// 面板与背景点按区是平级的两个子视图：点面板不会触发收起，
// 点面板以外（透明区）才收起。
- (void)buildLauncherWindow {
CGRect screenBounds = [UIScreen mainScreen].bounds;
CGFloat panelWidth = 220.0;
GHLSSLauncherWindow = [[UIWindow alloc] initWithFrame:screenBounds];
// v29：基准层级 Alert - 3（锁屏之下；有悬浮窗时见 showLauncher，会升到 Alert - 1）。
GHLSSLauncherWindow.windowLevel = UIWindowLevelAlert - 3.0;
GHLSSLauncherWindow.backgroundColor = [UIColor clearColor];
// 启动器的窗也显式挂 scene（v22 的教训：没挂 scene 的窗可能不显示）。
UIWindowScene *launcherScene = GHLSSActiveWindowScene();
if (launcherScene) {
GHLSSLauncherWindow.windowScene = launcherScene;
GHLSSLogLine("v38 launcher scene found");
} else {
GHLSSLogLine("v38 launcher scene nil");
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
snprintf(ibuf, sizeof(ibuf), "v38 icon nil for %s", GHLSSAppBundleIDs[i]);
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
GHLSSLogLine("v38 launcher built");
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
snprintf(buf, sizeof(buf), "v38 deferred setup ran, switch=%s", state);
GHLSSLogLine("v38 deferred setup ran");
GHLSSLogLine(buf);
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
GHLSSLogLine("v38 window scene found");
} else {
GHLSSLogLine("v38 window scene nil");
}
UIViewController *stripVC = [[UIViewController alloc] init];
GHLSSPlainStripView *stripView = [[GHLSSPlainStripView alloc] initWithFrame:CGRectMake(0, 0, stripWidth, screenBounds.size.height)];
stripView.backgroundColor = [UIColor clearColor];
stripVC.view = stripView;
GHLSSStripWindow.rootViewController = stripVC;
GHLSSStripWindow.hidden = NO;
GHLSSLogLine("v38 edge strip built");
// 诊断日志：窗与带子到底是什么状态（真机一看就知道上没上屏）。
char dbuf[256];
CGRect wf = GHLSSStripWindow.frame;
snprintf(dbuf, sizeof(dbuf), "v38 window frame=%d,%d,%d,%d hidden=%d scene=%s", (int)wf.origin.x, (int)wf.origin.y, (int)wf.size.width, (int)wf.size.height, GHLSSStripWindow.hidden ? 1 : 0, GHLSSStripWindow.windowScene ? "ok" : "nil");
GHLSSLogLine(dbuf);
CGRect sf = stripView.frame;
snprintf(dbuf, sizeof(dbuf), "v38 strip frame=%d,%d,%d,%d", (int)sf.origin.x, (int)sf.origin.y, (int)sf.size.width, (int)sf.size.height);
GHLSSLogLine(dbuf);
// 5.1 的处理器（唯一的自定义处理类）。
GHLSSLauncherShared = [[GHLSSLauncher alloc] init];
// 右边缘滑动手势（挂在感应带上）。
UIScreenEdgePanGestureRecognizer *edgePan = [[UIScreenEdgePanGestureRecognizer alloc] initWithTarget:GHLSSLauncherShared action:@selector(handleEdgeSwipe:)];
edgePan.edges = UIRectEdgeRight;
edgePan.delegate = GHLSSLauncherShared;
[stripView addGestureRecognizer:edgePan];
GHLSSLogLine("v38 edge gesture added");
// v38：哆啦A夢鈕（皇上要金色「分」按钮改成可爱型哆啦A夢图，3D 大笑
// 版）。24pt 的感应带放不下 56pt 的圆钮（圆钮一半会伸出窗外、点
// 不到），所以哆啦A夢鈕单独一个 56x56 的小窗（右边缘、竖直居中、
// 层级 Alert - 4，和感应带同级），感应带只留右边缘滑动手势。图
// 从 prefs bundle 里读（NSBundle bundleWithPath: +
// pathForResource:ofType:，路径用运行时现做的字串；@3x 由系统按
// 屏幕 scale 自动挑）；读不到就退回金色圆钮 + 「分」字（不空白、
// 不崩）。
CGFloat doraemonSize = 56.0;
CGRect doraemonFrame = CGRectMake(screenBounds.size.width - doraemonSize, (screenBounds.size.height - doraemonSize) / 2.0, doraemonSize, doraemonSize);
GHLSSDoraemonButtonWindow = [[UIWindow alloc] initWithFrame:doraemonFrame];
GHLSSDoraemonButtonWindow.windowLevel = UIWindowLevelAlert - 4.0;
GHLSSDoraemonButtonWindow.backgroundColor = [UIColor clearColor];
UIWindowScene *doraemonScene = GHLSSActiveWindowScene();
if (doraemonScene) {
GHLSSDoraemonButtonWindow.windowScene = doraemonScene;
} else {
GHLSSLogLine("v38 doraemon scene nil");
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
NSString *bundlePath = [NSString stringWithCString:"/Library/PreferenceBundles/GuHaiLongSplitScreenPrefs.bundle" encoding:NSUTF8StringEncoding];
NSString *resName = [NSString stringWithCString:"doraemon-button" encoding:NSUTF8StringEncoding];
NSString *resType = [NSString stringWithCString:"png" encoding:NSUTF8StringEncoding];
NSBundle *prefsBundle = bundlePath ? [NSBundle bundleWithPath:bundlePath] : nil;
NSString *imagePath = (prefsBundle && resName && resType) ? [prefsBundle pathForResource:resName ofType:resType] : nil;
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
GHLSSLogLine("v38 doraemon image loaded");
} else {
// 退回金色圆钮 + 「分」字（图读不到时不空白、不崩）。
doraemonButton.backgroundColor = [UIColor colorWithRed:0.83 green:0.68 blue:0.21 alpha:1.0];
doraemonButton.layer.borderWidth = 2.0;
doraemonButton.layer.borderColor = [UIColor blackColor].CGColor;
[doraemonButton setTitle:[NSString stringWithCString:"分" encoding:NSUTF8StringEncoding] forState:UIControlStateNormal];
[doraemonButton setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
doraemonButton.titleLabel.font = [UIFont boldSystemFontOfSize:14];
GHLSSLogLine("v38 doraemon image missing, fallback to gold");
}
[doraemonButton addTarget:GHLSSLauncherShared action:@selector(handleHandleButton:) forControlEvents:UIControlEventTouchUpInside];
[doraemonRoot addSubview:doraemonButton];
GHLSSDoraemonButton = doraemonButton;
GHLSSDoraemonButtonWindow.hidden = NO;
GHLSSLogLine("v38 doraemon button added");
CGRect bf = doraemonButton.frame;
snprintf(dbuf, sizeof(dbuf), "v38 doraemon button frame=%d,%d,%d,%d", (int)bf.origin.x, (int)bf.origin.y, (int)bf.size.width, (int)bf.size.height);
GHLSSLogLine(dbuf);
// v32：锁屏信号——libnotify 的 notify_register_dispatch（<notify.h>，
// 纯 C API，传 C 字串）。这不是被禁的 CFNotificationCenterAddObserver，
// 不碰 CFString，回调跑在主队列。v31 的做法（锁了且有 hosted scene
// 就把它推回后台）不够——皇上 16:00 复现：等 30 秒左右密码就按不
// 了了，键盘看得见、按了没反应；foreground-scene 理论被证伪。
// v32 只加一个变量：锁屏时把悬浮窗也临时藏起来（窗/presenter 锁屏
// 时可能还抓着触摸），解锁时再显示回来——只藏"开着"的窗，最小化
// 着的窗本来就藏着，不碰它；没窗时什么都不做。开了只记日志、不自
// 动推前景（等用户点恢复，恢复路径会推）。handler 保持极小，只调
// 后台化函数 + 藏窗/显示 + 记日志。
int lockToken = 0;
int lockNotifyResult = notify_register_dispatch("com.apple.springboard.lockstate", &lockToken, dispatch_get_main_queue(), ^(int token) {
uint64_t lockState = 0;
notify_get_state(token, &lockState);
if (lockState == 1) {
if (GHLSSHostedScene) {
GHLSSBackgroundHostedScene("v38 scene backgrounded on lock");
} else {
GHLSSLogLine("v38 lock state locked, no hosted scene");
}
// v32：锁屏时把悬浮窗也临时藏起来（见上面注释）。只藏"开着"的窗
// （hidden=NO 且没最小化）；最小化着的窗本来就藏着（hidden=YES），
// 不碰它——解锁时它也不能自己弹出来，等用户点恢复。
if (GHLSSHostedWindow && !GHLSSHostedMinimized) {
GHLSSHostedWindow.hidden = YES;
GHLSSHostedHiddenByLock = YES;
GHLSSLogLine("v38 hosted window hidden on lock");
} else if (GHLSSHostedWindow) {
GHLSSLogLine("v38 lock, window already minimized");
}
} else {
if (GHLSSHostedHiddenByLock) {
if (GHLSSHostedWindow) {
GHLSSHostedWindow.hidden = NO;
GHLSSLogLine("v38 hosted window shown on unlock");
}
GHLSSHostedHiddenByLock = NO;
} else {
GHLSSLogLine("v38 lock state unlocked");
}
}
});
if (lockNotifyResult == 0) {
GHLSSLogLine("v38 lockstate notify registered");
} else {
GHLSSLogLine("v38 lockstate notify register failed");
}
});
}
