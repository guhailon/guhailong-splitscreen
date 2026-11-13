# 顾海龙集团分屏 — GuHaiLongSplitScreen v1.0.38（实验版 v38）

原创 iOS 越狱分屏插件，包名 `com.guhailong.splitscreen`。

## v38 是什么（托管已有主 scene + 无标题栏大窗 + 哆啦A夢鈕）

**① 撞崩修法（最高优先级，BUILD_LOG §99 的设计）——已在跑的 App 托管它已有的主 scene（仿照 KonbanXV，作者 Hoangdus，MIT——只仿结构，代码原创）：**切到一个 App 前，先查 FBSceneManager 的 `_workspace` → `_allScenesByID`，找 identifier 匹配固定 sceneID `sceneID:<bundleID>-default` 的已有主 scene；找到了就不 `registerProcessForAuditToken`、不 `createScene`、不用 `_UIScenePresenter`，改用 `_UISceneLayerHostContainerView` + `_setPresentationContext:` 把已有 scene 的画面嵌进窗（只推 foreground，**不动它的 frame、不动安全区 insets**），永远不 destroyScene 它；哪一步失败就落回原来的 createScene 路径并记日志。缓存多一套平行数组 `GHLSSCacheLayerHostViews[5]`，复用判断、缩放、关窗/最小化/恢复、锁屏、陈旧场景守卫都按 presenter==nil / layer-host 分支。**② 无标题栏大窗（浮动View 的样子）：**44pt 标题栏删掉，内容区就是整个窗、贴边填满、圆角 35；一般 App 默认窗改大到 350x757（85% 宽、按屏比例算高，层宿主按宽缩放正好填满、无裁切、无白边），计算器仍是 320x693（0.77 缩放不变）。窗顶只有一条 16pt 透明细条（中间一条 56x5 的白 pill，50% 透明），点一下展开/收起 36pt 控制条（半透明黑底：红 X、黄最小化、App 名、±），控制条收起时缩放滑杆条也跟着收起；细条和控制条都能拖窗。缩放滑杆仍是 v37 的反向耦合（scene frame = 内容尺寸 ÷ scale）。**③ 哆啦A夢鈕：**金色「分」按钮改成 56pt 圆钮，大笑 3D 版哆啦A夢图（皇上 22:23 确认），单独一个 56x56 的小窗（右边缘、竖直居中、层级 Alert - 4），图从 prefs bundle 里读（@3x 自动挑，读不到退回金色圆钮 + 「分」字）；感应带仍是 24pt，只留右边缘滑动手势。

测法：**先把设置打开（让它在后台跑着），再从分屏启动器点设置——必须不进安全模式、设置正常画出来**；切设置↔计算器↔时钟来回 6 次，看有没有崩；计算器窗里按键全在、左右没有白边；点窗顶细条，控制条出来（红 X、黄最小化、± 都在），再点控制条中间收起来；点 ±，缩放滑杆条出来，拖滑杆放大/缩小；点右边缘的哆啦A夢鈕，启动器打开；锁屏→解锁，密码能按（等 30 秒以上再按）；日志里应有 `v38 hosting existing scene …`、`v38 layer host ready`、`v38 doraemon image loaded`、`v38 control bar toggled`、`v38 scale changed to …%`。

## v37 是什么（反向耦合缩放 + 标题栏缩放滑杆 + 安全区规则）

