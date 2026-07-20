/* ============================================================
   MedEditAI 原型 — 应用逻辑（零依赖）
   使用真实 PFA 图书馆案例数据构建高保真原型
   ============================================================ */

const state = {
  theme: 'light',
  view: 'dashboard',
  project: 'PFA图书馆',
  selectedArticleId: 'a1',
  selectedSlide: 1,
  processing: false,
  processingPaused: false,
  processingDone: false,
  progress: 0,
  queueTick: 0,
  pageSize: 25,
  yearFrom: null, // 不指定：不限制起始年份
  showLowConfidenceOnly: false,
  selectedForExport: new Set(['a1', 'a2', 'a3']),
  tasks: {
    translate: true,
    study: true,
    topic: true,
    products: true,
    metrics: true,
  },
  customTasks: [
    { title: '风险分层', output: 'riskLevel', prompt: '请基于{title}和{abstract}输出风险分层结论。' },
  ],
  pptTemplate: {
    name: 'MedEditAI Onepage',
    accentHex: '#0E9F9F',
    metadataBg: '#EAF8F7',
    ctaText: '点击查看原文链接',
    abstractPrefix: '摘要：',
    citationPrefix: '参考文献：',
    disclaimerText: '*版权问题暂不提供直接下载，如有学术交流需要，请联系内部人员',
    fontFamily: 'PingFang SC',
    topicFontSize: 18,
    titleFontSize: 22,
    subtitleFontSize: 16,
    bodyFontSize: 12,
    metadataFontSize: 11,
    captionFontSize: 9,
  },
};

// 与 Swift 端 SlidePreviewCard 一致的比例缩放：字号变化时，预览按比例实时更新。
function pptFontPx(basePreviewPx, templateValue, templateBase) {
  const ratio = templateBase > 0 ? (templateValue / templateBase) : 1;
  return Math.max(6, basePreviewPx * ratio).toFixed(1);
}

const data = {
  stats: {
    articles: 127,
    translated: 119,
    toReview: 11,
    templates: 4,
  },
  dashboardAlerts: [
    '11 条低置信度分类待复核',
    'PFA 图书馆 2025 年 IF 数据集已导入',
    'onepage PPT 模板已识别 11 个占位符',
  ],
  categories: [
    {
      name: 'Science of PFA',
      children: [
        {
          name: '原理和影响因素',
          children: [
            {
              name: 'PFA发展史和生物物理学原理',
              children: [
                { name: '原理——PFA与既往热能源有何不同？', count: 23, active: true },
                { name: '组织选择性——不同细胞真有清晰损伤阈值吗？', count: 14 },
              ],
            },
            {
              name: 'PFA的影响因素',
              children: [
                { name: '电场强度——为何是衡量PFA损伤的第一因素？', count: 18 },
                { name: '波形、脉宽和频率——纳秒真的能解决麻醉问题吗？', count: 40 },
              ],
            },
          ],
        },
      ],
    },
  ],
  articles: [
    {
      id: 'a1',
      topic: '原理——PFA与既往热能源有何不同？',
      titleEn: 'The Biophysics of Radiofrequency Ablation and Factors Affecting Lesion Size',
      titleCn: '射频消融的生物物理学原理及消融灶尺寸的影响因素',
      abstractEn: 'Radiofrequency ablation has been the mainstay of catheter ablation. This review summarizes the biophysics of RF lesion formation and compares thermal energy behavior with newer pulsed field approaches.',
      abstractCn: '射频消融长期是导管消融的核心能量形式。本文综述了射频消融灶形成的生物物理学机制，并与新兴的脉冲电场消融在能量作用方式、组织反应和损伤边界控制方面进行比较，为理解 PFA 与既往热能源的差异提供了理论基础。',
      citation: 'Bates AP, et al. The Biophysics of Radiofrequency Ablation and Factors Affecting Lesion Size. Arrhythm Electrophysiol Rev. 2026 Mar 3.',
      authors: 'Bates AP, et al',
      date: '2026-03-03',
      studyType: '综述',
      journal: 'Arrhythm Electrophysiol Rev',
      if: '3.3',
      quartile: 'Q2',
      pmid: '41835106',
      url: 'https://pmc.ncbi.nlm.nih.gov/articles/PMCxxxxxxxx/pdf',
      confidence: 'high',
      product: 'PFA / RF 对照原理',
      evidence: '综述证据',
      notes: '交付 deck 第 1 页；用于与传统热能源机制对照。',
    },
    {
      id: 'a2',
      topic: '原理——PFA与既往热能源有何不同？',
      titleEn: 'Latest Advances and Ongoing Challenges in Pulsed Field Ablation',
      titleCn: '脉冲电场消融的最新进展与持续挑战',
      abstractEn: 'This review discusses current technical advances in PFA and remaining questions regarding waveform, tissue selectivity, and collateral damage.',
      abstractCn: '本文总结了 PFA 技术的最新进展，并围绕波形设计、组织选择性和邻近组织安全性等关键问题梳理仍待解决的挑战。文章可作为 PFA 原理与临床转化之间的桥梁性材料。',
      citation: 'Vázquez-Calvo S, et al. Latest Advances and Ongoing Challenges in Pulsed Field Ablation. Arrhythm Electrophysiol Rev. 2026 Feb 24.',
      authors: 'Vázquez-Calvo S, et al',
      date: '2026-02-24',
      studyType: '综述',
      journal: 'Arrhythm Electrophysiol Rev',
      if: '3.3',
      quartile: 'Q2',
      pmid: '41835109',
      url: 'https://pmc.ncbi.nlm.nih.gov/articles/PMCyyyyyyyy/pdf',
      confidence: 'high',
      product: 'PFA 原理',
      evidence: '综述证据',
      notes: '适合作为第 2-3 页。',
    },
    {
      id: 'a3',
      topic: '原理——PFA与既往热能源有何不同？',
      titleEn: 'Pulsed field ablation: Disrupting technologies for cardiac arrhythmias',
      titleCn: '脉冲电场消融：心律失常治疗的颠覆性技术',
      abstractEn: 'PFA leverages irreversible electroporation to achieve tissue ablation without relying on thermal injury, potentially improving safety near vulnerable structures.',
      abstractCn: 'PFA 通过不可逆电穿孔实现组织消融，不依赖热损伤机制，因此在邻近脆弱结构区域具备潜在安全优势。该文集中讨论了其相较于射频与冷冻的差异化价值。',
      citation: 'Miklavčič D, et al. Pulsed field ablation: Disrupting technologies for cardiac arrhythmias. Heart Rhythm. 2025 Dec 15.',
      authors: 'Miklavčič D, et al',
      date: '2025-12-15',
      studyType: '综述',
      journal: 'Heart Rhythm',
      if: '5.8',
      quartile: 'Q1',
      pmid: '41407239',
      url: 'https://www.heartrhythmjournal.com/article/xxx',
      confidence: 'mid',
      product: 'PFA / 热能源对照',
      evidence: '综述证据',
      notes: '主题分类置信度中等，建议复核。',
    },
    {
      id: 'a4',
      topic: '原理——PFA与既往热能源有何不同？',
      titleEn: 'Evaluation of variable inter-pulse delays for pulsed field ablation',
      titleCn: '不同脉冲间隔对脉冲电场消融效果的评估',
      abstractEn: 'Preclinical work evaluated variable inter-pulse delay settings and their effects on lesion quality and tissue response.',
      abstractCn: '该项前临床研究评估了不同脉冲间隔设置对消融灶质量和组织反应的影响，为理解 PFA 参数优化提供实验依据。',
      citation: 'Steiger NA, et al. Evaluation of variable inter-pulse delays for pulsed field ablation. J Interv Card Electrophysiol. 2025 Oct 22.',
      authors: 'Steiger NA, et al',
      date: '2025-10-22',
      studyType: '土豆模型',
      journal: 'J Interv Card Electrophysiol',
      if: '2.6',
      quartile: 'Q3',
      pmid: '41123832',
      url: 'https://link.springer.com/article/10.xxxx',
      confidence: 'low',
      product: 'PFA 参数优化',
      evidence: '实验模型',
      notes: '研究类型为客户自定义术语“土豆模型”，显示系统需支持自定义研究类型。',
    },
    {
      id: 'a5',
      topic: '原理——PFA与既往热能源有何不同？',
      titleEn: 'Internal atrial shock delivery by standard diagnostic electrophysiology catheters in goats',
      titleCn: '通过标准诊断性电生理导管进行心房内电击的山羊实验',
      abstractEn: 'An animal model assessed atrial shock delivery and tissue architectural changes, informing early electroporation understanding.',
      abstractCn: '该动物实验通过山羊模型评估心房内电击传递及其对组织结构的影响，为早期电穿孔相关消融机制提供实验依据。',
      citation: 'Wijffels MC, et al. Internal atrial shock delivery by standard diagnostic electrophysiology catheters in goats. Europace. 2007 Mar 9.',
      authors: 'Wijffels MC, et al',
      date: '2007-03-09',
      studyType: '动物实验',
      journal: 'Europace',
      if: '7.5',
      quartile: 'Q1',
      pmid: '17395650',
      url: 'https://academic.oup.com/europace/article/9/4/203/640812',
      confidence: 'high',
      product: '电穿孔基础实验',
      evidence: '动物实验',
      notes: '用于历史追溯部分。',
    },
  ],
  importMappings: [
    ['序号', 'sequence'],
    ['标题', 'titleEn'],
    ['摘要/研究简介-原文', 'abstractEn'],
    ['摘要/研究简介-翻译', 'abstractCn'],
    ['研究类型', 'studyDesign'],
    ['主题分类', 'topicCategories'],
  ],
  importFieldGuide: [
    { key: 'topic', label: '主题分类', desc: '文章所属主题词条；用于主题筛选和分组导出。', priority: 'recommended' },
    { key: 'titleEN', label: '标题（英文）', desc: '文献英文标题；导入必填（至少一列映射到此字段）。', priority: 'required' },
    { key: 'titleCN', label: '标题（中文）', desc: '中文标题；未提供时可在 AI 加工阶段补全。', priority: 'optional' },
    { key: 'abstractEN', label: '摘要（原文）', desc: '原始摘要文本；用于翻译和分类推断。', priority: 'recommended' },
    { key: 'abstractCN', label: '摘要（中文）', desc: '中文摘要；可人工填写或由 AI 生成。', priority: 'optional' },
    { key: 'keywords', label: '关键词', desc: '关键词（可分号分隔）；增强检索与分类上下文。', priority: 'optional' },
    { key: 'authors', label: '作者', desc: '作者列表；用于展示与引用。', priority: 'recommended' },
    { key: 'date', label: '发表日期', desc: '日期或年份；用于排序与导出。', priority: 'recommended' },
    { key: 'studyDesign', label: '研究类型', desc: '研究设计类型（RCT/队列/综述等）；可留空后续推断。', priority: 'recommended' },
    { key: 'journal', label: '期刊', desc: '期刊名称；用于匹配 IF。', priority: 'recommended' },
    { key: 'impactFactor', label: '影响因子', desc: '期刊 IF；可通过 IF 数据集自动回填。', priority: 'optional' },
    { key: 'pmid', label: 'PMID', desc: 'PubMed 唯一标识；用于溯源与去重。', priority: 'recommended' },
    { key: 'url', label: '原文链接', desc: 'DOI 或全文 URL；用于导出交付和跳转。', priority: 'recommended' },
    { key: 'abstractLink', label: '摘要链接', desc: '摘要页链接（如 PubMed 页面）。', priority: 'optional' },
    { key: 'note', label: '备注', desc: '人工说明、复核记录、客户关注点。', priority: 'optional' },
  ],
  exportMappings: [
    ['主题', 'topic'],
    ['序号', 'sequence'],
    ['标题', 'titleEn'],
    ['摘要/内容简介详情链接', 'abstractLink'],
    ['作者', 'authors'],
    ['发表日期', 'date'],
    ['研究类型', 'studyDesign'],
    ['期刊', 'journal'],
    ['2025年IF', 'impactFactor'],
    ['PMID', 'pmid'],
    ['原文链接', 'url'],
  ],
  pptPlaceholders: [
    ['{{topic}}', 'topic'],
    ['{{title_en}}', 'titleEn'],
    ['{{title_cn}}', 'titleCn'],
    ['{{authors}}', 'authors'],
    ['{{pub_date}}', 'date'],
    ['{{study_type}}', 'studyDesign'],
    ['{{journal}}', 'journal'],
    ['{{if}}', 'impactFactor'],
    ['{{abstract_cn}}', 'abstractCn'],
    ['{{citation}}', 'citation'],
    ['{{url}}', 'url'],
  ],
};

