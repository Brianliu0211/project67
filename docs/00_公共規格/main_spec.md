# 保險客戶管理小工具 (insurance_helper) 主系統規格書

本文件為 `insurance_helper` 專案之核心系統規格說明書。所有開發人員與 AI Agent 在編寫、重構或設計主程式時，必須以本規格書為**最高架構藍圖依據**。本文件透過快捷指令 `「對齊」` 按需與最新的程式碼及資料庫 Schema 保持同步。

---

## 🎯 專案願景與核心價值
專為保險從業人員設計的客戶關係管理 (CRM) 響應式 Web / 行動應用程式。透過**語音輸入**與 **Gemini AI 語意分析**，簡化業務員拜訪客戶後的備註紀錄工作，自動提取關鍵資訊、分類標籤並智慧排程跟進提醒，極大化日常客情維護的效率。

---

## 🏗️ 系統架構與技術棧

- **前端框架 (Frontend)**: Flutter (Dart) - 支援 Web / Mobile 響應式 (RWD) 版面
- **狀態管理與偏好 (State & Preferences)**: SharedPreferences & Supabase User Metadata 雙軌持久化
- **多國語系 (i18n)**: `flutter_localizations` & `intl` (支援繁體中文與英文切換)
- **後端服務 (Backend)**: Supabase
  - **資料庫 (Database)**: PostgreSQL (全表啟用 Row Level Security, RLS)
  - **驗證 (Authentication)**: Supabase Auth (支援 Email/Password, Google OAuth 第三方登入)
  - **定時任務 (Cron)**: Supabase `pg_cron` 處理垃圾桶 30 天自動永久清理
  - **儲存空間 (Storage)**: `customer-photos` / `avatars` Bucket 用於客戶照片與大頭貼上傳
- **AI 引擎 (AI Engine)**: Gemini API (語音轉文字、語意分析、需求提取與標籤自動對齊)

---

## 🗄️ 資料庫設計 (Supabase Schema)

所有資料表皆已啟用 **Row Level Security (RLS)**，存取權限嚴格綁定業務員之 `auth.uid()`。

### 1. 使用者個人檔案表 (`public.profiles`)
- **用途**: 儲存業務員（App 使用者）的基本資訊，與 `auth.users` 進行 1-to-1 串接。
- **關鍵欄位**: `id` (UUID, 參考 `auth.users`), `email`, `full_name`, `avatar_url`, `updated_at`。
- **觸發器**: 當 `auth.users` 新增帳號時自動建立 Profile。

### 2. 客戶資料表 (`public.customers`)
- **用途**: 儲存業務員所擁有的客戶基本檔案（支援名片化 3D 翻轉與詳情檢視）。
- **關鍵欄位**:
  - `id` (UUID, 主鍵)
  - `profile_id` (UUID, 參考 `profiles.id`)
  - `name` (TEXT, 必填), `nickname` (TEXT), `phone` (TEXT), `email` (TEXT)
  - `avatar_url` (TEXT, 客戶大頭貼照片 URL)
  - `notes` (TEXT, 滾動備註)
  - `deleted_at` (TIMESTAMPTZ, 可為空): **軟刪除標記**。非空表示位於垃圾桶中。
  - `created_at` / `updated_at` (TIMESTAMPTZ)
- **RLS 策略**: `auth.uid() = profile_id`。

### 3. 專屬行程排程表 (`public.schedule_events`)
- **用途**: 提供首頁行事曆「月網格」與「日時間軸 (Side-by-Side 重疊並排演算法)」之行程管理。
- **關鍵欄位**:
  - `id` (UUID, 主鍵)
  - `profile_id` (UUID, 參考 `profiles.id`)
  - `title` (TEXT, 行程標題), `description` (TEXT, 行程說明)
  - `event_date` (DATE), `start_time` (TIME), `end_time` (TIME)
  - `location` (TEXT), `event_type` (TEXT: 會議談判/客戶拜訪/提醒/個人行程)
  - `is_all_day` (BOOLEAN)
  - `created_at` / `updated_at` (TIMESTAMPTZ)

