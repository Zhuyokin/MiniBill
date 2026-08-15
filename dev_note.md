2026-08-14

v1.0.1 提交：

更新内容：

- 合并 `minibill-tabs-settings-1.0.1` 分支，纳入 1.0.1 导航与设置页更新：账单首页命名为 Home，统计能力独立为 Statistics tab，设置页保留备份、提醒、语言、关于与支持入口。
- 合并 `feature/associated-domains` 分支，为 MiniBill target 启用 Associated Domains，配置 `applinks:app-privacy-support.pages.dev`，用于支持 Universal Links。
- 更新 About MiniBill 内容，把隐私说明与应用介绍合并到关于页，补充小微经营、本地离线、备份恢复、提醒和分享等说明。
- 新增 `deeplink_desc.md`，记录 MiniBill 活动深链设计：兼容 `/MiniBill/activity<数字>` 和 `/MiniBill/activity_<payload>` 两类格式，当前统一跳转到统计 tab，后续按活动 payload 扩展其他页面。
- 保持 App Store 隐私政策与支持页路径作为网页 fallback，不由 App 内活动深链逻辑拦截。

验证记录：

- `swift test --package-path ios/MiniBill`：40 个 XCTest 通过，0 failures。
- `xcodebuild -project MiniBill.xcodeproj -scheme MiniBill -configuration Debug -destination 'generic/platform=iOS Simulator' build`：Debug 构建通过。
- Xcode 构建日志确认模拟器 entitlements 包含 `applinks:app-privacy-support.pages.dev`。

v1.0.3 开发中
预计9月再更新
1. apple connect 多语言配置，增加一个新活动，多账户
2. 统计页增加按月、按年、按类型的图表展示
3. 支持多账户切换记账，各账户独立,记得导入导出数据做兼容处理，不要产生不兼容数据的bug
4. 单笔账单分享的按钮点不了，点击编辑的时候弹窗那个分享bug为什么点击不了。