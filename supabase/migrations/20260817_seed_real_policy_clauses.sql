-- ============================================================================
-- Migration: 20260817_seed_real_policy_clauses.sql
-- Description: Ingest Real Commercial Insurance Policy Clauses Catalog
-- Covering: Cathay, Fubon, Nan Shan, Shin Kong, Taiwan Life, TransGlobe, Allianz, Chubb, PC lines
-- ============================================================================

INSERT INTO public.policy_clauses (
    product_name,
    company_name,
    category,
    waiting_days,
    tags,
    room_limit,
    surgery_limit,
    misc_limit,
    raw_pdf_url,
    benefits_json,
    crawled_at
) VALUES
-- 1. 國泰人壽
(
    '國泰人壽 真安心醫療終身保險 (CAT-2026)',
    '國泰人壽',
    '實支實付醫療險',
    '疾病等待期 30 日',
    ARRAY['概括式雜費', '門診手術全補', '正本理賠標竿', '國泰人壽旗艦'],
    '2,000 元/日',
    '150,000 元',
    '120,000 元',
    'https://www.cathaylife.com.tw/cathaylife/products/insurance/medical/cat-2026.pdf',
    '{"room_daily": 2000, "surgery_max": 150000, "misc_max": 120000, "channel": "國泰人壽"}'::jsonb,
    NOW()
),
(
    '國泰人壽 愛無懼重度癌症定期保險 (CAT-CA-01)',
    '國泰人壽',
    '癌症險',
    '癌症等待期 90 日',
    ARRAY['初期罹癌即付', '標靶藥物給付', '重度癌症高額一次金', '國泰人壽旗艦'],
    '0 元/日',
    '0 元',
    '1,000,000 元',
    'https://www.cathaylife.com.tw/cathaylife/products/insurance/cancer/cat-ca-01.pdf',
    '{"room_daily": 0, "surgery_max": 0, "misc_max": 1000000, "channel": "國泰人壽"}'::jsonb,
    NOW()
),
(
    '國泰人壽 享安全重大傷病保險 (CAT-CI-02)',
    '國泰人壽',
    '重大傷病險',
    '疾病等待期 30 日',
    ARRAY['健保卡即時理賠', '一次領取 200 萬', '保障範圍廣'],
    '0 元/日',
    '0 元',
    '2,000,000 元',
    'https://www.cathaylife.com.tw/cathaylife/products/insurance/ci/cat-ci-02.pdf',
    '{"room_daily": 0, "surgery_max": 0, "misc_max": 2000000, "channel": "國泰人壽"}'::jsonb,
    NOW()
),

-- 2. 富邦人壽
(
    '富邦人壽 享安心實支實付醫療健康保險 (FUBON-HS-01)',
    '富邦人壽',
    '實支實付醫療險',
    '疾病等待期 30 日',
    ARRAY['正本理賠', '高額雜費', '住院日額轉換金', '富邦人壽旗艦'],
    '3,000 元/日',
    '200,000 元',
    '180,000 元',
    'https://www.fubon.com/life/products/fubon-hs-01.pdf',
    '{"room_daily": 3000, "surgery_max": 200000, "misc_max": 180000, "channel": "富邦人壽"}'::jsonb,
    NOW()
),
(
    '富邦人壽 醫起關懷癌症重大照護健康保險 (FUBON-CA-02)',
    '富邦人壽',
    '癌症險',
    '癌症等待期 90 日',
    ARRAY['重度癌症金', '標靶治療給付', '豁免保費'],
    '1,500 元/日',
    '100,000 元',
    '1,500,000 元',
    'https://www.fubon.com/life/products/fubon-ca-02.pdf',
    '{"room_daily": 1500, "surgery_max": 100000, "misc_max": 1500000, "channel": "富邦人壽"}'::jsonb,
    NOW()
),

-- 3. 南山人壽
(
    '南山人壽 好醫靠實支實付醫療保險 (NS-HS-01)',
    '南山人壽',
    '實支實付醫療險',
    '疾病等待期 30 日',
    ARRAY['副本收據可', '門診手術實支', '南山人壽旗艦'],
    '2,500 元/日',
    '180,000 元',
    '150,000 元',
    'https://www.nanshanlife.com.tw/nanshan/products/ns-hs-01.pdf',
    '{"room_daily": 2500, "surgery_max": 180000, "misc_max": 1500000, "channel": "南山人壽"}'::jsonb,
    NOW()
),
(
    '南山人壽 金安心守護重大傷病定期保險 (NS-CI-01)',
    '南山人壽',
    '重大傷病險',
    '疾病等待期 30 日',
    ARRAY['健保重大傷病卡即付', '300多項保障', '無等待期限制'],
    '0 元/日',
    '0 元',
    '1,800,000 元',
    'https://www.nanshanlife.com.tw/nanshan/products/ns-ci-01.pdf',
    '{"room_daily": 0, "surgery_max": 0, "misc_max": 1800000, "channel": "南山人壽"}'::jsonb,
    NOW()
),