v36 真机日志（`GuHaiLongSplitScreen-8.log`，v36 段 183 行）：计算器贴边修好了（窗 320x736、scale 77%、presenterView frame 0,0 320x692、contentState 到 2）；切计算器→时钟→备忘录都正常；**切到设置时进安全模式两次，都是同一个签名——`app already running pid=3666` → 建 scene → `sceneID sceneID:com.apple.Preferences-default` → 下一行就是 `deferred setup ran`（SpringBoard 重启）。设置是皇上之前自己打开过、一直在后台跑的，所以 createScene 时它的进程已有同 ID 的主 scene，固定 ID 一撞就触发 registerHost fromRemnant 断言。**v35 段对比：设置第一次开是新进程、建 scene 成功，之后 12 次都是 reusing cached scene、0 崩——v35 的 never-destroy 修好了「销毁→重建」崩，但 v36 暴露了「已在跑 + 同 ID」这个新触发点。v37 的第 4 项（最高优先级，托管已有主 scene）因修法太大、且与第 1 项改同一处代码，**留给 v38 做**（见 BUILD_LOG §99 末尾的 v38 具体设计），v37 先做原定的三项：**① 反向耦合缩放（仿照 FrontBoardAppLauncher，作者 khanhduytran0，Apache-2.0——只仿结构，代码原创）：每个窗一个 scaleRatio（默认 1.0；计算器默认 0.77，窗仍是 320x737）；scene frame = 内容尺寸 ÷ scale，内容区 layer 加 sublayerTransform = CATransform3DMakeScale(scale, scale, 1) 缩回。一除一乘，任意 App、任意窗尺寸都填满内容区、贴边。v36 的计算器特判全删掉（只按宽缩放的 helper、建窗的计算器分支、缩放手柄的比例锁、resize 的计算器分支），只剩每 App 的默认 scaleRatio 不同。frame 更新防抖 0.05 秒；presentationView 的 bounds = frame 尺寸、anchorPoint (0,0)、position (0,0)。② 标题栏缩放滑杆 0.5–2.0（步进 0.01）：标题栏右边加一个 26x26 的「±」圆钮，点一下在内容区顶上展开一条 36pt 的滑杆条（半透明黑底，UISlider + 百分比），再点收起来。拖滑杆改 scaleRatio，走同一条反向耦合路径（立即改 transform、0.05 秒防抖改 frame）。滑杆条默认藏着；缩放能裁掉计算器顶上约 370pt 的黑空区（放大就裁掉）。③ 设置顶上切掉——按 LiveContainer 的安全区规则（AGPL，只借原则）：我们的初始 settings 本来就 peripheryInsets = 0、safeAreaInsetsPortrait = 0（窗口模式规则，已对上），初始 settings 不动；只在 frame 更新时（resize、滑杆）顺带把两个 insets 重设为 0。**若切掉只是滚动位置，这改就是空操作；若是 frame 更新后 insets 被重置，这改就修了它。仍需真机验证（滚动到顶看个人资料卡）。

测法：开计算器，看显示和按键是不是整个都在窗里、没被切掉、左右没有白边；点标题栏右边的 ±，滑杆条出来，拖滑杆放大/缩小，看内容跟着变大/变小、始终贴边填满；拖右下角手柄改窗大小（计算器窗现在不用按比例锁，随便拖），松手后内容重排版、仍贴边；切到时钟，再切回计算器，看计算器还画不画；**切到设置前先把它彻底关掉（App 切换器里划掉）——v37 还没修「已在跑的设置」崩，v38 才修**；锁屏密码还能按；日志里应有 `v37 calculator window 320x737 scale 77%`、`v37 presenterView frame 0,0 414x896`（图层尺寸，显示尺寸 = frame × scale）、`v37 scene scaled 77%`、`v37 scale changed to …%`、`v37 reusing cached scene …`。

## v36 是什么（计算器窗改高、按宽缩放贴边；内容贴边填满）

v35 真机（2026-11-13 20:39）：皇上「我觉得这些都不够整齐，没有对方好，我觉得可以做成第三幅图片样子」。三张截图：① 我们的 v35 计算器——全键盘出来了（显示 556,913,316，全部 5 排都在），但黑内容左右两边各有一条约 50pt 的白色边（53% 缩放的图层只有约 219 宽，居中放在 320 宽的窗里，两边露白——露的是内容区的白色底）；② 我们的 v35 设置——列表画出来了，但顶上第一项在内容区顶上被切掉一半；③ 对方 floatingView——一个又高又大的浮窗（几乎满屏高、约 85% 屏宽、圆角），Sileo 精选页把窗填得满满的、贴边，没有白边、没有被切掉、没有标题栏。v35 的防崩修法已证实有效（皇上能打开计算器和设置两个浮窗、没进安全模式；v34 切到设置崩了两次）。v36 只改：**① 计算器窗改高、只按宽缩放——内容区改成 320x693（屏高×320/屏宽，运行时算），s = 内容宽/图层宽 ≈ 320/414 ≈ 0.77（只按宽算，不再取宽高最小值），图层 414x896 按 0.77 缩后正好是 320x693，填满内容区、左右零白边、按键约 62pt；窗总高 693+44=737，896 高的屏上居中放得下。缩放手柄拖计算器窗时按比例锁高（内容高 = 宽×屏高/屏宽），不然缩放后的图层上下会被切。② 内容贴边填满：内容区底色由白改黑（万一哪有缝，露黑不露白）；建窗时记 presenterView 的实际 frame（x,y WxH），日志能证明它贴边放对了。**关于设置顶上切掉：从源码看，非计算器 App 的 presenterView 就是 frame = 内容区 bounds（0,0,320,480），没有任何偏移、没有裁——我们的几何不可能切掉顶部；最可能是列表被滚过（皇上测试时滑过，或缓存的 scene 留着滚动位置），其次才是 App 在零 safe-area 下的内部顶 inset。判定方法：把设置列表拉到最顶，看个人资料卡出不出现——出来就是滚动位置，没出来就是 inset 问题，v37 再试。默认窗尺寸不动：非计算器 App 已经贴边填满，加高默认窗不修任何毛病、只会多盖屏幕。

