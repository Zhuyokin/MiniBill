# MiniBill iOS MVP Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the approved iOS 17+ MiniBill offline bookkeeping MVP from the design specification and prototype.

**Architecture:** SwiftUI screens read and write a single SwiftData `LedgerEntry` model. Pure Foundation core types handle money, project-name normalization, monthly aggregation, backup validation, and reminder date calculation so they can be tested with SwiftPM. Backup, notification, and share-image services stay local and are injected at feature boundaries.

**Tech Stack:** Swift 5, SwiftUI, SwiftData, Swift Testing/XCTest through SwiftPM, UserNotifications, UniformTypeIdentifiers, ImageRenderer.

## Global Constraints

- App/project/target/product name is exactly `MiniBill`; bundle identifier is `com.masdey.minibill`.
- Minimum deployment target is iOS 17.0 and the app must build without third-party dependencies.
- Data is stored only on the device; there is no account, cloud sync, analytics, advertising, or network dependency.
- Navigation has only `账单` and `我的` tabs; statistics opens from the compact monthly summary.
- There is no category model, category selector, or category CRUD. `projectName` is the grouping key and recent entries are candidates.
- Supported localizations are `zh-Hans`, `zh-Hant`, `en`, `ja`, and `ko`.
- The installed Home Screen display name is `小微账单` for Simplified Chinese, `小微帳單` for Traditional Chinese, and `MiniBill` for every non-Chinese locale.
- After the system launch screen, show a short in-app brand splash with the approved AppIcon and localized slogan whose Simplified Chinese source is exactly `极简离线账单，小生意随手记`; it must not perform network work or add a long artificial delay.
- Reminders are pre-scheduled local notifications. Do not promise delivery through Focus, notification summaries, disabled permissions, or device power-off.
- Backup export/restore must round-trip IDs, cents, type, project name, note, and dates. Restore validates fully before replacing current data.
- Share images are rendered locally and never include entry notes.
- Preserve the approved AppIcon and `Docs/Design` assets.

---

### Task 1: Testable ledger core

**Files:**
- Create: `ios/MiniBill/Package.swift`
- Create: `ios/MiniBill/MiniBill/Core/LedgerTypes.swift`
- Create: `ios/MiniBill/MiniBill/Core/ProjectNameNormalizer.swift`
- Create: `ios/MiniBill/MiniBill/Core/LedgerAnalytics.swift`
- Create: `ios/MiniBill/MiniBill/Core/BackupArchive.swift`
- Create: `ios/MiniBill/MiniBill/Core/ReminderSchedule.swift`
- Create: `ios/MiniBill/Tests/MiniBillCoreTests/*.swift`

**Interfaces:**
- Produces: `LedgerKind`, `LedgerRecord`, `MonthlySummary`, `ProjectTotal`, `ProjectNameNormalizer.normalizedKey(_:)`, `LedgerAnalytics.summary(records:month:calendar:)`, `BackupArchive`, `BackupValidator.validate(_:)`, and `ReminderSchedule.monthEnds(startingAt:count:calendar:)`.

- [ ] **Step 1: Write failing tests** for cents-safe income/expense totals, whitespace/case normalization without fuzzy merging, stable project ranking, corrupted/duplicate backup rejection, and leap-year month-end dates. Use literal expected values.
- [ ] **Step 2: Run `swift test --package-path ios/MiniBill`** and confirm failures are caused by missing APIs.
- [ ] **Step 3: Implement the minimal Foundation-only core.** Money is signed only when displayed; storage is positive `Int64` cents plus `LedgerKind`. The normalizer trims, collapses internal whitespace, and lowercases Latin text using `Locale(identifier: "en_US_POSIX")`; it does not merge synonyms.
- [ ] **Step 4: Run `swift test --package-path ios/MiniBill`** and confirm all core tests pass.

### Task 2: SwiftData persistence and resilient launch

**Files:**
- Replace: `ios/MiniBill/MiniBill/Item.swift`
- Modify: `ios/MiniBill/MiniBill/MiniBillApp.swift`
- Create: `ios/MiniBill/MiniBill/Data/LedgerEntry.swift`
- Create: `ios/MiniBill/MiniBill/Data/LedgerEntryMapper.swift`
- Create: `ios/MiniBill/MiniBill/App/LaunchFailureView.swift`

