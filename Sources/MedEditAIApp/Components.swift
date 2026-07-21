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
                    .accessibilityIdentifier("page-title")
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
        .contentShape(Rectangle())
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

    private var metaLine: String {
        var parts: [String] = []
        if !article.authors.isEmpty { parts.append(article.authors) }
        if !article.journal.isEmpty { parts.append(article.journal) }
        if !article.pmid.isEmpty { parts.append("PMID \(article.pmid)") }
        return parts.joined(separator: " · ")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(article.titleEN.isEmpty ? "(无标题)" : article.titleEN)
                .font(.system(size: 13, weight: .semibold))
                .frame(maxWidth: .infinity, alignment: .leading)
            if !article.titleCN.isEmpty {
                Text(article.titleCN)
                    .font(.system(size: 12.5))
                    .foregroundStyle(AppTheme.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            HStack(spacing: 8) {
                if !article.studyType.isEmpty {
                    TagView(text: article.studyType, tint: AppTheme.accent)
                }
                if !article.impactFactor.isEmpty {
                    TagView(text: "IF \(article.impactFactor)", tint: AppTheme.accentBlue)
                }
                if !article.quartile.isEmpty {
                    TagView(text: article.quartile, tint: article.quartile == "Q1" ? AppTheme.ok : AppTheme.textSecondary)
                }
                ConfidenceBadge(level: article.confidence)
            }
            if !metaLine.isEmpty {
                Text(metaLine)
                    .font(.system(size: 11.5))
                    .foregroundStyle(AppTheme.textTertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
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
            Toggle("", isOn: Binding(get: { task.isEnabled }, set: { _ in action() }))
                .labelsHidden()
                .toggleStyle(.switch)
                .tint(AppTheme.accent)
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
                if let detail = item.detail, !detail.isEmpty {
                    Text(detail)
                        .font(.system(size: 11))
                        .foregroundStyle(color)
                        .lineLimit(2)
                }
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
        case .paused: "pause.circle.fill"
        case .failed: "exclamationmark.triangle.fill"
        }
    }

    private var color: Color {
        switch item.status {
        case .done: AppTheme.ok
        case .running: AppTheme.accent
        case .waiting: AppTheme.textSecondary
        case .paused: AppTheme.warn
        case .failed: AppTheme.danger
        }
    }

    private var statusText: String {
        switch item.status {
        case .done: "已完成"
        case .running: "运行中"
        case .waiting: "等待中"
        case .paused: "已暂停"
        case .failed: "处理失败"
        }
    }

    private var tagText: String {
        switch item.status {
        case .done: "完成"
        case .running: "处理中"
        case .waiting: "排队"
        case .paused: "暂停"
        case .failed: "失败"
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
    let template: PPTVisualTemplate

    private var accent: Color { Color(hex: template.accentHex) }
    private var metadataFill: Color { Color(hex: template.metadataBackgroundHex) }

    /// 根据模板字号与默认基准的比例，缩放预览卡上的字体大小。默认值下与之前硬编码的视觉效果一致。
    private func scaledFont(_ templateSize: Double, baseTemplate: Double, basePreview: CGFloat, weight: Font.Weight = .regular) -> Font {
        let ratio = baseTemplate > 0 ? CGFloat(templateSize / baseTemplate) : 1
        let size = max(6, basePreview * ratio)
        return .custom(template.fontFamily, size: size).weight(weight)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(article.topic)
                .font(scaledFont(template.topicFontSize, baseTemplate: 18, basePreview: 12, weight: .bold))
                .foregroundStyle(accent)
            Rectangle()
                .fill(LinearGradient(colors: [accent, .clear], startPoint: .leading, endPoint: .trailing))
                .frame(height: 2)
                .padding(.top, 6)
                .padding(.bottom, 12)
            Text(article.titleEN)
                .font(scaledFont(template.titleFontSize, baseTemplate: 22, basePreview: 14, weight: .bold))
                .lineSpacing(3)
            Text(article.titleCN)
                .font(scaledFont(template.subtitleFontSize, baseTemplate: 16, basePreview: 12.5, weight: .semibold))
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
                .font(scaledFont(template.metadataFontSize, baseTemplate: 11, basePreview: 9.5))
                .padding(10)
                .background(RoundedRectangle(cornerRadius: 8).fill(metadataFill))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(accent.opacity(0.16)))
                .frame(width: 220, alignment: .trailing)
            }
            .padding(.top, 10)

            Text("\(template.abstractPrefix)\(article.abstractCN)")
                .font(scaledFont(template.bodyFontSize, baseTemplate: 12, basePreview: 11.5, weight: .medium))
                .lineSpacing(4)
                .lineLimit(8)
                .padding(.top, 16)

            Spacer(minLength: 12)

            VStack(alignment: .leading, spacing: 6) {
                Divider()
                Text("\(template.citationPrefix)\(article.citation)")
                    .font(scaledFont(template.captionFontSize, baseTemplate: 9, basePreview: 8.5, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
                Text(template.ctaText)
                    .font(scaledFont(template.metadataFontSize, baseTemplate: 11, basePreview: 10, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(accent))
                Text(article.url)
                    .font(scaledFont(template.captionFontSize, baseTemplate: 9, basePreview: 8.5))
                    .foregroundStyle(AppTheme.accentBlue)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text(template.disclaimerText)
                    .font(scaledFont(template.captionFontSize, baseTemplate: 9, basePreview: 8))
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 10)
        }
        .padding(20)
        .frame(width: 300, height: 424)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.white))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppTheme.line))
        .shadow(color: .black.opacity(0.08), radius: 12, y: 8)
    }
}

