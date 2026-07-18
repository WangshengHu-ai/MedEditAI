import Foundation
import SwiftUI
import AppKit
import UniformTypeIdentifiers

@MainActor
final class AppViewModel: ObservableObject {
    // MARK: - Navigation & selection
    @Published var selectedSection: AppSection? = .dashboard
    @Published var selectedProject: Project = SampleData.projects[0]
    @Published var selectedArticleID: String?
    @Published var selectedSlideIndex: Int = 0
    @Published var searchText: String = "pulsed field ablation AND atrial fibrillation"
    @Published var enabledFilters: Set<String> = ["近 90 天", "房颤", "综述"]
    @Published var tasks: [ProcessingTask] = SampleData.processingTasks
    @Published var progress: Double = 0.0
    @Published var toastMessage: String?
    @Published var isBusy: Bool = false

    // MARK: - Real data (source of truth)
    @Published private var drafts: [ArticleDraft] = []
    @Published var topicTreeNodes: [TopicNode] = SampleData.topicTree
    @Published var impactFactorByJournal: [String: String] = [:]
    @Published var apiKey: String = ""
    @Published var pptTemplateURL: URL?

    let customStudyTerms = ["综述", "社论", "动物实验", "土豆模型"]

    // MARK: - Static display data
    let stats = SampleData.stats
    let alerts = SampleData.alerts
    let quickActions = SampleData.quickActions
    let importMappings = SampleData.importMappings
    let exportMappings = SampleData.exportMappings
    let pptMappings = SampleData.pptMappings
    let queue = SampleData.queue
    let projects = SampleData.projects
    let searchFilters = SampleData.searchFilters

    // MARK: - Services
    private let store = LibraryStore()
    private let pubmed: PubMedFetching

    init(pubmed: PubMedFetching = PubMedService()) {
        self.pubmed = pubmed
        let snapshot = store.load()
        self.impactFactorByJournal = snapshot.impactFactorByJournal
        if let seeded = snapshot.projects.first(where: { !$0.articles.isEmpty }) {
            self.drafts = seeded.articles
        } else {
            self.drafts = SampleData.articles.map(Self.draft(from:))
        }
        self.selectedArticleID = articles.first?.id
    }

    // MARK: - Derived display
    var topicTree: [TopicNode] { topicTreeNodes }

    var articles: [Article] {
        drafts.enumerated().map { index, draft in
            let id = (draft.pmid?.isEmpty == false ? draft.pmid! : "row-\(index)")
            return Self.display(draft, id: id)
        }
    }

    var activeArticle: Article {
        selectedArticle ?? articles.first ?? Self.display(Self.draft(from: SampleData.articles[0]), id: "seed")
    }

    var selectedArticle: Article? {
        articles.first { $0.id == selectedArticleID } ?? articles.first
    }

    var pageTitle: String { selectedSection?.title ?? "MedEditAI" }

    // MARK: - Navigation actions
    func navigate(to section: AppSection) { selectedSection = section }

    func chooseProject(_ project: Project) {
        selectedProject = project
        showToast("已切换项目：\(project.name)")
    }

    func chooseArticle(_ article: Article) { selectedArticleID = article.id }

    func chooseSlide(index: Int) {
        selectedSlideIndex = index
        if articles.indices.contains(index) {
            selectedArticleID = articles[index].id
        }
    }

    func toggleTask(_ task: ProcessingTask) {
        guard let index = tasks.firstIndex(where: { $0.id == task.id }) else { return }
        tasks[index].isEnabled.toggle()
        showToast("\(tasks[index].title)已\(tasks[index].isEnabled ? "启用" : "关闭")")
    }

    func toggleFilter(_ filter: String) {
        if enabledFilters.contains(filter) { enabledFilters.remove(filter) } else { enabledFilters.insert(filter) }
    }

    // MARK: - Real: PubMed search + enrichment
    func runSearch() async {
        guard !isBusy else { return }
        isBusy = true
        progress = 0
        showToast("正在检索 PubMed…")
        defer { isBusy = false }
        do {
            let ids = try await pubmed.search(query: searchText, maxResults: 25)
            guard !ids.isEmpty else { showToast("未找到结果"); return }
            let records = try await pubmed.fetch(pmids: ids)
            let enriched = await enrichmentService().enrichBatch(records: records) { [weak self] progress in
                Task { @MainActor in self?.progress = progress.fraction }
            }
            drafts = enriched
            selectedArticleID = articles.first?.id
            persist()
            showToast("检索完成：入库 \(enriched.count) 篇")
        } catch {
            showToast("检索失败：\(error.localizedDescription)")
        }
    }

