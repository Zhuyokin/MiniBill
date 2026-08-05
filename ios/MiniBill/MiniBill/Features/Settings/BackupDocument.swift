import SwiftUI
import UniformTypeIdentifiers

extension UTType {
    static let miniBillBackup = UTType(exportedAs: "com.masdey.minibill.backup", conformingTo: .json)
}

struct BackupDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.miniBillBackup, .json] }
    let data: Data

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.data = data
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