测法：开计算器，看显示和按键是不是整个都在窗里、没被切掉、左右没有白边；切到时钟，再切回计算器，看计算器还画不画；反复切计算器 ↔ 设置 6 次以上不进安全模式；关窗（X）再点同一个 App → 窗直接回来；锁屏密码还能按；日志里应有 `v36 calculator window 320x737 scale 77%`、`v36 presenterView frame 0,0 320x693`、`v36 scene scaled 77%`、`v36 reusing cached scene …`。

v34 真机（2026-11-13 20:01）：皇上「都还在，感觉非常OK，就是计算机画面有点没对准」——计算器画出来了、切换没问题、没进安全模式、状态也留住了（截图里 556,913,3… 是按过的数字）。但日志（`GuHaiLongSplitScreen-7.log`，v34 段 555 行）定死 v34 还是崩两次，两次都是切到设置：设置只建过一次、被切走时销毁过（切设置→照片），再建就崩在 `createSceneWithDefinition` 里（日志在 sceneID 后直接跳到 deferred setup ran，即 SpringBoard 重启；和 v32 的 .ips 定死的 registerHost 撞残留是同一个点）；第二次更是在重启之后又崩——设置进程 pid=2521 在重启后还活着，所以残留不在 SpringBoard 里、在设置进程自己身上，重启清不掉它。计算器、时钟、备忘录、照片都被销毁重建过多次，全成功——只有设置再建会崩，是设置特有的。结论：**v34「切走才销毁、ID 不同不撞」的判断错了——销毁 + 再建同一固定 ID 就是会崩。v35 只改一处原则：一个 SpringBoard 会话里永远不销毁 scene——关窗（X）和切走都只藏窗 + 推后台，每个 App 留一个 scene + presenter + 窗（最多 5 个），切回来直接复用；只在进程死了的时候（复用守卫判旧：pid 对不上或 presenter/view 没了）才销毁那个旧 scene 再建。**实现是每 App 一个窗、缓存在平行静态数组里（强引用，ARC 安全），一次只显示一个；活动窗仍用原来那套静态量，所有现成路径原样不动。

计算器对不准（20:01 截图）：窗 320 宽、计算器按全屏 414 宽排版、1:1 显示，右边和底下被切掉；日志 15 次 presentationView 全是 w=320 h=480。v35 只改：**① 计算器的 scene frame 改成屏幕尺寸（运行时读 UIScreen，不写死 414/896）——frame 决定远端图层大小，这样计算器的整张 414x896 画面都在图层里；② presentationView 按比例缩放到窗里（s = min(内容宽/图层宽，内容高/图层高)，只缩不放大；只对计算器——别的 App 按 scene frame 排版，s=1，不动）；触摸由 transform 自动映射。**缩放手柄松手时重算一次缩放。

测法：开计算器 → 点时钟 → 计算器窗藏起来、时钟窗出来；再点计算器 → 切回来，计算器必须画出来、不能黑，而且整个计算器（显示 + 全部按键）都要在窗里、不被切掉；反复切计算器 ↔ 设置 6 次以上不进安全模式；关窗（X）再点同一个 App → 窗直接回来；锁屏密码还能按；日志里应有 `v35 reusing cached scene …`、`v35 switching from … to …`、`v35 scene scaled …`，`v35 destroying scene …` 只在进程死了时出现（正常用不应出现）。

## v34 是什么（留着固定 sceneID，关窗改藏窗不销毁）