**Interfaces:**
- Consumes: `LedgerRecord` and `LedgerKind`.
- Produces: SwiftData `LedgerEntry` with `id`, `kindRawValue`, `amountCents`, `projectName`, `note`, `occurredAt`, `createdAt`, and `updatedAt`; mapping to/from `LedgerRecord`.

- [ ] **Step 1: Add mapper tests** that fail when any round-trip field changes.
- [ ] **Step 2: Run the core tests and verify RED.**
- [ ] **Step 3: Implement `LedgerEntry` and mapper, remove the placeholder `Item`, and create a persistent `ModelContainer`.** If container creation fails, render `LaunchFailureView`; never silently create a replacement in-memory ledger.
- [ ] **Step 4: Run `swift test` and `xcodebuild` and verify GREEN.**

### Task 3: Bills home and three-second entry flow

**Files:**
- Replace: `ios/MiniBill/MiniBill/ContentView.swift`
- Create: `ios/MiniBill/MiniBill/App/AppRootView.swift`
- Create: `ios/MiniBill/MiniBill/App/SplashView.swift`
- Create: `ios/MiniBill/MiniBill/Features/Bills/BillsView.swift`
- Create: `ios/MiniBill/MiniBill/Features/Bills/MonthlySummaryCard.swift`
- Create: `ios/MiniBill/MiniBill/Features/Bills/LedgerRow.swift`
- Create: `ios/MiniBill/MiniBill/Features/Entry/QuickEntrySheet.swift`
- Create: `ios/MiniBill/MiniBill/Features/Entry/EditEntryView.swift`

**Interfaces:**
- Consumes: SwiftData `ModelContext`, queried entries, analytics, and project normalizer.
- Produces: localized brand splash, two-tab shell, date-grouped ledger, compact monthly summary, bottom-sheet create/edit/delete flows.

- [ ] **Step 1: Add tests** for entry validation (`amountCents > 0`, non-empty normalized project name) and recent-candidate order/limit six; verify RED.
- [ ] **Step 2: Implement a short in-app splash, then the two-tab shell and bills home** matching the approved prototype. The splash uses the approved AppIcon plus a localized slogan and transitions to the ledger without network access; the ledger shows monthly summary first, today/history groups, signed amounts, and one floating add button.
- [ ] **Step 3: Implement the 0.75-height quick-entry sheet** with income/expense segment, amount keypad/input, required project name, recent candidates, optional note/date, save feedback, and validation messages.
- [ ] **Step 4: Implement edit and confirmed delete.** A project-name edit must immediately affect candidates and analytics because both derive from entries.
- [ ] **Step 5: Run tests and simulator build.**

### Task 4: Project-based statistics

**Files:**
- Create: `ios/MiniBill/MiniBill/Features/Statistics/StatisticsView.swift`
- Create: `ios/MiniBill/MiniBill/Features/Statistics/ProjectRankingView.swift`

**Interfaces:**
- Consumes: `LedgerAnalytics` output from current month records.
- Produces: month picker, income/expense/net totals, entry count, simple daily net chart, separate income and expense project rankings.

- [ ] **Step 1: Add failing analytics tests** for month boundaries, empty months, ties, and independent income/expense rankings.
- [ ] **Step 2: Implement the statistics screen** reachable only by tapping the home summary; do not add a third tab.
- [ ] **Step 3: Run tests and build.**

### Task 5: Local backup and transactional restore

**Files:**
- Create: `ios/MiniBill/MiniBill/Services/BackupService.swift`
- Create: `ios/MiniBill/MiniBill/Features/Settings/BackupDocument.swift`
- Create: `ios/MiniBill/MiniBill/Features/Settings/RestorePreviewView.swift`

**Interfaces:**
- Consumes: `BackupArchive`, mapper, and `ModelContext`.
- Produces: `.minibill` JSON export, import preview, validated replace operation, explicit success/failure states.

