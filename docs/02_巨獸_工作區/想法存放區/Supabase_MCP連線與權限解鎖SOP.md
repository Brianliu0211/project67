# 🚀 Supabase MCP 工具連線與 AI 後台直連權限解鎖 SOP

> **寫給巨獸 (beast) 🐾 的設定指南**  
> **建立時間**：2026-08-10  
> **編寫人**：蘿蔔 (lobo) & Antigravity AI  
> **目的**：教你如何在一分鐘內開啟 Antigravity IDE 的 Supabase MCP 工具，讓 AI 助手能直接為你線上查詢、管理與維護 Supabase 資料庫與 SQL 語法！

---

## 🎯 為什麼需要設定 Supabase MCP？

開啟後，AI 助手將解鎖 **20+ 項 Supabase 直連工具**（包含 `list_tables` 線上資料表查詢、`execute_sql` 語法執行、`search_docs` 文件檢視、`list_migrations` 遷移紀錄等）。

開發過程中無需手動切換到 Web 版 Supabase Dashboard，AI 就能在對話中直接幫你檢視 Schema、驗證 RLS 權限或修復資料庫問題！

---

## 🛠️ 三步驟重複設定 SOP

### 步驟 1：開啟 Antigravity 設定頁面 (Settings)

你有兩種最快的開法：
* **快捷鍵 (最推薦 ⚡)**：按下鍵盤 `Ctrl` + `,`（Control 加逗號）。
* **選單列**：點擊視窗左上角主選單 `File` $\rightarrow$ 選擇 `Preferences` (或 `Settings`)。

### 步驟 2：找到 Installed MCP Servers 區塊

1. 在設定頁頂部的搜尋框輸入 **`MCP`** 或 **`Supabase`**。
2. 找到 **`Installed MCP Servers`** 列表，會看到 `supabase` 項目。

### 步驟 3：完成帳號授權 (Sign in)

1. 點擊 `supabase` 旁邊的 **【Sign in】** 按鈕（或點擊右側 Toggle 開關）。
2. 跳出瀏覽器授權視窗後完成登入，或填入 Supabase 資料庫連線字串 (Database Connection String)：
   ```text
   postgresql://postgres.algufuoxkeizxwkofmmp:[YOUR_DATABASE_PASSWORD]@aws-0-ap-northeast-1.pooler.supabase.com:6543/postgres
   ```
3. 完成後，設定頁面會亮起 **綠色燈號 🟢 `supabase` (`20 tools enabled`)**！

---

## 🔍 驗證連線是否成功

設定完成後，你可以直接在對話中請 AI 測試：
> *「請幫我用 Supabase MCP 查詢現在資料庫有哪些 Table 與資料筆數？」*

當 AI 成功回傳 `public.profiles` (7 筆)、`public.customers` (21 筆)、`public.schedule_events` (15 筆) 等線上真實數據時，代表權限已 100% 解鎖！

---

> 💡 **小貼士**：若在對話框最下方看到舊的黃色 `⚠️ MCP Error` 警告，那是該對話開啟時的舊快照訊息，只要設定頁亮綠燈 🟢，所有 20 項 MCP 工具就已經全數生效發揮作用囉！
