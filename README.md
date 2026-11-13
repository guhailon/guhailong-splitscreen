# 顾海龙集团分屏 — GuHaiLongSplitScreen v1.0.31（实验版 v31）

原创 iOS 越狱分屏插件，包名 `com.guhailong.splitscreen`。

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
