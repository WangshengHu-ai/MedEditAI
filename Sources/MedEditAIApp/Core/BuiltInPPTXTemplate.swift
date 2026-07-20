import Foundation

enum BuiltInPPTXTemplate {
    static func makeTemplate(visualTemplate: PPTVisualTemplate) throws -> URL {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("builtin-pptx-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)

        try write("""
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
          <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
          <Default Extension="xml" ContentType="application/xml"/>
          <Override PartName="/ppt/presentation.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.presentation.main+xml"/>
          <Override PartName="/ppt/slides/slide1.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.slide+xml"/>
          <Override PartName="/ppt/slideLayouts/slideLayout1.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.slideLayout+xml"/>
          <Override PartName="/ppt/slideMasters/slideMaster1.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.slideMaster+xml"/>
          <Override PartName="/ppt/theme/theme1.xml" ContentType="application/vnd.openxmlformats-officedocument.theme+xml"/>
          <Override PartName="/docProps/core.xml" ContentType="application/vnd.openxmlformats-package.core-properties+xml"/>
          <Override PartName="/docProps/app.xml" ContentType="application/vnd.openxmlformats-officedocument.extended-properties+xml"/>
        </Types>
        """, to: root.appendingPathComponent("[Content_Types].xml"))

        try write("""
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
          <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="ppt/presentation.xml"/>
          <Relationship Id="rId2" Type="http://schemas.openxmlformats.org/package/2006/relationships/metadata/core-properties" Target="docProps/core.xml"/>
          <Relationship Id="rId3" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/extended-properties" Target="docProps/app.xml"/>
        </Relationships>
        """, to: root.appendingPathComponent("_rels/.rels"))

        try write("""
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Properties xmlns="http://schemas.openxmlformats.org/officeDocument/2006/extended-properties" xmlns:vt="http://schemas.openxmlformats.org/officeDocument/2006/docPropsVTypes">
          <Application>MedEditAI</Application>
          <PresentationFormat>Custom</PresentationFormat>
          <Slides>1</Slides>
          <Notes>0</Notes>
          <HiddenSlides>0</HiddenSlides>
          <MMClips>0</MMClips>
          <ScaleCrop>false</ScaleCrop>
        </Properties>
        """, to: root.appendingPathComponent("docProps/app.xml"))

        try write("""
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <cp:coreProperties xmlns:cp="http://schemas.openxmlformats.org/package/2006/metadata/core-properties" xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:dcterms="http://purl.org/dc/terms/" xmlns:dcmitype="http://purl.org/dc/dcmitype/" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
          <dc:title>\(escape(visualTemplate.name))</dc:title>
          <dc:creator>MedEditAI</dc:creator>
          <cp:lastModifiedBy>MedEditAI</cp:lastModifiedBy>
        </cp:coreProperties>
        """, to: root.appendingPathComponent("docProps/core.xml"))

        try write("""
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <p:presentation xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main">
          <p:sldMasterIdLst><p:sldMasterId id="2147483648" r:id="rId1"/></p:sldMasterIdLst>
          <p:sldIdLst><p:sldId id="256" r:id="rId2"/></p:sldIdLst>
          <p:sldSz cx="9144000" cy="6858000"/>
          <p:notesSz cx="6858000" cy="9144000"/>
        </p:presentation>
        """, to: root.appendingPathComponent("ppt/presentation.xml"))

        try write("""
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
          <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slideMaster" Target="slideMasters/slideMaster1.xml"/>
          <Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slide" Target="slides/slide1.xml"/>
        </Relationships>
        """, to: root.appendingPathComponent("ppt/_rels/presentation.xml.rels"))

        try write(slideMasterXML(accentHex: visualTemplate.accentHex), to: root.appendingPathComponent("ppt/slideMasters/slideMaster1.xml"))
        try write("""
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
          <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slideLayout" Target="../slideLayouts/slideLayout1.xml"/>
          <Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/theme" Target="../theme/theme1.xml"/>
        </Relationships>
        """, to: root.appendingPathComponent("ppt/slideMasters/_rels/slideMaster1.xml.rels"))

        try write(slideLayoutXML(), to: root.appendingPathComponent("ppt/slideLayouts/slideLayout1.xml"))
        try write("""
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
          <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slideMaster" Target="../slideMasters/slideMaster1.xml"/>
        </Relationships>
        """, to: root.appendingPathComponent("ppt/slideLayouts/_rels/slideLayout1.xml.rels"))

        try write(themeXML(accentHex: visualTemplate.accentHex, fontFamily: visualTemplate.fontFamily), to: root.appendingPathComponent("ppt/theme/theme1.xml"))
        try write(slideXML(visualTemplate: visualTemplate), to: root.appendingPathComponent("ppt/slides/slide1.xml"))
        try write("""
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
          <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slideLayout" Target="../slideLayouts/slideLayout1.xml"/>
        </Relationships>
        """, to: root.appendingPathComponent("ppt/slides/_rels/slide1.xml.rels"))

        let output = FileManager.default.temporaryDirectory.appendingPathComponent("MedEditAI-built-in-\(UUID().uuidString).pptx")
        try ZipArchiver.zip(directory: root, to: output)
        try? FileManager.default.removeItem(at: root)
        return output
    }

    private static func write(_ text: String, to url: URL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try text.write(to: url, atomically: true, encoding: .utf8)
    }

    // MARK: - Pure, testable helpers

    private static func slideMasterXML(accentHex: String) -> String {
        """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <p:sldMaster xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main">
          <p:cSld name="Master"><p:spTree><p:nvGrpSpPr><p:cNvPr id="1" name=""/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr><p:grpSpPr/></p:spTree></p:cSld>
          <p:clrMap bg1="lt1" tx1="dk1" bg2="lt2" tx2="dk2" accent1="accent1" accent2="accent2" accent3="accent3" accent4="accent4" accent5="accent5" accent6="accent6" hlink="hlink" folHlink="folHlink"/>
          <p:sldLayoutIdLst><p:sldLayoutId id="2147483649" r:id="rId1"/></p:sldLayoutIdLst>
        </p:sldMaster>
        """
    }

    private static func slideLayoutXML() -> String {
        """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <p:sldLayout xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main" type="blank" preserve="1">
          <p:cSld name="Blank"><p:spTree><p:nvGrpSpPr><p:cNvPr id="1" name=""/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr><p:grpSpPr/></p:spTree></p:cSld>
          <p:clrMapOvr><a:masterClrMapping/></p:clrMapOvr>
        </p:sldLayout>
        """
    }

    static func themeXML(accentHex: String, fontFamily: String) -> String {
        let accent = rgb(from: accentHex)
        let font = escape(fontFamily)
        return """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <a:theme xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" name="MedEditAI Theme">
          <a:themeElements>
            <a:clrScheme name="MedEditAI">
              <a:dk1><a:srgbClr val="1D1D1F"/></a:dk1>
              <a:lt1><a:srgbClr val="FFFFFF"/></a:lt1>
              <a:dk2><a:srgbClr val="3A3A3C"/></a:dk2>
              <a:lt2><a:srgbClr val="F5F5F7"/></a:lt2>
              <a:accent1><a:srgbClr val="\(accent)"/></a:accent1>
              <a:accent2><a:srgbClr val="0A84FF"/></a:accent2>
              <a:accent3><a:srgbClr val="34C759"/></a:accent3>
              <a:accent4><a:srgbClr val="FF9F0A"/></a:accent4>
              <a:accent5><a:srgbClr val="BF5AF2"/></a:accent5>
              <a:accent6><a:srgbClr val="FF453A"/></a:accent6>
              <a:hlink><a:srgbClr val="0A84FF"/></a:hlink>
              <a:folHlink><a:srgbClr val="5E5CE6"/></a:folHlink>
            </a:clrScheme>
            <a:fontScheme name="MedEditAI">
              <a:majorFont><a:latin typeface="\(font)"/><a:ea typeface="\(font)"/></a:majorFont>
              <a:minorFont><a:latin typeface="\(font)"/><a:ea typeface="\(font)"/></a:minorFont>
            </a:fontScheme>
            <a:fmtScheme name="Office"><a:fillStyleLst/><a:lnStyleLst/><a:effectStyleLst/><a:bgFillStyleLst/></a:fmtScheme>
          </a:themeElements>
        </a:theme>
        """
    }

    static func slideXML(visualTemplate: PPTVisualTemplate) -> String {
        let accent = rgb(from: visualTemplate.accentHex)
        let metaFill = rgb(from: visualTemplate.metadataBackgroundHex)
        let font = visualTemplate.fontFamily
        let urlFontSize = max(6, visualTemplate.captionFontSize - 1)
        let disclaimerFontSize = max(6, visualTemplate.captionFontSize - 2)
        return """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <p:sld xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main">
          <p:cSld name="MedEditAI Slide">
            <p:spTree>
              <p:nvGrpSpPr><p:cNvPr id="1" name=""/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr>
              <p:grpSpPr/>
              \(shape(id: 2, name: "Topic", x: 365760, y: 182880, cx: 8229600, cy: 365760, text: "{{topic}}", fontFamily: font, fontSize: visualTemplate.topicFontSize, bold: true, color: accent))
              \(shape(id: 3, name: "Rule", x: 365760, y: 594360, cx: 4200000, cy: 36576, text: "", fontFamily: font, fontSize: 12, bold: false, color: accent, fillHex: accent))
              \(shape(id: 4, name: "TitleEN", x: 365760, y: 731520, cx: 8229600, cy: 685800, text: "{{title_en}}", fontFamily: font, fontSize: visualTemplate.titleFontSize, bold: true, color: "1D1D1F"))
              \(shape(id: 5, name: "TitleCN", x: 365760, y: 1500000, cx: 8229600, cy: 548640, text: "{{title_cn}}", fontFamily: font, fontSize: visualTemplate.subtitleFontSize, bold: true, color: "4A4A4A"))
              \(shape(id: 6, name: "MetaBox", x: 5943600, y: 2057400, cx: 2640960, cy: 1143000, text: "作者：{{authors}}\n发表日期：{{pub_date}}\n研究类型：{{study_type}}\n期刊：{{journal}}\nIF：{{if}}", fontFamily: font, fontSize: visualTemplate.metadataFontSize, bold: false, color: "1D1D1F", fillHex: metaFill))
              \(shape(id: 7, name: "Abstract", x: 365760, y: 3291840, cx: 8229600, cy: 1463040, text: "\(escape(visualTemplate.abstractPrefix)){{abstract_cn}}", fontFamily: font, fontSize: visualTemplate.bodyFontSize, bold: false, color: "1D1D1F"))
              \(shape(id: 8, name: "Citation", x: 365760, y: 5303520, cx: 8229600, cy: 548640, text: "\(escape(visualTemplate.citationPrefix)){{citation}}", fontFamily: font, fontSize: visualTemplate.captionFontSize, bold: false, color: "555555"))
              \(shape(id: 9, name: "Button", x: 365760, y: 5943600, cx: 2286000, cy: 365760, text: "\(escape(visualTemplate.ctaText))", fontFamily: font, fontSize: visualTemplate.metadataFontSize, bold: true, color: "FFFFFF", fillHex: accent))
              \(shape(id: 10, name: "URL", x: 365760, y: 6442560, cx: 8229600, cy: 274320, text: "{{url}}", fontFamily: font, fontSize: urlFontSize, bold: false, color: "0A84FF"))
              \(shape(id: 11, name: "Disclaimer", x: 365760, y: 6716880, cx: 8229600, cy: 274320, text: "\(escape(visualTemplate.disclaimerText))", fontFamily: font, fontSize: disclaimerFontSize, bold: false, color: "666666"))
            </p:spTree>
          </p:cSld>
          <p:clrMapOvr><a:masterClrMapping/></p:clrMapOvr>
        </p:sld>
        """
    }

    static func shape(id: Int, name: String, x: Int, y: Int, cx: Int, cy: Int, text: String, fontFamily: String, fontSize: Double, bold: Bool, color: String, fillHex: String? = nil) -> String {
        let fill = fillHex.map { "<a:solidFill><a:srgbClr val=\"\($0)\"/></a:solidFill>" } ?? "<a:noFill/>"
        let line = "<a:ln><a:noFill/></a:ln>"
        let sz = Int((fontSize * 100).rounded())
        let runProps = "<a:rPr lang=\"zh-CN\" sz=\"\(sz)\" b=\"\(bold ? 1 : 0)\"><a:solidFill><a:srgbClr val=\"\(color)\"/></a:solidFill><a:latin typeface=\"\(escape(fontFamily))\"/><a:ea typeface=\"\(escape(fontFamily))\"/></a:rPr>"
        let textXml = text.isEmpty ? "" : "<a:p><a:r>\(runProps)<a:t>\(escape(text))</a:t></a:r></a:p>"
        return """
        <p:sp>
          <p:nvSpPr><p:cNvPr id=\"\(id)\" name=\"\(name)\"/><p:cNvSpPr txBox=\"1\"/><p:nvPr/></p:nvSpPr>
          <p:spPr><a:xfrm><a:off x=\"\(x)\" y=\"\(y)\"/><a:ext cx=\"\(cx)\" cy=\"\(cy)\"/></a:xfrm><a:prstGeom prst=\"rect\"><a:avLst/></a:prstGeom>\(fill)\(line)</p:spPr>
          <p:txBody><a:bodyPr wrap=\"square\" rtlCol=\"0\" anchor=\"t\"/><a:lstStyle/>\(textXml)</p:txBody>
        </p:sp>
        """
    }

    private static func rgb(from hex: String) -> String {
        hex.replacingOccurrences(of: "#", with: "").uppercased()
    }

    private static func escape(_ text: String) -> String {
        text.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
    }
}
