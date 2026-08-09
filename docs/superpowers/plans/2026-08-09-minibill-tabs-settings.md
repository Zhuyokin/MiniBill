# MiniBill Tabs and Settings Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship MiniBill 1.0.1 navigation and settings updates with a dedicated Statistics tab and consolidated About/privacy content.

**Architecture:** Keep the existing SwiftUI app structure and Form-based settings. Root tab state owns the selected statistics month and passes it to Statistics through a binding, so Bills and notification routes can switch to the Statistics tab without duplicating analytics screens or losing month updates. Settings actions mirror the existing LightKitList behavior using UIKit URL opening and pasteboard fallback.

**Tech Stack:** SwiftUI, SwiftData `@Query`, UIKit `UIApplication` and `UIPasteboard`, Xcode string catalogs, Xcode project build settings.

## Global Constraints

- App marketing version must be `1.0.1`.
- Root tabs must be Bills, Statistics, and Me.
- Statistics summary card must not show a non-clickable grey chevron.
- Privacy content must live inside About MiniBill; the standalone Privacy settings row must be removed.
- Settings must expose More Apps, Contact Email, Rate App, and visible version information.
- Rate App temporarily uses LightKitList app id `6761642667`.
- Support email is `yokinzhu@gmail.com`.
- New visible strings must be localized in English, Simplified Chinese, Traditional Chinese, Japanese, and Korean.

---

### Task 1: Version and Summary Card Affordance

**Files:**
- Modify: `ios/MiniBill/MiniBill.xcodeproj/project.pbxproj`
- Modify: `ios/MiniBill/MiniBill/Features/Bills/MonthlySummaryCard.swift`
- Modify: `ios/MiniBill/MiniBill/Features/Statistics/StatisticsView.swift`

**Interfaces:**
- Produces: `MonthlySummaryCard.init(summary:showsChevron:)`, where `showsChevron` defaults to `false`.
- Consumes: Existing `MonthlySummaryCard(summary:)` call sites.

- [ ] **Step 1: Update the marketing version**

Change both Debug and Release target build settings:

```pbxproj
MARKETING_VERSION = 1.0.1;
```

- [ ] **Step 2: Add an explicit chevron parameter**

Edit `MonthlySummaryCard`:

```swift
struct MonthlySummaryCard: View {
    let summary: MonthlySummary
    let showsChevron: Bool

    init(summary: MonthlySummary, showsChevron: Bool = false) {
        self.summary = summary
        self.showsChevron = showsChevron
    }
```

Then wrap the chevron:

```swift
if showsChevron {
    Image(systemName: "chevron.forward")
        .foregroundStyle(AppTheme.muted)
}
```

- [ ] **Step 3: Keep Statistics non-clickable visually**

Ensure `StatisticsView` continues to call:

```swift
MonthlySummaryCard(summary: summary)
```

Because `showsChevron` defaults to `false`, this removes the grey chevron in Statistics.

- [ ] **Step 4: Verify package tests still compile**

Run:

```bash
swift test
```

Expected: all `MiniBillCoreTests` pass.

### Task 2: Dedicated Statistics Tab

**Files:**
- Modify: `ios/MiniBill/MiniBill/App/AppRootView.swift`
- Modify: `ios/MiniBill/MiniBill/Features/Bills/BillsView.swift`

**Interfaces:**
- Produces: `RootTab.statistics`.
- Produces: `StatisticsView.init(selectedMonth: Binding<Date>)`.
- Produces: `BillsView(onOpenStatistics:)` switches the selected tab and selected statistics month.
- Consumes: Existing `NotificationRoute.statistics`.

- [ ] **Step 1: Add tab state for Statistics**

In `AppRootView`, update the tab enum and remove the Bills-only statistics destination:

```swift
private enum RootTab: Hashable {
    case bills
    case statistics
    case settings
}
```

Add:

```swift
@State private var selectedStatisticsMonth = Date()
```

- [ ] **Step 2: Wire Bills shortcut to tab switching**

Change the `BillsView` call:

```swift
BillsView(
    showQuickEntry: $showQuickEntry,
    onOpenStatistics: { month in
        selectedStatisticsMonth = month
        selectedTab = .statistics
    }
)
```

- [ ] **Step 3: Add the Statistics tab**

Insert between Bills and Me:

```swift
NavigationStack {
    StatisticsView(selectedMonth: $selectedStatisticsMonth)
}
.tabItem { Label("Statistics", systemImage: "chart.bar.xaxis") }
.tag(RootTab.statistics)
```

