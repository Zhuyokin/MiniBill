import SwiftUI
import UIKit

struct ShareImageLink: View {
    @Environment(\.appLanguage) private var language

    let payload: ShareCardPayload
    let title: LocalizedStringKey
    let systemImage: String

    @State private var renderedImage: UIImage?
    @State private var isRendering = false
    @State private var renderFailed = false

    private var renderKey: String {
        "\(payload.id)|\(language.rawValue)"
    }

    var body: some View {
        Group {
            if let renderedImage {
                let image = Image(uiImage: renderedImage)
                ShareLink(
                    item: image,
                    subject: Text("MiniBill"),
                    message: Text("Made locally with MiniBill"),
                    preview: SharePreview("MiniBill", image: Image("BrandIcon"))
                ) {
                    Label(title, systemImage: systemImage)
                }
            } else if renderFailed {
                Button(action: render) {
                    Label("Try Again", systemImage: "arrow.clockwise")
                }
            } else {
                Button(action: render) {
                    Label(title, systemImage: systemImage)
                        .foregroundStyle(.secondary)
                        .overlay(alignment: .trailing) {
                            if isRendering {
                                ProgressView()
                                    .controlSize(.small)
                                    .offset(x: 24)
                            }
                        }
                }
                .disabled(isRendering)
            }
        }
        .task(id: renderKey) {
            renderedImage = nil
            renderFailed = false
            try? await Task.sleep(nanoseconds: 250_000_000)
            guard !Task.isCancelled, renderedImage == nil else { return }
            render()
        }
        .alert("Image generation failed. Try again.", isPresented: $renderFailed) {
            Button("Try Again", action: render)
            Button("Cancel", role: .cancel) {}
        }
    }

    @MainActor
    private func render() {
        renderedImage = nil
        renderFailed = false
        isRendering = true
        defer { isRendering = false }

        do {
            renderedImage = try ShareImageService.render(payload, language: language)
        } catch {
            renderFailed = true
        }
    }
}