function qs(sel, root = document) { return root.querySelector(sel); }
function qsa(sel, root = document) { return Array.from(root.querySelectorAll(sel)); }
function getSelectedArticle() { return data.articles.find(a => a.id === state.selectedArticleId) || data.articles[0]; }

function icon(path) {
  return `<svg viewBox="0 0 24 24" class="ico">${path}</svg>`;
}

function confBadge(level) {
  const map = {
    high: ['高可信', 'conf-high'],
    mid: ['中等可信', 'conf-mid'],
    low: ['待复核', 'conf-low'],
  };
  const [label, cls] = map[level] || map.high;
  return `<span class="conf ${cls}"><span class="conf-dot"></span>${label}</span>`;
}

function toast(text) {
  const wrap = qs('#toastWrap');
  const el = document.createElement('div');
  el.className = 'toast';
  el.innerHTML = `${icon('<path d="M20 6 9 17l-5-5"/>')}<span>${text}</span>`;
  wrap.appendChild(el);
  setTimeout(() => {
    el.classList.add('out');
    setTimeout(() => el.remove(), 300);
  }, 2200);
}

function render() {
  qs('#content').innerHTML = views[state.view]();
  qs('#titlebarTitle').textContent = `MedEditAI — ${titleMap[state.view]}`;
  bindView();
}

const titleMap = {
  dashboard: '仪表盘',
  search: '检索中心',
  library: '文献库',
  enrich: 'AI 加工',
  slides: '产出生成',
  settings: '设置',
};

const views = {
  dashboard: renderDashboard,
  search: renderSearch,
  library: renderLibrary,
  enrich: renderEnrich,
  slides: renderSlides,
  settings: renderSettings,
};