v33 真机（2026-11-13 17:08）：**开计算器就是黑屏**，没进安全模式——崩是没崩，但主 App 画不出来，比 v32 还糟。元凶定死是新 UUID sceneID：这次测的只是全新打开计算器，没走切换逻辑；v33 相对 v32 对全新打开唯一的区别就是 sceneID 从固定改成每次新 UUID。历史对得上：v25–v27（新 UUID）计算器黑；v28（固定 ID，高层级）黑（层级问题）；v29–v32（固定 ID，低层级）计算器能画；v33（新 UUID，低层级）又黑了。结论：**已在跑着的单 scene App（计算器）要画出来，需要固定 sceneID `sceneID:<bundleID>-default`**（即 App 自己的默认 scene ID）；全新 UUID 的 scene 它认不出来、不往里画。v28「sceneID 假说已死」是错的——当时是层级问题盖住了 sceneID 的作用；两个条件（固定 ID + 低层级）都要，缺一不可。

但固定 ID 的残留撞 ID 崩是真的（.ips 定死：EXC_BREAKPOINT，`FBWorkspace registerHost:...fromRemnant:` 里断言；同一固定 ID 关窗重开 5 次都好、第 6、7 次崩）。v34 的修法不靠新 ID，靠改关窗的生命周期：**① 关窗（X）不再销毁 scene——只藏窗、推后台、记最小化，scene 留着；重开同一个 App 直接复用旧 scene（推前景、显示窗），不再建新 scene，同一 ID 一个 SpringBoard 会话里只建一次。② 切走别的 App 时才真正销毁（新方法 `destroyHostedScene`，旧关窗体；新 App 的固定 ID 不同，不撞）。③ `createHostedScene` 入口加复用守卫：已有同 App 的 scene 且 presenter/view 还活着、进程还是同一个 pid，就直接复用、不建新 scene；scene 旧了就先销毁再建。**单窗切换（v33 的）原样保留。残留风险：A→B→A 切回来时，A 的 scene 在第一次切走时已销毁，重建同一固定 ID——v32 的崩要攒 ~6 次同 ID 关窗重开才触发，单次切回远不到阈值，但反复来回切可能攒够；若真机再现，v35 再做每 App 留一个 scene、会话内永不销毁。

测法：开计算器悬浮窗 → 点启动器里的时钟 → 计算器窗关掉、时钟悬浮窗出来；再点计算器 → 时钟窗关掉、计算器悬浮窗出来（切回来，计算器必须画出来、不能黑）；关窗（X）再点计算器 → 窗直接回来、计算器画出来（复用，不建新 scene）；关窗重开同一个 App 6 次以上不进安全模式；锁屏密码还能按；日志里应有 `v34 reusing existing scene …`、`v34 switching from … to …` 与 `v34 destroying scene …`。

## v33 是什么（单窗切换 + 每次新 sceneID）

v32 真机（2026-11-13 16:31）：**锁屏密码修好了**（「可以了，非常OK」）。但新问题：**App 没办法来回切换**——开着计算器，点启动器里的时钟没反应，必须先把计算器悬浮窗关掉（X）再点。5.2 只准开一个窗，点别的 App 时直接忽略。皇上 16:33 确认是不同 App 之间切。

v33 只改两处（同一条关窗→开窗路）：**① 点别的 App 时，先关当前窗（走现有关窗路径，销毁 scene、停 presenter、进程留着），核对状态清干净了，再开新 App 的悬浮窗（单窗切换）；最小化着的窗也一样关了再开；同一个 App 再点不变（恢复/已开着）。② sceneID 改每次新 UUID**——同一天皇上又报：悬浮窗开着时点启动器里的 App，SpringBoard 会进安全模式；日志（`GuHaiLongSplitScreen-6.log`）定死：2 次崩全是计算器关窗重开，崩在 `createSceneWithDefinition` 里，同一固定 sceneID、同一 pid，前面 5 次关窗重开都好、第 6、7 次崩；第 2 次崩很可能是第 1 次崩留下的半注册 scene 撞的。`destroyScene` 不是完全同步/干净的，v28「固定 ID 复用安全」的判断错了。每次新 ID（LiveContainer 的做法；我们保留 bundleID 在前面、UUID 在后面），关窗重开与切 App 都不会撞 ID。固定 ID 不是画画的必要条件：v28 换固定 ID 时计算器还是黑的，是 v29 降层级才让它画出来。UUID 用纯 C 的 `uuid_generate` / `uuid_unparse`，不用 NSUUID 类。其余与 v32 相同。