### 4. 專案拜訪清單表 (`public.visit_projects` & `public.visit_project_customers`)
- **用途**: 記錄拜訪目的 (Why) 與可勾選之客戶拜訪 Checklist。
- **關鍵欄位**: `project_name`, `purpose`, `status`, `target_customer_ids`。

### 5. 標籤三層結構關聯表 (`public.tag_categories`, `public.tags`, `public.customer_tags`)
- **用途**: 支援大分類（例如：意願度、險種需求）與 HSL 質感顏色渲染之客戶標籤關聯表。

### 6. 提醒與紀錄表 (`public.reminders`)
- **用途**: 儲存語音錄音轉錄文字與 Gemini 結構化分析摘要。

### 7. 保險新聞與主題聚類表 (`public.insurance_news_topics` & `public.insurance_news_articles`)
- **用途**: 提供 Phase 7 每日產業頭條與 Google News 風格主題聚類新聞系統。
- **關鍵欄位**:
  - `insurance_news_topics`: `id`, `topic_title`, `daily_trend` (總體趨勢), `daily_overview` (綜合文章), `published_at`
  - `insurance_news_articles`: `id`, `topic_id`, `article_title`, `source_name`, `article_url`, `article_summary`
- **RLS 策略**: `public` 唯讀，僅由 `service_role` Edge Function 進行定時寫入與更新。

---

## 🧱 專案五大核心功能模組 (5 Core Modules Architecture)

主系統功能劃分為五大模組，所有開發人員與 AI 助理於撰寫新程式碼時，**必須依此邊界維護與對齊**：

### 1. 模組一：身分驗證、帳號連線與安全管理 (Auth, Accounts & Security)
- **範圍**: Supabase Auth 登入/註冊、Email 轉址驗證修復 (`emailRedirectTo: redirectTo`)、忘記密碼、個人檔案管理、開發者 RBAC 角色 (`admin` / `dev` / `agent`) 與第三方連線 (Google OAuth / LINE Login)。
- ** UI 排版**: 側邊欄將「個人帳號 👤」置於頂點快捷區，管理性質之「垃圾桶 🗑️」獨立放置於底欄。
- **🎮 遊戲化登入成就與新手指引**:
  - 於用戶『首次註冊登入成功』與『完成新手教學』雙階段，觸發全螢幕解鎖成就卡片：包含兩側 `confetti` 彩帶噴發與 360 度 3D 徽章旋轉彈出。
  - 自動讀取/寫入 `is_first_login` 標記，老用戶登入時自動順暢跳過直接進入系統首頁。

### 2. 模組二：客戶資產與名片庫 (Customers & CRM)
- **範圍**: 客戶 3D 翻轉卡片、綽號與照片上傳、詳情檢視彈窗、拜訪專案 Checklist、客戶批次匯入/匯出 (vCard/.vcf) 與數位名片 Master Studio。

### 3. 模組三：語音助理與 AI 語意分析 (Voice & Gemini AI)
- **範圍**: 語音轉錄 (`visit_logs`)、Gemini 需求提取、`voice-scheduler` Edge Function (Groq Whisper + Llama 3.3 70B 語音排程與三燈分流)，以及 **Make.com + LINE 官方帳號 (音雪倫斯．艾希斯坦 / 🥕 AI 客服) 雙軌自動化客服**。

### 4. 模組四：排程、日曆與戰情中樞 (Calendar & Operations)
- **範圍**: 行事曆「月網格」與「日時間軸 Side-by-Side 重疊並排演算法」雙視圖、`schedule_events` 表，以及 **「保經/業務員客戶線上預約系統」** (空閒時段開放、行程自動遮蔽、CRM 客戶掛載、多公司保單健診/理賠諮詢/新保單規劃預約分類與團隊派單)。

### 5. 模組五：系統個性化、情報與多國語系 (Preferences, i18n & Insights)
- **範圍**: 系統主題色與檢視模式設定、全站 i18n 語系檔 (`app_zh.arb` / `app_en.arb`) 徹底對齊、動態標籤管理器與 16 色選擇器、Phase 7 保險新聞主題聚類，以及 **設定頁面「章節式新手導覽」控制器**（支援重新播放完整教學、按章節分區選看重播與隨時跳過功能）。

