# Stats v3.0.21-combined.5

本版本基于上游 Stats 3.0.21，汇总 combined.4、combined.5 的性能/能耗优化，以及 Combined 电池模块 A1 视觉与容量口径修正。

## 性能与能耗

- 按真实消费者分发 Reader 数据：独立菜单栏、独立弹窗、设置页、Combined 弹窗和 Combined 菜单栏互不误触发。
- 隐藏的 Popup、Portal 和 Preview 不再持续维护高频图表及数据历史。
- Network 拆分快速与详细路径：纯 Combined 网速仅读取接口累计字节，不运行 `ps`、`top`、`nettop`、CoreWLAN、定位和公网 IP 查询。
- 即使 Network Reader 偏好为进程模式，纯 Combined 网速仍强制使用接口字节计数；独立 Network 模块保持原设置行为。
- 网速按单调时钟真实时间差换算，动态改变采样间隔时仍保持速率准确。
- 新增实时、平衡、省电三档能耗模式：空闲网速可从 3 秒降至 10 秒或 30 秒；平衡模式跟随 macOS 低电量模式。
- 同频 Reader 共用 Timer bucket，并使用 utility QoS 与动态 leeway。
- Reader 增加不可重入保护，避免外部采样进程尚未结束便再次触发。
- 进程榜在平衡/省电模式下降低刷新频率，固定弹窗失焦时进一步降频；重新打开时立即刷新。
- 非历史 Reader 的数据库写入先执行 30 秒节流判断，再进行 JSON 编码。

## Combined 电池模块

- 采用 A1 图标：电池内部显示当前电量百分比。
- 右上角状态角标区分充电、已接电未充电、优化充电暂停、已充满和低电量。
- 移除重复的“充电中”文字；文字区仅展示充满还需、循环次数、最大容量比例及 mAh。
- 修正 Apple Silicon 最大容量读取优先级，优先采用 `AppleRawMaxCapacity` / `FullChargeCapacity`，与 macOS 最大容量口径保持一致。
- 独立 Battery 详情页维持原有外观，A1 样式仅应用于 Combined Portal。

## 验证

- arm64 Debug 构建通过。
- Universal Release（arm64 + x86_64）构建通过。
- 排除发布基线已存在的 `testIsNewestVersion_beta` 两个断言后，其余 16 项回归测试通过。
- Combined 电池六种状态完成离屏视觉验证，角标未裁切，百分比跨填充区域仍可读。
- 发布产物使用 ad-hoc 签名；不是 Apple 公证版本，首次运行时可能需要在“系统设置 → 隐私与安全性”中允许。