function renderDashboard() {
  return `
    <section class="view">
      <div class="page-head">
        <div>
          <div class="page-title">${state.project}</div>
          <div class="page-sub">真实案例驱动的医学编辑工作台，当前项目为 PFA 图书馆</div>
        </div>
        <div class="flex items-center gap-8">
          <button class="btn btn-ghost" data-action="demoProcess">演示批处理</button>
          <button class="btn btn-primary" data-nav="search">开始检索</button>
        </div>
      </div>

      <div class="page-body">
        <div class="grid grid-4">
          <div class="card stat">
            <div class="stat-label">${icon('<path d="M4 19h16M6 17V7m6 10V5m6 12v-7"/>')}文献总量</div>
            <div class="stat-value">${data.stats.articles}</div>
            <div class="stat-delta">+24 本周期新增</div>
          </div>
          <div class="card stat">
            <div class="stat-label">${icon('<path d="M12 3v18M3 12h18"/>')}已翻译</div>
            <div class="stat-value">${data.stats.translated}</div>
            <div class="stat-delta">93.7% 已完成</div>
          </div>
          <div class="card stat">
            <div class="stat-label">${icon('<path d="M12 9v4l2.5 2.5M21 12a9 9 0 1 1-18 0 9 9 0 0 1 18 0Z"/>')}待复核</div>
            <div class="stat-value">${data.stats.toReview}</div>
            <div class="stat-delta" style="color: var(--warn);">建议优先处理</div>
          </div>
          <div class="card stat">
            <div class="stat-label">${icon('<path d="M4 4h16v12H4zM8 20h8"/>')}模板数</div>
            <div class="stat-value">${data.stats.templates}</div>
            <div class="stat-delta">含产品内可编辑 onepage 模板</div>
          </div>
        </div>

        <div class="section-title">快捷开始</div>
        <div class="grid grid-3">
          <div class="card quick" data-nav="search">
            <div class="quick-ico" style="background: linear-gradient(145deg, #0e9f9f, #16c8b8);">${icon('<path d="M11 4a7 7 0 1 0 0 14 7 7 0 0 0 0-14Zm10 17-5.2-5.2"/>')}</div>
            <div>
              <div class="quick-title">从 PubMed 开始检索</div>
              <div class="quick-desc">输入关键词或高级检索式，批量拉取文献元数据</div>
            </div>
          </div>
          <div class="card quick" data-nav="library">
            <div class="quick-ico" style="background: linear-gradient(145deg, #0a84ff, #54a8ff);">${icon('<path d="M4 5v14M8 5v14M13 5l5 14"/>')}</div>
            <div>
              <div class="quick-title">导入已有 Excel 清单</div>
              <div class="quick-desc">智能列映射，不要求固定格式，可复用映射模板</div>
            </div>
          </div>
          <div class="card quick" data-nav="slides">
            <div class="quick-ico" style="background: linear-gradient(145deg, #f97316, #fb923c);">${icon('<path d="M3 4h18v12H3zM8 20h8M12 16v4"/>')}</div>
            <div>
              <div class="quick-title">生成 onepage 交付物</div>
              <div class="quick-desc">使用产品内可编辑的 PPT 模板和自定义 Excel 导出模板</div>
            </div>
          </div>
        </div>

        <div class="grid grid-2 mt-24">
          <div class="card" style="padding: 18px;">
            <div class="section-title" style="margin: 0 0 12px;">项目提醒</div>
            <div class="list">
              ${data.dashboardAlerts.map(item => `
                <div class="row" style="padding-left:0; padding-right:0; cursor:default;">
                  <div class="conf conf-high"><span class="conf-dot"></span>已就绪</div>
                  <div style="font-size:13.5px; font-weight:500;">${item}</div>
                </div>
              `).join('')}
            </div>
          </div>

          <div class="card" style="padding: 18px;">
            <div class="section-title" style="margin: 0 0 12px;">PFA 案例摘要</div>
            <div class="muted" style="font-size:13px; line-height:1.75;">
              当前原型直接按真实案例抽象：工作稿 Excel 与交付 Excel 为两套不同列结构；主题分类采用四级菜单树；研究类型存在客户自定义术语；PPT 为纵向 A4 onepage 结构化模板。
            </div>
            <div class="mt-16 flex gap-8">
              <span class="tag tag-type">四级主题树</span>
              <span class="tag tag-if">自定义 IF 数据源</span>
              <span class="tag tag-q1">用户模板 PPT</span>
            </div>
          </div>
        </div>
      </div>
    </section>
  `;
}

function renderSearch() {
  const article = getSelectedArticle();
  return `
    <section class="view">
      <div class="page-head">
        <div>
          <div class="page-title">检索中心</div>
          <div class="page-sub">透明展示 PubMed query，支持从零开始检索并直接入库</div>
        </div>
        <div class="flex items-center gap-8">
          <button class="btn btn-ghost" onclick="qs('.search-query-field').value=''">清空检索词</button>
          
          <div style="position: relative; display: inline-block;">
            <button class="btn btn-primary" onclick="qs('#batchDialog').style.display='block'">批量检索入库</button>
            <div id="batchDialog" class="card" style="display: none; position: absolute; top: calc(100% + 4px); right: 0; width: 280px; z-index: 100; box-shadow: 0 4px 20px rgba(0,0,0,0.15); padding: 8px;">
              <div style="padding: 8px; font-size: 13px; font-weight: 500; border-bottom: 1px solid var(--line); margin-bottom: 4px;">即将把检索结果写入当前项目的文献库。</div>
              <button class="btn btn-ghost" style="width: 100%; justify-content: flex-start; text-align: left; background: none; border-color: transparent;" onclick="toast('批量入库完成'); qs('#batchDialog').style.display='none'">下载所有检索结果（限前100条）</button>
              <button class="btn btn-ghost" style="width: 100%; justify-content: flex-start; text-align: left; background: none; border-color: transparent;" onclick="toast('已保留提取勾选文献'); qs('#batchDialog').style.display='none'">仅保留勾选结果</button>
              <button class="btn btn-ghost" style="width: 100%; justify-content: flex-start; text-align: left; background: none; border-color: transparent; color: var(--text-secondary);" onclick="qs('#batchDialog').style.display='none'">取消</button>
            </div>
          </div>
        </div>
      </div>

      <div class="page-body">
        <div class="searchbar">
          ${icon('<path d="M11 4a7 7 0 1 0 0 14 7 7 0 0 0 0-14Zm10 17-5.2-5.2"/>')}
          <input class="search-query-field" value="pulsed field ablation AND atrial fibrillation" />
          <button class="btn btn-sm btn-primary">检索</button>
        </div>
        
        <div class="flex items-center gap-16 mt-16">
          <div class="flex items-center gap-8">
            <span class="muted" style="font-size:12.5px;">起始年份</span>
            <input type="number" class="field-input" placeholder="不限" style="width: 130px; font-size:13px;" value="${state.yearFrom ?? ''}" data-action="yearFrom" />
          </div>
          <div class="flex items-center gap-8">
            <span class="muted" style="font-size:12.5px;">排序</span>
            <select class="field-input" style="width: 130px; font-size:13px;">
              <option>Best Match</option>
              <option>Publication Date</option>
              <option>Recently Added</option>
            </select>
          </div>
          <div class="flex items-center gap-8">
            <span class="muted" style="font-size:12.5px;">每页条数</span>
            <select class="field-input" data-action="pageSize" style="width: 110px; font-size:13px;">
              ${[10, 25, 50, 100, 200, 500, 1000].map(n => `<option value="${n}" ${state.pageSize === n ? 'selected' : ''}>${n} 条/页</option>`).join('')}
            </select>
          </div>
        </div>
        
        <div class="query-str mt-16">
          <b>PubMed query:</b> ("pulsed field ablation"[Title/Abstract] OR PFA[Title/Abstract]) AND ("atrial fibrillation"[Title/Abstract] OR AF[Title/Abstract])${state.yearFrom ? ` AND (${state.yearFrom}:3000[pdat])` : ''}
        </div>

        <div class="grid" style="grid-template-columns: 1.3fr .9fr; align-items:start; gap:16px; margin-top:24px;">
          <div class="card" style="overflow:hidden;">
            <div class="tbl-head" style="grid-template-columns: 36px 1.8fr .8fr .6fr .8fr .55fr;">
              <div><div class="check ${data.articles.every(a => state.selectedForExport.has(a.id)) ? 'on' : ''}" data-select-all><svg viewBox="0 0 24 24"><path d="M5 13l4 4L19 7"/></svg></div></div>
              <div>标题</div>
              <div>作者</div>
              <div>研究类型</div>
              <div>期刊</div>
              <div>IF</div>
            </div>
            ${data.articles.map(a => `
              <div class="tbl-row ${a.id === state.selectedArticleId ? 'selected' : ''}" style="grid-template-columns: 36px 1.8fr .8fr .6fr .8fr .55fr;" data-article="${a.id}">
                <div><div class="check ${state.selectedForExport.has(a.id) ? 'on' : ''}" data-select-row="${a.id}"><svg viewBox="0 0 24 24"><path d="M5 13l4 4L19 7"/></svg></div></div>
                <div>
                  <div class="t-title">${a.titleEn}</div>
                  <div class="t-sub">${a.titleCn}</div>
                </div>
                <div class="t-sub">${a.authors}</div>
                <div><span class="tag tag-type">${a.studyType}</span></div>
                <div class="t-sub">${a.journal}</div>
                <div><span class="tag tag-if">${a.if}</span></div>
              </div>
            `).join('')}
          </div>

          <div class="card" style="padding:16px;">
            <div class="section-title" style="margin:0 0 10px;">右侧完整文章信息</div>
            <div class="detail-block">
              <div class="detail-label">标题</div>
              <div class="bi">
                <div class="bi-en">${article.titleEn}</div>
                <div class="bi-cn">${article.titleCn}</div>
              </div>
            </div>
            <div class="detail-block">
              <div class="detail-label">摘要中译</div>
              <div class="bi-cn">${article.abstractCn}</div>
            </div>
            <div class="detail-block">
              <div class="detail-label">完整元数据</div>
              <dl class="kv">
                <dt>作者</dt><dd>${article.authors}</dd>
                <dt>日期</dt><dd>${article.date}</dd>
                <dt>研究类型</dt><dd>${article.studyType}</dd>
                <dt>期刊</dt><dd>${article.journal}</dd>
                <dt>PMID</dt><dd>${article.pmid}</dd>
              </dl>
            </div>
          </div>
        </div>
      </div>
    </section>
  `;
}

