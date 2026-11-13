# BUILD_LOG — 顾海龙集团分屏 v1.0.0 / v1.0.1 构建记录

> **更新（v3，2026-11-12）：v2（1.0.1）已于 2026-11-12 14:48 部署到线上 v8，
> 等皇上真机测试。v3（1.0.2）已按皇上给的 floatingView 成品参考改走悬浮窗
> 路线、一次编过、本地源已更新为 v3（v9 待部署），改动与校验见下面第 9 节。
> v1.0.0 不要再装。**
>
> v1 结论先行：**.deb 真的编出来了**，`dpkg-deb -I / -c` 校验通过，
> 已放进本地越狱源（14 个包，见下）。但**未在真机验证**——分屏入口
> 是否真的出现，只有皇上在 iPhone 11 / iOS 16.5 / Dopamine 上装了才知道。

## 目标（定死，2026-11-12 皇上确认）

- 机型：iPhone 11；系统：iOS 16.5；越狱：Dopamine（rootless）
- 包名：`com.guhailong.splitscreen`，版本 1.0.0，`iphoneos-arm64`
- 架构：`arm64 / arm64e`；SDK：iPhoneOS 16.5；`TARGET iphone:clang:16.5:15.0`
- 形态：真左右分屏（iPad 式 Split View），不是悬浮窗

## 1. 本机环境实测（2026-11-12，Ubuntu 24.04.5 LTS，root）

```
uname: Linux htch-runtime 7.0.0-44-generic x86_64
clang: MISSING（初始）  gcc: /usr/bin/gcc 13.3.0  make/perl/git/curl/wget: 有
dpkg-deb / dpkg-scanpackages: 有  ldid: MISSING  theos: MISSING  THEOS: 未设置
~/theos、/opt/theos、~/sdks：均不存在
```

- `apt-get update`：第一次 15 秒超时只拉到部分索引；第二次完整跑
  超过 10 分钟无输出（azure 源极慢），后直接停掉，未再依赖 apt。
  随后 `apt-get install -y clang libplist-utils fakeroot` 报错：
  `E: Unable to locate package clang` / `libplist-utils` /
  `Package 'fakeroot' has no installation candidate`。
  结论：**apt 这条路走不通，改走 GitHub 直链下载**（见第 2 节）。

## 2. 工具链与 SDK（直链下载，全部成功）

- Theos：`git clone --depth 1 https://github.com/theos/theos.git ~/theos`
  - 注意：`--depth 1` 不带子模块，`vendor/dm.pl` 等是空的，
    构建时报 `make package requires dm.pl`；后补
    `git -C ~/theos submodule update --init --recursive` 解决。
- iOS 交叉工具链：L1ghtmann/llvm-project 最新版
  `iOSToolchain-x86_64.tar.xz`，解到 `~/theos/toolchain/`。
  含 clang 11.1.0、ldid / ldid2、lipo、install_name_tool、codesign_allocate。
  `clang --version`：`clang version 11.1.0 (https://github.com/L1ghtmann/llvm-project ...)`。
  解压时有 `tar: Cannot change ownership to uid 1001 ... Operation not permitted`
  警告（tar 想还原原属主），文件本身完整，不影响使用。
- SDK：`THEOS=~/theos ~/theos/bin/install-sdk iPhoneOS16.5`
  （theos/sdks 发布页确有 `iPhoneOS16.5.sdk.tar.xz`），
  解到 `~/theos/sdks/iPhoneOS16.5.sdk`（222 MB，Frameworks 齐全）。
  同样有 chown 警告，内容完整。

## 3. 构建尝试（按顺序，失败的也如实记）

构建命令（成功那次）：
```
export THEOS=$HOME/theos
cd /tmp/ghlss-build   # 见第 4 节：必须在 /tmp 构建
umask 022 && make package FINALPACKAGE=1 THEOS_PACKAGE_SCHEME=rootless
```

- **第 1 次（workspace 内）：** `Error: make package requires dm.pl.`
  原因：Theos 子模块没拉。修好子模块后通过。
- **第 2 次：** 编译通过，链接失败：
  `Undefined symbols for architecture arm64/arm64e: "__Z15MGGetBoolAnswerPK10__CFString"`。
  原因：`Tweak.xm` 按 Objective-C++ 编译，`extern BOOL MGGetBoolAnswer(...)`
  声明被 C++ 修饰。改为 `extern "C" BOOL MGGetBoolAnswer(CFStringRef property);` 后通过。
- **第 3、4 次：** 链接通过（arm64 + arm64e），签名失败：
  `Signing GuHaiLongSplitScreen…` / `ldid: operator(): Operation not permitted`。
  排查：手动 `ldid -S` 单片 arm64、胖二进制（lipo 合并后）在 /tmp 均成功（exit 0）；
  同一文件拷到 workspace（`/home/hatch/workspace/.../.theos/obj/`）里签就失败。
  根因：`/home/hatch` 是 overlayfs（`upperdir=/run/hatch/overlay/upper`，
  `nouserxattr`），ldid 在该文件系统上写签名报 EPERM；
  `/tmp` 是 tmpfs，签名正常。**不是代码问题，是构建目录的文件系统问题。**
- **第 5 次（改到 /tmp 构建）：** 编译、链接、合并、签名（主插件 + 设置页）
  全部通过；打包失败：`ERROR: control directory has bad permissions 770`。
  原因：本机 umask 是 0007，`cp -r` 保留了 workspace 的 770 权限，
  dm.pl 要求 DEBIAN 目录权限在 0755–0775 之间。
  修复：`chmod -R 755` + `umask 022` 后重编。
- **第 6 次：** 发现设置页 `Root.plist` 没打进 bundle（`dpkg-deb -c`
  里只有可执行文件，没有 Root.plist/Info.plist）。
  原因：Theos 的 bundle 模板要求资源放 `prefs/Resources/`，
  我一开始把 `Root.plist` 直接放 `prefs/` 根目录，构建时不拷贝。
  修复：`prefs/Root.plist` → `prefs/Resources/Root.plist`，
  并补 `prefs/Resources/Info.plist`；同时去掉设置入口 plist 里
  不存在的 `icon.png` 引用。
- **第 7 次：成功。** `MAKE_EXIT:0`，
  `dm.pl: building package 'com.guhailong.splitscreen:iphoneos-arm64'
  in './packages/com.guhailong.splitscreen_1.0.0_iphoneos-arm64.deb'`。

残留警告（不影响出包，记下来）：arm64e 目标每次都有
`ld: warning: object file ... was built with an incompatible arm64e ABI compiler`
（clang 11 的 arm64e ABI 与新版有差异，链接仍成功，两个 slice 都在包里）。

## 4. 成品校验（全部通过）

```
$ file com.guhailong.splitscreen_1.0.0_iphoneos-arm64.deb
Debian binary package (format 2.0), with control.tar.gz, data compression lzma
$ sha256sum <deb>
5a03db6306f196452e295fbb9e6b553ef9770a0a7a6e9e74b663e2b6719da887
$ dpkg-deb -I <deb>
Package: com.guhailong.splitscreen
Name: 顾海龙集团分屏
Version: 1.0.0
Architecture: iphoneos-arm64
Depends: firmware (>= 15.0), mobilesubstrate, preferenceloader
Installed-Size: 336
$ dpkg-deb -c <deb>（节选）
var/jb/Library/MobileSubstrate/DynamicLibraries/GuHaiLongSplitScreen.dylib  166064
var/jb/Library/MobileSubstrate/DynamicLibraries/GuHaiLongSplitScreen.plist     308
var/jb/Library/PreferenceBundles/GuHaiLongSplitScreenPrefs.bundle/GuHaiLongSplitScreenPrefs  166528
var/jb/Library/PreferenceBundles/GuHaiLongSplitScreenPrefs.bundle/Info.plist    776
var/jb/Library/PreferenceBundles/GuHaiLongSplitScreenPrefs.bundle/Root.plist   1030
var/jb/Library/PreferenceLoader/Preferences/GuHaiLongSplitScreen.plist         504
```

dylib 抽查（解包后）：
- `file`：Mach-O universal binary，`arm64` + `arm64e` 两个 slice。
- `llvm-objdump --macho --private-headers`：两个 slice 都有 `LC_CODE_SIGNATURE`
  （ldid 已签名）。
- `strings`：含 `DeviceSupportsEnhancedMultitasking`、`medusaCapabilities`、
  `isMedusaCapable`、`supportsMultiwindow` 及日志前缀
  `[GuHaiLongSplitScreen] v1.0.0 loaded ... (iPhone 11 / iOS 16.5 / Dopamine target)`。

## 5. 已放进本地越狱源（未部署到线上）

- `.deb` 已拷到 `../ios-jailbreak-repo/debs/com.guhailong.splitscreen_1.0.0_iphoneos-arm64.deb`
- `dpkg-scanpackages -m debs /dev/null > Packages` + `gzip -kf` + `bzip2 -kf`：
  14 个包（含本包）；Packages 里本包 SHA256 与上面一致。
- `Release` 已按原格式重算 MD5 / SHA1 / SHA256 / SHA512，逐项核对通过。
- 说明页：`../ios-jailbreak-repo/depictions/splitscreen.html`（已写明实验版、未验证、风险）。
- `index.html`：总数 13 → 14，工具分类下加了一项；`README.md`：加 v7 说明与工具表一行。
- **未部署到 Netlify 线上**：线上仍是 v6（13 个包）。部署要走浏览器认领流程，由主代理另行处理。

## 6. GitHub Actions 路线（目前走不通）

- workflow 已写好：`.github/workflows/build.yml`
  （macos runner + `waruhachi/theos-action@v2.4.6`，rootless 打包，
  不需要任何密钥，只需把本目录推到一个 GitHub 仓库）。
- 但按最新记录，账号 `guhailong2026`（2309103548@qq.com）注册后
  即被 GitHub 封停（"Account suspended"），需先向 GitHub Support 申诉；
  **勿用同一邮箱重注册**。在申诉通过（或换号）之前，Actions 跑不起来。
  本地 Linux 构建已成功，Actions 只是备用路线，不阻塞本次出包。

## 7. 还缺什么（下一步）

1. **皇上真机测试（最关键）**：iPhone 11 / iOS 16.5 / Dopamine，
   部署后在 Sileo 里装本包 → respring → 横屏进 App 切换器看
   有没有分屏入口；设置里“顾海龙分屏”开关是否出现、能否开关。
   若装后无分屏入口或进安全模式：卸载本包，在 Sileo 里确认，
   把现象告诉奴才，做 v2。
2. **v2（视测试结果）**：若只有能力解锁不够，需要补界面层
   （悬浮 Dock / 手势触发 / 分屏拖放条，TrollPad 量级的工作量），
   或改推成熟插件 Medousa / Zetsu 的官方源指引。
3. 构建复现：以后改代码重编，**必须在 /tmp 里编**
   （`cp -r` 本目录到 /tmp，`umask 022`，`THEOS=~/theos make package
   FINALPACKAGE=1 THEOS_PACKAGE_SCHEME=rootless`），
   workspace 的 overlayfs 上 ldid 一定失败。工具链与 SDK 已留在
   `~/theos/toolchain/` 与 `~/theos/sdks/iPhoneOS16.5.sdk`，不用重下。

---

## 8. v2（1.0.1）—— v1 真机进安全模式后的修复

### 8.1 真机结果（2026-11-12，皇上实测）

- 机型：iPhone 11；iOS 16.5；Dopamine（rootless）。
- v1.0.0（线上 v7，14 个包）装完 respring **立刻进安全模式**。
  皇上后来补的关键信息：“进去就进入安全模式”——装完一进去就进，
  不是后来打开 App 切换器、用分屏时才崩。
- 皇上已按指引卸载 v1.0.0，手机已回到正常状态。v1.0.0 不要再装。

### 8.2 诊断：逐个审 v1 的 hook（结论：启动即崩，崩点在启动时就跑的 hook）

v1 的 hook 全在 `GHLSSEnabled` 默认 ON 下工作（prefs 文件不存在时默认 YES），
所以装完第一次 respring，全部 hook 立即生效。逐项核查（任务书里的 (a)–(e)）：

| # | v1 的 hook | 核查结果 | 嫌疑 |
|---|---|---|---|
| (a) | `SBPlatformController.medusaCapabilities` 返回 2 | **排第一。** SpringBoard 启动时读它，决定初始化哪些多任务子系统。“2 = iPad 完整多任务”是 v1 猜的值，未经 class-dump 核对：iPad 在 iOS 16 上的真实位掩码，v1 没从任何可达的公开来源核实过（网上搜到的只有 Medousa/Zetsu 的功能介绍，没有该枚举的定义）。错值会让 SpringBoard 走 iPad 专属初始化路径（切换器布局、App 排布网格等），在 iPhone 屏幕特性下启动即崩。返回值类型本身不是问题（NSInteger 在 arm64 上就是 8 字节，与 long long 一致），问题在**值**未经核实。 | ★最高 |
| (b) | `SBApplication.isMedusaCapable` / `supportsMultitaskingShelf` / `supportsMultiWindowLayoutsForSwitcherWindowManagementStyle:displayIdentity:` / `iconAllowsLaunch:` | **次高。** 启动时 SpringBoard 为每个 App（含系统 App）查询这些方法；其中 `iconAllowsLaunch:` 一律 YES 最危险：会放行本应隐藏的系统图标，启动建主屏时就可能崩。其余三个方法在 iOS 16.5 上的存在性与签名，v1 未经核对（公开渠道只找到功能介绍，找不到 iOS 16.5 的头文件定义）。 | ★次高 |
| (c) | `%hookf MGGetBoolAnswer`（MobileGestalt） | **嫌疑低。** 过滤 plist 只写了 `com.apple.springboard`，dylib 只进 SpringBoard，没有注入到别的进程；hook 只改 `DeviceSupportsEnhancedMultitasking` 一个键，其余一律 `%orig` 透传。但它在启动早期就跑，且 v1 里与 medusaCapabilities 叠加，等于“整机切 iPad 模式”，不能完全排除。v2 保留（只改该键），配合默认 OFF 隔离。 | 低 |
| (d) | `SBApplicationInfo.wantsFullScreen` / `wantsExclusiveForeground` 改 NO | **中。** 启动建场景时改尺寸与独占属性，对锁屏、主屏等必须全屏的场景是危险改动。v2 删除。 | 中 |
| (e) | 设置页 prefs bundle | **排除。** 只在“设置”App 里加载，不进 SpringBoard，不可能导致 SpringBoard 启动崩溃。但 v1 默认 ON 是设计失误：装完即生效、无法隔离问题。v2 默认 OFF。 | 无 |

两种可能都已考虑：(i) 装完 respring 即崩——皇上确认就是这一种，上面
的诊断按此定论；(ii) 后来操作分屏时才崩——皇上否认了这一种（“进去就
进入安全模式”），所以 v2 不按“分屏操作时崩”修，不补界面层、不碰拖放逻辑。

### 8.3 v2 改动清单（最小改动、逐项加）

删掉的（Tweak.xm）：
- `SBPlatformController` 整个 hook：`medusaCapabilities`、`isHomeGestureEnabled`
  （后者在 iPhone 11 上本来就是开的，留着无意义）。
- `SBApplication` 整个 hook：`isMedusaCapable`、`supportsMultitaskingShelf`、
  `supportsMultiWindowLayoutsForSwitcherWindowManagementStyle:displayIdentity:`、
  `iconAllowsLaunch:`。
- `SBApplicationInfo` 的 `wantsFullScreen`、`wantsExclusiveForeground`。

留下的（只两个）：
1. `%hookf MGGetBoolAnswer`：只改 `DeviceSupportsEnhancedMultitasking` → YES，
   其余透传；只在开关 ON 时生效。
2. `SBApplicationInfo.supportsMultiwindow` → YES，**运行时先查方法存在才 hook**：
   `%ctor` 里 `NSClassFromString(@"SBApplicationInfo")` + `instancesRespondToSelector:`，
   不存在就跳过并记日志，不再假设方法一定存在（`MSHookMessageEx` 直接挂接）。

开关默认 OFF（三处一致）：
- `Tweak.xm`：`GHLSSEnabled` 默认 NO，prefs 缺失时默认 NO（v1 是 YES）。
- `prefs/Resources/Root.plist`：`default` 改 `<false/>`，标题改为 v1.0.1（实验版 v2），
  footer 写清“默认关、手动开、开后若进安全模式在安全模式下关掉”。
- `prefs/RootListController.m`：`readPreferenceValue` 默认 `@(NO)`（v1 是 `@(YES)`）。

其他：`control` 版本 1.0.1，描述写清 v1 进安全模式、v2 改动与默认 OFF；
`README.md` 加 v2 一节与新的使用步骤。

### 8.4 v2 编译（本地 Linux Theos 路线，一次成功）

```
rm -rf /tmp/ghlss-v2-build && cp -r <本目录> /tmp/ghlss-v2-build && chmod -R 755 /tmp/ghlss-v2-build
cd /tmp/ghlss-v2-build && export THEOS=$HOME/theos && umask 022 && make package FINALPACKAGE=1 THEOS_PACKAGE_SCHEME=rootless
MAKE_EXIT:0
```
一次编过，无新报错；残留警告与 v1 相同（arm64e ABI 警告、plutil 未装提示），不影响出包。

### 8.5 v2 成品校验（全部通过）

```
$ file com.guhailong.splitscreen_1.0.1_iphoneos-arm64.deb
Debian binary package (format 2.0), with control.tar.gz, data compression lzma
$ sha256sum <deb>
a178023fe46a4ad944814bbe5adb700799d23aaf00602b040e72fb666e2c087c
$ dpkg-deb -I <deb>
Package: com.guhailong.splitscreen
Name: 顾海龙集团分屏
Version: 1.0.1
Architecture: iphoneos-arm64
Depends: firmware (>= 15.0), mobilesubstrate, preferenceloader
Installed-Size: 344
$ dpkg-deb -c <deb>（节选）
var/jb/Library/MobileSubstrate/DynamicLibraries/GuHaiLongSplitScreen.dylib  166064
var/jb/Library/MobileSubstrate/DynamicLibraries/GuHaiLongSplitScreen.plist     308
var/jb/Library/PreferenceBundles/GuHaiLongSplitScreenPrefs.bundle/GuHaiLongSplitScreenPrefs  166528
var/jb/Library/PreferenceBundles/GuHaiLongSplitScreenPrefs.bundle/Info.plist    776
var/jb/Library/PreferenceBundles/GuHaiLongSplitScreenPrefs.bundle/Root.plist   1173
var/jb/Library/PreferenceLoader/Preferences/GuHaiLongSplitScreen.plist         504
```

dylib 抽查（解包后）：
- `file`：Mach-O universal binary，`arm64` + `arm64e` 两个 slice。
- `llvm-objdump --macho --private-headers`：两个 slice 都有 `LC_CODE_SIGNATURE`
  （ldid 已签名，共 2 处）。
- `strings` 核对（已删的 hook 必须不在，高危符号已清零）：
  - 在：`DeviceSupportsEnhancedMultitasking`、`supportsMultiwindow`
  - 不在：`medusaCapabilities`、`isMedusaCapable`、`supportsMultitaskingShelf`、
    `iconAllowsLaunch`、`wantsFullScreen`、`wantsExclusiveForeground`
- 设置页核对：解包后 `Root.plist` 里“启用分屏”的 `default` 为 False。

### 8.6 本地源已更新为 v2（未部署到线上）

- 旧的 `debs/com.guhailong.splitscreen_1.0.0_iphoneos-arm64.deb` 已删
  （避免皇上误装回坏版本）；新的 `debs/com.guhailong.splitscreen_1.0.1_iphoneos-arm64.deb`
  （7920 字节）已放进 `../ios-jailbreak-repo/debs/`。
- `dpkg-scanpackages -m debs /dev/null > Packages` + `gzip -kf` + `bzip2 -kf`：
  仍 14 个包；Packages 里本包为 Version 1.0.1，SHA256
  `a178023fe46a4ad944814bbe5adb700799d23aaf00602b040e72fb666e2c087c` 与 .deb 一致。
- `Release` 已按原格式重算 MD5 / SHA1 / SHA256 / SHA512，逐项核对通过
  （Packages 8948 字节，SHA256 `3a087930357bda169c9eaa0a41f1e3872e80e24c00c659e01afc18c3dffdd058`）。
- 说明页 `../ios-jailbreak-repo/depictions/splitscreen.html` 已重写为 v2
  （写明 v1 进安全模式不要再装、v2 默认 OFF、四步安装法）。
- `index.html`：分屏一项改为 1.0.1（实验版 v2），注明 v1 不要再装、v2 开关默认 OFF。
- `README.md`：v7 一行已更正为“已于 2026-11-12 14:35 部署到线上”；
  新增 v8 待部署说明与 v2 段落；v1 段落改为“已废弃”；工具表分屏一行改为 1.0.1。
- **未部署到 Netlify 线上**：线上仍是 v7（分屏 1.0.0 坏版本）。部署要走浏览器
  认领流程，由主代理另行处理。**在 v8 部署之前，皇上在 Sileo 里刷新源看到的
  仍是 v1.0.0，千万不要重装。**
- 其他 13 个包没动：只换了分屏这一个 .deb，Packages 总数仍是 14。

### 8.7 还缺什么（下一步）

1. **主代理部署 v8 到线上**（浏览器认领流程），部署后独立核对线上 Packages
   含 splitscreen 1.0.1、SHA256 一致，再让皇上装。
2. **皇上装 v2 的正确顺序**：Sileo 刷新源 → 装 1.0.1 → respring，
   先确认手机正常启动（开关默认关，不应进安全模式）；再去设置 → 顾海龙分屏
   把开关打开 → 再 respring → 横屏进 App 切换器看分屏入口。
   若“装完 respring”这一步就进安全模式：说明连默认 OFF 的 dylib 加载本身
   都有问题（与 hook 内容无关），请立即卸载并告诉主代理。
   若“打开开关、再 respring”后才进安全模式：说明崩点在留下的两个 hook 里，
   请在安全模式下进设置把开关关掉、退出安全模式，再告诉主代理。
3. **若 v2 还是进安全模式，下一步查什么**：请皇上在手机上看
   设置 → 隐私与安全性 → 分析与改进 → 分析数据，找名字以
   `SpringBoard-` 开头、时间是崩溃当时的那条日志（或搜 `GuHaiLongSplitScreen`），
   把“异常类型 / 崩溃线程最上面几行”发回来；没有日志也行，告诉主代理
   是上面第 2 步里哪一步进的安全模式，v3 就按那一步修（例如只留
   MGGetBoolAnswer 一个 hook，或逐个开关测试）。
4. 若 v2 开关打开后仍无分屏入口但不崩：说明“只改两个能力位”不够，
   需要 v3 补界面层（悬浮 Dock / 手势触发 / 分屏拖放条，TrollPad 量级的工作量），
   或改推成熟插件 Medousa / Zetsu 的官方源指引。

---

## 9. v3（1.0.2）—— 按 floatingView 成品参考，改走悬浮窗路线（第一步：只做壳）

### 9.1 参考是怎么来的（2026-11-12，皇上给的）

- 皇上先说成品插件叫 "floating-view"，奴才两次全网搜都没找到同名越狱插件
  （最接近的是 FloatingDockXVI / Myrtle / Zetsu），如实报了查不到、请皇上
  给来源；皇上随后给了源地址：https://kiIIuaaa.github.io/repo。
- 该源标题 "Floating-View"，Packages 实测：116 条
  `com.be-huge.floating-view`（1.4.1 → 1.6.0-6）+ 1 条
  `com.be-huge.floating-view-free` 1.6.0-6，共 117 条。
  最新 1.6.0-6：iphoneos-arm64，作者 be-huge，Name floatingView，
  Depends `dev.theos.orion (>= 1.0.0), firmware (>= 12.2)`，
  .deb 669484 字节，SHA256 `ca4e82975faff2e1baf6bc4d2ebc0221053d06364c2e13b279190f3553c2431e`。
  描述统一为“分屏，不必太复杂，一切从简即可。”。
  depiction（https://sileodepiction.8235467.xyz/com.be-huge.floating-view/js.json）：
  “所有版本均为付费版本，需要请联系开发者购买后使用”；购买方式：下载
  tie-gesture → 进插件点“赞助入口”跳支付宝 → 付 100 元 → 拿订单详情联系商家
  → 准备 UDID 登记；或加微信 stnaoy。另有 "floatingView Free" 1.6.0-6，
  描述“移除设备验证，免费使用”——那是破解版（去 UDID 验证）。
- .deb 元数据检查（公开信息，不下二进制、不反编译、不抄代码）：
  Swift + Orion 编写；主 dylib 只注入 `com.apple.springboard`，
  另有辅助 dylib 注入 UIKeyboardImpl 与 mediaserverd；
  它不用 medusa Split View——自己在 SpringBoard 里画悬浮窗
  （根窗口 + 启动器/搜索界面），手势 hook 在
  SBFluidSwitcherGestureManager / SBMainWorkspace / SBIcon 上。
- **红线（已守住）：没有下载它的 .deb，没有复制、反编译、重打包、
  没有把它或它的免费版（破解版）收进本源。** v3 只学“悬浮窗壳”这个
  思路，代码全部原创。皇上后来说“可以按照它的基础来做”“或者可以全抄，
  我们再改”——“全抄”没有做：它是付费闭源插件，没有源码可抄，
  抄二进制、做破解版既侵权、也会把来路不明的代码装进皇上的手机，
  所以 v3 仍是原创实现，只借鉴公开做法。

### 9.2 v3 第一步做什么、不做什么

做（Tweak.xm 全新重写，v2 的两个 hook 原样保留）：
- 开关 ON + respring 后，主屏出现金色“分”字悬浮按钮（56pt 圆钮，
  `UIWindow`，level = UIWindowLevelStatusBar + 10，挂在当前前台
  UIWindowScene 上；没有 scene 时 2 秒重试、最多 6 次，失败只记日志）。
- 按钮可拖动：自定义 `GHLSSDragButton`（UIButton 子类），直接用
  touchesBegan/Moved/Ended 判断——移动 > 6pt 算拖动（跟手移窗、
  限制在屏幕内），否则算点按；不用手势识别器（会和按钮点按抢触摸）。