- [ ] **Step 4: Keep Bills summary as an actionable affordance**

In `BillsView`, change the summary card button label:

```swift
MonthlySummaryCard(summary: summary, showsChevron: true)
```

- [ ] **Step 5: Update notification routing**

Change the statistics route handling:

```swift
case .statistics:
    selectedStatisticsMonth = Date()
    selectedTab = .statistics
```

Keep quick entry selecting Bills, clearing Bills path, and showing the sheet.

- [ ] **Step 6: Build the app target**

Run:

```bash
xcodebuild -project MiniBill.xcodeproj -scheme MiniBill -configuration Debug -destination 'generic/platform=iOS Simulator' build
```

Expected: build succeeds.

### Task 3: Settings About, Version, and External Actions

**Files:**
- Modify: `ios/MiniBill/MiniBill/Features/Settings/SettingsView.swift`

**Interfaces:**
- Produces: `SettingsView.appVersion`.
- Produces: `SettingsView.openSupportEmail()`, `copySupportEmail()`, `openAppStoreRating()`, `openMoreApps()`.
- Produces: `AboutView(appVersion:)`.

- [ ] **Step 1: Add settings constants and version value**

Inside `SettingsView`:

```swift
private let supportEmail = "yokinzhu@gmail.com"
private let appStoreReviewURL = URL(string: "itms-apps://apps.apple.com/app/id6761642667?action=write-review")
private let appStoreWebReviewURL = URL(string: "https://apps.apple.com/app/id6761642667?action=write-review")
private let moreAppsURL = URL(string: "https://apps.apple.com/developer/%E8%A3%95%E9%87%91-%E6%9C%B1/id1888184686")

private var appVersion: String {
    Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "-"
}
```

- [ ] **Step 2: Add alert state for copied email**

Add:

```swift
@State private var copiedEmailMessage: String?
```

Add an alert modifier:

```swift
.alert("Email Copied", isPresented: Binding(
    get: { copiedEmailMessage != nil },
    set: { if !$0 { copiedEmailMessage = nil } }
)) {
    Button("OK", role: .cancel) { copiedEmailMessage = nil }
} message: {
    Text(copiedEmailMessage ?? "")
}
```

- [ ] **Step 3: Replace the App section rows**

Use:

```swift
Section("App") {
    NavigationLink {
        LanguageSelectionView(languageCode: $languageCode)
    } label: {
        HStack {
            Label("Language", systemImage: "globe")
            Spacer()
            Text(AppLanguage(storedCode: languageCode).displayName)
                .foregroundStyle(.secondary)
        }
    }
    NavigationLink { AboutView(appVersion: appVersion) } label: {
        Label("About MiniBill", systemImage: "info.circle")
    }
    LabeledContent {
        Text(appVersion)
    } label: {
        Label("Version", systemImage: "number")
    }
    Button(action: openSupportEmail) {
        LabeledContent {
            Text(supportEmail)
                .foregroundStyle(.secondary)
        } label: {
            Label("Contact Email", systemImage: "envelope")
        }
    }
    Button(action: openAppStoreRating) {
        Label("Rate App", systemImage: "star")
    }
    Button(action: openMoreApps) {
        Label("More Apps", systemImage: "square.grid.2x2")
    }
}
```

Delete the standalone Privacy navigation row.

- [ ] **Step 4: Implement external action helpers**

Add:

```swift
private func openSupportEmail() {
    var components = URLComponents()
    components.scheme = "mailto"
    components.path = supportEmail
    components.queryItems = [
        URLQueryItem(name: "subject", value: "MiniBill Support")
    ]

    guard let url = components.url else {
        copySupportEmail()
        return
    }

    UIApplication.shared.open(url) { success in
        if !success {
            copySupportEmail()
        }
    }
}

private func copySupportEmail() {
    UIPasteboard.general.string = supportEmail
    copiedEmailMessage = AppLocalization.string("Email copied: %@")
        .replacingOccurrences(of: "%@", with: supportEmail)
}

private func openAppStoreRating() {
    guard let appStoreReviewURL else { return }
    UIApplication.shared.open(appStoreReviewURL) { success in
        if !success, let appStoreWebReviewURL {
            UIApplication.shared.open(appStoreWebReviewURL)
        }
    }
}

private func openMoreApps() {
    guard let moreAppsURL else { return }
    UIApplication.shared.open(moreAppsURL)
}
```