测法：开计算器悬浮窗 → 点启动器里的时钟 → 计算器窗关掉、时钟悬浮窗出来；再点计算器 → 时钟窗关掉、计算器悬浮窗出来；最小化计算器 → 点时钟 → 直接开时钟悬浮窗；同一个 App 再点仍恢复/已开着；关窗重开同一个 App 6 次以上不进安全模式；日志里应有 `v33 switching from … to …`、`v33 sceneID sceneID:…` 与 `v33 destroying scene …`。

## v32 是什么（锁屏时把悬浮窗也临时藏起来）

v31 真机（2026-11-13 16:00）：**密码还是按不动**——等 30 秒左右密码就开始按不了了，键盘看得见（跟 15:21 的截图一样），按了没反应。锁屏时把 scene 推回后台不够，**foreground-scene 理论被证伪**。下一方向（`V31_RESEARCH.md` 写的）：锁屏时我们的窗/presenter 可能还抓着触摸。

v32 只改一个变量：**在 v31 的锁屏回调里，锁了除了推后台化，还把悬浮窗临时藏起来（`hidden=YES`）；开了再显示回来——只藏「开着」的窗，最小化着的窗本来就藏着，不碰它；没窗时什么都不做**。感应带和启动器不动（只藏悬浮窗）。开了不自动推前景（等用户点恢复，恢复路径会推）。其余与 v31 相同。

测法：开计算器悬浮窗 → 锁屏 → 开屏 → 密码每次都能按（连测 3 次）；锁屏时悬浮窗应该藏起来、开屏后重新出现；最小化 → 锁屏 → 开屏 → 密码能按 → 恢复计算器必须画出来，不能黑；日志里应有 `v32 hosted window hidden on lock` 与 `v32 hosted window shown on unlock`。

## v31 是什么（修锁屏密码按不动——最小化与锁屏时把 scene 推回后台）

v29 把所有窗层级降到锁屏之下，只修好了第一次锁屏；v30 上源后皇上 2026-11-13 15:21 复现：**锁屏密码键盘看得见（数字键全在），但按了没反应**，6 个圆圈一个都没填——不是窗盖住键盘，是按了没被系统处理。首要怀疑：hosted scene 从没被后台化（只推过 `foreground=YES`，从没推过 `NO`），锁屏时它还占着前景，干扰锁屏触摸。

v31 只改三处：**① 最小化时把 scene 推回后台（`foreground=NO + backgrounded=YES`）；② 锁屏信号用 libnotify 的 `notify_register_dispatch("com.apple.springboard.lockstate")`（纯 C API，传 C 字串，不是被禁的 `CFNotificationCenterAddObserver`，不碰 CFString），锁了且有 hosted scene 就把它推回后台，开了只记日志、不自动推前景；③ 恢复时 v30 的 foreground 推送里补 `backgrounded=NO`**。`backgrounded` 属性由 KonbanXV（MIT）的 `dehost` 先例证实存在，另加 `respondsToSelector` 兜底；presenter 不动（只在关窗销毁时才 deactivate）。层级、sceneID、主线程启动、重试、其余什么都不动。

测法：开计算器悬浮窗 → 锁屏 → 开屏 → 密码每次都能按（连测 3 次）；最小化 → 锁屏 → 开屏 → 密码能按 → 恢复计算器必须画出来，不能黑；日志里应有 `v31 scene backgrounded on lock`。

## v30 是什么（5.2 修恢复后黑窗——恢复时再推一遍 foreground）

v29 真机（2026-11-13 15:12–15:14）：锁屏修好了——开悬浮窗锁屏，再开屏密码能输；计算器也能画了（截图为证：数字键全画出来了）。但新 bug：**最小化悬浮窗 → 锁屏 → 解锁 → 再点同一个 App 恢复窗，内容是黑的**（截图为证：标题栏和按钮都在，内容区全黑）；点 X 关窗再打开就正常（新 scene、建窗时推了 foreground）。原因是锁屏把 scene 的 foreground 状态弄丢了，恢复时只取消 hidden、没再推 foreground，scene 就一直黑着。

