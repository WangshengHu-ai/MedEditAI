import Foundation

enum ArchiveError: Error, LocalizedError {
    case toolFailed(String)
    case toolUnavailable(String)

    var errorDescription: String? {
        switch self {
        case .toolFailed(let message): "归档工具执行失败：\(message)"
        case .toolUnavailable(let tool): "系统工具不可用：\(tool)"
        }
    }
}

/// 通过 macOS 自带命令行工具处理 zip 容器（.xlsx / .pptx 均为 zip+xml）。
/// 不引入任何第三方依赖，复制到 Mac 后可直接工作。
enum ZipArchiver {
    static func unzip(archive: URL, to destination: URL) throws {
        try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
        try run(tool: "/usr/bin/unzip", arguments: ["-o", "-q", archive.path, "-d", destination.path])
    }

    /// 将 directory 内的内容（不含 directory 本身）打包为 OOXML 兼容的 zip。
    static func zip(directory: URL, to archive: URL) throws {
        if FileManager.default.fileExists(atPath: archive.path) {
            try FileManager.default.removeItem(at: archive)
        }
        try run(
            tool: "/usr/bin/zip",
            arguments: ["-r", "-X", "-q", archive.path, "."],
            currentDirectory: directory
        )
    }

    private static func run(tool: String, arguments: [String], currentDirectory: URL? = nil) throws {
        guard FileManager.default.isExecutableFile(atPath: tool) else {
            throw ArchiveError.toolUnavailable(tool)
        }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: tool)
        process.arguments = arguments
        if let currentDirectory {
            process.currentDirectoryURL = currentDirectory
        }
        let errorPipe = Pipe()
        process.standardError = errorPipe
        process.standardOutput = Pipe()

        try process.run()
        process.waitUntilExit()

        if process.terminationStatus != 0 {
            let data = errorPipe.fileHandleForReading.readDataToEndOfFile()
            let message = String(data: data, encoding: .utf8) ?? "unknown error"
            throw ArchiveError.toolFailed(message)
        }
    }
}
