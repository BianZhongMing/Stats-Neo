# Stats

<a href="https://github.com/BianZhongMing/stats/releases"><p align="center"><img src="https://github.com/exelban/stats/raw/master/Stats/Supporting%20Files/Assets.xcassets/AppIcon.appiconset/icon_256x256.png" width="120"></p></a>

[![Stats](https://cdn.mac-stats.com/assets/images/menus.png)](https://github.com/BianZhongMing/stats/releases)
[![Stats](https://cdn.mac-stats.com/assets/images/popups.png)](https://github.com/BianZhongMing/stats/releases)

macOS system monitor in your menu bar

> [!IMPORTANT]
> 这是基于 [exelban/stats](https://github.com/exelban/stats) `3.0.21` 的非官方二次开发版本，重点增强网速状态栏显示和多模块聚合能力。上游项目及原作者不负责维护本 Fork。页面顶部截图来自上游原版，二开差异以本文说明和本 Fork Release 为准。

## Combined Edition（二开说明）

### 相较原版的功能变化

| 功能 | 原版行为 | 本 Fork 调整 |
| --- | --- | --- |
| 网速采样 | 网络读取器使用原有默认周期 | 默认每 **3 秒**采样；按单调时钟的实际时间差换算每秒速率。仅 Combined 网速运行时只读取接口字节计数，空闲时可按能耗模式自动降到 10～30 秒 |
| 网速状态栏 | 原有 Speed Widget 默认样式 | 默认使用上下行箭头；采用等宽数字、常规字重、独立上下行颜色，并调整箭头尺寸、间距和动态宽度，使显示更接近 iStat Menus |
| 合并模块入口 | 位于应用通用设置中，与普通模块启用状态和 one-view 行为耦合 | 在设置侧边栏增加独立的 **Combined / 合并**页面，使用与普通模块一致的右上角启用开关 |
| 合并组件管理 | 聚合已启用的普通模块 | 可直接在合并页面勾选组件并拖拽排序；选择结果独立保存，不会修改普通模块的开关；拖动释放后按持久化顺序安全重建全宽行，避免列错位或行向中间收缩 |
| 合并状态栏 | 复用普通模块的菜单栏 View，可能影响其显示方式 | 合并项是独立状态栏项目，可选择显示单图标或完整上下行网速；普通 CPU、网络等状态栏项目可同时存在 |
| 数据采集 | 普通模块关闭后对应读取器停止 | 读取结果只投递给当前真实消费者；纯 Combined 网速模式不启动 `ps`、`top`、`nettop`、CoreWLAN/定位详情资源；CPU、内存、磁盘、电池等面板数据只在聚合弹窗打开时采集 |
| 能耗策略 | 各 Reader 独立定时且始终按固定周期运行 | 提供实时、平衡、省电三档；同频 Reader 共享定时节拍，平衡模式下空闲网速降至 10 秒，省电或系统低电量模式可降至 30 秒，进程榜默认限制为 3～10 秒且禁止重叠采样 |
| 聚合面板 | 标题和组件布局沿用原聚合实现 | 标题改为 `Stats`，字体和间距更紧凑；组件按选择顺序展示，传感器标题、列表和滚动区域统一左对齐 |
| 合并选项 | 包含间距、分隔符、合并详情等多组关联设置 | 移除意义有限且容易造成状态混乱的旧选项，保留启用开关、状态栏网速模式、组件选择和排序 |

### 使用方式

1. 打开 **Stats 设置 → Combined（合并）**。
2. 使用窗口右上角开关单独启用合并模块。
3. 在组件列表中勾选需要聚合展示的模块；拖动每行右侧手柄调整顺序。
4. 开启“显示网速”后，合并状态栏项显示完整的上传/下载箭头和数值；关闭后显示 Stats 小图标。
5. 在“能耗模式”选择实时、平衡或省电；平衡模式会自动跟随 macOS 低电量模式进入更保守的采样策略。
6. 点击合并状态栏项打开聚合面板。普通模块可独立开启或关闭，也可与合并项同时显示在状态栏。

### 关键代码调整

| 代码位置 | 调整说明 |
| --- | --- |
| `Stats/Views/CombinedView.swift` | 重构合并状态栏与聚合弹窗；新增独立 `CombinedSettings`、组件勾选列表、拖拽排序，以及合并专用 `SpeedWidget` |
| `Stats/Views/Settings.swift` | 在侧边栏加入 Combined 页面，并复用设置窗口右上角通用开关控制合并模块 |
| `Stats/Views/AppSettings.swift` | 移除通用设置页中旧的合并配置，避免出现两套入口和状态来源 |
| `Kit/module/module.swift`、`Kit/module/reader.swift` | 按独立模块、合并弹窗和合并状态栏区分真实消费者；定向分发回调、无消费者时停止 Reader，并支持不可重入采样和运行时间隔覆盖 |
| `Kit/plugins/Repeater.swift`、`Kit/plugins/DB.swift` | 同频 Reader 共用定时节拍与 utility 回调队列；扩大调度容差，并在持久化节流判断后才执行 JSON 编码 |
| `Kit/module/widget.swift` | 合并开关不再强制普通模块进入 one-view，也不再隐藏、搬移或重建普通模块的状态栏项目 |
| `Modules/Net/readers.swift` | 拆分快速字节计数和慢速接口/Wi-Fi/IP 详情路径；使用单调时钟换算速率，纯 Combined 网速强制避开 `nettop`，并按流量和能耗模式自适应降频 |
| `Modules/Net/main.swift` | 网络结果只发送给可见 Popup/Portal/Preview、独立菜单栏或 Combined 网速消费者，隐藏界面不再维护高频图表历史 |
| `Modules/Net/settings.swift` | 增加网络更新间隔设置，并确保修改的是 Usage Reader 的采样周期 |
| `Kit/Widgets/Speed.swift` | 重绘上下行线性箭头，使用等宽数字并重新计算两行布局、颜色和动态宽度 |
| `Kit/module/portal.swift`、`Modules/Sensors/portal.swift` | 压缩 Portal 标题样式，显式约束全宽与 leading 对齐，修复传感器滚动条出现后的错误缩进 |
| `Stats/AppDelegate.swift`、`Stats/helpers.swift` | 将合并项视为独立活动状态栏项目，并在全局暂停/恢复时同步合并专用读取器 |
| `Stats/Supporting Files/{en,zh-Hans,zh-Hant}.lproj/Localizable.strings` | 补充合并页面、组件列表和网速模式的英文、简体中文与繁体中文文案 |

本次核心二开提交共调整 **26 个文件**（`686 insertions / 267 deletions`）。基线为上游提交 `88d5359`，核心功能提交为 [`81d5162`](https://github.com/BianZhongMing/stats/commit/81d516200409e05e402c9e7513823246396782db)。

### 构建与发布信息

- 应用版本：`3.0.21`（build `849`）
- 架构：Universal（`x86_64` + `arm64`）
- 签名：ad-hoc；不是 Apple 公证版本，首次运行时可能需要在“系统设置 → 隐私与安全性”中手动允许
- 已验证：Release 构建、Universal 架构、`codesign --verify --deep --strict`、DMG 校验和、ZIP 完整性
- 当前 Release：[`v3.0.21-combined.3`](https://github.com/BianZhongMing/stats/releases/tag/v3.0.21-combined.3)

## Installation
### Manual（本 Fork）
推荐从本 Fork 的最新 Release 下载：

- [Stats.dmg](https://github.com/BianZhongMing/stats/releases/latest/download/Stats.dmg)
- [Stats.app.zip](https://github.com/BianZhongMing/stats/releases/latest/download/Stats.app.zip)

打开 `Stats.dmg` 后将应用拖入“应用程序”目录；或者解压 `Stats.app.zip` 后手动移动 `Stats.app`。

> [!NOTE]
> 以下 Homebrew 和 Headless 安装方式仍由上游项目维护，安装的是 `exelban/stats` 原版，不包含本 Fork 的合并模块和状态栏网速调整。

### Homebrew（上游原版）
To install it using Homebrew, open the Terminal app and type:
```bash
brew install stats
```

### Headless (SSH，上游原版)
To install Stats remotely over SSH and set it up as a remote monitoring agent, run:
```bash
curl -fsSL https://cdn.mac-stats.com/install.sh | bash
```
The script installs the app, enables the Remote module and prints a URL with an authorization code - open it on any device and sign in to your System Stats account to authorize the machine. After that Stats starts streaming metrics to your account and is registered to launch automatically at login and restart if it stops.
The Mac needs an active user session (a locked screen is fine) to run the app; on a fully headless machine Stats will start at the next login.

### Uninstall
Run the uninstall script bundled with the app (requires administrator privileges to remove the SMC helper):
```bash
sh /Applications/Stats.app/Contents/Resources/Scripts/uninstall.sh
```

### Legacy version
Legacy version for older systems could be found [here](https://mac-stats.com/downloads).

## Requirements
Stats is supported on macOS 12 (Monterey) and newer.
Beta versions of macOS are not supported - only stable releases.

## Features
Stats is an application that allows you to monitor your macOS system.

 - CPU utilization
 - GPU utilization
 - Memory usage
 - Disk utilization
 - Network usage
 - Battery level
 - Fan's control (not maintained)
 - Sensors information (Temperature/Voltage/Power)
 - Bluetooth devices
 - Multiple time zone clock
 - Independent Combined panel with selectable and reorderable components
 - iStat-style upload/download speed display with a default 3-second refresh interval

## FAQs

### How do you change the order of the menu bar icons?
macOS decides the order of the menu bar items not `Stats` - it may change after the first reboot after installing Stats.

To change the order of any menu bar icon - macOS Mojave (version 10.14) and up.

1. Hold down ⌘ (command key).
2. Drag the icon to the desired position on the menu bar.
3. Release ⌘ (command key)

### Stats icons do not appear in the menu bar
macOS 26 introduced a new privacy control under System Settings → Menu Bar. Apps must be explicitly allowed there to display menu bar items. If Stats is running with at least one module active and one widget enabled, but none of its icons show up in the menu bar, this is almost certainly the cause. More details you can find [here](https://github.com/exelban/stats/issues/3120).

**Solution:** open **System Settings → Menu Bar** and toggle **Stats** ON.

### Desktop widgets not showing the data
Due to a problem with high data load in the system process (`chronod`) responsible for communication between the app and widgets, communication is disabled by default on the Stats side. To enable it, the `macOS widgets` option must be enabled in the Stats settings. More details you can find [here](https://github.com/exelban/stats/issues/2733).

**Solution:** open **Stats Settings** and toggle **macOS widgets** ON.

### Wi-Fi network name shows Unknown
macOS requires Location Services permission to read the Wi-Fi network name. If access for Stats is disabled, the network name may show as `Unknown` without a permission popup.

**Solution:** open **System Settings → Privacy & Security → Location Services**, make sure Location Services is enabled, and toggle **Stats** ON. Then quit and reopen Stats.

### How to reduce energy impact or CPU usage of Stats?
Stats tries to be efficient as it's possible. But reading some data periodically is not a cheap task. Each module has its own "price". So, if you want to reduce energy impact from the Stats you need to disable some Stats modules. The most inefficient modules are Sensors and Bluetooth. Disabling these modules could reduce CPU usage and power efficiency by up to 50% in some cases.

### Fan control
Fan control is in legacy mode. It does not receive any updates or fixes. It's not dropped from the app just because in the old Macs it works pretty acceptable. I'm open to accepting fixed or improvements (via PR) for this feature in case someone would like to help with that. But have no option and time to provide support for this feature.

### Sensors show incorrect CPU/GPU core count
CPU/GPU sensors are simply thermal zones (sensors) on the CPU/GPU. They have no relation to the number of cores or specific cores.
For example, a CPU is typically divided into two clusters: efficiency and performance. Each cluster contains multiple temperature sensors, and Stats simply displays these sensors. However, "CPU Efficient Core 1" does not represent the temperature of a single efficient core—it only indicates one of the temperature sensors within the efficiency core cluster.
Additionally, with each new SoC, Apple changes the sensor keys. As a result, it takes time to determine which SMC values correspond to the appropriate sensors. If anyone knows how to accurately match the sensors for Apple Silicon, please contact me.

### App crash – what to do?
First, ensure that you are using the latest version of Stats. There is a high chance that a fix preventing the crash has already been released. If you are already running the latest version, search both [open and closed issues](https://github.com/exelban/stats/issues?q=is%3Aissue). If the crash has already been reported, add new diagnostic information to the existing issue when comments are open instead of opening a duplicate. Otherwise, use the [bug report form](https://github.com/exelban/stats/issues/new?template=bug_report.yml) and include your Mac model, chip, macOS version and build, Stats version, steps to reproduce, and the complete crash report from Console.

### Why my issue was closed without any response?
Most probably because it's a duplicated issue and there is an answer to the question, report, or proposition. Please use a search by closed issues to get an answer.
So, if your issue was closed without any response, most probably it already has a response.

### External API
Stats does not collect any telemetry or analytics. The only external requests it makes are to the following APIs:

- https://api.mac-stats.com – For update checks and retrieving the public IP address
- https://api.github.com – Fallback for update checks

Both of these APIs are used to check for updates. Additionally, an external request is required to obtain the public IP address. I do not want to use any third-party providers for retrieving the public IP address, so I use my own server for this purpose.

If you have concerns about these requests, you have a few options:

- propose a PR that allows these features to work without an external server
- block both of these servers using any network filtering app (if you're reading this, you're likely using something like Little Snitch, so you can easily do this). In this case do not expect to receive any updates or see your public IP in the network module.

### How to contribute to the project?
If you want to develop a new feature, or you've found something that doesn't work, the first step is to open an issue so the feature or problem can be discussed. Pull requests should only be opened for existing issues and after discussion; otherwise, they may be closed automatically. There are a few cases where this can be skipped: language changes, and contributors who have already made significant contributions and whose implementations align well with the project.

## Open source, but not open contribution
Stats is an open-source project: the full source code is available under the MIT license, and you are free to read it, learn from it, fork it, and build your own version of the app.

However, it is not an open-contribution project. Stats is developed and maintained by a single person, and keeping the project stable and coherent takes priority over accepting every proposed change. Reviewing external code, testing it across different Macs and macOS versions, and maintaining it afterward often takes more time than writing it in the first place.

For that reason, unsolicited pull requests are generally not accepted and may be closed without review. If you want to change or add something, please open an issue first so it can be discussed. The exceptions are translations and language fixes, which are always welcome, and contributions from people who have already made significant contributions to the project.

The best ways to support the project are reporting bugs, improving translations, and proposing ideas through issues.

## Supported languages
- English
- Polski
- Українська
- Русский
- 中文 (简体) (thanks to [chenguokai](https://github.com/chenguokai), [Tai-Zhou](https://github.com/Tai-Zhou), and [Jerry](https://github.com/Jerry23011))
- Türkçe (thanks to [yusufozgul](https://github.com/yusufozgul) and [setanarut](https://github.com/setanarut))
- 한국어 (thanks to [escapeanaemia](https://github.com/escapeanaemia) and [iamhslee](https://github.com/iamhslee))
- German (thanks to [natterstefan](https://github.com/natterstefan) and [aneitel](https://github.com/aneitel))
- 中文 (繁體) (thanks to [iamch15542](https://github.com/iamch15542) and [jrthsr700tmax](https://github.com/jrthsr700tmax))
- Spanish (thanks to [jcconca](https://github.com/jcconca))
- Vietnamese (thanks to [HXD.VN](https://github.com/xuandung38))
- French (thanks to [RomainLt](https://github.com/RomainLt))
- Italian (thanks to [gmcinalli](https://github.com/gmcinalli))
- Portuguese (Brazil) (thanks to [marcelochaves95](https://github.com/marcelochaves95) and [pedroserigatto](https://github.com/pedroserigatto))
- Norwegian Bokmål (thanks to [rubjo](https://github.com/rubjo))
- 日本語 (thanks to [treastrain](https://github.com/treastrain))
- Portuguese (Portugal) (thanks to [AdamModus](https://github.com/AdamModus))
- Czech (thanks to [mpl75](https://github.com/mpl75))
- Magyar (thanks to [moriczr](https://github.com/moriczr))
- Bulgarian (thanks to [zbrox](https://github.com/zbrox))
- Romanian (thanks to [razluta](https://github.com/razluta))
- Dutch (thanks to [ngohungphuc](https://github.com/ngohungphuc))
- Hrvatski (thanks to [milotype](https://github.com/milotype))
- Danish (thanks to [casperes1996](https://github.com/casperes1996) and [aleksanderbl29](https://github.com/aleksanderbl29))
- Catalan (thanks to [davidalonso](https://github.com/davidalonso))
- Indonesian (thanks to [yooody](https://github.com/yooody))
- Hebrew (thanks to [BadSugar](https://github.com/BadSugar))
- Slovenian (thanks to [zigapovhe](https://github.com/zigapovhe))
- Greek (thanks to [sudoxcess](https://github.com/sudoxcess) and [vaionicle](https://github.com/vaionicle))
- Persian (thanks to [ShawnAlisson](https://github.com/ShawnAlisson))
- Slovenský (thanks to [martinbernat](https://github.com/martinbernat))
- Thai (thanks to [apiphoomchu](https://github.com/apiphoomchu))
- Estonian (thanks to [postylem](https://github.com/postylem))
- Hindi (thanks to [patiljignesh](https://github.com/patiljignesh))
- Finnish (thanks to [eightscrow](https://github.com/eightscrow))
- Bengali (thanks to [adnan29979](https://github.com/adnan29979))
- Tamil (thanks to [sabapathy7](https://github.com/sabapathy7))

You can help by adding a new language or improving the existing translation.

## License
[MIT License](https://github.com/exelban/stats/blob/master/LICENSE)
