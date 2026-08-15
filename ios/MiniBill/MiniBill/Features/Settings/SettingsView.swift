import SwiftUI
import SwiftData
import UserNotifications
import UIKit

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Query(sort: \LedgerEntry.occurredAt, order: .reverse) private var entries: [LedgerEntry]
    @Query(sort: \LedgerAccount.createdAt) private var accounts: [LedgerAccount]
    @Binding var selectedAccountID: UUID

    @AppStorage(ReminderPreferenceKey.dailyEnabled) private var dailyEnabled = false
    @AppStorage(ReminderPreferenceKey.dailyHour) private var dailyHour = 20
    @AppStorage(ReminderPreferenceKey.dailyMinute) private var dailyMinute = 0
    @AppStorage(ReminderPreferenceKey.monthEndEnabled) private var monthEndEnabled = false
    @AppStorage(ReminderPreferenceKey.monthEndHour) private var monthEndHour = 21
    @AppStorage(ReminderPreferenceKey.monthEndMinute) private var monthEndMinute = 0
    @AppStorage(AppLanguage.storageKey) private var languageCode = AppLanguage.simplifiedChinese.rawValue

    @State private var authorizationStatus: UNAuthorizationStatus = .notDetermined
    @State private var exportedDocument: BackupDocument?
    @State private var showExporter = false
    @State private var showImporter = false
    @State private var restorePreview: RestorePreview?
    @State private var errorMessage: String?
    @State private var reminderErrorMessage: String?
    @State private var copiedEmailMessage: String?

    private let supportEmail = "yokinzhu@gmail.com"
    private let appStoreReviewURL = URL(string: "itms-apps://apps.apple.com/app/id6761642667?action=write-review")
    private let appStoreWebReviewURL = URL(string: "https://apps.apple.com/app/id6761642667?action=write-review")
    private let moreAppsURL = URL(string: "https://apps.apple.com/developer/%E8%A3%95%E9%87%91-%E6%9C%B1/id1888184686")

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "-"
    }

    private var selectedEntryCount: Int {
        entries.lazy.filter { $0.resolvedAccountID == selectedAccountID }.count
    }

    var body: some View {
        Form {
            Section {
                LabeledContent {
                    Text("\(selectedEntryCount)")
                } label: {
                    Label("Local Entries", systemImage: "tray.full")
                }
            }

            Section {
                AccountSwitcher(selectedAccountID: $selectedAccountID)
                NavigationLink {
                    AccountManagerView(selectedAccountID: $selectedAccountID)
                } label: {
                    Label("Manage Accounts", systemImage: "creditcard")
                }
            } header: {
                Text("Accounts")
            } footer: {
                Text("Entries and statistics are isolated by account.")
            }

            Section {
                Toggle(isOn: dailyBinding) {
                    Label("Daily Reminder", systemImage: "bell")
                }
                if dailyEnabled {
                    DatePicker("Daily Time", selection: timeBinding(hour: $dailyHour, minute: $dailyMinute, action: reconcileDaily), displayedComponents: .hourAndMinute)
                }
                Toggle(isOn: monthEndBinding) {
                    Label("Month-end Reminder", systemImage: "calendar.badge.clock")
                }
                if monthEndEnabled {
                    DatePicker("Month-end Time", selection: timeBinding(hour: $monthEndHour, minute: $monthEndMinute, action: reconcileMonthEnd), displayedComponents: .hourAndMinute)
                }
                if authorizationStatus == .denied {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("System notifications are off. Your reminder preference is preserved.")
                            .font(.footnote)
                            .foregroundStyle(.red)
                        Button { openSystemSettings() } label: {
                            Label("Open System Settings", systemImage: "gearshape")
                        }
                    }
                }
                if let reminderErrorMessage {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(reminderErrorMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                        Button("Try Again", action: retryReminderScheduling)
                    }
                }
            } header: {
                Text("Reminders")
            } footer: {
                Text("MiniBill schedules reminders on this device. Delivery can be affected by system notification settings, Focus, or power state.")
            }

            Section {
                Button { prepareExport() } label: { Label("Export Backup", systemImage: "arrow.up.doc") }
                Button { showImporter = true } label: { Label("Restore from Backup", systemImage: "arrow.down.doc") }
            } header: {
                Text("Backup")
            } footer: {
                Text("Backups are not encrypted. Save them only in a location you trust.")
            }

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
                    HStack {
                        Label("Contact Email", systemImage: "envelope")
                        Spacer()
                        Text(supportEmail)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                }
                Button(action: openAppStoreRating) {
                    Label("Thanks for using MiniBill. Leave a review", systemImage: "star")
                }
                Button(action: openMoreApps) {
                    Label("More Apps", systemImage: "square.grid.2x2")
                }
            }

            if let errorMessage {
                Section { Text(errorMessage).foregroundStyle(.red) }
            }
        }
        .navigationTitle("Me")
        .task { await refreshReminderSchedulingState() }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            Task { await refreshReminderSchedulingState() }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.significantTimeChangeNotification)) { _ in
            Task { await refreshReminderSchedulingState() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .NSSystemTimeZoneDidChange)) { _ in
            Task { await refreshReminderSchedulingState() }
        }
        .alert("Email Copied", isPresented: Binding(
            get: { copiedEmailMessage != nil },
            set: { if !$0 { copiedEmailMessage = nil } }
        )) {
            Button("OK", role: .cancel) { copiedEmailMessage = nil }
        } message: {
            Text(copiedEmailMessage ?? "")
        }
        .fileExporter(
            isPresented: $showExporter,
            document: exportedDocument,
            contentType: .miniBillBackup,
            defaultFilename: "\(BackupService.filename()).minibill"
        ) { result in
            if case .failure(let error) = result, !isCancellation(error) {
                errorMessage = AppLocalization.string("Export failed. Choose another location or try again.")
            }
            exportedDocument = nil
        }
        .fileImporter(isPresented: $showImporter, allowedContentTypes: [.miniBillBackup]) { result in
            importBackup(result)
        }
        .sheet(item: $restorePreview) { preview in
            RestorePreviewView(
                preview: preview,
                onExportCurrent: prepareExport,
                onRestore: {
                    try BackupService.replace(with: preview.archive, in: modelContext)
                    selectedAccountID = preview.archive.selectedAccountID
                }
            )
        }
    }

    private var dailyBinding: Binding<Bool> {
        Binding(get: { dailyEnabled }, set: { enabled in
            dailyEnabled = enabled
            applyDailyPreference(enabled: enabled, hour: dailyHour, minute: dailyMinute)
        })
    }

    private var monthEndBinding: Binding<Bool> {
        Binding(get: { monthEndEnabled }, set: { enabled in
            monthEndEnabled = enabled
            applyMonthEndPreference(enabled: enabled, hour: monthEndHour, minute: monthEndMinute)
        })
    }

    private func timeBinding(hour: Binding<Int>, minute: Binding<Int>, action: @escaping () -> Void) -> Binding<Date> {
        Binding(
            get: {
                Calendar.current.date(from: DateComponents(hour: hour.wrappedValue, minute: minute.wrappedValue)) ?? Date()
            },
            set: { date in
                hour.wrappedValue = Calendar.current.component(.hour, from: date)
                minute.wrappedValue = Calendar.current.component(.minute, from: date)
                action()
            }
        )
    }

    private func reconcileDaily() {
        applyDailyPreference(enabled: dailyEnabled, hour: dailyHour, minute: dailyMinute)
    }

    private func reconcileMonthEnd() {
        applyMonthEndPreference(enabled: monthEndEnabled, hour: monthEndHour, minute: monthEndMinute)
    }

    private func applyDailyPreference(enabled: Bool, hour: Int, minute: Int) {
        Task {
            do {
                try await ReminderService.shared.setDailyEnabled(enabled, hour: hour, minute: minute)
                reminderErrorMessage = nil
            } catch {
                reminderErrorMessage = AppLocalization.string("Could not schedule the reminder. Your preference was saved; try again.")
            }
            authorizationStatus = await ReminderService.shared.authorizationStatus()
        }
    }

    private func applyMonthEndPreference(enabled: Bool, hour: Int, minute: Int) {
        Task {
            do {
                try await ReminderService.shared.setMonthEndEnabled(enabled, hour: hour, minute: minute)
                reminderErrorMessage = nil
            } catch {
                reminderErrorMessage = AppLocalization.string("Could not schedule the reminder. Your preference was saved; try again.")
            }
            authorizationStatus = await ReminderService.shared.authorizationStatus()
        }
    }

    private func retryReminderScheduling() {
        Task {
            await refreshReminderSchedulingState()
        }
    }

    private func refreshReminderSchedulingState() async {
        do {
            try await ReminderService.shared.reconcileFromPreferences()
            reminderErrorMessage = nil
        } catch {
            reminderErrorMessage = AppLocalization.string("Could not schedule the reminder. Your preference was saved; try again.")
        }
        authorizationStatus = await ReminderService.shared.authorizationStatus()
    }

    private func prepareExport() {
        do {
            exportedDocument = try BackupService.document(
                entries: entries,
                accounts: accounts,
                selectedAccountID: selectedAccountID
            )
            showExporter = true
        } catch {
            errorMessage = AppLocalization.string("Export failed. Choose another location or try again.")
        }
    }

    private func importBackup(_ result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            let accessing = url.startAccessingSecurityScopedResource()
            defer { if accessing { url.stopAccessingSecurityScopedResource() } }
            do {
                restorePreview = try BackupService.preview(data: Data(contentsOf: url), currentRecordCount: entries.count)
            } catch let error as BackupValidationError {
                switch error {
                case .schemaTooNew: errorMessage = AppLocalization.string("This backup needs a newer version of MiniBill. Your ledger was not changed.")
                default: errorMessage = AppLocalization.string("This backup is damaged or invalid. Your ledger was not changed.")
                }
            } catch {
                errorMessage = AppLocalization.string("This backup could not be read. Your ledger was not changed.")
            }
        case .failure(let error):
            if !isCancellation(error) { errorMessage = AppLocalization.string("This backup could not be read. Your ledger was not changed.") }
        }
    }

    private func isCancellation(_ error: Error) -> Bool {
        (error as NSError).code == NSUserCancelledError
    }

    private func openSystemSettings() {
        guard let url = URL(string: UIApplication.openNotificationSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    private func openSupportEmail() {
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = supportEmail
        components.queryItems = [
            URLQueryItem(name: "subject", value: AppLocalization.string("MiniBill Support"))
        ]

        guard let url = components.url else {
            copySupportEmail()
            return
        }

        UIApplication.shared.open(url) { success in
            guard !success else { return }
            DispatchQueue.main.async { copySupportEmail() }
        }
    }

    private func copySupportEmail() {
        UIPasteboard.general.string = supportEmail
        copiedEmailMessage = String(format: AppLocalization.string("Email copied: %@"), supportEmail)
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

}

private struct LanguageSelectionView: View {
    @Binding var languageCode: String

    var body: some View {
        List(AppLanguage.allCases) { language in
            Button {
                languageCode = language.rawValue
            } label: {
                HStack {
                    Text(verbatim: language.displayName)
                    Spacer()
                    if language.rawValue == languageCode {
                        Image(systemName: "checkmark")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(AppTheme.brand)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityAddTraits(language.rawValue == languageCode ? .isSelected : [])
        }
        .navigationTitle("Language")
    }
}

private struct AboutView: View {
    let appVersion: String

    var body: some View {
        List {
            VStack(spacing: 12) {
                AppBrandIcon(size: 96, cornerRadius: 20)
                Text("MiniBill").font(.title2.bold())
                Text("Offline bookkeeping for small businesses and side work.")
                    .foregroundStyle(AppTheme.muted).multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)

            Section {
                AboutParagraph("MiniBill 是深耕小微经营者的本地离线收支流水记录工具，完美适配 iPhone 与 iPad。")
                AboutParagraph("专为摆摊、零工、副业、小微商户打造极简记账体验，无需复杂分类、不用维护账户库存，打开即可快速记收支，离线也能高效完成流水记录、账目复盘与收益统计。")
                AboutParagraph("支持项目化流水汇总、每日账单查看、本月收益趋势分析，搭配本地备份、收支截图分享、定时记账提醒功能，是小微从业者日常对账、收益核算、月末结账的刚需记账工具。")
            } header: {
                Text(verbatim: "App 简介")
            }

            Section {
                ForEach(Self.coreFeatures) { feature in
                    AboutFeatureBlock(feature: feature)
                }
            } header: {
                Text(verbatim: "【核心功能】")
            }

            Section {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Self.targetUsers, id: \.self) { user in
                        AboutBullet(user)
                    }
                }
                .padding(.vertical, 2)
            } header: {
                Text(verbatim: "【适合这些用户】")
            } footer: {
                Text(verbatim: "专为小微日常收支场景打造，零学习门槛，离线轻量化记账，一站式解决小生意、副业、零工的账目记录与收益统计需求。")
            }

            Section {
                AboutParagraph("全程无需注册登录、无需联网、不收集任何用户信息，所有记账数据本地存储、用户自主掌控，无广告、无内购、无数据上传分析，极致纯净、安全私密。")
            } header: {
                Text(verbatim: "【隐私与纯净说明】")
            }

            Section {
                AboutParagraph("由衷感谢每一位用户对独立开发者的支持！")
            } header: {
                Text(verbatim: "【感谢支持】")
            }

            Section("App") {
                LabeledContent("Version", value: appVersion)
            }
        }
        .navigationTitle("About MiniBill")
    }

    private static let coreFeatures = [
        AboutCopyBlock(
            title: "极简极速记账",
            body: "摒弃繁琐分类、账户、客户、库存维护流程，仅需输入金额、填写/选择项目名称即可保存收支记录，冰粉、摊位费、跑腿收入、副业佣金等各类小微收支都能快速记录，零基础上手无门槛。"
        ),
        AboutCopyBlock(
            title: "项目化收益智能汇总",
            body: "自动按项目名称统计本月总收入、总支出与净收益，生成项目收支排行，清晰区分盈利项目与支出项目，精准掌握每一笔资金流向与核心收益来源。"
        ),
        AboutCopyBlock(
            title: "明细与趋势可视化复盘",
            body: "支持按日查看全部收支流水，完整留存每笔账单记录；直观展示本月收支趋势，清晰掌握月度经营资金波动，方便月末对账、经营复盘。"
        ),
        AboutCopyBlock(
            title: "灵活账单编辑与分享",
            body: "可随时修改、删除错误记账记录，保障账目精准；支持单笔流水、本月整体收益一键生成图片，预览确认后通过系统直接分享，分享图纯净无备注，保护账目隐私。"
        ),
        AboutCopyBlock(
            title: "本地安全备份恢复",
            body: "所有账单数据仅保存在本机设备，无云端上传、无数据泄露风险。支持导出专属.minibill备份文件，恢复账目前自动校验数据并预览内容，确认后一键完整替换本机流水，账目留存安全可控。"
        ),
        AboutCopyBlock(
            title: "智能定时记账提醒",
            body: "可选本地每日记账提醒、月末结账提醒，由iOS本地专属排程运行，无后台驻留耗电，仅首次开启时申请通知权限，贴心杜绝漏记、忘记账单问题。"
        ),
        AboutCopyBlock(
            title: "多语言&本地化适配",
            body: "原生支持简体中文、繁体中文、英语、日语、韩语五国语言，自动适配设备地区，精准匹配对应日期、时间、数字格式与人民币金额展示，适配不同用户使用习惯。"
        ),
        AboutCopyBlock(
            title: "极致纯净无干扰体验",
            body: "无账号注册、无网络依赖、无云端同步功能，全程零广告、无弹窗、无推送骚扰，应用轻量简洁，专注核心记账功能，无多余冗余功能干扰。"
        )
    ]

    private static let targetUsers = [
        "夜市、地摊、摆摊创业者",
        "跑腿、兼职、自由职业零工从业者",
        "各类副业、小众小微经营者",
        "个体散户、小成本创业者",
        "需要极简离线记账、快速复盘收支的用户"
    ]
}

private struct AboutCopyBlock: Identifiable {
    let title: String
    let body: String

    var id: String { title }
}

private struct AboutParagraph: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(verbatim: text)
            .font(.body)
            .foregroundStyle(AppTheme.ink)
            .lineSpacing(3)
            .fixedSize(horizontal: false, vertical: true)
    }
}

private struct AboutFeatureBlock: View {
    let feature: AboutCopyBlock

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(verbatim: feature.title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.ink)
            Text(verbatim: feature.body)
                .font(.body)
                .foregroundStyle(AppTheme.ink)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 4)
    }
}

private struct AboutBullet: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(verbatim: "-")
                .foregroundStyle(AppTheme.muted)
            Text(verbatim: text)
                .foregroundStyle(AppTheme.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
        .font(.body)
    }
}