struct SlideSettingsPanel: View {
    let templateName: String

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionTitle(title: "模板设置")
                .padding(.bottom, 10)
            SettingInlineRow(title: "产品内模板", subtitle: templateName, trailing: "A4 纵向")
            Divider()
            SettingInlineRow(title: "分组维度", subtitle: "按四级主题生成独立 deck", trailing: "topic")
            Divider()
            SettingInlineRow(title: "导出字段", subtitle: "含按钮文案、版权说明和占位符映射", trailing: "UI 编辑")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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

/// 明文设置输入行（用于非敏感配置，如 LLM 接口地址、模型名）。
struct SettingsFieldRow: View {
    let title: String
    let subtitle: String
    let placeholder: String
    @Binding var text: String
    var accessibilityID: String? = nil

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
            TextField(placeholder, text: $text)
                .textFieldStyle(.roundedBorder)
                .frame(width: 240)
                .accessibilityIdentifier(accessibilityID ?? "")
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

struct ExportTemplateEditorPanel: View {
    @Binding var columns: [ExportColumnConfig]
    let availableFields: [CanonicalField]
    let previewDrafts: [ArticleDraft]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                SectionTitle(title: "Excel 导出模板")
                Spacer()
                Button {
                    columns.append(ExportColumnConfig(header: "新列", field: availableFields.first(where: { !$0.id.isEmpty })?.id ?? "titleEN"))
                } label: {
                    Label("添加列", systemImage: "plus")
                }
                .buttonStyle(.bordered)
            }

            Text("列顺序、表头、字段和超链接都可以自定义。修改后右侧预览会实时刷新。")
                .font(.system(size: 12.5))
                .foregroundStyle(AppTheme.textSecondary)

            VStack(spacing: 8) {
                ForEach($columns) { $column in
                    HStack(spacing: 8) {
                        TextField("表头", text: $column.header)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 140)
                        Picker("字段", selection: $column.field) {
                            ForEach(availableFields, id: \.id) { field in
                                Text(field.label).tag(field.id)
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(width: 170)
                        Toggle("超链接", isOn: $column.isHyperlink)
                            .toggleStyle(.switch)
                        Spacer()
                        Button {
                            columns.removeAll { $0.id == column.id }
                        } label: {
                            Image(systemName: "trash")
                        }
                        .buttonStyle(.borderless)
                    }
                    .padding(10)
                    .background(RoundedRectangle(cornerRadius: 10).fill(AppTheme.panelSecondary))
                }
            }

            ExportTemplatePreviewTable(columns: columns, previewDrafts: previewDrafts)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .roundedPanel()
    }
}

struct ExportTemplatePreviewTable: View {
    let columns: [ExportColumnConfig]
    let previewDrafts: [ArticleDraft]

