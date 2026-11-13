# v5 设计：把第二个 App 的 live scene 装进悬浮窗

> **性质：只做设计，不写代码、不改源、不部署。** 2026-11-12。
> 目标：iPhone 11 / iOS 16.5 / Dopamine（rootless），`com.guhailong.splitscreen`。
> 红线不变：**全部原创代码**；不下载、不复制、不反编译 floatingView（be-huge，付费闭源）
> 的二进制与代码；不把它或它的破解版收进本源。参考实现只取公开原理：
> FrontBoardAppLauncher（Apache-2.0 开源）与 LiveContainer 的多任务实现
> （同作者 khanhduytran0，即 TrollPad 作者 Duy Tran Khanh）。

## 0. 结论先行

**可行的路只有一条：FrontBoard 直连。** 在 SpringBoard 进程里直接用
FrontBoard 的私有 API：先经 `FBProcessManager` 把目标 App 的进程拉起来，
再经 `FBSceneManager` 为它建一个 scene，用 `_UIScenePresenter` 把 scene 的
画面嵌进我们自己的悬浮 `UIWindow` 里。这条路在开源实现里已经跑通
（FrontBoardAppLauncher / LiveContainer 多任务），不需要 medusa 能力位、
不需要 hook `SBApplication`、`SBPlatformController`——v1 证明 medusa 会进
安全模式，v3 证明启动时改 SpringBoard 多任务决策会卡住手机。**v5 不碰
medusa，不碰 SB 的私有方法，只调 FrontBoard + UIKit 的私有接口。**

一句话概括 v5 的形态：**我们自己的悬浮窗壳（v4 已有）+ 每个窗里嵌一个
`_UIScenePresenter` 的 presentationView（v5 新增）+ 边缘滑动叫出侧边小窗
（v5.1）+ 小窗贴边收起（v5.3）。** 三屏左右钉小窗是 5.4，不进 v5。

最难的三件事，按难度排：**(1) 键盘**——托管 scene 里点输入框能不能弹出
键盘、字能不能打进去（参考实现承认这是已知坑，有三档修法，iOS 16 上没有
干净修法）；**(2) 进程生死**——SpringBoard 不认我们的托管 App 是前台
App，RunningBoard 会不会把它挂起/杀掉；**(3) 单场景 App**——iPhone 上多数
App 只支持一个 scene，App 已经在前台开着时再建第二个 scene 可能只剩白窗。

---

## 1. 证据：这次查了什么、没查什么

### 1.1 皇上的录屏（已核实：逐帧看过）

`workspace/user/media_library/video/49/497dafca92e3f0f730947997465996f87ef1580dfd5880cbd3afe4a8e5c0b71b.mp4`，
18.6 秒、592×1280，逐秒抽帧核对：

- 微信搜索界面、微信聊天（花·海）、汽水音乐开屏，各自装在**圆角悬浮窗**
  里，窗后是主屏图标——是 live 的 App 画面，不是截图。
- 同一时间多个窗并存；屏幕右侧边缘有贴边的小窗（窄条，只露一部分内容）。
- 浮窗圆角约 35（与设置页“浮窗圆角 35.0”滑条一致）、有阴影。

结论：floatingView 的做法就是“每个 App 一个 scene + 一个悬浮窗”，与下面
§2 的 FrontBoard 路线在形态上完全一致。**这只是形态证据，不能证明它
内部就是这么实现的**（它的二进制没看过，也不会去看）。

### 1.2 开源参考实现（已核实：读过实际源码，不是只看介绍）

克隆到 `/tmp/fbal`（`khanhduytran0/FrontBoardAppLauncher`，Apache-2.0，
2026-11-12 当天克隆的最新版），逐个读过：

| 文件 | 读到的关键内容 |
|---|---|
| `AppSceneViewController.m` | 建 scene、建 presenter、改尺寸、关窗、转设置差量的完整流程（见 §2.2） |
| `DecoratedAppSceneView.m` | 先起进程事务、完成后再建 scene 的两段式流程；`RBSTarget` 的 hook（键盘修法之一） |
| `UIKitPrivate+MultitaskSupport.h` | 全部私有接口的最小声明（类名与方法名，见附录 A） |
| `DecoratedFloatingView.m` | 窗口外框：44pt 标题栏（拖动）、右下角 60×60 缩放手柄、圆角 10、边框、点按置顶 |
| `LauncherViewController.m` | App 列表取法；图标用 `UIImage _applicationIconImageForBundleIdentifier:format:scale:` |
| `Hooks.m` | `FBSWorkspaceScenesClient` 的设置差量过滤；`UIWindow` 的几个私有开关（`_allowsOcclusionDetectionOverride` 等） |
| `SceneDelegate.m` / `main.m` | 宿主 App 自己的浮动 scene + `UIRootWindowScenePresentationBinder`；`main` 里先调 `FBSystemShellInitialize` |
| `README.md` | 支持 iOS 15+、需 TrollStore；已知问题见 §2.5 |

另读了同作者的 LiveContainer 多任务键盘研究
（gist `khanhduytran0/504b16d86a2091e676c412bd0a517306`，全文 867 行）：
键盘焦点问题的根因、三种修法、iOS 17.4+ 的干净修法（见 §3）。

### 1.3 本地 SDK 的符号核查（已核实：2026-11-12 在本机 iPhoneOS16.5.sdk 上跑过）

`.tbd` 只列类与函数符号，不列方法（方法是运行时解析的，所以查不到
`createSceneWithDefinition:` 这种方法名是正常的，不代表它不存在）：

- `FrontBoard.framework/FrontBoard.tbd`：`FBSceneManager` 32 处、
  `FBProcessManager` 17 处、`FBApplicationProcessLaunchTransaction` 10 处。
  → **FBScene / FBProcessManager 这组类在 iOS 16.5 SDK 里是可链接的。**
- `FrontBoardServices.framework/FrontBoardServices.tbd`：
  `FBSMutableSceneDefinition`、`FBSSceneIdentity`、`FBSSceneClientIdentity` 均有导出。
- `RunningBoardServices.framework/RunningBoardServices.tbd`：
  `RBSProcessIdentity`、`RBSProcessHandle` 均有导出。
- `UIKitCore.framework/UIKitCore.tbd`：`_UIScenePresenter` 20 处、
  `UIScenePresentationManager` 9 处、`UIRootWindowScenePresentationBinder` 1 处、
  `_UIScenePresentationView` 1 处。
  → **presenter 这组类也是可链接的。**

结论：v5 可以在 Makefile 里链接 `FrontBoard`、`FrontBoardServices`、
`RunningBoardServices` 私有 framework（Theos 的 `_PRIVATE_FRAMEWORKS`），
方法名用自己写的最小 `@interface` 声明（像参考实现那样），不要等
class-dump。**但“可链接”不等于“SpringBoard 进程里能调通”**——那是真机
问题，见 §6。