function renderLibrary() {
  const article = getSelectedArticle();
  const libraryArticles = state.showLowConfidenceOnly ? data.articles.filter(a => a.confidence === 'low') : data.articles;
  return `
    <section class="view">
      <div class="page-head">
        <div>
          <div class="page-title">文献库</div>
          <div class="page-sub">三栏工作台：分类树 / 文献列表 / 中英对照详情</div>
        </div>
        <div class="flex items-center gap-8">
          <button class="btn">导入 Excel</button>
          <button class="btn" data-action="toggleLowConfidence">${state.showLowConfidenceOnly ? '显示全部' : '仅看低置信度'}</button>
          <button class="btn" data-action="markReviewed">批量标记已复核</button>
          <button class="btn btn-primary" data-nav="enrich">批量 AI 加工</button>
        </div>
      </div>

      <div class="page-body" style="padding-top:0;">
        <div class="card" style="overflow:hidden;">
          <div class="split">
            <div class="split-col">
              <div class="split-head">主题分类（四级菜单）</div>
              <div class="tree">${renderTree(data.categories)}</div>
            </div>

            <div class="split-col">
              <div class="split-head">文献列表 · ${libraryArticles.length} 篇</div>
              ${libraryArticles.map(a => `
                <div class="lit-card ${a.id === state.selectedArticleId ? 'on' : ''}" data-article="${a.id}">
                  <div class="lit-en">${a.titleEn}</div>
                  <div class="lit-cn">${a.titleCn}</div>
                  <div class="lit-meta">
                    <span class="tag tag-type">${a.studyType}</span>
                    <span class="tag tag-if">IF ${a.if}</span>
                    <span class="tag ${a.quartile === 'Q1' ? 'tag-q1' : 'tag-muted'}">${a.quartile}</span>
                    ${confBadge(a.confidence)}
                  </div>
                  <div class="mt-8"><small class="muted">${a.authors} · ${a.journal} · PMID ${a.pmid}</small></div>
                </div>
              `).join('')}
            </div>

            <div class="split-col">
              <div class="split-head">详情与 AI 结果</div>
              <div class="detail">
                <div class="detail-block">
                  <div class="detail-label">标题</div>
                  <div class="bi">
                    <div class="bi-en">${article.titleEn}</div>
                    <div class="bi-cn">${article.titleCn}</div>
                  </div>
                </div>
                <div class="detail-block">
                  <div class="detail-label">元数据</div>
                  <dl class="kv">
                    <dt>作者</dt><dd>${article.authors}</dd>
                    <dt>日期</dt><dd>${article.date}</dd>
                    <dt>研究类型</dt><dd>${article.studyType}</dd>
                    <dt>期刊</dt><dd>${article.journal}</dd>
                    <dt>影响因子</dt><dd>${article.if} · ${article.quartile}</dd>
                    <dt>PMID</dt><dd>${article.pmid}</dd>
                  </dl>
                </div>
                <div class="detail-block">
                  <div class="detail-label">摘要中译 ${confBadge(article.confidence)}</div>
                  <div class="bi-cn">${article.abstractCn}</div>
                </div>
                <div class="detail-block">
                  <div class="detail-label">AI 字段</div>
                  <div class="ai-field">
                    <div class="ai-field-main"><span class="tag tag-type">研究设计</span><strong>${article.studyType}</strong></div>
                    ${confBadge(article.confidence)}
                  </div>
                  <div class="ai-field">
                    <div class="ai-field-main"><span class="tag tag-type">主题分类</span><strong>${article.topic}</strong></div>
                    <span class="tag tag-muted">四级菜单</span>
                  </div>
                  <div class="ai-field">
                    <div class="ai-field-main"><span class="tag tag-type">研究产品</span><strong>${article.product}</strong></div>
                    <span class="tag tag-muted">词典识别</span>
                  </div>
                  <div class="ai-field">
                    <div class="ai-field-main"><span class="tag tag-type">证据等级</span><strong>${article.evidence}</strong></div>
                    <span class="tag tag-muted">自动联动</span>
                  </div>
                </div>
                <div class="detail-block">
                  <div class="detail-label">备注</div>
                  <div class="muted" style="font-size:13px; line-height:1.7;">${article.notes}</div>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </section>
  `;
}

function renderTree(nodes, level = 1) {
  return nodes.map(node => {
    const children = node.children ? renderTree(node.children, level + 1) : '';
    const isLeaf = !node.children;
    return `
      <div>
        <div class="tree-node tree-l${Math.min(level, 4)} ${node.active ? 'on' : ''}">
          ${level < 4 ? '<span style="color: var(--text-3);">▾</span>' : '<span style="width:10px;"></span>'}
          <span>${node.name}</span>
          ${isLeaf ? `<span class="tree-count">${node.count}</span>` : ''}
        </div>
        ${children}
      </div>
    `;
  }).join('');
}

