import SwiftUI
import SwiftData

private func accountDisplayName(_ account: LedgerAccount) -> String {
    if account.id == LedgerAccountDefaults.id,
       account.name == LedgerAccountDefaults.name {
        return AppLocalization.string("Default Account")
    }
    return account.name
}

struct AccountSwitcher: View {
    @Query(sort: \LedgerAccount.createdAt) private var accounts: [LedgerAccount]
    @Binding var selectedAccountID: UUID

    private var selectedName: String {
        if let account = accounts.first(where: { $0.id == selectedAccountID }) ?? accounts.first {
            return accountDisplayName(account)
        }
        return AppLocalization.string("Default Account")
    }

    var body: some View {
        Menu {
            ForEach(accounts) { account in
                Button {
                    selectedAccountID = account.id
                } label: {
                    if account.id == selectedAccountID {
                        Label(accountDisplayName(account), systemImage: "checkmark")
                    } else {
                        Text(accountDisplayName(account))
                    }
                }
            }
        } label: {
            Label(selectedName, systemImage: "creditcard")
                .lineLimit(1)
        }
        .accessibilityLabel("Switch Account")
        .onAppear(perform: repairSelection)
        .onChange(of: accounts.map(\.id)) { _, _ in repairSelection() }
    }

    private func repairSelection() {
        guard let first = accounts.first,
              !accounts.contains(where: { $0.id == selectedAccountID }) else { return }
        selectedAccountID = first.id
    }
}

struct AccountManagerView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \LedgerAccount.createdAt) private var accounts: [LedgerAccount]
    @Query private var entries: [LedgerEntry]
    @Binding var selectedAccountID: UUID

    @State private var isShowingNameEditor = false
    @State private var editingAccountID: UUID?
    @State private var nameDraft = ""
    @State private var pendingDelete: LedgerAccount?
    @State private var errorMessage: String?

    var body: some View {
        List {
            Section {
                ForEach(accounts) { account in
                    Button {
                        selectedAccountID = account.id
                    } label: {
                        HStack {
                            Label(accountDisplayName(account), systemImage: "creditcard")
                                .foregroundStyle(AppTheme.ink)
                            Spacer()
                            Text("\(entryCount(for: account.id))")
                                .foregroundStyle(AppTheme.muted)
                            if account.id == selectedAccountID {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(AppTheme.brand)
                            }
                        }
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) {
                            pendingDelete = account
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                        .disabled(accounts.count == 1)

                        Button {
                            beginEditing(account)
                        } label: {
                            Label("Rename", systemImage: "pencil")
                        }
                        .tint(AppTheme.brandDark)
                    }
                    .contextMenu {
                        Button("Rename") { beginEditing(account) }
                    }
                }
            } footer: {
                Text("Each account has independent entries and statistics. Backups include every account.")
            }
        }
        .navigationTitle("Accounts")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    editingAccountID = nil
                    nameDraft = ""
                    isShowingNameEditor = true
                } label: {
                    Label("Add Account", systemImage: "plus")
                }
            }
        }
        .alert(editingAccountID == nil ? "New Account" : "Rename Account", isPresented: $isShowingNameEditor) {
            TextField("Account Name", text: $nameDraft)
            Button("Cancel", role: .cancel) {}
            Button("Save", action: saveName)
        } message: {
            Text("Use 1–30 characters.")
        }
        .confirmationDialog(
            "Delete this account?",
            isPresented: Binding(
                get: { pendingDelete != nil },
                set: { if !$0 { pendingDelete = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Delete Account and Its Entries", role: .destructive, action: deletePendingAccount)
        } message: {
            if let account = pendingDelete {
                Text("This permanently deletes \(entryCount(for: account.id)) entries in \(accountDisplayName(account)).")
            }
        }
        .alert("Could not update accounts", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
        .onAppear(perform: repairSelection)
        .onChange(of: accounts.map(\.id)) { _, _ in repairSelection() }
    }

    private func entryCount(for accountID: UUID) -> Int {
        entries.lazy.filter { $0.resolvedAccountID == accountID }.count
    }

    private func beginEditing(_ account: LedgerAccount) {
        editingAccountID = account.id
        nameDraft = account.name
        isShowingNameEditor = true
    }

    private func saveName() {
        let previousSelection = selectedAccountID
        do {
            let name = try LedgerAccountName.normalized(nameDraft)
            if let editingAccountID,
               let account = accounts.first(where: { $0.id == editingAccountID }) {
                account.name = name
                account.updatedAt = Date()
            } else {
                let now = Date()
                let account = LedgerAccount(name: name, createdAt: now, updatedAt: now)
                modelContext.insert(account)
                selectedAccountID = account.id
            }
            try modelContext.save()
        } catch let error as LedgerAccountNameError {
            modelContext.rollback()
            selectedAccountID = previousSelection
            errorMessage = error == .empty
                ? AppLocalization.string("Account name is required.")
                : AppLocalization.string("Account name must be 30 characters or fewer.")
        } catch {
            modelContext.rollback()
            selectedAccountID = previousSelection
            errorMessage = AppLocalization.string("Your accounts were not changed.")
        }
    }

    private func deletePendingAccount() {
        guard accounts.count > 1,
              let account = pendingDelete,
              let replacement = accounts.first(where: { $0.id != account.id }) else {
            pendingDelete = nil
            return
        }
        let previousSelection = selectedAccountID
        do {
            for entry in entries where entry.resolvedAccountID == account.id {
                modelContext.delete(entry)
            }
            modelContext.delete(account)
            try modelContext.save()
            if previousSelection == account.id {
                selectedAccountID = replacement.id
            }
            pendingDelete = nil
        } catch {
            modelContext.rollback()
            selectedAccountID = previousSelection
            pendingDelete = nil
            errorMessage = AppLocalization.string("Your accounts were not changed.")
        }
    }

    private func repairSelection() {
        guard !accounts.isEmpty,
              !accounts.contains(where: { $0.id == selectedAccountID }) else { return }
        selectedAccountID = accounts[0].id
    }
}
