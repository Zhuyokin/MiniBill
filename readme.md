# MiniBill · App Store 审核与 ASO 提交资料

> 本文是 iOS 17+、目标版本 1.0（Build 1）的候选商店文案，不代表当前并行开发中的 build 已具备所述功能。只有最终归档 build 逐项通过下方提交门禁后，才能把这些字段粘贴到 App Store Connect。所有长度均由文末脚本按 Unicode 代码点（字符）及 UTF-8 字节实测；App Store Connect 的关键词以 UTF-8 字节为准。

## 提交前阻塞门禁 / Pre-submission blockers

以下项目全部完成前，不得将本文标记为可提交，也不得把候选文案粘贴到 App Store Connect：

1. 使用拟提交的最终归档 build，在支持的 iPhone、iPad 和 iOS 17+ 环境逐项验收本文所述的记账、按项目名称聚合、统计、分享、通知、备份与恢复、多语言、无登录以及纯本地数据边界。
2. 部署 `app-privacy-support` 后，分别请求计划中的 Privacy Policy URL 和 Support URL；两者最终响应都必须是 HTTP 200。任何一个 URL 未部署、返回 4xx/5xx 或无法访问，均为提交阻塞项。
3. 从 App Store Connect 的卖方资料或权利人书面信息确认版权主体，把唯一允许的人工模板 `<confirmed rights holder>` 替换为已确认的名称。
4. 审计最终二进制以及所有链接的依赖和框架，再确认出口合规答案；当前文档中的 **Expected: No** 只基于目标 1.0 设计，不是对最终二进制的结论。

## 简体中文（China mainland storefront）

### 商店元数据

| 字段 | 目标 1.0 候选内容 | 实测长度 |
| --- | --- | --- |
| 应用名称（上限 30 字符） | `MiniBill` | 8 字符；8 UTF-8 字节 |
| 副标题（上限 30 字符） | `本地离线收支流水` | 8 字符；24 UTF-8 字节 |
| 关键词（上限 100 UTF-8 字节） | `离线记账,收支流水,摆摊,副业,零工,本地账本,项目统计,无注册,备份` | 35 字符；89 UTF-8 字节 |
| 推广文本（上限 170 字符） | `不设分类，不必注册。MiniBill 在设备本地记录收入和支出，按项目名称看本月收支与排行；可手动备份、恢复和分享。` | 58 字符；156 UTF-8 字节 |
| 描述（上限 4,000 字符） | 见下方“描述复制文本” | 463 字符；1,269 UTF-8 字节 |
| 1.0 版本更新说明 | `MiniBill 1.0 首次发布：本地离线记录收入和支出，按项目名称汇总本月收支；支持统计、图片分享、手动备份与恢复，以及可选的本地提醒。` | 70 字符；184 UTF-8 字节 |

关键词不包含应用名或竞品商标。

#### 描述复制文本

```text
MiniBill 是一款面向摆摊、零工、副业和小微经营者的本地离线收支流水工具。打开后即可记录一笔收入或支出：输入金额，选择或填写项目名称，保存即可。无需注册，也不依赖网络。

不设分类，不要求维护账户、客户或库存。你可以用“冰粉”“摊位费”“跑腿收入”等项目名称记录流水；MiniBill 会按项目名称汇总本月收入、支出、净收益和排行，让你知道哪些项目带来收入、哪些项目产生支出。

你还可以查看按日的流水和本月趋势，修改或删除错误记录；将本月收益或单笔流水生成图片，在确认预览后通过系统分享。分享图不会包含备注。

数据只保存在你的设备上。MiniBill 不提供账号、云端同步、广告或分析功能。你可随时导出单个 .minibill 备份文件；恢复前会先校验并显示预览，确认后以备份完整替换本机流水。请将备份保存到可信位置。

可选的每日记账提醒和月末结账提醒由 iOS 在本地排程；首次开启提醒时才会请求通知权限。MiniBill 支持简体中文、繁体中文、英语、日语和韩语，并按设备地区显示日期、时间、数字和人民币金额。
```

### 截图文案

