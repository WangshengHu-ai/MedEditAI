import Foundation
import SwiftUI

enum AppSection: String, CaseIterable, Identifiable {
    case dashboard
    case search
    case library
    case enrich
    case slides
    case settings          // 项目设置（工作台内）
    case systemSettings    // 系统设置（左下角按钮）

    var id: String { rawValue }

    var title: String {
        switch self {
        case .dashboard: "仪表盘"
        case .search: "检索中心"
        case .library: "文献库"
        case .enrich: "AI 加工"
        case .slides: "产出生成"
        case .settings: "项目设置"
        case .systemSettings: "系统设置"
        }
    }

    var systemImage: String {
        switch self {
        case .dashboard: "square.grid.2x2.fill"
        case .search: "magnifyingglass"
        case .library: "books.vertical.fill"
        case .enrich: "sparkles"
        case .slides: "play.rectangle.on.rectangle.fill"
        case .settings: "slider.horizontal.3"
        case .systemSettings: "gearshape.fill"
        }
    }
}

enum ConfidenceLevel: String {
    case high
    case medium
    case low

    var title: String {
        switch self {
        case .high: "高可信"
        case .medium: "中等可信"
        case .low: "待复核"
        }
    }

    var tint: Color {
        switch self {
        case .high: AppTheme.ok
        case .medium: AppTheme.warn
        case .low: AppTheme.danger
        }
    }

    var background: Color {
        tint.opacity(0.14)
    }
}

struct Project: Identifiable, Hashable {
    let id: UUID
    let name: String
    let color: Color

    init(id: UUID = UUID(), name: String, color: Color) {
        self.id = id
        self.name = name
        self.color = color
    }
}

struct StatItem: Identifiable {
    let id = UUID()
    let title: String
    let value: String
    let detail: String
    let symbol: String
}

struct AlertItem: Identifiable {
    let id = UUID()
    let title: String
}

struct QuickAction: Identifiable {
    let id = UUID()
    let title: String
    let description: String
    let symbol: String
    let gradient: [Color]
    let destination: AppSection
}

struct TopicNode: Identifiable, Hashable {
    let id = UUID()
    let title: String
    let level: Int
    let count: Int?
    let children: [TopicNode]
}

struct Article: Identifiable, Hashable {
    let id: String
    let topic: String
    let titleEN: String
    let titleCN: String
    let abstractEN: String
    let abstractCN: String
    let citation: String
    let authors: String
    let date: String
    let studyType: String
    let journal: String
    let impactFactor: String
    let quartile: String
    let pmid: String
    let url: String
    let confidence: ConfidenceLevel
    let product: String
    let evidence: String
    let note: String
    var keywords: String = ""
    var customFields: [String: String] = [:]
}

struct MappingPair: Identifiable, Hashable {
    let id = UUID()
    let source: String
    let target: String
}

struct ProcessingTask: Identifiable {
    let id = UUID()
    let key: String
    let title: String
    let description: String
    let symbol: String
    var isEnabled: Bool
}

enum QueueStatus: Equatable {
    case done
    case running
    case waiting
    case paused
    case failed
}

struct QueueItem: Identifiable {
    let id = UUID()
    let title: String
    let status: QueueStatus
    let detail: String?

    init(title: String, status: QueueStatus, detail: String? = nil) {
        self.title = title
        self.status = status
        self.detail = detail
    }
}