- 点按钮打开启动器窗（`UIWindow`，level = UIWindowLevelAlert + 10，
  半透明遮罩 + 居中圆角面板）：标题“顾海龙分屏 · 选 App”、✕ 关闭钮、
  App 列表（UITableView，纯文字行：名字 + bundle ID，暂无图标）。
- App 列表来自运行时查到的 `LSApplicationWorkspace`
  （`allInstalledApplications`，只取 applicationType == "User"、
  非 placeholder 的，按名字排序）；点一行 → `openApplicationWithBundleID:`
  全屏打开该 App，再关启动器。全部调用先查方法存在、包在 @try/@catch 里。
- 开关 OFF 时两扇窗都撤掉；开关变化走 Darwin 通知即时生效；
  %ctor 里只做登记 + 2 秒后主线程建窗（SpringBoard 启动早期还没有
  windowScene，不能在 %ctor 里直接建窗），另监听
  UIApplicationDidBecomeActiveNotification 补一次（已建好就直接返回）。

不做（实话实说，留给后面的步骤）：
- 点 App 是全屏打开它，**不是**把第二个 App 的画面装进悬浮窗里、
  **不是**真左右分屏；把第二个 App 的 scene 装进悬浮窗内是下一步的
  硬核工作（接管第二个 App 的窗口层级与触摸路由）。
- 启动器列表暂无 App 图标（图标要走 SBApplicationController 的私有
  图标接口，留给后面的步骤）。
- 没有手势触发（SBFluidSwitcherGestureManager 等私有方法签名在
  iOS 16.5 上未经 class-dump 核对，贸然 hook 就是下一个安全模式；
  先用最稳的悬浮按钮）。
- 刻意不碰：不 hook SBPlatformController.medusaCapabilities、
  不 hook SBApplication、不改 wantsFullScreen / wantsExclusiveForeground、
  不 hook SBMainWorkspace / SBIcon。

### 9.3 v3 编译（本地 Linux Theos 路线，两次才成）

```
rm -rf /tmp/ghlss-v3-build && cp -r <本目录> /tmp/ghlss-v3-build && chmod -R 755 /tmp/ghlss-v3-build
cd /tmp/ghlss-v3-build && export THEOS=$HOME/theos && umask 022 && make package FINALPACKAGE=1 THEOS_PACKAGE_SCHEME=rootless
```
- **第 1 次失败：** `'keyWindow' is deprecated: first deprecated in iOS 13.0 ...
  [-Werror,-Wdeprecated-declarations]`（Tweak.xm:122，
  `GHLSSActiveWindowScene` 里用 `app.keyWindow` 做兜底）。Theos 默认
  -Werror，废弃 API 直接报错。修复：删掉 keyWindow 兜底，只用
  connectedScenes 循环取 scene（前台优先，其次任意 UIWindowScene）。
- **第 2 次成功。** MAKE_EXIT:0；残留警告与 v1/v2 相同（arm64e ABI 警告、
  plutil 未装提示），不影响出包。
- 新教训：Theos 构建把废弃 API 当错误，写代码时就不要用 iOS 13 已废弃的
  API（keyWindow 等），直接用 connectedScenes / windowScene 写法。

### 9.4 v3 成品校验（全部通过）

```
$ file com.guhailong.splitscreen_1.0.2_iphoneos-arm64.deb
Debian binary package (format 2.0), with control.tar.gz, data compression lzma
$ sha256sum <deb>
24eda2730c6a1d25669692a7c567695aa730fb8d0c4bdc71a9f0d24c44f62f6a
$ dpkg-deb -I <deb>
Package: com.guhailong.splitscreen
Name: 顾海龙集团分屏
Version: 1.0.2
Architecture: iphoneos-arm64
Depends: firmware (>= 15.0), mobilesubstrate, preferenceloader
Installed-Size: 380
$ dpkg-deb -c <deb>（节选）
var/jb/Library/MobileSubstrate/DynamicLibraries/GuHaiLongSplitScreen.dylib  202432
var/jb/Library/MobileSubstrate/DynamicLibraries/GuHaiLongSplitScreen.plist     308
var/jb/Library/PreferenceBundles/GuHaiLongSplitScreenPrefs.bundle/GuHaiLongSplitScreenPrefs  166528
var/jb/Library/PreferenceBundles/GuHaiLongSplitScreenPrefs.bundle/Info.plist    776
var/jb/Library/PreferenceBundles/GuHaiLongSplitScreenPrefs.bundle/Root.plist   1351
var/jb/Library/PreferenceLoader/Preferences/GuHaiLongSplitScreen.plist         504
```

dylib 抽查（解包后，lipo 拆 slice 再查——本机 llvm-objdump 不支持 -arch 参数，
直接对胖二进制查会静默失败，之前那次 0 不是真的没签名）：
- `file`：Mach-O universal binary，`arm64` + `arm64e` 两个 slice。
- `llvm-objdump --macho --private-headers`（逐 slice）：两个 slice 都有
  `LC_CODE_SIGNATURE`（ldid 已签名，各 1 处）；设置页二进制两 slice 也各有 1 处。
- `strings` 核对：
  - 在：`DeviceSupportsEnhancedMultitasking`、`supportsMultiwindow`、
    `LSApplicationWorkspace`、`openApplicationWithBundleID:`、
    `allInstalledApplications`
  - 不在：`medusaCapabilities`、`isMedusaCapable`、`iconAllowsLaunch`、
    `wantsFullScreen`、`wantsExclusiveForeground`、`be-huge`、
    `floatingView`、`kiIIuaaa`、`SBFluidSwitcherGestureManager`、
    `SBMainWorkspace`
- 设置页核对：解包后 `Root.plist` 里“启用分屏”的 `default` 为 False，
  标题为“顾海龙集团分屏 v1.0.2（实验版 v3）”。

### 9.5 本地源已更新为 v3（未部署到线上）

- `.deb` 已拷到本目录根（`com.guhailong.splitscreen_1.0.2_iphoneos-arm64.deb`，
  22958 字节）与 `../ios-jailbreak-repo/debs/`。
- 旧的 `debs/com.guhailong.splitscreen_1.0.1_iphoneos-arm64.deb` 已从本地源删掉
  （v2 的副本还在 `/tmp/ghlss-v2-build/packages/`，线上 v8 仍在提供 1.0.1，
  删本地不影响皇上装 v2）。
- `dpkg-scanpackages -m debs /dev/null > Packages` + `gzip -kf` + `bzip2 -kf`：
  仍 14 个包；Packages 里本包为 Version 1.0.2，Size 22958，SHA256
  `24eda2730c6a1d25669692a7c567695aa730fb8d0c4bdc71a9f0d24c44f62f6a` 与 .deb 一致。
- `Release` 已按原格式重算 MD5 / SHA1 / SHA256 / SHA512，逐项核对通过
  （Packages 9095 字节，SHA256 `ecbec115fa700a3492769eb4ef65701620e4c40dd09116c4d4c7f8cfc4defc84`）。
- 说明页 `../ios-jailbreak-repo/depictions/splitscreen.html` 已重写为 v3
  （写明 v1 不要再装、v3 只做悬浮窗壳、不能做的事、五步安装法）。
- `index.html`：分屏一项改为 1.0.2（实验版 v3）。
- `README.md`：v8 一行已更正为“已于 2026-11-12 14:48 部署到线上”；
  新增 v9 待部署说明与 v3 段落；工具表分屏一行改为 1.0.2。
- **未部署到 Netlify 线上**：线上仍是 v8（分屏 1.0.1）。部署要走浏览器
  认领流程，由主代理另行处理。**在 v9 部署之前，皇上在 Sileo 里刷新源看到的
  仍是 v2 1.0.1。**
- 其他 13 个包没动：只换了分屏这一个 .deb，Packages 总数仍是 14。

### 9.6 还缺什么（下一步）

1. **主代理部署 v9 到线上**（浏览器认领流程），部署后独立核对线上 Packages
   含 splitscreen 1.0.2、SHA256 一致，再让皇上装。
2. **皇上装 v3 的正确顺序**：Sileo 刷新源 → 装 1.0.2 → respring，
   先确认手机正常启动（开关默认关，不应进安全模式）；再去设置 → 顾海龙分屏
   把开关打开 → 再 respring → 主屏右上角应出现金色“分”字按钮。
   点按钮打开启动器，点一个 App 看能不能全屏打开；拖动按钮，看能不能跟手移动。
   若“装完 respring”这一步就进安全模式：说明连默认 OFF 的 dylib 加载本身
   都有问题（与悬浮窗代码无关，因开关关着时不建窗），请立即卸载并告诉主代理。
   若“打开开关、再 respring”后才进安全模式：崩点在悬浮窗创建或 v2 留下的
   两个 hook 里，请在安全模式下进设置把开关关掉、退出安全模式，再告诉主代理
   是第几步出的事。
3. **v3 下一步（等壳在真机跑通、不崩之后）**：(a) 启动器加 App 图标；
   (b) 手势触发（需先 class-dump 核对 SBFluidSwitcherGestureManager 等
   私有方法签名，核对不上就不 hook）；(c) 真正的硬核——把第二个 App 的
   scene 装进悬浮窗内（窗口层级 + 触摸路由），这是 v3 后面几个步骤的事，
   不要一次全上。
4. **v2 的测试仍有效**：v2 1.0.1 还在线上 v8，皇上若先测 v2，请按第 8.7 节
   的两步法报结果（哪一步进安全模式 / 分屏入口出没出来）；v2 的结果决定
   v3 里的两个能力位 hook 留不留。

---

## 10. v4（1.0.3）—— v3 真机卡住手机 + 白苹果后的修复

### 10.1 真机结果（2026-11-12，皇上实测）

- v3 1.0.2（线上 v9，15:07 部署）装完，皇上报告**手机卡住了**（约 15:17，
  “把我手机卡住了”），强制重启后**进白苹果**（一直停在苹果标志），
  后来手机恢复（皇上：“已经可以了”）。
- **没有崩溃日志。** 皇上没说卡住发生在哪一步：(i) 装完 respring
  （开关应是关的）；(ii) 开开关、再 respring；(iii) 点金色“分”字按钮
  打开启动器。哪一步出事，直接决定下面 (a)(b)(c) 三个嫌疑谁是真凶——
  目前只能按代码逐项定性，不能定罪。v4 按“三个嫌疑全部处理”修，
  不赌其中某一个。
- v3 1.0.2 不要再装。本地源与线上源已由主代理另行回滚到 v10（分屏 1.0.1），
  v4 不动那次回滚，只在本地源上把分屏换成 1.0.3（见 10.6）。

### 10.2 诊断：逐项审 v3 的代码（行号按 v3 的 Tweak.xm，466 行）

| # | 核查点 | 代码依据 | 结论 |
|---|---|---|---|
| (a) | **v1 残留的 prefs 让开关实际是开的** | `GHLSSReloadPrefs`（Tweak.xm:59-62）读 `/var/jb/var/mobile/Library/Preferences/com.guhailong.splitscreen.plist`；文件不存在时才默认 NO。v1 的设置页默认是 YES（`RootListController.m` 曾为 `@(YES)`、v1 的 Tweak.xm 默认 YES），且 Sileo 卸载插件**不会删** Preferences 里的 plist。皇上装过 v1 又卸载过，所以 v3 装完第一次 respring 时，该文件极可能还在、且 `Enabled=YES`。 | **已确认的机制，文件是否真在皇上手机上未确认**（查不了他的手机）。后果：v3 的“默认 OFF”保护对他不生效——两个能力位 hook 与悬浮窗从装完第一次 respring 就全活了。v4 的对策：两个 hook 直接删掉（留不留都无所谓了），且测试步骤明确要求“装之前先确认开关是关的”。 |
| (b) | **两个能力位 hook 在启动时改 SpringBoard 的多任务决策** | `%hookf MGGetBoolAnswer`（Tweak.xm:80-87）：`DeviceSupportsEnhancedMultitasking` → YES；`SBApplicationInfo.supportsMultiwindow` → YES（Tweak.xm:91-96，`MSHookMessageEx` 在 %ctor 里，Tweak.xm:449-452）。开关 ON 时对**所有** App 生效。v2 保留了这两个 hook，但 v2 从没上过真机，所以这两个 hook 的安全性**从未被验证过**。 | **头号嫌疑（未确认）。** SpringBoard 启动时为每个 App 查这些能力位；全改 YES 可能让场景/布局代码走异常分支——死锁或反复崩溃都会表现为手机卡住；若崩溃发生在 SpringBoard 启动早期、Safe Mode 还没接管，就会反复出现苹果标志（respring 循环），与皇上报的白苹果对得上。没有崩溃日志，定不了罪，v4 直接删掉这两个 hook。 |
| (c) | **App 列表在主线程同步枚举** | `GHLSSLauncherViewController.viewDidLoad` 里 `self.apps = GHLSSFetchUserApps();`（Tweak.xm:306），而 `GHLSSFetchUserApps`（Tweak.xm:130-158）在第 143 行同步调 `allInstalledApplications`：该调用要查 LS 数据库、可能走 daemon，耗时以秒计，**全程占着 SpringBoard 主线程**。 | **头号嫌疑（未确认），仅当皇上点了“分”字按钮才成立。** 主线程被占 = 触摸全死、界面定格、但不进安全模式——与“卡住了”完全吻合；与 (b) 的区别是它只在点按钮后发生，不在启动时发生。v4 改成后台队列枚举 + 先显示“正在读取…”再刷新，启动器再也不占主线程。 |
| (d) | **悬浮窗在 SpringBoard 启动早期建窗** | %ctor 里 `dispatch_after` 2 秒后 `GHLSSApplyFloatingUI()`（Tweak.xm:459-460），另监听 `UIApplicationDidBecomeActiveNotification` 每次都调 `GHLSSApplyFloatingUI()`（Tweak.xm:461-463）；而 `GHLSSApplyFloatingUI` 每次开关 ON 时都把 `GHLSSEnsureAttempts` 归零（Tweak.xm:427、432），scene 一直没有时重试链会反复重生。 | **小毛病，不是卡住的原因。** 每步本身都不占主线程、不调私有接口；重试归零只会让定时器多跑几轮。v4 仍改掉它：只在 SpringBoard 完全启动（前台激活 + 有前台 scene）后才建窗，首次检查推迟到 5 秒后，重试有上限、不叠加。 |
| (e) | **UIWindow 本身** | 触发按钮窗 `UIWindowLevelStatusBar + 10`（Tweak.xm:约 357 行）、启动器窗 `UIWindowLevelAlert + 10`；建窗前先查 scene 是否存在，没有就重试、不硬建。 | **嫌疑低。** 建窗调用本身是公开 UIKit、无阻塞；v3 的建窗守卫写对了。v4 保留同样写法，只把触发时机推迟到启动完成之后。 |
| (f) | **白苹果本身** | — | **已确认的推理：冷重启后 Dopamine 不工作、没有任何插件代码会跑，所以插件不可能直接让一次冷启动卡在苹果标志。** 白苹果最可能是两种情形之一：(i) 强制重启后的第一次开机本身就慢；(ii) 皇上重启后又重新越狱，开关仍是 ON，SpringBoard 带着 (b) 的 hook 启动失败、反复重生，每次都闪苹果标志（respring 循环）。是哪一种，皇上没说、无法确认；但两种都不指向“插件烧坏了系统”，v4 按 (b) 修就是对的。 |

**诊断结论（诚实版）：** 没有日志、不知道卡在哪一步，(b) 与 (c)
无法二选一；(a) 让 (b) 在第一次 respring 就生效，放大了风险。
v4 把三条路全堵上：删掉两个能力位 hook（b 消失）、App 列表改后台
枚举（c 消失）、悬浮窗只在 SpringBoard 完全启动后建（d 的毛病修掉）；
(a) 的残留 prefs 问题无法从插件里删文件，改由测试步骤兜底
（装 v4 之前先确认开关是关的）。

### 10.3 v4 改动清单（最小、最保守的一步）

删掉的（Tweak.xm）：
- `%hookf MGGetBoolAnswer` 整个 hook（Tweak.xm:80-87）及
  `extern "C" BOOL MGGetBoolAnswer(...)` 声明（Tweak.xm:49）。
- `SBApplicationInfo.supportsMultiwindow` 的替换函数与
  `MSHookMessageEx` 挂接（Tweak.xm:91-96、449-455）。
- `#import <substrate.h>`（已无任何 hook 调用）；Makefile 里的
  `GuHaiLongSplitScreen_LIBRARIES = MobileGestalt` 也删掉。
- v4 的 dylib 里不应再有 `DeviceSupportsEnhancedMultitasking` 与
  `supportsMultiwindow` 两个符号（校验见 10.5）。

改掉的（Tweak.xm）：
- **悬浮窗只在 SpringBoard 完全启动后建：** %ctor 只做登记
  （读 prefs、注册 Darwin 通知、注册 `UIApplicationDidBecomeActiveNotification`）
  与 5 秒后的首次检查；建窗前必须同时满足：开关 ON、App 状态为
  `UIApplicationStateActive`、存在前台激活的 `UIWindowScene`；
  不满足就 3 秒重试、最多 10 次（30 秒），超限就停下、等下一次激活
  通知再试；重试不叠加（`GHLSSSettledCheckPending` 守卫，不再每次归零）。
- **App 列表改后台枚举：** 启动器 `viewDidLoad` 先显示“正在读取
  App 列表…”（`self.apps == nil` 即加载中），在全局后台队列调
  `GHLSSFetchUserApps()`，完成后回主线程赋值并 `reloadData`；
  读到的列表缓存起来（`GHLSSCachedApps`），下次打开直接用、不再等。
- 开关仍默认 OFF（三处一致：`Tweak.xm` 默认 NO、`Root.plist`
  `<false/>`、`RootListController.m` 默认 `@(NO)`）。

保留的（v3 的壳，不变）：
- 金色“分”字悬浮按钮（可拖动、点按开启动器）、启动器面板
  （遮罩 + 圆角面板 + 纯文字 App 列表）、点 App 全屏打开
  （`openApplicationWithBundleID:`，仍只在点选时调一次）。
- 仍**不**把第二个 App 装进悬浮窗内、**不是**真左右分屏；
  仍无 App 图标、无手势触发。

其他：`control` 版本 1.0.3，描述写清 v4 的删改与仍是实验版；
`Root.plist` 标题改为 v1.0.3（实验版 v4），footer 写清 v3 卡住手机
已下架、v4 删了两个能力位 hook、装前先确认开关是关的；
`README.md` 加 v4 一节；本文件加第 10 节。

### 10.4 v4 编译（本地 Linux Theos 路线，两次才成）

```
rm -rf /tmp/ghlss-v4-build && cp -r <本目录> /tmp/ghlss-v4-build && chmod -R 755 /tmp/ghlss-v4-build
cd /tmp/ghlss-v4-build && export THEOS=$HOME/theos && umask 022 && make package FINALPACKAGE=1 THEOS_PACKAGE_SCHEME=rootless
```
- **第 1 次失败：** `Makefile:15: *** missing separator. Stop.`——Makefile 里
  写了 `//` 注释，make 只认 `#`。修复：改成 `#` 注释后重编。
- **第 2 次成功。** MAKE_EXIT:0；残留警告与 v1/v2/v3 相同（arm64e ABI 警告、
  plutil 未装提示），不影响出包。
- 新教训：Makefile 里只能用 `#` 写注释，不要写 `//`。

### 10.5 v4 成品校验（全部通过）

```
$ file com.guhailong.splitscreen_1.0.3_iphoneos-arm64.deb
Debian binary package (format 2.0), with control.tar.gz, data compression lzma
$ sha256sum <deb>
ca97da99f5b3c65a30761bbd4d8515ba6a77c3bbb63407c4ba0cb614b7f46d9a
$ dpkg-deb -I <deb>
Package: com.guhailong.splitscreen
Name: 顾海龙集团分屏
Version: 1.0.3
Architecture: iphoneos-arm64
Depends: firmware (>= 15.0), mobilesubstrate, preferenceloader
Installed-Size: 380
$ dpkg-deb -c <deb>（节选）
var/jb/Library/MobileSubstrate/DynamicLibraries/GuHaiLongSplitScreen.dylib  202336
var/jb/Library/MobileSubstrate/DynamicLibraries/GuHaiLongSplitScreen.plist     308
var/jb/Library/PreferenceBundles/GuHaiLongSplitScreenPrefs.bundle/GuHaiLongSplitScreenPrefs  166528
var/jb/Library/PreferenceBundles/GuHaiLongSplitScreenPrefs.bundle/Info.plist    776
var/jb/Library/PreferenceBundles/GuHaiLongSplitScreenPrefs.bundle/Root.plist   1702
var/jb/Library/PreferenceLoader/Preferences/GuHaiLongSplitScreen.plist         504
```

dylib 抽查（解包后，lipo 拆 slice 再查——工具在
`~/theos/toolchain/linux/iphone/bin/`，不在 `usr/bin/`）：
- `file`：Mach-O universal binary，`arm64` + `arm64e` 两个 slice。
- `llvm-objdump --macho --private-headers`（逐 slice）：两个 slice 都有
  `LC_CODE_SIGNATURE`（ldid 已签名，各 1 处）；设置页二进制两 slice 也各有 1 处。
- `strings` 核对（v4 删掉的 hook 必须不在）：
  - 在：`LSApplicationWorkspace`、`openApplicationWithBundleID:`、
    `allInstalledApplications`
  - 不在（计数为 0）：`medusaCapabilities`、`isMedusaCapable`、
    `iconAllowsLaunch`、`wantsFullScreen`、`wantsExclusiveForeground`、
    `DeviceSupportsEnhancedMultitasking`、`supportsMultiwindow`、
    `MGGetBoolAnswer`、`be-huge`、`floatingView`、`kiIIuaaa`、
    `SBFluidSwitcherGestureManager`、`SBMainWorkspace`
- 链接库核对：dylib 只链接 `/usr/lib/libSystem.B.dylib`，已无
  MobileGestalt 与 substrate 的引用（`grep -ci MobileGestalt|substrate` = 0）。
- 设置页核对：解包后 `Root.plist` 里“启用分屏”的 `default` 为 False，
  标题为“顾海龙集团分屏 v1.0.3（实验版 v4）”。

### 10.6 本地源已更新为 v4（未部署到线上）

- `.deb` 已拷到本目录根（`com.guhailong.splitscreen_1.0.3_iphoneos-arm64.deb`，
  23534 字节）与 `../ios-jailbreak-repo/debs/`。
- 旧的 `debs/com.guhailong.splitscreen_1.0.1_iphoneos-arm64.deb` 已从本地源删掉
  （v2 的副本还在 `/tmp/ghlss-v2-build/packages/`，线上 v10 仍在提供 1.0.1，
  删本地不影响皇上装 v2）。
- `dpkg-scanpackages -m debs /dev/null > Packages` + `gzip -kf` + `bzip2 -kf`：
  仍 14 个包；Packages 里本包为 Version 1.0.3，Size 23534，SHA256
  `ca97da99f5b3c65a30761bbd4d8515ba6a77c3bbb63407c4ba0cb614b7f46d9a` 与 .deb 一致。
- `Release` 已按原格式重算 MD5 / SHA1 / SHA256 / SHA512，逐项核对通过
  （Packages 9160 字节，SHA256 `b63ebead272d9915b71cd53c7828a6e5bf1e482fb7548468ff26f13092064709`）。
- 说明页 `../ios-jailbreak-repo/depictions/splitscreen.html` 已重写为 v4
  （写明 v1 不要再装、v3 1.0.2 卡住手机已下架、v4 删了两个能力位 hook、
  装前先确认开关是关的、五步安装法）。
- `index.html`：分屏一项改为 1.0.3（实验版 v4）。
- `README.md`：v10 一行后新增 v11 待部署说明与 v4 段落；工具表分屏一行改为 1.0.3。
- **未部署到 Netlify 线上**：线上仍是 v10（分屏 1.0.1）。部署要走浏览器
  认领流程，由主代理另行处理。**在 v11 部署之前，皇上在 Sileo 里刷新源看到的
  仍是 v2 1.0.1。**
- 其他 13 个包没动：只换了分屏这一个 .deb，Packages 总数仍是 14。

### 10.7 还缺什么（下一步）

1. **主代理部署 v11 到线上**（浏览器认领流程），部署后独立核对线上
   Packages 含 splitscreen 1.0.3、SHA256 一致，再让皇上装。
   **v4 部署前不要让皇上装 1.0.1 之外的任何分屏版本。**
2. **皇上装 v4 的正确顺序（关键：先确认开关是关的）：**
   (0) 装之前先去设置 → 顾海龙分屏，看一眼开关——若是开的（v1 残留
   的 prefs 可能让它显示开），先把它关掉。
   (1) Sileo 刷新源 → 装 1.0.3 → respring，确认手机能正常启动、
   不进安全模式、不卡住（开关关着时 v4 不建窗、不 hook，SpringBoard
   应与没装插件时完全一样）。
   (2) 再去设置打开开关 → 再 respring → 等几秒，主屏应出现金色
   “分”字按钮（v4 会等 SpringBoard 完全启动后才建窗，按钮出现会比
   v3 晚几秒，这是故意的）。
   (3) 点按钮：启动器应先显示“正在读取 App 列表…”，随后出现 App
   列表（不应卡住）；点一个 App 看能不能全屏打开；拖动按钮看能不
   能跟手移动。
   若第 (1) 步就出问题：说明连“什么都不做”的 dylib 加载本身都有
   问题，请立即卸载并告诉主代理。
   若第 (2)/(3) 步出问题：请告诉主代理是哪一步、当时屏幕什么样
   （卡住 / 安全模式 / 白苹果），并尽量保留崩溃日志（设置 → 隐私
   与安全性 → 分析与改进 → 分析数据，找 `SpringBoard-` 开头的条目）。
3. **v4 之后（等壳在真机跑通、不崩之后）：** (a) 启动器加 App 图标；
   (b) 手势触发（需先 class-dump 核对私有方法签名）；(c) 真正的硬核——
   把第二个 App 的 scene 装进悬浮窗内。不要一次全上。

---

## 11. v4（1.0.3）—— 装完重启也卡住后的诊断（只诊断，不建新版）

### 11.1 真机结果（2026-11-12，皇上实测）