### 1.4 没查的东西（明确列出来，不装作查过）

- 没有看过 floatingView 的二进制、没有反编译它；它的内部做法只知道
  公开元数据那部分（BUILD_LOG.md §9.1）：Swift + Orion、主 dylib 只进
  SpringBoard、另有键盘（UIKeyboardImpl）与相机（mediaserverd）辅助 dylib、
  hook 类名里有 SBFluidSwitcherGestureManager / SBMainWorkspace / SBIcon /
  FBScene 相关。**它为什么 hook SBMainWorkspace、它怎么保活托管进程，
  一概不知道。**
- 没有 iOS 16.5 的 SpringBoard / FrontBoard class-dump；下面所有
  “SpringBoard 里是这样”的说法，凡是没标“已核实”的，都是从参考实现
  （宿主是普通 App）外推到 SpringBoard 的推断，**必须真机验证**。
- 没有读过 SplitViewEverywhere 的源码（它是 iPad 专用、解锁 Split View，
  与 v5 的悬浮窗路线不是一回事；只确认了它的定位，不用它的代码）。
- 没有在真机上跑过任何一行 v5 代码——本文档全部是纸面设计。

---

## 2. §1 场景托管：怎么把第二个 App 的画面装进我们的悬浮窗

### 2.1 先建立正确的模型（这节是全文的基础）

iOS 上每个 App 的界面都跑在**自己的进程**里，SpringBoard（系统外壳）
并不画 App 的界面，它只**管理 scene**：哪个 App 在哪个 scene 里、
scene 多大、前台还是后台。FrontBoard 就是管这件事的框架。

托管一个 App 的 scene，意思不是“把 App 的代码搬进 SpringBoard”，而是：

1. 让系统把目标 App 的进程拉起来；
2. 以 SpringBoard（宿主）的名义，为这个进程建一个 **FBScene**；
3. 建一个 **presenter**，把 scene 的画面（远程图层，`_UIScenePresentationView`）
   嵌进我们悬浮窗的视图层级里。

画面是目标 App 自己的进程画的，通过跨进程图层（CAContext）送过来；
触摸点在 presenter 的 view 上，UIKit 的远程视图机制会把触摸送回目标
App 进程。**SpringBoard 进程里没有目标 App 的代码**——这一点决定了
v5 的崩溃面：我们调错 API 最多让自己的窗出不来或 SpringBoard 进安全
模式，但不会把目标 App 的进程搞坏；反过来，目标 App 自己的崩溃也只会
让窗变白，不会拖垮 SpringBoard（理论上，待真机验证）。

### 2.2 完整时序（按参考实现，方法名已核实）

下面是 `DecoratedAppSceneView` + `AppSceneViewController` 两段式流程，
用我们自己的话重述（不是抄代码，是抄步骤）：

**第 1 步——起进程（只在 App 没跑起来时做）：**

1. `RBSProcessIdentity identityForEmbeddedApplicationIdentifier:<bundleID>`
   ——给目标 App 建一个进程身份。
2. `RBSProcessPredicate predicateMatchingIdentity:identity`——用来事后
   找回这个进程。
3. `FBApplicationProcessLaunchTransaction initWithProcessIdentity:executionContextProvider:`
   ——建一个启动事务；provider block 里配一个
   `FBMutableProcessExecutionContext`：`identity` 填上，`environment` 为空
   字典，`launchIntent = 4`（**这个 4 是参考实现里的魔法数字，含义未核实**，
   不要改它，先照抄这个值，真机上再试别的）。
4. `[transaction begin]`，在 completion block 里继续第 2 步。
   （`FBProcessManager.sharedInstance launchProcessWithContext:` 是 provider
   内部调的，不用我们直接调。）

**第 2 步——拿到进程句柄并登记：**

5. `RBSProcessHandle handleForPredicate:error:`——拿到句柄，读 `pid`。
   `pid <= 0`（App 没起来）就直接返回、窗里显示“未启动”，不要继续建 scene。
6. `[FBProcessManager.sharedInstance registerProcessForAuditToken:handle.auditToken]`
   ——登记审计令牌，让 scene 系统信任这个进程。

**第 3 步——定义 scene：**

7. `sceneID = @"sceneID:<bundleID>-default"`——每个窗一个唯一 sceneID；
   多个窗开同一个 App 时，sceneID 必须不同（后面加 `-1`、`-2` 后缀，
   或拼一个随机 UUID；**不要复用同一个 sceneID 开两个窗**）。
8. `FBSMutableSceneDefinition definition`：
   - `identity = [FBSSceneIdentity identityForIdentifier:sceneID]`
   - `clientIdentity = [FBSSceneClientIdentity identityForProcessIdentity:handle.identity]`
     （注意：这里用的是**进程句柄的 identity**，不是 bundleID 那份；
     参考实现里两个地方写法不一样，以 `AppSceneViewController` 的版本为准。）
   - `specification = [UIApplicationSceneSpecification specification]`
9. `FBSMutableSceneParameters parametersForSpecification:specification`。

**第 4 步——配 scene 设置（决定窗里 App 长什么样）：**

10. `UIMutableApplicationSceneSettings`：
    - `foreground = YES`（托管的 scene 必须是前台的，否则 App 不画界面）
    - `frame` = 窗口内容区的大小（竖屏按宽高、横屏宽高互换）
    - `interfaceOrientation` = 竖屏；`deviceOrientation` = 当前设备方向
    - `displayConfiguration` = 主屏的 `displayConfiguration`
    - `level = 1`
    - `canShowAlerts = YES`
    - `persistenceIdentifier` = 随机 UUID（**每个窗都要新生成**，否则系统
      会把窗当成上次那个 scene 来恢复）
    - `statusBarDisabled = YES`（悬浮窗不画 App 自己的状态栏，留给
      SpringBoard 的状态栏；三屏钉住的原生窗才留状态栏）
    - `peripheryInsets` / `safeAreaInsetsPortrait` = 零（悬浮窗；参考实现
      注明“有些 App 不认这些值，所以顶部不遮”——意思是别指望 insets
      能挡住 App 顶栏，标题栏要我们自己画在窗外框上）
    - `cornerRadiusConfiguration` = 按窗口圆角建的
      `BSCornerRadiusConfiguration`（四个角都填窗的圆角值——floatingView
      设置里“浮窗圆角 35.0”滑条，调的就是这个）
    - `interruptionPolicy`：参考实现里注释掉了（值为 2 据信是“重连”），
      v5.2 先不填，留默认。
11. `UIMutableApplicationSceneClientSettings`：
    `interfaceOrientation` = 竖屏，`statusBarStyle = 0`。