v30 只改一个变量：**`restoreHostedWindow` 里，取消 hidden 之后，用建窗时同一个已证明能用的 `updateSettingsWithBlock:` 把 `foreground=YES` 再推一遍，并记一行日志（`foreground pushed on restore`）**；单独包 `@try/@catch`，出错只记日志。锁屏层级（v29 的 `Alert - 4/-3/-2/-1`）、sceneID（v28 的固定格式）、其余什么都不动。

测法：最小化计算器悬浮窗 → 锁屏 → 解锁 → 再点计算器恢复——必须画出来，不能黑；再测锁屏密码还能输（v29 的修不能丢）。

## v29 是什么（修锁屏密码输不进去——所有窗层级降到锁屏之下）

皇上 2026-11-13 14:51 复现并确认：锁屏再开屏，锁屏密码输不进去，只能关机。原因在代码里看得一清二楚：我们所有窗的层级都在锁屏之上——悬浮窗 `UIWindowLevelAlert + 2.0`（2002）、启动器最高 `+ 3.0`（2003）、感应带就是 `Alert`（2000），而锁屏约在 `Alert=2000`。手机一锁屏，我们的窗还盖在锁屏上面，密码键盘点不到。

v29 只改一个变量：**所有 `windowLevel` 整体下移 4，相对顺序不变**——感应带 `Alert - 4`（1996）、启动器基准 `Alert - 3`（1997）、悬浮窗 `Alert - 2`（1998）、有悬浮窗时启动器 `Alert - 1`（1999）。全部在锁屏（2000）之下，仍在状态栏（1000）与 App（0）之上，平时用不受影响。sceneID 仍是 v28 的固定格式，其余什么都不动。

测法：开一个悬浮窗（任意 App），锁屏，再开屏输密码——必须能输；再测计算器在悬浮窗里画不画（v28 的问题还没验）。

## v28 是什么（5.2 修计算器还是黑——sceneID 改固定格式）

计算器的诊断到此定死了（2026-11-13 14:16–14:27）：v26 的 foreground
显式推修好了 4/5 个 App 的黑窗——设置、时钟、照片、备忘录全能在悬浮
窗里画出来（截图为证）；只有计算器还是黑的。已排除的：**时机**（等
10 秒还是黑，不是连得慢）；**全新启动 vs 已在跑**（新启动和已在跑都
黑，别的 App 画出来之前和之后都黑）；**第一个进程被「毒化」也排除了**
——皇上 14:27 重新越狱（全部进程全新、新 SpringBoard），计算器在悬浮
窗里还是黑的。所以是**计算器这个 App 本身不吃我们现在的 scene 设置**。

v27 是诊断版（1.5 秒 + 4 秒重试、无条件记日志、记 presenterView），
重试修不了计算器（10 秒等待已证明不是时机问题），没部署到源。

v28 只改一个变量：**sceneID 从每次新 UUID，改成参考项目
FrontBoardAppLauncher 的固定格式 `sceneID:<bundleID>-default`
（`persistenceIdentifier` 也用同一个固定值）**，和参考项目完全一样。
关窗时 scene 本来就会销毁，所以固定 ID 重用是安全的（参考项目就是
这么做的）。如果 v28 计算器画出来了，就是 sceneID 的问题；如果还是
黑，下一步走 KonbanXV 的路——宿主 App 已有的主 scene。

## v27 是什么（5.2 修 v26 的重试没留日志 + 计算器还是黑）

v26 真机（2026-11-13 14:16–14:17）：foreground 显式推，修好了 4/5
个 App 的黑窗——设置、时钟、照片、备忘录全能在悬浮窗里画出来
（截图为证：设置 > 通用、世界时钟都显示了）。只有计算器还是黑的，
3 次全黑（全新启动 pid=5642 + 已在跑重开两次，别的 App 画出来之前
和之后都黑）——所以是计算器自己的问题，不是启动时机、不是顺序、
不是全新还是已在跑。日志（`GuHaiLongSplitScreen-4.log`）20 次
`contentState` 全是 1、一次都不是 2，连能画出来的 App 也是 1——
`contentState` 不能当画没画的信号（继续记，但不拿它当通过标准）。
1.5 秒的 foreground 重试在整份日志里一次都没出现：要么皇上每次都
在 1.5 秒内关窗/最小化了（守卫条件直接 return、没留日志），要么
重试块根本没跑。

