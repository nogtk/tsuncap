import Foundation

protocol BookmarkDataStore {
    func loadBookmarkData(forKey key: String) -> Data?
    func saveBookmarkData(_ data: Data, forKey key: String)
    func removeBookmarkData(forKey key: String)
}

struct UserDefaultsBookmarkStore: BookmarkDataStore {
    private let userDefaults: UserDefaults

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    func loadBookmarkData(forKey key: String) -> Data? {
        userDefaults.data(forKey: key)
    }

    func saveBookmarkData(_ data: Data, forKey key: String) {
        userDefaults.set(data, forKey: key)
    }

    func removeBookmarkData(forKey key: String) {
        userDefaults.removeObject(forKey: key)
    }
}

enum FolderBookmarkControllerError: Error {
    case bookmarkMissing
    case failedToCreateBookmark(underlying: Error)
    case failedToResolveBookmark(underlying: Error)
    case failedToWrite(underlying: Error)
}

extension FolderBookmarkControllerError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .bookmarkMissing:
            return "保存済みのフォルダブックマークが見つかりません。"
        case let .failedToCreateBookmark(underlying):
            return "フォルダのブックマーク作成に失敗しました: \(underlying.localizedDescription)"
        case let .failedToResolveBookmark(underlying):
            return "保存済みブックマークの復元に失敗しました: \(underlying.localizedDescription)"
        case let .failedToWrite(underlying):
            return "フォルダへの書き込みに失敗しました: \(underlying.localizedDescription)"
        }
    }
}

final class FolderBookmarkController {
    private enum Constants {
        static let bookmarkKey = "com.tsuncap.folderBookmark.securityScope"
    }

    private let dataStore: BookmarkDataStore
    private var cachedResolvedURL: URL?
    private let timestampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return formatter
    }()

    init(dataStore: BookmarkDataStore = UserDefaultsBookmarkStore()) {
        self.dataStore = dataStore
    }

    func saveBookmark(for folderURL: URL) throws {
        let shouldStop = folderURL.startAccessingSecurityScopedResource()
        defer {
            if shouldStop {
                folderURL.stopAccessingSecurityScopedResource()
            }
        }

        do {
            let data = try folderURL.bookmarkData(
                options: [],
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
            dataStore.saveBookmarkData(data, forKey: Constants.bookmarkKey)
            cachedResolvedURL = try resolveBookmark(from: data)
        } catch {
            throw FolderBookmarkControllerError.failedToCreateBookmark(underlying: error)
        }
    }

    @discardableResult
    func resolveBookmark() throws -> URL? {
        if let cachedResolvedURL {
            return cachedResolvedURL
        }

        guard let data = dataStore.loadBookmarkData(forKey: Constants.bookmarkKey) else {
            return nil
        }

        let resolved = try resolveBookmark(from: data)
        cachedResolvedURL = resolved
        return resolved
    }

    func clearBookmark() {
        cachedResolvedURL = nil
        dataStore.removeBookmarkData(forKey: Constants.bookmarkKey)
    }

    func accessFolder<T>(_ work: (URL) throws -> T) throws -> T {
        guard let folderURL = try resolveBookmark() else {
            throw FolderBookmarkControllerError.bookmarkMissing
        }

        let started = folderURL.startAccessingSecurityScopedResource()
        defer {
            if started {
                folderURL.stopAccessingSecurityScopedResource()
            }
        }

        return try work(folderURL)
    }

    func createTestFile(
        prefix: String = "tsuncap-write-check",
        contents: String? = nil,
        fileExtension: String = "txt"
    ) throws -> URL {
        let resolvedContents: String
        if let contents {
            resolvedContents = contents
        } else {
            let timestamp = timestampFormatter.string(from: Date())
            resolvedContents = "Tsuncap write check executed at \(timestamp)."
        }

        return try accessFolder { folderURL in
            let timestamp = timestampFormatter.string(from: Date())
            let identifier = UUID().uuidString.prefix(8)
            let fileName = "\(prefix)-\(timestamp)-\(identifier).\(fileExtension)"
            let fileURL = folderURL.appendingPathComponent(fileName, isDirectory: false)

            do {
                try resolvedContents.write(to: fileURL, atomically: true, encoding: .utf8)
            } catch {
                throw FolderBookmarkControllerError.failedToWrite(underlying: error)
            }

            return fileURL
        }
    }

    private func resolveBookmark(from data: Data) throws -> URL {
        do {
            var isStale = false
            let resolvedURL = try URL(
                resolvingBookmarkData: data,
                options: [.withoutUI],
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )

            if isStale {
                let refreshed = try resolvedURL.bookmarkData(
                    options: [],
                    includingResourceValuesForKeys: nil,
                    relativeTo: nil
                )
                dataStore.saveBookmarkData(refreshed, forKey: Constants.bookmarkKey)
            }

            return resolvedURL
        } catch {
            throw FolderBookmarkControllerError.failedToResolveBookmark(underlying: error)
        }
    }
}