**第 5 步——建 scene、建 presenter、嵌进去：**

12. `FBScene *scene = [[FBSceneManager sharedInstance] createSceneWithDefinition:definition initialParameters:parameters]`
13. `presenter = [scene.uiPresentationManager createPresenterWithIdentifier:sceneID]`
14. `[presenter modifyPresentationContext:^(UIMutableScenePresentationContext *c){ c.appearanceStyle = 2; }]`
    （appearanceStyle = 2 的含义未核实，是参考实现的做法，先照抄。）
15. `[presenter activate]`
16. `self.view = presenter.presentationView`——把 presenter 的 view 当成
    窗内容区的 view（或 `insertSubview:atIndex:0` 嵌进我们的内容区）。

**第 6 步——改尺寸与关窗：**

17. 改尺寸：`[scene updateSettingsWithBlock:^{ …改 frame / orientation… }]`
    （参考实现里防抖 50ms：拖动缩放时不要每次移动都调一次，等停下再调。）
18. 关窗：`[[FBSceneManager sharedInstance] destroyScene:<scene> withTransitionContext:nil]`
    ——**注意：`destroyScene:` 的第一个参数在参考实现的新旧两处写法不一致
    （一处传 scene 对象，一处传了个字符串 key），iOS 16.5 上到底传什么，
    必须 class-dump 核对，见 §6 第 7 条。** 然后
    `[presenter deactivate]; [presenter invalidate]; presenter = nil;`
    再把 view 从父视图移除。
19. 进程清理：**v5.2 关窗时只销毁 scene，不杀进程**（参考实现 README 也把
    “App 关窗后进程还跑着”列为已知问题）。杀进程（先 SIGTERM，3 秒后还
    活着再 SIGKILL）是后面的优化，而且杀之前必须先确认这个进程没有别的
    scene 在用（比如用户同时还开着这个 App 的全屏版），否则会把人家的
    全屏 App 也杀掉。

### 2.3 SpringBoard 当宿主，和参考实现有什么不同（关键推断，待真机验证）

参考实现是个**普通 App**（TrollStore 装的），它为了能托管 scene，
在 `main` 里先调了 `FBSystemShellInitialize(nil)`，又在 SceneDelegate 里
给自己的 scene 建了个 `UIRootWindowScenePresentationBinder`。**v5 不用
照抄这两步**，理由：

- SpringBoard 本身就是系统外壳，启动时已经跑过 `FBSystemAppMain`
  （崩溃日志里能看到 `FBSystemAppMain` 与 `+[FBSceneManager synchronizeChanges:]`
  的调用栈——这是已核实的公开崩溃日志内容），`FBSystemShellInitialize`
  的事系统已经替它做了。
- SpringBoard 自己的主屏 scene 早就绑好了，我们的悬浮窗是挂在主屏
  scene 上的普通 `UIWindow`（v4 已经是这么做的），不需要再为宿主建
  binder。**binder 是给“宿主自己的 scene”用的，不是给“被托管的 App
  scene”用的**——被托管的 scene 在 §2.2 里没有任何 binder 调用，
  只有 createScene + presenter。

还有一个对 v5 有利的点：参考实现是普通 App，它的 `FBSceneManager`
是它自己进程里的那一份；**我们的 tweak 跑在 SpringBoard 进程里，
`[FBSceneManager sharedInstance]` 拿到的就是系统那一份**——SpringBoard
平时就是用它来管所有 App 的 scene 的。所以 v5 不需要另起一个宿主进程，
也不需要 `SBMainWorkspace` 的事务（`requestTransitionWithOptions:` 那套
是 SpringBoard 自己启动 App 全屏版时走的流程，我们绕开它，直接调
FrontBoard）。**这是 v5 设计里最重要的一条：不 hook SBMainWorkspace、
不 hook SBApplication、不走 SpringBoard 的启动事务。**

但有一个反向风险必须写清楚：SpringBoard 的 scene 管理是**事务制**的
（`FBSceneManager synchronizeChanges`、workspace transaction）。我们在
事务之外直接 `createScene`，SpringBoard 自己的账本（哪个 App 在前台、
哪个 scene 归谁）并不知道这个 scene 的存在。可能出现的后果：

- 锁屏 / 按 Home 键时，SpringBoard 可能把托管 scene 的进程当成后台
  App 挂起（见 §6 第 4 条）；
- 内存紧张时，系统可能先杀托管 App 的进程（因为它在 SpringBoard 的
  账本里不是前台 App）；
- 极端情况下，SpringBoard 自己的 scene 清理可能把我们的 scene 一起清掉。

floatingView 的 hook 列表里有 SBMainWorkspace，很可能就是在处理这件事
（让 SpringBoard 的账本认下托管的 App）。**我们不知道它具体 hook 了
哪个方法、为什么**——这是 §6 里最值得 class-dump 的问题。v5.2 先不
hook，跑起来再看托管 App 会不会被挂起；如果会，再去查。

### 2.4 单场景 App 的限制（参考实现 README 原话的含义）

参考实现 README 的已知问题里有一条：“Single-scene apps may not work
yet. You may see empty window in such cases.”（单场景 App 可能还不行，
你可能会看到空窗。）

iPhone 上的多数 App 只声明一个 scene（`UIApplicationSupportsMultipleScenes`
没开）。对 v5 来说，这条限制要拆成两种情况：

- **App 没在跑（最常见）**：我们起进程、建 scene，这是它的**唯一**一个
  scene，App 照常接上去画界面——应该能工作。这是 v5.2 的主攻场景，
  测试时先杀掉目标 App 再开悬浮窗。
- **App 已经在前台/后台开着全屏版**：再建第二个 scene，单场景 App
  可能拒绝连接（SceneDelegate 不接第二个 session），窗里只剩白板。
  v5.2 的处理：开悬浮窗之前，先查目标 App 是不是已经有活着的 scene
  （经 `SBApplication` / `FBSceneManager` 的 scene 列表查，方法待
  class-dump 核对）；如果有，先提示用户“这个 App 已经开着，先关掉
  全屏版再开悬浮窗”，不要硬建第二个 scene。

floatingView 的录屏里，微信聊天窗是 live 的——微信在 iPhone 上也是单
场景 App，所以它一定是按上面第一种情况（微信没开全屏版，悬浮窗里的
就是它唯一的 scene）跑的，或者它有办法把已有的 scene 接管过来。
**接管已有 scene（把全屏版的 presenter view 抢过来嵌进悬浮窗）是
另一条更难的路，v5 不做**，先只做“App 没跑时建新 scene”。

### 2.5 参考实现的已知问题清单（v5 要逐项面对的）

照抄 FrontBoardAppLauncher README 的已知问题，逐项标 v5 的态度：

1. “Apps stay running even after closing”——v5.2 接受（关窗只销毁 scene，
   不杀进程），后面再优化。
