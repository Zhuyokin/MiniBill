# MiniBill 离线工程设计约束

日期：2026-08-05  
最低版本：iOS 17.0  
技术栈：SwiftUI、SwiftData、UserNotifications、UniformTypeIdentifiers

本文定义后续实现必须遵守的边界，不包含具体任务拆分。

## 1. 工程命名

```text
ios/
└── MiniBill/
    ├── MiniBill.xcodeproj
    ├── MiniBill/
    └── Docs/Design/
```

- Project / Target / Scheme / Swift module / 产品名：`MiniBill`。
- Bundle ID：`com.masdey.minibill`。
- 备份文件采用 `MiniBill-YYYYMMDD-HHmm.minibill`。
- 目录、Target 和模块名不使用中文或连字符。

## 2. 组件边界

| 组件 | 职责 | 依赖 |
|---|---|---|
| LedgerStore | SwiftData 流水读写与查询 | SwiftData |
| EntryService | 金额、项目名称和日期领域校验 | LedgerStore |
| ProjectSuggestionService | 从流水推导历史项目候选 | LedgerStore |
| StatisticsService | 按月、日期和项目名称聚合 | LedgerStore |
| ShareImageService | 构建并渲染分享卡 | SwiftUI ImageRenderer |
| ReminderService | 权限状态、本地通知排程与校准 | UserNotifications |
| BackupService | DTO 编解码、文件校验、替换恢复 | LedgerStore / FileDocument |
| DeepLinkRouter | 处理本地通知进入记账或统计 | App 生命周期 |
| Localization | 五语文案与地区格式 | String Catalog / Foundation |

这些服务只通过明确输入输出通信。通知、分享和备份不直接访问 SwiftData 内部 store 文件。

## 3. 数据模型

唯一业务实体为 `LedgerEntry`：

| 字段 | 类型 | 规则 |
|---|---|---|
| id | UUID | 稳定、不复用 |
| kindRaw | String | `income` 或 `expense` |
| amountMinor | Int64 | CNY 分，必须大于 0 且单笔不超过 9,999,999,999 分（¥99,999,999.99） |
| itemName | String | 必填，保存用户原始展示值 |
| note | String? | 可空，MVP 限长 200 字符 |
| occurredAt | Date | 业务发生时间 |
| createdAt | Date | 创建时间 |
| updatedAt | Date | 最后修改时间 |

金额使用最小货币单位整数，避免浮点累计误差。MVP 账本币种固定为 CNY，不提供换汇。

不存在 `Category`、`Project`、`Account` 或统计缓存持久化实体。

## 4. 项目名称与聚合

候选和统计使用同一规范化键：

1. 去除首尾空格。
2. 连续空白合并为单个空格。
3. 拉丁字母比较使用 locale-independent case folding。
4. 不做拼音、同义词或模糊合并。

展示名称选择该规范化键最近一条流水的原始输入。候选排序：最近使用时间降序；最多显示 6 个，完整列表按需滚动。

候选计算失败不能阻塞保存；统计缓存仅存在内存，可随时从流水重建。

## 5. 本地通知