v27 只改两件事：**① 1.5 秒重试之外再加 4 秒重试一次，两次重试的块
一跑就先无条件记一行 `retry check`（窗关了也记，`contentState=0`、
`minimized=0`），再按老条件决定推不推；推了记 `retry` / `retry2`。
② presenter activate 之后，记 `presenterView` 的尺寸（w/h）与有
没有 layer**，排除 view 本身没尺寸、没嵌进去的可能。其余与 v26
相同。

## v26 是什么（5.2 修 v25 的黑窗）

v25 真机（2026-11-13 11:50）：悬浮窗出来了（圆角、标题栏「计算器」、
红 X、黄最小化、金色「分」按钮），没进安全模式、没卡住、手机没重启——
v24 的崩修好了。但窗里的内容全黑，计算器的界面画不出来，没法用。
日志（`GuHaiLongSplitScreen-3.log`）证明整条链全走通了两遍：
`identity ok` → `handle pid=0` → `manager ok` → `transaction created`
→ `provider called` → `begin called` → `transaction begun` →
`scene start` → `process launched pid=5254` → `scene created` →
`presenter ready` → `window shown`；关窗后重开（进程已在跑 pid=5254）
也一样走到 `window shown`、也一样黑——所以不是启动时机问题。
scene、presenter、窗都在，就是计算器进程没往 scene 里画东西。

v26 只改一件事：**presenter activate 之后，把 foreground=YES 显式推给
scene**（KonbanXV 的做法，注释写着 "important for the view to be
interactable"），并记 scene 的 `contentState`（0 没就绪、1 准备中、2
就绪）；窗出来 1.5 秒后，如果窗还在、没最小化、`contentState` 还不是
2，再推一遍。推 foreground 用的是已经证明能用的
`updateSettingsWithBlock:`（缩放那条路就用它推 frame，日志里有
`v25 scene resized`）。其余与 v25 相同。

## v25 是什么（5.2 修 v24 的安全模式）

v24 真机：点启动器里的计算器，手机直接进安全模式。崩溃日志
（`SpringBoard-2026-11-13-110826.ips`）定死了原因：
**EXC_BREAKPOINT**，崩在 `-[BSTransaction begin]` 里，后台队列。
`FBApplicationProcessLaunchTransaction` 是 `BSTransaction` 的子类，
`begin` 里面断言当前队列必须是主队列（`BSDispatchQueueAssert`）——
v24 把启动放后台队列，`begin` 一调就触发断言，把 SpringBoard 杀进
安全模式。RBS 那些调用在后台队列都成功了，只有 `begin` 崩。

v25 只改一件事：**启动放回主线程做**（和参考实现
FrontBoardAppLauncher 一模一样——它就是在主线程点按回调里拉起进程）。
FB 事务本身是异步的：`begin` 立刻返回、完成走回调，主线程不会被堵
（v23 那种 5 秒卡死是同步打开调用造成的，那条路已经删了，不会重演）。
先收启动器不变；启动每一步都记日志（`v25 identity ok`、`v25 handle
pid=0`、`v25 manager ok`、`v25 transaction created`、`v25 begin called`），
下次再崩直接定位到具体调用。

## v24 是什么（5.2：悬浮窗里打开 App）

v23 真机：按钮看得见、启动器能开能关，但点 App 会卡 5 秒以上、
App 全屏打开、手机随后自己重启。日志证明两件事：系统打开 App 的
方法在 SpringBoard 里根本打不开 App（四次全失败，ok=0），而那个
同步调用把主线程堵了 5 秒以上，触发看门狗把 SpringBoard 重启了。
v25 只改启动的线程（见上），其余与 v24 相同：

- 点 App 时**先收启动器，再在主线程走 FB 事务启动**——事务本身
  异步，`begin` 立刻返回，主线程不被堵；
- 启动只走 **FBProcessManager + FBApplicationProcessLaunchTransaction**
  （SpringBoard 这边的正路），再经 **FBSceneManager** 建 scene、
  用 **\_UIScenePresenter** 把 App 的画面嵌进悬浮窗；
- 悬浮窗照 floatingView 的样子：圆角 35、带阴影、320x480、44pt
  标题栏可拖动、红关闭钮、黄最小化钮、右下角缩放手柄；一次只开
  一个悬浮窗；每一步都记日志，任何一步失败只记日志、不拖垮
  SpringBoard；场景结构仿 FrontBoardAppLauncher（Apache-2.0），
  代码是原创。

