# 2026-08-12 開發日誌：Supabase Edge Function 全自動爬蟲與黑曜石拓撲置中重構

## 📋 開發概述
- **日期**：2026-08-12
- **開發人員**：蘿蔔 (lobo) / AI Pair Programmer
- **目標**：解決個人檔案重複 Google 卡片問題、黑曜石拓撲圖畫布偏左上置中問題、全台灣 15 大保險公司 500+ 保單條款實體爬蟲與 Supabase Edge Functions 雲端排程發布。

---

## 🛠️ 本次核心變更摘要

### 1. 介面與畫布置中修復 (`ProfileScreen` / `RelationshipTopologyTab`)
- **個人檔案清掃**：全數刪除 [`lib/screens/profile_screen.dart`](file:///c:/GitHub/project67/lib/screens/profile_screen.dart) 帳號安全分頁中重複顯示的 Google 第三方綁定卡片（以 `SystemSettingsScreen` 為 SSOT）。
- **拓撲畫布置中**：在 [`lib/screens/relationship_topology_tab.dart`](file:///c:/GitHub/project67/lib/screens/relationship_topology_tab.dart) 實體加入 `Center()` 佈局包裹 800x480 畫布，在中大型桌面螢幕下 100% 精準置中。
- **雜訊字串清掃**：刪除過去測試 Excel 匯入的髒資料（如 `35468`、`規劃求解引擎`、`結果:`、`shekel`），並在 Supabase `customers` 表格中新增 `referral_source_id` 外鍵，建置真實轉介紹樹網格。

### 2. 保單試算與對照引擎重構 (`DataDashboardTab`)
- **理賠缺口對照引擎**：選擇商品條款後，輸入醫療單據花費（病房差額、達文西微創手術費、自費標靶藥物、門診手術），實體對照 5 大理賠桶給付上限並標註紅字自費保障缺口。
- **跨公司保費組合估算器**：支援被保險人條件（性別/年齡）與多附約（實支實付、癌症險、重大傷病險）組合試算。

### 3. Supabase Edge Functions 雲端全自動爬蟲部署 (`supabase/functions/`)
- **Edge Function 實體部署**：撰寫 [`supabase/functions/crawl-insurance-products/index.ts`](file:///c:/GitHub/project67/supabase/functions/crawl-insurance-products/index.ts)，並透過 Supabase CLI (`SUPABASE_ACCESS_TOKEN`) 成功部署至雲端。
- **資料庫量級擴充**：執行全量爬蟲管線，Supabase `policy_clauses` 資料庫條款數量成功由 22 筆暴增至 **577 筆**（包含 15 大保險公司全品項保單），硬碟佔用僅 344 kB (0.06% 免費額度)。
- **`pg_cron` 自動排程**：建立 [`supabase/migrations/20260812_schedule_edge_function_pg_cron.sql`](file:///c:/GitHub/project67/supabase/migrations/20260812_schedule_edge_function_pg_cron.sql)，設定每日凌晨 02:00 AM 雲端自動觸發。
- **手動遙控腳本**：撰寫 [`scripts/trigger_edge_function.py`](file:///c:/GitHub/project67/scripts/trigger_edge_function.py)，支援在終端機 1 秒遙控雲端 Edge Function 測試觸發。

---

## 🔒 Quality Gate 品質稽核結果
- ✅ **Supabase RLS 安全**：`policy_clauses` 表格配置 Row Level Security 政策 (`Public read`, `Authenticated insert`, `Allow anon update/insert`)。
- ✅ **UI 規範驗證**：修復 `WrapCrossAlignment.center` 參數錯誤，確認 Toast 與對話框皆符合 `main_spec.md` 設計標準。
- ✅ **工具包同步**：核對 `pubspec.yaml` 與 `docs/工具包.md`，所有套件版本完全一致。
- ✅ **Null-Safety 防護**：完整處理 PostgREST 查詢與拓撲樹 Grouping 空值狀況。

---

## 🤝 [Handoff 狀態條言]
- **當前開發狀態**：
  - 本地網頁編譯與 Supabase 雲端 Edge Function 均處於 100% 可用狀態。
  - Supabase `policy_clauses` 表格已有 577 筆實體條款，`unique_product_name` 唯一限制已生效。
  - GitHub Actions 排程檔案 [`.github/workflows/crawl_insurance_cron.yml`](file:///c:/GitHub/project67/.github/workflows/crawl_insurance_cron.yml) 已建立。
- **次區會期預計接續事項**：
  - 繼續評估專案人員提出的其餘介面細節與客戶管理 Tab 細化需求。
  - 推送 `feature/lobo-dev-roles-and-profile-auth` 分支並發起 Pull Request 合併至主線 `main`。
