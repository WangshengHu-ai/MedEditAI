import SwiftUI

struct SidebarView: View {
    @ObservedObject var viewModel: AppViewModel

    var body: some View {
        List(selection: $viewModel.selectedSection) {
            Section("工作台") {
                ForEach(AppSection.allCases.filter { $0 != .settings }) { section in
                    Label(section.title, systemImage: section.systemImage)
                        .tag(section)
                }
            }

            Section("项目") {
                ForEach(viewModel.projects) { project in
                    HStack(spacing: 10) {
                        Circle()
                            .fill(project.color)
                            .frame(width: 8, height: 8)
                        Text(project.name)
                        Spacer()
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        viewModel.chooseProject(project)
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("MedEditAI")
        .safeAreaInset(edge: .bottom) {
            Button {
                viewModel.navigate(to: .settings)
            } label: {
                Label("设置", systemImage: "gearshape.fill")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
            .padding(12)
            .background(.bar)
        }
    }
}

struct DashboardView: View {
    @ObservedObject var viewModel: AppViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                PageHeader(
                    title: viewModel.selectedProject.name,
                    subtitle: "真实案例驱动的医学编辑工作台，当前项目为 PFA 图书馆"
                ) {
                    HStack(spacing: 10) {
                        Button("演示批处理") {
                            viewModel.navigate(to: .enrich)
                            Task { await viewModel.runEnrichment() }
                        }
                        Button("开始检索") {
                            viewModel.navigate(to: .search)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(AppTheme.accent)
                    }
                }

                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 14), count: 4), spacing: 14) {
                    ForEach(viewModel.stats) { item in
                        StatCard(item: item)
                    }
                }

                SectionTitle(title: "快捷开始")

                HStack(spacing: 14) {
                    ForEach(viewModel.quickActions) { action in
                        QuickActionCard(action: action) {
                            viewModel.navigate(to: action.destination)
                        }
                    }
                }

                HStack(alignment: .top, spacing: 14) {
                    VStack(alignment: .leading, spacing: 12) {
                        SectionTitle(title: "项目提醒")
                        VStack(spacing: 0) {
                            ForEach(viewModel.alerts) { alert in
                                HStack(spacing: 12) {
                                    ConfidenceBadge(level: .high)
                                    Text(alert.title)
                                        .font(.system(size: 13.5, weight: .medium))
                                    Spacer()
                                }
                                .padding(.vertical, 12)
                                if alert.id != viewModel.alerts.last?.id {
                                    Divider()
                                }
                            }
                        }
                        .roundedPanel()
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        SectionTitle(title: "PFA 案例摘要")
                        VStack(alignment: .leading, spacing: 12) {
                            Text("当前原型直接按真实案例抽象：工作稿 Excel 与交付 Excel 为两套不同列结构；主题分类采用四级菜单树；研究类型存在客户自定义术语；PPT 为纵向 A4 onepage 结构化模板。")
                                .font(.system(size: 13.5))
                                .foregroundStyle(AppTheme.textSecondary)
                                .lineSpacing(4)

                            HStack(spacing: 8) {
                                Chip(text: "四级主题树", tint: AppTheme.accent)
                                Chip(text: "自定义 IF 数据源", tint: AppTheme.accentBlue)
                                Chip(text: "用户模板 PPT", tint: AppTheme.ok)
                            }
                        }
                        .roundedPanel()
                    }
                }
            }
            .padding(24)
        }
    }
}

struct SearchView: View {
    @ObservedObject var viewModel: AppViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                PageHeader(title: "检索中心", subtitle: "透明展示 PubMed query，支持从零开始检索并直接入库") {
                    HStack(spacing: 10) {
                        Button("高级检索式构建器") {}
                        Button("批量检索入库") {
                            Task { await viewModel.runSearch() }
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(AppTheme.accent)
                        .disabled(viewModel.isBusy)
                    }
                }

                HStack(spacing: 12) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(AppTheme.textSecondary)
                    TextField("输入检索词", text: $viewModel.searchText)
                        .textFieldStyle(.plain)
                    Button("检索") {
                        Task { await viewModel.runSearch() }
                    }
                        .buttonStyle(.borderedProminent)
                        .tint(AppTheme.accent)
                        .disabled(viewModel.isBusy)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(AppTheme.panel)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(AppTheme.line)
                )