- v4 1.0.3（线上 v11，16:08 部署）装完，皇上报告**“装完重启卡住”**（约 16:10），
  即第 (1) 步：Sileo 装完 → respring → 卡住，还没到开开关、点按钮。
  开关是否事先确认关的（步骤 0）**未确认**。皇上手机上同时装着正版
  floatingView（已启用）——这是 v3 测试时没有的新变量。
- 与 v3 的区别：v3 卡住发生在哪一步没说清，v4 明确是"装完重启"这一步。
- 没有崩溃日志。v4 1.0.3 不要再装。本地源与线上源已由主代理另行回滚到
  v12（分屏 1.0.1）。本节只诊断，不写新代码、不改 Tweak.xm、不动源。

### 11.2 先核实：皇上装的 1.0.3 真的是 v4 代码吗（已确认：是）

- `.deb` SHA256 `ca97da99f5b3c65a30761bbd4d8515ba6a77c3bbb63407c4ba0cb614b7f46d9a`
  与 §10.5 一致；control 解包后**只有 control 一个文件，没有
  postinst / preinst / postrm**——安装时不跑任何脚本，排除"安装脚本卡住"。
- 解包 dylib strings：hook 相关符号计数为 **0**
  （`medusaCapabilities` / `isMedusaCapable` / `iconAllowsLaunch` /
  `wantsFullScreen` / `wantsExclusiveForeground` /
  `DeviceSupportsEnhancedMultitasking` / `supportsMultiwindow` /
  `MGGetBoolAnswer` / `SBFluidSwitcherGestureManager` / `SBMainWorkspace`
  全不在）；v1.0.3 标记在（"v1.0.3 loaded"、"floating trigger button shown"、
  "SpringBoard not settled" 等）。
- 链接库只有 libobjc / Foundation / CoreFoundation / libc++ /
  libSystem / UIKit，无 MobileGestalt、无 substrate。
- filter plist 只写 `com.apple.springboard`，dylib 只进 SpringBoard。
- 结论：皇上装的确实是"零 hook"的 v4 代码，下面按当前这份
  Tweak.xm（480 行）逐行诊断。

### 11.3 启动时到底跑了什么（逐行追踪，按 v4 Tweak.xm 行号）

**%ctor（462–480 行），dylib 加载时跑一次：**
1. 463 行 `GHLSSReloadPrefs()`：读
   `/var/jb/var/mobile/Library/Preferences/com.guhailong.splitscreen.plist`，
   文件不存在默认 NO。同步读一个小 plist，毫秒级，不阻塞。
2. 464–469 行：Darwin 通知中心注册 prefs 变更回调（C 函数指针）；
   只在开关被改时才触发，启动时不跑。
3. 473–474 行：`dispatch_after` 5 秒后主队列跑 `GHLSSApplyFloatingUI()`——
   只排队，不阻塞。
4. 475–478 行：`NSNotificationCenter` 注册
   `UIApplicationDidBecomeActiveNotification`，block 调
   `GHLSSApplyFloatingUI()`。**附带发现的 bug：返回值（observer token）
   没存，ARC 立即释放，观察者实际不生效**——这只会让代码少跑，不会卡住；
   但下版必须修（存到 static 强引用里），否则"每次回前台补一次"根本没生效，
   唯一真正起作用的启动触发只有上面那个 5 秒 dispatch_after。
5. 479 行：NSLog 一行。

**+5 秒后（主队列）：`GHLSSApplyFloatingUI()`（454–460 行）：**
- 开关 OFF → `GHLSSHideFloatingUI()`（441–452 行）：对两个 nil 窗口置
  `hidden = YES`（空操作），计数器归零。**什么都不做。**
- 开关 ON → `GHLSSMaybeShowFloatingUI()`（387–439 行）：
  - 388 行开关检查；390–392 行非主线程则转主线程；393 行窗已存在直接返回；
    394 行重试进行中直接返回。
  - 395–396 行：取 `[UIApplication sharedApplication]` +
    `GHLSSActiveWindowScene()`（92–113 行）：遍历 `connectedScenes`，
    找 `activationState == ForegroundActive` 的 UIWindowScene；
    全是快速属性访问，不阻塞。
  - 397–399 行：settled = app 存在 && `applicationState == Active` &&
    scene 存在 && scene 前台激活。
  - 不满足：400–410 行，attempts < 10 时 +1、Pending = YES、3 秒后主队列
    重试；超 10 次停下。每次重试都是快速检查，不阻塞。
  - 满足：413 行计数器归零；416–434 行 `@try` 里建窗：`UIWindow
    initWithWindowScene:`、frame 56×56、level = `UIWindowLevelStatusBar + 10`、
    clear 背景、UIViewController + 金色 `GHLSSDragButton`（圆角 28、标题"分"）、
    `rootViewController = vc`、`hidden = NO`、赋值 `GHLSSFloatWindow`。
    标准 UIKit 调用，无同步等待、无 LS 调用、无私有接口。

**启动时不跑的东西（同样已确认）：**
- `GHLSSFetchUserApps`（115–154 行，含第 128 行 `allInstalledApplications`
  同步调用）**只在启动器打开时才跑**，且 v4 已改到后台队列
  （`GHLSSLoadApps` 298–316 行：先显示"正在读取…"，后台枚举、回主线程刷新）。
  "装完重启卡住"发生在启动器打开之前，所以 §10.2(c) 在 v4 已排除——
  除非皇上在卡住前点了按钮（他说的是装完重启卡住，未提点按钮）。
- `GHLSSOpenApp`（156–171 行）只在点选 App 时跑；`GHLSSShowLauncher`
  （356–385 行）只在点按钮时跑；拖动回调只在触摸时跑。启动时都不跑。

**结论（已确认）：开关 OFF 时，v4 在启动时做的全部工作 = 读一个小 plist +
注册两个观察者 + 排一个 5 秒后的空操作。没有任何主线程阻塞调用，没有任何
hook，没有任何 UI 创建。** 开关 ON 时，启动时唯一多出来的工作就是建一个
56×56 的 UIWindow（标准 UIKit）。

### 11.4 逐项排除（什么不可能是原因）

- (i) 两个能力位 hook：v4 已删，strings 计数 0。排除。
- (ii) App 列表主线程枚举：v4 已改后台，且启动器没打开就不会跑。排除
  （除非卡住发生在点按钮后——皇上说的是装完重启卡住）。
- (iii) 安装脚本：.deb 里没有 postinst / preinst / postrm。排除。
- (iv) 设置页 prefs bundle：只进"设置"App，不进 SpringBoard。排除。
- (v) dylib 加载本身：加载时只做 plist 读 + 注册观察者；v1/v2/v3 的 dylib
  都正常加载过（v1 加载后进安全模式，说明加载成功）。加载本身基本排除。
- (vi) filter 范围：只进 SpringBoard，无其他进程。排除。

### 11.5 假设排序（按可能性）

**H1（最可能）：开关实际是开的（v1 残留 prefs，步骤 0 很可能没做）+
启动时建窗触发了卡住。**
- 依据：§10.2(a) 的残留机制已确认（v1 默认 YES、Sileo 卸载不删 plist）；
  步骤 0 未确认；皇上回复简短，很可能没做步骤 0。v3 与 v4 都在"装完重启"
  卡住，而 v1（无悬浮窗）是进安全模式——"卡住"这个现象与"悬浮窗"这条线
  对得上，v1 的反衬也支持这一点。
- 但注意：建窗本身是标准 UIKit 调用，正常不该卡住。所以 H1 的"卡住"机制
  仍未确认，子可能有二：(H1a) 建窗时机仍太早——5 秒是从 dylib 加载
  （dyld 期）算起，不是 SpringBoard 就绪后 5 秒；若皇上手机启动慢
  （floatingView 的 Swift/Orion 初始化 + 其他插件），5 秒时 SpringBoard
  仍在建自己的窗口层级，而"settled"判断（applicationState == Active
  且 scene 前台激活）只是启发式，不能保证 SpringBoard 内部已空闲；
  (H1b) 建窗与 floatingView 的 SBMainWorkspace /
  SBFluidSwitcherGestureManager hook 相互作用——floatingView 监听窗口/
  场景变化来管理自己的浮窗，我们的窗出现可能触发它的 hook 代码（未证实）。
- 证实/证伪：(1) 崩溃日志（见 11.7）；(2) 对照实验：确认开关 OFF
  （或删 prefs 文件）后再装，若不卡住 → H1 成立；(3) 卸掉 floatingView
  再装，若不卡住 → H1b 成立。

**H2：floatingView 冲突（与 H1 叠加，或单独成立）。**
- 依据：v4 测试时 floatingView 已装且启用，这是 v3 测试时没有的新变量。
  两个插件都在 SpringBoard 里建高层级浮窗；floatingView 还 hook
  SBMainWorkspace / SBFluidSwitcherGestureManager / SBIcon。
- 但注意：floatingView 单独在皇上手机上跑得好好的（15:42–15:53 截图录屏
  都正常），且我们不 hook 任何东西、没有直接的 hook 冲突点；只能是
  "窗口共存"或"它的 hook 被我们的窗触发"这种间接作用，未证实。
- 证实/证伪：卸掉 floatingView 后重测 v4；崩溃日志里若出现 floatingView
  的符号（`FVRootWindow` / `SBFSGMHook` / `SBMWHook` 等）则支持 H2。

**H3：1.0.3 实际没装上，手机里跑的还是 1.0.2。**
- 依据：若 Sileo 升级失败、或皇上实际装的仍是 1.0.2，症状会与 v3 一模一样
  （带 hook 的代码卡住）。这是"症状相同"的最简单解释。
- 证实/证伪：在 Sileo 里看"顾海龙集团分屏"的已装版本是不是 1.0.3；
  或用 Filza 看 dylib（v3 dylib 202432 字节，v4 dylib 202336 字节——
  太接近，分辨力弱，最好以 Sileo 显示的版本为准）。

**H4：开关确实是关的，v4 代码无辜，卡住来自 respring 本身或其他原因。**
- 依据：开关 OFF 时 v4 在启动时什么都不做（11.3 已确认），代码上不可能卡住。
  若步骤 0 真做了且开关确认关的仍卡住，H4 就是唯一剩下的解释：
  respring 本身挂住、SpringBoard 当时已有问题、或 floatingView 单独出问题。
- 证实/证伪：确认开关 OFF 后重装仍卡住 → H4；崩溃日志里若完全没有
  GuHaiLongSplitScreen 的符号、也没有我们的窗相关调用 → 支持 H4。
  注意：v3 与 v4 两次都在"装完"卡住，纯巧合的可能性低，H4 排在 H1 之后。

**H5：dylib 加载/签名问题。**
- 基本排除（11.4(v)），列出仅为完整：若 ldid 签名或 fat 二进制有问题，
  SpringBoard 会直接崩溃或拒绝加载，不会"卡住"；且 v1/v2/v3 同一工具链
  出的包都加载成功。证实/证伪：崩溃日志里若出现 dyld / libhooker 相关
  崩溃则支持 H5。

### 11.6 最可能的单一原因（判断）

**H1：开关实际是开的（v1 残留 prefs，步骤 0 很可能没做），启动后 5 秒建窗
这一步把 SpringBoard 卡住了。** 机制未确认（H1a 时机 vs H1b floatingView
相互作用），但"开关 ON + 建窗"是 v4 启动时唯一能跑到真实 UI 代码的路径，
也是 v3/v4 两次卡住的唯一共同点。v1 没有悬浮窗、走的是安全模式，更加反衬
出"卡住"与悬浮窗这条线有关。

### 11.7 下一步必须做的诊断（按重要性排序）

1. **崩溃日志（最重要，能定罪）：** 手机恢复后，去"设置 → 隐私与安全性 →
   分析与改进 → 分析数据"，找卡住当时（16:10 左右）时间最接近的
   `SpringBoard-*.ips`（或 `SpringBoard-*.ips.synced`）。点进去看：
   ① Exception Type / Termination Reason——若是 `0x8badf00d`
   （看门狗超时）说明主线程被堵住；② 崩溃线程（通常是 Thread 0）的最上面
   10–20 行调用栈，截图发回来。栈里若出现 `GHLSSMaybeShowFloatingUI` /
   `GHLSSActiveWindowScene` / `-[UIWindow initWithWindowScene:]` → H1 定罪；
   若出现 `FVRootWindow` / `SBFSGMHook` / `SBMWHook` 等 floatingView 符号
   → H2；若完全没有我们的符号 → H4；若是 dyld 相关 → H5。
   **若当时根本没有 SpringBoard 日志**，说明不是崩溃/看门狗杀掉，而是硬卡死
   或 respring 本身没完成，也请告诉主代理（同样是重要信息）。
2. **确认开关状态（第二重要）：** 手机恢复、卸载 1.0.3 之前，先去
   "设置 → 顾海龙分屏"看一眼开关现在是开还是关（若设置页已随卸载消失，
   改用 Filza 看 `/var/jb/var/mobile/Library/Preferences/com.guhailong.splitscreen.plist`
   里 `Enabled` 的值）。这个答案直接决定 H1 成立与否。
3. **确认装上的到底是哪个版本（排除 H3）：** Sileo 里"顾海龙集团分屏"
   已装版本是不是 1.0.3。
4. **对照实验（等上面三条有答案再做，不要现在盲试）：**(a) 确认开关 OFF
   （或删掉 prefs 文件）后重装 v4，若不卡住 → H1；(b) 若仍卡住，再卸掉
   floatingView 重测，若不卡住 → H2。**不要两个变量一起改**（同时关开关
   又卸 floatingView），否则分不清是谁的功劳。

### 11.8 下一版必须改什么（不管哪个假设成立，这些都要做）

1. **启动时什么窗都不建。** 这是 v4 教训的核心：只要启动时建窗，就有卡住
   的风险，且无法从代码上证明"5 秒 + settled 判断"一定安全。下版改为：
   dylib 加载后只登记、不建窗；悬浮按钮只在用户明确操作后才出现
   （例如开关打开后第一次解锁时、或通过一个明确的手势触发），且建窗前加
   一道"SpringBoard 已空闲"的确认（例如等主屏已显示的通知，而不只是
   applicationState == Active）。
2. **修 DidBecomeActive 观察者没存 token 的 bug**（Tweak.xm:475–478）：
   返回值存到 static 强引用里，否则观察者立即失效；顺带把 5 秒
   dispatch_after 的触发逻辑与它统一。
3. **加文件日志（file logging）：** 关键节点（%ctor、每次 Apply、每次
   MaybeShow 的 settled 判断结果、建窗成功/失败）都 append 写到
   `/var/mobile/Library/Logs/GuHaiLongSplitScreen.log`（NSLog 只进 syslog，
   手机卡住后不一定能拿到；文件日志只要手机能开机就能用 Filza 看到）。
   下次再卡住，日志能直接说清卡在哪一步。
4. **先做一个"空壳"对照版再谈功能：** 下版第一步只保留 dylib 加载 +
   日志 + 开关读取，不建任何窗、不读 LS、不注册手势；皇上装完确认不卡住，
   再逐步加回建窗（且建窗时机改到解锁后）。一步一测，不要一次把几个改动
   全押上。
5. **测试流程必须加一道"删残留 prefs"的步骤：** 装新版之前，先用 Filza
   删掉 `/var/jb/var/mobile/Library/Preferences/com.guhailong.splitscreen.plist`
   （或在设置里确认开关是关的），否则"默认 OFF"对这台手机永远不成立，
   任何一版的测试结果都不可信。
6. **floatingView 共存测试单列：** 下版测试分两轮：先卸掉 floatingView
   测（排除 H2），通过后再装回 floatingView 测共存。两轮结果都要报。
7. **v5 的 FrontBoard 悬浮窗方案（V5_DESIGN.md）不受影响**——v5 的核心是
   把第二个 App 的 scene 嵌进窗里，但它同样依赖"在 SpringBoard 里建窗"
   这一步；11.8(1) 的"启动时不建窗"原则同样适用于 v5，v5.1 的边缘滑触发
   反而更符合这条原则（用户手势触发，不在启动时建窗）。

## 12. v5（1.0.4）—— 空壳对照版（只证明加载安全，不加功能）

### 12.1 为什么做 v5（两处已确认的教训，见 §10、§11 + 崩溃日志）

- v1 崩溃日志（皇上 2026-11-12 16:21/16:22 发来的两份
  `SpringBoard-2026-11-12-144157.ips` / `144206.ips`，14:41:55 与
  14:42:05，两次同一处）：EXC_BREAKPOINT / SIGTRAP，主线程，在
  `GuHaiLongSplitScreen.dylib` 的初始化代码调
  `dictionaryWithContentsOfFile:` 读设置文件时，崩在
  `_NSIsNSString` / `object_getMethodImplementation` 里（dyld
  `findAndRunAllInitializers` 阶段）。连崩两次 → 安全模式。
  **v1 进安全模式的真正原因是 %ctor 里读设置文件，不是之前猜的
  medusa 钩子**（钩子还没轮到跑就已经崩了）。
- v4 卡住（2026-11-12 16:10，装完重启卡住）：皇上 16:26 确认
  开关实际是开的（v1 残留 prefs，步骤 0 没做），v4 开机 5 秒后
  建悬浮窗，卡在那一步。H1 前半已确认。
- 皇上 16:28 确认 1.0.3 已从手机卸载；16:30 授权先做 v5，残留
  prefs 文件由他稍后用 Filza 自己删。

### 12.2 v5 改了什么（对照 §11.8 的清单）

1. **%ctor 里不读任何文件。** 设置只在 SpringBoard 完全启动后、
   第一次收到 `UIApplicationDidBecomeActiveNotification` 时才懒读，
   而且用 `CFPreferencesCopyAppValue`（走系统偏好服务，不在进程内
   解析 plist 文件）。`dictionaryWithContentsOfFile:` 已从代码里
   彻底删掉（strings 核对为 0）。
2. **这个版本永远不建窗。** 没有 `UIWindow`、没有启动器、没有
   `LSApplicationWorkspace`、没有手势。开关开着也只记一行日志，
   不做任何 UI。下一步（v5.1 边缘滑 + 启动器，见 V5_DESIGN.md）
   等空壳版真机通过后再做。
3. **修 v4 的观察者 bug：** `addObserverForName:usingBlock:` 的
   返回值存到 static 强引用 `GHLSSActiveObserver` 里。
4. **加文件日志：** `%ctor`、懒读开关、前台激活、设置变更通知，
   全部 append 写到 `/var/mobile/Library/Logs/GuHaiLongSplitScreen.log`
   （纯文本写文件，不解析任何东西；任何一步失败都静默吞掉）。
   卡住后只要手机能开机就能用 Filza 看到日志。
5. **仍不 hook 任何东西。** 开关默认 OFF（Root.plist `<false/>`
   已核对），设置页不动。

### 12.3 编译与校验（2026-11-12 16:31，/tmp/ghlss-v5-build）

- 命令（与 v2/v3/v4 相同）：`rm -rf /tmp/ghlss-v5-build &&
  cp -r <本目录> /tmp/ghlss-v5-build && chmod -R 755
  /tmp/ghlss-v5-build && cd /tmp/ghlss-v5-build &&
  export THEOS=$HOME/theos && umask 022 &&
  make package FINALPACKAGE=1 THEOS_PACKAGE_SCHEME=rootless`。
  一次成功（只有一处无害的 arm64e ABI 警告，与之前各版相同）。
- `.deb`：`com.guhailong.splitscreen_1.0.4_iphoneos-arm64.deb`，
  9572 字节，SHA256
  `45a23aec8c6044ac5ed3f17d3acc025cc08b39cccb5c9c97a668409bffcb5cf5`。
- `dpkg-deb -I`：Package `com.guhailong.splitscreen`，Version
  1.0.4，Architecture `iphoneos-arm64`，Depends 正确。
- `dpkg-deb -c`：dylib（167024 字节）+ filter plist + 设置页
  bundle（Root.plist 在，1702 字节）。
- dylib：Mach-O 通用二进制 arm64 + arm64e；LC_CODE_SIGNATURE
  两处（两 slice 各 1 处，ldid 已签名）。
- strings 核对：**0** —— `dictionaryWithContentsOfFile`、
  `UIWindow`、`LSApplicationWorkspace`、`medusaCapabilities`、
  `MGGetBoolAnswer`、`supportsMultiwindow`、`isMedusaCapable`、
  `floatingView`、`be-huge` 全部为 0；**有** ——
  `CFPreferencesCopyAppValue`（4）、`GuHaiLongSplitScreen.log`（2）、
  `control shell`（4）、`v1.0.4`（6）。
- 备份：`.deb` 的 `.bak` 副本已存到源码目录
  （`com.guhailong.splitscreen_1.0.4_iphoneos-arm64.deb.bak`；
  教训：/tmp 里的 v2 副本曾被系统清理过，重要版本必须在
  workspace 里留一份）。

### 12.4 本地源 v13（只更新本地，未部署，等皇上批准）

- 本地源已换成分屏 1.0.4（1.0.1 .deb 已从本地源删掉，仍 14 个包；
  Packages 9013 字节，SHA256
  `871743cf81e404a17663d1923e564c13263652dc6e469fed2805f51d1c14331e`，
  0 个 1.0.3；Release 已重算；说明页 / 首页 / README 已更新）。
- 部署 zip：`workspace/goals/space/files/ios-jailbreak-repo-v13-deploy.zip`
  （约 44 MB）。**未部署到线上。** 线上仍是 v12（分屏 1.0.1）。

### 12.5 真机测试步骤（给皇上，部署批准后）

0. 先用 Filza 删掉残留的设置文件
   `/var/jb/var/mobile/Library/Preferences/com.guhailong.splitscreen.plist`
   （皇上 16:30 说等会删；Sileo 卸载不删它，开关会一直是开的）。
1. 在 Sileo 里装 1.0.4，respring。
2. 确认：手机正常启动，不卡、不进安全模式。
3. 用 Filza 看日志文件
   `/var/mobile/Library/Logs/GuHaiLongSplitScreen.log`，应有
   “v1.0.4 loaded”“prefs read”“didBecomeActive”三行。
4. 再去设置 → 顾海龙分屏把开关打开，respring 一次，确认还是正常
   （空壳版开着开关也不会出现按钮，这是正常的）。
5. 报回结果；通过后再做 v5.1（边缘滑 + 启动器）。
## 13. v5（1.0.4）—— 装完进安全模式后的诊断（崩溃日志 + 反汇编）

### 13.1 真机结果（2026-11-12，皇上实测）

- 皇上 16:48 报“进入安全模式”。崩溃日志：
  `SpringBoard-2026-11-12-164812.ips`（capture 16:48:11，进程启动
  16:48:09，启动后约 1.4 秒崩溃）。
- 例外：`EXC_BAD_ACCESS` / `SIGSEGV`，主线程，ESR “Address size
  fault”，fault address `0x20f3d1458`。

### 13.2 调用栈（已确认是咱们的代码，见 13.3）

```
libobjc.A.dylib +10272  objc_msgSend            （崩在这里）
GuHaiLongSplitScreen.dylib +30216               （返回地址）
GuHaiLongSplitScreen.dylib +29912               （返回地址）
dyld ... findAndRunAllInitializers ... dlopen_from
```

### 13.3 反汇编定位（arm64e slice，dylib 基址 0x102a74000）

- +29912 = `0x74D8`：`%ctor`（0x74b8）里 `bl GHLSSLog`（0x74d4）
  的下一条指令 —— %ctor 第一件事就是调 `GHLSSLog`。
- +30216 = `0x7608`：`GHLSSLog`（0x75e4）里 `bl _objc_retain`
  （0x7604）的下一条指令 —— `GHLSSLog` 的第一个 ObjC 调用，
  retain 那个 format 常量字符串。
- 寄存器：`x0`（receiver）= `0x102a7c0e8` = dylib 基址 +
  `0x80E8`，正好是 arm64e slice 的 `__cfstring` 段开头（第 1 个
  常量字符串对象）；`lr` = `0x102a7b608`（= 基址 + 0x7608，
  与栈帧一致）；fault address `0x20f3d1458` 是 `objc_msgSend`
  读 isa / 方法缓存时碰到的野指针。
- 结论：**v5 崩在 %ctor 的第一个 ObjC 调用上** —— retain 一个
  编译期常量字符串时，它的 isa 指针是野的。不是日志文件路径的
  问题（文件写操作还没轮到），不是 prefs（v5 根本不读 prefs），
  不是 hook（v5 没有 hook），不是建窗（v5 不建窗）。

### 13.4 与 v1/v3/v4 的对照

- v1 也崩在 %ctor 里（§11 崩溃日志：`dictionaryWithContentsOfFile:`
  读设置文件时崩在 `_NSIsNSString` / `object_getMethodImplementation`）。
- v3/v4 的 %ctor 里同样先调 `dictionaryWithContentsOfFile:`，却没有
  在加载时崩（它们是装完重启后卡住，另一回事）。
- 所以“%ctor 里调 ObjC 一定崩”不成立；“%ctor 里调 ObjC 一定安全”
  也不成立。两次加载时崩溃（v1、v5）与两次没崩（v3、v4）之间，
  目前没有代码层面的决定性差异——可能与加载时机 / 加载顺序 /
  工具链的 arm64e ABI（构建时一直有 “incompatible arm64e ABI
  compiler” 警告）有关。**isa 野指针的确切成因未证实，不硬猜。**
- 另外已确认：两次崩溃日志里 SpringBoard 的已加载镜像都没有
  floatingView 的主 dylib（只有 `FloatingViewKeyboard.dylib`），
  所以这两处加载时崩溃怪不到 floatingView 头上。
- v4 dylib 202336 字节、v5 dylib 167024 字节——v5 的体积不反常，
  不是构建产物损坏的证据；`__cfstring` 段位置与 x0 一致，
  进一步坐实崩溃点就是第 1 个常量字符串。

### 13.5 下一版（v6，1.0.5）必须改什么

- **%ctor 里零 ObjC。** 只留纯 C 调用：`CFNotificationCenterAddObserver`
  （C API）+ `dispatch_after`（C API），把所有 ObjC 工作（日志、
  懒读开关、注册观察者）都推迟到 SpringBoard 完全启动后，在
  dispatch 的 block 里做。连 `NSLog` 都不要放在 %ctor 里。