2. “In-app keyboard offset may be off”——键盘偏移问题，见 §3。
3. “Keyboard doesn't work when windowed on top of SpringBoard yet”——
   **注意这句话**：参考实现（宿主是普通 App）承认，在 SpringBoard 上
   方开窗时键盘还不行。我们的宿主**就是** SpringBoard，情况不一样，
   可能更好也可能更坏——这是 §3 要解决的核心问题。
4. “Re-opening an app after closing may crash”——关窗后重开可能崩，
   与 sceneID / persistenceIdentifier 的复用有关；v5 每次建窗都用新的
   sceneID 与新的 persistenceIdentifier。
5. “Single-scene apps may not work yet”——见 §2.4。

---

## 3. §2 触摸与键盘：手点进去、字打进去

### 3.1 触摸（预期能直接工作，待真机确认）

presenter 的 view（`_UIScenePresentationView`）是远程视图：它本身是
我们窗里的一个普通 UIView，手指点在它上面，UIKit 的远程视图机制会把
触摸事件经 XPC 送回目标 App 进程，App 像正常一样响应。**不需要我们
额外转接触摸**（参考实现里没有任何触摸转发的代码）。

要注意的两点：

- 窗口层级：presenter 的 view 必须在窗内容区的最上层（`insertSubview:atIndex:0`
  是相对内容区而言的——标题栏、缩放手柄这些我们自己的控件要盖在它上面，
  否则点不到关闭按钮）。
- 点按置顶：参考实现的 `DecoratedFloatingView` 在 `touchesBegan` 里把自己
  `bringSubviewToFront`（注释里还写了个 FIXME：点到透传区域时置顶有问题）。
  v5 的窗管理器也要做“点哪个窗、哪个窗到最前”，办法是调各窗 `windowLevel`
  或 `makeKeyWindow`，不要用 `bringSubviewToFront` 去碰 presenter 的 view。

### 3.2 键盘：为什么会坏（已核实：同作者的研究手记）

这是 v5 最难的部分，根因已经有人挖出来了（LiveContainer 的研究手记，
gist 全文已读）：

系统里有个**键盘焦点仲裁器**（`_UIKeyboardArbiter`，在 SpringBoard 里由
`SBKeyboardFocusCoordinator` 协调）。它要决定键盘归谁——依据是一张
“可见性图”（visibility graph）：每个窗口都有一个环境字符串
（`_visibilityLock_windowEnvironment`），由
`_UIVisibilityPropagationInteraction._visibilityLock_didMoveToWindow:` 算出来：

- 窗口是 `_UIRootWindow` → 环境是 `UIRootWindow:<地址>`；
- 窗口是 `_UIHostedWindow` / `UIRemoteKeyboardWindow` /
  `_UITextEffectsWindowHosted` 或 `_isRemoteInputHostWindow` →
  用 `_UISVisibilityEnvironmentForUIHostedWindowContextID` 算；
- 其他窗口 → 取窗口的 `_fbsScene`，用它的 `FBSSceneIdentityToken`
  算 `UIScene:<token>`。

仲裁器靠这个环境字符串找到“键盘应该给谁”。托管 scene 的窗如果不在这张
图里、或环境字符串不对，SpringBoard 就找不到它、不会把焦点交过去——
**键盘弹不出来，或者弹出来字打不进去**。这就是为什么 floatingView
要配一个键盘辅助 dylib（注入 `UIKeyboardImpl` 所在的进程），以及为什么
参考实现承认“在 SpringBoard 上方开窗时键盘还不行”。

### 3.3 键盘的三档修法（按“从轻到重”排，iOS 16.5 上没有干净修法）

**第一档（先试，不用 hook）：什么都不做，先测。**
我们的宿主就是 SpringBoard，仲裁器与可见性图都在 SpringBoard 进程里，
我们的窗是 SpringBoard 的窗、挂在主屏 scene 上，`_fbsScene` 能取到主屏
scene 的 token，环境字符串大概率是合法的 `UIScene:<token>`。有可能键盘
直接就能用——这是 v5.2 要测的第一件事：点微信聊天窗的输入框，看键盘
弹不弹、字进不进得去。

**第二档（如果第一档不行，hook 一个方法）：`RBSTarget` 的 hook。**
参考实现的做法：hook `+[RBSTarget targetWithPid:environmentIdentifier:]`，
把环境标识里含 `LiveProcess` 的改写成 `LiveProcess:<pid>`。原理是
presenter 的 view 初始化时会调这个方法拿目标（target），改写后的标识
能让仲裁器找对进程。代价：这是一个 hook（`method_exchangeImplementations`
换实现），但它只改一个字符串、不碰 SpringBoard 的私有类，风险比
SBMainWorkspace 的 hook 小得多。**注意：参考实现里的 `LiveProcess` 是
LiveContainer 自己的环境名前缀，我们的场景里标识长什么样，要真机上
打日志看过才知道，不能照抄 `LiveProcess` 这几个字。**

**第三档（如果第二档不行，伪装窗口类型）：假装自己是 `_UIRootWindow`。**
LiveContainer 最早的修法：hook `UIWindow.isKindOfClass:`，让自己的窗
对 `_UIRootWindow.class` 的判断返回 YES，环境字符串就变成
`UIRootWindow:<地址>`，仲裁器能找到它。但手记里写明了副作用：
“App 在后台会停掉音频播放”（因为系统以为这个窗是根窗，改了它的
生命周期判断）。**这是最后的手段，能不用就不用。**

另外还有一条“关掉可见性传播”的路（hook
`UIScenePresentationContext._isVisibilityPropagationEnabled` 返回 NO），
手记里写明了“还是会有副作用，所以又把它开回来了”——**v5 不用这条**。

**iOS 17.4+ 的干净修法在 iOS 16.5 上不存在**，这里必须说清楚：手记的
更新部分写道，正确修法是改用 `_UISceneHostingSceneSpecification` 建
scene（它自带 `_UISceneHostingEventDeferringExtension` 与
`_UIApplicationSceneKeyboardExtension`，`UIApplicationSceneSpecification`
里没有这两个扩展，所以键盘焦点会断）。但 `_UISceneHostingSceneSpecification`
是 iOS 17.0+ 才有的类，iOS 16.5 上没有。**所以 v5 在 iOS 16.5 上只能用
第一、二、三档，没有第四档。**

### 3.4 键盘辅助 dylib 与 mediaserverd 辅助 dylib（floatingView 的做法，我们的态度）

floatingView 配了两个辅助 dylib（公开元数据，已核实）：

