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
    @Environment(\.appInterfaceStyle) private var interfaceStyle
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
            if interfaceStyle == .modern {
                Image(systemName: "person.2.circle.fill")
                    .font(.body.weight(.semibold))
                    .frame(width: 32, height: 32)
                    .contentShape(Rectangle())
            } else {
                Image(systemName: "person.2.circle.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 32)
                    .background(SkeuomorphicPalette.primaryButtonStyle, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .stroke(Color.white.opacity(0.58), lineWidth: 1)
                            .padding(1)
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .stroke(Color.black.opacity(0.40), lineWidth: 1)
                    }
                    .shadow(color: .black.opacity(0.28), radius: 1.5, y: 1)
                    .contentShape(Rectangle())
            }
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
    @State private var editingAccount: LedgerAccountRecord?
    @State private var nameDraft = ""
    @State private var pendingDelete: LedgerAccountRecord?
    @State private var pendingDeleteEntries: [LedgerRecord] = []
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
                            pendingDelete = LedgerAccountMapper.record(from: account)
                            pendingDeleteEntries = entries.filter { $0.resolvedAccountID == account.id }
                                .map(LedgerEntryMapper.record)
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
                    editingAccount = nil
                    nameDraft = ""
                    isShowingNameEditor = true
                } label: {
                    Label("Add Account", systemImage: "plus")
                }
            }
        }
        .alert(editingAccount == nil ? "New Account" : "Rename Account", isPresented: $isShowingNameEditor) {
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
                let name = account.id == LedgerAccountDefaults.id && account.name == LedgerAccountDefaults.name
                    ? AppLocalization.string("Default Account", language: language) : account.name
                Text("This permanently deletes \(pendingDeleteEntries.count) entries in \(name).")
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
        editingAccount = LedgerAccountMapper.record(from: account)
        nameDraft = account.name
        isShowingNameEditor = true
    }

    private func saveName() {
        do {
            let name = try LedgerAccountName.normalized(nameDraft)
            let now = Date()
            let record = LedgerAccountRecord(
                id: editingAccount?.id ?? UUID(), name: name,
                createdAt: editingAccount?.createdAt ?? now, updatedAt: now
            )
            try LedgerMutationStore.apply(
                WatchLedgerMutation(ledgerID: UUID(), kind: .saveAccount, account: record, baseAccount: editingAccount),
                in: modelContext.container
            )
            if editingAccount == nil { selectedAccountID = record.id }
        } catch is WatchSyncRejection {
            errorMessage = AppLocalization.string("The ledger changed while you were editing. Close this screen, review the latest entries and accounts, then try again.")
        } catch let error as LedgerAccountNameError {
            errorMessage = error == .empty
                ? AppLocalization.string("Account name is required.")
                : AppLocalization.string("Account name must be 30 characters or fewer.")
        } catch {
            errorMessage = AppLocalization.string("Your accounts were not changed.")
        }
    }

    private func deletePendingAccount() {
        guard let account = pendingDelete else { return }
        do {
            try LedgerMutationStore.apply(
                WatchLedgerMutation(
                    ledgerID: UUID(), kind: .deleteAccount, account: account,
                    baseAccount: account, accountEntries: pendingDeleteEntries
                ),
                in: modelContext.container
            )
            pendingDelete = nil
            repairSelection()
        } catch is WatchSyncRejection {
            pendingDelete = nil
            errorMessage = AppLocalization.string("The ledger changed while you were editing. Close this screen, review the latest entries and accounts, then try again.")
        } catch {
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