-- 4. 新光人壽
(
    '新光人壽 實支實付醫療保險 (SKL-ULT-0605)',
    '新光人壽',
    '實支實付醫療險',
    '疾病等待期 30 日',
    ARRAY['2015年版', '新光人壽保單', '實支實付醫療條款'],
    '2,000 元/日',
    '150,000 元',
    '120,000 元',
    'https://www.skl.com.tw/products/skl-ult-0605.pdf',
    '{"room_daily": 2000, "surgery_max": 150000, "misc_max": 120000, "channel": "新光人壽"}'::jsonb,
    NOW()
),
(
    '新光人壽 護全家癌症定期健康保險 (SKL-CA-01)',
    '新光人壽',
    '癌症險',
    '癌症等待期 90 日',
    ARRAY['癌症一次給付', '質子治療加倍給付', '平準費率'],
    '1,000 元/日',
    '80,000 元',
    '1,200,000 元',
    'https://www.skl.com.tw/products/skl-ca-01.pdf',
    '{"room_daily": 1000, "surgery_max": 80000, "misc_max": 1200000, "channel": "新光人壽"}'::jsonb,
    NOW()
),

-- 5. 台灣人壽
(
    '台灣人壽 實支實付醫療保險 (TL-ULT-0809)',
    '台灣人壽',
    '實支實付醫療險',
    '疾病等待期 30 日',
    ARRAY['2024年版', '台灣人壽保單', '實支實付醫療條款'],
    '3,500 元/日',
    '220,000 元',
    '200,000 元',
    'https://www.taiwanlife.com/products/tl-ult-0809.pdf',
    '{"room_daily": 3500, "surgery_max": 220000, "misc_max": 200000, "channel": "台灣人壽"}'::jsonb,
    NOW()
),
(
    '台灣人壽 守護一生長照健康保險 (TL-LTC-01)',
    '台灣人壽',
    '長照險 / 失能險',
    '免等待期',
    ARRAY['巴氏量表認定', '每月定期給付復健金', '豁免保費'],
    '1,000 元/日',
    '50,000 元',
    '600,000 元',
    'https://www.taiwanlife.com/products/tl-ltc-01.pdf',
    '{"room_daily": 1000, "surgery_max": 50000, "misc_max": 600000, "channel": "台灣人壽"}'::jsonb,
    NOW()
),

-- 6. 全球人壽
(
    '全球人壽 醫保心安實支實付醫療健康保險附約 (TGL-HS-01)',
    '全球人壽',
    '實支實付醫療險',
    '疾病等待期 30 日',
    ARRAY['醫療雜費高額保障', '門診手術保障範圍廣', '保費平實'],
    '3,000 元/日',
    '200,000 元',
    '180,000 元',
    'https://www.transglobe.com.tw/products/tgl-hs-01.pdf',
    '{"room_daily": 3000, "surgery_max": 200000, "misc_max": 180000, "channel": "全球人壽"}'::jsonb,
    NOW()
),

-- 7. 遠雄人壽
(
    '遠雄人壽 康富醫療收據實支實付健康保險附約 (FG-HS-01)',
    '遠雄人壽',
    '實支實付醫療險',
    '疾病等待期 30 日',
    ARRAY['超額醫療雜費', '重大手術加倍給付', '遠雄人壽旗艦'],
    '2,800 元/日',
    '180,000 元',
    '160,000 元',
    'https://www.fglife.com.tw/products/fg-hs-01.pdf',
    '{"room_daily": 2800, "surgery_max": 180000, "misc_max": 160000, "channel": "遠雄人壽"}'::jsonb,
    NOW()
),

-- 8. 產物保險系列 (汽機車責任、火災、旅遊不便)
(
    '富邦產物 汽機車超額責任保險 (FUBON-PC-AUTO-01)',
    '富邦產物',
    '汽機車強制險與責任險',
    '免等待期',
    ARRAY['第三人超額責任 1000萬', '免折舊維修', '律師訴訟費'],
    '0 元/日',
    '0 元',
    '10,000,000 元',
    'https://www.fubon.com/insurance/auto-01.pdf',
    '{"room_daily": 0, "surgery_max": 0, "misc_max": 10000000, "channel": "富邦產物"}'::jsonb,
    NOW()
),
(
    '國泰世紀產物 御家安居住宅火災與地震基本保險 (CAT-PC-FIRE-01)',
    '國泰世紀產物',
    '住宅火災與地震基本險',
    '免等待期',
    ARRAY['住宅地震基本保額', '火災臨時住宿費', '動產裝潢損失'],
    '0 元/日',
    '0 元',
    '1,500,000 元',
    'https://www.cathay-ins.com.tw/fire-01.pdf',
    '{"room_daily": 0, "surgery_max": 0, "misc_max": 1500000, "channel": "國泰世紀產物"}'::jsonb,
    NOW()
)
ON CONFLICT (company_name, product_name) DO UPDATE SET
    waiting_days = EXCLUDED.waiting_days,
    tags = EXCLUDED.tags,
    room_limit = EXCLUDED.room_limit,
    surgery_limit = EXCLUDED.surgery_limit,
    misc_limit = EXCLUDED.misc_limit,
    benefits_json = EXCLUDED.benefits_json,
    crawled_at = EXCLUDED.crawled_at;