    private var rows: [[String]] {
        let drafts = Array(previewDrafts.prefix(3))
        return DocumentService.exportRows(articles: drafts, columns: columns)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("实时预览")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(AppTheme.textSecondary)
            ScrollView(.horizontal, showsIndicators: true) {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                        HStack(spacing: 0) {
                            ForEach(row.indices, id: \.self) { columnIndex in
                                Text(row[columnIndex].isEmpty ? "—" : row[columnIndex])
                                    .font(.system(size: 11.5))
                                    .frame(minWidth: 110, alignment: .leading)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 6)
                                    .background(index == 0 ? AppTheme.accent.opacity(0.10) : Color.clear)
                                    .overlay(RoundedRectangle(cornerRadius: 0).stroke(AppTheme.line.opacity(index == 0 ? 0.6 : 0.3), lineWidth: 0.5))
                            }
                        }
                    }
                }
            }
            .frame(maxHeight: 170)
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 10).fill(AppTheme.panelSecondary))
    }
}

struct PPTTemplateEditorPanel: View {
    @Binding var mappings: [PPTPlaceholderMapping]
    let availableFields: [CanonicalField]
    let previewDraft: ArticleDraft?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                SectionTitle(title: "PPT 占位符映射")
                Spacer()
                Button {
                    mappings.append(PPTPlaceholderMapping(placeholder: "{{new_placeholder}}", field: availableFields.first(where: { !$0.id.isEmpty })?.id ?? "titleEN"))
                } label: {
                    Label("添加占位符", systemImage: "plus")
                }
                .buttonStyle(.bordered)
            }

            Text("占位符文本和字段都可改名；右侧会实时展示模板填充结果。")
                .font(.system(size: 12.5))
                .foregroundStyle(AppTheme.textSecondary)

            VStack(spacing: 8) {
                ForEach($mappings) { $mapping in
                    HStack(spacing: 8) {
                        TextField("占位符", text: $mapping.placeholder)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 180)
                        Picker("字段", selection: $mapping.field) {
                            ForEach(availableFields, id: \.id) { field in
                                Text(field.label).tag(field.id)
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(width: 170)
                        Spacer()
                        Button {
                            mappings.removeAll { $0.id == mapping.id }
                        } label: {
                            Image(systemName: "trash")
                        }
                        .buttonStyle(.borderless)
                    }
                    .padding(10)
                    .background(RoundedRectangle(cornerRadius: 10).fill(AppTheme.panelSecondary))
                }
            }

            PPTTemplatePreviewCard(mapping: mappings, previewDraft: previewDraft)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .roundedPanel()
    }
}

struct PPTTemplatePreviewCard: View {
    let mapping: [PPTPlaceholderMapping]
    let previewDraft: ArticleDraft?

    private var values: [String: String] {
        guard let previewDraft else { return [:] }
        return DocumentService.slidePlaceholderValues(for: previewDraft, mapping: mapping)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("实时预览")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(AppTheme.textSecondary)
            VStack(alignment: .leading, spacing: 6) {
                ForEach(mapping.prefix(8)) { item in
                    HStack(alignment: .top, spacing: 10) {
                        Text(item.placeholder)
                            .font(.system(size: 11.5, weight: .semibold, design: .monospaced))
                            .foregroundStyle(AppTheme.accent)
                            .frame(width: 180, alignment: .leading)
                        Text(values[item.placeholder] ?? "—")
                            .font(.system(size: 11.5))
                            .foregroundStyle(AppTheme.textSecondary)
                            .lineLimit(2)
                        Spacer()
                    }
                    .padding(.vertical, 2)
                }
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 10).fill(AppTheme.panelSecondary))
        }
    }
}

struct PPTVisualTemplateEditorPanel: View {
    @Binding var template: PPTVisualTemplate

    private static let fontFamilyPresets = ["PingFang SC", "Songti SC", "STHeiti Sans", "Helvetica Neue", "Arial", "Georgia", "Times New Roman", "Menlo"]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(title: "PPT 样式模板")
            Text("直接在产品里编辑 onepage PPT 的名称、颜色、字体、各部分字号、按钮文案和页脚说明；无需上传外部 .pptx。")
                .font(.system(size: 12.5))
                .foregroundStyle(AppTheme.textSecondary)

