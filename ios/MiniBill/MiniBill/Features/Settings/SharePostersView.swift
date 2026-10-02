import Photos
import SwiftUI
import UIKit

struct SharePostersView: View {
    @State private var selectedPosterIndex = 0
    @State private var isSaving = false
    @State private var alertMessage: LocalizedStringKey?
    @State private var sharedPoster: SharedPoster?

    private let appStoreURL = URL(string: "https://apps.apple.com/app/id6798309389")!
    private let posterTitles: [LocalizedStringKey] = [
        "Feature Overview", "Daily Ledger", "Quick Entry", "Statistics", "Backup",
    ]

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: 16) {
                    TabView(selection: $selectedPosterIndex) {
                        ForEach(posterTitles.indices, id: \.self) { index in
                            Image("SharePoster\(index)")
                                .resizable()
                                .scaledToFit()
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                                .shadow(color: .black.opacity(0.08), radius: 8, y: 4)
                                .padding(.horizontal, 8)
                                .padding(.bottom, 36)
                                .tag(index)
                                .accessibilityLabel(posterTitles[index])
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .always))
                    .indexViewStyle(.page(backgroundDisplayMode: .always))
                    .frame(height: max(300, geometry.size.height - 180))
                    .accessibilityIdentifier("share-app.posters")

                    Text("Swipe to choose a poster to save or share.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)

                    HStack(spacing: 12) {
                        Button(action: savePoster) {
                            HStack(spacing: 8) {
                                if isSaving {
                                    ProgressView()
                                } else {
                                    Image(systemName: "square.and.arrow.down")
                                }
                                Text("Save")
                            }
                            .frame(maxWidth: .infinity, minHeight: 32)
                        }
                        .themedSecondaryButton()
                        .disabled(isSaving)
                        .accessibilityIdentifier("share-app.save")

                        Button(action: sharePoster) {
                            Label("Share Poster", systemImage: "square.and.arrow.up")
                                .frame(maxWidth: .infinity, minHeight: 32)
                        }
                        .themedPrimaryButton()
                        .accessibilityIdentifier("share-app.share-poster")
                    }
                    .font(.subheadline.weight(.semibold))
                }
                .frame(maxWidth: 760)
                .padding(16)
                .frame(maxWidth: .infinity)
            }
        }
        .themedScreen()
        .navigationTitle("Share App")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                ShareLink(item: appStoreURL) {
                    Image(systemName: "square.and.arrow.up")
                }
                .accessibilityLabel("Share App Store Link")
                .accessibilityIdentifier("share-app.link")
            }
        }
        .sheet(item: $sharedPoster) { poster in
            PosterActivitySheet(image: poster.image)
        }
        .alert("Share App", isPresented: Binding(
            get: { alertMessage != nil },
            set: { if !$0 { alertMessage = nil } }
        )) {
            Button("OK", role: .cancel) { alertMessage = nil }
        } message: {
            if let alertMessage {
                Text(alertMessage)
            }
        }
    }

    private func sharePoster() {
        guard let image = UIImage(named: "SharePoster\(selectedPosterIndex)") else { return }
        sharedPoster = SharedPoster(image: image)
    }

    private func savePoster() {
        guard let image = UIImage(named: "SharePoster\(selectedPosterIndex)") else { return }
        isSaving = true
        Task { @MainActor in
            defer { isSaving = false }
            let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
            guard status == .authorized || status == .limited else {
                alertMessage = "Allow Photos access in Settings to save posters."
                return
            }
            do {
                try await PHPhotoLibrary.shared().performChanges {
                    PHAssetChangeRequest.creationRequestForAsset(from: image)
                }
                alertMessage = "Poster saved to Photos."
            } catch {
                alertMessage = "Could not save the poster. Try again."
            }
        }
    }
}

private struct SharedPoster: Identifiable {
    let id = UUID()
    let image: UIImage
}

private struct PosterActivitySheet: UIViewControllerRepresentable {
    let image: UIImage

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [image], applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
