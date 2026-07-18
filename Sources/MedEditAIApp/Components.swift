import SwiftUI

struct PageHeader<Actions: View>: View {
    let title: String
    let subtitle: String
    @ViewBuilder var actions: Actions

    init(title: String, subtitle: String, @ViewBuilder actions: () -> Actions) {
        self.title = title
        self.subtitle = subtitle
        self.actions = actions()
    }

    var body: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 24, weight: .bold))
                Text(subtitle)
                    .font(.system(size: 13))
                    .foregroundStyle(AppTheme.textSecondary)
            }
            Spacer()
            actions
        }
    }
}

struct SectionTitle: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.system(size: 15, weight: .bold))
    }
}

struct StatCard: View {
    let item: StatItem

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(item.title, systemImage: item.symbol)
                .font(.system(size: 12.5, weight: .medium))
                .foregroundStyle(AppTheme.textSecondary)
                .labelStyle(.titleAndIcon)
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(AppTheme.accent)
            Text(item.value)
                .font(.system(size: 30, weight: .bold))
            Text(item.detail)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(item.title == "待复核" ? AppTheme.warn : AppTheme.ok)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .roundedPanel()
    }
}

struct QuickActionCard: View {
    let action: QuickAction
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(LinearGradient(colors: action.gradient, startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 46, height: 46)
                    .overlay {
                        Image(systemName: action.symbol)
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(.white)
                    }

                VStack(alignment: .leading, spacing: 2) {
                    Text(action.title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.primary)
                    Text(action.description)
                        .font(.system(size: 12.5))
                        .foregroundStyle(AppTheme.textSecondary)
                        .multilineTextAlignment(.leading)
                }
                Spacer()
            }
            .padding(20)
            .roundedPanel(padding: 0)
        }
        .buttonStyle(.plain)
    }
}

struct Chip: View {
    let text: String
    let tint: Color

    var body: some View {
        Text(text)
            .font(.system(size: 11.5, weight: .semibold))
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(Capsule().fill(tint.opacity(0.12)))
            .foregroundStyle(tint)
    }
}

struct FilterChip: View {
    let text: String
    let isOn: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(text)
                .font(.system(size: 12.5, weight: .medium))
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(Capsule().fill(isOn ? AppTheme.accent : AppTheme.panel))
                .overlay(Capsule().stroke(isOn ? AppTheme.accent : AppTheme.line))
                .foregroundStyle(isOn ? .white : AppTheme.textSecondary)
        }
        .buttonStyle(.plain)
    }
}

struct ConfidenceBadge: View {
    let level: ConfidenceLevel

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(level.tint)
                .frame(width: 7, height: 7)
            Text(level.title)
                .font(.system(size: 11.5, weight: .semibold))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Capsule().fill(level.background))
        .foregroundStyle(level.tint)
    }
}

struct SearchHeaderRow: View {
    var body: some View {
        HStack {
            Text("标题").frame(maxWidth: .infinity, alignment: .leading)
            Text("作者").frame(width: 160, alignment: .leading)
            Text("研究类型").frame(width: 100, alignment: .leading)
            Text("期刊").frame(width: 140, alignment: .leading)
            Text("IF").frame(width: 48, alignment: .leading)
        }
        .font(.system(size: 12, weight: .semibold))
        .foregroundStyle(AppTheme.textSecondary)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }
}

struct SearchArticleRow: View {
    let article: Article
    let isChecked: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: isChecked ? "checkmark.square.fill" : "square")
                .foregroundStyle(isChecked ? AppTheme.accent : AppTheme.textTertiary)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 2) {
                Text(article.titleEN)
                    .font(.system(size: 13, weight: .semibold))
                Text(article.titleCN)
                    .font(.system(size: 12))
                    .foregroundStyle(AppTheme.textSecondary)
            }
            Spacer()
            Text(article.authors)
                .font(.system(size: 12))
                .foregroundStyle(AppTheme.textSecondary)
                .frame(width: 160, alignment: .leading)
            TagView(text: article.studyType, tint: AppTheme.accent)
                .frame(width: 100, alignment: .leading)
            Text(article.journal)
                .font(.system(size: 12))
                .foregroundStyle(AppTheme.textSecondary)
                .frame(width: 140, alignment: .leading)
            TagView(text: article.impactFactor, tint: AppTheme.accentBlue)
                .frame(width: 48, alignment: .leading)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
    }
}

struct TagView: View {
    let text: String
    let tint: Color

