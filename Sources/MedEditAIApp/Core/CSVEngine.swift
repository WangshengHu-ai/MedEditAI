import Foundation

/// 纯 Foundation 实现的 CSV 解析与写入，支持带引号、逗号、换行的字段。
enum CSVEngine {
    static func parse(_ text: String) -> [[String]] {
        var rows: [[String]] = []
        var field = ""
        var record: [String] = []
        var inQuotes = false
        let scalars = Array(text.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n"))
        var index = 0

        func endField() {
            record.append(field)
            field = ""
        }
        func endRecord() {
            endField()
            rows.append(record)
            record = []
        }

        while index < scalars.count {
            let char = scalars[index]
            if inQuotes {
                if char == "\"" {
                    if index + 1 < scalars.count, scalars[index + 1] == "\"" {
                        field.append("\"")
                        index += 1
                    } else {
                        inQuotes = false
                    }
                } else {
                    field.append(char)
                }
            } else {
                switch char {
                case "\"":
                    inQuotes = true
                case ",":
                    endField()
                case "\n":
                    endRecord()
                default:
                    field.append(char)
                }
            }
            index += 1
        }

        if !field.isEmpty || !record.isEmpty {
            endRecord()
        }

        return rows.filter { !($0.count == 1 && $0[0].isEmpty) }
    }

    static func write(_ rows: [[String]]) -> String {
        rows.map { row in
            row.map(escapeField).joined(separator: ",")
        }.joined(separator: "\n")
    }

    private static func escapeField(_ field: String) -> String {
        if field.contains(",") || field.contains("\"") || field.contains("\n") {
            let escaped = field.replacingOccurrences(of: "\"", with: "\"\"")
            return "\"\(escaped)\""
        }
        return field
    }
}
