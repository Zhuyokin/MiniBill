import SwiftUI
import UniformTypeIdentifiers

extension UTType {
    static let miniBillBackup = UTType(exportedAs: "com.masdey.minibill.backup", conformingTo: .json)
}

enum BackupFileFormat: String {
    case json
    case csv

    var contentType: UTType {
        switch self {
        case .json: .json
        case .csv: .commaSeparatedText
        }
    }

    var importContentTypes: [UTType] {
        switch self {
        case .json: [.miniBillBackup, .json]
        case .csv: [.commaSeparatedText]
        }
    }
}

struct BackupDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.miniBillBackup, .json, .commaSeparatedText] }
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