    var body: some View {
        Text(text)
            .font(.system(size: 11.5, weight: .semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Capsule().fill(tint.opacity(0.12)))
            .foregroundStyle(tint)
    }
}

struct ArticleListCard: View {
    let article: Article
    let isSelected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(article.titleEN)
                .font(.system(size: 13, weight: .semibold))
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(article.titleCN)
                .font(.system(size: 12.5))
                .foregroundStyle(AppTheme.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            HStack(spacing: 8) {
                TagView(text: article.studyType, tint: AppTheme.accent)
                TagView(text: "IF \(article.impactFactor)", tint: AppTheme.accentBlue)
                TagView(text: article.quartile, tint: article.quartile == "Q1" ? AppTheme.ok : AppTheme.textSecondary)
                ConfidenceBadge(level: article.confidence)
            }
            Text("\(article.authors) · \(article.journal) · PMID \(article.pmid)")
                .font(.system(size: 11.5))
                .foregroundStyle(AppTheme.textTertiary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(isSelected ? AppTheme.accent.opacity(0.10) : AppTheme.panel)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(isSelected ? AppTheme.accent.opacity(0.35) : AppTheme.line)
        )
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
    }
}

struct DetailBlock<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(AppTheme.textTertiary)
                .textCase(.uppercase)
            content
        }
        .roundedPanel()
    }
}

struct DetailKeyValueGrid: View {
    let pairs: [(String, String)]

    var body: some View {
        Grid(alignment: .leading, horizontalSpacing: 10, verticalSpacing: 8) {
            ForEach(Array(pairs.enumerated()), id: \.offset) { _, pair in
                GridRow {
                    Text(pair.0)
                        .foregroundStyle(AppTheme.textSecondary)
                    Text(pair.1)
                        .fontWeight(.medium)
                }
            }
        }
        .font(.system(size: 13))
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct AIFieldRow: View {
    let label: String
    let value: String
    let trailing: String

    var body: some View {
        HStack {
            HStack(spacing: 8) {
                TagView(text: label, tint: AppTheme.accent)
                Text(value)
                    .font(.system(size: 13, weight: .semibold))
            }
            Spacer()
            Text(trailing)
                .font(.system(size: 12))
                .foregroundStyle(AppTheme.textSecondary)
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(AppTheme.panelSecondary))
        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(AppTheme.line))
    }
}

struct ProcessingTaskRow: View {
    let task: ProcessingTask
    let action: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(AppTheme.accent.opacity(0.12))
                .frame(width: 38, height: 38)
                .overlay {
                    Image(systemName: task.symbol)
                        .foregroundStyle(AppTheme.accent)
                }
            VStack(alignment: .leading, spacing: 2) {
                Text(task.title)
                    .font(.system(size: 14, weight: .semibold))
                Text(task.description)
                    .font(.system(size: 12))
                    .foregroundStyle(AppTheme.textSecondary)
            }
            Spacer()
            Toggle("", isOn: .constant(task.isEnabled))
                .labelsHidden()
                .toggleStyle(.switch)
                .tint(AppTheme.accent)
                .onTapGesture(perform: action)
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 14).fill(AppTheme.panelSecondary))
    }
}

struct QueueRow: View {
    let item: QueueItem

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(color)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.system(size: 12.5, weight: .semibold))
                Text(statusText)
                    .font(.system(size: 11.5))
                    .foregroundStyle(AppTheme.textSecondary)
            }
            Spacer()
            TagView(text: tagText, tint: color)
        }
        .padding(.vertical, 9)
    }

    private var icon: String {
        switch item.status {
        case .done: "checkmark.circle.fill"
        case .running: "arrow.triangle.2.circlepath.circle.fill"
        case .waiting: "clock.fill"
        }
    }

    private var color: Color {
        switch item.status {
        case .done: AppTheme.ok
        case .running: AppTheme.accent
        case .waiting: AppTheme.textSecondary
        }
    }

    private var statusText: String {
        switch item.status {
        case .done: "已完成"
        case .running: "运行中"
        case .waiting: "等待中"
        }
    }

    private var tagText: String {
        switch item.status {
        case .done: "完成"
        case .running: "处理中"
        case .waiting: "排队"
        }
    }
}

