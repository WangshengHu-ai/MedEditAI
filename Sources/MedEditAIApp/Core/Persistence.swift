import Foundation

struct StoredProject: Codable, Identifiable, Hashable {
    var id: UUID
    var name: String
    var colorHex: String
    var articles: [ArticleDraft]

    init(id: UUID = UUID(), name: String, colorHex: String, articles: [ArticleDraft] = []) {
        self.id = id
        self.name = name
        self.colorHex = colorHex
        self.articles = articles
    }
}

struct LibrarySnapshot: Codable {
    var projects: [StoredProject]
    var customStudyTerms: [String]
    var impactFactorByJournal: [String: String]

    static let empty = LibrarySnapshot(projects: [], customStudyTerms: [], impactFactorByJournal: [:])
}

/// 真实本地持久化：将文献库以 JSON 写入 Application Support，离线可用、可备份。
final class LibraryStore {
    private let fileURL: URL
    private let queue = DispatchQueue(label: "com.wangshenghu.MedEditAI.store")

    init(fileURL: URL? = nil) {
        if let fileURL {
            self.fileURL = fileURL
        } else {
            let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            let dir = base.appendingPathComponent("MedEditAI", isDirectory: true)
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            self.fileURL = dir.appendingPathComponent("library.json")
        }
    }

    func load() -> LibrarySnapshot {
        queue.sync {
            guard let data = try? Data(contentsOf: fileURL) else { return .empty }
            return (try? JSONDecoder().decode(LibrarySnapshot.self, from: data)) ?? .empty
        }
    }

    func save(_ snapshot: LibrarySnapshot) throws {
        try queue.sync {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(snapshot)
            try data.write(to: fileURL, options: .atomic)
        }
    }

    func upsertProject(_ project: StoredProject) throws {
        var snapshot = load()
        if let index = snapshot.projects.firstIndex(where: { $0.id == project.id }) {
            snapshot.projects[index] = project
        } else {
            snapshot.projects.append(project)
        }
        try save(snapshot)
    }

    func replaceArticles(_ articles: [ArticleDraft], inProjectNamed name: String) throws {
        var snapshot = load()
        if let index = snapshot.projects.firstIndex(where: { $0.name == name }) {
            snapshot.projects[index].articles = articles
        } else {
            snapshot.projects.append(StoredProject(name: name, colorHex: "#0E9F9F", articles: articles))
        }
        try save(snapshot)
    }

    var storageURL: URL { fileURL }
}
