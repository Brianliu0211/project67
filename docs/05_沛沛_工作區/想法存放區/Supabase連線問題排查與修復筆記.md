# Supabase 連線問題排查與修復筆記

> **建立日期**：2026-10-06  
> **紀錄人員**：沛沛 (peihan)  
> **問題類型**：線上部署環境變數錯誤 / OAuth 登入中斷 / Supabase API 閘道誤判  

---

## 一、 問題現象 (Symptom)

- **觸發情境**：在開啟專題線上網址（`https://project67-red.vercel.app`）並點擊「Google 登入」時，畫面跳轉至一個黑底頁面，並顯示以下 JSON 錯誤字串：
  ```json
  {"message":"No API key found in request","hint":"No 'apikey' request header or url param was found."}
  ```
- **當下網址列**：
  ```text
  https://algufuoxkeizxwkofmmp.supabase.co/rest/v1//auth/v1/authorize?provider=google&redirect_to=https%3A%2F%2Fproject67-red.vercel.app&prompt=select_account
  ```
- **直覺疑慮**：「是不是專案忘記給 API Key？還是 API Key 過期失效了？」

---

## 二、 根本成因剖析 (Root Cause)

### 1. 表面原因 vs. 根本原因
- **不是漏給 API Key**：錯誤訊息雖然寫著「No API key found」，但這只是一個「誤判結果」。
- **根本原因**：**Supabase 基礎網址（`SUPABASE_URL`）被填入了 `/rest/v1`，導致認證跳轉被送進了資料庫 API 通道。**

### 2. Supabase 雙通道閘道架構差異
| 服務通道 | 標準端點路徑 | 作用 | 驗證規則 |
|---|---|---|---|
| **Auth 認證模組 (GoTrue)** | `/auth/v1/...` | 處理使用者註冊、登入、Google OAuth 瀏覽器跳轉授權 | 瀏覽器直接造訪授權端點，**不需**也不該帶 `apikey` 標頭 |
| **Data 資料庫模組 (PostgREST)** | `/rest/v1/...` | 提供資料表 CRUD 操作的 RESTful API | **強制要求**每一個請求必須附帶 `apikey` 標頭或參數，否則直接拒絕 (401) |

當前端拿到的 Supabase URL 結尾帶有 `/rest/v1` 時，Flutter Supabase SDK 在發起 Google 登入時會自動串接路徑，結果拼湊成：
$$\text{https://algufuoxkeizxwkofmmp.supabase.co} + \mathbf{/rest/v1} + \mathbf{//auth/v1/authorize}$$

Supabase 雲端閘道（Kong API Gateway）解析該請求時，看到開頭是 `/rest/v1`，便判定這是「資料庫查詢」，進而檢查是否帶有 API Key；因瀏覽器跳轉網址未帶 API Key，閘道立即拋出 `No API key found in request`。

### 3. 為什麼會突然發生？（時間溯源）
1. **GitHub Secrets 誤填**：9/30 團隊在設定/修復保險商品爬蟲排程時，從 Supabase 後台複製網址時，誤複製了「REST URL」（`.../rest/v1`），而非乾淨的「Project URL」（`...supabase.co`），並存入 GitHub Secrets 的 `SUPABASE_URL`。
2. **爬蟲腳本有修，但 Secrets 未改回**：當時爬蟲也噴出錯誤，蘿蔔在爬蟲工作流（`crawl_insurance_cron.yml`）中加入了 `sed` 替換過濾，但 GitHub Secrets 裡的值依舊保持錯誤狀態。
3. **前端自動部署打包**：後續只要有 PR 合併至 `main`，GitHub Actions 的 [deploy.yml](../../.github/workflows/deploy.yml) 就會抓取該 Secret 產生 `.env`，並以該設定編譯 Flutter Web 部署至 Vercel，導致線上版本的 Google 登入跟著損壞。

---

## 三、 GitHub Secrets 資安觀念補充

在前往 GitHub 修改 `SUPABASE_URL` 時，點擊「Update secret」會發現裡面的 **Value 欄位完全是空的**：
- **這是 100% 正常的資安設計**：GitHub Secrets 採取「**Write-Only（只寫不讀）**」的安全架構。
- 為了避免任何具備倉庫權限的人調閱或竊取 API 金鑰、密碼等敏感資料，GitHub 永遠不會回顯已儲存的值。
- 每次點進「Update secret」，只需要直接將**全新且正確的值**貼入文字框覆蓋即可。

---

## 四、 標準解決流程 (SOP)

### 步驟 1：修正 GitHub Repository Secrets
1. 前往 GitHub 專案倉庫：`Brianliu0211/project67`。
2. 點擊頂部 **Settings** $\rightarrow$ 左側 **Secrets and variables** $\rightarrow$ **Actions**。
3. 找到 **Repository secrets** 中的 **`SUPABASE_URL`**，點擊右側編輯筆圖示。
4. 在 `Value` 欄位填入乾淨的根網域：
   ```text
   https://algufuoxkeizxwkofmmp.supabase.co
   ```
   *(⚠️ 特別注意：結尾不可包含 `/rest/v1`，也不可包含結尾斜線 `/`)*
5. 點擊綠色 **Update secret** 儲存。

### 步驟 2：重新執行 Vercel 部署 (Re-run)
1. 點擊 GitHub 專案頂部的 **Actions** 頁籤。
2. 左側選擇 **`Deploy Flutter Web to Vercel`** 工作流。
3. 點選最新一筆執行紀錄（最上方那筆）。
4. 點擊右上角 **Re-run jobs** $\rightarrow$ **Re-run all jobs**。
5. 等待約 2~3 分鐘，全部步驟顯示綠色打勾（✅）完成部署。

### 步驟 3：驗證與確認
- 開啟線上專題網址：`https://project67-red.vercel.app`。
- 點擊「Google 登入」，確認畫面能正常跳轉至 Google 帳號選擇畫面，且授權後能正確導回系統。

---

## 五、 長期防呆建議 (防患未然)

為防止未來其他成員或重新配置環境時再度誤填，建議後續在專案中加入**雙重防禦機制**：
1. **前端初始化淨化（`lib/main.dart`）**：
   在執行 `Supabase.initialize` 前，程式碼自動進行網址正規化：
   ```dart
   if (supabaseUrl != null) {
     supabaseUrl = supabaseUrl
         .replaceAll(RegExp(r'/rest/v1/?$'), '')
         .replaceAll(RegExp(r'/+$'), '');
   }
   ```
2. **部署工作流防呆（`.github/workflows/deploy.yml`）**：
   在建立 `.env` 時加入 `sed` 指令自動清理結尾的 `/rest/v1`，確保編譯產物永遠使用乾淨網址。
