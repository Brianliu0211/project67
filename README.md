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
- 自動建立日曆行程或本地/雲端推播提醒，確保不會遺漏任何跟進時機。

---

## 💻 技術棧 (Technology Stack)

- **前端框架 (Frontend)**: Flutter (Dart)
- **後端服務 (Backend)**: Firebase
  - **驗證 (Authentication)**: Firebase Authentication (支援 Email/密碼及第三方登入)
  - **資料庫 (Database)**: Cloud Firestore (即時同步文件資料庫)
- **人工智慧 (AI Engine)**: Gemini API (整合語意理解與摘要提取)

---

## 📖 專案進度與規格書 (Source of Truth)

> [!NOTE]
> 本區塊為專案的唯一真理來源 (Source of Truth)，用於開發人員與 AI Agent 協作時同步專案狀態、規格與約定。

### 📅 開發里程碑 (Milestones)
- [x] **Phase 0: 專案基礎建設初始化** (Flutter 建立, Git ignore, README 配置)
- [ ] **Phase 1: 客戶基本資料庫與 UI 刻劃** (Firestore 整合, 客戶卡片, 基本欄位 CRUD)
- [ ] **Phase 2: Firebase Auth 登入系統** (使用者註冊、登入與狀態保存)
- [ ] **Phase 3: 語音錄音與文字轉錄** (語音輸入與基本備註儲存)
- [ ] **Phase 4: Gemini API 語意分析核心** (關鍵字提取、重點摘要、時間分析)
- [ ] **Phase 5: 排程與提醒推播** (本地/系統日曆串接與通知)

### 🗄️ Firestore 資料結構預覽 (Schema Draft)
*(未來將隨 Phase 1 開發持續更新詳細規格)*
- `/users/{userId}`: 業務員帳號資料。
- `/users/{userId}/customers/{customerId}`: 客戶基本資料與標籤。
- `/users/{userId}/customers/{customerId}/notes/{noteId}`: 互動備註、AI 摘要與待辦事項。

### 🔌 API 與敏感資訊管理規範
- 所有敏感金鑰（如 Firebase 配置、Gemini API Key）**嚴禁**提交至 Git 倉庫。
- 使用 `flutter_dotenv` 或 Dart 官方定義的 `--dart-define` 載入本地變數。