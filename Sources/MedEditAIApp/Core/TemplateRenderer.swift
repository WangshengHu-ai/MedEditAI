import Foundation

enum TemplateRenderer {
    static func renderSlide(from article: ArticleDraft, template: SlideTemplateDescriptor) -> RenderedSlide {
        let slide = ArticleProcessor.renderSlide(article: article)
        return slide
    }

    static func renderExportRows(from articles: [ArticleDraft]) -> [ExportRow] {
        articles.enumerated().map { index, article in
            ArticleProcessor.renderExportRow(article: article, sequence: index + 1)
        }
    }

    static func extractPlaceholders(from templateText: String) -> [String] {
        let pattern = #"\{\{[a-zA-Z0-9_]+\}\}"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let nsrange = NSRange(templateText.startIndex..., in: templateText)
        return regex.matches(in: templateText, range: nsrange).compactMap { match in
            guard let range = Range(match.range, in: templateText) else { return nil }
            return String(templateText[range])
        }
    }

    static func buildPlaceholderMap(from placeholders: [String], fields: [String]) -> [String: String] {
        var mapping: [String: String] = [:]
        for placeholder in placeholders {
            let normalized = placeholder
                .trimmingCharacters(in: CharacterSet(charactersIn: "{}"))
                .lowercased()
                .replacingOccurrences(of: "_", with: "")
            if let match = fields.first(where: { 
                let fLow = $0.lowercased().replacingOccurrences(of: "_", with: "")
                return fLow == normalized || fLow.contains(normalized) || normalized.contains(fLow)
            }) {
                mapping[placeholder] = match
            }
        }
        return mapping
    }
}
