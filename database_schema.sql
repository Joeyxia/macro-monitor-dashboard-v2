-- 宏观经济监控系统数据库架构 v2
-- 基于14维机构级宏观监控模型设计

-- 创建每日报告主表
CREATE TABLE daily_reports (
    report_id INTEGER PRIMARY KEY AUTOINCREMENT,
    report_date DATE UNIQUE NOT NULL,
    as_of_date DATE NOT NULL, -- 模型更新日期
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    -- 综合评分
    overall_score REAL,
    score_interpretation TEXT, -- 'bullish', 'neutral', 'bearish'
    alert_count INTEGER DEFAULT 0, -- 预警数量
    
    -- 报告状态
    is_weekday BOOLEAN DEFAULT 1,
    report_generated BOOLEAN DEFAULT 0,
    data_validation_status TEXT DEFAULT 'pending' -- 'pending', 'validated', 'failed'
);

-- 创建14维度指标表
CREATE TABLE macro_dimensions (
    dimension_id INTEGER PRIMARY KEY AUTOINCREMENT,
    report_id INTEGER NOT NULL,
    dimension_code TEXT NOT NULL, -- D01, D02, ..., D14
    dimension_name TEXT NOT NULL,
    tier_level TEXT NOT NULL, -- 'Core Macro', 'Policy & External', 'Market Mapping', 'Theme Panel'
    weight_percentage REAL NOT NULL,
    
    -- 评分数据
    dimension_score REAL,
    raw_value TEXT, -- 存储原始指标值（可能为JSON格式多个指标）
    normalized_score REAL,
    
    -- 元数据
    update_frequency TEXT,
    last_updated TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    FOREIGN KEY (report_id) REFERENCES daily_reports(report_id),
    UNIQUE(report_id, dimension_code)
);

-- 创建关键指标详情表（45个指标）
CREATE TABLE key_indicators (
    indicator_id INTEGER PRIMARY KEY AUTOINCREMENT,
    dimension_id INTEGER NOT NULL,
    indicator_code TEXT NOT NULL, -- YC_10Y3M, SOFR, FED_ASSETS等
    indicator_name TEXT NOT NULL,
    current_value REAL,
    previous_value REAL,
    change_percentage REAL,
    units TEXT,
    frequency TEXT, -- Daily, Weekly, Monthly, Quarterly, Annual
    direction TEXT, -- 'HigherBetter', 'LowerBetter', 'TargetBand'
    
    -- 目标区间（用于TargetBand评分）
    target_low REAL,
    target_high REAL,
    worst_low REAL,
    worst_high REAL,
    cap_low REAL,
    cap_high REAL,
    
    -- 数据源信息
    data_source TEXT,
    source_url TEXT,
    series_code TEXT,
    last_fetched TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    -- 权重（在维度内的权重）
    weight_within_dimension REAL,
    
    FOREIGN KEY (dimension_id) REFERENCES macro_dimensions(dimension_id),
    UNIQUE(indicator_code, dimension_id)
);

-- 创建AI分析表
CREATE TABLE ai_analysis (
    analysis_id INTEGER PRIMARY KEY AUTOINCREMENT,
    report_id INTEGER NOT NULL,
    analysis_date DATE NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    -- AI相关指标
    ai_capex_quarterly REAL, -- AI资本开支季度数据
    stablecoin_liquidity REAL, -- 稳定币流动性
    openrouter_tokens_monthly REAL,
    openrouter_tokens_mom_growth REAL,
    
    -- AI市场分析
    ai_market_trend TEXT,
    model_competition_summary TEXT,
    ai_impact_on_macro TEXT,
    
    FOREIGN KEY (report_id) REFERENCES daily_reports(report_id),
    UNIQUE(report_id)
);

