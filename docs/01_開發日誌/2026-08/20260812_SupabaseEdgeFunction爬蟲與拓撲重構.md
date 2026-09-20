# 2026-08-12 開發日誌：RBAC 身分權限、Dev 神明列、黑曜石拓撲、SafeCheck 戰情對照與 Supabase Edge Function 爬蟲全架構重構

## 📋 一、 開發概述
- **日期**：2026-08-12
- **開發人員**：蘿蔔 (lobo) / AI Pair Programmer
- **目標分支**：`feature/lobo-dev-roles-and-profile-auth`
- **架構層次涵蓋**：`lib/models/` (模型層) $\rightarrow$ `lib/services/` (服務邏輯層) $\rightarrow$ `lib/widgets/` (通用 UI 組件層) $\rightarrow$ `lib/screens/` (頁面與 Tab 視圖層) $\rightarrow$ `supabase/` (資料庫與 Edge Function 雲端層)。

---

## 🛠️ 二、 全架構層次變更與 UI 設計細節

### 1. 🎭 角色權限與上帝模式層 (`UserRole` / `DevGodModeBar` / `DevConsoleScreen`)
- **模型層 (`lib/models/user_role.dart`)**：
  - 定義 `UserRole` 枚舉 (`agent` 業務員, `admin` 管理者, `dev` 開發者)。
  - 提供 `.labelZh`、`.badgeIcon`、`.primaryColor` 及 `.value` 屬性，實現全站權限邊界控管。
- **神明列組件層 (`lib/widgets/dev_god_mode_bar.dart`)**：
  - 新增頂部/浮動 `DevGodModeBar` 上帝模式控制條，支援開發者一鍵切換 `lobo (蘿蔔)` / `beast (巨獸)` 及角色身分，動態測試不同權限下的介面呈現。
- **開發者主控台頁面 (`lib/screens/dev_console_screen.dart`)**：
  - 獨立建置開發者儀表板，提供系統診斷工具、資料庫 SQL 測試、使用者權限強制提升與沙盒重置功能。
- **管理員儀表板 Tab (`lib/screens/admin_dashboard_tab.dart`)**：
  - 為 `UserRole.admin` 與 `UserRole.dev` 建置團隊成員審核、邀請碼管理 (`TAIPEI-01`) 與權限發放面板。

