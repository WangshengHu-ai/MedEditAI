import Foundation

enum PubMedQueryBuilder {
    static func buildQuery(keywords: [String], requiredTerms: [String] = [], yearRange: ClosedRange<Int>? = nil) -> String {
        let keywordClause = keywords.map { "\"\($0)\"[Title/Abstract]" }.joined(separator: " OR ")
        let requiredClause = requiredTerms.map { "\"\($0)\"[Title/Abstract]" }.joined(separator: " AND ")
        var clauses: [String] = []
        if !keywordClause.isEmpty { clauses.append("(\(keywordClause))") }
        if !requiredClause.isEmpty { clauses.append("(\(requiredClause))") }
        if let yearRange {
            clauses.append("(\(yearRange.lowerBound):\(yearRange.upperBound)[pdat])")
        }
        return clauses.joined(separator: " AND ")
    }
}

enum PubMedXMLParser {
    static func parse(_ xml: String) -> PubMedRecord? {
        parseArticles(xml).first
    }

    static func parseArticles(_ xml: String) -> [PubMedRecord] {
        guard let data = xml.data(using: .utf8) else { return [] }
        let delegate = ParserDelegate()
        let parser = XMLParser(data: data)
        parser.delegate = delegate
        guard parser.parse() else { return delegate.finishedRecords }
        return delegate.finishedRecords
    }

    private final class ParserDelegate: NSObject, XMLParserDelegate {
        private(set) var finishedRecords: [PubMedRecord] = []
        private var record = PubMedRecord(pmid: "", title: "", abstract: "", authors: [], journal: "", pubDate: "", doi: nil, keywords: [], meshTerms: [], references: [])
        private var currentElement = ""
        private var currentText = ""
        private var authorParts: [String] = []
        private var references: [String] = []
        private var keywords: [String] = []
        private var meshTerms: [String] = []
        private var elementStack: [String] = []
        private var inAuthor = false
        private var inReference = false
        private var hasArticle = false

        func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
            currentElement = elementName
            elementStack.append(elementName)
            currentText = ""
            if elementName == "PubmedArticle" {
                resetRecord()
                hasArticle = true
            }
            if elementName == "Author" {
                inAuthor = true
                authorParts = []
            }
            if elementName == "Reference" {
                inReference = true
                currentText = ""
            }
            if elementName == "Keyword" || elementName == "MeshHeading" {
                currentText = ""
            }
        }

        func parser(_ parser: XMLParser, foundCharacters string: String) {
            currentText += string
        }

        func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
            let text = currentText.trimmingCharacters(in: .whitespacesAndNewlines)
            let path = elementStack.joined(separator: "/")
            switch elementName {
            case "PMID" where record.pmid.isEmpty: record.pmid = text
            case "ArticleTitle": record.title = text
            case "AbstractText": record.abstract = record.abstract.isEmpty ? text : record.abstract + " " + text
            case "Title" where path.contains("Journal/Title"): record.journal = text
            case "PubDate": record.pubDate = text
            case "ELocationID": if currentText.contains("10.") { record.doi = text }
            case "Keyword": if !text.isEmpty { keywords.append(text) }
            case "DescriptorName": if !text.isEmpty { meshTerms.append(text) }
            case "Author":
                let name = authorParts.joined(separator: " ").trimmingCharacters(in: .whitespaces)
                if !name.isEmpty { record.authors.append(name) }
                inAuthor = false
                authorParts = []
            case "LastName", "ForeName":
                if inAuthor, !text.isEmpty {
                    authorParts.append(text)
                }
            case "Reference":
                if !text.isEmpty { references.append(text) }
                inReference = false
            case "PubmedArticle":
                commitRecord()
            default:
                break
            }
            currentText = ""
            if !elementStack.isEmpty {
                elementStack.removeLast()
            }
        }

        func parserDidEndDocument(_ parser: XMLParser) {
            if hasArticle, finishedRecords.isEmpty {
                commitRecord()
            } else if !hasArticle, !record.pmid.isEmpty || !record.title.isEmpty {
                commitRecord()
            }
        }

        private func resetRecord() {
            record = PubMedRecord(pmid: "", title: "", abstract: "", authors: [], journal: "", pubDate: "", doi: nil, keywords: [], meshTerms: [], references: [])
            keywords = []
            meshTerms = []
            references = []
            authorParts = []
        }

        private func commitRecord() {
            guard !record.pmid.isEmpty || !record.title.isEmpty else { return }
            record.keywords = keywords
            record.meshTerms = meshTerms
            record.references = references
            finishedRecords.append(record)
            resetRecord()
        }
    }
}
