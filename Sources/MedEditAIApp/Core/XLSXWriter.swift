import Foundation

/// 生成合法的 .xlsx（OOXML）。使用 inlineStr，避免 sharedStrings 复杂度。
/// XML 生成为纯函数，便于单元测试；落盘时用 ZipArchiver 打包。
enum XLSXWriter {
    static func write(rows: [[String]], to url: URL, sheetName: String = "Sheet1") throws {
        let temp = FileManager.default.temporaryDirectory.appendingPathComponent("xlsxwrite-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: temp) }

        try writeFile(contentTypesXML(), to: temp.appendingPathComponent("[Content_Types].xml"))
        try writeFile(rootRelsXML(), to: temp.appendingPathComponent("_rels/.rels"))
        try writeFile(workbookXML(sheetName: sheetName), to: temp.appendingPathComponent("xl/workbook.xml"))
        try writeFile(workbookRelsXML(), to: temp.appendingPathComponent("xl/_rels/workbook.xml.rels"))
        try writeFile(stylesXML(), to: temp.appendingPathComponent("xl/styles.xml"))
        try writeFile(sheetXML(rows: rows), to: temp.appendingPathComponent("xl/worksheets/sheet1.xml"))

        try ZipArchiver.zip(directory: temp, to: url)
    }

    static func sheetXML(rows: [[String]]) -> String {
        var body = ""
        for (rowIndex, row) in rows.enumerated() {
            let rowNumber = rowIndex + 1
            var cells = ""
            for (columnIndex, value) in row.enumerated() {
                let ref = "\(columnLetter(columnIndex))\(rowNumber)"
                cells += "<c r=\"\(ref)\" t=\"inlineStr\"><is><t xml:space=\"preserve\">\(escape(value))</t></is></c>"
            }
            body += "<row r=\"\(rowNumber)\">\(cells)</row>"
        }
        return """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"><sheetData>\(body)</sheetData></worksheet>
        """
    }

    static func columnLetter(_ index: Int) -> String {
        var value = index
        var result = ""
        repeat {
            let remainder = value % 26
            result = String(UnicodeScalar(UInt8(65 + remainder))) + result
            value = value / 26 - 1
        } while value >= 0
        return result
    }

    static func escape(_ text: String) -> String {
        text
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&apos;")
    }

    private static func writeFile(_ content: String, to url: URL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try content.write(to: url, atomically: true, encoding: .utf8)
    }

    private static func contentTypesXML() -> String {
        """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/><Default Extension="xml" ContentType="application/xml"/><Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/><Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/><Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/></Types>
        """
    }

    private static func rootRelsXML() -> String {
        """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/></Relationships>
        """
    }

    private static func workbookXML(sheetName: String) -> String {
        """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><sheets><sheet name="\(escape(sheetName))" sheetId="1" r:id="rId1"/></sheets></workbook>
        """
    }

    private static func workbookRelsXML() -> String {
        """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/><Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/></Relationships>
        """
    }

    private static func stylesXML() -> String {
        """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"><fonts count="1"><font><sz val="11"/><name val="Calibri"/></font></fonts><fills count="1"><fill><patternFill patternType="none"/></fill></fills><borders count="1"><border/></borders><cellStyleXfs count="1"><xf/></cellStyleXfs><cellXfs count="1"><xf/></cellXfs></styleSheet>
        """
    }
}
