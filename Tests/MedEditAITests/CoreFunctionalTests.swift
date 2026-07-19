import XCTest
@testable import MedEditAI

final class CoreFunctionalTests: XCTestCase {
    // MARK: - CSV
    func testCSVRoundTripWithQuotesCommasNewlines() {
        let rows = [
            ["标题", "作者", "备注"],
            ["A, B", "Zhang \"Q\"", "line1\nline2"],
            ["普通", "李", ""]
        ]
        let text = CSVEngine.write(rows)
        let parsed = CSVEngine.parse(text)
        XCTAssertEqual(parsed, rows)
    }

    // MARK: - XLSX writer XML
    func testXLSXColumnLettersAndSheetXML() {
        XCTAssertEqual(XLSXWriter.columnLetter(0), "A")
        XCTAssertEqual(XLSXWriter.columnLetter(25), "Z")
        XCTAssertEqual(XLSXWriter.columnLetter(26), "AA")

        let xml = XLSXWriter.sheetXML(rows: [["标题", "IF"], ["PFA", "5.8"]])
        XCTAssertTrue(xml.contains("<c r=\"A1\" t=\"inlineStr\">"))
        XCTAssertTrue(xml.contains("IF"))
        XCTAssertTrue(xml.contains("<row r=\"2\">"))
    }

    func testXLSXEscaping() {
        XCTAssertEqual(XLSXWriter.escape("a<b>&\"c"), "a&lt;b&gt;&amp;&quot;c")
    }

    // MARK: - XLSX reader (no zip needed)
    func testXLSXReaderParsesInlineAndSharedStrings() {
        let shared = XLSXReader.parseSharedStrings(data: Data("""
        <sst><si><t>标题</t></si><si><t>作者</t></si></sst>
        """.utf8))
        XCTAssertEqual(shared, ["标题", "作者"])

        let sheet = """
        <worksheet><sheetData>
        <row r="1"><c r="A1" t="s"><v>0</v></c><c r="B1" t="s"><v>1</v></c></row>
        <row r="2"><c r="A2" t="inlineStr"><is><t>PFA</t></is></c><c r="B2"><v>5.8</v></c></row>
        </sheetData></worksheet>
        """
        let rows = XLSXReader.parseSheet(data: Data(sheet.utf8), sharedStrings: shared)
        XCTAssertEqual(rows[0], ["标题", "作者"])
        XCTAssertEqual(rows[1], ["PFA", "5.8"])
    }

    // MARK: - PPTX helpers
    func testPPTXPlaceholderReplacementEscapes() {
        let xml = "<a:t>{{title_en}}</a:t><a:t>{{authors}}</a:t>"
        let filled = PPTXTemplateFiller.replacePlaceholders(in: xml, with: [
            "{{title_en}}": "PFA & RF <review>",
            "{{authors}}": "Bates AP"
        ])
        XCTAssertTrue(filled.contains("PFA &amp; RF &lt;review&gt;"))
        XCTAssertTrue(filled.contains("Bates AP"))
        XCTAssertFalse(filled.contains("{{"))
    }

    func testPPTXRelationshipsRebuildAndSldIdList() {
        let relsXML = """
        <Relationships xmlns="x">
        <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slideMaster" Target="slideMasters/slideMaster1.xml"/>
        <Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slide" Target="slides/slide1.xml"/>
        </Relationships>
        """
        let rels = PPTXTemplateFiller.parseRelationships(relsXML)
        XCTAssertEqual(rels.count, 2)
        XCTAssertTrue(rels.contains { $0.type.hasSuffix("/slide") })

        let nonSlide = rels.filter { !$0.type.hasSuffix("/slide") }
        let rebuilt = PPTXTemplateFiller.buildPresentationRels(nonSlideRels: nonSlide, slideCount: 3)
        XCTAssertEqual(rebuilt.slideRelIds.count, 3)
        XCTAssertTrue(rebuilt.xml.contains("slides/slide3.xml"))
        XCTAssertTrue(rebuilt.xml.contains("slideMaster"))

        let presentation = "<p:presentation><p:sldIdLst><p:sldId id=\"256\" r:id=\"rId9\"/></p:sldIdLst></p:presentation>"
        let updated = PPTXTemplateFiller.replaceSlideIdList(in: presentation, slideRelIds: rebuilt.slideRelIds)
        XCTAssertEqual(updated.components(separatedBy: "<p:sldId ").count - 1, 3)
    }

    func testPPTXContentTypesAddsSlideOverrides() {
        let contentTypes = "<Types><Default Extension=\"xml\" ContentType=\"application/xml\"/></Types>"
        let updated = PPTXTemplateFiller.ensureSlideContentTypes(in: contentTypes, slideCount: 2)
        XCTAssertTrue(updated.contains("/ppt/slides/slide1.xml"))
        XCTAssertTrue(updated.contains("/ppt/slides/slide2.xml"))
        XCTAssertTrue(updated.hasSuffix("</Types>"))
    }

