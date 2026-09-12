import SwiftUI

struct WatchAccountsView: View {
    @EnvironmentObject private var store: WatchLedgerStore
    @State private var isAdding = false
    private var strings: WatchStrings { WatchStrings(language: store.language) }

    var body: some View {
        List {
            ForEach(store.accounts) { account in
                NavigationLink {
                    WatchAccountDetail(accountID: account.id)
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(strings.accountName(account))
                            if account.id == store.selectedAccountID {
                                Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                            }
                        }
                        Text(strings.entries(store.records.filter { $0.accountID == account.id }.count))
                            .font(.caption2).foregroundStyle(.secondary)
                    }
                }
            }
            Button { isAdding = true } label: {
                Label(strings("Add Account"), systemImage: "plus")
            }
            .disabled(!store.hasSnapshot)
        }
        .navigationTitle(strings("Accounts"))
        .sheet(isPresented: $isAdding) {
            NavigationStack { WatchAccountNameEditor() }
        }
    }
}

private struct WatchAccountDetail: View {
    @EnvironmentObject private var store: WatchLedgerStore
    @Environment(\.dismiss) private var dismiss
    let accountID: UUID
    @State private var isRenaming = false
    @State private var confirmDelete = false
    @State private var errorMessage: String?
    private var strings: WatchStrings { WatchStrings(language: store.language) }
    private var account: LedgerAccountRecord? { store.accounts.first { $0.id == accountID } }

    var body: some View {
        List {
            if let account {
                Text(strings.accountName(account)).font(.headline)
                Text(strings.entries(store.records.filter { $0.accountID == accountID }.count))
                    .font(.caption).foregroundStyle(.secondary)
                Button {
                    store.selectedAccountID = accountID
                    dismiss()
                } label: {
                    Label(strings(accountID == store.selectedAccountID ? "Current Ledger" : "Switch Account"),
                          systemImage: accountID == store.selectedAccountID ? "checkmark.circle.fill" : "arrow.left.arrow.right")
                }
                .disabled(accountID == store.selectedAccountID)
                Button(strings("Rename")) { isRenaming = true }
                Button(role: .destructive) { confirmDelete = true } label: {
                    Label(strings("Delete"), systemImage: "trash")
                }
                .disabled(store.accounts.count <= 1)
                if store.accounts.count <= 1 {
                    Text(strings("Keep at least one account.")).font(.caption2).foregroundStyle(.secondary)
                }
            }
            if let errorMessage { Text(errorMessage).font(.caption).foregroundStyle(.red) }
        }
        .navigationTitle(strings("Accounts"))
        .sheet(isPresented: $isRenaming) {
            if let account {
                NavigationStack { WatchAccountNameEditor(account: account) }
            }
        }
        .confirmationDialog(strings("Delete this account?"), isPresented: $confirmDelete, titleVisibility: .visible) {
            Button(strings("Delete Account and Its Entries"), role: .destructive, action: delete)
            Button(strings("Cancel"), role: .cancel) {}
        } message: {
            if let account {
                Text(String(format: strings("This permanently deletes %lld entries in %@."),
                            locale: store.language.locale,
                            Int64(store.records.filter { $0.accountID == accountID }.count),
                            strings.accountName(account)))
            }
        }
        .onChange(of: store.accounts.map(\.id)) { _, ids in
            if !ids.contains(accountID) { dismiss() }
        }
    }

    private func delete() {
        guard let account else { return }
        do {
            try store.deleteAccount(account)
            dismiss()
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription
                ?? strings("Your accounts were not changed.")
        }
    }
}

private struct WatchAccountNameEditor: View {
    @EnvironmentObject private var store: WatchLedgerStore
    @Environment(\.dismiss) private var dismiss
    let account: LedgerAccountRecord?
    @State private var name: String
    @State private var errorMessage: String?
    @State private var confirmDiscard = false
    private var strings: WatchStrings { WatchStrings(language: store.language) }
    private var hasChanges: Bool { name != (account?.name ?? "") }

    init(account: LedgerAccountRecord? = nil) {
        self.account = account
        _name = State(initialValue: account?.name ?? "")
    }

    var body: some View {
        Form {
            TextField(strings("Account Name"), text: $name)
            Text(strings("Use 1–30 characters.")).font(.caption).foregroundStyle(.secondary)
            if let errorMessage { Text(errorMessage).font(.caption).foregroundStyle(.red) }
            Button(strings("Save"), action: save).disabled(!store.hasSnapshot)
        }
        .navigationTitle(strings(account == nil ? "New Account" : "Rename Account"))
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(strings("Cancel")) {
                    if hasChanges { confirmDiscard = true } else { dismiss() }
                }
            }
        }
        .interactiveDismissDisabled(hasChanges)
        .confirmationDialog(strings("Discard your changes?"), isPresented: $confirmDiscard, titleVisibility: .visible) {
            Button(strings("Discard"), role: .destructive) { dismiss() }
            Button(strings("Cancel"), role: .cancel) {}
        }
    }

    private func save() {
        do {
            let normalized = try LedgerAccountName.normalized(name)
            let now = Date()
            let value = LedgerAccountRecord(id: account?.id ?? UUID(), name: normalized,
                                            createdAt: account?.createdAt ?? now, updatedAt: now)
            try store.saveAccount(value, replacing: account)
            if account == nil { store.selectedAccountID = value.id }
            dismiss()
        } catch {
            errorMessage = WatchFormat.validationMessage(error, language: store.language)
        }
    }
}