struct InfoPanel: View {
    let title: String
    let text: String
    let tags: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(title: title)
            Text(text)
                .font(.system(size: 13.5))
                .foregroundStyle(AppTheme.textSecondary)
                .lineSpacing(4)
            if !tags.isEmpty {
                HStack(spacing: 8) {
                    ForEach(tags, id: \.self) { tag in
                        Chip(text: tag, tint: AppTheme.accent)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .roundedPanel()
    }
}

struct SlideThumbnail: View {
    let article: Article
    let index: Int
    let selected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Spacer()
                Text("\(index)")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(AppTheme.textTertiary)
            }
            Text(String(article.topic.prefix(12)) + "...")
                .font(.system(size: 7, weight: .bold))
                .foregroundStyle(AppTheme.accent)
            Rectangle()
                .fill(AppTheme.accent.opacity(0.18))
                .frame(height: 1)
            Text(String(article.titleEN.prefix(42)) + "...")
                .font(.system(size: 7, weight: .semibold))
                .lineLimit(3)
            Text(article.authors)
                .font(.system(size: 6))
                .foregroundStyle(.secondary)
            RoundedRectangle(cornerRadius: 4)
                .fill(AppTheme.accent.opacity(0.10))
                .frame(height: 18)
                .overlay {
                    Text("作者 / 日期 / 研究类型 / IF")
                        .font(.system(size: 6))
                        .foregroundStyle(.secondary)
                }
            Text(String(article.abstractCN.prefix(95)) + "...")
                .font(.system(size: 6))
                .foregroundStyle(.secondary)
                .lineLimit(5)
            Spacer()
        }
        .padding(8)
        .frame(width: 118, height: 156)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.white))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(selected ? AppTheme.accent : AppTheme.line, lineWidth: selected ? 2 : 1))
        .shadow(color: .black.opacity(0.04), radius: 8, y: 4)
    }
}

struct SlidePreviewCard: View {
    let article: Article

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(article.topic)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(AppTheme.accent)
            Rectangle()
                .fill(LinearGradient(colors: [AppTheme.accent, .clear], startPoint: .leading, endPoint: .trailing))
                .frame(height: 2)
                .padding(.top, 6)
                .padding(.bottom, 12)
            Text(article.titleEN)
                .font(.system(size: 14, weight: .bold))
                .lineSpacing(3)
            Text(article.titleCN)
                .font(.system(size: 12.5, weight: .semibold))
                .foregroundStyle(.secondary)
                .padding(.top, 4)

            HStack {
                Spacer()
                VStack(alignment: .leading, spacing: 3) {
                    Text("作者：\(article.authors)")
                    Text("发表日期：\(article.date)")
                    Text("研究类型：\(article.studyType)")
                    Text("期刊：\(article.journal)")
                    Text("IF：\(article.impactFactor)")
                }
                .font(.system(size: 9.5))
                .padding(10)
                .background(RoundedRectangle(cornerRadius: 8).fill(AppTheme.accent.opacity(0.08)))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(AppTheme.accent.opacity(0.16)))
                .frame(width: 220, alignment: .trailing)
            }
            .padding(.top, 10)

            Text("摘要：\(article.abstractCN)")
                .font(.system(size: 11.5, weight: .medium))
                .lineSpacing(4)
                .padding(.top, 16)

            Spacer(minLength: 16)

            VStack(alignment: .leading, spacing: 6) {
                Divider()
                Text("参考文献：\(article.citation)")
                    .font(.system(size: 8.5, weight: .semibold))
                    .foregroundStyle(.secondary)
                Text("点击查看原文链接")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(AppTheme.accent))
                Text(article.url)
                    .font(.system(size: 8.5))
                    .foregroundStyle(AppTheme.accentBlue)
                Text("*版权问题暂不提供直接下载，如有学术交流需要，请联系内部人员")
                    .font(.system(size: 8))
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 10)
        }
        .padding(26)
        .frame(width: 420, height: 594)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.white))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppTheme.line))
        .shadow(color: .black.opacity(0.08), radius: 12, y: 8)
    }
}

struct SlideSettingsPanel: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionTitle(title: "模板设置")
                .padding(.bottom, 10)
            SettingInlineRow(title: "客户模板", subtitle: "20260413-PFA图书馆-onepage.pptx", trailing: "A4 纵向")
            Divider()
            SettingInlineRow(title: "分组维度", subtitle: "按四级主题生成独立 deck", trailing: "topic")
            Divider()
            SettingInlineRow(title: "导出字段", subtitle: "含超链接与版权免责声明", trailing: "编辑")
        }
        .frame(width: 240, alignment: .leading)
        .roundedPanel()
    }
}