- **键盘 dylib**：注入过滤器是类 `UIKeyboardImpl`——也就是说它注入到
  **每一个**会弹键盘的进程里（包括被托管的 App 进程），修键盘在悬浮窗
  里的表现。推测（未核实）它在调键盘窗口的层级/位置（比如
  `windowingModeEnabled` 之类），或修键盘焦点。**v5 不先做这个**：
  先测第一档；不行再上第二档；键盘辅助 dylib 是 5.3 之后的事，而且
  它的过滤器写法（按类注入所有进程）风险高，要单独评估。
- **相机 dylib**：注入过滤器是可执行文件 `mediaserverd`——相机与音视频
  播放跑在 mediaserverd 进程里。推测（未核实）它在修托管 App 里相机预览
  或视频播放的方向/画面。**v5 不做这个**：5.2 的测试 App 避开相机与视频
  播放；如果以后发现悬浮窗里视频黑屏或相机打不开，再立项。

---

## 4. §3 边缘滑动触发与贴边小窗（不 hook 私有手势方法）

### 4.1 触发：我们自己的 `UIScreenEdgePanGestureRecognizer`

floatingView 是边缘滑动触发（皇上 2026-11-12 确认：“屏幕边缘滑”），
它的“调度窗口设置”里写着“自定义侧边小窗位置、手势”。v5.1 照这个做，
但**不用 hook `SBFluidSwitcherGestureManager`**（v3 刻意避开它，就是因为
它的私有方法签名在 iOS 16.5 上没核对过，贸然 hook 就是下一个安全模式）。

做法（全部公开 UIKit）：

1. 建一个**透明的边缘条窗口**：宽 12pt、高满屏，贴在屏幕左边缘（或右边缘，
   设置里可换），`windowLevel` 与触发按钮窗同级（`UIWindowLevelStatusBar + 10`），
   背景全透明，平时不挡任何东西。
2. 在这个条窗的根视图上挂一个 `UIScreenEdgePanGestureRecognizer`，
   `edges` 设为要触发的那一边（`UIRectEdgeLeft` 或 `UIRectEdgeRight`），
   识别到就打开侧边小窗（App 列表）。
3. 手势识别器要设 `delegate`，允许与系统手势同时识别
  （`gestureRecognizer:shouldRecognizeSimultaneouslyWithGestureRecognizer:`
   返回 YES），否则会抢掉系统手势；同时只在“手势从屏幕最边缘开始”
   时才响应——`UIScreenEdgePanGestureRecognizer` 本身就只认从边缘
   起手的手势，这正是用它而不是普通 `UIPanGestureRecognizer` 的原因。

**冲突分析（诚实写出来）：**

- 左边缘滑动：iPhone 上多数 App 用左边缘右滑做“返回”，我们的条窗
  如果常驻左边缘，会抢掉前台 App 的返回手势。**v5.1 默认用右边缘**，
  或只在主屏（没有前台 App）时启用条窗；设置里给用户换边。
  floatingView 的“自定义侧边小窗位置、手势”就是在处理同一个冲突，
  我们照这个思路做。
- 底部边缘不要碰：Home Indicator 的上滑（回主屏）与控制中心都在底部，
  抢了会出大事。
- 锁屏时不要触发：条窗只在 SpringBoard 解锁、主屏或 App 前台时启用；
  锁屏状态下（`SBLockStateAggregator` 的状态，或更简单：前台 App 是
  SpringBoard 且未锁定时）才挂手势。**不要为了判断锁屏去 hook
  SBLockStateAggregator**——v4 已经证明“不 hook 也能活”，锁屏判断
  先用“当前前台 scene 是不是主屏 scene + 屏幕已解锁”的公开办法拼，
  拼不出来就先只在主屏启用，锁屏误触是小问题、抢系统手势是大问题。

v4 的金色“分”字按钮在 5.1 里**保留**（当备用触发方式），边缘滑动是
新增的触发方式，两者并存，不互相替代。

### 4.2 侧边小窗（调度窗口）：从边缘滑出来的 App 列表

从边缘滑进来后，出现的是一个**侧边小窗**：窄条（约 100–120pt 宽），
贴着滑入的那一边，里面是 App 列表（图标 + 名字，竖排）。点一个 App，
就在小窗旁边（或小窗的位置）开出悬浮窗；再滑一次（或点窗外）收起。

实现上，侧边小窗就是 v4 启动器的变体：同样是 `UIWindow` + 列表，
只是位置贴边、宽度变窄、从边缘滑入有动画。App 列表复用 v4 的后台枚举
+ 缓存（`GHLSSFetchUserApps` / `GHLSSCachedApps`），不要重写。

### 4.3 贴边收起（mini 窗）：窗不要关，要“收到边上”

floatingView 录屏里，屏幕右侧边缘贴着几个小窗（窄条，只露一部分内容）。
做法：

- 窗被拖到屏幕边缘（或点标题栏的收起钮）时，**不要销毁 scene**，
  只把窗移出屏幕、留一个 24pt 宽的抓手（tab）在边缘；scene 的 frame
  **保持原样不变**——App 不用重新布局，只是被窗的 `masksToBounds`
  裁掉了。点抓手，窗滑回来。
- 这样做的好处：收起/展开只是改窗的 `center`，不调
  `updateSettingsWithBlock:`，不惊动目标 App，风险最小。
  坏处：收起来的 App 还在前台跑（占内存、占 CPU），与参考实现“关窗后
  进程还跑着”是同一个取舍——v5 接受。
- 真正的“关窗”（标题栏 ✕）：按 §2.2 第 18 步销毁 scene、去 presenter，
  进程留着。

### 4.4 窗口外框（标题栏 + 缩放，照参考实现的做法）

每个悬浮窗的外框（参考实现 `DecoratedFloatingView` 的做法，我们自己重写）：

- 顶部 44pt 标题栏：App 名 + 关闭钮；**拖标题栏移动窗口**
  （`UIPanGestureRecognizer`，单指），不要用 v4 按钮那种 touches 回调
  （标题栏够大，手势识别器够用；v4 按钮小才用 touches）。
- 右下角 60×60 缩放手柄：拖动改窗大小（最小 50×50 的下限要放大到
  手机上能用的尺寸，比如最小 200×300）；改完尺寸后调
  `updateSettingsWithBlock:` 改 scene 的 frame（防抖 50ms，见 §2.2）。
- 圆角：窗口 `layer.cornerRadius` 与 scene 的
  `cornerRadiusConfiguration` 用同一个值（默认 35，对齐 floatingView
  设置里的 35.0；设置里给用户调）。
- 点按置顶：点哪个窗，哪个窗到最前（调 `windowLevel` 或
  `makeKeyAndVisible`，不要动 presenter 的 view）。

---

## 5. §4 分步计划（每步只做一件事，测完再上下一步）

