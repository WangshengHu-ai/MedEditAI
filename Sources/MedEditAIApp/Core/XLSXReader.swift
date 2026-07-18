import Foundation

/// 读取 .xlsx（OOXML）第一个工作表为二维字符串数组。
/// 支持 sharedStrings 与 inlineStr 两种字符串存储方式。
enum XLSXReader {
    static func read(url: URL) throws -> [[String]] {
        let temp = FileManager.default.temporaryDirectory.appendingPathComponent("xlsxread-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: temp) }
        try ZipArchiver.unzip(archive: url, to: temp)

        let sharedStrings = try loadSharedStrings(in: temp)
        let sheetURL = try firstSheetURL(in: temp)
        let sheetData = try Data(contentsOf: sheetURL)
        return parseSheet(data: sheetData, sharedStrings: sharedStrings)
    }

    static func parseSheet(data: Data, sharedStrings: [String]) -> [[String]] {
        let delegate = SheetParser(sharedStrings: sharedStrings)
        let parser = XMLParser(data: data)
        parser.delegate = delegate
        parser.parse()
        return delegate.rows
    }

    static func parseSharedStrings(data: Data) -> [String] {
        let delegate = SharedStringsParser()
        let parser = XMLParser(data: data)
        parser.delegate = delegate
        parser.parse()
        return delegate.strings
    }

    private static func loadSharedStrings(in root: URL) throws -> [String] {
        let url = root.appendingPathComponent("xl/sharedStrings.xml")
        guard FileManager.default.fileExists(atPath: url.path) else { return [] }
        let data = try Data(contentsOf: url)
        return parseSharedStrings(data: data)
    }

    private static func firstSheetURL(in root: URL) throws -> URL {
        let candidate = root.appendingPathComponent("xl/worksheets/sheet1.xml")
        if FileManager.default.fileExists(atPath: candidate.path) {
            return candidate
        }
        let worksheets = root.appendingPathComponent("xl/worksheets")
        let contents = try FileManager.default.contentsOfDirectory(at: worksheets, includingPropertiesForKeys: nil)
        guard let first = contents.filter({ $0.pathExtension == "xml" }).sorted(by: { $0.lastPathComponent < $1.lastPathComponent }).first else {
            throw ArchiveError.toolFailed("工作簿中未找到工作表")
        }
        return first
    }

    private final class SharedStringsParser: NSObject, XMLParserDelegate {
        var strings: [String] = []
        private var current = ""
        private var capturing = false

        func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
            if elementName == "si" {
                current = ""
                capturing = true
            }
        }

        func parser(_ parser: XMLParser, foundCharacters string: String) {
            if capturing { current += string }
        }

        func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
            if elementName == "si" {
                strings.append(current)
                capturing = false
            }
        }
    }

    private final class SheetParser: NSObject, XMLParserDelegate {
        var rows: [[String]] = []
        private let sharedStrings: [String]
        private var currentRow: [String] = []
        private var currentValue = ""
        private var cellType = ""
        private var cellRef = ""
        private var capturingValue = false
        private var isInlineString = false

        init(sharedStrings: [String]) {
            self.sharedStrings = sharedStrings
        }

        func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
            switch elementName {
            case "row":
                currentRow = []
            case "c":
                cellType = attributeDict["t"] ?? ""
                cellRef = attributeDict["r"] ?? ""
                currentValue = ""
                isInlineString = false
            case "v":
                capturingValue = true
                currentValue = ""
            case "t":
                if cellType == "inlineStr" || cellType == "str" {
                    isInlineString = true
                    capturingValue = true
                    currentValue = ""
                }
            default:
                break
            }
        }

        func parser(_ parser: XMLParser, foundCharacters string: String) {
            if capturingValue { currentValue += string }
        }

        func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
            switch elementName {
            case "v":
                capturingValue = false
                if cellType == "s", let index = Int(currentValue.trimmingCharacters(in: .whitespaces)), index < sharedStrings.count {
                    currentRow.append(sharedStrings[index])
                } else if !isInlineString {
                    currentRow.append(currentValue)
                }
            case "t":
                if isInlineString {
                    capturingValue = false
                    currentRow.append(currentValue)
                }
            case "c":
                break
            case "row":
                rows.append(currentRow)
            default:
                break
            }
        }
    }
}
