# 顾海龙集团分屏 — GuHaiLongSplitScreen v1.0.24（实验版 v24）

原创 iOS 越狱分屏插件，包名 `com.guhailong.splitscreen`。

## v24 是什么（5.2：悬浮窗里打开 App）

v23 真机：按钮看得见、启动器能开能关，但点 App 会卡 5 秒以上、
App 全屏打开、手机随后自己重启。日志证明两件事：系统打开 App 的
方法在 SpringBoard 里根本打不开 App（四次全失败，ok=0），而那个
同步调用把主线程堵了 5 秒以上，触发看门狗把 SpringBoard 重启了。
v24 修掉这三个缺点：

- 点 App 时**先收启动器，再异步启动**——主线程绝不被启动堵住；
- 启动只走 **FBProcessManager + FBApplicationProcessLaunchTransaction**
  （SpringBoard 这边的正路），再经 **FBSceneManager** 建 scene、
  用 **\_UIScenePresenter** 把 App 的画面嵌进悬浮窗；
- 悬浮窗照 floatingView 的样子：圆角 35、带阴影、320x480、44pt
  标题栏可拖动、红关闭钮、黄最小化钮、右下角缩放手柄；一次只开
  一个悬浮窗；每一步都记日志，任何一步失败只记日志、不拖垮
  SpringBoard；场景结构仿 FrontBoardAppLauncher（Apache-2.0），
  代码是原创。

测前先把计算器彻底关掉（在 App 切换器里划掉），不然 scene 可能
只剩白窗。键盘不在 v24 做（计算器不用键盘；iOS 16.5 没有干净的
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
