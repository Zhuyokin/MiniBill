import SwiftUI
import SwiftData

private func accountDisplayName(_ account: LedgerAccount, language: AppLanguage) -> String {
    if account.id == LedgerAccountDefaults.id,
       account.name == LedgerAccountDefaults.name {
        return AppLocalization.string("Default Account", language: language)
    }
    return account.name
}

struct AccountSwitcher: View {
    @Environment(\.appLanguage) private var language
    @Query(sort: \LedgerAccount.createdAt) private var accounts: [LedgerAccount]
    @Binding var selectedAccountID: UUID

    private var selectedName: String {
        if let account = accounts.first(where: { $0.id == selectedAccountID }) ?? accounts.first {
            return accountDisplayName(account, language: language)
        }
        return AppLocalization.string("Default Account", language: language)
    }

    var body: some View {
        Menu {
            ForEach(accounts) { account in
                Button {
                    selectedAccountID = account.id
                } label: {
                    if account.id == selectedAccountID {
                        Label(accountDisplayName(account, language: language), systemImage: "checkmark")
                    } else {
                        Text(accountDisplayName(account, language: language))
                    }
                }
            }
        } label: {
            Image(systemName: "person.2.circle.fill")
                .font(.body.weight(.semibold))
                .frame(width: 32, height: 32)
                .contentShape(Rectangle())
        }
        .accessibilityLabel(
            "\(AppLocalization.string("Switch Account", language: language)): \(selectedName)"
        )
        .onAppear(perform: repairSelection)
        .onChange(of: accounts.map(\.id)) { _, _ in repairSelection() }
    }

    private func repairSelection() {
        guard let first = accounts.first,
              !accounts.contains(where: { $0.id == selectedAccountID }) else { return }
        selectedAccountID = first.id
    }
}

struct AccountSettingsLink: View {
    @Environment(\.appLanguage) private var language
    @Query(sort: \LedgerAccount.createdAt) private var accounts: [LedgerAccount]
    @Binding var selectedAccountID: UUID
    let entryCount: Int
    @State private var isShowingManager = false

    private var selectedName: String {
        if let account = accounts.first(where: { $0.id == selectedAccountID }) ?? accounts.first {
            return accountDisplayName(account, language: language)
        }
        return AppLocalization.string("Default Account", language: language)
    }

    var body: some View {
        Button {
            isShowingManager = true
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "wallet.pass.fill")
                    .foregroundStyle(AppTheme.ink)
                    .frame(width: 24)
                VStack(alignment: .leading, spacing: 3) {
                    Text(selectedName)
                        .font(.body)
                        .foregroundStyle(AppTheme.ink)
                        .lineLimit(1)
                    Text("\(entryCount) entries")
                        .font(.caption)
                        .foregroundStyle(AppTheme.muted)
                }
                Spacer()
                Image(systemName: "gearshape")
                    .foregroundStyle(AppTheme.muted)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Manage Accounts")
        .navigationDestination(isPresented: $isShowingManager) {
            AccountManagerView(selectedAccountID: $selectedAccountID)
        }
        .onAppear(perform: repairSelection)
        .onChange(of: accounts.map(\.id)) { _, _ in repairSelection() }
    }

    private func repairSelection() {
        guard let first = accounts.first,
              !accounts.contains(where: { $0.id == selectedAccountID }) else { return }
        selectedAccountID = first.id
    }
}

private struct AccountManagerRow: View {
    let name: String
    let entryCount: Int
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "wallet.pass.fill")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(isSelected ? AppTheme.brandDark : AppTheme.muted)
                .frame(width: 40, height: 40)
                .background(
                    isSelected ? AppTheme.brandSoft : AppTheme.background,
                    in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                )

            VStack(alignment: .leading, spacing: 3) {
                Text(name)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(AppTheme.ink)
                    .lineLimit(1)
                Text("\(entryCount) entries")
                    .font(.caption)
                    .foregroundStyle(AppTheme.muted)
            }

            Spacer(minLength: 8)

            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .font(.title3)
                .foregroundStyle(isSelected ? AppTheme.brand : AppTheme.muted.opacity(0.45))
        }
        .padding(12)
        .contentShape(Rectangle())
        .themedPanel(cornerRadius: 12)
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(isSelected ? AppTheme.brand.opacity(0.55) : Color.clear, lineWidth: 1.25)
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

struct AccountManagerView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.appLanguage) private var language
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
                        AccountManagerRow(
                            name: accountDisplayName(account, language: language),
                            entryCount: entryCount(for: account.id),
                            isSelected: account.id == selectedAccountID
                        )
                    }
                    .buttonStyle(.plain)
                    .listRowInsets(EdgeInsets(top: 5, leading: 16, bottom: 5, trailing: 16))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
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
        .themedForm()
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
                Text("This permanently deletes \(entryCount(for: account.id)) entries in \(accountDisplayName(account, language: language)).")
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
