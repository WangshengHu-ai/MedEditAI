import XCTest
@testable import MedEditAI

final class CoreServicesTests: XCTestCase {
    func testImportMappingHandlesChineseHeadersAndRequiredFields() {
        let headers = ["主题", "序号", "标题", "摘要/研究简介-原文", "摘要/研究简介-翻译", "作者", "发表日期", "研究类型", "期刊", "2025年IF", "PMID", "原文链接"]
        let mapping = ColumnMappingEngine.buildImportMapping(from: headers, requiredFields: ["titleEN", "abstractEN", "abstractCN", "studyDesign"])

        XCTAssertEqual(mapping["标题"], "titleEN")
        XCTAssertEqual(mapping["摘要/研究简介-原文"], "abstractEN")
        XCTAssertEqual(mapping["摘要/研究简介-翻译"], "abstractCN")
        XCTAssertEqual(mapping["研究类型"], "studyDesign")
    }

    func testClassificationSchemeBuildsFourLevelTree() {
        let rows = [
            ["主题", "次级菜单", "三级菜单", "四级菜单", "呈现方式", "文献备注"],
            ["Science of PFA", "原理和影响因素", "PFA发展史和生物物理学原理", "原理——PFA与既往热能源有何不同？", "PPT+文献原文+微课", "以电穿孔原理为主"],
            ["Science of PFA", "原理和影响因素", "PFA发展史和生物物理学原理", "组织选择性——不同细胞真有的清晰的损伤阈值边界吗？", "PPT+文献原文+微课", "组织选择性" ]
        ]

        let scheme = ClassificationEngine.buildTree(from: rows)
        XCTAssertTrue(scheme.isHierarchical)
        XCTAssertEqual(ClassificationEngine.flattenPaths(in: scheme).count, 2)
        let leaf = ClassificationEngine.findNode(in: scheme, title: "原理——PFA与既往热能源有何不同？")
        XCTAssertEqual(leaf?.presentation, "PPT+文献原文+微课")
    }

    func testStudyDesignClassifierSupportsCustomTermsAndDefaults() {
        let custom = ClassificationEngine.classifyStudyDesign(in: "This is a 土豆模型 animal study", customTerms: ["土豆模型"])
        XCTAssertEqual(custom.design, "土豆模型")
        XCTAssertGreaterThan(custom.confidence, 0.9)

        let rct = ClassificationEngine.classifyStudyDesign(in: "randomized controlled trial of ablation")
        XCTAssertEqual(rct.design, "随机对照试验")
        XCTAssertEqual(rct.evidenceLevel, "高")
    }

    func testMatchCustomStudyTermReturnsNilWithoutMatchOrTerms() {
        XCTAssertNil(ClassificationEngine.matchCustomStudyTerm(in: "randomized controlled trial", customTerms: []))
        XCTAssertNil(ClassificationEngine.matchCustomStudyTerm(in: "randomized controlled trial", customTerms: ["土豆模型"]))
    }

    func testMatchCustomStudyTermMatchesWithHighConfidenceAndNoEnglishFallback() {
        // 不同于 classifyStudyDesign，matchCustomStudyTerm 未命中自定义词条时不应回退到英文关键词启发式或默认“综述”。
        let result = ClassificationEngine.matchCustomStudyTerm(in: "This is a 土豆模型 animal study", customTerms: ["土豆模型"])
        XCTAssertEqual(result?.design, "土豆模型")
        XCTAssertEqual(result?.evidenceLevel, "自定义")
        XCTAssertGreaterThan(result?.confidence ?? 0, 0.9)
    }

    func testBuildTreeWithColumnRolesUsesUserSpecifiedMapping() {
        let rows = [
            ["列A", "列B", "列C", "列D"],
            ["Science of PFA", "原理", "史", "叶子A"],
            ["Science of PFA", "原理", "史", "叶子B"]
        ]
        let roles = ["列A": "topic", "列B": "secondary", "列C": "tertiary", "列D": "quaternary"]
        let scheme = ClassificationEngine.buildTree(from: rows, columnRoles: roles)
        XCTAssertEqual(ClassificationEngine.flattenPaths(in: scheme).count, 2)
        XCTAssertNotNil(ClassificationEngine.findNode(in: scheme, title: "叶子A"))
    }