                FlowLayout(spacing: 8) {
                    ForEach(viewModel.searchFilters, id: \.self) { filter in
                        FilterChip(text: filter, isOn: viewModel.enabledFilters.contains(filter)) {
                            viewModel.toggleFilter(filter)
                        }
                    }
                }

                Text("PubMed query: (\"pulsed field ablation\"[Title/Abstract] OR PFA[Title/Abstract]) AND (\"atrial fibrillation\"[Title/Abstract] OR AF[Title/Abstract]) AND (2024:3000[pdat])")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(AppTheme.textSecondary)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(AppTheme.panelSecondary))
                    .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [5, 4])).foregroundStyle(AppTheme.line))

                VStack(spacing: 0) {
                    SearchHeaderRow()
                    ForEach(Array(viewModel.articles.enumerated()), id: \.element.id) { index, article in
                        SearchArticleRow(article: article, isChecked: index < 3)
                        if article.id != viewModel.articles.last?.id {
                            Divider()
                        }
                    }
                }
                .roundedPanel(padding: 0)
            }
            .padding(24)
        }
    }
}

struct LibraryListView: View {
    @ObservedObject var viewModel: AppViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            PageHeader(title: "文献库", subtitle: "三栏工作台：分类树 / 文献列表 / 中英对照详情") {
                HStack(spacing: 10) {
                    Button("导入 Excel") { viewModel.importDocument() }
                    Button("批量 AI 加工") {
                        viewModel.navigate(to: .enrich)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(AppTheme.accent)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 24)
            .padding(.bottom, 12)

            ScrollView {
                HStack(alignment: .top, spacing: 16) {
                    TopicTreePanel(nodes: viewModel.topicTree)
                        .frame(width: 260, alignment: .topLeading)

                    VStack(spacing: 0) {
                        ForEach(viewModel.articles) { article in
                            Button {
                                viewModel.chooseArticle(article)
                            } label: {
                                ArticleListCard(article: article, isSelected: viewModel.selectedArticle?.id == article.id)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .roundedPanel(padding: 0)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
        }
    }
}

struct LibraryDetailView: View {
    let article: Article

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("详情与 AI 结果")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(AppTheme.textSecondary)
                    .textCase(.uppercase)

                DetailBlock(title: "标题") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(article.titleEN)
                            .font(.system(size: 14, weight: .semibold))
                        Text(article.titleCN)
                            .font(.system(size: 13.5))
                            .padding(10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(RoundedRectangle(cornerRadius: 10).fill(AppTheme.accent.opacity(0.1)))
                    }
                }

                DetailBlock(title: "元数据") {
                    DetailKeyValueGrid(pairs: [
                        ("作者", article.authors),
                        ("日期", article.date),
                        ("研究类型", article.studyType),
                        ("期刊", article.journal),
                        ("影响因子", "\(article.impactFactor) · \(article.quartile)"),
                        ("PMID", article.pmid)
                    ])
                }

                DetailBlock(title: "摘要中译") {
                    VStack(alignment: .leading, spacing: 10) {
                        ConfidenceBadge(level: article.confidence)
                        Text(article.abstractCN)
                            .font(.system(size: 13.5))
                            .lineSpacing(4)
                    }
                }

                DetailBlock(title: "AI 字段") {
                    VStack(spacing: 8) {
                        AIFieldRow(label: "研究设计", value: article.studyType, trailing: article.confidence.title)
                        AIFieldRow(label: "主题分类", value: article.topic, trailing: "四级菜单")
                        AIFieldRow(label: "研究产品", value: article.product, trailing: "词典识别")
                        AIFieldRow(label: "证据等级", value: article.evidence, trailing: "自动联动")
                    }
                }

                DetailBlock(title: "备注") {
                    Text(article.note)
                        .font(.system(size: 13.5))
                        .foregroundStyle(AppTheme.textSecondary)
                        .lineSpacing(4)
                }
            }
            .padding(20)
        }
    }
}

struct EnrichView: View {
    @ObservedObject var viewModel: AppViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                PageHeader(title: "AI 加工", subtitle: "每项任务独立可开关、可重跑、可回滚；低置信度自动进入待复核") {
                    HStack(spacing: 10) {
                        Button("切换任务") {
                            if let first = viewModel.tasks.first {
                                viewModel.toggleTask(first)
                            }
                        }
                        Button("运行批处理") {
                            Task { await viewModel.runEnrichment() }
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(AppTheme.accent)
                        .disabled(viewModel.isBusy)
                    }
                }

                HStack(alignment: .top, spacing: 16) {
                    VStack(alignment: .leading, spacing: 12) {
                        SectionTitle(title: "加工项")
                        VStack(spacing: 12) {
                            ForEach(viewModel.tasks) { task in
                                ProcessingTaskRow(task: task) {
                                    viewModel.toggleTask(task)
                                }
                            }
                        }
                        .roundedPanel()
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        SectionTitle(title: "批处理队列")
                        VStack(alignment: .leading, spacing: 16) {
                            Text("本次将处理 23 篇文献，优先输出中文摘要、研究设计、主题分类与 IF 匹配。")
                                .font(.system(size: 13.5))
                                .foregroundStyle(AppTheme.textSecondary)

                            ProgressView(value: viewModel.progress)
                                .tint(AppTheme.accent)
                            Text("进度 \(Int(viewModel.progress * 100))% · 可断点续跑")
                                .font(.system(size: 12))
                                .foregroundStyle(AppTheme.textSecondary)

                            VStack(spacing: 0) {
                                ForEach(viewModel.queue) { item in
                                    QueueRow(item: item)
                                    if item.id != viewModel.queue.last?.id {
                                        Divider()
                                    }
                                }
                            }
                        }
                        .roundedPanel()
                    }
                }

                HStack(alignment: .top, spacing: 14) {
                    InfoPanel(title: "分类体系", text: "当前启用「PFA 图书馆主题树（四级）」与「PFA 研究类型（自定义）」两套方案，可按项目切换。", tags: ["四级菜单", "呈现方式字段", "备注字段"])
                    InfoPanel(title: "可信度策略", text: "所有 AI 结果都与原始文献字段分层存储，不覆盖原始数据。低置信度结果自动进入待复核列表。", tags: [])
                    InfoPanel(title: "客户自定义术语", text: "示例：研究类型包含“综述”“社论”“动物实验”“土豆模型”。系统仅提供标准化机制，不强制替换客户术语。", tags: [])
                }
            }
            .padding(24)
        }
    }
}

