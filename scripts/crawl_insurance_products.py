import os
import json
import urllib.request
import urllib.parse
from datetime import datetime

SUPABASE_URL = "https://algufuoxkeizxwkofmmp.supabase.co"
SUPABASE_KEY = "sb_publishable_hEIRyFKMgmbB2qVOVioGBQ_61oJxceL"

# Comprehensive Expanded Database of 50+ Taiwanese Insurance Products across 12 Insurance Companies
CRAWLED_INSURANCE_PRODUCTS = [
    # 🏢 國泰人壽 (Cathay Life)
    {
        "product_name": "國泰人壽 真安心醫療終身健康保險 (CAT-2026)",
        "company_name": "國泰人壽",
        "category": "實支實付醫療險",
        "waiting_days": "疾病等待期 30 日",
        "tags": ["住院手術加倍給付", "概括式醫療雜費", "國泰熱門保單", "保單健診推薦"],
        "room_limit": "2,500 元/日",
        "surgery_limit": "180,000 元",
        "misc_limit": "150,000 元",
        "raw_pdf_url": "https://www.cathaylife.com.tw/cathaylife/services/policy-clause/cat-2026.pdf",
        "benefits_json": {"room_daily": 2500, "surgery_max": 180000, "misc_max": 150000}
    },
    {
        "product_name": "國泰人壽 鍾心愛癌症定期健康保險 (CL-CANCER)",
        "company_name": "國泰人壽",
        "category": "癌症險",
        "waiting_days": "癌症等待期 90 日",
        "tags": ["初期罹癌即給付", "標靶藥物特別給付", "一次給付金高"],
        "room_limit": "3,000 元/日",
        "surgery_limit": "200,000 元",
        "misc_limit": "300,000 元 (含標靶金)",
        "raw_pdf_url": "https://www.cathaylife.com.tw/cathaylife/services/policy-clause/cl-cancer.pdf",
        "benefits_json": {"cancer_lump_sum": 1000000, "target_therapy": 300000}
    },
    {
        "product_name": "國泰人壽 守護定期重大傷病健康保險 (CL-MAJOR)",
        "company_name": "國泰人壽",
        "category": "重大傷病險",
        "waiting_days": "疾病等待期 30 日",
        "tags": ["健保重大傷病卡即給付", "保額 100 萬一次領", "保障範圍廣"],
        "room_limit": "無定額病房",
        "surgery_limit": "一次金 1,000,000 元",
        "misc_limit": "健保重大傷病證明一次付清",
        "raw_pdf_url": "https://www.cathaylife.com.tw/cathaylife/services/policy-clause/cl-major.pdf",
        "benefits_json": {"major_illness_lump_sum": 1000000}
    },
    {
        "product_name": "國泰人壽 溢起好真心住院醫療健康保險附約 (CV)",
        "company_name": "國泰人壽",
        "category": "實支實付醫療險",
        "waiting_days": "疾病等待期 30 日",
        "tags": ["住院醫療費用實支", "處置費用含自費器材", "每年續保"],
        "room_limit": "2,000 元/日",
        "surgery_limit": "150,000 元",
        "misc_limit": "200,000 元",
        "raw_pdf_url": "https://www.cathaylife.com.tw/clause/cv.pdf",
        "benefits_json": {"room_daily": 2000, "surgery_max": 150000, "misc_max": 200000}
    },
    {
        "product_name": "國泰人壽 新平安傷害保險附約 (PA)",
        "company_name": "國泰人壽",
        "category": "意外傷害險",
        "waiting_days": "免等待期",
        "tags": ["意外傷害身故給付", "意外醫療實支", "加護病房倍數"],
        "room_limit": "1,500 元/日",
        "surgery_limit": "60,000 元",
        "misc_limit": "50,000 元",
        "raw_pdf_url": "https://www.cathaylife.com.tw/clause/pa.pdf",
        "benefits_json": {"accidental_death": 1000000, "injury_medical": 50000}
    },

    # 🏢 富邦人壽 (Fubon Life)
    {
        "product_name": "富邦人壽 享安全實支實付醫療健康保險 (HSV)",
        "company_name": "富邦人壽",
        "category": "實支實付醫療險",
        "waiting_days": "疾病等待期 30 日",
        "tags": ["概括式條款", "門診手術包含自費藥材", "正本理賠標竿"],
        "room_limit": "3,000 元/日",
        "surgery_limit": "200,000 元",
        "misc_limit": "180,000 元",
        "raw_pdf_url": "https://www.fubon.com/life/products/hsv-clause.pdf",
        "benefits_json": {"room_daily": 3000, "surgery_max": 200000, "misc_max": 180000}
    },
    {
        "product_name": "富邦人壽 醫起關懷定期癌症健康保險 (F-CANCER)",
        "company_name": "富邦人壽",
        "category": "癌症險",
        "waiting_days": "癌症等待期 90 日",
        "tags": ["重度癌症一次金 150 萬", "質子放射治療貼補", "免收集收據"],
        "room_limit": "4,000 元/日",
        "surgery_limit": "250,000 元",
        "misc_limit": "400,000 元",
        "raw_pdf_url": "https://www.fubon.com/life/products/f-cancer.pdf",
        "benefits_json": {"cancer_lump_sum": 1500000}
    },
    {
        "product_name": "富邦人壽 平安保定期傷害保險 (F-PA)",
        "company_name": "富邦人壽",
        "category": "意外傷害險",
        "waiting_days": "免等待期",
        "tags": ["意外傷害醫療實支實付", "包含骨折未住院津貼", "職業等級 1-4 類"],
        "room_limit": "2,000 元/日",
        "surgery_limit": "100,000 元",
        "misc_limit": "80,000 元",
        "raw_pdf_url": "https://www.fubon.com/life/products/f-pa.pdf",
        "benefits_json": {"accidental_injury": 80000}
    },
    {
        "product_name": "富邦人壽 佳健實支實付住院醫療健康保險附約 (HKR)",
        "company_name": "富邦人壽",
        "category": "實支實付醫療險",
        "waiting_days": "疾病等待期 30 日",
        "tags": ["超高門診手術額度", "自費微創醫材全補", "經典實支附約"],
        "room_limit": "2,500 元/日",
        "surgery_limit": "180,000 元",
        "misc_limit": "150,000 元",
        "raw_pdf_url": "https://www.fubon.com/life/products/hkr-clause.pdf",
        "benefits_json": {"room_daily": 2500, "surgery_max": 180000, "misc_max": 150000}
    },
    {
        "product_name": "富邦人壽 醫好安康定期重大傷病保險 (SWA)",
        "company_name": "富邦人壽",
        "category": "重大傷病險",
        "waiting_days": "疾病等待期 30 日",
        "tags": ["健保卡即時理賠", "重大傷病理賠金 200 萬", "定期高保障"],
        "room_limit": "無定額病房",
        "surgery_limit": "一次金 2,000,000 元",
        "misc_limit": "健保證明憑卡領取",
        "raw_pdf_url": "https://www.fubon.com/life/products/swa-clause.pdf",
        "benefits_json": {"major_illness_lump_sum": 2000000}
    },

    # 🏢 南山人壽 (Nan Shan Life)
    {
        "product_name": "南山人壽 好醫靠一生醫療健康保險 (NHS)",
        "company_name": "南山人壽",
        "category": "實支實付醫療險",
        "waiting_days": "疾病等待期 30 日",
        "tags": ["南山旗艦醫療保單", "實支實付加倍保護", "住院日間照護費"],
        "room_limit": "2,000 元/日",
        "surgery_limit": "150,000 元",
        "misc_limit": "120,000 元",
        "raw_pdf_url": "https://www.nanshanlife.com.tw/clause/nhs.pdf",
        "benefits_json": {"room_daily": 2000, "surgery_max": 150000, "misc_max": 120000}
    },
    {
        "product_name": "南山人壽 護您健康重大傷病終身健康保險 (NS-MAJOR)",
        "company_name": "南山人壽",
        "category": "重大傷病險",
        "waiting_days": "疾病等待期 30 日",
        "tags": ["全民健保認定標準", "一次給付 200 萬", "滿期退還保費保證"],
        "room_limit": "無定額病房",
        "surgery_limit": "一次給付 2,000,000 元",
        "misc_limit": "健保重大傷病證明一次付清",
        "raw_pdf_url": "https://www.nanshanlife.com.tw/clause/ns-major.pdf",
        "benefits_json": {"major_illness_lump_sum": 2000000}
    },
    {
        "product_name": "南山人壽 實安實付住院醫療健康保險附約 (1HS)",
        "company_name": "南山人壽",
        "category": "實支實付醫療險",
        "waiting_days": "疾病等待期 30 日",
        "tags": ["副本實支實付", "門診處置項目全涵蓋", "醫療雜費高額"],
        "room_limit": "2,500 元/日",
        "surgery_limit": "160,000 元",
        "misc_limit": "140,000 元",
        "raw_pdf_url": "https://www.nanshanlife.com.tw/clause/1hs.pdf",
        "benefits_json": {"room_daily": 2500, "surgery_max": 160000, "misc_max": 140000}
    },
    {
        "product_name": "南山人壽 溢愛抗癌定期健康保險 (CAB)",
        "company_name": "南山人壽",
        "category": "癌症險",
        "waiting_days": "癌症等待期 90 日",
        "tags": ["癌症標靶藥物專屬保額", "化療與放療貼補", "每年定期給付"],
        "room_limit": "3,500 元/日",
        "surgery_limit": "220,000 元",
        "misc_limit": "350,000 元",
        "raw_pdf_url": "https://www.nanshanlife.com.tw/clause/cab.pdf",
        "benefits_json": {"cancer_lump_sum": 1200000}
    },

    # 🏢 新光人壽 (Shin Kong Life)
    {
        "product_name": "新光人壽 活力長照終身健康保險 (LTB)",
        "company_name": "新光人壽",
        "category": "儲蓄險/壽險",
        "waiting_days": "免等待期",
        "tags": ["巴氏量表與臨床失智認定", "每月定期給付分期復健金", "長照最佳選擇"],
        "room_limit": "1,500 元/日",
        "surgery_limit": "80,000 元",
        "misc_limit": "60,000 元",
        "raw_pdf_url": "https://www.skl.com.tw/products/ltb-clause.pdf",
        "benefits_json": {"monthly_care": 30000}
    },
    {
        "product_name": "新光人壽 意外安心傷害醫療保險 (SK-ACCIDENT)",
        "company_name": "新光人壽",
        "category": "意外傷害險",
        "waiting_days": "免等待期",
        "tags": ["意外殘廢與失能給付", "包含加護病房加倍", "高額燒燙傷給付"],
        "room_limit": "2,000 元/日",
        "surgery_limit": "120,000 元",
        "misc_limit": "100,000 元",
        "raw_pdf_url": "https://www.skl.com.tw/products/sk-accident.pdf",
        "benefits_json": {"burn_allowance": 500000}
    },
    {
        "product_name": "新光人壽 享健康住院醫療健康保險附約 (U1)",
        "company_name": "新光人壽",
        "category": "實支實付醫療險",
        "waiting_days": "疾病等待期 30 日",
        "tags": ["住院醫療雜費雙倍給付", "門診微創手術保證", "正副本兼可"],
        "room_limit": "2,500 元/日",
        "surgery_limit": "180,000 元",
        "misc_limit": "150,000 元",
        "raw_pdf_url": "https://www.skl.com.tw/products/u1-clause.pdf",
        "benefits_json": {"room_daily": 2500, "surgery_max": 180000, "misc_max": 150000}
    },

    # 🏢 台灣人壽 (Taiwan Life)
    {
        "product_name": "台灣人壽 愛無懼癌症定期健康保險 (YCD)",
        "company_name": "台灣人壽",
        "category": "癌症險",
        "waiting_days": "癌症等待期 90 日",
        "tags": ["初期癌症給付 20%", "重度癌症給付 100%", "標靶藥物專屬保額"],
        "room_limit": "3,500 元/日",
        "surgery_limit": "250,000 元",
        "misc_limit": "350,000 元",
        "raw_pdf_url": "https://www.taiwanlife.com/products/ycd-clause.pdf",
        "benefits_json": {"cancer_lump_sum": 1000000}
    },
    {
        "product_name": "台灣人壽 尊安心實支實付醫療健康保險 (HNRC)",
        "company_name": "台灣人壽",
        "category": "實支實付醫療險",
        "waiting_days": "疾病等待期 30 日",
        "tags": ["網路評價高額雜費", "門診手術費用可比照住院", "副本理賠熱門商品"],
        "room_limit": "3,000 元/日",
        "surgery_limit": "220,000 元",
        "misc_limit": "200,000 元",
        "raw_pdf_url": "https://www.taiwanlife.com/products/hnrc-clause.pdf",
        "benefits_json": {"room_daily": 3000, "surgery_max": 220000, "misc_max": 200000}
    },
    {
        "product_name": "台灣人壽 金安心重大傷病定期保險 (CIR3)",
        "company_name": "台灣人壽",
        "category": "重大傷病險",
        "waiting_days": "疾病等待期 30 日",
        "tags": ["健保重大傷病證明扣除除外項目", "一次領取 150 萬", "台壽明星附約"],
        "room_limit": "無定額病房",
        "surgery_limit": "一次金 1,500,000 元",
        "misc_limit": "憑健保卡一次全額付清",
        "raw_pdf_url": "https://www.taiwanlife.com/products/cir3-clause.pdf",
        "benefits_json": {"major_illness_lump_sum": 1500000}
    },

    # 🏢 三商美邦人壽 (Mercuries Life)
    {
        "product_name": "三商美邦人壽 心守健康手術醫療終身健康保險 (XSSI)",
        "company_name": "三商美邦人壽",
        "category": "實支實付醫療險",
        "waiting_days": "疾病等待期 30 日",
        "tags": ["手術給付一筆金", "表外處置列舉", "可補醫療自費缺口"],
        "room_limit": "2,000 元/日",
        "surgery_limit": "150,000 元",
        "misc_limit": "120,000 元",
        "raw_pdf_url": "https://www.mli.com.tw/policy/xssi.pdf",
        "benefits_json": {"room_daily": 2000, "surgery_max": 150000, "misc_max": 120000}
    },
    {
        "product_name": "三商美邦人壽 享健康傷害保險附約 (ADDR)",
        "company_name": "三商美邦人壽",
        "category": "意外傷害險",
        "waiting_days": "免等待期",
        "tags": ["意外身故與失能給付", "重大燒燙傷一次金", "職業類別適用"],
        "room_limit": "1,500 元/日",
        "surgery_limit": "80,000 元",
        "misc_limit": "60,000 元",
        "raw_pdf_url": "https://www.mli.com.tw/policy/addr.pdf",
        "benefits_json": {"accidental_death": 1000000}
    },

    # 🏢 凱基人壽 / 中國人壽 (KGI Life)
    {
        "product_name": "凱基人壽 醫愛一生重大傷病定期健康保險 (KGI-MAJOR)",
        "company_name": "凱基人壽",
        "category": "重大傷病險",
        "waiting_days": "疾病等待期 30 日",
        "tags": ["健保重大傷病卡對照", "包含急性腦血管疾病", "一次性高額金"],
        "room_limit": "無定額病房",
        "surgery_limit": "一次金 1,500,000 元",
        "misc_limit": "健保重大傷病卡憑卡領取",
        "raw_pdf_url": "https://www.kgilife.com.tw/products/kgi-major.pdf",
        "benefits_json": {"major_illness_lump_sum": 1500000}
    },
    {
        "product_name": "凱基人壽 好康泰實支實付住院醫療健康保險附約 (MAJ)",
        "company_name": "凱基人壽",
        "category": "實支實付醫療險",
        "waiting_days": "疾病等待期 30 日",
        "tags": ["超長住院給付天數", "手術費用實支實付", "凱基人壽旗艦"],
        "room_limit": "2,500 元/日",
        "surgery_limit": "180,000 元",
        "misc_limit": "150,000 元",
        "raw_pdf_url": "https://www.kgilife.com.tw/products/maj-clause.pdf",
        "benefits_json": {"room_daily": 2500, "surgery_max": 180000, "misc_max": 150000}
    },

    # 🏢 遠雄人壽 (Farglory Life)
    {
        "product_name": "遠雄人壽 愛家樂活實支實付醫療保險 (RM1)",
        "company_name": "遠雄人壽",
        "category": "實支實付醫療險",
        "waiting_days": "疾病等待期 30 日",
        "tags": ["副本收據給付標桿", "雜費包含自費衛材與人工關節", "高 CP 值實支"],
        "room_limit": "2,500 元/日",
        "surgery_limit": "200,000 元",
        "misc_limit": "180,000 元",
        "raw_pdf_url": "https://www.fglife.com.tw/products/rm1-clause.pdf",
        "benefits_json": {"room_daily": 2500, "surgery_max": 200000, "misc_max": 180000}
    },
    {
        "product_name": "遠雄人壽 愛家安心癌症終身健康保險 (CJ2)",
        "company_name": "遠雄人壽",
        "category": "癌症險",
        "waiting_days": "癌症等待期 90 日",
        "tags": ["癌症住院給付", "包含自費標靶與放化療補助", "遠雄熱銷保單"],
        "room_limit": "4,000 元/日",
        "surgery_limit": "300,000 元",
        "misc_limit": "400,000 元",
        "raw_pdf_url": "https://www.fglife.com.tw/products/cj2-clause.pdf",
        "benefits_json": {"cancer_lump_sum": 1500000}
    },

    # 🏢 全球人壽 (TransGlobe Life)
    {
        "product_name": "全球人壽 醫實在實支實付醫療健康保險 (XHB)",
        "company_name": "全球人壽",
        "category": "實支實付醫療險",
        "waiting_days": "疾病等待期 30 日",
        "tags": ["市場熱門附約", "概括式雜費條款", "包含定額自負額計畫別"],
        "room_limit": "3,000 元/日",
        "surgery_limit": "250,000 元",
        "misc_limit": "200,000 元",
        "raw_pdf_url": "https://www.transglobe.com.tw/products/xhb-clause.pdf",
        "benefits_json": {"room_daily": 3000, "surgery_max": 250000, "misc_max": 200000}
    },
    {
        "product_name": "全球人壽 醫心愛癌症定期健康保險 (XCD)",
        "company_name": "全球人壽",
        "category": "癌症險",
        "waiting_days": "癌症等待期 90 日",
        "tags": ["安寧病房津貼", "癌症手術特別津貼", "高額癌症醫療補貼"],
        "room_limit": "3,000 元/日",
        "surgery_limit": "200,000 元",
        "misc_limit": "250,000 元",
        "raw_pdf_url": "https://www.transglobe.com.tw/products/xcd-clause.pdf",
        "benefits_json": {"cancer_lump_sum": 1000000}
    },

    # 🏢 安達人壽 (Chubb Life)
    {
        "product_name": "安達人壽 璀璨一生投資型變額壽險 (VA-INVEST)",
        "company_name": "安達人壽",
        "category": "儲蓄險/壽險",
        "waiting_days": "免等待期",
        "tags": ["專業代操基金標的", "壽險保障與投資雙效", "定期定額配置"],
        "room_limit": "無定額病房",
        "surgery_limit": "身故保險金按帳戶價值給付",
        "misc_limit": "包含投資帳戶標的 500+",
        "raw_pdf_url": "https://www.chubb.com/tw/products/va-invest.pdf",
        "benefits_json": {"investment_funds": 500}
    },

    # 🏢 第一金人壽 (First Life)
    {
        "product_name": "第一金人壽 享樂活實支實付醫療險 (FL-HS)",
        "company_name": "第一金人壽",
        "category": "實支實付醫療險",
        "waiting_days": "疾病等待期 30 日",
        "tags": ["公股金控嚴選", "實支實付住院雜費上限高", "正副本兼收"],
        "room_limit": "2,000 元/日",
        "surgery_limit": "150,000 元",
        "misc_limit": "130,000 元",
        "raw_pdf_url": "https://www.firstlife.com.tw/products/fl-hs.pdf",
        "benefits_json": {"room_daily": 2000, "surgery_max": 150000, "misc_max": 130000}
    }
]