总原则（v1/v3/v4 的教训）：**每步只加一个新风险点；每步的测试都有
“通过标准”，不过就停在那一步修，不往下堆功能。** 开关默认 OFF 不变；
每步的 .deb 都要像 v4 那样完整校验（`dpkg-deb -I/-c`、SHA256、strings
核对、Root.plist 默认 False）；**每步都不部署，等皇上点头。**

### 5.1（v5.1）：边缘滑动 + 侧边小窗启动器——不碰 scene

- **做什么**：边缘条窗 + `UIScreenEdgePanGestureRecognizer`（默认右边缘，
  设置里可换左/右/关）；从边缘滑入打开侧边小窗（App 列表，图标用
  `UIImage _applicationIconImageForBundleIdentifier:format:scale:`，
  这是 v4 留下的图标缺口，5.1 顺手补上）；点 App 仍是**全屏打开**
  （复用 v4 的 `openApplicationWithBundleID:`），不建 scene；金色“分”
  字按钮保留当备用触发。
- **不做什么**：不建 scene、不调 FrontBoard、不 hook 任何东西。
- **改哪些文件**：`Tweak.xm`（新增边缘条窗与手势；侧边小窗用 v4 启动器
  改窄版）、`prefs`（加“触发边缘：左/右/关”与“侧边小窗”开关）。
- **崩溃风险：低。** 新增的只是公开 UIKit（手势识别器 + 透明窗），
  与 v4 的悬浮按钮同级。最大的风险是抢系统手势（§4.1），不是崩溃。
- **皇上测试（通过标准）**：
  1. 装完 respring，手机正常启动（开关关着时与没装一样）；
  2. 开开关、respring，从右边缘滑入，侧边小窗出现（App 列表带图标）；
  3. 在微信里从右边缘滑入——**不应该**抢掉微信的返回/手势（右边缘
     本来就没什么手势，重点是别让微信卡住）；
  4. 点一个 App，全屏打开；再滑一次，侧边小窗收起。
  - 任何一步卡住/进安全模式：卸载，告诉主代理是哪一步。

### 5.2（v5.2）：一个托管 App 窗——v5 的硬核，第一只白鼠

- **做什么**：在 5.1 的基础上，点 App 不再全屏打开，而是按 §2.2 建
  scene + presenter，嵌进悬浮窗（带标题栏与缩放手柄，见 §4.4）；
  先只支持**一个**悬浮窗；关窗只销毁 scene、不杀进程。
- **先测哪个 App**：先测**计算器**（`com.apple.calculator`，简单、无账号、
  无后台同步），再测**时钟**，最后才测**微信**。**不要第一个就测微信**：
  微信有账号状态、后台同步、支付相关进程，变量太多。测试前先把目标
  App 彻底关掉（后台划掉），保证它没在跑、没有已有的 scene（见 §2.4）。
- **不做什么**：不做多窗、不做贴边收起、不做键盘辅助 dylib、不做
  mediaserverd 辅助、不 hook SBMainWorkspace。
- **改哪些文件**：新增 `GHLSSHostedAppWindow`（窗 + presenter 管理）、
  `GHLSSSceneHost`（建 scene 的流程，§2.2 的 1–16 步）、最小私有接口
  声明头文件（附录 A）；`Tweak.xm` 的启动器点选改成“建悬浮窗”而不是
  “全屏打开”（全屏打开保留当 fallback：建 scene 失败时回退到全屏打开，
  并记日志）。
- **崩溃风险：高。** 这是第一次在 SpringBoard 进程里调
  `FBSceneManager createSceneWithDefinition:`，可能的结果按坏的程度排：
  1. scene 建不出来（返回 nil 或抛异常）→ 窗里空白，SpringBoard 不崩
     （最可能，也是最好的坏结果）；
  2. App 进程起不来 → 窗里空白 + 目标 App 打不开（重启目标 App 就好）；
  3. SpringBoard 进安全模式（某个设置字段 iOS 16.5 不认、或
     `createScene` 在 SpringBoard 里有前置条件）→ 在安全模式下关开关、
     卸载，等主代理修；
  4. 目标 App 的 scene 建出来了但画面不更新（presenter 没激活或设置
     差量没转发）→ 窗里定格在开屏画面。
  每一步都要包在 `@try/@catch` 里、失败只记日志，**绝不能让一次
  建 scene 失败拖垮 SpringBoard**（v4 的教训：任何一步失败只记日志、
  不让 SpringBoard 崩）。
- **皇上测试（通过标准）**：
  1. 先确认开关是关的（v1 残留 prefs 的教训，见 BUILD_LOG.md §10.2(a)），
     装完 respring，手机正常启动；
  2. 开开关、respring，从边缘滑入，点**计算器**：悬浮窗里出现活的计算器，
     点数字键有反应、能算出结果；
  3. 拖标题栏移动窗口、拖右下角缩放窗口，计算器跟着变大变小、不白屏；
  4. 点 ✕ 关窗，计算器进程留着也没关系，再点一次能重新打开；
  5. 点微信聊天窗的输入框：**键盘能不能弹出来、字打不打得进去**——
     这一步的结果直接决定 §3 要不要上第二档修法（先只报结果，不要自己
     改设置）。
  - 任何一步卡住/进安全模式/白苹果：卸载，告诉主代理是哪一步、当时
    屏幕什么样，并尽量保留崩溃日志（设置 → 隐私与安全性 → 分析与改进
    → 分析数据，找 `SpringBoard-` 开头的条目）。

### 5.3（v5.3）：多窗 + 贴边收起 + 点窗外收起

- **做什么**：窗管理器（每个窗一个 sceneID、一个 presenter、一个
  `UIWindow`；点哪个窗哪个到最前）；贴边收起（§4.3，scene 帧不变，
  只移窗）；点窗外收起（设置里可开关，对齐 floatingView 的“点击浮窗
  外部事件”）；圆角/阴影/刘海安全距离设置（对齐 floatingView 的
  浮窗设置页：圆角默认 35、安全距离默认 50、靠太近自动回弹）。
- **不做什么**：不做三屏、不做 ARC 菜单、不做键盘/mediaserverd 辅助 dylib。
- **崩溃风险：中高。** 多窗的变量是 scene 之间的干扰（一个窗的设置更新
  别串到另一个窗）、贴边收起时 scene 的前台状态（收起来的窗算不算前台？
  App 会不会被挂起？）、点窗外收起时误触（透明背景窗抢了主屏的点按）。
  每加一个窗，SpringBoard 的 scene 账本就多一笔，风险线性上升——
  **先只测两个窗**（计算器 + 时钟），再加到三个。
- **皇上测试（通过标准）**：
  1. 开两个悬浮窗（计算器 + 时钟），两个都能点、都能算/能走；
  2. 把一个窗拖到右边缘收起（只剩抓手），再点抓手滑回来，里面的 App
     还活着、不用重开；
  3. 点窗外空白，窗收起（如果设置里开了这项）；
  4. 关掉其中一个窗，另一个不受影响。

