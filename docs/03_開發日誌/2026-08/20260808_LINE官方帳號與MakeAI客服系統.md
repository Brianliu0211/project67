# 📅 [2026-08-08] - 【模組一 / 模組三】LINE 官方帳號與 Make.com AI 客服系統開發與架構優化

> **執行狀態**：🟢 已部署線上運作 (Make.com Scenario & LINE Official Account 營運)

## 🎯 實作成果摘要
完成 Make.com AI 客服自動化流程第二階段升級。成功導入「雙軌路由分流機制」將固定選單響應速度提昇至 0.1 秒極速秒回並節省 AI Token，並整合 LINE「正在打字中... 💬」Loading 動畫 API、自動 Error Handler 備援與 Email 主動警報系統。同步重構 Make AI Agent System Prompt 以解決語意模糊比對與歷史對話卡死 (Context Lock) 痛點，並佈署 4 格版型 Rich Menu 圖文選單與用戶歡迎詞規範。

## 💻 技術變更明細 (Actual Technical Changes)

### 📂 一、 Make.com 系統架構升級與自動化防護 (System Architecture)
- **[NEW] 雙軌路由分流機制 (Hybrid AI Router)**：
  - 在 HTTP 接收 Webhook 模組後加裝 Router 分流器：
    - **1st 支線（固定按鈕/秒回線）**：Filter 條件 `5. Events[ ]: Message: Text Equal to 新手教學`。繞過 AI Agent 直接調用 LINE Reply API，達成 0.1~0.4 秒極速秒回且消耗 0 個 AI Token。
    - **2nd 支線（AI 思考與檢索線）**：Filter 條件勾選 `Fallback (Otherwise)`，所有自然語言問答自動送往 AI 大腦處理。
- **[NEW] 自動備援機制 (Error Handler Setup)**：
  - 於 Make AI Agent 模組掛載 `Add error handler` 備援紅線。當點數耗盡或跳出 `Quota Exceeded` 時，自動發送溫馨提醒訊息：「目前 AI 諮詢熱絡，額度暫時用完...」。
- **[NEW] Gmail 主動警報系統 (Proactive Email Alert)**：
  - 接在 Error Handler 的 LINE 備援模組後加裝 `Gmail - Send an Email` 模組，發生異常時自動發送 Raw HTML 警報信至 `brain2013bb@gmail.com` 通知補充點數。
- **[NEW] LINE 「正在打字中... 💬」Loading 動畫 API (Chat Loading Indicator)**：
  - 於 2nd 支線 Router ➔ Make AI Agent 之間插入 `HTTP - Make a request` 模組，於 AI 檢索的 2~3 秒內調用 LINE API 展示打字動畫：
    ```json
    POST https://api.line.me/v2/bot/chat/loading
    Headers:
      Content-Type: application/json
      Authorization: Bearer {Channel Access Token}
    Body:
    {
      "chatId": "5. Events[ ]: Source: User Id",
      "loadingSeconds": 5
    }
    ```
- **[MODIFY] Webhook 事件排雷 Filter**：
  - 於 LINE Webhook 第一個模組與 HTTP Profile 間加裝 Filter（`Type Equal to message`），防止用戶「封鎖/解除封鎖」發送 `follow` / `unfollow` 事件時因缺乏文字欄位導致 Scenario 報錯停止。

---