function renderEnrich() {
  const tasks = [
    ['translate', '翻译', '标题 / 摘要 / 关键词中译，受医学术语库约束', '<path d="M4 5h10M4 9h6M14 5s0 8 6 14M18 5c-.4 2.4-1.8 4.8-4 7"/><path d="M10 19l4-9 4 9"/>'],
    ['study', '研究设计分类', '支持客户自定义术语，如综述 / 动物实验 / 土豆模型', '<path d="M6 3h12v18l-6-3-6 3V3Z"/>'],
    ['topic', '主题分类', '支持四级树分类与“呈现方式 / 备注”等扩展字段', '<path d="M5 5h6v6H5zM13 5h6v6h-6zM9 13h6v6H9z"/>'],
    ['products', '研究产品识别', '抽取药物 / 器械 / 干预措施，可联动产品词典', '<path d="M7 21h10M12 17v4M7 3h10l1 6H6l1-6Zm0 6v3a5 5 0 1 0 10 0V9"/>'],
    ['metrics', 'IF / 分区匹配', '根据用户导入的 2025 IF 数据表进行本地匹配', '<path d="M4 19h16M7 16V8m5 8V5m5 11v-4"/>'],
  ];

  const queue = data.articles.map((article, index) => {
    if (state.processingDone) return ['已完成', article.titleEn, 'done'];
    if (state.processingPaused && index > 1) return ['已暂停', article.titleEn, 'pause'];
    if (state.processing && index === 1) return ['运行中', article.titleEn, 'run'];
    if (state.processing && index < 1) return ['已完成', article.titleEn, 'done'];
    return [article.confidence === 'low' ? '待复核' : '未处理', article.titleEn, article.confidence === 'low' ? 'fail' : 'wait'];
  });

  return `
    <section class="view">
      <div class="page-head">
        <div>
          <div class="page-title">AI 加工</div>
          <div class="page-sub">每项任务独立可开关、可重跑、可回滚；低置信度自动进入待复核</div>
        </div>
        <div class="flex items-center gap-8">
          <button class="btn" data-action="demoToggleAll">切换任务</button>
          <button class="btn" data-action="togglePause">${state.processingPaused ? '继续' : '暂停'}</button>
          <button class="btn btn-primary" data-action="runPipeline">运行批处理</button>
        </div>
      </div>

      ${state.processingDone ? `
        <div class="page-body" style="padding-bottom:0;">
          <div class="card" style="padding:16px; display:flex; align-items:center; justify-content:space-between; gap:16px;">
            <div>
              <div class="section-title" style="margin:0 0 6px;">AI 加工完成</div>
              <div class="muted" style="font-size:13px;">生成结果已实时同步到文献库，可直接跳转查看。</div>
            </div>
            <button class="btn btn-primary" data-nav="library">跳转到文献库页</button>
          </div>
        </div>
      ` : ''}

      <div class="page-body">
        <div class="grid grid-2">
          <div class="card" style="padding: 8px;">
            <div class="section-title" style="padding: 8px 12px 4px; margin: 0;">加工项</div>
            <div class="enrich-tasks">
              ${tasks.map(([key, name, desc, ico]) => `
                <div class="task-toggle">
                  <div class="task-ico">${icon(ico)}</div>
                  <div class="spacer">
                    <div class="task-name">${name}</div>
                    <div class="task-desc">${desc}</div>
                  </div>
                  <div class="switch ${state.tasks[key] ? 'on' : ''}" data-switch="${key}"></div>
                </div>
              `).join('')}
            </div>
          </div>

          <div class="card" style="padding: 18px;">
            <div class="section-title" style="margin:0 0 14px;">批处理队列</div>
            <div class="muted" style="font-size:13px; margin-bottom:10px;">本次将处理 23 篇文献，优先输出中文摘要、研究设计、主题分类与 IF 匹配。</div>
            <div class="progress-track"><div class="progress-fill" style="width:${state.progress}%;"></div></div>
            <div class="mt-8 muted" style="font-size:12px;">进度 ${state.progress}% · 已处理 ${queue.filter(x => x[2] === 'done').length} / 正在处理 ${queue.filter(x => x[2] === 'run').length} / 未处理 ${queue.filter(x => x[2] === 'wait').length}</div>
            <div class="mt-16">
              ${queue.map(([label, title, status]) => `
                <div class="queue-item">
                  <div class="q-status q-${status}">
                    ${status === 'done' ? icon('<path d="M20 6 9 17l-5-5"/>') : status === 'run' ? `<svg viewBox="0 0 24 24" class="ico spin"><path d="M12 3a9 9 0 1 1-9 9"/></svg>` : status === 'pause' ? icon('<path d="M10 7v10M14 7v10"/><path d="M21 12a9 9 0 1 1-18 0 9 9 0 0 1 18 0Z"/>') : icon('<path d="M12 8v4l3 3"/><path d="M21 12a9 9 0 1 1-18 0 9 9 0 0 1 18 0Z"/>')}
                  </div>
                  <div class="spacer">
                    <div style="font-weight:600;">${title}</div>
                    <div class="muted" style="font-size:11.5px;">${label}${status === 'fail' ? ' · 需人工确认或重试' : ''}</div>
                  </div>
                  ${status === 'run' ? '<span class="tag tag-type">处理中</span>' : status === 'done' ? '<span class="tag tag-q1">完成</span>' : status === 'pause' ? '<span class="tag tag-if">暂停</span>' : status === 'fail' ? '<span class="tag tag-muted">待人工确认</span>' : '<span class="tag tag-muted">排队</span>'}
                </div>
              `).join('')}
            </div>
          </div>
        </div>

        <div class="grid grid-2 mt-24">
          <div class="card" style="padding:16px;">
            <div class="section-title" style="margin:0 0 10px;">自定义 AI 加工任务</div>
            ${state.customTasks.map(task => `
              <div class="setting-row" style="padding-left:0; padding-right:0;">
                <div class="setting-main">
                  <div>
                    <div class="setting-name">${task.title}</div>
                    <div class="setting-desc">输出字段：${task.output}</div>
                  </div>
                </div>
                <span class="tag tag-type">Prompt 可编辑</span>
              </div>
            `).join('')}
            <div class="mt-16 muted" style="font-size:12.5px; line-height:1.7;">支持新增 Prompt 和产出字段，例如 riskLevel、insightSummary、marketTag，并可在 Excel/PPT 模板中直接引用这些字段。</div>
          </div>

          <div class="card" style="padding:16px;">
            <div class="section-title" style="margin:0 0 10px;">完整文献列表</div>
            ${data.articles.map((article, index) => `
              <div class="setting-row" style="padding-left:0; padding-right:0; ${index === data.articles.length - 1 ? 'border-bottom:none;' : ''}">
                <div class="setting-main">
                  <div>
                    <div class="setting-name">${article.titleEn}</div>
                    <div class="setting-desc">${article.titleCn}</div>
                  </div>
                </div>
                ${confBadge(article.confidence)}
              </div>
            `).join('')}
          </div>
        </div>

        <div class="grid grid-3 mt-24">
          <div class="card" style="padding:16px;">
            <div class="section-title" style="margin:0 0 10px;">分类体系</div>
            <div class="muted" style="font-size:13px; line-height:1.7;">当前启用「PFA 图书馆主题树（四级）」与「PFA 研究类型（自定义）」两套方案，可按项目切换。</div>
            <div class="mt-16 flex gap-8">
              <span class="tag tag-type">四级菜单</span>
              <span class="tag tag-type">呈现方式字段</span>
              <span class="tag tag-type">备注字段</span>
            </div>
          </div>
          <div class="card" style="padding:16px;">
            <div class="section-title" style="margin:0 0 10px;">可信度策略</div>
            <div class="muted" style="font-size:13px; line-height:1.7;">所有 AI 结果都与原始文献字段分层存储，不覆盖原始数据。低置信度结果自动进入待复核列表。</div>
          </div>
          <div class="card" style="padding:16px;">
            <div class="section-title" style="margin:0 0 10px;">客户自定义术语</div>
            <div class="muted" style="font-size:13px; line-height:1.7;">示例：研究类型包含“综述”“社论”“动物实验”“土豆模型”。系统仅提供标准化机制，不强制替换客户术语。</div>
          </div>
        </div>
      </div>
    </section>
  `;
}

