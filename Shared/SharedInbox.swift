import Darwin
import Foundation

/// 앱과 공유 확장이 App Group 컨테이너를 통해 주고받는 공유 사진 대기열.
enum SharedInbox {
    static let appGroup = "group.com.armsone.starmanager"

    struct Batch: Codable, Identifiable, Sendable, Equatable {
        let id: UUID
        var filenames: [String]
        let createdAt: Date
    }

    enum InboxError: LocalizedError {
        case appGroupUnavailable
        case invalidFilename
        case lockFailed(Int32)

        var errorDescription: String? {
            switch self {
            case .appGroupUnavailable: "Stargram 공동 보관함을 열 수 없습니다."
            case .invalidFilename: "안전하지 않은 공유 파일 이름입니다."
            case let .lockFailed(code): "공유 보관함을 잠글 수 없습니다. (\(code))"
            }
        }
    }

    static func containerURL() throws -> URL {
        guard let url = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroup) else {
            throw InboxError.appGroupUnavailable
        }
        let inbox = url.appendingPathComponent("Inbox", isDirectory: true)
        try FileManager.default.createDirectory(at: inbox, withIntermediateDirectories: true)
        return inbox
    }

    static func fileURL(named filename: String) throws -> URL {
        guard !filename.isEmpty,
              filename == (filename as NSString).lastPathComponent,
              filename != ".", filename != ".." else {
            throw InboxError.invalidFilename
        }
        let inbox = try containerURL().standardizedFileURL
        let candidate = inbox.appendingPathComponent(filename).standardizedFileURL
        guard candidate.deletingLastPathComponent() == inbox else { throw InboxError.invalidFilename }
        return candidate
    }

    /// 파일 복사가 끝난 뒤에만 호출한다. 프로세스 간 잠금 안에서 매니페스트를 원자적으로 갱신한다.
    static func commit(_ batch: Batch) throws {
        guard !batch.filenames.isEmpty else { return }
        try withExclusiveLock {
            var batches = try readManifestWithoutLock()
            batches.append(batch)
            try writeManifestWithoutLock(batches)
        }
    }

    static func pendingBatches() throws -> [Batch] {
        try withExclusiveLock { try readManifestWithoutLock() }
    }

    static func oldestPendingBatch() -> Batch? {
        (try? pendingBatches())?.min { $0.createdAt < $1.createdAt }
    }

    static func removeBatch(id: UUID) throws {
        try withExclusiveLock {
            var batches = try readManifestWithoutLock()
            batches.removeAll { $0.id == id }
            try writeManifestWithoutLock(batches)
        }
    }

    static func deleteFiles(for batch: Batch) {
        deleteUncommittedFiles(named: batch.filenames)
    }

    static func deleteUncommittedFiles(named filenames: [String]) {
        for filename in filenames {
            guard let url = try? fileURL(named: filename) else { continue }
            try? FileManager.default.removeItem(at: url)
        }
    }

    private static func manifestURL() throws -> URL {
        try containerURL().appendingPathComponent("manifest.json")
    }

    private static func lockURL() throws -> URL {
        try containerURL().appendingPathComponent("manifest.lock")
    }

    private static func readManifestWithoutLock() throws -> [Batch] {
        let url = try manifestURL()
        guard FileManager.default.fileExists(atPath: url.path) else { return [] }
        return try JSONDecoder().decode([Batch].self, from: Data(contentsOf: url))
    }

    private static func writeManifestWithoutLock(_ batches: [Batch]) throws {
        try JSONEncoder().encode(batches).write(to: manifestURL(), options: .atomic)
    }

    private static func withExclusiveLock<T>(_ body: () throws -> T) throws -> T {
        let descriptor = Darwin.open(try lockURL().path, O_CREAT | O_RDWR, S_IRUSR | S_IWUSR)
        guard descriptor >= 0 else { throw InboxError.lockFailed(errno) }
        defer { Darwin.close(descriptor) }
        guard flock(descriptor, LOCK_EX) == 0 else { throw InboxError.lockFailed(errno) }
        defer { flock(descriptor, LOCK_UN) }
        return try body()
    }
}