- 其余 v5 的设计不变：不 hook、不建窗、只写日志（日志写操作也挪
  到启动后），仍是空壳对照版。
- v6 通过真机测试（装完重启不卡、不进安全模式、日志有三行）之后，
  再做 v5.1（边缘滑 + 启动器，见 V5_DESIGN.md）。
- 1.0.4 已确认坏：**不要再装**，并从线上源上撤下（回退到 1.0.1）。

### 13.6 残留 prefs 之谜的修正

- 皇上 16:40 发的两张 Filza 截图（Preferences 文件夹，28 个文件）
  已直接核对：**没有** `com.guhailong.splitscreen.plist`。残留
  prefs 文件根本不存在，开关从来没有靠它留着开过。
- 因此 H1（§11.5）的前提不成立：v4 卡住不是开关开着造成的；
  “开着”应理解为手机开着。v4 卡住的原因重新开放（H2 floatingView
  冲突 / H4 重启本身在前）。
- v1 崩溃日志与“文件不存在”之间的张力如实记录：日志证明崩溃发生
  在读设置文件的调用里；文件现在不存在。可能该文件在 14:41 时存在
  随后被删，也可能崩溃点另有细节——不影响 v6 的修法（%ctor 零
  ObjC 之后，读不读文件都不在加载时发生）。
## 14. v6（1.0.5）—— 纯 C 启动的空壳对照版

### 14.1 为什么做 v6（见 §13）

- v5 崩在 %ctor 的第一个 ObjC 调用上（retain 编译期常量字符串，
  isa 野指针）。v1 也死在 %ctor 里。v6 的铁律：**%ctor 里零 ObjC**。
- 皇上 16:58 批准做 v6（点选“做 v6”）。

### 14.2 v6 改了什么（相对 v5）

1. **%ctor 只留两行纯 C 调用**：`CFNotificationCenterAddObserver`
   （C API）+ `dispatch_after` 5 秒（C API，主队列）。不写日志、
   不读文件、不调 `NSLog`、不建窗、不 hook。
2. **所有 ObjC 工作推迟到 deferred setup**：%ctor 里 dispatch 的
   block 5 秒后在主队列跑 `GHLSSDeferredSetup()`——写日志、懒读开关
   （`CFPreferencesCopyAppValue`）、注册前台激活观察者（token 存住）、
   置启动完成标志。设置变更通知的回调在启动完成前只返回、不做任何
   ObjC。
3. 其余 v5 的设计不变：不 hook、不建窗、只写日志到
   `/var/mobile/Library/Logs/GuHaiLongSplitScreen.log`，仍是空壳对照版。
   开关默认 OFF（Root.plist `<false/>`，未改设置页）。

### 14.3 编译与校验（2026-11-12 17:00，/tmp/ghlss-v6-build）

- 命令（与之前各版相同）：`rm -rf /tmp/ghlss-v6-build &&
  cp -r <本目录> /tmp/ghlss-v6-build && chmod -R 755
  /tmp/ghlss-v6-build && cd /tmp/ghlss-v6-build &&
  export THEOS=$HOME/theos && umask 022 &&
  make package FINALPACKAGE=1 THEOS_PACKAGE_SCHEME=rootless`。
  一次成功（只有一处无害的 arm64e ABI 警告，与之前各版相同）。
- `.deb`：`com.guhailong.splitscreen_1.0.5_iphoneos-arm64.deb`，
  9772 字节，SHA256
  `c41f6b5fb3011b62d03986212dc278d4fac70f3ed50950f9bbad2bfc83e6051d`。
- `dpkg-deb -I`：Package `com.guhailong.splitscreen`，Version
  1.0.5，Architecture `iphoneos-arm64`，Depends 正确。
- `dpkg-deb -c`：dylib（167200 字节）+ filter plist + 设置页
  bundle（Root.plist 在，1702 字节）。
- dylib：Mach-O 通用二进制 arm64 + arm64e；LC_CODE_SIGNATURE
  两处（两 slice 各 1 处，ldid 已签名）。
- strings 核对：**0** —— `dictionaryWithContentsOfFile`、
  `UIWindow`、`LSApplicationWorkspace`、`medusaCapabilities`、
  `MGGetBoolAnswer`、`supportsMultiwindow`、`isMedusaCapable`、
  `floatingView`、`be-huge` 全部为 0；**有** ——
  `CFPreferencesCopyAppValue`（4）、`GuHaiLongSplitScreen.log`（2）、
  `v1.0.5`（8）、`dispatch_after`（4）。
- **%ctor 纯 C 的反汇编核对（arm64e slice，函数起于 0x73e8）**：
  调用的只有 `CFNotificationCenterGetDarwinNotifyCenter`、
  `CFNotificationCenterAddObserver`、`dispatch_time`、
  `dispatch_after`（结尾是 `b _dispatch_after` 尾调用）；**没有**
  `objc_msgSend`、**没有** `NSLog`、**没有**调 `GHLSSLog`。
  %ctor 零 ObjC 已由反汇编证实，不只是代码上这么写。
- 备份：`.deb` 的 `.bak` 副本已存到源码目录
  （`com.guhailong.splitscreen_1.0.5_iphoneos-arm64.deb.bak`）。

### 14.4 本地源 v15（只更新本地，未部署，等皇上批准）

- 本地源已换成分屏 1.0.5（1.0.1 .deb 已从本地源删掉，仍 14 个包；
  Packages 9026 字节，SHA256
  `4c0e8f29f113af3386c8f8c3862926fb4932c51b9635ef47996a9270cb17647e`，
  0 个 1.0.4；Release 已重算；说明页 / 首页 / README 已更新）。
- 部署 zip：`workspace/goals/space/files/ios-jailbreak-repo-v15-deploy.zip`
  （约 44 MB）。**已部署到线上**：皇上 17:02 批准部署；v15 于
  2026-11-12 17:03 部署到线上（部署编号
  6af580c8b1c42da16fae375c，线上 Packages 独立核对过：HTTP 200，
  9026 字节，SHA256 `4c0e8f29…`，含分屏 1.0.5，0 个 1.0.4）。

### 14.5 真机测试步骤（给皇上，部署批准后）

1. 在 Sileo 里装 1.0.5，respring。
2. 确认：手机正常启动，不卡、不进安全模式。
3. 用 Filza 看日志文件
   `/var/mobile/Library/Logs/GuHaiLongSplitScreen.log`，应有
   “v1.0.5 deferred setup”“prefs read”“didBecomeActive”三行。
4. 再去设置 → 顾海龙分屏把开关打开，respring 一次，确认还是正常
   （空壳版开着开关也不会出现按钮，这是正常的）。
5. 报回结果；通过后再做 v5.1（边缘滑 + 启动器）。
## 15. v6（1.0.5）—— 纯 C 启动也还是卡住（2026-11-12 17:06）

### 15.1 真机结果

- 皇上 17:06 报“还是卡住”：装完 1.0.5、respring 后手机又卡住了。
  **1.0.5 不要再装。** 这是今天第五次坏在真机上（v1 安全模式、
  v3 卡住 + 白苹果、v4 卡住、v5 安全模式、v6 卡住）。
- 皇上手机是否恢复、1.0.5 是否已卸、日志文件内容、崩溃日志——
  已问皇上，待回。
- v16 回退已于 2026-11-12 17:07 部署到线上（部署编号
  6af581b610f3c49abc813ffa，线上 Packages 独立核对过：HTTP 200，
  8948 字节，SHA256 `3a087930…`，分屏 1.0.1，0 个 1.0.5）。

### 15.2 这次失败推翻了什么

- v6 的 %ctor 是**反汇编核对过的纯 C**（只调
  CFNotificationCenterGetDarwinNotifyCenter、
  CFNotificationCenterAddObserver、dispatch_time、dispatch_after；
  无 objc_msgSend、无 NSLog、无 GHLSSLog），且所有 ObjC 工作都
  推迟到主屏起来 5 秒后。手机还是卡住了。
- 所以：**“%ctor 里碰 ObjC”是 v1/v5 安全模式的死因，但解释不了
  卡住（v3、v4、v6）**。卡住的毛病在别处。v1/v5 是加载时崩溃
  （有崩溃日志为证），v3/v4/v6 是装完重启卡住（v4 没有崩溃日志，
  硬卡住 + 强制重启通常不产生日志）——这是两类不同的症状，
  不能再混为一谈。
- 卡住的嫌疑（按目前证据排，待日志文件/崩溃日志验证）：
  (a) 推迟到 +5 秒的 deferred setup 里那几行 ObjC（写日志、读开关、
      注册观察者）——但 v3/v4 在加载时做同样量级的事也没崩；
  (b) dylib 被注入/加载这件事本身——与注入器（ElleKit /
      libinjector）或其他插件（floatingView 键盘 dylib、Choicy、
      Crane 等）的加载顺序/互相作用；
  (c) 根本不是咱们的代码——respring 本身、或 Sileo 的安装后处理。
  (d) 设置页 bundle（Root.plist）——但它不在 SpringBoard 启动时
      加载，嫌疑最小。

### 15.3 下一步（等皇上手机恢复 + 日志回来再定，不催）

- **关键证据是 v6 的日志文件**
  `/var/mobile/Library/Logs/GuHaiLongSplitScreen.log`：
  没文件/空文件 = 卡在 +5 秒之前（加载或重启本身）；
  有“v1.0.5 deferred setup”行 = deferred setup 跑起来了，卡在
  之后；有“prefs read”/“didBecomeActive”行 = 还要往后排。
- **决定性对照测试（v7，1.0.6，空 dylib）**：只留 filter plist +
  一个 %ctor 里什么都不做的 dylib（连两行纯 C 登记都不要）。
  如果空 dylib 也卡住，毛病在注入/加载本身（或根本不是咱们的
  代码）；如果不卡，再把两行纯 C 登记、再把 deferred setup
  一件一件加回去，看加到哪件开始卡。**一次只加一件。**
- 在拿到日志/崩溃日志、皇上点头之前，不再做新版、不再催安装。
  五次都坏在同一台手机上，下一版必须先有证据再动手。
## 16. v7（1.0.6）—— 空 dylib 对照版

### 16.1 为什么做 v7（见 §15）

- v6 卡住时 log 文件根本不存在（皇上 20:08 确认）→ deferred
  setup（+5 秒）根本没跑起来，卡在重启、主屏刚起来的那几秒里；
  也没有 17:05 左右的 SpringBoard 崩溃日志（硬卡住 + 强制重启
  通常不产生日志，v4 同理）。
- v6 的 %ctor 是反汇编验过的纯 C，还是卡住。所以卡住的毛病不在
  插件的代码写了什么。v7 把 dylib 里能拿掉的都拿掉，只测一件事：
  **“光是把咱们的 dylib 塞进 SpringBoard 加载，手机会不会卡住？”**
- 皇上 20:09 确认 1.0.5 已卸载，手机安全；20:11 说“想试”——
  批准做 v7 对照测试。

### 16.2 v7 是什么

- Tweak.xm 只有注释，没有任何代码：没有 %ctor、没有 hook、
  不读开关、不写日志、不建窗。只留 filter（注入 SpringBoard）
  和设置页（开关还在，但什么都不干）。
- 本次唯一变量就是 dylib 本身：v6（纯 C %ctor + deferred setup）
  → v7（什么都没有）。其余 13 个包、源结构一概不动。

### 16.3 编译与校验（2026-11-12 20:11，/tmp/ghlss-v7-build）

- 命令与之前各版相同（/tmp 构建、umask 022、FINALPACKAGE=1、
  THEOS_PACKAGE_SCHEME=rootless）。一次成功。
- `.deb`：`com.guhailong.splitscreen_1.0.6_iphoneos-arm64.deb`，
  6282 字节，SHA256
  `28b51e657ebdcc2aa50f0430282f4311b4f125b346759700c732a328c1215ef8`。
- `dpkg-deb -I`：Package `com.guhailong.splitscreen`，Version
  1.0.6，Architecture `iphoneos-arm64`。
- `dpkg-deb -c`：dylib（99072 字节）+ filter plist + 设置页
  bundle（Root.plist 在，1702 字节）。
- dylib：Mach-O 通用二进制 arm64 + arm64e；LC_CODE_SIGNATURE
  两处（两 slice 各 1 处）。
- strings 核对：**0** —— `GuHaiLongSplitScreen.log`、
  `CFPreferencesCopyAppValue`、`dispatch_after`、
  `dictionaryWithContentsOfFile`、`UIWindow`、
  `LSApplicationWorkspace`、`medusaCapabilities`、
  `MGGetBoolAnswer`、`supportsMultiwindow`、`floatingView`、
  `be-huge`、`NSLog` 全部为 0。
- **反汇编核对：两 slice 的 `__text` 段大小都是 0，全文件
  `bl` 指令 0 条，`objc_msgSend` 0 处。dylib 里一行代码都没有，**
  只有 `__objc_imageinfo`。dyld 加载它时没有任何初始化器可跑。
- 备份：`.deb` 的 `.bak` 副本已存到源码目录
  （`com.guhailong.splitscreen_1.0.6_iphoneos-arm64.deb.bak`）；
  v6 的 Tweak.xm / control 已另存为 `Tweak.xm.v6.bak` /
  `control.v6.bak`。

### 16.4 本地源 v17（只更新本地，未部署，等皇上批准）

- 本地源已换成分屏 1.0.6（1.0.1 .deb 已从本地源删掉，仍 14 个包；
  Packages 8838 字节，SHA256
  `01a4f3a273486cc5f5ab37f4a5ab69ad2fcd37d1491a1b01891a176ae54070bb`，
  0 个 1.0.5；Release 已重算；说明页 / 首页 / README 已更新）。
- 部署 zip：`workspace/goals/space/files/ios-jailbreak-repo-v17-deploy.zip`
  （约 44 MB）。**已部署到线上**：皇上 20:13 批准部署；v17 于
  2026-11-12 20:13 部署到线上（部署编号
  6af5ad7a783330eaba89a534，线上 Packages 独立核对过：HTTP 200，
  8838 字节，SHA256 `01a4f3a2…`，含分屏 1.0.6，0 个 1.0.5）。

### 16.5 真机测试步骤（给皇上，部署批准后）

1. 在 Sileo 里装 1.0.6，respring。
2. 确认：手机正常启动，不卡、不进安全模式。
3. 怎么判：
   - 空 dylib 也卡住 → 毛病在注入/加载本身（或根本不是咱们的
     代码）；下一步是查注入器/其他插件/重启本身，不再加代码。
   - 空 dylib 不卡 → 毛病在咱们代码做的某件事上；再把东西
     一件一件加回去（先加两行纯 C 登记，再加 deferred setup……），
     看加到哪件开始卡。一次只加一件。
4. 要是卡住：强制重启、关注入重越狱、卸掉本包，再报给奴才。
## 17. v7（1.0.6）真机通过 + v8（1.0.7）—— 只加回两行纯 C 登记

### 17.1 v7 真机结果（2026-11-12 20:18，皇上实测）

- **v7 1.0.6 空 dylib：装完正常启动，不卡、不进安全模式。**
  这是今天第一次有咱们的插件在皇上手机上装完不出事。
- 结论：**光是把 dylib 塞进 SpringBoard 加载不会卡住。**
  毛病在咱们代码做的某件事上，不在注入/加载本身，也不在
  重启本身。v3/v4/v6 卡住的原因收窄到“%ctor 或启动后代码
  做的事”，而 v7 与 v6 之间唯一的区别就是 %ctor 里的两行
  纯 C 调用（CFNotificationCenterAddObserver + dispatch_after
  5 秒）——v6 又卡在 5 秒之前（log 文件不存在，deferred
  setup 没跑起来）。所以 v8 一次只加回这一件。

### 17.2 v8 是什么（相对 v7）

- %ctor 里恢复两行纯 C 登记（与 v6 相同）：登记设置变更通知
  （回调是空的）+ dispatch_after 5 秒（block 是空的）。
- 其余 v7 不变：不 hook、不读开关、不写日志、不建窗。
- 判法：
  - v8 不卡 → 两行纯 C 登记清白，下一版再加 deferred setup
    （写日志 + 读开关 + 注册观察者）；
  - v8 卡住 → 毛病就在这两行纯 C 登记里，再拆成两版单测
    （只留 AddObserver / 只留 dispatch_after）。

### 17.3 编译与校验（2026-11-12 20:18，/tmp/ghlss-v8-build）

- 命令与之前各版相同（/tmp 构建、umask 022、FINALPACKAGE=1、
  THEOS_PACKAGE_SCHEME=rootless）。一次成功。
- `.deb`：`com.guhailong.splitscreen_1.0.7_iphoneos-arm64.deb`，
  7162 字节，SHA256
  `0ab027d1cb7713cd439555a83c220ff9c525c9ebdfed8172ed8b547263b115e9`。
- `dpkg-deb -I`：Package `com.guhailong.splitscreen`，Version
  1.0.7，Architecture `iphoneos-arm64`。
- `dpkg-deb -c`：dylib（148944 字节）+ filter plist + 设置页
  bundle（Root.plist 在，1702 字节）。
- dylib：Mach-O 通用二进制 arm64 + arm64e；LC_CODE_SIGNATURE
  两处（两 slice 各 1 处）。
- strings 核对：**0** —— `GuHaiLongSplitScreen.log`、
  `CFPreferencesCopyAppValue`、`dictionaryWithContentsOfFile`、
  `UIWindow`、`LSApplicationWorkspace`、`medusaCapabilities`、
  `MGGetBoolAnswer`、`supportsMultiwindow`、`floatingView`、
  `be-huge`、`NSLog` 全部为 0；**有** ——
  `CFNotificationCenterAddObserver`（4）、`dispatch_after`（4），
  正是本版要测的两行调用。
- **反汇编核对：两 slice 的 %ctor 里调的只有**
  `CFNotificationCenterGetDarwinNotifyCenter`、
  `CFNotificationCenterAddObserver`、`dispatch_time`、
  `dispatch_after`（结尾是 `b _dispatch_after` 尾调用）；
  全文件 `objc_msgSend` 0 处。**%ctor 里零 ObjC。**
- 备份：`.deb` 的 `.bak` 副本已存到源码目录
  （`com.guhailong.splitscreen_1.0.7_iphoneos-arm64.deb.bak`）；
  v7 的 Tweak.xm / control 已另存为 `Tweak.xm.v7.bak` /
  `control.v7.bak`。

### 17.4 本地源 v18（只更新本地，未部署，等皇上批准）

- 本地源已换成分屏 1.0.7（1.0.6 .deb 已从本地源删掉，仍 14 个包；
  Packages 8905 字节，SHA256
  `d6da93ecc0e0a314d08638750821fe21835812a32d4aa4021633d9bc0c2f4d97`，
  0 个 1.0.6；Release 已重算；说明页 / 首页 / README 已更新）。
- 部署 zip：`workspace/goals/space/files/ios-jailbreak-repo-v18-deploy.zip`
  （约 44 MB）。**已部署到线上**：皇上 20:19 批准部署；v18 于
  2026-11-12 20:20 部署到线上（部署编号
  6af5aef5d0dfe0102bbddfd6，线上 Packages 独立核对过：HTTP 200，
  8905 字节，SHA256 `d6da93ec…`，含分屏 1.0.7，0 个 1.0.6）。

### 17.5 真机测试步骤（给皇上，部署批准后）

1. 在 Sileo 里装 1.0.7，respring。
2. 确认：手机正常启动，不卡、不进安全模式。
3. 要是卡住：强制重启、关注入重越狱、卸掉本包，再报给奴才。
## 18. v8（1.0.7）—— 加回两行纯 C 登记也卡住（2026-11-12 20:30）

### 18.1 真机结果

- 皇上 20:30 报“卡住了”：装完 1.0.7、respring 后手机又卡住了。
  **1.0.7 不要再装。** 这是今天第六次坏在真机上（v1 安全模式、
  v3 卡住 + 白苹果、v4 卡住、v5 安全模式、v6 卡住、v8 卡住；
  v7 空 dylib 是唯一装完不卡的）。
- 皇上手机是否恢复、1.0.7 是否已卸——已问皇上，待回。
- v19 回退已于 2026-11-12 20:31 部署到线上（部署编号
  6af5b1a67ce050cb0721e136，线上 Packages 独立核对过：HTTP 200，
  8838 字节，SHA256 `01a4f3a2…`，分屏 1.0.6，0 个 1.0.7）。

### 18.2 现在的证据全貌（六败一胜）

| 版 | %ctor 里有什么 | 真机结果 |
|----|--------------|---------|
| v1 1.0.0 | 读设置文件（ObjC）+ hook | 安全模式（崩在 %ctor 读文件） |
| v3 1.0.2 | 读设置文件 + hook + 悬浮窗 | 卡住 + 白苹果 |
| v4 1.0.3 | 读设置文件 + 5 秒后建窗 | 卡住 |
| v5 1.0.4 | 写日志（ObjC） | 安全模式（崩在 %ctor 写日志） |
| v6 1.0.5 | 两行纯 C 登记 + 5 秒后 deferred | 卡住（log 不存在，卡在 5 秒前） |
| v7 1.0.6 | **没有 %ctor** | **正常启动，不卡** |
| v8 1.0.7 | 两行纯 C 登记，deferred 是空的 | 卡住 |

- 规律：**凡是 %ctor 里跑了代码的版，全坏了；唯一没有 %ctor
  的版，好了。** v1/v5 是加载时崩溃（有崩溃日志），v3/v4/v6/v8
  是装完重启卡住（无崩溃日志）。
- 但“任何 %ctor 代码都卡住”不能照字面信：皇上手机上其他插件
  （floatingView、Choicy、Crane 等）都有 %ctor、都正常工作。
  所以更可能的解释是：**咱们这套工具链编出来的 %ctor 本身有
  问题**（构建时一直有的 arm64e ABI 警告），或者咱们 %ctor 里
  的某次调用在 dyld 初始化阶段不安全——而不是“%ctor”这个概念
  有问题。

### 18.3 下一步（v9，1.0.8）：空 %ctor 单测

- **v9 = 显式写一个空的 `%ctor { }`**（有构造函数，但里面
  什么都不做）。它与 v7 的区别只有一处：v7 连构造函数都没有，
  v9 有一个空构造函数。
  - 空 %ctor 也卡住 → 构造函数机制本身（工具链编出来的 %ctor）
    有问题；出路是**不要用 %ctor**——改用 hook SpringBoard
    启动后才跑的方法做初始化（%hook 本身也要靠 %ctor 注册，
    得另想办法；或换工具链重编）。
  - 空 %ctor 不卡 → %ctor 本身没事，毛病在两行纯 C 登记里；
    再拆成两版单测（只留 AddObserver / 只留 dispatch_after）。
- 在皇上手机恢复、1.0.7 卸掉、皇上点头之前，不做 v9、不催安装。
## 19. v9（1.0.8）—— 空 %ctor 单测

### 19.1 为什么做 v9（见 §18）

- v8 也卡住了。六败一胜：凡是 %ctor 里跑了代码的版全坏了，
  唯一没有 %ctor 的 v7 好了。但别的插件也有 %ctor、都好好的，
  所以毛病可能在咱们这套工具链编出来的 %ctor 本身（构建时
  一直有的 arm64e ABI 警告），或者在 %ctor 里的某次调用上。
- v9 只测一件事：显式写一个空的 `%ctor { }`（有构造函数，
  但里面什么都不做）。它与 v7 的区别只有一处：v7 连构造函数
  都没有，v9 有一个空构造函数。
- 皇上 20:33 批准做 v9（点选“做 v9 空 %ctor”）。

### 19.2 v9 是什么（相对 v7）

- Tweak.xm 里只有 `%ctor { }` 一个空构造函数。不 hook、
  不读开关、不写日志、不建窗、不调任何函数。
- 判法：
  - 空 %ctor 也卡住 → 构造函数机制本身（工具链编出来的
    %ctor）有问题；出路是不要用 %ctor，改别的初始化办法；
  - 空 %ctor 不卡 → %ctor 本身没事，毛病在两行纯 C 登记里；
    再拆成两版单测（只留 AddObserver / 只留 dispatch_after）。

### 19.3 编译与校验（2026-11-12 20:33，/tmp/ghlss-v9-build）

- 命令与之前各版相同（/tmp 构建、umask 022、FINALPACKAGE=1、
  THEOS_PACKAGE_SCHEME=rootless）。一次成功。
- `.deb`：`com.guhailong.splitscreen_1.0.8_iphoneos-arm64.deb`，
  6560 字节，SHA256
  `175eff195cae359fa658417f5698ee403a347013a216abc271ede7036eba3765`。
- `dpkg-deb -I`：Package `com.guhailong.splitscreen`，Version
  1.0.8，Architecture `iphoneos-arm64`。
- `dpkg-deb -c`：dylib（131968 字节）+ filter plist + 设置页
  bundle（Root.plist 在，1702 字节）。
- dylib：Mach-O 通用二进制 arm64 + arm64e；LC_CODE_SIGNATURE
  两处（两 slice 各 1 处）。
- strings 核对：**0** —— `GuHaiLongSplitScreen.log`、
  `CFPreferencesCopyAppValue`、`CFNotificationCenterAddObserver`、
  `dispatch_after`、`dictionaryWithContentsOfFile`、`UIWindow`、
  `LSApplicationWorkspace`、`medusaCapabilities`、
  `MGGetBoolAnswer`、`supportsMultiwindow`、`floatingView`、
  `be-huge`、`NSLog` 全部为 0。
- **反汇编核对（关键）：两 slice 的 `__text` 段大小都是 4 字节
  （v7 是 0 字节——v9 确实多了一个构造函数），arm64e 的
  `__text` 里只有一条指令 `ret`（0x7fb0）；全文件 `bl` 指令
  0 条，`objc_msgSend` 0 处。构造函数存在，但只做一件事：
  立即返回。**
- 备份：`.deb` 的 `.bak` 副本已存到源码目录
  （`com.guhailong.splitscreen_1.0.8_iphoneos-arm64.deb.bak`）；
  v8 的 Tweak.xm / control 已另存为 `Tweak.xm.v8.bak` /
  `control.v8.bak`。

### 19.4 本地源 v20（只更新本地，未部署，等皇上批准）