            HStack(spacing: 8) {
                LabeledField("模板名称", text: $template.name)
                LabeledField("主色", text: $template.accentHex)
                LabeledField("信息框背景", text: $template.metadataBackgroundHex)
            }
            HStack(spacing: 8) {
                LabeledField("按钮文案", text: $template.ctaText)
                LabeledField("摘要前缀", text: $template.abstractPrefix)
                LabeledField("引文前缀", text: $template.citationPrefix)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("字体")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(AppTheme.textTertiary)
                    .textCase(.uppercase)
                HStack(spacing: 8) {
                    TextField("字体名称，如 PingFang SC", text: $template.fontFamily)
                        .textFieldStyle(.roundedBorder)
                        .accessibilityIdentifier("field-ppt-font-family")
                    Menu("常用字体") {
                        ForEach(Self.fontFamilyPresets, id: \.self) { name in
                            Button(name) { template.fontFamily = name }
                        }
                    }
                    .accessibilityIdentifier("menu-ppt-font-family-presets")
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("字号")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(AppTheme.textTertiary)
                    .textCase(.uppercase)
                fontSizeRow(label: "主题标签", value: $template.topicFontSize, identifier: "topic")
                fontSizeRow(label: "英文标题", value: $template.titleFontSize, identifier: "title")
                fontSizeRow(label: "中文标题", value: $template.subtitleFontSize, identifier: "subtitle")
                fontSizeRow(label: "正文摘要", value: $template.bodyFontSize, identifier: "body")
                fontSizeRow(label: "信息框", value: $template.metadataFontSize, identifier: "metadata")
                fontSizeRow(label: "引文/脚注", value: $template.captionFontSize, identifier: "caption")
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("版权说明")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(AppTheme.textTertiary)
                    .textCase(.uppercase)
                TextEditor(text: $template.disclaimerText)
                    .font(.system(size: 12.5))
                    .frame(height: 70)
                    .padding(6)
                    .background(RoundedRectangle(cornerRadius: 8).fill(AppTheme.panelSecondary))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(AppTheme.line))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .roundedPanel()
    }

    private func fontSizeRow(label: String, value: Binding<Double>, identifier: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 12.5))
                .frame(width: 90, alignment: .leading)
            Stepper(value: value, in: 6...48, step: 1) {
                Text("\(Int(value.wrappedValue)) pt")
                    .font(.system(size: 12.5, weight: .semibold))
                    .frame(width: 50, alignment: .leading)
            }
            .accessibilityIdentifier("stepper-ppt-font-\(identifier)")
        }
    }
}

struct PromptTemplateEditorPanel: View {
    @Binding var templates: PromptTemplates

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(title: "AI Prompt 模板")
            Text("占位符：{title} {abstract} {keywords} {candidates}。修改后会立即影响当前项目的 AI 加工。")
                .font(.system(size: 12.5))
                .foregroundStyle(AppTheme.textSecondary)
            promptField("翻译 · System", text: $templates.translationSystem, height: 44)
            promptField("翻译 · User", text: $templates.translationUser, height: 150)
            promptField("主题分类 · System", text: $templates.classificationSystem, height: 44)
            promptField("主题分类 · User", text: $templates.classificationUser, height: 150)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .roundedPanel()
    }

    private func promptField(_ label: String, text: Binding<String>, height: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(AppTheme.textTertiary)
                .textCase(.uppercase)
            TextEditor(text: text)
                .font(.system(size: 12.5, design: .monospaced))
                .frame(height: height)
                .padding(6)
                .background(RoundedRectangle(cornerRadius: 8).fill(AppTheme.panelSecondary))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(AppTheme.line))
        }
    }
}

