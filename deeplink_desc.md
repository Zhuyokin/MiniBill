# MiniBill Deep Link Design

## 背景

MiniBill 已在 iOS entitlement 中配置 Universal Links 域名：

- `applinks:app-privacy-support.pages.dev`

站点的 AASA 文件已包含 MiniBill 的 App ID 与路径范围：

- App ID: `96DQ7VQS3P.com.masdey.minibill`
- Path: `/MiniBill/*`

当前需要补齐 App 内深层链接解析逻辑，让活动链接可以打开 App 并跳转到合适页面。

## 目标

先支持两类活动链接格式，并统一跳转到统计 tab：

- `/MiniBill/activity1`
- `/MiniBill/activity100`
- `/MiniBill/activity_xxx`
- `/MiniBill/activity_20270101`

后续上线新活动时，可以继续扩展 `activity_` 后缀对应的页面，不需要改动 AASA 路径范围。

## URL 规则

MiniBill 只处理 host 为 `app-privacy-support.pages.dev` 且路径位于 `/MiniBill/` 下的活动链接。

### 兼容数字活动格式

格式：

```text
/MiniBill/activity<digits>
```

示例：

```text
/MiniBill/activity1
/MiniBill/activity100
/MiniBill/activity20270101
```

匹配规则：

- 最后一段 path 必须以 `activity` 开头。
- `activity` 后面必须是至少 1 位数字。
- 当前统一跳转到统计 tab。

不匹配示例：

```text
/MiniBill/activity
/MiniBill/activityabc
/MiniBill/activity1abc
```

### 未来活动前缀格式

格式：

```text
/MiniBill/activity_<payload>
```

示例：

```text
/MiniBill/activity_xxx
/MiniBill/activity_20270101
/MiniBill/activity_campaign_20270101
```

匹配规则：

- 最后一段 path 必须以 `activity_` 开头。
- `activity_` 后面必须有内容。
- 当前不解析 payload，统一跳转到统计 tab。
- 后续可以按 payload 增加页面分流，例如统计、首页、设置页、活动详情页等。

不匹配示例：

```text
/MiniBill/activity_
```

## 跳转行为

当前版本的活动链接统一映射到统计 tab：

```text
Universal Link -> DeepLinkRoute.activity -> NotificationRouter.Route.statistics -> AppRootView selectedTab = .statistics
```

进入统计 tab 时，默认使用当前月份：

```swift
selectedStatisticsMonth = Date()
selectedTab = .statistics
```

## 非活动路径

这些页面路径不由 App 内深链逻辑处理：

```text
/MiniBill/privacy/
/MiniBill/support/
```

它们继续作为网页路径存在，用于 App Store 隐私政策、支持链接和浏览器 fallback。

## 实现边界

本次只补 App 内路由识别与跳转，不新增具体活动页。

建议新增一个独立解析器，例如：

```swift
enum DeepLinkRoute {
    case activity

    static func parse(_ url: URL) -> DeepLinkRoute?
}
```

`AppRootView` 使用 `.onOpenURL` 接入 Universal Link：

```swift
.onOpenURL { url in
    guard let route = DeepLinkRoute.parse(url) else { return }
    switch route {
    case .activity:
        selectedStatisticsMonth = Date()
        selectedTab = .statistics
    }
}
```

如果后续活动 payload 需要分流，可以把 route 扩展为：

```swift
enum DeepLinkRoute {
    case activity(payload: String?)
    case statistics
    case home
    case settings
}
```

## 测试覆盖

建议增加单元测试覆盖：

- `/MiniBill/activity1` 命中 activity。
- `/MiniBill/activity100` 命中 activity。
- `/MiniBill/activity_xxx` 命中 activity。
- `/MiniBill/activity_20270101` 命中 activity。
- `/MiniBill/activity` 不命中。
- `/MiniBill/activityabc` 不命中。
- `/MiniBill/activity_` 不命中。
- `/MiniBill/privacy/` 不命中。
- `/MiniBill/support/` 不命中。
- 其他 host 不命中。

## 部署检查

代码实现后需要确认：

- Xcode target 继续引用 `MiniBill/MiniBill.entitlements`。
- AASA 文件仍返回 HTTP 200。
- AASA 中保留 `96DQ7VQS3P.com.masdey.minibill` 与 `/MiniBill/*`。
- App 安装到真机后，点击活动 Universal Link 可以打开 App 并切到统计 tab。
