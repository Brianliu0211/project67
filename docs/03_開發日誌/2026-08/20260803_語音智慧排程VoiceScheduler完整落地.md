# 📅 2026-08-03 - 【模組三 + 模組四】語音智慧行程排程功能 (Voice Scheduler) 完整落地

> **執行狀態**：🟢 已併入主線 (src) — `feature/beast-voice-scheduler` 分支

---

## 🎯 實作成果摘要

在「今日行程」頁面右下角新增霓虹呼吸光暈麥克風 FAB，點擊後彈出全螢幕磨砂玻璃錄音面板。說出行程語音後，由後端 Groq Whisper 進行 STT 轉錄、Llama 3.3 70B 進行語意分析，自動推算時間、匹配客戶並寫入 `schedule_events`，前端以🟢🟡🔴三燈防呆機制回饋解析品質，行事曆即時刷新。

---

## 💻 技術變更明細 (Actual Technical Changes)

### 後端 (Supabase Edge Functions)

- **[NEW] `supabase/functions/voice-scheduler/index.ts`**：
  - 全新 Deno Edge Function，接收 `audioBase64`、`mimeType`、`localTime`。
  - **STT 層 (Groq Whisper)**：`transcribeWithGroq()` 將 Base64 音訊還原為二進位，封裝為 `multipart/form-data` 送至 `whisper-large-v3-turbo` 模型。
  - **NLU 層 (Groq 自適應輪替)**：`parseScheduleWithGroq()` 自動依序嘗試 `llama-3.3-70b-versatile` → `llama-3.1-8b-instant` → `llama3-70b-8192`，具備防下架容錯能力。System Prompt 要求模型輸出含 `is_time_defaulted` 與 `is_title_defaulted` 布林旗標的 JSON，作為黃燈觸發依據。
  - **客戶模糊匹配**：自動去除姓名尾碼（「經理」「總」「小姐」等），以 `ilike` 查詢 `customers` 表。
  - **JWT 驗證 Hotfix**：Deno Stateless 環境中必須以 `auth.getUser(token)` 而非 `auth.getUser()` 取得使用者身分，否則回傳 `Auth session missing!`。

    ```typescript
    const token = authHeader.replace('Bearer ', '');
    const { data: { user } } = await supabaseClient.auth.getUser(token);
    ```

  - **三燈判定邏輯**：根據 `is_time_defaulted`、`is_title_defaulted`、客戶匹配結果，組合 `status: 'green' | 'yellow'` 與 `warning_messages[]` 回傳前端。

---

### 前端 (Flutter)

- **[NEW] `lib/widgets/voice_scheduler_overlay.dart`**：
  - `RecordingState` enum 新增 `success`（🟢）、`warning`（🟡）兩種狀態，原有 `error` 為🔴。
  - 🟢 **綠燈面板**：`AnimatedContainer` 背景染綠光暈，大勾勾圖示 + 1.2 秒後自動 `Navigator.pop` 並回傳 event。
  - 🟡 **黃燈面板**：橘色光暈，警示圖示，以 Column 展示所有 `warning_messages`，底部「捨棄行程」（呼叫 Supabase DELETE）與「手動調整」（pop 回 eventResult 供後續編輯）。
  - 🔴 **紅燈面板**：原有錯誤畫面微染紅光暈。
  - `PulseCircle` 同心圓波紋動畫現支援傳入任意 `Color`（綠燈面板使用 `Colors.green`）。

- **[MODIFY] `lib/screens/home_screen.dart`**：
  - 新增 `_openVoiceSchedulerDialog()`，依回傳的 `status` 分流：
    - 🟡 Yellow → `CustomToast.warning` + 自動 `await _openAddEditEventDialog(event)` 帶入預填資料。
    - 🟢 Green → `CustomToast.success` + `_fetchEventsForSelectedDate()` 即時刷新。
  - Scaffold `floatingActionButton` 依 `_activeMenu == '今日行程'` 條件顯示 `_VoiceSchedulerFAB`。
  - `_VoiceSchedulerFAB` 組件：深色模式下以 `AnimationController` 動態調整 `boxShadow.blurRadius`，實現霓虹呼吸光暈效果。

- **[MODIFY] `lib/services/voice_transcription_service.dart`**：
  - 新增 `transcribeAndCreateEvent(DateTime localTime)`：錄音轉 Base64 → 帶入 `_formatIso8601WithOffset(localTime)` 時區字串 → POST 至 `voice-scheduler` Edge Function。
  - 引入 `flutter_dotenv` 雙軌讀取環境配置，修復靜態 Web 建置中 `SUPABASE_URL` 為空導致 HTTP 501 的問題。

---

## ⚠️ 環境異動與破壞性變更

- **Supabase Edge Function 需重新部署**：`supabase functions deploy voice-scheduler`（需在有 CLI 的環境操作）。
- **Supabase Secrets 依賴**：Edge Function 依賴已配置的 `GROQ_API_KEY`（Whisper STT + Llama NLU）。本次已完全移除 Gemini API 依賴，不需設定 `GEMINI_API_KEY`。
- **無 pubspec.yaml 新增套件**：本次功能不涉及新套件安裝。

---

## 🚦 團隊協作與驗證指南 (Verification Plan)

### 工程師驗證

```bash
# 1. 部署 Edge Function（需 Supabase CLI）
supabase functions deploy voice-scheduler

# 2. 重新建置前端
flutter build web --release

# 3. 啟動本地預覽
python -m http.server 8080 --directory build/web
```

### 三燈測試語音範本

| 語音輸入 | 預期燈號 |
|---|---|
| 「明天下午三點跟林經理開會一個小時」 | 🟢 綠燈 |
| 「跟客戶開個會」（無時間） | 🟡 黃燈 |
| 「下午四點跟宇宙人開會」（查無客戶） | 🟡 黃燈 |
| 不說話直接按完成 | 🔴 紅燈 |

### PM 預覽

登入 http://localhost:8080 後，點擊「今日行程」右下角麥克風按鈕，說出行程語音後觀察面板燈號與 Toast 提示。