struct StudyTermsEditorPanel: View {
    @Binding var terms: [String]
    @State private var newTerm: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionTitle(title: "研究类型词条")
            if terms.isEmpty {
                Text("未配置自定义词条时，AI 会根据标题和摘要自动推断；仍无法判断则留空。")
                    .font(.system(size: 12))
                    .foregroundStyle(AppTheme.textSecondary)
            } else {
                ForEach(terms, id: \.self) { term in
                    HStack(spacing: 8) {
                        Text(term)
                            .font(.system(size: 12.5))
                        Spacer()
                        Button {
                            terms.removeAll { $0 == term }
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(AppTheme.textTertiary)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(RoundedRectangle(cornerRadius: 6).fill(AppTheme.panelSecondary))
                }
            }

            HStack(spacing: 8) {
                TextField("新增研究类型词条", text: $newTerm)
                    .textFieldStyle(.roundedBorder)
                Button("添加") {
                    let trimmed = newTerm.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !trimmed.isEmpty, !terms.contains(trimmed) else { return }
                    terms.append(trimmed)
                    newTerm = ""
                }
                .disabled(newTerm.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .roundedPanel()
    }
}

struct CustomProcessingTasksEditorPanel: View {
    @Binding var tasks: [CustomProcessingTask]
    @State private var newTitle: String = ""
    @State private var newOutputKey: String = ""
    @State private var newPrompt: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(title: "自定义 AI 加工任务")
            Text("用户可定义 Prompt 和产出字段，任务会与翻译/研究设计/主题分类并行运行。")
                .font(.system(size: 12.5))
                .foregroundStyle(AppTheme.textSecondary)

            ForEach($tasks) { $task in
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        TextField("任务名称", text: $task.title)
                            .textFieldStyle(.roundedBorder)
                        TextField("输出字段", text: $task.outputFieldKey)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 160)
                        Toggle("启用", isOn: $task.isEnabled)
                            .toggleStyle(.switch)
                        Button {
                            tasks.removeAll { $0.id == task.id }
                        } label: {
                            Image(systemName: "trash")
                        }
                        .buttonStyle(.borderless)
                    }
                    TextEditor(text: $task.prompt)
                        .font(.system(size: 12.5, design: .monospaced))
                        .frame(height: 90)
                        .padding(6)
                        .background(RoundedRectangle(cornerRadius: 8).fill(AppTheme.panelSecondary))
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(AppTheme.line))
                }
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 12).fill(AppTheme.panelSecondary))
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    TextField("任务名称", text: $newTitle)
                        .textFieldStyle(.roundedBorder)
                        .accessibilityIdentifier("field-custom-task-title")
                    TextField("输出字段", text: $newOutputKey)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 160)
                        .accessibilityIdentifier("field-custom-task-output")
                }
                TextEditor(text: $newPrompt)
                    .font(.system(size: 12.5, design: .monospaced))
                    .frame(height: 96)
                    .padding(6)
                    .background(RoundedRectangle(cornerRadius: 8).fill(AppTheme.panelSecondary))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(AppTheme.line))
                    .accessibilityIdentifier("field-custom-task-prompt")
                Button("添加自定义任务") {
                    let title = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)
                    let key = newOutputKey.trimmingCharacters(in: .whitespacesAndNewlines)
                    let prompt = newPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !title.isEmpty, !key.isEmpty, !prompt.isEmpty else { return }
                    tasks.append(CustomProcessingTask(title: title, outputFieldKey: key, prompt: prompt))
                    newTitle = ""
                    newOutputKey = ""
                    newPrompt = ""
                }
                .buttonStyle(.bordered)
                .disabled(newTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || newOutputKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || newPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .accessibilityIdentifier("btn-add-custom-task")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .roundedPanel()
    }
}

/// 手动新增一条主题分类路径（无需导入 Excel），格式：主题>次级>三级>四级，也支持只输入单个词条。
/// 主题分类词条编辑器：展示已配置的主题词条并支持移除，同时支持手动新增。
/// 主题分类是一个扁平的词条列表（不是四级菜单）；AI 加工会在这些词条中为每篇文献选择最匹配的一条。
struct TopicTermsEditor: View {
    @ObservedObject var viewModel: AppViewModel
    @State private var newTerm: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if viewModel.topicTerms.isEmpty {
                Text("未配置主题词条：AI 加工时主题分类会留空。可在下方逐条添加，或载入示例数据。")
                    .font(.system(size: 12))
                    .foregroundStyle(AppTheme.textSecondary)
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(viewModel.topicTerms, id: \.self) { term in
                        HStack(spacing: 6) {
                            Text(term)
                                .font(.system(size: 12.5))
                            Spacer()
                            Button {
                                viewModel.removeTopicTerm(term)
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 12))
                                    .foregroundStyle(AppTheme.textTertiary)
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("btn-remove-topic-term-\(term)")
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(RoundedRectangle(cornerRadius: 6).fill(AppTheme.panelSecondary))
                    }
                }
            }
            HStack(spacing: 8) {
                TextField("新增主题词条，如：原理与生物物理学", text: $newTerm)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 12.5))
                    .onSubmit(add)
                    .accessibilityIdentifier("field-add-topic-term")
                Button("添加") { add() }
                    .disabled(newTerm.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .accessibilityIdentifier("btn-add-topic-term")
            }
        }
    }

    private func add() {
        guard viewModel.addTopicTerm(newTerm) else { return }
        newTerm = ""
    }
}