- 本地源已换成分屏 1.0.8（1.0.6 .deb 已从本地源删掉，仍 14 个包；
  Packages 8895 字节，SHA256
  `05ca1c44eae2295bcad90a4b627009a31cc2052cc2d191e6611e39b5e5e2f94d`，
  0 个 1.0.7；Release 已重算；说明页 / 首页 / README 已更新）。
- 部署 zip：`workspace/goals/space/files/ios-jailbreak-repo-v20-deploy.zip`
  （约 44 MB）。**部署失败，未上线。** 2026-11-12 20:36–20:37
  两次上传都被 Netlify 挡住：“Account credit usage exceeded -
  new deploys are blocked until credits are added”（账号额度用完，
  新部署被暂停；不是文件或登录问题）。没有产生 v20 部署记录。
  线上仍是 v19（分屏 1.0.6，独立核对过：HTTP 200，8838 字节，
  SHA256 `01a4f3a2…`，0 个 1.0.7）。今天一共部署了约 14 次
  （每次约 44 MB），额度被耗尽；要等下个账单周期恢复，或升级/
  加购额度，或搬到别的免费托管。v9 的本地源和部署 zip 都已备好，
  额度恢复后可直接重传。

### 19.5 真机测试步骤（给皇上，部署批准后）

1. 先确认手机已恢复、1.0.7 已卸掉。
2. 在 Sileo 里装 1.0.8，respring。
3. 确认：手机正常启动，不卡、不进安全模式。
4. 要是卡住：强制重启、关注入重越狱、卸掉本包，再报给奴才。

## 20. Cloudflare Pages 部署后 Sileo 报 zst 错（2026-11-12 22:03）

### 20.1 报错

- 皇上在 Sileo 里加了新源 `https://guhailong-repo.pages.dev`，刷新时红字：
  `Error: Could not decompress packages from https://guhailong-repo.pages.dev/ (zst):
  未能完成操作。(Sileo.ZSTDError错误2。)`
- 服务器这边核对过是好的：Release、Packages、Packages.gz、Packages.bz2
  全都正常，哈希对得上，14 个包、分屏 1.0.8。

### 20.2 原因

- Sileo 刷新时会先要 `Packages.zst`（zstd 压缩的清单），源里没有这个文件。
- Cloudflare Pages 对不存在的路径不是回 404，而是回 **200 + 首页 index.html**
  （实测 `/Packages.zst`、`/nonexistent-test-123`、`/Release.gpg` 全是
  HTTP 200、8503 字节、text/html，就是首页内容）。Sileo 拿到首页 HTML
  当 zstd 解，解不开就报 ZSTDError 2。
- Netlify 那边缺文件是回 404，Sileo 会自己换 .gz，所以以前没事。
  这是托管方的行为差，不是源文件的问题。

### 20.3 修复

- 给源里加了一个真的 `Packages.zst`：Python `zstandard` 0.25.0（level 19），
  3516 字节，解压回放核对过，和 Packages 一模一样（SHA256 `05ca1c44…`）。
- Release 用新脚本重算，四个哈希段都加上了 Packages.zst：
  `workspace/goals/space/files/ios-jailbreak-split-screen/regen_release.py`
  （保留原头部，只重算哈希；文件顺序 Packages、Packages.gz、Packages.bz2、
  Packages.zst）。
- 2026-11-12 约 22:11 重新传到 Cloudflare Pages（64 个文件，2 个新传），
  线上核对过：`/Packages.zst` 200、3516 字节，解出来 SHA256 和本地一致；
  线上 Release 有 Packages.zst 的哈希（SHA256 `28eeace1…`）；Packages
  仍是 14 个包、分屏 1.0.8、0 个 1.0.7。
- 注意：本机没有 zstd 命令行（`apt-get install zstd` 找不到包，
  `apt-get update` 跑了 5 分钟没出结果，后来杀掉了）；用的是
  `python3 -m pip install --user --break-system-packages zstandard`。
- 以后上架插件的步骤里也要加一步：压好 Packages.zst 再重算 Release
  （README 已更新）。

## 21. v9（1.0.8）—— 空 %ctor 真机通过（2026-11-12 约 22:14）

### 21.1 结果

- 皇上从 Cloudflare 新源安装了 1.0.8，手机正常启动，**通过**。
- 这是第一个带 %ctor 还能正常开机的版本（v7 是完全没 %ctor 的空 dylib）。
- 结论：%ctor 机制本身没坏，空的构造器能跑；问题出在 %ctor 里**做的事**，
  也就是 v8 加回的那两行纯 C 登记（`CFNotificationCenterAddObserver` +
  `dispatch_after` 5 秒）中的某一个，或者两者的组合。

### 21.2 下一步（等皇上批准再做）

- 分测：v10a 只加回 `CFNotificationCenterAddObserver`（回调为空），
  v10b 只加回 `dispatch_after`（block 为空），一次测一个。
- 哪个卡住就是哪个有问题；两个都过，再往回加延迟初始化（日志 →
  读开关 → 观察者），一次加一件。

## 22. v10a（1.0.9）—— 只留通知登记单测

### 22.1 为什么做 v10a（见 §21）

- v9（1.0.8，空 %ctor）皇上真机实测通过（2026-11-12 约 22:14）：
  装完正常启动。%ctor 机制本身没坏，毛病在 %ctor 里做的事上，
  也就是 v8 加回的两行纯 C 登记中的某一个。
- v10a 一次只加回第一件：%ctor 里只调 `CFNotificationCenterAddObserver`，
  回调是空的 C 函数；不调 `dispatch_after`。
- 皇上 22:14 批准做 v10a（点选“做 v10a 试试”）。

### 22.2 编译与校验（2026-11-12 22:15，/tmp/ghlss-v10a-build）

- 命令与之前各版相同（/tmp 构建、umask 022、FINALPACKAGE=1、
  THEOS_PACKAGE_SCHEME=rootless）。一次成功。
- `.deb`：`com.guhailong.splitscreen_1.0.9_iphoneos-arm64.deb`，
  6894 字节，SHA256
  `5651f4884054199f4665ada49cee8275ceb13124ea4e277ed0133641de2b70b0`。
- `dpkg-deb -I`：Package `com.guhailong.splitscreen`，Version
  1.0.9，Architecture `iphoneos-arm64`。
- `dpkg-deb -c`：dylib（148704 字节）+ filter plist + 设置页
  bundle（Root.plist 在，1702 字节）。
- dylib：Mach-O 通用二进制 arm64 + arm64e；LC_CODE_SIGNATURE
  两处（两 slice 各 1 处）。
- strings 核对：**0** —— `GuHaiLongSplitScreen.log`、
  `CFPreferencesCopyAppValue`、`dispatch_after`、
  `dictionaryWithContentsOfFile`、`UIWindow`、
  `LSApplicationWorkspace`、`medusaCapabilities`、
  `MGGetBoolAnswer`、`supportsMultiwindow`、`floatingView`、
  `be-huge`、`NSLog` 全部为 0；`CFNotificationCenterAddObserver`
  存在（4 处，正是 v10a 要测的那一行）。
- **反汇编核对（关键）：arm64e 的 `__text` 一共只有 19 行，
  就是 %ctor 一个函数：`bl _CFNotificationCenterGetDarwinNotifyCenter`，
  设好 6 个参数（x1 = 0，x2 = 空回调地址，x3 = cfstring
  `@"com.guhailong.splitscreen.prefschanged"`，x4 = 0，w5 = 4），
  再 `b _CFNotificationCenterAddObserver`（尾调用）。空回调本身
  就是一条 `ret`。`objc_msgSend` 0 处，`dispatch_after` 0 处。
  %ctor 只调这两个 C 函数，别的什么都不做。**
- 备份：`.deb` 的 `.bak` 副本已存到源码目录
  （`com.guhailong.splitscreen_1.0.9_iphoneos-arm64.deb.bak`）；
  v9 的 Tweak.xm / control 已另存为 `Tweak.xm.v9.bak` /
  `control.v9.bak`。

### 22.3 本地源 v21（只更新本地，未部署，等皇上批准）

- 本地源已换成分屏 1.0.9（1.0.8 .deb 已从本地源删掉，仍 14 个包；
  Packages 含 1.0.9，0 个 1.0.8；Packages.gz / .bz2 / .zst 与
  Release 已重算；说明页 / 首页 / README 已更新）。
- 判法：
  - v10a 不卡 → 通知登记是清白的，毛病在 dispatch_after；
    下一版做 v10b（只留 dispatch_after，block 是空的）；
  - v10a 卡住 → 毛病就在 AddObserver 这一行。

### 22.4 真机测试步骤（给皇上，部署批准后）

1. 先确认手机已恢复、1.0.8 已卸掉（或直接在 Sileo 里升级到 1.0.9）。
2. 在 Sileo 里装 1.0.9，respring。
3. 确认：手机正常启动，不卡、不进安全模式。
4. 要是卡住：强制重启、关注入重越狱、卸掉本包，再报给奴才。

### 22.5 部署到 Cloudflare Pages（皇上 22:19 批准“部署到源上”）

- `cloudflare_deploy.py` 部署成功（Deployment complete），
  但脚本自带的线上检查报了 LIVE CHECK FAILED——原因是脚本里还
  写死检查 1.0.8，而新版是 1.0.9，部署本身没失败。已把脚本的
  检查改成动态的：线上 Packages 与本地 Packages 逐字节比对，
  以后换版本不用再改脚本。
- 独立核对过线上：首页 200；`/Packages` 200、8889 字节、14 个包、
  分屏 1.0.9、0 个 1.0.8，与本地 Packages 逐字节相同；
  `/Packages.zst` 200、3494 字节，解出来与线上 Packages 一致；
  Release 里有 Packages.zst 的哈希。v21 已上线。

## 23. v10a（1.0.9）—— 只留通知登记也卡住（2026-11-12 22:21）

### 23.1 结果

- 皇上从 Cloudflare 新源安装了 1.0.9，装完重启**卡住了**。
- 判法兑现：v9 空 %ctor 不卡，v10a 只加回一行
  `CFNotificationCenterAddObserver` 就卡住了——**毛病就在
  AddObserver 这一行**。在 %ctor（dyld 初始化）期间调
  `CFNotificationCenterAddObserver` 会卡住皇上手机的 SpringBoard。
- 七败两胜：v1 Safe Mode、v3 卡住 + 白苹果、v4 卡住、v5 Safe Mode、
  v6 卡住、v8 卡住、v10a 卡住；只有 v7 空 dylib 与 v9 空 %ctor
  装完不卡。

### 23.2 回退到 v22（1.0.8）

- 按老规矩立刻回退：本地源换回 1.0.8 .deb（1.0.9 .deb 已删），
  Packages / .gz / .bz2 / .zst 与 Release 已重算，说明页 / 首页 /
  README 已更新回 1.0.8（含 v10a 已废弃的警告）。
- 2026-11-12 约 22:23 部署到 Cloudflare Pages，线上核对过：
  Packages 与本地逐字节相同，14 个包，分屏 1.0.8，0 个 1.0.9。
  源上又是安全的版本了。

### 23.3 下一步（等皇上手机恢复、批准再做）

- v10b：只留 `dispatch_after`（block 是空的），验证另一行是不是
  也一样卡。按 v10a 的结果，dispatch_after 很可能也是清白的，
  但没测过不能算数。
- 更远的路：如果两行单测一坏一好，坏的那行就是凶手；如果两行
  都坏，说明 %ctor 里调任何 C 函数都有风险，出路是不要在 %ctor
  里调任何东西，改用别的初始化办法（比如第一次收到通知或
  SpringBoard 启动完成后再登记）。

## 24. v10b（1.0.10）—— 只留 dispatch_after 单测（2026-11-12 22:25 批准制作）

### 24.1 目的

- v10a（1.0.9，只留通知登记）皇上真机实测：装完重启卡住
  （2026-11-12 约 22:21）。结论：**毛病在 AddObserver 这一行**。
- v10b 一次只加回 v8 两行中的第二行：%ctor 里只调 dispatch_after
  （5 秒后在主队列跑一个空 block），不调 CFNotificationCenterAddObserver。
- 判法：v10b 不卡 = dispatch_after 是清白的，AddObserver 是唯一凶手，
  以后启动时只用 dispatch_after 延后做事，绝不在 %ctor 里登记通知；
  v10b 也卡住 = %ctor 里调任何东西都会卡，出路是不要在 %ctor 里调
  任何东西（改用别的初始化办法），或拿掉 arm64e 只出 arm64 的版
  再测（工具链的 arm64e 最可疑）。
- 不 hook、不读开关、不写日志、不建窗。Tweak.xm / control 已备份
  为 .v10a.bak，.deb 已备份为
  com.guhailong.splitscreen_1.0.10_iphoneos-arm64.deb.bak。

### 24.2 编译与校验（2026-11-12 22:25，/tmp/ghlss-v10b-build）

- 命令与 v10a 相同（/tmp 里编，umask 022，FINALPACKAGE=1，
  THEOS_PACKAGE_SCHEME=rootless）。
- .deb **6990 字节，SHA256 `6b7c4ed46ef7735648b23fe59a8995b63f847f9917ad6f8f49f31a219d121173`**；
  dpkg-deb -I/-c 验过（dylib 148656 字节，filter plist、prefs
  bundle、Root.plist 1702 字节都在）。
- Mach-O 通用 arm64 + arm64e，LC_CODE_SIGNATURE 两个片都有。
- strings：禁用的全部是 0（日志路径、CFPreferencesCopyAppValue、
  dictionaryWithContentsOfFile、NSLog、UIWindow、medusa、
  floatingView、MGGetBoolAnswer、supportsMultiwindow、
  LSApplicationWorkspace），**CFNotificationCenterAddObserver 0、
  CFNotificationCenterGetDarwinNotifyCenter 0、prefschanged 0**；
  dispatch_after 4、dispatch_time 4；dispatch_get_main_queue 0
  是正常的——它是内联的，编译器直接取 `__dispatch_main_q`
  的地址，不留符号。
- arm64e __text 一共 19 行（与 v10a 同形）：%ctor 先
  `bl _dispatch_time`（x0=0，x1=5,000,000,000 纳秒），再取主
  队列地址、取空 block 的地址，尾调用 `b _dispatch_after`；
  **objc_msgSend 0**。%ctor 里只有这两行 C 调用，没有别的。

### 24.3 本地源 v23（只更新本地，未部署，等皇上批准）

- 本地源换成 1.0.10 .deb（1.0.8 .deb 已删），Packages / .gz /
  .bz2 / .zst 与 Release 已重算（Packages.zst 往返校验过），
  14 个包，分屏 1.0.10，0 个 1.0.8；说明页 / 首页 / README
  已更新到 v10b。
- 线上还是 v22（分屏 1.0.8），等皇上批准再部署。

### 24.4 真机测试步骤（等部署后）

1. 确认手机已恢复（1.0.9 已卸掉）；
2. Sileo 里直接升级装 1.0.10，respring，确认正常启动、不卡、
   不进安全模式，报给奴才；
3. 要是卡住：强制重启 → Dopamine 关注入重越狱 → 卸掉 1.0.10
   → 报给奴才，奴才立刻把源换回 1.0.8。

### 24.5 部署到 Cloudflare Pages（皇上 22:26 批准“部署到源上”）

- 部署本身成功（新部署 ff0248a3），但脚本刚部署完立刻去验，
  抓到的还是旧版 Packages（8038 字节 = v22），报了 LIVE CHECK FAILED；
  紧接着奴才自己 curl 又抓到更旧的 8895 字节（v20 的）。原因是
  **Cloudflare 边缘节点有传播延迟**：不同节点在同一分钟里
  吐出不同版本。等了一分钟再抓，主域名就是新版了。
- 独立核对过线上：`/Packages` 200、8925 字节，与本地 v23 逐字
  节相同，14 个包，分屏 1.0.10，0 个 1.0.8；`/Packages.zst`
  解出来与线上 Packages 一致；首页 200。v23 已上线。
- 教训：以后部署脚本报 LIVE CHECK FAILED，先别慌，等一分钟再
  抓一次线上核对；边缘传播延迟是常事，不是部署失败。

### 24.6 真机测试：v10b 过了（2026-11-12 22:30）

- 皇上装了 1.0.10，手机正常启动，**没问题**。v10b 通过。
- 结论：**dispatch_after 是清白的，AddObserver 是唯一凶手**。
  %ctor 里只调 dispatch_after 不卡；只调 AddObserver 就卡。
- 路通了：以后启动时只用 dispatch_after 延后做事，绝不在
  %ctor 里登记通知。通知登记要挪到延后的步骤里（等 SpringBoard
  启动完成后再登记），那是 v11 要测的。

## 25. 旧 Netlify 源站已删除（2026-11-12 约 22:30）

- 皇上说旧版可以删、没必要留着。浏览器任务删了
  resonant-biscochitos-df682c（核对过站名与项目 ID
  2f1ff3d9-c4b7-4378-821f-9f019fe78b64，账号 2309103548@qq.com）：
  Project configuration → Configuration → Danger zone →
  Delete this project，输入站名确认。删后项目清单只剩
  delightful-cactus-361664。
- 奴才独立核对过：旧源站 https://resonant-biscochitos-df682c.netlify.app
  现在是 404；官網 https://delightful-cactus-361664.netlify.app
  还是 200，没被动过；Cloudflare 源 https://guhailong-repo.pages.dev
  还是 200。**越狱源现在只有 Cloudflare 这一家了。**

## 26. v11（1.0.11）—— 延后登记通知单测（2026-11-12 22:32 批准制作）

### 26.1 目的

- v10a（1.0.9，%ctor 里只调通知登记）皇上真机实测：装完重启卡住
  （2026-11-12 约 22:21）。结论：**%ctor 里调 AddObserver 会卡**。
- v10b（1.0.10，%ctor 里只调 dispatch_after）皇上真机实测：装完
  正常启动，没问题（2026-11-12 约 22:30）。结论：**dispatch_after
  是清白的，AddObserver 是唯一凶手**。
- v11 只加回一件：%ctor 和 v10b 一模一样（只调 dispatch_after，
  5 秒后在主队列跑一个 block），**登记通知挪到延后的 block 里做**，
  回调是空的 C 函数。测的是：启动完成后再登记通知，安不安全。
- 判法：v11 不卡 = 通知登记可以放在延后步骤里，以后开关变更通知
  就这么接；再往下一次加一件（读开关、写日志）。v11 卡住 =
  通知登记连启动完成后再调也不安全，那就彻底不用通知登记，改用
  别的办法（每次需要时直接读开关文件）。
- 不 hook、不读开关、不写日志、不建窗。Tweak.xm / control 已备份
  为 .v10b.bak，.deb 已备份为
  com.guhailong.splitscreen_1.0.11_iphoneos-arm64.deb.bak。

### 26.2 编译与校验（2026-11-12 22:33，/tmp/ghlss-v11-build）

- 命令与 v10a/v10b 相同（/tmp 里编，umask 022，FINALPACKAGE=1，
  THEOS_PACKAGE_SCHEME=rootless）。
- .deb **7158 字节，SHA256 `752b2b4a2d302568d98cb1afc6dd11f521bcf3ba9153d2dd666e6d8cdc619035`**；
  dpkg-deb -I/-c 验过（dylib 148944 字节，filter plist、prefs
  bundle、Root.plist 1702 字节都在）。
- Mach-O 通用 arm64 + arm64e，LC_CODE_SIGNATURE 两个片都有。
- strings：禁用的全部是 0（日志路径、CFPreferencesCopyAppValue、
  dictionaryWithContentsOfFile、NSLog、UIWindow、medusa、
  floatingView、MGGetBoolAnswer、supportsMultiwindow、
  LSApplicationWorkspace）；**CFNotificationCenterAddObserver 4、
  CFNotificationCenterGetDarwinNotifyCenter 4、prefschanged 2**
  （都在延后的 block 里）；dispatch_after 4、dispatch_time 4。
- arm64e __text 反汇编：%ctor 只调 `bl _dispatch_time` 再尾调用
  `b _dispatch_after`（与 v10b 同形）；延后的 block 函数里调
  `bl _CFNotificationCenterGetDarwinNotifyCenter` 再尾调用
  `b _CFNotificationCenterAddObserver`；**objc_msgSend 0**。
  （注：最后一条 grep 计数 0 时 grep 退出码是 1，这是“0 个”
  的正常结果，不是校验失败。）

### 26.3 本地源 v24（只更新本地，未部署，等皇上批准）

- 本地源换成 1.0.11 .deb（1.0.10 .deb 已删），Packages / .gz /
  .bz2 / .zst 与 Release 已重算（Packages.zst 往返校验过），
  14 个包，分屏 1.0.11，0 个 1.0.10；说明页 / 首页 / README
  已更新到 v11。
- 线上还是 v23（分屏 1.0.10），等皇上批准再部署。

### 26.4 真机测试步骤（等部署后）

1. Sileo 里直接升级装 1.0.11，respring，确认正常启动、不卡、
   不进安全模式，报给奴才；
2. 要是卡住：强制重启 → Dopamine 关注入重越狱 → 卸掉 1.0.11
   → 报给奴才，奴才立刻把源换回 1.0.10（真机不卡的版本）。

### 26.5 部署到 Cloudflare Pages（皇上 22:33 批准“部署到源上”）

- 部署成功（新部署 16c44a83），脚本线上检查直接报 LIVE OK
  （这次没有遇到边缘传播延迟）。
- 独立核对过线上：`/Packages` 200、8937 字节，与本地 v24 逐字
  节相同，14 个包，分屏 1.0.11，0 个 1.0.10；`/Packages.zst`
  解出来与线上 Packages 一致；首页 200。v24 已上线。

### 26.6 真机测试：v11 过了（2026-11-12 22:37）

- 皇上装了 1.0.11，**安装 OK**，手机正常启动。v11 通过。
- 结论：**启动完成后再登记通知是安全的**。AddObserver 只有在
  %ctor 里调才会卡，挪到 5 秒后的延后步骤里做就没事。
- 延后初始化的路子验证通过了：%ctor 只排一个 dispatch_after，
  真正的事都等启动完成后再做。开关的通知可以这样接。
- 下一步（等皇上批准）：v12，延后步骤里读开关 + 写日志，证明
  延后步骤真的跑了、开关读得到。

### 26.7 更正：v11 其实没过，是延后卡住（2026-11-12 22:39）

- §26.6 写错了，奴才认错：皇上 22:37 说“1.0.11 安装 OK”的
  时候还没卡，是**装完能进系统，进去后画面卡住动不了**。
  奴才当时就当它过了，是说早了。v11 没有通过。
- v10b（延后 block 是空的）没事，v11（延后 block 里只多了一行
  AddObserver）进去后卡住——**通知登记不管是启动时调还是
  5 秒后调都会卡**。AddObserver 这个调用本身就是凶手，和时机
  无关。
- 奴才上一条说的“固定字串坏掉”的解释也站不住了：5 秒后字串
  早就是好的了，还是卡，说明不是字串的问题，就是 AddObserver
  这个调用本身会卡住（最可能是它在里面等一个永远等不到的
  东西，死锁了）。确切机制仍没法百分之百证明，但“不能用
  AddObserver”这个结论是实的。
- 结论：**彻底不用 AddObserver**。开关的状态不需要通知来推，
  需要用的时候直接读开关文件就行。那是 v12 要做的。

## 27. 回退到 v25（1.0.10）（2026-11-12 22:39）

- 按老规矩立刻回退：本地源换回 1.0.10 .deb（1.0.11 .deb 已删），
  Packages / .gz / .bz2 / .zst 与 Release 已重算，说明页 / 首页 /
  README 已更新回 1.0.10（含 v11 已废弃的警告）。
- 2026-11-12 约 22:40 部署到 Cloudflare Pages，线上核对过：
  Packages 与本地逐字节相同，14 个包，分屏 1.0.10，0 个 1.0.11。
  源上又是安全的版本了。

## 28. 皇上确认：进主画面后约 5 秒卡住（2026-11-12 22:41）

- 奴才问皇上是不是进主画面后大概 5 秒左右卡住的，皇上说“是的”。
- 5 秒正是延后 block 跑起来的时间（dispatch_after 5 秒）。
  v10b（延后 block 是空的）没事，v11（延后 block 里只多了一行
  AddObserver）5 秒后卡住——时间点对得严丝合缝，凶手就是
  AddObserver 这个调用本身，和启动时机无关。
- 下一步（等皇上批准）：v12，延后步骤里读开关 + 写日志，
  彻底不用通知登记。

## 29. v12（1.0.12）—— 延后读开关 + 写日志单测（2026-11-12 22:42 批准制作）

### 29.1 目的

- v10a（1.0.9，%ctor 里只调通知登记）：装完重启卡住。
- v11（1.0.11，通知登记挪到 5 秒后的延后步骤里）：装完能进系统，
  进去后约 5 秒画面卡住动不了（皇上确认就是 5 秒）。
  结论：**AddObserver 不管什么时候调都会卡，彻底不能用**。
  早先“固定字串坏掉”的解释已被证伪——5 秒后字串是好的，
  还是卡。
- v12 彻底不用通知登记：%ctor 还是只调 dispatch_after（5 秒后
  在主队列跑一个 block），延后的 block 里**直接读开关文件**
  （CFPreferencesCopyAppValue，C API），再把结果写进日志文件，
  证明延后步骤真的跑了、开关读到了什么。
- 判法：v12 不卡 + 日志里有开关的值 = 延后读开关是安全的，开关
  以后就这么读（需要用的时候现读，不用通知推）；v12 卡住 =
  连延后读开关都会卡，那就再拆（只写日志不读开关，定位到底是
  哪一行）。
- 日志是这次测试的观测手段，不是单独的功能。日志写在
  /var/mobile/Library/Logs/GuHaiLongSplitScreen.log，用 Filza 就能看。
- 不登记通知、不 hook、不建窗。Tweak.xm / control 已备份为
  .v11.bak，.deb 已备份为
  com.guhailong.splitscreen_1.0.12_iphoneos-arm64.deb.bak。

### 29.2 编译与校验（2026-11-12 22:43，/tmp/ghlss-v12-build）

- 命令与 v10a/v10b/v11 相同（/tmp 里编，umask 022，FINALPACKAGE=1，
  THEOS_PACKAGE_SCHEME=rootless）。
