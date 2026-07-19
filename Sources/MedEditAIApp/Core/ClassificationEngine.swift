import Foundation

enum ClassificationEngine {
    static func flattenPaths(in scheme: ClassificationScheme) -> [String] {
        scheme.items.flatMap { flatten(node: $0, prefix: []) }
    }

    static func buildTree(from rows: [[String]]) -> ClassificationScheme {
        let filteredRows = rows.filter { !$0.allSatisfy { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty } }
        guard filteredRows.count > 1 else {
            return ClassificationScheme(name: "Empty", type: .topic, isHierarchical: true, items: [])
        }

        let headers = filteredRows[0]
        let topicIndex = headers.firstIndex(where: { normalize($0) == normalize("主题") }) ?? 0
        let secondaryIndex = headers.firstIndex(where: { normalize($0) == normalize("次级菜单") }) ?? 1
        let tertiaryIndex = headers.firstIndex(where: { normalize($0) == normalize("三级菜单") }) ?? 2
        let quaternaryIndex = headers.firstIndex(where: { normalize($0) == normalize("四级菜单") }) ?? 3
        let presentationIndex = headers.firstIndex(where: { normalize($0) == normalize("呈现方式") })
        let noteIndex = headers.firstIndex(where: { normalize($0) == normalize("文献备注") })

        let roots = buildRoots(
            rows: filteredRows.dropFirst(),
            topicIndex: topicIndex, secondaryIndex: secondaryIndex,
            tertiaryIndex: tertiaryIndex, quaternaryIndex: quaternaryIndex,
            presentationIndex: presentationIndex, noteIndex: noteIndex
        )
        return ClassificationScheme(name: "Imported Scheme", type: .topic, isHierarchical: true, items: deduplicate(roots))
    }

    /// 按用户在导入确认界面指定的列角色（"topic"/"secondary"/"tertiary"/"quaternary"/"presentation"/"note"）构建四级主题树，
    /// 而非仅依赖固定表头名称自动识别，用于支持“用户导入 Excel 后自行指定列名对应的分类层级”。
    /// `columnRoles` 为 表头文本 -> 角色 key 的映射；未出现在映射中的列会被忽略。
    static func buildTree(from rows: [[String]], columnRoles: [String: String]) -> ClassificationScheme {
        let filteredRows = rows.filter { !$0.allSatisfy { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty } }
        guard filteredRows.count > 1 else {
            return ClassificationScheme(name: "Empty", type: .topic, isHierarchical: true, items: [])
        }
        let headers = filteredRows[0]
        func index(for role: String) -> Int? { headers.firstIndex(where: { columnRoles[$0] == role }) }

        let roots = buildRoots(
            rows: filteredRows.dropFirst(),
            topicIndex: index(for: "topic") ?? -1,
            secondaryIndex: index(for: "secondary") ?? -1,
            tertiaryIndex: index(for: "tertiary") ?? -1,
            quaternaryIndex: index(for: "quaternary") ?? -1,
            presentationIndex: index(for: "presentation"),
            noteIndex: index(for: "note")
        )
        return ClassificationScheme(name: "Imported Scheme", type: .topic, isHierarchical: true, items: deduplicate(roots))
    }

    private static func buildRoots(
        rows: ArraySlice<[String]>,
        topicIndex: Int, secondaryIndex: Int, tertiaryIndex: Int, quaternaryIndex: Int,
        presentationIndex: Int?, noteIndex: Int?
    ) -> [ClassificationNode] {
        var roots: [ClassificationNode] = []
        for row in rows {
            let topic = value(at: topicIndex, in: row)
            let secondary = value(at: secondaryIndex, in: row)
            let tertiary = value(at: tertiaryIndex, in: row)
            let quaternary = value(at: quaternaryIndex, in: row)
            let presentation = presentationIndex.flatMap { value(at: $0, in: row) }
            let note = noteIndex.flatMap { value(at: $0, in: row) }

            guard !quaternary.isEmpty else { continue }
            roots.append(
                ClassificationNode(
                    title: topic,
                    level: 1,
                    children: [
                        ClassificationNode(
                            title: secondary,
                            level: 2,
                            children: [
                                ClassificationNode(
                                    title: tertiary,
                                    level: 3,
                                    children: [
                                        ClassificationNode(title: quaternary, level: 4, presentation: presentation, note: note)
                                    ]
                                )
                            ]
                        )
                    ]
                )
            )
        }
        return roots
    }