/// 研究类型自定义词条编辑器：展示已配置词条并支持移除，同时支持手动新增。
/// 未配置词条时，AI 加工会根据标题/摘要自动推断研究类型，仍无法判断则留空。
struct CustomStudyTermsEditor: View {
    @ObservedObject var viewModel: AppViewModel
    @State private var newTerm: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if viewModel.customStudyTerms.isEmpty {
                Text("未配置自定义词条：AI 加工时将根据标题/摘要自动推断研究类型，无法判断则留空。")
                    .font(.system(size: 12))
                    .foregroundStyle(AppTheme.textSecondary)
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(viewModel.customStudyTerms, id: \.self) { term in
                        HStack(spacing: 6) {
                            Text(term)
                                .font(.system(size: 12.5))
                            Spacer()
                            Button {
                                viewModel.removeCustomStudyTerm(term)
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 12))
                                    .foregroundStyle(AppTheme.textTertiary)
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("btn-remove-study-term-\(term)")
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(RoundedRectangle(cornerRadius: 6).fill(AppTheme.panelSecondary))
                    }
                }
            }
            HStack(spacing: 8) {
                TextField("新增研究类型词条，如：土豆模型", text: $newTerm)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 12.5))
                    .onSubmit(add)
                    .accessibilityIdentifier("field-add-study-term")
                Button("添加") { add() }
                    .disabled(newTerm.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .accessibilityIdentifier("btn-add-study-term")
            }
        }
    }

    private func add() {
        viewModel.addCustomStudyTerm(newTerm)
        newTerm = ""
    }
}

struct TopicTreePanel: View {
    let nodes: [TopicNode]
    var selectedTitle: String? = nil
    var onSelect: ((String) -> Void)? = nil

    var body: some View {
        if nodes.isEmpty {
            EmptyStateView(
                icon: "list.bullet",
                title: "暂无主题词条",
                message: "在设置详情页添加主题分类词条，或载入示例数据。"
            )
        } else {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(nodes) { node in
                    TopicTreeNodeView(node: node, selectedTitle: selectedTitle, onSelect: onSelect)
                }
            }
            .roundedPanel()
        }
    }
}

struct TopicTreeNodeView: View {
    let node: TopicNode
    let selectedTitle: String?
    var onSelect: ((String) -> Void)? = nil

    private var isLeaf: Bool { node.children.isEmpty }
    private var isSelected: Bool { node.title == selectedTitle }

    @ViewBuilder private var rowLabel: some View {
        HStack(spacing: 6) {
            if !node.children.isEmpty {
                Image(systemName: "chevron.down")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(AppTheme.textTertiary)
            } else {
                Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                    .font(.system(size: 9))
                    .foregroundStyle(isSelected ? AppTheme.accent : AppTheme.textTertiary)
            }
            Text(node.title)
                .font(font)
                .foregroundStyle(isSelected ? AppTheme.accent : node.level >= 4 ? AppTheme.textSecondary : .primary)
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
        .contentShape(Rectangle())
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected ? AppTheme.accent.opacity(0.10) : .clear)
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if isLeaf {
                Button { onSelect?(node.title) } label: { rowLabel }
                    .buttonStyle(.plain)
                    .help("点击按此主题筛选文献")
            } else {
                rowLabel
            }

            ForEach(node.children) { child in
                TopicTreeNodeView(node: child, selectedTitle: selectedTitle, onSelect: onSelect)
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

/// 统一的空状态占位视图：无数据时替代示例内容，并给出下一步操作提示。
struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 34, weight: .regular))
                .foregroundStyle(AppTheme.textTertiary)
            Text(title)
                .font(.system(size: 15, weight: .semibold))
            Text(message)
                .font(.system(size: 13))
                .foregroundStyle(AppTheme.textSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .frame(maxWidth: 360)
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(.borderedProminent)
                    .tint(AppTheme.accent)
                    .padding(.top, 2)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
        .padding(.horizontal, 20)
        .roundedPanel()
    }
}

/// 带标签的单行文本编辑字段。
struct LabeledField: View {
    let label: String
    @Binding var text: String

    init(_ label: String, text: Binding<String>) {
        self.label = label
        self._text = text
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(AppTheme.textTertiary)
                .textCase(.uppercase)
            TextField(label, text: $text)
                .textFieldStyle(.roundedBorder)
        }
    }
}

/// 待复核文献的人工编辑与保存表单。用 .id(article.id) 让切换文献时重置编辑缓冲。
struct ArticleReviewEditor: View {
    @ObservedObject var viewModel: AppViewModel
    let article: Article

    @State private var topic: String
    @State private var titleCN: String
    @State private var abstractCN: String
    @State private var studyType: String
    @State private var product: String
    @State private var note: String

