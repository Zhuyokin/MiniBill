import SwiftUI

struct LaunchFailureView: View {
    let onRetry: () -> Void

    var body: some View {
        ContentUnavailableView {
            Label("Ledger unavailable", systemImage: "exclamationmark.lock")
        } description: {
            Text("Your existing ledger was not changed. Try opening it again.")
        } actions: {
            Button("Try Again", action: onRetry)
                .buttonStyle(.borderedProminent)
                .tint(AppTheme.brand)
        }
    }
}
