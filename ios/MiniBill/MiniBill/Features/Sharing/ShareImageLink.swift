import SwiftUI
import UIKit

struct ShareImageLink: View {
    @Environment(\.appLanguage) private var language

    let payload: ShareCardPayload
    let title: LocalizedStringKey
    let systemImage: String
    let colorOnlyInRetro: Bool

    init(
        payload: ShareCardPayload,
        title: LocalizedStringKey,
        systemImage: String,
        colorOnlyInRetro: Bool = false
    ) {
        self.payload = payload
        self.title = title
        self.systemImage = systemImage
        self.colorOnlyInRetro = colorOnlyInRetro
    }

    @State private var isRendering = false
    @State private var renderFailed = false
    @State private var preparedShare: PreparedImageShare?

    var body: some View {
        Button(action: prepareAndShare) {
            Label(title, systemImage: systemImage)
                .overlay(alignment: .trailing) {
                    if isRendering {
                        ProgressView()
                            .controlSize(.small)
                            .offset(x: 24)
                    }
                }
        }
        .themedActionButton(colorOnlyInRetro: colorOnlyInRetro)
        .disabled(isRendering)
        .sheet(item: $preparedShare) { share in
            ActivityShareSheet(activityItems: [share.image])
        }
        .alert("Image generation failed. Try again.", isPresented: $renderFailed) {
            Button("Try Again", action: prepareAndShare)
            Button("Cancel", role: .cancel) {}
        }
    }

    private func prepareAndShare() {
        guard !isRendering else { return }
        isRendering = true
        renderFailed = false

        Task { @MainActor in
            await Task.yield()
            do {
                let image = try ShareImageService.render(payload, language: language)
                isRendering = false
                preparedShare = PreparedImageShare(image: image)
            } catch {
                isRendering = false
                renderFailed = true
            }
        }
    }
}

private struct PreparedImageShare: Identifiable {
    let id = UUID()
    let image: UIImage
}

private struct ActivityShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
