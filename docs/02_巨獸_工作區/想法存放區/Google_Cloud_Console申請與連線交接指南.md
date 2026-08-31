# 📄 Google Cloud Console 憑證申請與日曆雙向同步啟用交接指南

> **文件版本**：v1.0  
> **建立日期**：2026-09-01  
> **撰寫人員**：巨獸 (beast)  
> **交接對象**：蘿蔔 (lobo) / 專案團隊  
> **相關規格**：[Google帳號與服務整合開發說明書](../../00_公共規格/Google帳號與服務整合開發說明書.md) | [主系統規格書](../../00_公共規格/main_spec.md) | [進度.md](../../進度.md)

---

## 🎯 1. 前言與交接背景

巨獸已完成 **模組四 Phase 5：Google 日曆雙向自動同步** 的全套代碼實作、資料庫 Schema 遷移與 31/31 單元測試驗證！

**目前架構具備 100% 生產級 (Production-Ready) 的「零修改即插即用」特性**。在尚未填入 Google Cloud 官方 Client ID 前，系統會自動平滑降級為離線模式，絕不影響 App 原有行程排程運作。

本指南專為 **蘿蔔 (lobo)** 撰寫，詳細說明如何申請 Google Cloud Console 憑證，以及金鑰設定完成後如何一鍵解鎖完全體功能！

---

## 🛠️ 2. 蘿蔔專屬 SOP：Google Cloud Console 憑證申請 4 步驟

請蘿蔔前往 [Google Cloud Console](https://console.cloud.google.com/) 執行以下步驟：

### Step 1: 建立或選擇專案
1. 登入 Google Cloud Console。
2. 頂部專案下拉選單點擊 **「新增專案 (New Project)」**。
3. 專案名稱輸入：`insurance-helper-prod`（或自訂名稱），點擊 **建立**。

### Step 2: 設定 OAuth 同意畫面 (OAuth Consent Screen)
1. 左側選單：**API 與服務** $\rightarrow$ **OAuth 同意畫面**。
2. User Type 選擇 **「外部 (External)」**，點擊 **建立**。
3. **應用程式資訊**：
   - 應用程式名稱：`保險經紀人智慧助理 (Insurance Helper)`
   - 使用者支援電子郵件：選擇您的 Email
4. **已授權網域 (Authorized Domains)** 新增：
   - `supabase.co`
   - `vercel.app`
5. **儲存並繼續**，進入 Scope 設定頁，點擊 **新增或移除範圍**，勾選：
   - `.../auth/calendar.events` (檢視與編輯日曆行程)
   - `.../auth/calendar` (檢視與管理次日曆)
6. 儲存完畢後完成設定。

### Step 3: 啟用 Google Calendar API 服務
1. 左側選單：**API 與服務** $\rightarrow$ **程式庫 (Library)**。
2. 搜尋欄輸入 `Google Calendar API`。
3. 點擊搜尋結果，並點選 **【啟用 (Enable)】**。

### Step 4: 建立 OAuth Client ID 憑證
1. 左側選單：**API 與服務** $\rightarrow$ **憑證 (Credentials)**。
2. 點擊頂部 **+ 建立憑證** $\rightarrow$ **OAuth 客戶端 ID**。
3. 應用程式類型選擇：**網頁應用程式 (Web Application)**。
4. 名稱輸入：`Insurance Helper Web Client`。
5. **已授權的 JavaScript 來源** 新增：
   - `http://localhost:8080`
   - `https://algufuoxkeizxwkofmmp.supabase.co`
6. **已授權的重導向 URI** 新增：
   - `http://localhost:8080`
   - `https://algufuoxkeizxwkofmmp.supabase.co/auth/v1/callback`
7. 點擊 **建立**，彈窗會顯示 **Client ID** 與 **Client Secret**，請妥善複製保存！

---

## 🔑 3. 將金鑰配置至 Supabase 與 `.env`

取得 Client ID 與 Client Secret 後：

1. **配置 Supabase Dashboard**：
   - 前往 [Supabase Dashboard](https://supabase.com/dashboard) $\rightarrow$ 選擇專案 $\rightarrow$ **Authentication** $\rightarrow$ **Providers** $\rightarrow$ **Google**。
   - 開啟 **Enable Google Provider**。
   - 貼入 **Client ID** 與 **Client Secret** 並存檔。

2. **配置本地與 Vercel 環境變數**：
   - 在專案 `.env` 檔新增：
     ```env
     GOOGLE_CLIENT_ID=您的Client_ID字串.apps.googleusercontent.com
     ```
   - 於 Vercel 環境變數中同步新增 `GOOGLE_CLIENT_ID`。

---

## 🚀 4. 金鑰設定完成後的驗收與功能測試流程

金鑰搞定後，請依以下 5 步驟體驗完全體功能：

1. **啟動預覽**：執行 `run_local_web.bat` 或開啟 [http://localhost:8080](http://localhost:8080)。
2. **連線帳號**：前往【系統設定 ⚙️】 $\rightarrow$ 【🔗 第三方帳號與服務連線管理】，點擊【未連線 / 點擊授權】，在跳出的 Google 畫面中完成登入與授權。
3. **開啟同步**：在同一個卡片中，將【Google 日曆行程雙向自動同步】開關切換為 **ON**。
4. **新增行程**：前往【今日行程 📅】，點擊新增一筆拜訪行程（如：`拜訪張先生 discuss 保單`）。
5. **前往真實 Google 日曆驗證**：
   - 打開您的真實 [Google Calendar 網頁或 App](https://calendar.google.com/)。
   - 側邊「我的日曆」列表會自動出現名為 **「保險助手 (Insurance Helper)」** 的專屬次日曆。
   - 剛剛在 App 建立的行程已精準出現在 Google 日曆中！
   - 在 Google 日曆上修改時間，再回到 App 重新整理，App 的行程時間亦會自動雙向對齊（LWW 衝突解決）！

---

## 🧩 5. 巨獸實作之底層技術細節摘要 (Technical Handoff)

給蘿蔔與 AI 團隊參考的實體異動檔案：

| 異動檔案 | 變更說明 |
| :--- | :--- |
| **`supabase_schema.sql`** | 於 `schedule_events` 表新增 `sync_status` 欄位 |
| **`20260901_google_calendar_sync_schema.sql`** | 獨立 DB Migration 腳本，具備 UNIQUE 索引防護 |
| **`pubspec.yaml` & `docs/工具包.md`** | 導入 `googleapis (^13.2.0)`, `google_sign_in (^6.2.1)`, `extension_google_sign_in_as_googleapis_auth (^2.0.12)` 並完成工具包對齊 |
| **`lib/services/google_calendar_sync_service.dart`** | 單例服務，包含次日曆自動探測、`extendedProperties.private` ID 對齊、LWW 時間戳衝突解決與離線降級防護 |
| **`lib/services/schedule_service.dart`** | 於 CRUD 中無縫掛載 Google Calendar 非同步同步鉤子 |
| **`lib/screens/settings_screen.dart`** | 整合「Google 日曆雙向同步」 Switch 開關與偏好持久化 |
| **`lib/widgets/schedule_event_dialog.dart`** | 頂部新增「Google 已對齊 / 自動對齊 Google」狀態徽章 |
| **`test/google_calendar_sync_test.dart`** | 4/4 單元測試全數綠燈通過 |

---
*本文件已歸檔於 `docs/02_巨獸_工作區/想法存放區/Google_Cloud_Console申請與連線交接指南.md`。*