Apple 说明，本地通知由系统根据 App 提交的内容和触发条件处理；当 App 不在运行或处于后台时，系统负责与用户交互：[Scheduling a notification locally](https://developer.apple.com/documentation/usernotifications/scheduling-a-notification-locally-from-your-app)。

### 每日提醒

- 一个重复 `UNCalendarNotificationTrigger`。
- `DateComponents` 只包含本地小时与分钟。
- 标识符：`minibill.reminder.daily`。

`UNCalendarNotificationTrigger` 支持以小时和分钟创建重复日历触发器：[UNCalendarNotificationTrigger](https://developer.apple.com/documentation/usernotifications/uncalendarnotificationtrigger)。

### 月末提醒

“每月最后一天”不能用固定 day 的单个重复规则准确表示，因此：

- 按公历和设备当前时区计算未来 12 个月最后一天。
- 创建 12 个不重复日历通知。
- 标识符：`minibill.reminder.monthEnd.YYYY-MM`。
- App 启动、进入前台、时间设置变化或时区变化时幂等校准。

若用户超过 12 个月从未再次打开 App，月末提醒在预排范围结束后停止；每日重复提醒继续。产品不得承诺绕过专注模式、通知摘要、静音或系统权限。

### 权限

只在用户开启提醒时请求授权。Apple 建议在用户能理解通知用途的上下文中请求，并在排程前检查当前授权状态：[Asking permission to use notifications](https://developer.apple.com/documentation/usernotifications/asking-permission-to-use-notifications)。

不启用后台模式、不接入 APNs、不使用服务器。

## 6. 分享图

参考现有 `pboc-data` 工程的结构：固定尺寸 SwiftUI View → `ImageRenderer` → `UIImage` → `ShareLink`。

Apple 的 `ImageRenderer` 可将 SwiftUI 视图导出为位图：[ImageRenderer](https://developer.apple.com/documentation/swiftui/imagerenderer)。实现要求：

- 月度卡 `.frame(width: 900, height: 1200)`，`scale = 2`。
- 分享图固定浅色主题，不跟随当前深色模式。
- 渲染前生成不可变 DTO，避免 View 渲染期间读取变化中的 ModelContext。
- 备注永不进入分享 DTO。
- 渲染失败返回可恢复错误，不打开空白分享面板。

## 7. 备份文件

通过自定义 UTType 与 `.minibill` 扩展名，使用 `FileDocument`、`fileExporter` 和 `fileImporter`。`FileDocument` 用于把值类型序列化为单文件：[FileDocument](https://developer.apple.com/documentation/swiftui/filedocument)；SwiftUI 提供系统文件导入与导出面板：[View presentation modifiers](https://developer.apple.com/documentation/swiftui/view-presentation)。

备份是业务 DTO，不复制 SwiftData 的 SQLite、WAL 或内部 store。

示例：

```json
{
  "format": "com.minibill.backup",
  "schemaVersion": 1,
  "exportedAt": "2026-08-05T12:00:00Z",
  "appVersion": "1.0.0",
  "currencyCode": "CNY",
  "recordCount": 1,
  "records": [
    {
      "id": "31F00AC2-8C09-4B28-8E81-D8838B334B14",
      "kind": "expense",
      "amount": "12.50",
      "itemName": "矿泉水",
      "note": null,
      "occurredAt": "2026-08-05T03:30:00Z",
      "createdAt": "2026-08-05T03:31:00Z",
      "updatedAt": "2026-08-05T03:31:00Z"
    }
  ]
}
```

规则：

- JSON 金额使用十进制定点字符串，不使用浮点数。
- 日期使用 ISO 8601 UTC 毫秒精度，显示时转换为设备时区；账单 UI 以分钟为用户输入精度。
- 项目名称、备注和 UUID 无损保存。
- 项目候选、统计缓存、语言、通知权限和排程不进入备份。
- 备份未额外加密，导出页明确提示保存到可信位置。

## 8. 恢复事务

写入前完整校验：文件标识、schema 版本、记录数、UUID 唯一性、金额、类型、项目名称和日期。新于当前 App 的 schema 必须拒绝，并提示升级 App。

MVP 只支持整库替换：

1. 保存当前未提交变化。
2. 在独立 ModelContext 中解析 DTO。
3. 事务内删除旧流水并插入备份流水。
4. 保存并重新核对数量。
5. 失败则 rollback，原账本保持不变。
6. 成功后清空内存统计，重新推导项目候选。

SwiftData 的 `ModelContext` 提供事务和 `rollback()` 能力：[ModelContext](https://developer.apple.com/documentation/swiftdata/modelcontext)。不得接受部分恢复。

## 9. 多语言

使用 `Localizable.xcstrings` 管理全部界面、通知、分享和错误文案。Apple 的 String Catalog 支持集中管理语言、复数和设备变体：[Localizing with a string catalog](https://developer.apple.com/documentation/xcode/localizing-and-varying-text-with-a-string-catalog)。

支持：

- `zh-Hans`
- `zh-Hant`
- `en`
- `ja`
- `ko`

默认跟随系统语言；用户可使用 iOS 的系统级 App 语言设置。App 内不维护第二套语言偏好。

项目名称永不翻译。日期、时间、数字和货币使用 Foundation `FormatStyle` 与当前 locale。备份键、枚举值、文件名格式和扩展名不本地化。

## 10. 隐私与日志

- 不接入分析、广告或崩溃上传 SDK。
- 不申请网络权限作为核心功能前提。
- 本地错误日志不得记录金额、项目名称、备注或完整备份内容。
- 分享预览清楚显示将要分享的数据。
- 卸载 App 会删除本机账本与已排程通知；隐私说明必须明确。

## 11. 测试与验收

### 数据

- 金额加总无浮点误差。
- 中、英、日、韩和 emoji 项目名称可保存、统计、导出和恢复。
- 修改项目名称后统计即时更新。
- 删除最后一笔项目后候选自然消失。

### 通知

- 首次启动不弹权限。
- 开启后恰有 1 个每日重复请求和未来 12 个月月末请求。
- 月末生成覆盖 28、29、30、31 日与闰年。
- 多次校准不生成重复请求。
- 真机将提醒设为数分钟后并强制结束 App，系统仍显示通知。
- 点击每日提醒进入快速记账；点击月末提醒进入当月统计。

### 备份

- N 条流水导出再恢复后仍为 N 条，UUID 和金额不变。
- 损坏 JSON、重复 UUID、非法金额、未知类型和新 schema 在写入前被拒绝。
- 注入保存失败后事务回滚，原流水逐条不变。
- 取消导入或导出不显示错误。
- 空备份需要强化确认。

### 本地化与可访问性

- 五种语言完成度 100%，不存在直接显示 key。
- 小屏与最大动态字体下关键操作不截断。
- VoiceOver 能读出类型、项目、金额、日期和按钮用途。
- 切换系统级 App 语言后，界面与下一次校准的通知使用新语言。
- 任意语言导出的备份可在另一语言环境恢复。

### 分享

- 月度和单笔图在所有语言下无文本溢出。
- 输出尺寸、固定浅色背景和品牌元素符合规范。
- 分享 DTO 不包含备注。