struct SlidesView: View {
    @ObservedObject var viewModel: AppViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                PageHeader(title: "产出生成", subtitle: "PPT + Excel 双交付物；客户模板即产品模板") {
                    HStack(spacing: 10) {
                        Button("导出 Excel") {
                            viewModel.exportExcel()
                        }
                        Button("导出 PPT") {
                            viewModel.exportPPTX()
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(AppTheme.accent)
                    }
                }

                HStack(alignment: .top, spacing: 16) {
                    VStack(alignment: .leading, spacing: 12) {
                        SectionTitle(title: "PPT 预览（onepage 模板）")
                        HStack(alignment: .top, spacing: 14) {
                            VStack(spacing: 10) {
                                ForEach(Array(viewModel.articles.prefix(5).enumerated()), id: \.element.id) { index, article in
                                    Button {
                                        viewModel.chooseSlide(index: index)
                                    } label: {
                                        SlideThumbnail(article: article, index: index + 1, selected: viewModel.selectedSlideIndex == index)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }

                            SlidePreviewCard(article: viewModel.activeArticle)

                            SlideSettingsPanel()
                        }
                        .roundedPanel()
                    }

                    VStack(alignment: .leading, spacing: 16) {
                        MappingPanel(title: "PPT 占位符映射", items: viewModel.pptMappings)
                        MappingPanel(title: "Excel 导出模板", items: Array(viewModel.exportMappings.prefix(6)), footer: "支持自定义列名、列顺序、超链接字段和年份化 IF 列（如“2025年IF”）。")
                    }
                    .frame(width: 340)
                }
            }
            .padding(24)
        }
    }
}

struct SettingsView: View {
    @ObservedObject var viewModel: AppViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                PageHeader(title: "设置与数据源", subtitle: "管理模型、IF 数据集、分类体系、导入/导出模板") {
                    HStack(spacing: 10) {
                        Button("导入分类字典") { viewModel.importClassificationDictionary() }
                        Button("保存配置") { viewModel.showToast("配置已保存") }
                            .buttonStyle(.borderedProminent)
                            .tint(AppTheme.accent)
                    }
                }