function renderSlides() {
  const article = getSelectedArticle();
  return `
    <section class="view">
      <div class="page-head">
        <div>
          <div class="page-title">产出生成</div>
          <div class="page-sub">PPT + Excel 双交付物；PPT 模板与 Excel 模板都可在产品内直接编辑</div>
        </div>
        <div class="flex items-center gap-8">
          <button class="btn" data-action="exportExcel">导出 Excel</button>
          <button class="btn btn-primary" data-action="exportPPT">导出 PPT</button>
        </div>
      </div>

      <div class="page-body">
        <div class="grid" style="grid-template-columns: 1.2fr 1fr; align-items:start;">
          <div class="card" style="padding:16px;">
            <div class="section-title" style="margin:0 0 14px;">PPT 预览（onepage 模板）</div>
            <div class="slides-layout">
              <div class="thumbs">
                ${data.articles.slice(0, 5).map((a, i) => `
                  <div class="thumb ${state.selectedSlide === i + 1 ? 'on' : ''}" data-slide="${i + 1}">
                    <div class="thumb-num">${i + 1}</div>
                    <div style="font-weight:700; font-size:7px; color:#0e9f9f;">${a.topic.slice(0, 10)}...</div>
                    <div style="height:1px; background:#d9eeee; margin:4px 0 6px;"></div>
                    <div style="font-size:7px; font-weight:700; line-height:1.3;">${a.titleEn.slice(0, 38)}...</div>
                    <div style="font-size:6px; color:#666; margin-top:4px;">${a.authors}</div>
                    <div style="margin-top:8px; background:#f4fbfb; border-radius:4px; padding:4px; font-size:6px;">作者 / 日期 / 研究类型 / IF</div>
                    <div style="margin-top:8px; font-size:6px; color:#444; line-height:1.5;">${a.abstractCn.slice(0, 90)}...</div>
                  </div>
                `).join('')}
              </div>

              <div>
                <div class="slide" style="font-family:${state.pptTemplate.fontFamily};">
                  <div class="slide-topic" style="color:${state.pptTemplate.accentHex}; font-size:${pptFontPx(12, state.pptTemplate.topicFontSize, 18)}px;">${article.topic}</div>
                  <div class="slide-rule" style="background:linear-gradient(90deg, ${state.pptTemplate.accentHex}, transparent);"></div>
                  <div class="slide-title-en" style="font-size:${pptFontPx(14, state.pptTemplate.titleFontSize, 22)}px;">${article.titleEn}</div>
                  <div class="slide-title-cn" style="font-size:${pptFontPx(12.5, state.pptTemplate.subtitleFontSize, 16)}px;">${article.titleCn}</div>
                  <div class="slide-infocard" style="background:${state.pptTemplate.metadataBg}; font-size:${pptFontPx(9.5, state.pptTemplate.metadataFontSize, 11)}px;">
                    作者：${article.authors}<br>
                    发表日期：${article.date}<br>
                    研究类型：${article.studyType}<br>
                    期刊：${article.journal}<br>
                    IF：${article.if}
                  </div>
                  <div class="slide-abstract" style="font-size:${pptFontPx(11.5, state.pptTemplate.bodyFontSize, 12)}px;"><b>${state.pptTemplate.abstractPrefix}</b>${article.abstractCn}</div>
                  <div class="slide-foot">
                    <div class="slide-cite" style="font-size:${pptFontPx(8.5, state.pptTemplate.captionFontSize, 9)}px;">${state.pptTemplate.citationPrefix}${article.citation}</div>
                    <div class="slide-linkbtn" style="background:${state.pptTemplate.accentHex}; font-size:${pptFontPx(10, state.pptTemplate.metadataFontSize, 11)}px;">${state.pptTemplate.ctaText}</div>
                    <div class="slide-url" style="font-size:${pptFontPx(8.5, state.pptTemplate.captionFontSize, 9)}px;">${article.url}</div>
                    <div class="slide-disc" style="font-size:${pptFontPx(8, state.pptTemplate.captionFontSize, 9)}px;">${state.pptTemplate.disclaimerText}</div>
                  </div>
                </div>
              </div>

              <div class="card" style="padding:14px; background:var(--panel-2);">
                <div class="section-title" style="margin:0 0 10px; font-size:14px;">模板设置</div>
                <div class="setting-row" style="padding-left:0; padding-right:0;">
                  <div class="setting-main">
                    <div>
                      <div class="setting-name">产品内模板</div>
                      <div class="setting-desc">${state.pptTemplate.name} · ${state.pptTemplate.fontFamily}</div>
                    </div>
                  </div>
                  <span class="tag tag-q1">A4 纵向</span>
                </div>
                <div class="setting-row" style="padding-left:0; padding-right:0;">
                  <div class="setting-main">
                    <div>
                      <div class="setting-name">分组维度</div>
                      <div class="setting-desc">按四级主题生成独立 deck</div>
                    </div>
                  </div>
                  <span class="tag tag-type">topic</span>
                </div>
                <div class="setting-row" style="padding-left:0; padding-right:0; border-bottom:none;">
                  <div class="setting-main">
                    <div>
                      <div class="setting-name">导出字段</div>
                      <div class="setting-desc">含按钮文案、版权说明和占位符映射</div>
                    </div>
                  </div>
                  <span class="tag tag-type">UI 编辑</span>
                </div>
              </div>
            </div>
          </div>

          <div class="grid" style="gap:16px;">
            <div class="card" style="padding:16px;">
              <div class="section-title" style="margin:0 0 10px;">PPT 样式模板</div>
              <div class="setting-row" style="padding-left:0; padding-right:0;">
                <input class="field-input" data-ppt-field="name" value="${state.pptTemplate.name}" style="width:42%;" />
                <input class="field-input" data-ppt-field="accentHex" value="${state.pptTemplate.accentHex}" style="width:26%;" />
                <input class="field-input" data-ppt-field="metadataBg" value="${state.pptTemplate.metadataBg}" style="width:26%;" />
              </div>
              <div class="setting-row" style="padding-left:0; padding-right:0;">
                <input class="field-input" data-ppt-field="ctaText" value="${state.pptTemplate.ctaText}" style="width:42%;" />
                <input class="field-input" data-ppt-field="abstractPrefix" value="${state.pptTemplate.abstractPrefix}" style="width:26%;" />
                <input class="field-input" data-ppt-field="citationPrefix" value="${state.pptTemplate.citationPrefix}" style="width:26%;" />
              </div>
              <div class="setting-row" style="padding-left:0; padding-right:0;">
                <span class="muted" style="font-size:12.5px; width:70px;">字体</span>
                <select class="field-input" data-ppt-field="fontFamily" style="width:70%;">
                  ${['PingFang SC', 'Songti SC', 'STHeiti Sans', 'Helvetica Neue', 'Arial', 'Georgia', 'Times New Roman', 'Menlo'].map(f => `<option ${f === state.pptTemplate.fontFamily ? 'selected' : ''}>${f}</option>`).join('')}
                </select>
              </div>
              <div class="setting-row" style="padding-left:0; padding-right:0; flex-wrap:wrap; gap:8px;">
                ${[['topicFontSize', '主题标签'], ['titleFontSize', '英文标题'], ['subtitleFontSize', '中文标题'], ['bodyFontSize', '正文摘要'], ['metadataFontSize', '信息框'], ['captionFontSize', '引文/脚注']].map(([field, label]) => `
                  <div class="flex items-center gap-8" style="width:31%;">
                    <span class="muted" style="font-size:11.5px;">${label}</span>
                    <input class="field-input" type="number" min="6" max="48" data-ppt-field="${field}" value="${state.pptTemplate[field]}" style="width:56px; min-width:56px;" />
                  </div>
                `).join('')}
              </div>
              <div class="mt-16 muted" style="font-size:12.5px; line-height:1.7;">无需上传 .pptx 文件，直接在产品内编辑模板名称、主色、字体、字号、按钮文案、摘要前缀和版权说明；左侧预览实时刷新。</div>
            </div>

            <div class="card" style="padding:16px;">
              <div class="section-title" style="margin:0 0 10px;">PPT 占位符映射</div>
              ${data.pptPlaceholders.map(([src, target]) => `
                <div class="setting-row" style="padding-left:0; padding-right:0;">
                  <input class="field-input" value="${src}" style="width: 42%;" />
                  <span class="muted">→</span>
                  <select class="field-input" style="width: 42%;">
                    ${['topic', 'titleEn', 'titleCn', 'authors', 'date', 'studyDesign', 'journal', 'impactFactor', 'abstractCn', 'citation', 'url', 'riskLevel'].map(option => `<option ${option === target ? 'selected' : ''}>${option}</option>`).join('')}
                  </select>
                </div>
              `).join('')}
              <div class="mt-16 card" style="padding:12px; background:var(--panel-2);">
                <div class="section-title" style="margin:0 0 8px; font-size:13px;">实时预览</div>
                <div class="muted" style="font-size:12px; line-height:1.7;">{{title_en}} → ${article.titleEn}</div>
                <div class="muted" style="font-size:12px; line-height:1.7;">{{abstract_cn}} → ${article.abstractCn.slice(0, 60)}...</div>
              </div>
            </div>

            <div class="card" style="padding:16px;">
              <div class="section-title" style="margin:0 0 10px;">Excel 导出模板</div>
              ${data.exportMappings.slice(0, 6).map(([src, target]) => `
                <div class="setting-row" style="padding-left:0; padding-right:0;">
                  <input class="field-input" value="${src}" style="width: 38%;" />
                  <select class="field-input" style="width: 38%;">
                    ${['topic', 'sequence', 'titleEn', 'abstractLink', 'authors', 'date', 'studyDesign', 'journal', 'impactFactor', 'pmid', 'url', 'riskLevel'].map(option => `<option ${option === target ? 'selected' : ''}>${option}</option>`).join('')}
                  </select>
                  <span class="tag tag-type">预览</span>
                </div>
              `).join('')}
              <div class="mt-16 card" style="padding:12px; background:var(--panel-2); overflow:auto;">
                <div class="section-title" style="margin:0 0 8px; font-size:13px;">实时预览</div>
                <table style="width:100%; border-collapse:collapse; font-size:12px;">
                  <tr>${data.exportMappings.slice(0, 4).map(([src]) => `<th style="text-align:left; padding:6px; border-bottom:1px solid var(--border);">${src}</th>`).join('')}</tr>
                  <tr>${[article.topic, '1', article.titleEn, article.url].map(cell => `<td style="padding:6px; border-bottom:1px solid var(--border);">${cell}</td>`).join('')}</tr>
                </table>
              </div>
            </div>
          </div>
        </div>
      </div>
    </section>
  `;
}

