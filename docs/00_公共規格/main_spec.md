# 保險客戶管理小工具 (insurance_helper) 主系統規格書

本文件為 `insurance_helper` 專案之核心系統規格說明書。所有開發人員與 AI Agent (如 Antigravity) 在編寫、重構或設計主程式時，必須以本規格書為**唯一且最高參考依據**。

---

## 🎯 專案願景與核心價值
專為保險從業人員設計的客戶關係管理 (CRM) 行動應用程式。透過**語音輸入**與 **AI 語意分析**，簡化業務員拜訪客戶後的備註紀錄工作，自動提取關鍵資訊並智慧排程跟進提醒，極大化日常客情維護的效率。

---

## 🏗️ 系統架構與技術棧

- **前端框架 (Frontend)**: Flutter (Dart)
- **後端服務 (Backend)**: Supabase
  - **資料庫 (Database)**: PostgreSQL (啟用 Row Level Security, RLS)
  - **驗證 (Authentication)**: Supabase Auth (支援 Email/Password, Magic Link 等)
  - **即時通訊 (Realtime)**: PostgreSQL Changes 監聽
  - **儲存空間 (Storage)**: 用於存放語音備註之錄音檔 (.m4a/.mp3)
- **AI 引擎 (AI Engine)**: Gemini API (負責語音轉文字、語意分析、資訊提取、自動生成摘要及時效性提醒偵測)

---

## 🗄️ 資料庫設計 (Supabase Schema)

資料庫採用關聯式設計，以確保資料完整性與強大的安全性隔離。所有資料表皆已啟用 **Row Level Security (RLS)**，存取權限嚴格綁定業務員之 `auth.uid()`。

### 1. 使用者個人檔案表 (`public.profiles`)
- **用途**: 儲存業務員（App 使用者）的基本資訊，與 Supabase Auth 的 `auth.users` 進行 1-to-1 串接。
- **欄位說明**:
  - `id` (UUID, 主鍵): 參考 `auth.users(id)`，串接 `ON DELETE CASCADE`。
  - `email` (TEXT, 唯一): 業務員電子信箱。
  - `full_name` (TEXT): 業務員姓名。
  - `updated_at` (TIMESTAMPTZ): 最後更新時間。
- **觸發器 (Trigger)**: 當 `auth.users` 新增帳號時，自動透過觸發器建立對應的 profile 紀錄。

### 2. 客戶資料表 (`public.customers`)
- **用途**: 儲存業務員所擁有的客戶基本檔案。
- **欄位說明**:
  - `id` (UUID, 主鍵): 自動產生 UUID。
  - `profile_id` (UUID): 參考 `public.profiles(id)`，串接 `ON DELETE CASCADE`。
  - `name` (TEXT, 必填): 客戶姓名。
  - `phone` (TEXT): 客戶電話。
  - `email` (TEXT): 客戶電子信箱。
  - `tags` (TEXT[], 預設空陣列): 客戶標籤系統 (例如：`{"高意願", "意外險需求"}`)。
  - `notes` (TEXT): 備註。
  - `created_at` / `updated_at` (TIMESTAMPTZ): 建立與更新時間。
- **RLS 策略**: `auth.uid() = profile_id`。業務員僅能對自己名下的客戶進行 CRUD。

### 3. 提醒與紀錄表 (`public.reminders`)
- **用途**: 儲存業務員對客戶的語音錄音轉錄文字、AI 摘要，以及未來要跟進的提醒時間。
- **欄位說明**:
  - `id` (UUID, 主鍵): 自動產生 UUID。
  - `customer_id` (UUID): 參考 `public.customers(id)`，串接 `ON DELETE CASCADE`。
  - `raw_transcript` (TEXT): 語音轉錄的原始文字。
  - `ai_summary` (TEXT): Gemini 處理後的客戶需求與對話摘要。
  - `remind_at` (TIMESTAMPTZ, 可為空): AI 辨識出的提醒跟進時間（例如下次拜訪日）。
  - `is_completed` (BOOLEAN, 預設 false): 提醒事項是否已完成。
  - `created_at` / `updated_at` (TIMESTAMPTZ): 建立與更新時間。
- **RLS 策略**: 透過子查詢確保只有該客戶所屬的業務員 (`auth.uid()`) 才能存取對應的提醒紀錄。

---

## 🎙️ AI 核心語意分析流程 (Gemini Integration)
1. **錄音輸入**: 業務員在 Flutter App 內錄製語音備註，並上傳至 Supabase Storage，或直接將語音串流/檔案送至轉譯服務。
2. **語意解析**: 將轉錄文字送至 **Gemini API**，進行結構化分析：
   - 提取**痛點與需求**（如：客戶提到最近想買車、考慮給剛出生的寶寶買醫療險）。
   - 提取**時效性跟進指令**（如：「下星期五下午三點打給他」，自動轉換為具體的 ISO 8601 時間格式，存入 `remind_at` 欄位）。
   - 輸出簡短的**摘要**，寫入 `ai_summary`。
3. **日程建立**: App 偵測到有 `remind_at` 時，引導業務員將行程同步至本地日曆，或透過本地通知（Local Notifications）在指定時間進行提醒。

---

## 🔒 安全與金鑰管理規範
- 所有 API 金鑰、Supabase 憑證（`SUPABASE_URL`、`SUPABASE_ANON_KEY`、`GEMINI_API_KEY`）**絕對禁止**以明文形式寫在程式碼中或提交至 Git 倉庫。
- 必須使用 `flutter_dotenv` 或 `--dart-define` 技術在建置階段動態載入環境變數。