- .deb **7730 字节，SHA256 `dae5942ef8a4a05df817a5ea7df6ee89f8f1ce82cbf9b4472ef3c0f58a265091`**；
  dpkg-deb -I/-c 验过（dylib 149392 字节，filter plist、prefs
  bundle、Root.plist 1702 字节都在）。
- Mach-O 通用 arm64 + arm64e，LC_CODE_SIGNATURE 两个片都有。
- strings：禁用的全部是 0（NSLog、UIWindow、medusa、floatingView、
  MGGetBoolAnswer、supportsMultiwindow、LSApplicationWorkspace、
  dictionaryWithContentsOfFile、**CFNotificationCenterAddObserver 0、
  CFNotificationCenterGetDarwinNotifyCenter 0、prefschanged 0**）；
  dispatch_after 4、dispatch_time 4、**CFPreferencesCopyAppValue 4、
  GuHaiLongSplitScreen.log 2、CFBooleanGetValue 4、fopen 4**。
- arm64e __text 反汇编：%ctor 只调 `bl _dispatch_time` 再尾调用
  `b _dispatch_after`（与 v10b/v11 同形）；延后的 block 函数里
  只调纯 C 函数（CFPreferencesCopyAppValue、CFGetTypeID、
  CFBooleanGetTypeID、CFBooleanGetValue、CFRelease、fopen、fputs、
  fputc、fclose、snprintf、__stack_chk_fail）；**objc_msgSend 0**。
  （注：反汇编里每个调用出现两次，是 objdump 把 __text 段印了
  两遍，不是代码重复。）

### 29.3 本地源 v26（只更新本地，未部署，等皇上批准）

- 本地源换成 1.0.12 .deb（1.0.10 .deb 已删），Packages / .gz /
  .bz2 / .zst 与 Release 已重算（Packages.zst 往返校验过），
  14 个包，分屏 1.0.12，0 个 1.0.10；说明页 / 首页 / README
  已更新到 v12。
- 线上还是 v25（分屏 1.0.10），等皇上批准再部署。

### 29.4 真机测试步骤（等部署后）

1. 确认 1.0.11 已卸掉、手机已恢复；
2. Sileo 里直接升级装 1.0.12，respring，确认正常启动、不卡、
   不进安全模式；
3. 用 Filza 看 `/var/mobile/Library/Logs/GuHaiLongSplitScreen.log`，
   把里面的内容报给奴才（应该有 `v12 deferred setup ran` 和
   `v12 deferred setup ran, switch=...` 两行；开关默认是 OFF，
   手机里现在没有开关文件，所以应该是 `switch=none(default OFF)`）；
4. 也可以再测一次：去设置里把分屏开关打开，respring，再看日志，
   应该变成 `switch=ON`；
5. 要是卡住：强制重启 → Dopamine 关注入重越狱 → 卸掉 1.0.12
   → 报给奴才，奴才立刻把源换回 1.0.10（真机不卡的版本）。

### 29.5 部署到 Cloudflare Pages（皇上 22:44 批准“部署到源上”）

- 部署成功（新部署 bec79335），脚本线上检查直接报 LIVE OK。
- 独立核对过线上：`/Packages` 200、8965 字节，与本地 v26 逐字
  节相同，14 个包，分屏 1.0.12，0 个 1.0.10；`/Packages.zst`
  解出来与线上 Packages 一致；首页 200。v26 已上线。

### 29.6 Sileo 刷新遇到 522（2026-11-12 22:45，短暂故障）

- 皇上在 Sileo 里刷新源，报：`/Release` 与 `/Packages` 都
  returned status 522（Cloudflare 边缘连不上源站），
  “Could not find release file”。
- 奴才马上从这边查：首页 / Release / Packages 全部是 200，
  Packages 8965 字节，分屏 1.0.12，部署地址也正常。522 是
  短暂的——皇上 22:45 刷新时正好赶上 v26 部署完还在传播，
  边缘节点一时连不上源站；过了一会儿就好了。
- 教训：刚部署完立刻在 Sileo 里刷新，有可能撞上 522；等一
  分钟再拉一下就行，源本身没坏，不用删源重加。

### 29.7 Sileo 刷新持续 522（2026-11-12 22:46）

- 皇上重新刷新还是 522。奴才查了 Cloudflare 自己的状态页：
  当时是 **“Partially Degraded Service”（部分服务降级）**，
  是 Cloudflare 那边的问题，不是咱们的源坏了。
- 奴才把 v26 同样内容重新部署了一遍（新部署 a4896e62），
  从这边查全是 200（Packages 8965 字节，分屏 1.0.12，
  Release 200）。等皇上再刷新一次看。
- 如果还是 522，就是皇上那边走的 Cloudflare 节点还有问题，
  等一会儿再试，或换一下网络（Wi-Fi / 流量切换）走另一条路。

### 29.6 真机测试：v12 进安全模式（2026-11-12 22:48）

- 皇上装了 1.0.12，**进安全模式了**。v12 没过。
- v12 的延后步骤只做两件事：读开关（CFPreferencesCopyAppValue）
  和写日志（纯 C 的 fopen/fputs）。写日志用的全是 C 字符串，
  不可能因为字符串坏掉而崩；唯一用到 CFSTR（写死的固定字串）
  的地方就是读开关传进去的域名和键名。
- 所以最可能的凶手又回到了**写死的固定字串（CFSTR）本身**：
  咱们这套工具链编出来的 CFSTR 在手机上是坏的——v5 崩溃时
  就看到第一个 CFSTR 的内容是乱的。v10b 没事是因为它一个
  CFSTR 都没传；v11 卡住是把坏字串传给了 AddObserver；v12
  进安全模式是把坏字串传给了读开关。
- 关键证据等皇上恢复后确认：`/var/mobile/Library/Logs/
  GuHaiLongSplitScreen.log` 在不在、里面有什么。如果日志文件
  不存在，说明崩在读开关那一行（日志还没来得及写）；如果
  日志里已经有 `v12 deferred setup ran`，说明读开关成功了，
  崩在后面的写日志——那就另有原因。
- 下一步（等皇上批准）：v13，和 v12 一模一样，但**不用写死
  的 CFSTR，域名和键名改成运行时现做的字串**
  （CFStringCreateWithCString）。v13 过了 = CFSTR 的解释证实，
  以后全用现做的字串；v13 也崩 = 问题不在 CFSTR，是读开关
  这个调用本身，再拆（只写日志不读开关）。

## 30. 回退到 v27（1.0.10）（2026-11-12 22:49）

- 按老规矩立刻回退：本地源换回 1.0.10 .deb（1.0.12 .deb 已删），
  Packages / .gz / .bz2 / .zst 与 Release 已重算，说明页 / 首页 /
  README 已更新回 1.0.10（含 v12 已废弃的警告）。
- 2026-11-12 约 22:49 部署到 Cloudflare Pages，线上核对过：
  Packages 与本地逐字节相同，14 个包，分屏 1.0.10，0 个 1.0.12。
  源上又是安全的版本了。

## 31. 更正：§26.7 说“字串解释被证伪”是错的（2026-11-12 22:49）

- §26.7 里奴才写“5 秒后字串早就是好的了，还是卡，说明不是
  字串的问题”，这个推理是错的。奴才当时默认字串启动后会变好，
  但没有任何证据支持这一点——如果工具链编出来的 CFSTR 本来
  就是坏的（重定位信息不对），那它在 dylib 的整个生命周期里
  都是坏的，不分启动时还是 5 秒后。
- 修正后的解释（自洽）：**CFSTR 在咱们这个 dylib 里一直是坏的**。
  不同 API 碰到坏字串反应不同：AddObserver 是卡住（v10a、v11），
  读开关是崩溃进安全模式（v12、v5 的日志也是崩溃）。v10b 没事
  是因为它一个 CFSTR 都没传。v13（运行时现做字串）就是验证
  这个解释的决定性测试。

## 32. 日志文件证据：没有 GuHaiLongSplitScreen.log（2026-11-12 22:52）

- 皇上恢复后用 Filza 看了 `/var/mobile/Library/Logs/`（截图
  22:52）：里面只有 AppleSupport、ExposureNotification、
  Bluetooth、mobileactivationd、SiriTTSService、com.apple.ioam、
  RTCReporting、com.apple.itunestored、CrashReporter、
  com.apple.FeatureStore、DiagnosticPipeline、
  WirelessRadioManager、Dedisco 这些文件夹和一个 wifi 的
  plist，**没有 GuHaiLongSplitScreen.log**。
- 卸载插件不会删日志文件，所以“没有”就是真的没写出来。
  v12 的延后步骤第一件事就是读开关，读完才写日志——日志
  一行都没有，说明**崩在读开关那一行**，CFPreferencesCopyAppValue
  传进去的两个 CFSTR（域名和键名）就是凶手。
- CFSTR 的解释至此已由三处独立证据支持：v5 崩溃日志里第一个
  CFSTR 的内容是乱的；v10a/v11 把 CFSTR 传给 AddObserver 就卡住；
  v12 把 CFSTR 传给读开关就崩溃、且日志一行都没写出来。
  v10b 没事是因为它一个 CFSTR 都没传。
- 下一步（等皇上批准）：v13，和 v12 一模一样，但域名和键名
  改成运行时现做的字串（CFStringCreateWithCString），不用写死
  的 CFSTR。v13 过了 = 解释证实，以后全用现做的字串；
  v13 也崩 = 问题不在 CFSTR，是读开关这个调用本身，再拆。

## 33. v13（1.0.13）—— 运行时现做字串读开关单测（2026-11-12 22:54 批准制作）

### 33.1 目的

- v12（1.0.12，延后读开关 + 写日志）皇上真机实测：装完进安全模式。
  皇上恢复后用 Filza 看了 `/var/mobile/Library/Logs/`（截图 22:52）：
  **没有 GuHaiLongSplitScreen.log**。卸载插件不会删日志，所以
  “没有”就是真的没写出来——v12 的延后步骤第一件事就是读开关，
  读完才写日志，一行都没有，说明**崩在读开关那一行**。
- v12 里读开关传进去的域名和键名是写死的固定字串（CFSTR），而写
  日志用的全是普通 C 字串，不可能崩。三处独立证据都指向**咱们
  这套工具链编出来的 CFSTR 是坏的**：v5 崩溃日志里第一个 CFSTR
  的内容是乱的；v10a/v11 把 CFSTR 传给 AddObserver 就卡住；v12
  把 CFSTR 传给读开关就崩溃、且日志一行都没写出来。v10b 没事
  是因为它一个 CFSTR 都没传。
- v13 和 v12 一模一样，只改一件：**域名和键名改成运行时现做的
  字串（CFStringCreateWithCString），一个 CFSTR 都不用**。
- 判法：v13 不卡 + 日志里有开关的值 = 解释证实，以后全用现做的
  字串，读开关这条路通了；v13 也崩 = 问题不在 CFSTR，是读开关
  这个调用本身，再拆（只写日志不读开关）。
- 日志是这次测试的观测手段，不是单独的功能。日志写在
  /var/mobile/Library/Logs/GuHaiLongSplitScreen.log，用 Filza 就能看。
- 不登记通知、不 hook、不建窗。Tweak.xm / control 已备份为
  .v12.bak，.deb 已备份为
  com.guhailong.splitscreen_1.0.13_iphoneos-arm64.deb.bak。

### 33.2 编译与校验（2026-11-12 22:54，/tmp/ghlss-v13-build）

- 命令与 v10a/v10b/v11/v12 相同（/tmp 里编，umask 022，
  FINALPACKAGE=1，THEOS_PACKAGE_SCHEME=rootless）。
- .deb **7790 字节，SHA256 `e57f1da0c18a238edf374eacb7cd90a06555fe2841948df7cdbc531e96ef5704`**；
  dpkg-deb -I/-c 验过（dylib 149392 字节，filter plist、prefs
  bundle、Root.plist 1702 字节都在）。
- Mach-O 通用 arm64 + arm64e，LC_CODE_SIGNATURE 两个片都有。
- **关键校验：dylib 里根本没有 __cfstring 段**——一个写死的
  固定字串都没有，这是第一个没有 CFSTR 的版本。
- strings：禁用的全部是 0（NSLog、UIWindow、medusa、floatingView、
  MGGetBoolAnswer、supportsMultiwindow、LSApplicationWorkspace、
  dictionaryWithContentsOfFile、**CFNotificationCenterAddObserver 0、
  CFNotificationCenterGetDarwinNotifyCenter 0、prefschanged 0**）；
  dispatch_after 4、dispatch_time 4、**CFPreferencesCopyAppValue 4、
  CFStringCreateWithCString 4、GuHaiLongSplitScreen.log 2、
  CFBooleanGetValue 4、fopen 4**。
- arm64e __text 反汇编：%ctor 只调 `bl _dispatch_time` 再尾调用
  `b _dispatch_after`（与 v10b/v11/v12 同形）；延后的 block 函数
  里只调纯 C 函数（CFStringCreateWithCString 两次、CFPreferencesCopyAppValue、
  CFGetTypeID、CFBooleanGetTypeID、CFBooleanGetValue、CFRelease 三次、
  fopen、fputs、fputc、fclose、snprintf、__stack_chk_fail）；
  **objc_msgSend 0**。

### 33.3 本地源 v28（只更新本地，未部署，等皇上批准）

- 本地源换成 1.0.13 .deb（1.0.10 .deb 已删），Packages / .gz /
  .bz2 / .zst 与 Release 已重算（Packages.zst 往返校验过），
  14 个包，分屏 1.0.13，0 个 1.0.10；说明页 / 首页 / README
  已更新到 v13。
- 线上还是 v27（分屏 1.0.10），等皇上批准再部署。

### 33.4 真机测试步骤（等部署后）

1. Sileo 里直接升级装 1.0.13，respring，确认正常启动、不卡、
   不进安全模式；
2. 用 Filza 看 `/var/mobile/Library/Logs/GuHaiLongSplitScreen.log`，
   把里面的内容报给奴才（应该有 `v13 deferred setup ran` 和
   `v13 deferred setup ran, switch=...` 两行；开关默认是 OFF，
   手机里现在没有开关文件，所以应该是 `switch=none(default OFF)`）；
3. 也可以再测一次：去设置里把分屏开关打开，respring，再看日志，
   应该变成 `switch=ON`；
4. 要是卡住或进安全模式：强制重启 → Dopamine 关注入重越狱 →
   卸掉 1.0.13 → 报给奴才，奴才立刻把源换回 1.0.10（真机不卡的版本）。

### 33.5 部署到 Cloudflare Pages（皇上 22:55 批准“部署到源上”）

- 部署成功（新部署 b2df5308），脚本线上检查直接报 LIVE OK。
- 独立核对过线上：`/Packages` 200、8964 字节，与本地 v28 逐字
  节相同，14 个包，分屏 1.0.13，0 个 1.0.10；`/Packages.zst`
  解出来与线上 Packages 一致；首页 200。v28 已上线。

### 33.6 真机测试：v13 装完没问题（2026-11-12 22:57）

- 皇上装了 1.0.13，**没问题，安装成功**，手机正常启动，
  不卡、不进安全模式。v13 的启动部分通过。
- 这说明运行时现做的字串没事，写死的 CFSTR 就是凶手——
  CFSTR 的解释基本证实了。
- 还差最后一步确认：日志文件里有没有开关的值（证明延后
  步骤真的跑了、开关读到了）。等皇上用 Filza 看
  `/var/mobile/Library/Logs/GuHaiLongSplitScreen.log` 的内容。

### 33.7 真机测试：v13 完全通过（2026-11-12 22:58）

- 皇上用 Filza 看了日志文件（截图 22:58），内容是：
  ```
  1 v13 deferred setup ran
  2 v13 deferred setup ran, switch=none(default OFF)
  ```
- 两行都在：延后步骤真的跑了，读开关也成功了，返回值是
  “没有文件、默认 OFF”——和预期一模一样（手机里本来就
  没有开关文件）。
- **v13 完全通过。CFSTR 的解释证实了**：写死的固定字串是
  坏的，运行时现做的字串没事。以后全用现做的字串。
- 基础打通了：%ctor 只排 dispatch_after（v10b 证实安全），
  延后步骤里读开关 + 写日志（v13 证实安全），不用通知登记，
  不用 CFSTR。下一步（等皇上批准）：v14，5.1 边缘滑动测试。

## 34. v14（1.0.14）—— 5.1 边缘滑动测试（2026-11-12 22:59 批准制作）

### 34.1 目的

- v13（1.0.13）皇上真机实测完全通过（2026-11-12 约 22:58）：
  装完没问题，日志里有两行（延后步骤跑了，开关读到默认 OFF）。
  结论：**写死的固定字串（CFSTR）是坏的，运行时现做的字串没事**。
  基础打通了：%ctor 只排 dispatch_after，延后步骤里读开关 +
  写日志，不用通知登记，不用 CFSTR。
- v14 只加一件（设计文档 V5_DESIGN.md §5.1 的第一步）：延后
  步骤里在屏幕右边缘建一条 12pt 宽的透明感应带（UIWindow），
  挂一个 UIScreenEdgePanGestureRecognizer（右边缘）；皇上从右
  边缘滑入，写一行日志。不做侧边小窗、不做 App 列表、不点 App
  打开、不建 scene、不 hook。
- 判法：v14 不卡 + 滑一下日志里有 `v14 edge swipe detected` =
  手势在 SpringBoard 里能用，下一步做侧边小窗；v14 卡住或进
  安全模式 = 建透明窗或挂手势本身有问题，再拆（只建窗不挂手势）。
- 关键约束（v13 的教训）：**这个文件里一个写死的字串都不能有**——
  不用 CFSTR，也不用 @"..."（ObjC 字串字面量也是 CFSTR）。手势
  回调、窗、视图全用运行时创建的对象，不碰任何字串常量。编译完
  要验 dylib 里没有 __cfstring 段。
- 感应带不看开关：v14 永远建带，只测手势本身；开关的门以后再加。
  横屏不处理：只按竖屏算位置。
- 不登记通知。Tweak.xm / control 已备份为 .v13.bak。

### 34.2 编译与校验（2026-11-12 23:00，/tmp/ghlss-v14-build）

- 命令与 v10a/v10b/v11/v12/v13 相同（/tmp 里编，umask 022，
  FINALPACKAGE=1，THEOS_PACKAGE_SCHEME=rootless）。
- .deb **9406 字节，SHA256 `1636bba05698069dffd1c2bf0a71ac08fa52f6295db02b3dd3978e65dcf58f0c`**；
  dpkg-deb -I/-c 验过（dylib 167296 字节，filter plist、prefs
  bundle、Root.plist 1702 字节都在）。
- Mach-O 通用 arm64 + arm64e，LC_CODE_SIGNATURE 两个片都有。
- **关键校验：dylib 里没有 __cfstring 段**——即使加了 ObjC
  的窗和手势代码，一个写死的字串都没有。
- strings：禁用的全部是 0（NSLog、medusa、floatingView、
  MGGetBoolAnswer、supportsMultiwindow、LSApplicationWorkspace、
  dictionaryWithContentsOfFile、**CFNotificationCenterAddObserver 0、
  CFNotificationCenterGetDarwinNotifyCenter 0、prefschanged 0**）；
  dispatch_after 4、dispatch_time 4、CFPreferencesCopyAppValue 4、
  CFStringCreateWithCString 4、GuHaiLongSplitScreen.log 2、
  **UIScreenEdgePanGestureRecognizer 4、GHLSSEdgeSwipeHandler 10、
  handleEdgeSwipe: 2**。
- arm64e __text 反汇编：%ctor 只调 `bl _dispatch_time` 再尾调用
  `b _dispatch_after`（与 v10b/v11/v12/v13 同形）；延后的 block
  函数里调纯 C 函数（CFStringCreateWithCString、CFPreferencesCopyAppValue、
  CFGetTypeID、CFBooleanGetTypeID、CFBooleanGetValue、CFRelease、
  fopen、fputs、fputc、fclose、snprintf）加 ObjC 消息发送
  （objc_msgSend——现在有了，是因为建窗和手势要用 ObjC，对象
  都是运行时创建的，没有字串常量）；**AddObserver、NSLog、
  medusa 均无**。

### 34.3 设置图标（皇上 23:00 要求加上）

- 皇上在设置 → 越狱插件里看到别的插件都有图标，顾海龙分屏
  没有，要求加上。
- 原因：PreferenceLoader 的 entry 里一直没写 `icon`，bundle 里
  也没有图标文件。
- 做法：用网站头的无字龙头裁剪图（header-logo-dragon-800.jpg，
  800x800）做成三张 PNG——icon.png 29x29、icon@2x.png 58x58、
  icon@3x.png 87x87，放进 prefs/Resources/；PreferenceLoader
  的 entry 里加 `<key>icon</key><string>icon</string>`；bundle
  的 Info.plist 里加 `CFBundleIconFile` = icon。
- v14 重新编了一遍（/tmp/ghlss-v14b-build），.deb **SHA256
  `a354e7da6115af58ce0b4cee5a869cdffcdf33876998b47d950a22d24011ba27`**；
  验过：.deb 里三张图标都在 bundle 里且是合法 PNG（29/58/87），
  PreferenceLoader 的 plist 里有 icon 键，Info.plist 里有
  CFBundleIconFile，dylib 里仍然没有 __cfstring 段。图标文件
  也备份在项目目录（prefs/Resources/icon*.png）。

### 34.4 本地源 v29（只更新本地，未部署，等皇上批准）

- 本地源换成 1.0.14 .deb（含图标的新版，1.0.13 .deb 已删），
  Packages / .gz / .bz2 / .zst 与 Release 已重算（Packages.zst
  往返校验过），14 个包，分屏 1.0.14，0 个 1.0.13；说明页 /
  首页 / README 已更新到 v14。
- 线上还是 v28（分屏 1.0.13），等皇上批准再部署。

### 34.5 真机测试步骤（等部署后）

1. Sileo 里直接升级装 1.0.14，respring，确认正常启动、不卡、
   不进安全模式；
2. 去设置 → 越狱插件，看顾海龙分屏左边有没有龙头图标；
3. 从屏幕右边缘向左滑一下，再用 Filza 看
   `/var/mobile/Library/Logs/GuHaiLongSplitScreen.log`，把里面
   的内容报给奴才（应该有 `v14 edge strip built`，滑过之后
   还有 `v14 edge swipe detected`）；
4. 要是卡住或进安全模式：强制重启 → Dopamine 关注入重越狱 →
   卸掉 1.0.14 → 报给奴才，奴才立刻把源换回 1.0.13（真机完全
   通过的版本）。

### 34.6 部署到 Cloudflare Pages（皇上 23:02 批准“部署到源上”）

- 部署成功（新部署 e1f3b930），脚本线上检查直接报 LIVE OK。
- 独立核对过线上：`/Packages` 200、8969 字节，与本地 v29 逐字
  节相同，14 个包，分屏 1.0.14，0 个 1.0.13；`/Packages.zst`
  解出来与线上 Packages 一致；首页 200。v29 已上线。

### 34.7 真机测试：v14 装完启动黑屏（2026-11-12 23:04），换回 v30

- 皇上装完 1.0.14，启动就黑屏（进不了主屏）。v14 失败，
  **不要再装 1.0.14**。
- 源已换回 v30（分屏 1.0.13，1.0.14 .deb 已从本地源删掉），
  部署 af376cb3；脚本刚传完的即时检查报了不匹配（又是边缘
  节点还没同步的老毛病，见 §24.5），等了一分多钟再独立核对：
  线上 Packages 200、8964 字节，与本地 v30 逐字节相同，14 个
  包，分屏 1.0.13，0 个 1.0.14，Packages.zst 解出来与线上
  Packages 一致，首页 200。v30 已上线。
- 初步分析：v14 相对 v13 只加了透明感应带窗 + 滑动手势。
  一条 12pt 的透明带本身遮不住整个屏幕，黑屏更像是延后步骤
  里建窗（或挂手势）那一步把主线程拖住了、SpringBoard 没
  启动完，或者建窗触发了 SpringBoard 的窗口管理问题。具体
  哪一步，要靠下一次拆分测试：v15 只建窗不挂手势；过了就
  是手势的问题，不过就是窗的问题。
- 皇上恢复步骤：强制重启 → Dopamine 关掉注入重越狱 → 卸掉
  1.0.14 → 正常重越狱。等皇上确认恢复。

- 皇上按恢复步骤弄好了（2026-11-12 23:08）：强制重启 → Dopamine
  关注入重越狱 → 卸掉 1.0.14 → 正常重越狱，手机恢复正常。
  源上是 v30（分屏 1.0.13），要装就装 1.0.13。
- 下一步（等皇上批准）：v15，只建窗不挂手势，定位 v14 黑屏
  到底是窗还是手势的问题。

## 35. v15（1.0.15）—— 只建窗、不挂手势（2026-11-12 23:08 批准制作）

### 35.1 目的

- v14（1.0.14）皇上真机实测失败（2026-11-12 约 23:04）：装完
  启动就黑屏，进不了主屏。皇上已恢复（强制重启 → Dopamine
  关注入重越狱 → 卸掉 1.0.14 → 正常重越狱，23:08 确认弄好了），
  源已换回 v30（分屏 1.0.13）。
- v14 相对 v13 只加了两件：透明感应带窗 + 滑动手势。一条 12pt
  的透明带本身遮不住整个屏幕，黑屏更像是延后步骤里建窗（或挂
  手势）那一步把主线程拖住了、SpringBoard 没启动完，或者建窗
  触发了 SpringBoard 的窗口管理问题。
- v15 只留一件：建窗，不挂手势。
- 判法：v15 不黑屏 = 窗没事，黑屏是手势的问题，下一步只加手势
  再测（换个挂法）；v15 也黑屏 = 窗本身就是问题，感应带这条路
  要换做法（比如不自己建窗，改挂到 SpringBoard 现成的视图上）。
- 关键约束（v13 的教训）：**这个文件里一个写死的字串都不能有**——
  不用 CFSTR，也不用 @"..."。窗、视图全用运行时创建的对象，
  不碰任何字串常量。编译完要验 dylib 里没有 __cfstring 段。
- 感应带不看开关：v15 永远建带，只测建窗本身；开关的门以后再加。
  横屏不处理：只按竖屏算位置。
- 不登记通知、不 hook、不建 scene。Tweak.xm / control 已备份为
  .v14.bak，.deb 已备份为
  com.guhailong.splitscreen_1.0.15_iphoneos-arm64.deb.bak。