    func runEnrichment() async {
        guard !isBusy, !drafts.isEmpty else { return }
        isBusy = true
        progress = 0
        defer { isBusy = false }
        let records = drafts.map(Self.record(from:))
        let enriched = await enrichmentService().enrichBatch(records: records) { [weak self] progress in
            Task { @MainActor in self?.progress = progress.fraction }
        }
        drafts = enriched
        selectedArticleID = articles.first?.id
        persist()
        showToast("批处理完成：\(enriched.count) 篇已更新 AI 结果")
    }

    // MARK: - Real: import / export
    func importDocument() {
        guard let url = openPanel(extensions: ["xlsx", "csv"]) else { return }
        do {
            let imported = try DocumentService.importArticles(from: url)
            guard !imported.isEmpty else { showToast("未从文件解析到文献"); return }
            drafts = imported
            selectedArticleID = articles.first?.id
            persist()
            showToast("导入成功：\(imported.count) 篇")
        } catch {
            showToast("导入失败：\(error.localizedDescription)")
        }
    }

    func importImpactFactors() {
        guard let url = openPanel(extensions: ["xlsx", "csv"]) else { return }
        do {
            let table = try DocumentService.importImpactFactors(from: url)
            impactFactorByJournal = table
            reapplyImpactFactors()
            persist()
            showToast("已导入 IF 数据：\(table.count) 条")
        } catch {
            showToast("IF 导入失败：\(error.localizedDescription)")
        }
    }

    func importClassificationDictionary() {
        guard let url = openPanel(extensions: ["xlsx", "csv"]) else { return }
        do {
            let rows: [[String]]
            if url.pathExtension.lowercased() == "xlsx" {
                rows = try XLSXReader.read(url: url)
            } else {
                rows = CSVEngine.parse(try String(contentsOf: url, encoding: .utf8))
            }
            let scheme = ClassificationEngine.buildTree(from: rows)
            topicTreeNodes = Self.nodes(from: scheme)
            showToast("已导入分类字典：\(ClassificationEngine.flattenPaths(in: scheme).count) 条路径")
        } catch {
            showToast("分类字典导入失败：\(error.localizedDescription)")
        }
    }

    func chooseTemplate() {
        guard let url = openPanel(extensions: ["pptx"]) else { return }
        pptTemplateURL = url
        showToast("已选择 PPT 模板：\(url.lastPathComponent)")
    }

    func exportExcel() {
        guard !drafts.isEmpty else { showToast("暂无可导出的文献"); return }
        guard let url = savePanel(suggestedName: "MedEditAI-交付.xlsx") else { return }
        do {
            try DocumentService.exportExcel(articles: drafts, template: Self.deliveryTemplate, to: url)
            showToast("已导出 Excel 交付表")
        } catch {
            showToast("导出失败：\(error.localizedDescription)")
        }
    }

    func exportPPTX() {
        guard !drafts.isEmpty else { showToast("暂无可导出的文献"); return }
        guard let template = pptTemplateURL ?? openPanel(extensions: ["pptx"]) else {
            showToast("请先选择 onepage PPT 模板")
            return
        }
        pptTemplateURL = template
        guard let output = savePanel(suggestedName: "MedEditAI-onepage.pptx") else { return }
        do {
            try DocumentService.exportPPTX(articles: drafts, templateURL: template, to: output)
            showToast("已导出 onepage PPT")
        } catch {
            showToast("导出失败：\(error.localizedDescription)")
        }
    }

    // MARK: - Toast
    func showToast(_ message: String) {
        toastMessage = message
        Task {
            try? await Task.sleep(for: .seconds(2))
            if self.toastMessage == message { self.toastMessage = nil }
        }
    }

    // MARK: - Helpers
    private func enrichmentService() -> EnrichmentService {
        let provider: LLMProviding = apiKey.isEmpty ? LocalDeterministicLLM() : OpenAICompatibleLLM(apiKey: apiKey)
        return EnrichmentService(
            llm: provider,
            topicScheme: Self.scheme(from: topicTreeNodes),
            customStudyTerms: customStudyTerms,
            impactFactorByJournal: impactFactorByJournal
        )
    }

