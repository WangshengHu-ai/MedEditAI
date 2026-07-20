import SwiftUI

enum SampleData {
    static let projects: [Project] = [
        .init(name: "PFA 图书馆", color: AppTheme.accent),
        .init(name: "房颤消融监测", color: AppTheme.accentBlue),
        .init(name: "肿瘤免疫治疗", color: AppTheme.purple)
    ]

    static let stats: [StatItem] = [
        .init(title: "文献总量", value: "127", detail: "+24 本周期新增", symbol: "chart.bar.fill"),
        .init(title: "已翻译", value: "119", detail: "93.7% 已完成", symbol: "character.book.closed.fill"),
        .init(title: "待复核", value: "11", detail: "建议优先处理", symbol: "clock.badge.exclamationmark.fill"),
        .init(title: "模板数", value: "4", detail: "含产品内可编辑 onepage 模板", symbol: "square.on.square.intersection.dashed")
    ]

    static let alerts: [AlertItem] = [
        .init(title: "11 条低置信度分类待复核"),
        .init(title: "PFA 图书馆 2025 年 IF 数据集已导入"),
        .init(title: "onepage PPT 模板已识别 11 个占位符")
    ]

    static let quickActions: [QuickAction] = [
        .init(title: "从 PubMed 开始检索", description: "输入关键词或高级检索式，批量拉取文献元数据", symbol: "magnifyingglass", gradient: [AppTheme.accent, AppTheme.accentMint], destination: .search),
        .init(title: "导入已有 Excel 清单", description: "智能列映射，不要求固定格式，可复用映射模板", symbol: "square.and.arrow.down.on.square.fill", gradient: [AppTheme.accentBlue, Color(red: 0.33, green: 0.66, blue: 1.0)], destination: .library),
        .init(title: "生成 onepage 交付物", description: "使用产品内可编辑的 PPT 模板和自定义 Excel 导出模板", symbol: "play.rectangle.on.rectangle.fill", gradient: [AppTheme.orange, Color(red: 0.98, green: 0.6, blue: 0.27)], destination: .slides)
    ]

    static let topicTree: [TopicNode] = [
        .init(title: "Science of PFA", level: 1, count: nil, children: [
            .init(title: "原理和影响因素", level: 2, count: nil, children: [
                .init(title: "PFA发展史和生物物理学原理", level: 3, count: nil, children: [
                    .init(title: "原理——PFA与既往热能源有何不同？", level: 4, count: 23, children: []),
                    .init(title: "组织选择性——不同细胞真有清晰损伤阈值吗？", level: 4, count: 14, children: [])
                ]),
                .init(title: "PFA的影响因素", level: 3, count: nil, children: [
                    .init(title: "电场强度——为何是衡量 PFA 损伤的第一因素？", level: 4, count: 18, children: []),
                    .init(title: "波形、脉宽和频率——纳秒真的能解决麻醉问题吗？", level: 4, count: 40, children: [])
                ])
            ])
        ])
    ]

