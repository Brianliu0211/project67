# 保險客戶管理小工具 (insurance_helper)

這是一款專為保險從業人員設計的客戶管理（CRM）行動應用程式，旨在透過語音輸入與 AI 語意分析，極大化日常客戶維護與跟進的工作效率。

---

## 🎯 專案願景與核心功能

### 1. 客戶檔案建立與管理 (Customer Profile)
- 提供結構化的客戶基本資訊建立（姓名、聯絡資訊、生日、保單狀況等）。
- 支援靈活的「標籤系統」（如：高意願、已簽單、意外險需求）與「客戶分組」，方便快速篩選與歸類。

### 2. 語音輸入備註與 AI 語意分析 (Voice-to-Text & AI Analysis)
- 業務員在拜訪完客戶後，可直接透過語音錄製備註。
- 整合 **Gemini API** 進行語意分析：
  - 自動轉錄為文字。
  - 自動提取關鍵資訊（例如：家庭成員近況、關心的話題、痛點等）。
  - 自動產生摘要，存入該客戶的互動紀錄中。

### 3. AI 時效性排程與跟進提醒 (AI-Driven Scheduling & Reminders)
- AI 自動偵測備註中的時效性關鍵字（如：「下週三下午兩點約見面」、「三個月後續約」）。
- 自動建立日曆行程並串接推送提醒，確保不會遺漏任何跟進時機。

---

## 🚀 改用 Supabase (PostgreSQL) 的架構優勢

專案後端與資料庫已由 Firebase 遷移至 **Supabase**，主要考量關聯式資料庫 (PostgreSQL) 對此應用程式帶來的以下優勢：

1. **強固的關聯性數據模型**：
   保險客管系統（如：業務員對應多個客戶、客戶對應多個互動紀錄與提醒事項）天生非常適合關聯式模型（Relational Model）。PostgreSQL 提供的「外鍵約束 (Foreign Key Constraints)」與「級聯刪除 (Cascading)」能確保資料完整性，避免產生孤立的提醒或客戶紀錄。
2. **強大的 Row Level Security (RLS)**：
   利用 PostgreSQL 的 RLS 整合 Supabase Auth，可以直接在資料庫層級利用 `auth.uid()` 進行行級安全過濾。這確保了不同保險業務員之間的資料絕對隔離，安全性控制精準且高效。
3. **原生支援 Array 與 JSONB 欄位**：
   PostgreSQL 支援 `text[]` (陣列) 與 `jsonb` (JSON 格式) 欄位，這使得存取客戶「標籤系統 (Tags)」或未來 Gemini API 輸出的「非結構化 JSON 分析資料」變得非常直覺且易於查詢。
4. **開放標準與免鎖定 (Lock-in Free)**：
   Supabase 底層是標準的 PostgreSQL，未來專案若需要轉移或進行複雜的 SQL 分析、報表產出，都不會受到專有技術的平台限制限制。

---

## 💻 技術棧 (Technology Stack)

- **前端框架 (Frontend)**: Flutter (Dart)
- **後端與資料庫 (Backend & DB)**: Supabase (PostgreSQL)
  - **驗證 (Authentication)**: Supabase Auth (Email/Password, Magic Link, OAuth)
  - **即時資料同步 (Realtime)**: Supabase Realtime (Postgres Changes)
  - **儲存空間 (Storage)**: Supabase Storage (儲存語音備註錄音檔)
- **人工智慧 (AI Engine)**: Gemini API (整合語意理解與摘要提取)

---

## 📖 專案進度與規格書 (Source of Truth)

> [!NOTE]
> 本區塊為專案的唯一真理來源 (Source of Truth)，用於開發人員與 AI Agent 協作時同步專案狀態、規格與約定。

### 📅 開發里程碑 (Milestones)
- [x] **Phase 0: 專案基礎建設初始化** (Flutter 建立, Git ignore, README 配置)
- [x] **Phase 0.5: 後端架構遷移** (從 Firebase 移轉至 Supabase, 設計 SQL Schema & RLS)
- [ ] **Phase 1: 客戶基本資料庫與 UI 刻劃** (Supabase 整合, 客戶卡片, 基本欄位 CRUD)
- [ ] **Phase 2: Supabase Auth 登入系統** (使用者註冊、登入與會話保存)
- [ ] **Phase 3: 語音錄音與文字轉錄** (語音輸入與基本備註儲存)
- [ ] **Phase 4: Gemini API 語意分析核心** (關鍵字提取、重點摘要、時間分析)
- [ ] **Phase 5: 排程與提醒推播** (本地/系統日曆串接與通知)

### 🗄️ Supabase 資料結構與 RLS 規範
- 詳細定義檔案參見：[`supabase_schema.sql`](file:///c:/Users/haolu/OneDrive/%E6%96%87%E4%BB%B6/GitHub/project67/supabase_schema.sql)
- 所有資料表皆啟用 `Row Level Security (RLS)`。
- 資料存取權嚴格綁定業務員的 `auth.uid()`，禁止任何跨用戶的未授權查詢。

### 🔌 API 與敏感資訊管理規範
- 所有敏感金鑰（如 Supabase URL, Anon Key, Gemini API Key）**嚴禁**提交至 Git 倉庫。
- 使用 `flutter_dotenv` 或 Dart 官方定義的 `--dart-define` 載入本地變數。