function renderSettings() {
  return `
    <section class="view">
      <div class="page-head">
        <div>
          <div class="page-title">系统设置</div>
          <div class="page-sub">仅保留系统密钥与默认项目配置；Excel 导入映射在导入时自动识别并要求确认</div>
        </div>
        <div class="flex items-center gap-8">
          <button class="btn">使用当前项目覆盖默认配置</button>
          <button class="btn btn-primary">保存默认项目配置</button>
        </div>
      </div>

      <div class="page-body">
        <div class="section-title" style="margin:0 0 12px;">系统密钥</div>
        <div class="grid grid-2">
          <div class="card">
            <div class="setting-row">
              <div class="setting-main">
                <div>
                  <div class="setting-name">LLM API Key</div>
                  <div class="setting-desc">必填；用于调用云端 LLM 执行翻译、研究设计和主题分类</div>
                </div>
              </div>
              <input class="field-input" placeholder="sk-..." type="password" value="sk-xxxxxx" style="width: 140px;" />
            </div>
            <div class="setting-row">
              <div class="setting-main">
                <div>
                  <div class="setting-name">NCBI API Key</div>
                  <div class="setting-desc">可选；用于提升 PubMed 检索速率，遵守 E-utilities 限流规则</div>
                </div>
              </div>
              <input class="field-input" value="ncbi-xxxxxx" />
            </div>
          </div>

          <div class="card">
            <div class="setting-row">
              <div class="setting-main">
                <div>
                  <div class="setting-name">当前项目配置在哪里修改</div>
                  <div class="setting-desc">当前项目的 AI 加工任务、自定义研究类型、Excel 导出模板和 PPT 占位符映射不在这里混合编辑。</div>
                </div>
              </div>
              <span class="tag tag-type">项目级</span>
            </div>
            <div class="setting-row">
              <div class="setting-main">
                <div>
                  <div class="setting-name">当前项目</div>
                  <div class="setting-desc">PFA 图书馆</div>
                </div>
              </div>
              <span class="tag tag-if">当前项目</span>
            </div>
            <div class="setting-row">
              <div class="setting-main">
                <div>
                  <div class="setting-name">当前自定义加工任务</div>
                  <div class="setting-desc">已配置 1 个任务：风险分层</div>
                </div>
              </div>
              <button class="btn btn-sm" data-nav="enrich">前往 AI 加工页</button>
            </div>
            <div class="setting-row">
              <div class="setting-main">
                <div>
                  <div class="setting-name">当前导出模板 / PPT 模板</div>
                  <div class="setting-desc">当前项目单独维护，不受默认值编辑区直接覆盖</div>
                </div>
              </div>
              <button class="btn btn-sm" data-nav="slides">前往产出生成页</button>
            </div>
          </div>
        </div>

        <div class="section-title" style="margin:24px 0 12px;">默认项目配置</div>
        <div class="grid grid-2 mt-24">
          <div class="card" style="padding:16px;">
            <div class="section-title" style="margin:0 0 10px;">默认值说明</div>
            <div class="muted" style="font-size:12.5px; line-height:1.75; margin-bottom:12px;">
              这里编辑的是新建项目时自动继承的默认值。它不会反向覆盖已有项目；如果你想把当前项目整套配置沉淀成默认值，应使用顶部“使用当前项目覆盖默认配置”。
            </div>
            <div class="setting-row" style="padding-left:0; padding-right:0;">
              <div class="setting-main"><div><div class="setting-name">默认 Prompt</div><div class="setting-desc">翻译 / 主题分类 Prompt 作为新项目初始值</div></div></div>
              <span class="tag tag-type">可编辑</span>
            </div>
            <div class="setting-row" style="padding-left:0; padding-right:0;">
              <div class="setting-main"><div><div class="setting-name">默认研究类型词条</div><div class="setting-desc">综述 / 社论 / 动物实验 / 土豆模型</div></div></div>
              <span class="tag tag-q1">新项目复用</span>
            </div>
            <div class="setting-row" style="padding-left:0; padding-right:0;">
              <div class="setting-main"><div><div class="setting-name">默认 IF / 分区数据集</div><div class="setting-desc">JCR 2025.xlsx（新建项目自动继承）</div></div></div>
              <button class="btn btn-sm">导入</button>
            </div>
            <div class="setting-row" style="padding-left:0; padding-right:0; border-bottom:none;">
              <div class="setting-main"><div><div class="setting-name">默认 PPT 模板</div><div class="setting-desc">产品内置可编辑 onepage 模板，新建项目自动带出样式与占位符映射</div></div></div>
              <button class="btn btn-sm">选择</button>
            </div>
          </div>
          <div class="card" style="padding:16px;">
            <div class="section-title" style="margin:0 0 10px;">默认项目配置清单</div>
            <div class="muted" style="font-size:13px; line-height:1.75;">
              新建项目时自动继承：AI Prompt、IF 数据集、研究类型词条、PPT 模板、Excel 导出模板、PPT 占位符映射。用户导入 Excel 后的列映射由 AI 当场识别和确认，不做全局默认模板。
            </div>
          </div>
        </div>

        <div class="grid grid-2 mt-24">
          <div class="card" style="padding:16px;">
            <div class="section-title" style="margin:0 0 10px;">默认 Excel 导出模板</div>
            <div class="setting-row" style="padding-left:0; padding-right:0;">
              <div class="setting-main"><div><div class="setting-name">列名、列顺序、超链接字段</div><div class="setting-desc">可直接编辑，并在右侧实时查看预览</div></div></div>
              <span class="tag tag-if">实时预览</span>
            </div>
            <div class="setting-row" style="padding-left:0; padding-right:0; border-bottom:none;">
              <div class="setting-main"><div><div class="setting-name">默认字段范围</div><div class="setting-desc">标准字段 + 当前产品约定字段，供新项目起步使用</div></div></div>
              <span class="tag tag-type">模板起点</span>
            </div>
          </div>
          <div class="card" style="padding:16px;">
            <div class="section-title" style="margin:0 0 10px;">默认 PPT 占位符映射</div>
            <div class="setting-row" style="padding-left:0; padding-right:0;">
              <div class="setting-main"><div><div class="setting-name">占位符文本与字段映射</div><div class="setting-desc">支持自定义占位符和字段映射，并实时查看填充结果</div></div></div>
              <span class="tag tag-q1">新项目复用</span>
            </div>
            <div class="setting-row" style="padding-left:0; padding-right:0;">
              <div class="setting-main"><div><div class="setting-name">与当前项目关系</div><div class="setting-desc">已有项目继续保留各自模板，不会因为这里修改而被自动覆盖</div></div></div>
              <span class="tag tag-type">隔离</span>
            </div>
          </div>
        </div>
      </div>
    </section>
  `;
}

