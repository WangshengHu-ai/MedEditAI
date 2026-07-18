import Foundation

struct FieldMapping: Hashable, Codable {
    let sourceHeader: String
    let canonicalField: String
}

struct ImportTemplate: Hashable, Codable {
    let name: String
    let requiredFields: Set<String>
    let mappings: [FieldMapping]
}

struct ExportTemplate: Hashable, Codable {
    let name: String
    let columns: [String]
    let hyperlinkFields: Set<String>
}

struct ClassificationNode: Hashable, Codable, Identifiable {
    let id: UUID
    var title: String
    var level: Int
    var presentation: String?
    var note: String?
    var children: [ClassificationNode]

    init(id: UUID = UUID(), title: String, level: Int, presentation: String? = nil, note: String? = nil, children: [ClassificationNode] = []) {
        self.id = id
        self.title = title
        self.level = level
        self.presentation = presentation
        self.note = note
        self.children = children
    }
}

struct ClassificationScheme: Hashable, Codable, Identifiable {
    let id: UUID
    let name: String
    let type: ClassificationSchemeType
    let isHierarchical: Bool
    let items: [ClassificationNode]

    init(id: UUID = UUID(), name: String, type: ClassificationSchemeType, isHierarchical: Bool, items: [ClassificationNode]) {
        self.id = id
        self.name = name
        self.type = type
        self.isHierarchical = isHierarchical
        self.items = items
    }
}

enum ClassificationSchemeType: String, Codable {
    case studyDesign
    case topic
}

struct StudyDesignResult: Hashable, Codable {
    let design: String
    let evidenceLevel: String
    let confidence: Double
}

struct ArticleDraft: Hashable, Codable {
    var topic: String
    var titleEN: String
    var titleCN: String
    var abstractEN: String
    var abstractCN: String
    var citation: String
    var authors: String
    var date: String
    var studyType: String
    var journal: String
    var impactFactor: String?
    var quartile: String?
    var pmid: String?
    var url: String?
    var confidence: Double
    var product: String
    var evidence: String
    var note: String
}

struct PubMedRecord: Hashable, Codable {
    var pmid: String
    var title: String
    var abstract: String
    var authors: [String]
    var journal: String
    var pubDate: String
    var doi: String?
    var keywords: [String]
    var meshTerms: [String]
    var references: [String]
}

struct SlidePlaceholder: Hashable, Codable {
    let placeholder: String
    let canonicalField: String
}

struct SlideTemplateDescriptor: Hashable, Codable {
    let name: String
    let orientation: String
    let placeholderMappings: [SlidePlaceholder]
    let fieldOrder: [String]
}

struct RenderedSlide: Hashable, Codable {
    let topic: String
    let titleEN: String
    let titleCN: String
    let authors: String
    let date: String
    let studyType: String
    let journal: String
    let impactFactor: String
    let abstract: String
    let citation: String
    let url: String?
}

struct ExportRow: Hashable, Codable {
    let values: [String: String]
    let hyperlinks: [String: String]
}