    static func classifyStudyDesign(in text: String, customTerms: [String] = []) -> StudyDesignResult {
        let normalized = normalize(text)
        let customNormalized = customTerms.map(normalize)

        for custom in customTerms where normalized.contains(normalize(custom)) {
            return StudyDesignResult(design: custom, evidenceLevel: "自定义", confidence: 0.98)
        }

        if normalized.contains("meta") || normalized.contains("systematicreview") {
            return StudyDesignResult(design: "系统评价/Meta 分析", evidenceLevel: "高", confidence: 0.97)
        }
        if normalized.contains("randomized") || normalized.contains("randomised") || normalized.contains("rct") {
            return StudyDesignResult(design: "随机对照试验", evidenceLevel: "高", confidence: 0.95)
        }
        if normalized.contains("cohort") {
            return StudyDesignResult(design: "队列研究", evidenceLevel: "中高", confidence: 0.93)
        }
        if normalized.contains("casecontrol") || normalized.contains("case-control") {
            return StudyDesignResult(design: "病例对照研究", evidenceLevel: "中", confidence: 0.92)
        }
        if normalized.contains("crosssectional") || normalized.contains("cross-sectional") {
            return StudyDesignResult(design: "横断面研究", evidenceLevel: "中", confidence: 0.91)
        }
        if normalized.contains("case report") || normalized.contains("case series") {
            return StudyDesignResult(design: normalized.contains("case series") ? "病例系列" : "病例报告", evidenceLevel: "低", confidence: 0.9)
        }
        if normalized.contains("animal") || normalized.contains("goat") || normalized.contains("model") {
            return StudyDesignResult(design: "动物实验", evidenceLevel: "实验", confidence: 0.9)
        }
        if normalized.contains("editorial") || normalized.contains("commentary") {
            return StudyDesignResult(design: "社论", evidenceLevel: "低", confidence: 0.88)
        }

        return StudyDesignResult(design: "综述", evidenceLevel: "默认", confidence: 0.75)
    }

    /// 仅依据用户自定义研究类型词条做本地关键词匹配（不含内置英文关键词启发式，不给默认“综述”兜底）。
    /// 用于 AI 加工流程：命中则直接采用（无需联网/调用 AI）；未命中（或未配置自定义词条）返回 nil，交由上层决定是否调用 AI 推断或留空。
    static func matchCustomStudyTerm(in text: String, customTerms: [String]) -> StudyDesignResult? {
        let normalized = normalize(text)
        for custom in customTerms {
            let trimmed = custom.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty, normalized.contains(normalize(trimmed)) else { continue }
            return StudyDesignResult(design: trimmed, evidenceLevel: "自定义", confidence: 0.98)
        }
        return nil
    }

    static func findNode(in scheme: ClassificationScheme, title: String) -> ClassificationNode? {
        for node in scheme.items {
            if let found = find(node: node, title: title) {
                return found
            }
        }
        return nil
    }

    private static func flatten(node: ClassificationNode, prefix: [String]) -> [String] {
        let nextPrefix = prefix + [node.title]
        guard !node.children.isEmpty else { return [nextPrefix.joined(separator: " > ")] }
        return node.children.flatMap { flatten(node: $0, prefix: nextPrefix) }
    }

    private static func deduplicate(_ nodes: [ClassificationNode]) -> [ClassificationNode] {
        var seen: Set<String> = []
        var output: [ClassificationNode] = []
        for node in nodes {
            let path = flatten(node: node, prefix: []).joined(separator: "|")
            if seen.insert(path).inserted {
                output.append(node)
            }
        }
        return output
    }

    private static func find(node: ClassificationNode, title: String) -> ClassificationNode? {
        if normalize(node.title) == normalize(title) {
            return node
        }
        for child in node.children {
            if let found = find(node: child, title: title) { return found }
        }
        return nil
    }

    private static func value(at index: Int, in row: [String]) -> String {
        guard index >= 0, index < row.count else { return "" }
        return row[index].trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func normalize(_ text: String) -> String {
        text.lowercased()
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: "_", with: "")
    }
}