struct SettingInlineRow: View {
    let title: String
    let subtitle: String
    let trailing: String

    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13.5, weight: .semibold))
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(AppTheme.textSecondary)
            }
            Spacer()
            Text(trailing)
                .font(.system(size: 11.5, weight: .semibold))
                .foregroundStyle(AppTheme.accent)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Capsule().fill(AppTheme.accent.opacity(0.10)))
        }
        .padding(.vertical, 12)
    }
}

struct SettingsActionRow: View {
    let title: String
    let subtitle: String
    let button: String
    let action: () -> Void

    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13.5, weight: .semibold))
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(AppTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            Button(button, action: action)
                .buttonStyle(.bordered)
        }
        .padding(16)
    }
}

struct SettingsSecureRow: View {
    let title: String
    let subtitle: String
    let placeholder: String
    @Binding var text: String

    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13.5, weight: .semibold))
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(AppTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            SecureField(placeholder, text: $text)
                .textFieldStyle(.roundedBorder)
                .frame(width: 200)
        }
        .padding(16)
    }
}

struct MappingPanel: View {
    let title: String
    let items: [MappingPair]
    var footer: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionTitle(title: title)
            ForEach(items) { item in
                HStack(spacing: 10) {
                    Text(item.source)
                        .font(.system(size: 12.5, design: .monospaced))
                        .foregroundStyle(AppTheme.accent)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(RoundedRectangle(cornerRadius: 8).fill(AppTheme.panelSecondary))
                    Image(systemName: "arrow.right")
                        .foregroundStyle(AppTheme.textTertiary)
                    Text(item.target)
                        .font(.system(size: 12.5))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(RoundedRectangle(cornerRadius: 8).fill(AppTheme.panelSecondary))
                }
            }
            if let footer {
                Text(footer)
                    .font(.system(size: 12.5))
                    .foregroundStyle(AppTheme.textSecondary)
                    .lineSpacing(4)
                    .padding(.top, 6)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .roundedPanel()
    }
}

struct SettingsCard: View {
    let rows: [(String, String, String)]

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(row.0)
                            .font(.system(size: 13.5, weight: .semibold))
                        Text(row.1)
                            .font(.system(size: 12))
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                    Spacer()
                    if index < 2 {
                        TextField("", text: .constant(row.2))
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 220)
                    } else {
                        Button(row.2) {}
                    }
                }
                .padding(16)
                if index != rows.count - 1 {
                    Divider()
                }
            }
        }
        .roundedPanel(padding: 0)
    }
}

struct TopicTreePanel: View {
    let nodes: [TopicNode]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(nodes) { node in
                TopicTreeNodeView(node: node, highlightLeaf: "原理——PFA与既往热能源有何不同？")
            }
        }
        .roundedPanel()
    }
}

struct TopicTreeNodeView: View {
    let node: TopicNode
    let highlightLeaf: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                if !node.children.isEmpty {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(AppTheme.textTertiary)
                } else {
                    Spacer().frame(width: 10)
                }
                Text(node.title)
                    .font(font)
                    .foregroundStyle(node.title == highlightLeaf ? AppTheme.accent : node.level >= 4 ? AppTheme.textSecondary : .primary)
                Spacer()
                if let count = node.count {
                    Text("\(count)")
                        .font(.system(size: 11))
                        .foregroundStyle(AppTheme.textTertiary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 1)
                        .background(Capsule().fill(AppTheme.panelSecondary))
                }
            }
            .padding(.leading, CGFloat((node.level - 1) * 12))
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(node.title == highlightLeaf ? AppTheme.accent.opacity(0.10) : .clear)
            )

            ForEach(node.children) { child in
                TopicTreeNodeView(node: child, highlightLeaf: highlightLeaf)
            }
        }
    }

    private var font: Font {
        switch node.level {
        case 1: .system(size: 13, weight: .bold)
        case 2: .system(size: 13, weight: .semibold)
        case 3: .system(size: 12.5, weight: .medium)
        default: .system(size: 12)
        }
    }
}

struct FlowLayout<Content: View>: View {
    let spacing: CGFloat
    @ViewBuilder let content: Content

    init(spacing: CGFloat = 8, @ViewBuilder content: () -> Content) {
        self.spacing = spacing
        self.content = content()
    }

    var body: some View {
        HStack(spacing: spacing) {
            content
        }
    }
}