    // MARK: - LLM Mock provider
    struct MockLLM: LLMProviding {
        var studyTypeResult: StudyTypeClassificationResult = StudyTypeClassificationResult(studyType: "队列研究", confidence: 0.82)

        func translate(_ request: TranslationRequest) async throws -> TranslationResult {
            TranslationResult(titleCN: "脉冲电场消融", abstractCN: "摘要测试", keywordsCN: ["消融"])
        }
        func classifyTopic(title: String, abstract: String, candidatePaths: [String]) async throws -> TopicClassificationResult {
            TopicClassificationResult(topicPath: "Science > 原理 > electroporation", confidence: 0.85)
        }
        func classifyStudyType(title: String, abstract: String, candidateTerms: [String]) async throws -> StudyTypeClassificationResult {
            studyTypeResult
        }
    }

    func testMockLLMTranslation() async throws {
        let provider = MockLLM()
        let result = try await provider.translate(TranslationRequest(
            title: "Pulsed field ablation for atrial fibrillation",
            abstract: "",
            keywords: ["ablation"]
        ))
        XCTAssertTrue(result.titleCN.contains("脉冲电场消融"))
        XCTAssertEqual(result.keywordsCN, ["消融"])
    }

    func testMockLLMClassification() async throws {
        let provider = MockLLM()
        let result = try await provider.classifyTopic(
            title: "Electroporation biophysics of ablation",
            abstract: "electroporation review",
            candidatePaths: ["Science > 原理 > electroporation", "Science > 影响因素 > 波形"]
        )
        XCTAssertEqual(result.topicPath, "Science > 原理 > electroporation")
    }

    // MARK: - Enrichment pipeline
    func testEnrichmentPipelineWithMockProvider() async {
        let scheme = ClassificationScheme(name: "PFA", type: .topic, isHierarchical: true, items: [
            ClassificationNode(title: "Science of PFA", level: 1, children: [
                ClassificationNode(title: "原理", level: 2, children: [
                    ClassificationNode(title: "electroporation", level: 3)
                ])
            ])
        ])
        let service = EnrichmentService(
            llm: MockLLM(),
            topicScheme: scheme,
            customStudyTerms: ["土豆模型"],
            impactFactorByJournal: ["heartrhythm": "5.8"]
        )
        let record = PubMedRecord(
            pmid: "1", title: "Electroporation review", abstract: "electroporation ablation",
            authors: ["Bates AP", "Smith B"], journal: "Heart Rhythm", pubDate: "2026",
            doi: "10.1/x", keywords: ["ablation"], meshTerms: [], references: []
        )
        let drafts = await service.enrichBatch(records: [record])
        XCTAssertEqual(drafts.count, 1)
        XCTAssertEqual(drafts[0].impactFactor, "5.8")
        XCTAssertEqual(drafts[0].url, "https://doi.org/10.1/x")
        XCTAssertFalse(drafts[0].titleCN.isEmpty)
        // 本地自定义词条未命中（文本不含“土豆模型”），回退到 AI 推断结果。
        XCTAssertEqual(drafts[0].studyType, "队列研究")
        XCTAssertEqual(drafts[0].evidence, "AI 推断")
    }

    func testEnrichmentPrefersLocalCustomTermOverAI() async {
        let scheme = ClassificationScheme(name: "PFA", type: .topic, isHierarchical: true, items: [])
        let service = EnrichmentService(
            llm: MockLLM(studyTypeResult: StudyTypeClassificationResult(studyType: "不相干结果", confidence: 0.9)),
            topicScheme: scheme,
            customStudyTerms: ["electroporation"],
            impactFactorByJournal: [:]
        )
        let record = PubMedRecord(
            pmid: "2", title: "Electroporation review", abstract: "electroporation ablation",
            authors: ["A"], journal: "Heart Rhythm", pubDate: "2026",
            doi: nil, keywords: [], meshTerms: [], references: []
        )
        let drafts = await service.enrichBatch(records: [record])
        // 本地自定义词条命中优先于 AI，不应使用 Mock 返回的不相干结果。
        XCTAssertEqual(drafts[0].studyType, "electroporation")
        XCTAssertEqual(drafts[0].evidence, "自定义")
    }