    static let articles: [Article] = [
        .init(
            id: "a1",
            topic: "原理——PFA与既往热能源有何不同？",
            titleEN: "The Biophysics of Radiofrequency Ablation and Factors Affecting Lesion Size",
            titleCN: "射频消融的生物物理学原理及消融灶尺寸的影响因素",
            abstractEN: "Radiofrequency ablation has been the mainstay of catheter ablation.",
            abstractCN: "射频消融长期是导管消融的核心能量形式。本文综述了射频消融灶形成的生物物理学机制，并与新兴的脉冲电场消融在能量作用方式、组织反应和损伤边界控制方面进行比较，为理解 PFA 与既往热能源的差异提供了理论基础。",
            citation: "Bates AP, et al. The Biophysics of Radiofrequency Ablation and Factors Affecting Lesion Size. Arrhythm Electrophysiol Rev. 2026 Mar 3.",
            authors: "Bates AP, et al",
            date: "2026-03-03",
            studyType: "综述",
            journal: "Arrhythm Electrophysiol Rev",
            impactFactor: "3.3",
            quartile: "Q2",
            pmid: "41835106",
            url: "https://pmc.ncbi.nlm.nih.gov/articles/PMCxxxxxxxx/pdf",
            confidence: .high,
            product: "PFA / RF 对照原理",
            evidence: "综述证据",
            note: "交付 deck 第 1 页；用于与传统热能源机制对照。"
        ),
        .init(
            id: "a2",
            topic: "原理——PFA与既往热能源有何不同？",
            titleEN: "Latest Advances and Ongoing Challenges in Pulsed Field Ablation",
            titleCN: "脉冲电场消融的最新进展与持续挑战",
            abstractEN: "This review discusses current technical advances in PFA.",
            abstractCN: "本文总结了 PFA 技术的最新进展，并围绕波形设计、组织选择性和邻近组织安全性等关键问题梳理仍待解决的挑战。文章可作为 PFA 原理与临床转化之间的桥梁性材料。",
            citation: "Vázquez-Calvo S, et al. Latest Advances and Ongoing Challenges in Pulsed Field Ablation. Arrhythm Electrophysiol Rev. 2026 Feb 24.",
            authors: "Vázquez-Calvo S, et al",
            date: "2026-02-24",
            studyType: "综述",
            journal: "Arrhythm Electrophysiol Rev",
            impactFactor: "3.3",
            quartile: "Q2",
            pmid: "41835109",
            url: "https://pmc.ncbi.nlm.nih.gov/articles/PMCyyyyyyyy/pdf",
            confidence: .high,
            product: "PFA 原理",
            evidence: "综述证据",
            note: "适合作为第 2-3 页。"
        ),
        .init(
            id: "a3",
            topic: "原理——PFA与既往热能源有何不同？",
            titleEN: "Pulsed field ablation: Disrupting technologies for cardiac arrhythmias",
            titleCN: "脉冲电场消融：心律失常治疗的颠覆性技术",
            abstractEN: "PFA leverages irreversible electroporation to achieve tissue ablation.",
            abstractCN: "PFA 通过不可逆电穿孔实现组织消融，不依赖热损伤机制，因此在邻近脆弱结构区域具备潜在安全优势。该文集中讨论了其相较于射频与冷冻的差异化价值。",
            citation: "Miklavčič D, et al. Pulsed field ablation: Disrupting technologies for cardiac arrhythmias. Heart Rhythm. 2025 Dec 15.",
            authors: "Miklavčič D, et al",
            date: "2025-12-15",
            studyType: "综述",
            journal: "Heart Rhythm",
            impactFactor: "5.8",
            quartile: "Q1",
            pmid: "41407239",
            url: "https://www.heartrhythmjournal.com/article/xxx",
            confidence: .medium,
            product: "PFA / 热能源对照",
            evidence: "综述证据",
            note: "主题分类置信度中等，建议复核。"
        ),
        .init(
            id: "a4",
            topic: "原理——PFA与既往热能源有何不同？",
            titleEN: "Evaluation of variable inter-pulse delays for pulsed field ablation",
            titleCN: "不同脉冲间隔对脉冲电场消融效果的评估",
            abstractEN: "Preclinical work evaluated variable inter-pulse delay settings.",
            abstractCN: "该项前临床研究评估了不同脉冲间隔设置对消融灶质量和组织反应的影响，为理解 PFA 参数优化提供实验依据。",
            citation: "Steiger NA, et al. Evaluation of variable inter-pulse delays for pulsed field ablation. J Interv Card Electrophysiol. 2025 Oct 22.",
            authors: "Steiger NA, et al",
            date: "2025-10-22",
            studyType: "土豆模型",
            journal: "J Interv Card Electrophysiol",
            impactFactor: "2.6",
            quartile: "Q3",
            pmid: "41123832",
            url: "https://link.springer.com/article/10.xxxx",
            confidence: .low,
            product: "PFA 参数优化",
            evidence: "实验模型",
            note: "研究类型为客户自定义术语“土豆模型”，系统需支持自定义研究类型。"
        ),
        .init(
            id: "a5",
            topic: "原理——PFA与既往热能源有何不同？",
            titleEN: "Internal atrial shock delivery by standard diagnostic electrophysiology catheters in goats",
            titleCN: "通过标准诊断性电生理导管进行心房内电击的山羊实验",
            abstractEN: "An animal model assessed atrial shock delivery and tissue changes.",
            abstractCN: "该动物实验通过山羊模型评估心房内电击传递及其对组织结构的影响，为早期电穿孔相关消融机制提供实验依据。",
            citation: "Wijffels MC, et al. Internal atrial shock delivery by standard diagnostic electrophysiology catheters in goats. Europace. 2007 Mar 9.",
            authors: "Wijffels MC, et al",
            date: "2007-03-09",
            studyType: "动物实验",
            journal: "Europace",
            impactFactor: "7.5",
            quartile: "Q1",
            pmid: "17395650",
            url: "https://academic.oup.com/europace/article/9/4/203/640812",
            confidence: .high,
            product: "电穿孔基础实验",
            evidence: "动物实验",
            note: "用于历史追溯部分。"
        )
    ]