### 5.4（展望，不进 v5）：三屏 + ARC 菜单

- **三屏**：左右两边各钉一个小窗（§4.3 的贴边收起升级版：收起的窗
  不是缩成抓手，而是以小窗形态钉在左右两边，带工具栏排序与 App 排序，
  对齐 floatingView 的三屏设置页）。技术上与 5.3 同一套东西，只是位置
  与尺寸策略不同——等 5.3 稳了再做。
- **ARC 菜单**：扇形/弧形启动器（floatingView 的 FVArcLayout 那一路）。
  纯 UI 工作，不碰 scene，等 5.3 稳了再做。
- **键盘/mediaserverd 辅助 dylib**：只有当 5.2/5.3 的测试证明“没有它
  就不行”时才立项；立项前先单独评估注入过滤器的风险（键盘 dylib 是
  按类注入所有进程，面很广）。

---

## 6. §5 未解问题清单（只有真机或 class-dump 能回答）

按“最先堵住 v5.2”的顺序排：

1. **`FBSceneManager sharedInstance` 在 SpringBoard 进程里能不能直接
   `createSceneWithDefinition:`？** 参考实现是在普通 App 里做的；
   SpringBoard 是系统外壳，按理更能做，但没验证过。**堵住 5.2 的第一
   个问题。** 验证办法：5.2 里先建一个计算器 scene，看返回是不是 nil、
   SpringBoard 崩不崩。
2. **要不要 `FBSystemShellInitialize` 或 `UIRootWindowScenePresentationBinder`？**
   推断是不用（SpringBoard 启动时已经做过了），但没验证过。如果
   createScene 返回 nil 或 presenter 激活失败，先查这两个。
3. **单场景 App 已有全屏 scene 时，再建第二个 scene 会怎样？**
   空白窗？崩溃？还是自动复用已有 scene？验证办法：微信开着全屏版时
   再开微信悬浮窗，看结果。**在答案出来之前，5.2 只测“App 没在跑”的
   情况。**
4. **托管 App 的进程会不会被 RunningBoard 挂起/杀掉？**
   scene 的 `foreground = YES` 够不够，还是要向 SpringBoard 登记
   （可能要 hook SBMainWorkspace 的某个方法）？验证办法：开微信悬浮窗，
   放着 5 分钟不用，再点它，看还活着没有、消息还收不收得到。
5. **键盘能不能用？**（见 §3.3：先测第一档；不行再看第二档要 hook
   `RBSTarget` 的哪个标识；第三档是最后手段。）
6. **触摸能不能直接工作？** 预期能（presenter view 自动转发），但
   没验证过。验证办法：5.2 里点计算器数字键。
7. **`destroyScene:` 第一个参数到底传什么？** 参考实现新旧两处写法
   不一致（scene 对象 vs 字符串 key）。验证办法：class-dump iOS 16.5
   的 FrontBoard，看 `FBSceneManager` 的方法签名。
8. **旋转怎么办？** 托管 scene 跟不跟随设备旋转？参考实现靠
   `_registerSettingsDiffActionArray:forKey:` 把宿主 scene 的设置差量
   转给托管 scene；在 SpringBoard 里，这个注册要挂在主屏 scene 上，
   转发的对象是谁、差量从哪来，都要真机上试。5.2 先只测竖屏，旋转是
   5.3 的事。
9. **相机/视频/音频在悬浮窗里能不能用？** 需不需要 mediaserverd 辅助
   dylib？5.2 的测试 App 避开这些；5.3 再测微信视频通话、汽水音乐播放。
10. **floatingView 为什么 hook SBMainWorkspace？** 只知道它 hook 了，
    不知道为什么。最可能的两个猜测：(a) 让 SpringBoard 的账本认下托管
    的 App（对应第 4 条）；(b) 拦截正常启动流程、把 App 导进悬浮窗。
    验证办法：class-dump iOS 16.5 的 SpringBoard，看 `SBMainWorkspace`
    里与 scene 创建/前台 App 相关的方法，再结合我们的测试现象对号入座。
    **在答案出来之前，v5 不 hook SBMainWorkspace。**
11. **建 scene 要不要特殊 entitlement？** 参考实现提到
    `com.apple.backboard.client`。SpringBoard 几乎肯定有，但没法在本机
    核实（SDK 里没有 SpringBoard 的二进制）。如果 createScene 在真机上
    报权限错，再回头查。
12. **`launchIntent = 4` 与 `appearanceStyle = 2` 到底是什么意思？**
    两个都是参考实现里的魔法数字，含义未核实。5.2 先照抄；如果建 scene
    出问题，再试别的值（并记下来哪个值管用）。

**class-dump 怎么做（给 v5.2 之前准备）：** 需要 iOS 16.5 的
SpringBoard 与 FrontBoard 的头文件。两条路：(a) 在皇上的手机上
（越狱后）用 class-dump 工具直接导 SpringBoard.app 与
FrontBoard.framework 的头文件；(b) 找公开的 iOS 16.5 运行时头文件
dump（GitHub 上有多个版本，**必须核对版本号是 16.5**，别拿 17.x 的
头文件来写 16.5 的代码）。拿到头文件后，重点看
`FBSceneManager`、`FBScene`、`SBMainWorkspace`、`SBApplication`、
`SBSceneManager`（如果存在）的方法签名。

---

## 附录 A：最小私有接口清单（v5.2 要声明的，按框架分）

只列类名与方法名（来自开源参考实现的头文件，已核实；**不要抄参考
实现的代码，只抄接口名——接口名是事实，不是表达**）：

- **FrontBoard**（链接 `FrontBoard.framework`，`.tbd` 已核实有导出）：
  `FBSceneManager`（`+sharedInstance`、`-createSceneWithDefinition:initialParameters:`、
  `-destroyScene:withTransitionContext:`）、`FBScene`
  （`-uiPresentationManager`、`-updateSettings:…`、
  `-updateSettingsWithBlock:`）、`FBProcessManager`（`+sharedInstance`、
  `-launchProcessWithContext:`、`-registerProcessForAuditToken:`）、
  `FBApplicationProcessLaunchTransaction`
  （`-initWithProcessIdentity:executionContextProvider:`）、
  `FBMutableProcessExecutionContext`（`identity`、`environment`、
  `launchIntent`）、`FBScene` 的 `settings`。
- **FrontBoardServices**（链接 `FrontBoardServices.framework`）：
  `FBSMutableSceneDefinition`（`+definition`、`identity`、`clientIdentity`、
  `specification`）、`FBSSceneIdentity`（`+identityForIdentifier:`）、
  `FBSSceneClientIdentity`（`+identityForProcessIdentity:`、
  `+localIdentity`）、`FBSMutableSceneParameters`
  （`+parametersForSpecification:`、`settings`、`clientSettings`）、
  `FBSSceneSpecification`（`+specification`）。