                HStack(alignment: .top, spacing: 16) {
                    VStack(spacing: 0) {
                        SettingsSecureRow(
                            title: "LLM API Key",
                            subtitle: "留空则使用离线本地模型；填入后调用云端 LLM",
                            placeholder: "sk-...",
                            text: $viewModel.apiKey
                        )
                        Divider()
                        SettingInlineRow(title: "NCBI API Key", subtitle: "提升 PubMed 检索速率，遵守限流规则", trailing: "可选")
                        Divider()
                        SettingsActionRow(
                            title: "IF / 分区数据集",
                            subtitle: viewModel.impactFactorByJournal.isEmpty ? "未导入（用户自持版权数据）" : "已导入 \(viewModel.impactFactorByJournal.count) 条",
                            button: "导入"
                        ) { viewModel.importImpactFactors() }
                        Divider()
                        SettingsActionRow(
                            title: "PPT 模板",
                            subtitle: viewModel.pptTemplateURL?.lastPathComponent ?? "未选择 onepage.pptx",
                            button: "选择"
                        ) { viewModel.chooseTemplate() }
                    }
                    .roundedPanel(padding: 0)

                    VStack(spacing: 0) {
                        SettingsActionRow(title: "导入文献", subtitle: "Excel / CSV，智能列映射不要求固定格式", button: "导入") { viewModel.importDocument() }
                        Divider()
                        SettingsActionRow(title: "导出交付 Excel", subtitle: "11 列，含摘要链接 / 原文链接", button: "导出") { viewModel.exportExcel() }
                        Divider()
                        SettingsActionRow(title: "导出 onepage PPT", subtitle: "使用客户自备 .pptx 模板填充", button: "导出") { viewModel.exportPPTX() }
                        Divider()
                        SettingInlineRow(title: "研究类型体系", subtitle: viewModel.customStudyTerms.joined(separator: " / "), trailing: "自定义")
                    }
                    .roundedPanel(padding: 0)
                }

                HStack(alignment: .top, spacing: 16) {
                    MappingPanel(title: "导入映射预览", items: viewModel.importMappings)
                    InfoPanel(
                        title: "数据源状态",
                        text: "文献 \(viewModel.articles.count) 篇已入库；IF 数据 \(viewModel.impactFactorByJournal.count) 条；PPT 模板 \(viewModel.pptTemplateURL == nil ? "未配置" : "已配置")。所有数据本地持久化，可离线使用。",
                        tags: ["本地持久化", "客户自定义", "可追溯"]
                    )
                }
            }
            .padding(24)
        }
    }
}

struct SearchContextDetailView: View {
    @ObservedObject var viewModel: AppViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("检索上下文")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(AppTheme.textSecondary)
                .textCase(.uppercase)
            InfoPanel(title: "当前检索意图", text: "围绕 PFA 与房颤场景，筛选近 90 天、高影响因子、综述类文献，直接进入项目库。", tags: ["PubMed", "透明 query", "批量下载"])
        }
        .padding(20)
    }
}

struct EnrichDetailView: View {
    @ObservedObject var viewModel: AppViewModel

    var body: some View {
        LibraryDetailView(article: viewModel.activeArticle)
    }
}

struct SettingsDetailView: View {
    @ObservedObject var viewModel: AppViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("主题分类（四级菜单）")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(AppTheme.textSecondary)
                    .textCase(.uppercase)
                TopicTreePanel(nodes: viewModel.topicTree)
            }
            .padding(20)
        }
    }
}

struct InsightDetailView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("项目洞察")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(AppTheme.textSecondary)
                    .textCase(.uppercase)
                InfoPanel(title: "为什么必须做成原生 macOS App", text: "你的场景本质是桌面生产力工具：需要强文件系统能力、本地模板、批量处理、可信存储和稳定导入导出。SwiftUI 原生实现会比 WebView 或网页壳更稳。", tags: ["SwiftUI", "SwiftData", "原生文件导入"])
            }
            .padding(20)
        }
    }
}

struct SlidePreviewDetailView: View {
    let article: Article

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("当前幻灯详情")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(AppTheme.textSecondary)
                    .textCase(.uppercase)
                SlidePreviewCard(article: article)
            }
            .padding(20)
        }
    }
}