### 35.2 编译与校验（2026-11-12 23:09，/tmp/ghlss-v15-build）

- 命令与 v10a/v10b/v11/v12/v13/v14 相同（/tmp 里编，umask 022，
  FINALPACKAGE=1，THEOS_PACKAGE_SCHEME=rootless）。
- .deb **37858 字节，SHA256 `1cfa0c527a1bbad4d98e9191b1b19c73d2d53ac04f1fcb46a8a355d614c2c95e`**
  （比 v14 大是因为设置图标三张图占了约 29KB）；
  dpkg-deb -I/-c 验过（dylib 166736 字节，filter plist、prefs
  bundle、Root.plist 1702 字节、三张图标都在）。
- Mach-O 通用 arm64 + arm64e，LC_CODE_SIGNATURE 两个片都有。
- **关键校验：dylib 里没有 __cfstring 段**——一个写死的字串
  都没有。
- strings：禁用的全部是 0（NSLog、medusa、floatingView、
  MGGetBoolAnswer、supportsMultiwindow、LSApplicationWorkspace、
  dictionaryWithContentsOfFile、**CFNotificationCenterAddObserver 0、
  CFNotificationCenterGetDarwinNotifyCenter 0、prefschanged 0、
  UIScreenEdgePanGestureRecognizer 0、GHLSSEdgeSwipeHandler 0、
  handleEdgeSwipe: 0**——手势真的拿掉了）；
  dispatch_after 4、dispatch_time 4、CFPreferencesCopyAppValue 4、
  CFStringCreateWithCString 4、GuHaiLongSplitScreen.log 2、UIWindow 8。
- arm64e __text 反汇编：%ctor 只调 `bl _dispatch_time` 再尾调用
  `b _dispatch_after`（与 v10b/v11/v12/v13/v14 同形）；延后的
  block 函数里调纯 C 函数（CFStringCreateWithCString、
  CFPreferencesCopyAppValue、CFGetTypeID、CFBooleanGetTypeID、
  CFBooleanGetValue、CFRelease、fopen、fputs、fputc、fclose、
  snprintf）加 ObjC 消息发送（objc_msgSend——建窗和视图要用
  ObjC，对象都是运行时创建的，没有字串常量）；**手势、通知
  登记、NSLog、medusa 均无**。

### 35.3 本地源 v31（只更新本地，未部署，等皇上批准）

- 本地源换成 1.0.15 .deb（1.0.13 .deb 已删），Packages / .gz /
  .bz2 / .zst 与 Release 已重算（Packages.zst 往返校验过），
  14 个包，分屏 1.0.15，0 个 1.0.13；说明页 / 首页 / README
  已更新到 v15。
- 线上还是 v30（分屏 1.0.13），等皇上批准再部署。

### 35.4 真机测试步骤（等部署后）

1. Sileo 里直接升级装 1.0.15，respring，确认正常启动、不黑屏、
   不卡、不进安全模式；
2. 用 Filza 看 `/var/mobile/Library/Logs/GuHaiLongSplitScreen.log`，
   把里面的内容报给奴才（应该有 `v15 edge strip built`）；
3. 要是黑屏、卡住或进安全模式：强制重启 → Dopamine 关注入重越狱 →
   卸掉 1.0.15 → 报给奴才，奴才立刻把源换回 1.0.13（真机完全
   通过的版本）。

### 35.5 部署到 Cloudflare Pages（皇上 23:10 批准“部署到源上”）

- 部署成功（新部署 933c8ab0）；脚本刚传完的即时检查又报了
  不匹配（边缘节点还没同步的老毛病，见 §24.5），等了一分多钟
  再独立核对：线上 `/Packages` 200、8945 字节，与本地 v31
  逐字节相同，14 个包，分屏 1.0.15，0 个 1.0.13；
  `/Packages.zst` 解出来与线上 Packages 一致；首页 200。
  v31 已上线。

### 35.6 真机测试：v15 完全通过（2026-11-12 23:13）

- 皇上装了 1.0.15，手机正常启动、不黑屏、不卡。日志文件
  （截图 23:13）：
  ```
  1 v13 deferred setup ran
  2 v13 deferred setup ran, switch=none(default OFF)
  3 v15 deferred setup ran
  4 v15 deferred setup ran, switch=none(default OFF)
  5 v15 edge strip built
  ```
- 延后步骤跑了，开关读到默认 OFF，**感应带窗建出来了**。
  （前面两行是 v13 留下的，日志是追加的，正常。）
- **v15 完全通过。窗是清白的，v14 黑屏的凶手是滑动手势。**
- 下一步（等皇上批准）：v16，窗 + 普通滑动手势
  （UIPanGestureRecognizer，不用边缘滑动手势），看是“任何
  手势都不行”还是“只有边缘滑动手势不行”。

## 36. v16（1.0.16）—— 窗加普通滑动手势 + 设置页闪退修好（2026-11-12 23:14 批准制作）

### 36.1 目的

- v15（1.0.15）皇上真机实测完全通过（2026-11-12 约 23:13）：
  装完正常启动、不黑屏，日志里有三行 v15（延后步骤跑了，开关
  读到默认 OFF，感应带窗建出来了）。**窗是清白的，v14 黑屏的
  凶手是滑动手势。**
- v16 只加一件：感应带上挂一个普通的 UIPanGestureRecognizer
  （不是边缘滑动手势），皇上从右边缘滑入，写一行日志。
- 判法：v16 不黑屏 + 滑一下日志里有 `v16 pan detected` =
  普通手势没事，问题只在边缘滑动手势那一个类上；v16 也黑屏 =
  任何手势识别器在咱们的窗里都不行，触发要换做法（自己接
  touch 事件，或用金色“分”字按钮当触发）。
- 关键约束（v13 的教训）：**主插件这个文件里一个写死的字串
  都不能有**——不用 CFSTR，也不用 @"..."。手势回调、窗、视图
  全用运行时创建的对象，不碰任何字串常量。编译完要验 dylib
  里没有 __cfstring 段。
- 感应带不看开关：v16 永远建带，只测手势本身；开关的门以后再加。
  横屏不处理：只按竖屏算位置。
- 不登记通知、不 hook、不建 scene。Tweak.xm / control 已备份为
  .v15.bak。

### 36.2 设置页闪退（皇上 23:15 报告，顺手修好）

- 皇上说：进设置 → 越狱插件 → 顾海龙分屏，一进去就闪退。
  这不是没问题，是个真 bug，而且和主插件是同一个病根：
  **设置页的二进制文件（GuHaiLongSplitScreenPrefs）里也有
  __cfstring 段**（每个片 0x80 字节），是咱们这套工具链编出来
  的写死字串坏掉的毛病，只不过这次崩在设置进程里。
- 病灶在 prefs/RootListController.m：`@"Root"`、
  `@"/var/jb/.../com.guhailong.splitscreen.plist"`（两处）、
  `specifier.properties[@"key"]`、`CFSTR("...prefschanged")`——
  全是写死的字串。设置一打开设置页，`specifiers` 第一步就碰
  `@"Root"`，直接崩掉。
- 另外还发现一个旧 bug：Root.plist 里开关的键名是 `Enabled`
  （大写 E），主插件读的是 `enabled`（小写），两边对不上，
  开关就算能打开也控制不了主插件。
- 修法：RootListController.m 重写过，一个写死的字串都不留——
  名字、键名全在运行时现做（stringWithCString /
  CFStringCreateWithCString），读写开关直接用 CFPreferences
  （v13 证实过这条路是通的）；以前发的 Darwin 通知不发了，
  主插件那边根本不听通知（登记通知会卡住手机），发了也没用；
  Root.plist 的键名改成 `enabled`（小写，和主插件一致），
  标题改成 v1.0.16，说明文字也按 v16 重写过（以前写的是 v4
  的金色按钮，早就不对了）。
- v16 重新编了一遍（/tmp/ghlss-v16b-build），.deb **SHA256
  `3ae027c64761b3c1089fde1ccfc6dc592cdb52e3902fb11b82789b86786226b3`**；
  验过：设置页二进制里**没有 __cfstring 段**了，prefschanged
  0，主插件 dylib 里也没有 __cfstring 段，禁用的全是 0
  （NSLog、medusa、floatingView、AddObserver、prefschanged、
  边缘滑动手势 0），UIPanGestureRecognizer 4、GHLSSPanHandler 10，
  Root.plist 里的键名是 enabled。
- 设置页的修好和主插件的手势测试是两个独立的二进制、两个
  独立的进程，互不影响，放在同一个版本里没问题。

### 36.3 编译与校验（2026-11-12 23:14，/tmp/ghlss-v16-build；设置页重编 23:15，/tmp/ghlss-v16b-build）

- 命令与 v10a/v10b/v11/v12/v13/v14/v15 相同（/tmp 里编，umask 022，
  FINALPACKAGE=1，THEOS_PACKAGE_SCHEME=rootless）。
- 第一版 .deb 38494 字节，SHA256
  `ff66deedf26abb43297da90966d055d7078c1dd09f219bbb1434c88f545c6db1`；
  设置页重编后 .deb **SHA256
  `3ae027c64761b3c1089fde1ccfc6dc592cdb52e3902fb11b82789b86786226b3`**；
  dpkg-deb -I/-c 验过（dylib 167248 字节，filter plist、prefs
  bundle、Root.plist 1702 字节、三张图标都在）。
- Mach-O 通用 arm64 + arm64e，LC_CODE_SIGNATURE 两个片都有。
- **关键校验：主插件 dylib 和设置页二进制里都没有 __cfstring
  段**——一个写死的字串都没有。
- strings：禁用的全部是 0（NSLog、medusa、floatingView、
  MGGetBoolAnswer、supportsMultiwindow、LSApplicationWorkspace、
  dictionaryWithContentsOfFile、**CFNotificationCenterAddObserver 0、
  CFNotificationCenterGetDarwinNotifyCenter 0、prefschanged 0、
  UIScreenEdgePanGestureRecognizer 0、GHLSSEdgeSwipeHandler 0、
  handleEdgeSwipe: 0**——边缘滑动手势真的拿掉了）；
  dispatch_after 4、dispatch_time 4、CFPreferencesCopyAppValue 4、
  CFStringCreateWithCString 4、GuHaiLongSplitScreen.log 2、
  **UIPanGestureRecognizer 4、GHLSSPanHandler 10、handlePan: 2**。
- arm64e __text 反汇编：%ctor 只调 `bl _dispatch_time` 再尾调用
  `b _dispatch_after`（与 v10b/v11/v12/v13/v14/v15 同形）；延后的
  block 函数里调纯 C 函数（CFStringCreateWithCString、
  CFPreferencesCopyAppValue、CFGetTypeID、CFBooleanGetTypeID、
  CFBooleanGetValue、CFRelease、fopen、fputs、fputc、fclose、
  snprintf）加 ObjC 消息发送（objc_msgSend——建窗、手势和视图
  要用 ObjC，对象都是运行时创建的，没有字串常量）；**边缘滑动
  手势、通知登记、NSLog、medusa 均无**。

### 36.4 本地源 v32（只更新本地，未部署，等皇上批准）

- 本地源换成 1.0.16 .deb（设置页重编后的新版，1.0.15 .deb
  已删），Packages / .gz / .bz2 / .zst 与 Release 已重算
  （Packages.zst 往返校验过），14 个包，分屏 1.0.16，
  0 个 1.0.15；说明页 / 首页 / README 已更新到 v16。
- 线上还是 v31（分屏 1.0.15），等皇上批准再部署。

### 36.5 真机测试步骤（等部署后）

1. Sileo 里直接升级装 1.0.16，respring，确认正常启动、不黑屏、
   不卡、不进安全模式；
2. 去设置 → 越狱插件 → 顾海龙分屏，确认能打开、不闪退，
   开关能正常显示（默认关）；
3. 从屏幕右边缘向左滑一下，再用 Filza 看
   `/var/mobile/Library/Logs/GuHaiLongSplitScreen.log`，把里面
   的内容报给奴才（应该有 `v16 edge strip built`，滑过之后
   还有 `v16 pan detected`）；
4. 要是黑屏、卡住或进安全模式：强制重启 → Dopamine 关注入重越狱 →
   卸掉 1.0.16 → 报给奴才，奴才立刻把源换回 1.0.15（真机完全
   通过的版本）。

### 36.6 部署到 Cloudflare Pages（皇上 23:18 批准“部署到源上”）

- 部署成功（新部署 ffac468f），脚本线上检查直接报 LIVE OK。
- 独立核对过线上：`/Packages` 200、9003 字节，与本地 v32 逐字
  节相同，14 个包，分屏 1.0.16，0 个 1.0.15；`/Packages.zst`
  解出来与线上 Packages 一致；首页 200。v32 已上线。

### 36.7 真机测试：v16 也黑屏（2026-11-12 23:20），换回 v33

- 皇上装完 1.0.16，启动又黑屏了。v16 失败，**不要再装 1.0.16**。
- 结论干净了：v15（只建窗）通过，v14（窗 + 边缘滑动手势）
  黑屏，v16（窗 + 普通滑动手势）也黑屏——**任何手势识别器
  在咱们的窗里都会黑屏**，不是某一个手势类的问题。下一步
  只能不用手势识别器：自己接 touch 事件（touchesBegan /
  touchesMoved / touchesEnded），或用金色“分”字按钮当触发。
- 源已换回 v33（分屏 1.0.15，1.0.16 .deb 已从本地源删掉），
  部署 c53ee7c6，脚本线上检查直接报 LIVE OK；独立核对过线上：
  `/Packages` 200、8945 字节，与本地 v33 逐字节相同，14 个包，
  分屏 1.0.15，0 个 1.0.16；`/Packages.zst` 解出来与线上
  Packages 一致；首页 200。v33 已上线。
- 注意：这次换回的 1.0.15 不是原来那个 .deb（原来那个的设置页
  还会闪退，SHA256 `1cfa0c52...`），是用 v15 的主插件代码
  （Tweak.xm.v15.bak / control.v15.bak）加修好的设置页
  （RootListController.m 重写版、Root.plist 键名 enabled、标题
  改成 v1.0.15）重新编的，.deb **SHA256
  `e2e657dcae73a0bda8a13ec84c1d1ee0a705ccd733a788987bb3ca9b27bbdcf1`**；
  验过：主插件 dylib 和设置页二进制里都没有 __cfstring 段，
  禁用的全是 0（两种手势都是 0），Root.plist 的键名是 enabled。
  主插件的安全性就是 v15 本身（真机通过过），设置页是修好
  的版本。
- 皇上恢复步骤：强制重启 → Dopamine 关注入重越狱 → 卸掉
  1.0.16 → 正常重越狱。等皇上确认恢复。
- 下一步（等皇上批准）：v17，自己接 touch 事件做边缘滑动
  触发，不用手势识别器。

## 37. v17（1.0.17）—— 自己接 touch 做边缘滑动（2026-11-12 23:22 批准制作）

### 37.1 目的

- v16（1.0.16）皇上真机实测失败（2026-11-12 约 23:20）：装完
  启动又黑屏了。皇上已恢复（约 23:22 批准做 v17 时已在正常用
  手机），源已换回 v33（分屏 1.0.15，主插件是 v15，设置页是
  修好的版本）。
- 结论干净了：v15（只建窗）通过，v14（窗 + 边缘滑动手势）黑屏，
  v16（窗 + 普通滑动手势）也黑屏——**任何手势识别器在咱们的
  窗里都会黑屏**，不是某一个手势类的问题。
- v17 不用手势识别器：感应带用一个自己写的 UIView 子类
  （GHLSSStripView），直接接 touch 事件——手指按在带子上
  （touchesBegan）记下起点，手指往左滑（touchesMoved）超过
  40pt 就写一行日志，手指抬起（touchesEnded）或取消
  （touchesCancelled）就收尾。一次滑动只记一行。
- 判法：v17 不黑屏 + 滑一下日志里有 `v17 swipe detected` =
  自己接 touch 没事，边缘滑动触发这条路通了，下一步做侧边
  小窗；v17 也黑屏 = 问题不在手势识别器，是咱们的窗接 touch
  本身就不行，触发只能换金色“分”字按钮。
- 关键约束（v13 的教训）：**这个文件里一个写死的字串都不能有**——
  不用 CFSTR，也不用 @"..."。窗、视图全用运行时创建的对象，
  不碰任何字串常量。编译完要验 dylib 里没有 __cfstring 段，
  也没有手势识别器。
- 感应带不看开关：v17 永远建带，只测 touch 本身；开关的门以后再加。
  横屏不处理：只按竖屏算位置。
- 不登记通知、不 hook、不建 scene。Tweak.xm / control 已备份为
  .v15.bak 的是 v15 的版本（v17 建在 v15 之上，.v15.bak 就是
  v17 的底子），.deb 已备份为
  com.guhailong.splitscreen_1.0.17_iphoneos-arm64.deb.bak。
  设置页还是修好的版本（Root.plist 标题和说明改成 v1.0.17）。

### 37.2 编译与校验（2026-11-12 23:23，/tmp/ghlss-v17-build）

- 命令与 v10a/v10b/v11/v12/v13/v14/v15/v16 相同（/tmp 里编，
  umask 022，FINALPACKAGE=1，THEOS_PACKAGE_SCHEME=rootless）。
- .deb **38822 字节，SHA256 `2586fd94b0e300d69b475710075ffc4c44f7f252634ea1cb220a05051c9f1cd1`**；
  dpkg-deb -I/-c 验过（dylib 167472 字节，filter plist、prefs
  bundle、Root.plist 1409 字节、三张图标都在）。
- Mach-O 通用 arm64 + arm64e，LC_CODE_SIGNATURE 两个片都有。
- **关键校验：dylib 里没有 __cfstring 段**——一个写死的字串
  都没有；**`GestureRecognizer` 出现 0 次**——一个手势识别器
  都没有。
- strings：禁用的全部是 0（NSLog、medusa、floatingView、
  MGGetBoolAnswer、supportsMultiwindow、LSApplicationWorkspace、
  dictionaryWithContentsOfFile、**CFNotificationCenterAddObserver 0、
  CFNotificationCenterGetDarwinNotifyCenter 0、prefschanged 0、
  GestureRecognizer 0**）；
  dispatch_after 4、dispatch_time 4、CFPreferencesCopyAppValue 4、
  CFStringCreateWithCString 4、GuHaiLongSplitScreen.log 2、
  **GHLSSStripView 16、touchesBegan 2、touchesMoved 2、
  touchesEnded 2、touchesCancelled 2**。
- arm64e __text 反汇编：%ctor 只调 `bl _dispatch_time` 再尾调用
  `b _dispatch_after`（与 v10b/v11/v12/v13/v14/v15/v16 同形）；
  延后的 block 函数里调纯 C 函数（CFStringCreateWithCString、
  CFPreferencesCopyAppValue、CFGetTypeID、CFBooleanGetTypeID、
  CFBooleanGetValue、CFRelease、fopen、fputs、fputc、fclose、
  snprintf）加 ObjC 消息发送（objc_msgSend 与 objc_msgSendSuper——
  建窗、视图和 [super touches...] 要用 ObjC，对象都是运行时
  创建的，没有字串常量）；**手势识别器、通知登记、NSLog、
  medusa 均无**。
- 设置页二进制里也没有 __cfstring 段（修好的版本）。

### 37.3 本地源 v34（只更新本地，未部署，等皇上批准）

- 本地源换成 1.0.17 .deb（1.0.15 .deb 已删），Packages / .gz /
  .bz2 / .zst 与 Release 已重算（Packages.zst 往返校验过），
  14 个包，分屏 1.0.17，0 个 1.0.15；说明页 / 首页 / README
  已更新到 v17。
- 线上还是 v33（分屏 1.0.15），等皇上批准再部署。

### 37.4 真机测试步骤（等部署后）

1. Sileo 里直接升级装 1.0.17，respring，确认正常启动、不黑屏、
   不卡、不进安全模式；
2. 从屏幕右边缘向左滑一下，再用 Filza 看
   `/var/mobile/Library/Logs/GuHaiLongSplitScreen.log`，把里面
   的内容报给奴才（应该有 `v17 edge strip built`，滑过之后
   还有 `v17 swipe detected`）；
3. 要是黑屏、卡住或进安全模式：强制重启 → Dopamine 关注入重越狱 →
   卸掉 1.0.17 → 报给奴才，奴才立刻把源换回 1.0.15（真机完全
   通过的版本）。

### 37.5 部署到 Cloudflare Pages（皇上 23:25 批准“部署到源上”）

- 部署成功（新部署 4f61fd3d）；脚本刚传完的即时检查又报了
  不匹配（边缘节点还没同步的老毛病，见 §24.5），等了一分多钟
  再独立核对：线上 `/Packages` 200、9018 字节，与本地 v34
  逐字节相同，14 个包，分屏 1.0.17，0 个 1.0.15；
  `/Packages.zst` 解出来与线上 Packages 一致；首页 200。
  v34 已上线。

### 37.6 真机测试：v17 还是黑屏（2026-11-12 23:28），换回 v35

- 皇上装完 1.0.17，还是黑屏。v17 失败，**不要再装 1.0.17**。
- 重要修正：v17 一个手势识别器都没有，还是黑屏，所以**黑屏
  的凶手不是手势识别器**，之前 v16 的结论错了。v14/v16/v17
  相对 v15 共同的东西只剩两件：①它们都在感应带上加了“自己
  的东西”（v14/v16 是带回调对象手势，v17 是自己写的视图子类）；
  ②它们都可能赶上 SpringBoard 还没启动完（5 秒的延后也许
  不够，皇上手机里插件多，启动慢）。v15（只用苹果自己的类
  建窗）通过。
- 还有一个可能要问皇上：黑屏之前，主屏有没有出现过？还是
  苹果标志一过就直接黑屏？——主屏出现过再黑 = 延后步骤那 5 秒
  的问题；直接黑 = 加载时的问题。等皇上回答。
- 源已换回 v35（分屏 1.0.15，1.0.17 .deb 已从本地源删掉；
  这次换回的是 v33 那个 1.0.15 .deb，SHA256 `e2e657dc...`，
  主插件是 v15，设置页是修好的版本），部署 6f35a2b3，脚本
  线上检查直接报 LIVE OK；独立核对过线上：`/Packages` 200、
  8945 字节，与本地 v35 逐字节相同，14 个包，分屏 1.0.15，
  0 个 1.0.17；`/Packages.zst` 解出来与线上 Packages 一致；
  首页 200。v35 已上线。项目源码也换回 v15（Tweak.xm.v15.bak /
  control.v15.bak），Root.plist 标题和说明改回 v1.0.15。
- 皇上恢复步骤：强制重启 → Dopamine 关注入重越狱 → 卸掉
  1.0.17 → 正常重越狱。等皇上确认恢复。
- 下一步（等皇上批准和回答）：v18，感应带用一个自己写的
  普通视图子类（不接 touch、不挂手势），看“自己写的类”是
  不是凶手；如果 v18 也黑屏，就把延后从 5 秒改成更晚再测。

- 皇上回答了诊断问题（2026-11-12 23:31）：“装好就黑屏”——装好
  一启动就是黑屏，主屏没出现过。这说明问题出在启动那段时间，
  不是装好用了一会儿才出问题；结合 5 秒的延后，可能是延后步骤
  赶上 SpringBoard 还没启动完，也可能是加载时自定义类的注册
  就有问题。v18（自己写的普通视图，不接 touch、不挂手势）
  能分清这两者：过了 = 自己写的类没事，是 touch 那部分的问题；
  不过 = 自己写的类本身或时机有问题。
- 皇上还没确认从 v17 黑屏恢复，也还没点 v18 的选项，等他恢复
  后再说。

- 皇上从 v17 黑屏恢复了（2026-11-12 23:32）：强制重启 → Dopamine
  关注入重越狱 → 卸掉 1.0.17 → 正常重越狱，手机恢复正常。
  源上是 v35（分屏 1.0.15，主插件是 v15，设置页是修好的版本）。
- 等皇上决定做不做 v18（自己写的普通视图，不接 touch、不挂手势）。

## 38. v18（1.0.18）—— 自己写的普通视图（2026-11-12 23:33 批准制作）

### 38.1 目的

- v17（1.0.17）皇上真机实测失败（2026-11-12 约 23:28）：装完
  还是黑屏。皇上已恢复（约 23:32 确认好了），源已换回 v35
  （分屏 1.0.15，主插件是 v15，设置页是修好的版本）。
- 重要修正：v17 一个手势识别器都没有，还是黑屏，所以**黑屏
  的凶手不是手势识别器**，之前 v16 的结论错了。皇上还回答了：
  “装好就黑屏”，主屏没出现过，问题出在启动那段时间。
- v14/v16/v17 相对 v15 共同的东西只剩两件：①它们都在感应带
  上加了“自己的东西”（v14/v16 是带回调对象手势，v17 是自己
  写的视图子类）；②它们都可能赶上 SpringBoard 还没启动完
  （5 秒的延后也许不够，皇上手机里插件多，启动慢）。
- v18 只加一件：感应带用一个自己写的普通 UIView 子类
  （GHLSSPlainStripView），里面什么方法都没有，不接 touch、
  不挂手势，只测“自己写的类”本身是不是凶手。
- 判法：v18 不黑屏 = 自己写的类没事，是 touch 那部分的问题，
  下一步再想办法做边缘触发；v18 也黑屏 = 自己写的类本身就
  是问题（或时机问题），下一步把延后从 5 秒改成更晚再测。
- 关键约束（v13 的教训）：**这个文件里一个写死的字串都不能有**——
  不用 CFSTR，也不用 @"..."。窗、视图全用运行时创建的对象，
  不碰任何字串常量。编译完要验 dylib 里没有 __cfstring 段，
  也没有手势识别器和 touch 方法。
- 感应带不看开关：v18 永远建带，只测类本身；开关的门以后再加。
  横屏不处理：只按竖屏算位置。
- 不登记通知、不 hook、不建 scene。Tweak.xm / control 已备份为
  .v15.bak 的是 v15 的版本（v18 建在 v15 之上），.deb 已备份为
  com.guhailong.splitscreen_1.0.18_iphoneos-arm64.deb.bak。
  设置页还是修好的版本（Root.plist 标题和说明改成 v1.0.18）。

