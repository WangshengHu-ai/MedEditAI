import Foundation

/// 统一的导入/导出门面：连接列映射、XLSX/CSV 读写、PPTX 生成。
enum DocumentService {
    static let canonicalRequired: Set<String> = ["titleEN"]

    // MARK: - Import

    static func importArticles(from url: URL) throws -> [ArticleDraft] {
        articles(from: try readRows(from: url))
    }

    /// 读取 xlsx/csv 为二维字符串数组（供分析与映射确认复用）。
    static func readRows(from url: URL) throws -> [[String]] {
        switch url.pathExtension.lowercased() {
        case "xlsx":
            return try XLSXReader.read(url: url)
        case "csv":
            return CSVEngine.parse(try String(contentsOf: url, encoding: .utf8))
        default:
            throw ArchiveError.toolFailed("不支持的文件类型：\(url.pathExtension)")
        }
    }

    static func articles(from rows: [[String]]) -> [ArticleDraft] {
        guard let headerIndex = rows.firstIndex(where: { row in
            row.contains(where: { $0.contains("标题") || $0.lowercased().contains("title") })
        }) else { return [] }

        let headers = rows[headerIndex]
        let mapping = ColumnMappingEngine.buildImportMapping(from: headers, requiredFields: canonicalRequired)
        return articles(fromRows: rows, headerIndex: headerIndex, mapping: mapping)
    }

    /// 使用明确的「源列名 → 规范字段」映射生成草稿（供确认界面使用）。
    static func articles(fromRows rows: [[String]], headerIndex: Int, mapping: [String: String]) -> [ArticleDraft] {
        guard rows.indices.contains(headerIndex) else { return [] }
        let headers = rows[headerIndex]

        var drafts: [ArticleDraft] = []
        for row in rows.dropFirst(headerIndex + 1) {
            guard row.contains(where: { !$0.trimmingCharacters(in: .whitespaces).isEmpty }) else { continue }
            var record: [String: String] = [:]
            for (columnIndex, header) in headers.enumerated() where columnIndex < row.count {
                if let canonical = mapping[header] {
                    record[canonical] = row[columnIndex]
                }
            }
            guard let title = record["titleEN"], !title.trimmingCharacters(in: .whitespaces).isEmpty else { continue }
            drafts.append(makeDraft(from: record))
        }
        return drafts
    }

    static func makeDraft(from record: [String: String]) -> ArticleDraft {
        ArticleDraft(
            topic: record["topic"] ?? record["topicCategories"] ?? "未分类",
            titleEN: record["titleEN"] ?? "",
            titleCN: record["titleCN"] ?? "",
            abstractEN: record["abstractEN"] ?? "",
            abstractCN: record["abstractCN"] ?? "",
            citation: record["citation"] ?? "",
            authors: record["authors"] ?? "",
            date: record["date"] ?? "",
            studyType: record["studyDesign"] ?? "",
            journal: record["journal"] ?? "",
            impactFactor: record["impactFactor"],
            quartile: record["quartile"],
            pmid: record["pmid"],
            url: record["url"] ?? record["abstractLink"],
            confidence: 1.0,
            product: "",
            evidence: "",
            note: "由导入文件创建",
            keywords: record["keywords"]
        )
    }

    // MARK: - IF dataset import

    static func importImpactFactors(from url: URL) throws -> [String: String] {
        let rows: [[String]]
        switch url.pathExtension.lowercased() {
        case "xlsx": rows = try XLSXReader.read(url: url)
        case "csv": rows = CSVEngine.parse(try String(contentsOf: url, encoding: .utf8))
        default: throw ArchiveError.toolFailed("不支持的文件类型：\(url.pathExtension)")
        }
        return impactFactorTable(from: rows)
    }

    static func impactFactorTable(from rows: [[String]]) -> [String: String] {
        guard let header = rows.first else { return [:] }
        let journalIndex = header.firstIndex(where: { $0.contains("期刊") || $0.lowercased().contains("journal") }) ?? 0
        let ifIndex = header.firstIndex(where: { $0.uppercased().contains("IF") || $0.contains("影响因子") }) ?? 1

        var table: [String: String] = [:]
        for row in rows.dropFirst() where row.count > max(journalIndex, ifIndex) {
            let journal = row[journalIndex].lowercased().replacingOccurrences(of: " ", with: "")
            let value = row[ifIndex]
            if !journal.isEmpty { table[journal] = value }
        }
        return table
    }

    // MARK: - Export

    static func exportRows(articles: [ArticleDraft], template: ExportTemplate) -> [[String]] {
        var output: [[String]] = [template.columns]
        for (index, article) in articles.enumerated() {
            let row = ArticleProcessor.renderExportRow(article: article, sequence: index + 1)
            output.append(template.columns.map { row.values[$0] ?? "" })
        }
        return output
    }

    static func exportExcel(articles: [ArticleDraft], template: ExportTemplate, to url: URL) throws {
        try XLSXWriter.write(rows: exportRows(articles: articles, template: template), to: url)
    }

    static func exportCSV(articles: [ArticleDraft], template: ExportTemplate, to url: URL) throws {
        let text = CSVEngine.write(exportRows(articles: articles, template: template))
        try text.write(to: url, atomically: true, encoding: .utf8)
    }

    // MARK: - PPT

    static func slidePlaceholderValues(for article: ArticleDraft) -> [String: String] {
        [
            "{{topic}}": article.topic,
            "{{title_en}}": article.titleEN,
            "{{title_cn}}": article.titleCN,
            "{{authors}}": article.authors,
            "{{pub_date}}": article.date,
            "{{study_type}}": article.studyType,
            "{{journal}}": article.journal,
            "{{if}}": article.impactFactor ?? "",
            "{{abstract_cn}}": article.abstractCN,
            "{{citation}}": article.citation,
            "{{url}}": article.url ?? ""
        ]
    }

    static func exportPPTX(articles: [ArticleDraft], templateURL: URL, to url: URL) throws {
        let slides = articles.map(slidePlaceholderValues(for:))
        try PPTXTemplateFiller.fill(templateURL: templateURL, slides: slides, outputURL: url)
    }
}