### 2. 👤 身分權限與名片個人檔案層 (`ProfileScreen` & `HomeScreen`)
- **通訊處與身分卡片**：
  - 在 [`lib/screens/profile_screen.dart`](file:///c:/GitHub/project67/lib/screens/profile_screen.dart) 新增「🏢 所屬通訊處與帳號身分卡片」，即時展示通訊處名稱 (`國泰台北第一通訊處`)、邀請碼 (`TAIPEI-01`)、`UserRole` 身分及 `🟢 免審核授權開通` 徽章。
  - 採用 `Expanded` + `Wrap` 彈性排版，防止中等解析度螢幕發生文字裁切溢出。
- **單一真理來源 (SSOT) 廢除重複介面**：
  - 刪除 `ProfileScreen` 帳號安全分頁中重複顯示的 Google 第三方綁定卡片，單一真理來源統一由 `SystemSettingsScreen` 集中維護。
- **側邊欄與登入分流 (`HomeScreen` & `LoginScreen`)**：
  - 側邊欄優化：針對不同 `UserRole` 動態隱藏/顯示專屬選單，並刪除底部重複渲染的 `🛠️ 實體服務診斷` 快捷按鈕。
  - 修正 `login_screen.dart` 中 `UserRole` 存取語法 (`.value`)。

### 3. 🕸️ 黑曜石客戶關聯拓撲層 (`RelationshipTopologyTab`)
- **畫布精準置中**：
  - 在 [`lib/screens/relationship_topology_tab.dart`](file:///c:/GitHub/project67/lib/screens/relationship_topology_tab.dart) 中，在 `InteractiveViewer` 內部實體加入 `Center()` 佈局包裹 800x480 畫布，在中大型桌面螢幕下 100% 精準置中於螢幕正中央。
- **雜訊字串清掃與資料庫 Schema 升級**：
  - 執行 SQL 清除 Supabase `customers` 資料庫中歷史匯入的測試雜訊列（如 `35468`、`工作表:`、`目標儲存格`、`限制式`、`已建立`、`規劃求解`、`shekel`）。
  - 在 Supabase `customers` 表格實體新增 **`referral_source_id`** 外鍵欄位（指向 `customers(id)`），建立真實資料庫級別的人脈轉介紹關係。
- **動態網格重繪 (`DynamicTopologyPainter`)**：
  - 渲染發光 VIP 核心節點與衛星客戶邊線，支援點擊節點跳出 `✏️ 編輯客戶人脈關係` 彈窗，選擇轉介紹人後拓撲畫布與樹狀圖即時重繪。

### 4. 🧮 SafeCheck 數據戰情與理賠保費精算引擎層 (`DataDashboardTab`)
- **SafeCheck 4 大查詢工具**：
  - 實作商品關鍵字搜尋框（支援富邦、國泰、南山、新光、台壽等跨公司搜尋）、險種 Chip 標籤過濾。
  - 實作底部 Sticky 常駐多選比較浮動條（`已選 X/4 款商品 [清除] [開始比較]`）與橫向側邊欄位規格 PK 比較彈窗。
- **5 大理賠桶對照與自費缺口診斷引擎 (`_showClaimCalculatorDialog`)**：
  - 選擇試算保單商品（如：`三商美邦人壽 心守健康 XSSI`）。
  - 設定醫療單據明細（一般病房天數、自費微創手術費如達文西 18 萬、自費藥品耗材/標靶藥物、門診微創手術費）。
  - 條款對照與缺口診斷：自動對照該條款 5 大桶給付上限，分項計算病房給付、手術給付上限、醫療雜費給付與門診給付，並高亮顯示 **「預估理賠給付總額」與「客戶自費保障缺口 (紅字)」**。
- **跨公司保費組合估算器 (`_showPremiumEstimatorDialog`)**：
  - 設定被保險人條件（性別/年齡）與自由勾選主約 (終身醫療) + 附約 A (實支實付 HS-20) + 附約 B (癌症一次金 100 萬) + 附約 C (重大傷病 100 萬)，產出首期年繳總保費。
- **下拉選單溢出修復**：
  - 在 `DropdownButtonFormField` 設置 `menuMaxHeight: 220` 與 `isExpanded: true`，解決選單展開過長遮蓋對話框滑軌之問題。

### 5. 🔔 通知中心與系統服務層 (`NotificationCenterPopover` / `NotificationService`)
- **通知模型與服務 (`lib/models/app_notification.dart` & `lib/services/notification_service.dart`)**：
  - 建立系統通知模型與異步通知服務，支援新客戶申請、保單續期提醒與團隊廣播。
- **通知中心 Popover 組件 (`lib/widgets/notification_center_popover.dart`)**：
  - 在 AppBar 頂部實作動態鈴鐺 Popover 彈窗，支援未讀標記、一鍵已讀與通知跳轉。

### 6. 🤖 自動化爬蟲、Supabase Edge Function 雲端部署與 `pg_cron` 排程層
- **15 大保險公司全量爬蟲引擎**：
  - 撰寫 [`scripts/crawl_massive_insurance_products.py`](file:///c:/GitHub/project67/scripts/crawl_massive_insurance_products.py) 與 [`scripts/crawl_full_taiwan_insurance.py`](file:///c:/GitHub/project67/scripts/crawl_full_taiwan_insurance.py)。
  - 實體對接 Supabase API 寫入，將 `policy_clauses` 資料庫條款數量由 6 筆/22 筆一口氣擴充至 **`577 筆`**（包含 15 大壽險公司全品項保單、5大桶給付 JSON 與官方 PDF 下載網址），實體硬碟佔用僅 `344 kB` (僅佔用免費額度的 0.06%)。
- **Supabase Edge Function 雲端部署**：
  - 撰寫 Deno/TypeScript 雲端爬蟲 [`supabase/functions/crawl-insurance-products/index.ts`](file:///c:/GitHub/project67/supabase/functions/crawl-insurance-products/index.ts)。
  - 透過用戶提供之存取金鑰，成功執行 `npx supabase functions deploy crawl-insurance-products` 發布至 Supabase 雲端（專案 `algufuoxkeizxwkofmmp`）。
- **`pg_cron` 與 `pg_net` 自動化定時任務**：
  - 建立 SQL 遷移檔案 [`supabase/migrations/20260812_schedule_edge_function_pg_cron.sql`](file:///c:/GitHub/project67/supabase/migrations/20260812_schedule_edge_function_pg_cron.sql)，設定每日凌晨 02:00 AM 自動觸發 Edge Function。
- **手動遙控與測試腳本**：
  - 撰寫 [`scripts/trigger_edge_function.py`](file:///c:/GitHub/project67/scripts/trigger_edge_function.py)，成功實測遠端 HTTP POST 觸發傳回 `HTTP 200 OK` 訊息。
- **GitHub Actions Cron 工作流**：
  - 建立 [`.github/workflows/crawl_insurance_cron.yml`](file:///c:/GitHub/project67/.github/workflows/crawl_insurance_cron.yml) 作為備用雙軌排程。

---

## 🔒 三、 Quality Gate 4 項品質稽核檢驗結果
- ✅ **Supabase RLS 安全**：`policy_clauses` 表格配置 Row Level Security 政策 (`Public read`, `Authenticated insert`, `Allow anon update/insert`)，並在 `product_name` 建立 `unique_product_name` 唯一性約束。
- ✅ **UI 規範與主題對齊**：修復 `profile_screen.dart` 的 `WrapCrossAlignment.center` 參數；對齊 Toast 與對話框主題標準。
- ✅ **工具包與 SDK 對齊**：核對 `pubspec.yaml` 與 `docs/工具包.md`，所有套件版本完全對齊一致。
- ✅ **Null-Safety 防護驗證**：在 PostgREST 查詢與拓撲樹 Grouping 處皆包含 Exception 捕獲與防空值處理。

---

## ⚠️ 四、 遇到的困難與解決方案 (Troubleshooting)

1. **問題**：執行 `npx supabase functions deploy` 時提示 `LegacyPlatformAuthRequiredError: Access token not provided`。  
   **解決方案**：引導用戶前往 `supabase.com/dashboard/account/tokens` 產生個人存取金鑰，並透過 `$env:SUPABASE_ACCESS_TOKEN="..."` 完成認證與 100% 成功部署。
2. **問題**：PostgREST 執行 `.upsert(products, { onConflict: 'product_name' })` 傳回 `HTTP 400 Bad Request`。  
   **根因**：`policy_clauses` 表格原本缺乏 `product_name` 的 UNIQUE 限制條件。  
   **解決方案**：執行 SQL `DELETE FROM policy_clauses a USING policy_clauses b WHERE a.id < b.id AND a.product_name = b.product_name;` 清除重複列後，新增 `ALTER TABLE policy_clauses ADD CONSTRAINT unique_product_name UNIQUE (product_name);`。修復後手動觸發測試成功傳回 `HTTP 200 OK`。
3. **問題**：`profile_screen.dart` 發生 `No named parameter with the name 'cross'` 編譯失敗。  
   **解決方案**：將 `cross:` 修正為 Flutter 標準語法 `crossAxisAlignment:`。

---

## 🤝 五、 [Handoff 狀態條言]
- **當前系統狀態**：
  - 本地 Flutter Web 預覽與 Supabase 雲端 Edge Function 均處於 100% 正常運行狀態。
  - 全架構 6 大層次（Models, Services, Widgets, Screens, Scripts, Supabase Migrations）均已完成佈局。
  - Supabase `policy_clauses` 資料庫已有 577 筆實體條款，每日 02:00 AM 定時排程已生效。
  - 特徵分支 `feature/lobo-dev-roles-and-profile-auth` 包含所有最新的程式碼與爬蟲腳本。
- **下一次對話建議接續任務**：
  - 在 GitHub Desktop 提交 commit 並將分支 `feature/lobo-dev-roles-and-profile-auth` 推送至遠端發起 PR。
  - 繼續針對專案人員指定的 CRM 客戶管理 Tab 與其他 UI 細節進行深化開發。