### 38.2 编译与校验（2026-11-12 23:33，/tmp/ghlss-v18-build）

- 命令与 v10a/v10b/v11/v12/v13/v14/v15/v16/v17 相同（/tmp 里编，
  umask 022，FINALPACKAGE=1，THEOS_PACKAGE_SCHEME=rootless）。
- .deb **37772 字节，SHA256 `fec97f7537850f15dbe302a90386ad6125b809a7fed74a74596a3b2c590636c5`**；
  dpkg-deb -I/-c 验过（dylib 167184 字节，filter plist、prefs
  bundle、Root.plist 1391 字节、三张图标都在）。
- Mach-O 通用 arm64 + arm64e，LC_CODE_SIGNATURE 两个片都有。
- **关键校验：dylib 里没有 __cfstring 段**——一个写死的字串
  都没有；**`GestureRecognizer` 出现 0 次、`touchesBegan` /
  `touchesMoved` / `touchesEnded` / `touchesCancelled` 各 0 次**——
  一个手势识别器、一个 touch 方法都没有。
- strings：禁用的全部是 0（NSLog、medusa、floatingView、
  MGGetBoolAnswer、supportsMultiwindow、LSApplicationWorkspace、
  dictionaryWithContentsOfFile、**CFNotificationCenterAddObserver 0、
  CFNotificationCenterGetDarwinNotifyCenter 0、prefschanged 0、
  GestureRecognizer 0、touchesBegan 0、touchesMoved 0、
  touchesEnded 0、touchesCancelled 0**）；
  dispatch_after 4、dispatch_time 4、CFPreferencesCopyAppValue 4、
  CFStringCreateWithCString 4、GuHaiLongSplitScreen.log 2、
  **GHLSSPlainStripView 10**。
- arm64e __text 反汇编：%ctor 只调 `bl _dispatch_time` 再尾调用
  `b _dispatch_after`（与 v10b/v11/v12/v13/v14/v15/v16/v17 同形）；
  延后的 block 函数里调纯 C 函数（CFStringCreateWithCString、
  CFPreferencesCopyAppValue、CFGetTypeID、CFBooleanGetTypeID、
  CFBooleanGetValue、CFRelease、fopen、fputs、fputc、fclose、
  snprintf）加 ObjC 消息发送（objc_msgSend——建窗和视图要用
  ObjC，对象都是运行时创建的，没有字串常量）；**手势识别器、
  touch 方法、通知登记、NSLog、medusa 均无**。
- 设置页二进制里也没有 __cfstring 段（修好的版本）。

### 38.3 本地源 v36（只更新本地，未部署，等皇上批准）

- 本地源换成 1.0.18 .deb（1.0.15 .deb 已删），Packages / .gz /
  .bz2 / .zst 与 Release 已重算（Packages.zst 往返校验过），
  14 个包，分屏 1.0.18，0 个 1.0.15；说明页 / 首页 / README
  已更新到 v18。
- 线上还是 v35（分屏 1.0.15），等皇上批准再部署。

### 38.4 真机测试步骤（等部署后）

1. Sileo 里直接升级装 1.0.18，respring，确认正常启动、不黑屏、
   不卡、不进安全模式；
2. 用 Filza 看 `/var/mobile/Library/Logs/GuHaiLongSplitScreen.log`，
   把里面的内容报给奴才（应该有 `v18 edge strip built`）；
3. 要是黑屏、卡住或进安全模式：强制重启 → Dopamine 关注入重越狱 →
   卸掉 1.0.18 → 报给奴才，奴才立刻把源换回 1.0.15（真机完全
   通过的版本）。

### 38.5 部署到 Cloudflare Pages（皇上 23:49 批准“部署到源上”）

- 部署成功（新部署 e48259fa）；脚本线上检查直接报 LIVE OK；
  独立核对过线上：`/Packages` 200、9020 字节，与本地 v36
  逐字节相同，14 个包，分屏 1.0.18，0 个 1.0.15；
  `/Packages.zst` 解出来与线上 Packages 一致；首页 200。
  v36 已上线。

### 38.6 真机测试：v18 也黑屏（2026-11-12 23:53），换回 v37

- 皇上装完 1.0.18，也黑屏。v18 失败，**不要再装 1.0.18**。
- 这次是决定性的：v18 的 GHLSSPlainStripView 是一个**空的
  视图子类，里面一个方法都没有，不接 touch、不挂手势**，
  还是黑屏。v15（只用苹果自己的类建窗）通过，v14/v16/v17/
  v18（都定义了自己写的类）全黑屏。结论：**黑屏的凶手是
  “自己写的 ObjC 类”本身**——这个工具链编出来的自定义类
  在 SpringBoard 里就是坏的（和 CFSTR 一个家族的问题，很
  可能是类的元数据/签名指针坏了），不是 touch、不是手势。
  附带修正：手势识别器本身可能是无辜的——v14/v16 的识别器
  目标一直都是自己写的类，黑屏也可以全怪在类头上。
- 5 秒时机的可能还没完全排除（v15 只通过一次），但四连败
  全带自定义类、一通过全不带，这个相关性已经很强。
- 源已换回 v37（分屏 1.0.15，1.0.18 .deb 已从本地源删掉；
  这次换回的是 v33 那个 1.0.15 .deb，SHA256 `e2e657dc...`，
  主插件是 v15，设置页是修好的版本），部署 e7a50864，脚本
  线上检查直接报 LIVE OK；独立核对过线上：`/Packages` 200、
  8945 字节，与本地 v37 逐字节相同，14 个包，分屏 1.0.15，
  0 个 1.0.18；`/Packages.zst` 解出来与线上 Packages 一致；
  首页 200。v37 已上线。项目源码也换回 v15（Tweak.xm.v15.bak /
  control.v15.bak），Root.plist 标题和说明改回 v1.0.15。
- 皇上恢复步骤：强制重启 → Dopamine 关注入重越狱 → 卸掉
  1.0.18 → 正常重越狱。等皇上确认恢复。
- 下一步（等皇上批准）：v19，**不用自己写的类**，只用苹果
  自己的类 + C 函数 + block：v15 的窗 + 一个透明 UIButton
  （苹果的类）盖在感应带上，用 UIAction（block 回调，标题
  用运行时现做的字串）记一行日志。不定义任何类、不挂手势。
  v19 不黑屏 = 这条路通了，触发器和小窗都能用“苹果的类 +
  UIAction”搭出来；v19 也黑屏 = 连苹果的按钮在窗里都有
  问题，感应带这条路要换做法（比如只用金色“分”按钮的
  思路，或把窗做得更晚）。

### 38.7 皇上叫停一个个测，改看开源项目（2026-11-13 00:00）

- 皇上：“没有开源项目看模仿一下吗？我们一个个测试感觉效率
  很慢”。奴才认了：v1 到 v18 一个个试了一晚上，是慢。
- v19 的源码已经写好了（Tweak.xm / control / Root.plist 都是
  1.0.19），但**还没编译，暂停**——等看完开源项目再决定
  还做不做 v19。本地源还是 v37（分屏 1.0.15），线上也是
  v37，没动。
- 已派人去查开源的分屏/浮窗项目（TrollPad、FrontBoardAppLauncher、
  LiveContainer、SplitViewEverywhere、Medousa 等），重点看：
  它们怎么在 SpringBoard 里建浮窗、怎么触发、怎么定义自己的
  类、用什么工具链编译——尤其是为什么它们的类能用，我们
  工具链编出来的类就黑屏。只看开源的（MIT/Apache-2.0），
  闭源/付费的一行都不抄。
- 等查完回来，奴才把能模仿的项目和做法报给皇上，再决定下一步。

## 39. 开源项目调研（2026-11-13 00:00–00:03，皇上叫停逐个测之后）

### 39.1 查到什么

- 最佳模型 **FrontBoardAppLauncher**（khanhduytran0，TrollPad /
  LiveContainer 的作者）：https://github.com/khanhduytran0/FrontBoardAppLauncher，
  **Apache-2.0（奴才亲自核对过 LICENSE 全文）**，可直接仿照。
  浮窗容器 `DecoratedFloatingView.m`（UIView 子类，顶部 nav bar
  拖动 + 右下角 resize handle，移动和缩放都用
  `UIPanGestureRecognizer`）、场景托管 `DecoratedAppSceneView.m`
  （`FBApplicationProcessLaunchTransaction` → `FBSceneManager` →
  `_UIScenePresenter`，和我们 V5 设计文档的 FrontBoard 路线
  一致）、私有 API 声明集中在 `UIKitPrivate.h`。它的自定义类
  带手势、带 target-action 回调，在生产环境里正常工作——直接
  反驳了“手势识别器本身会黑屏”的旧结论。触发方式是独立 App
  表格点选，没有边缘滑动，解决不了触发器问题，只能解决浮窗
  + 场景托管。已知问题和我们 V5 文档的风险完全一致（键盘、
  单场景 app 空白窗、关窗后进程还在跑）。
- 第二模型 **KonbanXV**（MIT）：https://github.com/Hoangdus/KonbanXV，
  把一个 app 嵌进主屏 Today 页的 **SpringBoard tweak**，iOS 15–16，
  Havoc 上架，rootless。证明自定义类 + 场景托管在 SpringBoard
  里、iOS 15/16 rootless 上是可以工作的——只要构建工具链是对的。
- 只能看原理、不能抄：LiveContainer（AGPL-3.0，不要从这里抄，
  要抄就抄 Apache-2.0 的原版；它的 `MultitaskSupport/` 明确写着
  "Based on FrontBoardAppLauncher"）、TrollPad（medusa 路线，
  LICENSE 未验证，我们已决定不用 medusa）、SplitViewEverywhere
  （仅 iPad）、Zetsu/Medousa/MilkyWay 4/Little12/Myrtle/Aerial/
  floatingView/TrollOpen（全部闭源或付费；TrollOpen 明确写
  "Do not fork"）。

### 39.2 关键发现：我们的工具链很可能是真正的凶手

- 所有能正常工作的开源项目都是用 **Apple clang（macOS/Xcode
  工具链）**编的，没有一个用 Linux 交叉工具链。
- **FrontBoardAppLauncher 的 Makefile 第一行就是
  `ARCHS := arm64`**（奴才亲自核对过原文），只编 arm64，
  没有 arm64e 切片；TARGET 是 `iphone:clang:16.5:15.0`，
  构建环境是 macOS（GitHub Actions macOS runner）。
- arm64e 切片涉及指针认证（pointer authentication）：类的 isa、
  方法表、CFString 的 isa 都是签名指针。Linux 交叉 clang 11.1.0
  很可能签错了这些指针——这能同时解释 CFSTR 坏和自定义类坏
  （同一个家族的问题），而只用苹果类 + C 函数的 v15 能通过
  （它不产生这些元数据）。
- 注意：这目前是强相关 + 机理合理的假说，不是已证实的事实；
  下面 v20 那一测才是证明。DeepWiki 的文件级摘要细节（行号）
  写代码时要先打开原文逐行核对。

### 39.3 下一步（等皇上批准）

- **第一件（先做，成本最低）：v20（1.0.20）——v18 的代码原封
  不动（自定义空视图那个版本），只改 `Makefile` 加
  `ARCHS = arm64`（去掉 arm64e 切片），编出来真机测一次。**
  过了 → 凶手就是 Linux 工具链的 arm64e 切片；以后全部编
  arm64-only，自定义类、手势、CFSTR 可能全都恢复正常，一晚
  上的逐变量测试就此结束。不过 → 再做第二件。
- **第二件（如果第一件不过）：换 macOS 构建。**用 GitHub Actions
  的 macOS runner + Theos + iOS 16.5 SDK 编（FrontBoardAppLauncher
  的 `.github/workflows/build.yml` 就是现成模板，照抄它的流程）。
  障碍是 GitHub 账号 guhailong2026 被停用、申诉 #4992858 还没
  回音；要么等申诉结果，要么用新账号/新邮箱建一个只做构建的号。
  不要再在 Linux 工具链上逐个试 touch/手势/延时了——那是绕着
  凶手打转。
- v19（UIButton + UIAction，已写好源码但未编译）可以继续测，
  是个便宜的数据点（纯苹果类触摸是否安全），但**不要把它当成
  主线**。如果 v20（arm64-only）过了，触发器直接用
  FrontBoardAppLauncher 的做法：`UIPanGestureRecognizer` 挂在
  nav bar/handle 上，自定义类做 target——开源项目已经证明这套
  组合是工作的。
- 仿照清单（给下一版）：①浮窗容器仿
  `FrontBoardAppLauncher/DecoratedFloatingView.m`（Apache-2.0，
  保留原作者 copyright 声明并注明改动）；②场景托管仿
  `DecoratedAppSceneView.m`（场景设置照它 43–58 行的表），
  `UIKitPrivate.h` 的私有 API 声明方式也照抄结构；③SpringBoard
  内嵌细节仿 `KonbanXV/KonbanSpringboard/`（MIT），看它如何把
  场景 view 嵌进 SpringBoard 的 view 层级、它的 `Makefile` 和
  rootless 打包；④触发器开源项目里没有好的边缘滑动模型，
  继续用我们自己的方案（先 v19 的按钮验证，再过渡到 pan 手势）。

## 40. v20（1.0.20）—— v18 代码原封不动，只编 arm64（2026-11-13 00:05 批准制作）

### 40.1 目的

- v18（1.0.18）皇上真机实测失败（2026-11-12 约 23:53）：装完
  也黑屏。皇上叫停一个个测（2026-11-13 00:00），改看开源项目；
  调研见 §39：FrontBoardAppLauncher（Apache-2.0）和 KonbanXV
  （MIT）的自定义类带手势、带 target，在生产环境里正常工作；
  所有能用的开源项目都是用苹果自己的 clang 在 macOS 上编的，
  FrontBoardAppLauncher 的 Makefile 第一行就是 `ARCHS := arm64`
  （奴才核对过原文），只编 arm64，没有 arm64e 切片。
- 新假说：凶手不是“自己写的类”，而是 **Linux 工具链的 arm64e
  切片**——arm64e 有指针认证，类的 isa、方法表、CFString 的 isa
  都是签名指针，Linux 交叉 clang 11.1.0 很可能签错了这些指针，
  这能同时解释 CFSTR 坏和自定义类坏。
- v20 就是证明：代码和 v18 一模一样（同一个空视图子类、同一
  个延后步骤、同一扇窗），只改 `Makefile` 的 `ARCHS = arm64`
  （去掉 arm64e 切片）。版本号和日志里的 v18 改成 v20，除此
  之外一个字都没动。v19 的源码已备份为 Tweak.xm.v19.bak /
  control.v19.bak / Makefile.v19.bak（Makefile 原来是
  `ARCHS = arm64 arm64e`），v19 暂停未编。
- 判法：v20 不黑屏 = 凶手就是 arm64e 切片；以后全部编
  arm64-only，自定义类、手势、CFSTR 可能全都恢复正常，一晚
  上的逐变量测试就此结束。v20 也黑屏 = arm64e 不是凶手，
  下一步换 macOS 构建（GitHub Actions，模板现成的；障碍是
  GitHub 账号停用申诉 #4992858 还没回音）。
- 关键约束（v13 的教训）：**这个文件里一个写死的字串都不能有**——
  不用 CFSTR，也不用 @"..."。窗、视图全用运行时创建的对象，
  不碰任何字串常量。编译完要验 dylib 里没有 __cfstring 段，
  也没有手势识别器和 touch 方法，**并且只有一个 arm64 片
  （没有 arm64e）**。
- 感应带不看开关：v20 永远建带，只测类本身；开关的门以后再加。
  横屏不处理：只按竖屏算位置。
- 不登记通知、不 hook、不建 scene。Tweak.xm / control 已备份为
  .v19.bak 的是 v19 的版本（v20 建在 v18 之上），.deb 已备份为
  com.guhailong.splitscreen_1.0.20_iphoneos-arm64.deb.bak。
  设置页还是修好的版本（Root.plist 标题和说明改成 v1.0.20）。

### 40.2 编译与校验（2026-11-13 00:05，/tmp/ghlss-v20-build）

- 命令与 v10a/v10b/v11/v12/v13/v14/v15/v16/v17/v18/v19 相同（/tmp 里编，
  umask 022，FINALPACKAGE=1，THEOS_PACKAGE_SCHEME=rootless），
  唯一差别是 Makefile 的 `ARCHS = arm64`。
- .deb **36966 字节，SHA256 `20e099fe4eeebd4c90b177e715a3efde35e75826ba7c0975a38646baf8beea7a`**；
  dpkg-deb -I/-c 验过（dylib **68944 字节**——v18 通用版是 167184
  字节，单片自然小一半；filter plist、prefs bundle、Root.plist
  1492 字节、三张图标都在）。
- **关键校验：`file` 显示 `Mach-O 64-bit arm64`，只有一个片，
  不是通用二进制——arm64e 确实没了。**LC_CODE_SIGNATURE 1 个。
- **dylib 里没有 __cfstring 段**——一个写死的字串都没有；
  **`GestureRecognizer` 出现 0 次、`touchesBegan` / `touchesMoved` /
  `touchesEnded` / `touchesCancelled` 各 0 次**——一个手势识别器、
  一个 touch 方法都没有；UIButton / UIAction 也是 0（v20 没有
  按钮，是 v18 的代码）。
- strings：禁用的全部是 0（NSLog、medusa、floatingView、
  MGGetBoolAnswer、supportsMultiwindow、LSApplicationWorkspace、
  dictionaryWithContentsOfFile、**CFNotificationCenterAddObserver 0、
  CFNotificationCenterGetDarwinNotifyCenter 0、prefschanged 0、
  GestureRecognizer 0、touchesBegan 0、touchesMoved 0、
  touchesEnded 0、touchesCancelled 0**）；
  dispatch_after 2、dispatch_time 2、CFPreferencesCopyAppValue 2、
  CFStringCreateWithCString 2、GuHaiLongSplitScreen.log 1、
  **GHLSSPlainStripView 5**——出现次数正好是 v18 通用版的一半
  （v18 是 4、4、4、4、2、10），因为只有一个片，符合预期。
- arm64 __text 反汇编：%ctor 只调 `bl _dispatch_time` 再尾调用
  `b _dispatch_after`（与 v10b/v11/v12/v13/v14/v15/v16/v17/v18 同形）；
  延后的 block 函数里调纯 C 函数（CFStringCreateWithCString、
  CFPreferencesCopyAppValue、CFGetTypeID、CFBooleanGetTypeID、
  CFBooleanGetValue、CFRelease、fopen、fputs、fputc、fclose、
  snprintf）加 ObjC 消息发送（objc_msgSend——建窗和视图要用
  ObjC，对象都是运行时创建的，没有字串常量）；**手势识别器、
  touch 方法、通知登记、NSLog、medusa 均无**。
- 设置页二进制里也没有 __cfstring 段（修好的版本）。

### 40.3 本地源 v39（只更新本地，未部署，等皇上批准）

- 本地源换成 1.0.20 .deb（1.0.15 .deb 已删），Packages / .gz /
  .bz2 / .zst 与 Release 已重算（Packages.zst 往返校验过），
  14 个包，分屏 1.0.20，0 个 1.0.15；说明页 / 首页 / README
  已更新到 v20。
- 线上还是 v37（分屏 1.0.15），等皇上批准再部署。

### 40.4 真机测试步骤（等部署后）

1. Sileo 里直接升级装 1.0.20，respring，确认正常启动、不黑屏、
   不卡、不进安全模式；
2. 用 Filza 看 `/var/mobile/Library/Logs/GuHaiLongSplitScreen.log`，
   把里面的内容报给奴才（应该有 `v20 edge strip built`）；
3. 要是黑屏、卡住或进安全模式：强制重启 → Dopamine 关注入重越狱 →
   卸掉 1.0.20 → 报给奴才，奴才立刻把源换回 1.0.15（真机完全
   通过的版本）。

### 40.5 部署到 Cloudflare Pages（皇上 00:07 批准“部署到源上”）

- 部署成功（新部署 ae180fd6）；脚本线上检查直接报 LIVE OK；
  独立核对过线上：`/Packages` 200、9181 字节，与本地 v39
  逐字节相同，14 个包，分屏 1.0.20，0 个 1.0.15；
  `/Packages.zst` 解出来与线上 Packages 一致；首页 200。
  v39 已上线。

### 40.6 皇上说明天测（2026-11-13 00:08）

- 皇上：“辛苦了，我明天测试”。v20（1.0.20）的真机测试推到
  明天（2026-11-13）白天。源上是 v39（分屏 1.0.20），不用动。
- 皇上从 v18 黑屏的恢复还没有明确确认过，但他说明天测 v20，
  测的时候自然就确认了；明天等他报结果再说。

### 40.6 皇上今天装了 v20，可以使用（2026-11-13 08:23）

- 皇上：“我今天加了，可以使用”。按上下文是装了 1.0.20，
  手机能正常用、没有黑屏。这是 v20 的初步好消息：v18 的
  代码（通用 arm64+arm64e）黑屏，v20 同样的代码只编 arm64
  就能用了，arm64e 切片是凶手的假说很可能对了。
- 还没完全确认：皇上没说日志里有没有 `v20 edge strip built`，
  也没明确说装的是 1.0.20。等皇上报日志再记正式结论。

### 40.7 皇上的日志截图：没有 v20 的行（2026-11-13 08:24）

- 皇上发来日志截图（08:23）：只有 5 行，v13 的两行和 v15
  的三行（`v15 edge strip built`），**没有 `v20 deferred setup
  ran`，也没有 `v20 edge strip built`**。
- 结论：1.0.20 还没有在皇上手机上跑起来。手机能用、没黑屏
  是好消息，但不能算通过——有两种可能：①装完还没 respring，
  新版还没加载（日志还是上次 1.0.15 启动时写的）；②arm64-only
  的 dylib 根本没注进 arm64e 的 SpringBoard（那“没黑屏”就是
  假通过——什么都没加载，当然不黑屏）。
- 等皇上确认：Sileo 里装的版本是不是 1.0.20、有没有 respring、
  再看一次日志有没有 v20 的行。

### 40.8 皇上确认装的是 1.0.20，但日志里没 v20（2026-11-13 08:27）

- 皇上：“装的是1.0.20可是没看见v20”。Sileo 里装的版本确认
  是 1.0.20，但日志里没有 v20 的行。
- 剩下两种可能：①装完还没 respring，新版还没加载（日志还是
  上次 1.0.15 启动时写的）；②已经 respring 过了，但 arm64-only
  的 dylib 没注进 arm64e 的 SpringBoard（假通过）。
- 等皇上回答：装完有没有 respring。没 respring 就现在 respring
  一次，等 10 秒再看日志；已经 respring 过了还没 v20，就说明
  dylib 没加载，下一步要查 arm64-only 的 dylib 能不能注进
  arm64e 进程，或走 macOS 构建。

### 40.9 真机测试：v20 失败——包没加载，假通过（2026-11-13 08:29），换回 v40

- 皇上确认：装的是 1.0.20，respring 过了，还是没看见 v20。
  结论：**v20 失败**。只编 arm64 的 dylib 注不进 arm64e 的
  SpringBoard，等于什么都没加载——“没黑屏”是假通过，不是
  arm64e 被证明无罪。arm64-only 这条路走不通（连测都没法测），
  arm64e 切片是不是凶手仍然没证明。
- 源已换回 v40（分屏 1.0.15，1.0.20 .deb 已从本地源删掉；
  这次换回的是 v33 那个 1.0.15 .deb，SHA256 `e2e657dc...`，
  主插件是 v15，设置页是修好的版本；Makefile 也换回
  `ARCHS = arm64 arm64e`），部署 e28e3cf9，脚本线上检查直接
  报 LIVE OK；独立核对过线上：`/Packages` 200、8945 字节，
  与本地 v40 逐字节相同，14 个包，分屏 1.0.15，0 个 1.0.20；
  `/Packages.zst` 解出来与线上 Packages 一致；首页 200。
  v40 已上线。项目源码也换回 v15（Tweak.xm.v15.bak /
  control.v15.bak / Makefile.v19.bak），Root.plist 标题和说明
  改回 v1.0.15。
- 皇上要做的事：Sileo 里把分屏降回 1.0.15（或卸掉 1.0.20 重装
  1.0.15），respring，日志里应该重新有 `v15 edge strip built`。
- 下一步：macOS 构建（GitHub Actions，FrontBoardAppLauncher
  的 build.yml 是现成模板）。障碍是 GitHub 账号 guhailong2026
  被停用、申诉 #4992858 还没回音；主聊天那边约好今天约 10:00
  公开查账号有没有恢复、问皇上有没有收到回复。等那个结果：
  恢复了就用它建 Actions；没恢复就用新邮箱建一个只做构建的号。
  v19（UIButton + UIAction，通用版）还是个便宜的数据点，但
  不是主线，先放着。

### 40.10 GitHub 旧账号还没恢复（2026-11-13 08:33 公开查过）

- 皇上问能不能用新账号。奴才公开查了
  https://github.com/guhailong2026：404 找不到页面，没有用户
  信息（GitHub 对停用的账号就是这么显示的）。旧账号还没恢复，
  申诉 #4992858 还没结果。
- 所以现在能走的路是新账号：换一个邮箱注册（不能用
  2309103548@qq.com），专门做 macOS 构建。等皇上说有没有
  别的邮箱。

### 40.11 新 GitHub 账号建好了：yxiao4168-coder（2026-11-13 08:36）

- 皇上发来 GitHub App 截图：新账号 **yxiao4168-coder**，已登入，
  Repositories 0、Starred 0、Organizations 0。旧账号
  guhailong2026 今早 08:33 公开查还是 404，没恢复。
- 下一步：用这个新账号做 macOS 构建。做法是在新账号下建一个
  仓库，放插件源码 + GitHub Actions 构建文件（照抄
  FrontBoardAppLauncher 的 `.github/workflows/build.yml` 流程：
  macOS runner + Theos + iOS 16.5 SDK + ldid，编出 .deb 当
  artifact 下载）。皇上在手机上看不懂英文，建仓库、加文件
  最好是奴才在浏览器里帮皇上办（需要皇上在浏览器里登入新
  账号一次），或者奴才一步步用中文教皇上在 App 里点。
- 等皇上决定怎么做。
