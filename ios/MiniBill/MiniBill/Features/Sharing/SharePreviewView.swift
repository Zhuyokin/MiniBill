import SwiftUI

struct SharePreviewView: View {
    @Environment(\.dismiss) private var dismiss
    let payload: ShareCardPayload
    @State private var fileURL: URL?
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                GeometryReader { proxy in
                    card
                        .scaleEffect(min(proxy.size.width / 900, proxy.size.height / 1200))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .aspectRatio(3 / 4, contentMode: .fit)
                .background(Color(white: 0.9), in: RoundedRectangle(cornerRadius: 16))

                if let fileURL {
                    ShareLink(item: fileURL, preview: SharePreview("MiniBill", image: Image(systemName: "book.closed.fill"))) {
                        Label("Open Share Sheet", systemImage: "square.and.arrow.up")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(AppTheme.brand)
                } else if let errorMessage {
                    Text(errorMessage).foregroundStyle(.red)
                    Button("Try Again", action: render)
                } else {
                    ProgressView("Generating image…")
                }
            }
            .padding(16)
            .background(AppTheme.background)
            .navigationTitle("Share Preview")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } } }
            .task { render() }
        }
    }

    @ViewBuilder private var card: some View {
        switch payload {
        case .month(let value): MonthlyShareCard(payload: value)
        case .entry(let value): EntryShareCard(payload: value)
        }
    }

    private func render() {
        do {
            fileURL = try ShareImageService.render(payload)
            errorMessage = nil
        } catch {
            fileURL = nil
            errorMessage = String(localized: "Image generation failed. Try again.")
        }
    }
}