| 顺序 / 画面 | 截图标题 | 截图副文案 | 标题实测 | 副文案实测 |
| --- | --- | --- | --- | --- |
| 1. 本月汇总与日期流水 | `今天的收支，一眼看清` | `本月收入、支出和净收益，打开就能看见` | 10 字符；30 UTF-8 字节 | 18 字符；54 UTF-8 字节 |
| 2. 快速记一笔 | `收入或支出，随手记录` | `金额和项目名称是两项核心信息` | 10 字符；30 UTF-8 字节 | 14 字符；42 UTF-8 字节 |
| 3. 项目名称候选 | `不用分类，也能理清项目` | `从已有流水给出最近使用的项目名称` | 11 字符；33 UTF-8 字节 | 16 字符；48 UTF-8 字节 |
| 4. 本月统计 | `按项目名称查看本月收支` | `收入、支出、净收益与每日趋势` | 11 字符；33 UTF-8 字节 | 14 字符；42 UTF-8 字节 |
| 5. 本地提醒 | `需要时，再开启本地提醒` | `每日记账和月末结账提醒由 iOS 本地排程` | 11 字符；33 UTF-8 字节 | 21 字符；53 UTF-8 字节 |
| 6. 备份与恢复 | `账本由你保管` | `手动导出备份，恢复前先查看预览` | 6 字符；18 UTF-8 字节 | 15 字符；45 UTF-8 字节 |
| 7. 分享预览 | `确认后再分享` | `月度收益或单笔流水图不包含备注` | 6 字符；18 UTF-8 字节 | 15 字符；45 UTF-8 字节 |

### 审核备注（简体中文）

MiniBill 是纯本地账本：不需要登录、注册、演示账号或联网。所有流水只存储在设备本地；没有账号、服务端、iCloud 同步、广告、分析或追踪。应用没有分类功能；统计按用户录入的项目名称聚合。

审核路径：

1. 首次打开即进入“账单”。点右下角“+”，输入金额和项目名称，保存一笔收入或支出。
2. 点首页“本月汇总”进入“统计”，可查看净收益、收入、支出、每日趋势以及按项目名称的收入/支出排行；在统计页点“分享”可预览月度收益图，再打开系统分享面板。
3. 点任一流水进入详情，可编辑、删除或分享单笔流水。分享图不含备注。
4. 在“我的”中开启“每日记账提醒”或“月末结账提醒”。此时才会请求通知权限；通知由 iOS 在本地排程。每日提醒进入快速记账，月末提醒进入当月统计。
5. 在“我的”选择“导出备份”以创建 `.minibill` 文件；随后选择“从备份恢复”，选取刚导出的文件，先查看校验预览，再确认“替换并恢复”。恢复会完整替换本机流水，不会合并；取消、校验失败或恢复失败均不会改动原账本。

**审核备注实测（仅上述备注文本）：458 字符；1,256 UTF-8 字节。**

## English (U.S. storefront)

### Store metadata

| Field | Target 1.0 candidate value | Measured length |
| --- | --- | --- |
| App name (30-character limit) | `MiniBill` | 8 characters; 8 UTF-8 bytes |
| Subtitle (30-character limit) | `Offline income & expenses` | 25 characters; 25 UTF-8 bytes |
| Keywords (100 UTF-8-byte limit) | `offline ledger,income,expenses,side hustle,small business,local backup,project totals,no sign-in` | 96 characters; 96 UTF-8 bytes |
| Promotional text (170-character limit) | `No categories or sign-in. Record income and expenses on your device, see monthly totals by project name, and manually back up, restore, or share.` | 145 characters; 145 UTF-8 bytes |
| Description (4,000-character limit) | See “Description copy” below | 1,293 characters; 1,307 UTF-8 bytes |
| What’s New, version 1.0 | `Welcome to MiniBill 1.0. Record income and expenses offline, review monthly totals by project name, share images, back up and restore manually, and opt in to local reminders.` | 174 characters; 174 UTF-8 bytes |

#### Description copy

```text
MiniBill is a local, offline income-and-expense ledger for market sellers, freelancers, side hustles, and small businesses. Record an income or expense with an amount and a project name—no sign-in and no network connection required.

There are no categories to maintain. Use project names such as “Market stall fee,” “Delivery income,” or “Materials,” then view monthly income, expenses, net income, and rankings grouped by project name. See daily entries and a monthly trend, or correct and delete an entry when needed.

Create a monthly-summary image or a single-entry image on your device, preview it, and then use the system share sheet. Shared images never include notes.

Your ledger stays on your device. MiniBill has no accounts, cloud sync, ads, or analytics. Export a single .minibill backup file whenever you choose. Before restoring, MiniBill validates the file and shows a preview; after confirmation, the backup replaces the local ledger. Save backup files in a trusted location.

Optional daily and month-end reminders are scheduled locally by iOS and request notification permission only when you turn one on. MiniBill supports Simplified Chinese, Traditional Chinese, English, Japanese, and Korean, with dates, times, numbers, and CNY amounts formatted for your device region.
```