测前先把计算器彻底关掉（在 App 切换器里划掉），不然 scene 可能
只剩白窗。键盘不在 v25 做（计算器不用键盘；iOS 16.5 没有干净的
键盘办法，见 `V5_DESIGN.md` §3.3）。

## 目标（定死）

- 机型：**iPhone 11**
- 系统：**iOS 16.5**
- 越狱：**Dopamine（rootless）**
- 架构：`iphoneos-arm64`，`arm64 / arm64e`，SDK 16.5

其他版本、其他越狱工具均不在目标内，不保证能用。

## v23 是什么（修 v22 的窗没显示出来）

v22 真机：装得上、不黑屏，日志全齐，但金色「分」按钮看不见，滑两次
也打不开启动器——感应带的窗在代码里建了，却没显示到屏幕上。v23 只
改三件事：

- 窗显式挂 `windowScene`（从 `connectedScenes` 取，没挂 scene 的窗
  可能不显示）；
- 带子的视图给显式 frame（不用 plain init 的零 frame）；
- 把手做大做显眼：感应带 24pt 宽，按钮 24x64、14pt 粗体、金底黑边。

建窗后还记诊断日志（窗的 frame、hidden、scene 有没有，带子与按钮的
frame），真机一看日志就知道窗到底上没上屏。启动器的窗也一样显式挂
scene。5.1 其余不变。

## v22 是什么（5.1）

v22 在 v21 的基础上加 5.1：边缘滑动 + 侧边小窗启动器。

- 右边缘感应带（12pt 透明窗）上多了一个看得见的金色「分」按钮
  （备用触发）。
- 感应带上挂 `UIScreenEdgePanGestureRecognizer`（右边缘）：2 秒内
  滑两次打开启动器（防误触），点「分」按钮则点一次就开。
- 启动器：右边缘 220pt 宽、暗色半透明，列 5 个系统 App（计算器、
  时钟、备忘录、设置、照片），带图标；点 App 全屏打开（5.2 才做
  scene 托管），点窗外或「关闭」收起。
- 关键测试：手势识别器在 macOS 编的包里能不能工作（v14/v16 的
  手势在 Linux 编的包里黑屏；v21 只证明了自定义类）。
- 一切照旧：`%ctor` 里只调 `dispatch_after`，一个写死的字串都不用，
  不登记通知，不建 scene，不 hook；macOS（GitHub Actions）上编。

## v21 是什么

v21 的代码和 v18（1.0.18）一模一样：感应带是自己写的普通视图
（不接 touch、不挂手势），`%ctor` 里只调 `dispatch_after`，
5 秒后在延后的步骤里读开关、建右边缘 12pt 透明感应带并写日志。
唯一差别是**改在 macOS（GitHub Actions，苹果 clang）上编**。

为什么：v18（Linux 工具链编的）装完黑屏，v20（只编 arm64）装完
不加载。开源项目调研发现所有能用的开源分屏/浮窗项目都是用苹果
自己的 clang 在 macOS 上编的（见 `BUILD_LOG.md` 第 39 节）。
v21 就是证明：

- v21 不黑屏 + 日志里有 `v21 edge strip built` = 凶手就是 Linux
  工具链，往后全部在 macOS 上编；
- v21 也黑屏 = 问题不在工具链，要换做法。

## 构建

GitHub Actions，见 `.github/workflows/build.yml`
（macOS runner + Theos + iOS 16.5 SDK + ldid，做法照抄
FrontBoardAppLauncher 的 build.yml，Apache-2.0）。
推代码就自动跑；跑完在该次运行的 Artifacts 里下载 `.deb`。

本地 Linux 构建见 `BUILD_LOG.md`——需 clang 交叉工具链 + iOS SDK +
ldid，但 Linux 编出来的自定义类在真机黑屏，所以主线已改走 macOS。

## 文件

- `Makefile` / `control` / `Tweak.xm` / `GuHaiLongSplitScreen.plist`：主插件
- `prefs/`：设置页（PreferenceLoader，开关）
- `.github/workflows/build.yml`：云端编译
- `BUILD_LOG.md`：编译尝试的实际命令与输出（成功/失败都如实记）
- `V5_DESIGN.md`：5.1 分屏完整设计（FrontBoard 路线，研究用）
