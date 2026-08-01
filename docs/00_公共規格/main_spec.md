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

## 🔒 安全與金鑰管理規範
- 所有 API 金鑰（`SUPABASE_URL`、`SUPABASE_ANON_KEY`、`GEMINI_API_KEY`）**絕對禁止**明文寫入程式碼。
- 本地開發使用 `.env`（被 `.gitignore` 排除），並由團隊於 Line 記事本安全範本集中維護；正式部署由 GitHub Secrets 動態注入。