- [ ] **Step 1: Add failing archive tests** for exact round-trip, schema-too-new, duplicate UUID, invalid cents/type/date/project, and malformed JSON.
- [ ] **Step 2: Implement versioned JSON DTO export** with ISO-8601 dates and a stable file name `MiniBill-YYYYMMDD-HHmm.minibill`.
- [ ] **Step 3: Implement import preview without mutation.** Show backup time/count/range and current count.
- [ ] **Step 4: Implement replace restore in one SwiftData transaction.** On any error rollback and preserve the original entries.
- [ ] **Step 5: Run tests and build.**

### Task 6: Offline notifications and settings

**Files:**
- Create: `ios/MiniBill/MiniBill/Services/ReminderService.swift`
- Create: `ios/MiniBill/MiniBill/Features/Settings/SettingsView.swift`
- Create: `ios/MiniBill/MiniBill/App/NotificationRouter.swift`

**Interfaces:**
- Consumes: `ReminderSchedule`, `UNUserNotificationCenter`, and app-scoped preferences.
- Produces: daily repeating reminder, 12 pre-scheduled last-day reminders, permission/status UI, and routes to quick entry/statistics.

- [ ] **Step 1: Add failing reminder-date tests** for all month lengths, year rollover, and leap years.
- [ ] **Step 2: Implement settings groups** for daily/month-end reminders, export/restore, system language, privacy, and about.
- [ ] **Step 3: Request permission only after a user enables a reminder.** Reconcile pending requests on launch and after settings changes; daily reminder repeats, month-end schedules 12 unique calendar notifications.
- [ ] **Step 4: Route notification responses** after the model container is ready.
- [ ] **Step 5: Run tests/build and document a physical-device killed-process reminder check.**

### Task 7: Local share images and localization

**Files:**
- Create: `ios/MiniBill/MiniBill/Services/ShareImageService.swift`
- Create: `ios/MiniBill/MiniBill/Features/Sharing/MonthlyShareCard.swift`
- Create: `ios/MiniBill/MiniBill/Features/Sharing/EntryShareCard.swift`
- Create: `ios/MiniBill/MiniBill/Features/Sharing/SharePreviewView.swift`
- Create: `ios/MiniBill/MiniBill/Resources/Localizable.xcstrings`
- Create: localized `InfoPlist.strings` resources for `zh-Hans`, `zh-Hant`, `en`, `ja`, and `ko`, or an equivalent String Catalog that localizes `CFBundleDisplayName`.

**Interfaces:**
- Consumes: selected record/month summary.
- Produces: local PNG at a temporary URL and system share sheet; localized UI, reminders, errors, and share-card text.

- [ ] **Step 1: Add tests** proving share payloads omit notes and contain only the approved fields.
- [ ] **Step 2: Implement `ImageRenderer` cards** at 900×1200 logical size for monthly sharing and a matching single-entry layout. Write PNG data to a temporary file for `ShareLink`.
- [ ] **Step 3: Add all user-facing strings** in Simplified Chinese, Traditional Chinese, English, Japanese, and Korean. Project names and backup keys remain untranslated.
- [ ] **Step 3a: Localize the installed display name.** Verify Chinese locales render `小微账单` / `小微帳單`; English, Japanese, Korean, and all fallback locales render `MiniBill`.
- [ ] **Step 4: Run tests/build and inspect every localization for truncation using previews or simulator screenshots.**

### Task 8: Acceptance verification

**Files:**
- Update: `ios/MiniBill/Docs/Design/README.md` only if implementation paths need cross-links.

- [ ] **Step 1: Run `swift test --package-path ios/MiniBill`** with zero failures.
- [ ] **Step 2: Run Debug and Release simulator builds** with code signing disabled.
- [ ] **Step 3: Exercise add/edit/delete, month statistics, export/import preview/restore, notification toggles, both share cards, empty/error states, and both tabs.
- [ ] **Step 4: Confirm no source or engineering directory under `ios/` contains Chinese characters.**
- [ ] **Step 5: Verify the splash uses the approved icon, shows the correct localized slogan, remains fully offline, and transitions without a long artificial delay.**
- [ ] **Step 6: Review the diff against every Global Constraint and report any device-only check separately.**