### Screenshot copy

| Order / screen | Headline | Supporting copy | Headline measured | Supporting copy measured |
| --- | --- | --- | --- | --- |
| 1. Monthly summary and dated entries | `See today’s money at a glance` | `Monthly income, expenses, and net income on the first screen` | 29 characters; 31 UTF-8 bytes | 60 characters; 60 UTF-8 bytes |
| 2. Quick entry | `Record income or an expense` | `Amount and project name are the only core fields` | 27 characters; 27 UTF-8 bytes | 48 characters; 48 UTF-8 bytes |
| 3. Project-name suggestions | `No categories to maintain` | `Recent project names come from your own entries` | 25 characters; 25 UTF-8 bytes | 47 characters; 47 UTF-8 bytes |
| 4. Monthly statistics | `Understand this month by project` | `Totals, rankings, and a daily net-income trend` | 32 characters; 32 UTF-8 bytes | 46 characters; 46 UTF-8 bytes |
| 5. Local reminders | `Turn on reminders only when useful` | `Daily and month-end reminders are scheduled locally by iOS` | 34 characters; 34 UTF-8 bytes | 58 characters; 58 UTF-8 bytes |
| 6. Backup and restore | `Your ledger stays with you` | `Export manually and preview a backup before restoring` | 26 characters; 26 UTF-8 bytes | 53 characters; 53 UTF-8 bytes |
| 7. Share preview | `Preview before you share` | `Monthly and entry images never include notes` | 24 characters; 24 UTF-8 bytes | 44 characters; 44 UTF-8 bytes |

### Review notes (English)

MiniBill is a fully local ledger. It requires no sign-in, registration, demo account, or network connection. Entries remain on the device. The app has no accounts, server, iCloud sync, ads, analytics, or tracking. It has no category feature: statistics aggregate entries by the project name entered by the user.

Review path:

1. The first launch opens **Bills**. Tap **+**, enter an amount and project name, then save an income or expense.
2. Tap the monthly summary on **Bills** to open **Statistics**. Review net income, income, expenses, the daily trend, and income/expense rankings by project name. Tap **Share** to preview a monthly-summary image, then open the system share sheet.
3. Open any entry for editing, deletion, or a single-entry share image. Shared images do not include notes.
4. In **Me**, turn on **Daily bookkeeping reminder** or **Month-end closing reminder**. Notification permission is requested only at that point. iOS schedules these notifications locally; a daily reminder opens quick entry and a month-end reminder opens the current month’s statistics.
5. In **Me**, use **Export backup** to create a `.minibill` file. Then use **Restore from backup**, select that exported file, review its validation preview, and confirm **Replace and restore**. Restore replaces the entire local ledger; it does not merge data. Cancelling, failed validation, or a failed restore leaves the existing ledger unchanged.

**Measured length (review-notes text above only): 1,431 characters; 1,433 UTF-8 bytes.**

## Shared App Store Connect submission guidance