    init(viewModel: AppViewModel, article: Article) {
        self.viewModel = viewModel
        self.article = article
        _topic = State(initialValue: article.topic)
        _titleCN = State(initialValue: article.titleCN)
        _abstractCN = State(initialValue: article.abstractCN)
        _studyType = State(initialValue: article.studyType)
        _product = State(initialValue: article.product)
        _note = State(initialValue: article.note)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("人工复核与编辑")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(AppTheme.textTertiary)
                    .textCase(.uppercase)
                Spacer()
                ConfidenceBadge(level: article.confidence)
            }

            LabeledField("主题分类", text: $topic)
            LabeledField("研究类型", text: $studyType)
            LabeledField("研究产品", text: $product)
            LabeledField("中文标题", text: $titleCN)

            VStack(alignment: .leading, spacing: 4) {
                Text("中文摘要")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(AppTheme.textTertiary)
                    .textCase(.uppercase)
                TextEditor(text: $abstractCN)
                    .font(.system(size: 13))
                    .frame(height: 96)
                    .padding(6)
                    .background(RoundedRectangle(cornerRadius: 8).fill(AppTheme.panelSecondary))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(AppTheme.line))
            }

            LabeledField("备注", text: $note)

            HStack(spacing: 10) {
                Button("保存修改") {
                    viewModel.saveArticleEdits(
                        id: article.id, topic: topic, titleCN: titleCN, abstractCN: abstractCN,
                        studyType: studyType, product: product, note: note, markReviewed: false
                    )
                }
                Spacer()
                Button("保存并标记已复核") {
                    viewModel.saveArticleEdits(
                        id: article.id, topic: topic, titleCN: titleCN, abstractCN: abstractCN,
                        studyType: studyType, product: product, note: note, markReviewed: true
                    )
                }
                .buttonStyle(.borderedProminent)
                .tint(AppTheme.accent)
            }
        }
        .roundedPanel()
    }
}

/// 导入映射确认/调整界面：展示分析结果，允许用户逐列调整“源列 → 底层字段”映射后再导入。
struct ImportMappingSheet: View {
    @ObservedObject var viewModel: AppViewModel
    let analysis: ImportAnalysis
    @State private var proposals: [ColumnProposal]

    init(viewModel: AppViewModel, analysis: ImportAnalysis) {
        self.viewModel = viewModel
        self.analysis = analysis
        _proposals = State(initialValue: analysis.proposals)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
            if analysis.kind == .classification {
                classificationContent
            } else {
                articleContent
            }
            Divider()
            footer
        }
        .frame(width: 640, height: 560)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(analysis.kind == .classification ? "确认分类字典导入" : "确认导入字段映射")
                .font(.system(size: 17, weight: .bold))
            Text(analysis.kind == .classification
                 ? "已识别为分类字典结构，可按需调整每列对应的分类层级后再导入（当前将构建 \(currentClassificationPathCount) 条主题路径）。"
                 : "已分析文件结构并给出字段映射建议，请确认或调整后导入（约 \(analysis.articleCountEstimate) 篇）。")
                .font(.system(size: 12.5))
                .foregroundStyle(AppTheme.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
    }