    static let importMappings: [MappingPair] = [
        .init(source: "序号", target: "sequence"),
        .init(source: "标题", target: "titleEN"),
        .init(source: "摘要/研究简介-原文", target: "abstractEN"),
        .init(source: "摘要/研究简介-翻译", target: "abstractCN"),
        .init(source: "研究类型", target: "studyDesign"),
        .init(source: "主题分类", target: "topicCategories")
    ]

    static let exportMappings: [MappingPair] = [
        .init(source: "主题", target: "topic"),
        .init(source: "序号", target: "sequence"),
        .init(source: "标题", target: "titleEN"),
        .init(source: "摘要/内容简介详情链接", target: "abstractLink"),
        .init(source: "作者", target: "authors"),
        .init(source: "发表日期", target: "date"),
        .init(source: "研究类型", target: "studyDesign"),
        .init(source: "期刊", target: "journal"),
        .init(source: "2025年IF", target: "impactFactor"),
        .init(source: "PMID", target: "pmid"),
        .init(source: "原文链接", target: "url")
    ]

    static let pptMappings: [MappingPair] = [
        .init(source: "{{topic}}", target: "topic"),
        .init(source: "{{title_en}}", target: "titleEN"),
        .init(source: "{{title_cn}}", target: "titleCN"),
        .init(source: "{{authors}}", target: "authors"),
        .init(source: "{{pub_date}}", target: "date"),
        .init(source: "{{study_type}}", target: "studyDesign"),
        .init(source: "{{journal}}", target: "journal"),
        .init(source: "{{if}}", target: "impactFactor"),
        .init(source: "{{abstract_cn}}", target: "abstractCN"),
        .init(source: "{{citation}}", target: "citation"),
        .init(source: "{{url}}", target: "url")
    ]

    static let processingTasks: [ProcessingTask] = [
        .init(key: "translate", title: "翻译", description: "标题 / 摘要 / 关键词中译，受医学术语库约束", symbol: "character.book.closed.fill", isEnabled: true),
        .init(key: "study", title: "研究设计分类", description: "支持客户自定义术语，如综述 / 动物实验 / 土豆模型", symbol: "bookmark.fill", isEnabled: true),
        .init(key: "topic", title: "主题分类", description: "支持四级树分类与呈现方式 / 备注等扩展字段", symbol: "square.grid.3x3.topleft.filled", isEnabled: true),
        .init(key: "products", title: "研究产品识别", description: "抽取药物 / 器械 / 干预措施，可联动产品词典", symbol: "pills.fill", isEnabled: true),
        .init(key: "metrics", title: "IF / 分区匹配", description: "根据用户导入的 2025 IF 数据表进行本地匹配", symbol: "chart.xyaxis.line", isEnabled: true)
    ]

    static let queue: [QueueItem] = [
        .init(title: "Pulsed field ablation: Disrupting technologies...", status: .done),
        .init(title: "Evaluation of variable inter-pulse delays...", status: .running),
        .init(title: "Internal atrial shock delivery in goats...", status: .waiting),
        .init(title: "Latest Advances and Ongoing Challenges...", status: .waiting)
    ]
}