| Item | Submit / answer |
| --- | --- |
| Primary category | Finance |
| Secondary category | Productivity (optional; omit if a secondary category is not desired) |
| Age rating | 4+. In the age-rating questionnaire, answer **No / None** for violence, sexual content, profanity, horror, medical-treatment content, gambling/contests, unrestricted web access, and publicly shared user-generated content. The app is a personal local ledger, not an investing, lending, gambling, or social service. |
| Copyright | `2026 <confirmed rights holder>` — mandatory human field. Confirm the legal rights holder from App Store Connect seller information or written ownership records, then replace the bracketed template before submission; do not infer it from the bundle identifier. |
| Bundle ID | `com.masdey.minibill` |
| Version / build | 1.0 / 1 |
| Privacy Policy URL | Planned URL: <https://app-privacy-support.pages.dev/MiniBill/privacy/>. **Submission blocker:** after deploying `app-privacy-support`, verify the final response is HTTP 200 before entering this URL in App Store Connect. |
| Support URL | Planned URL: <https://app-privacy-support.pages.dev/MiniBill/support/>. **Submission blocker:** after deploying `app-privacy-support`, verify the final response is HTTP 200 before entering this URL in App Store Connect. |
| Marketing URL | Leave blank; no separate marketing site has been supplied. |
| Sign-in / demo account | Not required. No account or sign-in functionality exists. |
| Encryption export compliance | **Expected: No, based on the target 1.0 design only.** The design specifies no proprietary or non-exempt encryption, no ledger-data network transmission, and an unencrypted local backup file. Before submission, audit the final binary plus every linked dependency and framework; confirm or revise the App Store Connect answer from that evidence. |
| App Privacy: data collection | **Data Not Collected.** Ledger entries, amounts, project names, notes, and backup files stay on the device and are not transmitted to the developer or third parties. |
| App Privacy: tracking | **No tracking.** No advertising, analytics, tracking SDKs, or account identifiers. |
| App Privacy: permissions | Notifications are optional and requested only after the user enables a daily or month-end local reminder. The app does not require contacts, location, camera, microphone, photos, or network access for its core features. |
| Backup disclosure | Export is user initiated and produces one `.minibill` file. The app does not provide cloud sync. Restore validates and previews the chosen file, then replaces—not merges—the local ledger after confirmation. |
| Sharing disclosure | Images are rendered locally. The user previews them before the iOS system share sheet opens. Notes are excluded from both monthly and single-entry share images. |

### Validation method

The following command was run against the literal values in this document. It counts Unicode code points with `len()` and UTF-8 bytes with `len(value.encode("utf-8"))`, prints every backticked metadata and screenshot field, and separately prints both descriptions and review notes.

```sh
python3 - <<'PY'
from pathlib import Path
import re

document = Path("readme.md").read_text()

def measure(label, value):
    print(f"{label}: {len(value)} chars; {len(value.encode('utf-8'))} UTF-8 bytes")

# All quoted title, subtitle, keyword, promotional, release-note, and screenshot fields.
for line_no, line in enumerate(document.splitlines(), 1):
    if line.startswith("|"):
        for value in re.findall(r"`([^`]*)`", line):
            measure(f"table line {line_no}", value)

def fenced_copy(heading):
    start = document.index(heading)
    start = document.index("```text\n", start) + len("```text\n")
    end = document.index("\n```", start)
    return document[start:end]

def review_notes(heading, marker):
    start = document.index(heading) + len(heading) + 2
    end = document.index(marker, start)
    return document[start:end].rstrip("\n")

measure("Chinese description", fenced_copy("#### 描述复制文本"))
measure("English description", fenced_copy("#### Description copy"))
measure("Chinese review notes", review_notes("### 审核备注（简体中文）", "**审核备注实测"))
measure("English review notes", review_notes("### Review notes (English)", "**Measured length"))

# App Store Connect limits stated in the implementation plan.
limits = {
    "Chinese subtitle": ("本地离线收支流水", 30, "chars"),
    "Chinese keywords": ("离线记账,收支流水,摆摊,副业,零工,本地账本,项目统计,无注册,备份", 100, "bytes"),
    "Chinese promotional text": ("不设分类，不必注册。MiniBill 在设备本地记录收入和支出，按项目名称看本月收支与排行；可手动备份、恢复和分享。", 170, "chars"),
    "English subtitle": ("Offline income & expenses", 30, "chars"),
    "English keywords": ("offline ledger,income,expenses,side hustle,small business,local backup,project totals,no sign-in", 100, "bytes"),
    "English promotional text": ("No categories or sign-in. Record income and expenses on your device, see monthly totals by project name, and manually back up, restore, or share.", 170, "chars"),
}
for label, (value, limit, unit) in limits.items():
    size = len(value) if unit == "chars" else len(value.encode("utf-8"))
    assert size <= limit, f"{label}: {size} > {limit} {unit}"

for label, value in {"Chinese app name": "MiniBill", "English app name": "MiniBill"}.items():
    assert len(value) <= 30, f"{label}: {len(value)} > 30 chars"
for label, value in {
    "Chinese description": fenced_copy("#### 描述复制文本"),
    "English description": fenced_copy("#### Description copy"),
}.items():
    assert len(value) <= 4000, f"{label}: {len(value)} > 4000 chars"
PY
```
