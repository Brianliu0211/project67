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

---

## 🔒 安全與金鑰管理規範
- 所有 API 金鑰（`SUPABASE_URL`、`SUPABASE_ANON_KEY`、`GEMINI_API_KEY`）**絕對禁止**明文寫入程式碼。
- 本地開發使用 `.env`（被 `.gitignore` 排除），並由團隊於 Line 記事本安全範本集中維護；正式部署由 GitHub Secrets 動態注入。
