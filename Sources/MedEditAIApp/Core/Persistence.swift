import Foundation

struct StoredProject: Codable, Identifiable, Hashable {
    var id: UUID
    var name: String
    var colorHex: String
    var articles: [ArticleDraft]
    /// 项目自身的配置（Prompt/IF/研究类型/分类字典/PPT模板/导出列/占位符/自定义任务）。
    /// Optional 是为了兼容此前版本持久化的项目数据（没有该字段时按 nil 处理，由上层用默认项目配置迁移）。
    var config: ProjectConfig?

    init(id: UUID = UUID(), name: String, colorHex: String, articles: [ArticleDraft] = [], config: ProjectConfig? = nil) {
        self.id = id
        self.name = name
        self.colorHex = colorHex
        self.articles = articles
        self.config = config
    }
}

struct LibrarySnapshot: Codable {
    var projects: [StoredProject]
    var customStudyTerms: [String]
    var impactFactorByJournal: [String: String]
    var promptTemplates: PromptTemplates?
    var topicScheme: ClassificationScheme?
    var apiKey: String?
    var ncbiApiKey: String?
    /// 云端 LLM 的接口地址（OpenAI 兼容 /chat/completions）。可选，缺省时由上层回退到内置默认值。
    var llmEndpoint: String?
    /// 云端 LLM 使用的模型名（如 glm-4-flash / gpt-4o-mini）。可选，缺省时由上层回退到内置默认值。
    var llmModel: String?
    /// 新建项目时使用的默认项目配置模板；在设置页的“默认项目配置”区域编辑。
    var defaultProjectConfig: ProjectConfig?

    static let empty = LibrarySnapshot(projects: [], customStudyTerms: [], impactFactorByJournal: [:], promptTemplates: nil)

    init(
        projects: [StoredProject],
        customStudyTerms: [String],
        impactFactorByJournal: [String: String],
        promptTemplates: PromptTemplates? = nil,
        topicScheme: ClassificationScheme? = nil,
        apiKey: String? = nil,
        ncbiApiKey: String? = nil,
        llmEndpoint: String? = nil,
        llmModel: String? = nil,
        defaultProjectConfig: ProjectConfig? = nil
    ) {
        self.projects = projects
        self.customStudyTerms = customStudyTerms
        self.impactFactorByJournal = impactFactorByJournal
        self.promptTemplates = promptTemplates
        self.topicScheme = topicScheme
        self.apiKey = apiKey
        self.ncbiApiKey = ncbiApiKey
        self.llmEndpoint = llmEndpoint
        self.llmModel = llmModel
        self.defaultProjectConfig = defaultProjectConfig
    }
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
