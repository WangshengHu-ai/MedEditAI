import SwiftUI

struct SidebarView: View {
    @ObservedObject var viewModel: AppViewModel
    @State private var renamingProject: Project?
    @State private var renameText = ""
    @State private var showingNewProjectAlert = false
    @State private var newProjectText = ""

    var body: some View {
        List(selection: $viewModel.selectedSection) {
            Section("工作台") {
                ForEach(AppSection.allCases) { section in
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
        .alert("新建项目", isPresented: $showingNewProjectAlert) {
            TextField("项目名称", text: $newProjectText)
            Button("创建") {
                viewModel.addProject(name: newProjectText)
            }
            Button("取消", role: .cancel) { }
        } message: {
            Text("请输入项目名称，稍后可在项目列表里右键重命名。")
        }
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
                    newProjectText = "新项目 \(viewModel.projects.count + 1)"
                    showingNewProjectAlert = true
                } label: {
                    Label("新建项目", systemImage: "plus.circle.fill")
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("btn-add-project")

                Spacer()
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
    @State private var yearInput: String = ""

    /// 起始年份支持“不指定”：清空输入框即代表不限制起始年份，检索会覆盖所有年份。
    private var yearBinding: Binding<String> {
        Binding(
            get: {
                if !yearInput.isEmpty { return yearInput }
                if let year = viewModel.yearFrom { return "\(year)" }
                return ""
            },
            set: { newValue in
                yearInput = newValue.filter { $0.isNumber }
                if yearInput.isEmpty {
                    Task { await viewModel.changeYearFrom(nil) }
                } else if let value = Int(yearInput), (1900...3000).contains(value) {
                    Task { await viewModel.changeYearFrom(value) }
                }
            }
        )
    }

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
                        TextField("不限", text: yearBinding)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 92)
                            .accessibilityIdentifier("field-year-from")
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
                        .frame(width: 130)
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

                if !viewModel.hasSearchResults {
                    EmptyStateView(
                        icon: "magnifyingglass",
                        title: "暂无检索结果",
                        message: "输入检索词后点击“检索”从 PubMed 拉取文献。勾选结果后用“批量检索入库”将其加入当前项目文献库；检索结果不会自动进入文献库。"
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
                        ForEach(viewModel.searchResults) { article in
                            Button {
                                viewModel.chooseSearchResult(article)
                                viewModel.toggleSearchImport(article)
                            } label: {
                                SearchArticleRow(article: article, isChecked: viewModel.isSelectedForImport(article))
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("search-article-\(article.id)")
                            if article.id != viewModel.searchResults.last?.id {
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

    private var displayedArticles: [Article] {
        let base = viewModel.filteredArticles
        if viewModel.showLowConfidenceOnly {
            return base.filter { $0.confidence == .low }
        }
        return base
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            PageHeader(title: "文献库", subtitle: "三栏工作台：分类树 / 文献列表 / 中英对照详情") {
                HStack(spacing: 10) {
                    Button("导入 Excel") { viewModel.importDocument() }
                        .accessibilityIdentifier("btn-import-excel")
                    Button(viewModel.showLowConfidenceOnly ? "显示全部" : "仅看低置信度") {
                        viewModel.showLowConfidenceOnly.toggle()
                    }
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("btn-low-confidence-filter")
                    Button("批量标记已复核") {
                        let ids = displayedArticles.filter { $0.confidence == .low }.map(\.id)
                        viewModel.markArticlesReviewed(ids: ids)
                    }
                    .buttonStyle(.bordered)
                    .disabled(displayedArticles.allSatisfy { $0.confidence != .low })
                    .accessibilityIdentifier("btn-mark-reviewed")
                    Button("批量 AI 加工") {
                        viewModel.navigate(to: .enrich)
                        Task { await viewModel.runEnrichment() }
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

                    if displayedArticles.isEmpty {
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

                            if displayedArticles.isEmpty {
                                Text("该主题下暂无文献")
                                    .font(.system(size: 12.5))
                                    .foregroundStyle(AppTheme.textTertiary)
                                    .padding(16)
                            } else {
                                VStack(spacing: 0) {
                                    ForEach(displayedArticles) { article in
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
                        AIFieldRow(label: "主题分类", value: article.topic, trailing: "词条列表")
                        AIFieldRow(label: "研究产品", value: article.product, trailing: "词典识别")
                        AIFieldRow(label: "证据等级", value: article.evidence, trailing: "自动联动")
                    }
                }

                if !article.customFields.isEmpty {
                    DetailBlock(title: "自定义加工字段") {
                        VStack(spacing: 8) {
                            ForEach(article.customFields.keys.sorted(), id: \.self) { key in
                                AIFieldRow(label: key, value: article.customFields[key] ?? "", trailing: "自定义")
                            }
                        }
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

    private var customTasksBinding: Binding<[CustomProcessingTask]> {
        Binding(get: { viewModel.customTasks }, set: { viewModel.updateCustomTasks($0) })
    }

    private var queueSummary: String {
        let done = viewModel.queue.filter { $0.status == .done }.count
        let running = viewModel.queue.filter { $0.status == .running }.count
        let paused = viewModel.queue.filter { $0.status == .paused }.count
        let failed = viewModel.queue.filter { $0.status == .failed }.count
        let waiting = viewModel.queue.filter { $0.status == .waiting }.count
        return "已完成 \(done) · 处理中 \(running) · 已暂停 \(paused) · 失败 \(failed) · 未处理 \(waiting)"
    }

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
                        .accessibilityIdentifier("btn-run-enrichment")
                        if viewModel.isBusy {
                            Button(viewModel.isEnrichmentPaused ? "继续" : "暂停") {
                                if viewModel.isEnrichmentPaused {
                                    viewModel.resumeEnrichment()
                                } else {
                                    viewModel.pauseEnrichment()
                                }
                            }
                            .buttonStyle(.bordered)
                            .accessibilityIdentifier("btn-toggle-enrichment")
                        }
                    }
                }

                if viewModel.enrichmentCompleted {
                    HStack {
                        InfoPanel(title: "AI 加工完成", text: "结果已实时回写到文献库，可直接跳转查看。", tags: ["已更新文献库"])
                        Button("跳转到文献库页") {
                            viewModel.navigate(to: .library)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(AppTheme.accent)
                        .accessibilityIdentifier("btn-jump-library")
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

                        CustomProcessingTasksEditorPanel(tasks: customTasksBinding)
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        SectionTitle(title: "批处理队列")
                        VStack(alignment: .leading, spacing: 16) {
                            Text(viewModel.hasData
                                 ? "本次将处理 \(viewModel.enrichmentTargetCount) 篇文献（\(viewModel.selectedForExport.isEmpty ? "全部" : "已选")），优先输出中文摘要、研究设计、主题分类与 IF 匹配。"
                                 : "当前文献库为空，请先在检索中心或文献库导入数据后再运行批处理。")
                                .font(.system(size: 13.5))
                                .foregroundStyle(AppTheme.textSecondary)

                            Text(queueSummary)
                                .font(.system(size: 12))
                                .foregroundStyle(AppTheme.textTertiary)

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
                        text: viewModel.topicTerms.isEmpty
                            ? "尚未配置主题分类词条，可在设置详情页逐条添加。"
                            : "已配置主题分类词条，共 \(viewModel.topicTerms.count) 个词条。",
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
                            ? "未配置 API Key：AI 加工需要云端 LLM 支持，暂时无法运行；请先在设置中配置 API Key。"
                            : "已配置 API Key：使用云端 LLM 进行翻译、研究设计和主题分类。",
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

    private var exportColumnsBinding: Binding<[ExportColumnConfig]> {
        Binding(get: { viewModel.exportColumns }, set: { viewModel.updateExportColumns($0) })
    }

    private var pptMappingsBinding: Binding<[PPTPlaceholderMapping]> {
        Binding(get: { viewModel.pptPlaceholderMappings }, set: { viewModel.updatePPTPlaceholderMappings($0) })
    }

    private var pptVisualTemplateBinding: Binding<PPTVisualTemplate> {
        Binding(get: { viewModel.pptVisualTemplate }, set: { viewModel.updatePPTVisualTemplate($0) })
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                PageHeader(title: "产出生成", subtitle: "PPT + Excel 双交付物；PPT 模板与 Excel 模板都可在产品内直接编辑") {
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
                        message: "请先导入文献或从 PubMed 检索。产出生成会使用产品内可编辑的 PPT 模板和自定义 Excel 导出模板。",
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

                    PPTVisualTemplateEditorPanel(template: pptVisualTemplateBinding)
                    ExportTemplateEditorPanel(columns: exportColumnsBinding, availableFields: viewModel.availableExportFields, previewDrafts: viewModel.activeDrafts)
                    PPTTemplateEditorPanel(mappings: pptMappingsBinding, availableFields: viewModel.availableExportFields, previewDraft: viewModel.activeDraft)
                }
            }
            .padding(24)
        }
    }
}

struct SettingsView: View {
    @ObservedObject var viewModel: AppViewModel
    @State private var defaultConfig: ProjectConfig

    init(viewModel: AppViewModel) {
        self.viewModel = viewModel
        _defaultConfig = State(initialValue: viewModel.defaultProjectConfig)
    }

    private var defaultPromptBinding: Binding<PromptTemplates> {
        Binding(get: { defaultConfig.promptTemplates }, set: { defaultConfig.promptTemplates = $0 })
    }

    private var defaultStudyTermsBinding: Binding<[String]> {
        Binding(get: { defaultConfig.customStudyTerms }, set: { defaultConfig.customStudyTerms = $0 })
    }

    private var defaultExportColumnsBinding: Binding<[ExportColumnConfig]> {
        Binding(get: { defaultConfig.exportColumns }, set: { defaultConfig.exportColumns = $0 })
    }

    private var defaultPPTMappingsBinding: Binding<[PPTPlaceholderMapping]> {
        Binding(get: { defaultConfig.pptPlaceholders }, set: { defaultConfig.pptPlaceholders = $0 })
    }

    private var defaultAvailableFields: [CanonicalField] {
        ExportFieldCatalog.fields
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                PageHeader(title: "系统设置", subtitle: "仅保留系统密钥与默认项目配置；Excel 导入格式会在导入时自动识别") {
                    HStack(spacing: 10) {
                        Button("使用当前项目覆盖默认配置") {
                            defaultConfig = viewModel.makeCurrentProjectConfig()
                        }
                        .accessibilityIdentifier("btn-use-current-default-config")
                        Button("保存默认项目配置") {
                            viewModel.saveDefaultProjectConfig(defaultConfig)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(AppTheme.accent)
                        .accessibilityIdentifier("btn-save-default-config")
                    }
                }

                SectionTitle(title: "系统密钥")
                HStack(alignment: .top, spacing: 16) {
                    VStack(spacing: 0) {
                        SettingsSecureRow(
                            title: "LLM API Key",
                            subtitle: "必填；用于调用云端 LLM 执行翻译、研究设计和主题分类",
                            placeholder: "sk-... 或 智谱 id.secret",
                            text: $viewModel.apiKey
                        )
                        Divider()
                        SettingsFieldRow(
                            title: "LLM 接口地址",
                            subtitle: "OpenAI 兼容 /chat/completions；默认智谱 BigModel，可改为其他服务",
                            placeholder: AppViewModel.defaultLLMEndpoint,
                            text: $viewModel.llmEndpoint,
                            accessibilityID: "field-llm-endpoint"
                        )
                        Divider()
                        SettingsFieldRow(
                            title: "LLM 模型",
                            subtitle: "如 glm-4-flash（默认，免费）/ glm-4 / gpt-4o-mini",
                            placeholder: AppViewModel.defaultLLMModel,
                            text: $viewModel.llmModel,
                            accessibilityID: "field-llm-model"
                        )
                        Divider()
                        SettingsSecureRow(
                            title: "NCBI API Key",
                            subtitle: "可选；用于提升 PubMed 检索速率并减少限流",
                            placeholder: "ncbi-...",
                            text: $viewModel.ncbiApiKey
                        )
                    }
                    .roundedPanel(padding: 0)

                    VStack(alignment: .leading, spacing: 12) {
                        InfoPanel(
                            title: "当前项目配置在哪里修改",
                            text: "当前项目的 AI 加工任务、自定义研究类型、导出列、PPT 占位符映射都属于项目配置，不在这里直接混编辑。AI 加工相关配置在“AI 加工”页维护，导出模板和 PPT 模板在“产出生成”页维护。",
                            tags: ["当前项目", "项目级配置", "与默认值分离"]
                        )
                        VStack(spacing: 0) {
                            SettingInlineRow(title: "当前项目", subtitle: viewModel.selectedProject.name, trailing: "项目级")
                            Divider()
                            SettingInlineRow(title: "当前 IF / 分区数据", subtitle: viewModel.impactFactorByJournal.isEmpty ? "未导入" : "已导入 \(viewModel.impactFactorByJournal.count) 条", trailing: "当前项目")
                            Divider()
                            SettingInlineRow(title: "当前 PPT 样式模板", subtitle: viewModel.pptVisualTemplate.name, trailing: "当前项目")
                            Divider()
                            SettingInlineRow(title: "当前自定义加工任务", subtitle: viewModel.customTasks.isEmpty ? "未配置" : "已配置 \(viewModel.customTasks.count) 个任务", trailing: "当前项目")
                            Divider()
                            SettingsActionRow(title: "跳转到 AI 加工页", subtitle: "维护当前项目的自定义 AI 加工任务、任务开关和加工队列。", button: "前往") {
                                viewModel.navigate(to: .enrich)
                            }
                            Divider()
                            SettingsActionRow(title: "跳转到产出生成页", subtitle: "维护当前项目的 Excel 导出模板、PPT 占位符映射和 PPT 模板。", button: "前往") {
                                viewModel.navigate(to: .slides)
                            }
                        }
                        .roundedPanel(padding: 0)
                        .accessibilityIdentifier("panel-current-project-config")
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                SectionTitle(title: "默认项目配置")
                HStack(alignment: .top, spacing: 16) {
                    VStack(alignment: .leading, spacing: 12) {
                        InfoPanel(
                            title: "默认值说明",
                            text: "这里编辑的是“新建项目时自动继承”的默认项目配置。修改后不会强制覆盖已有项目；如需用当前项目覆盖默认值，请使用顶部的“使用当前项目覆盖默认配置”。",
                            tags: ["新项目继承", "不会回写旧项目", "与当前项目分离"]
                        )
                        PromptTemplateEditorPanel(templates: defaultPromptBinding)
                        StudyTermsEditorPanel(terms: defaultStudyTermsBinding)
                        PPTVisualTemplateEditorPanel(template: Binding(get: { defaultConfig.pptVisualTemplate }, set: { defaultConfig.pptVisualTemplate = $0 }))
                        VStack(spacing: 0) {
                            SettingsActionRow(
                                title: "默认 IF / 分区数据集",
                                subtitle: defaultConfig.impactFactorByJournal.isEmpty ? "未导入" : "已导入 \(defaultConfig.impactFactorByJournal.count) 条",
                                button: "导入"
                            ) {
                                if let table = viewModel.importImpactFactorTableFromPanel() {
                                    defaultConfig.impactFactorByJournal = table
                                }
                            }
                            Divider()
                            SettingInlineRow(title: "默认 PPT 模板来源", subtitle: "产品内置可编辑模板", trailing: "无需上传")
                        }
                        .roundedPanel(padding: 0)
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        ExportTemplateEditorPanel(columns: defaultExportColumnsBinding, availableFields: defaultAvailableFields, previewDrafts: [viewModel.previewDraftForTemplates])
                        PPTTemplateEditorPanel(mappings: defaultPPTMappingsBinding, availableFields: defaultAvailableFields, previewDraft: viewModel.previewDraftForTemplates)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(24)
        }
        .onChange(of: viewModel.apiKey) { _, _ in viewModel.persistSystemKeys() }
        .onChange(of: viewModel.ncbiApiKey) { _, _ in viewModel.persistSystemKeys() }
        .onChange(of: viewModel.llmEndpoint) { _, _ in viewModel.persistSystemKeys() }
        .onChange(of: viewModel.llmModel) { _, _ in viewModel.persistSystemKeys() }
    }
}

struct SearchContextDetailView: View {
    @ObservedObject var viewModel: AppViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("检索结果详情")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(AppTheme.textSecondary)
                    .textCase(.uppercase)

                InfoPanel(
                    title: "当前检索",
                    text: viewModel.searchTerms.isEmpty
                        ? "输入检索词（多个用 AND 连接）后，将透明展示等价 PubMed 检索式，并支持排序与分页。检索结果不会自动进入文献库。"
                        : "检索式：\(viewModel.displayedQuery)",
                    tags: viewModel.totalHits > 0 ? ["共 \(viewModel.totalHits) 条命中"] : []
                )

                if viewModel.hasSearchResults, let article = viewModel.selectedSearchArticle {
                    Button {
                        viewModel.importSingleSearchResult(article)
                    } label: {
                        Label("将本条加入文献库", systemImage: "tray.and.arrow.down.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(AppTheme.accent)
                    .accessibilityIdentifier("btn-import-single-search")

                    DetailBlock(title: "标题") {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(article.titleEN)
                                .font(.system(size: 14, weight: .semibold))
                            if !article.titleCN.isEmpty {
                                Text(article.titleCN)
                                    .font(.system(size: 13.5))
                                    .foregroundStyle(AppTheme.textSecondary)
                            }
                        }
                    }

                    DetailBlock(title: "元数据") {
                        DetailKeyValueGrid(pairs: [
                            ("作者", article.authors),
                            ("日期", article.date),
                            ("研究类型", article.studyType),
                            ("期刊", article.journal),
                            ("影响因子", article.impactFactor),
                            ("PMID", article.pmid)
                        ])
                    }

                    if !article.abstractEN.isEmpty {
                        DetailBlock(title: "摘要原文") {
                            Text(article.abstractEN)
                                .font(.system(size: 13))
                                .foregroundStyle(AppTheme.textSecondary)
                                .lineSpacing(4)
                        }
                    }
                } else {
                    Text("在左侧检索并点击某条结果，可在此查看详情并单独入库。")
                        .font(.system(size: 12.5))
                        .foregroundStyle(AppTheme.textTertiary)
                }
            }
            .padding(20)
        }
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
                Text("主题分类（词条列表）")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(AppTheme.textSecondary)
                    .textCase(.uppercase)
                Text("主题分类是一个扁平的词条列表，不是四级菜单。AI 加工会在这些词条中为每篇文献选择最匹配的一条。")
                    .font(.system(size: 12))
                    .foregroundStyle(AppTheme.textSecondary)
                TopicTermsEditor(viewModel: viewModel)
                    .roundedPanel()
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
    let template: PPTVisualTemplate

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("当前幻灯详情")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(AppTheme.textSecondary)
                    .textCase(.uppercase)
                SlidePreviewCard(article: article, template: template)
            }
            .padding(20)
        }
    }
}
