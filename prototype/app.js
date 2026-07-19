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
  progress: 0,
  queueTick: 0,
  pageSize: 25,
  selectedForExport: new Set(['a1', 'a2', 'a3']),
  tasks: {
    translate: true,
    study: true,
    topic: true,
    products: true,
    metrics: true,
  },
};

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
            <div class="stat-delta">含 onepage 客户模板</div>
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
              <div class="quick-desc">使用客户自备 .pptx 模板和自定义 Excel 导出模板</div>
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
            <input type="number" class="field-input" style="width: 130px; font-size:13px;" value="2024" />
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
              ${[10, 25, 50, 100].map(n => `<option value="${n}" ${state.pageSize === n ? 'selected' : ''}>${n} 条/页</option>`).join('')}
            </select>
          </div>
        </div>
        
        <div class="query-str mt-16">
          <b>PubMed query:</b> ("pulsed field ablation"[Title/Abstract] OR PFA[Title/Abstract]) AND ("atrial fibrillation"[Title/Abstract] OR AF[Title/Abstract]) AND (2024:3000[pdat])
        </div>

        <div class="card mt-24" style="overflow:hidden;">
          <div class="tbl-head" style="grid-template-columns: 36px 1.8fr .8fr .6fr .8fr .55fr;">
            <div><div class="check ${data.articles.every(a => state.selectedForExport.has(a.id)) ? 'on' : ''}" data-select-all><svg viewBox="0 0 24 24"><path d="M5 13l4 4L19 7"/></svg></div></div>
            <div>标题</div>
            <div>作者</div>
            <div>研究类型</div>
            <div>期刊</div>
            <div>IF</div>
          </div>
          ${data.articles.map((a, idx) => `
            <div class="tbl-row" style="grid-template-columns: 36px 1.8fr .8fr .6fr .8fr .55fr;" data-select-row="${a.id}">
              <div><div class="check ${state.selectedForExport.has(a.id) ? 'on' : ''}"><svg viewBox="0 0 24 24"><path d="M5 13l4 4L19 7"/></svg></div></div>
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
      </div>
    </section>
  `;
}

function renderLibrary() {
  const article = getSelectedArticle();
  return `
    <section class="view">
      <div class="page-head">
        <div>
          <div class="page-title">文献库</div>
          <div class="page-sub">三栏工作台：分类树 / 文献列表 / 中英对照详情</div>
        </div>
        <div class="flex items-center gap-8">
          <button class="btn">导入 Excel</button>
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
              <div class="split-head">文献列表 · 23 篇</div>
              ${data.articles.map(a => `
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

  const queue = [
    ['已完成', 'Pulsed field ablation: Disrupting technologies...', 'done'],
    ['运行中', 'Evaluation of variable inter-pulse delays...', 'run'],
    ['等待中', 'Internal atrial shock delivery in goats...', 'wait'],
    ['等待中', 'Latest Advances and Ongoing Challenges...', 'wait'],
  ];

  return `
    <section class="view">
      <div class="page-head">
        <div>
          <div class="page-title">AI 加工</div>
          <div class="page-sub">每项任务独立可开关、可重跑、可回滚；低置信度自动进入待复核</div>
        </div>
        <div class="flex items-center gap-8">
          <button class="btn" data-action="demoToggleAll">切换任务</button>
          <button class="btn btn-primary" data-action="runPipeline">运行批处理</button>
        </div>
      </div>

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
            <div class="mt-8 muted" style="font-size:12px;">进度 ${state.progress}% · 可断点续跑</div>
            <div class="mt-16">
              ${queue.map(([label, title, status]) => `
                <div class="queue-item">
                  <div class="q-status q-${status}">
                    ${status === 'done' ? icon('<path d="M20 6 9 17l-5-5"/>') : status === 'run' ? `<svg viewBox="0 0 24 24" class="ico spin"><path d="M12 3a9 9 0 1 1-9 9"/></svg>` : icon('<path d="M12 8v4l3 3"/><path d="M21 12a9 9 0 1 1-18 0 9 9 0 0 1 18 0Z"/>')}
                  </div>
                  <div class="spacer">
                    <div style="font-weight:600;">${title}</div>
                    <div class="muted" style="font-size:11.5px;">${label}</div>
                  </div>
                  ${status === 'run' ? '<span class="tag tag-type">处理中</span>' : status === 'done' ? '<span class="tag tag-q1">完成</span>' : '<span class="tag tag-muted">排队</span>'}
                </div>
              `).join('')}
            </div>
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
          <div class="page-sub">PPT + Excel 双交付物；客户模板即产品模板</div>
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
                <div class="slide">
                  <div class="slide-topic">${article.topic}</div>
                  <div class="slide-rule"></div>
                  <div class="slide-title-en">${article.titleEn}</div>
                  <div class="slide-title-cn">${article.titleCn}</div>
                  <div class="slide-infocard">
                    作者：${article.authors}<br>
                    发表日期：${article.date}<br>
                    研究类型：${article.studyType}<br>
                    期刊：${article.journal}<br>
                    IF：${article.if}
                  </div>
                  <div class="slide-abstract"><b>摘要：</b>${article.abstractCn}</div>
                  <div class="slide-foot">
                    <div class="slide-cite">参考文献：${article.citation}</div>
                    <div class="slide-linkbtn">点击查看原文链接</div>
                    <div class="slide-url">${article.url}</div>
                    <div class="slide-disc">*版权问题暂不提供直接下载，如有学术交流需要，请联系内部人员</div>
                  </div>
                </div>
              </div>

              <div class="card" style="padding:14px; background:var(--panel-2);">
                <div class="section-title" style="margin:0 0 10px; font-size:14px;">模板设置</div>
                <div class="setting-row" style="padding-left:0; padding-right:0;">
                  <div class="setting-main">
                    <div>
                      <div class="setting-name">客户模板</div>
                      <div class="setting-desc">20260413-PFA图书馆-onepage.pptx</div>
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
                      <div class="setting-desc">含超链接与版权免责声明</div>
                    </div>
                  </div>
                  <button class="btn btn-sm">编辑</button>
                </div>
              </div>
            </div>
          </div>

          <div class="grid" style="gap:16px;">
            <div class="card" style="padding:16px;">
              <div class="section-title" style="margin:0 0 10px;">PPT 占位符映射</div>
              ${data.pptPlaceholders.map(([src, target]) => `
                <div class="map-row">
                  <div class="map-pill src">${src}</div>
                  <div class="map-arrow">→</div>
                  <div class="map-pill">${target}</div>
                </div>
              `).join('')}
            </div>

            <div class="card" style="padding:16px;">
              <div class="section-title" style="margin:0 0 10px;">Excel 导出模板</div>
              ${data.exportMappings.slice(0, 6).map(([src, target]) => `
                <div class="map-row">
                  <div class="map-pill src">${src}</div>
                  <div class="map-arrow">→</div>
                  <div class="map-pill">${target}</div>
                </div>
              `).join('')}
              <div class="mt-16 muted" style="font-size:12.5px; line-height:1.65;">支持自定义列名、列顺序、超链接字段和年份化 IF 列（如“2025年IF”）。</div>
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
          <div class="page-title">设置与数据源</div>
          <div class="page-sub">管理模型、IF 数据集、分类体系、导入/导出模板</div>
        </div>
        <div class="flex items-center gap-8">
          <button class="btn">导入分类字典</button>
          <button class="btn btn-primary">保存配置</button>
        </div>
      </div>

      <div class="page-body">
        <div class="grid grid-2">
          <div class="card">
            <div class="setting-row">
              <div class="setting-main">
                <div>
                  <div class="setting-name">LLM API Key</div>
                  <div class="setting-desc">必填；用于调用云端 LLM 执行翻译与主题分析（未配置时无法进行 AI 加工）</div>
                </div>
              </div>
              <input class="field-input" placeholder="sk-..." type="password" value="sk-xxxxxx" style="width: 140px;" />
            </div>
            <div class="setting-row">
              <div class="setting-main">
                <div>
                  <div class="setting-name">AI 加工 Prompt</div>
                  <div class="setting-desc">查看并自定义翻译 / 主题分类使用的 Prompt</div>
                </div>
              </div>
              <button class="btn btn-sm" onclick="qs('#promptDialog').style.display='block'">查看/编辑</button>
            </div>
            <div class="setting-row">
              <div class="setting-main">
                <div>
                  <div class="setting-name">NCBI API Key</div>
                  <div class="setting-desc">提升 PubMed 检索速率，遵守 E-utilities 限流规则</div>
                </div>
              </div>
              <input class="field-input" value="已配置" />
            </div>
            <div class="setting-row">
              <div class="setting-main">
                <div>
                  <div class="setting-name">IF / 分区数据集</div>
                  <div class="setting-desc">JCR 2025.xlsx（用户导入，自持版权数据）</div>
                </div>
              </div>
              <button class="btn btn-sm">更新数据</button>
            </div>
            <div class="setting-row">
              <div class="setting-main">
                <div>
                  <div class="setting-name">PPT 模板</div>
                  <div class="setting-desc">onepage.pptx，自动识别 11 个占位符（需用户上传自备 .pptx，不提供内置默认模板）</div>
                </div>
              </div>
              <button class="btn btn-sm">替换模板</button>
            </div>
          </div>

          <div class="card">
            <div class="setting-row">
              <div class="setting-main">
                <div>
                  <div class="setting-name">导入模板</div>
                  <div class="setting-desc">PFA 工作稿（6 列）</div>
                </div>
              </div>
              <button class="btn btn-sm">编辑映射</button>
            </div>
            <div class="setting-row">
              <div class="setting-main">
                <div>
                  <div class="setting-name">导出模板</div>
                  <div class="setting-desc">PFA 交付 Excel（11 列，含摘要链接 / 原文链接）</div>
                </div>
              </div>
              <button class="btn btn-sm">编辑映射</button>
            </div>
            <div class="setting-row">
              <div class="setting-main">
                <div>
                  <div class="setting-name">主题分类体系</div>
                  <div class="setting-desc">四级菜单 + 呈现方式 + 文献备注（导入 Excel 时可指定列名对应层级，也可手动新增词条）</div>
                </div>
              </div>
              <button class="btn btn-sm">导入 Excel</button>
            </div>
            <div class="setting-row">
              <div class="setting-main">
                <div>
                  <div class="setting-name">研究类型体系</div>
                  <div class="setting-desc">综述 / 社论 / 动物实验 / 土豆模型（可自行增删；未配置时 AI 根据标题/摘要自动推断，无法判断则留空）</div>
                </div>
              </div>
              <button class="btn btn-sm">维护词表</button>
            </div>
          </div>
        </div>

        <div class="grid grid-2 mt-24">
          <div class="card" style="padding:16px;">
            <div class="section-title" style="margin:0 0 10px;">导入映射说明</div>
            <div class="muted" style="font-size:12.5px; line-height:1.65; margin-bottom:10px;">
              导入映射 = 您的 Excel 字段名（源列）映射到系统底层数据模型字段（target key）。系统会自动猜测，您也可以在导入确认界面逐列修改。字段优先级分为：必需 / 建议 / 可选。
            </div>
            ${data.importFieldGuide.map(field => `
              <div class="field-guide-item">
                <div class="field-guide-head">
                  <div class="field-guide-label-wrap">
                    <div class="field-guide-label">${field.label}</div>
                    <span class="field-guide-badge ${field.priority === 'required' ? 'required' : field.priority === 'recommended' ? 'recommended' : 'optional'}">${field.priority === 'required' ? '必需' : field.priority === 'recommended' ? '建议' : '可选'}</span>
                  </div>
                  <div class="field-guide-key">${field.key}</div>
                </div>
                <div class="field-guide-desc">${field.desc}</div>
              </div>
            `).join('')}
          </div>
          <div class="card" style="padding:16px;">
            <div class="section-title" style="margin:0 0 10px;">设计原则</div>
            <div class="muted" style="font-size:13px; line-height:1.75;">
              本原型坚持“专业、克制、精致”的界面语言，采用 macOS 三栏式工作台布局，突出可追溯、可复核和客户自定义能力，而不是做通用的 AI 幻灯工具。
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
  state.progress = 0;
  render();

  const steps = [16, 31, 47, 68, 84, 100];
  steps.forEach((p, idx) => {
    setTimeout(() => {
      state.progress = p;
      render();
      if (p === 100) {
        state.processing = false;
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