- [ ] **Step 5: Merge Privacy into About MiniBill**

Delete `PrivacyView`. Replace `AboutView` with:

```swift
private struct AboutView: View {
    let appVersion: String

    var body: some View {
        List {
            VStack(spacing: 12) {
                AppBrandIcon(size: 96, cornerRadius: 20)
                Text("MiniBill").font(.title2.bold())
                Text("Offline bookkeeping for small businesses and side work.")
                    .foregroundStyle(AppTheme.muted)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)

            Section("App") {
                LabeledContent("Version", value: appVersion)
            }

            Section("Privacy") {
                Text("MiniBill stores ledger entries only on this device. It has no account, analytics, advertising, cloud sync, or network dependency.")
                Text("Share images are generated locally and never include notes. Backup files are not encrypted.")
                Text("Deleting MiniBill removes its local ledger and scheduled notifications from this device.")
            }
        }
        .navigationTitle("About MiniBill")
    }
}
```

- [ ] **Step 6: Build the app target**

Run:

```bash
xcodebuild -project MiniBill.xcodeproj -scheme MiniBill -configuration Debug -destination 'generic/platform=iOS Simulator' build
```

Expected: build succeeds.

### Task 4: Localization and Final Verification

**Files:**
- Modify: `ios/MiniBill/MiniBill/Resources/Localizable.xcstrings`

**Interfaces:**
- Consumes: Visible strings introduced in Tasks 2 and 3.
- Produces: localized string catalog entries for all supported languages.

- [ ] **Step 1: Add missing string catalog entries**

Add these keys with English source and translated values:

```text
Version
Contact Email
Rate App
More Apps
Email Copied
Email copied: %@
MiniBill Support
```

Use these Simplified Chinese values:

```text
Version = 版本
Contact Email = 联系邮箱
Rate App = 去 App Store 评分
More Apps = 更多作品
Email Copied = 邮箱已复制
Email copied: %@ = 邮箱已复制：%@
MiniBill Support = MiniBill 支持
```

Use these Traditional Chinese values:

```text
Version = 版本
Contact Email = 聯絡信箱
Rate App = 前往 App Store 評分
More Apps = 更多作品
Email Copied = 電子郵件已複製
Email copied: %@ = 電子郵件已複製：%@
MiniBill Support = MiniBill 支援
```

Use these Japanese values:

```text
Version = バージョン
Contact Email = 連絡先メール
Rate App = App Storeで評価
More Apps = その他の作品
Email Copied = メールをコピーしました
Email copied: %@ = メールをコピーしました：%@
MiniBill Support = MiniBillサポート
```

Use these Korean values:

```text
Version = 버전
Contact Email = 문의 이메일
Rate App = App Store에서 평가
More Apps = 더 많은 작품
Email Copied = 이메일 복사됨
Email copied: %@ = 이메일 복사됨: %@
MiniBill Support = MiniBill 지원
```

- [ ] **Step 2: Validate the string catalog parses and compiles**

Run:

```bash
python3 -m json.tool MiniBill/Resources/Localizable.xcstrings >/tmp/minibill-localizable-jsoncheck.json
outdir=$(mktemp -d /tmp/minibill-xcstring-check.XXXXXX)
xcrun xcstringstool compile --dry-run --output-directory "$outdir" MiniBill/Resources/Localizable.xcstrings
```

Expected: JSON parsing exits 0, and `xcstringstool` emits generated `.strings` paths for `ja`, `ko`, `zh-Hans`, and `zh-Hant`.

- [ ] **Step 3: Run package tests**

Run:

```bash
swift test
```

Expected: all tests pass.

- [ ] **Step 4: Run final app build**

Run:

```bash
xcodebuild -project MiniBill.xcodeproj -scheme MiniBill -configuration Debug -destination 'generic/platform=iOS Simulator' build
```

Expected: build succeeds.

- [ ] **Step 5: Review git diff**

Run:

```bash
git diff --stat
git diff -- ios/MiniBill/MiniBill.xcodeproj/project.pbxproj ios/MiniBill/MiniBill/App/AppRootView.swift ios/MiniBill/MiniBill/Features/Bills/BillsView.swift ios/MiniBill/MiniBill/Features/Bills/MonthlySummaryCard.swift ios/MiniBill/MiniBill/Features/Settings/SettingsView.swift ios/MiniBill/MiniBill/Resources/Localizable.xcstrings
```

Expected: only requested version, navigation, statistics affordance, settings, About/privacy, and localization changes are present.