- **RunningBoardServices**（链接 `RunningBoardServices.framework`）：
  `RBSProcessIdentity`（`+identityForEmbeddedApplicationIdentifier:`）、
  `RBSProcessPredicate`（`+predicateMatchingIdentity:`）、
  `RBSProcessHandle`（`+handleForPredicate:error:`、`-auditToken`、`-pid`、
  `-identity`）。
- **UIKit / UIKitCore**（`_UIScenePresenter` 等在 `UIKitCore.tbd` 已核实有导出）：
  `UIScenePresentationManager`（`-createPresenterWithIdentifier:`）、
  `_UIScenePresenter`（`-modifyPresentationContext:`、`-activate`、
  `-deactivate`、`-invalidate`、`presentationView`、`scene`）、
  `UIMutableApplicationSceneSettings`（`canShowAlerts`、`foreground`、
  `frame`、`interfaceOrientation`、`deviceOrientation`、`level`、
  `persistenceIdentifier`、`peripheryInsets`、`safeAreaInsetsPortrait`、
  `cornerRadiusConfiguration`、`displayConfiguration`、`statusBarDisabled`）、
  `UIMutableApplicationSceneClientSettings`（`interfaceOrientation`、
  `statusBarStyle`）、`UIApplicationSceneSpecification`（`+specification`）、
  `BSCornerRadiusConfiguration`
  （`-initWithTopLeft:bottomLeft:bottomRight:topRight:`）、
  `UIScene` 的 `_registerSettingsDiffActionArray:forKey:` /
  `_unregisterSettingsDiffActionArrayForKey:`、`_UISceneSettingsDiffAction`
  协议（`_performActionsForUIScene:…`）。
- **已有（v4 在用，不用新声明）**：`LSApplicationWorkspace`
  （`defaultWorkspace`、`allInstalledApplications`、
  `openApplicationWithBundleID:`）、
  `UIImage _applicationIconImageForBundleIdentifier:format:scale:`
  （启动器图标，5.1 用）。

写法：像 v4 一样，**能用 `NSClassFromString` + `objc_msgSend` 的就用
运行时查找**（最稳，不依赖链接）；链接失败时再退到直接引用类
（`.tbd` 已核实导出这些类，链接本身应该能过）。

## 附录 B：构建注意事项（v5.2 动手前必读）

- Makefile：`GuHaiLongSplitScreen_PRIVATE_FRAMEWORKS = FrontBoard FrontBoardServices RunningBoardServices`，
  再加 `UIKit`（已有）。**不要**把整个 SpringBoard 框架链进来。
- 构建仍在 `/tmp` 做（ldid 在 workspace 的 overlayfs 上失败，见
  BUILD_LOG.md §3）；`umask 022`；prefs 的 `Root.plist` 在
  `prefs/Resources/`；Makefile 注释只用 `#`（v4 的教训：`//` 会报
  `missing separator`）。
- 废弃 API 当错误：不要用 `keyWindow`（v3 的教训），用
  `connectedScenes` 取 scene。
- 新文件建议：`GHLSSSceneHost.m/.h`（建 scene 的流程）、
  `GHLSSHostedAppWindow.m/.h`（窗 + presenter + 外框）、
  `GHLSSPrivateInterfaces.h`（附录 A 的最小声明）；`Tweak.xm` 只留
  开关、通知与窗管理，不要把建 scene 的代码全塞进 `Tweak.xm`。
- 校验清单（沿用 v4 的）：`dpkg-deb -I/-c`、SHA256、strings 核对
  （新增：必须**没有** `medusaCapabilities`、`isMedusaCapable`、
  `iconAllowsLaunch`、`wantsFullScreen`、`wantsExclusiveForeground`、
  `SBMainWorkspace`、`SBApplication`、`SBFluidSwitcherGestureManager`
  这些符号——v5 还是不碰它们；必须**有** `createSceneWithDefinition`、
  `FBSceneManager`、`_UIScenePresenter` 这些符号）、Root.plist 默认 False。
- 每次建 scene、每次 presenter 激活/销毁、每次进程启动失败，
  都要写日志（`NSLog(@"[GuHaiLongSplitScreen] …")`），格式与 v4 一致，
  方便皇上出问题时报日志。

## 附录 C：参考资料（都已实际读过，不是只列名字）

- FrontBoardAppLauncher（Apache-2.0）——`khanhduytran0/FrontBoardAppLauncher`，
  2026-11-12 克隆到 `/tmp/fbal` 读过 `AppSceneViewController.m`、
  `DecoratedAppSceneView.m`、`UIKitPrivate+MultitaskSupport.h`、
  `DecoratedFloatingView.m`、`LauncherViewController.m`、`Hooks.m`、
  `SceneDelegate.m`、`main.m`、`README.md`。
- LiveContainer 多任务键盘研究——gist `khanhduytran0/504b16d86a2091e676c412bd0a517306`
  （2026-11-12 读过全文 867 行）。
- LiveContainer 多任务实现（DeepWiki 摘要）——与 FrontBoardAppLauncher
  同一套代码（`AppSceneViewController`、`DecoratedAppSceneView`）。
- 皇上的录屏与截图（2026-11-12）：floatingView 设置页（启用/三屏设置/
  ARC 设置/浮窗设置/其他杂项功能/操作性功能）、浮窗设置页（阴影/通知横幅/
  竖屏固定中心/圆角 35.0/刘海安全距离 50.0/键盘设置/调度窗口设置/
  点击外部事件）、三屏设置页（选择应用/工具栏排序/App 排序/关闭三屏同时
  关闭侧边小窗/小窗显示位置左/右）、18.6 秒录屏（微信搜索、微信聊天
  花·海、汽水音乐各在圆角悬浮窗里，右侧边缘有贴边小窗）。
- TrollPad（Duy Tran Khanh）——只确认了定位：它是改 MobileGestalt
  能力位、让 iPhone 用 iPad 多任务（Stage Manager / Split View）的路子，
  与 v5 的 FrontBoard 路线不是一回事；v1 已证明 medusa 路在皇上的手机
  上进安全模式，所以 v5 不用它。
- SplitViewEverywhere（ETHN）——只确认了定位：iPad 专用，解锁所有 App
  的 Split View / Slide Over；与 v5 的悬浮窗路线不是一回事。
- 本机 iPhoneOS16.5.sdk 的 `.tbd` 符号核查（2026-11-12，见 §1.3）。
- 项目内：`BUILD_LOG.md` §8（v2）、§9（v3）、§10（v4 诊断）、
  `Tweak.xm`（v4，1.0.3，无 hook 的悬浮窗壳）。
