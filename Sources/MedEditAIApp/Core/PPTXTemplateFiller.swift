import Foundation

struct SlideRelationship: Hashable {
    let id: String
    let type: String
    let target: String
}

enum PPTXError: Error, LocalizedError {
    case templateSlideNotFound
    case malformedTemplate(String)

    var errorDescription: String? {
        switch self {
        case .templateSlideNotFound: "模板中未找到样板幻灯片"
        case .malformedTemplate(let message): "模板结构异常：\(message)"
        }
    }
}

/// 方案 C：以用户自备的 onepage .pptx 为模板，按文献批量填充占位符生成多页幻灯。
enum PPTXTemplateFiller {
    /// slides: 每个元素是一页幻灯的 占位符→值 字典（如 ["{{title_en}}": "..."]）。
    static func fill(templateURL: URL, slides: [[String: String]], outputURL: URL) throws {
        let temp = FileManager.default.temporaryDirectory.appendingPathComponent("pptxfill-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: temp) }
        try ZipArchiver.unzip(archive: templateURL, to: temp)

        let presentationRelsURL = temp.appendingPathComponent("ppt/_rels/presentation.xml.rels")
        let presentationURL = temp.appendingPathComponent("ppt/presentation.xml")
        let contentTypesURL = temp.appendingPathComponent("[Content_Types].xml")

        let relsXML = try String(contentsOf: presentationRelsURL, encoding: .utf8)
        let relationships = parseRelationships(relsXML)
        guard let templateSlideRel = relationships.first(where: { $0.type.hasSuffix("/slide") }) else {
            throw PPTXError.templateSlideNotFound
        }

        let templateSlidePath = "ppt/" + templateSlideRel.target.replacingOccurrences(of: "../", with: "")
        let templateSlideURL = temp.appendingPathComponent(templateSlidePath)
        let templateSlideXML = try String(contentsOf: templateSlideURL, encoding: .utf8)
        let templateSlideName = URL(fileURLWithPath: templateSlidePath).lastPathComponent
        let templateSlideRelsURL = templateSlideURL.deletingLastPathComponent()
            .appendingPathComponent("_rels/\(templateSlideName).rels")
        let templateSlideRelsXML = (try? String(contentsOf: templateSlideRelsURL, encoding: .utf8)) ?? defaultSlideRels()

        let slidesDir = temp.appendingPathComponent("ppt/slides")
        try? FileManager.default.removeItem(at: slidesDir)
        try FileManager.default.createDirectory(at: slidesDir.appendingPathComponent("_rels"), withIntermediateDirectories: true)

        for (index, values) in slides.enumerated() {
            let slideNumber = index + 1
            let filledXML = replacePlaceholders(in: templateSlideXML, with: values)
            try filledXML.write(to: slidesDir.appendingPathComponent("slide\(slideNumber).xml"), atomically: true, encoding: .utf8)
            try templateSlideRelsXML.write(
                to: slidesDir.appendingPathComponent("_rels/slide\(slideNumber).xml.rels"),
                atomically: true,
                encoding: .utf8
            )
        }

        let nonSlideRels = relationships.filter { !$0.type.hasSuffix("/slide") }
        let rebuiltRels = buildPresentationRels(nonSlideRels: nonSlideRels, slideCount: slides.count)
        try rebuiltRels.xml.write(to: presentationRelsURL, atomically: true, encoding: .utf8)

        let presentationXML = try String(contentsOf: presentationURL, encoding: .utf8)
        let updatedPresentation = replaceSlideIdList(in: presentationXML, slideRelIds: rebuiltRels.slideRelIds)
        try updatedPresentation.write(to: presentationURL, atomically: true, encoding: .utf8)

        let contentTypesXML = try String(contentsOf: contentTypesURL, encoding: .utf8)
        let updatedContentTypes = ensureSlideContentTypes(in: contentTypesXML, slideCount: slides.count)
        try updatedContentTypes.write(to: contentTypesURL, atomically: true, encoding: .utf8)

        try ZipArchiver.zip(directory: temp, to: outputURL)
    }

    // MARK: - Pure, testable helpers

    static func replacePlaceholders(in xml: String, with values: [String: String]) -> String {
        var result = xml
        for (placeholder, value) in values {
            result = result.replacingOccurrences(of: placeholder, with: escape(value))
        }
        return result
    }

    static func parseRelationships(_ xml: String) -> [SlideRelationship] {
        var relationships: [SlideRelationship] = []
        let pattern = #"<Relationship\s+[^>]*?/>"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let range = NSRange(xml.startIndex..., in: xml)
        for match in regex.matches(in: xml, range: range) {
            guard let matchRange = Range(match.range, in: xml) else { continue }
            let tag = String(xml[matchRange])
            let id = attribute("Id", in: tag)
            let type = attribute("Type", in: tag)
            let target = attribute("Target", in: tag)
            if !id.isEmpty {
                relationships.append(SlideRelationship(id: id, type: type, target: target))
            }
        }
        return relationships
    }

    static func buildPresentationRels(nonSlideRels: [SlideRelationship], slideCount: Int) -> (xml: String, slideRelIds: [String]) {
        var maxId = 0
        for rel in nonSlideRels {
            if rel.id.hasPrefix("rId"), let value = Int(rel.id.dropFirst(3)) {
                maxId = max(maxId, value)
            }
        }

        var slideRelIds: [String] = []
        var body = ""
        for rel in nonSlideRels {
            body += "<Relationship Id=\"\(rel.id)\" Type=\"\(rel.type)\" Target=\"\(rel.target)\"/>"
        }
        for index in 0..<slideCount {
            maxId += 1
            let relId = "rId\(maxId)"
            slideRelIds.append(relId)
            body += "<Relationship Id=\"\(relId)\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/slide\" Target=\"slides/slide\(index + 1).xml\"/>"
        }

        let xml = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">\(body)</Relationships>
        """
        return (xml, slideRelIds)
    }

    static func replaceSlideIdList(in presentationXML: String, slideRelIds: [String]) -> String {
        var entries = ""
        var slideId = 256
        for relId in slideRelIds {
            entries += "<p:sldId id=\"\(slideId)\" r:id=\"\(relId)\"/>"
            slideId += 1
        }
        let newList = "<p:sldIdLst>\(entries)</p:sldIdLst>"

        if let range = presentationXML.range(of: #"<p:sldIdLst>.*?</p:sldIdLst>"#, options: .regularExpression) {
            return presentationXML.replacingCharacters(in: range, with: newList)
        }
        if let range = presentationXML.range(of: "<p:sldIdLst/>") {
            return presentationXML.replacingCharacters(in: range, with: newList)
        }
        return presentationXML
    }

    static func ensureSlideContentTypes(in contentTypesXML: String, slideCount: Int) -> String {
        var cleaned = contentTypesXML
        while let range = cleaned.range(of: #"<Override PartName="/ppt/slides/slide\d+\.xml"[^>]*/>"#, options: .regularExpression) {
            cleaned.removeSubrange(range)
        }

        var overrides = ""
        for index in 1...max(slideCount, 1) where slideCount > 0 {
            overrides += "<Override PartName=\"/ppt/slides/slide\(index).xml\" ContentType=\"application/vnd.openxmlformats-officedocument.presentationml.slide+xml\"/>"
        }

        if let insertRange = cleaned.range(of: "</Types>") {
            return cleaned.replacingCharacters(in: insertRange, with: "\(overrides)</Types>")
        }
        return cleaned
    }

    private static func attribute(_ name: String, in tag: String) -> String {
        guard let range = tag.range(of: "\(name)=\"", options: .caseInsensitive) else { return "" }
        let after = tag[range.upperBound...]
        guard let end = after.firstIndex(of: "\"") else { return "" }
        return String(after[..<end])
    }

    private static func escape(_ text: String) -> String {
        text
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
    }

    private static func defaultSlideRels() -> String {
        """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"></Relationships>
        """
    }
}
