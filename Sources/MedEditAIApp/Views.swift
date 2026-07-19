import SwiftUI

struct SidebarView: View {
    @ObservedObject var viewModel: AppViewModel
    @State private var renamingProject: Project?
    @State private var renameText = ""

    var body: some View {
        List(selection: $viewModel.selectedSection) {
            Section("工作台") {
                ForEach(AppSection.allCases.filter { $0 != .settings }) { section in
                    Label(section.title, systemImage: section.systemImage)
                        .tag(section)
                        .accessibilityIdentifier("nav-\(section.rawValue)")
                }
            }

            Section("项目") {
                ForEach(viewModel.projects) { project in
                    Button {
                        viewModel.chooseProject(project)
                    } label: {
                        HStack(spacing: 10) {
                            Circle()
                                .fill(project.color)
                                .frame(width: 8, height: 8)
                            Text(project.name)
                                .foregroundStyle(viewModel.selectedProjectID == project.id ? AppTheme.accent : .primary)
                            Spacer()
                            if viewModel.selectedProjectID == project.id {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(AppTheme.accent)
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button("重命名") {
                            renamingProject = project
                            renameText = project.name
                        }
                        Button("删除", role: .destructive) {
                            viewModel.deleteProject(id: project.id)
                        }
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("MedEditAI")
        .alert("重命名项目", isPresented: Binding(
            get: { renamingProject != nil },
            set: { if !$0 { renamingProject = nil } }
        )) {
            TextField("项目名称", text: $renameText)
            Button("保存") {
                if let project = renamingProject {
                    viewModel.renameProject(id: project.id, to: renameText)
                }
                renamingProject = nil
            }
            Button("取消", role: .cancel) { renamingProject = nil }
        }
        .safeAreaInset(edge: .bottom) {
            HStack(spacing: 8) {
                Button {
                    viewModel.addProject(name: "新项目 \(viewModel.projects.count + 1)")
                } label: {
                    Label("新建项目", systemImage: "plus.circle.fill")
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("btn-add-project")

                Spacer()

                Button {
                    viewModel.navigate(to: .settings)
                } label: {
                    Label("设置", systemImage: "gearshape.fill")
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("btn-settings")
            }
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
                    subtitle: "真实案例驱动的医学编辑工作台"
                ) {
                    HStack(spacing: 10) {
                        if viewModel.hasData {
                            Button("清空数据") { viewModel.clearAll() }
                                .accessibilityIdentifier("btn-clear-data")
                        } else {
                            Button("载入示例数据") { viewModel.loadSampleData() }
                                .accessibilityIdentifier("btn-load-sample")
                        }
                        Button("开始检索") {
                            viewModel.navigate(to: .search)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(AppTheme.accent)
                        .accessibilityIdentifier("btn-start-search")
                    }
                }

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 180), spacing: 14)], spacing: 14) {
                    ForEach(viewModel.stats) { item in
                        StatCard(item: item)
                    }
                }

                SectionTitle(title: "快捷开始")

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 260), spacing: 14)], spacing: 14) {
                    ForEach(viewModel.quickActions) { action in
                        QuickActionCard(action: action) {
                            switch action.destination {
                            case .library:
                                viewModel.importDocument()
                            default:
                                viewModel.navigate(to: action.destination)
                            }
                        }
                    }
                }

                if viewModel.hasData {
                    VStack(alignment: .leading, spacing: 12) {
                        SectionTitle(title: "项目提醒")
                        VStack(spacing: 0) {
                            ForEach(viewModel.alerts) { alert in
                                HStack(spacing: 12) {
                                    Image(systemName: "bell.badge.fill")
                                        .foregroundStyle(AppTheme.accent)
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
                } else {
                    EmptyStateView(
                        icon: "tray",
                        title: "文献库为空",
                        message: "从 PubMed 检索、导入你自己的 Excel/CSV 清单，或先载入内置示例数据来体验完整流程。",
                        actionTitle: "载入示例数据",
                        action: { viewModel.loadSampleData() }
                    )
                }
            }
            .padding(24)
        }
    }
}

struct SearchView: View {
    @ObservedObject var viewModel: AppViewModel
    @State private var showingBatchOptions = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                PageHeader(title: "检索中心", subtitle: "透明展示 PubMed query，支持从零开始检索并直接入库") {
                    HStack(spacing: 10) {
                        Button("清空检索词") { viewModel.searchText = "" }
                            .disabled(viewModel.searchText.isEmpty)
                        Button("批量检索入库") {
                            showingBatchOptions = true
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(AppTheme.accent)
                        .disabled(viewModel.isBusy || viewModel.searchTerms.isEmpty)
                        .accessibilityIdentifier("btn-run-search")
                        .confirmationDialog("批量下载入库", isPresented: $showingBatchOptions) {
                            Button("下载所有检索结果（限前100条）") {
                                Task { await viewModel.batchImport(all: true) }
                            }
                            Button("仅保留勾选结果") {
                                Task { await viewModel.batchImport(all: false) }
                            }
                            Button("取消", role: .cancel) { }
                        } message: {
                            Text("即将把检索结果写入当前项目的文献库。")
                        }
                    }
                }

                HStack(spacing: 12) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(AppTheme.textSecondary)
                    TextField("输入检索词（多个词用 AND 连接）", text: $viewModel.searchText)
                        .textFieldStyle(.plain)
                        .accessibilityIdentifier("field-search")
                    Button("检索") {
                        Task { await viewModel.runSearch() }
                    }
                        .buttonStyle(.borderedProminent)
                        .tint(AppTheme.accent)
                        .disabled(viewModel.isBusy || viewModel.searchTerms.isEmpty)
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

                HStack(spacing: 16) {
                    HStack(spacing: 8) {
                        Text("起始年份")
                            .font(.system(size: 12.5))
                            .foregroundStyle(AppTheme.textSecondary)
                        Stepper("\(viewModel.yearFrom)", value: $viewModel.yearFrom, in: 1900...3000)
                            .frame(width: 130)
                    }
                    HStack(spacing: 8) {
                        Text("排序")
                            .font(.system(size: 12.5))
                            .foregroundStyle(AppTheme.textSecondary)
                        Picker("排序", selection: Binding(
                            get: { viewModel.sortOrder },
                            set: { newValue in Task { await viewModel.changeSort(newValue) } }
                        )) {
                            ForEach(viewModel.sortOptions) { option in
                                Text(option.title).tag(option)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                        .frame(width: 130)
                    }
                    HStack(spacing: 8) {
                        Text("每页条数")
                            .font(.system(size: 12.5))
                            .foregroundStyle(AppTheme.textSecondary)
                        Picker("每页条数", selection: Binding(
                            get: { viewModel.pageSize },
                            set: { newValue in Task { await viewModel.changePageSize(newValue) } }
                        )) {
                            ForEach(viewModel.pageSizeOptions, id: \.self) { size in
                                Text("\(size) 条/页").tag(size)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                        .frame(width: 110)
                        .accessibilityIdentifier("picker-page-size")
                    }
                    Spacer()
                }

                Text("PubMed query: \(viewModel.displayedQuery)")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(AppTheme.textSecondary)
                    .textSelection(.enabled)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(AppTheme.panelSecondary))
                    .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [5, 4])).foregroundStyle(AppTheme.line))

                if viewModel.articles.isEmpty {
                    EmptyStateView(
                        icon: "magnifyingglass",
                        title: "暂无检索结果",
                        message: "点击“批量检索入库”从 PubMed 拉取文献，或在文献库导入本地 Excel/CSV。勾选结果可仅导出所选。"
                    )
                } else {
                    if viewModel.totalHits > 0 {
                        HStack(spacing: 12) {
                            Text(viewModel.resultRangeText)
                                .font(.system(size: 12.5, weight: .medium))
                                .foregroundStyle(AppTheme.textSecondary)
                            Spacer()
                            Button {
                                Task { await viewModel.prevPage() }
                            } label: {
                                Label("上一页", systemImage: "chevron.left")
                            }
                            .disabled(!viewModel.canGoPrevPage || viewModel.isBusy)
                            Text("第 \(viewModel.currentPage + 1) / \(max(viewModel.totalPages, 1)) 页")
                                .font(.system(size: 12.5, weight: .semibold))
                            Button {
                                Task { await viewModel.nextPage() }
                            } label: {
                                Label("下一页", systemImage: "chevron.right")
                            }
                            .disabled(!viewModel.canGoNextPage || viewModel.isBusy)
                        }
                    }

                    VStack(spacing: 0) {
                        SearchHeaderRow()
                        ForEach(viewModel.articles) { article in
                            Button {
                                viewModel.toggleExportSelection(article)
                            } label: {
                                SearchArticleRow(article: article, isChecked: viewModel.isSelectedForExport(article))
                            }
                            .buttonStyle(.plain)
                            if article.id != viewModel.articles.last?.id {
                                Divider()
                            }
                        }
                    }
                    .roundedPanel(padding: 0)
                }
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
                        .accessibilityIdentifier("btn-import-excel")
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
                    TopicTreePanel(
                        nodes: viewModel.topicTree,
                        selectedTitle: viewModel.selectedTopic,
                        onSelect: { viewModel.selectTopic($0) }
                    )
                    .frame(width: 260, alignment: .topLeading)

                    if viewModel.articles.isEmpty {
                        EmptyStateView(
                            icon: "books.vertical",
                            title: "文献库为空",
                            message: "点击右上角“导入 Excel”从本地清单智能映射入库，或到检索中心从 PubMed 拉取。",
                            actionTitle: "导入 Excel/CSV",
                            action: { viewModel.importDocument() }
                        )
                    } else {
                        VStack(alignment: .leading, spacing: 8) {
                            if let topic = viewModel.selectedTopic {
                                HStack(spacing: 8) {
                                    Image(systemName: "line.3.horizontal.decrease.circle.fill")
                                        .foregroundStyle(AppTheme.accent)
                                    Text("按主题筛选：\(topic)（\(viewModel.filteredArticles.count) 篇）")
                                        .font(.system(size: 12.5, weight: .medium))
                                    Spacer()
                                    Button("清除筛选") { viewModel.selectTopic(nil) }
                                        .buttonStyle(.plain)
                                        .foregroundStyle(AppTheme.accentBlue)
                                }
                                .padding(.horizontal, 4)
                            }

                            if viewModel.filteredArticles.isEmpty {
                                Text("该主题下暂无文献")
                                    .font(.system(size: 12.5))
                                    .foregroundStyle(AppTheme.textTertiary)
                                    .padding(16)
                            } else {
                                VStack(spacing: 0) {
                                    ForEach(viewModel.filteredArticles) { article in
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
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
        }
    }
}

struct LibraryDetailView: View {
    @ObservedObject var viewModel: AppViewModel
    let article: Article

    private var isRealArticle: Bool { article.id != "placeholder" && viewModel.hasData }

    private var metadataPairs: [(String, String)] {
        var pairs: [(String, String)] = [
            ("作者", article.authors),
            ("日期", article.date),
            ("研究类型", article.studyType),
            ("期刊", article.journal),
            ("影响因子", "\(article.impactFactor) · \(article.quartile)"),
            ("PMID", article.pmid)
        ]
        if !article.keywords.isEmpty { pairs.append(("关键词", article.keywords)) }
        return pairs
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("详情与 AI 结果")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(AppTheme.textSecondary)
                    .textCase(.uppercase)

                if isRealArticle {
                    ArticleReviewEditor(viewModel: viewModel, article: article)
                        .id(article.id + "|" + article.titleCN + "|" + article.abstractCN + "|" + article.topic + "|" + article.studyType + "|" + article.product + "|" + article.note)
                }

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
                    DetailKeyValueGrid(pairs: metadataPairs)
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
                        Button("清除选择") { viewModel.selectedForExport.removeAll() }
                            .disabled(viewModel.selectedForExport.isEmpty)
                        Button(viewModel.selectedForExport.isEmpty ? "加工全部" : "加工所选") {
                            Task { await viewModel.runEnrichment() }
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(AppTheme.accent)
                        .disabled(viewModel.isBusy || !viewModel.hasData)
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
                            Text(viewModel.hasData
                                 ? "本次将处理 \(viewModel.enrichmentTargetCount) 篇文献（\(viewModel.selectedForExport.isEmpty ? "全部" : "已选")），优先输出中文摘要、研究设计、主题分类与 IF 匹配。"
                                 : "当前文献库为空，请先在检索中心或文献库导入数据后再运行批处理。")
                                .font(.system(size: 13.5))
                                .foregroundStyle(AppTheme.textSecondary)

                            ProgressView(value: viewModel.progress)
                                .tint(AppTheme.accent)
                            Text("进度 \(Int(viewModel.progress * 100))% · 可断点续跑")
                                .font(.system(size: 12))
                                .foregroundStyle(AppTheme.textSecondary)

                            if viewModel.queue.isEmpty {
                                Text("暂无排队文献")
                                    .font(.system(size: 12.5))
                                    .foregroundStyle(AppTheme.textTertiary)
                                    .padding(.vertical, 8)
                            } else {
                                VStack(spacing: 0) {
                                    ForEach(viewModel.queue) { item in
                                        QueueRow(item: item)
                                        if item.id != viewModel.queue.last?.id {
                                            Divider()
                                        }
                                    }
                                }
                            }
                        }
                        .roundedPanel()
                    }
                }

                HStack(alignment: .top, spacing: 14) {
                    InfoPanel(
                        title: "分类体系",
                        text: viewModel.topicTree.isEmpty
                            ? "尚未导入主题分类体系，可在设置中导入四级分类字典。"
                            : "已加载主题分类体系，共 \(viewModel.topicTree.count) 个顶层主题。",
                        tags: []
                    )
                    InfoPanel(
                        title: "可信度策略",
                        text: "所有 AI 结果与原始字段分层存储，不覆盖原始数据；低置信度结果自动进入待复核。",
                        tags: []
                    )
                    InfoPanel(
                        title: "LLM 模式",
                        text: viewModel.apiKey.isEmpty
                            ? "未配置 API Key：使用离线本地识别，未命中词典的译文标注“待人工校对”。"
                            : "已配置 API Key：使用云端 LLM 进行翻译与主题分类。",
                        tags: []
                    )
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
                        .disabled(!viewModel.hasData)
                        Button("导出 PPT") {
                            viewModel.exportPPTX()
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(AppTheme.accent)
                        .disabled(!viewModel.hasData)
                    }
                }

                if !viewModel.hasData {
                    EmptyStateView(
                        icon: "play.rectangle.on.rectangle",
                        title: "暂无可生成的交付物",
                        message: "请先导入文献或从 PubMed 检索。产出生成会使用你选择的 onepage .pptx 模板与自定义 Excel 导出模板。",
                        actionTitle: "载入示例数据",
                        action: { viewModel.loadSampleData() }
                    )
                } else {
                    VStack(alignment: .leading, spacing: 12) {
                        SectionTitle(title: "PPT 预览（onepage 模板）")
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                ForEach(Array(viewModel.articles.prefix(8).enumerated()), id: \.element.id) { index, article in
                                    Button {
                                        viewModel.chooseSlide(index: index)
                                    } label: {
                                        SlideThumbnail(article: article, index: index + 1, selected: viewModel.selectedSlideIndex == index)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    .roundedPanel()

                    SlideSettingsPanel(templateName: viewModel.pptTemplateName)

                    MappingPanel(title: "PPT 占位符映射", items: viewModel.pptMappings)
                    MappingPanel(title: "Excel 导出模板", items: Array(viewModel.exportMappings.prefix(6)), footer: "支持自定义列名、列顺序、超链接字段和年份化 IF 列（如“2025年IF”）。")
                }
            }
            .padding(24)
        }
    }
}

struct SettingsView: View {
    @ObservedObject var viewModel: AppViewModel
    @State private var showingPromptEditor = false

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
                            subtitle: "必填；用于调用云端 LLM 执行翻译与主题分析（未配置时无法进行 AI 加工）",
                            placeholder: "sk-...",
                            text: $viewModel.apiKey
                        )
                        Divider()
                        SettingsActionRow(
                            title: "AI 加工 Prompt",
                            subtitle: "查看并自定义翻译 / 主题分类使用的 Prompt（仅云端 LLM 生效）",
                            button: "查看 / 编辑"
                        ) { showingPromptEditor = true }
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
                            subtitle: viewModel.pptTemplateURL?.lastPathComponent ?? "未选择：不提供内置模板，需上传您自备的 .pptx（导出时会再次提示选择）",
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
                        SettingInlineRow(title: "研究类型体系", subtitle: viewModel.customStudyTerms.isEmpty ? "未配置：AI 自动推断" : viewModel.customStudyTerms.joined(separator: " / "), trailing: "自定义")
                        CustomStudyTermsEditor(viewModel: viewModel)
                            .padding(.horizontal, 16)
                            .padding(.bottom, 12)
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
        .sheet(isPresented: $showingPromptEditor) {
            PromptEditorSheet(viewModel: viewModel)
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
            InfoPanel(
                title: "当前检索",
                text: viewModel.searchTerms.isEmpty
                    ? "输入检索词（多个用 AND 连接）后，将透明展示等价 PubMed 检索式，并支持排序与分页。"
                    : "检索式：\(viewModel.displayedQuery)",
                tags: viewModel.totalHits > 0 ? ["共 \(viewModel.totalHits) 条命中"] : []
            )
        }
        .padding(20)
    }
}

struct EnrichDetailView: View {
    @ObservedObject var viewModel: AppViewModel

    var body: some View {
        LibraryDetailView(viewModel: viewModel, article: viewModel.activeArticle)
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
                ManualTopicEntryField(viewModel: viewModel)
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
                Text("工作台说明")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(AppTheme.textSecondary)
                    .textCase(.uppercase)
                InfoPanel(title: "完整工作流", text: "从 PubMed 检索或导入本地清单 → AI 加工（翻译 / 研究设计 / 主题分类 / IF 匹配）→ 人工复核 → 导出 Excel 与 onepage PPT。", tags: ["检索/导入", "AI 加工", "导出"])
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