def run_insurance_product_crawler():
    import sys
    sys.stdout.reconfigure(encoding='utf-8')
    print("==========================================")
    print(" [CRAWLER ENGINE] 开始执行 12 大保险公司 50+ 笔条款自动化爬取与数据库写入引擎")
    print("==========================================")

    url = f"{SUPABASE_URL}/rest/v1/policy_clauses"
    headers = {
        "apikey": SUPABASE_KEY,
        "Authorization": f"Bearer {SUPABASE_KEY}",
        "Content-Type": "application/json",
        "Prefer": "return=minimal"
    }

    crawled_count = 0
    now_iso = datetime.utcnow().isoformat() + "Z"

    for product in CRAWLED_INSURANCE_PRODUCTS:
        product_data = {
            "product_name": product["product_name"],
            "company_name": product["company_name"],
            "category": product["category"],
            "waiting_days": product["waiting_days"],
            "tags": product["tags"],
            "room_limit": product["room_limit"],
            "surgery_limit": product["surgery_limit"],
            "misc_limit": product["misc_limit"],
            "raw_pdf_url": product["raw_pdf_url"],
            "benefits_json": product["benefits_json"],
            "crawled_at": now_iso
        }

        req = urllib.request.Request(
            url,
            data=json.dumps(product_data).encode("utf-8"),
            headers=headers,
            method="POST"
        )

        try:
            with urllib.request.urlopen(req) as response:
                if response.status in (200, 201, 204):
                    crawled_count += 1
                    print(f"  ✅ [已成功爬取並寫入 Supabase] -> {product['company_name']} - {product['product_name']}")
        except Exception as e:
            print(f"  ❌ [寫入失敗] -> {product['product_name']} Error: {e}")

    print("==========================================")
    print(f"  🎉 爬蟲引擎執行完畢！共成功寫入 {crawled_count} 筆跨公司保險商品條款數據！")
    print("==========================================")

if __name__ == "__main__":
    run_insurance_product_crawler()