    private func reapplyImpactFactors() {
        drafts = drafts.map { draft in
            var updated = draft
            let key = draft.journal.lowercased().replacingOccurrences(of: " ", with: "")
            if let value = impactFactorByJournal[key] { updated.impactFactor = value }
            return updated
        }
    }

    private func persist() {
        try? store.save(
            LibrarySnapshot(
                projects: [StoredProject(name: selectedProject.name, colorHex: "#0E9F9F", articles: drafts)],
                customStudyTerms: customStudyTerms,
                impactFactorByJournal: impactFactorByJournal
            )
        )
    }

    private func openPanel(extensions: [String]) -> URL? {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = extensions.compactMap { UTType(filenameExtension: $0) }
        return panel.runModal() == .OK ? panel.url : nil
    }

    private func savePanel(suggestedName: String) -> URL? {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = suggestedName
        if let ext = suggestedName.split(separator: ".").last, let type = UTType(filenameExtension: String(ext)) {
            panel.allowedContentTypes = [type]
        }
        return panel.runModal() == .OK ? panel.url : nil
    }

    // MARK: - Static conversions
    static let deliveryTemplate = ExportTemplate(
        name: "PFA 交付 Excel",
        columns: ["主题", "序号", "标题", "摘要/内容简介详情链接", "作者", "发表日期", "研究类型", "期刊", "2025年IF", "PMID", "原文链接"],
        hyperlinkFields: ["原文链接", "摘要/内容简介详情链接"]
    )

    static func draft(from article: Article) -> ArticleDraft {
        ArticleDraft(
            topic: article.topic,
            titleEN: article.titleEN,
            titleCN: article.titleCN,
            abstractEN: article.abstractEN,
            abstractCN: article.abstractCN,
            citation: article.citation,
            authors: article.authors,
            date: article.date,
            studyType: article.studyType,
            journal: article.journal,
            impactFactor: article.impactFactor.isEmpty ? nil : article.impactFactor,
            quartile: article.quartile.isEmpty ? nil : article.quartile,
            pmid: article.pmid.isEmpty ? nil : article.pmid,
            url: article.url.isEmpty ? nil : article.url,
            confidence: article.confidence == .high ? 0.95 : article.confidence == .medium ? 0.78 : 0.6,
            product: article.product,
            evidence: article.evidence,
            note: article.note
        )
    }

    static func record(from draft: ArticleDraft) -> PubMedRecord {
        PubMedRecord(
            pmid: draft.pmid ?? "",
            title: draft.titleEN,
            abstract: draft.abstractEN,
            authors: draft.authors.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) },
            journal: draft.journal,
            pubDate: draft.date,
            doi: nil,
            keywords: [],
            meshTerms: [],
            references: []
        )
    }

    static func display(_ draft: ArticleDraft, id: String) -> Article {
        Article(
            id: id,
            topic: draft.topic,
            titleEN: draft.titleEN,
            titleCN: draft.titleCN,
            abstractEN: draft.abstractEN,
            abstractCN: draft.abstractCN,
            citation: draft.citation,
            authors: draft.authors,
            date: draft.date,
            studyType: draft.studyType,
            journal: draft.journal,
            impactFactor: draft.impactFactor ?? "",
            quartile: draft.quartile ?? "",
            pmid: draft.pmid ?? "",
            url: draft.url ?? "",
            confidence: level(draft.confidence),
            product: draft.product,
            evidence: draft.evidence,
            note: draft.note
        )
    }

    static func level(_ confidence: Double) -> ConfidenceLevel {
        confidence >= 0.85 ? .high : confidence >= 0.7 ? .medium : .low
    }

    static func scheme(from nodes: [TopicNode]) -> ClassificationScheme {
        ClassificationScheme(name: "主题分类", type: .topic, isHierarchical: true, items: nodes.map(classificationNode(from:)))
    }

    static func classificationNode(from node: TopicNode) -> ClassificationNode {
        ClassificationNode(title: node.title, level: node.level, children: node.children.map(classificationNode(from:)))
    }

    static func nodes(from scheme: ClassificationScheme) -> [TopicNode] {
        scheme.items.map(topicNode(from:))
    }

    static func topicNode(from node: ClassificationNode) -> TopicNode {
        TopicNode(title: node.title, level: node.level, count: node.children.isEmpty ? 0 : nil, children: node.children.map(topicNode(from:)))
    }
}