    private var articleContent: some View {
        ScrollView {
            VStack(spacing: 0) {
                if !missingRequiredFields.isEmpty {
                    Text("缺少必需映射：\(missingRequiredFields.map(\.label).joined(separator: "、"))。请至少完成这些字段映射后再导入。")
                        .font(.system(size: 12))
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 20)
                        .padding(.top, 10)
                        .padding(.bottom, 6)
                }

                HStack {
                    Text("源列 / 示例值")
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text("映射到底层字段")
                        .frame(width: 200, alignment: .leading)
                }
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(AppTheme.textTertiary)
                .textCase(.uppercase)
                .padding(.horizontal, 20)
                .padding(.vertical, 8)

                ForEach($proposals) { $proposal in
                    HStack(alignment: .top, spacing: 12) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(proposal.sourceHeader.isEmpty ? "（空列名）" : proposal.sourceHeader)
                                .font(.system(size: 13, weight: .semibold))
                            if !proposal.sample.isEmpty {
                                Text(proposal.sample)
                                    .font(.system(size: 11.5))
                                    .foregroundStyle(AppTheme.textSecondary)
                                    .lineLimit(1)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                        Picker("", selection: $proposal.field) {
                            ForEach(viewModel.canonicalFieldOptions) { option in
                                Text(option.label).tag(option.id)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 200)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
                    Divider().padding(.leading, 20)
                }
            }
        }
    }

    private var classificationContent: some View {
        ScrollView {
            VStack(spacing: 0) {
                Text("支持用户导入 Excel 后自行指定每列名称对应的分类层级（无需固定表头文字）。")
                    .font(.system(size: 12.5))
                    .foregroundStyle(AppTheme.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 10)

                HStack {
                    Text("源列 / 示例值")
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text("对应分类层级")
                        .frame(width: 200, alignment: .leading)
                }
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(AppTheme.textTertiary)
                .textCase(.uppercase)
                .padding(.horizontal, 20)
                .padding(.vertical, 8)

                ForEach($proposals) { $proposal in
                    HStack(alignment: .top, spacing: 12) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(proposal.sourceHeader.isEmpty ? "（空列名）" : proposal.sourceHeader)
                                .font(.system(size: 13, weight: .semibold))
                            if !proposal.sample.isEmpty {
                                Text(proposal.sample)
                                    .font(.system(size: 11.5))
                                    .foregroundStyle(AppTheme.textSecondary)
                                    .lineLimit(1)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                        Picker("", selection: $proposal.field) {
                            ForEach(viewModel.classificationFieldOptions) { option in
                                Text(option.label).tag(option.id)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 200)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
                    Divider().padding(.leading, 20)
                }
            }
        }
    }

    /// 依据当前（可能已被用户调整）的列角色映射，实时计算将构建的主题路径数，供界面提示。
    private var currentClassificationPathCount: Int {
        ClassificationEngine.flattenPaths(in: ImportAnalyzer.classificationScheme(from: analysis, proposals: proposals)).count
    }

    private var mappedArticleFieldIDs: Set<String> {
        Set(proposals.map(\.field).filter { !$0.isEmpty })
    }

    private var missingRequiredFields: [CanonicalField] {
        guard analysis.kind == .articles else { return [] }
        return viewModel.canonicalFieldOptions.filter {
            $0.priority == .required && !mappedArticleFieldIDs.contains($0.id)
        }
    }

    private var footer: some View {
        HStack {
            Button("取消") { viewModel.cancelImport() }
                .accessibilityIdentifier("btn-cancel-import")
            Spacer()
            Button("确认导入") {
                if analysis.kind == .classification {
                    viewModel.confirmClassificationImport(proposals: proposals)
                } else {
                    viewModel.confirmArticleImport(proposals: proposals)
                }
            }
            .disabled(analysis.kind == .articles && !missingRequiredFields.isEmpty)
            .buttonStyle(.borderedProminent)
            .tint(AppTheme.accent)
            .accessibilityIdentifier("btn-confirm-import")
        }
        .padding(20)
    }
}

/// 查看并自定义 AI 加工使用的 Prompt 模板（仅云端 LLM 生效）。
struct PromptEditorSheet: View {
    @ObservedObject var viewModel: AppViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var templates: PromptTemplates

    init(viewModel: AppViewModel) {
        self.viewModel = viewModel
        _templates = State(initialValue: viewModel.promptTemplates)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 6) {
                Text("AI 加工 Prompt 模板")
                    .font(.system(size: 17, weight: .bold))
                Text("占位符：{title} {abstract} {keywords} {candidates}。")
                    .font(.system(size: 12))
                    .foregroundStyle(AppTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    promptField("翻译 · System", text: $templates.translationSystem, height: 44)
                    promptField("翻译 · User", text: $templates.translationUser, height: 150)
                    promptField("主题分类 · System", text: $templates.classificationSystem, height: 44)
                    promptField("主题分类 · User", text: $templates.classificationUser, height: 150)
                }
                .padding(20)
            }

            Divider()

            HStack {
                Button("恢复默认") { templates = .default }
                Spacer()
                Button("取消") { dismiss() }
                Button("保存") {
                    viewModel.savePromptTemplates(templates)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .tint(AppTheme.accent)
            }
            .padding(20)
        }
        .frame(width: 660, height: 640)
    }

    private func promptField(_ label: String, text: Binding<String>, height: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(AppTheme.textTertiary)
                .textCase(.uppercase)
            TextEditor(text: text)
                .font(.system(size: 12.5, design: .monospaced))
                .frame(height: height)
                .padding(6)
                .background(RoundedRectangle(cornerRadius: 8).fill(AppTheme.panelSecondary))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(AppTheme.line))
        }
    }
}