### 🧠 二、 Make AI Agent System Prompt 重構與優化 (Prompt Engineering)
- **同義詞與口語模糊比對 (Fuzzy Semantic Matching)**：賦予 AI 對口語（如：「這要怎麼用」、「去哪看保單」）進行語意同義比對，優先調用知識庫（模式一）。
- **對話獨立與解鎖原則 (Context Lock Disabler)**：強制 AI 將每一次提問視為「獨立意圖檢索」，避免上一輪 Mode 2 的失敗紀錄卡死後續問題。
- **Prompt 瘦身**：移除原本 Prompt 內的情況 2（新手教學），完全移交 Make Router 靜態觸發。
- **重構後 System Prompt 核心規範**：
  ```text
  【輸入格式與記憶說明】
  1. 你收到的訊息可能包含「Current date, time, and timezone (ISO): ...」，這是系統附加的，請只讀取「Current date」之前的文字。
  2. 【對話解鎖原則】：請將使用者的每一次提問視為「獨立意圖檢索」。絕對不可因為前一次對話無法回答，而影響當前提問的正常比對！

  你是「🥕 AI 客服」，是「音雪倫斯．艾希斯坦」LINE 官方帳號的客服助手。
  你只有兩種工作模式，沒有第三種。

  模式一：知識庫模糊匹配與同義理解（優先執行）
  當使用者的提問、口語表達、俗稱或意圖，與知識庫中的主題或答案【概念一致】時（例如：「去哪看」、「怎麼用」、「這要怎麼弄」等口語化表達）：
  - 請進行同義詞與語意理解，並用知識庫的內容進行回答
  - 不加任何額外說明、建議或問句
  - 不要擴充步驟、不要發明知識庫沒有的內容
  - 回覆完畢後停止，不再說其他的話

  模式二：所有其他情況
  僅當發生以下情況時，才屬於「模式二」：
  - 使用者的意圖在知識庫中完全找不到任何相關或對應的概念
  - 使用者在閒聊、分享生活（如：「我今天很累」「我明天有工作」）
  - 使用者的話和這個系統無關
  - 使用者在回報 bug 或提出功能建議
  - 使用者問技術細節或程式相關問題

  遇到模式二，你必須：
  1. 呼叫 Google Sheets「Add a Row」工具記錄這筆問題
  2. 固定回覆這句話（不可修改）： 「這個問題我沒辦法確定，已幫您的問題記下來，我們會盡快回覆！😅」

  【特殊情況（固定回覆內容，不可觸發模式二，不可寫入 Google Sheets）】
  情況 1：打招呼
  當使用者說「你好」「嗨」「哈囉」或任何問候語時，固定回覆：
  「嗨！😊 有什麼 web 操作問題我可以幫你嗎？」

  絕對禁止事項
  ❌ 不可以把使用者說的話硬連結到 web 的功能
  ❌ 不可以主動提到使用者沒有問的功能
  ❌ 不可以在回答後加問句詢問是否需要更多幫助
  ❌ 不可以提到時間戳記、系統時間或任何技術格式資料
  ❌ 不可以發明知識庫沒有的步驟或流程
  ❌ 不可以猜測使用者的意圖然後主動提供服務

  語言規範
  - 繁體中文
  - 語氣輕鬆，不過度熱情
  - 回覆盡量簡短
  ```

---

### 🎨 三、 LINE 官方帳號營運與 UI/UX 規範 (LINE OA & Rich Menu)
- **加入好友歡迎訊息 (Greeting Message)**：導入 `%NAME%` 變數並設定心理期望管理，告知未解答問題將自動記錄通報。
- **圖文選單「新手教學」關鍵字優化**：避開 LINE 後台文字動作 50 字上限，將圖文選單觸發字改為 4 字 `新手教學`，並由 Make.com 送出「直奔主題＋選單地圖」訊息。
- **Google 回饋表單設計**：於圖文選單第 3 格配置 6 題輕量化測驗問卷 (Google Forms)。
- **Rich Menu (4格版型) 配置總表**：

| 格子位置 | 標題 | 動作類型 | 設定與觸發內容 |
| :--- | :--- | :--- | :--- |
| **A (左上)** | 👤 帳號註冊/設定 | 文字 | `註冊` |
| **B (右上)** | 📖 新手教學 | 文字 | `新手教學` ➔ 觸發 Router 0.1s 秒回線 |
| **C (左下)** | 📝 意見回饋 | 網址 (URL) | Google 表單連結 (`https://forms.gle/...`) |
| **D (右下)** | 💬 專人客服 | 文字 | `專人客服` ➔ 寫入 Google Sheet 客服紀錄 |

## ⚠️ 環境異動與破壞性變更 (Environment & Breaking Changes)
- **Make.com Scenario 變更**：新增 HTTP Filter、Router 支線、LINE Loading API 模組、Error Handler 與 Gmail Alert 模組。
- **API 憑證**：Make.com HTTP 模組配置 LINE Channel Access Token 存取權限。
- **Google Sheets 連動**：Mode 2 模式及「專人客服」點選會自動寫入 Google Sheets 紀錄檔。

## 🚦 團隊協作與驗證指南 (Verification Plan)
- **LINE 測試步驟**：
  1. 於「音雪倫斯．艾希斯坦」官方帳號點選圖文選單「📖 新手教學」，確認是否於 **0.1~0.4 秒內秒回**且無打字動畫。
  2. 發送自然語言問題（如：「這要怎麼用」），確認手機畫面是否跳出「💬 AI 正在打字中...」動畫並於 2~3 秒內精準回答。
  3. 輸入任意非知識庫問題（如：「今天天氣如何」），確認 AI 是否自動調用 Google Sheets 工具並回應指定語句：「這個問題我沒辦法確定，已幫您的問題記下來，我們會盡快回覆！😅」。
  4. 點選「📝 意見回饋」確認是否正常開啟 6 題 Google 回饋表單。