---

## 🤖 AI 語意與自動化客服服務 (AI Engine & Microservices)

### 1. 核心 AI 引擎與語音服務
- **Gemini API**: 客戶備註語義萃取、需求提取與標籤自動對齊。
- **Groq Llama 3.3 70B & Whisper STT**: 
  - 語音行程排程 (`voice-scheduler` Edge Function): 實現語音轉文字、客戶稱謂去除與三燈防呆機制。
  - 新聞主題聚類 (`fetch-insurance-news` Edge Function): 兩階段 AI 聚類與 2~3 句重點摘要。

### 2. LINE 官方帳號與 Make.com AI 客服系統
- **官方帳號角色**: 「音雪倫斯．艾希斯坦」 / 🥕 AI 客服。
- **雙軌路由分流機制 (Hybrid AI Router)**:
  - **1st 支線 (固定選單秒回線)**: 點擊「新手教學」繞過 AI Agent，0.1~0.4 秒極速秒回 (0 Token 消耗)。
  - **2nd 支線 (AI 大腦思考線)**: 自然語言問答由 Make AI Agent 思考與檢索。
- **即時體驗與防護**:
  - **LINE 打字中動畫 API**: 調用 `POST https://api.line.me/v2/bot/chat/loading`，消解 2 秒思考焦慮。
  - **Error Handler 與 Gmail 警報**: 點數用盡時觸發溫馨備援訊息，並自動寄送 HTML 警報信至 `brain2013bb@gmail.com`。
- **圖文選單 (Rich Menu 4格版型)**: 整合帳號註冊、新手教學、Google 意見回饋表單與專人客服寫入。
- **🛡️ 維運防護與 4 大錯誤診斷矩陣 (Observability & Fortification SOP)**:
  - **Scenario 防護設定**: ⚙️ Scenario settings 將 `Store incomplete executions` 切換為 `Yes`，防止偶發錯誤導致 Scenario 被自動切換為 Active: OFF。
  - **雙重告警機制 (Dual Alert System)**: 第一重 Make 系統自動寄發停用/額度信件；第二重 Make AI Agent Error Handler 後端掛載 Gmail 模組 0.1 秒發送 `⚠️ [系統警報]` 至 `brain2013bb@gmail.com`。
  - **4 大系統錯誤診斷矩陣**:
    - **【類別 1】Scenario 遭自動停用**: 模組未捕捉連續錯誤（已讀不回）➔ Make 發送信件 ➔ 登入 Make 重開 Active 並檢視 History 補齊 Filter。
    - **【類別 2】Make Operations 額度耗盡**: 每月 1,000 次用罄 ➔ 收到 quota reached 警報 ➔ 匯出 Scenario JSON 至備用帳號或升級。
    - **【類別 3】AI Agent 點數/模型報錯**: OpenAI 餘額不足/逾時 ➔ 用戶收到備援回覆，開發者收到 Gmail HTML 警報 ➔ 補充點數或調整 Prompt。
    - **【類別 4】LINE API 憑證失效**: Channel Access Token 過期 (401 Unauthorized) ➔ History 顯示紅色 401 標籤 ➔ 至 LINE Developers 重新發行 Token 並更新 Connection。

---

## ⏱️ 定時排程與 Edge Functions

- **`voice-scheduler` (Edge Function)**: 處理全螢幕磨砂玻璃 UI 傳送之語音音訊，回傳 JSON 與三燈號 (`status` / `warning_messages`)。
- **`fetch-insurance-news` (Edge Function)**: 聚合 Google News 及 7 大保險 RSS，執行 Groq AI 摘要並寫入資料庫。
- **`daily-news.yml` (GitHub Actions)**: 定時 Cron 排程（台灣時間 06:00 與 18:00 一日兩更）自動觸發 `fetch-insurance-news`。
- **`pg_cron` (Supabase Cron)**: 每日自動實體刪除逾 30 天之垃圾桶軟刪除紀錄 (`deleted_at`)。

