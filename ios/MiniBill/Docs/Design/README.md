# MiniBill 设计交付包

状态：MVP 设计已确认，尚未进入业务功能开发。

## 交付内容

- `2026-08-05-minibill-product-ux-design.md`：产品定位、高频功能、信息架构、页面和交互规范。
- `MiniBill-Prototype-Spec.md`：关键任务流程、页面状态与跳转关系。
- `MiniBill-Visual-System.md`：微信式极简视觉语言、组件规则、分享图和图标规范。
- `MiniBill-Offline-Engineering-Spec.md`：iOS 17+ 本地存储、通知、备份、多语言和测试边界。
- `App-Icon-Generation-Notes.md`：最终图标方向、生成方式与提示词。
- `assets/app-icon-recommended-1024.png`：推荐 App Icon 概念稿。
- `assets/minibill-ui-design-board.png`：六个关键页面的设计画板。
- `prototype/minibill-ui-prototype.html`：可交互 UI 原型。
- `prototype/minibill-design-board.html`：可缩放的静态设计画板源文件。

## 已锁定决策

- 品牌、工程、Target、Scheme 和模块统一使用 `MiniBill`。
- 最低系统版本为 iOS 17.0；技术栈为 SwiftUI、SwiftData。
- 纯本机、无注册、无云端依赖；允许用户手动导出与恢复备份。
- 双页签：`账单`、`我的`；统计通过首页汇总卡进入。
- 不做正式分类，也不做分类 CRUD。
- 以流水中的“项目名称”生成历史候选，并按项目名称聚合统计。
- 每日提醒和月末提醒均为预先排程的本地通知。
- 首发支持简中、繁中、英语、日语和韩语。
- 分享图在设备本地生成，支持月度收益和单笔流水。

## 本阶段明确不做

- 客户、供应商、库存、应收应付。
- 多账本、多币种与汇率换算。
- 登录、服务端、iCloud 同步和多人协作。
- 分类、标签、预算、发票识别和 OCR。
- 自动条件提醒，例如“当天没记账才提醒”。

## 下一步

请先审核本目录文档与设计稿。确认后再生成实现计划；本设计包不代表已开始开发业务页面。