-- 创建专业术语表
CREATE TABLE glossary_terms (
    term_id INTEGER PRIMARY KEY AUTOINCREMENT,
    term_name TEXT UNIQUE NOT NULL,
    term_category TEXT NOT NULL, -- 'macro_indicator', 'financial_term', 'ai_term', 'data_source'
    definition TEXT NOT NULL,
    related_dimensions TEXT, -- JSON array of dimension codes
    example_usage TEXT,
    data_source TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 创建历史趋势表（用于图表展示）
CREATE TABLE historical_trends (
    trend_id INTEGER PRIMARY KEY AUTOINCREMENT,
    indicator_code TEXT NOT NULL,
    date_recorded DATE NOT NULL,
    value REAL NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(indicator_code, date_recorded)
);

-- 创建预警信号表
CREATE TABLE alerts (
    alert_id INTEGER PRIMARY KEY AUTOINCREMENT,
    report_id INTEGER NOT NULL,
    indicator_code TEXT NOT NULL,
    alert_type TEXT NOT NULL, -- 'red', 'yellow', 'green'
    alert_message TEXT NOT NULL,
    triggered_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (report_id) REFERENCES daily_reports(report_id)
);

-- 创建索引以提高查询性能
CREATE INDEX idx_reports_date ON daily_reports(report_date);
CREATE INDEX idx_dimensions_report ON macro_dimensions(report_id);
CREATE INDEX idx_dimensions_code ON macro_dimensions(dimension_code);
CREATE INDEX idx_indicators_dimension ON key_indicators(dimension_id);
CREATE INDEX idx_indicators_code ON key_indicators(indicator_code);
CREATE INDEX idx_ai_analysis_report ON ai_analysis(report_id);
CREATE INDEX idx_trends_indicator_date ON historical_trends(indicator_code, date_recorded);
CREATE INDEX idx_alerts_report ON alerts(report_id);

-- 插入14维模型的基础维度结构
INSERT INTO glossary_terms (term_name, term_category, definition, related_dimensions, data_source) VALUES
('D01 货币政策与流动性', 'macro_indicator', '核心指标: 10Y-3M利差、SOFR/EFFR、美联储总资产、净流动性代理。权重: 12%。更新频率: 日/周。', '["D01"]', 'FRED, NY Fed'),
('D02 增长与前瞻', 'macro_indicator', '核心指标: 实际GDP环比折年、制造业PMI、初请失业金4周均值、LEI同比。权重: 11%。更新频率: 周/月/季。', '["D02"]', 'BEA, ISM/S&P, FRED, Conference Board'),
('D03 通胀与价格压力', 'macro_indicator', '核心指标: 核心CPI、核心PCE、5Y5Y通胀预期。权重: 10%。更新频率: 月。', '["D03"]', 'BLS/FRED, BEA/FRED'),
('D04 就业与居民部门', 'macro_indicator', '核心指标: 失业率、工资增速、信用卡拖欠率、实际可支配收入同比。权重: 10%。更新频率: 月/季。', '["D04"]', 'BLS/FRED'),
('D05 企业盈利与信用', 'macro_indicator', '核心指标: 标普500 Forward P/E、EPS修正广度、HY OAS。权重: 8%。更新频率: 日/周/月。', '["D05"]', 'S&P, FRED'),
('D06 房地产与利率敏感部门', 'macro_indicator', '核心指标: 30年按揭利率、成屋销售、新屋开工。权重: 6%。更新频率: 周/月。', '["D06"]', 'FRED'),
('D07 风险偏好与跨资产波动', 'macro_indicator', '核心指标: VIX、MOVE、3个月最大回撤。权重: 6%。更新频率: 日/周。', '["D07"]', 'CBOE, FRED'),
('D08 外部部门与美元条件', 'macro_indicator', '核心指标: DXY/REER、美日利差、海外净买入美国资产。权重: 7%。更新频率: 周/月。', '["D08"]', 'FRED'),
('D09 财政政策与债务约束', 'macro_indicator', '核心指标: 财政赤字/GDP、债务/GDP、利息支出/财政收入。权重: 8%。更新频率: 月/季/年。', '["D09"]', 'Treasury, FRED'),
('D10 金融条件与信用传导', 'macro_indicator', '核心指标: FCI、银行信贷增速、TED利差。权重: 6%。更新频率: 周/月。', '["D10"]', 'Chicago Fed, FRED'),
('D11 大宗商品与能源/地缘风险', 'macro_indicator', '核心指标: WTI、CRB同比、GPR指数。权重: 5%。更新频率: 日/月。', '["D11"]', 'EIA, CRB, GPR'),
('D12 信心与不确定性', 'macro_indicator', '核心指标: 消费者信心、CEO Confidence、EPU。权重: 6%。更新频率: 月/季。', '["D12"]', 'Conference Board, EPU'),
('D13 AI资本开支周期（主题）', 'macro_indicator', '核心指标: 云与AI资本开支/营收动能。权重: 4%。更新频率: 季度。', '["D13"]', 'Company Reports, OpenRouter'),
('D14 加密与稳定币流动性（主题）', 'macro_indicator', '核心指标: 稳定币与链上流动性。权重: 1%。更新频率: 日/周。', '["D14"]', 'CoinGecko, Chainalysis');

-- 插入关键指标定义
INSERT INTO glossary_terms (term_name, term_category, definition, data_source) VALUES
('10Y-3M利差', 'financial_term', '10年期美国国债收益率与3个月期美国国债收益率之间的利差，是预测经济衰退的重要领先指标。', 'FRED (H.15)'),
('VIX', 'financial_term', '芝加哥期权交易所波动率指数，衡量标普500指数期权的隐含波动率，被称为“恐慌指数”。', 'CBOE'),
('SOFR', 'financial_term', '有担保隔夜融资利率，是替代LIBOR的美国主要基准利率。', 'NY Fed / FRED'),
('FCI', 'financial_term', '金融条件指数，综合反映货币政策、信贷条件和金融市场状况的指标。', 'Chicago Fed'),
('LEI', 'macro_indicator', '领先经济指标，由Conference Board发布的预测未来经济活动的综合指标。', 'Conference Board'),
('OpenRouter', 'ai_term', 'AI模型路由平台，提供多种大语言模型的统一API接口，用于监控AI使用趋势。', 'OpenRouter'),
('GPR指数', 'macro_indicator', '地缘政治风险指数，衡量全球地缘政治紧张程度对经济的影响。', 'GPR'),
('EPU', 'macro_indicator', '经济政策不确定性指数，衡量政策不确定性对经济决策的影响。', 'EPU');

-- 创建视图：14维模型概览
CREATE VIEW v_model_overview AS
SELECT 
    md.dimension_code,
    md.dimension_name,
    md.tier_level,
    md.weight_percentage,
    md.update_frequency,
    COUNT(ki.indicator_id) as indicator_count
FROM macro_dimensions md
LEFT JOIN key_indicators ki ON md.dimension_id = ki.dimension_id
GROUP BY md.dimension_code, md.dimension_name, md.tier_level, md.weight_percentage, md.update_frequency
ORDER BY 
    CASE md.tier_level 
        WHEN 'Core Macro' THEN 1
        WHEN 'Policy & External' THEN 2
        WHEN 'Market Mapping' THEN 3
        WHEN 'Theme Panel' THEN 4
    END,
    md.dimension_code;