---

## 🗑️ 資料垃圾桶與 30 天自動清理機制
- **軟刪除控制**: 刪除客戶時將 `deleted_at` 設定為當前時間，資料移至「垃圾桶頁面」，支援復原與手動徹底刪除。
- **自動清理 (pg_cron)**: 資料庫後端建立 `pg_cron` 定時任務，每日自動對 `deleted_at < NOW() - INTERVAL '30 days'` 之紀錄進行實體刪除。

---

## 🎨 全局 UI Toast 提示規範 (CustomToast)

專案內所有模組的操作回饋與狀態提示，**必須統一調用 [lib/widgets/custom_toast.dart](../../lib/widgets/custom_toast.dart) 的 `CustomToast.show()` 靜態方法**。

- 🟢 **`ToastType.success` (成功 - 青綠色 `0xFF00ADB5`)**: 新增/編輯/儲存成功。
- 🟡 **`ToastType.warning` (警告 - 琥珀黃色 `Colors.amber`)**: 時間防呆、刪除項目、欄位缺漏。
- 🔴 **`ToastType.error` (錯誤 - 霓虹紅 `Colors.redAccent`)**: 網路斷線、資料庫寫入失敗、權限不足。

---

## 📐 全局 UI/UX 視覺與對話框組件設計規範 (UI Design System)

為避免隨開發時間推移導致全站 UI 視覺割裂，所有模組（客戶管理、行事曆排程、拜訪專案、標籤管理器等）的對話框 (Dialog)、輸入框 (TextField) 與按鈕，**必須嚴格遵循以下新版 UI 視覺標準**：

### 1. 彈窗與卡片容器 (Modal & Card Container)
- **彈窗圓角 (Modal Radius)**: 統一使用 `BorderRadius.circular(20)`。
- **內嵌卡片圓角 (Card Radius)**: 統一使用 `BorderRadius.circular(16)` 或 `BorderRadius.circular(12)`。
- **彈窗頂欄 (Modal Header)**:
  - 左側：`Icon` 圖示 + `fontSize: 18, fontWeight: FontWeight.bold` 主標題。
  - 右側：置入 `IconButton(icon: Icon(Icons.close))` 顯性關閉按鈕。
- **主題顏色適配 (Theme Adaptation)**:
  - 淺色模式：卡片背景 `Color(0xFFF8FAFC)`，邊框 `Color(0xFFE2E8F0)`。
  - 深色模式：卡片背景 `Color(0xFF1E293B)`，邊框 `Color(0xFF334155)`。

### 2. 表單輸入框 (Input Field Design)
- **統一外觀 (Border & Icon)**:
  - 全站放棄傳統 Material 外突刻痕舊框線，統一使用 **現代圓角外框 (`BorderRadius.circular(12)`)**。
  - 每個輸入框皆需配置前綴 Icon 引導（如：`Icons.person_outline`、`Icons.calendar_today`）。
  - Focus 時高亮為品牌主色 (`0xFF10B981` / `0xFF0369A1`)，邊框加寬至 `1.5 - 2.0`。
- **行動版 RWD 與 Web App 防護**: 窄螢幕 (`< 600px`) 下輸入框與內距調整，全站頁面必須包覆 `SafeArea` 防止 Web App 手機瀏覽器上方網址列與下方導覽列裁切。

### 3. 按鈕視覺階層 (Action Button Hierarchy)
- **主要動作按鈕 (Primary Action Button - 儲存/新增/確定)**:
  - 使用填色膠囊/圓角按鈕 (`ElevatedButton` / `Container`)。
  - 背景：`0xFF10B981` (綠色系) 或 `0xFF0369A1` (天藍色系)。
  - 文字：純白粗體 (`Colors.white, fontWeight: FontWeight.bold`)。
- **次要動作按鈕 (Secondary Action Button - 取消/返回)**:
  - 使用灰色/無邊框純文字按鈕 (`TextButton`)，呈現清晰的主次視覺對比。