    func testPubMedQueryBuilderProducesExpectedClause() {
        let query = PubMedQueryBuilder.buildQuery(keywords: ["pulsed field ablation"], requiredTerms: ["atrial fibrillation"], yearRange: 2024...2026)
        XCTAssertTrue(query.contains("\"pulsed field ablation\"[Title/Abstract]"))
        XCTAssertTrue(query.contains("\"atrial fibrillation\"[Title/Abstract]"))
        XCTAssertTrue(query.contains("2024:2026[pdat]"))
    }

    func testPubMedXMLParserExtractsCoreFields() {
        let xml = """
        <PubmedArticle>
          <MedlineCitation>
            <PMID>41835106</PMID>
            <Article>
              <ArticleTitle>The Biophysics of Radiofrequency Ablation</ArticleTitle>
              <Abstract><AbstractText>First abstract sentence.</AbstractText></Abstract>
              <Journal><Title>Arrhythm Electrophysiol Rev</Title><JournalIssue><PubDate>2026 Mar 3</PubDate></JournalIssue></Journal>
              <AuthorList>
                <Author><LastName>Bates</LastName><ForeName>AP</ForeName></Author>
              </AuthorList>
            </Article>
            <KeywordList><Keyword>ablation</Keyword></KeywordList>
            <MeshHeadingList><MeshHeading><DescriptorName>Pulsed Field Ablation</DescriptorName></MeshHeading></MeshHeadingList>
          </MedlineCitation>
        </PubmedArticle>
        """

        let record = PubMedXMLParser.parse(xml)
        XCTAssertEqual(record?.pmid, "41835106")
        XCTAssertEqual(record?.title, "The Biophysics of Radiofrequency Ablation")
        XCTAssertEqual(record?.journal, "Arrhythm Electrophysiol Rev")
        XCTAssertEqual(record?.authors, ["Bates AP"])
        XCTAssertEqual(record?.keywords, ["ablation"])
        XCTAssertEqual(record?.meshTerms, ["Pulsed Field Ablation"])
    }

    func testArticleProcessingBuildsExportAndSlidePayloads() {
        let scheme = ClassificationScheme(
            name: "PFA",
            type: .topic,
            isHierarchical: true,
            items: [
                ClassificationNode(title: "Science of PFA", level: 1, children: [
                    ClassificationNode(title: "原理和影响因素", level: 2, children: [
                        ClassificationNode(title: "PFA发展史和生物物理学原理", level: 3, children: [
                            ClassificationNode(title: "原理——PFA与既往热能源有何不同？", level: 4)
                        ])
                    ])
                ])
            ]
        )

        let record = PubMedRecord(
            pmid: "41835106",
            title: "The Biophysics of Radiofrequency Ablation and Factors Affecting Lesion Size",
            abstract: "Radiofrequency ablation has been the mainstay of catheter ablation.",
            authors: ["Bates AP", "et al"],
            journal: "Arrhythm Electrophysiol Rev",
            pubDate: "2026-03-03",
            doi: "10.1000/example",
            keywords: ["PFA"],
            meshTerms: ["Pulsed Field Ablation"],
            references: []
        )
        let context = ArticleProcessingContext(customStudyTerms: ["土豆模型"], topicScheme: scheme, impactFactorByJournal: ["arrhythmelectrophysiolrev": "3.3"])
        let article = ArticleProcessor.enrich(record: record, context: context)

        XCTAssertEqual(article.topic, "原理——PFA与既往热能源有何不同？")
        XCTAssertEqual(article.studyType, "综述")
        XCTAssertEqual(article.impactFactor, "3.3")
        XCTAssertEqual(article.product, "PFA")

        let exportRow = ArticleProcessor.renderExportRow(article: article, sequence: 1)
        XCTAssertEqual(exportRow.values["主题"], "原理——PFA与既往热能源有何不同？")
        XCTAssertEqual(exportRow.values["PMID"], "41835106")
        XCTAssertEqual(exportRow.hyperlinks["原文链接"], "")

        let slide = ArticleProcessor.renderSlide(article: article)
        XCTAssertEqual(slide.topic, article.topic)
        XCTAssertEqual(slide.titleEN, article.titleEN)
    }

    func testTemplateRendererExtractsPlaceholders() {
        let placeholders = TemplateRenderer.extractPlaceholders(from: "Hello {{title_en}} and {{authors}}")
        XCTAssertEqual(placeholders, ["{{title_en}}", "{{authors}}"])

        let mapping = TemplateRenderer.buildPlaceholderMap(from: placeholders, fields: ["titleEN", "authors", "url"])
        XCTAssertEqual(mapping["{{title_en}}"], "titleEN")
        XCTAssertEqual(mapping["{{authors}}"], "authors")
    }
}