    func testEnrichmentLeavesStudyTypeBlankWhenAICannotDetermine() async {
        let scheme = ClassificationScheme(name: "PFA", type: .topic, isHierarchical: true, items: [])
        let service = EnrichmentService(
            llm: MockLLM(studyTypeResult: StudyTypeClassificationResult(studyType: "", confidence: 0.4)),
            topicScheme: scheme,
            customStudyTerms: [],
            impactFactorByJournal: [:]
        )
        let record = PubMedRecord(
            pmid: "3", title: "Unclear design report", abstract: "ambiguous text",
            authors: ["A"], journal: "Heart Rhythm", pubDate: "2026",
            doi: nil, keywords: [], meshTerms: [], references: []
        )
        let drafts = await service.enrichBatch(records: [record])
        // 未配置自定义词条且 AI 也无法判断时，留空而非编造。
        XCTAssertEqual(drafts[0].studyType, "")
        XCTAssertEqual(drafts[0].evidence, "")
    }

    // MARK: - DocumentService import/export
    func testDocumentServiceImportsFromRows() {
        let rows = [
            ["检索式：pulsed field ablation"],
            ["序号", "标题", "摘要/研究简介-原文", "摘要/研究简介-翻译", "研究类型", "主题分类"],
            ["1", "The Biophysics of RF Ablation", "abstract en", "摘要翻译", "综述", "原理"]
        ]
        let drafts = DocumentService.articles(from: rows)
        XCTAssertEqual(drafts.count, 1)
        XCTAssertEqual(drafts[0].titleEN, "The Biophysics of RF Ablation")
        XCTAssertEqual(drafts[0].abstractCN, "摘要翻译")
        XCTAssertEqual(drafts[0].studyType, "综述")
    }

    func testDocumentServiceExportRowsFollowTemplateColumns() {
        let draft = ArticleDraft(
            topic: "原理", titleEN: "T", titleCN: "标题", abstractEN: "a", abstractCN: "摘要",
            citation: "c", authors: "Bates AP", date: "2026", studyType: "综述", journal: "Heart Rhythm",
            impactFactor: "5.8", quartile: "Q1", pmid: "1", url: "https://x", confidence: 0.9,
            product: "PFA", evidence: "综述证据", note: ""
        )
        let template = ExportTemplate(name: "t", columns: ["主题", "序号", "标题", "研究类型", "2025年IF", "PMID"], hyperlinkFields: [])
        let rows = DocumentService.exportRows(articles: [draft], template: template)
        XCTAssertEqual(rows[0], ["主题", "序号", "标题", "研究类型", "2025年IF", "PMID"])
        XCTAssertEqual(rows[1], ["原理", "1", "T", "综述", "5.8", "1"])
    }

    func testImpactFactorTableParsing() {
        let rows = [
            ["期刊", "2025年IF", "分区"],
            ["Heart Rhythm", "5.8", "Q1"],
            ["Europace", "7.5", "Q1"]
        ]
        let table = DocumentService.impactFactorTable(from: rows)
        XCTAssertEqual(table["heartrhythm"], "5.8")
        XCTAssertEqual(table["europace"], "7.5")
    }

    func testSlidePlaceholderValuesCoverAllKeys() {
        let draft = ArticleDraft(
            topic: "原理", titleEN: "EN", titleCN: "中", abstractEN: "a", abstractCN: "摘要",
            citation: "cite", authors: "Bates", date: "2026", studyType: "综述", journal: "HR",
            impactFactor: "5.8", quartile: nil, pmid: "1", url: "https://x", confidence: 0.9,
            product: "PFA", evidence: "e", note: ""
        )
        let values = DocumentService.slidePlaceholderValues(for: draft)
        XCTAssertEqual(values["{{title_en}}"], "EN")
        XCTAssertEqual(values["{{title_cn}}"], "中")
        XCTAssertEqual(values["{{if}}"], "5.8")
        XCTAssertEqual(values["{{url}}"], "https://x")
    }

    // MARK: - Multi-article PubMed parsing
    func testPubMedParsesMultipleArticles() {
        let xml = """
        <PubmedArticleSet>
        <PubmedArticle><MedlineCitation><PMID>1</PMID><Article><ArticleTitle>First</ArticleTitle></Article></MedlineCitation></PubmedArticle>
        <PubmedArticle><MedlineCitation><PMID>2</PMID><Article><ArticleTitle>Second</ArticleTitle></Article></MedlineCitation></PubmedArticle>
        </PubmedArticleSet>
        """
        let records = PubMedXMLParser.parseArticles(xml)
        XCTAssertEqual(records.count, 2)
        XCTAssertEqual(records[0].pmid, "1")
        XCTAssertEqual(records[1].title, "Second")
    }

    func testESearchJSONParsing() {
        let json = "{\"esearchresult\":{\"idlist\":[\"111\",\"222\"]}}"
        let ids = PubMedService.parseESearchIDs(from: Data(json.utf8))
        XCTAssertEqual(ids, ["111", "222"])
    }
}