### 4. 標籤選擇器 (Categorized Tag Selector)
- **全站統一組件**: 任何需要標籤維護與點選的模組，**必須 100% 調用 [`CategorizedTagAccordionSelector`](../../lib/widgets/categorized_tag_accordion_selector.dart)**。
- 嚴禁使用傳統單行純文字輸入框或自訂逗號分隔字串。

### 5. 行動端 RWD 響應式跑板優化與防溢出規範 (Mobile Responsive Standard) 🔥
- **全站元件嚴禁跑板 (Zero Yellow Overflow)**：全站所有卡片、彈窗、表單與視圖在窄螢幕（手機寬度 `< 600px`）下，**嚴禁出現黃黑色條紋溢出警告 (Yellow Overflow Striped Bar)**。
- **邊距與字體自適應**：手機端卡片 padding 應由 24px 自動微調為 12~16px，文字標題過長時強制套用 `TextOverflow.ellipsis` 或包裹 `FittedBox` / `Flexible`。
- **可滾動容器防護**：彈窗與對話框主體必須包裹 `SingleChildScrollView` 或 `ListView`，確保在手機彈出軟鍵盤時畫面可平滑滾動，防止輸入框被軟鍵盤遮擋或壓迫溢出。

---

## 🔒 安全與金鑰管理規範
- 所有 API 金鑰（`SUPABASE_URL`、`SUPABASE_ANON_KEY`、`GEMINI_API_KEY`）**絕對禁止**明文寫入程式碼。
- 本地開發使用 `.env`（被 `.gitignore` 排除），並由團隊於 Line 記事本安全範本集中維護；正式部署由 GitHub Secrets 動態注入。

---

## 🛠️ 開發協作與 AI 快捷指令體系 (Developer Automation & Shortcuts)

為確保開發品質、團隊防呆與維運規範，全專案定義 8 大 AI 快捷指令，由 [`.agents/AGENTS.md`](../../.agents/AGENTS.md) 作為實體運作條文驅動，並與 [`開發人員快捷指令.md`](開發人員快捷指令.md) 保持 Type A 雙向自動對齊：

1. **`開工`**：實施 Git 狀態檢查、確認身分 (lobo / beast)、巡檢靈感、讀取 `進度.md` 任務並執行 **4 階段大任務微型拆解協定**，給予特徵分支建議。
2. **`收工`**：執行 **Quality Gate 4 項品質稽核**，自動建立帶有 `[Handoff 狀態條言]` 之開發日誌與更新 `進度.md`，並執行**智慧 Git 提交分流**：
   - 🟢 **純文件修訂 (Fast-Track 快速通道)**：100% 僅包含 `docs/` 或 `.md` 時，**目標分支一律鎖定為 `main`**，直接在 `main` 分支提交並推送至遠端（免發起 PR）。
   - 🔴 **程式碼修訂 (Standard PR 流程)**：包含 `lib/` 或程式碼變更時，強制位於特徵分支 `feature/username-featurename` 並提供 PR 合併指引。
3. **`精簡模式` / `詳細模式`**：切換對話風格。精簡模式下使用 Caveman 極簡高密度技術語言，去客套直奔關鍵與代碼，極致節省 Token 消耗與對話資源。
4. **`讓我看看`**：自動在背景啟動 Flutter Web 預覽伺服器並提供 [http://localhost:8080](http://localhost:8080) 測試連結。
5. **`確認狀況`**：啟動安全凍結狀態，只讀不寫，列出目前修改檔案、脈絡與預期變化。
6. **`對齊`**：對比現有程式碼、Supabase Schema 與 `進度.md`，自動將最新資料表與系統規範補全至本主規格書 (`main_spec.md`)。
7. **`book`**：渲染 Mermaid 視覺化全專案文檔關係地圖與說明 4 種連動型態。
8. **`自我修復`**：當發現 AI 行為瑕疵、邏輯死角或與原本系統設計違背時觸發。AI 將自動進行「根因剖析 ➔ 修訂 `.agents/AGENTS.md` 條文 ➔ 全套連動更新 `開發人員快捷指令.md` / `main_spec.md` / `進度.md` ➔ 報告修復結果與全新防呆邏輯」。