function bindView() {
  qsa('[data-nav]').forEach(el => {
    el.onclick = () => {
      state.view = el.dataset.nav;
      updateNav();
      render();
    };
  });

  qsa('[data-view]').forEach(el => {
    el.onclick = () => {
      state.view = el.dataset.view;
      updateNav();
      render();
    };
  });

  qsa('[data-article]').forEach(el => {
    el.onclick = () => {
      state.selectedArticleId = el.dataset.article;
      render();
    };
  });

  qsa('[data-slide]').forEach(el => {
    el.onclick = () => {
      state.selectedSlide = Number(el.dataset.slide);
      state.selectedArticleId = data.articles[state.selectedSlide - 1].id;
      render();
    };
  });

  qsa('[data-switch]').forEach(el => {
    el.onclick = () => {
      const key = el.dataset.switch;
      state.tasks[key] = !state.tasks[key];
      el.classList.toggle('on', state.tasks[key]);
      toast(`${labelForTask(key)}已${state.tasks[key] ? '启用' : '关闭'}`);
    };
  });

  qsa('[data-action="runPipeline"]').forEach(el => el.onclick = runDemoPipeline);
  qsa('[data-action="demoProcess"]').forEach(el => el.onclick = () => { state.view = 'enrich'; updateNav(); render(); setTimeout(runDemoPipeline, 120); });
  qsa('[data-action="demoToggleAll"]').forEach(el => el.onclick = () => {
    Object.keys(state.tasks).forEach((k, i) => setTimeout(() => { state.tasks[k] = !state.tasks[k]; render(); }, i * 60));
  });
  qsa('[data-action="exportPPT"]').forEach(el => el.onclick = () => toast('已导出 onepage PPT（示意）'));
  qsa('[data-action="exportExcel"]').forEach(el => el.onclick = () => toast('已导出客户 Excel 交付表（示意）'));

  qsa('[data-select-row]').forEach(el => {
    el.onclick = () => {
      const id = el.dataset.selectRow;
      if (state.selectedForExport.has(id)) state.selectedForExport.delete(id);
      else state.selectedForExport.add(id);
      render();
    };
  });

  const selectAllEl = qs('[data-select-all]');
  if (selectAllEl) {
    selectAllEl.onclick = () => {
      const allSelected = data.articles.every(a => state.selectedForExport.has(a.id));
      if (allSelected) state.selectedForExport.clear();
      else data.articles.forEach(a => state.selectedForExport.add(a.id));
      render();
    };
  }

  const pageSizeEl = qs('[data-action="pageSize"]');
  if (pageSizeEl) {
    pageSizeEl.onchange = () => {
      state.pageSize = Number(pageSizeEl.value);
      toast(`每页条数已切换为 ${state.pageSize} 条`);
      render();
    };
  }

  const yearEl = qs('[data-action="yearFrom"]');
  if (yearEl) {
    yearEl.onchange = () => {
      const trimmed = yearEl.value.trim();
      state.yearFrom = trimmed === '' ? null : Number(trimmed);
      toast(state.yearFrom === null ? '起始年份已清除（不限）' : `起始年份已切换为 ${state.yearFrom}`);
      render();
    };
  }

  qsa('[data-action="toggleLowConfidence"]').forEach(el => el.onclick = () => {
    state.showLowConfidenceOnly = !state.showLowConfidenceOnly;
    render();
  });

  qsa('[data-action="markReviewed"]').forEach(el => el.onclick = () => {
    data.articles.forEach(article => {
      if (article.confidence === 'low') article.confidence = 'high';
    });
    toast('已批量标记低置信度结果为已复核');
    render();
  });

  qsa('[data-action="togglePause"]').forEach(el => el.onclick = () => {
    state.processingPaused = !state.processingPaused;
    render();
  });

  qsa('[data-ppt-field]').forEach(el => {
    el.onchange = () => {
      const field = el.dataset.pptField;
      state.pptTemplate[field] = el.type === 'number' ? Number(el.value) : el.value;
      toast('PPT 样式模板已更新');
      render();
    };
  });

  qs('#themeToggle').onclick = toggleTheme;
}

function labelForTask(key) {
  return {
    translate: '翻译',
    study: '研究设计分类',
    topic: '主题分类',
    products: '研究产品识别',
    metrics: 'IF / 分区匹配',
  }[key] || '任务';
}

function updateNav() {
  qsa('.nav-item[data-view]').forEach(el => {
    el.classList.toggle('active', el.dataset.view === state.view);
  });
}

function toggleTheme() {
  state.theme = state.theme === 'light' ? 'dark' : 'light';
  document.documentElement.setAttribute('data-theme', state.theme);
  toast(state.theme === 'dark' ? '已切换到深色模式' : '已切换到浅色模式');
}

function runDemoPipeline() {
  if (state.processing) return;
  state.processing = true;
  state.processingPaused = false;
  state.processingDone = false;
  state.progress = 0;
  render();

  const steps = [16, 31, 47, 68, 84, 100];
  steps.forEach((p, idx) => {
    setTimeout(() => {
      state.progress = p;
      render();
      if (p === 100) {
        state.processing = false;
        state.processingDone = true;
        toast('批处理完成：23 篇文献已更新 AI 结果');
      }
    }, idx * 380);
  });
}

function init() {
  document.documentElement.setAttribute('data-theme', state.theme);
  updateNav();
  render();

  qsa('.project-item').forEach(el => {
    el.onclick = () => {
      qsa('.project-item').forEach(x => x.classList.remove('active', 'active-project'));
      el.classList.add('active-project');
      state.project = el.dataset.project;
      toast(`已切换项目：${state.project}`);
      render();
    };
  });
}

init();
