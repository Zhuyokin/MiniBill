import SwiftUI

struct WatchSyncView: View {
    @EnvironmentObject private var store: WatchLedgerStore
    private var strings: WatchStrings { WatchStrings(language: store.language) }

    var body: some View {
        List {
            Label(strings(store.isReachable ? "iPhone connected" : "iPhone offline"),
                  systemImage: store.isReachable ? "iphone.radiowaves.left.and.right" : "iphone.slash")
                .font(.headline)
            if !store.hasSnapshot {
                Text(strings("Open MiniBill on your iPhone to start.")).font(.caption)
            } else {
                Text(String(format: strings("%lld pending changes"), locale: store.language.locale,
                            Int64(store.pendingCount))).font(.caption)
                if store.pendingCount > 0 {
                    Text(strings("Saved on Apple Watch. Sync resumes when iPhone is available."))
                        .font(.caption2).foregroundStyle(.secondary)
                }
                if let lastSync = store.lastSync {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(strings("Last sync")).font(.caption2).foregroundStyle(.secondary)
                        Text(WatchFormat.dateTime(lastSync, language: store.language)).font(.caption)
                    }
                }
            }
            Button { store.refresh() } label: {
                Label(strings("Sync now"), systemImage: "arrow.triangle.2.circlepath")
            }
            if !store.failedChanges.isEmpty {
                Section(strings("Changes need attention")) {
                    ForEach(store.failedChanges) { failure in
                        NavigationLink { WatchSyncFailureView(failureID: failure.id) } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(strings(operationTitle(failure.mutation.kind))).font(.caption2)
                                Text(failure.mutation.record?.projectName
                                     ?? failure.mutation.account.map { strings.accountName($0) }
                                     ?? strings("Entry Details"))
                                    .font(.headline).lineLimit(2)
                                Text(strings(rejectionTitle(failure.reason)))
                                    .font(.caption2).foregroundStyle(.orange)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle(strings("Sync"))
    }
}

private struct WatchSyncFailureView: View {
    @EnvironmentObject private var store: WatchLedgerStore
    @Environment(\.dismiss) private var dismiss
    let failureID: UUID
    @State private var confirmRetry = false
    @State private var confirmDiscard = false
    @State private var errorMessage: String?
    private var strings: WatchStrings { WatchStrings(language: store.language) }
    private var failure: WatchSyncFailure? { store.failedChanges.first { $0.id == failureID } }

    var body: some View {
        List {
            if let failure {
                Text(strings(rejectionTitle(failure.reason))).font(.caption).foregroundStyle(.orange)
                Section(strings("Saved change")) {
                    Text(strings(operationTitle(failure.mutation.kind))).font(.headline)
                    if let record = failure.mutation.record ?? failure.mutation.baseRecord {
                        WatchFailureRecordView(record: record, language: store.language)
                    }
                    if let account = failure.mutation.account ?? failure.mutation.baseAccount {
                        Text(strings.accountName(account))
                        if let entries = failure.mutation.accountEntries {
                            Text(strings.entries(entries.count)).font(.caption)
                        }
                    }
                }
                if let recordID = failure.mutation.record?.id,
                   let current = store.records.first(where: { $0.id == recordID }) {
                    Section(strings("Latest version")) {
                        WatchFailureRecordView(record: current, language: store.language)
                    }
                }
                if let accountID = failure.mutation.account?.id,
                   let current = store.accounts.first(where: { $0.id == accountID }) {
                    Section(strings("Latest version")) {
                        Text(strings.accountName(current))
                        Text(strings.entries(store.records.filter { $0.accountID == accountID }.count))
                            .font(.caption)
                    }
                }
                Button(strings("Try Again")) { confirmRetry = true }.disabled(!store.hasSnapshot)
                Button(strings("Discard"), role: .destructive) { confirmDiscard = true }
            }
            if let errorMessage { Text(errorMessage).font(.caption).foregroundStyle(.red) }
        }
        .navigationTitle(strings("Saved change"))
        .confirmationDialog(strings("Apply this change again?"), isPresented: $confirmRetry, titleVisibility: .visible) {
            Button(strings("Try Again"), role: .destructive, action: retry)
            Button(strings("Cancel"), role: .cancel) {}
        } message: {
            Text(strings(retryMessage))
        }
        .confirmationDialog(strings("Discard saved change?"), isPresented: $confirmDiscard, titleVisibility: .visible) {
            Button(strings("Discard"), role: .destructive, action: discard)
            Button(strings("Cancel"), role: .cancel) {}
        } message: {
            Text(strings("This removes the saved change from Apple Watch."))
        }
        .onChange(of: store.failedChanges.map(\.id)) { _, ids in
            if !ids.contains(failureID) { dismiss() }
        }
    }

    private var retryMessage: String {
        switch failure?.mutation.kind {
        case .deleteAccount: return "Retry deletes this account and all of its current entries."
        case .deleteEntry: return "Retry deletes the latest version of this entry."
        default: return "Retry uses the latest data and may overwrite newer edits."
        }
    }

    private func retry() {
        do {
            try store.retryFailure(failureID)
            dismiss()
        } catch let rejection as WatchSyncRejection {
            errorMessage = strings(rejectionTitle(rejection))
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription
                ?? strings("Could not save on Apple Watch. Your changes are still on screen.")
        }
    }

    private func discard() {
        do {
            try store.discardFailure(failureID)
            dismiss()
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription
                ?? strings("Could not save on Apple Watch. Your changes are still on screen.")
        }
    }
}

private struct WatchFailureRecordView: View {
    let record: LedgerRecord
    let language: AppLanguage

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(record.projectName).font(.headline)
            Text(WatchStrings(language: language)(record.kind == .income ? "Income" : "Expense"))
                .font(.caption)
            Text(WatchFormat.money(record.amountCents, language: language))
                .font(.headline).monospacedDigit().foregroundStyle(WatchFormat.color(record.kind))
                .lineLimit(1).minimumScaleFactor(0.5)
            Text(WatchFormat.dateTime(record.occurredAt, language: language)).font(.caption)
            if let note = record.note { Text(note).font(.caption) }
        }
    }
}

private func operationTitle(_ kind: WatchMutationKind) -> String {
    switch kind {
    case .saveEntry: return "Save Entry"
    case .deleteEntry: return "Delete Entry"
    case .saveAccount: return "Save Account"
    case .deleteAccount: return "Delete Account and Its Entries"
    }
}

private func rejectionTitle(_ reason: WatchSyncRejection) -> String {
    switch reason {
    case .conflict: return "This item changed on iPhone. Review the latest version."
    case .accountMissing: return "This account no longer exists."
    case .lastAccount: return "Keep at least one account."
    case .invalidData: return "Check the amount, project and account name."
    }
}
